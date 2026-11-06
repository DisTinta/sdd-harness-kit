#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Tests for core/.claude/openspec-archive.sh (OpenSpec archive retention).
# Kit-repo only (not installed). Plain bash, no framework.
#
# Usage:  bash tests/openspec-archive.test.sh [name-filter]
# Needs:  git, openspec CLI (>= 1.9.0), jq (hygiene hook test). Each test runs in a fresh
#         temporary Git repo with the kit's .claude/ copied in, mimicking an installed project.
# One test function per scenario in openspec/changes/openspec-archive-retention/specs/.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILTER="${1:-}"
unset CLAUDE_PROJECT_DIR
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

command -v openspec >/dev/null 2>&1 || { echo "SKIP: openspec CLI not found in PATH"; exit 0; }

TODAY="$(date +%F)"
MONTH="$(date +%Y-%m)"
A="openspec/changes/archive"

# ── Helpers ──────────────────────────────────────────────────────────────────
fail_() { printf '    assertion failed: %s\n' "$*" >&2; exit 1; }   # exits the test's subshell
assert()        { "$@" || fail_ "$*"; }
assert_not()    { ! "$@" || fail_ "NOT $*"; }
assert_eq()     { [[ "$1" == "$2" ]] || fail_ "expected [$2] got [$1]"; }
assert_has()    { grep -qF -- "$2" <<< "$1" || fail_ "output lacks [$2]"; }
exists_at()     { git cat-file -e "$1:$2" 2>/dev/null; }
state()         { printf '%s\n%s\n%s\n' "$(git status --porcelain -uall)" "$(git rev-parse HEAD)" "$(git tag -l | sort)"; }

kit() { bash .claude/openspec-archive.sh "$@"; }

setenv() { # KEY=VALUE … → .claude/sdd-harness.env, committed
  printf '%s\n' "$@" > .claude/sdd-harness.env
  git add .claude/sdd-harness.env && git commit -qm "test: env"
}

new_repo() {
  local d; d="$(mktemp -d)"
  cd "$d" || exit 1
  git init -q -b main .
  git config commit.gpgsign false
  git config core.autocrlf false
  mkdir -p .claude/hooks
  cp "$KIT_DIR"/core/.claude/hooks/*.sh .claude/hooks/
  cp "$KIT_DIR"/core/.claude/openspec-archive.sh .claude/ 2>/dev/null || true
  openspec init --tools none --no-animation . >/dev/null 2>&1
  printf 'readme\n' > README.md
  git add -A && git commit -qm "init"
}

# make_change <name> [capability…]  — active change with proposal, tasks (all done) and deltas.
make_change() {
  local name="$1"; shift
  local c="openspec/changes/$name" cap
  mkdir -p "$c"
  printf 'schema: spec-driven\n' > "$c/.openspec.yaml"
  printf '## Why\n\nAdd %s support for the test suite. More text here.\n\n## What Changes\n\n- add it\n' "$name" > "$c/proposal.md"
  printf '## 1. Work\n\n- [x] 1.1 done\n' > "$c/tasks.md"
  for cap in "$@"; do
    mkdir -p "$c/specs/$cap"
    printf '## Purpose\n\nCapability %s exists to exercise archive retention in tests.\n\n## ADDED Requirements\n\n### Requirement: %s works\nThe system SHALL support %s.\n\n#### Scenario: basic\n- **WHEN** used\n- **THEN** it works\n' "$cap" "$cap" "$cap" > "$c/specs/$cap/spec.md"
  done
}

# fake_archived <folder> [with-specs] — committed archived folder (for index/folder tests).
fake_archived() {
  local d="$A/$1"
  mkdir -p "$d"
  printf '# Title of %s\n\n## Why\n\nx\n' "$1" > "$d/proposal.md"
  printf '## 1. W\n\n- [x] 1.1 done\n' > "$d/tasks.md"
  if [[ "${2:-}" == "with-specs" ]]; then mkdir -p "$d/specs/cap"; printf 'spec\n' > "$d/specs/cap/spec.md"; fi
}
commit_all() { git add -A && git commit -qm "${1:-test: fixture}"; }

index_row() { grep -F "| $1 |" "$A/INDEX.md"; }
index_row_at() { git show "$1:$A/INDEX.md" | grep -F "| $2 |"; }
col() { awk -F' \\| ' -v n="$2" '{ print $n }' <<< "$1" | sed 's/ |$//'; } # col "<row>" 1..5 (1=folder)

# squash_scenario: change "alpha" archived on feat-a, squash-merged into main, new branch feat-b.
squash_scenario() {
  git checkout -qb feat-a
  make_change alpha alpha-cap
  kit archive alpha >/dev/null 2>&1 || return 1
  git checkout -q main
  git merge -q --squash feat-a >/dev/null 2>&1 && git commit -qm "squash: alpha (#1)"
  SQUASH="$(git rev-parse --short HEAD)"
  git checkout -qb feat-b
}

# ── archive-index ────────────────────────────────────────────────────────────
test_index_created_on_first_archive() {
  make_change alpha cap; kit archive alpha >/dev/null 2>&1
  assert test -f "$A/INDEX.md"
  assert grep -qF "| Folder | Title | Capabilities | Archive commit | Snapshot tag |" "$A/INDEX.md"
  assert_eq "$(grep -c "^| $TODAY-alpha |" "$A/INDEX.md")" "1"
}

test_index_disabled() {
  setenv 'KIT_ARCHIVE_INDEX="0"'
  make_change alpha cap; kit archive alpha >/dev/null 2>&1
  assert test -d "$A/$TODAY-alpha"
  assert_not test -e "$A/INDEX.md"
}

test_index_title_and_capabilities_before_delta_prune() {
  setenv 'KIT_ARCHIVE_PRUNE_DELTAS="immediate"'
  make_change alpha auth billing; kit archive alpha >/dev/null 2>&1
  local row_c row_d
  row_c="$(index_row_at HEAD~1 "$TODAY-alpha")"; row_d="$(index_row "$TODAY-alpha")"
  assert_eq "$(col "$row_c" 2)" "Add alpha support for the test suite"
  assert_eq "$(col "$row_c" 3)" "auth, billing"
  assert_eq "$(col "$row_d" 3)" "auth, billing"
  assert_not test -d "$A/$TODAY-alpha/specs"
}

test_index_commit_filled_in_immediate_mode() {
  setenv 'KIT_ARCHIVE_PRUNE_DELTAS="immediate"'
  make_change alpha cap; kit archive alpha >/dev/null 2>&1
  assert_eq "$(col "$(index_row "$TODAY-alpha")" 4)" "$(git rev-parse --short HEAD~1)"
  assert exists_at HEAD~1 "$A/$TODAY-alpha/specs/cap/spec.md"
}

test_index_backfill_legacy_archive() {
  fake_archived 2024-01-01-one; fake_archived 2024-02-01-two; fake_archived 2024-03-01-three; commit_all
  kit index >/dev/null
  assert_eq "$(grep -c '^| 2024-' "$A/INDEX.md")" "3"
  assert_eq "$(col "$(index_row 2024-01-01-one)" 2)" "Title of 2024-01-01-one"
}

test_index_second_run_is_noop() {
  fake_archived 2024-01-01-one with-specs; commit_all
  kit index >/dev/null; assert test -f "$A/INDEX.md"; git add -A; git commit -qm "index"
  local before head; before="$(cat "$A/INDEX.md")"; head="$(git rev-parse HEAD)"
  kit index >/dev/null
  assert_eq "$(cat "$A/INDEX.md")" "$before"
  assert_eq "$(git rev-parse HEAD)" "$head"
  assert_eq "$(git status --porcelain)" ""
}

# ── archive-delta-pruning ────────────────────────────────────────────────────
test_delta_archive_commit_includes_delta_specs() {
  git checkout -qb feat
  make_change alpha cap; kit archive alpha >/dev/null 2>&1
  local c; c="$(git log -1 --format=%H --grep='archive OpenSpec change alpha')"
  assert test -n "$c"
  assert exists_at "$c" "$A/$TODAY-alpha/specs/cap/spec.md"
  assert exists_at "$c" "openspec/specs/cap/spec.md"
}

test_delta_commit_hook_fails() {
  setenv 'KIT_ARCHIVE_PRUNE_DELTAS="immediate"'
  printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
  local head rc=0 out; head="$(git rev-parse HEAD)"
  make_change alpha cap
  out="$(kit archive alpha 2>&1)" || rc=$?
  assert test "$rc" -ne 0
  assert_has "$out" "archive commit was NOT created"
  assert_eq "$(git rev-parse HEAD)" "$head"
  assert test -f "$A/$TODAY-alpha/specs/cap/spec.md"
}

test_delta_unrelated_changes_in_working_tree() {
  make_change alpha cap; git add -A; git commit -qm "change"
  printf 'edited\n' >> README.md
  local head rc=0 out; head="$(git rev-parse HEAD)"
  out="$(kit archive alpha 2>&1)" || rc=$?
  assert test "$rc" -eq 2
  assert_has "$out" "README.md"
  assert_eq "$(git rev-parse HEAD)" "$head"
  assert test -f "openspec/changes/alpha/specs/cap/spec.md"
}

test_delta_immediate_two_distinct_commits() {
  setenv 'KIT_ARCHIVE_PRUNE_DELTAS="immediate"'
  make_change alpha cap; kit archive alpha >/dev/null 2>&1
  assert exists_at HEAD~1 "$A/$TODAY-alpha/specs/cap/spec.md"
  assert_not exists_at HEAD "$A/$TODAY-alpha/specs"
  assert exists_at HEAD "$A/$TODAY-alpha/proposal.md"
  assert_has "$(git log -1 --format=%s HEAD~1)" "archive OpenSpec change alpha"
  assert_has "$(git log -1 --format=%s HEAD)" "prune archived OpenSpec deltas"
  assert_eq "$(git rev-parse HEAD^)" "$(git rev-parse HEAD~1)"
}

test_delta_deferred_squash_merged_change_pruned_later() {
  squash_scenario || return 1
  assert test -d "$A/$TODAY-alpha/specs"
  kit prune-deltas >/dev/null 2>&1
  assert_not test -d "$A/$TODAY-alpha/specs"
  assert_not exists_at HEAD "$A/$TODAY-alpha/specs"
  assert_eq "$(col "$(index_row "$TODAY-alpha")" 4)" "$SQUASH"
  assert_eq "$(git branch --show-current)" "feat-b"
}

test_delta_deferred_unmerged_change_not_pruned() {
  git checkout -qb feat
  make_change beta cap; kit archive beta >/dev/null 2>&1
  local out; out="$(kit prune-deltas --dry-run 2>&1)"
  assert_has "$out" "$TODAY-beta"
  assert_has "$out" "not on default branch"
  kit prune-deltas >/dev/null 2>&1
  assert test -d "$A/$TODAY-beta/specs"
}

test_delta_off_mode_keeps_deltas() {
  setenv 'KIT_ARCHIVE_PRUNE_DELTAS="off"'
  make_change alpha cap; kit archive alpha >/dev/null 2>&1
  kit prune-deltas >/dev/null 2>&1
  assert exists_at HEAD "$A/$TODAY-alpha/specs/cap/spec.md"
}

test_delta_dry_run_has_no_effects() {
  squash_scenario || return 1
  make_change gamma cap2; git add -A; git commit -qm "gamma"
  local before; before="$(state)"
  kit prune-deltas --dry-run >/dev/null 2>&1
  assert_eq "$(state)" "$before"
  kit archive gamma --dry-run >/dev/null 2>&1
  assert_eq "$(state)" "$before"
  kit post-archive "$TODAY-alpha" --dry-run >/dev/null 2>&1
  assert_eq "$(state)" "$before"
}

test_delta_second_prune_is_noop() {
  squash_scenario || return 1
  kit prune-deltas >/dev/null 2>&1
  assert_not test -d "$A/$TODAY-alpha/specs"
  local head out; head="$(git rev-parse HEAD)"
  out="$(kit prune-deltas 2>&1)"
  assert_eq "$(git rev-parse HEAD)" "$head"
  assert_has "$out" "nothing to prune"
}

test_delta_validate_archived_after_prune() {
  setenv 'KIT_ARCHIVE_PRUNE_DELTAS="immediate"'
  make_change alpha cap; kit archive alpha >/dev/null 2>&1
  assert test -f "$A/$TODAY-alpha/proposal.md"
  assert_not test -d "$A/$TODAY-alpha/specs"
  assert openspec validate --archived --no-interactive
}

# ── archive-folder-pruning ───────────────────────────────────────────────────
five_old() { local i; for i in 1 2 3 4 5; do fake_archived "2020-01-0$i-old$i"; done; commit_all; }

test_folder_default_run_is_dry_run() {
  setenv 'KIT_ARCHIVE_PRUNE_FOLDERS="1"' 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  five_old
  local before out; before="$(state)"
  out="$(kit prune-folders 2>&1)"
  assert_has "$out" "eligible: 2020-01-01-old1"
  assert_eq "$(state)" "$before"
}

test_folder_disabled_by_config() {
  setenv 'KIT_ARCHIVE_PRUNE_FOLDERS="0"' 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  five_old
  local before rc=0 out; before="$(state)"
  out="$(kit prune-folders --apply 2>&1)" || rc=$?
  assert test "$rc" -ne 0
  assert_has "$out" "KIT_ARCHIVE_PRUNE_FOLDERS"
  assert_eq "$(state)" "$before"
}

test_folder_keep_count_protects_recent() {
  setenv 'KIT_ARCHIVE_PRUNE_FOLDERS="1"' 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  five_old
  local out; out="$(kit prune-folders 2>&1)"
  assert_eq "$(grep -c '^eligible: ' <<< "$out")" "2"
  assert_has "$out" "eligible: 2020-01-01-old1"
  assert_has "$out" "eligible: 2020-01-02-old2"
}

test_folder_age_protects_beyond_keep() {
  setenv 'KIT_ARCHIVE_PRUNE_FOLDERS="1"' 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  local i; for i in 1 2 3 4 5; do fake_archived "$TODAY-new$i"; done; commit_all
  local out; out="$(kit prune-folders 2>&1)"
  assert_has "$out" "nothing to prune"
  assert_eq "$(grep -c '^eligible: ' <<< "$out")" "0"
}

test_folder_tag_points_at_commit_with_folders() {
  setenv 'KIT_ARCHIVE_PRUNE_FOLDERS="1"' 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  five_old
  kit prune-folders --apply >/dev/null 2>&1
  local tag="openspec-archive-snapshot-$MONTH"
  assert_eq "$(git cat-file -t "$tag")" "tag"
  assert git show "$tag:$A/2020-01-01-old1/proposal.md" >/dev/null
  assert git show "$tag:$A/2020-01-02-old2/proposal.md" >/dev/null
  assert_not test -d "$A/2020-01-01-old1"
}

test_folder_tag_name_collision() {
  setenv 'KIT_ARCHIVE_PRUNE_FOLDERS="1"' 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  five_old
  git tag -a "openspec-archive-snapshot-$MONTH" -m "pre-existing" HEAD~1
  local orig; orig="$(git rev-parse "openspec-archive-snapshot-$MONTH")"
  kit prune-folders --apply >/dev/null 2>&1
  assert_eq "$(git rev-parse "openspec-archive-snapshot-$MONTH")" "$orig"
  assert git rev-parse -q --verify "refs/tags/openspec-archive-snapshot-$MONTH-2"
}

test_folder_index_rows_keep_pruned_changes() {
  setenv 'KIT_ARCHIVE_PRUNE_FOLDERS="1"' 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  five_old
  kit prune-folders --apply >/dev/null 2>&1
  assert_eq "$(col "$(index_row 2020-01-01-old1)" 5)" "openspec-archive-snapshot-$MONTH"
  assert_eq "$(col "$(index_row 2020-01-02-old2)" 5)" "openspec-archive-snapshot-$MONTH"
  assert_not exists_at HEAD "$A/2020-01-01-old1"
  assert_not exists_at HEAD "$A/2020-01-02-old2"
}

test_folder_local_only_warning_nothing_pushed() {
  setenv 'KIT_ARCHIVE_PRUNE_FOLDERS="1"' 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  five_old
  local bare; bare="$(mktemp -d)"; git init -q --bare "$bare"
  git remote add origin "$bare"; git push -q origin main 2>/dev/null
  local out; out="$(kit prune-folders --apply 2>&1)"
  assert_has "$out" "LOCAL ONLY"
  assert_has "$out" "git push origin openspec-archive-snapshot-$MONTH"
  assert_eq "$(git ls-remote --tags origin)" ""
}

test_folder_second_apply_is_noop() {
  setenv 'KIT_ARCHIVE_PRUNE_FOLDERS="1"' 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  five_old
  kit prune-folders --apply >/dev/null 2>&1
  local before out; before="$(state)"
  out="$(kit prune-folders --apply 2>&1)"
  assert_has "$out" "nothing to prune"
  assert_eq "$(state)" "$before"
}

test_folder_notice_after_archive() {
  setenv 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  five_old
  make_change alpha cap
  local out; out="$(kit archive alpha 2>&1)"
  assert_has "$out" "prune-folders"
  local i; for i in 1 2 3 4 5; do assert test -d "$A/2020-01-0$i-old$i"; done
}

# ── archive-retention-config ─────────────────────────────────────────────────
test_config_defaults_without_keys() {
  local out; out="$(kit config 2>&1)"
  assert_eq "$out" "KIT_ARCHIVE_INDEX=1
KIT_ARCHIVE_PRUNE_DELTAS=deferred
KIT_ARCHIVE_PRUNE_FOLDERS=0
KIT_ARCHIVE_KEEP=50
KIT_ARCHIVE_MAX_AGE_DAYS=180
KIT_ARCHIVE_DEFAULT_BRANCH=main"
}

test_config_override_from_env_file() {
  setenv 'KIT_ARCHIVE_PRUNE_DELTAS="off"'
  make_change alpha cap; kit archive alpha >/dev/null 2>&1   # on main: deferred would prune at once
  assert exists_at HEAD "$A/$TODAY-alpha/specs/cap/spec.md"
}

test_config_invalid_prune_mode_fails_safe() {
  setenv 'KIT_ARCHIVE_PRUNE_DELTAS="sometimes"'
  make_change alpha cap
  local out; out="$(kit archive alpha 2>&1)"
  assert_has "$out" "KIT_ARCHIVE_PRUNE_DELTAS"
  assert exists_at HEAD "$A/$TODAY-alpha/specs/cap/spec.md"
}

test_config_installer_update_warns_missing_keys() {
  local dest; dest="$(mktemp -d)"
  ( cd "$dest" && git init -q -b main . )
  # Pre-existing project-context.md skips step 6 (python3 templating), unrelated to this feature.
  mkdir -p "$dest/docs"; printf '# Project context

Task tracker: none
' > "$dest/docs/project-context.md"
  bash "$KIT_DIR/install.sh" --dest "$dest" --stack fastify --no-frontend >/dev/null 2>&1
  sed -i '/^KIT_ARCHIVE_PRUNE_DELTAS=/d' "$dest/.claude/sdd-harness.env"
  local sum; sum="$(cksum < "$dest/.claude/sdd-harness.env")"
  local out; out="$(bash "$KIT_DIR/install.sh" --dest "$dest" --stack fastify --no-frontend 2>&1)"
  assert_eq "$(cksum < "$dest/.claude/sdd-harness.env")" "$sum"
  assert test -f "$dest/.claude/openspec-archive.sh"
  assert_has "$out" "KIT_ARCHIVE_PRUNE_DELTAS"
}

test_config_no_push_in_any_mode() {
  setenv 'KIT_ARCHIVE_PRUNE_DELTAS="immediate"' 'KIT_ARCHIVE_PRUNE_FOLDERS="1"' 'KIT_ARCHIVE_KEEP="3"' 'KIT_ARCHIVE_MAX_AGE_DAYS="30"'
  five_old
  local bare; bare="$(mktemp -d)"; git init -q --bare "$bare"
  git remote add origin "$bare"; git push -q origin main 2>/dev/null
  local before; before="$(git ls-remote origin)"
  make_change alpha cap
  kit archive alpha >/dev/null 2>&1
  kit prune-deltas >/dev/null 2>&1
  kit prune-folders --apply >/dev/null 2>&1
  assert test -f "$A/$TODAY-alpha/proposal.md"
  assert_not test -d "$A/2020-01-01-old1"
  assert_eq "$(git ls-remote origin)" "$before"
}

# ── archive-context-hygiene ──────────────────────────────────────────────────
test_hygiene_session_context_ignores_archived_tasks() {
  command -v jq >/dev/null 2>&1 || { echo "    (jq missing: skipped)"; return 0; }
  mkdir -p "$A/2024-01-01-old"; printf '## 1. W\n\n- [ ] 1.1 never done\n' > "$A/2024-01-01-old/tasks.md"
  local out; out="$(printf '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$PWD" bash .claude/hooks/session-context.sh)"
  assert_has "$out" "Pending tasks in active changes: 0"
}

test_hygiene_settings_deny_archive_index_readable() {
  local s="$KIT_DIR/core/.claude/settings.json"
  assert grep -qF '"Read(/openspec/changes/archive/*/**)"' "$s"
  assert_not grep -qE '"Read\(/?openspec/changes/archive(/\*\*|/INDEX\.md|/\*)?\)"' "$s"
}

test_hygiene_no_archive_reads_in_installed_instructions() {
  local roots=("$KIT_DIR/core/ai-specs" "$KIT_DIR/core/.cursor/rules" "$KIT_DIR/core/.github/copilot-instructions.md" "$KIT_DIR/core/docs")
  # Listing/globbing the whole changes tree without excluding archive.
  local bad
  bad="$(grep -rnE 'ls[^`]*openspec/changes/?`|openspec/changes/\*\*|find[^`]*openspec/changes' "${roots[@]}" | grep -v 'archive' || true)"
  assert_eq "$bad" ""
  local f
  for f in "$KIT_DIR/core/ai-specs/skills/adversarial-review/SKILL.md" \
           "$KIT_DIR/core/ai-specs/skills/explain/SKILL.md" \
           "$KIT_DIR/core/.cursor/rules/20-openspec.mdc"; do
    assert grep -qF "openspec/changes/archive/INDEX.md" "$f"
  done
}

# ── Runner ───────────────────────────────────────────────────────────────────
PASS=0; FAILED=(); LOGDIR="$(mktemp -d)"
TESTS="$(declare -F | awk '{print $3}' | grep '^test_' || true)"
for t in $TESTS; do
  [[ -z "$FILTER" || "$t" == *"$FILTER"* ]] || continue
  if ( new_repo && "$t" ) > "$LOGDIR/$t.log" 2>&1; then
    PASS=$((PASS + 1)); printf 'ok    %s\n' "$t"
  else
    FAILED+=("$t"); printf 'FAIL  %s\n' "$t"; sed 's/^/      /' "$LOGDIR/$t.log" | tail -n 15
  fi
done
printf '\n%d passed, %d failed\n' "$PASS" "${#FAILED[@]}"
(( ${#FAILED[@]} == 0 ))
