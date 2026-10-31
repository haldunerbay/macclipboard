import AppKit
import ClipCore

/// Adds every screenshot saved to a file, wherever macOS saves it, through a live Spotlight
/// query for `kMDItemIsScreenCapture`. Screenshots taken while the app was not running are
/// picked up at the next launch.
@MainActor
final class ScreenshotWatcher: NSObject {
    private let store: HistoryStore
    private let query = NSMetadataQuery()
    private let defaults = UserDefaults.standard
    private static let lastRunKey = "screenshotsCheckedUntil"
    /// Screenshots older than this were already seen (or predate the app) and are not added again.
    private let cutoff: Date

    init(store: HistoryStore) {
        self.store = store
        // On the first launch, bring in the screenshots of the last week.
        cutoff = defaults.object(forKey: Self.lastRunKey) as? Date ?? Date().addingTimeInterval(-7 * 24 * 3600)
        super.init()
    }

    func start() {
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(didFinishGathering), name: .NSMetadataQueryDidFinishGathering, object: query)
        center.addObserver(self, selector: #selector(didUpdate(_:)), name: .NSMetadataQueryDidUpdate, object: query)
        query.start()
    }

    func recordRun() {
        defaults.set(Date(), forKey: Self.lastRunKey)
    }

    @objc private func didFinishGathering() {
        query.disableUpdates()
        add(query.results.compactMap { $0 as? NSMetadataItem })
        query.enableUpdates()
        recordRun()
    }

    @objc private func didUpdate(_ notification: Notification) {
        let info = notification.userInfo ?? [:]
        let added = info[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
        let changed = info[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] ?? []
        let removed = info[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] ?? []
        add(added + changed)
        // A deleted or moved screenshot leaves the history (a moved one comes back under its new path).
        let gone = Set(removed.compactMap(path(of:)).filter { !FileManager.default.fileExists(atPath: $0) })
        if !gone.isEmpty {
            store.removeAll { $0.category == .screenshot && gone.contains($0.filePaths?.first ?? "") }
        }
        recordRun()
    }

    private func add(_ results: [NSMetadataItem]) {
        for result in results {
            guard let path = path(of: result),
                  let date = result.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date,
                  date > cutoff,
                  FileManager.default.fileExists(atPath: path)
            else { continue }
            let hash = ClipClassifier.contentHash(filePaths: [path])
            guard !store.contains(hash: hash) else { continue }
            store.add(ClipItem(
                category: .screenshot,
                date: date,
                filePaths: [path],
                pixelWidth: (result.value(forAttribute: "kMDItemPixelWidth") as? NSNumber)?.intValue,
                pixelHeight: (result.value(forAttribute: "kMDItemPixelHeight") as? NSNumber)?.intValue,
                sourceApp: "Screenshot",
                contentHash: hash
            ))
        }
    }

    private func path(of result: NSMetadataItem) -> String? {
        result.value(forAttribute: NSMetadataItemPathKey) as? String
    }
}
