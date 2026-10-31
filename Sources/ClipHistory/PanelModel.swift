import ClipCore
import Combine
import Foundation

/// What is typed in the search field. It is kept apart from `PanelModel`, so a keystroke redraws
/// only the field; the results follow when typing pauses.
@MainActor
final class SearchText: ObservableObject {
    @Published var text = ""
}

/// State of the history popup: search, category filter, the results and the selected row.
@MainActor
final class PanelModel: ObservableObject {
    /// nil is "All".
    static let categories: [ClipCategory?] = [nil] + ClipCategory.allCases.map(Optional.some)

    let searchText = SearchText()
    /// The search the results are for: the typed text, applied 50 ms after the last keystroke
    /// (or at once by `commitSearch()`).
    @Published private(set) var query = "" {
        didSet { if query != oldValue { selectFirstAndRefresh() } }
    }
    @Published var category: ClipCategory? {
        didSet { if category != oldValue { selectFirstAndRefresh() } }
    }
    @Published var searchMode = SearchMode(rawValue: UserDefaults.standard.string(forKey: PanelModel.searchModeKey) ?? "") ?? .fuzzy {
        didSet {
            UserDefaults.standard.set(searchMode.rawValue, forKey: Self.searchModeKey)
            if searchMode != oldValue { selectFirstAndRefresh() }
        }
    }
    /// nil selects the first result.
    @Published var selectedID: UUID?
    /// Matches of the search in every category, for the category counts.
    @Published private(set) var matches: [ClipItem] = []
    /// How many matches the All tab lists (no screenshots while searching).
    @Published private(set) var allCount = 0
    /// Matches in the selected category, best and newest first. Computed once per change, not
    /// on every redraw.
    @Published private(set) var results: [ClipItem] = []
    /// The first result that only matches with a typo, where the "Similar to" heading goes.
    @Published private(set) var firstSimilarID: UUID?
    @Published private(set) var isShowingSettings = false
    @Published private(set) var focusRequest = 0
    @Published private(set) var canAutoPaste = true

    let store: HistoryStore
    private let searchIndex = SearchIndex()
    private var subscriptions: Set<AnyCancellable> = []
    private static let searchModeKey = "searchMode"

    init(store: HistoryStore) {
        self.store = store
        // @Published sends the new items before they are stored, so they are passed along.
        store.$items
            .sink { [weak self] items in self?.refreshResults(items: items) }
            .store(in: &subscriptions)
        searchText.$text
            .removeDuplicates()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] text in self?.query = text }
            .store(in: &subscriptions)
    }

    func selectedItem(in results: [ClipItem]) -> ClipItem? {
        results.first { $0.id == selectedID } ?? results.first
    }

    /// Applies the typed text now, before a key acts on the results.
    func commitSearch() {
        query = searchText.text
    }

    func clearSearch() {
        searchText.text = ""
        query = ""
    }

    func prepareForShow(settings: Bool) {
        clearSearch()
        category = nil
        selectedID = nil
        isShowingSettings = settings
        canAutoPaste = Paster.hasAccessibility
    }

    func showSettings() {
        isShowingSettings = true
    }

    func showHistory() {
        isShowingSettings = false
        requestFocus()
    }

    func requestFocus() {
        focusRequest += 1
    }

    func move(by offset: Int) {
        guard !results.isEmpty else { return }
        let current = results.firstIndex { $0.id == selectedID } ?? 0
        selectedID = results[min(max(current + offset, 0), results.count - 1)].id
    }

    func cycleCategory(backwards: Bool) {
        let all = Self.categories
        let index = all.firstIndex(of: category) ?? 0
        category = all[(index + (backwards ? all.count - 1 : 1)) % all.count]
    }

    func selectCategory(at index: Int) {
        guard Self.categories.indices.contains(index) else { return }
        category = Self.categories[index]
    }

    /// Deletes the selected item and selects the one that took its place.
    func deleteSelection() {
        guard let selected = selectedItem(in: results), let index = results.firstIndex(of: selected) else { return }
        store.remove(selected.id)
        selectedID = results.isEmpty ? nil : results[min(index, results.count - 1)].id
    }

    private func selectFirstAndRefresh() {
        selectedID = nil
        refreshResults()
    }

    private func refreshResults(items: [ClipItem]? = nil) {
        let all = ClipSearch.filter(items ?? store.items, query: query, mode: searchMode, index: searchIndex)
        let inAll = all.filter { ClipSearch.isListedInAll($0, query: query) }
        matches = all
        allCount = inAll.count
        results = category.map { category in all.filter { $0.category == category } } ?? inAll
        firstSimilarID = query.isEmpty ? nil : results.first { !ClipSearch.isExactMatch($0, query: query, index: searchIndex) }?.id
    }
}
