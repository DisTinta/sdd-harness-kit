#!/usr/bin/env bash
# PreToolUse (Read) — impide que el agente lea ficheros de secretos al contexto.
# Complementa block-secrets.sh (que solo mira el prompt del usuario).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT=$(cat)
TOOL=$(field "$INPUT" '.tool_name')
FILE=$(field "$INPUT" '.tool_input.file_path')
[[ -n "$FILE" ]] || FILE=$(field "$INPUT" '.tool_input.path')
[[ -n "$FILE" ]] || exit 0

case "$TOOL" in
  Read|read|"") : ;;
  *) exit 0 ;;
esac

if is_secret_path "$FILE"; then
  deny "Lectura bloqueada: ${FILE} parece un fichero de secretos o credenciales. No cargues .env, claves privadas ni credentials.json en el contexto del modelo. Usa variables de entorno del shell o un secret manager. Si necesitas la FORMA de la config, pide al humano un ejemplo redactado."
fi

exit 0
