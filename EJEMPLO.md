# Una unidad de trabajo, de principio a fin

Recorrido completo del flujo sobre una unidad genérica, para ver cómo encajan las piezas. No es un
tutorial de ningún framework: los nombres van entre `<corchetes>` y la traducción a tu stack sale de
`docs/backend-standards.md` y de `LAYER_ORDER` en `.claude/sdd-harness.env`.

El caso: **añadir un filtro opcional a un listado existente**. Es deliberadamente pequeño. La
mayoría del trabajo real tiene este tamaño, y es donde el flujo se nota.

---

## Punto de partida

Un issue de tres frases en el gestor de tareas:

> **Filtrar el listado por estado**
> La vista de «pendientes» se está quedando corta. El cliente descarga todo y filtra en memoria.

Eso es todo lo que hay. Lo que sigue es cómo se convierte en un merge.

---

## F1 · De issue a story

`/enrich-us Filtrar el listado por estado — la vista de pendientes descarga todo y filtra en memoria`

Devuelve un borrador. Este es el resultado **después** de pasarle P2 (poke-holes) y de que un humano
recorte y añada:

```markdown
## Story
Como miembro del equipo, quiero filtrar el listado por estado,
para ver de un vistazo lo que tengo pendiente hoy.

## Criterios de aceptación

Scenario: Filtro por un estado válido
Given un usuario autenticado con 12 <recursos>, 5 de ellos en estado "pendiente"
When solicita el listado filtrando por estado "pendiente"
Then la respuesta es correcta
And  contiene exactamente 5 elementos
And  todos están en estado "pendiente"

Scenario: Sin filtro se mantiene el comportamiento actual
Given un usuario autenticado con 12 <recursos>
When solicita el listado sin filtro
Then la respuesta contiene los 12

Scenario: Estado no reconocido
Given un usuario autenticado
When solicita el listado con un estado que no existe
Then la respuesta es un error de validación
And  el mensaje enumera los estados admitidos

Scenario: Aislamiento entre usuarios
Given otro usuario tiene <recursos> en estado "pendiente"
When el usuario autenticado filtra por "pendiente"
Then la respuesta no incluye ningún <recurso> ajeno

Scenario: Petición sin autenticar
Given una petición sin credenciales
When solicita el listado
Then la respuesta es no autorizado

## Contexto técnico
- Punto de entrada: <PATH_HTTP>/<recurso>_controller — el método de listado ya existe
- Entidad: <PATH_SOURCE>/models/<recurso>, campo `estado`
- Validación a extender: <la del listado>
- Test de referencia: <PATH_TESTS>/<recurso>/listado

## Non-goals
- No filtrar por otros campos: va en su propio ticket
- No tocar el cliente
- No añadir índices de base de datos en este ticket
- No refactorizar el controlador más allá del método afectado

## Estimación
S — un filtro de lectura sobre una entidad que ya existe.
```

**Lo que aportó la IA:** el borrador y los escenarios de aislamiento y de no autenticado, que el
autor del issue no había pensado.

**Lo que aportó el humano:** los non-goals, y descartar tres «mejoras» que el copiloto había colado
—ordenación configurable, paginación por cursor y un endpoint de recuento— que nadie había pedido.

> Ese descarte es exactamente el trabajo del gate de F1. Sin él, esta story de talla S habría
> llegado a implementación como una L.

---

## F2 · De story a contrato

Contexto limpio. `/opsx:propose` o el prompt P5 — cualquiera de los dos produce los mismos cuatro
ficheros y queda sujeto a los mismos hooks.

Cuatro ficheros. Los dos que más deciden el resultado:

**`specs/<capability>/spec.md`** — el contrato. Un escenario por criterio de aceptación:

```markdown
# Delta for <Capability>

## ADDED Requirements

### Requirement: Filtering by state
The system MUST allow an authenticated user to filter their own <resources> by state, using an
optional parameter. The system MUST reject any value outside the supported state set.

#### Scenario: Filter by a valid state
- GIVEN an authenticated user owning 12 <resources>, 5 of them in state "pending"
- WHEN the user requests the list filtered by state "pending"
- THEN the response is successful
- AND it contains exactly 5 items
- AND every returned item is in state "pending"

#### Scenario: Isolation between users
- GIVEN another user owns <resources> in state "pending"
- WHEN the authenticated user filters by "pending"
- THEN the response contains no <resource> belonging to another user

## MODIFIED Requirements

### Requirement: Listing
The system SHALL return the authenticated user's <resources> paginated with a fixed page size.
(Previously: returned every item without pagination and without filtering.)
```

**`design.md`** — donde se impide que el agente improvise:

```markdown
## Decisions
- El filtro es un parámetro opcional del listado existente, no un endpoint nuevo: así se combina
  con futuros filtros sin multiplicar puntos de entrada.
- El conjunto de estados válidos se modela como un tipo del dominio y es la única fuente de verdad:
  la validación y la persistencia derivan de él, no al revés.
- La validación ocurre en la capa de validación, no en la de negocio: un valor inválido no debe
  llegar nunca a la lógica.
- El filtro se expresa como una consulta reutilizable de la entidad, no como una condición suelta
  dentro del servicio.
- El aislamiento por usuario se aplica SIEMPRE y ANTES que el filtro opcional.
- La respuesta se pagina con tamaño fijo. El cliente todavía no lo controla.

## Risks / Trade-offs
- Sin índice sobre (usuario, estado) la consulta recorre la tabla. Aceptable con el volumen actual;
  queda registrado como deuda.

## Open Questions
- ¿Habrá un estado "archivado" o será un indicador aparte? Pendiente de Producto. No bloquea.
```

**Lo que hace `design.md` que no hace la especificación:** la especificación dice *qué*; el diseño
cierra el *cómo* para que no lo decida el agente a mitad de la implementación. Sin la línea sobre el
aislamiento, un agente razonable podría aplicar el filtro primero y la propiedad después: pasaría
cuatro de los cinco escenarios y filtraría datos ajenos en producción.

**`tasks.md`** — y aquí es donde el kit no te deja improvisar. `docs/openspec-tasks-mandatory-steps.md`
exige que el paso 0 cree la rama, que los pasos de verificación estén presentes y etiquetados, y que
toda tarea que mute datos incluya su restauración:

```markdown
## 0. Setup: Create Feature Branch (MANDATORY - FIRST STEP)
- [ ] 0.1 Create feature branch `feature/<change-name>` from the base branch
- [ ] 0.2 Verify branch creation and current branch status

## 1. Backend: Validation Tests (TDD)
- [ ] 1.1 Failing test for the unrecognised state scenario
- [ ] 1.2 Minimum implementation to pass it

## 2-5. Backend: <the change's own work>

## 6. Backend: Review and Update Existing Tests (MANDATORY)
- [ ] 6.1 Identify tests affected by the new pagination

## 7. Backend: Run Tests and Verify Data State (MANDATORY)
- [ ] 7.1 Capture pre-test baseline for the impacted entities
- [ ] 7.2 Run targeted tests, then the required suite
- [ ] 7.3 Verify post-test state and restore if needed
- [ ] 7.4 Create the report under `openspec/changes/<id>/reports/`

## 8. Backend: Manual Interface Testing (MANDATORY - AGENT MUST EXECUTE)
- [ ] 8.1 Exercise the success path and verify the response
- [ ] 8.2 Exercise the error cases
- [ ] 8.3 Restore any mutated state

## 10. Update Technical Documentation (MANDATORY)
- [ ] 10.1 Regenerate the API specification
```

Si el agente escribe un `tasks.md` sin el paso 0, sin la etiqueta `(MANDATORY)`, sin el
`AGENT MUST EXECUTE` o sin restauración de estado, el hook `validate-tasks` **lo rechaza en el
momento de escribirlo** y le dice exactamente qué falta. La doctrina deja de ser una
recomendación.

**Gate humano.** Abrir los cuatro ficheros y editarlos. El subagente `spec-auditor` o el prompt P6 te
dicen dónde mirar —incluida la conformidad del `tasks.md`—; la decisión es tuya.

---

## F4 · De contrato a código

`/openspec-implement <id>` recorre las tasks. Lo que ocurre en cada una:

### Rojo

```
Test escrito. Ejecutado. Falla:
  Error: la función de filtrado no existe
```

Que falle **por el motivo correcto** importa: si fallara por un error de sintaxis en el propio test,
no estarías midiendo nada.

### Verde

El agente implementa recorriendo `LAYER_ORDER`, y solo lo necesario. Aquí es donde los hooks
trabajan sin que nadie los invoque:

| Momento | Hook | Qué pasó |
|---|---|---|
| El agente intenta editar el test para «arreglar» un fallo | `protect-specs-and-tests` | Pide confirmación explícita. El humano dice que no; el agente vuelve al código |
| El agente intenta «mejorar» el delta spec para que encaje con lo implementado, sin que el diseño haya cambiado | `protect-specs-and-tests` | Pide confirmación explicando el caso legítimo (regla 7) frente al ilegítimo. El humano dice que no; el agente vuelve al código en vez de reescribir la spec |
| El agente escribe en la capa de negocio importando el transporte | `post-edit-quality` | Devuelve el control con la violación de capas. Se corrige antes de seguir |
| El agente escribe un comentario en español | `post-edit-quality` | Aviso, no bloqueo: `base-standards.md` §2 exige inglés en todo artefacto técnico |
| El agente propone instalar una librería de utilidades | `block-dangerous-bash` | Pide confirmación. El humano comprueba el registro y decide |
| El agente da el turno por cerrado con un test en rojo | `verify-tests` | Bloquea el cierre con la salida de la suite |

Ninguna de esas seis cosas está en ningún prompt. Están en código, y por eso pasan siempre.

### La pieza que decide el resultado

De todo lo implementado, esta es la que hay que mirar en la revisión:

```
listar(sujeto, filtro_opcional, página):
    consulta(<recurso>)
      .deSuPropiedad(sujeto)        ← siempre, y primero
      .conEstado(filtro_opcional)   ← opcional; si viene vacío, no altera la consulta
      .ordenar(...)
      .paginar(tamaño_fijo, página)
```

El orden no es estético. Invertirlo hace que el escenario de aislamiento pase igual en los tests
—porque el filtro también restringe— y falle en producción en cuanto alguien consulte sin filtro.

### Refactor

Con la suite en verde, `/tdd-refactor` sobre el service. Aquí devolvió algo útil y algo que conviene
leer con atención:

```
Candidatos, por valor:
1. El filtro y el aislamiento están en el mismo método, y el nombre no dice que haga las dos cosas.
   → extraer el scope de propiedad, que ya existe en el modelo y no se estaba usando.
2. El tamaño de página está como número literal en dos sitios.
   → una constante, que además es lo que el ADR va a citar.

Deliberadamente sin tocar:
- La longitud del método: 18 líneas no es un problema. Tiene una sola razón para cambiar.
```

Y el límite que hace que la fase sea segura: **no tocó ningún test**. Si un refactor necesita cambiar
un test, el comportamiento cambió y no era un refactor. El subagente `tdd-refactorer` se detiene y lo
reporta en vez de ajustar la aserción.

### Triangulación

P10 detecta que el agente devolvió un valor fijo en la primera task, escribe el segundo test que le
obliga a generalizar, y ejecuta el ejercicio de romper la implementación a propósito: si al invertir
la condición del filtro no se pone ningún test en rojo, ese test sobra.

---

## F5 · Verificación

Tres pasos distintos, y se suelen confundir. El primero es el que casi nadie hace.

### Demostrar que funciona — `/show-spec-working`

Esto es lo que el harness marca como **AGENT MUST EXECUTE**, y es trabajo, no documentación: el
agente arranca el servicio, ejerce cada escenario contra el sistema real, y entrega evidencia.

```
## Demostrado
| Escenario | Interacción | Resultado | Coincide |
|---|---|---|---|
| Filter by a valid state | GET listado?estado=pendiente | 200, 5 elementos | sí |
| Listing without filter  | GET listado                  | 200, 12 elementos | sí |
| Unrecognised state      | GET listado?estado=xxx       | 422 + valores admitidos | sí |
| Isolation between users | GET como usuario B           | 0 elementos ajenos | sí |
| Unauthenticated request | GET sin credenciales         | 401 | sí |

## Estado
- Antes: 12 registros del usuario A, 3 del usuario B
- Después: 12 y 3
- Restaurado: no hizo falta, todas las interacciones son de lectura
```

Y el informe queda en `openspec/changes/<id>/reports/`, uno de los pocos sitios bajo `openspec/` donde
escribir nunca dispara ni una pregunta —crear artefactos nuevos tampoco la dispara; lo que sí la
dispara es reescribir uno que ya existía—. Si el escenario hubiera mutado datos, el informe
tendría que documentar la restauración: crear, comprobar, borrar, y verificar que el recuento vuelve
a ser el de antes.

**La diferencia con los tests:** los tests pasaron hace veinte minutos en un entorno de test aislado.
Esto demuestra que funciona en el sistema que arrancas tú, con la configuración real. No es
redundante: es la primera vez que alguien lo ejecuta de verdad.

### Comprobar conformidad — `/verify-against-spec`

Devuelve tres bloques. El tercero es el que sorprende:

```
3. COMPORTAMIENTOS NO ESPECIFICADOS
   - El listado ahora ordena por fecha descendente. La especificación no menciona ordenación.
     (<PATH_BUSINESS>/<recurso>_service:31)
```

Es alcance inventado. Dos salidas legítimas: quitarlo, o añadirlo a la especificación porque
efectivamente lo queríamos. **La que no vale es dejarlo sin decidir**: es exactamente el hueco por
donde entra el comportamiento que nadie revisó.

Ojo con el atajo que aquí es tentador: si decides que sí lo querías, la regla 7 de
`base-standards.md` exige actualizar **primero** los artefactos del change y solo después el código.
Un arreglo que llega entre `apply` y `archive` no es «cámbialo rápido»: es una actualización de la
especificación.

### Refutar — `/adversarial-review`

En una sesión distinta de la que implementó, porque un agente revisando su propio trabajo hereda sus
propios puntos ciegos. Su trabajo es refutar, no aprobar:

```
### Findings
| Severidad | Fichero:línea | Hallazgo |
|---|---|---|
| Major | <service>:24 | El escenario de aislamiento pasaría igual si el filtro se aplicara antes
                       que la propiedad. El test no distingue los dos órdenes |
| Minor | <test>:88   | El test de aislamiento no comprueba el caso sin filtro, que es donde el
                       orden invertido fallaría |

### Verdict
PASS WITH GAPS — sin bloqueantes, pero el hueco del test de aislamiento debe cerrarse
```

Ese hallazgo es el valor de la revisión hostil: el test verde no demuestra lo que creías que
demostraba. Un revisor amable no lo habría dicho.

### Seguridad

El subagente `security-reviewer` sobre el diff: sin hallazgos de severidad alta, un aviso medio por
la falta de índice que ya estaba registrada como deuda en `design.md`.

---

## F6 · Documentación

`/adr-new` aplica primero el criterio de necesidad, y en este caso responde que **sí** procede:
un developer nuevo se preguntaría por qué el tamaño de página es fijo y no configurable, afecta al
contrato con el cliente, y revertirlo después de que haya integraciones cuesta más de un día.

El ADR resultante transcribe lo que ya estaba en `design.md`. No añade razonamiento nuevo: si el
«por qué» no estaba en el diseño, es que el diseño estaba incompleto.

---

## F7 · Entrega

`/commit` comprueba primero el gate de documentación, propone dos commits atómicos en lugar de uno
—la implementación y la documentación por separado— y, cuando el diff toca el contrato de API, el hook
`docs-gate` lo confirma otra vez antes de dejar pasar el commit. Dos capas para la misma garantía, a
propósito: la skill se puede olvidar de invocar, el hook no. `/pr-describe` genera todo menos el «por qué», que llega marcado:

```markdown
## ¿Qué cambia?
Añade un filtro opcional por estado al listado, con validación contra el conjunto de estados del
dominio, y pagina la respuesta con tamaño fijo. Sin el parámetro, el comportamiento es el de antes.

## ¿Por qué?
<!-- lo completa el humano -->

## ¿Cómo probarlo?
1. <comando de migración y arranque>
2. <petición con filtro válido> → solo los pendientes
3. <petición con filtro inválido> → error de validación con los estados admitidos
4. <comando de test filtrado> → 5 tests en verde

## Trazabilidad
| Escenario | Test |
|---|---|
| Filter by a valid state | <ruta>:34 |
| Listing without filter | <ruta>:52 |
| Unrecognised state | <ruta>:65 |
| Isolation between users | <ruta>:84 |
| Unauthenticated request | <ruta>:101 |

## Origen
agent+human-review
```

El humano rellena el porqué: *«La vista de pendientes descargaba el listado completo y filtraba en
memoria. Con más de 50 elementos degradaba la carga inicial y transfería datos que nunca se
muestran.»*

Eso no lo genera un modelo. No está en el diff.

---

## F8 · Cierre

Archivar el cambio, borrar la rama, y la retro de P15 sobre los datos del ciclo. En este caso
apareció una task no prevista —el segundo test de triangulación— y la conclusión fue accionable:
añadir a `docs/backend-standards.md` la regla de que toda task de implementación lleva su
triangulación desde el
principio.

Ese es el bucle completo: el proceso se corrige a sí mismo con lo que aprende de cada ciclo.

---

## Qué llevarse

| Momento | Coste de saltárselo |
|---|---|
| Recortar el alcance inventado en F1 | Una story S se convierte en L, y nadie sabe por qué |
| Escribir las decisiones en `design.md` | El agente decide por ti a mitad de la implementación, sin dejar rastro |
| Ver el test fallar | Un test que nace en verde no prueba nada |
| Ejecutar la demostración de F5 | Los tests pasan y la feature no funciona en el entorno real |
| Leer el bloque 3 de la verificación | Comportamiento en producción que nadie especificó ni revisó |
| Lanzar la revisión hostil en otra sesión | Los puntos ciegos del implementador sobreviven al review |
| Escribir el «por qué» del PR | Nadie recordará dentro de seis meses por qué se hizo así |

Los hooks se ocupan de lo mecánico. Los cinco gates son tuyos, y son la razón de que el resto
funcione.

---

## Y si el flujo te pide cambiar el kit

Ocurre, y es buena señal: significa que el proceso está aprendiendo. La retro de F8 produjo aquí una
regla nueva. Dónde va cada cosa:

| Lo que aprendiste | Dónde se escribe |
|---|---|
| Un hecho de este proyecto | `docs/project-context.md` |
| Una convención de arquitectura | `docs/backend-standards.md` |
| Un procedimiento que repites en el chat | Una skill nueva en `ai-specs/skills/`, con `/writing-skills` |
| Un invariante que no puede fallar | Un hook en `.claude/hooks/` |
| Un comando o una ruta que cambió | `.claude/sdd-harness.env` |

Y siempre en `ai-specs/`, no en `.claude/skills/`: son el mismo fichero solo si tu sistema permite
symlinks. Después, `bash .claude/sync-artifacts.sh` para propagar. La skill
`/sync-agent-artifacts` diagnostica el estado si algo dejó de resolver.
