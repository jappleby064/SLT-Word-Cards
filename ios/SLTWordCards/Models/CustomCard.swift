import Foundation

/// A card the user made themselves.
///
/// These live only in the user's own private iCloud container — they are never
/// uploaded anywhere and never travel in a shared pack, because the person on the
/// other end has no copy of the picture. See `DeckPack` for how they're excluded.
struct CustomCard: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var word: String
    var initialSound: String
    var finalSound: String
    var structure: String
    /// Whether a picture was saved alongside this card. Optional by design — a
    /// card is useful without one, and shows a placeholder instead.
    var hasImage: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        word: String,
        initialSound: String,
        finalSound: String,
        structure: String,
        hasImage: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.word = word.trimmed
        self.initialSound = initialSound.trimmed.lowercased()
        self.finalSound = finalSound.trimmed.lowercased()
        self.structure = structure.trimmed.lowercased()
        self.hasImage = hasImage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// The searchable card this becomes. The id namespace is separate from the
    /// shared catalogue's so the two can never collide.
    var asCard: Card {
        Card(
            word: word,
            initialSound: initialSound,
            finalSound: finalSound,
            structure: structure,
            kind: .word,
            numeral: "",
            variant: "",
            origin: .custom,
            customID: id
        )
    }

    /// Everything except the picture is required, so a card is always searchable
    /// on the criteria that matter.
    var isComplete: Bool {
        !word.isEmpty && !initialSound.isEmpty && !finalSound.isEmpty && !structure.isEmpty
    }
}
