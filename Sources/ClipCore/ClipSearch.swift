import Foundation

public enum SearchMode: String, CaseIterable, Sendable {
    /// Every word of the query appears in the item as typed.
    case fullText
    /// Also finds words with a typo: "raed" or "red" finds "read".
    case fuzzy
}

public enum ClipSearch {
    /// Items of the category (all when nil) that match every word of the query. Matching ignores
    /// case and diacritics, Turkish ones included: "istanbul toplanti" finds "İSTANBUL toplantı".
    /// Best matches first: the term as a whole word ("red"), at the start of a word ("redo"),
    /// inside a word ("stored"), then, in fuzzy mode, with a typo ("read"). Equally good matches
    /// keep the newest-first order.
    /// Pass the same `index` on every search so each item's text is prepared only once.
    public static func filter(
        _ items: [ClipItem],
        category: ClipCategory? = nil,
        query: String,
        mode: SearchMode = .fullText,
        index: SearchIndex = SearchIndex()
    ) -> [ClipItem] {
        let candidates = category.map { category in items.filter { $0.category == category } } ?? items
        let terms = query.split(whereSeparator: \.isWhitespace).map { fold(String($0)) }
        guard !terms.isEmpty else { return candidates }
        index.prune(keeping: items)
        let matches = candidates.enumerated().compactMap { position, item in
            matchCost(of: item, terms: terms, mode: mode, index: index).map { (item: item, cost: $0, position: position) }
        }
        return matches.sorted { ($0.cost, $0.position) < ($1.cost, $1.position) }.map(\.item)
    }

    /// While searching, the All tab leaves screenshots out: they would fill the results with
    /// thumbnails that are slow to draw. Their own tab still searches them; without a search, All
    /// lists everything.
    public static func isListedInAll(_ item: ClipItem, query: String) -> Bool {
        item.category != .screenshot || query.allSatisfy(\.isWhitespace)
    }

    public static func counts(_ items: [ClipItem]) -> [ClipCategory: Int] {
        items.reduce(into: [:]) { counts, item in counts[item.category, default: 0] += 1 }
    }

    /// Whether every word of the query appears in the item as typed (no typo needed).
    public static func isExactMatch(_ item: ClipItem, query: String, index: SearchIndex = SearchIndex()) -> Bool {
        let haystack = index.haystack(of: item)
        return query.split(whereSeparator: \.isWhitespace).allSatisfy { contains(haystack, fold(String($0))) }
    }

    /// Added per term that only matches with a typo, so those items always follow the exact ones.
    static let typoCost = 100

    /// Lower is better: per term the `occurrenceRank` when it appears as typed, `typoCost` plus
    /// the distance when only with a typo. nil when a term is missing.
    static func matchCost(of item: ClipItem, terms: [String], mode: SearchMode, index: SearchIndex) -> Int? {
        let haystack = index.haystack(of: item)
        var cost = 0
        for term in terms {
            if let rank = occurrenceRank(of: term, in: haystack) {
                cost += rank
                continue
            }
            guard mode == .fuzzy, allowedTypos(forLength: term.unicodeScalars.count) > 0,
                  let distance = typoDistance(term, in: index.words(of: item))
            else { return nil }
            cost += typoCost + distance
        }
        return cost
    }

    /// How well a (folded) term occurs in a (folded) text: 0 as a whole word, 1 at the start of a
    /// word, 2 inside one; nil when it does not occur.
    static func occurrenceRank(of term: String, in haystack: String) -> Int? {
        var haystack = haystack
        var term = term
        return haystack.withUTF8 { text -> Int? in
            term.withUTF8 { needle -> Int? in
                guard let textStart = text.baseAddress, let needleStart = needle.baseAddress, !needle.isEmpty else { return nil }
                var best: Int?
                var offset = 0
                while offset + needle.count <= text.count,
                      let found = memmem(textStart + offset, text.count - offset, needleStart, needle.count) {
                    let start = UnsafeRawPointer(textStart).distance(to: UnsafeRawPointer(found))
                    let end = start + needle.count
                    let startsWord = !isWordCharacter(before: start, in: text)
                    let endsWord = !isWordCharacter(at: end, in: text)
                    let rank = startsWord ? (endsWord ? 0 : 1) : 2
                    if rank == 0 { return 0 }
                    best = min(best ?? rank, rank)
                    offset = start + 1
                }
                return best
            }
        }
    }

    private static func isWordCharacter(before index: Int, in text: UnsafeBufferPointer<UInt8>) -> Bool {
        guard index > 0 else { return false }
        var start = index - 1
        while start > 0, text[start] & 0xC0 == 0x80 { start -= 1 } // back to the first byte of the character
        return isWordCharacter(at: start, in: text)
    }

    /// Letters, digits and combining marks, as `tokens(in:)` counts them.
    private static func isWordCharacter(at index: Int, in text: UnsafeBufferPointer<UInt8>) -> Bool {
        guard index < text.count else { return false }
        let byte = text[index]
        if byte < 0x80 {
            return (0x30...0x39).contains(byte) || (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
        }
        let length = byte >= 0xF0 ? 4 : byte >= 0xE0 ? 3 : 2
        let bytes = UnsafeBufferPointer(rebasing: text[index..<min(index + length, text.count)])
        guard let scalar = String(decoding: bytes, as: UTF8.self).unicodeScalars.first else { return false }
        let category = scalar.properties.generalCategory
        return scalar.properties.isAlphabetic || category == .decimalNumber || category == .nonspacingMark
    }

    /// Typos a term of this length may have: none up to 2 letters, 1 up to 5, then 2.
    static func allowedTypos(forLength length: Int) -> Int {
        length <= 2 ? 0 : length <= 5 ? 1 : 2
    }

    /// Words shorter than this never match with a typo: "re" (from "you're") is not "red".
    static let minimumTypoWordLength = 3

    /// Whether a word of this length can match the term with a typo at all, so the rest is skipped cheaply.
    static func canMatchWithTypo(termLength: Int, wordLength: Int) -> Bool {
        let limit = allowedTypos(forLength: termLength)
        return limit > 0 && wordLength >= max(minimumTypoWordLength, termLength - limit)
            && (wordLength <= termLength + limit || termLength >= 5)
    }

    /// The smallest typo distance between the term and a word of the text, or the start of a
    /// longer word for terms of 5+ letters with at most one typo (the query may still be being
    /// typed: "raedin" finds "reading", "invoce" does not find "invited"). Terms of up to 4 letters allow a swapped, missing or extra letter but not a
    /// different one: "red" finds "read", not "bed".
    static func typoDistance(_ term: String, in words: [[Unicode.Scalar]]) -> Int? {
        let term = Array(term.unicodeScalars)
        let limit = allowedTypos(forLength: term.count)
        guard limit > 0 else { return nil }
        let substitutionCost = term.count <= 4 ? 2 : 1
        var best: Int?
        for word in words where canMatchWithTypo(termLength: term.count, wordLength: word.count) {
            let bound = (best ?? limit + 1) - 1
            var distance = editDistance(term[...], word[...], limit: bound, substitutionCost: substitutionCost)
            if term.count >= 5, word.count > term.count,
               let start = editDistance(term[...], word.prefix(term.count), limit: min(bound, 1), substitutionCost: substitutionCost) {
                distance = min(distance ?? start, start)
            }
            guard let distance else { continue }
            best = distance
            if distance <= 1 { break }
        }
        return best
    }

    /// Optimal string alignment distance: an insertion, deletion or swap of two neighbouring
    /// characters each counts 1 ("raed" → "read" is 1), a substitution `substitutionCost`.
    /// nil when above `limit`.
    static func editDistance(_ a: [Unicode.Scalar], _ b: [Unicode.Scalar], limit: Int, substitutionCost: Int = 1) -> Int? {
        editDistance(a[...], b[...], limit: limit, substitutionCost: substitutionCost)
    }

    static func editDistance(
        _ a: ArraySlice<Unicode.Scalar>,
        _ b: ArraySlice<Unicode.Scalar>,
        limit: Int,
        substitutionCost: Int = 1
    ) -> Int? {
        guard limit >= 0, abs(a.count - b.count) <= limit else { return nil }
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
        let a = Array(a), b = Array(b)
        var beforePrevious = [Int](repeating: 0, count: b.count + 1)
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            var rowMinimum = i
            for j in 1...b.count {
                var value = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : substitutionCost))
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    value = min(value, beforePrevious[j - 2] + 1)
                }
                current[j] = value
                rowMinimum = min(rowMinimum, value)
            }
            guard rowMinimum <= limit else { return nil }
            (beforePrevious, previous, current) = (previous, current, beforePrevious)
        }
        return previous[b.count] <= limit ? previous[b.count] : nil
    }

    /// The distinct words of a (folded) text; long texts are read up to 20 000 characters.
    static func words(in text: String) -> [[Unicode.Scalar]] {
        Array(Set(tokens(in: text, maxScalars: 20_000).map(\.scalars)))
    }

    /// The words of a text with their UTF-16 ranges: runs of letters, digits and combining marks.
    /// Search and highlighting both split with this, so they agree on what a word is.
    static func tokens(in text: String, maxScalars: Int = .max) -> [(scalars: [Unicode.Scalar], range: NSRange)] {
        var tokens: [(scalars: [Unicode.Scalar], range: NSRange)] = []
        var word: [Unicode.Scalar] = []
        var start = 0
        var offset = 0
        for scalar in text.unicodeScalars.prefix(maxScalars) {
            let category = scalar.properties.generalCategory
            if scalar.properties.isAlphabetic || category == .decimalNumber || category == .nonspacingMark {
                if word.isEmpty { start = offset }
                word.append(scalar)
            } else if !word.isEmpty {
                tokens.append((word, NSRange(location: start, length: offset - start)))
                word.removeAll(keepingCapacity: true)
            }
            offset += scalar.utf16.count
        }
        if !word.isEmpty { tokens.append((word, NSRange(location: start, length: offset - start))) }
        return tokens
    }

    /// Byte-wise substring search on folded texts: far faster than `String.contains` on long ones.
    static func contains(_ haystack: String, _ needle: String) -> Bool {
        var haystack = haystack
        var needle = needle
        return haystack.withUTF8 { text in
            needle.withUTF8 { term in
                term.isEmpty || (text.count >= term.count && memmem(text.baseAddress, text.count, term.baseAddress, term.count) != nil)
            }
        }
    }

    /// Lowercase without diacritics; the dotless ı has no decomposition, so it is mapped by hand.
    static func fold(_ text: String) -> String {
        text.replacingOccurrences(of: "ı", with: "i")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}

/// The folded text and the words of each item, kept between searches so typing stays fast.
public final class SearchIndex {
    private struct Entry {
        let key: String
        let haystack: String
        var words: [[Unicode.Scalar]]?
    }

    private var entries: [UUID: Entry] = [:]

    public init() {}

    func haystack(of item: ClipItem) -> String {
        entry(of: item).haystack
    }

    /// Split only when a term is not found as typed, so full-text search never pays for it.
    func words(of item: ClipItem) -> [[Unicode.Scalar]] {
        var entry = entry(of: item)
        if let words = entry.words { return words }
        let words = ClipSearch.words(in: entry.haystack)
        entry.words = words
        entries[item.id] = entry
        return words
    }

    /// Forgets deleted items once they pile up.
    func prune(keeping items: [ClipItem]) {
        guard entries.count > items.count + 100 else { return }
        let ids = Set(items.map(\.id))
        entries = entries.filter { ids.contains($0.key) }
    }

    private func entry(of item: ClipItem) -> Entry {
        // The searchable text follows the content and the source app.
        let key = item.contentHash + "|" + (item.sourceApp ?? "")
        if let entry = entries[item.id], entry.key == key { return entry }
        let entry = Entry(key: key, haystack: ClipSearch.fold(item.searchableText))
        entries[item.id] = entry
        return entry
    }
}
