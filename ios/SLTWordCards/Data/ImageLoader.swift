import UIKit

/// Decoded-image cache shared by the presenter and the PDF renderer.
/// `NSCache` is thread-safe, so this is safe to touch from any isolation domain.
final class ImageLoader: @unchecked Sendable {
    static let shared = ImageLoader()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 120
    }

    /// The image for a word, falling back to the shared placeholder.
    func image(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }

        guard let url = ContentStore.imageURL(named: name) ?? ContentStore.fallbackImageURL,
              let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) else {
            return nil
        }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    /// Called after a download replaces a file on disk.
    func invalidate(_ name: String) {
        cache.removeObject(forKey: name as NSString)
    }
}
