import './styles/app.css'
import './leaflet-element.js'
import { Elm } from './Main.elm'

// ============================================================
// IndexedDB wrapper
// ============================================================

const DB_NAME = 'trail'
// v5 is schema-identical to v4. The bump exists only to re-run the additive,
// idempotent migration so a DB left at v4 *without* the `identity` store heals on
// next load with no data loss — e.g. an upgrade interrupted before its
// createObjectStore ran, or (in dev) an HMR reload that applied the v4 version
// bump a beat before the identity store-creation landed. onupgradeneeded fires
// only on a version change, hence the bump. (WI-5 / TASK-054.)
const DB_VERSION = 5
const RACES_STORE = 'races'
const GPX_STORE = 'gpx'
const SETTINGS_STORE = 'settings'
const IDENTITY_STORE = 'identity'
const ACTIVE_PROFILE_KEY = 'activeProfile'
const STRAVA_TOKEN_KEY = 'stravaSessionToken'
// One row holds the device-global identity bundle ({me, directory}); WI-5.
const IDENTITY_KEY = 'me'
const BACKEND_URL =
  import.meta.env.VITE_BACKEND_URL || 'http://localhost:3001'

const dbPromise = new Promise((resolve, reject) => {
  const req = indexedDB.open(DB_NAME, DB_VERSION)
  req.onupgradeneeded = (event) => {
    const db = req.result
    const tx = event.target.transaction
    if (!db.objectStoreNames.contains(RACES_STORE)) {
      db.createObjectStore(RACES_STORE, { keyPath: 'id' })
    }
    if (!db.objectStoreNames.contains(SETTINGS_STORE)) {
      db.createObjectStore(SETTINGS_STORE, { keyPath: 'key' })
    }
    // v3: GPX text moves into its own row so plan/aid edits don't re-ship or
    // rewrite the ~3 MB string (TASK-040 / ADR-0005). Upgrading from v2, split
    // each existing race: copy gpxText into the gpx store, strip it from the
    // races row. On a fresh DB the races store is empty, so the cursor is a
    // no-op and only the (empty) gpx store gets created.
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
    // v4: dedicated store for the device identity bundle ({me, directory}) —
    // person-level userId + name directory, kept out of `settings` and out of
    // the race performance profile (WI-5 / TASK-054 / ADR-0012). Additive: the
    // contains-check makes the upgrade a no-op for a DB that already has it, and
    // creating it on a populated DB leaves races/gpx/settings untouched.
    if (!db.objectStoreNames.contains(IDENTITY_STORE)) {
      db.createObjectStore(IDENTITY_STORE, { keyPath: 'key' })
    }
  }
  req.onsuccess = () => resolve(req.result)
  req.onerror = () => reject(req.error)
})

async function loadAllRaces() {
  const db = await dbPromise
  return new Promise((resolve, reject) => {
    const tx = db.transaction([RACES_STORE, GPX_STORE], 'readonly')
    const racesReq = tx.objectStore(RACES_STORE).getAll()
    const gpxReq = tx.objectStore(GPX_STORE).getAll()
    tx.oncomplete = () => {
      const gpxById = new Map((gpxReq.result || []).map((g) => [g.id, g.gpxText]))
      // Re-attach gpxText so the Elm decoder sees a full race. '' if a gpx
      // row is somehow missing — degrade (no profile) rather than crash.
      const races = (racesReq.result || []).map((r) => ({
        ...r,
        gpxText: gpxById.get(r.id) ?? '',
      }))
      resolve(races)
    }
    tx.onerror = () => reject(tx.error)
  })
}

// Full save: import / new race. Writes the GPX row (once) + the races row
// (without gpxText), and echoes the full race (with gpxText + the assigned
// id) back so Elm can add the brand-new race to its model.
async function saveRace(race) {
  const db = await dbPromise
  // `id` is the local row key (fresh on every import). `shareId` is the stable
  // cross-round-trip identity for .trail sharing (TASK-047): mint one only when
  // absent, so a v2 import that already carries a shareId keeps it.
  const withId = {
    ...race,
    id: race.id || crypto.randomUUID(),
    shareId: race.shareId || crypto.randomUUID(),
  }
  const { gpxText, ...meta } = withId
  return new Promise((resolve, reject) => {
    const tx = db.transaction([RACES_STORE, GPX_STORE], 'readwrite')
    tx.objectStore(RACES_STORE).put(meta)
    tx.objectStore(GPX_STORE).put({ id: withId.id, gpxText: gpxText ?? '' })
    tx.oncomplete = () => resolve(withId)
    tx.onerror = () => reject(tx.error)
  })
}

// Light save: plan/aid/metadata edit. The payload already omits gpxText
// (Elm's encodeRaceMeta), so this touches only the races row — the ~3 MB GPX
// neither crosses the port nor gets rewritten. Echoes the meta race back;
// RaceSaved refills gpxText from the in-model race.
async function saveRaceMeta(race) {
  const db = await dbPromise
  return new Promise((resolve, reject) => {
    const tx = db.transaction(RACES_STORE, 'readwrite')
    tx.objectStore(RACES_STORE).put(race)
    tx.oncomplete = () => resolve(race)
    tx.onerror = () => reject(tx.error)
  })
}

async function deleteRace(id) {
  const db = await dbPromise
  return new Promise((resolve, reject) => {
    // Delete both rows so a removed race doesn't orphan its (~3 MB) gpx row.
    const tx = db.transaction([RACES_STORE, GPX_STORE], 'readwrite')
    tx.objectStore(RACES_STORE).delete(id)
    tx.objectStore(GPX_STORE).delete(id)
    tx.oncomplete = () => resolve(id)
    tx.onerror = () => reject(tx.error)
  })
}

async function loadProfile() {
  const db = await dbPromise
  return new Promise((resolve, reject) => {
    const tx = db.transaction(SETTINGS_STORE, 'readonly')
    const req = tx.objectStore(SETTINGS_STORE).get(ACTIVE_PROFILE_KEY)
    req.onsuccess = () => resolve(req.result ? req.result.value : null)
    req.onerror = () => reject(req.error)
  })
}

async function saveProfile(value) {
  const db = await dbPromise
  return new Promise((resolve, reject) => {
    const tx = db.transaction(SETTINGS_STORE, 'readwrite')
    tx.objectStore(SETTINGS_STORE).put({ key: ACTIVE_PROFILE_KEY, value })
    tx.oncomplete = () => resolve(value)
    tx.onerror = () => reject(tx.error)
  })
}

async function loadStravaToken() {
  const db = await dbPromise
  return new Promise((resolve, reject) => {
    const tx = db.transaction(SETTINGS_STORE, 'readonly')
    const req = tx.objectStore(SETTINGS_STORE).get(STRAVA_TOKEN_KEY)
    req.onsuccess = () => resolve(req.result ? req.result.value : null)
    req.onerror = () => reject(req.error)
  })
}

async function saveStravaToken(token) {
  const db = await dbPromise
  return new Promise((resolve, reject) => {
    const tx = db.transaction(SETTINGS_STORE, 'readwrite')
    if (token) {
      tx.objectStore(SETTINGS_STORE).put({ key: STRAVA_TOKEN_KEY, value: token })
    } else {
      tx.objectStore(SETTINGS_STORE).delete(STRAVA_TOKEN_KEY)
    }
    tx.oncomplete = () => resolve(token)
    tx.onerror = () => reject(tx.error)
  })
}

// Device identity bundle ({me, directory}) in its own store (WI-5 / TASK-054).
// One row keyed IDENTITY_KEY; null until the first mint. Mirrors the
// settings-style single-row load/save.
async function loadIdentity() {
  const db = await dbPromise
  // Degrade gracefully if the store is somehow absent (it shouldn't be, given
  // the version-bump heal above) — "no identity yet" rather than a boot error.
  if (!db.objectStoreNames.contains(IDENTITY_STORE)) return null
  return new Promise((resolve, reject) => {
    const tx = db.transaction(IDENTITY_STORE, 'readonly')
    const req = tx.objectStore(IDENTITY_STORE).get(IDENTITY_KEY)
    req.onsuccess = () => resolve(req.result ? req.result.value : null)
    req.onerror = () => reject(req.error)
  })
}

async function saveIdentity(value) {
  const db = await dbPromise
  return new Promise((resolve, reject) => {
    const tx = db.transaction(IDENTITY_STORE, 'readwrite')
    tx.objectStore(IDENTITY_STORE).put({ key: IDENTITY_KEY, value })
    tx.oncomplete = () => resolve(value)
    tx.onerror = () => reject(tx.error)
  })
}

// ============================================================
// Capture ?token=… from the OAuth callback URL before Elm boots.
// Cadence's callback redirects to FRONTEND_URL_TRAIL?token=… so
// we have to handle the query string at the JS layer; trail's
// hash router doesn't see ?query.
// ============================================================

const callbackUrl = new URL(window.location.href)
const incomingStravaToken = callbackUrl.searchParams.get('token')
if (incomingStravaToken) {
  callbackUrl.searchParams.delete('token')
  history.replaceState({}, '', callbackUrl.toString())
}

// Stable per-device id (TASK-049): tags newly minted aid-station ids so two
// independently-edited copies of a race don't collide on the shared per-race
// counter, and is the author identity WI-3/WI-4 reuse. localStorage (not IDB)
// because Elm needs it synchronously at boot, via flags; it's a device
// fingerprint, not race data.
let deviceId = localStorage.getItem('trail.deviceId')
if (!deviceId) {
  deviceId = crypto.randomUUID()
  localStorage.setItem('trail.deviceId', deviceId)
}

// ============================================================
// Elm boot + port wiring
// ============================================================

const app = Elm.Main.init({
  flags: {
    width: window.innerWidth,
    now: Date.now(),
    incomingStravaToken: incomingStravaToken,
    backendUrl: BACKEND_URL,
    deviceId: deviceId,
  },
})

app.ports.storageLoadAll.subscribe(async () => {
  try {
    const races = await loadAllRaces()
    app.ports.storageRacesLoaded.send(races)
  } catch (e) {
    app.ports.storageError.send(`loadAll: ${e?.message || e}`)
  }
})

app.ports.storageSave.subscribe(async (race) => {
  try {
    const saved = await saveRace(race)
    app.ports.storageRaceSaved.send(saved)
  } catch (e) {
    app.ports.storageError.send(`save: ${e?.message || e}`)
  }
})

app.ports.storageSaveMeta.subscribe(async (race) => {
  try {
    const saved = await saveRaceMeta(race)
    app.ports.storageRaceSaved.send(saved)
  } catch (e) {
    app.ports.storageError.send(`saveMeta: ${e?.message || e}`)
  }
})

app.ports.storageDelete.subscribe(async (id) => {
  try {
    await deleteRace(id)
    app.ports.storageRaceDeleted.send(id)
  } catch (e) {
    app.ports.storageError.send(`delete: ${e?.message || e}`)
  }
})

app.ports.storageLoadProfile.subscribe(async () => {
  try {
    const profile = await loadProfile()
    app.ports.storageProfileLoaded.send(profile)
  } catch (e) {
    app.ports.storageError.send(`loadProfile: ${e?.message || e}`)
  }
})

app.ports.storageSaveProfile.subscribe(async (profile) => {
  try {
    await saveProfile(profile)
    app.ports.storageProfileLoaded.send(profile)
  } catch (e) {
    app.ports.storageError.send(`saveProfile: ${e?.message || e}`)
  }
})

app.ports.storageLoadStravaToken.subscribe(async () => {
  try {
    const token = await loadStravaToken()
    app.ports.storageStravaTokenLoaded.send(token)
  } catch (e) {
    app.ports.storageError.send(`loadStravaToken: ${e?.message || e}`)
  }
})

app.ports.storageSaveStravaToken.subscribe(async (token) => {
  try {
    await saveStravaToken(token)
    app.ports.storageStravaTokenLoaded.send(token)
  } catch (e) {
    app.ports.storageError.send(`saveStravaToken: ${e?.message || e}`)
  }
})

// Guard the identity subscriptions: an outgoing Elm port that isn't *used* yet
// (here `storageSaveIdentity` — saving identity lands with the WI-5 flows slice)
// is stripped by Elm's dead-code elimination, so `app.ports.storageSaveIdentity`
// is `undefined` and an unguarded `.subscribe` would throw and abort the rest of
// the port wiring (downloadFile, print, …). The guard wires each only once Elm
// actually exposes it; when the flows slice uses `saveIdentity`, it lights up.
if (app.ports.storageLoadIdentity) {
  app.ports.storageLoadIdentity.subscribe(async () => {
    try {
      const identity = await loadIdentity()
      app.ports.storageIdentityLoaded.send(identity)
    } catch (e) {
      app.ports.storageError.send(`loadIdentity: ${e?.message || e}`)
    }
  })
}

if (app.ports.storageSaveIdentity) {
  app.ports.storageSaveIdentity.subscribe(async (identity) => {
    try {
      await saveIdentity(identity)
      app.ports.storageIdentityLoaded.send(identity)
    } catch (e) {
      app.ports.storageError.send(`saveIdentity: ${e?.message || e}`)
    }
  })
}

app.ports.downloadFile.subscribe(({ filename, content, mime }) => {
  const blob = new Blob([content], { type: mime || 'application/octet-stream' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.style.display = 'none'
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  // Give the browser a tick to start the download before we revoke.
  setTimeout(() => URL.revokeObjectURL(url), 250)
})

app.ports.pickImageFilePort.subscribe(() => {
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = 'image/*'
  input.style.display = 'none'
  document.body.appendChild(input)
  input.onchange = () => {
    const file = input.files && input.files[0]
    document.body.removeChild(input)
    if (!file) return
    const reader = new FileReader()
    reader.onload = () => {
      app.ports.imagePickedAsDataUrl.send(reader.result)
    }
    reader.onerror = () => {
      app.ports.storageError.send(`image read: ${reader.error?.message || 'unknown error'}`)
    }
    reader.readAsDataURL(file)
  }
  input.click()
})

app.ports.print.subscribe(() => {
  // The plan page's @media print rules (app.css) strip the app chrome and
  // render the plan table for paper; this just opens the print dialog.
  window.print()
})

app.ports.scrollIntoView.subscribe((id) => {
  // Defer to the next frame so Elm has rendered the target element
  // (e.g. the aid-station form that just opened) before we scroll.
  requestAnimationFrame(() => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  })
})

// ============================================================
// Service worker registration (production only).
//
// Vite's dev server serves via HMR — caching it would break the
// reload-after-edit loop. import.meta.env.PROD is true only in
// `vite build`'s output.
// ============================================================

if (import.meta.env.PROD && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch((err) => {
      console.warn('Trail SW registration failed:', err)
    })
  })
}
