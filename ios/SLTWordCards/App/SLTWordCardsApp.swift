import SwiftUI

@main
struct SLTWordCardsApp: App {
    @State private var library = CardLibrary()
    @State private var decks = DeckLibrary()
    @State private var sync = ContentSync()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(decks)
                .environment(sync)
        }
    }
}
