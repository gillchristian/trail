// Smoke test for Planning.sectionsForRace — drives the REAL compiled Elm
// function from Node through a Platform.worker harness
// (src/SectionsHarness.elm). Proves that kms partition cleanly across
// sections: a km whose window straddles an aid-station distance is counted
// in exactly ONE section, so per-km gain/loss and the seconds callers sum
// over `kmIndices` never double-count it. (Regression guard for TASK-039.)
//
// Run with: node scripts/smoke-sections.mjs

import { execFileSync } from 'node:child_process'
import { readFileSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')

// 1. Compile the harness with the project's elm toolchain.
const tmp = mkdtempSync(join(tmpdir(), 'sections-'))
const out = join(tmp, 'harness.js')
try {
  execFileSync('npx', ['--no-install', 'elm', 'make', 'src/SectionsHarness.elm', '--output', out], {
    cwd: repoRoot,
    stdio: ['ignore', 'ignore', 'inherit'],
  })
} catch (e) {
  console.error('elm make failed for the harness')
  process.exit(1)
}

// 2. Evaluate the Elm IIFE, capturing `this.Elm` into a scope object.
const code = readFileSync(out, 'utf8')
const scope = {}
new Function(code).call(scope)
rmSync(tmp, { recursive: true, force: true })
const Elm = scope.Elm
const app = Elm.SectionsHarness.init()

// 3. Promise wrapper over the run/result port pair (one in flight at a time).
let resolveNext = null
app.ports.result.subscribe((r) => {
  const f = resolveNext
  resolveNext = null
  if (f) f(r)
})
const call = (req) => new Promise((res) => { resolveNext = res; app.ports.run.send(req) })

// ---- assertion helpers ----
let failures = 0
const check = (label, cond, detail) => {
  if (cond) console.log(`  ok   ${label}`)
  else { failures++; console.log(`  FAIL ${label}${detail ? ' — ' + detail : ''}`) }
}
const eqJson = (a, b) => JSON.stringify(a) === JSON.stringify(b)
const sum = (xs) => xs.reduce((a, b) => a + b, 0)

// n flat-and-sorted km indices across all sections must be exactly [0..n-1]:
// every km in exactly one section (no duplicate = no double-count, none dropped).
const partitions = (sections, n) => {
  const flat = sections.flatMap((s) => s.kmIndices)
  const sorted = [...flat].sort((a, b) => a - b)
  return flat.length === n && sorted.every((v, i) => v === i)
}

// A flat 5 km course (each km 1000 m wide). gain/loss per km are caller-set.
const course = (gain, loss) =>
  [0, 1, 2, 3, 4].map((i) => ({ index: i, distStart: i * 1000, distEnd: (i + 1) * 1000, gain, loss }))
const TOTAL = 5000

const run = async () => {
  // --- A: the bug — aids strictly inside km2 and km3 (straddles) ---
  {
    // Aid at 1700 straddles km1 [1000,2000]; aid at 3300 straddles km3 [3000,4000].
    const { sections } = await call({ totalDistance: TOTAL, kms: course(100, 0), aids: [1700, 3300] })
    console.log('A: straddling aids (the double-count bug)')
    check('3 sections', sections.length === 3, `got ${sections.length}`)
    check('clean partition of all 5 kms', partitions(sections, 5), JSON.stringify(sections.map((s) => s.kmIndices)))
    check('km assignment [[0,1],[2],[3,4]]', eqJson(sections.map((s) => s.kmIndices), [[0, 1], [2], [3, 4]]))
    check('Σ gain == 500 (not 700)', sum(sections.map((s) => s.gain)) === 500, String(sum(sections.map((s) => s.gain))))
    check('Σ loss == 0', sum(sections.map((s) => s.loss)) === 0)
    check('Σ section distance == total', sum(sections.map((s) => s.distance)) === TOTAL)
  }

  // --- B: aid exactly on a km boundary (no straddle) — behavior unchanged ---
  {
    const { sections } = await call({ totalDistance: TOTAL, kms: course(100, 0), aids: [2000] })
    console.log('B: aid on a km boundary (no straddle)')
    check('2 sections', sections.length === 2, `got ${sections.length}`)
    check('clean partition', partitions(sections, 5))
    check('km assignment [[0,1],[2,3,4]]', eqJson(sections.map((s) => s.kmIndices), [[0, 1], [2, 3, 4]]))
    check('Σ gain == 500', sum(sections.map((s) => s.gain)) === 500)
  }

  // --- C: no aid stations — one section, the whole course ---
  {
    const { sections } = await call({ totalDistance: TOTAL, kms: course(100, 0), aids: [] })
    console.log('C: no aid stations')
    check('1 section', sections.length === 1, `got ${sections.length}`)
    check('all kms in it', eqJson(sections[0].kmIndices, [0, 1, 2, 3, 4]))
    check('gain == 500', sections[0].gain === 500)
  }

  // --- D: two straddles + loss — conservation holds for both fields ---
  {
    // Aid 1400 straddles km1; aid 3600 straddles km3. Each km: gain 50, loss 80.
    const { sections } = await call({ totalDistance: TOTAL, kms: course(50, 80), aids: [1400, 3600] })
    console.log('D: straddles with gain AND loss')
    check('3 sections', sections.length === 3, `got ${sections.length}`)
    check('clean partition', partitions(sections, 5))
    check('km assignment [[0],[1,2,3],[4]]', eqJson(sections.map((s) => s.kmIndices), [[0], [1, 2, 3], [4]]))
    check('Σ gain == 250 (not double-counted)', sum(sections.map((s) => s.gain)) === 250, String(sum(sections.map((s) => s.gain))))
    check('Σ loss == 400 (not double-counted)', sum(sections.map((s) => s.loss)) === 400, String(sum(sections.map((s) => s.loss))))
  }

  // --- E: aid-REST attribution + conservation (the TASK-045 clock fix) ---
  {
    // Same straddles as A (km map [[0,1],[2],[3,4]]), now with rest times.
    // Aid 1700 is in the 2nd half of km1 (mid 1500 < 1700) → km1 → section 0,
    // the section ENDING at it (here == followedByAid). Aid 3300 is in the 1st
    // half of km3 (mid 3500 ≥ 3300) → km3 → section 2, the section AFTER it —
    // NOT section 1, which it "follows". So its rest lands in section 2.
    // (followedByAid would have wrongly charged section 1 — the bug we avoid.)
    const { sections } = await call({
      totalDistance: TOTAL, kms: course(100, 0), aids: [1700, 3300], rests: [300, 600],
    })
    console.log('E: aid-rest attribution (clock time) + conservation')
    check('km map still [[0,1],[2],[3,4]]', eqJson(sections.map((s) => s.kmIndices), [[0, 1], [2], [3, 4]]))
    check('aidRest per section == [300, 0, 600]', eqJson(sections.map((s) => s.aidRest), [300, 0, 600]),
      JSON.stringify(sections.map((s) => s.aidRest)))
    check('Σ aidRest == 900 (== Σ rests; none dropped or double-counted)',
      sum(sections.map((s) => s.aidRest)) === 900, String(sum(sections.map((s) => s.aidRest))))
  }

  // --- F: aids but no rest times → every section's aidRest defaults to 0 ---
  {
    const { sections } = await call({ totalDistance: TOTAL, kms: course(100, 0), aids: [2500] })
    console.log('F: aids but no rest times → aidRest all zero')
    check('aidRest == [0, 0]', eqJson(sections.map((s) => s.aidRest), [0, 0]), JSON.stringify(sections.map((s) => s.aidRest)))
  }

  console.log('')
  if (failures === 0) {
    console.log('PASS — all section-partition checks green')
    process.exit(0)
  } else {
    console.log(`FAIL — ${failures} check(s) failed`)
    process.exit(1)
  }
}

run()
