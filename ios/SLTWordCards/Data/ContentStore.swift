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

    private static var downloadedImagesDirectory: URL {
        contentDirectory.appending(path: imagesDirectoryName, directoryHint: .isDirectory)
    }

    // MARK: Freshness

    /// Shared with `ContentSync`, which sends it as `If-None-Match`. Kept here so
    /// that clearing the downloaded layer can clear the tag with it — otherwise
    /// the next check answers 304 and nothing is ever fetched again.
    static let etagKey = "cardsCSVETag"
    private static let stampKey = "downloadedContentBuild"

    private static var currentBuild: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    /// Recorded by `ContentSync` once a check completes, so the downloaded layer
    /// is trusted only while it belongs to the build that is running.
    static func markDownloadsCurrent() {
        UserDefaults.standard.set(currentBuild, forKey: stampKey)
    }

    /// Throws away anything downloaded by an earlier build, once per launch.
    ///
    /// The downloaded layer used to win over the bundle unconditionally and for
    /// good. An update ships newer cards and pictures inside the app, so a file
    /// fetched by an older build would shadow them permanently — and because
    /// `backfillImages` only fetches pictures that are *missing*, a picture
    /// already on disk was never replaced either. A picture withdrawn for
    /// licensing reasons would have survived the update meant to remove it.
    ///
    /// Clearing it puts the app back on the content it shipped with; the next
    /// sync pulls forward anything genuinely newer.
    private static let discardDownloadsFromAnOlderBuild: Void = {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: stampKey) != currentBuild else { return }

        let manager = FileManager.default
        try? manager.removeItem(at: downloadedCSV)
        try? manager.removeItem(at: downloadedImagesDirectory)
        try? manager.createDirectory(at: downloadedImagesDirectory, withIntermediateDirectories: true)
        defaults.removeObject(forKey: etagKey)
    }()

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

    /// The freshest CSV available: downloaded if this build put it there, else
    /// bundled.
    static var effectiveCSV: URL? {
        _ = discardDownloadsFromAnOlderBuild
        let downloaded = downloadedCSV
        if FileManager.default.fileExists(atPath: downloaded.path(percentEncoded: false)) {
            return downloaded
        }
        return bundledCSV
    }

    /// Image for a word, or the shared "no image" placeholder if we have neither.
    static func imageURL(named name: String) -> URL? {
        _ = discardDownloadsFromAnOlderBuild
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
