#!/usr/bin/env bash
# PreToolUse (Bash) con filtro sobre git commit — el gate de documentación de
# docs/documentation-standards.md: no se commitea código que deja la documentación mintiendo.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT=$(cat)
COMMAND=$(field "$INPUT" '.tool_input.command')
printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+commit' || exit 0

cd "$PROJECT_DIR" 2>/dev/null || exit 0

# Qué hay preparado para commitear.
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
[[ -n "$STAGED" ]] || exit 0

touches_source=0
touches_docs=0
touches_schema=0
touches_contract=0

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  is_source "$f" && touches_source=1
  case "$f" in
    docs/*|*.md) touches_docs=1 ;;
  esac
  [[ -n "$PATH_MIGRATIONS" ]] && under "$f" "$PATH_MIGRATIONS" && touches_schema=1
  [[ -n "$PATH_HTTP" ]] && under "$f" "$PATH_HTTP" && touches_contract=1
done <<< "$STAGED"

REASONS=""
if [[ $touches_schema -eq 1 && $touches_docs -eq 0 ]]; then
  REASONS+="  - Cambia el esquema de datos y no se actualiza ninguna documentación."$'\n'
fi
if [[ $touches_contract -eq 1 && $touches_docs -eq 0 ]]; then
  REASONS+="  - Cambia la capa de interfaz y no se regenera ni actualiza el contrato de API."$'\n'
fi

if [[ -n "$REASONS" ]]; then
  ask "Gate de documentación (docs/documentation-standards.md):
${REASONS}
Ejecuta la skill /update-docs antes de commitear, o confirma que la documentación ya estaba al día."
fi

exit 0
