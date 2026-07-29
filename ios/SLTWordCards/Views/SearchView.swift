import SwiftUI

/// Search and filter the catalogue, then tick cards to build a selection —
/// the same flow as the web app, with the selection feeding either the on-device
/// presenter or the print sheet.
struct SearchView: View {
    let selection: Selection

    @Environment(CardLibrary.self) private var library
    @Environment(ContentSync.self) private var sync

    @State private var criteria = SearchCriteria()
    @State private var destination: SelectionDestination?

    private var results: [Card] {
        library.search(criteria)
    }

    var body: some View {
        NavigationStack {
            List {
                filtersSection

                Section {
                    if results.isEmpty {
                        ContentUnavailableView(
                            "No matches",
                            systemImage: "magnifyingglass",
                            description: Text("Try clearing a filter.")
                        )
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(results) { card in
                            resultRow(card)
                        }
                    }
                } header: {
                    HStack {
                        Text(results.count == 1 ? "1 card" : "\(results.count) cards")
                        Spacer()
                        if !results.isEmpty {
                            Button(allSelected ? "Deselect all" : "Select all") {
                                if allSelected {
                                    selection.remove(results.map(\.id))
                                } else {
                                    selection.add(results.map(\.id))
                                }
                            }
                            .font(.footnote.weight(.medium))
                            .textCase(nil)
                        }
                    }
                } footer: {
                    SyncStatusLabel()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Word Cards")
            .searchable(text: $criteria.rawQuery, prompt: "Word or number")
            .refreshable { await sync.sync(library: library) }
            .safeAreaInset(edge: .bottom) {
                if !selection.isEmpty {
                    SelectionBar(selection: selection) { destination = $0 }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        criteria.clear()
                        selection.clear()
                    }
                    .disabled(criteria.isEmpty && selection.isEmpty)
                }
            }
            .sheet(item: $destination) { destination in
                switch destination {
                case .present:
                    PresenterView(cards: selectedCards, title: "Selection")
                case .print:
                    PrintSheet(cards: selectedCards, initialCopies: 1, jobName: "word-cards")
                case .save:
                    SaveDeckSheet(cardIDs: selection.ids)
                }
            }
        }
    }

    private var selectedCards: [Card] {
        library.cards(ids: selection.ids)
    }

    private var allSelected: Bool {
        !results.isEmpty && results.allSatisfy { selection.contains($0.id) }
    }

    // MARK: Filters

    private var filtersSection: some View {
        Section("Filters") {
            CardFilterControls(criteria: $criteria, structures: library.structures)
        }
    }

    private func resultRow(_ card: Card) -> some View {
        CardSelectRow(card: card, isSelected: selection.contains(card.id)) {
            selection.toggle(card.id)
        }
    }
}

/// What the user wants to do with the current selection.
enum SelectionDestination: Int, Identifiable {
    case present
    case print
    case save

    var id: Int { rawValue }
}

/// Bottom bar: how many cards are picked, and the three things you can do next.
struct SelectionBar: View {
    let selection: Selection
    let action: (SelectionDestination) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(selection.count == 1 ? "1 card selected" : "\(selection.count) cards selected")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    action(.present)
                } label: {
                    Label("Present", systemImage: "play.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    action(.print)
                } label: {
                    Label("Print", systemImage: "printer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    action(.save)
                } label: {
                    Label("Save", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

/// Where the card list came from and when it was last checked.
struct SyncStatusLabel: View {
    @Environment(ContentSync.self) private var sync
    @Environment(DeckLibrary.self) private var decks

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(syncText)
            Text(decks.location.label)
        }
        .font(.caption2)
    }

    private var syncText: String {
        switch sync.status {
        case .idle: "Cards ready to use offline."
        case .checking: "Checking for new cards…"
        case .upToDate(let date): "Card list up to date · checked \(date.formatted(date: .omitted, time: .shortened))"
        case .updated(let cards, let images, _):
            images > 0
                ? "Updated: \(cards) cards, \(images) new pictures downloaded."
                : "Updated: \(cards) cards."
        case .offline: "Offline — using cards saved on this device."
        case .failed(let message): "Couldn't check for updates: \(message)"
        }
    }
}
