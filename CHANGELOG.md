# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Versionado semántico: la versión viva está en [`VERSION`](VERSION).

> **Por qué existe este fichero.** El kit **reemplaza sus propios ficheros** de `docs/`,
> `ai-specs/` y `.claude/` cuando se actualiza un proyecto ya instalado. Quien actualiza
> necesita saber qué va a cambiar antes de ejecutar el instalador; sin este registro solo
> puede comparar a mano o confiar.

---

## [1.2.2]

### Cambiado

- Norma de rama y commit: con ticket, la rama es `feature/<TICKET>-<slug>` y el mensaje
  `tipo(TICKET): descripción` (ej. `feat(KAN-184): add listing filter by state`). Sin ticket,
  el scope es la capability o la capa; el agente pregunta el id y no lo inventa. Doctrina en
  `docs/base-standards.md`; `/commit`, pasos obligatorios de OpenSpec, P14 y el manual alineados.

---

## [1.2.1]

### Corregido

- Tras `openspec init`, `sync-artifacts` marcaba las skills nativas `openspec-*` (las de `/opsx:*`)
  como huérfanas y salía con código 1. Un agente leía eso como “borra”. Ahora las etiqueta
  `KEEP`, no fallan el sync y el mensaje dice que no se borren. Un `ORPHAN` / `HUÉRFANO` de
  verdad (cualquier otro nombre) sigue siendo error. Misma lógica en `.sh` y `.ps1`;
  `/sync-agent-artifacts` y `/kit-health` alineados.

---

## [1.2.0]

### Añadido

- **Adaptador `fastify`** para proyectos Fastify sobre monorepo hexagonal con workspaces de
  npm: `fastify.env`, `fastify.backend-standards.md`, `fastify.rules.mdc`, `fastify.ci.yml`
  y `fastify.dependency-cruiser.js`.
  - La guarda `GUARD_HTTP_IN_BUSINESS` incluye la regla de dependencias del monorepo: si un
    fichero de la capa de negocio menciona un paquete de infraestructura, el hook
    `post-edit-quality` avisa al guardar.
  - `ci.yml` levanta PostgreSQL con pgvector como servicio y aplica y revierte las
    migraciones antes de los tests.
  - `.dependency-cruiser.js` es la contrapartida en CI de esa misma guarda. Los
    instaladores lo copian a la raíz del proyecto y respetan el fichero si ya existe.
- **Detección automática de `fastify`** en `install.sh` e `install.ps1`. Busca `"fastify"`
  en el `package.json` de la raíz **y** en los de `packages/*`, porque en un monorepo la
  dependencia no está en la raíz.
- **`LICENSE`** (MIT) y **`CREDITS.md`**, con la procedencia del kit declarada: los apuntes
  del Máster AI4Devs de LIDR Academy y las ideas tomadas de
  [`LIDR-academy/lidr-specboot`](https://github.com/LIDR-academy/lidr-specboot) (MIT). El
  `LICENSE` conserva el aviso de copyright de specboot, como exige su propia licencia.
- **Este `CHANGELOG.md`.**
- **Lista de comprobación en `CONTRIBUTING.md`** con los sitios que hay que tocar para que
  un adaptador nuevo quede completo. Se añade porque al escribir el de `fastify` quedó a
  medias: los cuatro ficheros del adaptador estaban, pero la ayuda de `install.ps1` seguía
  anunciando solo tres stacks.

### Corregido

- La ayuda del parámetro `-Stack` de `install.ps1` enumeraba `adonisjs, laravel o
  _template` y no mencionaba los adaptadores nuevos. Ahora remite además a
  `adapters/*.env` como lista real.
- El README decía que un adaptador se escribe rellenando «doce variables». El contrato de
  `_template.env` tiene **24**.
- La versión estaba escrita a la vez en `VERSION` y en el texto del README, así que cada
  publicación eran dos ediciones y dos oportunidades de desincronizarse. El README ya no
  la repite: apunta a `VERSION` y a este fichero.

---

## [1.1.0] y anteriores

Sin registro. Este changelog empieza en la 1.2.0; el historial previo está en los commits.
No se reconstruye aquí de memoria.
