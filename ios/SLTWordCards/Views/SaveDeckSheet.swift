import SwiftUI

/// Saves the current selection as a named deck, filed under a learner — either a
/// brand new deck or appended to one that already exists.
struct SaveDeckSheet: View {
    let cardIDs: [Card.ID]

    @Environment(DeckLibrary.self) private var decks
    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable {
        case newDeck = "New Deck"
        case existingDeck = "Add to Deck"
    }

    /// `nil` tag means "create a new learner".
    @State private var mode: Mode = .newDeck
    @State private var learnerID: Learner.ID?
    @State private var newLearnerName = ""
    @State private var deckName = ""
    @State private var deckID: Deck.ID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(cardIDs.count == 1 ? "1 card" : "\(cardIDs.count) cards")
                        .font(.body.weight(.medium))
                } header: {
                    Text("Saving")
                }

                Section("Learner") {
                    Picker("Learner", selection: $learnerID) {
                        ForEach(decks.teacherLearners) { learner in
                            Text(learner.name).tag(Learner.ID?.some(learner.id))
                        }
                        Text("New learner…").tag(Learner.ID?.none)
                    }

                    if learnerID == nil {
                        TextField("Learner name", text: $newLearnerName)
                            .textInputAutocapitalization(.words)
                    }
                }

                Section("Deck") {
                    if !availableDecks.isEmpty {
                        Picker("", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    if mode == .existingDeck, !availableDecks.isEmpty {
                        Picker("Deck", selection: $deckID) {
                            ForEach(availableDecks) { deck in
                                Text("\(deck.name) (\(deck.cardCount))").tag(Deck.ID?.some(deck.id))
                            }
                        }
                    } else {
                        TextField("Deck name", text: $deckName)
                            .textInputAutocapitalization(.words)
                    }
                }
            }
            .navigationTitle("Save Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                learnerID = decks.teacherLearners.first?.id
                if deckName.isEmpty {
                    deckName = Self.suggestedName()
                }
            }
            .onChange(of: learnerID) { _, _ in
                deckID = availableDecks.first?.id
                if availableDecks.isEmpty { mode = .newDeck }
            }
        }
    }

    private var selectedLearner: Learner? {
        decks.teacherLearners.first { $0.id == learnerID }
    }

    private var availableDecks: [Deck] {
        selectedLearner.map { decks.decks(for: $0) } ?? []
    }

    private var canSave: Bool {
        guard !cardIDs.isEmpty else { return false }
        let learnerOK = learnerID != nil || !newLearnerName.trimmed.isEmpty
        let deckOK = mode == .existingDeck ? deckID != nil : !deckName.trimmed.isEmpty
        return learnerOK && deckOK
    }

    private func save() {
        let learner: Learner
        if let existing = selectedLearner {
            learner = existing
        } else {
            learner = decks.addLearner(named: newLearnerName)
        }

        if mode == .existingDeck, let deckID, let deck = decks.deck(id: deckID, in: learner) {
            decks.add(cardIDs: cardIDs, to: deck, for: learner)
        } else {
            decks.createDeck(named: deckName, for: learner, cardIDs: cardIDs)
        }
        dismiss()
    }

    private static func suggestedName() -> String {
        "Deck \(Date().formatted(date: .abbreviated, time: .omitted))"
    }
}
