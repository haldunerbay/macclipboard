import ClipCore
import Foundation

/// The history limit and expiry chosen in the settings: saved, and handed to the store.
@MainActor
final class HistoryLimitSettings: ObservableObject {
    enum Kind: String {
        case count, size, unlimited
    }

    @Published var kind: Kind {
        didSet { apply() }
    }
    /// Kept while another kind is chosen, so switching back restores it.
    @Published var count: Int {
        didSet {
            if count < 1 { count = 1 }
            apply()
        }
    }
    @Published var megabytes: Double {
        didSet {
            if megabytes < 0.1 { megabytes = 0.1 }
            apply()
        }
    }
    /// Whether items expire `days` after they were last copied.
    @Published var expires: Bool {
        didSet { apply() }
    }
    @Published var days: Int {
        didSet {
            if days < 1 { days = 1 }
            apply()
        }
    }

    private let store: HistoryStore
    private let defaults = UserDefaults.standard
    private static let kindKey = "historyLimitKind"
    private static let countKey = "historyLimitCount"
    private static let megabytesKey = "historyLimitMegabytes"
    private static let expiresKey = "historyExpires"
    private static let daysKey = "historyExpiryDays"

    init(store: HistoryStore) {
        self.store = store
        kind = Kind(rawValue: defaults.string(forKey: Self.kindKey) ?? "") ?? .count
        count = defaults.object(forKey: Self.countKey) as? Int ?? 500
        megabytes = defaults.object(forKey: Self.megabytesKey) as? Double ?? 2
        expires = defaults.bool(forKey: Self.expiresKey)
        days = defaults.object(forKey: Self.daysKey) as? Int ?? 30
        store.limit = limit
        store.maxAge = maxAge
    }

    var limit: HistoryLimit {
        switch kind {
        case .count: .count(count)
        case .size: .size(megabytes: megabytes)
        case .unlimited: .unlimited
        }
    }

    var maxAge: TimeInterval? {
        expires ? TimeInterval(days) * 24 * 3600 : nil
    }

    /// The store removes the oldest items over the new limit when the next item arrives, and
    /// expired items at its next check.
    private func apply() {
        store.limit = limit
        store.maxAge = maxAge
        defaults.set(kind.rawValue, forKey: Self.kindKey)
        defaults.set(count, forKey: Self.countKey)
        defaults.set(megabytes, forKey: Self.megabytesKey)
        defaults.set(expires, forKey: Self.expiresKey)
        defaults.set(days, forKey: Self.daysKey)
    }
}
