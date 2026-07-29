import Foundation

/// Saved decks, organised in two tiers: **Client → Deck**.
///
/// On disk each deck is its own JSON file:
/// ```
/// <root>/Clients/<clientID>/client.json
/// <root>/Clients/<clientID>/Decks/<deckID>.json
/// ```
/// `<root>` is the app's private iCloud Drive container when available, so decks
/// follow the user between their own devices. There is no sharing surface: the
/// container is private to the user's Apple Account. With no iCloud account
/// signed in, the same layout is used inside Application Support and everything
/// keeps working locally.
@Observable
@MainActor
final class DeckLibrary {
    enum Location: Equatable {
        case iCloud
        case localOnly

        var label: String {
            switch self {
            case .iCloud: "Syncing with iCloud"
            case .localOnly: "Saved on this device"
            }
        }
    }

    private(set) var clients: [Client] = []
    /// Decks keyed by client id.
    private(set) var decksByClient: [Client.ID: [Deck]] = [:]
    private(set) var location: Location = .localOnly
    private(set) var isReady = false

    private var root: URL = DeckStorage.localRoot
    private let coder = DeckStorage.Coder()

    // MARK: Lifecycle

    /// Resolves the storage root off the main thread — asking for the ubiquity
    /// container can block — then loads what's there.
    func bootstrap() async {
        let resolved = await DeckStorage.resolveRoot()
        root = resolved.url
        location = resolved.location

        if resolved.location == .iCloud {
            await DeckStorage.migrateLocalContentIfNeeded(to: resolved.url)
            await DeckStorage.requestDownloads(in: resolved.url)
        }

        reload()
        isReady = true
    }

    /// Re-reads from disk. Called on foreground so edits made on another device
    /// show up.
    func reload() {
        let snapshot = coder.readAll(root: root)
        clients = snapshot.clients.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        decksByClient = snapshot.decksByClient.mapValues { decks in
            decks.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    // MARK: Reading

    func decks(for client: Client) -> [Deck] {
        decksByClient[client.id] ?? []
    }

    func deck(id: Deck.ID, in client: Client) -> Deck? {
        decks(for: client).first { $0.id == id }
    }

    var totalDeckCount: Int {
        decksByClient.values.reduce(0) { $0 + $1.count }
    }

    // MARK: Clients

    @discardableResult
    func addClient(named name: String) -> Client {
        let client = Client(name: name.trimmed)
        coder.write(client, root: root)
        clients.append(client)
        clients.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        decksByClient[client.id] = []
        return client
    }

    func rename(_ client: Client, to name: String) {
        guard let index = clients.firstIndex(where: { $0.id == client.id }) else { return }
        clients[index].name = name.trimmed
        coder.write(clients[index], root: root)
        clients.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func delete(_ client: Client) {
        coder.deleteClientDirectory(client, root: root)
        clients.removeAll { $0.id == client.id }
        decksByClient[client.id] = nil
    }

    // MARK: Decks

    @discardableResult
    func createDeck(named name: String, for client: Client, cardIDs: [Card.ID], printCopies: Int = 1) -> Deck {
        let deck = Deck(name: name.trimmed, cardIDs: cardIDs, printCopies: max(1, printCopies))
        coder.write(deck, for: client, root: root)
        decksByClient[client.id, default: []].insert(deck, at: 0)
        return deck
    }

    /// Persists an edited deck and refreshes it in memory.
    func save(_ deck: Deck, for client: Client) {
        var updated = deck
        updated.updatedAt = Date()
        coder.write(updated, for: client, root: root)

        var decks = decksByClient[client.id] ?? []
        if let index = decks.firstIndex(where: { $0.id == updated.id }) {
            decks[index] = updated
        } else {
            decks.append(updated)
        }
        decksByClient[client.id] = decks.sorted { $0.updatedAt > $1.updatedAt }
    }

    func delete(_ deck: Deck, from client: Client) {
        coder.delete(deck, for: client, root: root)
        decksByClient[client.id]?.removeAll { $0.id == deck.id }
    }

    /// Adds cards to an existing deck, skipping ones already in it.
    /// Returns how many were actually added.
    @discardableResult
    func add(cardIDs: [Card.ID], to deck: Deck, for client: Client) -> Int {
        var updated = deck
        let before = updated.cardIDs.count
        updated.add(cardIDs)
        save(updated, for: client)
        return updated.cardIDs.count - before
    }
}

// MARK: - Storage

enum DeckStorage {
    private static let clientsDirectoryName = "Clients"
    private static let decksDirectoryName = "Decks"
    private static let clientFileName = "client.json"

    static let localRoot: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appending(path: "DeckLibrary", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Ubiquity container if the user has iCloud Drive available, else local.
    /// Runs off the main actor because `url(forUbiquityContainerIdentifier:)` can block.
    static func resolveRoot() async -> (url: URL, location: DeckLibrary.Location) {
        await Task.detached(priority: .userInitiated) { () -> (URL, DeckLibrary.Location) in
            guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                return (localRoot, .localOnly)
            }
            let documents = container.appending(path: "Documents", directoryHint: .isDirectory)
            do {
                try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
                return (documents, .iCloud)
            } catch {
                return (localRoot, .localOnly)
            }
        }.value
    }

    /// Moves decks created before iCloud became available into the container, once.
    static func migrateLocalContentIfNeeded(to root: URL) async {
        let fileManager = FileManager.default
        let source = localRoot.appending(path: clientsDirectoryName, directoryHint: .isDirectory)
        guard let clients = try? fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil),
              !clients.isEmpty else { return }

        let destinationBase = root.appending(path: clientsDirectoryName, directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: destinationBase, withIntermediateDirectories: true)

        for client in clients {
            let destination = destinationBase.appending(path: client.lastPathComponent, directoryHint: .isDirectory)
            guard !fileManager.fileExists(atPath: destination.path(percentEncoded: false)) else { continue }
            try? fileManager.moveItem(at: client, to: destination)
        }
    }

    /// Nudges iCloud to materialise deck files that exist only as placeholders.
    static func requestDownloads(in root: URL) async {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            guard let walker = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey]
            ) else { return }

            // `nextObject()` rather than for-in: NSEnumerator's iterator is
            // unavailable from an async context.
            while let url = walker.nextObject() as? URL {
                guard url.pathExtension == "json" else { continue }
                try? fileManager.startDownloadingUbiquitousItem(at: url)
            }
        }.value
    }

    /// Reads and writes the on-disk tree. Plain atomic writes: deck files are
    /// small, single-writer in practice, and iCloud reconciles whole files.
    struct Coder {
        private let encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return encoder
        }()

        private let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()

        func readAll(root: URL) -> (clients: [Client], decksByClient: [Client.ID: [Deck]]) {
            let fileManager = FileManager.default
            let clientsRoot = root.appending(path: clientsDirectoryName, directoryHint: .isDirectory)
            guard let directories = try? fileManager.contentsOfDirectory(
                at: clientsRoot,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) else {
                return ([], [:])
            }

            var clients: [Client] = []
            var decksByClient: [Client.ID: [Deck]] = [:]

            for directory in directories {
                let clientFile = directory.appending(path: clientFileName, directoryHint: .notDirectory)
                guard let data = try? Data(contentsOf: clientFile),
                      let client = try? decoder.decode(Client.self, from: data) else { continue }
                clients.append(client)

                let decksDirectory = directory.appending(path: decksDirectoryName, directoryHint: .isDirectory)
                let files = (try? fileManager.contentsOfDirectory(at: decksDirectory, includingPropertiesForKeys: nil)) ?? []
                decksByClient[client.id] = files
                    .filter { $0.pathExtension == "json" }
                    .compactMap { url in
                        guard let data = try? Data(contentsOf: url) else { return nil }
                        return try? decoder.decode(Deck.self, from: data)
                    }
            }
            return (clients, decksByClient)
        }

        func write(_ client: Client, root: URL) {
            let directory = clientDirectory(client, root: root)
            try? FileManager.default.createDirectory(
                at: directory.appending(path: decksDirectoryName, directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
            guard let data = try? encoder.encode(client) else { return }
            try? data.write(to: directory.appending(path: clientFileName, directoryHint: .notDirectory), options: .atomic)
        }

        func write(_ deck: Deck, for client: Client, root: URL) {
            let directory = clientDirectory(client, root: root)
                .appending(path: decksDirectoryName, directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard let data = try? encoder.encode(deck) else { return }
            try? data.write(
                to: directory.appending(path: "\(deck.id.uuidString).json", directoryHint: .notDirectory),
                options: .atomic
            )
        }

        func delete(_ deck: Deck, for client: Client, root: URL) {
            let file = clientDirectory(client, root: root)
                .appending(path: decksDirectoryName, directoryHint: .isDirectory)
                .appending(path: "\(deck.id.uuidString).json", directoryHint: .notDirectory)
            try? FileManager.default.removeItem(at: file)
        }

        func deleteClientDirectory(_ client: Client, root: URL) {
            try? FileManager.default.removeItem(at: clientDirectory(client, root: root))
        }

        private func clientDirectory(_ client: Client, root: URL) -> URL {
            root.appending(path: clientsDirectoryName, directoryHint: .isDirectory)
                .appending(path: client.id.uuidString, directoryHint: .isDirectory)
        }
    }
}
