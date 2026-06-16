// Smoke test for the Identity module (WI-5 / TASK-054, ADR-0012) — drives the
// REAL compiled Elm (src/IdentityHarness.elm) from Node. Proves the pure core:
//   - the name last-write-wins register: a strictly-newer name wins; an older or
//     tied one is ignored (importing a stale file never reverts a name);
//   - mergeDirectory is an LWW union keyed by userId;
//   - the import decision: a file you own imports silently, anything else asks;
//   - resolveOwnership encodes the mint discipline (yourself = adopt, never mint;
//     someone-else with no identity = mint-then-review; else review as me);
//   - subsetFor keeps only referenced ids (what the .trail denormalizes);
//   - me + directory round-trip through the codecs.
//
// Run with: node scripts/smoke-identity.mjs

import { execFileSync } from 'node:child_process'
import { readFileSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')

const tmp = mkdtempSync(join(tmpdir(), 'identity-'))
const out = join(tmp, 'harness.js')
try {
  execFileSync('npx', ['--no-install', 'elm', 'make', 'src/IdentityHarness.elm', '--output', out], {
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
const app = scope.Elm.IdentityHarness.init()

let resolveNext = null
app.ports.result.subscribe((r) => { const f = resolveNext; resolveNext = null; if (f) f(r) })
const call = (req) => new Promise((res) => { resolveNext = res; app.ports.run.send(req) })

let failures = 0
const check = (label, cond, detail) => {
  if (cond) console.log(`  ok   ${label}`)
  else { failures++; console.log(`  FAIL ${label}${detail !== undefined ? ' — ' + detail : ''}`) }
}

// directory entry shorthand: the serialized {userId, displayName, nameUpdatedAt} shape
const e = (userId, name, at) => ({ userId, displayName: name, nameUpdatedAt: at })

const run = async () => {
  console.log('learn: last-write-wins on displayName, keyed by userId, ordered by nameUpdatedAt')
  {
    const empty = await call({ op: 'learn', dir: [], userId: 'u1', displayName: 'Alex', nameUpdatedAt: 100 })
    check('into empty → name set', empty.name === 'Alex' && empty.at === 100, JSON.stringify(empty))

    const newer = await call({ op: 'learn', dir: [e('u1', 'Alex', 100)], userId: 'u1', displayName: 'Alexandra', nameUpdatedAt: 200 })
    check('newer wins', newer.name === 'Alexandra' && newer.at === 200, JSON.stringify(newer))

    const older = await call({ op: 'learn', dir: [e('u1', 'Alexandra', 200)], userId: 'u1', displayName: 'Alex', nameUpdatedAt: 100 })
    check('older ignored (no revert)', older.name === 'Alexandra' && older.at === 200, JSON.stringify(older))

    const tie = await call({ op: 'learn', dir: [e('u1', 'Alexandra', 200)], userId: 'u1', displayName: 'Other', nameUpdatedAt: 200 })
    check('tie keeps existing', tie.name === 'Alexandra' && tie.at === 200, JSON.stringify(tie))
  }

  console.log('merge: LWW union of two directories')
  {
    const local = [e('u1', 'Alex', 100), e('u2', 'Sam', 100)]
    const incoming = [e('u1', 'Alexandra', 200), e('u3', 'Coachy', 150)] // u1 newer, u3 new
    const r = await call({ op: 'merge', incoming, local })
    const byId = Object.fromEntries(r.pairs.map((p) => [p.userId, p]))
    check('all ids present (u1,u2,u3)', r.pairs.length === 3, JSON.stringify(r.pairs.map((p) => p.userId)))
    check('u1 takes the newer name', byId.u1.name === 'Alexandra' && byId.u1.at === 200)
    check('u2 (local-only) preserved', byId.u2.name === 'Sam')
    check('u3 (incoming-only) learned', byId.u3.name === 'Coachy')
  }
  {
    // an OLDER incoming entry must not clobber a newer local one
    const r = await call({ op: 'merge', incoming: [e('u1', 'Stale', 50)], local: [e('u1', 'Fresh', 100)] })
    check('older incoming does not revert', r.pairs[0].name === 'Fresh' && r.pairs[0].at === 100, JSON.stringify(r.pairs))
  }

  console.log('decideImport: only a file you own imports silently')
  {
    check('no identity → ask', (await call({ op: 'decide', me: null, fileOwner: 'u1' })).decision === 'askOwnership')
    check('owner == me → import as owner', (await call({ op: 'decide', me: { userId: 'u1', displayName: 'Me' }, fileOwner: 'u1' })).decision === 'importAsOwner')
    check('owner != me → ask', (await call({ op: 'decide', me: { userId: 'u1', displayName: 'Me' }, fileOwner: 'u2' })).decision === 'askOwnership')
  }

  console.log('resolveOwnership: the mint discipline (yourself adopts, never mints)')
  {
    const adopt = await call({ op: 'ownership', answer: 'myself', me: null, fileOwner: 'u9' })
    check('yourself + no identity → adopt the file owner id', adopt.result === 'adopt' && adopt.adopt === 'u9', JSON.stringify(adopt))

    const adopt2 = await call({ op: 'ownership', answer: 'myself', me: { userId: 'u1', displayName: 'Me' }, fileOwner: 'u9' })
    check('yourself + have identity → still adopt (device-link)', adopt2.result === 'adopt' && adopt2.adopt === 'u9', JSON.stringify(adopt2))

    const mint = await call({ op: 'ownership', answer: 'someoneElse', me: null, fileOwner: 'u9' })
    check('someone-else + no identity → mint then review', mint.result === 'mintThenReview', JSON.stringify(mint))

    const review = await call({ op: 'ownership', answer: 'someoneElse', me: { userId: 'u1', displayName: 'Coach' }, fileOwner: 'u9' })
    check('someone-else + have identity → review as me', review.result === 'reviewAs' && review.name === 'Coach', JSON.stringify(review))
  }

  console.log('subsetFor: only referenced ids (what the .trail denormalizes)')
  {
    const r = await call({ op: 'subset', ids: ['u1', 'u3', 'ghost'], dir: [e('u1', 'A', 1), e('u2', 'B', 1), e('u3', 'C', 1)] })
    check('keeps referenced + drops unknown', JSON.stringify(r.ids) === JSON.stringify(['u1', 'u3']), JSON.stringify(r.ids))
  }

  console.log('codec: me + directory round-trip')
  {
    const r = await call({ op: 'codec', me: { userId: 'u1', displayName: 'Álex' }, dir: [e('u2', 'Sam', 7), e('u1', 'Álex', 9)] })
    check('me survives', r.me && r.me.userId === 'u1' && r.me.displayName === 'Álex', JSON.stringify(r.me))
    check('directory survives (2 entries)', r.dir.length === 2)
    const nullMe = await call({ op: 'codec', me: null, dir: [] })
    check('null me round-trips as null', nullMe.me === null, JSON.stringify(nullMe.me))
  }

  console.log('')
  if (failures === 0) {
    console.log('PASS — identity LWW + import decision + codecs hold')
    process.exit(0)
  } else {
    console.log(`FAIL — ${failures} check(s) failed`)
    process.exit(1)
  }
}

run()
