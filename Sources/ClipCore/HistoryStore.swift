import Combine
import Foundation
import UniformTypeIdentifiers

/// How much history is kept. The oldest items go when a new one arrives over the limit.
public enum HistoryLimit: Equatable, Sendable {
    case count(Int)
    /// Size of the copied content: texts, file paths and stored images (screenshot files stay
    /// where macOS saved them and do not count). 1 MB is 1 000 000 bytes, as in Finder.
    case size(megabytes: Double)
    case unlimited
}

/// The clipboard history, newest first, saved as JSON with copied images next to it.
@MainActor
public final class HistoryStore: ObservableObject {
    @Published public private(set) var items: [ClipItem] = []

    public let directory: URL
    /// Changing it removes nothing until the next item arrives.
    public var limit: HistoryLimit
    /// Items last copied longer ago than this expire (nil keeps them). They are removed by
    /// `removeExpired()` and when a new item arrives.
    public var maxAge: TimeInterval?
    public var imagesDirectory: URL { directory.appendingPathComponent("Images", isDirectory: true) }
    private var historyFile: URL { directory.appendingPathComponent("history.json") }
    private var pendingSave: DispatchWorkItem?
    /// Sizes of stored images by file name, so totals do not read the disk every time.
    private var imageSizes: [String: Int] = [:]

    public static var defaultDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("ClipHistory", isDirectory: true)
    }

    public init(directory: URL, limit: HistoryLimit = .count(500)) {
        self.directory = directory
        self.limit = limit
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        load()
    }

    public func contains(hash: String) -> Bool {
        items.contains { $0.contentHash == hash }
    }

    /// Adds an item, or moves the entry with the same content to its date. `imageData` is the
    /// PNG of a copied image; it is written only for a new entry.
    @discardableResult
    public func add(_ item: ClipItem, imageData: Data? = nil) -> ClipItem? {
        // Such as a screenshot found at launch that was taken before the expiry period.
        if let cutoff = expiryCutoff(), item.date < cutoff, !contains(hash: item.contentHash) { return nil }
        var entry: ClipItem
        if let index = items.firstIndex(where: { $0.contentHash == item.contentHash }) {
            entry = items.remove(at: index)
            entry.date = max(entry.date, item.date)
            entry.sourceApp = item.sourceApp ?? entry.sourceApp
            if item.category == .screenshot { entry.category = .screenshot }
        } else {
            entry = item
            if let imageData {
                let name = "\(item.id.uuidString).png"
                do {
                    try imageData.write(to: imagesDirectory.appendingPathComponent(name), options: .atomic)
                } catch {
                    return nil
                }
                entry.imageName = name
                imageSizes[name] = imageData.count
            }
        }
        insert(entry)
        trimToLimit()
        removeExpired()
        scheduleSave()
        return entry
    }

    /// Removes the items whose last copy is older than `maxAge`. Returns how many went.
    @discardableResult
    public func removeExpired(now: Date = Date()) -> Int {
        guard let cutoff = expiryCutoff(now: now) else { return 0 }
        let before = items.count
        removeAll { $0.date < cutoff }
        return before - items.count
    }

    /// How many items have expired and wait for the next `removeExpired()`.
    public func expiredCount(now: Date = Date()) -> Int {
        guard let cutoff = expiryCutoff(now: now) else { return 0 }
        return items.count { $0.date < cutoff }
    }

    private func expiryCutoff(now: Date = Date()) -> Date? {
        maxAge.map { now.addingTimeInterval(-$0) }
    }

    /// Moves an entry to the top, as if it had just been copied.
    public func touch(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var entry = items.remove(at: index)
        entry.date = Date()
        insert(entry)
        scheduleSave()
    }

    public func remove(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        deleteFiles(of: items.remove(at: index))
        scheduleSave()
    }

    public func removeAll(where shouldRemove: (ClipItem) -> Bool) {
        let removed = items.filter(shouldRemove)
        guard !removed.isEmpty else { return }
        items.removeAll(where: shouldRemove)
        removed.forEach(deleteFiles)
        scheduleSave()
    }

    public func removeAll() {
        removeAll { _ in true }
    }

    /// The image to show for an item: a copied image, a screenshot or a single copied image file.
    public func imageURL(for item: ClipItem) -> URL? {
        switch item.category {
        case .image, .screenshot:
            // A screenshot saved to a file points at it; one taken to the clipboard has a stored image.
            if let path = item.filePaths?.first { return URL(fileURLWithPath: path) }
            return item.imageName.map { imagesDirectory.appendingPathComponent($0) }
        case .file:
            guard let paths = item.filePaths, paths.count == 1, let path = paths.first,
                  let type = UTType(filenameExtension: (path as NSString).pathExtension),
                  type.conforms(to: .image)
            else { return nil }
            return URL(fileURLWithPath: path)
        case .text, .link:
            return nil
        }
    }

    /// Bytes an item takes: its text and file paths, plus a stored image.
    public func byteSize(of item: ClipItem) -> Int {
        var size = (item.text?.utf8.count ?? 0) + (item.filePaths ?? []).reduce(0) { $0 + $1.utf8.count }
        if let name = item.imageName { size += imageSize(name) }
        return size
    }

    public var totalBytes: Int {
        items.reduce(0) { $0 + byteSize(of: $1) }
    }

    /// Whether the history holds more than the limit allows (until the next item trims it).
    public var isOverLimit: Bool {
        switch limit {
        case .count(let maximum): items.count > maximum
        case .size(let megabytes): totalBytes > Self.bytes(megabytes: megabytes)
        case .unlimited: false
        }
    }

    public func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: historyFile, options: .atomic)
        } catch {
            NSLog("ClipHistory: could not save the history: \(error)")
        }
    }

    private func insert(_ entry: ClipItem) {
        let position = items.firstIndex { $0.date <= entry.date } ?? items.endIndex
        items.insert(entry, at: position)
    }

    /// Removes the oldest items over the limit. The newest item always stays, even when it is
    /// larger than the size limit on its own.
    private func trimToLimit() {
        switch limit {
        case .count(let maximum):
            while items.count > max(maximum, 1) {
                deleteFiles(of: items.removeLast())
            }
        case .size(let megabytes):
            let maximum = Self.bytes(megabytes: megabytes)
            var total = totalBytes
            while items.count > 1, total > maximum {
                let removed = items.removeLast()
                total -= byteSize(of: removed)
                deleteFiles(of: removed)
            }
        case .unlimited:
            break
        }
    }

    private static func bytes(megabytes: Double) -> Int {
        Int(megabytes * 1_000_000)
    }

    private func imageSize(_ name: String) -> Int {
        if let size = imageSizes[name] { return size }
        let path = imagesDirectory.appendingPathComponent(name).path
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? 0
        imageSizes[name] = size
        return size
    }

    private func deleteFiles(of item: ClipItem) {
        guard let name = item.imageName else { return }
        try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(name))
        imageSizes[name] = nil
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyFile) else { return }
        do {
            items = try JSONDecoder().decode([ClipItem].self, from: data).sorted { $0.date > $1.date }
        } catch {
            NSLog("ClipHistory: the history file is unreadable, starting a new one: \(error)")
            let backup = directory.appendingPathComponent("history.unreadable.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: historyFile, to: backup)
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.saveNow() }
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}
