# How to use

**Language:** [Español](USO.md) · English

> Start with [STEP-BY-STEP.md](STEP-BY-STEP.md) if this is your first setup.

## What runs and when

| Tool | Required? | When |
|---|---|---|
| The kit installer | **Yes** | Once per project |
| Complete `docs/project-context.md` | **Yes** | Once per project, by hand |
| `openspec init` + wire up `config.yaml` | **Yes** | Once per project, after the installer |
| `doctor.ps1` / `doctor.sh` | **Yes** | After installing and when something “doesn’t click” |
| Enable project MCP (Context7, Playwright) | Recommended | Once per machine/IDE; the installer already copies the JSON |
| `claude` (the session, no slash) | **Yes** | Every time you work |
| `bash .claude/sync-artifacts.sh` | When needed | After creating, renaming, or moving a skill |
| `/init` | **NO. Never in this repository** | It would break the doctrine. See below |
| `claude mcp add …` (Jira, DB, etc.) | Optional | Team connectors with secrets; they do not go in the kit |

---

## Day 1 · Prepare the project

Once per repository. Twenty minutes.

### 1. Install the kit

```powershell
cd <kit-path>\sdd-harness-kit
.\install.ps1 -Dest C:\proyectos\mi-api -DryRun    # first see what it would touch
.\install.ps1 -Dest C:\proyectos\mi-api            # install
.\doctor.ps1 -Dest C:\proyectos\mi-api
```

```bash
./install.sh --dest ~/proyectos/mi-api --dry-run
./install.sh --dest ~/proyectos/mi-api
bash ./doctor.sh --dest ~/proyectos/mi-api
```

It detects the stack, copies `ai-specs/` and the hooks, writes the doctrine into `docs/`, applies the adapter,
generates `docs/project-context.md` with the commands already filled in, and links `.claude` and `.cursor` to
`ai-specs`.

At the end it will say **`enlazados N · copiados N`**. If it says «copiados», your system does not allow symlinks and
the kit has made copies: it works the same, but remember to always edit `ai-specs/` and run
`sync-artifacts` to propagate.

### 2. Initialize OpenSpec

```bash
node -v                                 # you need 20.19 or higher
npm install -g @fission-ai/openspec
cd C:\proyectos\mi-api
openspec init                           # pick Claude Code, Cursor, etc.
```

**After the kit, not before.** The OpenSpec wizard detects folders that already exist and only
adds its own pieces. Check what it touched:

```bash
git status --short
git diff .claude/settings.json     # should be empty
```

The names do not collide: OpenSpec installs `/opsx:*` commands and the kit has its own. What each
installer creates:

| Path | Created by |
|---|---|
| `ai-specs/templates/openspec/` | the kit (reference templates) |
| `openspec/project.md`, `openspec/changes/`, `openspec/specs/` | `openspec init` |

The kit **installer** does not write inside `openspec/`: that directory is owned by the tool.
During day-to-day work it is written there, of course —that is where each change lives— and **it does not
matter who writes it**: `/opsx:propose` or prompt P5, `/opsx:apply` or `/openspec-implement`. The
`validate-tasks` and `protect-specs-and-tests` hooks act on the file path, not on which
command touched it, so the kit works the same if you use exclusively OpenSpec’s native commands
(`/opsx:explore`, `/opsx:propose`, `/opsx:apply`, `/opsx:sync`, `/opsx:archive`), exclusively the
kit’s, or a mix. The full correspondence table is in [MANUAL.en.md](MANUAL.en.md#1-the-nine-phase-flow).

### 3. Complete `docs/project-context.md`

The installer leaves the commands filled in. The remaining `{{...}}` markers are yours: what the
product is, how it is tested, branch conventions, and *gotchas*.

You can do it by hand or with **prompt P0** from [PROMPTS.en.md](PROMPTS.en.md), which explores the repository and
proposes the content while flagging what it had to infer.

Write it **in English**: `base-standards.md` §2 requires that for every technical artifact, and a hook will
warn you if it detects Spanish in the code.

> ⚠️ **Do not run `/init`.** The four memory files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`,
> `codex.md`) point to `docs/base-standards.md`. `/init` would write through them and wipe the
> doctrine. For project context use P0.

### 4. Adjust the stack standards

`docs/backend-standards.md` comes from the adapter and describes a concrete architecture. **If your project
does not follow it, adjust it now**: that file is what stops the agent inventing a different architecture
on every task.

Same with `docs/frontend-standards.md` if your frontend is not what the installer detected
(React vs Livewire): use `--frontend` / `-Frontend` or edit the file.

If there is a UI, the installer leaves `tests/a11y/smoke.example.*`. **It is not a test yet** and it
does not touch `package.json`. For CI to run accessibility: install axe-core, rename the file, and
add the `test:a11y` script (steps in `docs/frontend-standards.md`). Until then the workflow only warns.

### 5. Verify the configuration

```bash
cat .claude/sdd-harness.env
```

Check that **every command really exists** by running it by hand. The critical one is `CMD_TEST`: the
`Stop` hook launches it at the end of every turn in which you touched code. If it is slow or does not exist,
you will block all your turns. If your full suite takes minutes, point it at the fast part.

`CMD_STATIC` / `CMD_MUTATION` and the adapter’s `ci.yml` assume quality tools
(PHPStan, Infection, Stryker…) that a stock project **may not have**. The installer does not
add them. If the binary does not exist, do not leave it as a usable command: see [Common problems](#common-problems).

### 6. Review the hooks

```bash
ls .claude/hooks/
```

The 9 hooks run code with your permissions. Read them. And try them without opening a session, because they are scripts that read
JSON from standard input:

```bash
export CLAUDE_PROJECT_DIR=$PWD

echo '{"source":"startup"}' | bash .claude/hooks/session-context.sh | jq -r '.hookSpecificOutput.additionalContext'
echo '{"tool_input":{"command":"rm -rf /"}}' | bash .claude/hooks/block-dangerous-bash.sh
echo '{"tool_input":{"command":"git status"}}' | bash .claude/hooks/block-dangerous-bash.sh   # no output
```

### 7. Check that the skills load

Open the session (`claude`) and type `/`. You should see `/enrich-us`, `/tdd-red`, `/pr-review` and the
rest.

If they do not appear: **restart the session.** Claude Code hot-reloads skill changes,
but if the directory did not exist at startup you must restart. If they still do not appear, run
`bash .claude/sync-artifacts.sh --check`: the references are probably plain text files.

### 8. Enable the project MCPs

The installer leaves `.mcp.json` (Claude Code) and `.cursor/mcp.json` (Cursor) with **Context7** and, if you did not
use `--no-frontend` / `-NoFrontend`, **Playwright** in isolated mode. Frontend UI (React or Livewire)
is chosen with `--frontend auto|react|livewire` / `-Frontend …` (see [CONFIG.en.md](CONFIG.en.md)).

You do not need to write `use context7` in every prompt: the doctrine (`docs/base-standards.md` §11) already
tells the agent when to consult them. The first time the IDE usually asks permission to start the
project server: accept it. Optional: `CONTEXT7_API_KEY` in the environment (never in the committed
JSON) if you hit the anonymous rate limit.

If the team designs in Figma, there is a reference template
`ai-specs/templates/mcp.with-figma.json` (Context7 + Playwright + Figma). The installer does **not**
apply it: merge it by hand. Details in [CONFIG.en.md](CONFIG.en.md).

Jira, databases, or other connectors with secrets do **not** go here: `claude mcp add …` per team.

### 9. Commit the kit

```bash
git add ai-specs .claude .cursor .github docs CLAUDE.md AGENTS.md GEMINI.md codex.md .mcp.json
git commit -m "chore: add SDD Harness Kit"
```

It is committed on purpose: it is the team’s configuration. What is not committed is
`.claude/settings.local.json`, and the installer already adds it to `.gitignore`.

---

## Day 2 and beyond · The work cycle

### Prepare the ground

```
claude
```

The session hook has already injected branch, latest commit, active changes, pending tasks, and the
project commands. You do not need to spell that out.

### Phase 1 · From ticket to executable work

```
/enrich-us Filter the listing by state — the client downloads everything and filters in memory
```

It returns `## Original` and `## Enhanced`, with acceptance criteria in Given/When/Then, technical
context with real paths, and non-goals. **It is a draft.** Now your part: paste the story and run
**prompt P2** (poke-holes) so it looks for gaps. It will return ten or fifteen candidates; you keep
the real ones and **cut what was invented**.

That cut is the highest-leverage work in the whole cycle.

### Phase 2 · From story to contract

Clean context first (`/clear`). Optional before this: `/opsx:explore` (native) or the
`explorer` subagent/**prompt P4** (kit) if you still do not have a clear approach.

```
/opsx:propose "filter the listing by state"
```

It is exactly equivalent to **prompt P5** if you do not use OpenSpec, or if you want to control the
content yourself instead of leaving it to the command’s judgment.

Audit before approving:

```
Use the spec-auditor subagent on the proposal in openspec/changes/<id>/
```

It will also check that `tasks.md` complies with `docs/openspec-tasks-mandatory-steps.md`. And afterwards
**open it and edit it yourself**. This is the gate that makes the rest work.

### Phase 3 · Plan

`Shift+Tab` twice for plan mode and **prompt P7**. For complex features, delegate to
`backend-planner` or `frontend-planner`: they produce the plan in a file under `docs/plans/` and never
implement.

### Phase 4 · Implement

```
/openspec-implement <change-id>
```

Equivalent to native `/opsx:apply`, with the kit’s doctrine made explicit: it requires the
traceability table before coding and runs the verification steps itself. If you use `/opsx:apply`
instead, the same doctrine still applies —it lives in `CLAUDE.md`, not in the skill— and the hooks do not
distinguish which of the two wrote the file.

Walk the tasks in TDD. For fine control, the cycle in two turns:

```
/tdd-red the listing with an invalid state returns a validation error
/tdd-green tests/Feature/Tasks/ListTasksTest.php
/tdd-refactor app/Services/TaskService.php
```

Three turns, one per cycle phase, each with its own context. And there is a subagent per phase
(`tdd-test-writer`, `tdd-implementer`, `tdd-refactorer`) for when the task is large enough
that isolating context for real is worth it.

While you work, the hooks act on their own: if it tries to edit an existing test it asks for confirmation, if
it mixes layers it returns control, if it writes an incomplete `tasks.md` it rejects it, if it proposes installing
a package it asks you to verify it, and if it tries to close with the suite in red it cannot.

### Phase 5 · Demonstrate and verify

```
/show-spec-working <id>
```

This is the verification the harness marks as «AGENT MUST EXECUTE» and the one most often skipped: the
agent starts the services, exercises each scenario against the real system, restores state, and
delivers evidence. Not analysis: commands and responses.

Afterwards:

```
/verify-against-spec <id>
```

Read the third block, the one about unspecified behaviours. And before archiving, the hostile
review:

```
/adversarial-review <id>
```

It returns an explicit verdict: PASS, PASS WITH GAPS, or FAIL. Run it in a different session from the one that
implemented: an agent reviewing its own work inherits its own blind spots.

### Phase 6 · Document

```
/update-docs
/adr-new <decision title>
```

`/adr-new` applies the need criterion and will tell you if it does **not** apply. Listen to it.

### Phase 7 · Deliver

```
/pr-review
/commit
/pr-describe
```

`/commit` checks the documentation gate before committing, and the `docs-gate` hook checks it
again just in case. `/pr-describe` delivers the description with «Why?» empty and marked:
you fill it in.

### Phase 8 · Close

`/opsx:archive` after the merge —it will ask whether `/opsx:sync` is needed first to dump the delta
onto the main spec, and in that case it rewrites `openspec/specs/<capability>/spec.md`: the hook
lets it through after asking, same as with any other rewrite—. Afterwards, **prompt P15** for the
retro on the cycle data.

---

## Cheat sheet

```
Day 1, once per project
  install.ps1 / install.sh  →  openspec init  →  complete docs/project-context.md
  adjust docs/backend-standards.md  →  verify sdd-harness.env  →  enable MCP  →  commit the kit

Every ticket
  /enrich-us          →  P2 poke-holes            →  YOU CUT
  (/opsx:explore)  →  /clear  →  /opsx:propose  →  spec-auditor  →  YOU EDIT
  Shift+Tab ×2  →  P7 plan                        →  YOU APPROVE
  /tdd-red  →  WATCH THE TEST FAIL  →  /tdd-green  →  P10 triangulation
  /show-spec-working  →  /verify-against-spec  →  /adversarial-review
  /update-docs  →  /adr-new  →  /pr-review
  /commit  →  /pr-describe                        →  YOU WRITE THE WHY
  (/opsx:sync)  →  /opsx:archive       →  P15 retro

  Everything on the left with /opsx: has a kit equivalent (see table in MANUAL.en.md)
  and vice versa. You do not have to pick one for the whole project: decide per ticket.

When touching the kit
  edit ai-specs/  →  bash .claude/sync-artifacts.sh

Never
  /init in this repository
  accept the agent touching an existing test without looking at why
  leave verification block 3 undecided
  edit the docs/ doctrine per project (it is lost on update)
```

---

## The 27 skills

**Planning**
`/enrich-us` · `/dod-feature` · `/dod-bug` · `/dod-refactor` · `/dod-spike` · `/dod-docs` · `/meta-prompt`

**Implementation**
`/openspec-implement` · `/feature-slice` · `/tdd-red` · `/tdd-green` · `/tdd-refactor`

**Verification**
`/show-spec-working` · `/verify-against-spec` · `/adversarial-review` · `/pr-review` · `/code-auditing` · `/privacy-ethics-check`

**Documentation and delivery**
`/explain` · `/adr-new` · `/update-docs` · `/commit` · `/pr-describe`

**Kit maintenance**
`/writing-skills` · `/sync-agent-artifacts` · `/using-git-worktrees` · `/kit-health`

## The 9 subagents

`explorer` (cheap, read-only) · `tdd-test-writer` · `tdd-implementer` · `tdd-refactorer` ·
`spec-auditor` · `security-reviewer` · `backend-planner` · `frontend-planner` · `product-analyst`

The three `tdd-*` are the kit’s testing trilogy: one subagent per cycle phase, each with
isolated context.

---

## Common problems

**P0 or CI say that `phpstan` / `infection` (or Stryker, Typedoc…) are missing.** The adapter copies a
pipeline and reference `CMD_*` values; the installer **does not install packages**. A stock Laravel does not
ship PHPStan or Infection. Do not list them as commands in `docs/project-context.md`: put them under **Gotchas**.
Then decide: install the tools and align `project-context.md`, `sdd-harness.env`, and
`ci.yml`, or clear those variables and remove the steps. The three files must say the same thing.

**Skills do not appear with `/`.** Restart the session. If it persists:
`bash .claude/sync-artifacts.sh --check`. If it says `TEXTO`, the symlinks materialised as
files: run `sync-artifacts.sh` without `--check` and it will make copies that do work.

**Context7 or Playwright do not show up as tools.** The JSON files are in the repo, but the IDE has
to enable the project MCP (a toggle the first time). Restart the session. Playwright the
first time downloads the browser via `npx` and can take a while. Without frontend, it is normal that Playwright
is absent if you installed with `--no-frontend`.

**You edit a skill and the change does not apply.** Did you edit it in `.claude/skills/` instead of in
`ai-specs/skills/`? In copy mode they are different files. `sync-artifacts.sh --check` will tell you
`DIVERGE`; move your change to `ai-specs/` and sync.

**Sync marks `openspec-*` skills as `KEEP` (or, on an old kit, as orphans).** That is
expected after `openspec init`. They do not live in `ai-specs/`: they are OpenSpec’s `/opsx:*`
commands. **Do not delete them.** `KEEP` does not fail the sync. A real `ORPHAN` / `HUÉRFANO`
is another name (a kit skill that was renamed, or a copy only in `.claude/skills/`).

**All my turns take a long time to close.** It is the `Stop` hook running `CMD_TEST`. Point it at
the fast part of the suite.

**Stop: `Hook JSON output validation failed`.** The hook did run (if you see «Suite en verde», the tests
passed). Claude Code rejected the output JSON: Stop does not allow `additionalContext`. Update
`.claude/hooks/lib.sh` and `verify-tests.sh` from the kit (the reminder goes in `systemMessage`).

**The hooks do nothing.** Is `jq` installed? Without it they disable themselves. And `bash`? On Windows
Git for Windows brings it. The hooks do not invoke bare `bash`: `.claude/hooks/invoke.cjs` picks Git Bash
on Windows (otherwise PATH `bash` is often WSL and a different PHP from Laragon’s).

**Stop / Composer: `You are running 8.2` with a project that requires 8.3.** `CMD_TEST` is fine. The
`php` is the hook shell’s. On Windows, `invoke.cjs` must exist and `settings.json` must
launch it with `node`. Do not put Laragon paths in `sdd-harness.env`.

**`validate-tasks` rejects my `tasks.md`.** It is enforcing
`docs/openspec-tasks-mandatory-steps.md`: missing branch Step 0, some mandatory step, the
`(MANDATORY)` label, `AGENT MUST EXECUTE`, state restoration, or `N.M` numbering. The message
says which.

**The English-only warning fires on a file that is in English.** It is heuristic and allows false
positives; that is why it warns instead of blocking. If it bothers you, tune `SPANISH_WORDS` in
`.claude/hooks/lib.sh`.

**A hook blocks something it should allow.** The pattern is in `block-dangerous-bash.sh` or in
`protect-specs-and-tests.sh` in **your repository**. Adjust it there.

**Disable them all for a moment.** `{"disableAllHooks": true}` in `.claude/settings.local.json`. Either
all or none.

**The agent ignores design decisions.** Context has grown and the document got buried.
`/clear` and relaunch referencing the file explicitly. There is a rescue prompt at the end of
[PROMPTS.en.md](PROMPTS.en.md).
