import Foundation
import UniformTypeIdentifiers

/// A shareable deck: just a name and a list of card ids.
///
/// Packs carry no images and no learner identity. Every install resolves cards
/// from the same shared source (`cards.csv` + `images/`), so naming the cards is
/// enough — which keeps a pack around a kilobyte and means it can travel by
/// AirDrop, message, or email. Leaving out the learner's name is deliberate: a
/// pack sent to a learner's own device should not contain their identity.
struct DeckPack: Codable, Sendable {
    static let formatIdentifier = "slt-word-cards.deck"
    static let currentVersion = 1
    static let fileExtension = "sltdeck"

    var format: String
    var version: Int
    var name: String
    var cardIDs: [Card.ID]
    var printCopies: Int
    var createdAt: Date

    init(deck: Deck) {
        self.format = Self.formatIdentifier
        self.version = Self.currentVersion
        self.name = deck.name
        // A recipient has no copy of the sender's own cards, so sending their ids
        // would only produce cards that can't resolve. `SendDeckSheet` tells the
        // user which ones were left behind.
        self.cardIDs = deck.cardIDs.filter { !Self.isCustomID($0) }
        self.printCopies = deck.printCopies
        self.createdAt = Date()
    }

    /// Custom cards live in their own id namespace — see `Card.id`.
    static func isCustomID(_ id: Card.ID) -> Bool {
        id.hasPrefix("custom|")
    }

    // MARK: Encoding

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Writes the pack to a temporary file ready to hand to the share sheet.
    func writeToTemporaryFile() throws -> URL {
        let data = try Self.encoder.encode(self)
        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(Self.sanitise(name)).\(Self.fileExtension)", directoryHint: .notDirectory)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Reads a pack that arrived from another device, validating it is one of
    /// ours before anything is saved.
    static func load(from url: URL) throws -> DeckPack {
        // Files handed over by Files/AirDrop may be security scoped.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PackError.unreadable
        }

        let pack: DeckPack
        do {
            pack = try decoder.decode(DeckPack.self, from: data)
        } catch {
            throw PackError.notADeck
        }

        guard pack.format == formatIdentifier else { throw PackError.notADeck }
        guard pack.version <= currentVersion else { throw PackError.tooNew }
        guard !pack.cardIDs.isEmpty else { throw PackError.empty }
        return pack
    }

    // MARK: Links
    //
    // The same pack also travels as a link, which is how the web app shares
    // decks. The payload is base64url-encoded JSON in the URL *fragment*, so it
    // is never sent to a server — the card list stays on the two devices.
    //
    //   https://speakeasy-slt.uk/deck/#deck=<payload>   (universal link)
    //   sltcards://deck?d=<payload>                     (older fallback)
    //
    // The https form is the one to share: a device with the app opens it there
    // directly, and one without it lands on the web app instead. `/deck/` is its
    // own path so that claiming it does not hijack every link to the site.
    //
    // Compact keys keep a twelve-card link short enough to paste into a message.

    private struct Payload: Codable {
        var v: Int
        var n: String
        var c: [String]
        var p: Int
    }

    /// The shareable link for this pack. Opens the app where it is installed and
    /// the web app where it isn't.
    func shareURL(webBase: String = "https://speakeasy-slt.uk/deck/") -> URL? {
        guard let encoded = encodedPayload() else { return nil }
        return URL(string: "\(webBase)#deck=\(encoded)")
    }

    func encodedPayload() -> String? {
        let payload = Payload(v: version, n: name, c: cardIDs.map(Self.shorten), p: printCopies)
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return data.base64URLEncodedString()
    }

    /// Word-card ids all end in the same `|word|`, which is pure repetition in a
    /// link. Send the bare word instead and let `expand` put it back. Number
    /// cards keep their full id because their variant matters.
    ///
    /// Nothing needs a version bump: an entry containing "|" is a full id, so
    /// links made before this change still open.
    static func shorten(_ id: Card.ID) -> String {
        let parts = id.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[1] == Card.Kind.word.rawValue, parts[2].isEmpty else {
            return id
        }
        return String(parts[0])
    }

    static func expand(_ token: String) -> Card.ID {
        token.contains("|") ? token : "\(token)|\(Card.Kind.word.rawValue)|"
    }

    /// Reads a pack out of a web link's `#deck=` fragment or a `sltcards://`
    /// URL. Returns nil when the URL simply isn't a deck link.
    static func fromLink(_ url: URL) -> DeckPack? {
        guard let encoded = payloadComponent(of: url) else { return nil }
        return decodePayload(encoded)
    }

    static func decodePayload(_ encoded: String) -> DeckPack? {
        guard let data = Data(base64URLEncoded: encoded),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.v <= currentVersion,
              !payload.c.isEmpty else {
            return nil
        }

        var pack = DeckPack(deck: Deck(
            name: payload.n,
            cardIDs: payload.c.map(expand),
            printCopies: max(1, payload.p)
        ))
        pack.version = payload.v
        return pack
    }

    /// Accepts a full web URL, a custom-scheme URL, or a bare payload pasted by
    /// the user.
    static func payloadComponent(of url: URL) -> String? {
        if let fragment = url.fragment(percentEncoded: false),
           let value = value(named: "deck", inQuery: fragment) {
            return value
        }
        if let query = url.query(percentEncoded: false),
           let value = value(named: "d", inQuery: query) ?? value(named: "deck", inQuery: query) {
            return value
        }
        return nil
    }

    private static func value(named name: String, inQuery query: String) -> String? {
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2, parts[0] == name {
                return String(parts[1])
            }
        }
        return nil
    }

    private static func sanitise(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
            .trimmed
        return cleaned.isEmpty ? "Deck" : cleaned
    }

    enum PackError: LocalizedError {
        case unreadable
        case notADeck
        case tooNew
        case empty

        var errorDescription: String? {
            switch self {
            case .unreadable: "That file could not be opened."
            case .notADeck: "That file isn't an SLT card deck."
            case .tooNew: "This deck was made with a newer version of the app. Update to open it."
            case .empty: "That deck is empty."
            }
        }
    }
}

extension UTType {
    /// Declared in the target's Info.plist (`UTExportedTypeDeclarations`).
    static let sltDeck = UTType(exportedAs: "com.applebytechnical.sltwordcards.deck")
}

// Base64url (RFC 4648 §5): URL-safe alphabet, padding stripped, so a payload can
// sit in a link untouched. The web app uses the identical transform.
extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var padded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if padded.count % 4 != 0 {
            padded.append(String(repeating: "=", count: 4 - padded.count % 4))
        }
        guard let data = Data(base64Encoded: padded) else { return nil }
        self = data
    }
}
