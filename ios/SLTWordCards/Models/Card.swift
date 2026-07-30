import Foundation

/// One printable/presentable card, mirroring a row of `cards.csv`.
struct Card: Identifiable, Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case word
        case number
    }

    /// Where a card came from. The shared catalogue is the same everywhere; a
    /// custom card exists only on its owner's devices.
    enum Origin: String, Codable, Sendable {
        case catalogue
        case custom
    }

    let word: String
    let initialSound: String
    let finalSound: String
    let structure: String
    let kind: Kind
    /// Digit form for number cards ("7"); empty for word cards.
    let numeral: String
    /// Number cards come in two variants: "symbol" ("7") and "word" ("Seven").
    let variant: String
    var origin: Origin = .catalogue
    /// Set for custom cards, and what their picture is filed under.
    var customID: UUID?

    /// Stable across CSV edits, so a saved deck survives content updates. Custom
    /// cards use a separate namespace so they can never collide with the
    /// catalogue, and so a pack can tell the two apart.
    var id: String {
        if let customID {
            return "custom|\(customID.uuidString)"
        }
        return "\(word)|\(kind.rawValue)|\(variant)"
    }

    var isCustom: Bool { origin == .custom }

    /// Disambiguates the two number variants in result lists.
    var label: String {
        kind == .number ? "\(word) (\(variant))" : word
    }

    /// Number cards have no image — they render this text where the picture goes.
    var faceText: String? {
        guard kind == .number else { return nil }
        return variant == "symbol" ? numeral : word.capitalizedFirst
    }

    /// Base name of the image file in `images/`, for catalogue word cards only.
    /// Nil for number cards, which draw text, and for custom cards, whose picture
    /// is the user's own and must never be looked for in the shared image set.
    var imageName: String? {
        guard origin == .catalogue, kind != .number else { return nil }
        return word
    }

    /// Free-text match: words match as a substring, numerals match exactly so
    /// "1" does not also catch "10".
    func matches(query: String) -> Bool {
        if word.lowercased().contains(query) { return true }
        if !numeral.isEmpty, numeral.lowercased() == query { return true }
        return false
    }
}

extension Card {
    /// Builds a card from a parsed CSV row, applying the same normalisation as
    /// the web app (`app.js`).
    init?(row: [String: String]) {
        let word = row["Word"]?.trimmed ?? ""
        guard !word.isEmpty else { return nil }

        let rawType = (row["Type"]?.trimmed.lowercased()).flatMap { $0.isEmpty ? nil : $0 } ?? "word"

        self.word = word
        self.initialSound = row["Word Initial"]?.trimmed.lowercased() ?? ""
        self.finalSound = row["Word Final"]?.trimmed.lowercased() ?? ""
        self.structure = row["Structure"]?.trimmed.lowercased() ?? ""
        self.kind = Kind(rawValue: rawType) ?? .word
        self.numeral = row["Numeral"]?.trimmed ?? ""
        self.variant = row["Variant"]?.trimmed.lowercased() ?? ""
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
