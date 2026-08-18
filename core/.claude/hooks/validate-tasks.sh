#!/usr/bin/env bash
# PostToolUse (Edit|Write) sobre tasks.md — hace cumplir mecánicamente
# docs/openspec-tasks-mandatory-steps.md. Sin esto, el documento es una recomendación.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT=$(cat)
FILE=$(field "$INPUT" '.tool_input.file_path')
case "$FILE" in
  */tasks.md) : ;;
  *) exit 0 ;;
esac
[[ -f "$FILE" ]] || exit 0

PROBLEMS=""
BODY=$(cat "$FILE")

# 1. El paso 0 debe crear la rama, y debe ser el primero.
FIRST_SECTION=$(printf '%s' "$BODY" | grep -m1 '^## ' || true)
if ! printf '%s' "$FIRST_SECTION" | grep -qiE '^## 0\.'; then
  PROBLEMS+="El primer encabezado de tasks.md debe ser '## 0. ...' con la creación de la rama. Encontrado: ${FIRST_SECTION:-ninguno}."$'\n'
elif ! printf '%s' "$FIRST_SECTION" | grep -qiE 'branch|rama'; then
  PROBLEMS+="El paso 0 existe pero no menciona la creación de la rama de trabajo."$'\n'
fi

# 1b. Prefijo de rama configurado (BRANCH_PREFIX, p.ej. feature/).
if [[ -n "$BRANCH_PREFIX" ]]; then
  if ! printf '%s' "$BODY" | grep -qF "$BRANCH_PREFIX"; then
    PROBLEMS+="Ninguna tarea menciona el prefijo de rama '${BRANCH_PREFIX}' definido en .claude/sdd-harness.env (BRANCH_PREFIX). El Step 0 debe crear una rama con ese prefijo."$'\n'
  fi
fi

# 2. Los pasos obligatorios de verificación (EN + ES).
missing=""
printf '%s' "$BODY" | grep -qiE '^## .*(Review and Update Existing Tests|Existing Tests|Revisar.*(tests|pruebas)|Tests existentes)' \
  || missing+="  - Review and Update Existing Tests / Revisar tests existentes"$'\n'
printf '%s' "$BODY" | grep -qiE '^## .*(Run Tests|Verify Data State|Verify Database State|Ejecutar (tests|pruebas)|Verificar.*(datos|estado|base))' \
  || missing+="  - Run Tests and Verify Data State / Ejecutar tests y verificar estado"$'\n'
printf '%s' "$BODY" | grep -qiE '^## .*(Manual .*Testing|Manual Interface|Prueba(s)? manual|Verificación manual)' \
  || missing+="  - Manual Interface Testing / Verificación manual (AGENT MUST EXECUTE)"$'\n'
printf '%s' "$BODY" | grep -qiE '^## .*(Documentation|Documentación)' \
  || missing+="  - Update Technical Documentation / Actualizar documentación"$'\n'
if [[ -n "$missing" ]]; then
  PROBLEMS+="Faltan pasos obligatorios en tasks.md (ver docs/openspec-tasks-mandatory-steps.md):"$'\n'"$missing"
fi

# 3. Etiquetado.
printf '%s' "$BODY" | grep -q '(MANDATORY' || \
  PROBLEMS+="Ningún paso lleva la etiqueta (MANDATORY). Los pasos obligatorios deben marcarse."$'\n'
if printf '%s' "$BODY" | grep -qiE '^## .*(Manual|manual)' && ! printf '%s' "$BODY" | grep -q 'AGENT MUST EXECUTE'; then
  PROBLEMS+="El paso de verificación manual debe declarar 'AGENT MUST EXECUTE' explícitamente."$'\n'
fi

# 4. Restauración de estado en operaciones que mutan.
if printf '%s' "$BODY" | grep -qiE 'POST|PUT|PATCH|DELETE|create|update|delete|crear|actualizar|eliminar|borrar' && \
   ! printf '%s' "$BODY" | grep -qiE 'restor|revert|restaur|deshacer'; then
  PROBLEMS+="Hay tareas que mutan datos y ninguna menciona la restauración del estado tras la verificación."$'\n'
fi

# 5. Numeración de subtareas.
if ! printf '%s' "$BODY" | grep -qE '^- \[[ x]\] [0-9]+\.[0-9]+'; then
  PROBLEMS+="Las subtareas deben usar numeración jerárquica: '- [ ] N.M descripción'."$'\n'
fi

if [[ -n "$PROBLEMS" ]]; then
  block "tasks.md no cumple los pasos obligatorios. Corrígelo antes de implementar:"$'\n'"$PROBLEMS"
fi
exit 0
