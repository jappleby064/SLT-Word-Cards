import SwiftUI

/// Tier two: the decks saved under one learner.
struct LearnerDecksView: View {
    let learner: Learner

    @Environment(DeckLibrary.self) private var decks
    @Environment(CardLibrary.self) private var library

    @State private var isAddingDeck = false
    @State private var newDeckName = ""

    private var learnerDecks: [Deck] { decks.decks(for: learner) }

    var body: some View {
        List {
            if learnerDecks.isEmpty {
                ContentUnavailableView {
                    Label("No decks", systemImage: "rectangle.stack.badge.plus")
                } description: {
                    Text("Create a deck here, or build one from the Search tab and save it to \(learner.name).")
                } actions: {
                    Button("New Deck") { startAddingDeck() }
                        .buttonStyle(.borderedProminent)
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(learnerDecks) { deck in
                    NavigationLink(value: deck) {
                        row(for: deck)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        decks.delete(learnerDecks[index], from: learner)
                    }
                }
            }
        }
        .navigationTitle(learner.name)
        .navigationDestination(for: Deck.self) { deck in
            DeckDetailView(learner: learner, deckID: deck.id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startAddingDeck()
                } label: {
                    Label("New Deck", systemImage: "plus")
                }
            }
        }
        .alert("New Deck", isPresented: $isAddingDeck) {
            TextField("Deck name", text: $newDeckName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let name = newDeckName.trimmed
                guard !name.isEmpty else { return }
                decks.createDeck(named: name, for: learner, cardIDs: [])
            }
        }
    }

    private func row(for deck: Deck) -> some View {
        let cards = library.cards(ids: deck.cardIDs)
        return HStack(spacing: 12) {
            // A peek at the first few cards in the deck.
            HStack(spacing: -14) {
                ForEach(Array(cards.prefix(3).enumerated()), id: \.offset) { _, card in
                    CardThumbnail(card: card, side: 38)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemBackground), lineWidth: 2))
                }
            }
            .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(deck.name)
                    .font(.body.weight(.medium))
                Text(subtitle(for: deck))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func subtitle(for deck: Deck) -> String {
        let cardText = deck.cardCount == 1 ? "1 card" : "\(deck.cardCount) cards"
        return "\(cardText) · edited \(deck.updatedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func startAddingDeck() {
        newDeckName = ""
        isAddingDeck = true
    }
}
