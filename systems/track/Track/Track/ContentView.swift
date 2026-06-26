//
//  ContentView.swift
//  Track
//
//  Created by Christian Gill on 25/06/2026.
//
//  TRACK-001 (WI-1) — the project skeleton: a Races-list root over a minimal on-disk race
//  bundle. To avoid premature project.pbxproj surgery (ADR-0001 — keep the app a thin shell,
//  add files via Xcode), WI-1's few types live together in this one file; WI-2 splits the
//  domain model + durable persistence into their own files as it hardens them.
//

import SwiftUI

// MARK: - Theme

/// Trail-derived design tokens (project-brief.md → Visual design). WI-1 establishes the
/// layer; `amber` mirrors the app-wide accent in Assets.xcassets/AccentColor (what tints the
/// controls here). The other tokens are consumed by the grids / badges / tracking view in
/// later WIs, where the richer race-card styling lands.
enum Theme {
    static let ground  = Color(red: 2/255,   green: 6/255,   blue: 23/255)  // #020617 slate-950
    static let surface = Color(red: 11/255,  green: 11/255,  blue: 33/255)  // #0b0b21 deep navy
    static let amber   = Color(red: 251/255, green: 191/255, blue: 36/255)  // #fbbf24 primary glow
    static let raceRed = Color(red: 229/255, green: 46/255,  blue: 58/255)  // #E52E3A
    static let green   = Color(red: 34/255,  green: 197/255, blue: 94/255)  // #22c55e go / finish
}

// MARK: - Race (WI-1 stub model)

/// A deliberately minimal slice of the full domain model (mvp-plan.md §4): just enough to
/// prove a race persists and reloads. WI-2 grows this into the real `Race` (aidStations,
/// palette, planRef) alongside the append-only `events.log` and its projections.
struct Race: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

// MARK: - Persistence (WI-1 minimal)

/// Each race is a directory bundle under Documents/Races/<raceID>/ (mvp-plan.md §3). WI-1
/// writes only race.json, atomically (temp-write + rename). WI-2 adds the append-only
/// events.log (fsync per append) + the audio/ subdir and hardens error handling. The root is
/// injectable so tests can use a throwaway directory.
struct RaceStorage {
    let racesRoot: URL

    init(root: URL? = nil) {
        if let root {
            racesRoot = root
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            racesRoot = documents.appending(path: "Races", directoryHint: .isDirectory)
        }
        try? FileManager.default.createDirectory(at: racesRoot, withIntermediateDirectories: true)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private static let decoder = JSONDecoder()

    private func bundle(for id: UUID) -> URL {
        racesRoot.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    func save(_ race: Race) throws {
        let dir = bundle(for: race.id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(race)
        try data.write(to: dir.appending(path: "race.json"), options: .atomic)
    }

    func delete(_ race: Race) throws {
        try FileManager.default.removeItem(at: bundle(for: race.id))
    }

    /// Scan the bundle root, decoding each race.json. A single unreadable bundle is skipped
    /// rather than failing the whole listing. Newest first.
    func loadAll() -> [Race] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: racesRoot, includingPropertiesForKeys: nil)) ?? []
        let races = contents.compactMap { dir -> Race? in
            guard let data = try? Data(contentsOf: dir.appending(path: "race.json")) else { return nil }
            return try? Self.decoder.decode(Race.self, from: data)
        }
        return races.sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Store

/// Observable app state for the Races list (Swift's Observation: mutating its properties
/// re-renders the views reading them — see swift-orientation.md Part 2).
@Observable final class RaceStore {
    private(set) var races: [Race] = []
    private let storage: RaceStorage

    init(storage: RaceStorage = RaceStorage()) {
        self.storage = storage
        // UI-test hook: `-uitest-reset` starts from an empty bundle root (see TrackUITests).
        if CommandLine.arguments.contains("-uitest-reset") {
            for race in storage.loadAll() { try? storage.delete(race) }
        }
        races = storage.loadAll()
    }

    /// WI-1 placeholder for the real create-race flow (WI-4): persist a stub race so we can
    /// prove the bundle survives relaunch. WI-4 replaces this with the name/date/palette form.
    @discardableResult
    func addStubRace() -> Race {
        let race = Race(name: "Stub race \(races.count + 1)")
        do {
            try storage.save(race)
            races.insert(race, at: 0)   // newest first — matches loadAll()'s order
        } catch {
            print("Track: failed to save race \(race.id): \(error)")
        }
        return race
    }

    func delete(_ race: Race) {
        do {
            try storage.delete(race)
            races.removeAll { $0.id == race.id }
        } catch {
            print("Track: failed to delete race \(race.id): \(error)")
        }
    }

    func delete(at offsets: IndexSet) {
        offsets.map { races[$0] }.forEach(delete)
    }
}

// MARK: - Views

/// Root: the Races list (mvp-plan.md §6.1). WI-1 shows the list + an empty state and wires
/// `+` to a stub race; the status badge, duration, create form, and detail navigation are
/// later WIs (they need the events.log projections / the configure flow).
struct RacesView: View {
    @State private var store = RaceStore()

    var body: some View {
        NavigationStack {
            Group {
                if store.races.isEmpty {
                    EmptyRacesView()
                } else {
                    List {
                        ForEach(store.races) { race in
                            RaceRow(race: race)
                        }
                        .onDelete(perform: store.delete(at:))
                    }
                }
            }
            .navigationTitle("Races")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.addStubRace()
                    } label: {
                        Label("Add race", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addRace")
                }
            }
        }
    }
}

private struct EmptyRacesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 52))
                .foregroundStyle(Theme.amber)
            Text("No races yet")
                .font(.title3.weight(.semibold))
            Text("Tap + to add a race.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RaceRow: View {
    let race: Race

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(race.name)
                .font(.headline)
            Text(race.createdAt, format: .dateTime.year().month().day().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RacesView()
}
