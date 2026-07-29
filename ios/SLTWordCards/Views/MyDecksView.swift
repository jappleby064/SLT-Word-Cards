import SwiftUI
import UniformTypeIdentifiers

/// Client mode's deck list: one flat list, no clients and no grouping. Decks can
/// be made here, and packs sent by a therapist can be opened into it.
struct MyDecksView: View {
    @Environment(DeckLibrary.self) private var decks
    @Environment(CardLibrary.self) private var library

    @State private var collection: Client?
    @State private var isAddingDeck = false
    @State private var newDeckName = ""
    @State private var isShowingFileImporter = false
    @State private var isShowingLinkImporter = false
    @State private var importError: String?

    private var myDecks: [Deck] {
        collection.map { decks.decks(for: $0) } ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                if myDecks.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No decks yet", systemImage: "rectangle.stack")
                        } description: {
                            Text("Make a deck from the Search tab, or open a deck your therapist sent you.")
                        } actions: {
                            VStack(spacing: 10) {
                                Button("New Deck") { startAddingDeck() }
                                    .buttonStyle(.borderedProminent)
                                Button("Open a Shared Deck") { isShowingFileImporter = true }
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        ForEach(myDecks) { deck in
                            NavigationLink(value: deck) {
                                row(for: deck)
                            }
                        }
                        .onDelete { offsets in
                            guard let collection else { return }
                            for index in offsets {
                                decks.delete(myDecks[index], from: collection)
                            }
                        }
                    } footer: {
                        Text(decks.location == .iCloud
                             ? "Your decks are kept in your private iCloud Drive and appear on your other devices."
                             : "Your decks are kept on this device.")
                    }
                }
            }
            .navigationTitle("My Decks")
            .navigationDestination(for: Deck.self) { deck in
                if let collection {
                    DeckDetailView(client: collection, deckID: deck.id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            startAddingDeck()
                        } label: {
                            Label("New Deck", systemImage: "plus")
                        }
                        Button {
                            isShowingFileImporter = true
                        } label: {
                            Label("Open Deck File…", systemImage: "doc.badge.plus")
                        }
                        Button {
                            isShowingLinkImporter = true
                        } label: {
                            Label("Open Deck Link…", systemImage: "link")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .task {
                // Created lazily so a therapist-only install never grows an
                // empty "My Decks" folder.
                if collection == nil, decks.isReady {
                    collection = decks.personalCollection()
                }
            }
            .onChange(of: decks.isReady) { _, ready in
                if ready, collection == nil {
                    collection = decks.personalCollection()
                }
            }
            .alert("New Deck", isPresented: $isAddingDeck) {
                TextField("Deck name", text: $newDeckName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    guard let collection, !newDeckName.trimmed.isEmpty else { return }
                    decks.createDeck(named: newDeckName, for: collection, cardIDs: [])
                }
            }
            .sheet(isPresented: $isShowingLinkImporter) {
                ImportLinkSheet { pack in
                    save(pack)
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.sltDeck, .json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Couldn't open that deck", isPresented: .init(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func row(for deck: Deck) -> some View {
        let cards = library.cards(ids: deck.cardIDs)
        return HStack(spacing: 12) {
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
                HStack(spacing: 6) {
                    if deck.isImported {
                        Label("Shared with me", systemImage: "tray.and.arrow.down")
                            .font(.caption2)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(deck.cardCount == 1 ? "1 card" : "\(deck.cardCount) cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func startAddingDeck() {
        newDeckName = ""
        isAddingDeck = true
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                save(try DeckPack.load(from: url))
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func save(_ pack: DeckPack) {
        let target = collection ?? decks.personalCollection()
        collection = target
        decks.importPack(pack, for: target)
    }
}

/// Paste a deck link (or a bare payload) to open it — the counterpart to the web
/// app's "Copy link".
struct ImportLinkSheet: View {
    let onImport: (DeckPack) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste link", text: $text, axis: .vertical)
                        .lineLimit(2...5)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Deck link")
                } footer: {
                    Text("Paste the link your therapist sent you. The deck is read straight from the link — nothing is uploaded.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Open Deck Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Open", action: open)
                        .fontWeight(.semibold)
                        .disabled(text.trimmed.isEmpty)
                }
            }
        }
    }

    private func open() {
        let trimmed = text.trimmed
        // Accept a full URL or a bare payload someone copied out of one.
        if let url = URL(string: trimmed), let pack = DeckPack.fromLink(url) {
            onImport(pack)
            dismiss()
            return
        }
        if let pack = DeckPack.decodePayload(trimmed) {
            onImport(pack)
            dismiss()
            return
        }
        errorMessage = "That doesn't look like a deck link. Check you copied all of it."
    }
}
