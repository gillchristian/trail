import './styles/app.css'
import { Elm } from './Main.elm'

// ============================================================
// IndexedDB wrapper
// ============================================================

const DB_NAME = 'trail'
const DB_VERSION = 1
const RACES_STORE = 'races'

const dbPromise = new Promise((resolve, reject) => {
  const req = indexedDB.open(DB_NAME, DB_VERSION)
  req.onupgradeneeded = () => {
    const db = req.result
    if (!db.objectStoreNames.contains(RACES_STORE)) {
      db.createObjectStore(RACES_STORE, { keyPath: 'id' })
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
