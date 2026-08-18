# Cómo se usa

> Empieza por [GUIA-PASO-A-PASO.md](GUIA-PASO-A-PASO.md) si es tu primer arranque.

## Qué se ejecuta y cuándo

| Herramienta | ¿Hace falta? | Cuándo |
|---|---|---|
| El instalador del kit | **Sí** | Una vez por proyecto |
| Completar `docs/project-context.md` | **Sí** | Una vez por proyecto, a mano |
| `openspec init` + cablear `config.yaml` | **Sí** | Una vez por proyecto, después del instalador |
| `doctor.ps1` / `doctor.sh` | **Sí** | Tras instalar y cuando algo “no pega” |
| Activar MCP del proyecto (Context7, Playwright) | Recomendado | Una vez por máquina/IDE; el JSON ya lo copia el instalador |
| `claude` (la sesión, sin barra) | **Sí** | Cada vez que trabajas |
| `bash .claude/sync-artifacts.sh` | Cuando toque | Tras crear, renombrar o mover una skill |
| `/init` | **NO. Nunca en este repositorio** | Rompería la doctrina. Ver abajo |
| `claude mcp add …` (Jira, BD, etc.) | Opcional | Conectores de equipo con secretos; no van en el kit |

---

## Día 1 · Preparar el proyecto

Una vez por repositorio. Veinte minutos.

### 1. Instala el kit

```powershell
cd <ruta-del-kit>\sdd-harness-kit
.\install.ps1 -Dest C:\proyectos\mi-api -DryRun    # primero mira qué tocaría
.\install.ps1 -Dest C:\proyectos\mi-api            # instala
.\doctor.ps1 -Dest C:\proyectos\mi-api
```

```bash
./install.sh --dest ~/proyectos/mi-api --dry-run
./install.sh --dest ~/proyectos/mi-api
bash ./doctor.sh --dest ~/proyectos/mi-api
```

Detecta el stack, copia `ai-specs/` y los hooks, escribe la doctrina en `docs/`, aplica el adaptador,
genera `docs/project-context.md` con los comandos ya puestos, y enlaza `.claude` y `.cursor` a
`ai-specs`.

Al final te dirá **`enlazados N · copiados N`**. Si dice «copiados», tu sistema no permite symlinks y
el kit ha hecho copias: funciona igual, pero recuerda editar siempre `ai-specs/` y ejecutar
`sync-artifacts` para propagar.

### 2. Inicializa OpenSpec

```bash
node -v                                 # necesitas 20.19 o superior
npm install -g @fission-ai/openspec
cd C:\proyectos\mi-api
openspec init                           # elige Claude Code, Cursor, etc.
```

**Después del kit, no antes.** El asistente de OpenSpec detecta las carpetas que ya existen y solo
añade lo suyo. Comprueba qué ha tocado:

```bash
git status --short
git diff .claude/settings.json     # debería estar vacío
```

Los nombres no colisionan: OpenSpec instala comandos `/opsx:*` y el kit tiene los suyos. Lo que crea
cada uno como instalador:

| Ruta | La crea |
|---|---|
| `ai-specs/templates/openspec/` | el kit (plantillas de referencia) |
| `openspec/project.md`, `openspec/changes/`, `openspec/specs/` | `openspec init` |

El **instalador** del kit no escribe dentro de `openspec/`: ese directorio lo gobierna la herramienta.
Durante el trabajo del día a día sí se escribe ahí, por supuesto —es donde vive cada change— y **da
igual qué lo escriba**: `/opsx:propose` o el prompt P5, `/opsx:apply` o `/openspec-implement`. Los
hooks `validate-tasks` y `protect-specs-and-tests` actúan sobre la ruta del fichero, no sobre qué
comando lo tocó, así que el kit funciona igual si usas exclusivamente los comandos nativos de OpenSpec
(`/opsx:explore`, `/opsx:propose`, `/opsx:apply`, `/opsx:sync`, `/opsx:archive`), exclusivamente los
del kit, o una mezcla. La tabla de correspondencia completa está en [MANUAL.md](MANUAL.md#1-el-flujo-en-nueve-fases).

### 3. Completa `docs/project-context.md`

El instalador deja los comandos rellenados. Los marcadores `{{...}}` que quedan son tuyos: qué es el
producto, cómo se testea, las convenciones de rama y los *gotchas*.

Puedes hacerlo a mano o con el **prompt P0** de [PROMPTS.md](PROMPTS.md), que explora el repositorio y
te propone el contenido señalando qué ha tenido que inferir.

Escríbelo **en inglés**: `base-standards.md` §2 lo exige para todo artefacto técnico, y un hook te
avisará si detecta español en el código.

> ⚠️ **No ejecutes `/init`.** Los cuatro ficheros de memoria (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`,
> `codex.md`) apuntan a `docs/base-standards.md`. `/init` escribiría a través de ellos y se llevaría la
> doctrina por delante. Para el contexto del proyecto usa P0.

### 4. Ajusta los standards del stack

`docs/backend-standards.md` viene del adaptador y describe una arquitectura concreta. **Si tu proyecto
no la sigue, ajústalo ahora**: ese fichero es lo que impide que el agente invente una arquitectura
distinta en cada tarea.

Lo mismo con `docs/frontend-standards.md` si tu frontend no es React.

### 5. Verifica la configuración

```bash
cat .claude/sdd-harness.env
```

Comprueba que **cada comando existe de verdad** ejecutándolo a mano. El crítico es `CMD_TEST`: el hook
de `Stop` lo lanza al cerrar cada turno en el que hayas tocado código. Si es lento o no existe,
bloquearás todos tus turnos. Si tu suite completa tarda minutos, apúntalo a la parte rápida.

Los `CMD_STATIC` / `CMD_MUTATION` y el `ci.yml` del adaptador asumen herramientas de calidad
(PHPStan, Infection, Stryker…) que un proyecto de fábrica **puede no tener**. El instalador no las
añade. Si el binario no existe, no lo dejes como comando utilizable: ver [Problemas frecuentes](#problemas-frecuentes).

### 6. Revisa los hooks

```bash
ls .claude/hooks/
```

Los 9 hooks ejecutan código con tus permisos. Léelos. Y pruébalos sin abrir sesión, porque son scripts que leen
JSON por la entrada estándar:

```bash
export CLAUDE_PROJECT_DIR=$PWD

echo '{"source":"startup"}' | bash .claude/hooks/session-context.sh | jq -r '.hookSpecificOutput.additionalContext'
echo '{"tool_input":{"command":"rm -rf /"}}' | bash .claude/hooks/block-dangerous-bash.sh
echo '{"tool_input":{"command":"git status"}}' | bash .claude/hooks/block-dangerous-bash.sh   # sin salida
```

### 7. Comprueba que las skills cargan

Abre la sesión (`claude`) y escribe `/`. Deben aparecer `/enrich-us`, `/tdd-red`, `/pr-review` y el
resto.

Si no aparecen: **reinicia la sesión.** Claude Code recarga en caliente los cambios en las skills,
pero si el directorio no existía al arrancar hay que reiniciar. Si siguen sin aparecer, ejecuta
`bash .claude/sync-artifacts.sh --check`: probablemente las referencias estén como ficheros de texto.

### 8. Activa los MCP del proyecto

El instalador deja `.mcp.json` (Claude Code) y `.cursor/mcp.json` (Cursor) con **Context7** y, si no
usaste `--no-frontend` / `-NoFrontend`, **Playwright** en modo aislado.

No hace falta escribir `use context7` en cada prompt: la doctrina (`docs/base-standards.md` §11) ya
le dice al agente cuándo consultarlos. La primera vez el IDE suele pedir permiso para arrancar el
servidor del proyecto: acéptalo. Opcional: `CONTEXT7_API_KEY` en el entorno (nunca en el JSON
commiteado) si te topas con el rate limit anónimo.

Jira, bases de datos u otros conectores con secretos **no** van aquí: `claude mcp add …` por equipo.

### 9. Commitea el kit

```bash
git add ai-specs .claude .cursor .github docs CLAUDE.md AGENTS.md GEMINI.md codex.md .mcp.json
git commit -m "chore: add SDD Harness Kit"
```

Se commitea a propósito: es la configuración del equipo. Lo que no se commitea es
`.claude/settings.local.json`, y el instalador ya lo añade al `.gitignore`.

---

## Día 2 y siguientes · El ciclo de trabajo

### Preparar el terreno

```
claude
```

El hook de sesión ya te ha inyectado rama, último commit, changes activos, tasks pendientes y los
comandos del proyecto. No hace falta contárselo.

### Fase 1 · De ticket a trabajo ejecutable

```
/enrich-us Filter the listing by state — the client downloads everything and filters in memory
```

Devuelve `## Original` y `## Enhanced`, con criterios de aceptación en Given/When/Then, contexto
técnico con rutas reales y non-goals. **Es un borrador.** Ahora tu parte: pega la story y lanza el
**prompt P2** (poke-holes) para que busque los huecos. Devolverá diez o quince candidatos; te quedas
con los reales y **recortas lo que se haya inventado**.

Ese recorte es el trabajo más rentable de todo el ciclo.

### Fase 2 · De story a contrato

Contexto limpio primero (`/clear`). Opcional antes de esto: `/opsx:explore` (nativo) o el subagente
`explorer`/**prompt P4** (kit) si todavía no tienes claro el enfoque.

```
/opsx:propose "filter the listing by state"
```

Es exactamente equivalente al **prompt P5** si no usas OpenSpec, o si quieres controlar tú el
contenido en lugar de dejárselo al criterio del comando.

Audita antes de aprobar:

```
Use the spec-auditor subagent on the proposal in openspec/changes/<id>/
```

Comprobará además que `tasks.md` cumple `docs/openspec-tasks-mandatory-steps.md`. Y después
**ábrela y edítala tú**. Este es el gate que hace que el resto funcione.

### Fase 3 · Planificar

`Shift+Tab` dos veces para plan mode y el **prompt P7**. Para features complejas, delega en
`backend-planner` o `frontend-planner`: producen el plan en un fichero bajo `docs/plans/` y nunca
implementan.

### Fase 4 · Implementar

```
/openspec-implement <id-del-change>
```

Equivalente al `/opsx:apply` nativo, con la doctrina del kit explícita: exige la tabla de
trazabilidad antes de codificar y ejecuta él mismo los pasos de verificación. Si usas `/opsx:apply`
en su lugar, la misma doctrina se aplica igual —está en `CLAUDE.md`, no en la skill— y los hooks no
distinguen cuál de los dos escribió el fichero.

Recorre las tasks en TDD. Para control fino, el ciclo en dos turnos:

```
/tdd-red the listing with an invalid state returns a validation error
/tdd-green tests/Feature/Tasks/ListTasksTest.php
/tdd-refactor app/Services/TaskService.php
```

Tres turnos, uno por fase del ciclo, cada uno con su contexto. Y hay un subagente por fase
(`tdd-test-writer`, `tdd-implementer`, `tdd-refactorer`) para cuando la tarea es lo bastante grande
como para que merezca aislar el contexto de verdad.

Mientras trabajas, los hooks actúan solos: si intenta editar un test existente pide confirmación, si
mezcla capas devuelve el control, si escribe un `tasks.md` incompleto lo rechaza, si propone instalar
un paquete pide verificarlo, y si intenta cerrar con la suite en rojo no puede.

### Fase 5 · Demostrar y verificar

```
/show-spec-working <id>
```

Esta es la verificación que el harness marca como «AGENT MUST EXECUTE» y la que más se salta: el
agente arranca los servicios, ejerce cada escenario contra el sistema real, restaura el estado y
entrega evidencia. No análisis: comandos y respuestas.

Después:

```
/verify-against-spec <id>
```

Léete el tercer bloque, el de comportamientos no especificados. Y antes de archivar, la revisión
hostil:

```
/adversarial-review <id>
```

Devuelve un veredicto explícito: PASS, PASS WITH GAPS o FAIL. Lánzala en una sesión distinta de la que
implementó: un agente revisando su propio trabajo hereda sus propios puntos ciegos.

### Fase 6 · Documentar

```
/update-docs
/adr-new <título de la decisión>
```

`/adr-new` aplica el criterio de necesidad y te dirá si **no** procede. Hazle caso.

### Fase 7 · Entregar

```
/pr-review
/commit
/pr-describe
```

`/commit` comprueba el gate de documentación antes de commitear, y el hook `docs-gate` lo comprueba
otra vez por si acaso. `/pr-describe` entrega la descripción con «¿Por qué?» vacío y marcado:
rellénalo tú.

### Fase 8 · Cerrar

`/opsx:archive` tras el merge —te preguntará si hace falta `/opsx:sync` primero para volcar el delta
sobre el spec principal, y en ese caso reescribe `openspec/specs/<capability>/spec.md`: el hook lo
deja pasar preguntando, igual que con cualquier otra reescritura—. Después, el **prompt P15** para la
retro sobre los datos del ciclo.

---

## Chuleta

```
Día 1, una vez por proyecto
  install.ps1 / install.sh  →  openspec init  →  completar docs/project-context.md
  ajustar docs/backend-standards.md  →  verificar sdd-harness.env  →  activar MCP  →  commitear el kit

Cada ticket
  /enrich-us          →  P2 poke-holes            →  RECORTAS TÚ
  (/opsx:explore)  →  /clear  →  /opsx:propose  →  spec-auditor  →  EDITAS TÚ
  Shift+Tab ×2  →  P7 plan                        →  APRUEBAS TÚ
  /tdd-red  →  VES FALLAR EL TEST  →  /tdd-green  →  P10 triangulación
  /show-spec-working  →  /verify-against-spec  →  /adversarial-review
  /update-docs  →  /adr-new  →  /pr-review
  /commit  →  /pr-describe                        →  ESCRIBES EL POR QUÉ
  (/opsx:sync)  →  /opsx:archive       →  P15 retro

  Todo lo de la izquierda con /opsx: tiene equivalente en el kit (ver tabla en MANUAL.md)
  y viceversa. No hay que elegir uno para todo el proyecto: se decide por ticket.

Al tocar el kit
  editar ai-specs/  →  bash .claude/sync-artifacts.sh

Nunca
  /init en este repositorio
  aceptar que el agente toque un test existente sin mirar por qué
  dejar el bloque 3 de la verificación sin decidir
  editar la doctrina de docs/ por proyecto (se pierde al actualizar)
```

---

## Las 27 skills

**Planificación**
`/enrich-us` · `/dod-feature` · `/dod-bug` · `/dod-refactor` · `/dod-spike` · `/dod-docs` · `/meta-prompt`

**Implementación**
`/openspec-implement` · `/feature-slice` · `/tdd-red` · `/tdd-green` · `/tdd-refactor`

**Verificación**
`/show-spec-working` · `/verify-against-spec` · `/adversarial-review` · `/pr-review` · `/code-auditing` · `/privacy-ethics-check`

**Documentación y entrega**
`/explain` · `/adr-new` · `/update-docs` · `/commit` · `/pr-describe`

**Mantenimiento del kit**
`/writing-skills` · `/sync-agent-artifacts` · `/using-git-worktrees` · `/kit-health`

## Los 9 subagentes

`explorer` (barato, solo lectura) · `tdd-test-writer` · `tdd-implementer` · `tdd-refactorer` ·
`spec-auditor` · `security-reviewer` · `backend-planner` · `frontend-planner` · `product-analyst`

Los tres `tdd-*` son la trilogía de testing del kit: un subagente por fase del ciclo, cada uno con
contexto aislado.

---

## Problemas frecuentes

**P0 o el CI dicen que faltan `phpstan` / `infection` (o Stryker, Typedoc…).** El adaptador copia un
pipeline y unos `CMD_*` de referencia; el instalador **no instala paquetes**. Un Laravel de fábrica no
trae PHPStan ni Infection. No los listes como comandos en `docs/project-context.md`: van a **Gotchas**.
Después decides: instalar las herramientas y alinear `project-context.md`, `sdd-harness.env` y
`ci.yml`, o vaciar esas variables y quitar los steps. Los tres ficheros tienen que decir lo mismo.

**Las skills no aparecen con `/`.** Reinicia la sesión. Si persiste:
`bash .claude/sync-artifacts.sh --check`. Si dice `TEXTO`, los symlinks se materializaron como
ficheros: ejecuta `sync-artifacts.sh` sin `--check` y hará copias que sí funcionan.

**Context7 o Playwright no salen como herramientas.** Los JSON están en el repo, pero el IDE tiene
que habilitar el MCP de proyecto (un toggle la primera vez). Reinicia la sesión. Playwright la
primera vez descarga el navegador vía `npx` y puede tardar. Sin frontend, es normal que Playwright
no esté si instalaste con `--no-frontend`.

**Editas una skill y el cambio no se aplica.** ¿La editaste en `.claude/skills/` en lugar de en
`ai-specs/skills/`? En modo copia son ficheros distintos. `sync-artifacts.sh --check` te dirá
`DIVERGE`; mueve tu cambio a `ai-specs/` y sincroniza.

**Todos mis turnos tardan mucho en cerrarse.** Es el hook de `Stop` ejecutando `CMD_TEST`. Apúntalo a
la parte rápida de la suite.

**Stop: `Hook JSON output validation failed`.** El hook sí corrió (si ves «Suite en verde», los tests
pasaron). Claude Code rechazó el JSON de salida: Stop no admite `additionalContext`. Actualiza
`.claude/hooks/lib.sh` y `verify-tests.sh` desde el kit (el recordatorio va en `systemMessage`).

**Los hooks no hacen nada.** ¿`jq` instalado? Sin él se desactivan solos. ¿Y `bash`? En Windows lo
trae Git for Windows. Los hooks no invocan `bash` a secas: `.claude/hooks/invoke.cjs` elige Git Bash
en Windows (si no, el `bash` de PATH suele ser WSL y un PHP distinto al de Laragon).

**Stop / Composer: `You are running 8.2` con un proyecto que pide 8.3.** `CMD_TEST` está bien. El
`php` es el del shell del hook. En Windows, `invoke.cjs` debe existir y `settings.json` debe
lanzarlo con `node`. No pongas rutas de Laragon en `sdd-harness.env`.

**`validate-tasks` rechaza mi `tasks.md`.** Está haciendo cumplir
`docs/openspec-tasks-mandatory-steps.md`: falta el Step 0 de rama, algún paso obligatorio, la etiqueta
`(MANDATORY)`, el `AGENT MUST EXECUTE`, la restauración de estado o la numeración `N.M`. El mensaje
dice cuál.

**El aviso de English-only salta en un fichero que está en inglés.** Es heurístico y admite falsos
positivos; por eso avisa en lugar de bloquear. Si molesta, afina `SPANISH_WORDS` en
`.claude/hooks/lib.sh`.

**Un hook bloquea algo que debería permitir.** El patrón está en `block-dangerous-bash.sh` o en
`protect-specs-and-tests.sh` de **tu repositorio**. Ajústalo ahí.

**Desactivarlos todos un momento.** `{"disableAllHooks": true}` en `.claude/settings.local.json`. O
todos o ninguno.

**El agente ignora las decisiones de diseño.** El contexto ha crecido y el documento quedó enterrado.
`/clear` y relanza referenciando el fichero explícitamente. Hay un prompt de rescate al final de
[PROMPTS.md](PROMPTS.md).
