---
description: Backend development standards for Laravel — layered architecture, validation, persistence, API design and testing.
globs: ["app/**/*.php", "routes/**/*.php", "database/**/*.php", "tests/**/*.php"]
alwaysApply: true
---

# Backend Standards — Laravel

## 1. Technology stack

- **Laravel** — application framework and service container
- **PHP 8.3** with `declare(strict_types=1);` in every file
- **Eloquent** — models, relations, scopes, migrations
- **Form Requests** — input validation and entry authorisation
- **API Resources** — output serialisation
- **Pest** — test runner
- **Pint** — formatter · **PHPStan** — static analysis · **Infection** — mutation testing

## 2. Layered architecture

A vertical slice is always implemented in this order, and in these files:

1. `tests/Feature/<Capability>/<Action>Test.php` — the failing test. Human authored.
2. `app/Enums/<Name>.php` — backed enum when the domain has a closed set of values.
3. `app/Http/Requests/<Action>Request.php` — validation and entry authorisation.
4. `app/Models/<Model>.php` — casts, relations, reusable scopes.
5. `app/Services/<Model>Service.php` — business logic.
6. `app/Http/Resources/<Model>Resource.php` — the exact shape of the output.
7. `app/Http/Controllers/...` and `routes/api.php`.

Dependency direction: controller → service → model. Never the reverse.

## 3. Hard rules

- `declare(strict_types=1);` on the first line of every PHP file.
- Business logic lives in `app/Services/`. **Never** in `routes/api.php` and never in a controller.
- A controller method does exactly three things: receive a validated Form Request, call the service,
  return a Resource. No Eloquent queries in a controller.
- A service never receives `Illuminate\Http\Request` and never returns `JsonResponse`. It receives
  scalars or DTOs, returns models or collections, and throws domain exceptions from `app/Exceptions/`.
- Every HTTP input passes through a Form Request in `app/Http/Requests/`. No exceptions.
- Every API output passes through a Resource with the fields **enumerated explicitly**. Never
  `return $model;` and never `parent::toArray($request)` on a public API: a new column would leak.
- Never `$request->all()` into `create()` or `update()`. Mass assignment is a vulnerability, not a
  shortcut.
- Closed sets of domain values are backed enums in `app/Enums/`, and they are the single source of
  truth: the model cast and the validation rule derive from the enum.
- Reusable queries are Eloquent scopes, not loose `where()` calls scattered across services.
- Ownership scoping is applied **always and first**, before any optional filter.
- Every listing is paginated. An endpoint without an upper bound is a denial of service vector.
- Explicit types on parameters and returns. Collection generics documented in PHPDoc
  (`@return LengthAwarePaginator<int, Task>`).
- Constructor injection with promoted `readonly` properties.

## 4. Validation

- `authorize()` carries the real check, not a reflexive `return true;`.
- `rules()` typed as `array<string, list<mixed>>`. Use `Rule::enum(...)` for enums.
- `messages()` only where the default is not useful to the client: the message is part of the contract.
- Expose typed accessors on the Form Request (`status(): ?TaskStatus`) so the controller does not
  re-parse validated data.
- Failed validation returns **422** automatically on JSON requests. Do not catch it to return 400.

## 5. Persistence

- Migrations are the versioned history. Never edit one already applied on the base branch: create a
  new one, and make sure `down()` actually works.
- Update the factory whenever a model gains a column.
- Avoid N+1: eager load with `with()`.
- Transactions for any operation that writes to more than one table.

## 6. API design

- RESTful resource URLs, correct verbs, plural resources.
- Consistent response shape across every endpoint, including errors.
- Status codes: 200 read, 201 created, 204 no content, 401 unauthenticated (Sanctum returns 401, not
  403), 403 unauthorised by policy, 404 missing, 422 validation, 500 unexpected.
- Every route that needs a session declares its auth middleware explicitly at the route or group.
- Authorisation through a Policy invoked from the controller, or an explicit ownership check in the
  service. Not both, and never neither.

## 7. Testing

- Pest. Feature tests in `tests/Feature/<Capability>/<Action>Test.php`.
- `it('describes the observable behaviour')`. The name explains the behaviour without reading the body.
- Arrange-Act-Assert, the three blocks separated and commented.
- `RefreshDatabase` with an in-memory database for isolation.
- Build test data with factories, never `Model::create()` by hand in the Arrange block.
- Assert on the contract: `assertStatus`, `assertJsonCount`, `assertJsonPath`,
  `assertJsonValidationErrors`, `assertDatabaseHas`. Never on internal details.
- Mock only at real boundaries: outbound HTTP, third-party services, clock, randomness.
- Every `#### Scenario:` in a delta spec maps to exactly one test, with a comment linking them.
- Mutation testing on `app/Services` for critical paths. Coverage is a signal; mutation score is the
  gate.

### Anti-patterns

- Do not test implementation details; test behaviour.
- Do not ignore or skip a failing test.
- Do not use a real external service in a feature test.
- Do not assert on a full JSON structure when the test is about one field: it breaks on every unrelated
  change.

## 8. Security

- Validate and sanitise every external input before it reaches the service layer.
- Never commit `.env` or secrets. `APP_KEY` in particular never appears in a diff.
- Authorisation is checked against the resource, not only authentication.
- No `DB::raw`, `whereRaw` or `selectRaw` with interpolated variables.
- `$hidden` on sensitive model attributes, and Resources that enumerate fields, are two independent
  layers: use both.
