# SDD Harness Kit

**Language:** [Español](../../README.md) · English

Version in [`VERSION`](../../VERSION), changes in [CHANGELOG.en.md](CHANGELOG.en.md). Guided setup: [STEP-BY-STEP.md](STEP-BY-STEP.md).
Contribution guide: [CONTRIBUTING.en.md](CONTRIBUTING.en.md). Origin and credits: [CREDITS.en.md](CREDITS.en.md).
Working rules for this repository (kit maintainers, not the installed project): [`AGENTS.md`](../../AGENTS.md) / [`CLAUDE.md`](../../CLAUDE.md).

Portable AI artefacts —subagents, skills, hooks, standards, and templates— to apply
**Spec-Driven Development** with a deterministic harness in any project.

Canonical source in `ai-specs/`, doctrine in `docs/base-standards.md`, and the memory files
(`CLAUDE.md`, `AGENTS.md`) pointing to it. Includes **deterministic hooks**, **per-stack adapters**,
**real Windows support**, a **health doctor**, and **deep secret gates**.

```bash
# Linux / macOS
./install.sh --dest /path/to/my-project --dry-run   # see what it would do
./install.sh --dest /path/to/my-project             # install
./install.sh --dest /path/to/my-project --no-frontend
./install.sh --dest /path/to/my-project --frontend livewire
bash ./doctor.sh --dest /path/to/my-project
```

```powershell
# Windows
.\install.ps1 -Dest C:\projects\my-project -DryRun
.\install.ps1 -Dest C:\projects\my-project
.\install.ps1 -Dest C:\projects\my-project -NoFrontend
.\install.ps1 -Dest C:\projects\my-project -Frontend livewire
.\doctor.ps1 -Dest C:\projects\my-project
```

Afterwards: `openspec init` + wire `config.yaml` with the kit template. And **do not run `/init`** —
see [STEP-BY-STEP.md](STEP-BY-STEP.md) / [USAGE.md](USAGE.md).

It works the same whether you use native OpenSpec commands (`/opsx:explore`, `/opsx:propose`,
`/opsx:apply`, `/opsx:sync`, `/opsx:archive`), the kit’s, or both at once: the **9 hooks** and the
doctrine act on the file path, not on which command wrote it. Correspondence table in
[MANUAL.en.md](MANUAL.en.md).

---

## What it installs

| Path in your repository | What it is |
|---|---|
| `ai-specs/skills/` | **29 skills**, canonical source. Includes `/show-spec-working`, `/adversarial-review`, `/migration-review`, `/architecture-audit`, `/privacy-ethics-check`, `/meta-prompt`, `/kit-health` |
| `ai-specs/agents/` | **9 subagents**, canonical source. Includes the trilogy `tdd-test-writer` / `tdd-implementer` / `tdd-refactorer`, one isolated context per cycle phase |
| `ai-specs/templates/` | Story, ADR, PR, OpenSpec artefact templates and `config.yaml.tpl` |
| `.claude/skills/` · `.cursor/skills/` | References to `ai-specs` (symlink, or copy if the OS does not allow it) |
| `.claude/agents/` · `.cursor/agents/` | Same |
| `.claude/hooks/` | **9** deterministic lifecycle **hooks** (includes secret-read blocking) |
| `.claude/sdd-harness.env` | **The only piece that changes between projects**: commands, paths, `BRANCH_PREFIX`, and guards |
| `.mcp.json` · `.cursor/mcp.json` | Project MCP: **Context7** (library docs) and **Playwright** (UI demo; omitted with `--no-frontend`) |
| `.claude/sync-artifacts.sh` · `.ps1` | Rebuilds the references to `ai-specs` |
| `docs/base-standards.md` | The doctrine. The kit replaces it on update |
| `docs/documentation-standards.md` | Documentation rules and the pre-commit gate |
| `docs/openspec-tasks-mandatory-steps.md` | What a `tasks.md` must contain to be valid |
| `docs/backend-standards.md` | Layers and conventions **of your stack** (from the adapter) |
| `docs/frontend-standards.md` | UI architecture (React or Livewire per `--frontend`) |
| `tests/a11y/smoke.example.*` | axe-core scaffold (not a test until `test:a11y` is wired) |
| `docs/project-context.md` | **The only file you write.** Survives updates |
| `.cursor/rules/` | The same rules for Cursor: core, TDD, OpenSpec, and stack |
| `.github/` | Copilot instructions, review and CI workflows, backend CI and `frontend.yml`, PR template |
| `CLAUDE.md` `AGENTS.md` | Point to `docs/base-standards.md` |

---

## The three design ideas

### 1. Single canonical source

Skills live once, in `ai-specs/`. `.claude/` and `.cursor/` reference them. You edit one file and
both tools see it.

Where the OS allows symlinks, they are symlinks. Where it does not —Windows without Developer Mode—
they are copies, and `sync-artifacts` refreshes them. If symlinks materialise as text stubs, skills
do not load: the kit detects that and fixes it with copies + sync.

### 2. Doctrine separated from context

| File | Who writes it | What happens when the kit updates |
|---|---|---|
| `docs/base-standards.md` | The kit | Replaced |
| `docs/documentation-standards.md` | The kit | Replaced |
| `docs/openspec-tasks-mandatory-steps.md` | The kit | Replaced |
| `docs/backend-standards.md` | The adapter; you adjust it | Kept if it differs |
| `docs/project-context.md` | **You** | Never touched |
| `tests/a11y/smoke.example.*` | Kit the first time; then **you** | Not overwritten if it already exists |

That way a kit update does not wipe your work, and a hook warns you if you try to edit doctrine
per project.

### 3. Agnostic core, per-stack adapter

Everything stack-dependent lives in `.claude/sdd-harness.env`. Hooks load it safely (allowlist, no
`eval`); skills read it as dynamic context. **Neither has a command hard-coded inside.**

To support a new stack you do not touch a skill or a hook: copy `_template.env`, fill in the 24
contract variables, write `<stack>.backend-standards.md`, and you are done. The full checklist of
places to touch is in [CONTRIBUTING.en.md](CONTRIBUTING.en.md).

| Adapter | Automatic detection | Ships |
|---|---|---|
| `adonisjs` | `package.json` with `@adonisjs/core` | env, backend-standards, Cursor rules, `ci.yml` |
| `laravel` | `artisan` + `composer.json` | same; FE React or Livewire (`--frontend`) |
| `fastify` | `"fastify"` in root or workspace-package `package.json` | same, plus `.dependency-cruiser.js`: hexagonal monorepo, Postgres+pgvector in CI, reversible migrations |
| `_template` | any other case | blank env and standards, commented to fill in |
| UI `react` / `livewire` | `--frontend` or auto-detect | `frontend-standards.md` + `.github/workflows/frontend.yml` + `tests/a11y/smoke.example.*` |

---

## The 9 hooks

This is the difference between a written convention and a convention that is enforced.

| Event | Script | What it guarantees |
|---|---|---|
| `SessionStart` | `session-context.sh` | Injects branch, active changes, tasks, commands, and pointers to `project-context` |
| `UserPromptSubmit` | `block-secrets.sh` | No credential enters the prompt |
| `PreToolUse` Read | `block-secret-reads.sh` | `.env` / credentials / private keys are not read into context |
| `PreToolUse` Bash | `block-dangerous-bash.sh` | Mass deletes, `push --force`, production, confirmation before installing dependencies |
| `PreToolUse` Bash | `docs-gate.sh` | No schema or contract change is committed with documentation untouched |
| `PreToolUse` Edit | `protect-specs-and-tests.sh` | Creating specs is fine; rewriting them asks; applied tests and migrations need confirmation |
| `PostToolUse` | `post-edit-quality.sh` | Format, static analysis, layer guards, and English-only notice (no `eval`) |
| `PostToolUse` | `validate-tasks.sh` | A `tasks.md` without Step 0, without `BRANCH_PREFIX`, or without mandatory steps fails |
| `Stop` | `verify-tests.sh` | The turn does not close with the suite in red (documented escape hatch for spikes) |

---

## Requirements

| Requirement | What for | If missing |
|---|---|---|
| `node` ≥ 20.19 | OpenSpec, the hook launcher (`invoke.cjs`), and `npx` for MCPs | OpenSpec does not install; on Windows hooks may fall back to WSL; Context7/Playwright do not start |
| `bash` | Run the `.sh` scripts. On Windows, Git for Windows provides it | Hooks do not run |
| `jq` | Parse the JSON hooks receive | They disable themselves without breaking the session |
| `git` | Session context and migration protection | Partial degradation |

On Windows: `winget install jqlang.jq`.

---

## Documentation

### Where to start (recommended order)

1. **[STEP-BY-STEP.md](STEP-BY-STEP.md)** — get started: prerequisites, install, OpenSpec, doctor, troubleshooting (Windows/Unix).
2. **[USAGE.md](USAGE.md)** — what to run on day 1, what on each ticket, and common problems.
3. **Once you are working:** [MANUAL.en.md](MANUAL.en.md) (flow F0–F8, artefact matrix, rules) + [PROMPTS.en.md](PROMPTS.en.md) (prompts P0–P15 ready to paste).
4. **Only if you need the fine procedure of one tool:** that skill’s `SKILL.md` under [`core/ai-specs/skills/`](../../core/ai-specs/skills/) (or, after install, `ai-specs/skills/<name>/SKILL.md` in your project). Same for agents under [`core/ai-specs/agents/`](../../core/ai-specs/agents/).

### Document index

| Document | Español | English |
|---|---|---|
| Setup | [GUIA-PASO-A-PASO.md](../es/GUIA-PASO-A-PASO.md) | [STEP-BY-STEP.md](STEP-BY-STEP.md) |
| Day-to-day use | [USO.md](../es/USO.md) | [USAGE.md](USAGE.md) |
| Manual (F0–F8) | [MANUAL.md](../es/MANUAL.md) | [MANUAL.en.md](MANUAL.en.md) |
| Prompts P0–P15 | [PROMPTS.md](../es/PROMPTS.md) | [PROMPTS.en.md](PROMPTS.en.md) |
| Config / adapters | [CONFIG.md](../es/CONFIG.md) | [CONFIG.en.md](CONFIG.en.md) |
| End-to-end example | [EJEMPLO.md](../es/EJEMPLO.md) | [EXAMPLE.md](EXAMPLE.md) |
| Product briefing | [presentacion.md](../es/presentacion.md) | [presentation.md](presentation.md) |
| Changelog | [CHANGELOG.md](../es/CHANGELOG.md) | [CHANGELOG.en.md](CHANGELOG.en.md) |
| Contributing | [CONTRIBUTING.md](../es/CONTRIBUTING.md) | [CONTRIBUTING.en.md](CONTRIBUTING.en.md) |
| Credits | [CREDITS.md](../es/CREDITS.md) | [CREDITS.en.md](CREDITS.en.md) |

---

## Language

Skills, agents, standards, and templates are **in English**, because `base-standards.md` §2 requires
English in every technical artefact and the agent cannot read a rule in English and an instruction
in Spanish without inconsistency.

Human documentation —[`README.md`](../../README.md) at the root, Spanish under
[`docs/es/`](../es/), English under [`docs/en/`](.) (including this English README, setup guide,
usage, the manual, prompts, config, the example, the Product briefing, the changelog, contributing,
and credits)— is **in Spanish and in English**, paired. Pick the language in each document’s top
bar or in the table above. Prompts in [PROMPTS.en.md](PROMPTS.en.md) are pasted in English; the
artefacts they produce (code, specs, commits) remain in English.

---

## What this kit does NOT do

- **It does not replace your judgement.** There are five points where it stops and waits for a human.
- **It does not guarantee quality.** It guarantees that certain concrete mistakes do not go unnoticed:
  tests quietly rewritten, specs overwritten, secrets in context, mixed layers, `tasks.md` without
  verification, suites in red when the turn closes.
- **It does not know your domain.** Everything it knows is in `docs/project-context.md` and in
  `sdd-harness.env`. What you do not write there, the agent will invent.
- **It does not install OpenSpec.** That is a separate step, on purpose: `openspec/` is governed by
  that tool, and the kit does not write inside it except for its templates.
- **It does not install Context7 or Playwright as repo dependencies.** It leaves the MCP config
  (`npx`); the first use downloads them. Playwright MCP demonstrates UI; it does not replace the
  E2E suite.

---

## Origin

This kit comes from the class notes of the **AI4Devs Master at [LIDR Academy](https://lidr.co)**
and takes as a starting point ideas and conventions from
**[`LIDR-academy/lidr-specboot`](https://github.com/LIDR-academy/lidr-specboot)** (MIT), the
master’s reference repository: the `ai-specs/` layout with skills and subagents as canonical source,
standards in `docs/`, and the per-copilot memory files —`CLAUDE.md`, `AGENTS.md`— pointing to a
single doctrine.

What this kit adds on top of that starting point:

| Addition | What it solves |
|---|---|
| **Installable** (`install.sh` / `install.ps1`, with `--dry-run`) | Not building the harness by hand on every new project |
| **9 deterministic lifecycle hooks** | A written convention becomes an enforced one. They act on the file path, not on which command wrote it |
| **Per-stack adapters** with automatic detection | The same artefacts work for Laravel, AdonisJS, or Fastify without touching a skill or a hook |
| **Real Windows support** | First-class PowerShell, copy when the OS does not allow symlinks |
| **`doctor`** (`doctor.sh` / `doctor.ps1`) | Diagnose an install instead of guessing why it fails |
| **Deep secret gates** | Blocking in the prompt and on file reads, not only at commit |
| **29 skills and 9 subagents** | The TDD trilogy with isolated context per phase, `/adversarial-review`, `/migration-review`, `/architecture-audit`, `/privacy-ethics-check`, `/kit-health` |

The design, the tuning, and everything above are original work. The debt to `lidr-specboot` is
architecture and conventions, and it is declared here and in [CREDITS.en.md](CREDITS.en.md).

## Licence

[MIT](../../LICENSE).
