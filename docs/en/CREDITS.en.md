# Origin and credits

**Language:** [Español](../es/CREDITS.md) · English

## Starting point

This kit comes from the **class notes of the AI4Devs Master** at
[LIDR Academy](https://lidr.co), and takes as a starting point the master’s reference repository:

**[`LIDR-academy/lidr-specboot`](https://github.com/LIDR-academy/lidr-specboot)** — MIT,
Copyright (c) 2026 LIDR.co

### What was taken from there

Architecture ideas and organisational conventions, not a copy of the content:

- The `ai-specs/` layout with **skills** and **subagents** as the repository’s canonical source,
  then referenced from each copilot’s folders.
- **Standards in `docs/`** as the document the agent reads so it does not reinvent architecture on
  every task.
- The **memory files** per copilot —`CLAUDE.md` and `AGENTS.md`— all pointing to a single doctrine
  instead of duplicating it.
- The general **Spec-Driven Development** approach on top of OpenSpec.

The skills, subagents, standards, templates, and hooks in this kit are written for it. Where a
convention matches, it matches because it was adopted on purpose.

### What this kit adds

| Addition | What it solves |
|---|---|
| **Installable** `install.sh` / `install.ps1`, with `--dry-run` and stack detection | Mount the harness on a new project without repeating the work by hand |
| **9 deterministic lifecycle hooks** | Turn a written convention into an enforced one. They act on the file path, not on which command wrote it |
| **Per-stack adapters** (`laravel`, `adonisjs`, `fastify`, `react`, `livewire`, template) | The same harness on different stacks without touching a skill or a hook |
| **Real Windows support** | First-class PowerShell, and copy when the OS does not allow symlinks |
| **`doctor.sh` / `doctor.ps1`** | Diagnose an install instead of guessing |
| **Deep secret gates** | Blocking in the prompt and on file reads, not only before commit |
| **29 skills and 9 subagents** | The TDD trilogy with isolated context per phase, `/adversarial-review`, `/migration-review`, `/architecture-audit`, `/privacy-ethics-check`, `/show-spec-working`, `/kit-health` |
| **Own doctrine** in `docs/base-standards.md` and `docs/documentation-standards.md` | The five human stop points and the documentation gate |

## Third-party tools

The kit does not ship them: it configures them or assumes they are installed.

| Tool | Role | Licence |
|---|---|---|
| [OpenSpec](https://www.npmjs.com/package/@fission-ai/openspec) (`@fission-ai/openspec`) | Governs `openspec/`: specs and changes. Installed separately, on purpose | See the package |
| [Context7](https://context7.com) | Library documentation MCP | See the provider |
| [Playwright MCP](https://github.com/microsoft/playwright) | UI demonstration. Does not replace the E2E suite | Apache-2.0 |
| [Figma MCP](https://developers.figma.com/docs/figma-mcp-server/) | Design → code context (`mcp.with-figma.json` template, optional) | See the provider |

## Licence of this kit

[MIT](LICENSE). The licence file keeps the copyright notice from `lidr-specboot`, as its own MIT
licence requires.
