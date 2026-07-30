import SwiftUI

@main
struct SLTWordCardsApp: App {
    @State private var library = CardLibrary()
    @State private var decks = DeckLibrary()
    @State private var sync = ContentSync()
    @State private var settings = AppSettings()
    @State private var customCards = CustomCardStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(decks)
                .environment(sync)
                .environment(settings)
                .environment(customCards)
        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 1100, height: 800)
        #endif
    }
}
