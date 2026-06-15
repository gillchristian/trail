// Smoke test for Calibration.fitVmh — drives the REAL compiled Elm function
// from Node through a Platform.worker harness (src/CalibrationHarness.elm).
// Verifies the climb-rate fit: gain-weighted realized vmh over climb kms,
// the climb-gain threshold cut, skipping kms with no/zero recorded time, and
// the no-data case. (TASK-043 / ADR-0006.)
//
// Run with: node scripts/smoke-calibration.mjs

import { execFileSync } from 'node:child_process'
import { readFileSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')

// 1. Compile the harness with the project's elm toolchain.
const tmp = mkdtempSync(join(tmpdir(), 'calib-'))
const out = join(tmp, 'harness.js')
try {
  execFileSync('npx', ['--no-install', 'elm', 'make', 'src/CalibrationHarness.elm', '--output', out], {
    cwd: repoRoot,
    stdio: ['ignore', 'ignore', 'inherit'],
  })
} catch (e) {
  console.error('elm make failed for the harness')
  process.exit(1)
}

// 2. Evaluate the Elm IIFE, capturing `this.Elm`.
const code = readFileSync(out, 'utf8')
const scope = {}
new Function(code).call(scope)
rmSync(tmp, { recursive: true, force: true })
const app = scope.Elm.CalibrationHarness.init()

// 3. Promise wrapper over the run/result port pair.
let resolveNext = null
app.ports.result.subscribe((r) => {
  const f = resolveNext
  resolveNext = null
  if (f) f(r)
})
const call = (runs) => new Promise((res) => { resolveNext = res; app.ports.run.send({ runs }) })

// ---- assertion helpers ----
let failures = 0
const check = (label, cond, detail) => {
  if (cond) console.log(`  ok   ${label}`)
  else { failures++; console.log(`  FAIL ${label}${detail ? ' — ' + detail : ''}`) }
}
const km = (index, gain) => ({ index, gain })

const run = async () => {
  // --- A: one run, mixed kms; flat km (<30 m) excluded ---
  {
    // climb kms 0/1/3 (gain >=30) with times 360/180/600; km2 is flat (10 m).
    const { fit } = await call([
      { kms: [km(0, 100), km(1, 50), km(2, 10), km(3, 300)], splits: [[0, 360], [1, 180], [3, 600]] },
    ])
    console.log('A: single run, gain-weighted fit')
    check('fit present', fit !== null)
    check('3 climb kms (flat km excluded)', fit.climbKmCount === 3, String(fit?.climbKmCount))
    check('runCount 1', fit.runCount === 1)
    check('totalGain 450', fit.totalGain === 450, String(fit?.totalGain))
    check('totalSeconds 1140', fit.totalSeconds === 1140, String(fit?.totalSeconds))
    // 450 m over 1140 s = 450 * 3600 / 1140 ≈ 1421.05 m/h
    check('vmh ≈ 1421', Math.round(fit.vmh) === 1421, String(fit?.vmh))
  }

  // --- B: a climb km with no recorded split is skipped ---
  {
    const { fit } = await call([
      { kms: [km(0, 100), km(1, 200)], splits: [[0, 360]] }, // km1 has no split
    ])
    console.log('B: km without a recorded time is skipped')
    check('1 climb km', fit.climbKmCount === 1, String(fit?.climbKmCount))
    check('totalGain 100 (km1 ignored)', fit.totalGain === 100, String(fit?.totalGain))
    check('vmh == 1000 (100 m / 360 s)', Math.round(fit.vmh) === 1000, String(fit?.vmh))
  }

  // --- C: no usable climb data → null ---
  {
    const flatOnly = await call([{ kms: [km(0, 10), km(1, 20)], splits: [[0, 360], [1, 180]] }])
    console.log('C: no climb kms / no runs → null')
    check('flat-only run → null fit', flatOnly.fit === null)
    const empty = await call([])
    check('no runs → null fit', empty.fit === null)
  }

  // --- D: two runs aggregate; runCount counts contributing runs ---
  {
    const { fit } = await call([
      { kms: [km(0, 180)], splits: [[0, 600]] },
      { kms: [km(0, 360)], splits: [[0, 1200]] },
    ])
    console.log('D: multi-run aggregate')
    check('runCount 2', fit.runCount === 2, String(fit?.runCount))
    check('climbKmCount 2', fit.climbKmCount === 2)
    // (180+360) m over (600+1200) s = 540 * 3600 / 1800 = 1080 m/h
    check('vmh == 1080', Math.round(fit.vmh) === 1080, String(fit?.vmh))
  }

  // --- E: a climb km with a zero/absent time doesn't divide-by-zero ---
  {
    const { fit } = await call([
      { kms: [km(0, 100), km(1, 200)], splits: [[0, 0], [1, 720]] }, // km0 time 0 → skipped
    ])
    console.log('E: zero-time climb km skipped')
    check('1 climb km (zero-time skipped)', fit.climbKmCount === 1, String(fit?.climbKmCount))
    check('vmh == 1000 (200 m / 720 s)', Math.round(fit.vmh) === 1000, String(fit?.vmh))
  }

  console.log('')
  if (failures === 0) {
    console.log('PASS — all calibration checks green')
    process.exit(0)
  } else {
    console.log(`FAIL — ${failures} check(s) failed`)
    process.exit(1)
  }
}

run()
