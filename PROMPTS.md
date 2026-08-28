# Secuencia de prompts

Dieciséis prompts, uno por paso del ciclo. Agnósticos de stack: los comandos y las rutas los toman de
`docs/project-context.md`, `docs/backend-standards.md` y `.claude/sdd-harness.env`, así que sirven igual en
cualquier proyecto donde hayas instalado el kit.

> **Los prompts están en español porque los escribes tú.** Los artefactos que produzcan —código,
> tests, especificaciones, mensajes de commit, documentación— van **en inglés**, porque
> `docs/base-standards.md` §2 lo exige. Varios prompts lo recuerdan explícitamente; si escribes uno
> nuevo, añádelo.

Cada prompt declara cuatro cosas:

- **Contexto y rol** — qué es el sistema y qué papel adopta la IA.
- **Inputs** — qué tienes que tener a mano antes de lanzarlo.
- **Instrucción** — la fase concreta del flujo.
- **Criterio de aceptación** — cómo sabes que ha salido bien, y cuándo rechazarlo sin discutir.

Sustituye solo lo que va entre `<corchetes angulares>`.

> Varios pasos tienen una skill o un subagente equivalente ya instalados. Cuando los haya, se indica:
> la skill es más rápida, el prompt es más explícito y editable. Usa el que prefieras.
>
> Las 27 skills y los 9 subagentes están en `ai-specs/`. `USO.md` los lista por fase.

---

## Reglas de uso

**Higiene de contexto.**

| Momento | Acción |
|---|---|
| Antes de P5 (especificar) | Contexto limpio. La IA lee el repositorio, no la conversación |
| Antes de P9 (implementar) | Si estás al 50 % o más de la ventana, límpiala primero |
| Entre tareas no relacionadas | Contexto limpio |
| Al 50-70 % de la ventana | Compacta con una indicación específica de qué conservar |
| Tras corregir dos veces el mismo problema | Limpia y reformula con lo aprendido, no sigas corrigiendo |

**Modelos.** El mejor disponible para P1-P3, P5-P7 y P12 (especificar, planificar, seguridad). Uno
equilibrado para P8-P11 (implementar). El más barato para P4 (explorar). No uses modelos pequeños
para generar la especificación.

**Gates humanos.** Cinco prompts donde no puedes limitarte a pulsar «sí»:

| Prompt | Qué revisas tú |
|---|---|
| **P2** | Los criterios de aceptación, contra el sistema real |
| **P6** | La propuesta: alcance inventado, escenarios que faltan, ambigüedad |
| **P7** | El plan, antes de que se escriba código |
| **P8** | El test: lo escribes o lo validas tú, y lo ves fallar |
| **P14** | El «por qué» del PR y la firma del merge |

---

## P0 · Bootstrap del harness

Se ejecuta una vez por repositorio, o cuando `docs/project-context.md` se ha quedado obsoleto. El instalador ya
deja el esqueleto con los comandos puestos; esto lo completa.

```
CONTEXTO Y ROL
Eres un arquitecto de software especializado en preparar repositorios para trabajo con agentes de
código. Tienes acceso de lectura a este repositorio.

INPUTS
- El repositorio completo.
- El manifiesto de dependencias y los ficheros de configuración de build, test y lint.
- El docs/project-context.md actual, que tiene marcadores {{...}} sin rellenar.

INSTRUCCIÓN
Completa docs/project-context.md. Reglas estrictas:

1. Menos de 200 líneas en total. Si no cabe, propón dividirlo por subdirectorio.
2. Rellena SOLO lo que un agente no puede inferir leyendo el código:
   - Comandos no triviales, con el comando exacto verificado en el manifiesto o en la
     configuración. Si un comando no existe, NO lo inventes: dilo.
   - Convenciones internas deducidas del código real: dónde vive cada cosa, cómo se nombra, qué
     patrón siguen las piezas equivalentes que ya existen.
   - Restricciones operativas.
   - Gotchas: comportamientos no obvios que hayas detectado leyendo el código o la configuración.
3. NO incluyas: árbol de directorios, documentación de arquitectura, onboarding para humanos, ni
   frases genéricas tipo "escribe código limpio".
4. Aplica el test de poda a cada línea: "¿causaría un error si la elimino?". Si no, elimínala.
5. Escríbelo EN INGLÉS: docs/base-standards.md §2 lo exige para todo artefacto técnico.

OUTPUT ESPERADO
El contenido completo de docs/project-context.md, más una lista aparte de las afirmaciones que has tenido que
inferir y que necesitan que yo las confirme.

CRITERIO DE ACEPTACIÓN
- Menos de 200 líneas.
- Todos los comandos citados existen realmente: indícame en qué fichero los has visto.
- Cero secciones de árbol de directorios.
- La lista de "afirmaciones a confirmar" no está vacía: si lo está, no has explorado lo suficiente.
```

---

## P1 · Expandir el issue a story ejecutable

> Skill equivalente: `/enrich-us <título y descripción>`

```
CONTEXTO Y ROL
Eres un Product Owner técnico. Conviertes issues en borrador en stories que un agente de código
pueda ejecutar sin inventarse nada. Tienes acceso de lectura al repositorio.

INPUTS
- Issue en borrador: "<título>" — <dos o tres frases de intención>
- docs/project-context.md y docs/backend-standards.md.

INSTRUCCIÓN
Genera la story completa en este orden exacto. El orden importa: el agente lee de arriba abajo, y si
pones la técnica primero decidirá sobre implementación antes de entender el problema de producto.

1. USER STORY — "Como <rol>, quiero <capacidad>, para <resultado de negocio>".
2. CRITERIOS DE ACEPTACIÓN en Given/When/Then. Entre 3 y 5 escenarios: camino feliz, al menos un
   caso límite y al menos un caso de error. Cada escenario debe ser traducible a un test
   automático: punto de entrada, entrada concreta, resultado esperado y efectos observables.
3. CONTEXTO TÉCNICO — busca en el repositorio y cita rutas REALES: dónde encaja, qué entidad toca,
   qué validación hay que extender, qué regla de autorización aplica y qué test previo sirve de
   plantilla. Si no encuentras alguno, dilo en lugar de inventar la ruta.
4. NON-GOALS — al menos dos límites explícitos.
5. ETIQUETAS Y ESTIMACIÓN — etiquetas de área y tipo, y talla S/M/L con una frase de justificación.

Aplica INVEST como filtro de salida. Si la story falla dos o más criterios, o no cabe en 1-2 días
humano-equivalente, márcala como needs-splitting y propón una descomposición en 2-3 stories.

OUTPUT ESPERADO
Markdown listo para pegar en el gestor de tareas, más una nota final recordando que los criterios
son un borrador pendiente de validación humana contra el sistema real.

CRITERIO DE ACEPTACIÓN
- Todas las rutas de fichero citadas existen. Verifícalas.
- Cada criterio es verificable: no acepto "el filtro debe funcionar".
- Hay al menos dos non-goals.
- Si marcas needs-splitting, la descomposición cubre el 100 % del alcance original.
```

---

## P2 · Poke-holes sobre los criterios de aceptación

**No delegues este paso.** El valor está en que la IA encuentre lo que faltaba, no en que escriba
los criterios desde cero.

```
CONTEXTO Y ROL
Eres un tester adversarial. Tu objetivo no es validar esta story: es romperla.

INPUTS
- User story y criterios de aceptación:
<pega la story completa>
- El repositorio, con acceso de lectura.

INSTRUCCIÓN
Dada esta story, lista:
1. Casos límite no cubiertos.
2. Supuestos implícitos que el redactor ha dado por hechos sin escribirlos.
3. Escenarios faltantes: concurrencia, autorización, datos vacíos, límites de tamaño, codificación
   de caracteres, valores nulos, estados intermedios del dominio, idempotencia.
4. Dependencias o riesgos no mencionados. Comprueba en el código qué otras partes del sistema tocan
   las mismas entidades, y qué efectos secundarios se disparan.

Para cada hallazgo indica: descripción, por qué importa, y si lo has deducido del código (con ruta y
línea) o de tu conocimiento general del dominio.

OUTPUT ESPERADO
Lista priorizada. Marca [CÓDIGO] los hallazgos verificados en el repositorio y [GENERAL] los que
provienen de tu conocimiento previo.

CRITERIO DE ACEPTACIÓN
- Entre 10 y 15 candidatos. Si das menos de 8, no has buscado lo suficiente.
- Al menos 3 hallazgos [CÓDIGO] con ruta y línea.
- NO reescribas los criterios. Solo señala huecos: decidir cuáles incorporar es mío.
```

---

## P3 · Estimación como par de planning poker

```
CONTEXTO Y ROL
Eres un miembro más del equipo en una sesión de planning poker. No eres el árbitro: eres un par que
estima en privado antes de que se revelen las cartas.

INPUTS
- Story a estimar:
<pega la story>
- Ejemplos calibrados del equipo (opcional, pero mejora mucho el resultado):
  <story pasada 1> = <puntos>
  <story pasada 2> = <puntos>
  <story pasada 3> = <puntos>
- El repositorio.

INSTRUCCIÓN
1. Estima en la escala Fibonacci del equipo (1, 2, 3, 5, 8, 13). Un ÚNICO número entero de la
   escala. Nada de decimales ni rangos: la precisión decimal es ficticia.
2. Justifica en tres bullets: qué hace la tarea grande, qué la hace pequeña, y qué incógnita
   concreta podría desviarla.
3. Aplica el multiplicador que corresponda y dilo explícitamente:
   - código nuevo: factor 0,85 sobre la estimación humana base
   - código heredado que el equipo conoce bien: factor 1,0, la IA no acelera aquí
   - exploración: no estimes en puntos, propón una talla de camiseta
4. Indica si detectas que esta story debería volver a refinamiento en lugar de entrar al sprint.

OUTPUT ESPERADO
Número Fibonacci, tres bullets, multiplicador aplicado y veredicto sobre si está lista.

CRITERIO DE ACEPTACIÓN
- El número está en la escala. Si me das "3,5" o "entre 3 y 5", el output es inválido.
- No presentes tu número como autoridad: es una carta más sobre la mesa. El número es el
  subproducto de la conversación, no el objetivo.
```

---

## P4 · Explore

> Subagente equivalente: delega en `explorer`.

Contexto limpio recomendado.

```
CONTEXTO Y ROL
Actúa como el subagente explorer: explorador de codebases de solo lectura. No propones
implementación y no editas nada.

INPUTS
- Objetivo de la feature: <resumen en una frase>
- El repositorio, docs/project-context.md y .claude/sdd-harness.env.

INSTRUCCIÓN
Mapea el estado actual del código relacionado, recorriendo las capas en el orden que declare
LAYER_ORDER. Identifica además el test existente MÁS PARECIDO al que habrá que escribir.

Devuelve exactamente este formato:

FINDINGS:
- <hecho verificado> (`ruta:línea`)

PATRÓN DE REFERENCIA:
- Test similar: `<ruta>` — estructura en dos líneas.
- Pieza equivalente ya implementada: `<ruta>:<símbolo>`.

OPEN QUESTIONS:
- <ambigüedad que un humano debe resolver antes de implementar>

OUTPUT ESPERADO
Máximo 30 líneas.

CRITERIO DE ACEPTACIÓN
- Todo hallazgo lleva ruta y línea. Sin cita, no cuenta.
- OPEN QUESTIONS no está vacía.
- No hay ninguna propuesta de implementación.
```

---

## P5 · Especificar el cambio

**Contexto limpio obligatorio.** Si usas OpenSpec, el comando `/opsx:propose "<descripción>"` hace
esto mismo. Este prompt es la versión controlada, y sirve también sin OpenSpec.

```
CONTEXTO Y ROL
Eres un arquitecto que escribe especificaciones ejecutables. La especificación es la fuente de
verdad: el código será una expresión de ella, y cuando ambos discrepen, gana la especificación.

INPUTS
- User story y criterios de aceptación validados:
<pega la story>
- Brief del codebase:
<pega el output de P4>
- Las plantillas de ai-specs/templates/openspec/ y docs/project-context.md.

INSTRUCCIÓN
Genera los cuatro artefactos del cambio en openspec/changes/<id>/:

1. proposal.md — secciones ## Why, ## What Changes, ## Capabilities (con ### New y ### Modified) y
   ## Impact. El "Why" explica el problema de negocio, no la solución.

2. specs/<capability>/spec.md — el DELTA, no la especificación completa del sistema:
     # Delta for <Capability>
     ## ADDED Requirements / ## MODIFIED Requirements / ## REMOVED Requirements
     ### Requirement: <nombre>   → cuerpo en RFC-2119 (The system MUST / SHALL ...)
     #### Scenario: <nombre>     → bullets - GIVEN / - WHEN / - THEN / - AND
   Cada criterio de aceptación de la story aparece como un escenario. En MODIFIED, añade
   "(Previously: ...)".

3. design.md — ## Context, ## Goals / Non-Goals, ## Decisions, ## Risks / Trade-offs,
   ## Open Questions. En Decisions cierra explícitamente: dónde se valida y por qué ahí, qué
   abstracción existente se reutiliza, cómo se garantiza el aislamiento por sujeto, qué forma exacta
   tiene la respuesta y qué se persiste. Todo lo que dejes abierto aquí lo improvisará el agente.

4. tasks.md — checklist `- [ ] N.M descripción`. DEBE cumplir docs/openspec-tasks-mandatory-steps.md:
   - El paso 0 crea la rama de trabajo, y es el primero.
   - Están presentes y etiquetados (MANDATORY) los pasos de: revisar los tests existentes, ejecutar
     los tests y verificar el estado de los datos, verificación manual de la interfaz, y actualizar
     la documentación técnica.
   - Los pasos de verificación manual declaran AGENT MUST EXECUTE.
   - Toda tarea que mute datos incluye su restauración.
   - Cada task cabe en un solo turno de agente: si una task es "implementar el módulo", divídela.
   El hook validate-tasks rechaza el fichero si falta alguna de estas condiciones, así que
   comprobarlo antes te ahorra un turno.

OUTPUT ESPERADO
Los cuatro ficheros completos, cada uno en su bloque, con su ruta como encabezado.

CRITERIO DE ACEPTACIÓN
- Hay exactamente un escenario por cada criterio de aceptación, y ninguno inventado.
- El delta NO contiene requisitos ya existentes que no cambien.
- design.md no deja ninguna decisión de arquitectura al criterio del implementador.
- Ninguna task necesita más de un turno.
- tasks.md pasa el hook validate-tasks: paso 0 de rama, pasos obligatorios etiquetados,
  AGENT MUST EXECUTE en la verificación manual, restauración de estado, numeración N.M.
- Todo el contenido está en inglés.
- Si detectas ambigüedad, va a Open Questions. No la resuelvas tú.
```

---

## P6 · Auditar la propuesta antes del gate

> Subagente equivalente: delega en `spec-auditor`.

Este prompt no sustituye tu revisión: la enfoca.

```
CONTEXTO Y ROL
Eres un revisor de especificaciones. Encuentras los defectos de esta propuesta antes de que se
escriba una línea de código, porque después cuesta diez veces más.

INPUTS
- Los cuatro ficheros del cambio, con acceso de lectura.
- El repositorio.

INSTRUCCIÓN
Audita la propuesta contra esta checklist y responde punto por punto:

1. ALCANCE INVENTADO — ¿hay algo en la propuesta o en las tasks que no se deduzca de los requisitos?
   Lístalo para que lo recorte.
2. ESCENARIOS FALTANTES — ¿algún requisito describe un comportamiento en su MUST sin escenario?
3. AMBIGÜEDAD — busca "rápido", "fácil", "seguro", "eficiente", "muchos", "adecuado", "robusto".
   Cada aparición es un defecto: propón la formulación medible.
4. CONTRADICCIONES — entre propuesta, diseño y especificación.
5. CONTRASTE CON EL CÓDIGO REAL — ¿alguna decisión choca con lo que ya existe? ¿duplica una
   abstracción? Cita ruta y línea.
6. TAMAÑO DE TASKS — marca las que no caben en un turno.
7. PASOS OBLIGATORIOS — contrasta tasks.md con docs/openspec-tasks-mandatory-steps.md: ¿el paso 0
   crea la rama? ¿están los pasos de verificación, etiquetados (MANDATORY)? ¿declaran AGENT MUST
   EXECUTE? ¿las tareas que mutan datos incluyen restauración?
8. TRAZABILIDAD — tabla Requisito → Escenario → task(s). Marca los huecos.

OUTPUT ESPERADO
Informe con los ocho puntos. Cada hallazgo con severidad (bloqueante / mejorable) y la corrección
concreta propuesta.

CRITERIO DE ACEPTACIÓN
- No modificas ningún fichero: solo informas.
- La tabla de trazabilidad está completa. Una fila vacía es un hallazgo bloqueante.
- Si no encuentras nada, dilo explícitamente en lugar de inventar un hallazgo.
```

**Gate humano.** Abre los cuatro ficheros y edítalos tú. Recorta el alcance inventado, añade los
escenarios que falten, resuelve las ambigüedades. Este es el momento más valioso del flujo.

---

## P7 · Plan de implementación

Entra en plan mode antes de lanzarlo.

```
CONTEXTO Y ROL
Estás en plan mode: solo lectura. Eres un tech lead planificando la ejecución de un cambio ya
especificado y aprobado.

INPUTS
- El cambio completo (propuesta, diseño, especificación, tasks).
- docs/project-context.md, docs/backend-standards.md y .claude/sdd-harness.env.
- El repositorio.

INSTRUCCIÓN
Produce un plan que respete el orden de capas declarado en LAYER_ORDER.

Para cada task indica:
- Fichero exacto que se crea o modifica, con su ruta.
- Qué cambia dentro de ese fichero, en una frase.
- El comando exacto con el que se verifica.
- Riesgo: bajo / medio / alto, y por qué.

Añade al final:
- La lista de ficheros existentes que se van a MODIFICAR (no crear), para que yo valore el radio de
  impacto.
- Si hace falta un cambio de esquema: el nombre propuesto y si es reversible.
- Los supuestos que estás haciendo y que podrían estar equivocados.

OUTPUT ESPERADO
Plan en Markdown, ordenado, ejecutable paso a paso.

CRITERIO DE ACEPTACIÓN
- Ninguna task toca ficheros bajo openspec/.
- Ninguna task propone modificar un test existente ni una migración ya aplicada.
- No se introducen dependencias nuevas. Si crees que hacen falta, para y pregúntame.
- Si el plan toca más de 8 ficheros, propón partir el cambio en dos.
```

**Gate humano.** Lee el plan entero y edítalo antes de aprobar.

---

## P8 · Rojo — el test que falla

> Skill equivalente: `/tdd-red <descripción>`

```
CONTEXTO Y ROL
Estamos haciendo TDD estricto. Eres un ingeniero de QA senior. NO implementes código de producción
en este turno.

INPUTS
- Escenario:
<pega el bloque GIVEN / WHEN / THEN completo>
- Test de referencia: <ruta del test más parecido>
- docs/project-context.md, docs/backend-standards.md y .claude/sdd-harness.env.

INSTRUCCIÓN
1. Lee el test de referencia y copia su estructura: imports, agrupación, preparación de datos,
   helpers de autenticación, aislamiento de base de datos.
2. Escribe UN SOLO test:
   - Comentario "// Scenario: <nombre exacto del escenario>" justo encima.
   - Nombre que describa el comportamiento observable, no la implementación.
   - Patrón Arrange-Act-Assert con los tres bloques separados y comentados.
   - Datos de prueba con las factories o helpers del proyecto.
   - Aserciones sobre el contrato: código de respuesta, forma del payload, efectos persistidos.
     Nada sobre detalles internos.
3. Ejecútalo con el comando de filtro del proyecto.
4. Detente y repórtame el mensaje de fallo exacto.

OUTPUT ESPERADO
El fichero de test completo y la salida del comando mostrando el fallo.

CRITERIO DE ACEPTACIÓN
- El test FALLA. Si pasa a la primera, no sirve: dímelo y reescríbelo.
- No has tocado la capa de producción.
- No has modificado ningún test existente.
- El nombre del test explica el comportamiento sin necesidad de leer el cuerpo.
```

---

## P9 · Verde — implementación mínima

> Skills equivalentes: `/tdd-green <ruta del test>` y, después, `/tdd-refactor <fichero>`.
> Subagentes: `tdd-implementer` y `tdd-refactorer`.
>
> Son **dos turnos, no uno**. El kit recomienda un subagente por fase del ciclo precisamente por
> esto: el agente que acaba de pelearse para poner el test en verde arrastra las justificaciones que
> usó para llegar ahí, y refactorizar con ese contexto en la sala es cómo una «mejora» cambia el
> comportamiento sin que nadie lo note.

Si estás al 50 % o más de contexto, límpialo antes: el agente releerá los ficheros del disco.

```
CONTEXTO Y ROL
Eres un desarrollador senior. Hay un test en rojo. Tu único objetivo es ponerlo en verde con el
mínimo código posible.

INPUTS
- Test en rojo: <ruta>
- design.md del cambio.
- docs/project-context.md, docs/backend-standards.md y .claude/sdd-harness.env.

INSTRUCCIÓN
1. Ejecuta el test y lee el fallo real. No supongas el motivo.
2. Implementa siguiendo el orden de LAYER_ORDER, y solo lo necesario.
3. Vuelve a ejecutar hasta verde. Después lanza la suite completa para comprobar que no has roto
   nada.
4. Deja limpios el análisis estático y el linter.

Puedes devolver un valor fijo si con un solo test basta. Si lo haces, dímelo explícitamente para
que yo añada el test de triangulación.

OUTPUT ESPERADO
Ficheros tocados, diff de cada uno, salida del test en verde, y si has usado un valor fijo.

CRITERIO DE ACEPTACIÓN
- El test pasa; análisis estático y linter limpios.
- No has modificado el test. Si creías que estaba mal, deberías haberte detenido.
- No hay escapes del sistema de tipos en el código nuevo.
- No hay lógica de negocio en la capa de transporte.
- No has añadido dependencias.
```

---

## P9b · Refactor — con la suite en verde

> Skill equivalente: `/tdd-refactor <fichero o módulo>` · Subagente: `tdd-refactorer`
>
> Lánzalo en un turno nuevo, no en el mismo que puso el test en verde.

```
CONTEXTO Y ROL
Estamos en la fase REFACTOR del ciclo TDD. La suite está en verde. Tu trabajo es mejorar el diseño
sin cambiar el comportamiento observable.

INPUTS
- Fichero o módulo a refactorizar: <ruta>
- docs/backend-standards.md y .claude/sdd-harness.env.

INSTRUCCIÓN
1. Ejecuta la suite y confirma que está verde. Si algo está en rojo, detente: no hay nada que
   refactorizar, hay algo que arreglar, y es otro trabajo.
2. Lee el código y dame una lista ORDENADA POR VALOR de candidatos a refactor, con el motivo de
   cada uno. Muéstrala antes de tocar nada.
   Prioriza en este orden: violaciones de capas; duplicación que ya ha divergido; nombres que
   mienten; funciones que no puedes nombrar sin usar "y"; conceptos del dominio pasados como string
   suelto; código que no se puede testear sin tocar el exterior.
3. Aplica UN refactor a la vez, ejecutando la suite después de cada uno.
4. Deja limpios el análisis estático y el linter.
5. Reporta qué cambiaste, qué dejaste deliberadamente igual, y por qué.

CRITERIO DE ACEPTACIÓN
- El comportamiento observable es idéntico: mismos contratos, mismas respuestas, mismos efectos.
- NO has tocado ningún test. Ni uno. Si un refactor necesitaba cambiar un test, el comportamiento
  cambió y no era un refactor: quiero que te detengas y me lo digas.
- La cobertura no ha bajado.
- No has mezclado ninguna corrección de bug ni trabajo de feature, ni siquiera de una línea.
- Si el código ya estaba lo bastante limpio, lo dices y no cambias nada. Churn sobre una suite verde
  es riesgo puro.
```

---

## P10 · Triangulación y casos límite

```
CONTEXTO Y ROL
Eres un tester con conocimiento del dominio. La implementación pasa los tests, pero puede estar
devolviendo valores fijos o estar incompleta.

INPUTS
- Implementación actual: <rutas de los ficheros tocados>
- Tests actuales: <ruta>

INSTRUCCIÓN
1. Si detectas un valor fijo que hace pasar el test sin implementar el comportamiento real, escribe
   un segundo test que fuerce la generalización.
2. Dame 5 casos límite que probablemente yo no haya considerado, priorizando los del dominio de
   negocio sobre los genéricos. Incluye al menos uno de autorización y uno de integridad de datos.
3. Para cada uno: qué pasaría hoy con el código actual (léelo, no lo supongas) y si debería cubrirse
   en este cambio o en un ticket aparte.
4. Rompe a propósito la implementación: cambia el retorno de un método o invierte una condición, y
   dime qué tests siguen pasando. Los que sigan pasando no sirven.
5. Si el código tocado está en la capa de negocio, ejecuta el mutation testing del proyecto y
   reporta el score.

OUTPUT ESPERADO
Test de triangulación si procede, los 5 casos límite con veredicto, el resultado del ejercicio de
romper la implementación y el mutation score si aplica.

CRITERIO DE ACEPTACIÓN
- El ejercicio de "romper a propósito" está hecho de verdad, con la salida del test como prueba.
- Restauras el código a su estado correcto al terminar.
- Si el mutation score baja del umbral configurado, lo señalas como bloqueante.
- No añades los casos límite al alcance sin preguntarme: solo los propones.
```

---

## P11 · Demostrar, verificar y refutar

> Skills equivalentes, en este orden: `/show-spec-working <id>` → `/verify-against-spec <id>` →
> `/adversarial-review <id>`

Son tres cosas distintas y se confunden a menudo:
>
> - **Demostrar** (`/show-spec-working`): el agente arranca el sistema, ejerce cada escenario contra
>   la interfaz real y entrega evidencia. Es lo que el harness marca como «AGENT MUST EXECUTE», y es
>   trabajo, no documentación. Nunca se delega al usuario.
> - **Verificar** (`/verify-against-spec`): conformidad entre código y especificación, incluido lo que
>   sobra.
> - **Refutar** (`/adversarial-review`): revisión hostil con veredicto, **en una sesión distinta de la
>   que implementó**.
>
> El prompt de abajo cubre el segundo. Para el primero y el tercero usa las skills: dependen de
> ejecutar cosas y de aislar el contexto, y eso lo hacen mejor ellas.

```
CONTEXTO Y ROL
Eres un auditor de conformidad. La implementación está terminada. Comprueba si hace exactamente lo
que la especificación dice, ni más ni menos.

INPUTS
- El delta spec del cambio.
- El código implementado y los tests.

INSTRUCCIÓN
Compara código y especificación, y devuelve tres bloques:

1. REQUISITOS IMPLEMENTADOS CORRECTAMENTE — con la ruta del código y del test que lo demuestra.
2. REQUISITOS NO IMPLEMENTADOS O PARCIALES — qué falta exactamente.
3. COMPORTAMIENTOS NO ESPECIFICADOS — código que hace cosas que la especificación no pide. Es tan
   grave como lo anterior: es alcance inventado, y nadie lo ha revisado.

Revisa además: ¿alguna dependencia importada que no exista en el manifiesto? ¿alguna comprobación de
autorización que la especificación exigía y no está? ¿algún campo en la respuesta que no se mencione?
¿algún escenario cuyo test asegure algo más débil de lo que el escenario dice?

Y si algo del bloque 2 o 3 hay que corregir: recuerda la regla 7 de docs/base-standards.md. Un cambio
que llega después de implementar y antes de archivar se trata PRIMERO como actualización de los
artefactos del change, y solo después se toca el código.

OUTPUT ESPERADO
Los tres bloques y una tabla final Escenario → test → estado (verde / rojo / ausente).

CRITERIO DE ACEPTACIÓN
- Cada afirmación va con ruta y línea.
- Si el bloque 3 está vacío, justifícalo: es poco habitual.
- No corriges nada en este turno.
```

---

## P12 · Revisión de seguridad

> Subagente equivalente: delega en `security-reviewer`.

```
CONTEXTO Y ROL
Actúa como el subagente security-reviewer. Solo analizas: no modificas nada.

INPUTS
- El diff de la rama contra la rama base.
- docs/project-context.md, docs/backend-standards.md y .claude/sdd-harness.env.

INSTRUCCIÓN
Revisa el diff completo contra esta lista, por severidad:

ALTA — secretos en texto plano; rutas nuevas sin autenticación; autorización ausente sobre un
recurso ajeno; entrada externa que no pasa por la capa de validación; asignación masiva desde la
petición; consultas por concatenación; datos sensibles en la respuesta.
MEDIA — errores que filtran estructura interna; listados sin paginación; dependencias nuevas cuyo
nombre debas verificar en el registro oficial; datos personales enviados a terceros sin
de-identificar.
BAJA — logs con el cuerpo completo de la petición; ausencia de limitación de tasa en endpoints
públicos.

OUTPUT ESPERADO
Tabla: severidad · fichero:línea · hallazgo · corrección propuesta.

CRITERIO DE ACEPTACIÓN
- Si no encuentras nada, dilo explícitamente.
- Todo hallazgo lleva fichero y línea.
- No modificas ningún archivo.
```

---

## P13 · Documentación

> Skills equivalentes: `/update-docs` para encontrar qué invalidó el cambio, y `/adr-new <título>`
> para el registro de decisión. El hook `docs-gate` comprueba lo mismo antes de dejarte commitear un
> cambio de esquema o de contrato.

```
CONTEXTO Y ROL
Eres un technical writer con criterio de ingeniería. La feature está implementada y verificada. Tu
trabajo es dejar rastro de lo que no se deduce del código.

INPUTS
- El diff completo del cambio.
- design.md y los ADR existentes.
- docs/project-context.md, docs/backend-standards.md y .claude/sdd-harness.env.

INSTRUCCIÓN
Tres tareas en orden:

1. ADR. Aplica primero el criterio de necesidad: ¿un developer nuevo se preguntaría "por qué lo
   hicieron así"? ¿afecta a más de un módulo? ¿cuesta más de un día revertirlo? Si NO procede,
   dímelo y no escribas nada. Si procede, créalo en PATH_ADR con nombre <YYYYMMDD>-<slug>.md,
   siguiendo la plantilla del proyecto y transcribiendo la decisión que ya está en design.md. No
   inventes alternativas que nadie consideró. Actualiza el índice.

2. DOCUMENTACIÓN DE CÓDIGO. Añádela a los símbolos públicos nuevos de la capa de negocio y de la
   capa de transporte: descripción de una frase, parámetros con su sentido (no su tipo, que ya está
   en la firma), retorno, errores que lanza, y un ejemplo en los métodos de negocio. Debe pasar la
   comprobación de cobertura de documentación del proyecto.

3. CONTRATO DE API. Regenera lo que sea generable. Anota a mano SOLO lo que el generador no pueda
   inferir. Duplicar lo que ya se infiere es deuda.

OUTPUT ESPERADO
Los ficheros generados o modificados, cada uno en su bloque.

CRITERIO DE ACEPTACIÓN
- Si el ADR no procede, no lo escribes: los ADR de relleno son un anti-patrón.
- El "por qué" del ADR sale de design.md o de lo que yo te haya dicho, no de tu imaginación.
- La documentación de código no repite en prosa lo que ya dice la firma.
```

---

## P14 · Commit y Pull Request

> Skills equivalentes: `/commit` y `/pr-describe`

```
CONTEXTO Y ROL
Eres un desarrollador cerrando una unidad de trabajo. El agente prepara; el humano firma.

INPUTS
- El estado del working tree y el diff.
- El cambio especificado.
- El ticket: <id y título>

INSTRUCCIÓN
1. COMMITS. Revisa el diff. Si mezcla áreas distintas, propón commits atómicos separados con
   staging selectivo, y pídeme confirmación antes de ejecutar nada. Formato convencional:
   tipo(TICKET-ID): descripción si hay ticket (ej. feat(KAN-184): add listing filter by state);
   si no, tipo(capa-o-capability): descripción. Verbo en imperativo presente, primera línea de
   72 caracteres máximo. El id del ticket sale de la rama (`feature/KAN-184-…`), de lo que yo
   te pase, o me lo preguntas; no lo inventes.

2. DESCRIPCIÓN DEL PR:
   - "¿Qué cambia?" — una a tres frases desde el diff.
   - "¿Cómo probarlo?" — pasos numerados y ejecutables tal cual, con los comandos reales.
   - "Trazabilidad" — tabla Escenario → fichero:línea del test que lo cubre.
   - "Decisiones / trade-offs" — SOLO si puedes fundamentarlas en design.md o en un ADR.
   Deja "¿Por qué?" con el marcador <!-- lo completa el humano -->.

3. Sugiere la etiqueta de origen del PR: human / human+copilot / agent / agent+human-review.

OUTPUT ESPERADO
Comandos de commit propuestos, sin ejecutar todavía, y la descripción del PR en Markdown.

CRITERIO DE ACEPTACIÓN
- No has hecho push. Nunca lo haces tú.
- La sección "¿Por qué?" está vacía y marcada, no rellenada.
- Todos los comandos de "¿Cómo probarlo?" son ejecutables tal cual.
- La tabla de trazabilidad no tiene filas vacías.
```

---

## P15 · Cierre y aprendizaje

Archiva el cambio primero. Después:

```
CONTEXTO Y ROL
Eres un analista de proceso. El cambio está mergeado. Trabajas a nivel de equipo y de proceso,
NUNCA a nivel individual.

INPUTS
- El cambio archivado.
- Datos del ciclo: <tiempo desde la apertura del PR hasta el merge>, <número de comentarios de
  revisión>, <commits de corrección tras la primera revisión>, <etiqueta de origen del PR>.

INSTRUCCIÓN
1. Compara el tasks.md final con el original: ¿aparecieron tasks no previstas? ¿cuáles y por qué?
2. Compara la especificación original con el código final: ¿hubo desviaciones? ¿se actualizó la
   especificación o se dejó desincronizada?
3. Identifica en qué fase se perdió más tiempo: especificación, implementación o revisión.
4. Propón UNA mejora concreta del proceso, no del equipo, e indica DÓNDE se implementa:
   - un hecho del proyecto        → docs/project-context.md
   - una convención de capas      → docs/backend-standards.md
   - un procedimiento repetido    → una skill nueva en ai-specs/skills/ (usa /writing-skills)
   - un invariante que no falla   → un hook en .claude/hooks/
   - un comando o ruta que cambió → .claude/sdd-harness.env
   Si es una skill o un agente nuevo, recuerda ejecutar después bash .claude/sync-artifacts.sh.

OUTPUT ESPERADO
Cuatro apartados breves. El último, con la mejora y dónde se implementaría exactamente.

CRITERIO DE ACEPTACIÓN
- Ninguna afirmación sobre personas concretas.
- La mejora es implementable esta semana, no un principio general.
```

---

## Apéndice · Prompts de rescate

### El agente ignora las decisiones de diseño

Causa habitual: el contexto ha crecido y `design.md` quedó enterrado. Limpia el contexto y relanza
referenciando el fichero explícitamente en el primer turno.

```
Implementa el cambio <id>.
Lee primero, en este orden y sin excepción: proposal.md, design.md, specs/*.md y tasks.md.
Sigue tasks.md paso a paso. Pregúntame antes de desviarte de cualquier requisito de specs/.
```

### El agente ha modificado un test para que la suite pase

```
Detente. Has modificado un test existente. Los tests son la especificación firmada, no un obstáculo.

1. Revierte el cambio en el fichero de test y muéstrame el diff de la reversión.
2. Ejecuta la suite y muéstrame el fallo real, sin tocar el test.
3. Explícame por qué falla el código, no por qué "el test estaba mal".
4. No implementes nada hasta que yo te lo diga.
```

### El agente propone una dependencia nueva

```
Antes de instalar nada:
1. Dime el nombre exacto del paquete y su versión.
2. Dime qué problema resuelve que no se pueda resolver con lo que ya está en el manifiesto.
3. Dime qué parte del código quedaría acoplada a él y cuánto costaría sacarlo.
No lo instales. La verificación en el registro oficial y la decisión son mías.
```

### Una skill no aparece o no se aplica

Casi siempre es la fuente canónica. `ai-specs/` es donde se edita; `.claude/skills/` y
`.cursor/skills/` solo la referencian, y en Windows pueden ser copias independientes.

```bash
bash .claude/sync-artifacts.sh --check
```

Si dice `TEXTO`, el symlink se materializó como fichero y la skill no carga: ejecútalo sin `--check`.
Si dice `DIVERGE`, editaste la copia en vez del original: mueve el cambio a `ai-specs/` y sincroniza.
Si dice `FALTA`, la skill es nueva y nunca se enlazó. Y si acabas de crear el directorio de skills,
reinicia la sesión: la recarga en caliente no cubre ese caso.

La skill `/sync-agent-artifacts` hace este diagnóstico y te explica cada estado.

### La sesión se ha degradado

Compacta indicando en una frase qué es lo único que importa conservar. Si has corregido dos veces el
mismo problema, no compactes: limpia del todo y reformula el prompt incorporando lo aprendido de los
dos intentos fallidos.

### Necesitas una especificación y no sabes por dónde empezar

```
Quiero construir <descripción breve>. Entrevístame en detalle antes de escribir nada.
Pregúntame sobre implementación técnica, casos borde, restricciones y trade-offs.
Sigue preguntando hasta que hayamos cubierto todo, y entonces escribe la especificación completa
en SPEC.md.
```

Después, sesión nueva para implementar: contexto limpio más especificación escrita rinde mejor que
continuar en la sesión saturada.
