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

                Section {
                    if let fileURL {
                        ShareLink(item: fileURL) {
                            Label("Send Deck File", systemImage: "doc")
                        }
                    }
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
                    Text("The deck file opens straight into the app. The link opens in the web app, and offers to open the app if it's installed. Either way only the list of cards travels — no pictures and no client name.")
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
