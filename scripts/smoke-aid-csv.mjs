// Smoke test for src/AidCsv.elm — drives the REAL compiled Elm parser +
// encoder from Node through a Platform.worker harness
// (src/AidCsvHarness.elm). Verifies parsing, unit handling, partial
// import, CSV quoting/BOM/CRLF, the ; delimiter, warnings, and the
// toCsv -> parse round-trip, all without a browser.
//
// Run with: node scripts/smoke-aid-csv.mjs

import { execFileSync } from 'node:child_process'
import { readFileSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')

// 1. Compile the harness with the project's elm toolchain.
const tmp = mkdtempSync(join(tmpdir(), 'aidcsv-'))
const out = join(tmp, 'harness.js')
try {
  execFileSync('npx', ['--no-install', 'elm', 'make', 'src/AidCsvHarness.elm', '--output', out], {
    cwd: repoRoot,
    stdio: ['ignore', 'ignore', 'inherit'],
  })
} catch (e) {
  console.error('elm make failed for the harness')
  process.exit(1)
}

// 2. Evaluate the Elm IIFE, capturing `this.Elm` into a scope object.
const code = readFileSync(out, 'utf8')
const scope = {}
new Function(code).call(scope)
rmSync(tmp, { recursive: true, force: true })
const Elm = scope.Elm
const app = Elm.AidCsvHarness.init()

// 3. Promise wrapper over the run/result port pair (one in flight at a time).
let resolveNext = null
app.ports.result.subscribe((r) => {
  const f = resolveNext
  resolveNext = null
  if (f) f(r)
})
const call = (req) => new Promise((res) => { resolveNext = res; app.ports.run.send(req) })

// ---- assertion helpers ----
let failures = 0
const check = (label, cond, detail) => {
  if (cond) console.log(`  ok   ${label}`)
  else { failures++; console.log(`  FAIL ${label}${detail ? ' — ' + detail : ''}`) }
}
const eqJson = (a, b) => JSON.stringify(a) === JSON.stringify(b)

const run = async () => {
  // --- A: happy path, header, km, services, cutoff ---
  {
    const csv = [
      'name,distance_km,rest_min,services,cutoff,notes',
      'Start Refugio,12.4,5,water|food,2:30,bring poles',
      'Col du Truc,27,10,water|food|wc,5:45:00,',
      'Finish,42.2,0,,,',
    ].join('\n')
    const { result } = await call({ op: 'parse', csv, totalDistance: 42200, defaultRestSeconds: 180 })
    console.log('A: happy path (header, km)')
    check('3 stations', result.stations.length === 3, `got ${result.stations.length}`)
    check('no errors', result.errors.length === 0, JSON.stringify(result.errors))
    const s = result.stations
    check('distances m', eqJson(s.map((x) => Math.round(x.distanceM)), [12400, 27000, 42200]))
    check('rest seconds', eqJson(s.map((x) => x.restSeconds), [300, 600, 0]))
    check('services row1', eqJson(s[0].services, ['water', 'food']))
    check('services row2', eqJson(s[1].services, ['water', 'food', 'wc']))
    check('cutoff 2:30 -> 9000s', s[0].cutoff === 9000, String(s[0].cutoff))
    check('cutoff 5:45:00 -> 20700s', s[1].cutoff === 20700, String(s[1].cutoff))
    check('finish cutoff null', s[2].cutoff === null)
    check('notes row1', s[0].notes === 'bring poles')
  }

  // --- B: miles header, default rest, partial import ---
  {
    const csv = [
      'Station,Mile,Services',
      'Hualapai,30.6,water/food',
      'BadDist,not-a-number,water',
      'Whiskey Row,?,food',
      'Deep Mile,9999,water',
    ].join('\n')
    const { result } = await call({ op: 'parse', csv, totalDistance: 80467, defaultRestSeconds: 180 })
    console.log('B: miles + partial import')
    check('1 valid station', result.stations.length === 1, `got ${result.stations.length}`)
    check('3 errors', result.errors.length === 3, JSON.stringify(result.errors.map((e) => e.row)))
    check('miles converted', Math.round(result.stations[0].distanceM) === Math.round(30.6 * 1609.344))
    check('default rest applied', result.stations[0].restSeconds === 180)
    check('error rows are 2,3,4', eqJson(result.errors.map((e) => e.row), [2, 3, 4]))
  }

  // --- C: no header (positional), km, cutoff + empties default ---
  {
    const csv = ['Aid 1,5,3,water,1:00,first', 'Aid 2,10,,food|wc,,second'].join('\n')
    const { result } = await call({ op: 'parse', csv, totalDistance: 11000, defaultRestSeconds: 120 })
    console.log('C: positional (no header)')
    check('2 stations', result.stations.length === 2, `got ${result.stations.length}`)
    check('no errors', result.errors.length === 0, JSON.stringify(result.errors))
    check('row1 rest 180', result.stations[0].restSeconds === 180)
    check('row2 empty rest -> default 120', result.stations[1].restSeconds === 120)
    check('row1 cutoff 3600', result.stations[0].cutoff === 3600)
    check('row2 cutoff null', result.stations[1].cutoff === null)
    check('row2 services', eqJson(result.stations[1].services, ['food', 'wc']))
  }

  // --- D: BOM + CRLF + quoted comma + doubled quotes ---
  {
    const csv =
      '﻿' +
      'name,distance_km,notes\r\n' +
      '"Refugio, Le Tour",12.4,"He said ""go"""\r\n' +
      'Plain,20,simple\r\n'
    const { result } = await call({ op: 'parse', csv, totalDistance: 42000, defaultRestSeconds: 180 })
    console.log('D: BOM / CRLF / quoting')
    check('2 stations', result.stations.length === 2, `got ${result.stations.length}`)
    check('quoted comma in name', result.stations[0].name === 'Refugio, Le Tour', result.stations[0].name)
    check('doubled-quote in notes', result.stations[0].notes === 'He said "go"', result.stations[0].notes)
    check('BOM stripped (first col is name)', Math.round(result.stations[0].distanceM) === 12400)
  }

  // --- E: semicolon delimiter + decimal comma ---
  {
    const csv = ['name;distance_km;services', 'Aid A;12,5;water|food'].join('\r\n')
    const { result } = await call({ op: 'parse', csv, totalDistance: 20000, defaultRestSeconds: 180 })
    console.log('E: semicolon delimiter')
    check('1 station', result.stations.length === 1, `got ${result.stations.length}`)
    check('decimal comma -> 12.5 km', Math.round(result.stations[0].distanceM) === 12500, String(result.stations[0].distanceM))
    check('services split', eqJson(result.stations[0].services, ['water', 'food']))
  }

  // --- F: warnings (unknown service + bad cutoff) but row still imports ---
  {
    const csv = ['name,distance_km,services,cutoff', 'Aid X,10,water|unicorn,nope'].join('\n')
    const { result } = await call({ op: 'parse', csv, totalDistance: 20000, defaultRestSeconds: 180 })
    console.log('F: warnings, row still imports')
    check('1 station imported', result.stations.length === 1)
    check('services keeps known only', eqJson(result.stations[0].services, ['water']))
    check('cutoff dropped to null', result.stations[0].cutoff === null)
    check('1 warning on row 1', result.warnings.length === 1 && result.warnings[0].row === 1, JSON.stringify(result.warnings))
    check('warning mentions unicorn', /unicorn/.test(result.warnings[0].message), result.warnings[0]?.message)
  }

  // --- G: round-trip (parse -> toCsv -> parse) preserves the data ---
  {
    const csv = [
      'name,distance_km,rest_min,services,cutoff,notes',
      'Start Refugio,12.4,5,water|food,2:30,"bring, poles"',
      'Col du Truc,27,7.5,water|food|wc,5:45:00,',
    ].join('\n')
    const { csv: exported, result } = await call({ op: 'roundtrip', csv, totalDistance: 42200, defaultRestSeconds: 180 })
    console.log('G: round-trip via toCsv')
    check('still 2 stations', result.stations.length === 2, `got ${result.stations.length}`)
    check('names survive (incl. comma)', eqJson(result.stations.map((x) => x.name), ['Start Refugio', 'Col du Truc']))
    check('distances survive', eqJson(result.stations.map((x) => Math.round(x.distanceM)), [12400, 27000]))
    check('rest survives (7.5 min = 450s)', result.stations[1].restSeconds === 450, String(result.stations[1].restSeconds))
    check('services survive', eqJson(result.stations[0].services, ['water', 'food']))
    check('cutoff survives', eqJson(result.stations.map((x) => x.cutoff), [9000, 20700]))
    check('export has header', exported.split(/\r?\n/)[0] === 'name,distance_km,rest_min,services,cutoff,notes')
    check('comma name is quoted in export', /"bring, poles"/.test(exported), exported)
  }

  // --- H: the shipped sample file parses cleanly ---
  {
    const csv = readFileSync(resolve(repoRoot, 'samples/aid-stations-example.csv'), 'utf8')
    const { result } = await call({ op: 'parse', csv, totalDistance: 21000, defaultRestSeconds: 180 })
    console.log('H: samples/aid-stations-example.csv')
    check('5 stations', result.stations.length === 5, `got ${result.stations.length}`)
    check('no errors', result.errors.length === 0, JSON.stringify(result.errors))
    check('no warnings', result.warnings.length === 0, JSON.stringify(result.warnings))
    check('a station has warm_food', result.stations.some((s) => s.services.includes('warm_food')))
  }

  // --- I: warm food is its own category, with token aliases ---
  {
    const csv = [
      'name,distance_km,services',
      'A,5,warm food',
      'B,10,soup',
      'C,15,Hot Food',
      'D,18,food|warm food',
    ].join('\n')
    const { result } = await call({ op: 'parse', csv, totalDistance: 20000, defaultRestSeconds: 180 })
    console.log('I: warm food category + aliases')
    check('4 stations, no warnings', result.stations.length === 4 && result.warnings.length === 0, JSON.stringify(result.warnings))
    check('"warm food" -> warm_food', eqJson(result.stations[0].services, ['warm_food']))
    check('"soup" -> warm_food', eqJson(result.stations[1].services, ['warm_food']))
    check('"Hot Food" -> warm_food (case-insensitive)', eqJson(result.stations[2].services, ['warm_food']))
    check('distinct from food', eqJson(result.stations[3].services, ['food', 'warm_food']))
  }

  console.log('')
  if (failures === 0) {
    console.log('PASS — all aid-csv checks green')
    process.exit(0)
  } else {
    console.log(`FAIL — ${failures} check(s) failed`)
    process.exit(1)
  }
}

run()
