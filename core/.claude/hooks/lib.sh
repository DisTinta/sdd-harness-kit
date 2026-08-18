#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lib.sh — utilidades comunes de los hooks del SDD Harness Kit.
#
# Todos los hooks hacen `source` de este fichero. Aquí vive:
#   · la carga SEGURA de .claude/sdd-harness.env (solo KEY=valor, sin eval de shell)
#   · run_cmd: ejecuta CMD_* sin `eval` (array + bash -c con argv)
#   · los emisores de decisiones en el formato JSON que espera Claude Code
#   · las degradaciones seguras cuando falta jq o falta configuración
#
# Principio: un hook nunca debe romper la sesión. Ante la duda, sale con 0.
# ─────────────────────────────────────────────────────────────────────────────

# Raíz del proyecto. En Windows, Claude Code puede pasar CLAUDE_PROJECT_DIR con
# backslashes que bash interpreta como escapes (C:\laragon → C:laragon). Si la
# ruta parece rota, caemos a git toplevel o PWD.
_project_root() {
  local d="${1:-}"
  d="${d//\\//}"
  if [[ -n "$d" && -d "$d/.claude/hooks" ]]; then
    printf '%s' "$d"
    return
  fi
  if [[ "$d" =~ ^[A-Za-z]:[^/] ]]; then
    d=""
  fi
  if [[ -z "$d" ]]; then
    d="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi
  d="${d//\\//}"
  printf '%s' "$d"
}
PROJECT_DIR="$(_project_root "${CLAUDE_PROJECT_DIR:-}")"
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
ENV_FILE="$PROJECT_DIR/.claude/sdd-harness.env"

# Valores por defecto: el kit funciona aunque el proyecto no configure nada.
STACK="sin configurar"
CMD_TEST=""; CMD_TEST_FILTER=""; CMD_LINT=""; CMD_FORMAT_FILE=""
CMD_STATIC_FILE=""; CMD_STATIC=""; CMD_MUTATION=""; CMD_DOCS_COVERAGE=""
CMD_DEV=""; CMD_MIGRATE=""
SOURCE_EXTENSIONS=""; PATH_SOURCE=""; PATH_TESTS=""; PATH_BUSINESS=""
PATH_HTTP=""; PATH_MIGRATIONS=""; PATH_ADR="docs/adr"
GUARD_HTTP_IN_BUSINESS=""; GUARD_DB_IN_HTTP=""; GUARD_DANGEROUS_CMD=""
LAYER_ORDER=""; MIN_MUTATION_SCORE="70"
BRANCH_PREFIX="feature/"
# Escape hatches (documentados en CONFIG.md / GUIA-PASO-A-PASO.md)
KIT_SKIP_STOP_TESTS="0"
KIT_ALLOW_WIP="0"

# Carga KEY="valor" o KEY=valor sin ejecutar el fichero como shell.
# Rechaza líneas con sustitución de comandos, backticks o $(...).
load_env_safe() {
  local file="$1" line key val
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    if [[ "$line" =~ \$\(|\`|\$\{ ]]; then
      printf 'sdd-harness: línea peligrosa ignorada en sdd-harness.env (posible command substitution)\n' >&2
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*\"(.*)\"[[:space:]]*$ ]]; then
      key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*\'(.*)\'[[:space:]]*$ ]]; then
      key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*([^#[:space:]].*)$ ]]; then
      key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
      val="${val%"${val##*[![:space:]]}"}"
    else
      continue
    fi
    case "$key" in
      STACK|CMD_TEST|CMD_TEST_FILTER|CMD_LINT|CMD_FORMAT_FILE|CMD_STATIC_FILE|CMD_STATIC|\
      CMD_MUTATION|CMD_DOCS_COVERAGE|CMD_DEV|CMD_MIGRATE|SOURCE_EXTENSIONS|PATH_SOURCE|\
      PATH_TESTS|PATH_BUSINESS|PATH_HTTP|PATH_MIGRATIONS|PATH_ADR|GUARD_HTTP_IN_BUSINESS|\
      GUARD_DB_IN_HTTP|GUARD_DANGEROUS_CMD|LAYER_ORDER|MIN_MUTATION_SCORE|BRANCH_PREFIX|\
      KIT_SKIP_STOP_TESTS|KIT_ALLOW_WIP)
        printf -v "$key" '%s' "$val"
        ;;
    esac
  done < "$file"
}

load_env_safe "$ENV_FILE"

# jq es la única dependencia externa. Sin ella, los hooks se desactivan solos
# en lugar de fallar en cada turno.
has_jq() { command -v jq >/dev/null 2>&1; }

# Lee el JSON de stdin y devuelve un campo. Uso: field "$INPUT" '.tool_name'
field() {
  has_jq || { printf ''; return 0; }
  printf '%s' "$1" | jq -r "$2 // empty" 2>/dev/null || printf ''
}

# Ejecuta un comando configurado en sdd-harness.env SIN eval.
# Uso: run_cmd "$CMD_TEST"
#      run_cmd "$CMD_FORMAT_FILE" "$FILE"
# El valor de CMD_* se interpreta como línea de shell simple (espacios = argv).
# Los argumentos extra se pasan como "$1", "$2"... al proceso vía entorno posicional.
run_cmd() {
  local cmdline="$1"; shift || true
  [[ -n "$cmdline" ]] || return 0
  # shellcheck disable=SC2086
  ( cd "$PROJECT_DIR" && bash -c -- "$cmdline \"\$@\"" _ "$@" )
}

# ── Emisores de decisión ─────────────────────────────────────────────────────
deny() {
  has_jq || { printf '%s\n' "$1" >&2; exit 2; }
  jq -nc --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

ask() {
  has_jq || exit 0
  jq -nc --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
}

block() {
  has_jq || { printf '%s\n' "$1" >&2; exit 2; }
  jq -nc --arg r "$1" '{decision:"block",reason:$r}'
  exit 0
}

block_prompt() {
  has_jq || { printf '%s\n' "$1" >&2; exit 2; }
  jq -nc --arg r "$1" '{decision:"block",reason:$r,hookSpecificOutput:{hookEventName:"UserPromptSubmit",suppressOriginalPrompt:true}}'
  exit 0
}

# Stop no admite additionalContext (Claude Code valida el JSON y falla el hook).
# systemMessage se muestra al usuario sin bloquear el cierre del turno.
notify() {
  has_jq || { printf '%s\n' "$1" >&2; exit 0; }
  jq -nc --arg m "$1" '{systemMessage:$m}'
  exit 0
}

inject() {
  has_jq || exit 0
  # Stop: ver notify(). SessionStart / PostToolUse sí usan additionalContext.
  if [[ "$1" == "Stop" ]]; then
    jq -nc --arg m "$2" '{systemMessage:$m}'
  else
    jq -nc --arg e "$1" --arg c "$2" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
  fi
  exit 0
}

# ── Utilidades ───────────────────────────────────────────────────────────────
under() {
  local file="$1" dir="$2"
  [[ -n "$dir" ]] || return 1
  # Normaliza barras para Windows (Git Bash).
  file="${file//\\//}"
  dir="${dir//\\//}"
  case "$file" in
    "$dir"|"$dir"/*|*/"$dir"|*/"$dir"/*) return 0 ;;
    *) return 1 ;;
  esac
}

SPANISH_WORDS='\b(que|para|con|los|las|una|del|por|como|pero|cuando|donde|desde|hasta|sobre|entre|porque|si no|además|también|según|función|usuario|usuarios|fecha|nombre|error de|no encontrado|obligatorio|debe|deben|siguiente|siguientes)\b'

is_source() {
  local file="$1" ext
  [[ -n "$SOURCE_EXTENSIONS" ]] || return 1
  for ext in $SOURCE_EXTENSIONS; do
    [[ "$file" == *."$ext" ]] && return 0
  done
  return 1
}

# ¿La ruta parece un fichero de secretos / entorno?
is_secret_path() {
  local file="${1//\\//}"
  case "$file" in
    *.env|*.env.*|*/.env|.env|*/.env.*|\
    */secrets/*|*/.secrets/*|*/credentials.json|*/credentials.*|\
    */id_rsa|*/id_ed25519|*/.npmrc|*/.pypirc|\
    */google-services.json|*/service-account*.json)
      return 0 ;;
  esac
  return 1
}
