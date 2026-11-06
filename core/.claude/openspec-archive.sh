#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# openspec-archive.sh — OpenSpec archive retention for the SDD Harness Kit.
#
# OpenSpec never prunes openspec/changes/archive/. This script keeps it bounded:
#   · INDEX.md   one row per archived change (folder, title, capabilities, commit, tag)
#   · deltas     archive commit WITH deltas first; prune archive/<change>/specs/ later
#   · folders    remove old archived folders behind an annotated snapshot tag
#
# Usage (from anywhere inside the repo; on Windows prefer
#   node .claude/hooks/invoke.cjs .claude/openspec-archive.sh <subcommand> …):
#   archive <change> [--dry-run]           openspec archive -y + post-archive
#   post-archive <folder> [--dry-run]      after /opsx:archive: index → archive commit → prune
#   index [--dry-run]                      rebuild/backfill INDEX.md (writes file, no commit)
#   prune-deltas [--dry-run] [--only F]    prune deltas already on the default branch
#   prune-folders [--apply] [--only F]     threshold folder prune (dry run unless --apply)
#   config                                 print the effective configuration
#
# Safety: never pushes, never amends/rebases/squashes/force-pushes, never uses --no-verify.
# Nothing is pruned unless the commit holding the content was verifiably created.
# Exit codes: 0 ok · 1 usage · 2 refused (preflight/config) · 3 commit failed (nothing pruned)
# Configuration: KIT_ARCHIVE_* in .claude/sdd-harness.env (see docs/en/CONFIG.en.md).
# Portable to bash 3.2 (macOS), Git Bash and Linux: no associative arrays, no mapfile.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROG="openspec-archive"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf '%s: not inside a Git work tree\n' "$PROG" >&2
  exit 2
}
cd "$ROOT" || exit 2
export CLAUDE_PROJECT_DIR="$ROOT"

# Defaults (lib.sh repeats them so hooks see the same values).
KIT_ARCHIVE_INDEX="1"
KIT_ARCHIVE_PRUNE_DELTAS="deferred"
KIT_ARCHIVE_PRUNE_FOLDERS="0"
KIT_ARCHIVE_KEEP="50"
KIT_ARCHIVE_MAX_AGE_DAYS="180"
KIT_ARCHIVE_DEFAULT_BRANCH=""
# shellcheck source=hooks/lib.sh
source "$SCRIPT_DIR/hooks/lib.sh"

CHANGES_REL="openspec/changes"
ARCHIVE_REL="$CHANGES_REL/archive"
INDEX_REL="$ARCHIVE_REL/INDEX.md"

say()  { printf '%s\n' "$*"; }
warn() { printf '%s: WARNING: %s\n' "$PROG" "$*" >&2; }
fail() { local code="$1"; shift; printf '%s: %s\n' "$PROG" "$*" >&2; exit "$code"; }

# ── Configuration ────────────────────────────────────────────────────────────
is_pos_int() { [[ "$1" =~ ^[1-9][0-9]*$ ]]; }

resolve_config() {
  case "$KIT_ARCHIVE_INDEX" in
    0|1) ;;
    *) warn "invalid KIT_ARCHIVE_INDEX=\"$KIT_ARCHIVE_INDEX\" (expected 0|1); using 0"; KIT_ARCHIVE_INDEX="0" ;;
  esac
  case "$KIT_ARCHIVE_PRUNE_DELTAS" in
    deferred|immediate|off) ;;
    *) warn "invalid KIT_ARCHIVE_PRUNE_DELTAS=\"$KIT_ARCHIVE_PRUNE_DELTAS\" (expected deferred|immediate|off); using off"
       KIT_ARCHIVE_PRUNE_DELTAS="off" ;;
  esac
  case "$KIT_ARCHIVE_PRUNE_FOLDERS" in
    0|1) ;;
    *) warn "invalid KIT_ARCHIVE_PRUNE_FOLDERS=\"$KIT_ARCHIVE_PRUNE_FOLDERS\" (expected 0|1); using 0"
       KIT_ARCHIVE_PRUNE_FOLDERS="0" ;;
  esac
  if ! is_pos_int "$KIT_ARCHIVE_KEEP"; then
    warn "invalid KIT_ARCHIVE_KEEP=\"$KIT_ARCHIVE_KEEP\" (expected a positive integer); folder pruning disabled"
    KIT_ARCHIVE_KEEP="50"; KIT_ARCHIVE_PRUNE_FOLDERS="0"; FOLDER_THRESHOLDS_OK=0
  fi
  if ! is_pos_int "$KIT_ARCHIVE_MAX_AGE_DAYS"; then
    warn "invalid KIT_ARCHIVE_MAX_AGE_DAYS=\"$KIT_ARCHIVE_MAX_AGE_DAYS\" (expected a positive integer); folder pruning disabled"
    KIT_ARCHIVE_MAX_AGE_DAYS="180"; KIT_ARCHIVE_PRUNE_FOLDERS="0"; FOLDER_THRESHOLDS_OK=0
  fi
  DEFAULT_REF="$KIT_ARCHIVE_DEFAULT_BRANCH"
  if [[ -z "$DEFAULT_REF" ]]; then
    DEFAULT_REF="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    [[ -n "$DEFAULT_REF" ]] || DEFAULT_REF="main"
  fi
}
FOLDER_THRESHOLDS_OK=1
resolve_config

# ── Git helpers ──────────────────────────────────────────────────────────────
head_rev() { git rev-parse -q --verify HEAD 2>/dev/null || true; }
short_rev() { git rev-parse --short "$1" 2>/dev/null || true; }

commit_scope() {
  local branch
  branch="$(git branch --show-current 2>/dev/null || true)"
  if [[ "$branch" =~ ([A-Z][A-Z0-9]+-[0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    printf 'openspec'
  fi
}

# Prints paths with uncommitted changes that are NOT allowed by the predicate "$1".
dirty_paths_outside() {
  local allow="$1" entry status path orig
  while IFS= read -r -d '' entry; do
    status="${entry:0:2}"; path="${entry:3}"
    if [[ "$status" == R* || "$status" == C* ]]; then
      IFS= read -r -d '' orig || true
      "$allow" "$orig" || printf '%s\n' "$orig"
    fi
    "$allow" "$path" || printf '%s\n' "$path"
  done < <(git status --porcelain -z -uall 2>/dev/null)
}
allow_openspec() { [[ "$1" == openspec/* ]]; }
allow_index()    { [[ "$1" == "$INDEX_REL" ]]; }

# Refuses (exit 2) on detached HEAD, operations in progress or unrelated changes.
preflight() {
  local allow="$1" gitdir bad
  git symbolic-ref -q HEAD >/dev/null || fail 2 "refusing: detached HEAD. Check out a branch first; nothing was committed or pruned."
  gitdir="$(git rev-parse --git-dir)"
  local f
  for f in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
    [[ -e "$gitdir/$f" ]] && fail 2 "refusing: a merge/rebase/cherry-pick is in progress ($f). Nothing was committed or pruned."
  done
  bad="$(dirty_paths_outside "$allow")"
  if [[ -n "$bad" ]]; then
    printf '%s: refusing: uncommitted changes unrelated to this operation:\n' "$PROG" >&2
    printf '%s\n' "$bad" | sed 's/^/  /' >&2
    fail 2 "commit or stash them first. Nothing was committed or pruned."
  fi
}

# Commits the staged index with message "$1" (and optional body "$2").
# Prints the new short hash; returns 1 if no new commit was created.
commit_or_fail() {
  local subject="$1" body="${2:-}" before after
  before="$(head_rev)"
  if [[ -n "$body" ]]; then
    git commit -q -m "$subject" -m "$body" >&2 || true
  else
    git commit -q -m "$subject" >&2 || true
  fi
  after="$(head_rev)"
  [[ -n "$after" && "$after" != "$before" ]] || return 1
  short_rev "$after"
}

# ── Archived folders ─────────────────────────────────────────────────────────
# Lists archived change folders (names only), sorted ascending.
list_folders() {
  local d
  [[ -d "$ARCHIVE_REL" ]] || return 0
  for d in "$ARCHIVE_REL"/*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"; printf '%s\n' "${d##*/}"
  done | LC_ALL=C sort
}

strip_cr() { tr -d '\r'; }

md_escape() { local s="$1"; s="${s//|/\\|}"; printf '%s' "$s"; }

# Title: first H1 that is not "Why"; else first sentence of the Why section
# (≤100 chars); else the folder name without its date prefix.
folder_title() {
  local folder="$1" p="$ARCHIVE_REL/$1/proposal.md" t=""
  if [[ -f "$p" ]]; then
    t="$(strip_cr < "$p" | awk '
      /^# / { h=$0; sub(/^# +/, "", h); if (tolower(h) != "why") { print h; exit } }')"
    if [[ -z "$t" ]]; then
      t="$(strip_cr < "$p" | awk '
        /^##? +[Ww]hy[[:space:]]*$/ { inwhy=1; next }
        inwhy && /^#/ { exit }
        inwhy && NF { print; exit }')"
      t="${t%%. *}"; t="${t%.}"
      if (( ${#t} > 100 )); then t="${t:0:97}..."; fi
    fi
  fi
  [[ -n "$t" ]] || t="$(printf '%s' "$folder" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')"
  md_escape "$t"
}

# Capabilities: spec.md paths under specs/, relative, comma-separated; "—" if none.
folder_caps() {
  local dir="$ARCHIVE_REL/$1/specs" caps
  [[ -d "$dir" ]] || { printf '—'; return; }
  caps="$(cd "$dir" && find . -name spec.md -type f | sed -e 's#^\./##' -e 's#/spec\.md$##' | LC_ALL=C sort | paste -sd ',' - | sed 's/,/, /g')"
  [[ -n "$caps" ]] && printf '%s' "$caps" || printf '—'
}

# ── INDEX.md ─────────────────────────────────────────────────────────────────
# Rows are kept in parallel arrays R_F (folder) R_T R_C R_A (archive commit) R_S (snapshot tag).
R_F=(); R_T=(); R_C=(); R_A=(); R_S=()

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

row_index() { # prints index of folder $1 in R_F, or nothing
  local i
  for (( i = 0; i < ${#R_F[@]}; i++ )); do
    [[ "${R_F[$i]}" == "$1" ]] && { printf '%s' "$i"; return; }
  done
}

index_load() {
  R_F=(); R_T=(); R_C=(); R_A=(); R_S=()
  [[ -f "$INDEX_REL" ]] || return 0
  local line f t c a s rest
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" == "| "* ]] || continue
    [[ "$line" == "| Folder |"* || "$line" == "|---"* ]] && continue
    line="${line//\\|/$'\001'}"
    IFS='|' read -r _ f t c a s rest <<< "$line"
    f="$(trim "$f")"; [[ -n "$f" ]] || continue
    t="$(trim "$t")"; t="${t//$'\001'/\\|}"
    R_F+=("$f"); R_T+=("$t"); R_C+=("$(trim "$c")"); R_A+=("$(trim "$a")"); R_S+=("$(trim "$s")")
  done < "$INDEX_REL"
}

# Adds rows for archived folders missing from the index (derived from proposal/specs).
index_backfill() {
  local folder
  while IFS= read -r folder; do
    [[ -n "$folder" ]] || continue
    [[ -n "$(row_index "$folder")" ]] && continue
    R_F+=("$folder"); R_T+=("$(folder_title "$folder")"); R_C+=("$(folder_caps "$folder")")
    R_A+=("pending"); R_S+=("—")
  done < <(list_folders)
}

index_set() { # folder column(A|S) value
  local i; i="$(row_index "$1")"
  [[ -n "$i" ]] || return 0
  case "$2" in
    A) R_A[$i]="$3" ;;
    S) R_S[$i]="$3" ;;
  esac
}

index_render() {
  local i
  printf '# Archived OpenSpec changes\n\n'
  printf '<!-- Generated by .claude/openspec-archive.sh (SDD Harness Kit). One row per archived change.\n'
  printf '     Read this file instead of the archived folders. Recover pruned content with\n'
  printf '     `git show <archive-commit-or-snapshot-tag>:openspec/changes/archive/<folder>/<file>`. -->\n\n'
  printf '| Folder | Title | Capabilities | Archive commit | Snapshot tag |\n'
  printf '|---|---|---|---|---|\n'
  for (( i = 0; i < ${#R_F[@]}; i++ )); do
    printf '| %s | %s | %s | %s | %s |\n' "${R_F[$i]}" "${R_T[$i]}" "${R_C[$i]}" "${R_A[$i]}" "${R_S[$i]}"
  done | LC_ALL=C sort
}

# Writes INDEX.md only if bytes differ. Returns 0 if changed, 1 if unchanged.
index_write() {
  local tmp; tmp="$(mktemp)"
  index_render > "$tmp"
  if [[ -f "$INDEX_REL" ]] && cmp -s "$tmp" "$INDEX_REL"; then
    rm -f "$tmp"; return 1
  fi
  mkdir -p "$ARCHIVE_REL"
  cat "$tmp" > "$INDEX_REL"; rm -f "$tmp"
  return 0
}

# ── Subcommand: index ────────────────────────────────────────────────────────
cmd_index() {
  local dry="$1"
  if [[ "$KIT_ARCHIVE_INDEX" != "1" ]]; then
    say "INDEX.md disabled (KIT_ARCHIVE_INDEX=$KIT_ARCHIVE_INDEX); nothing to do."
    return 0
  fi
  index_load; index_backfill
  if [[ "$dry" == "1" ]]; then
    local tmp; tmp="$(mktemp)"; index_render > "$tmp"
    if [[ -f "$INDEX_REL" ]] && cmp -s "$tmp" "$INDEX_REL"; then
      say "dry-run: $INDEX_REL is up to date."
    else
      say "dry-run: would write $INDEX_REL with ${#R_F[@]} row(s):"; cat "$tmp"
    fi
    rm -f "$tmp"; return 0
  fi
  if index_write; then say "updated $INDEX_REL (${#R_F[@]} row(s))."; else say "$INDEX_REL is up to date."; fi
}

# ── Delta pruning ────────────────────────────────────────────────────────────
ELIGIBLE=(); PROOF=()

# Fills ELIGIBLE/PROOF with folders whose specs/ is on the default branch and still in HEAD.
find_eligible_deltas() {
  local only="$1" folder path proof
  ELIGIBLE=(); PROOF=()
  if ! git rev-parse -q --verify "$DEFAULT_REF^{commit}" >/dev/null 2>&1; then
    say "default branch ref '$DEFAULT_REF' not found (set KIT_ARCHIVE_DEFAULT_BRANCH or git fetch); no deltas are eligible."
    return 0
  fi
  while IFS= read -r folder; do
    [[ -n "$folder" ]] || continue
    [[ -z "$only" || "$folder" == "$only" ]] || continue
    path="$ARCHIVE_REL/$folder/specs"
    [[ -d "$path" ]] || continue
    if ! git cat-file -e "HEAD:$path" 2>/dev/null; then
      say "skip: $folder (deltas not committed yet)"; continue
    fi
    if ! git cat-file -e "$DEFAULT_REF:$path" 2>/dev/null; then
      say "skip: $folder (deltas not on default branch $DEFAULT_REF yet)"; continue
    fi
    proof="$(git log --diff-filter=A --format=%h --reverse "$DEFAULT_REF" -- "$path" 2>/dev/null | head -n 1)"
    [[ -n "$proof" ]] || proof="$(git log -1 --format=%h "$DEFAULT_REF" -- "$path" 2>/dev/null)"
    ELIGIBLE+=("$folder"); PROOF+=("$proof")
  done < <(list_folders)
}

# Removes specs/ of ELIGIBLE folders in one commit. Restores everything on failure.
prune_eligible_deltas() {
  local i paths=() hash
  for (( i = 0; i < ${#ELIGIBLE[@]}; i++ )); do paths+=("$ARCHIVE_REL/${ELIGIBLE[$i]}/specs"); done
  git rm -r -q -- "${paths[@]}" || { git checkout -q HEAD -- "${paths[@]}" 2>/dev/null; fail 3 "git rm failed; nothing pruned."; }
  if [[ "$KIT_ARCHIVE_INDEX" == "1" ]]; then
    index_load; index_backfill
    for (( i = 0; i < ${#ELIGIBLE[@]}; i++ )); do index_set "${ELIGIBLE[$i]}" A "${PROOF[$i]}"; done
    index_write || true
    git add -- "$INDEX_REL"
  fi
  local body="Delta specs are kept in Git history; recover with git show <commit>:<path>."
  for (( i = 0; i < ${#ELIGIBLE[@]}; i++ )); do body+=$'\n'"- ${ELIGIBLE[$i]} (deltas in ${PROOF[$i]})"; done
  if ! hash="$(commit_or_fail "chore($(commit_scope)): prune archived OpenSpec deltas" "$body")"; then
    git reset -q HEAD -- "${paths[@]}" "$INDEX_REL" 2>/dev/null
    git checkout -q HEAD -- "${paths[@]}" 2>/dev/null
    [[ -n "$(git ls-files -- "$INDEX_REL")" ]] && git checkout -q HEAD -- "$INDEX_REL" 2>/dev/null
    fail 3 "prune commit was not created (commit hook failed?); deltas restored, nothing pruned."
  fi
  say "pruned deltas of ${#ELIGIBLE[@]} archived change(s) in commit $hash."
}

cmd_prune_deltas() {
  local dry="$1" only="$2" i
  if [[ "$KIT_ARCHIVE_PRUNE_DELTAS" == "off" ]]; then
    say "delta pruning is off (KIT_ARCHIVE_PRUNE_DELTAS=off); nothing to do."
    return 0
  fi
  find_eligible_deltas "$only"
  if (( ${#ELIGIBLE[@]} == 0 )); then say "nothing to prune."; return 0; fi
  if [[ "$dry" == "1" ]]; then
    for (( i = 0; i < ${#ELIGIBLE[@]}; i++ )); do
      say "dry-run: would remove $ARCHIVE_REL/${ELIGIBLE[$i]}/specs (on $DEFAULT_REF since ${PROOF[$i]})"
    done
    say "dry-run: would create one commit 'chore($(commit_scope)): prune archived OpenSpec deltas'."
    return 0
  fi
  preflight allow_index
  prune_eligible_deltas
}

# ── Folder pruning ───────────────────────────────────────────────────────────
to_epoch() { # YYYY-MM-DD → epoch seconds (GNU date, then BSD date)
  date -d "$1" +%s 2>/dev/null || date -j -f %Y-%m-%d "$1" +%s 2>/dev/null || true
}

FOLDERS_ELIGIBLE=()
find_eligible_folders() {
  local only="$1" dated=() folder n i now cutoff e d
  FOLDERS_ELIGIBLE=()
  while IFS= read -r folder; do
    [[ "$folder" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}- ]] && dated+=("$folder")
  done < <(list_folders)
  n=${#dated[@]}
  (( n > KIT_ARCHIVE_KEEP )) || return 0
  now="$(date +%s)"; cutoff=$(( now - KIT_ARCHIVE_MAX_AGE_DAYS * 86400 ))
  for (( i = 0; i < n - KIT_ARCHIVE_KEEP; i++ )); do   # ascending: oldest first, newest KEEP excluded
    folder="${dated[$i]}"
    [[ -z "$only" || "$folder" == "$only" ]] || continue
    d="${folder:0:10}"; e="$(to_epoch "$d")"
    [[ -n "$e" ]] || continue
    (( e < cutoff )) || continue
    if ! git cat-file -e "HEAD:$ARCHIVE_REL/$folder" 2>/dev/null; then
      say "skip: $folder (not committed; commit it before pruning)"; continue
    fi
    FOLDERS_ELIGIBLE+=("$folder")
  done
}

snapshot_tag_name() {
  local base n=1 name head
  base="openspec-archive-snapshot-$(date +%Y-%m)"; name="$base"; head="$(head_rev)"
  while git rev-parse -q --verify "refs/tags/$name" >/dev/null 2>&1; do
    [[ "$(git rev-parse "$name^{commit}")" == "$head" ]] && { printf '%s' "$name"; return; }
    n=$(( n + 1 )); name="$base-$n"
  done
  printf '%s' "$name"
}

local_tag_warning() {
  local tag="$1" remote
  remote="$(git remote 2>/dev/null | grep -qx origin && echo origin || git remote 2>/dev/null | head -n 1)"
  say ""
  say "┌──────────────────────────────────────────────────────────────────────────┐"
  say "│ WARNING: tag $tag is LOCAL ONLY."
  say "│ It protects nobody else until it is published. Nothing was pushed."
  if [[ -n "$remote" ]]; then
    say "│ To publish it (after review):  git push $remote $tag"
  else
    say "│ No remote configured; add one and push the tag to share the snapshot."
  fi
  say "└──────────────────────────────────────────────────────────────────────────┘"
}

cmd_prune_folders() {
  local apply="$1" only="$2" i tag hash paths=()
  find_eligible_folders "$only"
  if [[ "$apply" != "1" ]]; then
    say "dry-run (default; pass --apply to delete). Thresholds: keep newest $KIT_ARCHIVE_KEEP, older than $KIT_ARCHIVE_MAX_AGE_DAYS days."
    [[ "$KIT_ARCHIVE_PRUNE_FOLDERS" == "1" ]] || say "note: folder pruning is disabled (KIT_ARCHIVE_PRUNE_FOLDERS=$KIT_ARCHIVE_PRUNE_FOLDERS); --apply will refuse."
    if (( ${#FOLDERS_ELIGIBLE[@]} == 0 )); then say "nothing to prune."; return 0; fi
    for (( i = 0; i < ${#FOLDERS_ELIGIBLE[@]}; i++ )); do say "eligible: ${FOLDERS_ELIGIBLE[$i]}"; done
    say "would create annotated tag $(snapshot_tag_name) on HEAD, then remove ${#FOLDERS_ELIGIBLE[@]} folder(s) in one commit."
    return 0
  fi
  [[ "$KIT_ARCHIVE_PRUNE_FOLDERS" == "1" ]] || fail 2 "folder pruning is disabled: set KIT_ARCHIVE_PRUNE_FOLDERS=\"1\" in .claude/sdd-harness.env. Nothing changed."
  if (( ${#FOLDERS_ELIGIBLE[@]} == 0 )); then say "nothing to prune."; return 0; fi
  preflight allow_index
  # INDEX.md is the recovery record: make sure rows exist before anything is removed.
  index_load; index_backfill
  tag="$(snapshot_tag_name)"
  if ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
    git tag -a "$tag" -m "OpenSpec archive snapshot before pruning ${#FOLDERS_ELIGIBLE[@]} archived change folder(s)" \
      || fail 3 "could not create tag $tag; nothing pruned."
    say "created annotated tag $tag on $(short_rev HEAD)."
  else
    say "reusing tag $tag (already on HEAD)."
  fi
  for (( i = 0; i < ${#FOLDERS_ELIGIBLE[@]}; i++ )); do
    paths+=("$ARCHIVE_REL/${FOLDERS_ELIGIBLE[$i]}")
    index_set "${FOLDERS_ELIGIBLE[$i]}" S "$tag"
  done
  git rm -r -q -- "${paths[@]}" || { git checkout -q HEAD -- "${paths[@]}" 2>/dev/null; fail 3 "git rm failed; nothing pruned."; }
  index_write || true
  git add -- "$INDEX_REL"
  local body="Snapshot tag: $tag. Recover with git show $tag:<path>."
  for (( i = 0; i < ${#FOLDERS_ELIGIBLE[@]}; i++ )); do body+=$'\n'"- ${FOLDERS_ELIGIBLE[$i]}"; done
  if ! hash="$(commit_or_fail "chore($(commit_scope)): prune archived OpenSpec folders" "$body")"; then
    git reset -q HEAD -- "${paths[@]}" "$INDEX_REL" 2>/dev/null
    git checkout -q HEAD -- "${paths[@]}" 2>/dev/null
    [[ -n "$(git ls-files -- "$INDEX_REL")" ]] && git checkout -q HEAD -- "$INDEX_REL" 2>/dev/null
    fail 3 "prune commit was not created; folders restored. Tag $tag was kept (it only points at HEAD)."
  fi
  say "removed ${#FOLDERS_ELIGIBLE[@]} archived folder(s) in commit $hash."
  local_tag_warning "$tag"
}

folder_notice() {
  local saved_only=""
  find_eligible_folders "$saved_only"
  (( ${#FOLDERS_ELIGIBLE[@]} > 0 )) || return 0
  say "notice: ${#FOLDERS_ELIGIBLE[@]} archived folder(s) exceed the retention thresholds. Review with:"
  say "  bash .claude/openspec-archive.sh prune-folders   (dry run; --apply to delete; needs KIT_ARCHIVE_PRUNE_FOLDERS=\"1\")"
}

# ── Subcommands: post-archive / archive ──────────────────────────────────────
dated_name() { # change → folder name used by openspec archive
  if [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}- ]]; then printf '%s' "$1"; else printf '%s-%s' "$(date +%F)" "$1"; fi
}

cmd_post_archive() {
  local folder="$1" dry="$2" dir hash name
  dir="$ARCHIVE_REL/$folder"
  [[ -n "$folder" && -d "$dir" ]] || fail 1 "archived folder not found: $dir"
  name="$(printf '%s' "$folder" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')"

  if [[ "$dry" == "1" ]]; then
    say "dry-run: would update $INDEX_REL (KIT_ARCHIVE_INDEX=$KIT_ARCHIVE_INDEX)."
    say "dry-run: would commit openspec/ as 'chore($(commit_scope)): archive OpenSpec change $name' (deltas included)."
    case "$KIT_ARCHIVE_PRUNE_DELTAS" in
      immediate) say "dry-run: would then remove $dir/specs in a separate commit (immediate mode)." ;;
      deferred)  say "dry-run: would then prune deltas already on $DEFAULT_REF (deferred mode):"; cmd_prune_deltas 1 "" ;;
      off)       say "dry-run: delta pruning off." ;;
    esac
    return 0
  fi

  preflight allow_openspec
  if [[ "$KIT_ARCHIVE_INDEX" == "1" ]]; then
    index_load; index_backfill; index_write || true
  fi
  git add -A -- openspec/ || fail 3 "git add failed; nothing committed or pruned."
  if git diff --cached --quiet -- openspec/; then
    if git cat-file -e "HEAD:$dir" 2>/dev/null; then
      hash="$(git log -1 --format=%h -- "$dir")"
      say "archive of $folder already committed in $hash."
    else
      fail 3 "nothing to commit for $dir; nothing pruned."
    fi
  else
    if ! hash="$(commit_or_fail "chore($(commit_scope)): archive OpenSpec change $name")"; then
      warn "archive commit was NOT created (see the git output above: hook failure, conflict…)."
      warn "$dir keeps its delta specs; nothing was pruned. Fix the cause and commit, then re-run post-archive $folder."
      exit 3
    fi
    say "archive commit $hash (includes $dir/specs and updated openspec/specs)."
  fi

  case "$KIT_ARCHIVE_PRUNE_DELTAS" in
    immediate)
      if [[ -d "$dir/specs" ]] && git cat-file -e "HEAD:$dir/specs" 2>/dev/null; then
        ELIGIBLE=("$folder"); PROOF=("$hash")
        say "immediate mode: deltas pruned in a separate commit. Use only with merge-commit or rebase merges; a squash merge would drop the deltas from the default branch history."
        prune_eligible_deltas
      fi ;;
    deferred)
      find_eligible_deltas ""
      if (( ${#ELIGIBLE[@]} > 0 )); then preflight allow_index; prune_eligible_deltas; fi
      say "deferred mode: deltas of $folder are pruned by a later run once they are on $DEFAULT_REF." ;;
    off) ;;
  esac
  folder_notice
}

cmd_archive() {
  local change="$1" dry="$2" out folder
  [[ -n "$change" ]] || fail 1 "usage: archive <change> [--dry-run]"
  [[ -d "$CHANGES_REL/$change" ]] || fail 1 "active change not found: $CHANGES_REL/$change"
  command -v openspec >/dev/null 2>&1 || fail 2 "openspec CLI not found in PATH."
  if [[ "$dry" == "1" ]]; then
    folder="$(dated_name "$change")"
    say "dry-run: would run: openspec archive -y --json $change  →  $ARCHIVE_REL/$folder"
    say "dry-run: then post-archive $folder:"
    say "dry-run: would update $INDEX_REL (KIT_ARCHIVE_INDEX=$KIT_ARCHIVE_INDEX)."
    say "dry-run: would commit openspec/ as 'chore($(commit_scope)): archive OpenSpec change $change' (deltas included)."
    say "dry-run: delta prune mode: $KIT_ARCHIVE_PRUNE_DELTAS."
    return 0
  fi
  preflight allow_openspec
  out="$(openspec archive -y --json "$change" 2>&1)" || { printf '%s\n' "$out" >&2; fail 3 "openspec archive failed; nothing committed or pruned."; }
  folder="$(printf '%s' "$out" | tr -d '\r' | sed -n 's/.*"archivedAs"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  [[ -n "$folder" ]] || folder="$(dated_name "$change")"
  say "archived $change → $ARCHIVE_REL/$folder"
  cmd_post_archive "$folder" 0
}

cmd_config() {
  say "KIT_ARCHIVE_INDEX=$KIT_ARCHIVE_INDEX"
  say "KIT_ARCHIVE_PRUNE_DELTAS=$KIT_ARCHIVE_PRUNE_DELTAS"
  say "KIT_ARCHIVE_PRUNE_FOLDERS=$KIT_ARCHIVE_PRUNE_FOLDERS"
  say "KIT_ARCHIVE_KEEP=$KIT_ARCHIVE_KEEP"
  say "KIT_ARCHIVE_MAX_AGE_DAYS=$KIT_ARCHIVE_MAX_AGE_DAYS"
  say "KIT_ARCHIVE_DEFAULT_BRANCH=$DEFAULT_REF"
}

usage() { sed -n '9,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

# ── Main ─────────────────────────────────────────────────────────────────────
SUB="${1:-}"; shift || true
DRY=0; APPLY=0; ONLY=""; ARG=""
while (( $# > 0 )); do
  case "$1" in
    --dry-run) DRY=1 ;;
    --apply)   APPLY=1 ;;
    --only)    shift; ONLY="${1:-}"; [[ -n "$ONLY" ]] || fail 1 "--only needs a folder name" ;;
    -h|--help) usage; exit 0 ;;
    -*)        fail 1 "unknown option: $1" ;;
    *)         [[ -z "$ARG" ]] || fail 1 "unexpected argument: $1"; ARG="$1" ;;
  esac
  shift
done

case "$SUB" in
  archive)       cmd_archive "$ARG" "$DRY" ;;
  post-archive)  cmd_post_archive "$ARG" "$DRY" ;;
  index)         cmd_index "$DRY" ;;
  prune-deltas)  cmd_prune_deltas "$DRY" "$ONLY" ;;
  prune-folders) (( DRY == 1 )) && APPLY=0; cmd_prune_folders "$APPLY" "$ONLY" ;;
  config)        cmd_config ;;
  ""|-h|--help|help) usage ;;
  *)             usage >&2; fail 1 "unknown subcommand: $SUB" ;;
esac
