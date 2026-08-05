import Foundation

/// A named set of cards belonging to a learner. Stored as one JSON file so that
/// iCloud syncs decks independently and conflicts stay contained.
struct Deck: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    /// Ordered card ids — order is the presentation order.
    var cardIDs: [Card.ID]
    /// How many times the whole selection repeats in a print run, matching the
    /// web app's "instances of each card" field.
    var printCopies: Int
    var createdAt: Date
    var updatedAt: Date
    /// Set when the deck arrived as a pack from someone else. Optional so decks
    /// saved before packs existed still decode.
    var importedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        cardIDs: [Card.ID] = [],
        printCopies: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        importedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.cardIDs = cardIDs
        self.printCopies = printCopies
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.importedAt = importedAt
    }

    var cardCount: Int { cardIDs.count }

    var isImported: Bool { importedAt != nil }

    /// Adds cards that aren't already present, preserving existing order.
    mutating func add(_ ids: [Card.ID]) {
        let existing = Set(cardIDs)
        cardIDs.append(contentsOf: ids.filter { !existing.contains($0) })
        updatedAt = Date()
    }

    mutating func remove(_ id: Card.ID) {
        cardIDs.removeAll { $0 == id }
        updatedAt = Date()
    }
}

/// The learner a set of decks belongs to — the first of the two storage tiers.
struct Learner: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
