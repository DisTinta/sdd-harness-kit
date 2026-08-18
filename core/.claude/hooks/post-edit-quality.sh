#!/usr/bin/env bash
# PostToolUse (Edit|Write) — formatea, analiza y comprueba las guardas de
# arquitectura del fichero recién escrito. El fichero YA está en disco: este
# hook solo devuelve feedback al agente para que corrija antes de seguir.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT=$(cat)
FILE=$(field "$INPUT" '.tool_input.file_path')
[[ -n "$FILE" ]] || exit 0
[[ -f "$FILE" ]] || exit 0
is_source "$FILE" || exit 0

PROBLEMS=""
NOTES=""

# 1. Formato: se aplica en silencio (sin eval).
if [[ -n "$CMD_FORMAT_FILE" ]]; then
  run_cmd "$CMD_FORMAT_FILE" "$FILE" >/dev/null 2>&1 || true
fi

# 2. Análisis estático sobre el fichero tocado.
if [[ -n "$CMD_STATIC_FILE" ]]; then
  if ! OUT=$(run_cmd "$CMD_STATIC_FILE" "$FILE" 2>&1); then
    PROBLEMS+="Análisis estático con errores:"$'\n'"$(printf '%s' "$OUT" | head -20)"$'\n\n'
  fi
fi

# 3. Guardas de arquitectura: la capa de negocio no conoce el transporte.
if [[ -n "$GUARD_HTTP_IN_BUSINESS" ]] && under "$FILE" "$PATH_BUSINESS"; then
  if grep -qE "$GUARD_HTTP_IN_BUSINESS" "$FILE" 2>/dev/null; then
    PROBLEMS+="Violación de capas: ${FILE} está en ${PATH_BUSINESS} y conoce HTTP. La capa de negocio recibe datos ya validados y devuelve entidades de dominio; no importa la request ni emite códigos de estado. Ver docs/backend-standards.md y docs/project-context.md."$'\n\n'
  fi
fi

# 4. Guardas de arquitectura: la capa HTTP no consulta la base de datos.
if [[ -n "$GUARD_DB_IN_HTTP" ]] && under "$FILE" "$PATH_HTTP"; then
  if grep -qE "$GUARD_DB_IN_HTTP" "$FILE" 2>/dev/null; then
    PROBLEMS+="Posible violación de capas: ${FILE} está en ${PATH_HTTP} y parece consultar la base de datos o usar la request sin validar. Las consultas viven en ${PATH_BUSINESS}. Ver docs/backend-standards.md."$'\n\n'
  fi
fi

# 5. English-only (docs/base-standards.md §2). Aviso, no bloqueo.
if [[ -n "$SPANISH_WORDS" ]]; then
  MATCHES=$(grep -oiE "$SPANISH_WORDS" "$FILE" 2>/dev/null | tr 'A-Z' 'a-z' | sort -u || true)
  COUNT=$(printf '%s' "$MATCHES" | grep -c . 2>/dev/null) || COUNT=0
  HITS=$(printf '%s' "$MATCHES" | head -5 | paste -sd ', ' -)
  if [[ "${COUNT:-0}" -ge 2 ]]; then
    NOTES+="Posible texto en español en ${FILE} (${HITS}). base-standards.md §2 exige inglés en todo artefacto técnico: código, comentarios, mensajes de error y logs. Si es un falso positivo, ignóralo."$'\n'
  fi
fi

if [[ -n "$PROBLEMS" ]]; then
  block "Corrige esto antes de continuar:"$'\n'"$PROBLEMS$NOTES"
fi
if [[ -n "$NOTES" ]]; then
  inject "PostToolUse" "$NOTES"
fi
exit 0
