import AppKit
import ClipCore
import SwiftUI

struct ClipRow: View {
    let item: ClipItem
    let store: HistoryStore
    let isSelected: Bool
    @Environment(\.strings) private var strings

    var body: some View {
        HStack(spacing: 10) {
            ClipIcon(item: item, store: store)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(strings.title(of: item))
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor : Color.clear))
        .foregroundStyle(isSelected ? Color.white : Color.primary)
    }

    private var subtitle: String {
        [strings.categoryName(item.category), item.category == .screenshot ? nil : item.sourceApp, strings.relativeDate(item.date)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

struct ClipIcon: View {
    let item: ClipItem
    let store: HistoryStore

    var body: some View {
        if let url = store.imageURL(for: item) {
            ThumbnailView(url: url, maxPixel: 96, fill: true)
        } else if item.category == .file, let path = item.filePaths?.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: item.category.symbolName)
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.07))
        }
    }
}
