# CLAUDE.md — sdd-harness-kit (this repository)

> **Kit-repo working rules** for any AI assistant editing `sdd-harness-kit`.
> Do **not** confuse these files with the `CLAUDE.md` / `AGENTS.md` the installer creates in a
> consumer project (those are pointers to `docs/base-standards.md`).
> Keep `AGENTS.md` and `CLAUDE.md` in this repository **in lockstep** (same prose).

## 1. What this repository is

Portable Spec-Driven Development harness: skills, subagents, deterministic hooks, stack adapters,
installers, and human guides. It is **not** an application, not an OpenSpec project, and not a
product codebase with a suite to govern.

`core/docs/base-standards.md` is **payload** copied into consumer projects (TDD, OpenSpec,
English-only product artefacts). It is **not** the doctrine of this kit repository.

## 2. Map

| Path | Role |
|---|---|
| `core/` | What gets installed: `ai-specs/`, hooks, Cursor rules, Copilot instructions, doctrine markdown |
| `adapters/` | Per-stack env, backend/frontend standards, optional CI and Cursor rules |
| `docs/es/` | Human guides in Spanish (not copied as doctrine into projects) |
| `docs/en/` | Human guides in English (paired with `docs/es/`) |
| `install.sh` / `install.ps1` | Install into `--dest` (refuse to install the kit onto itself) |
| `doctor.sh` / `doctor.ps1` | Health check for an installed destination |
| `VERSION` | Semver of the installable kit |
| `AGENTS.md` / `CLAUDE.md` | **These files** — maintainer rules for the kit repo only |

## 3. Language

- **Talk to the human** in the language they use.
- **Spanish only in**:
  - `docs/es/**/*.md`
  - root `README.md` (landing; English pair: `docs/en/README.en.md`)
- **Do not add Spanish** anywhere else.
- **English everywhere else**, including:
  - skills, agents, hooks, comments inside them
  - adapters and `core/docs/` (installed doctrine)
  - templates, `install.*`, `doctor.*`
  - `docs/en/`
  - this `AGENTS.md` / `CLAUDE.md`
  - commit messages and code-oriented PR titles/bodies
- Human docs are **paired**: a change under `docs/es/` updates the matching file under `docs/en/`
  (and the reverse) in the same PR.
- Reason: models follow procedures more reliably in English; Spanish stays for Hispanic user guides.

Existing Spanish in installers or the root PR template is legacy debt — do not expand it.

## 4. How to change the kit

- Branch from `main`: `feat/…`, `fix/…`, `docs/…`. No direct pushes to `main`.
- Small, focused PRs. Use `.github/pull_request_template.md`.
- Touch **both** `install.sh` and `install.ps1` when installer behaviour changes.
- New stack adapter: follow the full checklist in `docs/en/CONTRIBUTING.en.md` (or `docs/es/CONTRIBUTING.md`).
- If the change affects what gets installed, bump `VERSION` and add the same entry to both
  `docs/es/CHANGELOG.md` and `docs/en/CHANGELOG.en.md`.
- Kit-only docs/memory (these files, human guides) need changelog entries when useful, but **no**
  version bump unless installable payload changes.

## 5. Canonical source

- Edit skills and agents only under `core/ai-specs/`. Do not duplicate bodies under the payload’s
  `.claude/` or `.cursor/` skill/agent trees.
- Placement rule (same as in consumer projects):
  - **Fact** about a product → that project’s `docs/project-context.md`
  - **Procedure** → skill
  - **Invariant that must not fail** → hook
- Doctrine shipped to projects lives in `core/docs/`. Do not invent a second parallel doctrine here.

## 6. Do not

- Do not install the kit onto itself (`install` with `--dest` equal to this repo).
- Do not run `/init` in a destination that already has the kit (it would overwrite doctrine pointers).
- Do not invent statistics, studies, or version claims; use sources already in the docs or explicit
  author instruction.
- Do not introduce build tools, SPA frameworks, or CSS frameworks unless explicitly requested.
- Do not commit secrets or `.env` files.
- Do not copy **these** kit-repo `AGENTS.md` / `CLAUDE.md` into a consumer project; the installer
  creates project pointers separately.
