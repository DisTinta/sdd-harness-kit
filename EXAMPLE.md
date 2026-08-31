# A unit of work, end to end

**Language:** [Español](EJEMPLO.md) · English

A full walkthrough of the flow on a generic unit, so you can see how the pieces fit together. It is
not a tutorial for any framework: names go in `<brackets>` and the mapping to your stack comes from
`docs/backend-standards.md` and from `LAYER_ORDER` in `.claude/sdd-harness.env`.

The case: **add an optional filter to an existing listing**. It is deliberately small. Most real
work is this size, and that is where the flow shows.

---

## Starting point

A three-sentence issue in the task tracker:

> **Filter the listing by state**
> The «pending» view is falling short. The client downloads everything and filters in memory.

That is all there is. What follows is how it becomes a merge.

---

## F1 · From issue to story

`/enrich-us Filter the listing by state — the pending view downloads everything and filters in memory`

It returns a draft. This is the result **after** running P2 (poke-holes) and a human cutting and
adding:

```markdown
## Story
As a team member, I want to filter the listing by state,
so I can see at a glance what I have pending today.

## Acceptance criteria

Scenario: Filter by a valid state
Given an authenticated user with 12 <resources>, 5 of them in state "pending"
When they request the listing filtered by state "pending"
Then the response is successful
And  it contains exactly 5 items
And  every one is in state "pending"

Scenario: Without a filter the current behaviour is preserved
Given an authenticated user with 12 <resources>
When they request the listing without a filter
Then the response contains all 12

Scenario: Unrecognised state
Given an authenticated user
When they request the listing with a state that does not exist
Then the response is a validation error
And  the message enumerates the allowed states

Scenario: Isolation between users
Given another user has <resources> in state "pending"
When the authenticated user filters by "pending"
Then the response includes no foreign <resource>

Scenario: Unauthenticated request
Given a request without credentials
When they request the listing
Then the response is unauthorized

## Technical context
- Entry point: <PATH_HTTP>/<resource>_controller — the listing method already exists
- Entity: <PATH_SOURCE>/models/<resource>, field `estado`
- Validation to extend: <the listing's>
- Reference test: <PATH_TESTS>/<resource>/listado

## Non-goals
- Do not filter by other fields: that belongs in its own ticket
- Do not touch the client
- Do not add database indexes in this ticket
- Do not refactor the controller beyond the affected method

## Estimate
S — a read filter on an entity that already exists.
```

**What the AI contributed:** the draft and the isolation and unauthenticated scenarios, which the
issue author had not thought of.

**What the human contributed:** the non-goals, and discarding three «improvements» the copilot had
slipped in —configurable sorting, cursor pagination, and a count endpoint— that nobody had asked for.

> That discard is exactly F1's gate work. Without it, this S-sized story would have reached
> implementation as an L.

---

## F2 · From story to contract

Clean context. `/opsx:propose` or the P5 prompt — either produces the same four files and is subject
to the same hooks.

Four files. The two that most decide the outcome:

**`specs/<capability>/spec.md`** — the contract. One scenario per acceptance criterion:

```markdown
# Delta for <Capability>

## ADDED Requirements

### Requirement: Filtering by state
The system MUST allow an authenticated user to filter their own <resources> by state, using an
optional parameter. The system MUST reject any value outside the supported state set.

#### Scenario: Filter by a valid state
- GIVEN an authenticated user owning 12 <resources>, 5 of them in state "pending"
- WHEN the user requests the list filtered by state "pending"
- THEN the response is successful
- AND it contains exactly 5 items
- AND every returned item is in state "pending"

#### Scenario: Isolation between users
- GIVEN another user owns <resources> in state "pending"
- WHEN the authenticated user filters by "pending"
- THEN the response contains no <resource> belonging to another user

## MODIFIED Requirements

### Requirement: Listing
The system SHALL return the authenticated user's <resources> paginated with a fixed page size.
(Previously: returned every item without pagination and without filtering.)
```

**`design.md`** — where the agent is prevented from improvising:

```markdown
## Decisions
- The filter is an optional parameter on the existing listing, not a new endpoint: that way it
  combines with future filters without multiplying entry points.
- The set of valid states is modelled as a domain type and is the single source of truth:
  validation and persistence derive from it, not the other way around.
- Validation happens in the validation layer, not in the business layer: an invalid value must
  never reach the logic.
- The filter is expressed as a reusable entity query, not as a loose condition
  inside the service.
- User isolation is applied ALWAYS and BEFORE the optional filter.
- The response is paginated with a fixed size. The client does not control it yet.

## Risks / Trade-offs
- Without an index on (user, state) the query scans the table. Acceptable at the current volume;
  recorded as debt.

## Open Questions
- Will there be an "archived" state or a separate flag? Pending Product. Does not block.
```

**What `design.md` does that the specification does not:** the specification says *what*; the design
locks down the *how* so the agent does not decide it mid-implementation. Without the line about
isolation, a reasonable agent could apply the filter first and ownership after: it would pass four
of the five scenarios and leak foreign data in production.

**`tasks.md`** — and this is where the kit will not let you improvise. `docs/openspec-tasks-mandatory-steps.md`
requires that step 0 create the branch, that verification steps be present and labelled, and that
every task that mutates data include its restoration:

```markdown
## 0. Setup: Create Feature Branch (MANDATORY - FIRST STEP)
- [ ] 0.1 Create feature branch `feature/<TICKET-ID>-<change-name>` from the base branch (or `feature/<change-name>` if there is no ticket)
- [ ] 0.2 Verify branch creation and current branch status

## 1. Backend: Validation Tests (TDD)
- [ ] 1.1 Failing test for the unrecognised state scenario
- [ ] 1.2 Minimum implementation to pass it

## 2-5. Backend: <the change's own work>

## 6. Backend: Review and Update Existing Tests (MANDATORY)
- [ ] 6.1 Identify tests affected by the new pagination

## 7. Backend: Run Tests and Verify Data State (MANDATORY)
- [ ] 7.1 Capture pre-test baseline for the impacted entities
- [ ] 7.2 Run targeted tests, then the required suite
- [ ] 7.3 Verify post-test state and restore if needed
- [ ] 7.4 Create the report under `openspec/changes/<id>/reports/`

## 8. Backend: Manual Interface Testing (MANDATORY - AGENT MUST EXECUTE)
- [ ] 8.1 Exercise the success path and verify the response
- [ ] 8.2 Exercise the error cases
- [ ] 8.3 Restore any mutated state

## 10. Update Technical Documentation (MANDATORY)
- [ ] 10.1 Regenerate the API specification
```

If the agent writes a `tasks.md` without step 0, without the `(MANDATORY)` label, without
`AGENT MUST EXECUTE`, or without state restoration, the `validate-tasks` hook **rejects it at
write time** and says exactly what is missing. Doctrine stops being a
recommendation.

**Human gate.** Open the four files and edit them. The `spec-auditor` subagent or the P6 prompt tell
you where to look —including `tasks.md` conformity—; the decision is yours.

---

## F4 · From contract to code

`/openspec-implement <id>` walks the tasks. What happens in each one:

### Red

```
Test written. Executed. Fails:
  Error: the filtering function does not exist
```

Failing **for the right reason** matters: if it failed because of a syntax error in the test itself,
you would not be measuring anything.

### Green

The agent implements by walking `LAYER_ORDER`, and only what is necessary. This is where the hooks
work without anyone invoking them:

| Moment | Hook | What happened |
|---|---|---|
| The agent tries to edit the test to «fix» a failure | `protect-specs-and-tests` | Asks for explicit confirmation. The human says no; the agent goes back to the code |
| The agent tries to «improve» the delta spec to fit what was implemented, without the design having changed | `protect-specs-and-tests` | Asks for confirmation explaining the legitimate case (rule 7) versus the illegitimate one. The human says no; the agent goes back to the code instead of rewriting the spec |
| The agent writes in the business layer importing transport | `post-edit-quality` | Returns control with the layer violation. It is corrected before continuing |
| The agent writes a comment in Spanish | `post-edit-quality` | Warning, not a block: `base-standards.md` §2 requires English in every technical artefact |
| The agent proposes installing a utility library | `block-dangerous-bash` | Asks for confirmation. The human checks the registry and decides |
| The agent closes the turn with a test in red | `verify-tests` | Blocks the close with the suite output |

None of those six things is in any prompt. They are in code, and that is why they always run.

### The piece that decides the outcome

Of everything implemented, this is the one to look at in review:

```
list(subject, optional_filter, page):
    query(<resource>)
      .ownedBy(subject)             ← always, and first
      .withState(optional_filter)   ← optional; if empty, does not alter the query
      .order(...)
      .paginate(fixed_size, page)
```

The order is not cosmetic. Inverting it makes the isolation scenario still pass in the tests
—because the filter also restricts— and fail in production as soon as someone queries without a
filter.

### Refactor

With the suite green, `/tdd-refactor` on the service. Here it returned something useful and something
worth reading carefully:

```
Candidates, by value:
1. The filter and isolation are in the same method, and the name does not say it does both.
   → extract the ownership scope, which already exists on the model and was not being used.
2. The page size is a literal number in two places.
   → a constant, which is also what the ADR will cite.

Deliberately left alone:
- Method length: 18 lines is not a problem. It has a single reason to change.
```

And the limit that makes the phase safe: **it did not touch any test**. If a refactor needs to change
a test, the behaviour changed and it was not a refactor. The `tdd-refactorer` subagent stops and
reports it instead of adjusting the assertion.

### Triangulation

P10 detects that the agent returned a fixed value in the first task, writes the second test that
forces it to generalise, and runs the exercise of breaking the implementation on purpose: if
inverting the filter condition puts no test in red, that test is surplus.

---

## F5 · Verification

Three distinct steps, and they are often confused. The first is the one almost nobody does.

### Show that it works — `/show-spec-working`

This is what the harness marks as **AGENT MUST EXECUTE**, and it is work, not documentation: the
agent starts the service, exercises each scenario against the real system, and delivers evidence.

```
## Demonstrated
| Scenario | Interaction | Result | Matches |
|---|---|---|---|
| Filter by a valid state | GET listado?estado=pendiente | 200, 5 items | yes |
| Listing without filter  | GET listado                  | 200, 12 items | yes |
| Unrecognised state      | GET listado?estado=xxx       | 422 + allowed values | yes |
| Isolation between users | GET as user B                | 0 foreign items | yes |
| Unauthenticated request | GET without credentials      | 401 | yes |

## State
- Before: 12 records for user A, 3 for user B
- After: 12 and 3
- Restored: not needed, all interactions are reads
```

And the report lands in `openspec/changes/<id>/reports/`, one of the few places under `openspec/` where
writing never triggers even a question —creating new artefacts does not trigger it either; what does
trigger it is rewriting one that already existed—. If the scenario had mutated data, the report
would have to document the restoration: create, verify, delete, and confirm the count returns
to what it was before.

**The difference from the tests:** the tests passed twenty minutes ago in an isolated test
environment. This shows it works on the system you start, with the real configuration. It is not
redundant: it is the first time anyone runs it for real.

### Check conformity — `/verify-against-spec`

It returns three blocks. The third is the one that surprises:

```
3. UNSPECIFIED BEHAVIOURS
   - The listing now sorts by date descending. The specification does not mention sorting.
     (<PATH_BUSINESS>/<resource>_service:31)
```

That is invented scope. Two legitimate exits: remove it, or add it to the specification because
we actually wanted it. **What does not work is leaving it undecided**: that is exactly the gap
through which behaviour nobody reviewed slips in.

Watch the shortcut that is tempting here: if you decide you did want it, rule 7 of
`base-standards.md` requires updating the change artefacts **first** and only then the code.
A fix that arrives between `apply` and `archive` is not «change it quickly»: it is a specification
update.

### Refute — `/adversarial-review`

In a session different from the one that implemented, because an agent reviewing its own work inherits
its own blind spots. Its job is to refute, not to approve:

```
### Findings
| Severity | File:line | Finding |
|---|---|---|
| Major | <service>:24 | The isolation scenario would still pass if the filter were applied before
                       ownership. The test does not distinguish the two orders |
| Minor | <test>:88   | The isolation test does not check the no-filter case, which is where the
                       inverted order would fail |

### Verdict
PASS WITH GAPS — no blockers, but the isolation test gap must be closed
```

That finding is the value of the hostile review: the green test does not prove what you thought it
proved. A friendly reviewer would not have said it.

### Security

The `security-reviewer` subagent on the diff: no high-severity findings, one medium warning for
the missing index that was already recorded as debt in `design.md`.

---

## F6 · Documentation

`/adr-new` first applies the necessity criterion, and in this case answers that **yes** it is
warranted: a new developer would wonder why the page size is fixed and not configurable, it affects
the client contract, and reverting it after integrations exist costs more than a day.

The resulting ADR transcribes what was already in `design.md`. It adds no new reasoning: if the
«why» was not in the design, the design was incomplete.

---

## F7 · Delivery

`/commit` first checks the documentation gate, proposes two atomic commits instead of one
—implementation and documentation separately— and, when the diff touches the API contract, the
`docs-gate` hook confirms it again before letting the commit through. Two layers for the same
guarantee, on purpose: the skill can forget to invoke, the hook cannot. `/pr-describe` generates
everything except the «why», which arrives marked:

```markdown
## What changes?
Adds an optional state filter to the listing, with validation against the domain state set,
and paginates the response with a fixed size. Without the parameter, behaviour is as before.

## Why?
<!-- completed by the human -->

## How to test it?
1. <migration and start command>
2. <request with a valid filter> → only the pending ones
3. <request with an invalid filter> → validation error with the allowed states
4. <filtered test command> → 5 tests green

## Traceability
| Scenario | Test |
|---|---|
| Filter by a valid state | <path>:34 |
| Listing without filter | <path>:52 |
| Unrecognised state | <path>:65 |
| Isolation between users | <path>:84 |
| Unauthenticated request | <path>:101 |

## Origin
agent+human-review
```

The human fills in the why: *«The pending view was downloading the full listing and filtering in
memory. Past 50 items it degraded the initial load and transferred data that is never
shown.»*

A model does not generate that. It is not in the diff.

---

## F8 · Close-out

Archive the change, delete the branch, and the P15 retro on the cycle data. In this case
an unforeseen task appeared —the second triangulation test— and the conclusion was actionable:
add to `docs/backend-standards.md` the rule that every implementation task carries its
triangulation from the
start.

That is the full loop: the process corrects itself with what it learns from each cycle.

---

## Takeaways

| Moment | Cost of skipping it |
|---|---|
| Cutting invented scope in F1 | An S story becomes an L, and nobody knows why |
| Writing the decisions in `design.md` | The agent decides for you mid-implementation, leaving no trace |
| Watching the test fail | A test born green proves nothing |
| Running the F5 demonstration | Tests pass and the feature does not work in the real environment |
| Reading block 3 of the verification | Behaviour in production that nobody specified or reviewed |
| Launching the hostile review in another session | The implementer's blind spots survive the review |
| Writing the PR «why» | Nobody will remember in six months why it was done this way |

The hooks handle the mechanical. The five gates are yours, and they are why the rest
works.

---

## And if the flow asks you to change the kit

It happens, and it is a good sign: it means the process is learning. The F8 retro produced a
new rule here. Where each thing goes:

| What you learned | Where it is written |
|---|---|
| A fact about this project | `docs/project-context.md` |
| An architecture convention | `docs/backend-standards.md` |
| A procedure you repeat in chat | A new skill in `ai-specs/skills/`, with `/writing-skills` |
| An invariant that cannot fail | A hook in `.claude/hooks/` |
| A command or path that changed | `.claude/sdd-harness.env` |

And always in `ai-specs/`, not in `.claude/skills/`: they are the same file only if your system allows
symlinks. Afterwards, `bash .claude/sync-artifacts.sh` to propagate. The
`/sync-agent-artifacts` skill diagnoses the state if something stopped resolving.
