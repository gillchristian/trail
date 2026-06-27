//
//  CreateRaceView.swift
//  Track
//
//  TRACK-004 (WI-4) — create / configure a race (mvp-plan.md §6.2). Presented as a sheet from the
//  Races list, replacing the WI-1 `addStubRace` stub. Edits a `RaceDraft` (TrackCore.swift, where
//  the ordinal/palette logic is unit-tested) and, on Save, hands the built `Race` back to the caller
//  (`RaceStore.add`) — the race enters Configured. The palette is sourced from the WI-3 trackable
//  library (multi-select); ad-hoc items can be created inline and optionally promoted into it.
//

import SwiftUI
import UniformTypeIdentifiers

struct CreateRaceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RaceDraft()
    @State private var hasDate = false
    @State private var scheduledDate = Date()
    @State private var addingAdHoc = false
    @State private var importingCSV = false
    @State private var importMessage: String?
    @State private var library: TrackableLibraryStore
    private let onSave: (Race) -> Void
    /// The race being edited, or `nil` to create a new one (TRACK-014). In edit mode the form is pre-filled
    /// and Save preserves the race's identity (`applied(to:)`); in create mode it mints a new race (`build()`).
    private let editing: Race?

    init(editing: Race? = nil,
         library: TrackableLibraryStore = TrackableLibraryStore(),
         onSave: @escaping (Race) -> Void) {
        self.editing = editing
        _library = State(initialValue: library)
        self.onSave = onSave
        if let editing {
            _draft = State(initialValue: RaceDraft(from: editing))
            _hasDate = State(initialValue: editing.date != nil)
            _scheduledDate = State(initialValue: editing.date ?? Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                raceSection
                aidStationsSection
                paletteSection
            }
            .navigationTitle(editing == nil ? "New Race" : "Edit Race")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!draft.isValid)
                        .accessibilityIdentifier("saveRace")
                }
            }
            .sheet(isPresented: $addingAdHoc) {
                AdHocItemEditor { item, promote in
                    if promote { library.upsert(item) }   // promote into the library first…
                    draft.palette.append(item)            // …then include it in this race's snapshot
                }
            }
            .fileImporter(isPresented: $importingCSV,
                          allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                handleImport(result)
            }
            .alert("CSV Import", isPresented: Binding(get: { importMessage != nil },
                                                      set: { if !$0 { importMessage = nil } })) {
                Button("OK", role: .cancel) { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
        }
    }

    private func save() {
        draft.date = hasDate ? scheduledDate : nil
        // Edit mode preserves the race's identity (applied); create mode mints a new race (build).
        onSave(editing.map(draft.applied(to:)) ?? draft.build())
        dismiss()
    }

    /// Read a user-picked Trail CSV and replace the aid stations with what it parses (mvp-plan.md
    /// §5; WI-5). Replacing (not appending) matches "import a plan's stations"; they stay editable.
    private func handleImport(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else {
            importMessage = "Couldn't import the file."
            return
        }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importMessage = "Couldn't read the file (expected UTF-8 text)."
            return
        }
        let parsed = AidStationCSV.parse(text)
        draft.replaceAidStations(with: parsed.stations)
        if parsed.stations.isEmpty {
            importMessage = "No aid stations found in that file."
        } else {
            let n = parsed.stations.count
            var message = "Imported \(n) aid station\(n == 1 ? "" : "s")."
            if parsed.skippedRows > 0 {
                let m = parsed.skippedRows
                message += " Skipped \(m) malformed row\(m == 1 ? "" : "s")."
            }
            importMessage = message
        }
    }

    // MARK: - Sections

    private var raceSection: some View {
        Section {
            TextField("Name", text: $draft.name)
                .accessibilityIdentifier("raceName")
            Toggle("Scheduled date", isOn: $hasDate.animation())
            if hasDate {
                DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
            }
        }
    }

    private var aidStationsSection: some View {
        Section {
            ForEach($draft.aidStations) { $station in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("\(station.ordinal).")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        TextField("AS \(station.ordinal)", text: $station.name)
                    }
                    TextField("Notes (optional)", text: $station.notes, axis: .vertical)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1...4)
                        .accessibilityIdentifier("aidNotes-\(station.ordinal)")
                }
            }
            .onDelete { draft.removeAidStations(at: $0) }
            .onMove { draft.moveAidStations(fromOffsets: $0, toOffset: $1) }

            Button {
                draft.addAidStation()
            } label: {
                Label("Add aid station", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("addAidStation")

            Button {
                importingCSV = true
            } label: {
                Label("Import from CSV…", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("importAidCsv")
        } header: {
            HStack {
                Text("Aid stations")
                Spacer()
                if !draft.aidStations.isEmpty { EditButton() }
            }
        } footer: {
            Text("Optional. Add manually or import a Trail CSV (replaces the list); reorder while editing. Notes show on the station while you're there. May be left empty for a plan-less race.")
        }
    }

    private var paletteSection: some View {
        Section {
            ForEach(library.items) { item in
                paletteRow(item)
            }
            ForEach(adHocPaletteItems) { item in
                paletteRow(item)
            }
            Button {
                addingAdHoc = true
            } label: {
                Label("Add custom item", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("addCustomItem")
        } header: {
            Text("Palette")
        } footer: {
            Text("Tap to include items to track during the race. Saved as a snapshot on this race.")
        }
    }

    /// Palette items the user added ad-hoc that aren't in the library (promoted ones fall under the
    /// library list above, so they never appear twice).
    private var adHocPaletteItems: [TrackableElement] {
        draft.palette.filter { selected in !library.items.contains { $0.id == selected.id } }
    }

    private func paletteRow(_ item: TrackableElement) -> some View {
        let selected = draft.paletteContains(item)
        return Button {
            draft.togglePalette(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.category.symbolName)
                    .foregroundStyle(Theme.amber)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.label)
                    Text(item.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.green : Color(uiColor: .tertiaryLabel))
            }
        }
        .buttonStyle(.plain)
    }
}

/// Inline ad-hoc palette item: label + category, with an opt-in to also save it to the library.
/// Distinct from the library's `TrackableEditor` (which has no promote affordance and always
/// persists). Hands back the built element plus whether to promote it.
private struct AdHocItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var category: TrackableCategory = .nutrition
    @State private var addToLibrary = false
    let onAdd: (TrackableElement, Bool) -> Void

    private var trimmedLabel: String { label.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label", text: $label)
                    .accessibilityIdentifier("adHocLabel")
                Picker("Category", selection: $category) {
                    ForEach(TrackableCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                Toggle("Add to library", isOn: $addToLibrary)
            }
            .navigationTitle("Custom Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(TrackableElement(label: trimmedLabel, category: category), addToLibrary)
                        dismiss()
                    }
                    .disabled(trimmedLabel.isEmpty)
                    .accessibilityIdentifier("addAdHocConfirm")
                }
            }
        }
    }
}

#Preview {
    CreateRaceView { _ in }
}
