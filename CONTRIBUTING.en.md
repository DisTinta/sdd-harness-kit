# Contributing to `sdd-harness-kit`

**Language:** [Español](CONTRIBUTING.md) · English

Thanks for contributing. This repository uses a simple flow to keep quality and traceability.

## Workflow

- Create a branch from `main` for each change:
  - `feat/<short-description>`
  - `fix/<short-description>`
  - `docs/<short-description>`
- Avoid pushing directly to `main`.
- Open a Pull Request (PR) to land any change.

## Pull Request rules

- Use the PR template in `.github/pull_request_template.md`.
- Always fill in:
  - what changes
  - why
  - how to test it
  - traceability
- Keep PRs small and focused (ideally one goal per PR).
- If the change is large, split it into several PRs.

## Adding a stack adapter

[CONFIG.en.md](CONFIG.en.md) explains the four adapter files. This is the checklist of **everything
else** you must touch for it to be complete — it exists because the `fastify` adapter was left
half-finished the first time:

1. `adapters/<stack>.env` — required. The 24 contract variables from `_template.env`.
2. `adapters/<stack>.backend-standards.md` — the five questions from [CONFIG.en.md](CONFIG.en.md), with real paths.
3. `adapters/<stack>.rules.mdc` and `adapters/<stack>.ci.yml` — optional, but the other adapters ship them.
4. Extra stack config, if needed: `<stack>.infection.json`, `<stack>.dependency-cruiser.js`. Needs a copy block in **both** installers.
   The a11y scaffold (`react.a11y.smoke.example.tsx` / `livewire.a11y.smoke.example.mjs`) is UI, not
   backend-stack: it lives next to the frontend `*.frontend-standards.md` and `*.ci.yml`.
5. `detect_stack()` in `install.sh` **and** the equivalent block in `install.ps1`.
6. The `-Stack` parameter help in the `install.ps1` header, and `--stack` in the `install.sh` header.
7. The adapters table in [README.en.md](README.en.md).
8. `VERSION` and [CHANGELOG.md](CHANGELOG.md) **and** [CHANGELOG.en.md](CHANGELOG.en.md) (same entry in both).

And actually try it, with the four commands in the “Try it” section of [CONFIG.en.md](CONFIG.en.md). An
adapter that has never been installed into a test repository is not finished.

## Review and merge

- Request at least one review before merging.
- Check that the description and test steps are clear and executable.
- Prefer **Squash and merge** to keep history clean.

## Content conventions

- Human documentation at the root: **bilingual and paired** (Spanish + English). A docs PR updates
  both languages in the same change.
- Code, skills, agents, standards, and templates the agent reads: **English**.
- Prefer concrete, actionable didactic changes.
- Do not introduce unsolicited build tooling or frameworks.

## Commits

- Clear, specific messages.
- One commit should represent one coherent change.
- Avoid mixing refactor, docs, and functional changes in the same commit when it is not necessary.
