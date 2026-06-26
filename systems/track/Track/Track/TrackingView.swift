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
            TrackingTabBar(selection: $tab, lockedToTracking: recorder.isRecording)
            ZStack(alignment: .bottom) {
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
                if tab.isTracking { chrome }
            }
        }
        .navigationTitle(tracker.race.name).navigationBarTitleDisplayMode(.inline)
        .contentShape(Rectangle())   // make the whole surface (incl. empty regions) hit-test for the swipe
        .simultaneousGesture(swipe)
        .task(id: tracker.lastAction?.token) { await autoDismissToast() }
        // If the view goes away while recording (a Back tap — tabs can't reach the stop-less Feed),
        // stop + save the clip so it isn't silently dropped (the symptom: "it never showed in the Feed").
        .onDisappear { recorder.stopIfRecording { tracker.addVoiceNote(data: $0, durationSec: $1) } }
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
            // While recording, skip the stop-less Feed tab so the record/stop button stays reachable.
            let locked = recorder.isRecording
            withAnimation(.easeInOut(duration: 0.2)) {
                tab = dx < 0 ? tab.next(excludingFeed: locked) : tab.previous(excludingFeed: locked)
            }
        }
    }

    private func autoDismissToast() async {
        guard tracker.lastAction != nil else { return }
        // Only dismiss if the 10s elapses (§6: mid-race reaction is slow). If the sleep is *cancelled* —
        // which happens when a newer action bumps `lastAction.token` and restarts this `.task` — we must
        // NOT fall through to dismiss, or the new action's just-set toast vanishes immediately. (A bare
        // `try? await sleep` swallows the cancellation and dismisses the replacement: that was the bug.)
        do {
            try await Task.sleep(for: .seconds(10))
        } catch {
            return
        }
        tracker.dismissToast()
    }
}

private struct TrackingTabBar: View {
    @Binding var selection: TrackingTab
    var lockedToTracking: Bool   // a recording is in progress → the stop-less Feed tab is unreachable

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TrackingTab.allCases) { tab in
                let selected = tab == selection
                let locked = lockedToTracking && !tab.isTracking   // Feed only
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = tab }
                } label: {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(selected ? Theme.amber : Color(.secondarySystemBackground), in: Capsule())
                        .foregroundStyle(selected ? Theme.ground : Color.primary)
                }
                .disabled(locked)
                .opacity(locked ? 0.35 : 1)
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
                    CurrentAidRow(visit: current,
                                  onFinish: { tracker.finishAid(current) },
                                  onCancel: { tracker.cancelAid(current) })
                    let notes = tracker.race.notes(forVisitOrdinal: current.ordinal)
                    if !notes.isEmpty { AidInfoCard(title: "Notes", text: notes) }
                    let services = tracker.race.services(forVisitOrdinal: current.ordinal)
                    if !services.isEmpty { AidInfoCard(title: "Services", text: services.joined(separator: " · ")) }
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
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(visit.label).font(.headline).foregroundStyle(.white)
                Text("In progress · arrived \(visit.enteredAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
                // Persistent escape hatch (the toast is most-recent-only): retract the arrival, so a
                // mistaken station isn't stuck with Finish as its only option.
                Button(action: onCancel) {
                    Label("Cancel arrival", systemImage: "arrow.uturn.backward").font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered).tint(.white).controlSize(.small)
                .accessibilityIdentifier("cancelAid")
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

/// A titled info card shown under the active aid station (its Notes, its Services).
private struct AidInfoCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary)
            Text(text).font(.subheadline)
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
            .contentShape(Rectangle())   // the whole row is the tap target, not just the text/icon (the Spacer gap was dead)
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
            FeedIcon(kind: entry.kind)
            Text(entry.kind.title).font(.subheadline)
            Spacer()
            Text(entry.at.formatted(date: .omitted, time: .standard))
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// The square tinted glyph that leads an event row — shared by the in-race Feed and the post-race timeline.
private struct FeedIcon: View {
    let kind: FeedEntry.Kind

    var body: some View {
        Image(systemName: kind.icon).font(.subheadline).foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(kind.tint, in: RoundedRectangle(cornerRadius: 9))
    }
}

/// Shared visual vocabulary for an event row — used by the in-race Feed (`FeedRow`) and the post-race
/// timeline (`TimelineRow`). Icon + tint are identical in both; `title` is the row text (the post-race
/// voice-note row replaces it with an inline play control + duration).
private extension FeedEntry.Kind {
    var title: String {
        switch self {
        case .raceStarted:               return "Race started"
        case .raceEnded:                 return "Race finished"
        case let .intake(label):         return label
        case let .aidArrived(label):     return "\(label) — arrived"
        case let .aidLeft(label):        return "\(label) — left"
        case let .voiceNote(_, seconds): return "Voice note (\(Int(seconds.rounded()))s)"
        }
    }

    var icon: String {
        switch self {
        case .raceStarted:  return "flag.fill"
        case .raceEnded:    return "flag.checkered"
        case .intake:       return "fork.knife"
        case .aidArrived:   return "arrow.down.circle.fill"
        case .aidLeft:      return "arrow.up.forward.circle.fill"
        case .voiceNote:    return "waveform"
        }
    }

    var tint: Color {
        switch self {
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

    /// Stop + hand off the clip if a recording is in progress — used when the tracking view goes away
    /// mid-record so the clip is saved, not silently dropped. No-op when idle.
    func stopIfRecording(onFinish: @escaping (Data, Double) -> Void) {
        if isRecording { stop(onFinish: onFinish) }
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

// MARK: - Finished (post-race race view; WI-7)

/// The post-race surface (mvp-plan.md §6.4): a resolved **summary** (counts + per-visit dwell + per-item
/// intake totals), an **editable finish time** (`endTimeCorrected`, never a mutation), and the chronological
/// event **timeline** with **inline clip playback** — the one place audio plays (tracking-view-spec.md §4
/// keeps it out of the in-race Feed). Replaces WI-6's minimal placeholder.
private struct FinishedRaceView: View {
    let tracker: RaceTracker
    @State private var player = AudioPlayer()
    @State private var editingFinish = false

    var body: some View {
        let summary = tracker.summary
        List {
            Section { SummaryHeader(summary: summary) }

            if !summary.visits.isEmpty {
                Section("Aid stations") {
                    ForEach(summary.visits) { VisitDurationRow(visit: $0) }
                }
            }
            if !summary.intakeTotals.isEmpty {
                Section("Intake") {
                    ForEach(summary.intakeTotals) { IntakeTotalRow(total: $0) }
                }
            }

            Section("Timeline") {
                if tracker.feed.isEmpty {
                    Text("No events were recorded.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    // Oldest → newest: the race read as a story start→finish ("chronological", §6.4) —
                    // intentionally unlike the in-race Feed's newest-first (OQ-4).
                    ForEach(tracker.feed) { entry in
                        TimelineRow(entry: entry, effectiveEnd: tracker.effectiveEnd,
                                    player: player, clipURL: tracker.clipURL)
                    }
                }
            }
        }
        .navigationTitle(tracker.race.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editingFinish = true } label: { Label("Edit finish", systemImage: "pencil") }
                    .accessibilityIdentifier("editFinish")
            }
        }
        .sheet(isPresented: $editingFinish) {
            EditFinishView(start: tracker.startedAt, current: tracker.effectiveEnd) {
                tracker.correctEndTime(to: $0)
            }
        }
        .onDisappear { player.stop() }
    }
}

/// The summary section's header: the big total duration, the start→end span, and the headline counts.
private struct SummaryHeader: View {
    let summary: RaceSummary

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                Label("Finished", systemImage: "flag.checkered")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.green)
                if let total = summary.totalDuration {
                    Text(RaceFormat.duration(total))
                        .font(.system(size: 44, weight: .bold)).monospacedDigit()
                        .accessibilityIdentifier("totalDuration")
                }
                if let start = summary.startedAt, let end = summary.effectiveEnd {
                    Text("\(start.formatted(date: .abbreviated, time: .shortened)) → \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                CountCell(value: summary.aidVisitCount, caption: "aid visits")
                Divider().frame(height: 32)
                CountCell(value: summary.intakeCount, caption: "intakes")
                Divider().frame(height: 32)
                CountCell(value: summary.voiceNoteCount, caption: "notes")
            }
        }
        .padding(.vertical, 6)
    }
}

private struct CountCell: View {
    let value: Int
    let caption: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title2.weight(.bold)).monospacedDigit()
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct VisitDurationRow: View {
    let visit: RaceSummary.VisitDuration

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.label).font(.subheadline.weight(.medium))
                Text("Arrived \(visit.enteredAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            // dwell = exit − entry; "—" when the exit was never marked (GPS reconstructs it later, app 3).
            Text(visit.dwell.map(RaceFormat.duration) ?? "—")
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(visit.dwell == nil ? .secondary : .primary)
        }
    }
}

private struct IntakeTotalRow: View {
    let total: RaceSummary.IntakeTotal

    var body: some View {
        HStack {
            Text(total.label).font(.subheadline)
            Spacer()
            Text("×\(total.count)").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}

/// One post-race timeline row. Mirrors the Feed's icon + tint; the finished milestone shows the *effective*
/// end (a correction is applied here, not as its own row), and a voice note becomes an inline play control.
private struct TimelineRow: View {
    let entry: FeedEntry
    let effectiveEnd: Date?
    let player: AudioPlayer
    let clipURL: (String) -> URL

    var body: some View {
        HStack(spacing: 12) {
            FeedIcon(kind: entry.kind)
            if case let .voiceNote(filename, seconds) = entry.kind {
                Button {
                    player.toggle(id: entry.id, url: clipURL(filename))
                } label: {
                    Label("Voice note · \(Int(seconds.rounded()))s",
                          systemImage: player.playingID == entry.id ? "stop.circle.fill" : "play.circle.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.plain).foregroundStyle(Theme.amber)
                .accessibilityIdentifier("playClip")
                .accessibilityValue(player.playingID == entry.id ? "playing" : "stopped")
            } else {
                Text(entry.kind.title).font(.subheadline)
            }
            Spacer()
            Text(displayTime.formatted(date: .omitted, time: .standard))
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.vertical, 2)
    }

    // The finished row reads the effective end (the correction), not the raw raceEnded timestamp (§6.4).
    private var displayTime: Date {
        if case .raceEnded = entry.kind, let effectiveEnd { return effectiveEnd }
        return entry.at
    }
}

// MARK: - Edit finish time (§6.4)

/// The finish-time correction sheet: a date+time picker (never earlier than the start) whose Save appends an
/// `endTimeCorrected`. A live duration row shows the effect before committing.
private struct EditFinishView: View {
    let start: Date?
    let onSave: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var finish: Date

    init(start: Date?, current: Date?, onSave: @escaping (Date) -> Void) {
        self.start = start
        self.onSave = onSave
        _finish = State(initialValue: current ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Finish time", selection: $finish,
                               in: (start ?? .distantPast)...,
                               displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("finishPicker")
                } footer: {
                    Text("Appends a correction — the original finish stays in the log. Use it when the recorded finish is off (e.g. the phone died and powered on late).")
                }
                if let start {
                    Section {
                        LabeledContent("Duration", value: RaceFormat.duration(finish.timeIntervalSince(start)))
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("Edit finish time").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(finish); dismiss() }.accessibilityIdentifier("saveFinish")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Clip playback (post-race; §6.4)

/// Inline voice-clip playback for the post-race view — the only place audio plays (capture-now-review-later).
/// One clip at a time: `playingID` drives the active row's play/stop glyph and resets when playback finishes.
@Observable final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playingID: EventID?
    @ObservationIgnored private var player: AVAudioPlayer?

    /// Toggle the clip for `id`: tapping the playing row stops it; tapping another switches to it.
    func toggle(id: EventID, url: URL) {
        if playingID == id { stop() } else { play(id: id, url: url) }
    }

    private func play(id: EventID, url: URL) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            guard player.play() else { return }
            self.player = player
            playingID = id
        } catch {
            print("Track: could not play clip \(url.lastPathComponent): \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        playingID = nil
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

#Preview("Finished") {
    let race = Race(
        name: "Sunset 50K",
        aidStations: [PlannedAidStation(ordinal: 1, name: "Ridge", services: ["water", "food"], distanceKm: 8.3)],
        palette: [TrackableElement(label: "Gel", category: .nutrition),
                  TrackableElement(label: "Water", category: .hydration)]
    )
    let tracker = RaceTracker(race: race)
    tracker.start()
    tracker.track(race.palette[0])
    tracker.track(race.palette[1])
    tracker.track(race.palette[0])
    if let upcoming = tracker.board.upcoming {
        tracker.arrive(at: upcoming)
        if let current = tracker.board.current { tracker.finishAid(current) }
    }
    tracker.finishRace()
    return NavigationStack { FinishedRaceView(tracker: tracker) }
}
