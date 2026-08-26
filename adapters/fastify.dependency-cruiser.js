/**
 * dependency-cruiser — regla de dependencias del monorepo hexagonal.
 *
 * Instalado por el SDD Harness Kit (adaptador `fastify`). Es la contrapartida en
 * CI de la guarda GUARD_HTTP_IN_BUSINESS del hook post-edit-quality: el hook
 * avisa al guardar un fichero, esto falla el build. Una es rápida y local, la
 * otra es la autoridad y no se puede saltar.
 *
 * Ajusta los nombres de paquete si tu monorepo no usa packages/<nombre>.
 */
module.exports = {
  forbidden: [
    {
      name: 'core-no-infra',
      comment:
        'packages/core es el dominio: define puertos y no conoce a quien los implementa. ' +
        'Si necesitas algo de un adaptador, lo que falta es un puerto.',
      severity: 'error',
      from: { path: '^packages/core' },
      to: { path: '^packages/(adapters|analyzers|api|cli|web)' },
    },
    {
      name: 'core-no-transport',
      comment:
        'packages/core no conoce el transporte: ni fastify, ni HTTP, ni códigos de estado. ' +
        'Lanza errores de dominio y deja que la capa HTTP los traduzca.',
      severity: 'error',
      from: { path: '^packages/core' },
      to: { dependencyTypes: ['npm', 'npm-dev'], path: '^(fastify|@fastify/|node:http)' },
    },
    {
      name: 'analyzers-are-siblings',
      comment:
        'Un analizador implementa AnalyzerPort y no sabe de los demás. Que el analizador de ' +
        'TypeScript no pueda importar del de PHP es lo que hace comprobable la independencia ' +
        'del lenguaje.',
      severity: 'error',
      from: { path: '^packages/analyzers/([^/]+)/' },
      to: { path: '^packages/analyzers/(?!$1)([^/]+)/' },
    },
    {
      name: 'api-no-sql',
      comment:
        'La capa HTTP valida, delega y serializa. El acceso a datos vive en store-postgres.',
      severity: 'error',
      from: { path: '^packages/api' },
      to: { dependencyTypes: ['npm'], path: '^(pg|postgres|drizzle-orm|knex)$' },
    },
    {
      name: 'no-circular',
      severity: 'error',
      from: {},
      to: { circular: true },
    },
    {
      name: 'no-orphans',
      severity: 'warn',
      from: { orphan: true, pathNot: ['\\.d\\.ts$', '(^|/)\\.[^/]+\\.(js|cjs|mjs|ts)$'] },
      to: {},
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    exclude: { path: '(^|/)(tests?|fixtures|seeds)/' },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: 'tsconfig.json' },
    reporterOptions: { text: { highlightFocused: true } },
  },
};
