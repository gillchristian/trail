// Smoke test for the Changelog module (WI-4 / TASK-051) — drives the REAL
// compiled Elm (src/ChangelogHarness.elm) from Node. Proves:
//   - the two-way diff emits the right typed descriptors for each kind of
//     planning-layer change (aid add/remove/move/rename/retime, km note
//     add/edit/clear, km pace set/change/clear, race rename/date) and nothing
//     for non-taxonomy changes (target time, location, url, notes);
//   - entries round-trip through the codec (the harness re-decodes what it encodes);
//   - union merges two histories conflict-free by entryId (dedupe, count).
//
// Run with: node scripts/smoke-changelog.mjs

import { execFileSync } from 'node:child_process'
import { readFileSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')

const tmp = mkdtempSync(join(tmpdir(), 'changelog-'))
const out = join(tmp, 'harness.js')
try {
  execFileSync('npx', ['--no-install', 'elm', 'make', 'src/ChangelogHarness.elm', '--output', out], {
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
const app = scope.Elm.ChangelogHarness.init()

let resolveNext = null
app.ports.result.subscribe((r) => { const f = resolveNext; resolveNext = null; if (f) f(r) })
const call = (req) => new Promise((res) => { resolveNext = res; app.ports.run.send(req) })

let failures = 0
const check = (label, cond, detail) => {
  if (cond) console.log(`  ok   ${label}`)
  else { failures++; console.log(`  FAIL ${label}${detail ? ' — ' + detail : ''}`) }
}

const mkRace = (over) => ({
  id: 'r', name: 'Race', date: null, location: '', url: '', notes: '',
  coverImage: null, distance: 10000, gain: 500, loss: 500, gpxText: '<gpx/>',
  createdAt: 0, aidStations: [], aidStationSeq: 0,
  plan: { targetSeconds: null, kmPlans: [] }, actualSplits: null,
  shareId: 's', courseHash: 'h', ...over,
})
const aid = (id, over = {}) => ({ id, name: id, distance: 1000, restSeconds: 120, services: [], notes: '', cutoff: null, ...over })
const km = (index, notes, time = { kind: 'auto' }) => ({ index, time, notes })
const diffKinds = async (before, after) => (await call({ op: 'diff', before, after })).changes

const run = async () => {
  console.log('diff: aid-station changes')
  check('add', JSON.stringify(await diffKinds(mkRace({}), mkRace({ aidStations: [aid('a0')] }))) === '["aidAdded"]')
  check('remove', JSON.stringify(await diffKinds(mkRace({ aidStations: [aid('a0')] }), mkRace({}))) === '["aidRemoved"]')
  check('move', JSON.stringify(await diffKinds(mkRace({ aidStations: [aid('a0', { distance: 1000 })] }), mkRace({ aidStations: [aid('a0', { distance: 5000 })] }))) === '["aidMoved"]')
  check('rename', JSON.stringify(await diffKinds(mkRace({ aidStations: [aid('a0', { name: 'Old' })] }), mkRace({ aidStations: [aid('a0', { name: 'New' })] }))) === '["aidRenamed"]')
  check('retime', JSON.stringify(await diffKinds(mkRace({ aidStations: [aid('a0', { restSeconds: 120 })] }), mkRace({ aidStations: [aid('a0', { restSeconds: 300 })] }))) === '["aidRetimed"]')

  console.log('diff: per-km note + pace changes')
  check('note added', JSON.stringify(await diffKinds(mkRace({}), mkRace({ plan: { targetSeconds: null, kmPlans: [km(3, 'hi')] } }))) === '["kmNoteAdded"]')
  check('note edited', JSON.stringify(await diffKinds(mkRace({ plan: { targetSeconds: null, kmPlans: [km(3, 'hi')] } }), mkRace({ plan: { targetSeconds: null, kmPlans: [km(3, 'bye')] } }))) === '["kmNoteEdited"]')
  check('note cleared', JSON.stringify(await diffKinds(mkRace({ plan: { targetSeconds: null, kmPlans: [km(3, 'hi')] } }), mkRace({}))) === '["kmNoteCleared"]')
  check('pace set', JSON.stringify(await diffKinds(mkRace({}), mkRace({ plan: { targetSeconds: null, kmPlans: [km(3, '', { kind: 'manual', seconds: 300 })] } }))) === '["kmPaceSet"]')
  check('pace changed', JSON.stringify(await diffKinds(mkRace({ plan: { targetSeconds: null, kmPlans: [km(3, '', { kind: 'manual', seconds: 300 })] } }), mkRace({ plan: { targetSeconds: null, kmPlans: [km(3, '', { kind: 'manual', seconds: 360 })] } }))) === '["kmPaceChanged"]')
  check('pace cleared', JSON.stringify(await diffKinds(mkRace({ plan: { targetSeconds: null, kmPlans: [km(3, '', { kind: 'manual', seconds: 300 })] } }), mkRace({}))) === '["kmPaceCleared"]')

  console.log('diff: race metadata')
  check('rename', JSON.stringify(await diffKinds(mkRace({ name: 'A' }), mkRace({ name: 'B' }))) === '["raceRenamed"]')
  check('date changed', JSON.stringify(await diffKinds(mkRace({ date: null }), mkRace({ date: '2026-09-01' }))) === '["raceDateChanged"]')

  console.log('diff: non-taxonomy changes produce NO entries (no feed spam)')
  check('target time → []', JSON.stringify(await diffKinds(mkRace({}), mkRace({ plan: { targetSeconds: 9000, kmPlans: [] } }))) === '[]')
  check('location → []', JSON.stringify(await diffKinds(mkRace({}), mkRace({ location: 'Chamonix' }))) === '[]')
  check('notes → []', JSON.stringify(await diffKinds(mkRace({}), mkRace({ notes: 'whatever' }))) === '[]')
  check('identical → []', JSON.stringify(await diffKinds(mkRace({ aidStations: [aid('a0')] }), mkRace({ aidStations: [aid('a0')] }))) === '[]')

  console.log('diff: a multi-change commit lists each change')
  {
    const before = mkRace({ name: 'A', aidStations: [aid('a0')] })
    const after = mkRace({ name: 'B', aidStations: [aid('a0'), aid('a1', { distance: 2000 })], plan: { targetSeconds: null, kmPlans: [km(2, 'push')] } })
    const kinds = await diffKinds(before, after)
    check('rename + add + note all present', kinds.includes('raceRenamed') && kinds.includes('aidAdded') && kinds.includes('kmNoteAdded'), JSON.stringify(kinds))
  }

  console.log('union: conflict-free merge by entryId')
  {
    const e = (id, ts) => ({ entryId: id, author: id.split('-')[0], timestampMs: ts, source: 'local', changes: [{ kind: 'courseUploaded' }] })
    const a = [e('devA-0', 100), e('devA-1', 300)]
    const b = [e('devA-1', 300), e('devB-0', 200)] // devA-1 duplicated across both
    const r = await call({ op: 'union', a, b })
    check('deduped by entryId (3 unique)', r.count === 3, String(r.count))
    check('sorted by timestamp', JSON.stringify(r.entryIds) === JSON.stringify(['devA-0', 'devB-0', 'devA-1']), JSON.stringify(r.entryIds))
  }

  console.log('')
  if (failures === 0) {
    console.log('PASS — changelog diff + codecs + union hold')
    process.exit(0)
  } else {
    console.log(`FAIL — ${failures} check(s) failed`)
    process.exit(1)
  }
}

run()
