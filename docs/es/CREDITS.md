# Origen y créditos

**Idioma:** Español · [English](../en/CREDITS.en.md)

## Punto de partida

Este kit nace de los **apuntes de las clases del Máster AI4Devs** de
[LIDR Academy](https://lidr.co), y toma como punto de partida el repositorio de referencia del
máster:

**[`LIDR-academy/lidr-specboot`](https://github.com/LIDR-academy/lidr-specboot)** — MIT,
Copyright (c) 2026 LIDR.co

### Qué se tomó de ahí

Ideas de arquitectura y convenciones de organización, no una copia del contenido:

- La disposición de `ai-specs/` con **skills** y **subagentes** como fuente canónica del
  repositorio, referenciada después desde las carpetas de cada copiloto.
- Los **estándares en `docs/`** como documento que el agente lee para no reinventar la
  arquitectura en cada tarea.
- Los **ficheros de memoria** por copiloto —`CLAUDE.md` y `AGENTS.md`— apuntando a una doctrina
  única en lugar de duplicarla.
- El enfoque general de **Spec-Driven Development** sobre OpenSpec.

Las skills, los subagentes, los estándares, las plantillas y los hooks de este kit están
escritos para él. Donde coincide una convención, coincide porque se adoptó a propósito.

### Qué añade este kit

| Añadido | Qué resuelve |
|---|---|
| **Instalable** `install.sh` / `install.ps1`, con `--dry-run` y detección de stack | Montar el harness en un proyecto nuevo sin repetir el trabajo a mano |
| **9 hooks deterministas** del ciclo de vida | Convertir una convención escrita en una comprobada. Actúan sobre la ruta del fichero, no sobre qué comando lo escribió |
| **29 skills y 9 subagentes** | La trilogía TDD con contexto aislado por fase, `/adversarial-review`, `/migration-review`, `/architecture-audit`, `/privacy-ethics-check`, `/show-spec-working`, `/kit-health` |
| **Adaptadores por stack** (`laravel`, `adonisjs`, `fastify`, `react`, `livewire`, plantilla) | El mismo harness en stacks distintos sin tocar una skill ni un hook |
| **Soporte real en Windows** | PowerShell de primera clase, y copia cuando el sistema no permite symlinks |
| **`doctor.sh` / `doctor.ps1`** | Diagnosticar una instalación en lugar de adivinar |
| **Gates de secretos en profundidad** | Bloqueo en el prompt y en la lectura de ficheros, no solo antes del commit |
| **Doctrina propia** en `docs/base-standards.md` y `docs/documentation-standards.md` | Los cinco puntos de parada humana y el gate de documentación |

## Herramientas de terceros

El kit no las incluye: las configura o las asume instaladas.

| Herramienta | Papel | Licencia |
|---|---|---|
| [OpenSpec](https://www.npmjs.com/package/@fission-ai/openspec) (`@fission-ai/openspec`) | Gobierna `openspec/`: specs y changes. Se instala aparte, a propósito | Ver el paquete |
| [Context7](https://context7.com) | MCP de documentación de librerías | Ver el proveedor |
| [Playwright MCP](https://github.com/microsoft/playwright) | Demostración de UI. No sustituye la suite E2E | Apache-2.0 |
| [Figma MCP](https://developers.figma.com/docs/figma-mcp-server/) | Diseño → contexto de código (plantilla `mcp.with-figma.json`, opcional) | Ver el proveedor |

## Licencia de este kit

[MIT](LICENSE). El fichero de licencia conserva el aviso de copyright de `lidr-specboot`,
como exige su propia licencia MIT.
