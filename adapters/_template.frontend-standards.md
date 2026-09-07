---
description: Frontend development standards for this project — component architecture, data access, state, accessibility and testing. Framework-agnostic template; fill before relying on the agent for UI work.
globs: []
alwaysApply: true
---

# Frontend Standards

<!-- Fill this in with real paths from your project. Leaving it as a React-shaped guess is how the
     agent invents a second frontend architecture.

     Answer these five questions with real paths and you have the whole document:
       1. Where do pages/routes live, and where do reusable components live?
       2. Where does every network call go (service/API layer), and what must components NOT do?
       3. How is client state handled — and when is global state forbidden?
       4. How are loading, empty and error states required to surface in the UI?
       5. In what order are files touched for a vertical UI slice?                              -->

## 1. Technology stack

- **{{framework / library}}** (e.g. React, Vue, Svelte, Angular, Livewire, HTMX + server templates)
- **{{language and version}}** (TypeScript / JS / PHP / other)
- **{{bundler or meta-framework}}**
- **{{styling approach}}**
- **{{unit / component test runner}}**
- **{{e2e tool, if any}}**
- Accessibility automation via **`{{test:a11y or equivalent}}`** (axe-core or stack equivalent)

## 2. Architecture

- **Routes / pages** live in `{{path}}`. A page orchestrates; it does not own business rules that belong on the server.
- **UI units** (components / Livewire components / partials) live in `{{path}}`. Presentation separated from data loading where the stack allows it.
- **Data access** lives in `{{path}}` (services, API clients, server loaders, backend actions). UI units do not build request URLs by hand or embed auth headers ad hoc.
- **State**: {{local defaults}}. Do not introduce a global store until {{explicit criterion}}.
- Server-originated state does not get duplicated into a client global store "for convenience".
- Loading, empty and error states are **{{required pattern}}** — never silent failures.

## 3. Hard rules

- Every value that crosses the network boundary is typed or validated at {{boundary}}.
- Never interpolate user input into markup that bypasses escaping / sanitisation.
- Never store long-lived secrets or session tokens in {{forbidden storage}} if {{preferred session mechanism}} is available.
- A unit that fetches, transforms, renders and handles errors should be split when it exceeds {{threshold}}.
- Prefer accessible queries in tests (roles/labels appropriate to the stack) over test IDs as the first choice.
- No secrets in frontend-exposed environment variables. Anything shipped to the browser is public.
- Follow `docs/backend-standards.md` for API contracts; the UI does not invent response shapes.
- Target **WCAG 2.2 AA**: contrast ≥ 4.5:1 for normal text, full keyboard use with visible focus,
  labelled controls, landmarks. Automated checks do not replace a keyboard pass on critical journeys.
- Core Web Vitals targets: **LCP < 2.5s**, **INP < 200ms**, **CLS < 0.1**. Do not "optimise"
  without a measurement; change one thing and re-measure.

## 4. Testing

- Component/UI tests assert behaviour a user can observe, not private implementation details.
- Mock at the **network or boundary** layer, not at random internal modules.
- End-to-end only for critical journeys: {{list}}. Everything else stays one level down.
- Arrange-Act-Assert (or the project equivalent), blocks separated and commented.
- Every user-visible `#### Scenario:` in a delta spec that belongs to the UI maps to a test.
- Run `{{test:a11y}}` on UI touched by the change before calling the work done.

### Wiring `{{test:a11y}}`

React and Livewire adapters copy `tests/a11y/smoke.example.*` (not auto-discovered). This template
does not. When you pick a stack, add an equivalent scaffold, then:

1. Install axe-core (or the stack equivalent) as a devDependency.
2. Rename the example so the test runner discovers it (or point a Node script at it).
3. Add a `package.json` script named **`test:a11y`** — CI looks for that exact name.
4. Point it at a **real** UI surface, not a placeholder.

Do not add a no-op script that always exits 0. The kit never edits `package.json`.

## 5. Definition of done for a frontend change

- Matches the scenarios in the OpenSpec change (or the story acceptance criteria).
- Loading / empty / error / success paths exercised or explicitly non-goals.
- Keyboard navigation works for interactive controls; no new WCAG 2.2 AA regressions on touched UI.
- `{{test:a11y}}` clean for changed surfaces (or gaps listed as non-goals).
- If the change touches a route, hero, or LCP-critical assets, note CWV impact or attach a measurement.
- Docs/contracts updated if the UI exposes or depends on a new API shape.
- The change was exercised in a real browser, by the agent, before the task was marked complete.
