#!/usr/bin/env bash
# Stop — no se cierra el turno con la suite en rojo.
# Escape: KIT_SKIP_STOP_TESTS=1 o KIT_ALLOW_WIP=1 en sdd-harness.env
# (solo para spikes locales; no uses esto en el flujo de entrega).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT=$(cat)
[[ "$(field "$INPUT" '.stop_hook_active')" == "true" ]] && exit 0
[[ "${KIT_SKIP_STOP_TESTS}" == "1" ]] && exit 0
[[ "${KIT_ALLOW_WIP}" == "1" ]] && exit 0
[[ -n "$CMD_TEST" ]] || exit 0

WATCH=""
for d in "$PATH_SOURCE" "$PATH_TESTS"; do
  [[ -n "$d" && -e "$PROJECT_DIR/$d" ]] && WATCH+=" $d"
done
[[ -n "$WATCH" ]] || exit 0
# shellcheck disable=SC2086
git -C "$PROJECT_DIR" diff --quiet HEAD -- $WATCH 2>/dev/null && exit 0

if OUT=$(run_cmd "$CMD_TEST" 2>&1); then
  notify "Suite en verde. Antes de dar por cerrada la tarea: marca las tasks completadas en tasks.md, comprueba si la decisión merece un ADR en ${PATH_ADR} y confirma que la documentación de la API sigue al día. Si tocas datos personales o auth, ejecuta /privacy-ethics-check."
  exit 0
fi

block "La suite de tests falla. No puedes cerrar el turno todavía. Salida de \`${CMD_TEST}\`:"$'\n'"$(printf '%s' "$OUT" | tail -30)"$'\n\nSi estás en un spike local y necesitas salir a medias, pon KIT_ALLOW_WIP=1 en .claude/sdd-harness.env (quítalo antes del PR).'
