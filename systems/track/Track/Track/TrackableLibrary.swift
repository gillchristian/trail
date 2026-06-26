//
//  TrackableLibrary.swift
//  Track
//
//  TRACK-003 (WI-3) — the trackable library: a CRUD list of TrackableElement (label + category),
//  the source for race palettes (mvp-plan.md §6.5; consumed by WI-4). The SwiftUI layer over
//  TrackableLibraryStorage (TrackCore.swift).
//

import SwiftUI

/// Observable state for the library (mirrors RaceStore). The list is small and config-like, so it
/// is persisted whole, atomically, on every change.
@Observable final class TrackableLibraryStore {
    private(set) var items: [TrackableElement] = []
    private let storage: TrackableLibraryStorage

    init(storage: TrackableLibraryStorage = TrackableLibraryStorage()) {
        self.storage = storage
        if CommandLine.arguments.contains("-uitest-reset") { try? storage.save([]) }
        items = storage.load()
    }

    /// Create (a new id) or edit (an existing id): the editor hands back a complete element.
    func upsert(_ item: TrackableElement) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        do { try storage.save(items) }
        catch { print("Track: failed to save trackables: \(error)") }
    }
}

/// The trackable library screen (mvp-plan.md §6.5). Pushed from the Races-list toolbar.
struct TrackableLibraryView: View {
    @State private var store = TrackableLibraryStore()
    @State private var editorSubject: EditorSubject?

    var body: some View {
        Group {
            if store.items.isEmpty {
                ContentUnavailableView("No trackables", systemImage: "list.bullet.rectangle",
                                       description: Text("Tap + to add foods, drinks, or gear to track during a race."))
            } else {
                List {
                    ForEach(store.items) { item in
                        Button { editorSubject = .existing(item) } label: { TrackableRow(item: item) }
                            .buttonStyle(.plain)
                    }
                    .onDelete(perform: store.delete(at:))
                }
            }
        }
        .navigationTitle("Trackables")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editorSubject = .new } label: { Label("Add trackable", systemImage: "plus") }
                    .accessibilityIdentifier("addTrackable")
            }
        }
        .sheet(item: $editorSubject) { subject in
            TrackableEditor(existing: subject.element) { store.upsert($0) }
        }
    }

    /// Drives the create/edit sheet: `.new` (create) or `.existing` (edit a specific element).
    private enum EditorSubject: Identifiable {
        case new
        case existing(TrackableElement)

        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let item): return item.id.uuidString
            }
        }
        var element: TrackableElement? {
            switch self {
            case .new: return nil
            case .existing(let item): return item
            }
        }
    }
}

private struct TrackableRow: View {
    let item: TrackableElement

    var body: some View {
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
        }
    }
}

/// Create / edit form, presented as a sheet. `existing == nil` is a create.
private struct TrackableEditor: View {
    @Environment(\.dismiss) private var dismiss
    private let existing: TrackableElement?
    private let onSave: (TrackableElement) -> Void
    @State private var label: String
    @State private var category: TrackableCategory

    init(existing: TrackableElement?, onSave: @escaping (TrackableElement) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _label = State(initialValue: existing?.label ?? "")
        _category = State(initialValue: existing?.category ?? .nutrition)
    }

    private var trimmedLabel: String { label.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label", text: $label)
                    .accessibilityIdentifier("trackableLabel")
                Picker("Category", selection: $category) {
                    ForEach(TrackableCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Trackable" : "Edit Trackable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var item = existing ?? TrackableElement(label: trimmedLabel, category: category)
                        item.label = trimmedLabel
                        item.category = category
                        onSave(item)
                        dismiss()
                    }
                    .disabled(trimmedLabel.isEmpty)
                    .accessibilityIdentifier("saveTrackable")
                }
            }
        }
    }
}

private extension TrackableCategory {
    var symbolName: String {
        switch self {
        case .nutrition: return "fork.knife"
        case .hydration: return "drop.fill"
        case .gear: return "backpack.fill"
        case .other: return "tag.fill"
        }
    }
}

#Preview {
    NavigationStack { TrackableLibraryView() }
}
