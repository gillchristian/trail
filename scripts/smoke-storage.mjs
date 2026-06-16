// Smoke test for the JS-side IndexedDB code path used by main.js.
//
// jsdom 29 doesn't load on Node 20 (CJS/ESM mismatch in a transitive
// dep), so we can't drive the compiled Elm bundle from Node — but we
// can still exercise the IDB schema, save/load/delete, and the v3 GPX
// split + migration. This file MIRRORS src/main.js's IDB logic (it can't
// `import` it — main.js imports Main.elm + CSS); keep the two in sync.
//
// Coverage: v3 store layout, save-assigns-id, ~3 MB round-trip, the v3
// split (races row carries no gpxText; gpx lives in its own row), the
// LIGHT (meta) save that leaves the gpx row untouched (TASK-040's win),
// orphan-free delete, and the v2 -> v3 migration of inline gpxText.
//
// Run with: node scripts/smoke-storage.mjs

import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import 'fake-indexeddb/auto'
import { webcrypto } from 'node:crypto'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')

const RACES_STORE = 'races'
const GPX_STORE = 'gpx'
const SETTINGS_STORE = 'settings'

// --- v3 schema + migration: mirrors src/main.js onupgradeneeded ---
function openV3(name) {
  return new Promise((res, rej) => {
    const req = indexedDB.open(name, 3)
    req.onupgradeneeded = (event) => {
      const db = req.result
      const tx = event.target.transaction
      if (!db.objectStoreNames.contains(RACES_STORE)) db.createObjectStore(RACES_STORE, { keyPath: 'id' })
      if (!db.objectStoreNames.contains(SETTINGS_STORE)) db.createObjectStore(SETTINGS_STORE, { keyPath: 'key' })
      if (!db.objectStoreNames.contains(GPX_STORE)) {
        db.createObjectStore(GPX_STORE, { keyPath: 'id' })
        const racesStore = tx.objectStore(RACES_STORE)
        const gpxStore = tx.objectStore(GPX_STORE)
        racesStore.openCursor().onsuccess = (e) => {
          const cursor = e.target.result
          if (!cursor) return
          const race = cursor.value
          if (race && typeof race.gpxText === 'string') {
            gpxStore.put({ id: race.id, gpxText: race.gpxText })
            const { gpxText, ...meta } = race
            cursor.update(meta)
          }
          cursor.continue()
        }
      }
    }
    req.onsuccess = () => res(req.result)
    req.onerror = () => rej(req.error)
  })
}

// --- the pre-split v2 schema: races + settings only, gpxText inline ---
function openV2(name) {
  return new Promise((res, rej) => {
    const req = indexedDB.open(name, 2)
    req.onupgradeneeded = () => {
      const db = req.result
      if (!db.objectStoreNames.contains(RACES_STORE)) db.createObjectStore(RACES_STORE, { keyPath: 'id' })
      if (!db.objectStoreNames.contains(SETTINGS_STORE)) db.createObjectStore(SETTINGS_STORE, { keyPath: 'key' })
    }
    req.onsuccess = () => res(req.result)
    req.onerror = () => rej(req.error)
  })
}

// --- store ops, mirroring src/main.js (each takes an open db) ---
function loadAll(db) {
  return new Promise((res, rej) => {
    const tx = db.transaction([RACES_STORE, GPX_STORE], 'readonly')
    const racesReq = tx.objectStore(RACES_STORE).getAll()
    const gpxReq = tx.objectStore(GPX_STORE).getAll()
    tx.oncomplete = () => {
      const gpxById = new Map((gpxReq.result || []).map((g) => [g.id, g.gpxText]))
      res((racesReq.result || []).map((r) => ({ ...r, gpxText: gpxById.get(r.id) ?? '' })))
    }
    tx.onerror = () => rej(tx.error)
  })
}

function saveRace(db, race) {
  // full save: races row (no gpxText) + gpx row; echoes the full race.
  // `id` = fresh local key; `shareId` = stable .trail identity, minted only
  // when absent so a v2 import keeps its own (TASK-047). Mirrors main.js.
  const withId = {
    ...race,
    id: race.id || webcrypto.randomUUID(),
    shareId: race.shareId || webcrypto.randomUUID(),
  }
  const { gpxText, ...meta } = withId
  return new Promise((res, rej) => {
    const tx = db.transaction([RACES_STORE, GPX_STORE], 'readwrite')
    tx.objectStore(RACES_STORE).put(meta)
    tx.objectStore(GPX_STORE).put({ id: withId.id, gpxText: gpxText ?? '' })
    tx.oncomplete = () => res(withId)
    tx.onerror = () => rej(tx.error)
  })
}

function saveRaceMeta(db, race) {
  // light save: races row only (payload already lacks gpxText)
  return new Promise((res, rej) => {
    const tx = db.transaction(RACES_STORE, 'readwrite')
    tx.objectStore(RACES_STORE).put(race)
    tx.oncomplete = () => res(race)
    tx.onerror = () => rej(tx.error)
  })
}

function deleteRace(db, id) {
  return new Promise((res, rej) => {
    const tx = db.transaction([RACES_STORE, GPX_STORE], 'readwrite')
    tx.objectStore(RACES_STORE).delete(id)
    tx.objectStore(GPX_STORE).delete(id)
    tx.oncomplete = () => res()
    tx.onerror = () => rej(tx.error)
  })
}

function getRaw(db, store, id) {
  return new Promise((res, rej) => {
    const tx = db.transaction(store, 'readonly')
    const req = tx.objectStore(store).get(id)
    req.onsuccess = () => res(req.result)
    req.onerror = () => rej(req.error)
  })
}

function putRaw(db, store, value) {
  return new Promise((res, rej) => {
    const tx = db.transaction(store, 'readwrite')
    tx.objectStore(store).put(value)
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
  plan: { targetSeconds: null, kmPlans: [] },
}

const db = await openV3('trail')

// 1. Empty DB → loadAll returns [].
assertEq((await loadAll(db)).length, 0, 'empty DB returns []')

// 2. Full save with id="" → JS assigns a uuid; echo carries gpxText.
const saved = await saveRace(db, draft)
if (!saved.id) {
  console.error('FAIL · save assigned no id')
  process.exit(1)
}
console.log(`OK   · save assigned id: ${saved.id}`)
assertEq(saved.gpxText, small, 'full-save echo carries gpxText')

// 2b. shareId (TASK-047): minted when absent, preserved when provided.
if (!saved.shareId) { console.error('FAIL · save minted no shareId'); process.exit(1) }
console.log(`OK   · save minted shareId: ${saved.shareId}`)
const kept = await saveRace(db, { ...draft, id: '', shareId: 'pinned-share-id' })
assertEq(kept.shareId, 'pinned-share-id', 'provided shareId is preserved (v2 import)')
assertEq((await loadAll(db)).find(r => r.id === kept.id)?.shareId, 'pinned-share-id', 'shareId round-trips through IDB')
await deleteRace(db, kept.id) // tidy up so the row count below stays 1

// 3. loadAll re-attaches gpxText from the gpx store.
let all = await loadAll(db)
assertEq(all.length, 1, 'one race after first save')
assertEq(all[0].name, draft.name, 'round-tripped name')
assertEq(all[0].gpxText, small, 'loadAll re-joins small GPX text')

// 3b. The v3 split: races row has NO gpxText; the gpx row holds it.
const rawRow = await getRaw(db, RACES_STORE, saved.id)
assertEq('gpxText' in rawRow, false, 'races row carries no gpxText')
assertEq((await getRaw(db, GPX_STORE, saved.id)).gpxText, small, 'gpx row holds the text')

// 4. 20k GPX round-trips.
const r20k = await saveRace(db, { ...draft, id: '', name: 'OMD 20k', gpxText: fixture20k })
assertEq((await loadAll(db)).find(r => r.id === r20k.id)?.gpxText?.length, fixture20k.length, '20k GPX length round-trips')

// 5. UTMB GPX (~3 MB) round-trips.
const tStart = Date.now()
const rUtmb = await saveRace(db, { ...draft, id: '', name: 'UTMB 2025', gpxText: fixtureUtmb })
const tSave = Date.now() - tStart
assertEq((await loadAll(db)).find(r => r.id === rUtmb.id)?.gpxText?.length, fixtureUtmb.length, 'UTMB GPX length round-trips')
console.log(`OK   · UTMB GPX (${fixtureUtmb.length.toLocaleString()} chars) full-saved in ${tSave}ms`)

// 6. Full re-save with an existing id is an upsert.
const updated = await saveRace(db, { ...saved, name: 'renamed' })
assertEq(updated.id, saved.id, 'upsert keeps id')
assertEq((await loadAll(db)).find(r => r.id === saved.id)?.name, 'renamed', 'upsert updated name')

// 7. THE WIN: a light (meta) save updates plan/name WITHOUT touching the
//    gpx row and without the payload ever carrying gpxText.
const metaPayload = { id: saved.id, name: 'meta-edited', date: null, location: '', url: '',
  notes: '', coverImage: null, distance: 1500, gain: 500, loss: 200, createdAt: draft.createdAt,
  plan: { targetSeconds: 9000, kmPlans: [] } }
assertEq('gpxText' in metaPayload, false, 'meta-save payload carries no gpxText')
await saveRaceMeta(db, metaPayload)
const afterMeta = (await loadAll(db)).find(r => r.id === saved.id)
assertEq(afterMeta.name, 'meta-edited', 'meta save updated the name')
assertEq(afterMeta.plan.targetSeconds, 9000, 'meta save updated the plan')
assertEq(afterMeta.gpxText, small, 'gpx still re-joined after a meta save')
assertEq((await getRaw(db, GPX_STORE, saved.id)).gpxText, small, 'gpx row untouched by the meta save')

// 8. Delete removes BOTH rows (no orphaned gpx).
await deleteRace(db, saved.id)
assertEq((await loadAll(db)).find(r => r.id === saved.id), undefined, 'deleted race is gone')
assertEq(await getRaw(db, GPX_STORE, saved.id), undefined, 'deleted race left no orphan gpx row')

// 9. MIGRATION v2 -> v3: a race stored inline under v2 is split on upgrade.
{
  const name = 'trail-migration-test'
  const v2 = await openV2(name)
  const legacyId = webcrypto.randomUUID()
  await putRaw(v2, RACES_STORE, { ...draft, id: legacyId, name: 'Legacy UTMB', gpxText: fixtureUtmb })
  v2.close() // release the connection so the version upgrade isn't blocked

  const v3 = await openV3(name)
  const migratedRow = await getRaw(v3, RACES_STORE, legacyId)
  assertEq('gpxText' in migratedRow, false, 'migration stripped gpxText from the races row')
  assertEq(migratedRow.name, 'Legacy UTMB', 'migration preserved the race fields')
  assertEq((await getRaw(v3, GPX_STORE, legacyId)).gpxText.length, fixtureUtmb.length, 'migration moved UTMB gpx into the gpx store')
  assertEq((await loadAll(v3)).find(r => r.id === legacyId)?.gpxText?.length, fixtureUtmb.length, 'migrated race re-joins its gpx on load')
}

console.log('\nSMOKE PASSED · v3 GPX split, light (meta) save, orphan-free delete, and v2→v3 migration all round-trip — including UTMB-size payloads.')
