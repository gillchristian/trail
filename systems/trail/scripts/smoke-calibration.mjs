// Smoke test for Calibration.fitVmh + fitFlatPace — drives the REAL compiled
// Elm functions from Node through a Platform.worker harness
// (src/CalibrationHarness.elm). Verifies both calibration fits:
//   - vmh:  gain-weighted realized climb rate over climb kms (gain >= 30 m),
//           the threshold cut, no/zero-time skip, no-data null. (TASK-043)
//   - flat: distance-weighted realized pace over runnable kms (|slope| < 0.04),
//           the slope-band cut, no/zero-time skip, no-data null. (TASK-044)
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
// a climb km (vmh): gain only. a runnable/graded km (flat): distance + slope.
const climbKm = (index, gain) => ({ index, gain })
const gradedKm = (index, distanceM, slope) => ({ index, distance: distanceM, slope })

const run = async () => {
  // ============ vmh fit (TASK-043) ============

  // --- A: one run, mixed climb kms; flat km (<30 m) excluded ---
  {
    const { vmh, flat } = await call([
      { kms: [climbKm(0, 100), climbKm(1, 50), climbKm(2, 10), climbKm(3, 300)], splits: [[0, 360], [1, 180], [3, 600]] },
    ])
    console.log('A: vmh — single run, gain-weighted')
    check('vmh fit present', vmh !== null)
    check('3 climb kms (flat km excluded)', vmh.climbKmCount === 3, String(vmh?.climbKmCount))
    check('totalGain 450', vmh.totalGain === 450, String(vmh?.totalGain))
    check('vmh ≈ 1421 (450 m / 1140 s)', Math.round(vmh.vmh) === 1421, String(vmh?.vmh))
    check('flat fit null (no km distance)', flat === null) // climbKm sets distance 0 → not runnable
  }

  // --- B: a climb km with no recorded split is skipped ---
  {
    const { vmh } = await call([{ kms: [climbKm(0, 100), climbKm(1, 200)], splits: [[0, 360]] }])
    console.log('B: vmh — km without a time skipped')
    check('1 climb km', vmh.climbKmCount === 1, String(vmh?.climbKmCount))
    check('vmh == 1000 (100 m / 360 s)', Math.round(vmh.vmh) === 1000, String(vmh?.vmh))
  }

  // --- C: no usable climb data → null ---
  {
    const flatOnly = await call([{ kms: [climbKm(0, 10), climbKm(1, 20)], splits: [[0, 360], [1, 180]] }])
    console.log('C: vmh — no climb kms / no runs → null')
    check('flat-gain-only run → null vmh', flatOnly.vmh === null)
    check('no runs → null vmh', (await call([])).vmh === null)
  }

  // --- D: two runs aggregate; runCount counts contributing runs ---
  {
    const { vmh } = await call([
      { kms: [climbKm(0, 180)], splits: [[0, 600]] },
      { kms: [climbKm(0, 360)], splits: [[0, 1200]] },
    ])
    console.log('D: vmh — multi-run aggregate')
    check('runCount 2', vmh.runCount === 2, String(vmh?.runCount))
    check('vmh == 1080 (540 m / 1800 s)', Math.round(vmh.vmh) === 1080, String(vmh?.vmh))
  }

  // --- E: a climb km with a zero time doesn't divide-by-zero ---
  {
    const { vmh } = await call([{ kms: [climbKm(0, 100), climbKm(1, 200)], splits: [[0, 0], [1, 720]] }])
    console.log('E: vmh — zero-time climb km skipped')
    check('1 climb km (zero-time skipped)', vmh.climbKmCount === 1, String(vmh?.climbKmCount))
    check('vmh == 1000 (200 m / 720 s)', Math.round(vmh.vmh) === 1000, String(vmh?.vmh))
  }

  // ============ flat-trail-pace fit (TASK-044) ============

  // --- F: runnable kms; steep km (|slope| >= 0.04) excluded ---
  {
    // km0 flat (1000 m, 360 s), km1 gentle +2% (1000 m, 400 s), km2 steep +6% (excluded),
    // km3 gentle -1% (800 m, 300 s). Σ dist 2800 m, Σ s 1060 → 1060 / 2.8 ≈ 379 s/km.
    const { flat } = await call([
      {
        kms: [gradedKm(0, 1000, 0), gradedKm(1, 1000, 0.02), gradedKm(2, 1000, 0.06), gradedKm(3, 800, -0.01)],
        splits: [[0, 360], [1, 400], [2, 600], [3, 300]],
      },
    ])
    console.log('F: flat — runnable kms, steep excluded')
    check('flat fit present', flat !== null)
    check('3 runnable kms (steep excluded)', flat.runnableKmCount === 3, String(flat?.runnableKmCount))
    check('totalDistanceM 2800', flat.totalDistanceM === 2800, String(flat?.totalDistanceM))
    check('pace ≈ 379 s/km (1060 s / 2.8 km)', flat.paceSecPerKm === 379, String(flat?.paceSecPerKm))
    check('runCount 1', flat.runCount === 1)
  }

  // --- G: exact-threshold slope is excluded (band is strict < 0.04) ---
  {
    const { flat } = await call([
      { kms: [gradedKm(0, 1000, 0.04), gradedKm(1, 1000, 0.0)], splits: [[0, 300], [1, 300]] },
    ])
    console.log('G: flat — slope == 0.04 excluded (strict band)')
    check('1 runnable km', flat.runnableKmCount === 1, String(flat?.runnableKmCount))
    check('pace 300 (1000 m / 300 s → 300 s/km)', flat.paceSecPerKm === 300, String(flat?.paceSecPerKm))
  }

  // --- H: no runnable data → null ---
  {
    const steepOnly = await call([{ kms: [gradedKm(0, 1000, 0.08), gradedKm(1, 1000, -0.09)], splits: [[0, 600], [1, 500]] }])
    console.log('H: flat — all-steep / no runnable → null')
    check('all-steep run → null flat', steepOnly.flat === null)
    check('no runs → null flat', (await call([])).flat === null)
  }

  // --- I: runnable km with zero time or zero distance is skipped ---
  {
    const { flat } = await call([
      { kms: [gradedKm(0, 1000, 0), gradedKm(1, 0, 0), gradedKm(2, 1000, 0.01)], splits: [[0, 0], [1, 300], [2, 480]] },
    ])
    console.log('I: flat — zero-time / zero-distance km skipped')
    // km0 zero time skipped; km1 zero distance skipped; only km2 (1000 m, 480 s) counts.
    check('1 runnable km', flat.runnableKmCount === 1, String(flat?.runnableKmCount))
    check('pace 480', flat.paceSecPerKm === 480, String(flat?.paceSecPerKm))
  }

  // --- J: both fits from one realistic run ---
  {
    const { vmh, flat } = await call([
      { kms: [climbKm(0, 300), gradedKm(1, 1000, 0.0), gradedKm(2, 1000, 0.02)], splits: [[0, 1200], [1, 360], [2, 400]] },
    ])
    console.log('J: both fits coexist')
    check('vmh from the climb km (300 m / 1200 s = 900)', Math.round(vmh.vmh) === 900, String(vmh?.vmh))
    check('flat from the runnable kms (760 s / 2 km = 380)', flat.paceSecPerKm === 380, String(flat?.paceSecPerKm))
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
