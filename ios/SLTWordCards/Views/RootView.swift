import SwiftUI

struct RootView: View {
    @Environment(CardLibrary.self) private var library
    @Environment(DeckLibrary.self) private var decks
    @Environment(ContentSync.self) private var sync
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    /// The working selection built up in Search, shared with the save/print bar.
    @State private var selection = Selection()
    @State private var tab = Tab.search
    /// A pack that arrived from a file or link and is waiting for confirmation.
    @State private var incomingPack: DeckPack?

    private enum Tab {
        case search, decks, settings
    }

    var body: some View {
        tabs
            .task {
                // Poll for new cards on open; bundled content already works offline.
                await decks.bootstrap()
                await sync.syncIfStale(library: library)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    decks.reload()          // pick up edits from another device
                    await sync.syncIfStale(library: library)
                }
            }
            .onOpenURL { url in
                handleIncoming(url)
            }
            .sheet(item: $incomingPack) { pack in
                ReceivedPackSheet(pack: pack)
            }
            .fullScreenCover(isPresented: .init(
                get: { !settings.hasChosenMode },
                set: { _ in }
            )) {
                ModeChooserView()
            }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            SearchView(selection: selection)
                .tag(Tab.search)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            deckTab
                .tag(Tab.decks)
                .tabItem {
                    Label(
                        settings.effectiveMode == .client ? "My Decks" : "Decks",
                        systemImage: settings.effectiveMode == .client ? "rectangle.stack" : "folder"
                    )
                }
                .badge(deckBadge)

            SettingsView()
                .tag(Tab.settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }

    @ViewBuilder
    private var deckTab: some View {
        switch settings.effectiveMode {
        case .therapist: ClientsView()
        case .client: MyDecksView()
        }
    }

    /// In client mode the badge counts their own decks, not every stored deck.
    private var deckBadge: Int {
        switch settings.effectiveMode {
        case .therapist:
            return decks.therapistClients.reduce(0) { $0 + decks.decks(for: $1).count }
        case .client:
            guard let personal = decks.clients.first(where: { $0.id == DeckLibrary.personalClientID }) else {
                return 0
            }
            return decks.decks(for: personal).count
        }
    }

    private func handleIncoming(_ url: URL) {
        // A deck link, from the web app or a message.
        if let pack = DeckPack.fromLink(url) {
            incomingPack = pack
            return
        }
        // A .sltdeck file opened from Files, Mail, or AirDrop.
        if let pack = try? DeckPack.load(from: url) {
            incomingPack = pack
        }
    }
}

/// Confirms a pack before it is saved, and says plainly what will happen.
struct ReceivedPackSheet: View {
    let pack: DeckPack

    @Environment(DeckLibrary.self) private var decks
    @Environment(CardLibrary.self) private var library
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var clientID: Client.ID?
    @State private var savedDeck: (client: Client, deck: Deck)?

    private var resolved: [Card] { library.cards(ids: pack.cardIDs) }
    private var missingCount: Int { pack.cardIDs.count - resolved.count }

    var body: some View {
        NavigationStack {
            Group {
                if let savedDeck {
                    PresenterView(cards: library.cards(ids: savedDeck.deck.cardIDs), title: savedDeck.deck.name)
                } else {
                    form
                }
            }
        }
    }

    private var form: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    HStack(spacing: -14) {
                        ForEach(Array(resolved.prefix(4).enumerated()), id: \.offset) { _, card in
                            CardThumbnail(card: card, side: 44)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemBackground), lineWidth: 2))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pack.name)
                            .font(.headline)
                        Text(pack.cardIDs.count == 1 ? "1 card" : "\(pack.cardIDs.count) cards")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Shared deck")
            } footer: {
                if missingCount > 0 {
                    Text("\(missingCount) card(s) aren't in your card list yet. They'll appear once the app picks up the latest cards.")
                }
            }

            if settings.effectiveMode == .therapist {
                Section("Save under") {
                    Picker("Client", selection: $clientID) {
                        ForEach(decks.therapistClients) { client in
                            Text(client.name).tag(Client.ID?.some(client.id))
                        }
                        Text("My Decks").tag(Client.ID?.none)
                    }
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    Label("Save to My Decks", systemImage: "square.and.arrow.down")
                }
                .disabled(resolved.isEmpty && missingCount == 0)
            } footer: {
                Text("Nothing was uploaded — this deck was read straight from the file or link.")
            }
        }
        .navigationTitle("Open Deck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            if settings.effectiveMode == .therapist {
                clientID = decks.therapistClients.first?.id
            }
        }
    }

    private func save() {
        let target: Client
        if settings.effectiveMode == .therapist, let clientID,
           let client = decks.clients.first(where: { $0.id == clientID }) {
            target = client
        } else {
            target = decks.personalCollection()
        }
        let deck = decks.importPack(pack, for: target)
        savedDeck = (target, deck)
    }
}

extension DeckPack: Identifiable {
    // Sheets need an identity; a pack is presented one at a time.
    var id: String { "\(name)-\(cardIDs.count)-\(createdAt.timeIntervalSince1970)" }
}

/// Cards ticked in the search results, kept as an ordered list so the deck and
/// the print sheet come out in the order they were found.
@Observable
final class Selection {
    private(set) var ids: [Card.ID] = []

    var count: Int { ids.count }
    var isEmpty: Bool { ids.isEmpty }

    func contains(_ id: Card.ID) -> Bool { ids.contains(id) }

    func toggle(_ id: Card.ID) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
    }

    func add(_ newIDs: [Card.ID]) {
        let existing = Set(ids)
        ids.append(contentsOf: newIDs.filter { !existing.contains($0) })
    }

    func remove(_ removed: [Card.ID]) {
        let drop = Set(removed)
        ids.removeAll { drop.contains($0) }
    }

    func clear() { ids.removeAll() }
}
