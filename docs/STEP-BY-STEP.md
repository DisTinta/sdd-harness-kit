# Step-by-step guide — SDD Harness Kit

**Language:** [Español](GUIA-PASO-A-PASO.md) · English

Getting-started guide to install and use the kit in a product repository. Human documentation
(English). Skills and technical standards remain in English.

Source kit: this folder (`sdd-harness-kit`, version in `VERSION`).  
Target: **your** application project (do not install the kit on itself).

More detail: [USAGE.md](USAGE.md) · [MANUAL.en.md](MANUAL.en.md) · [CONFIG.en.md](CONFIG.en.md) · [PROMPTS.en.md](PROMPTS.en.md).

---

## 0. Prerequisites


| Requirement                | What for                  | Windows                                                                                         | Unix (Linux/macOS)                        |
| -------------------------- | ------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------- |
| **Node.js ≥ 20.19**        | OpenSpec CLI              | [nodejs.org](https://nodejs.org) or `winget install OpenJS.NodeJS.LTS` — check with `node -v`   | `node -v`                                 |
| **Git**                    | Repo + session context    | Git for Windows (includes **Git Bash**)                                                          | System `git`                              |
| **Git Bash**               | Run `.sh` hooks           | Comes with Git for Windows; use it or call `bash` from PowerShell                               | Native bash                               |
| **jq**                     | Parse hook JSON           | `winget install jqlang.jq`                                                                      | `brew install jq` / `sudo apt install jq` |
| **OpenSpec CLI**           | Changes / specs           | After Node: `npm install -g @fission-ai/openspec`                                               | Same                                      |
| **Claude Code and/or Cursor** | Agent surfaces         | Whichever your team uses                                                                        | Same                                      |


Quick check:

```bash
node -v          # v20.19 or higher
jq --version
git --version
bash --version   # on Windows: from Git Bash, or `bash -lc 'echo ok'` if Git is on PATH
openspec --version
```

Without `jq`, hooks **disable themselves** (the session does not break, but you lose the guards). Without `bash`, hooks do not run.

---



## 1. Installation (dry-run → install)

Work from the **kit** folder (this one), not the target project.

### Windows (PowerShell)

```powershell
cd "C:\ruta\a\sdd-harness-kit"

# 1) Simulation: lists what it would touch, does not write
.\install.ps1 -Dest C:\proyectos\mi-api -DryRun

# 2) Real installation
.\install.ps1 -Dest C:\proyectos\mi-api

# Optional: force adapter
.\install.ps1 -Dest C:\proyectos\mi-api -Stack adonisjs
```



### Linux / macOS

```bash
cd /ruta/a/sdd-harness-kit

./install.sh --dest ~/proyectos/mi-api --dry-run
./install.sh --dest ~/proyectos/mi-api

# Optional:
./install.sh --dest ~/proyectos/mi-api --stack laravel
```

When it finishes you should see something like `enlazados N · copiados N`:

- **enlazados** = symlinks to `ai-specs/` (ideal).
- **copiados** = the OS did not allow symlinks (typical on Windows without Developer Mode). **It works the same**, but you must always edit `ai-specs/` and then sync (see § Troubleshooting).

The installer does **not** run `openspec init` or fill in the meaning of `project-context` for you.
It does copy `.mcp.json` and `.cursor/mcp.json` (Context7; Playwright unless `--no-frontend` / `-NoFrontend`).
The first session in Cursor or Claude Code usually asks permission to start those servers: accept it.
You do not need to paste `use context7` into every prompt; the project doctrine already triggers its use.

---



## 2. Complete `docs/project-context.md` (P0)

This is the highest-return step. The installer leaves adapter commands and `{{...}}` placeholders.

1. Open `docs/project-context.md` in the **target project**.
2. Replace every `{{...}}`: product, how you test, branch conventions, gotchas.
3. Under ~200 lines. Only what the agent **cannot** infer by reading the code.
4. Write it **in English** (kit doctrine: technical artifacts in English).

You can use the **P0 prompt** from [PROMPTS.en.md](PROMPTS.en.md) so the agent drafts a proposal and you mark what it inferred.

Also review the same day:

- `.claude/sdd-harness.env` — run `CMD_TEST` by hand (if it is slow, point it at the fast suite). If `CMD_STATIC` / `CMD_MUTATION` or `ci.yml` point at binaries that are not in the manifest (typical: PHPStan and Infection on Laravel), do not treat them as real commands: see [USAGE.md — Common problems](USAGE.md#common-problems).
- `docs/backend-standards.md` — adjust if your architecture is not the adapter’s.
- `docs/frontend-standards.md` — if it is not React or Livewire, start from `adapters/_template.frontend-standards.md` in the kit.
- `tests/a11y/smoke.example.*` — axe-core scaffold; wire `test:a11y` when you want the gate (see `docs/frontend-standards.md`).

---



## 3. `openspec init` + apply `config.yaml.tpl`

**After the kit, not before.**

```bash
cd C:\proyectos\mi-api    # or ~/proyectos/mi-api
npm install -g @fission-ai/openspec   # if not yet
openspec init                         # choose Claude Code, Cursor, etc.
```

Check that init did not unintentionally overwrite kit settings:

```bash
git status --short
git diff .claude/settings.json     # ideally empty or reviewed
```



### Wire OpenSpec to the kit

1. Copy the kit template into the project:

```bash
# From the project, if the template is already in ai-specs (after install):
cp ai-specs/templates/openspec/config.yaml.tpl openspec/config.yaml
```

On Windows (PowerShell):

```powershell
Copy-Item ai-specs\templates\openspec\config.yaml.tpl openspec\config.yaml
```

1. Open `openspec/config.yaml`, remove only what does not apply, and keep the pointers to `docs/` and `ai-specs/`.
2. Do not paste novels into `context` (~50KB limit): paths and short rules are enough.

Native `/opsx:*` commands and kit ones (`/openspec-implement`, etc.) can coexist: hooks look at **file paths**, not who wrote the change.

---



## 4. Verify with the doctor / `/kit-health`

In the project:

```bash
bash .claude/doctor.sh --dest .
```

```powershell
powershell -File .claude\doctor.ps1 -Dest .
```

Or in the agent session:

```
/kit-health
```

You should be able to explain the status of: `jq`, skills sync, `project-context` without `{{...}}`, OpenSpec initialized, `openspec/config.yaml`, `BRANCH_PREFIX`, and that `CMD_TEST` really exists.

Minimal hooks smoke test (with bash + jq):

```bash
export CLAUDE_PROJECT_DIR=$PWD   # in Git Bash / Unix
echo '{"source":"startup"}' | bash .claude/hooks/session-context.sh | jq .
```

---



## 5. Daily flow F0–F8 (summary with skills)


| Phase                 | What you do                                    | Useful skills / pieces                                                             |
| --------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------- |
| **F0** Harness        | Context loaded, healthy env, clean session     | `/kit-health` if something smells wrong                                            |
| **F1** Planning       | INVEST story + criteria + non-goals            | `/enrich-us`, `/dod-feature` (or another `/dod-`*)                                 |
| **F2** Specification  | proposal + delta spec + design + tasks         | `/opsx:propose` or P5; then `spec-auditor` / P6                                    |
| **F3** Arming         | Skills, plan mode, MCP                         | Plan mode (`Shift+Tab` ×2). Context7 when planning library APIs; Playwright for UI demos |
| **F4** Execution      | Task by task, TDD                              | `/openspec-implement` or `/opsx:apply`; `/tdd-red` → `/tdd-green` → `/tdd-refactor` |
| **F5** Verification   | Real evidence + conformance + hostile review   | `/show-spec-working`, `/verify-against-spec`, `/adversarial-review`                |
| **F6** Documentation  | Contracts / ADR if applicable                  | `/update-docs`, `/adr-new`                                                         |
| **F7** Delivery       | Atomic commits + PR                            | `/commit` (`feat(TICKET): …`), `/pr-describe`, `/pr-review` |
| **F8** Closure        | Archive change + learn                         | `/opsx:archive`; notes in `project-context` or standards                           |
| **Cross-cutting**     | Privacy / deps / data                          | `/privacy-ethics-check`                                                            |
| **Loose prompts**     | Before an expensive session                    | `/meta-prompt`                                                                     |


Narrative detail: [MANUAL.en.md](MANUAL.en.md) · full example: [EXAMPLE.md](EXAMPLE.md).

---



## 6. The 5 human gates

Hooks automate the mechanical parts. **These five are not delegated:**

1. **F1 — Story and criteria**
  Do not accept AI-generated acceptance criteria without checking them against the real system. Cut invented scope and lock non-goals.
2. **F2 — Contract**
  After the proposal/audit, **open and edit** `proposal` / `specs` / `design` / `tasks` yourself. `tasks.md` must meet the mandatory steps; the gate is your implicit sign-off on scope.
3. **F4 — Plan before execute**
  If the task touches many files, has side effects, or is unknown territory: plan mode, **you approve the plan**, then execute.
4. **F4/F5 — Tests and evidence**
  The test (or the criterion) is human authorship or supervision. The agent does not rewrite existing tests without your OK. Verification (`/show-spec-working`) is run by the agent, but **you** read the evidence and the unspecified-behaviors block.
5. **F7 — Merge**
  The agent can open the PR; **you sign the merge**. The PR “why” is not invented from the diff alone: you provide it.

If you skip a gate, the rest of the kit amplifies the error instead of saving you.

---



## 7. What not to do


| Don’t                                                                              | Why                                                                                                                |
| ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `/init` in the repo with the kit                                                   | `CLAUDE.md` / `AGENTS.md` point at `docs/base-standards.md`; `/init` would overwrite them and destroy the doctrine |
| **Edit doctrine per project** (`docs/base-standards.md`, mandatory-steps, etc.)    | It is lost or overwritten when you update the kit. Facts → `project-context`; stack architecture → `*-standards.md`    |
| **Real secrets or PII in chat / fixtures / PR**                                    | They enter the model context and history. Use env vars, MCP, synthetic data                                            |
| **Install packages only because the model said so**                                | Slopsquatting risk — verify in the registry (`/privacy-ethics-check`)                                                  |
| **Edit only** `.claude/skills/...` **in copy mode**                                | You diverge from the canonical `ai-specs/`                                                                             |
| **Install the kit on the kit folder**                                              | The installer rejects this on purpose                                                                                  |


---



## 8. Windows troubleshooting



### Symlinks → 22-byte files / skills that do not load

On Windows without Developer Mode, Git may materialize symlinks as text. Skills do not load.

1. `bash .claude/sync-artifacts.sh --check` (or the `.ps1`).
2. If you see `TEXTO` / broken: run sync **without** `--check` to switch to **copy mode**.
3. From then on: edit `ai-specs/…` and sync again after every skill/agent change.
4. System alternative: enable Windows Developer Mode and reinstall/re-link.



### Bash

Hooks are `.sh`. You need Git Bash or `bash` on PATH. From PowerShell:

```powershell
bash .claude/sync-artifacts.sh
bash .claude/doctor.sh
```



### jq

```powershell
winget install jqlang.jq
jq --version
```

Without jq: hooks no-op. The doctor / `/kit-health` should mark this as degraded, not as “all OK”.

### MCP (Context7 / Playwright) do not appear

The JSON files are in the project (`.mcp.json`, `.cursor/mcp.json`); the IDE must **enable** the
project server the first time. Restart the session. On first use, Playwright downloads the
browser with `npx` and may take a minute. If you installed with `--no-frontend`, Playwright should
not be in the JSON. A Context7 API key is optional (`CONTEXT7_API_KEY` in the environment, never in the
committed file).

### Copy mode + sync (routine)

```powershell
# After creating/editing a skill in ai-specs/skills/<nombre>/
bash .claude/sync-artifacts.sh
# or:
pwsh -File .claude/sync-artifacts.ps1
```

Also: `/sync-agent-artifacts`.

After `openspec init`, sync may list `openspec-propose`, `openspec-apply-change`, etc. with the
**`KEEP`** label. Those are OpenSpec’s native skills (`/opsx:*`). Do not delete them; it is not an
error. A real **`ORPHAN` / `HUÉRFANO`** is any other name that is not in
`ai-specs/`.

### `validate-tasks` and `BRANCH_PREFIX`

If the hook requires `feature/...` and your team uses another prefix, align `.claude/sdd-harness.env`:

```bash
BRANCH_PREFIX="feature/"   # example / kit default value
```

and document it in `project-context`.

### Skills do not show up with `/`

Restart the agent session → sync → confirm that `SKILL.md` is in `ai-specs/skills/<cmd>/`.

---



## 9. How to update the kit

1. Get the new version of `sdd-harness-kit`.
2. Check `VERSION` in the kit folder.
3. From the **new kit** folder, reinstall over the project:

```bash
./install.sh --dest /ruta/a/mi-api          # respects files that differ
# only if you consciously want to overwrite kit artifacts:
./install.sh --dest /ruta/a/mi-api --force
```

```powershell
.\install.ps1 -Dest C:\proyectos\mi-api
.\install.ps1 -Dest C:\proyectos\mi-api -Force
```

1. `docs/project-context.md` is **never overwritten** (it is yours).
2. Doctrine (`base-standards`, documentation-standards, mandatory-steps) **is** replaced: that is why you do not keep customizations there.
3. `backend-standards` / `frontend-standards` / `sdd-harness.env`: if they differ, the installer usually keeps them — review the report.
4. After updating: `bash .claude/sync-artifacts.sh`, re-apply `config.yaml.tpl` if the template changed, and run `/kit-health` or the doctor.

---



## “Ready to work” checklist

- [ ] Dry-run seen and install done in the correct repo  
- [ ] `docs/project-context.md` without `{{...}}`  
- [ ] `openspec init` + `openspec/config.yaml` wired  
- [ ] `jq` + `bash` OK; doctor/`/kit-health` green or degradations understood  
- [ ] `CMD_TEST` run by hand once  
- [ ] A test skill responds (`/enrich-us` or `/kit-health`)  
- [ ] You know where the 5 human gates are  

If something fails, start with [USAGE.md — Common problems](USAGE.md#common-problems) and `/kit-health`.
