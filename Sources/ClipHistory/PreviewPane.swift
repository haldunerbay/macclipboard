import AppKit
import ClipCore
import SwiftUI

struct PreviewPane: View {
    let item: ClipItem?
    let store: HistoryStore
    /// The search, whose matches are highlighted.
    let query: String
    let mode: SearchMode
    @Environment(\.strings) private var strings

    var body: some View {
        if let item {
            // The details follow the content; long content scrolls and keeps them in view.
            VStack(alignment: .leading, spacing: 12) {
                content(item)
                    .layoutPriority(1)
                Divider()
                details(item)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text(strings.selectToPreview)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func content(_ item: ClipItem) -> some View {
        if let url = store.imageURL(for: item) {
            ThumbnailView(url: url, maxPixel: 1200, placeholderAspectRatio: aspectRatio(of: item))
                .frame(maxWidth: .infinity)
        } else {
            switch item.category {
            case .link:
                VStack(alignment: .leading, spacing: 10) {
                    Text(highlighted(item.text ?? ""))
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                    if let url = (item.text).flatMap(ClipClassifier.link(in:)) {
                        Button(strings.openLink) { NSWorkspace.shared.open(url) }
                    }
                }
            case .file:
                scrollingIfNeeded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(item.filePaths ?? [], id: \.self) { path in
                            HStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(highlighted(path))
                                    .font(.system(size: 12))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            default:
                scrollingIfNeeded {
                    Text(highlighted(previewText(of: item.text ?? "")))
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// The text from the start, or from shortly before the first match when that is further in.
    private func previewText(of text: String) -> String {
        let firstMatch = query.isEmpty
            ? nil
            : ClipSearch.highlights(in: String(text.prefix(50_000)), query: query, mode: mode, limit: 1).first?.range.location
        return ClipSearch.excerpt(of: text, showing: firstMatch)
    }

    /// The text with the search matches marked: yellow as typed, orange with a typo.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard !query.isEmpty else { return attributed }
        for highlight in ClipSearch.highlights(in: text, query: query, mode: mode) {
            guard let range = Range(highlight.range, in: attributed) else { continue }
            attributed[range].backgroundColor = (highlight.isExact ? Color.yellow : Color.orange).opacity(0.45)
        }
        return attributed
    }

    /// The words the search found in the item, for the details.
    private func foundWords(in item: ClipItem) -> String? {
        guard !query.isEmpty else { return nil }
        let files = item.category == .screenshot ? item.fileNames : item.filePaths ?? []
        let texts = [item.text.map { String($0.prefix(50_000)) }, item.sourceApp].compactMap { $0 } + files
        let highlights = texts.flatMap { ClipSearch.highlights(in: $0, query: query, mode: mode) }
        guard !highlights.isEmpty else { return nil }
        var seen = Set<String>()
        let words = highlights.compactMap { highlight -> String? in
            guard seen.insert(highlight.word.lowercased()).inserted else { return nil }
            return highlight.isExact ? highlight.word : strings.typo(highlight.word)
        }
        let shown = Array(words.prefix(6)) + (words.count > 6 ? [strings.more(words.count - 6)] : [])
        return strings.matchesSummary(highlights.count, words: shown)
    }

    /// The content at its own height, or in a scroll view when it is taller than the pane.
    private func scrollingIfNeeded(@ViewBuilder _ content: () -> some View) -> some View {
        let content = content()
        return ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
    }

    private func aspectRatio(of item: ClipItem) -> CGFloat? {
        guard let width = item.pixelWidth, let height = item.pixelHeight, height > 0 else { return nil }
        return CGFloat(width) / CGFloat(height)
    }

    private func details(_ item: ClipItem) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            if let found = foundWords(in: item) { row(strings.found, AttributedString(found)) }
            row(strings.type, strings.categoryName(item.category))
            if let sourceApp = item.sourceApp, item.category != .screenshot { row(strings.copiedFrom, highlighted(sourceApp)) }
            row(strings.copied, strings.dateAndTime(item.date))
            if let size = item.pixelSizeDescription { row(strings.size, size) }
            if let text = item.text, item.category == .text {
                let lines = text.split(whereSeparator: \.isNewline).count
                row(strings.length, strings.lengthValue(characters: text.count, lines: lines))
            }
            if item.category == .screenshot, let path = item.filePaths?.first { row(strings.file, highlighted(path)) }
        }
        .font(.system(size: 11))
    }

    private func row(_ label: String, _ value: String) -> some View {
        row(label, AttributedString(value))
    }

    private func row(_ label: String, _ value: AttributedString) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}
