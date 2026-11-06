## 0. Branch

- [ ] 0.1 Work on `feat/openspec-archive-retention`, created from `dev` (already created with this proposal); never push without author confirmation

## 1. Test harness (red first)

- [ ] 1.1 Create `tests/openspec-archive.test.sh`: plain bash runner, temp Git repos via `mktemp -d`, bare remote, `openspec init --tools none`, helper to create a change with proposal/specs/tasks; skip with a clear message when `openspec` is missing
- [ ] 1.2 Write failing tests for `archive-index` scenarios (create, disabled, title/capabilities before prune, commit filled, backfill, second run no-op)
- [ ] 1.3 Write failing tests for `archive-delta-pruning` scenarios (deltas in archive commit, hook failure, unrelated changes, two commits in immediate, squash-merged deferred, unmerged deferred, off, dry-run no effects, idempotence, `openspec validate --archived` after prune)
- [ ] 1.4 Write failing tests for `archive-folder-pruning` scenarios (default dry run, disabled by config, keep count, age, tag contents, tag collision, index rows, LOCAL ONLY warning + nothing pushed, second apply no-op, notice after archive)
- [ ] 1.5 Write failing tests for `archive-retention-config` (defaults, override, invalid value, installer update warning, no push in any mode) and `archive-context-hygiene` (session-context count, settings deny, instruction search)
- [ ] 1.6 Run the suite and confirm every new test fails for the expected reason

## 2. Configuration and dispatch

- [ ] 2.1 Add `KIT_ARCHIVE_*` keys to the `load_env_safe` allowlist and defaults in `core/.claude/hooks/lib.sh`
- [ ] 2.2 Forward extra arguments in `core/.claude/hooks/invoke.cjs` (`process.argv.slice(3)`), backward compatible with existing hooks
- [ ] 2.3 Add commented `KIT_ARCHIVE_*` keys to `adapters/_template.env` and every `adapters/*.env`

## 3. Script `core/.claude/openspec-archive.sh`

- [ ] 3.1 Skeleton: subcommand parsing, `--dry-run` / `--apply` / `--only`, `config` subcommand, value validation with safe fallback
- [ ] 3.2 Preflight guards (work tree, detached HEAD, merge/rebase in progress, unrelated changes outside `openspec/`)
- [ ] 3.3 `index`: deterministic INDEX.md generation, row preservation, write only on byte change
- [ ] 3.4 `post-archive` / `archive`: index row → archive commit with HEAD-moved check → mode dispatch; commit message `type(scope): …` with ticket scope from branch when present, else `openspec`
- [ ] 3.5 `prune-deltas`: deferred eligibility via `git cat-file -e <default-branch>:<path>/specs`, proof commit recorded, one prune commit; `immediate` path inside `post-archive`
- [ ] 3.6 `prune-folders`: threshold selection (GNU/BSD date), annotated tag with reuse/suffix, `git rm -r`, index tag column, LOCAL ONLY warning, dry-run default
- [ ] 3.7 Threshold notice at the end of `post-archive`
- [ ] 3.8 Run the suite until index, delta, folder and config tests pass

## 4. Skill and doctrine

- [ ] 4.1 Create `core/ai-specs/skills/openspec-archive/SKILL.md` (after `/opsx:archive`: dry-run, confirm, `post-archive`; separate section for `prune-folders` with explicit confirmation; never push; relay LOCAL ONLY warning)
- [ ] 4.2 Update `core/docs/openspec-tasks-mandatory-steps.md` step 11.5, `core/ai-specs/templates/openspec/config.yaml.tpl` (`rules.tasks` + `operations.archive.guidance`) and `core/.cursor/rules/20-openspec.mdc` to call the skill after `/opsx:archive`

## 5. Context hygiene

- [ ] 5.1 Exclude `archive/` from the pending-task count in `core/.claude/hooks/session-context.sh`
- [ ] 5.2 Make `openspec-implement` list only active changes
- [ ] 5.3 Verify Claude Code permission pattern syntax, add `Read(openspec/changes/archive/*/**)` to `core/.claude/settings.json` deny list
- [ ] 5.4 Point history references to `INDEX.md` + Git in `adversarial-review`, `explain`, `00-core.mdc`, `20-openspec.mdc`, `copilot-instructions.md`, `base-standards.md`
- [ ] 5.5 Run the hygiene tests until green

## 6. Installer, doctor, docs, version

- [ ] 6.1 `install.sh` and `install.ps1`: copy `openspec-archive.sh` to `.claude/`, follow-up warnings for missing `KIT_ARCHIVE_*` keys and archive guidance line
- [ ] 6.2 `doctor.sh` and `doctor.ps1`: report presence of the script and effective archive config
- [ ] 6.3 `docs/es/CONFIG.md` + `docs/en/CONFIG.en.md`: keys, modes, squash-merge guidance, recovery commands
- [ ] 6.4 Bump `VERSION` to 1.6.0; same entry in `docs/es/CHANGELOG.md` and `docs/en/CHANGELOG.en.md`
- [ ] 6.5 Run `.claude/sync-artifacts.sh --check` equivalent on a dry-run install into a temp repo; run `doctor.sh` there

## 7. Verification

- [ ] 7.1 Full `tests/openspec-archive.test.sh` run green on Git Bash (Windows); record output in `reports/<date>-test-run.md`
- [ ] 7.2 End-to-end: install into a temp repo, archive a dummy change, check commits, INDEX row and `openspec validate --archived`
- [ ] 7.3 `openspec validate openspec-archive-retention --strict` passes
- [ ] 7.4 Commit in focused commits; ask the author before any push or PR (PR targets `dev`)
