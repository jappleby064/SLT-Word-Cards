import SwiftUI

/// An editable deck: reorder, remove, add more cards, then present it on the
/// device or export it for print.
struct DeckDetailView: View {
    let client: Client
    let deckID: Deck.ID

    @Environment(DeckLibrary.self) private var decks
    @Environment(CardLibrary.self) private var library

    @State private var isPresenting = false
    @State private var isPrinting = false
    @State private var isAddingCards = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var editMode: EditMode = .inactive
    @State private var isSharing = false

    private var deck: Deck? {
        decks.deck(id: deckID, in: client)
    }

    var body: some View {
        Group {
            if let deck {
                content(for: deck)
            } else {
                ContentUnavailableView("Deck not found", systemImage: "questionmark.folder")
            }
        }
        .navigationTitle(deck?.name ?? "Deck")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        renameText = deck?.name ?? ""
                        isRenaming = true
                    } label: {
                        Label("Rename Deck", systemImage: "pencil")
                    }
                    Button {
                        isAddingCards = true
                    } label: {
                        Label("Add Cards", systemImage: "plus.rectangle.on.rectangle")
                    }
                    Button {
                        editMode = editMode == .active ? .inactive : .active
                    } label: {
                        Label(editMode == .active ? "Done Reordering" : "Reorder", systemImage: "arrow.up.arrow.down")
                    }
                    if let deck {
                        Button {
                            shuffleSaved(deck)
                        } label: {
                            Label("Shuffle Saved Order", systemImage: "shuffle")
                        }
                        Divider()
                        Button {
                            isSharing = true
                        } label: {
                            Label("Send Deck…", systemImage: "square.and.arrow.up")
                        }
                        .disabled(deck.cardIDs.isEmpty)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isSharing) {
            if let deck {
                SendDeckSheet(deck: deck)
            }
        }
        .sheet(isPresented: $isPresenting) {
            if let deck {
                PresenterView(cards: library.cards(ids: deck.cardIDs), title: deck.name)
            }
        }
        .sheet(isPresented: $isPrinting) {
            if let deck {
                PrintSheet(
                    cards: library.cards(ids: deck.cardIDs),
                    initialCopies: deck.printCopies,
                    jobName: "\(client.name) - \(deck.name)"
                ) { copies in
                    var updated = deck
                    updated.printCopies = copies
                    decks.save(updated, for: client)
                }
            }
        }
        .sheet(isPresented: $isAddingCards) {
            if let deck {
                AddCardsSheet(existing: Set(deck.cardIDs)) { picked in
                    decks.add(cardIDs: picked, to: deck, for: client)
                }
            }
        }
        .alert("Rename Deck", isPresented: $isRenaming) {
            TextField("Deck name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                guard var updated = deck, !renameText.trimmed.isEmpty else { return }
                updated.name = renameText.trimmed
                decks.save(updated, for: client)
            }
        }
    }

    private func content(for deck: Deck) -> some View {
        let cards = library.cards(ids: deck.cardIDs)

        return List {
            Section {
                if cards.isEmpty {
                    ContentUnavailableView {
                        Label("Empty deck", systemImage: "rectangle.on.rectangle.slash")
                    } description: {
                        Text("Add cards to get started.")
                    } actions: {
                        Button("Add Cards") { isAddingCards = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(cards) { card in
                        HStack(spacing: 12) {
                            CardThumbnail(card: card)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.label)
                                    .font(.body.weight(.medium))
                                CardDetailLine(card: card)
                            }
                        }
                    }
                    .onDelete { offsets in
                        var updated = deck
                        for index in offsets.sorted(by: >) where index < cards.count {
                            updated.remove(cards[index].id)
                        }
                        decks.save(updated, for: client)
                    }
                    .onMove { source, destination in
                        var updated = deck
                        updated.cardIDs.move(fromOffsets: source, toOffset: destination)
                        decks.save(updated, for: client)
                    }
                }
            } header: {
                Text(cards.count == 1 ? "1 card" : "\(cards.count) cards")
            } footer: {
                if cards.count < deck.cardCount {
                    Text("\(deck.cardCount - cards.count) card(s) in this deck are no longer in the card list.")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !cards.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        isPresenting = true
                    } label: {
                        Label("Use on Device", systemImage: "play.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        isPrinting = true
                    } label: {
                        Label("Export for Print", systemImage: "printer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private func shuffleSaved(_ deck: Deck) {
        var updated = deck
        updated.cardIDs.shuffle()
        decks.save(updated, for: client)
    }
}

/// Search picker for adding cards to an existing deck.
struct AddCardsSheet: View {
    let existing: Set<Card.ID>
    let onAdd: ([Card.ID]) -> Void

    @Environment(CardLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var criteria = SearchCriteria()
    @State private var picked: [Card.ID] = []

    private var results: [Card] {
        library.search(criteria)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Filters") {
                    CardFilterControls(criteria: $criteria, structures: library.structures)
                }

                Section(results.count == 1 ? "1 card" : "\(results.count) cards") {
                    ForEach(results) { card in
                        if existing.contains(card.id) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.tertiary)
                                CardThumbnail(card: card)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.label)
                                    Text("Already in deck")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            CardSelectRow(card: card, isSelected: picked.contains(card.id)) {
                                if let index = picked.firstIndex(of: card.id) {
                                    picked.remove(at: index)
                                } else {
                                    picked.append(card.id)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $criteria.rawQuery, prompt: "Word or number")
            .navigationTitle("Add Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(picked.isEmpty ? "Add" : "Add \(picked.count)") {
                        onAdd(picked)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(picked.isEmpty)
                }
            }
        }
    }
}
