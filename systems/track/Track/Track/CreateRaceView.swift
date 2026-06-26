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

struct CreateRaceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RaceDraft()
    @State private var hasDate = false
    @State private var scheduledDate = Date()
    @State private var addingAdHoc = false
    @State private var library: TrackableLibraryStore
    private let onSave: (Race) -> Void

    init(library: TrackableLibraryStore = TrackableLibraryStore(),
         onSave: @escaping (Race) -> Void) {
        _library = State(initialValue: library)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                raceSection
                aidStationsSection
                paletteSection
            }
            .navigationTitle("New Race")
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
        }
    }

    private func save() {
        draft.date = hasDate ? scheduledDate : nil
        onSave(draft.build())
        dismiss()
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
                HStack(spacing: 8) {
                    Text("\(station.ordinal).")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    TextField("AS \(station.ordinal)", text: $station.name)
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
        } header: {
            HStack {
                Text("Aid stations")
                Spacer()
                if !draft.aidStations.isEmpty { EditButton() }
            }
        } footer: {
            Text("Optional. Add manually now (CSV import comes later); reorder while editing. May be left empty for a plan-less race.")
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
