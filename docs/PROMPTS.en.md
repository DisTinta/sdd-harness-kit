# Prompt sequence

**Language:** [Español](PROMPTS.md) · English

Sixteen prompts, one per step of the cycle. Stack-agnostic: commands and paths come from
`docs/project-context.md`, `docs/backend-standards.md` and `.claude/sdd-harness.env`, so they work the
same in any project where you have installed the kit.

> **The prompts are in English because you write them.** The artefacts they produce —code, tests,
> specifications, commit messages, documentation— go **in English**, because
> `docs/base-standards.md` §2 requires it. Several prompts remind this explicitly; if you write a
> new one, add it.

Each prompt declares four things:

- **Context and role** — what the system is and what role the AI takes.
- **Inputs** — what you need on hand before launching it.
- **Instruction** — the concrete phase of the flow.
- **Acceptance criteria** — how you know it went well, and when to reject it without discussion.

Replace only what is between `<angle brackets>`.

> Several steps have an equivalent skill or subagent already installed. When they do, it is noted:
> the skill is faster, the prompt is more explicit and editable. Use whichever you prefer.
>
> The 27 skills and 9 subagents are in `ai-specs/`. `USAGE.md` lists them by phase.

---

## Usage rules

**Context hygiene.**

| Moment | Action |
|---|---|
| Before P5 (specify) | Clean context. The AI reads the repository, not the conversation |
| Before P9 (implement) | If you are at 50 % or more of the window, clear it first |
| Between unrelated tasks | Clean context |
| At 50-70 % of the window | Compact with a specific indication of what to keep |
| After fixing the same problem twice | Clear and reformulate with what you learned; do not keep correcting |

**Models.** The best available for P1-P3, P5-P7 and P12 (specify, plan, security). A balanced one
for P8-P11 (implement). The cheapest for P4 (explore). Do not use small models to generate the
specification.

**Human gates.** Five prompts where you cannot just hit “yes”:

| Prompt | What you review |
|---|---|
| **P2** | The acceptance criteria, against the real system |
| **P6** | The proposal: invented scope, missing scenarios, ambiguity |
| **P7** | The plan, before any code is written |
| **P8** | The test: you write it or validate it, and you see it fail |
| **P14** | The “why” of the PR and the merge signature |

---

## P0 · Harness bootstrap

Run once per repository, or when `docs/project-context.md` has gone stale. The installer already
leaves the skeleton with commands in place; this completes it.

```
CONTEXT AND ROLE
You are a software architect specialised in preparing repositories for work with coding agents.
You have read access to this repository.

INPUTS
- The full repository.
- The dependency manifest and the build, test and lint configuration files.
- The current docs/project-context.md, which has unfilled {{...}} markers.

INSTRUCTION
Complete docs/project-context.md. Strict rules:

1. Fewer than 200 lines in total. If it does not fit, propose splitting it by subdirectory.
2. Fill in ONLY what an agent cannot infer by reading the code:
   - Non-trivial commands, with the exact command verified in the manifest or in the
     configuration. If a command does not exist, DO NOT invent it: say so.
   - Internal conventions deduced from real code: where each thing lives, how it is named, what
     pattern equivalent pieces that already exist follow.
   - Operational constraints.
   - Gotchas: non-obvious behaviours you have spotted by reading the code or the configuration.
3. DO NOT include: directory tree, architecture documentation, onboarding for humans, or
   generic phrases like "write clean code".
4. Apply the pruning test to every line: "Would removing this cause an error?". If not, remove it.
5. Write it IN ENGLISH: docs/base-standards.md §2 requires it for every technical artefact.

EXPECTED OUTPUT
The full content of docs/project-context.md, plus a separate list of the claims you had to infer
and that need me to confirm them.

ACCEPTANCE CRITERIA
- Fewer than 200 lines.
- Every cited command actually exists: tell me in which file you saw it.
- Zero directory-tree sections.
- The "claims to confirm" list is not empty: if it is, you have not explored enough.
```

---

## P1 · Expand the issue into an executable story

> Equivalent skill: `/enrich-us <title and description>`

```
CONTEXT AND ROLE
You are a technical Product Owner. You turn draft issues into stories that a coding agent can
execute without inventing anything. You have read access to the repository.

INPUTS
- Draft issue: "<title>" — <two or three sentences of intent>
- docs/project-context.md and docs/backend-standards.md.

INSTRUCTION
Before writing the enriched story, build a REALITY MAP by searching the repository. Ticket text
is a hypothesis, not evidence: an example like `/api/courses/:id` is not a real route until you
find it. Classify each piece as Exists (cited path), To create (conventional project path, labeled
to-create), or Ticket examples checked (FOUND / NOT FOUND). Cover HTTP routes, middleware,
reusable traits/helpers, controllers/services/validators, and the closest test template. Do not
write Enhanced until the map is done.

Then generate the story in this exact order. Order matters: the agent reads top to bottom, and if
you put technique first it will decide on implementation before understanding the product problem.

1. USER STORY — "As a <role>, I want <capability>, so that <business outcome>".
2. ACCEPTANCE CRITERIA in Given/When/Then. Between 3 and 5 scenarios: happy path, at least one
   edge case and at least one error case. Each scenario must be translatable into an automated
   test: entry point, concrete input, expected result and observable effects.
3. TECHNICAL CONTEXT — only paths from the Reality map. Exists: where it fits and what to extend.
   To create: state it is new and which existing pattern to follow. Prefer existing traits/middleware.
4. NON-GOALS — at least two explicit boundaries.
5. LABELS AND ESTIMATE — area and type labels, and S/M/L size with a one-sentence justification.

Apply INVEST as an output filter. If the story fails two or more criteria, or does not fit in 1-2
human-equivalent days, mark it as needs-splitting and propose a breakdown into 2-3 stories.

EXPECTED OUTPUT
Markdown with ## Original, ## Reality map (Exists / To create / Ticket examples checked) and
## Enhanced, plus a final note reminding that the criteria are a draft pending human validation
against the real system.

ACCEPTANCE CRITERIA
- Reality map present; ticket examples verified (FOUND or NOT FOUND).
- Paths in technical context only from Exists or To create (To create labeled; Exists verified).
- Each criterion is verifiable: I do not accept "the filter must work".
- There are at least two non-goals.
- If you mark needs-splitting, the breakdown covers 100 % of the original scope.
```

---

## P2 · Poke-holes in the acceptance criteria

**Do not delegate this step.** The value is that the AI finds what was missing, not that it writes
the criteria from scratch.

```
CONTEXT AND ROLE
You are an adversarial tester. Your goal is not to validate this story: it is to break it.

INPUTS
- User story and acceptance criteria:
<paste the full story>
- The repository, with read access.

INSTRUCTION
Given this story, list:
1. Uncovered edge cases.
2. Implicit assumptions the author took for granted without writing them down.
3. Missing scenarios: concurrency, authorisation, empty data, size limits, character
   encoding, null values, intermediate domain states, idempotency.
4. Unmentioned dependencies or risks. Check in the code which other parts of the system touch
   the same entities, and which side effects fire.

For each finding state: description, why it matters, and whether you deduced it from the code
(with path and line) or from your general domain knowledge.

EXPECTED OUTPUT
Prioritised list. Mark [CODE] findings verified in the repository and [GENERAL] those that
come from your prior knowledge.

ACCEPTANCE CRITERIA
- Between 10 and 15 candidates. If you give fewer than 8, you have not searched enough.
- At least 3 [CODE] findings with path and line.
- DO NOT rewrite the criteria. Only point out gaps: deciding which to incorporate is mine.
```

---

## P3 · Estimation as a planning-poker peer

```
CONTEXT AND ROLE
You are one more team member in a planning-poker session. You are not the referee: you are a peer
who estimates in private before the cards are revealed.

INPUTS
- Story to estimate:
<paste the story>
- Calibrated team examples (optional, but greatly improves the result):
  <past story 1> = <points>
  <past story 2> = <points>
  <past story 3> = <points>
- The repository.

INSTRUCTION
1. Estimate on the team's Fibonacci scale (1, 2, 3, 5, 8, 13). A SINGLE integer from the
   scale. No decimals or ranges: decimal precision is fictitious.
2. Justify in three bullets: what makes the task large, what makes it small, and which concrete
   unknown could throw it off.
3. Apply the matching multiplier and state it explicitly:
   - new code: factor 0.85 over the human base estimate
   - legacy code the team knows well: factor 1.0, AI does not accelerate here
   - exploration: do not estimate in points, propose a t-shirt size
4. Say whether you detect that this story should go back to refinement instead of entering the sprint.

EXPECTED OUTPUT
Fibonacci number, three bullets, applied multiplier and verdict on whether it is ready.

ACCEPTANCE CRITERIA
- The number is on the scale. If you give me "3.5" or "between 3 and 5", the output is invalid.
- Do not present your number as authority: it is one more card on the table. The number is the
  by-product of the conversation, not the goal.
```

---

## P4 · Explore

> Equivalent subagent: delegate to `explorer`.

Clean context recommended.

```
CONTEXT AND ROLE
Act as the explorer subagent: a read-only codebase explorer. You do not propose
implementation and you do not edit anything.

INPUTS
- Feature goal: <one-sentence summary>
- The repository, docs/project-context.md and .claude/sdd-harness.env.

INSTRUCTION
Map the current state of the related code, walking the layers in the order LAYER_ORDER declares.
Also identify the existing test MOST SIMILAR to the one that will need to be written.

Return exactly this format:

FINDINGS:
- <verified fact> (`path:line`)

REFERENCE PATTERN:
- Similar test: `<path>` — structure in two lines.
- Equivalent piece already implemented: `<path>:<symbol>`.

OPEN QUESTIONS:
- <ambiguity a human must resolve before implementing>

EXPECTED OUTPUT
Maximum 30 lines.

ACCEPTANCE CRITERIA
- Every finding carries path and line. Without a citation, it does not count.
- OPEN QUESTIONS is not empty.
- There is no implementation proposal.
```

---

## P5 · Specify the change

**Clean context mandatory.** If you use OpenSpec, the `/opsx:propose "<description>"` command does
the same thing. This prompt is the controlled version, and it also works without OpenSpec.

```
CONTEXT AND ROLE
You are an architect who writes executable specifications. The specification is the source of
truth: the code will be an expression of it, and when both disagree, the specification wins.

INPUTS
- Validated user story and acceptance criteria:
<paste the story>
- Codebase brief:
<paste the P4 output>
- The templates in ai-specs/templates/openspec/ and docs/project-context.md.

INSTRUCTION
Generate the four change artefacts under openspec/changes/<id>/:

1. proposal.md — sections ## Why, ## What Changes, ## Capabilities (with ### New and ### Modified) and
   ## Impact. The "Why" explains the business problem, not the solution.

2. specs/<capability>/spec.md — the DELTA, not the full system specification:
     # Delta for <Capability>
     ## ADDED Requirements / ## MODIFIED Requirements / ## REMOVED Requirements
     ### Requirement: <name>   → body in RFC-2119 (The system MUST / SHALL ...)
     #### Scenario: <name>     → bullets - GIVEN / - WHEN / - THEN / - AND
   Each acceptance criterion from the story appears as a scenario. In MODIFIED, add
   "(Previously: ...)".

3. design.md — ## Context, ## Goals / Non-Goals, ## Decisions, ## Risks / Trade-offs,
   ## Open Questions. In Decisions close explicitly: where validation happens and why there, which
   existing abstraction is reused, how subject isolation is guaranteed, what exact shape the
   response has and what is persisted. Everything you leave open here the agent will improvise.

4. tasks.md — checklist `- [ ] N.M description`. MUST satisfy docs/openspec-tasks-mandatory-steps.md:
   - Step 0 creates the working branch, and is the first.
   - The steps to review existing tests, run the tests and verify data state, manual interface
     verification, and update technical documentation are present and labelled (MANDATORY).
   - Manual verification steps declare AGENT MUST EXECUTE.
   - Every task that mutates data includes its restoration.
   - Each task fits in a single agent turn: if a task is "implement the module", split it.
   The validate-tasks hook rejects the file if any of these conditions is missing, so
   checking beforehand saves you a turn.

EXPECTED OUTPUT
The four complete files, each in its own block, with its path as the heading.

ACCEPTANCE CRITERIA
- There is exactly one scenario per acceptance criterion, and none invented.
- The delta does NOT contain existing requirements that do not change.
- design.md leaves no architecture decision to the implementer's judgement.
- No task needs more than one turn.
- tasks.md passes the validate-tasks hook: step 0 for the branch, mandatory steps labelled,
  AGENT MUST EXECUTE on manual verification, state restoration, N.M numbering.
- All content is in English.
- If you detect ambiguity, it goes to Open Questions. Do not resolve it yourself.
```

---

## P6 · Audit the proposal before the gate

> Equivalent subagent: delegate to `spec-auditor`.

This prompt does not replace your review: it focuses it.

```
CONTEXT AND ROLE
You are a specification reviewer. You find the defects in this proposal before a single line of
code is written, because afterwards it costs ten times more.

INPUTS
- The four change files, with read access.
- The repository.

INSTRUCTION
Audit the proposal against this checklist and answer point by point:

1. INVENTED SCOPE — is there anything in the proposal or in the tasks that does not follow from the
   requirements? List it so it can be cut.
2. MISSING SCENARIOS — does any requirement describe a behaviour in its MUST without a scenario?
3. AMBIGUITY — search for "fast", "easy", "secure", "efficient", "many", "adequate", "robust".
   Each occurrence is a defect: propose the measurable formulation.
4. CONTRADICTIONS — between proposal, design and specification.
5. CONTRAST WITH REAL CODE — does any decision clash with what already exists? Does it duplicate an
   abstraction? Cite path and line.
6. TASK SIZE — mark those that do not fit in one turn.
7. MANDATORY STEPS — contrast tasks.md with docs/openspec-tasks-mandatory-steps.md: does step 0
   create the branch? Are the verification steps present, labelled (MANDATORY)? Do they declare
   AGENT MUST EXECUTE? Do tasks that mutate data include restoration?
8. TRACEABILITY — table Requirement → Scenario → task(s). Mark the gaps.

EXPECTED OUTPUT
Report with the eight points. Each finding with severity (blocking / improvable) and the concrete
correction proposed.

ACCEPTANCE CRITERIA
- You modify no file: you only report.
- The traceability table is complete. An empty row is a blocking finding.
- If you find nothing, say so explicitly instead of inventing a finding.
```

**Human gate.** Open the four files and edit them yourself. Cut invented scope, add missing
scenarios, resolve ambiguities. This is the most valuable moment in the flow.

---

## P7 · Implementation plan

Enter plan mode before launching it.

```
CONTEXT AND ROLE
You are in plan mode: read-only. You are a tech lead planning the execution of a change already
specified and approved.

INPUTS
- The full change (proposal, design, specification, tasks).
- docs/project-context.md, docs/backend-standards.md and .claude/sdd-harness.env.
- The repository.

INSTRUCTION
Produce a plan that respects the layer order declared in LAYER_ORDER.

For each task state:
- Exact file that is created or modified, with its path.
- What changes inside that file, in one sentence.
- The exact command used to verify it.
- Risk: low / medium / high, and why.

Add at the end:
- The list of existing files that will be MODIFIED (not created), so I can assess the blast
  radius.
- If a schema change is needed: the proposed name and whether it is reversible.
- The assumptions you are making that could be wrong.

EXPECTED OUTPUT
Plan in Markdown, ordered, executable step by step.

ACCEPTANCE CRITERIA
- No task touches files under openspec/.
- No task proposes modifying an existing test or an already-applied migration.
- No new dependencies are introduced. If you think they are needed, stop and ask me.
- If the plan touches more than 8 files, propose splitting the change in two.
```

**Human gate.** Read the whole plan and edit it before approving.

---

## P8 · Red — the failing test

> Equivalent skill: `/tdd-red <description>`

```
CONTEXT AND ROLE
We are doing strict TDD. You are a senior QA engineer. DO NOT implement production code
in this turn.

INPUTS
- Scenario:
<paste the full GIVEN / WHEN / THEN block>
- Reference test: <path of the most similar test>
- docs/project-context.md, docs/backend-standards.md and .claude/sdd-harness.env.

INSTRUCTION
1. Read the reference test and copy its structure: imports, grouping, data setup,
   authentication helpers, database isolation.
2. Write A SINGLE test:
   - Comment "// Scenario: <exact scenario name>" right above it.
   - Name that describes the observable behaviour, not the implementation.
   - Arrange-Act-Assert pattern with the three blocks separated and commented.
   - Test data with the project's factories or helpers.
   - Assertions on the contract: response code, payload shape, persisted effects.
     Nothing about internal details.
3. Run it with the project's filter command.
4. Stop and report the exact failure message to me.

EXPECTED OUTPUT
The complete test file and the command output showing the failure.

ACCEPTANCE CRITERIA
- The test FAILS. If it passes first time, it is useless: tell me and rewrite it.
- You have not touched the production layer.
- You have not modified any existing test.
- The test name explains the behaviour without needing to read the body.
```

---

## P9 · Green — minimal implementation

> Equivalent skills: `/tdd-green <test path>` and, afterwards, `/tdd-refactor <file>`.
> Subagents: `tdd-implementer` and `tdd-refactorer`.
>
> These are **two turns, not one**. The kit recommends one subagent per phase of the cycle precisely
> for this: the agent that just fought to get the test green carries the justifications it used
> to get there, and refactoring with that context in the room is how a “improvement” changes
> behaviour without anyone noticing.

If you are at 50 % or more of context, clear it first: the agent will re-read the files from disk.

```
CONTEXT AND ROLE
You are a senior developer. There is a test in red. Your only goal is to get it green with the
minimum possible code.

INPUTS
- Red test: <path>
- design.md of the change.
- docs/project-context.md, docs/backend-standards.md and .claude/sdd-harness.env.

INSTRUCTION
1. Run the test and read the real failure. Do not assume the reason.
2. Implement following LAYER_ORDER, and only what is necessary.
3. Re-run until green. Then run the full suite to check you have not broken
   anything.
4. Leave static analysis and the linter clean.

You may return a fixed value if a single test is enough. If you do, tell me explicitly so
I can add the triangulation test.

EXPECTED OUTPUT
Files touched, diff of each one, green test output, and whether you used a fixed value.

ACCEPTANCE CRITERIA
- The test passes; static analysis and linter clean.
- You have not modified the test. If you thought it was wrong, you should have stopped.
- There are no type-system escapes in the new code.
- There is no business logic in the transport layer.
- You have not added dependencies.
```

---

## P9b · Refactor — with the suite green

> Equivalent skill: `/tdd-refactor <file or module>` · Subagent: `tdd-refactorer`
>
> Launch it in a new turn, not in the same one that got the test green.

```
CONTEXT AND ROLE
We are in the REFACTOR phase of the TDD cycle. The suite is green. Your job is to improve the design
without changing observable behaviour.

INPUTS
- File or module to refactor: <path>
- docs/backend-standards.md and .claude/sdd-harness.env.

INSTRUCTION
1. Run the suite and confirm it is green. If anything is red, stop: there is nothing to
   refactor, there is something to fix, and that is different work.
2. Read the code and give me a list ORDERED BY VALUE of refactor candidates, with the reason for
   each. Show it before touching anything.
   Prioritise in this order: layer violations; duplication that has already diverged; names that
   lie; functions you cannot name without using "and"; domain concepts passed as a loose
   string; code that cannot be tested without touching the outside.
3. Apply ONE refactor at a time, running the suite after each one.
4. Leave static analysis and the linter clean.
5. Report what you changed, what you deliberately left the same, and why.

ACCEPTANCE CRITERIA
- Observable behaviour is identical: same contracts, same responses, same effects.
- You have NOT touched any test. Not one. If a refactor needed to change a test, the behaviour
  changed and it was not a refactor: I want you to stop and tell me.
- Coverage has not dropped.
- You have mixed in no bug fix or feature work, not even one line.
- If the code was already clean enough, you say so and change nothing. Churn on a green suite
  is pure risk.
```

---

## P10 · Triangulation and edge cases

```
CONTEXT AND ROLE
You are a tester with domain knowledge. The implementation passes the tests, but it may be
returning fixed values or be incomplete.

INPUTS
- Current implementation: <paths of the files touched>
- Current tests: <path>

INSTRUCTION
1. If you detect a fixed value that makes the test pass without implementing the real behaviour,
   write a second test that forces generalisation.
2. Give me 5 edge cases I have probably not considered, prioritising those from the business
   domain over generic ones. Include at least one about authorisation and one about data integrity.
3. For each: what would happen today with the current code (read it, do not assume) and whether it
   should be covered in this change or in a separate ticket.
4. Deliberately break the implementation: change a method's return or invert a condition, and
   tell me which tests still pass. Those that still pass are useless.
5. If the touched code is in the business layer, run the project's mutation testing and
   report the score.

EXPECTED OUTPUT
Triangulation test if applicable, the 5 edge cases with verdict, the result of the
break-the-implementation exercise and the mutation score if applicable.

ACCEPTANCE CRITERIA
- The "deliberately break" exercise is done for real, with the test output as proof.
- You restore the code to its correct state when finished.
- If the mutation score falls below the configured threshold, you flag it as blocking.
- You do not add the edge cases to the scope without asking me: you only propose them.
```

---

## P11 · Demonstrate, verify and refute

> Equivalent skills, in this order: `/show-spec-working <id>` → `/verify-against-spec <id>` →
> `/adversarial-review <id>`
>
> Before applying migrations to a shared environment: `/migration-review`.
> Before a large design refactor: `/architecture-audit <module>`.

These are three distinct things and are often confused:
>
> - **Demonstrate** (`/show-spec-working`): the agent starts the system, exercises each scenario against
>   the real interface and delivers evidence. Playwright screenshots go under
>   `openspec/changes/<id>/reports/`, next to the report; not at the repo root. This is what the harness
>   marks as “AGENT MUST EXECUTE”, and it is work, not documentation. It is never delegated to the user.
> - **Verify** (`/verify-against-spec`): conformity between code and specification, including what
>   is surplus.
> - **Refute** (`/adversarial-review`): hostile review with a verdict, **in a session different from the
>   one that implemented**.
>
> The prompt below covers the second. For the first and the third use the skills: they depend on
> running things and isolating context, and they do that better.

```
CONTEXT AND ROLE
You are a conformity auditor. The implementation is finished. Check whether it does exactly what
the specification says, no more and no less.

INPUTS
- The change's delta spec.
- The implemented code and the tests.

INSTRUCTION
Compare code and specification, and return three blocks:

1. REQUIREMENTS CORRECTLY IMPLEMENTED — with the path of the code and of the test that proves it.
2. REQUIREMENTS NOT IMPLEMENTED OR PARTIAL — exactly what is missing.
3. UNSPECIFIED BEHAVIOURS — code that does things the specification does not ask for. This is as
   serious as the previous: it is invented scope, and nobody has reviewed it.

Also check: any imported dependency that does not exist in the manifest? Any authorisation check
the specification required that is missing? Any field in the response that is not mentioned?
Any scenario whose test asserts something weaker than what the scenario says?

And if something in block 2 or 3 needs correcting: remember rule 7 of docs/base-standards.md. A change
that arrives after implementing and before archiving is treated FIRST as an update to the
change artefacts, and only afterwards is the code touched.

EXPECTED OUTPUT
The three blocks and a final table Scenario → test → status (green / red / absent).

ACCEPTANCE CRITERIA
- Every claim carries path and line.
- If block 3 is empty, justify it: that is uncommon.
- You correct nothing in this turn.
```

---

## P12 · Security review

> Equivalent subagent: delegate to `security-reviewer`.

```
CONTEXT AND ROLE
Act as the security-reviewer subagent. You only analyse: you modify nothing.

INPUTS
- The branch diff against the base branch.
- docs/project-context.md, docs/backend-standards.md and .claude/sdd-harness.env.

INSTRUCTION
Review the full diff against this list, by severity:

HIGH — secrets in plain text; new routes without authentication; missing authorisation over a
foreign resource; external input that does not go through the validation layer; mass assignment from the
request; queries by concatenation; sensitive data in the response.
MEDIUM — errors that leak internal structure; listings without pagination; new dependencies whose
name you must verify in the official registry; personal data sent to third parties without
de-identification.
LOW — logs with the full request body; absence of rate limiting on public
endpoints.

EXPECTED OUTPUT
Table: severity · file:line · finding · proposed fix.

ACCEPTANCE CRITERIA
- If you find nothing, say so explicitly.
- Every finding carries file and line.
- You modify no file.
```

---

## P13 · Documentation

> Equivalent skills: `/update-docs` to find what the change invalidated, and `/adr-new <title>`
> for the decision record. The `docs-gate` hook checks the same before letting you commit a
> schema or contract change.

```
CONTEXT AND ROLE
You are a technical writer with engineering judgement. The feature is implemented and verified. Your
job is to leave a trail of what cannot be deduced from the code.

INPUTS
- The full diff of the change.
- design.md and the existing ADRs.
- docs/project-context.md, docs/backend-standards.md and .claude/sdd-harness.env.

INSTRUCTION
Three tasks in order:

1. ADR. First apply the necessity criterion: would a new developer wonder "why did they
   do it this way"? Does it affect more than one module? Does it cost more than a day to revert? If it does NOT
   apply, tell me and write nothing. If it does, create it under PATH_ADR named <YYYYMMDD>-<slug>.md,
   following the project template and transcribing the decision already in design.md. Do not
   invent alternatives nobody considered. Update the index.

2. CODE DOCUMENTATION. Add it to the new public symbols of the business layer and the
   transport layer: one-sentence description, parameters with their meaning (not their type, which is already
   in the signature), return, errors it throws, and an example on business methods. It must pass the
   project's documentation coverage check.

3. API CONTRACT. Regenerate whatever is generable. Annotate by hand ONLY what the generator cannot
   infer. Duplicating what is already inferred is debt.

EXPECTED OUTPUT
The generated or modified files, each in its own block.

ACCEPTANCE CRITERIA
- If the ADR does not apply, you do not write it: filler ADRs are an anti-pattern.
- The "why" of the ADR comes from design.md or from what I have told you, not from your imagination.
- Code documentation does not repeat in prose what the signature already says.
```

---

## P14 · Commit and Pull Request

> Equivalent skills: `/commit` and `/pr-describe`

```
CONTEXT AND ROLE
You are a developer closing a unit of work. The agent prepares; the human signs.

INPUTS
- The working tree state and the diff.
- The specified change.
- The ticket: <id and title>

INSTRUCTION
1. COMMITS. Review the diff. If it mixes distinct areas, propose separate atomic commits with
   selective staging, and ask me for confirmation before executing anything. Conventional format:
   type(TICKET-ID): description if there is a ticket (e.g. feat(KAN-184): add listing filter by state);
   otherwise, type(layer-or-capability): description. Verb in present imperative, first line
   72 characters maximum. The ticket id comes from the branch (`feature/KAN-184-…`), from what I
   pass you, or you ask me; do not invent it.

2. PR DESCRIPTION:
   - "What changes?" — one to three sentences from the diff.
   - "How to test it?" — numbered, executable steps as-is, with the real commands.
   - "Traceability" — table Scenario → file:line of the test that covers it.
   - "Decisions / trade-offs" — ONLY if you can ground them in design.md or in an ADR.
   Leave "Why?" with the marker <!-- completed by the human -->.

3. Suggest the PR origin label: human / human+copilot / agent / agent+human-review.

EXPECTED OUTPUT
Proposed commit commands, not yet executed, and the PR description in Markdown.

ACCEPTANCE CRITERIA
- You have not pushed. You never do.
- The "Why?" section is empty and marked, not filled in.
- Every "How to test it?" command is executable as-is.
- The traceability table has no empty rows.
```

---

## P15 · Close and learn

Archive the change first. Then:

```
CONTEXT AND ROLE
You are a process analyst. The change is merged. You work at team and process level,
NEVER at individual level.

INPUTS
- The archived change.
- Cycle data: <time from PR open to merge>, <number of review
  comments>, <fix commits after the first review>, <PR origin label>.

INSTRUCTION
1. Compare the final tasks.md with the original: did unforeseen tasks appear? which and why?
2. Compare the original specification with the final code: were there deviations? was the
   specification updated or left out of sync?
3. Identify in which phase the most time was lost: specification, implementation or review.
4. Propose ONE concrete process improvement, not of the team, and state WHERE it is implemented:
   - a project fact                 → docs/project-context.md
   - a layer convention             → docs/backend-standards.md
   - a repeated procedure           → a new skill in ai-specs/skills/ (use /writing-skills)
   - an invariant that must not fail → a hook in .claude/hooks/
   - a command or path that changed → .claude/sdd-harness.env
   If it is a new skill or agent, remember to run bash .claude/sync-artifacts.sh afterwards.

EXPECTED OUTPUT
Four short sections. The last one, with the improvement and exactly where it would be implemented.

ACCEPTANCE CRITERIA
- No claims about specific people.
- The improvement is implementable this week, not a general principle.
```

---

## Appendix · Rescue prompts

### The agent ignores design decisions

Common cause: context has grown and `design.md` got buried. Clear the context and relaunch
referencing the file explicitly in the first turn.

```
Implement change <id>.
Read first, in this order and without exception: proposal.md, design.md, specs/*.md and tasks.md.
Follow tasks.md step by step. Ask me before you deviate from any requirement in specs/.
```

### The agent has modified a test so the suite passes

```
Stop. You have modified an existing test. Tests are the signed specification, not an obstacle.

1. Revert the change in the test file and show me the revert diff.
2. Run the suite and show me the real failure, without touching the test.
3. Explain why the code fails, not why "the test was wrong".
4. Do not implement anything until I tell you to.
```

### The agent proposes a new dependency

```
Before installing anything:
1. Tell me the exact package name and its version.
2. Tell me what problem it solves that cannot be solved with what is already in the manifest.
3. Tell me which part of the code would be coupled to it and how costly it would be to remove.
Do not install it. Verification in the official registry and the decision are mine.
```

### A skill does not appear or does not apply

Almost always it is the canonical source. `ai-specs/` is where you edit; `.claude/skills/` and
`.cursor/skills/` only reference it, and on Windows they can be independent copies.

```bash
bash .claude/sync-artifacts.sh --check
```

If it says `TEXTO`, the symlink materialised as a file and the skill does not load: run it without `--check`.
If it says `DIVERGE`, you edited the copy instead of the original: move the change to `ai-specs/` and sync.
If it says `FALTA`, the skill is new and was never linked. And if you just created the skills directory,
restart the session: hot reload does not cover that case.

The `/sync-agent-artifacts` skill does this diagnosis and explains each state to you.

### The session has degraded

Compact indicating in one sentence the only thing that matters to keep. If you have fixed the same
problem twice, do not compact: clear completely and reformulate the prompt incorporating what you
learned from the two failed attempts.

### You need a specification and do not know where to start

```
I want to build <brief description>. Interview me in detail before writing anything.
Ask me about technical implementation, edge cases, constraints and trade-offs.
Keep asking until we have covered everything, and then write the complete specification
in SPEC.md.
```

Afterwards, a new session to implement: clean context plus a written specification performs better than
continuing in the saturated session.
