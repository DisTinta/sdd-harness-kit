#!/usr/bin/env bash
# PreToolUse (Bash) — invariantes de seguridad que no se delegan a un prompt.
# Lo que vive en AGENTS.md lo interpreta el modelo; esto lo ejecuta código.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT=$(cat)
COMMAND=$(field "$INPUT" '.tool_input.command')
[[ -n "$COMMAND" ]] || exit 0

# 1. Borrados masivos y destrucción de dispositivos.
if printf '%s' "$COMMAND" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]*[rf][a-zA-Z]*[[:space:]]+)+|mkfs|dd[[:space:]]+if=|:\(\)\{.*\};:'; then
  deny "Comando destructivo bloqueado por política del repositorio: ${COMMAND}"
fi

# 2. Permisos abiertos de par en par.
if printf '%s' "$COMMAND" | grep -qE 'chmod[[:space:]]+(-R[[:space:]]+)?777'; then
  deny "chmod 777 bloqueado: abre el fichero a cualquier usuario del sistema."
fi

# 3. Reescritura de historia y push forzado.
if printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+push.*(--force([^-]|$)|-f([[:space:]]|$))'; then
  deny "git push --force está prohibido. El push forzado lo hace un humano o no se hace."
fi
if printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[a-z]*f|filter-branch)'; then
  ask "Este comando descarta trabajo local de forma irreversible. Confirma manualmente."
fi

# 4. Producción.
if printf '%s' "$COMMAND" | grep -qiE '(APP_ENV|NODE_ENV|RAILS_ENV)=production|--env[[:space:]]*=?[[:space:]]*prod(uction)?|kubectl[[:space:]].*(-n|--namespace)[[:space:]]*prod'; then
  deny "Operaciones contra producción desde el agente no están permitidas."
fi

# 5. Instalación de dependencias: se permite, pero avisando.
#    19,7 % de los paquetes que recomiendan los LLM no existen (slopsquatting).
if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])(npm|pnpm|yarn|bun)[[:space:]]+(i|add|install)[[:space:]]+[^-]|(^|[[:space:]])(composer|pip|pip3|gem|cargo|go)[[:space:]]+(require|install|add|get)[[:space:]]+[^-]'; then
  ask "Vas a instalar una dependencia. Verifica primero en el registro oficial que el paquete existe y es el correcto: es el vector del slopsquatting."
fi

# 6. Patrón adicional propio del stack, definido en sdd-harness.env.
if [[ -n "$GUARD_DANGEROUS_CMD" ]] && printf '%s' "$COMMAND" | grep -qE "$GUARD_DANGEROUS_CMD"; then
  ask "Este comando es destructivo para el stack de este proyecto (${STACK}). Confirma manualmente."
fi

exit 0
