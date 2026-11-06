# archive-delta-pruning Specification

## Purpose
Remove `openspec/changes/archive/<change>/specs/` once Git provably holds the deltas, keeping
proposal, design and tasks in the checkout, without ever losing the delta snapshot from history.

## Requirements

### Requirement: Archive commit contains the deltas
After a change is archived, the kit SHALL create an archive commit that contains the whole archived
folder including `specs/`, the updated main specs under `openspec/specs/` and the `INDEX.md` row. The
commit message MUST follow the repository's commit convention (`type(scope): description`).

#### Scenario: Archive commit includes delta specs
- **WHEN** a change with delta specs is archived through the kit
- **THEN** the archive commit reported by the kit is a commit whose tree contains `openspec/changes/archive/<folder>/specs/` and the updated `openspec/specs/<capability>/spec.md`

### Requirement: Pruning only after a successful archive commit
The kit MUST NOT delete any delta specs when the archive commit was not created. Causes include
unrelated staged or unstaged changes in the working tree, a merge or rebase in progress, a detached
HEAD, or a failing commit hook. In that case the archived folder MUST stay intact with its deltas and
the kit MUST print a warning naming the cause.

#### Scenario: Commit hook fails
- **WHEN** a `pre-commit` hook rejects the archive commit
- **THEN** no prune commit is created, `archive/<folder>/specs/` still exists in the working tree, and the exit status is non-zero with a warning

#### Scenario: Unrelated changes in working tree
- **WHEN** the working tree has a modified file outside `openspec/` before archiving
- **THEN** the kit refuses to commit and does not prune

### Requirement: Immediate mode uses a separate prune commit
With `KIT_ARCHIVE_PRUNE_DELTAS=immediate`, after the archive commit succeeds the kit SHALL remove
`archive/<folder>/specs/` in a second, separate commit that also fills the archive-commit column of
the index. Both commits MUST be new commits; neither may be amended or squashed.

#### Scenario: Two distinct commits
- **WHEN** a change is archived in `immediate` mode
- **THEN** HEAD~1 contains the deltas, HEAD removes them, and HEAD's parent is HEAD~1

### Requirement: Deferred mode prunes only deltas present on the default branch
With `KIT_ARCHIVE_PRUNE_DELTAS=deferred` (default), archiving SHALL create only the archive commit.
The prune step SHALL remove `specs/` of an archived change only when `<default-branch>:<path>/specs`
exists in Git, and SHALL record that default-branch commit in the index. Changes whose deltas are not
on the default branch MUST be left untouched.

#### Scenario: Squash-merged change is pruned later
- **WHEN** change A was archived on a branch, the branch was squash-merged into the default branch, and the prune step runs on a new branch from it
- **THEN** A's `specs/` is removed in a prune commit and A's index row references the squash commit

#### Scenario: Unmerged change is not pruned
- **WHEN** change B is archived on the current branch but not yet on the default branch and the prune step runs
- **THEN** B's `specs/` is kept and the dry-run output lists B as "not on default branch"

### Requirement: Off mode
With `KIT_ARCHIVE_PRUNE_DELTAS=off` the kit SHALL create the archive commit and never delete delta specs.

#### Scenario: Off mode keeps deltas
- **WHEN** a change is archived with `off`
- **THEN** `archive/<folder>/specs/` exists at HEAD

### Requirement: Dry run and narrowing
Every delta-pruning entry point MUST support `--dry-run`, which prints the paths it would delete and
the commits it would create and changes neither the working tree, the index nor Git refs. The deferred
prune MUST accept `--only <folder>` to restrict it to one archived change.

#### Scenario: Dry run has no effects
- **WHEN** the prune step runs with `--dry-run` while eligible deltas exist
- **THEN** `git status --porcelain`, `git rev-parse HEAD` and `git tag` are identical before and after

### Requirement: Idempotence
Running the prune step twice in a row MUST make no change and create no commit the second time.

#### Scenario: Second prune is a no-op
- **WHEN** the prune step runs twice consecutively
- **THEN** the second run creates no commit and reports nothing to prune

### Requirement: Archived changes still validate
After delta pruning, `openspec validate --archived` MUST pass for every pruned change whose tasks were complete.

#### Scenario: Validate after prune
- **WHEN** a change with all tasks complete is archived and its deltas are pruned
- **THEN** `openspec validate --archived` exits 0
