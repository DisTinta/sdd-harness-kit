# Guía paso a paso — SDD Harness Kit

**Idioma:** Español · [English](STEP-BY-STEP.md)

Guía de arranque para instalar y usar el kit en un repositorio de producto. Documentación humana
(español). Las skills y standards técnicos siguen en inglés.

Kit de origen: esta carpeta (`sdd-harness-kit`, versión en `VERSION`).  
Destino: **tu** proyecto de aplicación (no instales el kit sobre sí mismo).

Más detalle: [USO.md](USO.md) · [MANUAL.md](MANUAL.md) · [CONFIG.md](CONFIG.md) · [PROMPTS.md](PROMPTS.md).

---

## 0. Prerrequisitos


| Requisito                  | Para qué                  | Windows                                                                                         | Unix (Linux/macOS)                        |
| -------------------------- | ------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------- |
| **Node.js ≥ 20.19**        | CLI de OpenSpec           | [nodejs.org](https://nodejs.org) o `winget install OpenJS.NodeJS.LTS` — comprueba con `node -v` | `node -v`                                 |
| **Git**                    | Repo + contexto de sesión | Git for Windows (incluye **Git Bash**)                                                          | `git` del sistema                         |
| **Git Bash**               | Ejecutar hooks `.sh`      | Viene con Git for Windows; úsalo o llama `bash` desde PowerShell                                | bash nativo                               |
| **jq**                     | Parsear JSON de los hooks | `winget install jqlang.jq`                                                                      | `brew install jq` / `sudo apt install jq` |
| **OpenSpec CLI**           | Changes / specs           | Tras Node: `npm install -g @fission-ai/openspec`                                                | Igual                                     |
| **Claude Code y/o Cursor** | Superficies de agente     | Las que uses en el equipo                                                                       | Igual                                     |


Comprobación rápida:

```bash
node -v          # v20.19 o superior
jq --version
git --version
bash --version   # en Windows: desde Git Bash, o `bash -lc 'echo ok'` si Git está en PATH
openspec --version
```

Sin `jq`, los hooks **se desactivan solos** (la sesión no rompe, pero pierdes las guardas). Sin `bash`, los hooks no corren.

---



## 1. Instalación (dry-run → install)

Colócate en la carpeta del **kit** (esta), no en el proyecto destino.

### Windows (PowerShell)

```powershell
cd "C:\ruta\a\sdd-harness-kit"

# 1) Simulación: lista qué tocaría, no escribe
.\install.ps1 -Dest C:\proyectos\mi-api -DryRun

# 2) Instalación real
.\install.ps1 -Dest C:\proyectos\mi-api

# Opcional: forzar adaptador
.\install.ps1 -Dest C:\proyectos\mi-api -Stack adonisjs
```



### Linux / macOS

```bash
cd /ruta/a/sdd-harness-kit

./install.sh --dest ~/proyectos/mi-api --dry-run
./install.sh --dest ~/proyectos/mi-api

# Opcional:
./install.sh --dest ~/proyectos/mi-api --stack laravel
```

Al terminar deberías ver algo como `enlazados N · copiados N`:

- **enlazados** = symlinks a `ai-specs/` (ideal).
- **copiados** = el SO no permitió symlinks (típico en Windows sin modo desarrollador). **Funciona igual**, pero debes editar siempre `ai-specs/` y luego sincronizar (ver § Troubleshooting).

El instalador **no** ejecuta `openspec init` ni rellena por ti el significado de `project-context`.
Sí copia `.mcp.json` y `.cursor/mcp.json` (Context7; Playwright salvo `--no-frontend` / `-NoFrontend`).
La primera sesión en Cursor o Claude Code suele pedir permiso para arrancar esos servidores: acéptalo.
No hace falta pegar `use context7` en cada prompt; la doctrina del proyecto ya dispara el uso.

---



## 2. Completar `docs/project-context.md` (P0)

Es el paso de más retorno. El instalador deja comandos del adaptador y marcadores `{{...}}`.

1. Abre `docs/project-context.md` en el **proyecto destino**.
2. Sustituye todos los `{{...}}`: producto, cómo se testea, convenciones de rama, gotchas.
3. Menos de ~200 líneas. Solo lo que el agente **no** puede deducir leyendo el código.
4. Redáctalo **en inglés** (doctrina del kit: artefactos técnicos en inglés).

Puedes usar el **prompt P0** de [PROMPTS.md](PROMPTS.md) para que el agente proponga un borrador y marques qué ha inferido.

También revisa en el mismo día:

- `.claude/sdd-harness.env` — ejecuta a mano `CMD_TEST` (si es lento, apunta a la suite rápida). Si `CMD_STATIC` / `CMD_MUTATION` o el `ci.yml` apuntan a binarios que no están en el manifiesto (típico: PHPStan e Infection en Laravel), no los trates como comandos reales: ver [USO.md — Problemas frecuentes](USO.md#problemas-frecuentes).
- `docs/backend-standards.md` — ajústalo si tu arquitectura no es la del adaptador.
- `docs/frontend-standards.md` — si no es React ni Livewire, parte de `adapters/_template.frontend-standards.md` del kit.
- `tests/a11y/smoke.example.*` — scaffold de axe-core; cablea `test:a11y` cuando quieras el gate (ver `docs/frontend-standards.md`).

---



## 3. `openspec init` + aplicar `config.yaml.tpl`

**Después del kit, no antes.**

```bash
cd C:\proyectos\mi-api    # o ~/proyectos/mi-api
npm install -g @fission-ai/openspec   # si aún no
openspec init                         # elige Claude Code, Cursor, etc.
```

Comprueba que el init no haya pisado settings del kit sin querer:

```bash
git status --short
git diff .claude/settings.json     # idealmente vacío o revisado
```



### Cablear OpenSpec al kit

1. Copia la plantilla del kit al proyecto:

```bash
# Desde el proyecto, si la plantilla ya está en ai-specs (tras install):
cp ai-specs/templates/openspec/config.yaml.tpl openspec/config.yaml
```

En Windows (PowerShell):

```powershell
Copy-Item ai-specs\templates\openspec\config.yaml.tpl openspec\config.yaml
```

1. Abre `openspec/config.yaml`, quita solo lo que no aplique, y deja los punteros a `docs/` y `ai-specs/`.
2. No pegues novelas en `context` (límite ~50KB): bastan rutas y reglas cortas.

Los comandos nativos `/opsx:*` y los del kit (`/openspec-implement`, etc.) pueden convivir: los hooks miran **rutas de fichero**, no quién escribió el change.

---



## 4. Verificar con el doctor / `/kit-health`

En el proyecto:

```bash
bash .claude/doctor.sh --dest .
```

```powershell
powershell -File .claude\doctor.ps1 -Dest .
```

O en la sesión del agente:

```
/kit-health
```

Debes poder explicar el estado de: `jq`, sync de skills, `project-context` sin `{{...}}`, OpenSpec inicializado, `openspec/config.yaml`, `BRANCH_PREFIX`, y que `CMD_TEST` existe de verdad.

Prueba mínima de hooks (con bash + jq):

```bash
export CLAUDE_PROJECT_DIR=$PWD   # en Git Bash / Unix
echo '{"source":"startup"}' | bash .claude/hooks/session-context.sh | jq .
```

---



## 5. Flujo diario F0–F8 (resumen con skills)


| Fase                  | Qué haces                                      | Skills / piezas útiles                                                             |
| --------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------- |
| **F0** Harness        | Contexto cargado, env sano, sesión limpia      | `/kit-health` si algo huele mal                                                    |
| **F1** Planificación  | Story INVEST + criterios + non-goals           | `/enrich-us`, `/dod-feature` (u otro `/dod-`*)                                     |
| **F2** Especificación | proposal + delta spec + design + tasks         | `/opsx:propose` o P5; luego `spec-auditor` / P6                                    |
| **F3** Armado         | Skills, plan mode, MCP                         | Plan mode (`Shift+Tab` ×2). Context7 al planear APIs de librería; Playwright al demo UI |
| **F4** Ejecución      | Task a task, TDD                               | `/openspec-implement` o `/opsx:apply`; `/tdd-red` → `/tdd-green` → `/tdd-refactor` |
| **F5** Verificación   | Evidencia real + conformidad + revisión hostil | `/show-spec-working`, `/verify-against-spec`, `/adversarial-review`                |
| **F6** Documentación  | Contratos / ADR si aplica                      | `/update-docs`, `/adr-new`                                                         |
| **F7** Entrega        | Commits atómicos + PR                          | `/commit` (`feat(TICKET): …`), `/pr-describe`, `/pr-review` |
| **F8** Cierre         | Archivar change + aprender                     | `/opsx:archive`; apuntes en `project-context` o standards                          |
| **Transversal**       | Privacidad / deps / datos                      | `/privacy-ethics-check`                                                            |
| **Prompts flojos**    | Antes de una sesión cara                       | `/meta-prompt`                                                                     |


Detalle narrado: [MANUAL.md](MANUAL.md) · ejemplo completo: [EJEMPLO.md](EJEMPLO.md).

---



## 6. Los 5 gates humanos

Los hooks automatizan lo mecánico. **Estos cinco no se delegan:**

1. **F1 — Story y criterios**
  No aceptes criterios de aceptación generados por IA sin contrastarlos con el sistema real. Recorta alcance inventado y fija non-goals.
2. **F2 — Contrato**
  Tras la propuesta/auditoría, **abre y edita** `proposal` / `specs` / `design` / `tasks` tú. El `tasks.md` debe cumplir los pasos obligatorios; el gate es tu firma implícita del alcance.
3. **F4 — Plan antes de ejecutar**
  Si la tarea toca muchos ficheros, efectos colaterales o zona desconocida: plan mode, **apruebas el plan**, luego execute.
4. **F4/F5 — Tests y evidencia**
  El test (o el criterio) es autoría o supervisión humana. El agente no reescribe tests existentes sin tu OK. La verificación (`/show-spec-working`) la ejecuta el agente, pero **tú** lees la evidencia y el bloque de comportamientos no especificados.
5. **F7 — Merge**
  El agente puede abrir el PR; **tú firmas el merge**. El «por qué» del PR no lo inventa el diff solo: lo aportas tú.

Si saltas un gate, el resto del kit amplifica el error en lugar de salvarte.

---



## 7. Qué no hacer


| No                                                                                 | Por qué                                                                                                                |
| ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `/init` en el repo con el kit                                                      | Los `CLAUDE.md` / `AGENTS.md` / … apuntan a `docs/base-standards.md`; `/init` escribiría encima y destroza la doctrina |
| **Editar doctrina por proyecto** (`docs/base-standards.md`, mandatory-steps, etc.) | Se pierde o se pisa al actualizar el kit. Hechos → `project-context`; arquitectura de stack → `*-standards.md`         |
| **Secretos o PII reales en el chat / fixtures / PR**                               | Entran en contexto del modelo y en el historial. Usa env vars, MCP, datos sintéticos                                   |
| **Instalar paquetes solo porque lo dijo el modelo**                                | Riesgo de slopsquatting — verifica en el registry (`/privacy-ethics-check`)                                            |
| **Editar solo** `.claude/skills/...` **en modo copia**                             | Diverges del canónico `ai-specs/`                                                                                      |
| **Instalar el kit sobre la carpeta del kit**                                       | El instalador lo rechaza a propósito                                                                                   |


---



## 8. Troubleshooting Windows



### Symlinks → ficheros de 22 bytes / skills que no cargan

En Windows sin Developer Mode, Git puede materializar symlinks como texto. Las skills no cargan.

1. `bash .claude/sync-artifacts.sh --check` (o el `.ps1`).
2. Si ves `TEXTO` / broken: ejecuta sync **sin** `--check` para pasar a **modo copia**.
3. A partir de ahí: edita `ai-specs/…` y vuelve a sincronizar tras cada cambio de skill/agent.
4. Alternativa de sistema: activa modo desarrollador de Windows y reinstala/re-enlaza.



### Bash

Los hooks son `.sh`. Necesitas Git Bash o `bash` en PATH. Desde PowerShell:

```powershell
bash .claude/sync-artifacts.sh
bash .claude/doctor.sh
```



### jq

```powershell
winget install jqlang.jq
jq --version
```

Sin jq: hooks en no-op. El doctor / `/kit-health` deben marcarlo como degradado, no como “todo OK”.

### MCP (Context7 / Playwright) no aparecen

Los JSON están en el proyecto (`.mcp.json`, `.cursor/mcp.json`); el IDE tiene que **habilitar** el
servidor de proyecto la primera vez. Reinicia la sesión. Playwright, al primer uso, descarga el
navegador con `npx` y puede tardar un minuto. Si instalaste con `--no-frontend`, Playwright no debe
estar en el JSON. Una API key de Context7 es opcional (`CONTEXT7_API_KEY` en el entorno, nunca en el
fichero commiteado).

### Modo copia + sync (rutina)

```powershell
# Tras crear/editar una skill en ai-specs/skills/<nombre>/
bash .claude/sync-artifacts.sh
# o:
pwsh -File .claude/sync-artifacts.ps1
```

También: `/sync-agent-artifacts`.

Tras `openspec init`, el sync puede listar `openspec-propose`, `openspec-apply-change`, etc. con
etiqueta **`KEEP`**. Son las skills nativas de OpenSpec (`/opsx:*`). No las borres; no es un
error. Un **`ORPHAN` / `HUÉRFANO`** de verdad es cualquier otro nombre que no esté en
`ai-specs/`.

### `validate-tasks` y `BRANCH_PREFIX`

Si el hook exige `feature/...` y tu equipo usa otro prefijo, alinea `.claude/sdd-harness.env`:

```bash
BRANCH_PREFIX="feature/"   # ejemplo / valor por defecto del kit
```

y documéntalo en `project-context`.

### Skills no salen con `/`

Reinicia la sesión del agente → sync → confirma que el `SKILL.md` está en `ai-specs/skills/<cmd>/`.

---



## 9. Cómo actualizar el kit

1. Obtén la versión nueva de `sdd-harness-kit`.
2. Mira `VERSION` en la carpeta del kit.
3. Desde la carpeta del **kit nuevo**, reinstala sobre el proyecto:

```bash
./install.sh --dest /ruta/a/mi-api          # respeta ficheros que difieren
# solo si quieres pisar artefactos del kit a conciencia:
./install.sh --dest /ruta/a/mi-api --force
```

```powershell
.\install.ps1 -Dest C:\proyectos\mi-api
.\install.ps1 -Dest C:\proyectos\mi-api -Force
```

1. **Nunca se pisa** `docs/project-context.md` (es tuyo).
2. La doctrina (`base-standards`, documentation-standards, mandatory-steps) **sí** se sustituye: por eso no guardes custom ahí.
3. `backend-standards` / `frontend-standards` / `sdd-harness.env`: si difieren, el instalador suele conservarlos — revisa el informe.
4. Tras actualizar: `bash .claude/sync-artifacts.sh`, vuelve a aplicar `config.yaml.tpl` si el template cambió, y corre `/kit-health` o el doctor.

---



## Checklist de “ya puedo trabajar”

- [ ] Dry-run visto y install hecho en el repo correcto  
- [ ] `docs/project-context.md` sin `{{...}}`  
- [ ] `openspec init` + `openspec/config.yaml` cableado  
- [ ] `jq` + `bash` OK; doctor/`/kit-health` en verde o degradaciones entendidas  
- [ ] `CMD_TEST` ejecutado a mano una vez  
- [ ] Una skill de prueba responde (`/enrich-us` o `/kit-health`)  
- [ ] Sabes dónde están los 5 gates humanos  

Si algo falla, empieza por [USO.md — Problemas frecuentes](USO.md#problemas-frecuentes) y `/kit-health`.