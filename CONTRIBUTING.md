# Contribuir a `sdd-harness-kit`

Gracias por contribuir. Este repositorio usa un flujo simple para mantener calidad y trazabilidad.

## Flujo de trabajo

- Crea una rama desde `main` para cada cambio:
  - `feat/<descripcion-corta>`
  - `fix/<descripcion-corta>`
  - `docs/<descripcion-corta>`
- Evita hacer `push` directo a `main`.
- Abre un Pull Request (PR) para integrar cualquier cambio.

## Reglas para Pull Requests

- Usa la plantilla de PR en `.github/pull_request_template.md`.
- Completa siempre:
  - qué cambia
  - por qué
  - cómo probarlo
  - trazabilidad
- Mantén PRs pequeños y enfocados (idealmente un objetivo por PR).
- Si el cambio es grande, divídelo en varios PRs.

## Revisión y merge

- Solicita al menos una revisión antes de hacer merge.
- Revisa que la descripción y pasos de prueba sean claros y ejecutables.
- Prefiere **Squash and merge** para mantener el historial limpio.

## Convenciones de contenido

- Idioma principal: español.
- Prioriza cambios didácticos concretos y accionables.
- Evita introducir tooling de build o frameworks no solicitados.

## Commits

- Mensajes claros y específicos.
- Un commit debe representar un cambio coherente.
- Evita mezclar refactor, docs y cambios funcionales en el mismo commit cuando no sea necesario.
