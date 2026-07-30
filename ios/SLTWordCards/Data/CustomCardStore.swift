import UIKit

/// The user's own cards, kept beside their decks in the same private iCloud
/// container so they follow them between their devices — and nowhere else.
///
/// ```
/// <root>/CustomCards/<uuid>.json
/// <root>/CustomCards/Images/<uuid>.jpg
/// ```
@Observable
@MainActor
final class CustomCardStore {
    private(set) var cards: [CustomCard] = []
    private(set) var location: DeckLibrary.Location = .localOnly
    private(set) var isReady = false

    private var root: URL = DeckStorage.localRoot
    private let watcher = ICloudWatcher()

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

    // MARK: Lifecycle

    func bootstrap() async {
        let resolved = await DeckStorage.resolveRoot()
        root = resolved.url
        location = resolved.location
        reload()
        isReady = true

        if resolved.location == .iCloud {
            watcher.start { [weak self] in
                self?.reload()
            }
        }
    }

    func reload() {
        let directory = cardsDirectory
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        cards = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(CustomCard.self, from: data)
            }
            .sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
    }

    /// The searchable form, for merging into the catalogue.
    var searchableCards: [Card] {
        cards.map(\.asCard)
    }

    // MARK: Writing

    /// Saves a card, and its picture if one was chosen. Passing `image: nil` with
    /// `keepExistingImage: true` leaves an existing picture alone, so editing the
    /// wording doesn't drop it.
    func save(_ card: CustomCard, image: UIImage?, keepExistingImage: Bool = false) throws {
        var updated = card
        updated.updatedAt = Date()

        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        if let image {
            let processed = CardImageProcessor.standardise(image)
            guard let data = processed.jpegData(compressionQuality: 0.9) else {
                throw StoreError.imageFailed
            }
            try data.write(to: imageURL(for: card.id), options: .atomic)
            updated.hasImage = true
        } else if !keepExistingImage {
            try? FileManager.default.removeItem(at: imageURL(for: card.id))
            updated.hasImage = false
        }

        let data = try encoder.encode(updated)
        try data.write(to: cardURL(for: updated.id), options: .atomic)

        ImageLoader.shared.invalidateCustom(updated.id)

        if let index = cards.firstIndex(where: { $0.id == updated.id }) {
            cards[index] = updated
        } else {
            cards.append(updated)
        }
        cards.sort { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
    }

    func delete(_ card: CustomCard) {
        try? FileManager.default.removeItem(at: cardURL(for: card.id))
        try? FileManager.default.removeItem(at: imageURL(for: card.id))
        ImageLoader.shared.invalidateCustom(card.id)
        cards.removeAll { $0.id == card.id }
    }

    // MARK: Paths

    private var cardsDirectory: URL {
        let url = root.appending(path: "CustomCards", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var imagesDirectory: URL {
        cardsDirectory.appending(path: "Images", directoryHint: .isDirectory)
    }

    private func cardURL(for id: UUID) -> URL {
        cardsDirectory.appending(path: "\(id.uuidString).json", directoryHint: .notDirectory)
    }

    private func imageURL(for id: UUID) -> URL {
        imagesDirectory.appending(path: "\(id.uuidString).jpg", directoryHint: .notDirectory)
    }

    /// Where `ImageLoader` should look for a custom card's picture.
    nonisolated static func imageLocation(for id: UUID, root: URL) -> URL {
        root.appending(path: "CustomCards", directoryHint: .isDirectory)
            .appending(path: "Images", directoryHint: .isDirectory)
            .appending(path: "\(id.uuidString).jpg", directoryHint: .notDirectory)
    }

    enum StoreError: LocalizedError {
        case imageFailed

        var errorDescription: String? {
            switch self {
            case .imageFailed: "That picture couldn't be saved. Try a different one."
            }
        }
    }
}

/// Brings a chosen picture into the same shape as the shared card images:
/// 500×500, padded with white rather than cropped or stretched, so nothing in the
/// picture is lost and printed cards stay consistent.
enum CardImageProcessor {
    static let side: CGFloat = 500

    static func standardise(_ image: UIImage) -> UIImage {
        let canvas = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))

            // Aspect fit, centred — never crop, never warp.
            let scale = min(side / image.size.width, side / image.size.height)
            let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (side - fitted.width) / 2, y: (side - fitted.height) / 2)
            image.draw(in: CGRect(origin: origin, size: fitted))
        }
    }
}
