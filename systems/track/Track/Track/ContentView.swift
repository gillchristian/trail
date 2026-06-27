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
import UIKit

// MARK: - Share sheet (TRACK-013)

/// A self-contained, `Identifiable` wrapper so a freshly-built export zip can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// Bridges `UIActivityViewController` — the iOS share sheet (AirDrop / Mail / Messages / **Save to Files**) —
/// into SwiftUI, to share a built export zip (TRACK-013). Presented via `.sheet(item:)`.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

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

    /// The race currently being run (status In-progress), if any — the "active race". The lock means at
    /// most one exists going forward; if legacy data has several, the newest (list order) wins. Drives the
    /// always-in-race-mode forefront: the app opens straight to it and can't be left mid-race (§6.1).
    var inProgressRace: Race? { races.first { statuses[$0.id] == .inProgress } }

    /// Look up a loaded race by id (for value-based navigation).
    func race(for id: RaceID) -> Race? { races.first { $0.id == id } }

    /// The storage backing the list, exposed for the per-row Export swipe action (TRACK-013). `RaceStorage`
    /// is a value type → `Sendable`, so the export's zip build can run off the main actor.
    var exportStorage: RaceStorage { storage }

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

/// A typed navigation route for the Races stack (mvp-plan.md §6.1). Programmatic so the app can push the
/// active race on launch — "always in race mode during a race."
private enum RaceRoute: Hashable {
    case race(RaceID)
    case library
}

/// Root: the Races list (mvp-plan.md §6.1). A projected status badge + finished-duration per row, an empty
/// state, `+` → the create/configure form. **Always-in-race-mode:** if a race is in progress, the stack
/// opens straight to it (computed in `init`, so there's no flash of the list first), and the tracking view
/// hides its back button (which also disables swipe-back), so a started race can't be left until it finishes.
struct RacesView: View {
    @State private var store: RaceStore
    @State private var path: [RaceRoute]
    @State private var creatingRace = false
    @State private var exportFile: ExportFile?       // set → present the share sheet (TRACK-013)
    @State private var exportError: String?

    init() {
        let store = RaceStore()
        _store = State(initialValue: store)
        // Cold launch mid-race → forefront the active race instead of the list. A warm resume keeps the
        // existing `path`, so this only needs to fire at construction (a killed-and-reopened app).
        _path = State(initialValue: store.inProgressRace.map { [RaceRoute.race($0.id)] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.races.isEmpty {
                    EmptyRacesView()
                } else {
                    List {
                        ForEach(store.races) { race in
                            NavigationLink(value: RaceRoute.race(race.id)) {
                                RaceRow(race: race, status: store.status(for: race),
                                        duration: store.duration(for: race))
                            }
                            // Safety-net export, reachable for any race straight off its bundle — doesn't
                            // depend on opening the detail view (TRACK-013). Leading swipe = Export (blue),
                            // trailing swipe = the existing Delete (red): two clearly-distinct directions.
                            .swipeActions(edge: .leading) {
                                Button { startExport(race) } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                .tint(Color(red: 47/255, green: 111/255, blue: 176/255))
                            }
                        }
                        .onDelete(perform: store.delete(at:))
                    }
                }
            }
            .navigationDestination(for: RaceRoute.self) { route in
                switch route {
                case let .race(id):
                    if let race = store.race(for: id) { RaceDetailView(race: race) }
                case .library:
                    TrackableLibraryView()
                }
            }
            .onAppear { store.refreshStatuses() }   // status/duration are projections — refresh on return
            .navigationTitle("Races")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: RaceRoute.library) {
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
            .sheet(item: $exportFile) { ShareSheet(items: [$0.url]) }
            .alert("Export failed", isPresented: Binding(
                get: { exportError != nil }, set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    /// Build the export zip off the main actor (capturing the `Sendable` storage + race), then present the
    /// share sheet (or surface an error). See `RaceStorage.exportZip`.
    private func startExport(_ race: Race) {
        let storage = store.exportStorage
        Task { @MainActor in
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try storage.exportZip(for: race, exportedAt: Date())
                }.value
                exportFile = ExportFile(url: url)
            } catch {
                exportError = error.localizedDescription
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
