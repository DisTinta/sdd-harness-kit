# `sdd-harness.env` reference

**Language:** [Español](CONFIG.md) · English

The kit's configuration contract. It is the only file that changes between projects: hooks load it
safely at startup (key allowlist, no `source` or `eval` of the file) and skills read it as dynamic
context.

How it sits relative to the other configuration files:

| File | Contains | Who writes it |
|---|---|---|
| `.claude/sdd-harness.env` | Commands, paths, and guards, as variables | The adapter; you adjust it |
| `.mcp.json` · `.cursor/mcp.json` | Project MCP servers (Context7, Playwright; optional Figma) | The kit. No secrets |
| `docs/project-context.md` | The same thing in prose, plus gotchas, for the model to read | **You** |
| `docs/backend-standards.md` | Stack layers and conventions | The adapter; you adjust it |
| `docs/base-standards.md` | Invariant doctrine | The kit. Do not edit per project |

Yes, commands appear in two places. On purpose: the `.env` makes them executable by hooks, and the
prose context makes them readable by the model. If you change one, change the other.

Format: `KEY="value"` on a single line. No commands, no substitutions, no backticks. The `lib.sh`
loader only accepts allowlisted keys; lines with `$(...)` or backticks are ignored with a warning.

**If a value does not apply to your project, leave it empty.** The kit degrades, it does not break:
a hook without a configured command exits with code 0 and stays out of the way.

---

## Commands

| Variable | How it is invoked | Who uses it |
|---|---|---|
| `CMD_TEST` | as-is | Hook `verify-tests` (Stop), session context, skills |
| `CMD_TEST_FILTER` | `$CMD_TEST_FILTER "<pattern>"` | TDD skills, `openspec-implement` |
| `CMD_LINT` | as-is | Session context, skills |
| `CMD_FORMAT_FILE` | `$CMD_FORMAT_FILE "<path>"` | Hook `post-edit-quality`, silently |
| `CMD_STATIC_FILE` | `$CMD_STATIC_FILE "<path>"` | Hook `post-edit-quality`; its output returns to the agent |
| `CMD_STATIC` | as-is | Session context, skills |
| `CMD_MUTATION` | as-is | Triangulation prompt (P10) |
| `CMD_DOCS_COVERAGE` | as-is | Documentation prompt (P13) |
| `CMD_DEV` | as-is | `docs/project-context.md` template |
| `CMD_MIGRATE` | as-is | `docs/project-context.md` template |

> **Watch out for `CMD_TEST`.** The `Stop` hook runs it at the end of every turn in which code was
> touched. If the command is slow or does not exist, you will block every turn. Try it by hand
> before leaving it set.

---

## Paths

| Variable | Purpose |
|---|---|
| `SOURCE_EXTENSIONS` | Source code extensions, space-separated and without a leading dot (`ts tsx`, `php`, `py`). Filters which files the quality hook analyzes |
| `PATH_SOURCE` | Root of production code. The `Stop` hook checks whether there are changes here |
| `PATH_TESTS` | Tests directory. The protection hook asks for confirmation before modifying ones that already exist |
| `PATH_BUSINESS` | Business-logic layer. Where `GUARD_HTTP_IN_BUSINESS` applies |
| `PATH_HTTP` | Transport layer. Where `GUARD_DB_IN_HTTP` applies |
| `PATH_MIGRATIONS` | Migrations. Empty if the project has none. Already versioned ones stay protected |
| `PATH_ADR` | Decision record. Defaults to `docs/adr` |

Branch variables and escape hatches:

| Variable | Purpose |
|---|---|
| `BRANCH_PREFIX` | Branch prefix that `validate-tasks` **requires** in Step 0. Defaults to `feature/` |
| `KIT_ALLOW_WIP` | `1` = the Stop hook does not block on a red suite (local spikes only; remove before the PR) |
| `KIT_SKIP_STOP_TESTS` | `1` = does not run the suite on Stop |

**File safety:** the env is never `source`d or `eval`ed. Only allowlisted keys in `KEY="value"`
format are accepted. Lines with `$(...)` or backticks are ignored with a warning.

Paths are relative to the repository root and compared by segment prefix, so
`app/services` matches `app/services/x.ts` and `backend/app/services/x.ts`.

---

## Who consumes this configuration

The kit's **nine** hooks. None of them has a command hard-coded inside:

| Hook | Variables it uses |
|---|---|
| `session-context` | `STACK`, `CMD_*`, `LAYER_ORDER`, `PATH_BUSINESS`, `BRANCH_PREFIX` |
| `block-secrets` | none (universal patterns in the prompt) |
| `block-secret-reads` | none (secret path patterns) |
| `block-dangerous-bash` | `GUARD_DANGEROUS_CMD`, `STACK` |
| `docs-gate` | `PATH_MIGRATIONS`, `PATH_HTTP`, `SOURCE_EXTENSIONS` |
| `protect-specs-and-tests` | `PATH_TESTS`, `PATH_MIGRATIONS` |
| `post-edit-quality` | `SOURCE_EXTENSIONS`, `CMD_FORMAT_FILE`, `CMD_STATIC_FILE`, `PATH_BUSINESS`, `PATH_HTTP`, both guards |
| `validate-tasks` | `BRANCH_PREFIX` + checklist from `openspec-tasks-mandatory-steps.md` |
| `verify-tests` | `CMD_TEST`, `PATH_SOURCE`, `PATH_TESTS`, `PATH_ADR`, `KIT_*` |

The skills that depend on this configuration to run something benefit the most:
`/openspec-implement`, `/tdd-red`, `/tdd-green`, `/tdd-refactor`, `/feature-slice`, `/show-spec-working`,
`/adversarial-review`, `/code-auditing`, `/privacy-ethics-check`, `/kit-health`.

And all 24 in general, through the dynamic context that opens almost every one:

```
## Project configuration
!`grep -vE '^\s*#|^\s*$' .claude/sdd-harness.env`
```

A single Bash command (no pipes or `&&`): Claude Code aborts the skill if dynamic context
`!`…`` contains multiple operations. Skills that use it must include `Bash(grep *)` in
`allowed-tools`.

That line is what makes the same skill work on AdonisJS, on Laravel, and on a stack the kit does
not know yet.

---

## Architecture guards

Extended regular expressions (`grep -E`). They are the part of the kit that turns a convention
written in `docs/backend-standards.md` —which the model can ignore— into a deterministic check.

| Variable | Applies to | What it detects |
|---|---|---|
| `GUARD_HTTP_IN_BUSINESS` | files under `PATH_BUSINESS` | That the business layer imports the transport |
| `GUARD_DB_IN_HTTP` | files under `PATH_HTTP` | That the transport layer queries the database or uses the request without validating |
| `GUARD_DANGEROUS_CMD` | Bash commands | Destructive commands specific to the stack. Added to the kit's universal list |

When a guard fires, the hook returns control to the agent with the reason. It does not block the
write —the file is already on disk— but the agent cannot continue without fixing it.

**How to write a guard that does not produce false positives:** start with the most specific pattern
you can. A guard that misses some cases is better than one that fires on every file: if it always
fires, the team turns it off and you are left with none.

Try it before leaving it set:

```bash
grep -nE "$GUARD_HTTP_IN_BUSINESS" app/services/*.ts   # should return nothing
```

### The English-only notice

`post-edit-quality` includes a heuristic language check, because `base-standards.md` §2 requires
English in every technical artifact. The word list is in `SPANISH_WORDS`, inside
`.claude/hooks/lib.sh`, not in `sdd-harness.env`, because it does not depend on the stack.

It requires **two distinct words** before warning, and **warns instead of blocking**: the false-
positive risk is real and blocking on it would be worse than the problem. If it bothers you, edit
the list or empty the variable.

---

## Conventions

| Variable | Purpose |
|---|---|
| `LAYER_ORDER` | The order in which files are touched when implementing a vertical slice. Skills enforce it and the session context reminds you of it |
| `MIN_MUTATION_SCORE` | Mutation score threshold on critical paths. Defaults to 70 |
| `STACK` | Informational identifier. Appears in the session context |

---

## Writing a new adapter

To support a stack the kit does not ship, **do not touch any skill or any hook**. You only need
four files under `adapters/`, and only the first is mandatory.

### 1. `<stack>.env` — mandatory

```bash
cp adapters/_template.env adapters/mi-stack.env
```

Fill in the variables. Verify each command by running it by hand in a real project before writing
it down.

### 2. `<stack>.backend-standards.md` — strongly recommended

The layers-and-conventions document that the installer copies to `docs/backend-standards.md`. Start
from `_template.backend-standards.md` and answer five questions:

1. Where does business logic live, and where can it not live?
2. Where does every external input enter and get validated?
3. What must the business layer not know about?
4. How is output serialized, and what guarantees that an internal field does not leak?
5. In what order are files touched when implementing a vertical slice?

### 3. `<stack>.rules.mdc` — optional

The same conventions in Cursor rule format, with `globs` pointing at your paths. The installer
copies it to `.cursor/rules/30-stack.mdc`.

### 4. `<stack>.ci.yml` — optional

The reference pipeline. Copied to `.github/workflows/ci.yml`. Keep the kit's criterion: the hard
gate is the mutation score on critical paths, not a line-coverage percentage.

Tests and mutation are gated with `dorny/paths-filter@v4` **inside the same** `quality` job
(one required check; do not split jobs). Two filters:

- `runtime` — **broad** allowlist: any path that can change behaviour or the suite (code,
  routes, config, migrations, tests, lockfile, the workflow itself). Do not use only
  `app/**` + `tests/**`: on Laravel that misses `routes/`, `config/`, and `database/`.
- `business` — `PATH_BUSINESS` plus Infection/Stryker config and the lockfile. **No**
  `tests/**`: an HTTP test does not change mutants in the critical layer.

Lint and static analysis always run. On Laravel, PRs that do touch `business` run Infection
with `--git-diff-base` / `--git-diff-lines`; a push to `main` mutates the whole layer.

### 4b. Frontend

Per `--frontend` (`auto` | `react` | `livewire`) the installer copies:

- `docs/frontend-standards.md` — React or Livewire; with `--no-frontend`, the empty template.
- `.github/workflows/frontend.yml` — that UI's CI (omitted with `--no-frontend`).
- `tests/a11y/smoke.example.tsx` (React) or `tests/a11y/smoke.example.mjs` (Livewire), **only if it
  does not already exist** — the kit does not overwrite a scaffold you already customised (same as
  `infection.json`).

The scaffold is not the gate: the filename is not picked up by Vitest/Pest, and the kit **does not
edit** `package.json`. Until the team installs axe-core, renames the file, and adds the `test:a11y`
script, the workflow only warns. Wiring steps live in `docs/frontend-standards.md`.

### 5. Automatic detection — optional

If you want the installer to detect your stack on its own, add a branch to `detect_stack()` in
`install.sh` and to the equivalent block in `install.ps1`. Until then, it works with
`--stack mi-stack`.

### 6. Try it

```bash
./install.sh --dest /tmp/repo-de-prueba --stack mi-stack --dry-run
./install.sh --dest /tmp/repo-de-prueba --stack mi-stack

cd /tmp/repo-de-prueba
export CLAUDE_PROJECT_DIR=$PWD
echo '{"source":"startup"}' | bash .claude/hooks/session-context.sh
echo '{"tool_input":{"command":"rm -rf /"}}' | bash .claude/hooks/block-dangerous-bash.sh
echo '{"tool_input":{"file_path":"<un fichero que viole una guarda>"}}' | bash .claude/hooks/post-edit-quality.sh
bash .claude/sync-artifacts.sh --check
```

If all four return what you expect, the adapter is ready.

And check what is not automatic: that `docs/backend-standards.md` describes **your** architecture
and not that of the adapter you copied, because that file is what stops the agent from inventing a
different architecture on every task.

---

## Project MCP

The installer copies the same template to `.mcp.json` (Claude Code) and `.cursor/mcp.json` (Cursor):

| Template | When |
|---|---|
| `ai-specs/templates/mcp.json` | Default: Context7 + Playwright (`--isolated`) |
| `ai-specs/templates/mcp.context7-only.json` | `--no-frontend` / `-NoFrontend`: Context7 only |
| `ai-specs/templates/mcp.with-figma.json` | **Reference only — installer does not apply it**: Context7 + Playwright + Figma (`https://mcp.figma.com/mcp`) |

They start with `npx` (or remote HTTP for Figma) at the moment of use; the kit does not install
global packages. Playwright does not replace the project's E2E suite. Context7 does not replace
`docs/project-context.md`.

**Figma:** if the team designs in Figma, merge the `figma` entry from `mcp.with-figma.json` into your
`.mcp.json` / `.cursor/mcp.json`, or copy the whole template. The first connection prompts for OAuth
in the IDE. Do not put tokens in the JSON.

Do not put API keys in the JSON. If Context7 rate-limits you anonymously, export `CONTEXT7_API_KEY`
in the machine environment.

Jira, databases, or other connectors with secrets do not live here: each team adds them with
`claude mcp add` / the Cursor UI.

### Frontend UI (React vs Livewire)

The installer chooses `docs/frontend-standards.md` and `.github/workflows/frontend.yml` by UI:

| Flag | Effect |
|---|---|
| `--frontend auto` / `-Frontend auto` (default) | Detect: Livewire without React/Inertia → Livewire; else → React |
| `--frontend react` / `-Frontend react` | Force React standards + CI + `tests/a11y` scaffold |
| `--frontend livewire` / `-Frontend livewire` | Force Livewire standards + CI + `tests/a11y` scaffold |
| `--no-frontend` / `-NoFrontend` | Empty FE template; MCP without Playwright; no `frontend.yml` or a11y scaffold |

Laravel may be **Inertia/React** or **Livewire**; both are first-class. Adonis/Fastify use React
when frontend is enabled.

---

## Debugging

**A hook does nothing.** Check in this order: does `jq` exist? is the script executable? is the
variable it needs filled in `sdd-harness.env`? Try it by hand by piping JSON on stdin, as in the
examples above.

**Stop: `Hook JSON output validation failed`.** Claude Code no longer accepts `additionalContext` on
the Stop event. The green-suite reminder goes in `systemMessage` (`notify` in `lib.sh`). Blocking on
a red suite remains `{decision:"block",reason:…}`, which is still valid.

**A hook blocks too much.** The kit hooks distinguish between deny and ask for confirmation, and
between create and rewrite.
If something is denied and should not be, the responsible pattern is in `block-dangerous-bash.sh` or
in `protect-specs-and-tests.sh`; adjust it in your copy of the repository, not in the kit.

**Disable them all temporarily.** `{"disableAllHooks": true}` in the local configuration. You cannot
disable an individual hook: all or none.

**See what runs.** Start the session in debug mode and look for the hook execution lines in the log.

**`validate-tasks` rejects a `tasks.md` you believe is correct.** The message lists exactly which
condition fails. The most common ones: the first heading is not `## 0.`, the `(MANDATORY)` label is
missing, the manual verification step does not say `AGENT MUST EXECUTE`, or there are tasks that
mutate data and none mentions restoration. Full doctrine is in
`docs/openspec-tasks-mandatory-steps.md`.

**A skill does not load.** This is not a configuration problem: it is the canonical source.
`bash .claude/sync-artifacts.sh --check` tells you the state of each reference. `TEXTO` means a
materialized symlink; `DIVERGE`, that you edited the copy instead of `ai-specs/`. `KEEP` on an
`openspec-*` is OpenSpec (`openspec init`): leave it. `HUÉRFANO` on any other name is drift.

**MCPs do not show up as tools.** The installer copies `.mcp.json` (Claude Code) and
`.cursor/mcp.json` (Cursor) from `ai-specs/templates/mcp.json` (or `mcp.context7-only.json` if
`--no-frontend`). Figma only if you merge `mcp.with-figma.json` by hand. The doctor warns if they
are missing; it does not fail. You must enable them in the IDE the first time. Do not put API keys
in those JSONs: `CONTEXT7_API_KEY` goes in the environment.

**You edit a hook and nothing changes.** Hooks are copied into the repository on install: the one
that runs is `<your-repo>/.claude/hooks/`, not the kit's. Edit there for this project, and in the
kit if you want the change in future installs.
