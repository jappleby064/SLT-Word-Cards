import UIKit

/// Decoded-image cache shared by the presenter and the PDF renderer.
/// `NSCache` is thread-safe, so this is safe to touch from any isolation domain.
final class ImageLoader: @unchecked Sendable {
    static let shared = ImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    /// Where custom-card pictures live. Set once storage resolves, because it
    /// depends on whether iCloud is available.
    private let rootLock = NSLock()
    private var customRoot: URL = DeckStorage.localRoot

    private init() {
        cache.countLimit = 120
    }

    func setCustomCardRoot(_ url: URL) {
        rootLock.lock()
        customRoot = url
        rootLock.unlock()
        cache.removeAllObjects()
    }

    /// The picture for any card, wherever it came from. Catalogue cards fall back
    /// to the shared placeholder; a custom card without a picture returns nil so
    /// the view can show its own placeholder.
    func image(for card: Card) -> UIImage? {
        if let customID = card.customID {
            return customImage(customID)
        }
        guard let name = card.imageName else { return nil }
        return image(named: name)
    }

    /// The picture for a catalogue word, falling back to the shared placeholder.
    func image(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }

        guard let url = ContentStore.imageURL(named: name) ?? ContentStore.fallbackImageURL,
              let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) else {
            return nil
        }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    private func customImage(_ id: UUID) -> UIImage? {
        let key = "custom-\(id.uuidString)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        rootLock.lock()
        let root = customRoot
        rootLock.unlock()

        let url = CustomCardStore.imageLocation(for: id, root: root)
        guard let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Called after a download replaces a file on disk.
    func invalidate(_ name: String) {
        cache.removeObject(forKey: name as NSString)
    }

    func invalidateCustom(_ id: UUID) {
        cache.removeObject(forKey: "custom-\(id.uuidString)" as NSString)
    }
}
