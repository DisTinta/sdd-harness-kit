/**
 * Accessibility smoke scaffold (axe-core + jsdom).
 *
 * This file is NOT part of Pest / PHPUnit / Vitest discovery.
 * The installer never overwrites it once it exists. The kit does not edit package.json.
 *
 * Wire the CI gate (`npm run test:a11y` in `.github/workflows/frontend.yml`):
 *   1. npm i -D axe-core jsdom
 *   2. Rename this file to `smoke.mjs`
 *   3. Add to package.json scripts:
 *        "test:a11y": "node tests/a11y/smoke.mjs"
 *   4. Replace FIXTURE_HTML with markup from a real Livewire / Blade view
 *      (or switch to Playwright + @axe-core/playwright against a running app).
 *
 * A green run on the kit placeholder is wiring, not coverage. Automated axe catches a
 * fraction of WCAG 2.2 AA — still do a keyboard pass on critical journeys.
 *
 * See docs/frontend-standards.md
 */
import { JSDOM } from 'jsdom'
import axe from 'axe-core'

const FIXTURE_HTML = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Kit placeholder — not your app</title>
  </head>
  <body>
    <main data-a11y-scaffold="replace-me">
      <h1>Kit placeholder — not your app</h1>
      <p>Replace FIXTURE_HTML with HTML from a real Livewire or Blade view.</p>
    </main>
  </body>
</html>
`

if (FIXTURE_HTML.includes('data-a11y-scaffold="replace-me"')) {
  console.warn(
    'WARNING: test:a11y is still scanning the kit placeholder, not your app. ' +
      'Replace FIXTURE_HTML — see docs/frontend-standards.md',
  )
}

const { window } = new JSDOM(FIXTURE_HTML, { pretendToBeVisual: true, url: 'http://localhost/' })
const results = await axe.run(window.document)

if (results.violations.length > 0) {
  console.error(JSON.stringify(results.violations, null, 2))
  process.exit(1)
}

console.log('axe-core: 0 violations')
