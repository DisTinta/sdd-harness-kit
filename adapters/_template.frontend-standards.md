---
description: Frontend development standards for this project — component architecture, data access, state and testing. Framework-agnostic template; fill before relying on the agent for UI work.
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

- **{{framework / library}}** (e.g. React, Vue, Svelte, Angular, HTMX + server templates — pick one)
- **{{language and version}}** (TypeScript / JS / other)
- **{{bundler or meta-framework}}**
- **{{styling approach}}**
- **{{unit / component test runner}}**
- **{{e2e tool, if any}}**

## 2. Architecture

- **Routes / pages** live in `{{path}}`. A page orchestrates; it does not own business rules that belong on the server.
- **Components** live in `{{path}}`. Presentation separated from data loading where the stack allows it.
- **Data access** lives in `{{path}}` (services, API clients, server loaders). Components/pages do not build request URLs by hand or embed auth headers ad hoc.
- **State**: {{local defaults}}. Do not introduce a global store until {{explicit criterion}}.
- Server-originated state does not get duplicated into a client global store "for convenience".
- Loading, empty and error states are **{{required pattern}}** — never silent failures.

## 3. Hard rules

- Every value that crosses the network boundary is typed or validated at {{boundary}}.
- Never interpolate user input into markup that bypasses escaping / sanitisation.
- Never store long-lived secrets or session tokens in {{forbidden storage}} if {{preferred session mechanism}} is available.
- A unit that fetches, transforms, renders and handles errors should be split when it exceeds {{threshold}}.
- Prefer accessible queries in tests (`getByRole`, roles/labels appropriate to the stack) over test IDs as the first choice.
- No secrets in frontend-exposed environment variables. Anything shipped to the browser is public.
- Follow `docs/backend-standards.md` for API contracts; the UI does not invent response shapes.

## 4. Testing

- Component/UI tests assert behaviour a user can observe, not private implementation details.
- Mock at the **network or boundary** layer, not at random internal modules.
- End-to-end only for critical journeys: {{list}}. Everything else stays one level down.
- Arrange-Act-Assert (or the project equivalent), blocks separated and commented.
- Every user-visible `#### Scenario:` in a delta spec that belongs to the UI maps to a test.

## 5. Definition of done for a frontend change

- Matches the scenarios in the OpenSpec change (or the story acceptance criteria).
- Loading / empty / error paths exercised or explicitly non-goals.
- No new a11y regressions on interactive controls touched by the change.
- Docs/contracts updated if the UI exposes or depends on a new API shape.
