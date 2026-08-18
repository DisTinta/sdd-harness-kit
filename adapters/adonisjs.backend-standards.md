---
description: Backend development standards for AdonisJS — layered architecture, validation, persistence, API design and testing.
globs: ["app/**/*.ts", "start/**/*.ts", "database/**/*.ts", "tests/**/*.ts"]
alwaysApply: true
---

# Backend Standards — AdonisJS

## 1. Technology stack

- **AdonisJS** — application framework, HTTP layer and IoC container
- **TypeScript** in strict mode
- **Lucid ORM** — models, relations, query builder, migrations
- **VineJS** — input validation
- **Japa** — test runner
- **Biome** — linter and formatter (replaces ESLint + Prettier)

## 2. Layered architecture

A vertical slice is always implemented in this order, and in these files:

1. `tests/functional/<capability>/<action>.spec.ts` — the failing test. Human authored.
2. `app/validators/<resource>.ts` — VineJS. The single source of truth for the shape of the input.
3. `app/models/<resource>.ts` — Lucid: columns, relations, reusable scopes.
4. `app/services/<resource>_service.ts` — business logic.
5. `app/controllers/<resources>_controller.ts` — HTTP: validate, delegate, serialise.
6. `start/routes.ts` — route registration with its middleware.

Dependency direction: controller → service → model. Never the reverse.

## 3. Hard rules

- Business logic lives in `app/services/`. **Never** in `start/routes.ts` and never in a controller.
- A controller method does exactly three things: `request.validateUsing(<validator>)`, call the
  service, return the serialised response. If it does a fourth, it is in the wrong layer.
- A service never imports `HttpContext` and never knows an HTTP status code. It receives validated
  data, returns domain entities, and throws domain exceptions from `app/exceptions/`.
- Every HTTP input passes through a validator in `app/validators/`. No exceptions.
- Reusable queries are expressed as Lucid scopes on the model, not as loose `where()` calls scattered
  across services.
- Never return a raw Lucid model: use `.serialize()` or a transformer, enumerating the fields.
- Ownership scoping is applied **always and first**, before any optional filter. No combination of
  parameters may return another subject's data.
- Every listing is paginated with `.paginate()`. An endpoint without an upper bound is a denial of
  service vector.
- No `any` and no `as unknown as`. Explicit return types on every public method.
- Files in snake_case (`task_service.ts`), classes in PascalCase (`TaskService`).
- Imports through subpath imports (`#services/...`, `#models/...`), never long relative paths.

## 4. Validation

- One compiled validator per operation, exported with an explicit name (`createTaskValidator`).
- Closed sets of domain values are declared once as a `const` tuple in the model and derived from
  there by `vine.enum`. The tuple is the single source of truth.
- Error messages are part of the contract with the client: write them deliberately.
- Query strings are validated too: `request.validateUsing(v, { data: request.qs() })`.

## 5. Persistence

- Migrations are the versioned history. Never edit one already applied on the base branch: create a
  new one, and verify it rolls back.
- Avoid N+1: preload relations explicitly.
- Select only the columns you need on hot paths.
- Transactions for any operation that writes to more than one table.

## 6. API design

- RESTful resource URLs, correct verbs, plural resources.
- Consistent response shape across every endpoint, including errors.
- Status codes: 200 read, 201 created, 204 no content, 401 unauthenticated, 403 unauthorised,
  404 missing, 422 validation, 500 unexpected. VineJS emits 422 by default in AdonisJS — do not
  intercept it to return 400.
- Every route that needs a session declares its auth middleware explicitly at the route or group.

## 7. Testing

- Japa. Functional tests in `tests/functional/<capability>/<action>.spec.ts`.
- Test name format: what the unit does, in which scenario, with what expected result.
- Arrange-Act-Assert, the three blocks separated and commented.
- Global transaction per test for isolation. Test database in memory.
- Build test data with factories, never by hand in the Arrange block.
- Assert on the contract: status, response shape, persisted effects. Never on internal details.
- Mock only at real boundaries: outbound HTTP, third-party services, clock, randomness. The database
  is real and ephemeral.
- Every `#### Scenario:` in a delta spec maps to exactly one test, with a comment linking them.

### Anti-patterns

- Do not test implementation details; test behaviour.
- Do not ignore or skip a failing test.
- Do not use a real external service in a functional test.
- Do not build overly elaborate setups: if the Arrange block is longer than the Act and Assert
  together, the design is telling you something.

## 8. Security

- Validate and sanitise every external input before it reaches the service layer.
- Never commit `.env` or secrets. Validate required environment variables at boot and fail loudly.
- Authorisation is checked against the resource, not only authentication: verify ownership.
- No raw SQL built by string interpolation.
- Never expose password hashes, tokens or internal columns in a serialised response.
