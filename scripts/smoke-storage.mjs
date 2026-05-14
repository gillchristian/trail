// Smoke test for the JS-side IndexedDB code path used by main.js.
//
// jsdom 29 doesn't load on Node 20 (CJS/ESM mismatch in a transitive
// dep), so we can't drive the compiled Elm bundle from Node — but we
// can still exercise the IDB schema, the save-assigns-id behaviour,
// and a full round-trip with a real ~3 MB GPX text. That's the
// half-of-the-port-pair we can usefully verify outside the browser;
// the Elm half is enforced by the compiler.
//
// Run with: node scripts/smoke-storage.mjs

import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import 'fake-indexeddb/auto'
import { webcrypto } from 'node:crypto'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')

const DB_NAME = 'trail'
const RACES_STORE = 'races'

const dbPromise = new Promise((res, rej) => {
  const req = indexedDB.open(DB_NAME, 1)
  req.onupgradeneeded = () => {
    const db = req.result
    if (!db.objectStoreNames.contains(RACES_STORE)) {
      db.createObjectStore(RACES_STORE, { keyPath: 'id' })
    }
  }
  req.onsuccess = () => res(req.result)
  req.onerror = () => rej(req.error)
})

async function loadAll() {
  const db = await dbPromise
  return new Promise((res, rej) => {
    const tx = db.transaction(RACES_STORE, 'readonly')
    const req = tx.objectStore(RACES_STORE).getAll()
    req.onsuccess = () => res(req.result || [])
    req.onerror = () => rej(req.error)
  })
}

async function saveRace(race) {
  const db = await dbPromise
  const withId = { ...race, id: race.id || webcrypto.randomUUID() }
  return new Promise((res, rej) => {
    const tx = db.transaction(RACES_STORE, 'readwrite')
    tx.objectStore(RACES_STORE).put(withId)
    tx.oncomplete = () => res(withId)
    tx.onerror = () => rej(tx.error)
  })
}

async function deleteRace(id) {
  const db = await dbPromise
  return new Promise((res, rej) => {
    const tx = db.transaction(RACES_STORE, 'readwrite')
    tx.objectStore(RACES_STORE).delete(id)
    tx.oncomplete = () => res()
    tx.onerror = () => rej(tx.error)
  })
}

function assertEq(actual, expected, label) {
  if (actual !== expected) {
    console.error(`FAIL · ${label}: expected ${expected}, got ${actual}`)
    process.exit(1)
  }
  console.log(`OK   · ${label}`)
}

const small = readFileSync(resolve(repoRoot, 'samples/sample.gpx'), 'utf8')
const fixture20k = readFileSync(resolve(repoRoot, 'samples/20k_oh_meu_deus.gpx'), 'utf8')
const fixtureUtmb = readFileSync(resolve(repoRoot, 'samples/utmb_2025.gpx'), 'utf8')

// 1. Empty DB → loadAll returns [].
assertEq((await loadAll()).length, 0, 'empty DB returns []')

// 2. Save with id="" → JS assigns a uuid.
const draft = {
  id: '',
  name: 'Test Climb',
  date: null,
  location: '',
  url: '',
  notes: '',
  coverImage: null,
  distance: 1500,
  gain: 500,
  loss: 200,
  gpxText: small,
  createdAt: Date.now(),
}
const saved = await saveRace(draft)
if (!saved.id) {
  console.error('FAIL · save assigned no id')
  process.exit(1)
}
console.log(`OK   · save assigned id: ${saved.id}`)

// 3. loadAll reflects the save.
let all = await loadAll()
assertEq(all.length, 1, 'one race after first save')
assertEq(all[0].id, saved.id, 'round-tripped id matches')
assertEq(all[0].name, draft.name, 'round-tripped name')
assertEq(all[0].gpxText, small, 'round-tripped small GPX text')

// 4. 20k GPX persists and round-trips.
const r20k = await saveRace({ ...draft, id: '', name: 'OMD 20k', gpxText: fixture20k })
all = await loadAll()
const got20k = all.find(r => r.id === r20k.id)
assertEq(got20k?.gpxText?.length, fixture20k.length, '20k GPX text length round-trips')

// 5. UTMB GPX (~3 MB text) persists and round-trips.
const tStart = Date.now()
const rUtmb = await saveRace({ ...draft, id: '', name: 'UTMB 2025', gpxText: fixtureUtmb })
const tSave = Date.now() - tStart
all = await loadAll()
const gotUtmb = all.find(r => r.id === rUtmb.id)
assertEq(gotUtmb?.gpxText?.length, fixtureUtmb.length, 'UTMB GPX text length round-trips')
console.log(`OK   · UTMB GPX (${fixtureUtmb.length.toLocaleString()} chars) saved in ${tSave}ms`)

// 6. Re-save with existing id is upsert.
const updated = await saveRace({ ...saved, name: 'renamed' })
assertEq(updated.id, saved.id, 'upsert keeps id')
const reloaded = (await loadAll()).find(r => r.id === saved.id)
assertEq(reloaded.name, 'renamed', 'upsert updated name')

// 7. Delete removes.
await deleteRace(saved.id)
all = await loadAll()
const stillThere = all.find(r => r.id === saved.id)
assertEq(stillThere, undefined, 'deleted race is gone')

console.log('\nSMOKE PASSED · IndexedDB schema + save/load/delete round-trips work, including UTMB-size payloads.')
