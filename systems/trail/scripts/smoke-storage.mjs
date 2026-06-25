// Smoke test for the JS-side IndexedDB code path used by main.js.
//
// jsdom 29 doesn't load on Node 20 (CJS/ESM mismatch in a transitive
// dep), so we can't drive the compiled Elm bundle from Node — but we
// can still exercise the IDB schema, save/load/delete, and the v3 GPX
// split + migration. This file MIRRORS src/main.js's IDB logic (it can't
// `import` it — main.js imports Main.elm + CSS); keep the two in sync.
//
// Coverage: v5 store layout (incl. the WI-5 identity store), save-assigns-id,
// ~3 MB round-trip, the v3 split (races row carries no gpxText; gpx lives in
// its own row), the LIGHT (meta) save that leaves the gpx row untouched
// (TASK-040's win), orphan-free delete, the identity bundle round-trip, the
// v2 -> v3 + v3 -> v4 migrations, and the v4 -> v5 self-heal of a DB left
// without the identity store (interrupted upgrade / dev HMR).
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
const IDENTITY_STORE = 'identity'
const IDENTITY_KEY = 'me'

// --- shared migration, mirroring src/main.js onupgradeneeded ---
// `withIdentity = false` reproduces a pre-WI-5 (v3) handler, or a *poisoned* v4
// whose identity store-creation never ran — used below to test the heal.
function migrate(db, tx, withIdentity) {
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
  if (withIdentity && !db.objectStoreNames.contains(IDENTITY_STORE)) db.createObjectStore(IDENTITY_STORE, { keyPath: 'key' })
}

function open(name, version, withIdentity = true) {
  return new Promise((res, rej) => {
    const req = indexedDB.open(name, version)
    req.onupgradeneeded = (event) => migrate(req.result, event.target.transaction, withIdentity)
    req.onsuccess = () => res(req.result)
    req.onerror = () => rej(req.error)
  })
}

const openV3 = (name) => open(name, 3, false) // v3 predates the identity store
const openV4 = (name) => open(name, 4)
const openV5 = (name) => open(name, 5)
// A v4 DB whose identity store-creation never ran (an interrupted upgrade, or in
// dev an HMR reload that caught the v4 version bump a beat before the
// store-creation landed). Reopening at v5 re-runs the additive migration → heal.
const openPoisonedV4 = (name) => open(name, 4, false)

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

// identity bundle: single row keyed IDENTITY_KEY; null until first mint (WI-5).
// Mirrors main.js's guard: a missing store degrades to null, never throws.
function loadIdentity(db) {
  if (!db.objectStoreNames.contains(IDENTITY_STORE)) return Promise.resolve(null)
  return new Promise((res, rej) => {
    const tx = db.transaction(IDENTITY_STORE, 'readonly')
    const req = tx.objectStore(IDENTITY_STORE).get(IDENTITY_KEY)
    req.onsuccess = () => res(req.result ? req.result.value : null)
    req.onerror = () => rej(req.error)
  })
}

function saveIdentity(db, value) {
  return new Promise((res, rej) => {
    const tx = db.transaction(IDENTITY_STORE, 'readwrite')
    tx.objectStore(IDENTITY_STORE).put({ key: IDENTITY_KEY, value })
    tx.oncomplete = () => res(value)
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

const db = await openV5('trail')

// 0. the schema creates the dedicated identity store (WI-5 / TASK-054).
assertEq(db.objectStoreNames.contains(IDENTITY_STORE), true, 'schema creates the identity store')

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

// 10. IDENTITY STORE (v4, WI-5 / TASK-054): empty until first mint, then the
//     {me, directory} bundle round-trips.
assertEq(await loadIdentity(db), null, 'identity store starts empty (loadIdentity → null)')
{
  const bundle = { me: { userId: 'u1', displayName: 'Alex' }, directory: [{ userId: 'u1', displayName: 'Alex', nameUpdatedAt: 1 }] }
  await saveIdentity(db, bundle)
  const back = await loadIdentity(db)
  assertEq(back?.me?.userId, 'u1', 'identity round-trips: me.userId')
  assertEq(back?.me?.displayName, 'Alex', 'identity round-trips: me.displayName')
  assertEq(back?.directory?.length, 1, 'identity round-trips: directory entries')
}

// 10b. DEVICE SETTINGS (i18n WI-2 / ADR-0014): the language record round-trips in
//      the settings store under DEVICE_SETTINGS_KEY — absent until first write,
//      so first run reads null and Elm falls back to navigator.language. Mirrors
//      main.js loadSettings/saveSettings.
{
  const DEVICE_SETTINGS_KEY = 'deviceSettings'
  assertEq(await getRaw(db, SETTINGS_STORE, DEVICE_SETTINGS_KEY), undefined, 'device settings absent until first write (first run → null)')
  await putRaw(db, SETTINGS_STORE, { key: DEVICE_SETTINGS_KEY, value: { language: 'es' } })
  assertEq((await getRaw(db, SETTINGS_STORE, DEVICE_SETTINGS_KEY)).value.language, 'es', 'device settings round-trip: language persisted')
}

// 11. MIGRATION v3 -> v4: an existing v3 DB gains the identity store on upgrade,
//     with races / gpx / settings preserved (additive, like v2→v3).
{
  const name = 'trail-v3-to-v4'
  const v3 = await openV3(name)
  const rid = webcrypto.randomUUID()
  await saveRace(v3, { ...draft, id: rid, name: 'Before v4', gpxText: small })
  await putRaw(v3, SETTINGS_STORE, { key: 'activeProfile', value: { fromV3: true } })
  assertEq(v3.objectStoreNames.contains(IDENTITY_STORE), false, 'v3 has no identity store')
  v3.close() // release the connection so the version upgrade isn't blocked

  const v4 = await openV4(name)
  assertEq(v4.objectStoreNames.contains(IDENTITY_STORE), true, 'v3→v4 adds the identity store')
  assertEq((await loadAll(v4)).find(r => r.id === rid)?.gpxText, small, 'v3→v4 preserves races + gpx')
  assertEq((await getRaw(v4, SETTINGS_STORE, 'activeProfile')).value.fromV3, true, 'v3→v4 preserves settings')
  assertEq(await loadIdentity(v4), null, 'identity store empty after migration')
}

// 12. SELF-HEAL: a v4 DB that's missing the identity store (interrupted upgrade
//     / dev HMR) gets it back on reopen at v5 — additively, no data loss — and
//     loadIdentity degrades to null (not a throw) while the store is absent.
{
  const name = 'trail-poisoned-v4'
  const poisoned = await openPoisonedV4(name)
  const rid = webcrypto.randomUUID()
  await saveRace(poisoned, { ...draft, id: rid, name: 'Survivor', gpxText: small })
  await putRaw(poisoned, SETTINGS_STORE, { key: 'activeProfile', value: { keep: 1 } })
  assertEq(poisoned.objectStoreNames.contains(IDENTITY_STORE), false, 'poisoned v4 lacks the identity store')
  assertEq(await loadIdentity(poisoned), null, 'loadIdentity degrades to null on the missing store (no throw)')
  poisoned.close()

  const healed = await openV5(name)
  assertEq(healed.objectStoreNames.contains(IDENTITY_STORE), true, 'reopen at v5 heals: identity store created')
  assertEq((await loadAll(healed)).find(r => r.id === rid)?.gpxText, small, 'heal preserved races + gpx')
  assertEq((await getRaw(healed, SETTINGS_STORE, 'activeProfile')).value.keep, 1, 'heal preserved settings')
  assertEq(await loadIdentity(healed), null, 'healed identity store is present + empty')
}

console.log('\nSMOKE PASSED · v5 schema incl. the identity store, the v4→v5 self-heal of a missing store, v3 GPX split, light (meta) save, orphan-free delete, and v2→v3 + v3→v4 migrations all round-trip — including UTMB-size payloads.')
