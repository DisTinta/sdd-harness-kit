#!/usr/bin/env bash
# SessionStart — inyecta el estado real del repositorio al arrancar la sesión.
# Evita que el agente pregunte lo que puede leer, y que lo suponga si no pregunta.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INPUT=$(cat)
SOURCE=$(field "$INPUT" '.source')
[[ "$SOURCE" == "startup" || "$SOURCE" == "resume" ]] || exit 0

BRANCH=$(git branch --show-current 2>/dev/null || echo "desconocida")
LAST_COMMIT=$(git log -1 --oneline 2>/dev/null || echo "sin commits")
DIRTY=$(git status --short 2>/dev/null | wc -l | tr -d ' ')

ACTIVE_CHANGES="ninguno"
PENDING_TASKS="0"
if [[ -d "$PROJECT_DIR/openspec/changes" ]]; then
  FOUND=$(find "$PROJECT_DIR/openspec/changes" -maxdepth 1 -mindepth 1 -type d \
    -not -name archive 2>/dev/null | sed 's#.*/##' | paste -sd ', ' - || true)
  [[ -n "$FOUND" ]] && ACTIVE_CHANGES="$FOUND"
  PENDING_TASKS=$(grep -rh '^- \[ \]' "$PROJECT_DIR/openspec/changes" \
    --include='tasks.md' 2>/dev/null | wc -l | tr -d ' ')
fi

CONTEXT="Estado del repositorio
- Stack configurado: ${STACK}
- Branch: ${BRANCH} (prefijo esperado: ${BRANCH_PREFIX})
- Último commit: ${LAST_COMMIT}
- Ficheros modificados sin commitear: ${DIRTY}
- Changes OpenSpec activos: ${ACTIVE_CHANGES}
- Tasks pendientes en changes activos: ${PENDING_TASKS}

Comandos del proyecto
- Tests: ${CMD_TEST:-no configurado}
- Lint: ${CMD_LINT:-no configurado}
- Análisis estático: ${CMD_STATIC:-no configurado}

Contexto de proyecto (léelo; no inventes)
- docs/project-context.md — gotchas, comandos reales, convenciones
- docs/backend-standards.md / docs/frontend-standards.md — capas del stack
- .claude/sdd-harness.env — contrato de comandos y rutas (BRANCH_PREFIX, PATH_*)

Recordatorios de flujo
- TDD: el test se escribe y se ve fallar antes de la implementación.
- Orden de capas: ${LAYER_ORDER:-consulta docs/backend-standards.md}.
- La lógica de negocio vive en ${PATH_BUSINESS:-la capa indicada en project-context}.
- OpenSpec: CREAR artefactos en propose/sync es normal. REESCRIBIR specs existentes
  para que encajen con un atajo de código está prohibido (regla 7 / protect-specs).
  Marcar tasks en tasks.md y escribir reports/ es siempre libre.
- Secretos: nunca pegues tokens ni leas .env al contexto. Usa /privacy-ethics-check
  si la unidad toca PII, auth o logging de datos personales.
- MCP: Context7 para docs de librerías (no esperes a que te digan «use context7»).
  Playwright MCP para demostrar una UI real en /show-spec-working. Si un servidor
  está desactivado, dilo y continúa."

inject "SessionStart" "$CONTEXT"
