---
description: Frontend development standards for Laravel Livewire — components, Blade, accessibility and testing.
globs: ["app/Livewire/**/*", "resources/views/**/*", "resources/js/**/*"]
alwaysApply: true
---

# Frontend Standards — Laravel Livewire

## 1. Technology stack

- **Laravel** + **Livewire** (Volt allowed where the project already uses it).
- **Blade** for markup. Escape by default.
- **Vite** for CSS/JS assets when the project has a frontend build.
- **Pest** (or PHPUnit) feature / component tests for Livewire behaviour.
- **Playwright** — end-to-end, for critical flows only.
- Accessibility automation via the project script **`test:a11y`** (axe-core, Pest a11y, or equivalent).

## 2. Architecture

- **Livewire components** live under the project's Livewire namespace (typically `app/Livewire/`) with
  matching views under `resources/views/`. A component orchestrates UI state; it does not own domain
  rules that belong in the backend service / action layer — follow `docs/backend-standards.md`.
- **Pages / full-page components** compose smaller Livewire (or Blade) units; they do not embed
  unbounded business logic.
- **Assets** (Alpine, CSS) go through Vite when configured; do not invent a second asset pipeline.
- Loading, empty, error and success (or equivalent Livewire states) are explicit in the UI, never silent.

## 3. Hard rules

- Prefer Blade `{{ }}` escaping. Never use `{!! !!}` with user-controlled or untrusted content.
- Never store long-lived secrets or API keys in frontend-exposed env (`VITE_*` / mixed into JS).
- Authorisation and validation of mutations happen on the server (Livewire actions / Form Requests /
  policies), not only in the browser.
- Prefer semantic HTML and accessible names; if a test cannot find a control by role or label, fix the
  markup first.
- Target **WCAG 2.2 AA**: contrast at least 4.5:1 for normal text, full keyboard operation with a
  visible focus, labelled controls, and landmarks. Automated axe (or equivalent) checks catch a
  fraction of issues; they do not replace a keyboard pass (and a screen-reader pass on critical journeys).
- Do not ask the agent to "optimise performance" without a measurement. Core Web Vitals targets:
  **LCP < 2.5s**, **INP < 200ms**, **CLS < 0.1**. Measure, change one thing, re-measure.
- Follow `docs/backend-standards.md` for API and persistence contracts; the UI does not invent shapes.

## 4. Testing

- Livewire / feature tests assert behaviour a user can observe: rendered text, emitted events,
  redirected flows, validation errors.
- Mock at real boundaries (outbound HTTP, third parties), not by rewriting the component under test.
- End-to-end only for critical journeys: authentication, the main creation flow, payment.
- Arrange-Act-Assert, the three blocks separated and commented.
- Run `npm run test:a11y` or the project's documented a11y command on UI touched by the change.

## 5. Definition of done for a frontend change

- Loading, empty, error and success (or equivalent) states implemented and visually checked.
- Keyboard navigation works for anything interactive; no new WCAG 2.2 AA regressions on touched UI.
- `test:a11y` is clean for the surfaces changed (or gaps are explicit non-goals in the change).
- If the change touches a route, hero, or LCP-critical assets, note the expected CWV impact (or attach
  a before/after measurement).
- The change was exercised in a real browser, by the agent, before the task was marked complete.
