---
description: Backend development standards for this project — layered architecture, validation, persistence, API design and testing.
globs: []
alwaysApply: true
---

# Backend Standards

<!-- Fill this in with real paths from your project. This file is what stops the agent from inventing
     a different architecture on every task.

     Answer these five questions with real paths and you have the whole document:
       1. Where does business logic live, and where can it NOT live?
       2. Where does every external input enter and get validated?
       3. What must the business layer never know about? (usually: the transport)
       4. How is output serialised, and what guarantees an internal field is never leaked?
       5. In what order are files touched when implementing a vertical slice?          -->

## 1. Technology stack

- **{{framework}}**
- **{{language and version}}**
- **{{ORM or persistence layer}}**
- **{{validation}}**
- **{{test runner}}**
- **{{linter and static analysis}}**

## 2. Layered architecture

A vertical slice is always implemented in this order, and in these files:

1. `{{path to the failing test}}` — human authored.
2. `{{path to validation}}` — the single source of truth for the shape of the input.
3. `{{path to the model}}`
4. `{{path to business logic}}`
5. `{{path to serialisation}}`
6. `{{path to the entry point and route registration}}`

Dependency direction: {{transport}} → {{business}} → {{persistence}}. Never the reverse.

## 3. Hard rules

- Business logic lives in `{{path}}`. **Never** in `{{forbidden path}}`.
- The {{transport layer}} does exactly three things: validate, delegate, serialise.
- The business layer never imports {{transport type}} and never knows a status code.
- Every external input passes through {{validation layer}}. No exceptions.
- Every output passes through {{serialisation layer}}, with fields enumerated explicitly.
- Ownership scoping is applied always and first, before any optional filter.
- Every listing is paginated.
- {{Typing rule for your language}}
- {{File and class naming conventions}}

## 4. Validation

- {{Where validation lives and how it is expressed}}
- Closed sets of domain values are declared once and derived from there.
- Error messages are part of the contract with the client.

## 5. Persistence

- Migrations are the versioned history. Never edit one already applied: create a new one.
- Zero-downtime schema changes follow **Expand → Backfill → Migrate reads → Contract**. Destructive
  `DROP`s and renames ship in a **later, separate** migration after readers have moved. Before applying
  to a shared environment, review the generated SQL (or run `/migration-review`): `DROP COLUMN` /
  `DROP TABLE`, `UNIQUE` on existing data, truncating `ALTER TYPE`, and renames that are secretly
  drop-and-add.
- Avoid N+1.
- Transactions for any operation writing to more than one table.

## 6. API design

- {{URL and verb conventions}}
- Consistent response shape across every endpoint, including errors.
- {{Status code map, and any framework default you must not fight}}

## 7. Testing

- {{Runner and test location}}
- Arrange-Act-Assert, the three blocks separated and commented.
- {{How isolation works: transactions, in-memory database, containers}}
- Build test data with factories.
- Assert on the contract, never on internal details.
- Mock only at real boundaries: outbound HTTP, third-party services, clock, randomness.
- Every `#### Scenario:` in a delta spec maps to exactly one test.

## 8. Security

- Validate and sanitise every external input.
- Never commit secrets. Validate required environment variables at boot.
- Authorisation is checked against the resource, not only authentication.
- No queries built by string interpolation.
- Never expose credentials, tokens or internal fields in a response.
