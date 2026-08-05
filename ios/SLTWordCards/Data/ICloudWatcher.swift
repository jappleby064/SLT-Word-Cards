import Foundation

/// Watches the iCloud container for deck and learner files changing underneath us,
/// so edits made on another device appear while the app is open rather than only
/// after it is backgrounded and reopened.
///
/// `NSMetadataQuery` is the only way to hear about ubiquitous items arriving —
/// the ordinary file-system APIs cannot see a change that hasn't downloaded yet.
@MainActor
final class ICloudWatcher {
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var coalesceTask: Task<Void, Never>?
    private var onChange: (@Sendable @MainActor () -> Void)?

    /// Starts watching. `onChange` is coalesced, because a single sync can emit
    /// a burst of per-file updates.
    func start(onChange: @escaping @Sendable @MainActor () -> Void) {
        guard query == nil else { return }
        self.onChange = onChange

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.json")
        // Keep the update stream calm; we only need "something changed".
        query.notificationBatchingInterval = 1.0

        let center = NotificationCenter.default
        for name in [NSNotification.Name.NSMetadataQueryDidFinishGathering,
                     NSNotification.Name.NSMetadataQueryDidUpdate] {
            let token = center.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleChange()
                }
            }
            observers.append(token)
        }

        self.query = query
        query.start()
    }

    func stop() {
        coalesceTask?.cancel()
        coalesceTask = nil
        query?.stop()
        query = nil
        onChange = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func scheduleChange() {
        coalesceTask?.cancel()
        coalesceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            self.coalesceTask = nil
            self.onChange?()
        }
    }
}
