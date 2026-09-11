# SDD Harness Kit Manual

**Language:** [Español](../es/MANUAL.md) · English

The workflow implemented by the kit’s artefacts, and why each piece sits where it sits.

This document is agnostic: it does not name any project or mandate any stack. What changes
across projects lives in `docs/project-context.md`, `docs/backend-standards.md`, and
`.claude/sdd-harness.env`.

The kit uses a canonical source in `ai-specs/`, doctrine in `docs/base-standards.md`, and the
memory files (`CLAUDE.md`, `AGENTS.md`) pointing to it.

Inventory: **29 skills**, **9 subagents**, and **9 hooks**. Skills and subagents are always edited
in `ai-specs/`; `.claude/` and `.cursor/` reference them, and `bash .claude/sync-artifacts.sh`
rebuilds those references when they stop resolving.

---

## 1. The nine-phase flow

The kit organises work into a stable sequence of phases spread
across modules. Reconstructed, it looks like this.

```
F0  HARNESS          Prepare the machine before asking it for anything
     └─ 3 pillars (tool · context · prompt) · project-context.md · autonomy level
F1  PLANNING         Turn intention into executable work                          ◆ gate
     └─ story with INVEST → acceptance criteria in GWT → non-goals → estimation
F2  SPECIFICATION    Turn the story into a contract                               ◆ gate
     └─ proposal + delta spec + design decisions + tasks
F3  ARMING           Install the session’s deterministic rails
     └─ skills · subagents · hooks · MCP · plan mode
F4  EXECUTION        Explore → Plan → Execute, task by task, in TDD               ◆ gate
     └─ red → green → refactor
F5  VERIFICATION     Prove that what was done is what was specified
     └─ static + tests + break the test on purpose + mutation on critical paths
F6  DOCUMENTATION    Leave a trail that does not drift out of sync
     └─ ADR · generated API contracts · code documentation
F7  DELIVERY         Sign off the work                                            ◆ gate
     └─ atomic commits · PR with what/why/how to test · review
F8  CLOSURE          Close the loop and learn
     └─ archive the change · metrics by PR origin · retro with data

CROSS-CUTTING: ethics, privacy, and security across all nine phases
```

**Two paths, one outcome.** F2 and F4 have two equivalent ways to run: native OpenSpec
commands (`/opsx:*`, installed by `openspec init`) or the kit’s artefacts. Use whichever
you prefer, mix them across tickets or even within the same ticket — the doctrine in `docs/` and the
9 hooks do not distinguish one from the other, because they act on the file path, not on who
wrote it.

| Phase | Native OpenSpec path | Kit path |
|---|---|---|
| Explore | `/opsx:explore` | Subagent `explorer`, or **prompt P4** |
| Specify | `/opsx:propose` (or `/opsx:new` + `/opsx:continue`/`/opsx:ff`) | **Prompt P5** — «also works without OpenSpec» |
| Audit the proposal | — | Subagent `spec-auditor`, or **prompt P6** |
| Implement | `/opsx:apply` | `/openspec-implement`, or the `/tdd-red` → `/tdd-green` → `/tdd-refactor` cycle |
| Reconcile delta → main spec | `/opsx:sync` | — (not needed: `/openspec-implement` does not touch `specs/`) |
| Verify | `/opsx:verify` (extended workflow) | `/show-spec-working`, `/verify-against-spec`, `/adversarial-review` |
| Close | `/opsx:archive` | — |

> OpenSpec's default profile ships `/opsx:explore`, `/opsx:propose`, `/opsx:apply` and
> `/opsx:archive`. The `/opsx:new`, `/opsx:continue`, `/opsx:ff` and `/opsx:verify` commands belong to
> the **extended** profile: enable them with `openspec config profile` and `openspec update`. If your
> install does not have them, use the kit path in the right-hand column.

What does **not** change between the two paths: `validate-tasks` still requires step 0 and the
mandatory steps in any `tasks.md`, `protect-specs-and-tests` still prompts on any rewrite of an
artefact that already exists (whether `/opsx:apply` is fixing its own work or you do it by hand),
and `session-context` reads `openspec/changes` without asking who created them.

### F0 · Harness

Before the first line of prompt you must decide three independent things, the **three pillars**:

| Pillar | What it controls |
|---|---|
| **Tool** | Which model, which tools it has, how it integrates, which flows it supports |
| **Context** | What information the model has in its window when it responds |
| **Prompt** | How you formulate the task, which success criteria you give, which constraints you set |

> «All three matter equally — if you neglect one, the others do not compensate.»
> The most common bottleneck is not the tool, but the context the model receives.

**Tools and artefacts by surface:** one body of rules, several readings.
`docs/base-standards.md` is read by Claude Code and Cursor through `CLAUDE.md` and `AGENTS.md`;
Cursor adds `.cursor/rules/`; Copilot, `.github/copilot-instructions.md`.

**What the kit installs in this phase:** the doctrine in `docs/`, the memory files
pointing to `docs/base-standards.md`, Cursor rules, and Copilot instructions. Several
surfaces, one single source of truth.

**What you have to do:** write `docs/project-context.md`. Under 200 lines, and only what
the agent cannot infer by reading the code:

- Non-trivial build, test, and run commands.
- Internal conventions: where each thing lives, how it is named, which pattern pieces follow.
- Operational constraints.
- *Gotchas*: what is not obvious and bites.

And what does **not** go there: the directory tree (raises inference cost without improving success
rate), architecture documentation (belongs in `docs/`), and human onboarding (belongs in the README).

Pruning test, line by line: *«Would it cause an error if I remove it?»*. If not, remove it.

**Context threshold you must internalise:** below 50 % green zone; between 50 and
70 % it is wise to compact; above 70 % reset is mandatory. Compact or restart every 15–20
turns in an agentic session.

### F1 · Planning

> «Before: a human developer reads it and completes the missing context with questions in the daily.
> Now: a copilot reads it and fills the missing context by **inventing**, and then a human
> reviews what was invented. The cost of ambiguity multiplied.»

Three non-negotiable rules when the executor is an agent:

1. The right prompt level is the **story**, not the epic. Granularity of 1–2 days
   human-equivalent.
2. Tasks are agent artefacts, not human artefacts.
3. Acceptance criteria are the only defence against *false completeness*.

**Entry filter: INVEST.** Any story that fails two or more of the six criteria goes back to
refinement, no negotiation. *AI does not rescue vague stories: it amplifies them.*

**Pattern for writing acceptance criteria — «AI as poke-holes»:**

1. The human writes the happy path: four to six bullets, three minutes.
2. Pass the story to the copilot asking for edge cases, implicit assumptions, missing
   scenarios, and unmentioned dependencies.
3. It returns ten or fifteen candidates. Most are noise; you keep the three or five real ones.
4. Refinement discusses the gaps; it does not read the story out loud.

> «Never accept the copilot’s acceptance criteria without human review against the real
> system. Treat them as a first draft, never as a deliverable.»

**Document order:** story → criteria → technical context. The agent reads top to bottom; if
you put technique first, it decides on implementation before understanding the problem. And at the end,
always, the **non-goals**: without explicit limits the agent over-optimises and over-refactors.

**Estimation:** story points for the sprint, t-shirt sizes for the roadmap, hours only
for external reporting. AI participates as one more peer in planning poker: estimates privately, then
everyone reveals at once; no averaging. And a **30–40 % buffer, not 10 %**, for the four taxes that
working with agents introduces: verification, quality, tool churn, and model
instability.

**Kit skills:** `/enrich-us`, `/dod-feature`, `/dod-bug`, `/dod-refactor`, `/dod-spike`,
`/dod-docs`.

### F2 · Specification

> «The spec is the memory AI needs to build what you wanted, not what it
> improvised.» · «When something disagrees between code and spec, the spec wins.»

The unit of specification is the **delta**: not the full system specification, but the diff
applied on top of it. The equivalent of a Git commit, but for requirements.

Four artefacts per unit of work:

| File | What it contains | Who reads it |
|---|---|---|
| `proposal.md` | The business why and the scope | Human + AI |
| `specs/<capability>/spec.md` | Requirements in RFC-2119 and scenarios in GIVEN/WHEN/THEN | AI, reviewers |
| `design.md` | Technical decisions already closed | AI, so it does not improvise architecture |
| `tasks.md` | Actionable checklist. One task, one agent turn | AI |

**Task size rule:** «Each task must be small enough to run in
a single AI turn. If a task is *implement the full auth system*, split it. If it is
*create the database table*, it is perfect.»

**When NOT to use all of this:** exploratory prototypes, one-off scripts, spikes under
two hours, trivial fixes where the change is obvious. Specifying has a cost; that is what
the criterion is for.

**Kit templates:** `ai-specs/templates/openspec/`. **Skills:** `/openspec-implement`.
**Subagent:** `spec-auditor`. **Hook:** `validate-tasks` rejects a `tasks.md` without the mandatory
steps from `docs/openspec-tasks-mandatory-steps.md`.

### F3 · Arming

Any modern copilot reduces to **seven primitives**:

| # | Primitive | What it is used for in this flow |
|---|---|---|
| 1 | Persistent memory | `docs/base-standards.md` (doctrine) + `docs/project-context.md` (facts) |
| 2 | Skills | Invocable reusable procedures |
| 3 | Subagents | Isolate context: explore without contaminating the session |
| 4 | Plan mode | Read-only dry-run with a human gate |
| 5 | Hooks | Invariants: «they are not interpreted, they are executed» |
| 6 | MCP | Context7 (library docs) and Playwright (UI demo). Each team adds Jira/DB |
| 7 | Output styles | Session personality |

MCP **is not a hook**: the model decides when to invoke it. That is why the doctrine (`base-standards.md` §11) and
the skills say *when* to use Context7 and Playwright, and you do not need to write `use context7` in
every prompt. If the server is down, the agent must say so and continue — not invent the API.

The allocation rule that runs through the whole kit:

> **Fact → memory. Procedure → skill. Critical invariant → hook.**
>
> «What lives in CLAUDE.md is *interpreted* by the model (it can fail). What lives in hooks is
> *executed* by code (it fails never or always, but it is deterministic). For security and
> compliance, always hooks.»

And its corollary, which saves context: if a hook already guarantees something, **do not repeat it in the prompt**.
«The prompt occupies context. The hook already does the work. You are paying twice for the same
guarantee.»

### F4 · Execution

**Explore → Plan → Execute pipeline:**

| Phase | Permissions | Model | Extra |
|---|---|---|---|
| Explore | Read-only | The cheapest | In a subagent, so as not to contaminate context |
| Plan | Read-only | The best available | **Human gate here** |
| Execute | Edit and run | Balanced | `PreToolUse` and `Stop` hooks active |

**When to enter plan mode:**

```
Does the task touch more than 3 files?
├── Yes → PLAN MODE
└── No → Does it have side effects (database, deploy, deletions, secrets)?
           ├── Yes → PLAN MODE + PreToolUse hooks
           └── No → Do you know the code area well?
                      ├── No → PLAN MODE
                      └── Yes → Is it a one-off fix, formatting, or a log?
                                 ├── Yes → direct agentic
                                 └── No → PLAN MODE
```

Inside Execute, the cycle for each task is **TDD adapted to agents**:

| Phase | With agent | Subagent |
|---|---|---|
| 🔴 Red | The developer writes or co-creates the test and **always reviews it**. Confirms it fails | `tdd-test-writer` |
| 🟢 Green | The **agent implements** the minimum code. Returning a fixed value is allowed | `tdd-implementer` |
| 🔵 Refactor | The agent proposes, the developer reviews. Tests are the safety net | `tdd-refactorer` |

**One subagent per phase, and not for the sake of symmetry.** The agent that just fought to get a
test green carries every justification it used to get there; refactoring with that context
in the room is exactly how a «improvement» changes behaviour without anyone noticing. Clean
context in each phase is why the cycle works with agents.

> **Golden rule:** «The test (or at least the acceptance criterion) must be human-authored or under
> explicit human supervision. Implementation may be delegated to AI. **Never the other way around.**»
>
> «Never allow the agent to modify your tests without explicit review. Protect tests as
> if they were the client’s signed specification — because they are.»

**Skills:** `/tdd-red`, `/tdd-green`, `/feature-slice`, `/openspec-implement`.
**Subagents:** `explorer`, and the TDD cycle trilogy —`tdd-test-writer`, `tdd-implementer`,
`tdd-refactorer`— each with isolated context for its phase.
**Hooks:** `protect-specs-and-tests`, `post-edit-quality`, `verify-tests`.

### F5 · Verification

Four gates, in order of rising cost:

1. **Static analysis always on.**
2. **Test suite**, shaped like a trophy: static → unit → **integration, the highest
   return** → e2e only on critical flows.
3. **Break the test on purpose.** «Before trusting an AI-generated test, break it: change the
   function’s return, invert a condition. If the test still passes, it is useless.»
4. **Mutation testing on critical paths** (authentication, payments, validations). Realistic
   target: 70 %. There are published cases with 100 % coverage and a 4 % mutation score.

Coverage is a signal, not a goal: «requiring a mandatory 90 % manufactures empty tests».

**And the gate most often skipped:** verification is run by the agent, not the user. Starting
services, exercising each scenario against the real system, restoring state, and leaving the report is
work, not documentation. `docs/openspec-tasks-mandatory-steps.md` requires it and the
`validate-tasks` hook checks that `tasks.md` contemplates it.

**Skills:** `/show-spec-working` (execution evidence), `/verify-against-spec` (conformance),
`/adversarial-review` (hostile review with a verdict), `/migration-review`, `/architecture-audit`,
`/pr-review`, `/code-auditing`.
**Subagent:** `security-reviewer`.

### F6 · Documentation

Four layers, each with its own lifecycle and generator:

| Layer | Artefact | Cycle |
|---|---|---|
| Architecture | ADR + diagrams | Slow: months |
| API | Contract generated from code | Medium: weeks |
| Code | Documentation on the symbol itself | Fast: days |
| Operations | Runbooks, deployment | Medium |

> «Code is the source of truth. The tool only turns it into something readable — you never
> write the documentation by hand and then the code separately.»
> «AI generates the draft; the human validates the semantics. Form is cheap; meaning is not.»

**Criterion for writing an ADR:** «If this developer joined the project today and saw this code,
would they ask *why did they do it this way*?». And two more conditions: that it affects more than one module and
that reverting it costs more than a day. If they are not met, a comment is enough. Padding ADRs are
as harmful as their absence.

File name: `YYYYMMDD-slug.md`. Never manual sequential numbering: it collides when there are
concurrent branches.

**Skill:** `/adr-new`. **Templates:** `docs/adr/_template.md`.

### F7 · Delivery

- **Conventional commits**, atomic, in present imperative, first line 72 characters.
  If there is a ticket, the scope **is the id**: `feat(KAN-184): add listing filter by state`. Branch:
  `feature/KAN-184-filter-listing`. If there is no ticket, the scope is the capability or the layer; the
  agent asks before committing.
- **PR with the three mandatory questions:** what changes? · why? · how to test it? The «what»
  is generated by AI from the diff; the «how to test» partly; **the «why» and the decisions are not**.
- **Automatic review** in the pipeline, plus human review on top. Never only the first.
- Label each PR with its origin: `human`, `human+copilot`, `agent`, `agent+human-review`.

> «The agent can open the PR, but you sign the merge.»

**The five golden rules of Git with AI:**

1. Review the diff before accepting any AI-generated commit.
2. Never let an agent run `git push --force` without human confirmation.
3. Strict CI gate: block the merge if tests, security, or static analysis fail.
4. Label auto-generated PRs.
5. Connectors in read-only mode for review; never write to production without a human.

**Skills:** `/commit`, `/pr-describe`, `/pr-review`.

### F8 · Closure

- **Archive the change.** «Archiving is not optional. If you leave active changes unarchived, the
  next proposals will not have the correct context of what is already implemented.»
- **Measure by segmenting on PR origin**: velocity, bugs per PR, time to merge, rework
  rate. «If agents have three times more bugs, velocity is lying.»
- **Retro with AI as a data source, not as a facilitator.** And always at team or
  process level, **never individual**: that is noise, bias, and it breaks trust.

### Cross-cutting · Ethics, privacy, and security

- **Tool plan:** for professional use, enterprise plan or API. Never consumer
  interfaces for company code or data: the data policy is radically different even when
  the brand is the same.
- **AI-suggested dependencies:** verify them in the official registry before installing. Nearly one
  in five packages models recommend does not exist, and attackers register those
  names.
- **Secrets:** never in context, never in files the assistant can read.
- **Personal data:** de-identify before the prompt leaves your network; impact
  assessment if there is large-scale processing; processing agreement with the provider.
- **Generated code:** around 45 % of AI-generated code introduces OWASP Top 10
  vulnerabilities. Security analysis in the pipeline is not optional.

**Hooks:** `block-secrets`, `block-dangerous-bash`. **Subagent:** `security-reviewer`.

---

## 2. Kit artefact matrix

| Artefact | Path | Phase | What it guarantees |
|---|---|---|---|
| `docs/project-context.md` | `docs/` | F0 | That the agent knows what it cannot deduce from the code |
| `docs/base-standards.md` + 4 symlinks | root and `docs/` | F0 | The doctrine, on all four agent surfaces |
| `docs/backend-standards.md` | `docs/` | F0 | The concrete layers of the stack |
| `docs/openspec-tasks-mandatory-steps.md` | `docs/` | F2 | What a valid `tasks.md` must contain |
| `.cursor/rules/00-core.mdc` | Cursor | F0 | The ten invariant rules, always active |
| `.cursor/rules/10-tdd.mdc` | Cursor | F4 | The TDD policy, always active |
| `.cursor/rules/20-openspec.mdc` | Cursor | F2 | How a change is worked |
| `.cursor/rules/30-stack.mdc` | Cursor | F4 | The concrete layers of the stack |
| `.github/copilot-instructions.md` | Copilot | F0 | The same rules on the third surface |
| `explorer` | subagent | F4 | Cheap, isolated exploration, with mandatory citations |
| `tdd-test-writer` | subagent | F4 | The test first, and that it is seen to fail |
| `tdd-implementer` | subagent | F4 | The minimum, respecting layers |
| `tdd-refactorer` | subagent | F4 | Improves design with the suite green, without touching a single test |
| `spec-auditor` | subagent | F2 | That invented scope is caught before coding |
| `security-reviewer` | subagent | F5 | That nobody merges an IDOR out of haste |
| `/enrich-us` | skill | F1 | Stories with verifiable criteria and non-goals |
| `/dod-*` (5) | skills | F1 | Definition of Done by task type |
| `/openspec-implement` | skill | F2-F4 | Scenario → test traceability, task by task |
| `/feature-slice` | skill | F4 | Full vertical unit in layer order |
| `/tdd-red`, `/tdd-green` | skills | F4 | The red-green cycle split into two turns |
| `/verify-against-spec` | skill | F5 | Detect both what is missing and what is surplus |
| `/pr-review` | skill | F5 | First review pass, read-only |
| `/migration-review` | skill | F4-F5 | Expand-Contract / destructive SQL audit |
| `/architecture-audit` | skill | F4 | DDD, boundaries, SOLID/CUPID, Fowler mode |
| `/adr-new` | skill | F6 | Transcribe decisions, and say when they are not needed |
| `/commit`, `/pr-describe` | skills | F7 | Atomic commits and PR with the «why» left blank |
| `session-context` | hook | F0 | That the agent starts knowing where it is |
| `validate-tasks` | hook | F2 | That a `tasks.md` without verification does not pass |
| `docs-gate` | hook | F6 | That you do not commit with documentation lying |
| `block-secrets` | hook | cross-cutting | That no credential enters the context |
| `block-dangerous-bash` | hook | cross-cutting | That `rm -rf`, `--force`, and production do not pass |
| `protect-specs-and-tests` | hook | F2-F4 | That specs, tests, and migrations are not rewritten without a human decision |
| `post-edit-quality` | hook | F4 | Format, static analysis, and layer guards |
| `verify-tests` | hook | F4 | That the turn does not close with the suite red |

---

## 3. The ten invariant rules

They are the non-negotiable core. They are encoded in `.cursor/rules/00-core.mdc` and, those that
admit mechanical verification, also in the hooks. In parentheses, the material guide that
supports them.

1. **The specification wins over the code.** If they disagree, fix the code or update the
   specification. Never ignore the discrepancy. *(`07`)*
2. **The human gate goes in the plan**, neither before nor after. *(`07`, `08`, `02b`)*
3. **Tests are human-authored or human-supervised; implementation is delegated.** Never the other way around.
   *(`15`)*
4. **The agent does not touch its own tests.** *(`15`)*
5. **Fact → memory; procedure → skill; invariant → hook.** *(`08`, `10`, `11`)*
6. **Curated context, not accumulated.** *(`06`, `08`, `02b`)*
7. **Explicit non-goals in every unit of work.** *(`12`, `07`)*
8. **The «why» is not written by AI.** *(`05`, `01`, `13`)*
9. **`git push --force` and merges are signed by a human.** *(`00`, `05`, `01`)*
10. **Never secrets or personal data in the agent’s context.** *(`08`, `14`)*

---

## 4. How much to delegate

The material contains two L1–L5 taxonomies. The operational one —the one that decides how to work a concrete
task— classifies by **who initiates the task and where the human is**:

| Level | Who initiates | Human present | Traceability | Risk |
|---|---|---|---|---|
| 1 · Assistance | Every keystroke | Always | None | None |
| 2 · Conversational | Explicit instruction | Active, guiding | Only if there is a commit | Low |
| 3 · Task agent | You assign | Only when reviewing the PR | Commits, branches, PR | Medium |
| 4 · Autonomous | The agent alone | Only in review | PR, logs | High |
| 5 · Orchestration | An AI orchestrator | Only at the orchestrator | Complex | Very high |

**The three questions:**

```
1. Can I describe "done" in one or two sentences without ambiguity?
     NO → Level 1-2. L1 if it is a single file; L2 if it is ambiguous or requires judgement.
     YES → continue.

2. Do I need to be present while it runs?
     YES → Level 2.
     NO → continue. (Check first: would CI catch an error from this task?
          If not, go back to Level 2: without a safety net you do not delegate.)

3. Is it a task that repeats without anyone assigning it?
     NO → Level 3. Assign, leave, review the PR.
     YES → Level 4-5. L4 if it is predictable and recurrent; L5 only if it is massively
          parallelisable and you already master L3 and L4.
```

**Level 3 test, literal:** «Can you create a pull request from your phone without opening your laptop?
If the answer is yes, it is Level 3.»

**Hard precondition for Level 3 or above:** it only works well if your engineering process is already
organised. AI is an amplifier, not a solution.

This kit is designed for **Level 2-3**. The `/dod-*` skills, `/enrich-us`, and the CI
workflows are the doorway to Level 4.

---

## 5. Anti-patterns the kit prevents

| Anti-pattern | How the kit prevents it |
|---|---|
| **Test Theater**: AI generates code and tests at once, and the tests only confirm what the code does | `/tdd-red` separated from `/tdd-green`; the `protect-specs-and-tests` hook asks for confirmation to modify a test |
| **False completeness**: twelve acceptance criteria that look exhaustive and are not | `/enrich-us` always ends with the warning that they are a draft pending validation against the real system |
| **Invented scope**: an 800-line PR where 150 would fit | Mandatory non-goals in the story; the `spec-auditor` subagent looks for them explicitly |
| **Over-prompting with active hooks** | The allocation rule: if the hook guarantees it, it does not go in the prompt |
| **Zombie session** | The session hook recalls the real state; context thresholds are in the manual |
| **Coverage as a goal** | The hard gate is mutation score, not line percentage |
| **Specs rewritten to fit the code** | Creating an artefact is free; the `protect-specs-and-tests` hook asks before rewriting one that already exists, so a human can distinguish «the design changed» from «I am adjusting the spec to the shortcut I already took» |
| **Slopsquatting** | The hook asks for confirmation on every dependency install |
| **Secrets in context** | The `UserPromptSubmit` hook detects them and hides the prompt |
| **Mixed layers** | The `post-edit-quality` hook compares each file against the adapter’s guards |

---

## 6. Kit decisions (adopted criteria)

When there are several reasonable ways to configure the harness, the kit adopts these:

| Topic | Adopted criterion |
|---|---|
| Two distinct «OpenSpec»s under the same name: the CLI tool with `/opsx:*` and delta specs, and a conceptual framework with `.feature.spec.md` extensions | The CLI tool for the flow; the conceptual framework only as a template catalogue |
| Two L1–L5 taxonomies: by who initiates the task, and by tool type | The first, to decide delegation |
| Two hook formats: a flat one and a three-level one (event → matcher → handlers) | The three-level one, which is canonical |
| Environment variables (`$CLAUDE_FILE`) versus reading JSON from stdin with `jq` | stdin and `jq` |
| `allowed-tools` as a YAML array versus a list with permission patterns | The list with patterns, which allows argument granularity |
| Non-existent Git commands versus natural-language operations | Natural-language operations within the session |
| Several factory skill lists | The one from the kit’s current inventory |
