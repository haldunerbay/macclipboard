import ClipCore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: HistoryStore
    let launchAtLogin: LaunchAtLogin
    let openShortcut: OpenShortcut
    let historyLimit: HistoryLimitSettings
    @ObservedObject var language: LanguageSettings
    let onChoose: (ClipItem) -> Void

    private var strings: Strings { language.strings }

    var body: some View {
        VStack(spacing: 0) {
            if model.isShowingSettings {
                settingsHeader
                Divider()
                SettingsPane(
                    language: language,
                    launchAtLogin: launchAtLogin,
                    openShortcut: openShortcut,
                    searchMode: $model.searchMode,
                    historyLimit: historyLimit,
                    store: store
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                history
            }
        }
        .frame(minWidth: 720, minHeight: 420)
        // The title bar is hidden, so the content starts at the top of the panel.
        .ignoresSafeArea()
        .environment(\.strings, strings)
        .environment(\.locale, strings.locale)
    }

    @ViewBuilder
    private var history: some View {
        let results = model.results
        let selected = model.selectedItem(in: results)
        SearchBar(
            searchText: model.searchText,
            focusRequest: model.focusRequest,
            onClear: model.clearSearch,
            onSettings: model.showSettings
        )
        CategoryBar(model: model, counts: ClipSearch.counts(model.matches), allCount: model.allCount)
        Divider()
        HStack(spacing: 0) {
            list(results, selected: selected)
                .frame(width: 340)
            Divider()
            PreviewPane(item: selected, store: store, query: model.query, mode: model.searchMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        Divider()
        footer
    }

    private var settingsHeader: some View {
        ZStack {
            Text(strings.settings)
                .font(.system(size: 15, weight: .semibold))
            HStack {
                Button {
                    model.showHistory()
                } label: {
                    Label(strings.history, systemImage: "chevron.left")
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(strings.backToHistory)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private func list(_ results: [ClipItem], selected: ClipItem?) -> some View {
        // Results come exact matches first; headings show where the typo matches begin.
        let firstSimilarID = model.firstSimilarID
        let query = model.query.trimmingCharacters(in: .whitespaces)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results) { item in
                        VStack(spacing: 2) {
                            if firstSimilarID != nil, item.id == results.first?.id, item.id != firstSimilarID {
                                groupHeading(strings.contains(query))
                            }
                            if item.id == firstSimilarID {
                                groupHeading(strings.similar(to: query))
                            }
                            ClipRow(item: item, store: store, isSelected: item.id == selected?.id)
                                .contentShape(Rectangle())
                                .onTapGesture { model.selectedID = item.id }
                                .simultaneousGesture(TapGesture(count: 2).onEnded { onChoose(item) })
                        }
                        .id(item.id)
                    }
                }
                .padding(6)
            }
            .overlay {
                if results.isEmpty { emptyState }
            }
            .onChange(of: selected?.id) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    private func groupHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: model.query.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 28))
            Text(model.query.isEmpty ? strings.nothingCopied : strings.noMatches(model.query))
        }
        .foregroundStyle(.secondary)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            KeyHint(keys: "↑ ↓", label: strings.hintSelect)
            KeyHint(keys: "↩", label: model.canAutoPaste ? strings.hintPaste : strings.hintCopy)
            KeyHint(keys: "⌘↩", label: strings.hintCopy)
            KeyHint(keys: "⇥", label: strings.hintCategory)
            KeyHint(keys: "⌘⌫", label: strings.hintDelete)
            KeyHint(keys: "esc", label: strings.hintClose)
            Spacer(minLength: 0)
            if !model.canAutoPaste {
                Button(strings.allowAutoPaste) { Paster.openAccessibilitySettings() }
                    .controlSize(.small)
                    .help(strings.allowAutoPasteHelp)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// The search field. It watches only the typed text, so a keystroke redraws just this bar.
private struct SearchBar: View {
    @ObservedObject var searchText: SearchText
    let focusRequest: Int
    let onClear: () -> Void
    let onSettings: () -> Void
    @FocusState private var isFocused: Bool
    @Environment(\.strings) private var strings

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
            TextField(strings.searchPlaceholder, text: $searchText.text)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($isFocused)
                .onAppear { isFocused = true }
            if !searchText.text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(strings.clearSearch)
                .accessibilityLabel(strings.clearSearch)
            }
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(strings.settingsHelp)
            .accessibilityLabel(strings.settings)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .onChange(of: focusRequest) {
            isFocused = true
        }
    }
}

private struct CategoryBar: View {
    @ObservedObject var model: PanelModel
    let counts: [ClipCategory: Int]
    let allCount: Int
    @Environment(\.strings) private var strings

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(PanelModel.categories.enumerated()), id: \.offset) { index, category in
                let isOn = model.category == category
                let count = category.map { counts[$0] ?? 0 } ?? allCount
                Button {
                    model.category = category
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: category?.symbolName ?? "square.grid.2x2")
                        Text(strings.categoryTitle(category))
                        Text("\(count)")
                            .monospacedDigit()
                            .opacity(0.7)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(isOn ? Color.accentColor : Color.primary.opacity(0.07)))
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("⌘\(index + 1)")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

private struct KeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
            Text(label)
        }
    }
}
