## Purpose

Bound the number of archived change folders kept in the checkout by removing old ones behind an
annotated Git tag, so every pruned folder stays recoverable without rewriting history.

## ADDED Requirements

### Requirement: Disabled by default and dry-run by default
Folder pruning SHALL be a separate command from archiving. It MUST do nothing destructive unless
`KIT_ARCHIVE_PRUNE_FOLDERS=1` and `--apply` is passed. Without `--apply` it MUST print the folders
that exceed the thresholds, the tag it would create, and change nothing.

#### Scenario: Default run is a dry run
- **WHEN** folder pruning runs without `--apply` while folders exceed the thresholds
- **THEN** the output lists them and `git status --porcelain`, HEAD and tags are unchanged

#### Scenario: Disabled by config
- **WHEN** folder pruning runs with `--apply` and `KIT_ARCHIVE_PRUNE_FOLDERS=0`
- **THEN** it exits non-zero with a message naming the key and changes nothing

### Requirement: Threshold selection
A folder is eligible only when it is outside the newest `KIT_ARCHIVE_KEEP` folders AND its date
prefix is older than `KIT_ARCHIVE_MAX_AGE_DAYS` days, so the rule that retains more wins. Folders
without a `YYYY-MM-DD-` prefix MUST never be eligible.

#### Scenario: Keep count protects recent folders
- **WHEN** there are 5 folders older than the age threshold and `KIT_ARCHIVE_KEEP=3`
- **THEN** exactly the 2 oldest are eligible

#### Scenario: Age protects folders beyond keep count
- **WHEN** there are 5 folders all newer than the age threshold and `KIT_ARCHIVE_KEEP=3`
- **THEN** none are eligible

### Requirement: Snapshot tag before deletion
With `--apply`, before deleting anything the kit SHALL create an annotated tag named
`openspec-archive-snapshot-YYYY-MM` on the current HEAD, whose tree contains every folder to be
removed. If a tag with that name already points to HEAD it MUST be reused; if it points elsewhere
the kit MUST use the first free suffix `-2`, `-3`, …. Existing tags MUST never be moved or deleted.

#### Scenario: Tag points at a commit with the folders
- **WHEN** folder pruning runs with `--apply`
- **THEN** `git show <tag>:openspec/changes/archive/<folder>/proposal.md` succeeds for every removed folder

#### Scenario: Tag name collision
- **WHEN** `openspec-archive-snapshot-YYYY-MM` already exists on another commit
- **THEN** the new tag is `openspec-archive-snapshot-YYYY-MM-2` and the existing tag is unchanged

### Requirement: Removal commit and index recovery hint
The kit SHALL remove eligible folders in one new commit and update each of their `INDEX.md` rows with
the snapshot tag, so recovery is possible with `git show <tag>:<path>`. It MUST NOT amend, squash,
rebase, force-push or push.

#### Scenario: Index rows keep pruned changes
- **WHEN** two folders are pruned
- **THEN** `INDEX.md` still has their rows with the tag in the snapshot column and HEAD's tree lacks both folders

### Requirement: Local-only tag warning
After creating a tag the kit MUST print a prominent warning that the tag exists only locally and does
not protect anyone else until published, plus the exact push command, and MUST NOT run it.

#### Scenario: Warning printed and nothing pushed
- **WHEN** folder pruning creates a tag in a repo with a remote
- **THEN** the output contains "LOCAL ONLY" and `git push origin <tag>`, and `git ls-remote --tags origin` does not list the tag

### Requirement: Idempotence
Running folder pruning with `--apply` twice in a row MUST create no new tag and no new commit the second time.

#### Scenario: Second apply is a no-op
- **WHEN** folder pruning with `--apply` runs twice consecutively
- **THEN** the second run reports nothing to prune and HEAD and tags are unchanged

### Requirement: Archive warns when threshold exceeded
After archiving, when eligible folders exist the kit SHALL print a one-line notice suggesting the
folder-pruning command, and MUST NOT prune folders itself.

#### Scenario: Notice after archive
- **WHEN** a change is archived and eligible folders exist
- **THEN** the output mentions the folder-pruning command and all archived folders remain
