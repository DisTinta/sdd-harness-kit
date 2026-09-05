# Changelog

**Language:** [Español](CHANGELOG.md) · English

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Semantic versioning: the live version is in [`VERSION`](VERSION).

> **Why this file exists.** The kit **replaces its own files** under `docs/`, `ai-specs/`, and
> `.claude/` when updating an already-installed project. Whoever updates needs to know what will
> change before running the installer; without this log they can only compare by hand or trust.

---

## [1.3.0]

### Added

- Skill `/migration-review`: read-only migration audit (Expand-Contract, DROP/UNIQUE/ALTER,
  destructive renames, rollback).
- Skill `/architecture-audit`: Fowler mode, DDD, hexagonal boundaries, SOLID/CUPID (no implementation).
- **Livewire** frontend adapter (`livewire.frontend-standards.md` + `livewire.ci.yml`) alongside
  React; flag `--frontend auto|react|livewire` / `-Frontend …`.
- Workflow `.github/workflows/frontend.yml` (React or Livewire by UI).
- Reference template `mcp.with-figma.json` (Context7 + Playwright + Figma); installer does not apply it.
- WCAG 2.2 AA, `test:a11y`, and CWV thresholds in FE standards (React, Livewire, template).
- Expand-Contract doctrine in Persistence § of all backend-standards; pgvector notes in Fastify.

### Changed

- `frontend-planner` agnostic to React/Livewire.
- `/dod-feature` requires `/migration-review` when the schema changes.
- Inventory: **29 skills**.
- `business` path filter in adapter `ci.yml` files (Laravel, Adonis, Fastify) includes
  `tests/**`, so mutation re-runs when tests change.

---

## [1.2.4]

### Changed

- Each adapter's `ci.yml` gates tests and mutation with `dorny/paths-filter@v4` inside the
  `quality` job. `runtime` is a broad allowlist (not just `app/**`); `business` is
  `PATH_BUSINESS` plus Infection/Stryker config, without `tests/**`. Lint and static analysis
  still always run. On Laravel, PRs mutate only the diff (`--git-diff-lines`); a push to
  `main` mutates the whole layer.

---

## [1.2.3]

### Changed

- Playwright screenshots (and durable demo binary evidence) must be saved under
  `openspec/changes/<id>/reports/`, next to the markdown report; not at the repo root.
  `/show-spec-working` 1.1.0, `docs/base-standards.md`, OpenSpec mandatory steps, and the
  `report.md` template require it.

### Fixed

- Skill dynamic context used `cat … | grep`, which Claude Code rejects ("multiple operations")
  and aborts the skill without prompting. Now a single `grep` on `.claude/sdd-harness.env`,
  with `Bash(grep *)` in `allowed-tools`. Affects `/privacy-ethics-check` and the other skills
  that inject project config.

---

## [1.2.2]

### Changed

- Branch and commit rule: with a ticket, the branch is `feature/<TICKET>-<slug>` and the message is
  `type(TICKET): description` (e.g. `feat(KAN-184): add listing filter by state`). Without a ticket,
  the scope is the capability or the layer; the agent asks for the id and does not invent it.
  Doctrine in `docs/base-standards.md`; `/commit`, OpenSpec mandatory steps, P14, and the manual
  aligned.

---

## [1.2.1]

### Fixed

- After `openspec init`, `sync-artifacts` marked native `openspec-*` skills (the `/opsx:*` ones) as
  orphans and exited with code 1. An agent read that as “delete”. It now labels them `KEEP`, sync
  does not fail, and the message says not to delete them. A real `ORPHAN` (any other name) is still
  an error. Same logic in `.sh` and `.ps1`; `/sync-agent-artifacts` and `/kit-health` aligned.

---

## [1.2.0]

### Added

- **`fastify` adapter** for Fastify projects on a hexagonal npm-workspaces monorepo: `fastify.env`,
  `fastify.backend-standards.md`, `fastify.rules.mdc`, `fastify.ci.yml`, and
  `fastify.dependency-cruiser.js`.
  - The `GUARD_HTTP_IN_BUSINESS` guard includes the monorepo dependency rule: if a business-layer
    file mentions an infrastructure package, the `post-edit-quality` hook warns on save.
  - `ci.yml` brings up PostgreSQL with pgvector as a service and applies and reverts migrations
    before tests.
  - `.dependency-cruiser.js` is the CI counterpart of that same guard. Installers copy it to the
    project root and respect the file if it already exists.
- **Automatic `fastify` detection** in `install.sh` and `install.ps1`. Looks for `"fastify"` in the
  root `package.json` **and** in `packages/*`, because in a monorepo the dependency is not at the
  root.
- **`LICENSE`** (MIT) and **`CREDITS.md`**, with the kit’s provenance declared: notes from the
  AI4Devs Master at LIDR Academy and ideas taken from
  [`LIDR-academy/lidr-specboot`](https://github.com/LIDR-academy/lidr-specboot) (MIT). The `LICENSE`
  keeps the specboot copyright notice, as its own licence requires.
- **This `CHANGELOG.md`.**
- **Checklist in `CONTRIBUTING.md`** with the places to touch so a new adapter is complete. Added
  because writing the `fastify` one left it half-finished: the four adapter files were there, but
  `install.ps1` help still announced only three stacks.

### Fixed

- The `-Stack` parameter help in `install.ps1` listed `adonisjs, laravel or _template` and did not
  mention new adapters. It now also points to `adapters/*.env` as the real list.
- The README said an adapter is written by filling in “twelve variables”. The `_template.env`
  contract has **24**.
- The version was written both in `VERSION` and in the README text, so every release was two edits
  and two chances to desync. The README no longer repeats it: it points to `VERSION` and to this
  file.

---

## [1.1.0] and earlier

No log. This changelog starts at 1.2.0; prior history is in the commits. It is not reconstructed
here from memory.
