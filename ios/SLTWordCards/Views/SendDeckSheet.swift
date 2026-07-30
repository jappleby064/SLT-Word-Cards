import SwiftUI

/// Sends a deck to someone else's device.
///
/// Two carriers for one payload: a small `.sltdeck` file (AirDrop, Mail,
/// Messages, Files) or a link that opens in the web app. Neither contains
/// images — every install resolves the pictures from the shared card source —
/// and neither contains the client's name.
struct SendDeckSheet: View {
    let deck: Deck

    @Environment(CardLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var fileURL: URL?
    @State private var shareURL: URL?
    @State private var didCopyLink = false
    @State private var errorMessage: String?

    private var pack: DeckPack { DeckPack(deck: deck) }
    private var cards: [Card] { library.cards(ids: deck.cardIDs) }

    /// The sender's own cards, which a pack deliberately leaves out.
    private var excludedCount: Int {
        deck.cardIDs.filter(DeckPack.isCustomID).count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        HStack(spacing: -14) {
                            ForEach(Array(cards.prefix(4).enumerated()), id: \.offset) { _, card in
                                CardThumbnail(card: card, side: 44)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemBackground), lineWidth: 2))
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(deck.name)
                                .font(.headline)
                            Text(deck.cardCount == 1 ? "1 card" : "\(deck.cardCount) cards")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if excludedCount > 0 {
                    Section {
                        Label(
                            excludedCount == 1
                                ? "1 of your own cards won't be included."
                                : "\(excludedCount) of your own cards won't be included.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.orange)
                    } footer: {
                        Text("Cards you made yourself live only on your devices, so nobody else can open them. Everything else in the deck sends normally.")
                    }
                }

                Section {
                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Label("Send Link", systemImage: "link")
                        }
                        Button {
                            copyLink(shareURL)
                        } label: {
                            Label(didCopyLink ? "Link Copied" : "Copy Link",
                                  systemImage: didCopyLink ? "checkmark" : "doc.on.doc")
                        }
                    }
                } header: {
                    Text("Send")
                } footer: {
                    Text("A link is the simplest thing to send: it opens this app on a device that has it, and the web app on one that doesn't. Only the list of cards travels — no pictures and no client name — and it rides in the part of the address that never reaches a server.")
                }

                Section {
                    if let fileURL {
                        ShareLink(item: fileURL) {
                            Label("Send Deck File", systemImage: "doc")
                        }
                    }
                } header: {
                    Text("Or send a file")
                } footer: {
                    Text("Useful over AirDrop, or anywhere without a connection. It opens in the app, and the web app can open one too.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Send Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { prepare() }
        }
    }

    private func prepare() {
        do {
            fileURL = try pack.writeToTemporaryFile()
        } catch {
            errorMessage = "Couldn't prepare the deck file: \(error.localizedDescription)"
        }
        shareURL = pack.shareURL()
    }

    private func copyLink(_ url: URL) {
        UIPasteboard.general.string = url.absoluteString
        didCopyLink = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            didCopyLink = false
        }
    }
}
