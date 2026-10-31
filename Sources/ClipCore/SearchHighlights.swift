import Foundation

/// A place in a text where the search matched.
public struct SearchHighlight: Equatable, Sendable {
    /// UTF-16 range in the text, as NSString and AttributedString use it.
    public let range: NSRange
    /// The whole word the match lies in, as written in the text.
    public let word: String
    /// false when the word only matches with a typo.
    public let isExact: Bool
}

extension ClipSearch {
    /// Where the query matches a text, in reading order: every occurrence of a term as typed and,
    /// in fuzzy mode for a term that does not occur as typed, every word that matches it with a typo.
    public static func highlights(in text: String, query: String, mode: SearchMode, limit: Int = 500) -> [SearchHighlight] {
        let terms = query.split(whereSeparator: \.isWhitespace).map { fold(String($0)) }
        guard !terms.isEmpty, !text.isEmpty else { return [] }
        let original = text as NSString
        // The Turkish dotted and dotless i are one UTF-16 unit like i and I, so ranges found in
        // this copy are ranges in `text`.
        let searchable = text.replacingOccurrences(of: "ı", with: "i").replacingOccurrences(of: "İ", with: "I") as NSString
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        var highlights: [SearchHighlight] = []
        for term in terms where highlights.count < limit {
            var remaining = NSRange(location: 0, length: searchable.length)
            var isFoundAsTyped = false
            while highlights.count < limit {
                let range = searchable.range(of: term, options: options, range: remaining)
                guard range.location != NSNotFound, range.length > 0 else { break }
                isFoundAsTyped = true
                highlights.append(SearchHighlight(range: range, word: word(around: range, in: original), isExact: true))
                remaining = NSRange(location: NSMaxRange(range), length: searchable.length - NSMaxRange(range))
            }
            let termLength = term.unicodeScalars.count
            guard !isFoundAsTyped, mode == .fuzzy, allowedTypos(forLength: termLength) > 0 else { continue }
            for token in tokens(in: text) where highlights.count < limit {
                guard canMatchWithTypo(termLength: termLength, wordLength: token.scalars.count) else { continue }
                let word = original.substring(with: token.range)
                guard typoDistance(term, in: [Array(fold(word).unicodeScalars)]) != nil else { continue }
                highlights.append(SearchHighlight(range: token.range, word: word, isExact: false))
            }
        }
        return highlights.sorted { $0.range.location < $1.range.location }
    }

    /// The text to preview, at most `length` UTF-16 units: from the start or, when `location`
    /// (the first match) lies further in, from shortly before it, marked with "… ".
    public static func excerpt(of text: String, showing location: Int?, length: Int = 10_000, context: Int = 300) -> String {
        let text = text as NSString
        guard let location, location > context * 3, location < text.length else {
            return substring(of: text, from: 0, length: length)
        }
        // Start at the first word boundary after `context` units before the match.
        var start = location - context
        while start < location, let scalar = Unicode.Scalar(text.character(at: start)), !CharacterSet.whitespacesAndNewlines.contains(scalar) {
            start += 1
        }
        return "… " + substring(of: text, from: min(start + 1, location), length: length)
    }

    private static func substring(of text: NSString, from start: Int, length: Int) -> String {
        let range = NSRange(location: start, length: min(length, text.length - start))
        return text.substring(with: text.rangeOfComposedCharacterSequences(for: range))
    }

    /// The whole word around a match (at most 40 characters each way).
    private static func word(around range: NSRange, in text: NSString) -> String {
        func isWordCharacter(_ index: Int) -> Bool {
            guard let scalar = Unicode.Scalar(text.character(at: index)) else { return false }
            return CharacterSet.alphanumerics.contains(scalar)
        }
        var start = range.location
        var end = NSMaxRange(range)
        while start > 0, range.location - start < 40, isWordCharacter(start - 1) { start -= 1 }
        while end < text.length, end - NSMaxRange(range) < 40, isWordCharacter(end) { end += 1 }
        return text.substring(with: NSRange(location: start, length: end - start))
    }
}
