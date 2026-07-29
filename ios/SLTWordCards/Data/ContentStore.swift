import Foundation

/// Where card content lives on disk.
///
/// Two layers, checked newest-first:
///  1. **Downloaded** — Application Support/Content, written by `ContentSync`.
///  2. **Bundled** — shipped inside the app, so a fresh install works offline.
enum ContentStore {
    static let csvFileName = "cards.csv"
    static let imagesDirectoryName = "images"
    static let fallbackImageName = "no_image"

    // MARK: Downloaded content

    static let contentDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appending(path: "Content", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(
            at: directory.appending(path: imagesDirectoryName, directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        return directory
    }()

    static var downloadedCSV: URL {
        contentDirectory.appending(path: csvFileName, directoryHint: .notDirectory)
    }

    static func downloadedImage(named name: String) -> URL {
        contentDirectory
            .appending(path: imagesDirectoryName, directoryHint: .isDirectory)
            .appending(path: "\(name).jpg", directoryHint: .notDirectory)
    }

    // MARK: Bundled baseline

    static var bundledCSV: URL? {
        Bundle.main.url(forResource: "cards", withExtension: "csv")
    }

    static func bundledImage(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: imagesDirectoryName)
    }

    // MARK: Resolution

    /// The freshest CSV available: downloaded if we have one, else bundled.
    static var effectiveCSV: URL? {
        let downloaded = downloadedCSV
        if FileManager.default.fileExists(atPath: downloaded.path(percentEncoded: false)) {
            return downloaded
        }
        return bundledCSV
    }

    /// Image for a word, or the shared "no image" placeholder if we have neither.
    static func imageURL(named name: String) -> URL? {
        let downloaded = downloadedImage(named: name)
        if FileManager.default.fileExists(atPath: downloaded.path(percentEncoded: false)) {
            return downloaded
        }
        return bundledImage(named: name)
    }

    static var fallbackImageURL: URL? {
        imageURL(named: fallbackImageName)
    }

    /// True when neither layer has an image for this word — used to decide what
    /// `ContentSync` should backfill.
    static func isImageMissing(named name: String) -> Bool {
        imageURL(named: name) == nil
    }

    static func loadCSVText() -> String? {
        guard let url = effectiveCSV else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
