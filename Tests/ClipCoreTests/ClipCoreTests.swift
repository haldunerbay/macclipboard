import Foundation
import Testing
@testable import ClipCore

struct ClassifierTests {
    @Test(arguments: [
        "https://www.apple.com/mac/",
        "  http://localhost:5173/login?redirect=%2F \n",
        "https://tr.wikipedia.org/wiki/İstanbul",
        "www.github.com/user/repo",
        "mailto:someone@example.com",
        "ssh://git@github.com/user/repo.git",
    ])
    func recognisesLinks(_ text: String) {
        #expect(ClipClassifier.link(in: text) != nil)
    }

    @Test(arguments: [
        "hello world",
        "see https://apple.com for details",
        "README.md",
        "apple.com",
        "https://",
        "mailto:",
        "file:///Users/me/Desktop",
        "",
    ])
    func keepsOtherTextAsText(_ text: String) {
        #expect(ClipClassifier.link(in: text) == nil)
    }

    @Test func textWithNothingVisibleIsNotText() {
        #expect(!ClipClassifier.hasVisibleText("\u{FFFC}"))
        #expect(!ClipClassifier.hasVisibleText(" \n\u{FFFC}\t"))
        #expect(ClipClassifier.hasVisibleText("\u{FFFC} caption"))
    }

    @Test func hashesTellContentKindsApart() {
        #expect(ClipClassifier.contentHash(text: "a") == ClipClassifier.contentHash(text: "a"))
        #expect(ClipClassifier.contentHash(text: "a") != ClipClassifier.contentHash(text: "b"))
        #expect(ClipClassifier.contentHash(text: "/tmp/a") != ClipClassifier.contentHash(filePaths: ["/tmp/a"]))
    }

    @Test func detectsScreenshotFilesByTheirAttribute() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        try Data([0]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(!ScreenshotFile.isScreenshot(atPath: url.path))
        let value = Data("1".utf8)
        let status = value.withUnsafeBytes { setxattr(url.path, ScreenshotFile.attribute, $0.baseAddress, value.count, 0, 0) }
        #expect(status == 0)
        #expect(ScreenshotFile.isScreenshot(atPath: url.path))
    }
}

struct SearchTests {
    let items = [
        ClipItem(category: .text, text: "Toplantı notları İSTANBUL ofisi", sourceApp: "Notes", contentHash: "1"),
        ClipItem(category: .link, text: "https://github.com/anthropics", sourceApp: "Safari", contentHash: "2"),
        ClipItem(category: .screenshot, filePaths: ["/Users/me/Desktop/Screenshot 2026-10-28 at 17.36.26.png"], contentHash: "3"),
    ]

    @Test func emptyQueryReturnsEverythingInOrder() {
        #expect(ClipSearch.filter(items, category: nil, query: "  ").map(\.contentHash) == ["1", "2", "3"])
    }

    @Test func matchesEveryWordIgnoringCaseAndDiacritics() {
        #expect(ClipSearch.filter(items, category: nil, query: "istanbul toplanti").map(\.contentHash) == ["1"])
        #expect(ClipSearch.filter(items, category: nil, query: "istanbul github").isEmpty)
    }

    @Test func searchesFileNamesAndSourceApps() {
        #expect(ClipSearch.filter(items, category: nil, query: "17.36").map(\.contentHash) == ["3"])
        #expect(ClipSearch.filter(items, category: nil, query: "safari").map(\.contentHash) == ["2"])
    }

    @Test func searchesScreenshotsByFileNameOnly() {
        let shot = ClipItem(category: .screenshot, filePaths: ["/Users/me/Library/Application Support/X/Screenshots/Screenshot 1.png"], contentHash: "s")
        #expect(ClipSearch.filter([shot], query: "library").isEmpty)
        #expect(ClipSearch.filter([shot], query: "screenshot 1").count == 1)
        let file = ClipItem(category: .file, filePaths: ["/Users/me/Projects/report.pdf"], contentHash: "f")
        #expect(ClipSearch.filter([file], query: "projects").count == 1)
    }

    @Test func allLeavesScreenshotsOutWhileSearching() {
        #expect(ClipSearch.isListedInAll(items[2], query: ""))
        #expect(ClipSearch.isListedInAll(items[2], query: "  "))
        #expect(!ClipSearch.isListedInAll(items[2], query: "17.36"))
        #expect(ClipSearch.isListedInAll(items[0], query: "istanbul"))
        #expect(ClipCategory.allCases.last == .screenshot)
    }

    @Test func filtersByCategory() {
        #expect(ClipSearch.filter(items, category: .link, query: "").map(\.contentHash) == ["2"])
        #expect(ClipSearch.filter(items, category: .link, query: "notları").isEmpty)
        #expect(ClipSearch.counts(items) == [.text: 1, .link: 1, .screenshot: 1])
    }

    @Test func titlesDescribeEachKind() {
        #expect(ClipItem(category: .text, text: "a\n\n  b", contentHash: "").title == "a b")
        #expect(ClipItem(category: .screenshot, pixelWidth: 800, pixelHeight: 600, contentHash: "").title == "Screenshot 800 × 600")
        #expect(items[2].title == "Screenshot 2026-10-28 at 17.36.26.png")
    }
}

struct FuzzySearchTests {
    let items = [
        ClipItem(category: .text, text: "Read the docs first", contentHash: "1"),
        ClipItem(category: .text, text: "Toplantı notları", contentHash: "2"),
        ClipItem(category: .text, text: "reading list for the weekend", contentHash: "3"),
    ]

    private func search(_ query: String, _ mode: SearchMode = .fuzzy) -> [String] {
        ClipSearch.filter(items, query: query, mode: mode).map(\.contentHash)
    }

    @Test func countsSwapsAndMissingLettersAsOneTypo() {
        let read = Array("read".unicodeScalars)
        #expect(ClipSearch.editDistance(Array("raed".unicodeScalars), read, limit: 2) == 1)
        #expect(ClipSearch.editDistance(Array("red".unicodeScalars), read, limit: 2) == 1)
        #expect(ClipSearch.editDistance(Array("kitten".unicodeScalars), Array("sitting".unicodeScalars), limit: 3) == 3)
        #expect(ClipSearch.editDistance(Array("kitten".unicodeScalars), Array("sitting".unicodeScalars), limit: 2) == nil)
    }

    @Test func findsWordsWithATypo() {
        #expect(search("raed").contains("1"))
        #expect(search("red").contains("1"))
        #expect(search("toplanit").contains("2"))
    }

    @Test func fullTextModeNeedsTheWordAsTyped() {
        #expect(search("raed", .fullText).isEmpty)
        #expect(search("read", .fullText) == ["1", "3"])
    }

    @Test func findsTheStartOfAWordWhileTyping() {
        #expect(search("raedin") == ["3"])
        #expect(ClipSearch.filter([ClipItem(category: .text, text: "invited", contentHash: "")], query: "invoce", mode: .fuzzy).isEmpty)
    }

    @Test func listsExactMatchesBeforeTypos() {
        // "raed it" contains the term as typed; "red car" only matches with a typo, though it is newer.
        let ranked = ClipSearch.filter(
            [ClipItem(category: .text, text: "red car", contentHash: "typo"), ClipItem(category: .text, text: "raed it", contentHash: "exact")],
            query: "raed",
            mode: .fuzzy
        ).map(\.contentHash)
        #expect(ranked == ["exact", "typo"])
    }

    @Test func shortTermsAllowNoDifferentLetterAndSkipFragments() {
        let words = [
            ClipItem(category: .text, text: "bed time", contentHash: "bed"),
            ClipItem(category: .text, text: "you’re right", contentHash: "fragment"),
            ClipItem(category: .text, text: "<link rel=\"icon\">", contentHash: "rel"),
        ]
        #expect(ClipSearch.filter(words, query: "red", mode: .fuzzy).isEmpty)
        #expect(ClipSearch.highlights(in: "you’re right", query: "red", mode: .fuzzy).isEmpty)
    }

    @Test func searchAndHighlightsAgreeOnTypoMatches() {
        let text = "Ready? It’s Read-only, re-read it"
        let item = ClipItem(category: .text, text: text, contentHash: "x")
        for query in ["raed", "red", "redy", "raedonly"] {
            let isListed = !ClipSearch.filter([item], query: query, mode: .fuzzy).isEmpty
            let isHighlighted = !ClipSearch.highlights(in: text, query: query, mode: .fuzzy).isEmpty
            #expect(isListed == isHighlighted, "\(query)")
        }
    }

    @Test func ranksWholeWordsThenWordStartsThenInsideWordsThenTypos() {
        let items = [ // newest first
            ClipItem(category: .text, text: "read me", contentHash: "typo"),
            ClipItem(category: .text, text: "stored value", contentHash: "inside"),
            ClipItem(category: .text, text: "redo the log", contentHash: "start"),
            ClipItem(category: .text, text: "the “red” car", contentHash: "word"),
        ]
        #expect(ClipSearch.filter(items, query: "red", mode: .fuzzy).map(\.contentHash) == ["word", "start", "inside", "typo"])
        #expect(ClipSearch.filter(items, query: "red", mode: .fullText).map(\.contentHash) == ["word", "start", "inside"])
        #expect(ClipSearch.isExactMatch(items[1], query: "red"))
        #expect(!ClipSearch.isExactMatch(items[0], query: "red"))
    }

    @Test func ranksHowATermOccurs() {
        #expect(ClipSearch.occurrenceRank(of: "red", in: "the “red” car") == 0)
        #expect(ClipSearch.occurrenceRank(of: "istanbul", in: "istanbul'da") == 0)
        #expect(ClipSearch.occurrenceRank(of: "red", in: "redo") == 1)
        #expect(ClipSearch.occurrenceRank(of: "red", in: "stored, then red") == 0)
        #expect(ClipSearch.occurrenceRank(of: "red", in: "stored") == 2)
        #expect(ClipSearch.occurrenceRank(of: "ore", in: "ömore") == 2)
        #expect(ClipSearch.occurrenceRank(of: "red", in: "read") == nil)
    }

    @Test func typoMatchesNeverOutrankExactOnes() {
        let items = [
            ClipItem(category: .text, text: "red raed", contentHash: "word-and-typo"),
            ClipItem(category: .text, text: "stored overread", contentHash: "inside-twice"),
        ]
        #expect(ClipSearch.filter(items, query: "red read", mode: .fuzzy).map(\.contentHash) == ["inside-twice", "word-and-typo"])
    }

    @Test func doesNotGuessShortWords() {
        #expect(search("rd").isEmpty)
        #expect(search("zzzz").isEmpty)
    }
}

struct HighlightTests {
    private func matched(_ text: String, _ query: String, _ mode: SearchMode = .fuzzy) -> [String] {
        ClipSearch.highlights(in: text, query: query, mode: mode).map { (text as NSString).substring(with: $0.range) }
    }

    @Test func marksEveryOccurrenceAndTheWordItIsIn() {
        let highlights = ClipSearch.highlights(in: "We developed the operation", query: "ope", mode: .fuzzy)
        #expect(highlights.map(\.word) == ["developed", "operation"])
        let isAllExact = highlights.allSatisfy(\.isExact)
        #expect(isAllExact)
        #expect(matched("We developed the operation", "ope") == ["ope", "ope"])
    }

    @Test func marksWordsWithATypoInFuzzyModeOnly() {
        let highlights = ClipSearch.highlights(in: "Read the docs", query: "raed", mode: .fuzzy)
        #expect(highlights == [SearchHighlight(range: NSRange(location: 0, length: 4), word: "Read", isExact: false)])
        #expect(matched("Read the docs", "raed", .fullText).isEmpty)
    }

    @Test func matchesTurkishLettersWithoutShiftingRanges() {
        #expect(matched("Toplantı notları İSTANBUL", "toplanti istanbul") == ["Toplantı", "İSTANBUL"])
    }

    @Test func previewStartsNearAFarMatch() {
        let text = String(repeating: "filler words here ", count: 300) + "the needle is here"
        let location = (text as NSString).range(of: "needle").location
        let excerpt = ClipSearch.excerpt(of: text, showing: location)
        #expect(excerpt.hasPrefix("… "))
        #expect(excerpt.contains("the needle"))
        #expect((excerpt as NSString).length < 400)
        #expect(ClipSearch.excerpt(of: "short text", showing: 6) == "short text")
    }
}

struct ShortcutTests {
    @Test func describesModifiersInMenuOrder() {
        let shortcut = Shortcut(keyCode: 9, keyLabel: "V", command: true, shift: true, option: true, control: true)
        #expect(shortcut.description == "⌃⌥⇧⌘V")
        #expect(Shortcut(keyCode: 49, keyLabel: "Space", option: true).description == "⌥Space")
    }

    @Test func needsCommandOptionOrControlUnlessItIsAFunctionKey() {
        #expect(Shortcut(keyCode: 9, keyLabel: "V", option: true).isValid)
        #expect(!Shortcut(keyCode: 9, keyLabel: "V").isValid)
        #expect(!Shortcut(keyCode: 9, keyLabel: "V", shift: true).isValid)
        #expect(Shortcut(keyCode: 96, keyLabel: "F5").isValid)
    }

    @Test func namesKeysWithoutACharacter() {
        #expect(Shortcut.specialKeyLabel(for: 49) == "Space")
        #expect(Shortcut.specialKeyLabel(for: 111) == "F12")
        #expect(Shortcut.specialKeyLabel(for: 9) == nil)
    }

    @Test func survivesSaving() throws {
        let shortcut = Shortcut(keyCode: 9, keyLabel: "V", command: true, option: true)
        let data = try JSONEncoder().encode(shortcut)
        #expect(try JSONDecoder().decode(Shortcut.self, from: data) == shortcut)
    }
}

@MainActor
struct HistoryStoreTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ClipHistoryTests-\(UUID().uuidString)")

    private func textItem(_ text: String, date: Date = Date()) -> ClipItem {
        ClipItem(category: .text, date: date, text: text, contentHash: ClipClassifier.contentHash(text: text))
    }

    @Test func newestItemComesFirst() {
        let store = HistoryStore(directory: directory)
        store.add(textItem("old", date: Date(timeIntervalSinceNow: -60)))
        store.add(textItem("new"))
        store.add(textItem("older", date: Date(timeIntervalSinceNow: -120)))
        #expect(store.items.compactMap(\.text) == ["new", "old", "older"])
    }

    @Test func copyingTheSameContentAgainMovesItToTheTop() {
        let store = HistoryStore(directory: directory)
        let first = store.add(textItem("a", date: Date(timeIntervalSinceNow: -60)))
        store.add(textItem("b", date: Date(timeIntervalSinceNow: -30)))
        store.add(textItem("a"))
        #expect(store.items.compactMap(\.text) == ["a", "b"])
        #expect(store.items.first?.id == first?.id)
    }

    @Test func touchMovesAnEntryToTheTop() throws {
        let store = HistoryStore(directory: directory)
        let a = try #require(store.add(textItem("a", date: Date(timeIntervalSinceNow: -60))))
        store.add(textItem("b", date: Date(timeIntervalSinceNow: -30)))
        store.touch(a.id)
        #expect(store.items.compactMap(\.text) == ["a", "b"])
    }

    @Test func dropsTheOldestItemsAndTheirImagesBeyondTheLimit() throws {
        let store = HistoryStore(directory: directory, limit: .count(2))
        let image = ClipItem(category: .image, date: Date(timeIntervalSinceNow: -60), contentHash: "i:1")
        let stored = try #require(store.add(image, imageData: Data([1, 2, 3])))
        let imageURL = try #require(store.imageURL(for: stored))
        #expect(FileManager.default.fileExists(atPath: imageURL.path))
        store.add(textItem("b", date: Date(timeIntervalSinceNow: -30)))
        store.add(textItem("c"))
        #expect(store.items.compactMap(\.text) == ["c", "b"])
        #expect(!FileManager.default.fileExists(atPath: imageURL.path))
    }

    @Test func sizeLimitDropsTheOldestUntilTheContentFits() {
        let store = HistoryStore(directory: directory, limit: .size(megabytes: 0.001)) // 1 000 bytes
        store.add(textItem(String(repeating: "a", count: 400), date: Date(timeIntervalSinceNow: -60)))
        store.add(textItem(String(repeating: "b", count: 400), date: Date(timeIntervalSinceNow: -30)))
        store.add(textItem(String(repeating: "c", count: 400)))
        #expect(store.items.compactMap { $0.text?.first } == ["c", "b"])
        #expect(store.totalBytes == 800)
    }

    @Test func sizeLimitCountsStoredImagesAndDeletesThem() throws {
        let store = HistoryStore(directory: directory, limit: .size(megabytes: 0.001))
        let image = try #require(store.add(ClipItem(category: .image, date: Date(timeIntervalSinceNow: -60), contentHash: "i:1"), imageData: Data(count: 700)))
        let imageURL = try #require(store.imageURL(for: image))
        #expect(store.byteSize(of: image) == 700)
        store.add(textItem(String(repeating: "x", count: 400)))
        #expect(store.items.compactMap(\.text).count == 1)
        #expect(store.items.count == 1)
        #expect(!FileManager.default.fileExists(atPath: imageURL.path))
    }

    @Test func sizeLimitKeepsTheNewestItemEvenWhenItIsTooLarge() {
        let store = HistoryStore(directory: directory, limit: .size(megabytes: 0.0001)) // 100 bytes
        store.add(textItem(String(repeating: "a", count: 500)))
        #expect(store.items.count == 1)
    }

    @Test func unlimitedKeepsEverything() {
        let store = HistoryStore(directory: directory, limit: .unlimited)
        for index in 0..<50 { store.add(textItem("item \(index)")) }
        #expect(store.items.count == 50)
        #expect(!store.isOverLimit)
    }

    @Test func aLowerLimitTakesEffectWhenTheNextItemArrives() {
        let store = HistoryStore(directory: directory, limit: .unlimited)
        for index in 0..<5 { store.add(textItem("item \(index)", date: Date(timeIntervalSinceNow: Double(index - 10)))) }
        store.limit = .count(2)
        #expect(store.items.count == 5)
        #expect(store.isOverLimit)
        store.add(textItem("new"))
        #expect(store.items.compactMap(\.text) == ["new", "item 4"])
        #expect(!store.isOverLimit)
    }

    @Test func removesItemsOlderThanTheMaximumAge() throws {
        let store = HistoryStore(directory: directory, limit: .unlimited)
        let day: TimeInterval = 24 * 3600
        let oldImage = try #require(store.add(ClipItem(category: .image, date: Date(timeIntervalSinceNow: -10 * day), contentHash: "i:old"), imageData: Data(count: 10)))
        let imageURL = try #require(store.imageURL(for: oldImage))
        store.add(textItem("five days old", date: Date(timeIntervalSinceNow: -5 * day)))
        store.add(textItem("today"))
        #expect(store.expiredCount() == 0)

        store.maxAge = 7 * day
        #expect(store.expiredCount() == 1)
        #expect(store.removeExpired() == 1)
        #expect(store.items.compactMap(\.text) == ["today", "five days old"])
        #expect(!FileManager.default.fileExists(atPath: imageURL.path))

        #expect(store.removeExpired(now: Date(timeIntervalSinceNow: 3 * day)) == 1)
        #expect(store.items.compactMap(\.text) == ["today"])
    }

    @Test func doesNotAddAnItemThatHasAlreadyExpired() {
        let store = HistoryStore(directory: directory, limit: .unlimited)
        store.maxAge = 3 * 24 * 3600
        #expect(store.add(textItem("old screenshot", date: Date(timeIntervalSinceNow: -4 * 24 * 3600))) == nil)
        #expect(store.add(textItem("new")) != nil)
        #expect(store.items.compactMap(\.text) == ["new"])
    }

    @Test func copyingAnExpiredItemAgainKeepsIt() {
        let store = HistoryStore(directory: directory, limit: .unlimited)
        store.add(textItem("again", date: Date(timeIntervalSinceNow: -10 * 24 * 3600)))
        store.maxAge = 7 * 24 * 3600
        store.add(textItem("again"))
        #expect(store.items.compactMap(\.text) == ["again"])
    }

    @Test func savedHistoryLoadsAgain() {
        let store = HistoryStore(directory: directory)
        store.add(textItem("kept"))
        store.saveNow()
        #expect(HistoryStore(directory: directory).items.compactMap(\.text) == ["kept"])
    }
}
