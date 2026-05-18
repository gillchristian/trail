// Perf + correctness trace for the elevation-profile pipeline.
//
// Mimics the Elm-side `Gpx.parseGPX` + `Gpx.simplify` flow against
// any GPX file, dumping stats so we can sanity-check what a long
// course should produce (Cocodona 250, UTMB, etc.) without booting
// the browser.
//
// Run with:
//   node scripts/profile-trace.mjs <path/to/file.gpx> [mPerPx]
//
// Defaults to samples/cocodona_250.gpx at mPerPx=10 — the
// configuration that surfaced the SVG path-truncation bug fixed in
// PR #41.

import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const file = process.argv[2] ?? 'samples/cocodona_250.gpx'
const mPerPx = Number(process.argv[3] ?? 10)
const content = readFileSync(resolve(file), 'utf8')

const t0 = performance.now()

// Same regex as src/Gpx.elm:54 — <trkpt ...>...</trkpt>
const trkptRe = /<trkpt\s+([^>]*)>([\s\S]*?)<\/trkpt>/g
const attrRe = /(\w+)\s*=\s*"([^"]*)"/g
const eleRe = /<ele>\s*([^<]+)\s*<\/ele>/

const points = []
for (const m of content.matchAll(trkptRe)) {
  const attrs = m[1]
  const inner = m[2]
  const pairs = {}
  for (const a of attrs.matchAll(attrRe)) pairs[a[1]] = a[2]
  const lat = Number(pairs.lat)
  const lon = Number(pairs.lon)
  const eleM = eleRe.exec(inner)
  const ele = eleM ? Number(eleM[1].trim()) : 0
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue
  points.push({ lat, lon, ele })
}

const t1 = performance.now()

// Haversine cumulative distance.
const R = 6371000
const toRad = (d) => (d * Math.PI) / 180
function haversine(a, b) {
  const phi1 = toRad(a.lat)
  const phi2 = toRad(b.lat)
  const dPhi = toRad(b.lat - a.lat)
  const dLam = toRad(b.lon - a.lon)
  const h = Math.sin(dPhi / 2) ** 2 + Math.cos(phi1) * Math.cos(phi2) * Math.sin(dLam / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h))
}

const cumDist = [0]
for (let i = 1; i < points.length; i++) {
  cumDist.push(cumDist[i - 1] + haversine(points[i - 1], points[i]))
}
const totalDist = cumDist[cumDist.length - 1]

const t2 = performance.now()

// Iterative Douglas-Peucker on (cumDist, ele) pairs.
// Tolerance matches Profile.elm: mPerPx * 0.5.
const tol = mPerPx * 0.5
const profile = points.map((p, i) => [cumDist[i], p.ele])
const n = profile.length

function perpDist([ax, ay], [bx, by], [px, py]) {
  const dx = bx - ax
  const dy = by - ay
  const len = Math.hypot(dx, dy)
  if (len === 0) return Math.hypot(px - ax, py - ay)
  const cross = Math.abs((px - ax) * dy - (py - ay) * dx)
  return cross / len
}

const keep = new Set([0, n - 1])
const stack = [[0, n - 1]]
while (stack.length > 0) {
  const [a, b] = stack.pop()
  if (b - a < 2) continue
  const pa = profile[a]
  const pb = profile[b]
  let bestIdx = a
  let bestDist = 0
  for (let i = a + 1; i < b; i++) {
    const d = perpDist(pa, pb, profile[i])
    if (d > bestDist) { bestDist = d; bestIdx = i }
  }
  if (bestDist > tol) {
    keep.add(bestIdx)
    stack.push([a, bestIdx])
    stack.push([bestIdx, b])
  }
}

const keepArr = [...keep].sort((a, b) => a - b)
const t3 = performance.now()

const drawWidth = totalDist / mPerPx

console.log(`file:             ${file}`)
console.log(`mPerPx:           ${mPerPx} (DP tolerance ${tol} m)`)
console.log('---')
console.log(`parsed points:    ${points.length}`)
console.log(`totalDist:        ${(totalDist / 1000).toFixed(2)} km`)
console.log(`drawWidth @scale: ${drawWidth.toFixed(0)} px`)
console.log(`simplified count: ${keepArr.length}`)
console.log(`last kept index:  ${keepArr[keepArr.length - 1]} / ${n - 1}`)
console.log(`last kept dist:   ${(profile[keepArr[keepArr.length - 1]][0] / 1000).toFixed(2)} km`)
console.log('---')
console.log(`parse:            ${(t1 - t0).toFixed(1)} ms`)
console.log(`cumDist:          ${(t2 - t1).toFixed(1)} ms`)
console.log(`simplify:         ${(t3 - t2).toFixed(1)} ms`)
console.log(`total:            ${(t3 - t0).toFixed(1)} ms`)
