//
//  TrackingView.swift
//  Track
//
//  TRACK-006 (WI-6) — the in-race tracking surface (tracking-view-spec.md; mvp-plan.md §6.3). Four
//  cyclic, swipeable tabs — Nutrition · AID · Others · Feed — over a `RaceTracker` (TrackCore.swift),
//  whose every action appends + fsyncs an event before mirroring it in memory. Three tracking tabs
//  (two trackable grids + the aid-station manager) carry a record-voice button (bottom-right) and an
//  Undo toast (bottom-left); Feed is a read-only event stream with neither. `RaceDetailView` branches
//  on the projected race status: Configured → Start, In-progress → this view, Finished → a minimal
//  read placeholder (the full post-race view is WI-7). Appearance follows the system light/dark setting;
//  Trail's accent palette (Theme, ContentView.swift) supplies the glow.
//

import SwiftUI
import AVFoundation

// MARK: - Race detail (status branch)

/// Pushed from the Races list (mvp-plan.md §6.1). Owns the race's `RaceTracker` and renders the right
/// surface for the projected status; starting / finishing the race flips the status and re-renders here.
struct RaceDetailView: View {
    @State private var tracker: RaceTracker

    init(race: Race, storage: RaceStorage = RaceStorage()) {
        _tracker = State(initialValue: RaceTracker(race: race, storage: storage))
    }

    var body: some View {
        switch tracker.status {
        case .configured: StartRaceView(tracker: tracker)
        case .inProgress: TrackingView(tracker: tracker)
        case .finished:   FinishedRaceView(tracker: tracker)
        }
    }
}

// MARK: - Start (Configured)

/// The pre-race screen for a Configured race: a summary + the Start control that logs `raceStarted`
/// (tracking-view-spec.md §1 — race start happens here, upstream of the tracking tabs).
private struct StartRaceView: View {
    let tracker: RaceTracker

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 64)).foregroundStyle(Theme.amber)
            Text(tracker.race.name)
                .font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
            if let date = tracker.race.date {
                Text(date.formatted(date: .long, time: .omitted)).foregroundStyle(.secondary)
            }
            HStack(spacing: 28) {
                summary("\(tracker.race.aidStations.count)", "aid stations")
                summary("\(tracker.race.palette.count)", "palette items")
            }
            .padding(.top, 4)
            Spacer()
            Button { tracker.start() } label: {
                Label("Start race", systemImage: "play.fill")
                    .font(.title3.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent).tint(Theme.raceRed)
            .accessibilityIdentifier("startRace")
        }
        .padding(24)
        .navigationTitle(tracker.race.name).navigationBarTitleDisplayMode(.inline)
    }

    private func summary(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.bold))
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Tracking shell (In-progress)

/// The four-tab in-race surface. The tab bar taps switch tabs; a cyclic horizontal swipe also moves
/// between them (wrapping past the ends). The record-voice button + Undo toast overlay the three
/// tracking tabs only (§1). The toast auto-dismisses ~10s after the latest action (§6).
struct TrackingView: View {
    let tracker: RaceTracker
    @State private var tab: TrackingTab = .nutrition
    @State private var recorder = AudioRecorder()

    var body: some View {
        VStack(spacing: 0) {
            TrackingTabBar(selection: $tab)
            ZStack(alignment: .bottom) {
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
                if tab.isTracking { chrome }
            }
        }
        .navigationTitle(tracker.race.name).navigationBarTitleDisplayMode(.inline)
        .contentShape(Rectangle())   // make the whole surface (incl. empty regions) hit-test for the swipe
        .simultaneousGesture(swipe)
        .task(id: tracker.lastAction?.token) { await autoDismissToast() }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .nutrition:
            TrackableGridView(items: tracker.race.paletteItems(for: .nutrition),
                              emptyHint: "Add nutrition or hydration items when configuring the race.",
                              onTap: tracker.track)
        case .others:
            TrackableGridView(items: tracker.race.paletteItems(for: .others),
                              emptyHint: "Add gear or other items when configuring the race.",
                              onTap: tracker.track)
        case .aid:
            AidTabView(tracker: tracker)
        case .feed:
            FeedTabView(entries: tracker.feed)
        }
    }

    private var chrome: some View {
        HStack(alignment: .bottom) {
            if let action = tracker.lastAction {
                UndoToast(action: action) { tracker.undoLast() }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            Spacer()
            RecordButton(recorder: recorder) { data, duration in
                tracker.addVoiceNote(data: data, durationSec: duration)
            }
        }
        .padding(.horizontal).padding(.bottom, 12)
        .animation(.spring(duration: 0.3), value: tracker.lastAction)
    }

    /// Cyclic tab swipe (§1). Simultaneous (not exclusive) so the grids/lists keep their vertical
    /// scroll and the tiles keep their taps; only a clearly-horizontal drag switches tabs.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local).onEnded { value in
            let (dx, dy) = (value.translation.width, value.translation.height)
            guard abs(dx) > abs(dy), abs(dx) > 50 else { return }
            withAnimation(.easeInOut(duration: 0.2)) { tab = dx < 0 ? tab.next : tab.previous }
        }
    }

    private func autoDismissToast() async {
        guard tracker.lastAction != nil else { return }
        try? await Task.sleep(for: .seconds(10))   // long-lived (§6): mid-race reaction is slow
        tracker.dismissToast()
    }
}

private struct TrackingTabBar: View {
    @Binding var selection: TrackingTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TrackingTab.allCases) { tab in
                let selected = tab == selection
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = tab }
                } label: {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(selected ? Theme.amber : Color(.secondarySystemBackground), in: Capsule())
                        .foregroundStyle(selected ? Theme.ground : Color.primary)
                }
                .accessibilityIdentifier("tab-\(tab)")
            }
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
    }
}

// MARK: - Nutrition / Others grids (§2)

private struct TrackableGridView: View {
    let items: [TrackableElement]
    let emptyHint: String
    let onTap: (TrackableElement) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        if items.isEmpty {
            ContentUnavailableView("Nothing to track here", systemImage: "tray",
                                   description: Text(emptyHint))
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(items) { item in
                        Button { onTap(item) } label: { TileView(item: item) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("tile-\(item.label)")
                    }
                }
                .padding()
                .padding(.bottom, 72)   // clear the floating record button
            }
        }
    }
}

private struct TileView: View {
    let item: TrackableElement

    var body: some View {
        Text(item.label)
            .font(.headline).multilineTextAlignment(.center).minimumScaleFactor(0.7)
            .foregroundStyle(item.category.tileTextColor)
            .frame(maxWidth: .infinity, minHeight: 96).padding(8)
            .background(item.category.tileColor, in: RoundedRectangle(cornerRadius: 18))
    }
}

extension TrackableCategory {
    /// High-contrast tile fill for the tracking grids (tracking-view-spec.md §2), drawn from Trail's
    /// palette + two complementary hues so each category reads at a glance, sweaty/gloved.
    var tileColor: Color {
        switch self {
        case .nutrition: return Theme.amber
        case .hydration: return Color(red: 47/255, green: 111/255, blue: 176/255)   // water blue
        case .gear:      return Theme.raceRed
        case .other:     return Color(red: 111/255, green: 90/255, blue: 166/255)   // slate purple
        }
    }
    /// A foreground that stays legible on `tileColor`.
    var tileTextColor: Color {
        switch self {
        case .nutrition: return Theme.ground                  // dark text on light amber
        case .hydration, .gear, .other: return .white
        }
    }
}

// MARK: - AID tab (§3)

private struct AidTabView: View {
    let tracker: RaceTracker
    @State private var confirmingFinish = false

    var body: some View {
        let board = tracker.board
        ScrollView {
            VStack(spacing: 12) {
                ForEach(board.passed) { PassedAidRow(visit: $0) }

                if let current = board.current {
                    CurrentAidRow(visit: current) { tracker.finishAid(current) }
                    let services = tracker.race.services(forVisitOrdinal: current.ordinal)
                    if !services.isEmpty { AidNotesCard(services: services) }
                }

                if board.isPlanned {
                    if let upcoming = board.upcoming {
                        UpcomingAidRow(station: upcoming, legKm: board.legToUpcomingKm) {
                            tracker.arrive(at: upcoming)
                        }
                    } else if board.current == nil {
                        Text("All planned aid stations reached.")
                            .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
                    }
                } else {
                    Button { tracker.startAdHocAid() } label: {
                        Label("Start new aid station", systemImage: "plus.circle.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.amber)
                    .accessibilityIdentifier("startAdHocAid")
                }

                Divider().padding(.vertical, 4)

                Button(role: .destructive) { confirmingFinish = true } label: {
                    Label("Finish race", systemImage: "flag.checkered")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.bordered).tint(Theme.raceRed)
                .accessibilityIdentifier("finishRace")
            }
            .padding().padding(.bottom, 80)   // clear the floating chrome
        }
        .confirmationDialog("Finish this race?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("Finish race", role: .destructive) { tracker.finishRace() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Logs the race as finished. You can correct the finish time afterward.")
        }
    }
}

private struct PassedAidRow: View {
    let visit: AidStationVisit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.label).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // `departedExitUnrecorded` is the forgot-to-Finish case — GPS reconstructs the real exit (§3).
    private var subtitle: String {
        switch visit.state {
        case let .departed(at): return "Left \(at.formatted(date: .omitted, time: .shortened))"
        case .departedExitUnrecorded: return "Left (time not marked)"
        case .inProgress: return "In progress"
        }
    }
}

private struct CurrentAidRow: View {
    let visit: AidStationVisit
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.label).font(.headline).foregroundStyle(.white)
                Text("In progress · arrived \(visit.enteredAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Button(action: onFinish) {
                Text("Finish").font(.headline).padding(.horizontal, 18).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(Theme.green)
            .accessibilityIdentifier("finishAid")
        }
        .padding()
        .background(Color(red: 47/255, green: 111/255, blue: 176/255), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct AidNotesCard: View {
    let services: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes").font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
            Text(services.joined(separator: " · ")).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }
}

private struct UpcomingAidRow: View {
    let station: PlannedAidStation
    let legKm: Double?
    let onArrive: () -> Void

    var body: some View {
        Button(action: onArrive) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.displayName).font(.headline)
                    if let legKm {
                        Text("→ \(legKm.formatted(.number.precision(.fractionLength(0...1)))) km to here")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "mappin.circle.fill")
                Text("Mark arrival").font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.amber)
            .padding()
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.amber.opacity(0.6), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("arriveUpcoming")
    }
}

// MARK: - Feed tab (§4)

private struct FeedTabView: View {
    let entries: [FeedEntry]

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView("No events yet", systemImage: "list.bullet.rectangle",
                                   description: Text("Tracked items, aid stations, and voice notes appear here."))
        } else {
            List(entries.reversed()) { FeedRow(entry: $0) }   // newest-first (OQ-4)
                .listStyle(.plain)
        }
    }
}

private struct FeedRow: View {
    let entry: FeedEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(tint, in: RoundedRectangle(cornerRadius: 9))
            Text(label).font(.subheadline)
            Spacer()
            Text(entry.at.formatted(date: .omitted, time: .standard))
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var label: String {
        switch entry.kind {
        case .raceStarted:            return "Race started"
        case .raceEnded:              return "Race finished"
        case let .intake(label):      return label
        case let .aidArrived(label):  return "\(label) — arrived"
        case let .aidLeft(label):     return "\(label) — left"
        case let .voiceNote(seconds): return "Voice note (\(Int(seconds.rounded()))s)"
        }
    }

    private var icon: String {
        switch entry.kind {
        case .raceStarted:  return "flag.fill"
        case .raceEnded:    return "flag.checkered"
        case .intake:       return "fork.knife"
        case .aidArrived:   return "arrow.down.circle.fill"
        case .aidLeft:      return "arrow.up.forward.circle.fill"
        case .voiceNote:    return "waveform"
        }
    }

    private var tint: Color {
        switch entry.kind {
        case .raceStarted, .raceEnded:   return Theme.green
        case .intake:                    return Theme.amber
        case .aidArrived, .aidLeft:      return Color(red: 47/255, green: 111/255, blue: 176/255)
        case .voiceNote:                 return Color(red: 111/255, green: 90/255, blue: 166/255)
        }
    }
}

// MARK: - Record-voice button + recorder (§5)

private struct RecordButton: View {
    let recorder: AudioRecorder
    let onFinish: (Data, Double) -> Void

    var body: some View {
        Button {
            recorder.toggle(onFinish: onFinish)
        } label: {
            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(recorder.isRecording ? .white : Theme.raceRed)
                .frame(width: 64, height: 64)
                .background(recorder.isRecording ? Theme.raceRed : Color(.secondarySystemBackground), in: Circle())
                .overlay(Circle().strokeBorder(Theme.raceRed, lineWidth: 2))
                .shadow(radius: 4, y: 2)
        }
        .accessibilityIdentifier("recordVoice")
        .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Record voice note")
    }
}

/// Foreground tap-record-tap-stop voice capture (§5): mono AAC/m4a to a temp file, handed to the
/// tracker on stop (which writes it durably into the race bundle). No background audio mode.
@Observable final class AudioRecorder {
    private(set) var isRecording = false
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    func toggle(onFinish: @escaping (Data, Double) -> Void) {
        if isRecording { stop(onFinish: onFinish) } else { begin() }
    }

    private func begin() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self, granted else { return }
                self.startRecording()
            }
        }
    }

    private func startRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            let target = FileManager.default.temporaryDirectory
                .appending(path: "voice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: 1,                         // mono (mvp-plan.md §9)
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: target, settings: settings)
            guard recorder.record() else { return }
            self.recorder = recorder
            self.fileURL = target
            self.isRecording = true
        } catch {
            print("Track: could not start recording: \(error)")
            isRecording = false
        }
    }

    private func stop(onFinish: @escaping (Data, Double) -> Void) {
        defer { isRecording = false; recorder = nil; fileURL = nil }
        guard let recorder, let fileURL else { return }
        let duration = recorder.currentTime
        recorder.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        if let data = try? Data(contentsOf: fileURL) {
            onFinish(data, duration)
            try? FileManager.default.removeItem(at: fileURL)   // the bundle keeps the canonical copy
        }
    }
}

// MARK: - Undo toast (§6)

private struct UndoToast: View {
    let action: RaceTracker.TrackedAction
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            Text(action.description).font(.subheadline.weight(.semibold)).lineLimit(1)
            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.amber)
                .accessibilityIdentifier("undoAction")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary))
        .shadow(radius: 4, y: 2)
    }
}

// MARK: - Finished (minimal read placeholder; full post-race view is WI-7)

/// A Finished race opens to a minimal read surface: the resolved summary header + the event Feed. The
/// full post-race view — inline clip playback, edit-finish-time, per-visit summary — is WI-7 (TRACK-007).
private struct FinishedRaceView: View {
    let tracker: RaceTracker

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Label("Finished", systemImage: "flag.checkered")
                    .font(.headline).foregroundStyle(Theme.green)
                if let start = tracker.startedAt, let end = tracker.effectiveEnd {
                    Text(RaceFormat.duration(end.timeIntervalSince(start)))
                        .font(.largeTitle.weight(.bold)).monospacedDigit()
                    Text("\(start.formatted(date: .abbreviated, time: .shortened)) → \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Full post-race review (clip playback, edit finish time, summary) arrives in WI-7.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.top, 4)
            }
            .frame(maxWidth: .infinity).padding()
            .background(Color(.secondarySystemBackground))

            FeedTabView(entries: tracker.feed)
        }
        .navigationTitle(tracker.race.name).navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Tracking") {
    let race = Race(
        name: "Sunset 50K",
        aidStations: [
            PlannedAidStation(ordinal: 1, name: "Trailhead", services: ["water"], distanceKm: 0),
            PlannedAidStation(ordinal: 2, name: "Ridge", services: ["water", "food", "medical"], distanceKm: 8.3),
        ],
        palette: [
            TrackableElement(label: "Gel", category: .nutrition),
            TrackableElement(label: "Water", category: .hydration),
            TrackableElement(label: "Poles", category: .gear),
        ]
    )
    let tracker = RaceTracker(race: race)
    tracker.start()
    return NavigationStack { TrackingView(tracker: tracker) }
}
