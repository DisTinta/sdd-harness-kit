# SDD Harness Kit — briefing para Producto

Documento interno para explicar el kit a perfiles no técnicos. No es una guía de instalación.

---

## En una frase

El **SDD Harness Kit** es un conjunto de reglas, plantillas y automatismos que instalamos en un proyecto para que la IA construya **exactamente lo que hemos acordado**, y no lo que se le ocurra por el camino.

No es un producto que el usuario final vea. Es la forma de trabajar del equipo de desarrollo cuando usa copilotos (Cursor, Claude Code, Copilot).

---

## El problema que resuelve

Hoy un ticket de tres frases llega al desarrollo y, si quien lo ejecuta es una IA, ocurre esto:

1. El ticket es ambiguo.
2. La IA rellena los huecos **inventando** (alcance extra, casos no pedidos, arquitectura distinta).
3. Un humano revisa al final, cuando ya hay cientos de líneas de código.
4. Lo que se entrega puede “funcionar” y aun así no ser lo que Producto quería.

El coste de la ambigüedad se multiplica. Una historia pequeña se convierte en una grande sin que nadie lo haya decidido.

El kit ataca eso **antes** de escribir código: primero se cierra el contrato (qué sí, qué no, cómo se verifica), y después se construye contra ese contrato.

---

## Qué es Spec-Driven Development (SDD)

**Spec-Driven Development** significa: *primero acordamos el comportamiento, después escribimos el código*.

En la práctica:

| Antes (flujo habitual) | Con SDD |
|---|---|
| Ticket → código → “¿era esto?” | Ticket → **contrato** → código que demuestra el contrato |
| Los criterios viven en la cabeza o en un comentario de Jira | Los criterios son un documento que la IA y el humano leen igual |
| Si código y ticket no coinciden, gana el código (porque ya está hecho) | Si no coinciden, **gana la especificación**: se corrige el código o se actualiza el acuerdo, nunca se ignora |

La especificación no es un PDF de 40 páginas. Es el **cambio concreto** de esta unidad de trabajo: qué se añade, qué se modifica, qué queda fuera.

Analogía útil: es como un commit de Git, pero para requisitos. No reescribimos todo el producto; documentamos el *diff* de esta historia.

**Cuándo no hace falta todo este aparato:** prototipos, spikes de un par de horas, correcciones triviales. Especificar tiene un coste; se usa cuando el cambio merece un acuerdo.

---

## Qué es OpenSpec

**OpenSpec** es la herramienta que guarda esos acuerdos en el repositorio, junto al código.

Cada unidad de trabajo (un “change”) deja cuatro piezas:

| Pieza | En cristiano | Quién la usa |
|---|---|---|
| **Propuesta** (`proposal.md`) | El *porqué* de negocio y el alcance | Producto + desarrollo |
| **Especificación** (`spec.md`) | Requisitos y escenarios: “dado X, cuando Y, entonces Z” | Desarrollo, revisión, IA |
| **Diseño** (`design.md`) | Decisiones técnicas ya cerradas, para que la IA no improvise arquitectura | Desarrollo |
| **Tareas** (`tasks.md`) | Checklist accionable, una tarea = un paso | La IA las recorre; el humano las firma |

Cuando el cambio se mergea, se **archiva**. Así la siguiente propuesta sabe qué ya está hecho. Si se deja abierto, el contexto se pudre.

OpenSpec no sustituye a Jira ni a Producto. Traduce el ticket a un contrato que un copiloto puede ejecutar sin adivinar.

---

## Qué es el kit (y qué no es)

El kit es el **arnés** alrededor de OpenSpec y de los copilotos: la disciplina que hace que el proceso se cumpla de verdad, no solo en un documento de buenas prácticas.

Instalado una vez por proyecto, deja:

- Las mismas reglas para Cursor, Claude Code, Copilot y Gemini (una doctrina, varias herramientas).
- 27 “skills”: procedimientos reutilizables (`enriquecer la historia`, `implementar`, `verificar`, `abrir el PR`…).
- 9 subagentes: roles especializados (explorar, auditar la spec, escribir el test, revisar seguridad…).
- 9 **hooks**: reglas que no se interpretan, se **ejecutan**. Son el cinturón de seguridad.
- **MCP** (enchufes a herramientas externas): **Context7** (documentación actual de librerías) y **Playwright** (demostrar la interfaz real en el navegador).
- Plantillas, estándares del stack y un chequeo de salud (`doctor`).

**Qué no hace:**

- No sustituye el criterio de Producto ni el de ingeniería.
- No garantiza calidad mágica. Garantiza que ciertos errores **no pasen desapercibidos**.
- No conoce el dominio del producto. Eso vive en un fichero que escribimos nosotros (`project-context`). Lo que no esté ahí, la IA se lo inventará.
- No es un chatbot para el PO. El PO sigue hablando con el equipo; el kit es para quien implementa.

---

## Context7 y Playwright: cómo se informa la IA y cómo demuestra

Además de las reglas y los cinturones de seguridad, el kit deja conectados dos **enchufes** (en jerga: MCP, *Model Context Protocol*). No son un producto de usuario: son canales para que el copiloto consulte información viva o actúe sobre un navegador, en lugar de limitarse a generar texto.

No hace falta que alguien escriba “usa Context7” en cada conversación. Las reglas del proyecto ya dicen *cuándo* usarlos. Si un enchufe está apagado, el agente debe decirlo y seguir con lo que tenga; no inventar para compensar.

Jira, bases de datos u otros conectores con secretos **no** vienen en el kit: cada equipo los añade aparte, porque llevan credenciales.

### Context7 — documentación al día, no memoria de hace dos años

Una IA “sabe” de librerías y frameworks por lo que vio al entrenarse. Ese conocimiento **se queda viejo**: cambia un comando, un flag, una API, y el copiloto escribe código que ya no existe o que nunca existió.

**Context7** es una consulta a la documentación **actual** de la librería (React, Laravel, Fastify, el CLI de OpenSpec, el runner de tests…). El kit lo dispara cuando el código va a llamar a una API que **no está definida en nuestro repositorio**.

| Lo usa para… | No lo usa para… |
|---|---|
| “¿Cómo se llama ahora esta función de la librería X?” | Las reglas de negocio de *nuestro* producto |
| Flags, versiones y setup que cambian entre releases | El contexto del proyecto (`project-context`) |
| Evitar APIs inventadas o caducadas | Revisar nuestro propio código |

Analogía: no le preguntamos a un compañero cómo se usa Stripe “de memoria de 2022”; abrimos la doc de hoy. Context7 es esa consulta, automática.

**Qué gana Producto:** menos tiempo perdido en “compilaba en la cabeza del modelo y no en nuestro stack”, menos dependencias raras y menos PRs que hay que rehacer porque la librería ya no funciona así.

### Playwright — demostrar la pantalla de verdad, no describirla

En la fase de verificación el kit exige **evidencia**, no un resumen de lo que el código *parece* hacer. Si el cambio tiene una interfaz de navegador, **Playwright** abre un navegador aislado, navega, hace clic, rellena, captura el estado y cierra. Deja constancia de que el escenario se ejerció contra el sistema arrancado.

Va ligado a “demostrar que la spec funciona”: cada criterio “dado / cuando / entonces” se recorre de verdad. Si no hay frontend (solo API), se demuestra por HTTP o línea de comandos, y Playwright no hace falta; el instalador puede omitirlo.

| Lo usa para… | No lo usa para… |
|---|---|
| Demo de un flujo de UI acordado en la spec | Sustituir la batería de tests E2E del proyecto (eso sigue siendo el contrato de CI) |
| Evidencia: pantallazo / snapshot + resultado | Entrar en producción, capturar secretos o datos personales |
| Cubrir también los casos de error en pantalla | Saltarse el ciclo de test-primero (TDD) |

Analogía: no vale “he leído el código y debería verse el filtro”. Vale “he abierto la pantalla, he filtrado por pendiente y han salido exactamente 5”. Eso es lo que un PO reconocería como una demo, hecha por el agente y guardada como informe.

**Modo aislado:** el navegador no reutiliza la sesión del desarrollador (cookies, logins). Es una caja aparte, a propósito.

**Qué gana Producto:** la verificación deja de ser “tests verdes en un entorno de prueba” y pasa a incluir “lo he visto en la interfaz, con el sistema en marcha”. Sigue haciendo falta que un humano **lea** esa evidencia; Playwright no firma el “está bien”.

---

## El flujo de trabajo (de ticket a merge)

Pensadlo como un embudo: cada fase reduce ambigüedad. Hay **cinco puntos donde un humano tiene que decidir**; el resto puede ir más rápido con IA.

```
Ticket (Jira / Linear / lo que usemos)
        │
        ▼
1. PLANIFICAR     Historia clara + criterios + “qué NO entra”
        │         ◆ Producto / tech lead recorta alcance inventado
        ▼
2. ESPECIFICAR    Los 4 documentos OpenSpec (propuesta, spec, diseño, tareas)
        │         ◆ Humano abre, edita y firma el alcance
        ▼
3. PLAN DE CÓDIGO Cómo se va a hacer (sin escribir aún)
        │         ◆ Humano aprueba el plan
        ▼
4. IMPLEMENTAR    Tarea a tarea, con test primero
        │         Los automatismos vigilan (ver siguiente sección)
        ▼
5. VERIFICAR      ¿Hace lo acordado? ¿Hace de más? ¿Hay agujeros?
        │         ◆ Humano lee la evidencia, no solo “tests en verde”
        ▼
6. DOCUMENTAR     Solo lo que hace falta (decisiones difíciles de revertir)
        ▼
7. ENTREGAR       Commits + PR con qué / por qué / cómo probarlo
        │         ◆ Humano escribe el “por qué” y firma el merge
        ▼
8. CERRAR         Archivar el change + aprender para el siguiente
```

### Qué ve Producto en cada fase

**1. De ticket a historia ejecutable**  
La IA propone escenarios (casos límite, no autenticado, aislamiento entre usuarios…). Casi siempre mete de más: ordenación extra, paginación nueva, endpoints que nadie pidió. **El trabajo de más retorno es recortar.** Sin este recorte, una historia S llega a desarrollo como L.

**2. De historia a contrato**  
Queda por escrito: qué debe pasar, qué queda fuera (non-goals), y cómo se va a verificar. Producto no tiene que redactar YAML; sí tiene que decir “sí / no / esto no” sobre el alcance.

**3–4. Plan e implementación**  
Desarrollo. Producto no interviene salvo que aparezca una pregunta de alcance. Si hay que usar una librería que no está en nuestro código, **Context7** consulta la documentación actual para no inventar la API.

**5. Verificación (la que más se salta sin el kit)**  
No basta con “los tests pasan”. El agente **ejerce los escenarios contra el sistema real** y deja evidencia: en API, con peticiones reales; en pantalla, con **Playwright** recorriendo el navegador. Después se busca lo no pedido: comportamiento extra que nadie revisó. Una revisión “hostil” intenta **refutar** el trabajo, no felicitarlo.

**7. Pull request**  
La IA puede redactar el “qué cambia” y el “cómo probarlo”. **El “por qué” lo escribe una persona.** El merge lo firma una persona.

---

## Qué hace el kit automáticamente (sin que nadie lo pida)

Esto es lo que diferencia “tenemos un documento de proceso” de “el proceso se cumple”.

Los **hooks** son comprobaciones que saltan solas mientras el copiloto trabaja:

| Si el copiloto intenta… | El kit… |
|---|---|
| Pegar contraseñas, tokens o leer ficheros `.env` | Lo bloquea. Los secretos no entran en el chat |
| Borrar masivo, `push --force`, tocar producción | Lo bloquea o pide confirmación humana |
| Instalar una librería nueva | Pide confirmación (casi 1 de cada 5 paquetes que “recomienda” una IA no existe; hay ataques que registran esos nombres) |
| Reescribir tests o la especificación para que encajen con un atajo de código | Pregunta. Un humano decide si el diseño cambió de verdad |
| Mezclar capas (p. ej. lógica de negocio en el controlador HTTP) | Devuelve el control para corregirlo |
| Commitear un cambio de API o de esquema sin tocar la documentación | Lo impide |
| Escribir una lista de tareas incompleta (sin rama, sin verificación, sin restaurar datos) | La rechaza en el momento |
| Cerrar el turno con tests en rojo | No deja cerrar |

Además, al **abrir cada sesión**, inyecta solo: rama actual, cambios OpenSpec activos, tareas pendientes y comandos del proyecto. No hace falta “contarle el contexto” cada mañana.

Los enchufes MCP también entran solos cuando toca:

| Momento | Qué ocurre |
|---|---|
| Planear o implementar contra una librería externa | **Context7** trae la doc vigente; no se fía de la “memoria” del modelo |
| Demostrar un escenario de interfaz | **Playwright** abre un navegador aislado, recorre el flujo y deja evidencia |
| El enchufe está apagado o no hay frontend | Lo dice y continúa (HTTP/CLI). No inventa APIs ni finge una demo |

En el **pipeline de GitHub** (si se activa): revisión automática del PR con el mismo criterio del kit. **No sustituye la revisión humana**; es un primer pase.

Otras acciones que el equipo dispara con un comando, pero que el kit estandariza:

- Enriquecer la historia y marcar Definition of Done según el tipo (feature, bug, refactor, spike, docs).
- Implementar recorriendo las tareas, con test en rojo → código mínimo → refactor.
- Demostrar cada escenario contra el sistema arrancado, con informe (Playwright si hay UI).
- Contrastar código vs. especificación (lo que falta **y** lo que sobra).
- Revisión de seguridad, privacidad y ética.
- Commits atómicos y descripción de PR (el “por qué” queda vacío a propósito).

---

## Dónde sigue haciendo falta una persona

El kit automatiza lo mecánico. **Estos cinco no se delegan.** Si se saltan, el resto amplifica el error en lugar de salvaros.

1. **Historia y criterios** — No aceptar criterios de IA sin contrastarlos con el producto real. Recortar alcance inventado. Fijar qué no entra.
2. **Contrato** — Abrir y editar propuesta / spec / diseño / tareas. Firmar el alcance.
3. **Plan antes de ejecutar** — Si toca muchas piezas o tiene efectos colaterales: se aprueba el plan, luego se escribe código.
4. **Tests y evidencia** — El criterio de “terminado” es humano. Se lee la demostración real y los comportamientos no especificados.
5. **Merge** — El agente puede abrir el PR; una persona firma. El “por qué” no sale del diff.

Mensaje para Producto: no desaparecéis del ciclo. Os movéis **hacia atrás**, donde la decisión es barata (alcance, non-goals, “¿esto es lo que queríamos?”) en lugar de al final, cuando deshacer cuesta un sprint.

---

## Ventajas de trabajar así

### Para Producto

- **Menos “no era eso”.** El alcance se cierra por escrito, con escenarios y con *qué no entra*, antes de gastar días de implementación.
- **Estimaciones más honestas.** Una historia vaga la IA la infla. Una historia recortada se puede tallar de verdad. El material del kit recomienda buffer del 30–40 % (verificación, calidad, rotación de herramientas), no del 10 %.
- **Trazabilidad.** Cada escenario de la spec se liga a un test y al PR. Se puede responder: “¿esto que pedimos está cubierto?”.
- **Menos alcance fantasma.** La verificación busca comportamiento *de más*, no solo *de menos*. Eso es oro para no llevar a producción cosas que nadie pidió ni revisó.
- **PRs que se pueden probar.** “Qué / por qué / cómo probarlo” deja de ser opcional.

### Para el equipo y el negocio

- **La IA deja de ser un generador de código suelto** y pasa a ser un ejecutor de un contrato. Misma disciplina con Cursor, Claude o Copilot.
- **Menos retrabajo.** El error se pilla en la spec o en el plan, no en QA o en producción. Context7 evita rehacer trabajo porque “la librería ya no se usa así”.
- **Demos con evidencia, no con fe.** Playwright recorre la pantalla acordada; el informe se puede contrastar con los criterios de aceptación.
- **Seguridad por defecto.** Secretos, fuerza bruta en Git, dependencias inventadas y tests “arreglados” para poner verde: el kit los para. Playwright no se usa contra producción ni para capturar datos personales.
- **El proceso se cumple aunque nadie recuerde el documento.** Un convenio escrito se ignora; un hook no.
- **Aprendizaje de ciclo a ciclo.** Al archivar y hacer retro, lo que salió mal se convierte en regla del proyecto, no en anécdota.

### Lo que cambia en el día a día (ejemplo real del kit)

Ticket: *“Filtrar el listado por estado; el cliente descarga todo y filtra en memoria.”*

Sin el kit, un copiloto razonable podría añadir ordenación configurable, paginación nueva y un endpoint de recuento. Historia S → L.

Con el kit: la IA propone esos extra; **el humano los tira** en el primer gate; el contrato dice “solo filtro, no tocar el cliente, no índices en este ticket”; la implementación se verifica contra esos cinco escenarios (incluido aislamiento entre usuarios y no autenticado). El PR explica el porqué de negocio, que no está en el diff.

---

## Cómo hablarlo en una reunión (guion corto)

1. **No es una herramienta más para el usuario.** Es cómo el equipo usa IA sin perder el control del alcance.
2. **SDD:** primero el acuerdo, después el código. La spec gana al código.
3. **OpenSpec:** el sitio en el repo donde vive ese acuerdo (por qué, qué, cómo, checklist).
4. **El kit:** el arnés que hace que eso se cumpla: plantillas + roles + cinturones de seguridad automáticos.
5. **Dos enchufes:** Context7 (doc actual de librerías, para no inventar APIs) y Playwright (demo real en el navegador, no un “debería verse así”).
6. **Flujo:** ticket → recortar historia → firmar contrato → plan → implementar con tests → demostrar en el sistema real → PR → merge humano.
7. **Producto gana** si participa en recortar y en firmar el “qué no entra”. Si solo aparece en el demo, el kit no puede salvar un ticket vago.
8. **Honestidad:** no promete velocidad infinita ni cero bugs. Promete que no construimos a ciegas, y que ciertos fallos típicos de trabajar con IA no se cuelan.

---

## Preguntas que suelen salir

**¿Esto retrasa las entregas?**  
La especificación añade tiempo al principio y lo quita al final (menos idas y vueltas, menos PRs de 800 líneas). En tickets triviales no se usa el ciclo completo.

**¿Producto tiene que escribir la spec?**  
No. Producto aporta el problema, el valor y el recorte. Desarrollo (con IA) redacta el contrato. Producto o tech lead **valida** alcance y non-goals.

**¿Sustituye a Jira / el backlog?**  
No. El backlog sigue siendo la cola de trabajo. OpenSpec es el contrato de *esta* unidad cuando entra a implementación.

**¿Podemos seguir usando IA “en chat” para cosas pequeñas?**  
Sí. El kit está pensado para trabajo de historia (nivel “te asigno la tarea y reviso el PR”), no para cada autocompletado.

**¿Quién firma la calidad?**  
Sigue siendo el equipo. El kit hace visibles los atajos; no los perdona en silencio.

**¿Qué es eso de Context7?**  
Un enchufe para que la IA lea la documentación **actual** de librerías y frameworks, en lugar de fiarse de lo que “recuerda”. Evita código caducado o APIs inventadas. No conoce nuestro producto: para eso sigue existiendo el contexto del proyecto.

**¿Y Playwright? ¿Sustituye a QA?**  
No. Es un navegador que el agente usa para **demostrar** un flujo de pantalla acordado en la spec y dejar evidencia. La batería de tests de extremo a extremo del proyecto y la revisión humana siguen siendo el contrato. Si el producto no tiene interfaz web, Playwright ni siquiera se instala.

---

*SDD Harness Kit · material interno · AI4Devs · LIDR Academy*
