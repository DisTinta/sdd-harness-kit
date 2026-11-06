# archive-context-hygiene Specification

## Purpose
Prevent installed agents, hooks and rules from loading archived change folders into context by
default; history is consulted through `INDEX.md` and Git instead.

## Requirements

### Requirement: Hooks ignore archived changes
Installed hooks that scan `openspec/changes/` SHALL exclude `openspec/changes/archive/`.

#### Scenario: Session context ignores archived pending tasks
- **WHEN** an archived change has an unchecked task and there are no active changes
- **THEN** the SessionStart hook reports zero pending tasks

### Requirement: Claude read permission denies archived folders
The installed `.claude/settings.json` SHALL deny `Read` on `openspec/changes/archive/*/**` while leaving
`openspec/changes/archive/INDEX.md` readable.

#### Scenario: Deny rule present and index readable
- **WHEN** `settings.json` is inspected after install
- **THEN** `permissions.deny` contains `Read(/openspec/changes/archive/*/**)` and no deny entry matches `openspec/changes/archive/INDEX.md`

### Requirement: Instructions point to INDEX.md and Git
Installed skills, agents, Cursor rules, Copilot instructions and doctrine MUST NOT instruct agents to
list, read or search `openspec/changes/archive/`. Where they refer to change history they MUST name
`openspec/changes/archive/INDEX.md` and Git (`git log`, `git show <ref>:<path>`).

#### Scenario: No archive reads in installed instructions
- **WHEN** the installed `ai-specs/`, `.cursor/rules/`, `.github/copilot-instructions.md` and `docs/` are searched for instructions that list or read `openspec/changes` without excluding `archive`
- **THEN** no match is found, and at least the history references in `adversarial-review`, `explain` and `20-openspec.mdc` mention `INDEX.md`
