# SDD Harness Kit — briefing for Product

**Language:** [Español](../es/presentacion.md) · English

Internal document to explain the kit to non-technical roles. This is not an installation guide.

---

## In one sentence

The **SDD Harness Kit** is a set of rules, templates, and automations we install in a project so that AI builds **exactly what we agreed**, and not whatever it invents along the way.

It is not a product the end user sees. It is how the development team works when using copilots (Cursor, Claude Code, Copilot).

---

## The problem it solves

Today a three-sentence ticket reaches development and, if the one executing it is an AI, this happens:

1. The ticket is ambiguous.
2. The AI fills the gaps by **inventing** (extra scope, unrequested cases, a different architecture).
3. A human reviews at the end, when there are already hundreds of lines of code.
4. What gets delivered may “work” and still not be what Product wanted.

The cost of ambiguity multiplies. A small story becomes a large one without anyone having decided that.

The kit attacks that **before** writing code: first the contract is closed (what is in, what is out, how it is verified), and then we build against that contract.

---

## What Spec-Driven Development (SDD) is

**Spec-Driven Development** means: *first we agree on the behaviour, then we write the code*.

In practice:

| Before (usual flow) | With SDD |
|---|---|
| Ticket → code → “was this it?” | Ticket → **contract** → code that demonstrates the contract |
| Criteria live in someone’s head or in a Jira comment | Criteria are a document that AI and humans read the same way |
| If code and ticket disagree, the code wins (because it is already done) | If they disagree, **the specification wins**: we fix the code or we update the agreement; we never ignore the gap |

The specification is not a 40-page PDF. It is the **concrete change** of this unit of work: what is added, what is modified, what is out of scope.

Useful analogy: it is like a Git commit, but for requirements. We do not rewrite the whole product; we document the *diff* of this story.

**When you do not need this whole apparatus:** prototypes, spikes of a couple of hours, trivial fixes. Specifying has a cost; we use it when the change is worth an agreement.

---

## What OpenSpec is

**OpenSpec** is the tool that stores those agreements in the repository, next to the code.

Each unit of work (a “change”) leaves four pieces:

| Piece | In plain English | Who uses it |
|---|---|---|
| **Proposal** (`proposal.md`) | The business *why* and the scope | Product + development |
| **Specification** (`spec.md`) | Requirements and scenarios: “given X, when Y, then Z” | Development, review, AI |
| **Design** (`design.md`) | Technical decisions already closed, so the AI does not improvise architecture | Development |
| **Tasks** (`tasks.md`) | Actionable checklist, one task = one step | The AI walks through them; the human signs them off |

When the change is merged, it is **archived**. That way the next proposal knows what is already done. If it is left open, the context goes stale.

OpenSpec does not replace Jira or Product. It translates the ticket into a contract that a copilot can execute without guessing.

---

## What the kit is (and what it is not)

The kit is the **harness** around OpenSpec and the copilots: the discipline that makes the process actually happen, not just live in a best-practices document.

Installed once per project, it leaves:

- The same rules for Cursor, Claude Code, and Copilot (one doctrine, several tools).
- 27 “skills”: reusable procedures (`enrich the story`, `implement`, `verify`, `open the PR`…).
- 9 subagents: specialised roles (explore, audit the spec, write the test, review security…).
- 9 **hooks**: rules that are not interpreted, they are **executed**. They are the seatbelt.
- **MCP** (plugs into external tools): **Context7** (up-to-date library documentation) and **Playwright** (demonstrate the real interface in the browser).
- Templates, stack standards, and a health check (`doctor`).

**What it does not do:**

- It does not replace Product judgement or engineering judgement.
- It does not guarantee magical quality. It guarantees that certain mistakes **do not go unnoticed**.
- It does not know the product domain. That lives in a file we write ourselves (`project-context`). Whatever is not in there, the AI will invent.
- It is not a chatbot for the PO. The PO still talks to the team; the kit is for whoever implements.

---

## Context7 and Playwright: how the AI gets informed and how it demonstrates

On top of the rules and the seatbelts, the kit wires two **plugs** (in jargon: MCP, *Model Context Protocol*). They are not a user-facing product: they are channels so the copilot can query live information or act on a browser, instead of being limited to generating text.

Nobody needs to type “use Context7” in every conversation. The project rules already say *when* to use them. If a plug is off, the agent must say so and continue with what it has; it must not invent to compensate.

Jira, databases, or other connectors that carry secrets **do not** ship with the kit: each team adds those separately, because they carry credentials.

### Context7 — up-to-date docs, not two-year-old memory

An AI “knows” libraries and frameworks from what it saw during training. That knowledge **goes stale**: a command, a flag, or an API changes, and the copilot writes code that no longer exists — or never did.

**Context7** is a lookup against the library’s **current** documentation (React, Laravel, Fastify, the OpenSpec CLI, the test runner…). The kit fires it when the code is about to call an API that **is not defined in our repository**.

| It is used for… | It is not used for… |
|---|---|
| “What is this function in library X called now?” | The business rules of *our* product |
| Flags, versions, and setup that change between releases | Project context (`project-context`) |
| Avoiding invented or outdated APIs | Reviewing our own code |

Analogy: we do not ask a colleague how to use Stripe “from 2022 memory”; we open today’s docs. Context7 is that lookup, automatic.

**What Product gains:** less time wasted on “it compiled in the model’s head and not on our stack”, fewer odd dependencies, and fewer PRs that have to be redone because the library no longer works that way.

### Playwright — demonstrate the real screen, not describe it

In the verification phase the kit demands **evidence**, not a summary of what the code *seems* to do. If the change has a browser interface, **Playwright** opens an isolated browser, navigates, clicks, fills in fields, captures the state, and closes. It leaves a record that the scenario was exercised against the running system.

It is tied to “demonstrate that the spec works”: each “given / when / then” criterion is actually walked through. If there is no frontend (API only), we demonstrate via HTTP or the command line, and Playwright is not needed; the installer can omit it.

| It is used for… | It is not used for… |
|---|---|
| Demo of a UI flow agreed in the spec | Replacing the project’s E2E test suite (that remains the CI contract) |
| Evidence: screenshot / snapshot + result | Hitting production, capturing secrets or personal data |
| Covering on-screen error cases as well | Skipping the test-first cycle (TDD) |

Analogy: “I read the code and the filter should show up” is not enough. “I opened the screen, filtered by pending, and exactly 5 came back” is. That is what a PO would recognise as a demo, done by the agent and saved as a report.

**Isolated mode:** the browser does not reuse the developer’s session (cookies, logins). It is a separate box, on purpose.

**What Product gains:** verification stops being “green tests in a test environment” and starts including “I saw it in the interface, with the system running”. A human still has to **read** that evidence; Playwright does not sign off “this is good”.

---

## The workflow (from ticket to merge)

Think of it as a funnel: each phase reduces ambiguity. There are **five points where a human has to decide**; the rest can go faster with AI.

```
Ticket (Jira / Linear / whatever we use)
        │
        ▼
1. PLAN          Clear story + criteria + “what is NOT in”
        │         ◆ Product / tech lead cuts invented scope
        ▼
2. SPECIFY       The 4 OpenSpec documents (proposal, spec, design, tasks)
        │         ◆ Human opens, edits, and signs off the scope
        ▼
3. CODE PLAN     How it will be done (without writing it yet)
        │         ◆ Human approves the plan
        ▼
4. IMPLEMENT     Task by task, with test first
        │         Automations watch (see next section)
        ▼
5. VERIFY        Does it do what we agreed? Does it do extra? Are there holes?
        │         ◆ Human reads the evidence, not just “tests are green”
        ▼
6. DOCUMENT      Only what is needed (decisions that are hard to reverse)
        ▼
7. DELIVER       Commits + PR with what / why / how to test it
        │         ◆ Human writes the “why” and signs the merge
        ▼
8. CLOSE         Archive the change + learn for the next one
```

### What Product sees in each phase

**1. From ticket to executable story**  
The AI proposes scenarios (edge cases, unauthenticated, isolation between users…). It almost always puts in extra: extra sorting, new pagination, endpoints nobody asked for. **The highest-return work is cutting.** Without that cut, an S story arrives in development as an L.

**2. From story to contract**  
It is written down: what must happen, what is out of scope (non-goals), and how it will be verified. Product does not have to write YAML; it does have to say “yes / no / not this” on the scope.

**3–4. Plan and implementation**  
Development. Product does not intervene unless a scope question appears. If a library that is not in our code is needed, **Context7** looks up the current documentation so the API is not invented.

**5. Verification (the one most often skipped without the kit)**  
“Tests pass” is not enough. The agent **exercises the scenarios against the real system** and leaves evidence: on API, with real requests; on screen, with **Playwright** walking the browser. Then it looks for the unrequested: extra behaviour nobody reviewed. A “hostile” review tries to **refute** the work, not congratulate it.

**7. Pull request**  
The AI can draft the “what changes” and the “how to test it”. **The “why” is written by a person.** The merge is signed by a person.

---

## What the kit does automatically (without anyone asking)

This is what separates “we have a process document” from “the process actually happens”.

**Hooks** are checks that fire on their own while the copilot works:

| If the copilot tries to… | The kit… |
|---|---|
| Paste passwords, tokens, or read `.env` files | Blocks it. Secrets do not enter the chat |
| Mass-delete, `push --force`, touch production | Blocks it or asks for human confirmation |
| Install a new library | Asks for confirmation (almost 1 in 5 packages an AI “recommends” does not exist; there are attacks that register those names) |
| Rewrite tests or the specification to fit a code shortcut | Asks. A human decides whether the design actually changed |
| Mix layers (e.g. business logic in the HTTP controller) | Hands control back so it can be fixed |
| Commit an API or schema change without touching the documentation | Prevents it |
| Write an incomplete task list (no branch, no verification, no data restore) | Rejects it on the spot |
| End the turn with tests in red | Does not let it close |

Also, at the **start of every session**, it injects only: current branch, active OpenSpec changes, pending tasks, and project commands. There is no need to “tell it the context” every morning.

The MCP plugs also come in on their own when it is time:

| Moment | What happens |
|---|---|
| Planning or implementing against an external library | **Context7** brings in the current docs; it does not trust the model’s “memory” |
| Demonstrating an interface scenario | **Playwright** opens an isolated browser, walks the flow, and leaves evidence |
| The plug is off or there is no frontend | It says so and continues (HTTP/CLI). It does not invent APIs or fake a demo |

In the **GitHub pipeline** (if enabled): automatic PR review with the same criteria as the kit. **It does not replace human review**; it is a first pass.

Other actions the team triggers with a command, but that the kit standardises:

- Enrich the story and mark Definition of Done by type (feature, bug, refactor, spike, docs).
- Implement by walking the tasks, with test in red → minimal code → refactor.
- Demonstrate each scenario against the running system, with a report (Playwright if there is UI).
- Contrast code vs. specification (what is missing **and** what is extra).
- Security, privacy, and ethics review.
- Atomic commits and PR description (the “why” is left empty on purpose).

---

## Where a person is still required

The kit automates the mechanical parts. **These five are not delegated.** If they are skipped, the rest amplifies the error instead of saving you.

1. **Story and criteria** — Do not accept AI criteria without checking them against the real product. Cut invented scope. Lock what is out.
2. **Contract** — Open and edit proposal / spec / design / tasks. Sign off the scope.
3. **Plan before executing** — If it touches many pieces or has side effects: the plan is approved, then code is written.
4. **Tests and evidence** — The “done” criterion is human. The real demonstration and unspecified behaviours are read.
5. **Merge** — The agent can open the PR; a person signs. The “why” does not come out of the diff.

Message for Product: you do not disappear from the cycle. You move **earlier**, where the decision is cheap (scope, non-goals, “is this what we wanted?”) instead of at the end, when undoing costs a sprint.

---

## Advantages of working this way

### For Product

- **Fewer “that wasn’t it” moments.** Scope is closed in writing, with scenarios and with *what is not in*, before spending days of implementation.
- **More honest estimates.** A vague story is inflated by the AI. A trimmed story can actually be sized. The kit material recommends a 30–40% buffer (verification, quality, tool rotation), not 10%.
- **Traceability.** Each scenario in the spec is tied to a test and to the PR. You can answer: “is what we asked for covered?”.
- **Less ghost scope.** Verification looks for *extra* behaviour, not only *missing* behaviour. That is gold for not shipping things nobody asked for and nobody reviewed.
- **PRs that can be tested.** “What / why / how to test it” stops being optional.

### For the team and the business

- **AI stops being a loose code generator** and becomes an executor of a contract. Same discipline with Cursor, Claude, or Copilot.
- **Less rework.** The error is caught in the spec or in the plan, not in QA or in production. Context7 avoids redoing work because “the library is no longer used that way”.
- **Demos with evidence, not with faith.** Playwright walks the agreed screen; the report can be checked against the acceptance criteria.
- **Security by default.** Secrets, brute force in Git, invented dependencies, and tests “fixed” to go green: the kit stops them. Playwright is not used against production or to capture personal data.
- **The process holds even if nobody remembers the document.** A written convention is ignored; a hook is not.
- **Learning from cycle to cycle.** On archive and retro, what went wrong becomes a project rule, not an anecdote.

### What changes day to day (real example from the kit)

Ticket: *“Filter the list by status; the client downloads everything and filters in memory.”*

Without the kit, a reasonable copilot might add configurable sorting, new pagination, and a count endpoint. Story S → L.

With the kit: the AI proposes those extras; **the human throws them out** at the first gate; the contract says “filter only, do not touch the client, no indexes in this ticket”; implementation is verified against those five scenarios (including isolation between users and unauthenticated). The PR explains the business why, which is not in the diff.

---

## Short script

1. **It is not another user-facing tool.** It is how the team uses AI without losing control of scope.
2. **SDD:** first the agreement, then the code. The spec wins over the code.
3. **OpenSpec:** the place in the repo where that agreement lives (why, what, how, checklist).
4. **The kit:** the harness that makes it stick: templates + roles + automatic seatbelts.
5. **Two plugs:** Context7 (current library docs, so APIs are not invented) and Playwright (real demo in the browser, not a “it should look like this”).
6. **Flow:** ticket → trim the story → sign the contract → plan → implement with tests → demonstrate on the real system → PR → human merge.
7. **Product wins** if it takes part in cutting and in signing off “what is not in”. If it only shows up at the demo, the kit cannot save a vague ticket.
8. **Honesty:** it does not promise infinite speed or zero bugs. It promises we do not build blind, and that certain typical failures of working with AI do not sneak in.

---

## FAQ

**Does this slow down delivery?**  
The specification adds time at the start and takes it away at the end (fewer round trips, fewer 800-line PRs). On trivial tickets the full cycle is not used.

**Does Product have to write the spec?**  
No. Product brings the problem, the value, and the cut. Development (with AI) drafts the contract. Product or tech lead **validates** scope and non-goals.

**Does it replace Jira / the backlog?**  
No. The backlog remains the work queue. OpenSpec is the contract for *this* unit when it enters implementation.

**Can we still use AI “in chat” for small things?**  
Yes. The kit is designed for story-level work (the “I assign you the task and I review the PR” level), not for every autocomplete.

**Who signs off on quality?**  
Still the team. The kit makes shortcuts visible; it does not forgive them in silence.

**What is this Context7 thing?**  
A plug so the AI reads the **current** documentation of libraries and frameworks, instead of trusting what it “remembers”. It avoids stale code or invented APIs. It does not know our product: that is what project context is still for.

**And Playwright? Does it replace QA?**  
No. It is a browser the agent uses to **demonstrate** a screen flow agreed in the spec and leave evidence. The project’s end-to-end test suite and human review remain the contract. If the product has no web interface, Playwright is not even installed.

---

*SDD Harness Kit · internal material · AI4Devs · LIDR Academy*
