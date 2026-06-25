# Swift / SwiftUI orientation (for track)

A fast on-ramp for building track, written for someone who knows **Elm** (trail) and **Go**
(gateway) but is new to Swift/iOS. The goal: enough to read and write the WI-1 skeleton confidently.
It is anchored to track's own domain (`mvp-plan.md` §4), so it doubles as a design primer.

> The single biggest mental shift from Elm is in **Part 2**: SwiftUI has no explicit
> `Msg`/`update`. You mutate state in place and the framework re-renders. Read that part slowly.

## Mental-model bridge

| You know (Elm / Go)                         | Swift                                            |
|---------------------------------------------|--------------------------------------------------|
| Elm custom type `type T = A \| B Int`        | `enum T { case a; case b(Int) }` (assoc. values) |
| Elm `Maybe a`                                | `Optional<T>` written `T?`                       |
| Elm record / Go struct (value)              | `struct` (value type — copied, not shared)       |
| Go pointer / shared mutable object          | `class` (reference type)                         |
| Elm `case … of` (exhaustive)                | `switch` (exhaustive; compiler enforces)         |
| Elm decoders/encoders (`Json.Decode`)       | `Codable` (compiler-**synthesized**, no boilerplate) |
| Go interface / Elm typeclass-ish constraint | `protocol`                                       |
| Elm `let x = …` (immutable)                 | `let` (immutable) vs `var` (mutable)             |
| Go `if err != nil`                          | `do { try … } catch { … }` + typed `throws`      |
| Elm `view : Model -> Html Msg`              | a `View` struct's `body` (declarative, like Elm) |
| Elm MVU (`Msg` → `update` → new `Model`)    | **gone** — mutate `@State`/`@Observable` directly |

## Part 1 — Swift the language

**Value types are the default, and that's a feature.** `struct` and `enum` are *value types*: copied
on assignment, no shared mutable aliasing — exactly Elm's model. Use them for data (the whole domain
model in `mvp-plan.md` §4 is structs + enums). `class` is a *reference type* (shared, like a Go
pointer); reach for it only when you need identity/sharing — in SwiftUI that's mainly the
`@Observable` store (Part 2).

```swift
let id = UUID()        // immutable binding (like Elm `let`)
var count = 0          // mutable; count += 1 is fine
```

**Optionals = `Maybe`.** `T?` is `.some(T)` or `nil`. You must unwrap before use:

```swift
var date: Date?                       // optional (the race's scheduled date)
if let date = race.date { use(date) } // safe unwrap (like `case Just d ->`)
let shown = race.date ?? Date()       // ?? is Elm's Maybe.withDefault
```

**Enums with associated values = Elm custom types.** This is the heart of the event log:

```swift
enum RaceEventKind: Codable {
    case raceStarted
    case intake(trackableID: UUID?, label: String)
    case aidStationEntered(visitID: UUID, ordinal: Int?, label: String)
    case retraction(target: UUID)
}
```

**`switch` is exhaustive** — the compiler forces you to handle every case (just like Elm), which is
how the projections (status / effectiveEnd / visit fold) stay total:

```swift
switch event.kind {
case .raceStarted:                       startSeen = true
case .intake(_, let label):              counts[label, default: 0] += 1
case .aidStationEntered(let v, _, _):    openVisit = v
case .retraction(let target):            retracted.insert(target)
}   // no `default:` needed — add a case and the compiler flags every switch
```

**`Codable` replaces hand-written decoders.** Conform a type to `Codable` and Swift synthesizes
JSON encode/decode for free — *including* enums with associated values (Swift 5.5+). This is why the
append-only log is cheap: `JSONEncoder().encode(event)` → one line; `JSONDecoder().decode(...)` folds
it back. (Verified on this machine — see `local-ci.md`.)

**Protocols** are interfaces. You already use three: `Identifiable` (has `var id`), `Codable`,
`Equatable`. Conformance is just `struct Race: Identifiable, Codable { … }`.

**Errors are typed and explicit** (no exceptions-by-surprise). A function that can fail is marked
`throws`; callers must `try` it inside `do/catch`. This is the durability spine:

```swift
func append(_ event: RaceEvent) throws {
    let line = try JSONEncoder().encode(event) + Data("\n".utf8)
    let fh = try FileHandle(forWritingTo: logURL)
    defer { try? fh.close() }            // `defer` runs on scope exit (like Go `defer`)
    try fh.seekToEnd()
    try fh.write(contentsOf: line)
    try fh.synchronize()                 // ← fsync: the "resilient to shutdown" guarantee
}
```

**Closures** are anonymous functions; the *trailing-closure* syntax (`foo { … }`) is everywhere in
SwiftUI. `palette.map { $0.label }` — `$0` is the first arg. Generics exist (`Array<T>`); you'll
mostly *use* them, rarely write them early.

## Part 2 — SwiftUI (the part that differs most from Elm)

**A view is a `struct` conforming to `View`, with a `body`** — declarative, like Elm's `view`:

```swift
struct ContentView: View {
    var body: some View {            // `some View` = "an opaque concrete View"
        Text("Hello, race")
    }
}
```

**State: there is no `Msg`/`update`.** In Elm you return a new `Model`; in SwiftUI you **mutate
state in place** and the framework re-runs `body`. The "messages" are just closures (e.g. a button's
action) that mutate state.

- `@State` — local, view-owned state (value types). Mutating it re-renders.
- `@Binding` — a two-way reference to someone else's `@State` (pass a text field a `$value`).
- `@Observable` (iOS 17) — a `class` holding shared app state; mutating its properties re-renders
  every view reading them. This is track's `RaceStore` (the races list + the active log).
- `@Environment` — dependency injection down the view tree.

```swift
@Observable class RaceStore {
    var races: [Race] = []
    func track(_ item: TrackableElement, in race: Race) { /* append + fsync */ }
}

struct NutritionGrid: View {
    @State private var store = RaceStore()
    let palette: [TrackableElement]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
            ForEach(palette) { item in
                Button(item.label) { store.track(item, in: currentRace) }  // ← the "Msg": a closure
            }
        }
    }
}
```

**App entry point** (the `@main` is your `Browser.application`):

```swift
@main
struct TrackApp: App {
    var body: some Scene { WindowGroup { RacesView() } }   // root view
}
```

**Navigation + lists** (WI-1 is essentially this):

```swift
NavigationStack {
    List(store.races) { race in
        NavigationLink(race.name, value: race)
    }
    .navigationTitle("Races")
    .navigationDestination(for: Race.self) { race in RaceDetailView(race: race) }
}
```

**Screen mapping (track):** Races list → `NavigationStack` + `List`. Tracking view's four cyclic
tabs → `TabView(selection:)` with swipe paging. Nutrition/Others grids → `LazyVGrid` of `Button`s.
AID tab → a `List` of visit rows. Feed → a read-only `List`. Record button / Undo toast → overlays
(`.overlay(alignment:)`). System light/dark is automatic; the Trail-styled palette becomes a small
`Color` theme (see `project-brief.md` → Visual design).

## Part 3 — iOS realities for track

- **Sandbox + Documents dir.** Each app gets a private container. The race bundles live under
  Documents: `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]`.
- **The two write paths (mvp-plan §3):** append-only `events.log` via `FileHandle` +
  `synchronize()` (fsync per append); `race.json` via `try data.write(to: url, options: .atomic)`
  (temp-write + rename under the hood). Write **audio file → fsync → then** append the referencing
  event (the safe failure direction).
- **No background work.** iOS may suspend/kill the app between taps — track *wants* that: each action
  is open → append a `Date()`-stamped event → fsync → done. Elapsed time is derived from the stored
  start timestamp, never a running timer. This erases the whole background-mode surface.

## Part 4 — what TRACK-001 (WI-1) looks like

The skeleton is small: the `@main App`, a `NavigationStack` + empty `List` "Races" root, a
`RaceStore` (`@Observable`), and the persistence root dir created on launch. Acceptance = it
launches, shows an empty list, and a stub race persists + survives relaunch. Everything in Part 1's
domain snippets is WI-2; keep WI-1 to the shell.

## Resources

- **The Swift Programming Language** (official, free): https://docs.swift.org/swift-book/ — read
  *The Basics*, *Optionals*, *Enumerations*, *Structures and Classes*, *Protocols*, *Error Handling*.
- **SwiftUI tutorials** (Apple): https://developer.apple.com/tutorials/swiftui — do *Creating and
  Combining Views* + *Building Lists and Navigation*.
- **Hacking with Swift** (100 Days of SwiftUI): https://www.hackingwithswift.com/100/swiftui — the
  best beginner path; the early days cover exactly Part 1 + Part 2.
- **Codable deep dive:** https://www.swiftbysundell.com/basics/codable/
