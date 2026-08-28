#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# sync-artifacts.sh — reconstruye las referencias de .claude y .cursor a ai-specs.
#
# ai-specs/ es la fuente canónica. Este script intenta enlazar con symlinks y,
# si la plataforma no los permite (Windows sin modo desarrollador), copia.
#
#   bash .claude/sync-artifacts.sh            enlaza o copia lo que falte
#   bash .claude/sync-artifacts.sh --check    solo informa, no toca nada
#   bash .claude/sync-artifacts.sh --force    rehace las copias desactualizadas
#
# Entradas en .claude/.cursor que no están en ai-specs/:
#   KEEP     — skills nativas de OpenSpec (openspec-*), de `openspec init`. No borrar.
#   HUÉRFANO — cualquier otra. Deriva real; decide el humano.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

CHECK=0; FORCE=0
for a in "$@"; do
  case "$a" in
    --check) CHECK=1 ;;
    --force) FORCE=1 ;;
    *) echo "Opción desconocida: $a" >&2; exit 2 ;;
  esac
done

[[ -d ai-specs ]] || { echo "No existe ai-specs/: nada que sincronizar." >&2; exit 1; }

linked=0; copied=0; ok=0; conflicts=0; orphans=0; keep=0

is_os_junk() {
  case "$(basename "$1")" in
    [Dd][Ee][Ss][Kk][Tt][Oo][Pp].[Ii][Nn][Ii]|[Tt][Hh][Uu][Mm][Bb][Ss].[Dd][Bb]|.DS_Store|.ds_store) return 0 ;;
    *) return 1 ;;
  esac
}

strip_os_junk() {
  [[ -e "$1" ]] || return 0
  find "$1" -type f \( -iname 'desktop.ini' -o -iname 'Thumbs.db' -o -name '.DS_Store' \) -delete 2>/dev/null || true
}

# OpenSpec init escribe skills openspec-* en .claude/skills y .cursor/skills.
# openspec-implement del kit vive en ai-specs, así que no entra en esta rama.
is_expected_foreign() {
  local kind="$1" name="$2"
  [[ "$kind" == "skills" ]] || return 1
  case "$name" in
    openspec-*) return 0 ;;
  esac
  return 1
}

report() { printf '  %-8s %s\n' "$1" "$2"; }

sync_one() {
  local src="$1" dst="$2"
  # Ya es un symlink correcto
  if [[ -L "$dst" ]]; then
    if [[ -e "$dst" ]]; then ok=$((ok+1)); return; fi
    [[ $CHECK -eq 1 ]] && { report "ROTO" "$dst"; return; }
    rm -f "$dst"
  fi
  # Fichero de texto que en realidad era un symlink materializado (checkout Windows)
  if [[ -f "$dst" && ! -d "$src" ]] || { [[ -f "$dst" ]] && [[ -d "$src" ]]; }; then
    if [[ $(wc -c < "$dst" 2>/dev/null || echo 999) -lt 200 ]] && grep -qE '^\.\./' "$dst" 2>/dev/null; then
      [[ $CHECK -eq 1 ]] && { report "TEXTO" "$dst (symlink materializado)"; return; }
      rm -f "$dst"
    fi
  fi
  # Copia real ya existente
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    if diff -rq -x 'desktop.ini' -x 'Thumbs.db' -x '.DS_Store' "$src" "$dst" >/dev/null 2>&1; then ok=$((ok+1)); return; fi
    if [[ $FORCE -eq 0 ]]; then
      report "DIVERGE" "$dst — difiere de ai-specs. Usa --force para sobrescribir, o mueve tu cambio a ai-specs/"
      conflicts=$((conflicts+1)); return
    fi
    [[ $CHECK -eq 1 ]] && { report "STALE" "$dst"; return; }
    rm -rf "$dst"
  fi
  [[ $CHECK -eq 1 ]] && { report "FALTA" "$dst"; return; }
  mkdir -p "$(dirname "$dst")"
  # Ruta relativa desde el directorio del enlace hasta ai-specs
  local depth rel
  depth=$(printf '%s' "${dst%/*}" | tr -cd '/' | wc -c)
  rel=$(printf '../%.0s' $(seq 1 $((depth+1))))
  if ln -s "${rel}${src}" "$dst" 2>/dev/null; then
    linked=$((linked+1))
  else
    cp -r "$src" "$dst"
    strip_os_junk "$dst"
    copied=$((copied+1))
  fi
}

echo "Sincronizando artefactos de ai-specs/"
for tool in .claude .cursor; do
  for kind in skills agents; do
    [[ -d "ai-specs/$kind" ]] || continue
    mkdir -p "$tool/$kind"
    for entry in ai-specs/"$kind"/*; do
      [[ -e "$entry" ]] || continue
      is_os_junk "$entry" && continue
      sync_one "$entry" "$tool/$kind/$(basename "$entry")"
    done
    # Referencias cuyo origen no está en ai-specs: KEEP (OpenSpec) o HUÉRFANO
    for ref in "$tool/$kind"/*; do
      [[ -e "$ref" || -L "$ref" ]] || continue
      is_os_junk "$ref" && continue
      name="$(basename "$ref")"
      if [[ ! -e "ai-specs/$kind/$name" ]]; then
        if is_expected_foreign "$kind" "$name"; then
          report "KEEP" "$ref — skill nativa de OpenSpec (no vive en ai-specs/; no borrar)"
          keep=$((keep+1))
        else
          report "HUÉRFANO" "$ref — no existe en ai-specs/$kind/"
          orphans=$((orphans+1))
        fi
      fi
    done
  done
done

printf '\n  enlazados %d · copiados %d · correctos %d · divergentes %d · huérfanos %d · keep %d\n' \
  "$linked" "$copied" "$ok" "$conflicts" "$orphans" "$keep"

if [[ $copied -gt 0 ]]; then
  echo
  echo "  Esta plataforma no permite symlinks, así que se han hecho copias."
  echo "  Edita siempre ai-specs/ y vuelve a ejecutar este script para propagar."
fi
if [[ $keep -gt 0 ]]; then
  echo
  echo "  KEEP = skills nativas de OpenSpec (openspec init). No viven en ai-specs/. No las borres."
fi
[[ $conflicts -gt 0 || $orphans -gt 0 ]] && exit 1
exit 0
