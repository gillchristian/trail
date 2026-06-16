// Smoke test for the WI-1 .trail identity/integrity layer — drives the REAL
// compiled Elm (src/TrailSyncHarness.elm) from Node through a Platform.worker
// harness. Proves:
//   - courseHash is deterministic, tolerant of cosmetic GPX differences
//     (whitespace + sub-1m precision + sub-1m elevation round to the same
//     fingerprint), and distinct for a genuinely different course;
//   - TrailSync.classify returns the right typed verdict (Mergeable /
//     DifferentRace / DifferentCourse), and an empty shareId never matches;
//   - ProjectFile.decode reads both v1 (no shareId/courseHash) and v2 docs and
//     still rejects an unknown version.
// (Foundation guard for the coach-collaboration arc, TASK-047 / ADR-0010.)
//
// Run with: node scripts/smoke-trailsync.mjs

import { execFileSync } from 'node:child_process'
import { readFileSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')

// 1. Compile the harness with the project's elm toolchain.
const tmp = mkdtempSync(join(tmpdir(), 'trailsync-'))
const out = join(tmp, 'harness.js')
try {
  execFileSync('npx', ['--no-install', 'elm', 'make', 'src/TrailSyncHarness.elm', '--output', out], {
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
const app = Elm.TrailSyncHarness.init()

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

// ---- GPX test vectors ----
// A 2-point track. The hash is over DECODED points (lat/lon rounded to 5 dp,
// ele to nearest m), so XML whitespace is irrelevant by construction.
const gpx = (pts) =>
  `<gpx><trk><name>Test</name><trkseg>` +
  pts.map((p) => `<trkpt lat="${p.lat}" lon="${p.lon}"><ele>${p.ele}</ele></trkpt>`).join('') +
  `</trkseg></trk></gpx>`

const courseA = gpx([
  { lat: '40.10000', lon: '-3.50000', ele: '100' },
  { lat: '40.20000', lon: '-3.60000', ele: '200' },
])
// Same course, cosmetically different: sub-1m precision (rounds equal) + ele
// fractions (round equal) + reformatted whitespace.
const courseACosmetic =
  `<gpx>\n  <trk>\n    <name>Renamed Export</name>\n    <trkseg>\n` +
  `      <trkpt lat="40.100002" lon="-3.499998">  <ele>100.4</ele>  </trkpt>\n` +
  `      <trkpt lat="40.200001" lon="-3.600000"><ele>199.6</ele></trkpt>\n` +
  `    </trkseg>\n  </trk>\n</gpx>\n`
// A genuinely different course (first point ~100 km north).
const courseDifferent = gpx([
  { lat: '41.10000', lon: '-3.50000', ele: '100' },
  { lat: '40.20000', lon: '-3.60000', ele: '200' },
])

// ---- .trail documents ----
const raceCore = {
  id: 'local-1', name: 'Demo Race', date: null, location: '', url: '',
  notes: '', coverImage: null, distance: 1000, gain: 100, loss: 50, createdAt: 123,
}
const trailV2 = JSON.stringify({
  format: 'trail-project', version: 2,
  race: { ...raceCore, shareId: 'share-xyz', courseHash: 'hash-abc' },
})
const trailV1 = JSON.stringify({
  format: 'trail-project', version: 1, race: raceCore, // no shareId / courseHash
})
const trailV3 = JSON.stringify({
  format: 'trail-project', version: 3, race: raceCore,
})

const run = async () => {
  // --- hash: determinism + cosmetic tolerance + distinctness + parse-fail ---
  const hashA1 = (await call({ op: 'hash', gpx: courseA })).hash
  const hashA2 = (await call({ op: 'hash', gpx: courseA })).hash
  const hashCosmetic = (await call({ op: 'hash', gpx: courseACosmetic })).hash
  const hashDiff = (await call({ op: 'hash', gpx: courseDifferent })).hash
  const hashGarbage = (await call({ op: 'hash', gpx: 'not gpx at all' })).hash
  console.log('hash: courseHash determinism + rounding tolerance')
  check('non-empty hash for a valid course', typeof hashA1 === 'string' && hashA1.length > 0, JSON.stringify(hashA1))
  check('deterministic (same input → same hash)', hashA1 === hashA2, `${hashA1} vs ${hashA2}`)
  check('tolerant: cosmetically-different-but-equivalent GPX → same hash', hashA1 === hashCosmetic, `${hashA1} vs ${hashCosmetic}`)
  check('distinct: a different course → different hash', hashA1 !== hashDiff, `${hashA1} vs ${hashDiff}`)
  check('unparseable GPX → "" (treated as unknown, no crash)', hashGarbage === '', JSON.stringify(hashGarbage))

  // --- classify: the typed import verdict ---
  console.log('classify: import guard verdicts')
  {
    const r = await call({ op: 'classify', incoming: { shareId: 's1', courseHash: 'h1' }, target: { shareId: 's1', courseHash: 'h1' } })
    check('same shareId + courseHash → Mergeable', r.verdict === 'Mergeable', r.verdict)
    check('Mergeable carries no message', r.message === '', JSON.stringify(r.message))
  }
  {
    const r = await call({ op: 'classify', incoming: { shareId: 's2', courseHash: 'h1' }, target: { shareId: 's1', courseHash: 'h1' } })
    check('different shareId → DifferentRace', r.verdict === 'DifferentRace', r.verdict)
    check('DifferentRace has a message', r.message.length > 0)
  }
  {
    const r = await call({ op: 'classify', incoming: { shareId: 's1', courseHash: 'h2' }, target: { shareId: 's1', courseHash: 'h1' } })
    check('same shareId, different courseHash → DifferentCourse', r.verdict === 'DifferentCourse', r.verdict)
    check('DifferentCourse has a message', r.message.length > 0)
  }
  {
    const r = await call({ op: 'classify', incoming: { shareId: '', courseHash: 'h1' }, target: { shareId: '', courseHash: 'h1' } })
    check('empty shareId never matches (→ DifferentRace)', r.verdict === 'DifferentRace', r.verdict)
  }

  // --- decode: v2 reads new fields, v1 back-compat, unknown version rejected ---
  console.log('decode: .trail v1/v2 back-compat')
  {
    const r = await call({ op: 'decode', trail: trailV2 })
    check('v2 decodes ok', r.ok === true, JSON.stringify(r))
    check('v2 preserves shareId', r.shareId === 'share-xyz', r.shareId)
    check('v2 preserves courseHash', r.courseHash === 'hash-abc', r.courseHash)
  }
  {
    const r = await call({ op: 'decode', trail: trailV1 })
    check('v1 decodes ok (back-compat)', r.ok === true, JSON.stringify(r))
    check('v1 shareId defaults to ""', r.shareId === '', JSON.stringify(r.shareId))
    check('v1 courseHash defaults to ""', r.courseHash === '', JSON.stringify(r.courseHash))
    check('v1 race body still read (name)', r.name === 'Demo Race', r.name)
  }
  {
    const r = await call({ op: 'decode', trail: trailV3 })
    check('unknown version (3) rejected', r.ok === false, JSON.stringify(r))
  }

  // --- encode: the exporter emits v2 + the identity fields ---
  console.log('encode: export is v2 with identity fields')
  {
    const { encoded } = await call({ op: 'encode', trail: trailV2 })
    const doc = JSON.parse(encoded)
    check('export version is 2', doc.version === 2, String(doc.version))
    check('export carries shareId', doc.race.shareId === 'share-xyz', doc.race.shareId)
    check('export carries courseHash', doc.race.courseHash === 'hash-abc', doc.race.courseHash)
    // round-trip: decode what we just encoded
    const back = await call({ op: 'decode', trail: encoded })
    check('encode→decode round-trip preserves identity', back.shareId === 'share-xyz' && back.courseHash === 'hash-abc', JSON.stringify(back))
  }
  {
    // A v1 doc re-exports as v2 (the version is the build's currentVersion).
    const { encoded } = await call({ op: 'encode', trail: trailV1 })
    const doc = JSON.parse(encoded)
    check('a v1 doc re-exports as v2', doc.version === 2, String(doc.version))
  }

  console.log('')
  if (failures === 0) {
    console.log('PASS — all .trail identity/integrity checks green')
    process.exit(0)
  } else {
    console.log(`FAIL — ${failures} check(s) failed`)
    process.exit(1)
  }
}

run()
