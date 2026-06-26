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
    private var statuses: [RaceID: RaceStatus] = [:]
    private var durations: [RaceID: TimeInterval] = [:]
    private let storage: RaceStorage

    init(storage: RaceStorage = RaceStorage()) {
        self.storage = storage
        load()   // reconstruction-safe: a pure read. The `-uitest-reset` wipe lives in TrackApp.init.
    }

    /// Projected status of a race (mvp-plan.md §6.1): a fold of its `events.log`, never a stored
    /// flag. Configured (no events) → In-progress (`raceStarted`) → Finished (`raceEnded`) as WI-6
    /// appends events.
    func status(for race: Race) -> RaceStatus { statuses[race.id] ?? .configured }

    /// Elapsed duration of a finished race (effective end − start); nil otherwise. Also a projection.
    func duration(for race: Race) -> TimeInterval? { durations[race.id] }

    /// Persist a fully-configured race (WI-4) and show it at the top — newest first, matching
    /// `loadAllRaces()`'s order. The race enters Configured (no events yet).
    func add(_ race: Race) {
        do {
            try storage.saveRace(race)
            races.insert(race, at: 0)
            statuses[race.id] = .configured
        } catch {
            print("Track: failed to save race \(race.id): \(error)")
        }
    }

    func delete(_ race: Race) {
        do {
            try storage.deleteRace(id: race.id)
            races.removeAll { $0.id == race.id }
            statuses.removeValue(forKey: race.id)
            durations.removeValue(forKey: race.id)
        } catch {
            print("Track: failed to delete race \(race.id): \(error)")
        }
    }

    func delete(at offsets: IndexSet) {
        offsets.map { races[$0] }.forEach(delete)
    }

    /// Re-fold every race's log to refresh the projected status + finished-duration badges. Called
    /// when the list reappears (e.g. after starting/finishing a race in the detail view, WI-6), since
    /// status/duration are projections, never stored flags.
    func refreshStatuses() {
        for race in races { project(race) }
    }

    private func load() {
        races = storage.loadAllRaces()
        for race in races { project(race) }
    }

    private func project(_ race: Race) {
        let events = storage.loadEvents(for: race.id)
        statuses[race.id] = events.status
        if events.status == .finished, let start = events.startedAt, let end = events.effectiveEnd {
            durations[race.id] = end.timeIntervalSince(start)
        } else {
            durations.removeValue(forKey: race.id)
        }
    }
}

// MARK: - Views

/// Root: the Races list (mvp-plan.md §6.1). Shows the list with a projected status badge per row,
/// an empty state, and wires `+` to the create/configure form (WI-4). Duration-when-finished and
/// the status-branching detail (Start / tracking / read) are later WIs (WI-6/7).
struct RacesView: View {
    @State private var store = RaceStore()
    @State private var creatingRace = false

    var body: some View {
        NavigationStack {
            Group {
                if store.races.isEmpty {
                    EmptyRacesView()
                } else {
                    List {
                        ForEach(store.races) { race in
                            NavigationLink {
                                RaceDetailView(race: race)
                            } label: {
                                RaceRow(race: race, status: store.status(for: race),
                                        duration: store.duration(for: race))
                            }
                        }
                        .onDelete(perform: store.delete(at:))
                    }
                }
            }
            .onAppear { store.refreshStatuses() }   // status/duration are projections — refresh on return
            .navigationTitle("Races")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        TrackableLibraryView()
                    } label: {
                        Label("Trackable Library", systemImage: "list.bullet.rectangle")
                    }
                    .accessibilityIdentifier("openLibrary")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        creatingRace = true
                    } label: {
                        Label("Add race", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addRace")
                }
            }
            .sheet(isPresented: $creatingRace) {
                CreateRaceView { store.add($0) }
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
    let status: RaceStatus
    let duration: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(race.name)
                    .font(.headline)
                Spacer()
                StatusBadge(status: status)
            }
            HStack(spacing: 6) {
                Text(dateLabel)
                if status == .finished, let duration {
                    Text("· \(RaceFormat.duration(duration))")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // The scheduled race date when set (day only), else when it was created (with time).
    private var dateLabel: String {
        if let date = race.date {
            return date.formatted(.dateTime.year().month().day())
        }
        return race.createdAt.formatted(.dateTime.year().month().day().hour().minute())
    }
}

/// The projected race status as a small capsule (mvp-plan.md §6.1). Amber = ready/Configured,
/// race-red = live/In-progress, green = Finished. The identifier is a stable test hook.
private struct StatusBadge: View {
    let status: RaceStatus

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
            .accessibilityIdentifier(identifier)
    }

    private var text: String {
        switch status {
        case .configured: return "Configured"
        case .inProgress: return "In progress"
        case .finished: return "Finished"
        }
    }

    private var tint: Color {
        switch status {
        case .configured: return Theme.amber
        case .inProgress: return Theme.raceRed
        case .finished: return Theme.green
        }
    }

    private var identifier: String {
        switch status {
        case .configured: return "status-configured"
        case .inProgress: return "status-inProgress"
        case .finished: return "status-finished"
        }
    }
}

#Preview {
    RacesView()
}
