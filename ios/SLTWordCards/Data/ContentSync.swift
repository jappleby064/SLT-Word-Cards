import Foundation

/// Pulls newer card content from the public GitHub repo.
///
/// Deliberately cheap and failure-tolerant: the app is fully usable offline from
/// bundled content, so every network step here is best-effort. `cards.csv` is
/// fetched with an `ETag` so an unchanged repo costs one 304 response.
@Observable
@MainActor
final class ContentSync {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate(Date)
        case updated(cards: Int, images: Int, at: Date)
        case offline
        case failed(String)
    }

    private static let rawBase = URL(string: "https://raw.githubusercontent.com/jappleby064/SLT-Word-Cards/main/")!
    /// Owned by `ContentStore`, which clears it whenever it clears the files the
    /// tag describes.
    private static let etagKey = ContentStore.etagKey
    private static let lastCheckKey = "lastSyncCheck"
    /// Don't re-poll on every foreground; the content changes rarely.
    private static let minimumInterval: TimeInterval = 15 * 60

    private(set) var status: Status = .idle
    private let defaults = UserDefaults.standard
    private var isRunning = false

    var lastChecked: Date? {
        defaults.object(forKey: Self.lastCheckKey) as? Date
    }

    /// Called on open and on foreground. Skips if checked recently.
    func syncIfStale(library: CardLibrary) async {
        if let last = lastChecked, Date().timeIntervalSince(last) < Self.minimumInterval {
            status = .upToDate(last)
            return
        }
        await sync(library: library)
    }

    /// Explicit pull-to-refresh: always checks.
    func sync(library: CardLibrary) async {
        guard !isRunning else { return }
        isRunning = true
        status = .checking
        defer { isRunning = false }

        do {
            let cardsChanged = try await refreshCSV(library: library)
            let imagesAdded = await backfillImages(for: library.cards)
            let now = Date()
            defaults.set(now, forKey: Self.lastCheckKey)
            // The downloaded layer is now this build's own, so it can be trusted
            // over the bundle until the next update replaces it.
            ContentStore.markDownloadsCurrent()

            if cardsChanged || imagesAdded > 0 {
                status = .updated(cards: library.cards.count, images: imagesAdded, at: now)
            } else {
                status = .upToDate(now)
            }
        } catch let error as URLError where Self.isOffline(error) {
            status = .offline
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: CSV

    /// Returns true when a new CSV was written.
    private func refreshCSV(library: CardLibrary) async throws -> Bool {
        var request = URLRequest(url: Self.rawBase.appending(path: ContentStore.csvFileName))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag = defaults.string(forKey: Self.etagKey),
           FileManager.default.fileExists(atPath: ContentStore.downloadedCSV.path(percentEncoded: false)) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }

        switch http.statusCode {
        case 304:
            return false
        case 200:
            // Only accept content that parses into cards — never let a bad
            // response replace working offline data.
            guard let text = String(data: data, encoding: .utf8),
                  !CardLibrary.parse(text).isEmpty else {
                throw SyncError.unusableContent
            }
            try data.write(to: ContentStore.downloadedCSV, options: .atomic)
            if let etag = http.value(forHTTPHeaderField: "Etag") {
                defaults.set(etag, forKey: Self.etagKey)
            }
            library.reload()
            return true
        default:
            throw SyncError.badStatus(http.statusCode)
        }
    }

    // MARK: Images

    /// Downloads images for any word cards we have no picture for — new rows from
    /// an updated CSV, or downloads that failed on an earlier run.
    private func backfillImages(for cards: [Card]) async -> Int {
        let missing = Set(cards.compactMap(\.imageName).filter(ContentStore.isImageMissing))
        guard !missing.isEmpty else { return 0 }

        var downloaded = 0
        // Bounded concurrency: a handful at a time keeps a big first sync polite.
        for batch in Array(missing).chunked(into: 4) {
            downloaded += await withTaskGroup(of: Bool.self) { group in
                for name in batch {
                    group.addTask { await Self.downloadImage(named: name) }
                }
                var succeeded = 0
                for await didDownload in group where didDownload {
                    succeeded += 1
                }
                return succeeded
            }
        }
        return downloaded
    }

    private static func downloadImage(named name: String) async -> Bool {
        let url = rawBase
            .appending(path: ContentStore.imagesDirectoryName)
            .appending(path: "\(name).jpg")
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty else {
                return false
            }
            try data.write(to: ContentStore.downloadedImage(named: name), options: .atomic)
            ImageLoader.shared.invalidate(name)
            return true
        } catch {
            return false   // best-effort; the placeholder covers it
        }
    }

    // MARK: Helpers

    private enum SyncError: LocalizedError {
        case badStatus(Int)
        case unusableContent

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): "Server returned \(code)."
            case .unusableContent: "Downloaded card list was unreadable."
            }
        }
    }

    private static func isOffline(_ error: URLError) -> Bool {
        [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
         .cannotConnectToHost, .dataNotAllowed, .timedOut].contains(error.code)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
