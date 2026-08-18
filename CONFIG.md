# Referencia de `sdd-harness.env`

El contrato de configuración del kit. Es el único fichero que cambia entre proyectos: los hooks lo
cargan de forma segura al arrancar (allowlist de claves, sin `source` ni `eval` del fichero) y las
skills lo leen como contexto dinámico.

Se sitúa así respecto a los demás ficheros de configuración:

| Fichero | Contiene | Quién lo escribe |
|---|---|---|
| `.claude/sdd-harness.env` | Comandos, rutas y guardas, en forma de variables | El adaptador; lo ajustas tú |
| `.mcp.json` · `.cursor/mcp.json` | Servidores MCP del proyecto (Context7, Playwright) | El kit. Sin secretos |
| `docs/project-context.md` | Lo mismo en prosa, más los gotchas, para que lo lea el modelo | **Tú** |
| `docs/backend-standards.md` | Las capas y convenciones del stack | El adaptador; lo ajustas tú |
| `docs/base-standards.md` | La doctrina invariante | El kit. No lo edites por proyecto |

Sí, los comandos aparecen en dos sitios. A propósito: el `.env` los hace ejecutables por los hooks, y
el contexto en prosa los hace legibles por el modelo. Si cambias uno, cambia el otro.

Formato: `CLAVE="valor"` en una sola línea. Sin comandos, sin sustituciones, sin backticks. El loader
de `lib.sh` solo acepta claves allowlisted; las líneas con `$(...)` o backticks se ignoran con aviso.

**Si un valor no aplica a tu proyecto, déjalo vacío.** El kit se degrada, no se rompe: un hook sin
comando configurado sale con código 0 y no molesta.

---

## Comandos

| Variable | Cómo se invoca | Quién la usa |
|---|---|---|
| `CMD_TEST` | tal cual | Hook `verify-tests` (Stop), contexto de sesión, skills |
| `CMD_TEST_FILTER` | `$CMD_TEST_FILTER "<patrón>"` | Skills de TDD, `openspec-implement` |
| `CMD_LINT` | tal cual | Contexto de sesión, skills |
| `CMD_FORMAT_FILE` | `$CMD_FORMAT_FILE "<ruta>"` | Hook `post-edit-quality`, en silencio |
| `CMD_STATIC_FILE` | `$CMD_STATIC_FILE "<ruta>"` | Hook `post-edit-quality`; su salida vuelve al agente |
| `CMD_STATIC` | tal cual | Contexto de sesión, skills |
| `CMD_MUTATION` | tal cual | Prompt de triangulación (P10) |
| `CMD_DOCS_COVERAGE` | tal cual | Prompt de documentación (P13) |
| `CMD_DEV` | tal cual | Plantilla de `docs/project-context.md` |
| `CMD_MIGRATE` | tal cual | Plantilla de `docs/project-context.md` |

> **Cuidado con `CMD_TEST`.** El hook de `Stop` lo ejecuta al cerrar cada turno en el que se haya
> tocado código. Si el comando es lento o no existe, bloquearás todos tus turnos. Pruébalo a mano
> antes de dejarlo puesto.

---

## Rutas

| Variable | Para qué |
|---|---|
| `SOURCE_EXTENSIONS` | Extensiones de código fuente, separadas por espacios y sin punto (`ts tsx`, `php`, `py`). Filtra qué ficheros analiza el hook de calidad |
| `PATH_SOURCE` | Raíz del código de producción. El hook de `Stop` mira si hay cambios aquí |
| `PATH_TESTS` | Directorio de tests. El hook de protección pide confirmación para modificar los que ya existen |
| `PATH_BUSINESS` | Capa de lógica de negocio. Donde se aplica `GUARD_HTTP_IN_BUSINESS` |
| `PATH_HTTP` | Capa de transporte. Donde se aplica `GUARD_DB_IN_HTTP` |
| `PATH_MIGRATIONS` | Migraciones. Vacío si el proyecto no tiene. Las ya versionadas quedan protegidas |
| `PATH_ADR` | Registro de decisiones. Por defecto `docs/adr` |

Variables de rama y escape hatches:

| Variable | Para qué |
|---|---|
| `BRANCH_PREFIX` | Prefijo de rama que **exige** `validate-tasks` en el Step 0. Por defecto `feature/` |
| `KIT_ALLOW_WIP` | `1` = el Stop hook no bloquea por suite en rojo (solo spikes locales; quitar antes del PR) |
| `KIT_SKIP_STOP_TESTS` | `1` = no ejecuta la suite en Stop |

**Seguridad del fichero:** no se hace `source` ni `eval` del env. Solo se aceptan claves allowlisted
en formato `KEY="valor"`. Líneas con `$(...)` o backticks se ignoran con aviso.

Las rutas son relativas a la raíz del repositorio y se comparan por prefijo de segmento, así que
`app/services` coincide con `app/services/x.ts` y con `backend/app/services/x.ts`.

---

## Quién consume esta configuración

Los **nueve** hooks del kit. Ninguno tiene un comando escrito dentro:

| Hook | Variables que usa |
|---|---|
| `session-context` | `STACK`, `CMD_*`, `LAYER_ORDER`, `PATH_BUSINESS`, `BRANCH_PREFIX` |
| `block-secrets` | ninguna (patrones universales en el prompt) |
| `block-secret-reads` | ninguna (patrones de ruta de secretos) |
| `block-dangerous-bash` | `GUARD_DANGEROUS_CMD`, `STACK` |
| `docs-gate` | `PATH_MIGRATIONS`, `PATH_HTTP`, `SOURCE_EXTENSIONS` |
| `protect-specs-and-tests` | `PATH_TESTS`, `PATH_MIGRATIONS` |
| `post-edit-quality` | `SOURCE_EXTENSIONS`, `CMD_FORMAT_FILE`, `CMD_STATIC_FILE`, `PATH_BUSINESS`, `PATH_HTTP`, las dos guardas |
| `validate-tasks` | `BRANCH_PREFIX` + checklist de `openspec-tasks-mandatory-steps.md` |
| `verify-tests` | `CMD_TEST`, `PATH_SOURCE`, `PATH_TESTS`, `PATH_ADR`, `KIT_*` |

Las skills que dependen de esta configuración para ejecutar algo son las que más se benefician:
`/openspec-implement`, `/tdd-red`, `/tdd-green`, `/tdd-refactor`, `/feature-slice`, `/show-spec-working`,
`/adversarial-review`, `/code-auditing`, `/privacy-ethics-check`, `/kit-health`.

Y las 24 en general, a través del contexto dinámico que abre casi todas:

```
## Project configuration
!`cat .claude/sdd-harness.env 2>/dev/null | grep -vE '^\s*#|^\s*$'`
```

Esa línea es lo que hace que la misma skill funcione en AdonisJS, en Laravel y en un stack que el kit
no conoce todavía.

---

## Guardas de arquitectura

Expresiones regulares extendidas (`grep -E`). Son la parte del kit que convierte una convención
escrita en `docs/backend-standards.md` —que el modelo puede ignorar— en una comprobación
determinista.

| Variable | Se aplica a | Qué detecta |
|---|---|---|
| `GUARD_HTTP_IN_BUSINESS` | ficheros bajo `PATH_BUSINESS` | Que la capa de negocio importe el transporte |
| `GUARD_DB_IN_HTTP` | ficheros bajo `PATH_HTTP` | Que la capa de transporte consulte la base de datos o use la petición sin validar |
| `GUARD_DANGEROUS_CMD` | comandos de Bash | Comandos destructivos propios del stack. Se suma a la lista universal del kit |

Cuando una guarda salta, el hook devuelve el control al agente con el motivo. No bloquea la escritura
—el fichero ya está en disco— pero el agente no puede seguir sin corregirlo.

**Cómo escribir una guarda que no dé falsos positivos:** empieza por el patrón más específico que
puedas. Es preferible una guarda que se pierda algún caso a una que salte en cada fichero: si salta
siempre, el equipo la desactiva y te quedas sin ninguna.

Pruébala antes de dejarla puesta:

```bash
grep -nE "$GUARD_HTTP_IN_BUSINESS" app/services/*.ts   # no debería devolver nada
```

### El aviso de English-only

`post-edit-quality` incluye una comprobación heurística de idioma, porque `base-standards.md` §2 exige
inglés en todo artefacto técnico. La lista de palabras está en `SPANISH_WORDS`, dentro de
`.claude/hooks/lib.sh`, no en `sdd-harness.env`, porque no depende del stack.

Exige **dos palabras distintas** antes de avisar, y **avisa en lugar de bloquear**: el riesgo de falso
positivo es real y bloquear por él sería peor que el problema. Si te molesta, edita la lista o vacía la
variable.

---

## Convenciones

| Variable | Para qué |
|---|---|
| `LAYER_ORDER` | El orden en que se tocan los ficheros al implementar una unidad vertical. Las skills lo imponen y el contexto de sesión lo recuerda |
| `MIN_MUTATION_SCORE` | Umbral de mutation score en paths críticos. Por defecto 70 |
| `STACK` | Identificador informativo. Aparece en el contexto de sesión |

---

## Escribir un adaptador nuevo

Para dar soporte a un stack que el kit no trae, **no toques ninguna skill ni ningún hook**. Solo
necesitas cuatro ficheros en `adapters/`, y solo el primero es obligatorio.

### 1. `<stack>.env` — obligatorio

```bash
cp adapters/_template.env adapters/mi-stack.env
```

Rellena las variables. Verifica cada comando ejecutándolo a mano en un proyecto real antes de
escribirlo.

### 2. `<stack>.backend-standards.md` — muy recomendable

El documento de capas y convenciones que el instalador copia a `docs/backend-standards.md`. Parte de
`_template.backend-standards.md` y responde a cinco preguntas:

1. ¿Dónde vive la lógica de negocio y dónde no puede vivir?
2. ¿Por dónde entra y se valida todo dato externo?
3. ¿Qué no puede conocer la capa de negocio?
4. ¿Cómo se serializa la salida, y qué garantiza que no se filtre un campo interno?
5. ¿En qué orden se tocan los ficheros al implementar una unidad vertical?

### 3. `<stack>.rules.mdc` — opcional

Las mismas convenciones en formato de regla de Cursor, con `globs` que apunten a tus rutas. El
instalador la copia a `.cursor/rules/30-stack.mdc`.

### 4. `<stack>.ci.yml` — opcional

El pipeline de referencia. Se copia a `.github/workflows/ci.yml`. Mantén el criterio del kit: el
gate duro es el mutation score en los paths críticos, no un porcentaje de cobertura de líneas.

### 4b. Frontend

`react.frontend-standards.md` se copia siempre a `docs/frontend-standards.md`, sea cual sea el
adaptador de backend. Si tu frontend no es React, escribe el tuyo y cambia la línea correspondiente
del instalador, o simplemente reemplaza el fichero en el proyecto: es de los que el kit conserva si
difiere.

### 5. Detección automática — opcional

Si quieres que el instalador detecte tu stack solo, añade una rama a `detect_stack()` en
`install.sh` y al bloque equivalente de `install.ps1`. Mientras tanto, funciona con
`--stack mi-stack`.

### 6. Pruébalo

```bash
./install.sh --dest /tmp/repo-de-prueba --stack mi-stack --dry-run
./install.sh --dest /tmp/repo-de-prueba --stack mi-stack

cd /tmp/repo-de-prueba
export CLAUDE_PROJECT_DIR=$PWD
echo '{"source":"startup"}' | bash .claude/hooks/session-context.sh
echo '{"tool_input":{"command":"rm -rf /"}}' | bash .claude/hooks/block-dangerous-bash.sh
echo '{"tool_input":{"file_path":"<un fichero que viole una guarda>"}}' | bash .claude/hooks/post-edit-quality.sh
bash .claude/sync-artifacts.sh --check
```

Si los cuatro devuelven lo esperado, el adaptador está listo.

Y comprueba lo que no es automático: que `docs/backend-standards.md` describa **tu** arquitectura y no
la del adaptador que copiaste, porque ese fichero es lo que impide que el agente invente una
arquitectura distinta en cada tarea.

---

## MCP del proyecto

El instalador copia la misma plantilla a `.mcp.json` (Claude Code) y `.cursor/mcp.json` (Cursor):

| Plantilla | Cuándo |
|---|---|
| `ai-specs/templates/mcp.json` | Por defecto: Context7 + Playwright (`--isolated`) |
| `ai-specs/templates/mcp.context7-only.json` | `--no-frontend` / `-NoFrontend`: solo Context7 |

Arrancan con `npx` en el momento de usarlos; el kit no instala paquetes globales. Playwright no
sustituye la suite E2E del proyecto. Context7 no sustituye `docs/project-context.md`.

No pongas API keys en el JSON. Si Context7 te rate-limita en anónimo, exporta `CONTEXT7_API_KEY` en
el entorno de la máquina.

Jira, bases de datos u otros conectores con secretos no viven aquí: cada equipo los añade con
`claude mcp add` / la UI de Cursor.

---

## Depuración

**Un hook no hace nada.** Comprueba en este orden: ¿existe `jq`? ¿es ejecutable el script? ¿está la
variable que necesita rellena en `sdd-harness.env`? Pruébalo a mano pasándole el JSON por stdin, como en
los ejemplos de arriba.

**Stop: `Hook JSON output validation failed`.** Claude Code ya no acepta `additionalContext` en el
evento Stop. El recordatorio de suite en verde va en `systemMessage` (`notify` en `lib.sh`). El
bloqueo por suite en rojo sigue siendo `{decision:"block",reason:…}`, que sí es válido.

**Un hook bloquea de más.** Los hooks del kit distinguen entre denegar y pedir confirmación, y entre crear y reescribir.
Si algo se deniega y no debería, el patrón responsable está en `block-dangerous-bash.sh` o en
`protect-specs-and-tests.sh`; ajústalo en tu copia del repositorio, no en el kit.

**Desactivarlos todos temporalmente.** `{"disableAllHooks": true}` en la configuración local. No se
puede desactivar un hook individual: o todos, o ninguno.

**Ver qué se ejecuta.** Arranca la sesión en modo depuración y busca las líneas de ejecución de
hooks en el log.

**`validate-tasks` rechaza un `tasks.md` que crees correcto.** El mensaje enumera exactamente qué
condición falla. Las más frecuentes: el primer encabezado no es `## 0.`, falta la etiqueta
`(MANDATORY)`, el paso de verificación manual no dice `AGENT MUST EXECUTE`, o hay tareas que mutan
datos y ninguna menciona restauración. La doctrina completa está en
`docs/openspec-tasks-mandatory-steps.md`.

**Una skill no carga.** No es un problema de configuración: es la fuente canónica.
`bash .claude/sync-artifacts.sh --check` te dice el estado de cada referencia. `TEXTO` significa
symlink materializado; `DIVERGE`, que editaste la copia en lugar de `ai-specs/`.

**Los MCP no aparecen como herramientas.** El instalador copia `.mcp.json` (Claude Code) y
`.cursor/mcp.json` (Cursor) desde `ai-specs/templates/mcp.json` (o `mcp.context7-only.json` si
`--no-frontend`). El doctor avisa si faltan; no falla. Hay que habilitarlos en el IDE la primera
vez. No pongas API keys en esos JSON: `CONTEXT7_API_KEY` va en el entorno.

**Editas un hook y no cambia nada.** Los hooks se copian al repositorio en la instalación: el que se
ejecuta es `<tu-repo>/.claude/hooks/`, no el del kit. Edita ahí para este proyecto, y en el kit si
quieres el cambio en los próximos.
