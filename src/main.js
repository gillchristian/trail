import './styles/app.css'
import './leaflet-element.js'
import { Elm } from './Main.elm'

// ============================================================
// IndexedDB wrapper
// ============================================================

const DB_NAME = 'trail'
const DB_VERSION = 2
const RACES_STORE = 'races'
const SETTINGS_STORE = 'settings'
const ACTIVE_PROFILE_KEY = 'activeProfile'

const dbPromise = new Promise((resolve, reject) => {
  const req = indexedDB.open(DB_NAME, DB_VERSION)
  req.onupgradeneeded = () => {
    const db = req.result
    if (!db.objectStoreNames.contains(RACES_STORE)) {
      db.createObjectStore(RACES_STORE, { keyPath: 'id' })
    }
    if (!db.objectStoreNames.contains(SETTINGS_STORE)) {
      db.createObjectStore(SETTINGS_STORE, { keyPath: 'key' })
    }
  }
  req.onsuccess = () => resolve(req.result)
  req.onerror = () => reject(req.error)
})

async function loadAllRaces() {
  const db = await dbPromise
  return new Promise((resolve, reject) => {
    const tx = db.transaction(RACES_STORE, 'readonly')
    const req = tx.objectStore(RACES_STORE).getAll()
    req.onsuccess = () => resolve(req.result || [])
    req.onerror = () => reject(req.error)
  })
}

async function saveRace(race) {
  const db = await dbPromise
  const withId = { ...race, id: race.id || crypto.randomUUID() }
  return new Promise((resolve, reject) => {
    const tx = db.transaction(RACES_STORE, 'readwrite')
    tx.objectStore(RACES_STORE).put(withId)
    tx.oncomplete = () => resolve(withId)
    tx.onerror = () => reject(tx.error)
  })
}

async function deleteRace(id) {
  const db = await dbPromise
  return new Promise((resolve, reject) => {
    const tx = db.transaction(RACES_STORE, 'readwrite')
    tx.objectStore(RACES_STORE).delete(id)
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

// ============================================================
// Elm boot + port wiring
// ============================================================

const app = Elm.Main.init({
  flags: {
    width: window.innerWidth,
    now: Date.now(),
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
