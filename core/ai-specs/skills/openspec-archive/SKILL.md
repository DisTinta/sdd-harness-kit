---
name: openspec-archive
description: Use right after /opsx:archive (Pre-merge Review step 11.5), or when the user asks to index, prune or clean up openspec/changes/archive. Writes the INDEX.md row, creates the archive commit with the delta specs, prunes deltas per KIT_ARCHIVE_PRUNE_DELTAS, and runs the separate, dry-run-first folder pruning behind an annotated snapshot tag. Never pushes.
author: sdd-harness-kit
version: 1.0.0
argument-hint: [archived folder YYYY-MM-DD-<change> | index | prune-deltas | prune-folders]
allowed-tools: Bash(bash .claude/openspec-archive.sh *) Bash(node .claude/hooks/invoke.cjs .claude/openspec-archive.sh *) Bash(git status *) Bash(git log *) Bash(git show *) Read
---

## Configuration
!`bash .claude/openspec-archive.sh config 2>&1`

## Repository state
- Branch: !`git branch --show-current`
- Uncommitted: !`git status --short`
- Archive index: `openspec/changes/archive/INDEX.md` (read it; do **not** open archived folders)

## How to run the script
- macOS / Linux / Git Bash: `bash .claude/openspec-archive.sh <subcommand> …`
- Windows from Claude Code: `node .claude/hooks/invoke.cjs .claude/openspec-archive.sh <subcommand> …`
  (picks Git Bash, never WSL's bash).

Exit codes: `0` ok · `1` usage · `2` refused (preflight or config) · `3` commit failed, nothing pruned.

## Procedure A — after `/opsx:archive` (default)

1. Identify the archived folder `openspec/changes/archive/YYYY-MM-DD-<change>` that `/opsx:archive`
   just created (its summary prints it). If `$ARGUMENTS` names it, use that.
2. Preview: `post-archive <folder> --dry-run`. Show the output to the user.
3. Run: `post-archive <folder>`. It:
   - writes or refreshes the `INDEX.md` row (title, capabilities) while `specs/` still exists;
   - creates the archive commit `chore(<scope>): archive OpenSpec change <change>` with the archived
     folder **including its deltas**, the updated `openspec/specs/` and `INDEX.md` (commit hooks run);
   - prunes deltas per `KIT_ARCHIVE_PRUNE_DELTAS`:
     - `deferred` (default): only deltas of earlier changes that already exist on the default branch,
       in one separate commit. Safe with squash merges.
     - `immediate`: this change's deltas in a second, separate commit. Only for repos that merge with
       merge commits or rebase; tell the user a squash merge would drop the deltas from main history.
     - `off`: no pruning.
4. If it exits `2` or `3`: report the message verbatim. Nothing was pruned. Do **not** retry with
   `--no-verify`, do not amend, do not stash the user's work on your own. Ask the user how to proceed.
5. Report the commits created (`git log --oneline -3`). Do not push; the author pushes and merges.

## Procedure B — standalone maintenance

- `index` — backfill or repair `INDEX.md` (writes the file, no commit). Commit it with `/commit`.
- `prune-deltas --dry-run` then `prune-deltas` — deferred pruning outside an archive run. Use
  `--only <folder>` to narrow. If nothing is eligible, suggest `git fetch` to the user (the script never
  touches the network).

## Procedure C — folder pruning (separate, explicit)

Only when the user asks, or when `post-archive` printed the threshold notice and the user agrees.

1. `prune-folders` (always a dry run). Show the eligible folders and the tag it would create.
2. Ask the user for explicit confirmation to delete those folders. Folder pruning also requires
   `KIT_ARCHIVE_PRUNE_FOLDERS="1"` in `.claude/sdd-harness.env`; never change that key yourself.
3. On confirmation: `prune-folders --apply`. It creates the annotated tag
   `openspec-archive-snapshot-YYYY-MM` on HEAD, removes the folders in one commit and records the tag
   in `INDEX.md`.
4. Relay the **LOCAL ONLY** warning: the tag protects nobody else until it is pushed. Offer the printed
   `git push <remote> <tag>` command; run it only if the user explicitly asks.

## Recovering archived content
- Pruned deltas: `git show <archive-commit>:openspec/changes/archive/<folder>/specs/<cap>/spec.md`
  (commit from the `Archive commit` column of `INDEX.md`).
- Pruned folders: `git show <snapshot-tag>:openspec/changes/archive/<folder>/proposal.md`.

## Prohibited
- Pushing commits or tags, merging, amending, rebasing, squashing, force-pushing, `--no-verify`.
- Editing `.claude/sdd-harness.env` to enable pruning on your own.
- Reading `openspec/changes/archive/*/` for context; use `INDEX.md` and Git.
