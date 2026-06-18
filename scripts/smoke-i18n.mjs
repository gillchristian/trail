// Smoke test for the i18n pure core (ADR-0014) — drives the REAL compiled Elm
// (src/I18nHarness.elm) from Node. TASK-058 covers the Language codec:
//   - toCode/fromCode round-trip for every constructor (en, es);
//   - the leaf decoder is strict — unknown codes fail (no silent default),
//     which is what lets WI-2's settingsDecoder own back-compat instead.
// Grows with TASK-059 (Settings back-compat) and TASK-060 (Format).
//
// Run with: node scripts/smoke-i18n.mjs

import { execFileSync } from 'node:child_process'
import { readFileSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')

const tmp = mkdtempSync(join(tmpdir(), 'i18n-'))
const out = join(tmp, 'harness.js')
try {
  execFileSync('npx', ['--no-install', 'elm', 'make', 'src/I18nHarness.elm', '--output', out], {
    cwd: repoRoot,
    stdio: ['ignore', 'ignore', 'inherit'],
  })
} catch (e) {
  console.error('elm make failed for the harness')
  process.exit(1)
}

const code = readFileSync(out, 'utf8')
const scope = {}
new Function(code).call(scope)
rmSync(tmp, { recursive: true, force: true })
const app = scope.Elm.I18nHarness.init()

let resolveNext = null
app.ports.result.subscribe((r) => { const f = resolveNext; resolveNext = null; if (f) f(r) })
const call = (req) => new Promise((res) => { resolveNext = res; app.ports.run.send(req) })

let failures = 0
const check = (label, cond, detail) => {
  if (cond) console.log(`  ok   ${label}`)
  else { failures++; console.log(`  FAIL ${label}${detail !== undefined ? ' — ' + detail : ''}`) }
}

const run = async () => {
  console.log('Language: codec round-trip for every constructor')
  {
    const en = await call({ op: 'decode', code: 'en' })
    check('"en" → English → "en"', en.ok === true && en.code === 'en', JSON.stringify(en))
    const es = await call({ op: 'decode', code: 'es' })
    check('"es" → Spanish → "es"', es.ok === true && es.code === 'es', JSON.stringify(es))
  }

  console.log('Language: leaf decoder is strict (unknown codes fail, no default)')
  {
    check('"de" fails', (await call({ op: 'decode', code: 'de' })).ok === false)
    check('"EN" fails (case-sensitive)', (await call({ op: 'decode', code: 'EN' })).ok === false)
    check('"" fails', (await call({ op: 'decode', code: '' })).ok === false)
    check('"english" fails', (await call({ op: 'decode', code: 'english' })).ok === false)
  }

  console.log('Settings: a stored record wins via per-field defaults (back-compat)')
  {
    check('{} (no language field) → English', (await call({ op: 'resolveSettings', raw: {}, browser: 'fr-FR' })).code === 'en')
    check('{language:"es"} → Spanish', (await call({ op: 'resolveSettings', raw: { language: 'es' }, browser: 'en-US' })).code === 'es')
    check('{language:"de"} (invalid) → English (oneOf fallback)', (await call({ op: 'resolveSettings', raw: { language: 'de' }, browser: 'es-AR' })).code === 'en')
  }

  console.log('Settings: first run (null) derives from the browser primary subtag')
  {
    check('null + "es-AR" → Spanish', (await call({ op: 'resolveSettings', raw: null, browser: 'es-AR' })).code === 'es')
    check('null + "es" → Spanish', (await call({ op: 'resolveSettings', raw: null, browser: 'es' })).code === 'es')
    check('null + "en-US" → English', (await call({ op: 'resolveSettings', raw: null, browser: 'en-US' })).code === 'en')
    check('null + "fr-FR" (unshipped) → English', (await call({ op: 'resolveSettings', raw: null, browser: 'fr-FR' })).code === 'en')
    check('null + "" → English', (await call({ op: 'resolveSettings', raw: null, browser: '' })).code === 'en')
  }

  console.log('Settings: encode → decode is identity')
  {
    for (const c of ['en', 'es']) {
      const enc = (await call({ op: 'encodeSettings', code: c })).encoded
      const back = await call({ op: 'resolveSettings', raw: enc, browser: 'xx' })
      check(`round-trip ${c}`, back.code === c, JSON.stringify({ enc, back }))
    }
  }

  console.log('')
  if (failures === 0) {
    console.log('PASS — Language codec + Settings resolution/codec hold')
    process.exit(0)
  } else {
    console.log(`FAIL — ${failures} check(s) failed`)
    process.exit(1)
  }
}

run()
