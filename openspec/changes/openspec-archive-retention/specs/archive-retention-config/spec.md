## Purpose

Let each consumer repo enable, disable and tune every archive-retention phase through the kit's
existing `.claude/sdd-harness.env`, with conservative defaults when keys are absent.

## ADDED Requirements

### Requirement: Configuration keys and defaults
The kit SHALL read these keys from `.claude/sdd-harness.env` through the existing allowlisted parser,
applying the defaults when a key is missing or empty:

| Key | Allowed values | Default |
|---|---|---|
| `KIT_ARCHIVE_INDEX` | `0`, `1` | `1` |
| `KIT_ARCHIVE_PRUNE_DELTAS` | `deferred`, `immediate`, `off` | `deferred` |
| `KIT_ARCHIVE_PRUNE_FOLDERS` | `0`, `1` | `0` |
| `KIT_ARCHIVE_KEEP` | positive integer | `50` |
| `KIT_ARCHIVE_MAX_AGE_DAYS` | positive integer | `180` |
| `KIT_ARCHIVE_DEFAULT_BRANCH` | branch name | `origin/HEAD` target, else `main` |

#### Scenario: Defaults without keys
- **WHEN** `sdd-harness.env` contains none of the keys
- **THEN** the effective configuration printed by the script's config report equals the defaults

#### Scenario: Override from env file
- **WHEN** `sdd-harness.env` sets `KIT_ARCHIVE_PRUNE_DELTAS=off`
- **THEN** archiving keeps the delta specs

### Requirement: Invalid values fail safe
An invalid value MUST make the kit fall back to the non-destructive behaviour for that phase
(`off` / `0` / no pruning) and print a warning naming the key.

#### Scenario: Unknown prune mode
- **WHEN** `KIT_ARCHIVE_PRUNE_DELTAS=sometimes`
- **THEN** no deltas are pruned and a warning names `KIT_ARCHIVE_PRUNE_DELTAS`

### Requirement: Install and update compatibility
Re-running the installer on a repo with the kit MUST deliver the script and skill (kit-owned) without
overwriting the project-owned `sdd-harness.env`, and MUST print a follow-up warning listing missing
`KIT_ARCHIVE_*` keys. New installs MUST receive the keys with defaults in the stack env file.

#### Scenario: Update warns about missing keys
- **WHEN** the installer runs on a destination whose `sdd-harness.env` lacks `KIT_ARCHIVE_PRUNE_DELTAS`
- **THEN** the env file is unchanged, `.claude/openspec-archive.sh` exists, and the output warns about the missing key

### Requirement: No implicit remote operations
No configuration value SHALL cause the kit to push commits or tags, merge, rebase, amend or squash.

#### Scenario: No push in any mode
- **WHEN** archiving and both prune steps run with every phase enabled in a repo with a bare remote
- **THEN** the remote's refs are unchanged
