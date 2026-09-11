# Changelog

**Idioma:** Español · [English](../en/CHANGELOG.en.md)

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Versionado semántico: la versión viva está en [`VERSION`](../../VERSION).

> **Por qué existe este fichero.** El kit **reemplaza sus propios ficheros** de `docs/`,
> `ai-specs/` y `.claude/` cuando se actualiza un proyecto ya instalado. Quien actualiza
> necesita saber qué va a cambiar antes de ejecutar el instalador; sin este registro solo
> puede comparar a mano o confiar.

---

## [1.3.2]

### Eliminado

- El instalador ya no crea `GEMINI.md` ni `codex.md`. Solo deja `CLAUDE.md` y `AGENTS.md`
  apuntando a `docs/base-standards.md`.

### Cambiado

- La documentación humana del kit pasa a `docs/es/` y `docs/en/` (el `README.md` español
  sigue en la raíz).

---

## [1.3.1]

### Añadido

- Scaffold de accesibilidad por UI: `tests/a11y/smoke.example.tsx` (React) /
  `tests/a11y/smoke.example.mjs` (Livewire). El instalador lo copia solo si no existe; no edita
  `package.json`. Cómo cablear `test:a11y` (axe-core) está en `docs/frontend-standards.md`.

### Cambiado

- `frontend.yml` (React y Livewire): si no existe el script `test:a11y`, avisa y continúa en lugar
  de fallar. El filtro de paths incluye `tests/a11y/**`.

---

## [1.3.0]

### Añadido

- Skill `/migration-review`: auditoría read-only de migraciones (Expand-Contract, DROP/UNIQUE/ALTER,
  renames destructivos, rollback).
- Skill `/architecture-audit`: modo Fowler, DDD, fronteras hexagonales, SOLID/CUPID (sin implementar).
- Adaptador frontend **Livewire** (`livewire.frontend-standards.md` + `livewire.ci.yml`) a la par de
  React; flag `--frontend auto|react|livewire` / `-Frontend …`.
- Workflow `.github/workflows/frontend.yml` (React o Livewire según UI).
- Plantilla de referencia `mcp.with-figma.json` (Context7 + Playwright + Figma); el instalador no la
  aplica.
- Doctrina WCAG 2.2 AA, `test:a11y` y umbrales CWV en standards FE (React, Livewire, plantilla).
- Doctrina Expand-Contract en § Persistence de todos los backend-standards; pgvector en Fastify.

### Cambiado

- `frontend-planner` agnóstico a React/Livewire.
- `/dod-feature` exige `/migration-review` si cambia el schema.
- Inventario: **29 skills**.
- Filtro `business` de los `ci.yml` (Laravel, Adonis, Fastify) incluye `tests/**`, para
  re-lanzar mutación cuando cambian tests.

---

## [1.2.4]

### Cambiado

- El `ci.yml` de cada adaptador gatilla tests y mutación con `dorny/paths-filter@v4` dentro
  del job `quality`. `runtime` es una allowlist amplia (no solo `app/**`); `business` es
  `PATH_BUSINESS` más la config de Infection/Stryker, sin `tests/**`. Lint y estático siguen
  siempre. En Laravel, las PRs mutan solo el diff (`--git-diff-lines`); el push a `main`
  muta toda la capa.

---

## [1.2.3]

### Cambiado

- Las capturas de Playwright (y la evidencia binaria de demo) deben guardarse en
  `openspec/changes/<id>/reports/`, junto al informe markdown; no en la raíz del repo.
  `/show-spec-working` 1.1.0, `docs/base-standards.md`, pasos obligatorios de OpenSpec y la
  plantilla `report.md` lo exigen.

### Corregido

- El contexto dinámico de las skills usaba `cat … | grep`, que Claude Code rechaza («multiple
  operations») y aborta el skill sin pedir aprobación. Ahora es un solo `grep` sobre
  `.claude/sdd-harness.env`, con `Bash(grep *)` en `allowed-tools`. Afecta a
  `/privacy-ethics-check` y al resto de skills que inyectan la config del proyecto.

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
