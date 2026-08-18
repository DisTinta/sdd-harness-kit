#!/usr/bin/env bash
# PreToolUse (Edit|Write) — protege los artefactos que el agente no debe reescribir:
#   1. Los specs de OpenSpec, que son input del flujo y no output.
#   2. Los tests existentes, que son la especificación firmada.
#   3. Las migraciones ya versionadas.
#   4. Los ficheros de entorno.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT=$(cat)
FILE=$(field "$INPUT" '.tool_input.file_path')
[[ -n "$FILE" ]] || exit 0

# Path traversal.
case "$FILE" in
  *..*) deny "Ruta con '..' rechazada: ${FILE}" ;;
esac

# 1. openspec/: la distinción que importa es CREAR frente a REESCRIBIR.
#    Crear los artefactos de una propuesta es el flujo normal (fase propose).
#    Reescribir un artefacto que ya existe puede ser legítimo —la regla 7 de
#    base-standards.md exige actualizar la especificación ANTES de tocar código cuando
#    llega un cambio— o puede ser el agente haciendo que la spec encaje con lo que ya
#    implementó. Solo un humano distingue esos dos casos, así que se pregunta.
case "$FILE" in
  */openspec/*|openspec/*)
    case "$FILE" in
      */tasks.md) : ;;                 # marcar tasks completadas
      */reports/*) : ;;                # informes de verificación obligatorios
      */openspec/templates/*) : ;;     # plantillas del kit
      *)
        if [[ -f "$FILE" ]]; then
          ask "Vas a REESCRIBIR un artefacto de especificación que ya existe (${FILE}).

Esto es normal y frecuente si trabajas con el flujo fluido de OpenSpec: /opsx:apply arregla un
artefacto y sigue, /opsx:sync vuelca un delta sobre el spec principal. No es una alarma por sí sola.

Legítimo: ha llegado un cambio de alcance, o el diseño resultó estar mal, y estás actualizando la
especificación ANTES de (o mientras) tocas el código — la regla 7 de docs/base-standards.md.

Ilegítimo: estás ajustando la especificación para que encaje con código que ya has escrito sin que
el diseño haya cambiado. Eso invierte la dirección del flujo y deja el cambio sin revisar.

Confirma si es el primer caso."
        fi
        ;;
    esac
    ;;
esac

# 1b. La doctrina de docs/ la sustituye el kit al actualizarse: editarla por proyecto
#     significa perder el cambio en la siguiente actualización.
case "$FILE" in
  */docs/base-standards.md|docs/base-standards.md|\
  */docs/documentation-standards.md|docs/documentation-standards.md|\
  */docs/openspec-tasks-mandatory-steps.md|docs/openspec-tasks-mandatory-steps.md)
    ask "Vas a editar doctrina del kit (${FILE}). El kit la sustituye al actualizarse, así que el cambio se perdería. Lo específico de este proyecto va en docs/project-context.md o en docs/backend-standards.md. Confirma solo si de verdad quieres divergir del kit."
    ;;
esac

# 2. Tests: crear uno nuevo es libre; modificar uno existente exige confirmación.
if under "$FILE" "$PATH_TESTS" && [[ -f "$FILE" ]]; then
  ask "Vas a MODIFICAR un test existente (${FILE}). Los tests son la especificación firmada del proyecto: confirma que este cambio es intencionado y no un atajo para poner la suite en verde."
fi

# 3. Migraciones ya versionadas en git.
if [[ -n "$PATH_MIGRATIONS" ]] && under "$FILE" "$PATH_MIGRATIONS" && [[ -f "$FILE" ]]; then
  if git -C "$PROJECT_DIR" ls-files --error-unmatch "$FILE" >/dev/null 2>&1; then
    ask "Estás modificando una migración ya versionada (${FILE}). Lo correcto es crear una migración nueva. Confirma si realmente quieres editarla."
  fi
fi

# 4. Entorno y secretos.
case "$FILE" in
  *.env|*.env.*|*/.env|.env)
    deny "No se editan ficheros de entorno desde el agente: ${FILE}" ;;
  */.claude/sdd-harness.env)
    ask "Vas a modificar la configuración del SDD Harness Kit. Confirma el cambio." ;;
esac

exit 0
