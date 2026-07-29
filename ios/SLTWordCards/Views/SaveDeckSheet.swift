import SwiftUI

/// Saves the current selection as a named deck, filed under a client — either a
/// brand new deck or appended to one that already exists.
struct SaveDeckSheet: View {
    let cardIDs: [Card.ID]

    @Environment(DeckLibrary.self) private var decks
    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable {
        case newDeck = "New Deck"
        case existingDeck = "Add to Deck"
    }

    /// `nil` tag means "create a new client".
    @State private var mode: Mode = .newDeck
    @State private var clientID: Client.ID?
    @State private var newClientName = ""
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

                Section("Client") {
                    Picker("Client", selection: $clientID) {
                        ForEach(decks.clients) { client in
                            Text(client.name).tag(Client.ID?.some(client.id))
                        }
                        Text("New client…").tag(Client.ID?.none)
                    }

                    if clientID == nil {
                        TextField("Client name", text: $newClientName)
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
                clientID = decks.clients.first?.id
                if deckName.isEmpty {
                    deckName = Self.suggestedName()
                }
            }
            .onChange(of: clientID) { _, _ in
                deckID = availableDecks.first?.id
                if availableDecks.isEmpty { mode = .newDeck }
            }
        }
    }

    private var selectedClient: Client? {
        decks.clients.first { $0.id == clientID }
    }

    private var availableDecks: [Deck] {
        selectedClient.map { decks.decks(for: $0) } ?? []
    }

    private var canSave: Bool {
        guard !cardIDs.isEmpty else { return false }
        let clientOK = clientID != nil || !newClientName.trimmed.isEmpty
        let deckOK = mode == .existingDeck ? deckID != nil : !deckName.trimmed.isEmpty
        return clientOK && deckOK
    }

    private func save() {
        let client: Client
        if let existing = selectedClient {
            client = existing
        } else {
            client = decks.addClient(named: newClientName)
        }

        if mode == .existingDeck, let deckID, let deck = decks.deck(id: deckID, in: client) {
            decks.add(cardIDs: cardIDs, to: deck, for: client)
        } else {
            decks.createDeck(named: deckName, for: client, cardIDs: cardIDs)
        }
        dismiss()
    }

    private static func suggestedName() -> String {
        "Deck \(Date().formatted(date: .abbreviated, time: .omitted))"
    }
}
