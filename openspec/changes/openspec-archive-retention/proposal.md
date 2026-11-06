## Why

OpenSpec (1.9.0) never prunes `openspec/changes/archive/`, so in every consumer repo of the kit the
archive grows without bound, inflates checkouts and pulls stale context into agents that glob or grep
the tree. The OpenSpec docs ("Keep or prune archived changes", https://openspec.dev/docs/quickstart)
endorse two manual operations — deleting `archive/<change>/specs/` once Git holds the history, and
deleting whole archived folders — but leave automation to the user. The kit should ship that
automation with safe defaults.

## What Changes

- New kit-owned script `.claude/openspec-archive.sh` (bash, same dispatch model as hooks) with
  subcommands for post-archive bookkeeping, index maintenance, delta pruning and folder pruning.
  All destructive subcommands support `--dry-run`; folder pruning is dry-run unless `--apply`.
- New skill `openspec-archive` that runs after `/opsx:archive` (OpenSpec-owned, not modified) and
  drives the script: index row → archive commit with deltas → prune per configured mode.
- Persistent `openspec/changes/archive/INDEX.md`: one row per archived change (folder, title,
  capabilities, archive commit, snapshot tag when the folder was pruned).
- Delta pruning with three modes: `deferred` (default, squash-merge safe: prune only deltas already
  present on the default branch), `immediate` (archive commit + separate prune commit in the same
  PR; merge-commit/rebase repos only) and `off`.
- Periodic folder pruning (off by default): annotated local tag `openspec-archive-snapshot-YYYY-MM`,
  removal of folders beyond `KEEP` count and `MAX_AGE_DAYS`, recovery hint kept in `INDEX.md`.
- New allowlisted config keys in `.claude/sdd-harness.env` with defaults in `lib.sh`.
- Context hygiene: hooks, skills, rules and Claude permissions stop agents from reading
  `openspec/changes/archive/*/` by default; history is consulted via `INDEX.md` and Git.
- Doctrine updates (`openspec-tasks-mandatory-steps.md` step 11.5, `config.yaml.tpl` archive guidance,
  `20-openspec.mdc`) to call the new skill after `/opsx:archive`.
- Installer follow-up warnings for missing keys; `VERSION` 1.5.1 → 1.6.0; paired CHANGELOG entries.
- Kit repo governance: this repository now holds an `openspec/` tree for its own changes
  (`AGENTS.md` / `CLAUDE.md` §1 updated in lockstep). Not payload.

### Non-goals

- No edits to OpenSpec-generated files (`/opsx:*` commands, `openspec-*` skills).
- No rewriting Git history, no squash, amend, rebase, force-push; no pushing commits or tags.
- No automatic detection of the hosting platform's merge strategy (configured per repo instead).
- No change to how `openspec archive` merges deltas into main specs.
- Fixing stale human docs that still say "archive after merge" (`dod-feature`, USAGE/USO, PROMPTS,
  EXAMPLE) — tracked as a follow-up.

## Capabilities

### New Capabilities

- `archive-index`: generation and idempotent maintenance of `openspec/changes/archive/INDEX.md`.
- `archive-delta-pruning`: archive commit with deltas and pruning of `archive/<change>/specs/`
  under `deferred` / `immediate` / `off` modes, with commit-success and default-branch guards.
- `archive-folder-pruning`: threshold-based removal of whole archived folders behind an annotated
  snapshot tag, dry-run by default.
- `archive-retention-config`: per-repo configuration keys, defaults and safety switches.
- `archive-context-hygiene`: installed artefacts do not make agents read archived change folders.

### Modified Capabilities

(none — the kit has no main specs yet)

## Impact

- **Payload (installable):** `core/.claude/openspec-archive.sh`, `core/.claude/hooks/lib.sh`,
  `core/.claude/hooks/session-context.sh`, `core/.claude/settings.json`,
  `core/ai-specs/skills/openspec-archive/`, `core/ai-specs/skills/{openspec-implement,adversarial-review,explain}`,
  `core/.cursor/rules/{00-core,20-openspec}.mdc`, `core/.github/copilot-instructions.md`,
  `core/docs/{base-standards,openspec-tasks-mandatory-steps}.md`, `core/ai-specs/templates/openspec/config.yaml.tpl`,
  `adapters/*.env`, `install.sh`, `install.ps1`, `doctor.sh`, `doctor.ps1`.
- **Kit repo only:** `tests/openspec-archive.test.sh`, `openspec/`, `AGENTS.md`, `CLAUDE.md`,
  `docs/{es,en}/CONFIG*`, `docs/{es,en}/CHANGELOG*`, `VERSION`.
- **Already-installed consumer repos:** re-running the installer overwrites kit-owned files (script,
  skill, hooks, `settings.json`, doctrine), so the feature arrives with defaults. Project-owned
  `sdd-harness.env` and `openspec/config.yaml` are untouched; `lib.sh` defaults apply and the installer
  warns about missing keys/guidance. Nothing is deleted at install time. On the first archive after
  updating, `INDEX.md` is backfilled for existing archived changes and `deferred` mode lists legacy
  deltas eligible for pruning (dry-run first, one separate prune commit, `--only <change>` to narrow).
- **Dependencies:** `git`, `openspec` CLI (≥ 1.9.0 behaviour verified), bash. No new runtime deps.
