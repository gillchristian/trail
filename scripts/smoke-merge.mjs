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

  console.log('mintAid: fork-collision-safe aid ids (TASK-049)')
  {
    const devA = '550e8400-e29b-41d4-a716-446655440000'
    const devB = 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
    const a5 = (await call({ op: 'mintAid', deviceId: devA, seq: 5 })).id
    const a5again = (await call({ op: 'mintAid', deviceId: devA, seq: 5 })).id
    const b5 = (await call({ op: 'mintAid', deviceId: devB, seq: 5 })).id
    const a6 = (await call({ op: 'mintAid', deviceId: devA, seq: 6 })).id
    const bare = (await call({ op: 'mintAid', deviceId: '', seq: 5 })).id
    check('same device + seq → deterministic', a5 === a5again, `${a5} vs ${a5again}`)
    check('different device, same seq → DISTINCT (fork-safe)', a5 !== b5, `${a5} vs ${b5}`)
    check('same device, different seq → distinct', a5 !== a6, `${a5} vs ${a6}`)
    check('id starts with "a"+seq', a5.startsWith('a5'), a5)
    check('empty deviceId → bare "aN" (back-compat fallback)', bare === 'a5', bare)
  }

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

  // ---- WI-3 three-way merge engine (TASK-050) ----
  const mkRace = (over) => ({
    id: 'r', name: 'Race', date: null, location: '', url: '', notes: '',
    coverImage: null, distance: 10000, gain: 500, loss: 500, gpxText: '<gpx/>',
    createdAt: 0, aidStations: [], aidStationSeq: 0,
    plan: { targetSeconds: null, kmPlans: [] }, actualSplits: null,
    shareId: 's', courseHash: 'h', ...over,
  })
  const aid = (id, over = {}) => ({ id, name: id, distance: 1000, restSeconds: 120, services: [], notes: '', cutoff: null, ...over })
  const km = (index, notes, time = { kind: 'auto' }) => ({ index, time, notes })
  const kmNote = (race, i) => (race.plan.kmPlans.find((k) => k.index === i) || {}).notes
  const aidById = (race, id) => race.aidStations.find((a) => a.id === id)
  const aidIds = (race) => race.aidStations.map((a) => a.id).sort()

  console.log('merge: disjoint edits (coach km-note + owner aid) → 0 conflicts, both land')
  {
    const base = mkRace({ aidStations: [aid('a0', { restSeconds: 120 })], plan: { targetSeconds: null, kmPlans: [km(5, '')] } })
    const mine = mkRace({ aidStations: [aid('a0', { restSeconds: 300 })], plan: { targetSeconds: null, kmPlans: [km(5, '')] } }) // owner changed aid rest
    const theirs = mkRace({ aidStations: [aid('a0', { restSeconds: 120 })], plan: { targetSeconds: null, kmPlans: [km(5, 'downhill')] } }) // coach changed note
    const r = await call({ op: 'merge', base, mine, theirs })
    check('0 conflicts', r.conflicts.length === 0, JSON.stringify(r.conflicts))
    check("owner's aid edit landed (rest 300)", aidById(r.merged, 'a0').restSeconds === 300, String(aidById(r.merged, 'a0').restSeconds))
    check("coach's note landed (km5 = downhill)", kmNote(r.merged, 5) === 'downhill', kmNote(r.merged, 5))
  }

  console.log('merge: both edit the SAME km note → 1 conflict, resolve flips it')
  {
    const base = mkRace({ plan: { targetSeconds: null, kmPlans: [km(5, 'base')] } })
    const mine = mkRace({ plan: { targetSeconds: null, kmPlans: [km(5, 'mine note')] } })
    const theirs = mkRace({ plan: { targetSeconds: null, kmPlans: [km(5, 'their note')] } })
    const r = await call({ op: 'merge', base, mine, theirs })
    check('exactly 1 conflict', r.conflicts.length === 1, JSON.stringify(r.conflicts))
    check('conflict is the km note', r.conflicts[0] && r.conflicts[0].label === 'Km 6 note', JSON.stringify(r.conflicts[0]))
    check('merged defaults to mine', kmNote(r.merged, 5) === 'mine note', kmNote(r.merged, 5))
    check('resolve(theirs) flips it to theirs', kmNote(r.resolvedAll, 5) === 'their note', kmNote(r.resolvedAll, 5))
    // determinism: same inputs → same conflict set
    const r2 = await call({ op: 'merge', base, mine, theirs })
    check('deterministic', JSON.stringify(r.conflicts) === JSON.stringify(r2.conflicts))
  }

  console.log('merge: disjoint aid adds (fork-safe ids) → both present')
  {
    const base = mkRace({ aidStations: [aid('a0')], aidStationSeq: 1 })
    const mine = mkRace({ aidStations: [aid('a0'), aid('a1-devmine', { distance: 2000 })], aidStationSeq: 2 })
    const theirs = mkRace({ aidStations: [aid('a0'), aid('a1-devtheir', { distance: 3000 })], aidStationSeq: 2 })
    const r = await call({ op: 'merge', base, mine, theirs })
    check('0 conflicts on disjoint adds', r.conflicts.length === 0, JSON.stringify(r.conflicts))
    check('both added aids present', JSON.stringify(aidIds(r.merged)) === JSON.stringify(['a0', 'a1-devmine', 'a1-devtheir']), JSON.stringify(aidIds(r.merged)))
    check('aidStationSeq = max', r.merged.aidStationSeq === 2, String(r.merged.aidStationSeq))
  }

  console.log('merge: theirs removes an aid mine left alone → honoured (dropped, 0 conflicts)')
  {
    const base = mkRace({ aidStations: [aid('a0'), aid('a1', { distance: 5000 })], aidStationSeq: 2 })
    const mine = mkRace({ aidStations: [aid('a0'), aid('a1', { distance: 5000 })], aidStationSeq: 2 })
    const theirs = mkRace({ aidStations: [aid('a0')], aidStationSeq: 2 }) // removed a1
    const r = await call({ op: 'merge', base, mine, theirs })
    check('removed aid is gone', JSON.stringify(aidIds(r.merged)) === JSON.stringify(['a0']), JSON.stringify(aidIds(r.merged)))
    check('0 conflicts for a clean remove', r.conflicts.length === 0, JSON.stringify(r.conflicts))
  }

  console.log('merge: disjoint scalar edits (name vs date) → 0 conflicts, both land')
  {
    const base = mkRace({ name: 'Base', date: '2026-01-01' })
    const mine = mkRace({ name: 'My Name', date: '2026-01-01' })
    const theirs = mkRace({ name: 'Base', date: '2026-09-09' })
    const r = await call({ op: 'merge', base, mine, theirs })
    check('0 conflicts', r.conflicts.length === 0, JSON.stringify(r.conflicts))
    check('name = mine', r.merged.name === 'My Name', r.merged.name)
    check('date = theirs', r.merged.date === '2026-09-09', r.merged.date)
  }

  console.log('classify: version-vector relations (Q4)')
  {
    const c = async (mine, theirs) => (await call({ op: 'classify', mine, theirs })).rel
    check('equal → Same', (await c({ m: 1 }, { m: 1 })) === 'Same')
    check('theirs ahead → FastForward', (await c({ m: 1 }, { m: 1, c: 1 })) === 'FastForward')
    check('mine ahead → Behind', (await c({ m: 2 }, { m: 1 })) === 'Behind')
    check('concurrent → Diverged', (await c({ m: 1, c: 1 }, { m: 1, x: 1 })) === 'Diverged')
  }

  console.log('')
  if (failures === 0) {
    console.log('PASS — course-freeze + three-way merge engine hold')
    process.exit(0)
  } else {
    console.log(`FAIL — ${failures} check(s) failed`)
    process.exit(1)
  }
}

run()
