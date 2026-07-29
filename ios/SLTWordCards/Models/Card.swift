import Foundation

/// One printable/presentable card, mirroring a row of `cards.csv`.
struct Card: Identifiable, Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case word
        case number
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

    /// Stable across CSV edits, so a saved deck survives content updates.
    var id: String { "\(word)|\(kind.rawValue)|\(variant)" }

    /// Disambiguates the two number variants in result lists.
    var label: String {
        kind == .number ? "\(word) (\(variant))" : word
    }

    /// Number cards have no image — they render this text where the picture goes.
    var faceText: String? {
        guard kind == .number else { return nil }
        return variant == "symbol" ? numeral : word.capitalizedFirst
    }

    /// Base name of the image file in `images/`, for word cards only.
    var imageName: String? {
        kind == .number ? nil : word
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
