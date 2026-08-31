# Manual del SDD Harness Kit

**Idioma:** Español · [English](MANUAL.en.md)

El flujo de trabajo que implementan los artefactos del kit, y por qué cada pieza está donde está.

Este documento es agnóstico: no menciona ningún proyecto ni obliga a ningún stack. Lo que cambia
entre proyectos vive en `docs/project-context.md`, `docs/backend-standards.md` y
`.claude/sdd-harness.env`.

El kit usa una fuente canónica en `ai-specs/`, doctrina en `docs/base-standards.md`, y los cuatro
ficheros de memoria apuntando a ella.

Inventario: **27 skills**, **9 subagentes** y **9 hooks**. Las skills y los subagentes se editan
siempre en `ai-specs/`; `.claude/` y `.cursor/` los referencian, y `bash .claude/sync-artifacts.sh`
reconstruye esas referencias cuando dejan de resolver.

---

## 1. El flujo en nueve fases

El kit organiza el trabajo en una secuencia estable de fases repartida
entre módulos. Reconstruida, es esta.

```
F0  HARNESS          Preparar la máquina antes de pedirle nada
     └─ 3 pilares (herramienta · contexto · prompt) · project-context.md · nivel de autonomía
F1  PLANIFICACIÓN    Convertir intención en trabajo ejecutable                    ◆ gate
     └─ story con INVEST → criterios de aceptación en GWT → non-goals → estimación
F2  ESPECIFICACIÓN   Convertir la story en contrato                               ◆ gate
     └─ propuesta + delta spec + decisiones de diseño + tasks
F3  ARMADO           Instalar los raíles deterministas de la sesión
     └─ skills · subagentes · hooks · MCP · plan mode
F4  EJECUCIÓN        Explore → Plan → Execute, task a task, en TDD                ◆ gate
     └─ rojo → verde → refactor
F5  VERIFICACIÓN     Demostrar que lo hecho es lo especificado
     └─ estático + tests + romper el test a propósito + mutación en paths críticos
F6  DOCUMENTACIÓN    Dejar rastro que no se desincronice
     └─ ADR · contratos de API generados · documentación de código
F7  ENTREGA          Firmar el trabajo                                            ◆ gate
     └─ commits atómicos · PR con qué/por qué/cómo probarlo · review
F8  CIERRE           Cerrar el bucle y aprender
     └─ archivar el change · métricas por origen del PR · retro con datos

TRANSVERSAL: ética, privacidad y seguridad en las nueve fases
```

**Dos caminos, un resultado.** F2 y F4 tienen dos formas equivalentes de ejecutarse: los comandos
nativos de OpenSpec (`/opsx:*`, instalados por `openspec init`) o los artefactos del kit. Usa el que
prefieras, mézclalos entre tickets o incluso dentro del mismo ticket — la doctrina en `docs/` y los
9 hooks no distinguen uno del otro, porque actúan sobre la ruta del fichero, no sobre quién lo
escribió.

| Fase | Camino nativo de OpenSpec | Camino del kit |
|---|---|---|
| Explorar | `/opsx:explore` | Subagente `explorer`, o el **prompt P4** |
| Especificar | `/opsx:propose` (o `/opsx:new` + `/opsx:continue`/`/opsx:ff`) | **Prompt P5** — «sirve también sin OpenSpec» |
| Auditar la propuesta | — | Subagente `spec-auditor`, o el **prompt P6** |
| Implementar | `/opsx:apply` | `/openspec-implement`, o el ciclo `/tdd-red` → `/tdd-green` → `/tdd-refactor` |
| Reconciliar delta → spec principal | `/opsx:sync` | — (no hace falta: `/openspec-implement` no toca `specs/`) |
| Verificar | `/opsx:verify` (workflow ampliado) | `/show-spec-working`, `/verify-against-spec`, `/adversarial-review` |
| Cerrar | `/opsx:archive` | — |

Lo que **no** cambia entre los dos caminos: `validate-tasks` sigue exigiendo el paso 0 y los pasos
obligatorios en cualquier `tasks.md`, `protect-specs-and-tests` sigue preguntando ante cualquier
reescritura de un artefacto que ya existe (lo haga `/opsx:apply` arreglando su propio trabajo o lo
hagas tú a mano), y `session-context` lee `openspec/changes` sin preguntar quién los creó.

### F0 · Harness

Antes de la primera línea de prompt hay que decidir tres cosas independientes, los **tres pilares**:

| Pilar | Lo que controla |
|---|---|
| **Herramienta** | Qué modelo, qué tools tiene, cómo se integra, qué flujos soporta |
| **Contexto** | Qué información tiene el modelo en su ventana cuando responde |
| **Prompt** | Cómo formulas la tarea, qué criterios de éxito das, qué restricciones pones |

> «Los tres importan por igual — si descuidas uno, los otros no compensan.»
> El cuello de botella más frecuente no es la herramienta, sino el contexto que recibe el modelo.

**Herramientas y artefactos por superficie:** un solo cuerpo de reglas, cuatro lecturas.
`docs/base-standards.md` la leen Claude Code, Cursor, Codex y Gemini a través de los cuatro ficheros
raíz; Cursor añade `.cursor/rules/`; Copilot, `.github/copilot-instructions.md`.

**Lo que instala el kit en esta fase:** la doctrina en `docs/`, los cuatro ficheros de memoria
apuntando a `docs/base-standards.md`, las reglas de Cursor y las instrucciones de Copilot. Cuatro
superficies, una sola fuente de verdad.

**Lo que tienes que hacer tú:** escribir `docs/project-context.md`. Menos de 200 líneas, y solo lo
que el agente no puede inferir leyendo el código:

- Comandos de build, test y ejecución no triviales.
- Convenciones internas: dónde vive cada cosa, cómo se nombra, qué patrón siguen las piezas.
- Restricciones operativas.
- *Gotchas*: lo que no es obvio y muerde.

Y lo que **no** va ahí: el árbol de directorios (aumenta el coste de inferencia sin mejorar la tasa
de éxito), la documentación de arquitectura (va en `docs/`) y el onboarding humano (va en el README).

Test de poda, línea a línea: *«¿causaría un error si la elimino?»*. Si no, elimínala.

**Umbral de contexto que hay que interiorizar:** por debajo del 50 % zona verde; entre el 50 y el
70 % conviene compactar; por encima del 70 % reset obligatorio. Compacta o reinicia cada 15-20
turnos en una sesión agéntica.

### F1 · Planificación

> «Antes: lo lee un dev humano que completa el contexto que falta con preguntas en el daily.
> Ahora: lo lee un copiloto que rellena el contexto que falta **inventando**, y luego un humano
> revisa lo inventado. El coste de la ambigüedad se multiplicó.»

Tres reglas no negociables cuando quien ejecuta es un agente:

1. El nivel correcto del prompt es la **story**, no el epic. Granularidad de 1-2 días
   humano-equivalente.
2. Las tasks son artefactos del agente, no del humano.
3. Los criterios de aceptación son la única defensa contra la *false completeness*.

**Filtro de entrada: INVEST.** Cualquier story que falle dos o más de los seis criterios vuelve a
refinamiento, sin negociación. *La IA no rescata stories vagas: las amplifica.*

**Patrón para escribir los criterios de aceptación — «AI as poke-holes»:**

1. El humano escribe el camino feliz: cuatro a seis bullets, tres minutos.
2. Se le pasa la story al copiloto pidiéndole casos límite, supuestos implícitos, escenarios
   faltantes y dependencias no mencionadas.
3. Devuelve diez o quince candidatos. La mayoría es ruido; te quedas con los tres o cinco reales.
4. El refinamiento discute los huecos, no lee la story en voz alta.

> «Nunca aceptes los criterios de aceptación del copiloto sin revisión humana contra el sistema
> real. Trátalos como primer borrador, nunca como entregable.»

**Orden del documento:** story → criterios → contexto técnico. El agente lee de arriba abajo; si
pones la técnica arriba, decide sobre implementación antes de entender el problema. Y al final,
siempre, los **non-goals**: sin límites explícitos el agente optimiza y refactoriza de más.

**Estimación:** puntos de historia para el sprint, tallas de camiseta para el roadmap, horas solo
para reporting externo. La IA participa como un par más en el planning poker: estima en privado, se
revela a la vez, no se promedia. Y **buffer del 30-40 %, no del 10 %**, por los cuatro impuestos que
introduce trabajar con agentes: verificación, calidad, rotación de herramientas e inestabilidad de
modelos.

**Skills del kit:** `/enrich-us`, `/dod-feature`, `/dod-bug`, `/dod-refactor`, `/dod-spike`,
`/dod-docs`.

### F2 · Especificación

> «La spec es la memoria que necesita la IA para construir lo que tú querías, no lo que ella
> improvisó.» · «Cuando algo no concuerda entre el código y la spec, gana la spec.»

La unidad de especificación es el **delta**: no la especificación completa del sistema, sino el diff
que aplica sobre ella. El equivalente a un commit de Git, pero para requisitos.

Cuatro artefactos por unidad de trabajo:

| Fichero | Qué contiene | Quién lo lee |
|---|---|---|
| `proposal.md` | El porqué de negocio y el alcance | Humano + IA |
| `specs/<capability>/spec.md` | Requisitos en RFC-2119 y escenarios en GIVEN/WHEN/THEN | IA, reviewers |
| `design.md` | Las decisiones técnicas ya cerradas | IA, para que no improvise arquitectura |
| `tasks.md` | Checklist accionable. Una task, un turno de agente | IA |

**Regla de tamaño de task:** «Cada task debe ser lo suficientemente pequeña como para ejecutarse en
un solo turno de IA. Si una task es *implementar el sistema de auth completo*, divídela. Si es
*crear la tabla en base de datos*, es perfecta.»

**Cuándo NO usar todo esto:** prototipos exploratorios, scripts de un solo uso, spikes de menos de
dos horas, correcciones triviales donde el cambio es obvio. Especificar tiene un coste; para eso
está el criterio.

**Plantillas del kit:** `ai-specs/templates/openspec/`. **Skills:** `/openspec-implement`.
**Subagente:** `spec-auditor`. **Hook:** `validate-tasks` rechaza un `tasks.md` sin los pasos
obligatorios de `docs/openspec-tasks-mandatory-steps.md`.

### F3 · Armado

Cualquier copiloto moderno se reduce a **siete primitivas**:

| # | Primitiva | Para qué se usa en este flujo |
|---|---|---|
| 1 | Memoria persistente | `docs/base-standards.md` (doctrina) + `docs/project-context.md` (hechos) |
| 2 | Skills | Procedimientos reusables invocables |
| 3 | Subagentes | Aislar contexto: explorar sin contaminar la sesión |
| 4 | Plan mode | Dry-run de solo lectura con gate humano |
| 5 | Hooks | Invariantes: «no se interpretan, se ejecutan» |
| 6 | MCP | Context7 (docs de librerías) y Playwright (demo de UI). Jira/BD los añade cada equipo |
| 7 | Output styles | Personalidad de la sesión |

MCP **no es un hook**: el modelo decide invocarlo. Por eso la doctrina (`base-standards.md` §11) y
las skills dicen *cuándo* usar Context7 y Playwright, y no hace falta escribir `use context7` en
cada prompt. Si el servidor está apagado, el agente debe decirlo y seguir —no inventar la API.

La regla de reparto que atraviesa todo el kit:

> **Hecho → memoria. Procedimiento → skill. Invariante crítico → hook.**
>
> «Lo que vive en CLAUDE.md es *interpretado* por el modelo (puede fallar). Lo que vive en hooks es
> *ejecutado* por código (falla nunca o siempre, pero es determinista). Para seguridad y
> compliance, siempre hooks.»

Y su corolario, que ahorra contexto: si un hook ya garantiza algo, **no lo repitas en el prompt**.
«El prompt ocupa contexto. El hook ya hace el trabajo. Estás pagando dos veces por la misma
garantía.»

### F4 · Ejecución

**Pipeline Explore → Plan → Execute:**

| Fase | Permisos | Modelo | Extra |
|---|---|---|---|
| Explore | Solo lectura | El más barato | En subagente, para no contaminar el contexto |
| Plan | Solo lectura | El mejor disponible | **Gate humano aquí** |
| Execute | Edición y ejecución | Equilibrado | Hooks de `PreToolUse` y `Stop` activos |

**Cuándo entrar en plan mode:**

```
¿La tarea toca más de 3 ficheros?
├── Sí → PLAN MODE
└── No → ¿Tiene efectos colaterales (base de datos, deploy, borrados, secretos)?
           ├── Sí → PLAN MODE + hooks PreToolUse
           └── No → ¿Conoces bien la zona del código?
                      ├── No → PLAN MODE
                      └── Sí → ¿Es un arreglo puntual, formato o log?
                                 ├── Sí → agéntico directo
                                 └── No → PLAN MODE
```

Dentro de Execute, el ciclo de cada task es **TDD adaptado a agentes**:

| Fase | Con agente | Subagente |
|---|---|---|
| 🔴 Rojo | El developer escribe o co-crea el test y **siempre lo revisa**. Confirma que falla | `tdd-test-writer` |
| 🟢 Verde | El **agente implementa** el código mínimo. Se permite devolver un valor fijo | `tdd-implementer` |
| 🔵 Refactor | El agente propone, el developer revisa. Los tests son la red de seguridad | `tdd-refactorer` |

**Un subagente por fase, y no por gusto de simetría.** El agente que acaba de pelearse para poner un
test en verde arrastra todas las justificaciones que usó para llegar ahí; refactorizar con ese contexto
en la sala es exactamente cómo una «mejora» cambia el comportamiento sin que nadie lo note. Contexto
limpio en cada fase es la razón de que el ciclo funcione con agentes.

> **Regla de oro:** «El test (o al menos el criterio de aceptación) debe ser autoría humana o
> supervisión humana explícita. La implementación puede delegarse a la IA. **Nunca al revés.**»
>
> «Nunca permitas que el agente modifique tus tests sin revisión explícita. Protege los tests como
> si fueran la especificación firmada del cliente — porque lo son.»

**Skills:** `/tdd-red`, `/tdd-green`, `/feature-slice`, `/openspec-implement`.
**Subagentes:** `explorer`, y la trilogía del ciclo TDD —`tdd-test-writer`, `tdd-implementer`,
`tdd-refactorer`— cada uno con contexto aislado para su fase.
**Hooks:** `protect-specs-and-tests`, `post-edit-quality`, `verify-tests`.

### F5 · Verificación

Cuatro gates, en orden de coste creciente:

1. **Análisis estático siempre activo.**
2. **Suite de tests**, con la forma de un trofeo: estático → unitarios → **integración, el mayor
   retorno** → e2e solo en los flujos críticos.
3. **Romper el test a propósito.** «Antes de confiar en un test generado por IA, rómpelo: cambia el
   retorno de la función, invierte una condición. Si el test sigue pasando, no sirve.»
4. **Mutation testing en los paths críticos** (autenticación, pagos, validaciones). Objetivo
   realista: 70 %. Hay casos publicados con 100 % de cobertura y un 4 % de mutation score.

La cobertura es una señal, no un objetivo: «exigir un 90 % obligatorio fabrica tests vacíos».

**Y el gate que más se salta:** la verificación la ejecuta el agente, no el usuario. Arrancar los
servicios, ejercer cada escenario contra el sistema real, restaurar el estado y dejar el informe es
trabajo, no documentación. `docs/openspec-tasks-mandatory-steps.md` lo exige y el hook
`validate-tasks` comprueba que el `tasks.md` lo contemple.

**Skills:** `/show-spec-working` (evidencia de ejecución), `/verify-against-spec` (conformidad),
`/adversarial-review` (revisión hostil con veredicto), `/pr-review`, `/code-auditing`.
**Subagente:** `security-reviewer`.

### F6 · Documentación

Cuatro capas, cada una con su ciclo de vida y su generador:

| Capa | Artefacto | Ciclo |
|---|---|---|
| Arquitectura | ADR + diagramas | Lento: meses |
| API | Contrato generado desde el código | Medio: semanas |
| Código | Documentación en el propio símbolo | Rápido: días |
| Operación | Runbooks, despliegue | Medio |

> «El código es la fuente de verdad. La herramienta solo lo convierte en algo legible — nunca
> escribes la documentación a mano y luego el código por separado.»
> «La IA genera el borrador, el humano valida la semántica. La forma es barata; el significado no.»

**Criterio para escribir un ADR:** «¿si este developer llegara hoy al proyecto y viera este código,
se preguntaría *por qué lo hicieron así*?». Y dos condiciones más: que afecte a más de un módulo y
que cueste más de un día revertirlo. Si no se cumplen, un comentario basta. Los ADR de relleno son
tan dañinos como su ausencia.

Nombre de fichero: `YYYYMMDD-slug.md`. Nunca numeración secuencial manual: colisiona cuando hay
ramas concurrentes.

**Skill:** `/adr-new`. **Plantillas:** `docs/adr/_template.md`.

### F7 · Entrega

- **Commits convencionales**, atómicos, en imperativo presente, primera línea de 72 caracteres.
  Si hay ticket, el scope **es el id**: `feat(KAN-184): add listing filter by state`. Rama:
  `feature/KAN-184-filter-listing`. Si no hay ticket, el scope es la capability o la capa; el
  agente pregunta antes de commitear.
- **PR con las tres preguntas obligatorias:** ¿qué cambia? · ¿por qué? · ¿cómo probarlo? El «qué»
  lo genera la IA desde el diff; el «cómo probarlo» en parte; **el «por qué» y las decisiones no**.
- **Revisión automática** en el pipeline, y revisión humana encima. Nunca solo la primera.
- Etiqueta cada PR con su origen: `human`, `human+copilot`, `agent`, `agent+human-review`.

> «El agente puede abrir el PR, pero tú firmas el merge.»

**Las cinco reglas de oro de Git con IA:**

1. Revisa el diff antes de aceptar cualquier commit generado por IA.
2. Nunca dejes que un agente haga `git push --force` sin confirmación humana.
3. Gate de CI estricto: bloquea el merge si fallan tests, seguridad o análisis estático.
4. Etiqueta los PR autogenerados.
5. Los conectores en modo solo lectura para revisión; nunca escritura sobre producción sin humano.

**Skills:** `/commit`, `/pr-describe`, `/pr-review`.

### F8 · Cierre

- **Archiva el change.** «Archivar no es opcional. Si dejas changes activos sin archivar, las
  próximas propuestas no tendrán el contexto correcto de qué ya está implementado.»
- **Mide segmentando por origen del PR**: velocity, bugs por PR, tiempo hasta el merge, tasa de
  retrabajo. «Si los agentes tienen tres veces más bugs, la velocity está mintiendo.»
- **Retro con la IA como fuente de datos, no como facilitadora.** Y siempre a nivel de equipo o de
  proceso, **nunca individual**: eso es ruido, sesgo, y rompe la confianza.

### Transversal · Ética, privacidad y seguridad

- **Plan de herramienta:** para uso profesional, plan empresarial o API. Nunca interfaces de
  consumidor para código o datos de empresa: la política de datos es radicalmente distinta aunque
  la marca sea la misma.
- **Dependencias sugeridas por IA:** verifícalas en el registro oficial antes de instalar. Casi uno
  de cada cinco paquetes que recomiendan los modelos no existe, y los atacantes registran esos
  nombres.
- **Secretos:** nunca en el contexto, nunca en ficheros que el asistente pueda leer.
- **Datos personales:** de-identificación antes de que el prompt salga de tu red; evaluación de
  impacto si hay tratamiento a gran escala; acuerdo de tratamiento con el proveedor.
- **Código generado:** en torno al 45 % del código generado por IA introduce vulnerabilidades del
  OWASP Top 10. El análisis de seguridad en el pipeline no es opcional.

**Hooks:** `block-secrets`, `block-dangerous-bash`. **Subagente:** `security-reviewer`.

---

## 2. Matriz de artefactos del kit

| Artefacto | Ruta | Fase | Qué garantiza |
|---|---|---|---|
| `docs/project-context.md` | `docs/` | F0 | Que el agente sepa lo que no puede deducir del código |
| `docs/base-standards.md` + 4 symlinks | raíz y `docs/` | F0 | La doctrina, en las cuatro superficies de agente |
| `docs/backend-standards.md` | `docs/` | F0 | Las capas concretas del stack |
| `docs/openspec-tasks-mandatory-steps.md` | `docs/` | F2 | Qué debe contener un `tasks.md` válido |
| `.cursor/rules/00-core.mdc` | Cursor | F0 | Las diez reglas invariantes, siempre activas |
| `.cursor/rules/10-tdd.mdc` | Cursor | F4 | La política TDD, siempre activa |
| `.cursor/rules/20-openspec.mdc` | Cursor | F2 | Cómo se trabaja un change |
| `.cursor/rules/30-stack.mdc` | Cursor | F4 | Las capas concretas del stack |
| `.github/copilot-instructions.md` | Copilot | F0 | Las mismas reglas en la tercera superficie |
| `explorer` | subagente | F4 | Exploración barata y aislada, con citas obligatorias |
| `tdd-test-writer` | subagente | F4 | El test primero, y que se vea fallar |
| `tdd-implementer` | subagente | F4 | El mínimo, respetando capas |
| `tdd-refactorer` | subagente | F4 | Mejora el diseño con la suite verde, sin tocar un solo test |
| `spec-auditor` | subagente | F2 | Que el alcance inventado se detecte antes de codificar |
| `security-reviewer` | subagente | F5 | Que nadie mergee un IDOR por prisa |
| `/enrich-us` | skill | F1 | Stories con criterios verificables y non-goals |
| `/dod-*` (5) | skills | F1 | Definition of Done por tipo de tarea |
| `/openspec-implement` | skill | F2-F4 | Trazabilidad escenario → test, task a task |
| `/feature-slice` | skill | F4 | Unidad vertical completa en el orden de capas |
| `/tdd-red`, `/tdd-green` | skills | F4 | El ciclo rojo-verde separado en dos turnos |
| `/verify-against-spec` | skill | F5 | Detectar tanto lo que falta como lo que sobra |
| `/pr-review` | skill | F5 | Primer pase de revisión, read-only |
| `/adr-new` | skill | F6 | Transcribir decisiones, y decir cuándo no hace falta |
| `/commit`, `/pr-describe` | skills | F7 | Commits atómicos y PR con el «por qué» vacío |
| `session-context` | hook | F0 | Que el agente arranque sabiendo dónde está |
| `validate-tasks` | hook | F2 | Que un `tasks.md` sin verificación no pase |
| `docs-gate` | hook | F6 | Que no se commitee con la documentación mintiendo |
| `block-secrets` | hook | transversal | Que ninguna credencial entre en el contexto |
| `block-dangerous-bash` | hook | transversal | Que `rm -rf`, `--force` y producción no pasen |
| `protect-specs-and-tests` | hook | F2-F4 | Que los specs, los tests y las migraciones no se reescriban sin decisión humana |
| `post-edit-quality` | hook | F4 | Formato, análisis estático y guardas de capas |
| `verify-tests` | hook | F4 | Que no se cierre el turno con la suite en rojo |

---

## 3. Las diez reglas invariantes

Son el núcleo no negociable. Están codificadas en `.cursor/rules/00-core.mdc` y, las que
admiten verificación mecánica, también en los hooks. Entre paréntesis, la guía del material que las
sostiene.

1. **La especificación gana al código.** Si no concuerdan, se corrige el código o se actualiza la
   especificación. Nunca se ignora la discrepancia. *(`07`)*
2. **El gate humano va en el plan**, ni antes ni después. *(`07`, `08`, `02b`)*
3. **Los tests son autoría o supervisión humana; la implementación se delega.** Nunca al revés.
   *(`15`)*
4. **El agente no toca sus propios tests.** *(`15`)*
5. **Hecho → memoria; procedimiento → skill; invariante → hook.** *(`08`, `10`, `11`)*
6. **Contexto curado, no acumulado.** *(`06`, `08`, `02b`)*
7. **Non-goals explícitos en cada unidad de trabajo.** *(`12`, `07`)*
8. **El «por qué» no lo escribe la IA.** *(`05`, `01`, `13`)*
9. **`git push --force` y los merges los firma un humano.** *(`00`, `05`, `01`)*
10. **Nunca secretos ni datos personales en el contexto del agente.** *(`08`, `14`)*

---

## 4. Cuánto delegar

El material contiene dos taxonomías L1–L5. La operativa —la que decide cómo trabajar una tarea
concreta— clasifica por **quién inicia la tarea y dónde está el humano**:

| Nivel | Quién inicia | Humano presente | Trazabilidad | Riesgo |
|---|---|---|---|---|
| 1 · Asistencia | Cada pulsación | Siempre | Ninguna | Nulo |
| 2 · Conversacional | Instrucción explícita | Activo, guiando | Solo si hay commit | Bajo |
| 3 · Agente de tarea | Tú asignas | Solo al revisar el PR | Commits, ramas, PR | Medio |
| 4 · Autónomo | El agente solo | Solo en revisión | PR, logs | Alto |
| 5 · Orquestación | Un orquestador IA | Solo en el orquestador | Compleja | Muy alto |

**Las tres preguntas:**

```
1. ¿Puedo describir "terminado" en una o dos frases sin ambigüedad?
     NO → Nivel 1-2. L1 si es un solo fichero; L2 si es ambigua o requiere criterio.
     SÍ → sigue.

2. ¿Necesito estar presente mientras se ejecuta?
     SÍ → Nivel 2.
     NO → sigue. (Comprueba antes: ¿el CI detectaría un error de esta tarea?
          Si no, vuelve al Nivel 2: sin red de seguridad no se delega.)

3. ¿Es una tarea que se repite sin que nadie la asigne?
     NO → Nivel 3. Asigna, vete, revisa el PR.
     SÍ → Nivel 4-5. L4 si es predecible y recurrente; L5 solo si es masivamente
          paralelizable y ya dominas L3 y L4.
```

**Test de Nivel 3, literal:** «¿Puedes crear una pull request desde tu teléfono sin abrir tu laptop?
Si la respuesta es sí, es Nivel 3.»

**Precondición dura para Nivel 3 o superior:** solo funciona bien si tu proceso de ingeniería ya
está organizado. La IA es un amplificador, no una solución.

Este kit está diseñado para **Nivel 2-3**. Las skills `/dod-*`, `/enrich-us` y los workflows de
CI son la puerta de entrada al Nivel 4.

---

## 5. Anti-patrones que el kit previene

| Anti-patrón | Cómo lo previene el kit |
|---|---|
| **Test Theater**: la IA genera código y tests a la vez, y los tests solo confirman lo que el código hace | `/tdd-red` separado de `/tdd-green`; el hook `protect-specs-and-tests` pide confirmación para modificar un test |
| **False completeness**: doce criterios de aceptación que parecen exhaustivos y no lo son | `/enrich-us` termina siempre con el aviso de que son un borrador pendiente de validar contra el sistema real |
| **Alcance inventado**: un PR de 800 líneas donde cabían 150 | Non-goals obligatorios en la story; el subagente `spec-auditor` los busca explícitamente |
| **Sobre-promptear con hooks activos** | La regla de reparto: si el hook lo garantiza, no va en el prompt |
| **Sesión zombi** | El hook de sesión recuerda el estado real; los umbrales de contexto están en el manual |
| **Cobertura como objetivo** | El gate duro es el mutation score, no el porcentaje de líneas |
| **Specs reescritos para encajar con el código** | Crear un artefacto es libre; el hook `protect-specs-and-tests` pregunta antes de reescribir uno que ya existe, para que sea un humano quien distinga «cambió el diseño» de «estoy ajustando la spec al atajo que ya tomé» |
| **Slopsquatting** | El hook pide confirmación en cada instalación de dependencias |
| **Secretos en el contexto** | El hook de `UserPromptSubmit` los detecta y oculta el prompt |
| **Capas mezcladas** | El hook `post-edit-quality` compara cada fichero contra las guardas del adaptador |

---

## 6. Decisiones del kit (criterios adoptados)

Cuando hay varias formas razonables de configurar el harness, el kit adopta estas:

| Tema | Criterio adoptado |
|---|---|
| Dos «OpenSpec» distintos bajo el mismo nombre: la herramienta CLI con `/opsx:*` y delta specs, y un framework conceptual con extensiones `.feature.spec.md` | La herramienta CLI para el flujo; el framework conceptual solo como catálogo de plantillas |
| Dos taxonomías L1–L5: por quién inicia la tarea, y por tipo de herramienta | La primera, para decidir delegación |
| Dos formatos de hooks: uno plano y otro de tres niveles (evento → matcher → handlers) | El de tres niveles, que es el canónico |
| Variables de entorno (`$CLAUDE_FILE`) frente a leer el JSON de stdin con `jq` | stdin y `jq` |
| `allowed-tools` como array YAML frente a lista con patrones de permiso | La lista con patrones, que permite granularidad de argumentos |
| Comandos de Git inexistentes frente a operaciones en lenguaje natural | Operaciones en lenguaje natural dentro de la sesión |
| Varias listas de skills de fábrica | La del inventario actual del kit |
