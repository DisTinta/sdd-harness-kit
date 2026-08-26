#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh — instala el SDD Harness Kit en un repositorio.
#
#   ./install.sh                        instala en el directorio actual
#   ./install.sh --dest ../mi-proyecto  instala en otro repositorio
#   ./install.sh --stack laravel        fuerza el adaptador
#   ./install.sh --dry-run              enseña lo que haría, sin tocar nada
#   ./install.sh --force                sobrescribe ficheros ya existentes
#
# Estructura que deja:
#   ai-specs/          fuente canónica de skills, agents y plantillas
#   .claude/ .cursor/  referencias a ai-specs (symlink, o copia si el SO no lo permite)
#   docs/              doctrina del kit + los standards del stack + tu contexto
#   CLAUDE.md AGENTS.md GEMINI.md codex.md → docs/base-standards.md
#
# Es idempotente: si vuelves a ejecutarlo, respeta lo que ya hay salvo --force.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$PWD"
STACK=""
DRY_RUN=0
FORCE=0
NO_FRONTEND=0

C_OK=$'\033[0;32m'; C_SKIP=$'\033[0;90m'; C_WARN=$'\033[0;33m'
C_ERR=$'\033[0;31m'; C_HEAD=$'\033[1;36m'; C_OFF=$'\033[0m'

say()   { printf '%s\n' "$*"; }
head_() { printf '\n%s%s%s\n' "$C_HEAD" "$*" "$C_OFF"; }
ok()    { printf '  %s✔%s %s\n' "$C_OK" "$C_OFF" "$*"; }
skip()  { printf '  %s·%s %s\n' "$C_SKIP" "$C_OFF" "$*"; }
warn()  { printf '  %s!%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
die()   { printf '%s✘ %s%s\n' "$C_ERR" "$*" "$C_OFF" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)        DEST="${2:?--dest necesita una ruta}"; shift 2 ;;
    --stack)       STACK="${2:?--stack necesita un nombre}"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --force)       FORCE=1; shift ;;
    --no-frontend) NO_FRONTEND=1; shift ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Opción desconocida: $1" ;;
  esac
done

[[ -d "$DEST" ]] || die "El destino no existe: $DEST"
DEST="$(cd "$DEST" && pwd)"
[[ "$DEST" == "$KIT_DIR" ]] && die "No instales el kit sobre sí mismo. Usa --dest."

# ── Detección de stack ───────────────────────────────────────────────────────
detect_stack() {
  if [[ -f "$DEST/package.json" ]] && grep -q '"@adonisjs/core"' "$DEST/package.json" 2>/dev/null; then
    echo adonisjs; return
  fi
  if [[ -f "$DEST/artisan" ]] && [[ -f "$DEST/composer.json" ]]; then
    echo laravel; return
  fi
  # Fastify puede estar en la raíz o, en un monorepo, en un paquete del workspace.
  if grep -rqs '"fastify"' "$DEST/package.json" "$DEST"/packages/*/package.json 2>/dev/null; then
    echo fastify; return
  fi
  echo _template
}

[[ -z "$STACK" ]] && STACK="$(detect_stack)"
[[ -f "$KIT_DIR/adapters/$STACK.env" ]] || die "No existe el adaptador '$STACK'. Disponibles: $(ls "$KIT_DIR"/adapters/*.env | xargs -n1 basename | sed 's/\.env$//' | paste -sd ', ' -)"

head_ "SDD Harness Kit"
VER="dev"; [[ -f "$KIT_DIR/VERSION" ]] && VER="$(tr -d '\r\n' < "$KIT_DIR/VERSION")"
say   "  Versión: $VER"
say   "  Origen : $KIT_DIR"
say   "  Destino: $DEST"
say   "  Stack  : $STACK"
[[ $NO_FRONTEND -eq 1 ]] && say "  Frontend: plantilla vacía (--no-frontend)"
[[ $DRY_RUN -eq 1 ]] && say "  Modo   : simulación, no se escribe nada"

# ── Copia idempotente ────────────────────────────────────────────────────────
copy_file() {
  local src="$1" rel="$2" dst="$DEST/$2"
  if [[ -e "$dst" && $FORCE -eq 0 ]]; then
    if cmp -s "$src" "$dst"; then skip "$rel (idéntico)"
    else warn "$rel ya existe y difiere — conservado (usa --force para sobrescribir)"; fi
    return
  fi
  if [[ $DRY_RUN -eq 1 ]]; then ok "$rel (simulado)"; return; fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  case "$rel" in *.sh) chmod +x "$dst" ;; esac
  ok "$rel"
}

head_ "1. Fuente canónica: ai-specs/"
( cd "$KIT_DIR/core" && find ai-specs -type f -print0 ) | while IFS= read -r -d '' rel; do
  copy_file "$KIT_DIR/core/$rel" "$rel"
done

head_ "2. Hooks y configuración de agente"
( cd "$KIT_DIR/core" && find .claude .cursor .github -type f -print0 ) | while IFS= read -r -d '' rel; do
  copy_file "$KIT_DIR/core/$rel" "$rel"
done

head_ "2b. MCP del proyecto (Context7 · Playwright)"
MCP_TPL="$KIT_DIR/core/ai-specs/templates/mcp.json"
[[ $NO_FRONTEND -eq 1 ]] && MCP_TPL="$KIT_DIR/core/ai-specs/templates/mcp.context7-only.json"
copy_file "$MCP_TPL" ".mcp.json"
copy_file "$MCP_TPL" ".cursor/mcp.json"

head_ "3. Doctrina en docs/"
for f in base-standards documentation-standards openspec-tasks-mandatory-steps; do
  copy_file "$KIT_DIR/core/docs/$f.md" "docs/$f.md"
done

head_ "4. Standards del stack"
copy_file "$KIT_DIR/adapters/$STACK.env" ".claude/sdd-harness.env"
BE="$KIT_DIR/adapters/$STACK.backend-standards.md"
[[ -f "$BE" ]] || BE="$KIT_DIR/adapters/_template.backend-standards.md"
copy_file "$BE" "docs/backend-standards.md"
if [[ $NO_FRONTEND -eq 1 ]]; then
  FE="$KIT_DIR/adapters/_template.frontend-standards.md"
  [[ -f "$FE" ]] || FE="$KIT_DIR/adapters/react.frontend-standards.md"
  copy_file "$FE" "docs/frontend-standards.md"
else
  copy_file "$KIT_DIR/adapters/react.frontend-standards.md" "docs/frontend-standards.md"
fi
[[ -f "$KIT_DIR/adapters/$STACK.rules.mdc" ]] && copy_file "$KIT_DIR/adapters/$STACK.rules.mdc" ".cursor/rules/30-stack.mdc"
[[ -f "$KIT_DIR/adapters/$STACK.ci.yml" ]] && copy_file "$KIT_DIR/adapters/$STACK.ci.yml" ".github/workflows/ci.yml"
if [[ -f "$KIT_DIR/adapters/$STACK.infection.json" ]]; then
  if [[ -f "$DEST/infection.json" ]]; then
    skip "infection.json ya existe — conservado"
  else
    copy_file "$KIT_DIR/adapters/$STACK.infection.json" "infection.json"
  fi
fi
if [[ -f "$KIT_DIR/adapters/$STACK.dependency-cruiser.js" ]]; then
  if [[ -f "$DEST/.dependency-cruiser.js" ]]; then
    skip ".dependency-cruiser.js ya existe — conservado"
  else
    copy_file "$KIT_DIR/adapters/$STACK.dependency-cruiser.js" ".dependency-cruiser.js"
  fi
fi

head_ "5. Plantillas del proyecto"
copy_file "$KIT_DIR/core/ai-specs/templates/pull_request_template.md" ".github/pull_request_template.md"
copy_file "$KIT_DIR/core/ai-specs/templates/adr.md.tpl" "docs/adr/_template.md"

head_ "6. Contexto del proyecto"
if [[ -f "$DEST/docs/project-context.md" ]]; then
  skip "docs/project-context.md ya existe — conservado (es tuyo, el kit no lo pisa)"
elif [[ $DRY_RUN -eq 1 ]]; then
  ok "docs/project-context.md (simulado, con los comandos del adaptador)"
else
  set -a; source "$KIT_DIR/adapters/$STACK.env"; set +a
  mkdir -p "$DEST/docs"
  PROJECT_NAME="$(basename "$DEST")"
  TPL="$KIT_DIR/core/ai-specs/templates/project-context.md.tpl"
  OUT="$DEST/docs/project-context.md"
  if command -v python3 >/dev/null 2>&1; then
    PROJECT_NAME="$PROJECT_NAME" python3 - "$TPL" "$OUT" <<'PY'
import os, pathlib, sys
tpl, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
text = tpl.read_text(encoding='utf-8')
text = text.replace('{{PROJECT_NAME}}', os.environ.get('PROJECT_NAME', 'project'))
for key in ('CMD_DEV', 'CMD_TEST', 'CMD_TEST_FILTER', 'CMD_LINT', 'CMD_STATIC', 'CMD_MIGRATE'):
    text = text.replace('{{' + key + '}}', os.environ.get(key) or 'not configured')
out.write_text(text, encoding='utf-8')
PY
  else
    # Fallback sin python3 (sed/bash puro)
    text="$(cat "$TPL")"
    text="${text//\{\{PROJECT_NAME\}\}/$PROJECT_NAME}"
    for key in CMD_DEV CMD_TEST CMD_TEST_FILTER CMD_LINT CMD_STATIC CMD_MIGRATE; do
      val="${!key:-not configured}"
      text="${text//\{\{$key\}\}/$val}"
    done
    printf '%s\n' "$text" > "$OUT"
    warn "python3 no disponible: project-context generado con fallback bash"
  fi
  ok "docs/project-context.md creado, con los comandos del adaptador ya puestos"
  warn "Tiene marcadores {{...}} pendientes: complétalos antes de la primera sesión"
fi

head_ "7. Memoria multi-agente"
# Los cuatro ficheros raíz apuntan a la misma doctrina.
for name in CLAUDE.md AGENTS.md GEMINI.md codex.md; do
  if [[ -e "$DEST/$name" ]]; then
    skip "$name ya existe"
  elif [[ $DRY_RUN -eq 1 ]]; then
    ok "$name → docs/base-standards.md (simulado)"
  elif ln -s docs/base-standards.md "$DEST/$name" 2>/dev/null; then
    ok "$name → docs/base-standards.md (symlink)"
  else
    printf '@docs/base-standards.md\n' > "$DEST/$name"
    ok "$name creado con import (el symlink no estaba disponible)"
  fi
done

head_ "8. Referencias de skills y agents"
if [[ $DRY_RUN -eq 1 ]]; then
  ok ".claude/{skills,agents} y .cursor/{skills,agents} → ai-specs (simulado)"
else
  ( cd "$DEST" && CLAUDE_PROJECT_DIR="$DEST" bash .claude/sync-artifacts.sh ) | sed 's/^/  /'
fi

head_ "8b. Doctor del harness (copia local en el proyecto)"
copy_file "$KIT_DIR/doctor.ps1" ".claude/doctor.ps1"
copy_file "$KIT_DIR/doctor.sh" ".claude/doctor.sh"

# ── Comprobaciones ───────────────────────────────────────────────────────────
head_ "9. Comprobaciones"
command -v jq  >/dev/null 2>&1 && ok "jq disponible"  || warn "jq NO está instalado: los hooks se desactivarán solos hasta que lo instales"
command -v git >/dev/null 2>&1 && ok "git disponible" || warn "git no disponible"
[[ -d "$DEST/.git" ]] && ok "el destino es un repositorio git" || warn "el destino no es un repositorio git"
if [[ -f "$DEST/.gitignore" ]] && ! grep -q '^\.claude/settings\.local\.json' "$DEST/.gitignore" 2>/dev/null; then
  if [[ $DRY_RUN -eq 1 ]]; then
    ok ".gitignore — se añadirían las entradas del kit (simulado)"
  else
    printf '\n# sdd-harness-kit\n.claude/settings.local.json\n.worktrees/\n' >> "$DEST/.gitignore"
    ok ".gitignore — añadidas las entradas del kit"
  fi
fi

if [[ $DRY_RUN -eq 0 ]]; then
  head_ "10. Doctor (salud del harness)"
  bash "$KIT_DIR/doctor.sh" --dest "$DEST" || warn "doctor encontró fallos — revísalos antes de la primera sesión"
fi

head_ "Siguientes pasos"
cat <<STEPS
  1. Completa docs/project-context.md (<200 líneas). Es el paso de mayor ROI del kit.
  2. Revisa .claude/sdd-harness.env (comandos reales + BRANCH_PREFIX). Los hooks los ejecutan tal cual.
  3. Revisa docs/backend-standards.md si tu arquitectura no es la del adaptador.
  4. Activa los MCP del proyecto en Claude Code / Cursor (Context7; Playwright si hay frontend).
     Si Cursor pide permiso la primera vez, acéptalo. Opcional: CONTEXT7_API_KEY en el entorno.
  5. Inicializa OpenSpec:  openspec init
     Luego cablea openspec/config.yaml con ai-specs/templates/openspec/config.yaml.tpl
  6. Revisa .claude/hooks/ antes de confiar en ellos: ejecutan código con tus permisos.
  7. Abre una sesión y escribe /enrich-us (o /kit-health) para probar que las skills cargan.
  8. Vuelve a pasar el doctor:  bash $DEST/.claude/doctor.sh --dest $DEST

  NO ejecutes /init: los cuatro ficheros raíz apuntan a docs/base-standards.md y /init
  escribiría a través de ellos. Para el contexto del proyecto usa el prompt P0.

  Edita siempre ai-specs/ y ejecuta 'bash .claude/sync-artifacts.sh' para propagar.

  Guía paso a paso: $KIT_DIR/GUIA-PASO-A-PASO.md
  Uso / Manual / Prompts: USO.md · MANUAL.md · PROMPTS.md
STEPS
