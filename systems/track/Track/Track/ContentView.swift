//
//  ContentView.swift
//  Track
//
//  Created by Christian Gill on 25/06/2026.
//
//  The SwiftUI layer: design tokens, the observable store, and the Races-list views. The
//  domain model, projections, and durable persistence live in TrackCore.swift (Foundation-
//  only) as of TRACK-002 (WI-2).
//

import SwiftUI

// MARK: - Theme

/// Trail-derived design tokens (project-brief.md → Visual design). `amber` mirrors the app-wide
/// accent in Assets.xcassets/AccentColor (what tints the controls here). The other tokens are
/// consumed by the grids / badges / tracking view in later WIs, where the race-card styling lands.
enum Theme {
    static let ground  = Color(red: 2/255,   green: 6/255,   blue: 23/255)  // #020617 slate-950
    static let surface = Color(red: 11/255,  green: 11/255,  blue: 33/255)  // #0b0b21 deep navy
    static let amber   = Color(red: 251/255, green: 191/255, blue: 36/255)  // #fbbf24 primary glow
    static let raceRed = Color(red: 229/255, green: 46/255,  blue: 58/255)  // #E52E3A
    static let green   = Color(red: 34/255,  green: 197/255, blue: 94/255)  // #22c55e go / finish
}

// MARK: - Store

/// Observable app state for the Races list (Swift's Observation: mutating its properties
/// re-renders the views reading them — see swift-orientation.md Part 2). Persistence lives in
/// `RaceStorage` (TrackCore.swift); event-append / projection wiring arrives with WI-6.
@Observable final class RaceStore {
    private(set) var races: [Race] = []
    private let storage: RaceStorage

    init(storage: RaceStorage = RaceStorage()) {
        self.storage = storage
        // UI-test hook: `-uitest-reset` starts from an empty bundle root (see TrackUITests).
        if CommandLine.arguments.contains("-uitest-reset") {
            for race in storage.loadAllRaces() { try? storage.deleteRace(id: race.id) }
        }
        races = storage.loadAllRaces()
    }

    /// WI-1 placeholder for the real create-race flow (WI-4): persist a stub race so we can
    /// prove the bundle survives relaunch. WI-4 replaces this with the name/date/palette form.
    @discardableResult
    func addStubRace() -> Race {
        let race = Race(name: "Stub race \(races.count + 1)")
        do {
            try storage.saveRace(race)
            races.insert(race, at: 0)   // newest first — matches loadAllRaces()'s order
        } catch {
            print("Track: failed to save race \(race.id): \(error)")
        }
        return race
    }

    func delete(_ race: Race) {
        do {
            try storage.deleteRace(id: race.id)
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

/// Root: the Races list (mvp-plan.md §6.1). WI-1 shows the list + an empty state and wires `+`
/// to a stub race; the status badge, duration, create form, and detail navigation are later WIs.
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
