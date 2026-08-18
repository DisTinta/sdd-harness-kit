#!/usr/bin/env bash
# doctor.sh — comprueba que el harness SDD Harness Kit está sano en el proyecto destino.
# Uso (desde la raíz del proyecto YA instalado):
#   bash .claude/../  → mejor: copiar/ejecutar desde el kit:
#   /ruta/al/kit/doctor.sh --dest .
#   ./doctor.sh                 # si estás en el proyecto y doctor está en PATH vía kit
set -euo pipefail

DEST="${1:-.}"
if [[ "${1:-}" == "--dest" ]]; then DEST="${2:?}"; fi
DEST="$(cd "$DEST" && pwd)"

C_OK=$'\033[0;32m'; C_WARN=$'\033[0;33m'; C_ERR=$'\033[0;31m'; C_OFF=$'\033[0m'
FAILS=0; WARNS=0
ok()   { printf '  %sOK%s  %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '  %sWARN%s %s\n' "$C_WARN" "$C_OFF" "$*"; WARNS=$((WARNS+1)); }
fail() { printf '  %sFAIL%s %s\n' "$C_ERR" "$C_OFF" "$*"; FAILS=$((FAILS+1)); }

printf '\nSDD Harness Kit doctor — %s\n\n' "$DEST"

# Doctrina y contexto
[[ -f "$DEST/docs/base-standards.md" ]] && ok "docs/base-standards.md" || fail "falta docs/base-standards.md"
[[ -f "$DEST/docs/project-context.md" ]] && ok "docs/project-context.md" || fail "falta docs/project-context.md"
if [[ -f "$DEST/docs/project-context.md" ]] && grep -q '{{' "$DEST/docs/project-context.md"; then
  warn "docs/project-context.md todavía tiene marcadores {{...}} sin completar"
fi
[[ -f "$DEST/.claude/sdd-harness.env" ]] && ok ".claude/sdd-harness.env" || fail "falta .claude/sdd-harness.env"

# Memoria multi-agente
for f in CLAUDE.md AGENTS.md; do
  if [[ -e "$DEST/$f" ]]; then ok "$f presente"
  else warn "falta $f (puntero a docs/base-standards.md)"; fi
done

# Skills / agents
[[ -d "$DEST/ai-specs/skills" ]] && ok "ai-specs/skills" || fail "falta ai-specs/skills"
[[ -d "$DEST/ai-specs/agents" ]] && ok "ai-specs/agents" || fail "falta ai-specs/agents"
SKILL_N=$(find "$DEST/ai-specs/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
ok "skills canónicas: $SKILL_N"

# Sync health: ¿.claude/skills es symlink o copia?
if [[ -L "$DEST/.claude/skills/enrich-us" ]] || [[ -L "$DEST/.claude/skills" ]]; then
  ok "sync: symlinks detectados en .claude/skills"
elif [[ -d "$DEST/.claude/skills" ]]; then
  warn "sync: modo COPIA (sin symlinks). Edita solo ai-specs/ y ejecuta sync-artifacts tras cambios"
else
  fail "falta .claude/skills — ejecuta bash .claude/sync-artifacts.sh"
fi

# Hooks
HOOKS=(session-context block-secrets block-secret-reads block-dangerous-bash docs-gate protect-specs-and-tests post-edit-quality validate-tasks verify-tests lib)
for h in "${HOOKS[@]}"; do
  if [[ -f "$DEST/.claude/hooks/${h}.sh" ]]; then ok "hook $h"
  else fail "falta hook ${h}.sh"; fi
done
[[ -f "$DEST/.claude/hooks/invoke.cjs" ]] && ok "hook invoke.cjs" || fail "falta hook invoke.cjs"
[[ -f "$DEST/.claude/settings.json" ]] && ok "settings.json" || fail "falta .claude/settings.json"
if [[ -f "$DEST/.claude/settings.json" ]] && grep -q 'block-secret-reads' "$DEST/.claude/settings.json"; then
  ok "settings registra block-secret-reads"
else
  warn "settings.json no referencia block-secret-reads (¿kit antiguo?)"
fi
if [[ -f "$DEST/.claude/settings.json" ]] && grep -q 'invoke.cjs' "$DEST/.claude/settings.json"; then
  ok "settings lanza hooks via invoke.cjs"
else
  warn "settings.json no usa invoke.cjs (en Windows bash puede ser WSL)"
fi

# Tooling
command -v jq >/dev/null && ok "jq instalado" || warn "jq NO instalado — los hooks se desactivan solos"
command -v bash >/dev/null && ok "bash disponible" || fail "bash no disponible"
command -v git >/dev/null && ok "git disponible" || warn "git no disponible"
command -v openspec >/dev/null && ok "openspec CLI" || warn "openspec no está en PATH (npm i -g @fission-ai/openspec)"

# OpenSpec
if [[ -d "$DEST/openspec" ]]; then ok "openspec/ presente"
else warn "openspec/ no inicializado — ejecuta: openspec init"; fi
if [[ -f "$DEST/openspec/config.yaml" ]] || [[ -f "$DEST/openspec/config.yml" ]]; then
  ok "openspec config presente"
else
  warn "falta openspec/config.yaml — usa ai-specs/templates/openspec/config.yaml.tpl como guía"
fi

# MCP (recomendado, no bloquea)
if [[ -f "$DEST/.mcp.json" ]]; then
  ok ".mcp.json (Claude Code)"
  grep -q '"context7"' "$DEST/.mcp.json" && ok "MCP context7 en .mcp.json" || warn ".mcp.json no declara context7"
  if grep -q '"playwright"' "$DEST/.mcp.json"; then
    ok "MCP playwright en .mcp.json"
  else
    warn "MCP playwright no está en .mcp.json (normal con --no-frontend)"
  fi
else
  warn "falta .mcp.json — el instalador del kit lo copia; sin él Context7/Playwright no cargan en Claude Code"
fi
if [[ -f "$DEST/.cursor/mcp.json" ]]; then
  ok ".cursor/mcp.json (Cursor)"
  grep -q '"context7"' "$DEST/.cursor/mcp.json" && ok "MCP context7 en .cursor/mcp.json" || warn ".cursor/mcp.json no declara context7"
else
  warn "falta .cursor/mcp.json — el instalador del kit lo copia; sin él Context7/Playwright no cargan en Cursor"
fi

# BRANCH_PREFIX
if [[ -f "$DEST/.claude/sdd-harness.env" ]]; then
  if grep -q '^BRANCH_PREFIX=' "$DEST/.claude/sdd-harness.env"; then ok "BRANCH_PREFIX definido"
  else warn "BRANCH_PREFIX no está en sdd-harness.env (validate-tasks no podrá exigirlo)"; fi
  if grep -qE '\$\(|`' "$DEST/.claude/sdd-harness.env"; then
    fail "sdd-harness.env contiene command substitution — el loader seguro la ignora; limpia el fichero"
  fi
fi

printf '\nResumen: %s fallos, %s avisos\n' "$FAILS" "$WARNS"
if [[ "$FAILS" -gt 0 ]]; then exit 1; fi
exit 0
