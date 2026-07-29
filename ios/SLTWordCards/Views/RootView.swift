import SwiftUI

struct RootView: View {
    @Environment(CardLibrary.self) private var library
    @Environment(DeckLibrary.self) private var decks
    @Environment(ContentSync.self) private var sync
    @Environment(\.scenePhase) private var scenePhase

    /// The working selection built up in Search, shared with the save/print bar.
    @State private var selection = Selection()
    @State private var tab = Tab.search

    private enum Tab {
        case search, decks
    }

    var body: some View {
        TabView(selection: $tab) {
            SearchView(selection: selection)
                .tag(Tab.search)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            ClientsView()
                .tag(Tab.decks)
                .tabItem { Label("Decks", systemImage: "folder") }
                .badge(decks.totalDeckCount)
        }
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
    }
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
