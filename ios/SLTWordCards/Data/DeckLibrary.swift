import Foundation

/// Saved decks, organised in two tiers: **Learner → Deck**.
///
/// On disk each deck is its own JSON file:
/// ```
/// <root>/Clients/<learnerID>/client.json
/// <root>/Learners/<learnerID>/Decks/<deckID>.json
/// ```
/// The two `client` names on disk predate the rename to "learner" and are kept
/// verbatim so an existing library keeps loading; only the vocabulary changed.
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

    private(set) var learners: [Learner] = []
    /// Decks keyed by learner id.
    private(set) var decksByLearner: [Learner.ID: [Deck]] = [:]
    private(set) var location: Location = .localOnly
    private(set) var isReady = false

    private var root: URL = DeckStorage.localRoot
    private let coder = DeckStorage.Coder()
    private let watcher = ICloudWatcher()

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

        if resolved.location == .iCloud {
            // Learners and decks both live in this container, so one watcher
            // keeps the whole two-tier library live.
            watcher.start { [weak self] in
                guard let self else { return }
                Task { await DeckStorage.requestDownloads(in: self.root) }
                self.reload()
            }
        }
    }

    /// Re-reads from disk. Called on foreground so edits made on another device
    /// show up.
    func reload() {
        let snapshot = coder.readAll(root: root)
        learners = snapshot.learners.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        decksByLearner = snapshot.decksByLearner.mapValues { decks in
            decks.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    // MARK: Reading

    func decks(for learner: Learner) -> [Deck] {
        decksByLearner[learner.id] ?? []
    }

    func deck(id: Deck.ID, in learner: Learner) -> Deck? {
        decks(for: learner).first { $0.id == id }
    }

    var totalDeckCount: Int {
        decksByLearner.values.reduce(0) { $0 + $1.count }
    }

    // MARK: Learners

    /// Reserved collection holding the decks a person makes for themselves in
    /// Learner mode. Storing it as an ordinary learner keeps one storage and sync
    /// path for both modes; the teacher-facing lists filter it out.
    static let personalLearnerID = UUID(uuidString: "5C1DECC0-0000-4000-8000-000000000001")!

    /// Learners a teacher manages — everything except the personal collection.
    var teacherLearners: [Learner] {
        learners.filter { $0.id != Self.personalLearnerID }
    }

    /// The personal collection, created on first use.
    @discardableResult
    func personalCollection() -> Learner {
        if let existing = learners.first(where: { $0.id == Self.personalLearnerID }) {
            return existing
        }
        return addLearner(named: "My Decks", id: Self.personalLearnerID)
    }

    @discardableResult
    func addLearner(named name: String, id: UUID = UUID()) -> Learner {
        let learner = Learner(id: id, name: name.trimmed)
        coder.write(learner, root: root)
        learners.append(learner)
        learners.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        decksByLearner[learner.id] = []
        return learner
    }

    func rename(_ learner: Learner, to name: String) {
        guard let index = learners.firstIndex(where: { $0.id == learner.id }) else { return }
        learners[index].name = name.trimmed
        coder.write(learners[index], root: root)
        learners.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func delete(_ learner: Learner) {
        coder.deleteLearnerDirectory(learner, root: root)
        learners.removeAll { $0.id == learner.id }
        decksByLearner[learner.id] = nil
    }

    // MARK: Decks

    @discardableResult
    func createDeck(named name: String, for learner: Learner, cardIDs: [Card.ID], printCopies: Int = 1) -> Deck {
        let deck = Deck(name: name.trimmed, cardIDs: cardIDs, printCopies: max(1, printCopies))
        coder.write(deck, for: learner, root: root)
        decksByLearner[learner.id, default: []].insert(deck, at: 0)
        return deck
    }

    /// Persists an edited deck and refreshes it in memory.
    func save(_ deck: Deck, for learner: Learner) {
        var updated = deck
        updated.updatedAt = Date()
        coder.write(updated, for: learner, root: root)

        var decks = decksByLearner[learner.id] ?? []
        if let index = decks.firstIndex(where: { $0.id == updated.id }) {
            decks[index] = updated
        } else {
            decks.append(updated)
        }
        decksByLearner[learner.id] = decks.sorted { $0.updatedAt > $1.updatedAt }
    }

    func delete(_ deck: Deck, from learner: Learner) {
        coder.delete(deck, for: learner, root: root)
        decksByLearner[learner.id]?.removeAll { $0.id == deck.id }
    }

    // MARK: Packs

    /// Saves a received pack as a new deck. Never overwrites an existing deck —
    /// importing the same pack twice gives you "Name 2" rather than replacing
    /// work in progress.
    @discardableResult
    func importPack(_ pack: DeckPack, for learner: Learner) -> Deck {
        let deck = Deck(
            name: uniqueName(from: pack.name, for: learner),
            cardIDs: pack.cardIDs,
            printCopies: max(1, pack.printCopies),
            importedAt: Date()
        )
        coder.write(deck, for: learner, root: root)
        decksByLearner[learner.id, default: []].insert(deck, at: 0)
        return deck
    }

    private func uniqueName(from name: String, for learner: Learner) -> String {
        let base = name.trimmed.isEmpty ? "Imported Deck" : name.trimmed
        let existing = Set(decks(for: learner).map(\.name))
        guard existing.contains(base) else { return base }

        var suffix = 2
        while existing.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    /// Adds cards to an existing deck, skipping ones already in it.
    /// Returns how many were actually added.
    @discardableResult
    func add(cardIDs: [Card.ID], to deck: Deck, for learner: Learner) -> Int {
        var updated = deck
        let before = updated.cardIDs.count
        updated.add(cardIDs)
        save(updated, for: learner)
        return updated.cardIDs.count - before
    }
}

// MARK: - Storage

enum DeckStorage {
    // These two are the names written to disk before "client" became "learner"
    // in the interface. Renaming them would strand an existing library, and the
    // path is never shown to anyone, so they stay as they are.
    private static let learnersDirectoryName = "Clients"
    private static let decksDirectoryName = "Decks"
    private static let learnerFileName = "client.json"

    /// The root last resolved by `resolveRoot`, so other stores and the image
    /// loader can find the same container without resolving it again.
    private(set) nonisolated(unsafe) static var currentRoot: URL = localRoot

    static let localRoot: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appending(path: "DeckLibrary", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Ubiquity container if the user has iCloud Drive available, else local.
    /// Runs off the main actor because `url(forUbiquityContainerIdentifier:)` can block.
    static func resolveRoot() async -> (url: URL, location: DeckLibrary.Location) {
        let resolved = await Task.detached(priority: .userInitiated) { () -> (URL, DeckLibrary.Location) in
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

        currentRoot = resolved.0
        return resolved
    }

    /// Moves decks created before iCloud became available into the container, once.
    static func migrateLocalContentIfNeeded(to root: URL) async {
        let fileManager = FileManager.default
        let source = localRoot.appending(path: learnersDirectoryName, directoryHint: .isDirectory)
        guard let learners = try? fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil),
              !learners.isEmpty else { return }

        let destinationBase = root.appending(path: learnersDirectoryName, directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: destinationBase, withIntermediateDirectories: true)

        for learner in learners {
            let destination = destinationBase.appending(path: learner.lastPathComponent, directoryHint: .isDirectory)
            guard !fileManager.fileExists(atPath: destination.path(percentEncoded: false)) else { continue }
            try? fileManager.moveItem(at: learner, to: destination)
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

        func readAll(root: URL) -> (learners: [Learner], decksByLearner: [Learner.ID: [Deck]]) {
            let fileManager = FileManager.default
            let learnersRoot = root.appending(path: learnersDirectoryName, directoryHint: .isDirectory)
            guard let directories = try? fileManager.contentsOfDirectory(
                at: learnersRoot,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) else {
                return ([], [:])
            }

            var learners: [Learner] = []
            var decksByLearner: [Learner.ID: [Deck]] = [:]

            for directory in directories {
                let learnerFile = directory.appending(path: learnerFileName, directoryHint: .notDirectory)
                guard let data = try? Data(contentsOf: learnerFile),
                      let learner = try? decoder.decode(Learner.self, from: data) else { continue }
                learners.append(learner)

                let decksDirectory = directory.appending(path: decksDirectoryName, directoryHint: .isDirectory)
                let files = (try? fileManager.contentsOfDirectory(at: decksDirectory, includingPropertiesForKeys: nil)) ?? []
                decksByLearner[learner.id] = files
                    .filter { $0.pathExtension == "json" }
                    .compactMap { url in
                        guard let data = try? Data(contentsOf: url) else { return nil }
                        return try? decoder.decode(Deck.self, from: data)
                    }
            }
            return (learners, decksByLearner)
        }

        func write(_ learner: Learner, root: URL) {
            let directory = learnerDirectory(learner, root: root)
            try? FileManager.default.createDirectory(
                at: directory.appending(path: decksDirectoryName, directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
            guard let data = try? encoder.encode(learner) else { return }
            try? data.write(to: directory.appending(path: learnerFileName, directoryHint: .notDirectory), options: .atomic)
        }

        func write(_ deck: Deck, for learner: Learner, root: URL) {
            let directory = learnerDirectory(learner, root: root)
                .appending(path: decksDirectoryName, directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard let data = try? encoder.encode(deck) else { return }
            try? data.write(
                to: directory.appending(path: "\(deck.id.uuidString).json", directoryHint: .notDirectory),
                options: .atomic
            )
        }

        func delete(_ deck: Deck, for learner: Learner, root: URL) {
            let file = learnerDirectory(learner, root: root)
                .appending(path: decksDirectoryName, directoryHint: .isDirectory)
                .appending(path: "\(deck.id.uuidString).json", directoryHint: .notDirectory)
            try? FileManager.default.removeItem(at: file)
        }

        func deleteLearnerDirectory(_ learner: Learner, root: URL) {
            try? FileManager.default.removeItem(at: learnerDirectory(learner, root: root))
        }

        private func learnerDirectory(_ learner: Learner, root: URL) -> URL {
            root.appending(path: learnersDirectoryName, directoryHint: .isDirectory)
                .appending(path: learner.id.uuidString, directoryHint: .isDirectory)
        }
    }
}
