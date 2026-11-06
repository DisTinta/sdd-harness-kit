## Purpose

Keep a persistent, human- and agent-readable index of every archived OpenSpec change so history can
be consulted without reading archived folders, even after their deltas or folders are pruned.

## ADDED Requirements

### Requirement: Index file location and format
The kit SHALL maintain `openspec/changes/archive/INDEX.md` as a Markdown table with exactly one row
per archived change and the columns: folder (dated name), title, capabilities, archive commit,
snapshot tag. Rows MUST be sorted by folder name ascending.

#### Scenario: Index created on first archive
- **WHEN** a change is archived in a repo without `INDEX.md` and `KIT_ARCHIVE_INDEX=1`
- **THEN** `INDEX.md` exists with the header row and one row whose folder equals the archived folder name

#### Scenario: Index disabled
- **WHEN** a change is archived with `KIT_ARCHIVE_INDEX=0`
- **THEN** `INDEX.md` is neither created nor modified

### Requirement: Row content derived before pruning
The row for a change MUST be written before any pruning of that change. The title MUST come from
`proposal.md`: its first level-1 heading that is not `Why`; otherwise the first sentence of its `Why`
section (at most 100 characters); otherwise the change name. Capabilities MUST be the capability paths
under the change's `specs/` (directories holding a `spec.md`), comma-separated, or `—` when there are
none.

#### Scenario: Title and capabilities captured before delta prune
- **WHEN** a change with `proposal.md` and delta specs for `auth` and `billing` is archived in `immediate` mode
- **THEN** the archive commit contains an `INDEX.md` row with the proposal title and capabilities `auth, billing`, and the row is unchanged in capability content after the prune commit

### Requirement: Archive commit recorded
The archive-commit column MUST hold the abbreviated hash of a commit whose tree contains the change's
delta specs. It MAY be empty (`pending`) until such a commit exists on the configured default branch
in `deferred` mode.

#### Scenario: Commit filled in immediate mode
- **WHEN** a change is archived in `immediate` mode
- **THEN** after the prune commit the row's archive-commit column equals the hash of the archive commit, and that commit's tree contains `archive/<folder>/specs/`

### Requirement: Idempotent rebuild and backfill
Running the index subcommand MUST add rows for archived folders missing from the index, keep existing
rows for folders that no longer exist (pruned), and MUST NOT change the file when nothing changed.

#### Scenario: Backfill legacy archive
- **WHEN** the index subcommand runs in a repo with three archived folders and no `INDEX.md`
- **THEN** `INDEX.md` has three rows

#### Scenario: Second run is a no-op
- **WHEN** the index subcommand runs twice in a row
- **THEN** the second run leaves `INDEX.md` byte-identical and creates no commit
