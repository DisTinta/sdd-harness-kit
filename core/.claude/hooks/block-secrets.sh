#!/usr/bin/env bash
# UserPromptSubmit — impide que una credencial entre en el contexto del modelo.
# Requisito transversal: nunca secretos ni PII en el contexto del agente.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT=$(cat)
PROMPT=$(field "$INPUT" '.prompt')
[[ -n "$PROMPT" ]] || exit 0

PATTERNS='(sk-ant-[A-Za-z0-9_-]{20,}'
PATTERNS+='|sk-[a-zA-Z0-9]{40,}'
PATTERNS+='|ghp_[a-zA-Z0-9]{36}'
PATTERNS+='|github_pat_[A-Za-z0-9_]{50,}'
PATTERNS+='|gho_[a-zA-Z0-9]{36}'
PATTERNS+='|xox[baprs]-[A-Za-z0-9-]{10,}'
PATTERNS+='|AKIA[0-9A-Z]{16}'
PATTERNS+='|AIza[0-9A-Za-z_-]{35}'
PATTERNS+='|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
PATTERNS+='|-----BEGIN [A-Z ]*PRIVATE KEY-----'
PATTERNS+='|(APP_KEY|SECRET_KEY|DB_PASSWORD|API_SECRET)[[:space:]]*=[[:space:]]*[^[:space:]]{8,})'

if printf '%s' "$PROMPT" | grep -qE "$PATTERNS"; then
  block_prompt "Se ha detectado un posible token, clave privada o contraseña en el prompt. No compartas credenciales con el asistente: usa variables de entorno o un servidor MCP. Si es un falso positivo, reformula sin pegar el valor."
fi

exit 0
