# Instrucciones para GitHub Copilot

La fuente de verdad de comandos, convenciones y restricciones de este repositorio es `AGENTS.md`.
Los valores concretos del stack están en `.claude/sdd-harness.env`. Consúltalos antes de sugerir nada.

Reglas que aplican siempre:

- **TDD.** Propón el test antes que la implementación y no modifiques tests existentes.
- **Capas.** La lógica de negocio no vive en la capa de transporte ni en los ficheros de rutas. La
  capa de negocio no conoce HTTP.
- **Validación.** Toda entrada externa pasa por la capa de validación del proyecto.
- **Salida.** Nunca devuelvas una entidad de persistencia directamente: serializa explícitamente
  los campos que salen.
- **Dependencias.** No sugieras paquetes que no estén ya en el manifiesto sin advertirlo de forma
  explícita: casi uno de cada cinco paquetes que recomiendan los modelos no existe.
- **Secretos.** Nunca escribas credenciales en el código, ni siquiera de ejemplo.
