# Contribuir a `sdd-harness-kit`

**Idioma:** Español · [English](CONTRIBUTING.en.md)

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

## Añadir un adaptador de stack

[CONFIG.md](CONFIG.md) explica los cuatro ficheros del adaptador. Esta es la lista de **todo** lo demás
que hay que tocar para que quede completo — existe porque el adaptador `fastify` se quedó a
medias la primera vez:

1. `adapters/<stack>.env` — obligatorio. Las 24 variables del contrato de `_template.env`.
2. `adapters/<stack>.backend-standards.md` — las cinco preguntas de [CONFIG.md](CONFIG.md), con rutas reales.
3. `adapters/<stack>.rules.mdc` y `adapters/<stack>.ci.yml` — opcionales, pero los demás
   adaptadores los traen.
4. Configuración extra del stack, si la necesita: `<stack>.infection.json`,
   `<stack>.dependency-cruiser.js`. Requiere su bloque de copia en **los dos** instaladores.
5. `detect_stack()` en `install.sh` **y** el bloque equivalente en `install.ps1`.
6. La ayuda del parámetro `-Stack` en la cabecera de `install.ps1`, y la de `--stack` en la
   de `install.sh`.
7. La tabla de adaptadores del [README.md](README.md).
8. `VERSION` y [CHANGELOG.md](CHANGELOG.md) **y** [CHANGELOG.en.md](CHANGELOG.en.md) (misma entrada en ambos).

Y pruébalo de verdad, con los cuatro comandos de la sección «Pruébalo» de [CONFIG.md](CONFIG.md). Un
adaptador que no se ha instalado nunca en un repositorio de prueba no está terminado.

## Revisión y merge

- Solicita al menos una revisión antes de hacer merge.
- Revisa que la descripción y pasos de prueba sean claros y ejecutables.
- Prefiere **Squash and merge** para mantener el historial limpio.

## Convenciones de contenido

- Documentación humana de la raíz: **bilingüe y emparejada** (español + inglés). Un PR de docs
  actualiza las dos lenguas en el mismo cambio.
- Código, skills, agents, standards y plantillas que lee el agente: **inglés**.
- Prioriza cambios didácticos concretos y accionables.
- Evita introducir tooling de build o frameworks no solicitados.

## Commits

- Mensajes claros y específicos.
- Un commit debe representar un cambio coherente.
- Evita mezclar refactor, docs y cambios funcionales en el mismo commit cuando no sea necesario.
