import Foundation

/// The searchable card catalogue, loaded from whichever `cards.csv` is freshest.
@Observable
@MainActor
final class CardLibrary {
    /// Everything searchable: the shared catalogue plus the user's own cards.
    private(set) var cards: [Card] = []
    private(set) var loadError: String?

    private var catalogue: [Card] = []
    private var custom: [Card] = []
    private var index: [Card.ID: Card] = [:]

    init() {
        reload()
    }

    func reload() {
        guard let text = ContentStore.loadCSVText() else {
            loadError = "Could not read cards.csv."
            return
        }
        let parsed = Self.parse(text)
        guard !parsed.isEmpty else {
            loadError = "cards.csv contained no cards."
            return
        }
        catalogue = parsed
        loadError = nil
        rebuild()
    }

    /// Merges in the user's own cards. Called whenever they change, including
    /// when iCloud brings across an edit from another device.
    func setCustomCards(_ cards: [Card]) {
        custom = cards
        rebuild()
    }

    private func rebuild() {
        // Custom cards sort after the catalogue; their ids are in a separate
        // namespace, so a card of your own named "cat" is a second card rather
        // than a replacement for the catalogue's.
        //
        // Deduplicated anyway. iCloud resolves a sync clash by leaving a second
        // file beside the first — "card 2.json", carrying the same id — and two
        // cards sharing an id would otherwise appear twice in every list, and
        // trap in `Dictionary(uniqueKeysWithValues:)`: a crash on launch that
        // repeats until the file is deleted by hand. The last one wins, matching
        // how the rest of the store treats a rewritten card.
        var seen = Set<Card.ID>()
        cards = (catalogue + custom).filter { seen.insert($0.id).inserted }
        index = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    /// Parses CSV text into cards, dropping exact duplicates — `cards.csv` lists
    /// "peg" twice, and a stable unique id is what lets decks survive updates.
    static func parse(_ text: String) -> [Card] {
        var seen = Set<Card.ID>()
        return CSV.parse(text)
            .filter(isLive)
            .compactMap(Card.init(row:))
            .filter { seen.insert($0.id).inserted }
    }

    /// A row is live unless `Status` says otherwise. New words are added as
    /// "review" so they can be checked before anyone sees them. A blank or
    /// missing Status means live, so a `cards.csv` written before the column
    /// existed still loads in full.
    private static func isLive(_ row: [String: String]) -> Bool {
        let status = row["Status"]?.trimmed.lowercased() ?? ""
        return status.isEmpty || status == "live"
    }

    /// Distinct structures present in the data, for the filter menu.
    var structures: [String] {
        Array(Set(cards.map(\.structure))).filter { !$0.isEmpty }.sorted {
            ($0.count, $0) < ($1.count, $1)
        }
    }

    func card(id: Card.ID) -> Card? { index[id] }

    /// Resolves saved deck contents, silently dropping ids no longer in the CSV.
    func cards(ids: [Card.ID]) -> [Card] {
        ids.compactMap { index[$0] }
    }

    /// Same rules as `onSearch` in app.js: exact match on the phonetic fields,
    /// substring on the word, and the type filter applied first.
    func search(_ criteria: SearchCriteria) -> [Card] {
        cards.filter { card in
            if let kind = criteria.kind, card.kind != kind { return false }
            if !criteria.initialSound.isEmpty, card.initialSound != criteria.initialSound { return false }
            if !criteria.finalSound.isEmpty, card.finalSound != criteria.finalSound { return false }
            if !criteria.structure.isEmpty, card.structure != criteria.structure { return false }
            if !criteria.query.isEmpty, !card.matches(query: criteria.query) { return false }
            return true
        }
    }
}

/// The four filters from the web app, normalised for comparison.
struct SearchCriteria: Equatable {
    var rawQuery = ""
    var initialSound = ""
    var finalSound = ""
    var structure = ""
    /// `nil` means "All types".
    var kind: Card.Kind?

    var query: String { rawQuery.trimmed.lowercased() }

    var isEmpty: Bool {
        query.isEmpty && initialSound.isEmpty && finalSound.isEmpty
            && structure.isEmpty && kind == nil
    }

    mutating func clear() {
        self = SearchCriteria()
    }
}
