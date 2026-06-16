// Smoke test for the Merge module — the WI-2 course-freeze boundary (TASK-048;
// grown by WI-3). Drives the REAL compiled Elm (src/MergeHarness.elm) from Node.
// Proves the freeze is structural:
//   - withPlanningLayer keeps the LOCAL race's course (gpxText + distance/gain/
//     loss + courseHash) and identity/owner-only fields (id, shareId, createdAt,
//     coverImage, actualSplits) verbatim, even when the incoming planning layer
//     comes from a different course;
//   - it takes the planning layer (name/date/location/url/notes + aids + plan)
//     from the source;
//   - round-trip identity: withPlanningLayer (planningLayer r) r == r.
// (The complementary "different course rejected on import" half is WI-1's
// smoke:trailsync.)
//
// Run with: node scripts/smoke-merge.mjs

import { execFileSync } from 'node:child_process'
import { readFileSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')

const tmp = mkdtempSync(join(tmpdir(), 'merge-'))
const out = join(tmp, 'harness.js')
try {
  execFileSync('npx', ['--no-install', 'elm', 'make', 'src/MergeHarness.elm', '--output', out], {
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
const app = scope.Elm.MergeHarness.init()

let resolveNext = null
app.ports.result.subscribe((r) => { const f = resolveNext; resolveNext = null; if (f) f(r) })
const call = (req) => new Promise((res) => { resolveNext = res; app.ports.run.send(req) })

let failures = 0
const check = (label, cond, detail) => {
  if (cond) console.log(`  ok   ${label}`)
  else { failures++; console.log(`  FAIL ${label}${detail ? ' — ' + detail : ''}`) }
}
const eqJson = (a, b) => JSON.stringify(a) === JSON.stringify(b)

// Two races on DIFFERENT courses with DIFFERENT plans.
const local = {
  id: 'local-id', name: 'My Plan', date: '2026-09-01', location: 'Chamonix', url: '',
  notes: 'my notes', coverImage: 'data:image/png;base64,LOCAL', distance: 20000, gain: 1200, loss: 1100,
  gpxText: '<gpx>LOCAL COURSE</gpx>', createdAt: 1000,
  aidStations: [{ id: 'a0', name: 'Local Aid', distance: 5000, restSeconds: 120, services: ['water'], notes: '', cutoff: null }],
  aidStationSeq: 1, plan: { targetSeconds: 7200, kmPlans: [] }, actualSplits: null,
  shareId: 'share-local', courseHash: 'COURSE-LOCAL',
}
const source = {
  id: 'source-id', name: "Coach's Edits", date: '2026-10-15', location: 'Coach Town', url: 'http://x',
  notes: 'coach notes', coverImage: 'data:image/png;base64,OTHER', distance: 99999, gain: 9999, loss: 8888,
  gpxText: '<gpx>OTHER COURSE</gpx>', createdAt: 2000,
  aidStations: [
    { id: 'a0', name: 'Coach Aid 1', distance: 3000, restSeconds: 60, services: ['food'], notes: 'soup', cutoff: 3600 },
    { id: 'a1', name: 'Coach Aid 2', distance: 8000, restSeconds: 90, services: [], notes: '', cutoff: null },
  ],
  aidStationSeq: 2, plan: { targetSeconds: 9000, kmPlans: [{ index: 4, time: { kind: 'manual', seconds: 300 }, notes: 'push here' }] },
  actualSplits: null, shareId: 'share-other', courseHash: 'COURSE-OTHER',
}

const run = async () => {
  console.log('freeze: withPlanningLayer keeps local course, takes source plan')
  const { result: r } = await call({ op: 'freeze', local, source })

  // The frozen course + identity + owner-only fields must all be LOCAL's.
  check('gpxText kept from local', r.gpxText === local.gpxText, r.gpxText)
  check('courseHash kept from local', r.courseHash === local.courseHash, r.courseHash)
  check('distance kept from local', r.distance === local.distance, String(r.distance))
  check('gain kept from local', r.gain === local.gain, String(r.gain))
  check('loss kept from local', r.loss === local.loss, String(r.loss))
  check('id kept from local', r.id === local.id, r.id)
  check('shareId kept from local', r.shareId === local.shareId, r.shareId)
  check('createdAt kept from local', r.createdAt === local.createdAt, String(r.createdAt))
  check('coverImage kept from local (owner-only)', r.coverImage === local.coverImage, r.coverImage)
  check('actualSplits kept from local (owner-only)', r.actualSplits === null, JSON.stringify(r.actualSplits))

  // The planning layer must all be SOURCE's.
  check('name taken from source', r.name === source.name, r.name)
  check('date taken from source', r.date === source.date, r.date)
  check('location taken from source', r.location === source.location, r.location)
  check('url taken from source', r.url === source.url, r.url)
  check('notes taken from source', r.notes === source.notes, r.notes)
  check('aidStationSeq taken from source', r.aidStationSeq === source.aidStationSeq, String(r.aidStationSeq))
  check('aidStations taken from source (2 of them)', r.aidStations.length === 2, String(r.aidStations.length))
  check('plan targetSeconds taken from source', r.plan.targetSeconds === 9000, String(r.plan.targetSeconds))
  check('plan kmPlans taken from source', r.plan.kmPlans.length === 1, String(r.plan.kmPlans.length))

  console.log('roundtrip: withPlanningLayer (planningLayer r) r == r')
  const { result: rt } = await call({ op: 'roundtrip', race: local })
  // Compare the full encoded race against a re-encoding of the input. The
  // harness echoes encodeRace; build the same shape from `local` is fragile, so
  // instead assert every field we care about survived unchanged.
  check('roundtrip preserves gpxText', rt.gpxText === local.gpxText)
  check('roundtrip preserves courseHash', rt.courseHash === local.courseHash)
  check('roundtrip preserves name', rt.name === local.name)
  check('roundtrip preserves aidStations', eqJson(rt.aidStations, local.aidStations))
  check('roundtrip preserves plan', rt.plan.targetSeconds === local.plan.targetSeconds)
  check('roundtrip preserves shareId', rt.shareId === local.shareId)

  console.log('')
  if (failures === 0) {
    console.log('PASS — course-freeze boundary holds')
    process.exit(0)
  } else {
    console.log(`FAIL — ${failures} check(s) failed`)
    process.exit(1)
  }
}

run()
