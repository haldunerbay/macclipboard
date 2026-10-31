import ClipCore
import ServiceManagement
import SwiftUI

/// The settings, shown inside the history popup (⚙ or ⌘,).
struct SettingsPane: View {
    @ObservedObject var language: LanguageSettings
    @ObservedObject var launchAtLogin: LaunchAtLogin
    @ObservedObject var openShortcut: OpenShortcut
    @Binding var searchMode: SearchMode
    @ObservedObject var historyLimit: HistoryLimitSettings
    @ObservedObject var store: HistoryStore
    @Environment(\.strings) private var strings

    var body: some View {
        Form {
            Section(strings.general) {
                Picker(strings.languageLabel, selection: $language.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                Toggle(strings.openAtLogin, isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if launchAtLogin.status == .requiresApproval {
                    HStack {
                        Text(strings.allowLoginItem)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(strings.openLoginItems) { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
                if let message = launchAtLogin.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Picker(strings.search, selection: $searchMode) {
                    Text(strings.fullText).tag(SearchMode.fullText)
                    Text(strings.fuzzy).tag(SearchMode.fuzzy)
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text(strings.search)
            } footer: {
                Text(searchMode == .fuzzy ? strings.fuzzyFooter : strings.fullTextFooter)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(strings.keep, selection: $historyLimit.kind) {
                    Text(strings.keepCount).tag(HistoryLimitSettings.Kind.count)
                    Text(strings.keepSize).tag(HistoryLimitSettings.Kind.size)
                    Text(strings.keepEverything).tag(HistoryLimitSettings.Kind.unlimited)
                }
                .pickerStyle(.radioGroup)
                switch historyLimit.kind {
                case .count:
                    LabeledContent(strings.items) {
                        HStack(spacing: 6) {
                            TextField(strings.items, value: $historyLimit.count, format: .number)
                                .labelsHidden()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Stepper(strings.items, value: $historyLimit.count, in: 1...1_000_000, step: 50)
                                .labelsHidden()
                        }
                    }
                case .size:
                    LabeledContent(strings.size) {
                        HStack(spacing: 6) {
                            TextField(strings.megabytes, value: $historyLimit.megabytes, format: .number.precision(.fractionLength(0...1)))
                                .labelsHidden()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Text("MB")
                            Stepper(strings.megabytes, value: $historyLimit.megabytes, in: 0.1...1_000_000, step: 0.5)
                                .labelsHidden()
                        }
                    }
                case .unlimited:
                    Label(strings.unlimitedWarning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Toggle(strings.expireToggle, isOn: $historyLimit.expires)
                if historyLimit.expires {
                    LabeledContent(strings.days) {
                        HStack(spacing: 6) {
                            TextField(strings.days, value: $historyLimit.days, format: .number)
                                .labelsHidden()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Stepper(strings.days, value: $historyLimit.days, in: 1...3_650)
                                .labelsHidden()
                        }
                    }
                }
            } header: {
                Text(strings.history)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(usage)
                    if store.isOverLimit {
                        Text(strings.overLimit)
                            .foregroundStyle(.orange)
                    } else if historyLimit.kind == .unlimited, store.items.count >= 2_000 {
                        Text(strings.manyItems)
                            .foregroundStyle(.orange)
                    }
                    if historyLimit.expires {
                        let expired = store.expiredCount()
                        Text(expired == 0 ? strings.expiryInfo(days: historyLimit.days) : strings.expiredPending(expired))
                            .foregroundStyle(expired == 0 ? Color.secondary : Color.orange)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent(strings.openHistoryShortcut) {
                    HStack(spacing: 8) {
                        Button {
                            if openShortcut.isRecording {
                                openShortcut.cancelRecording()
                            } else {
                                openShortcut.startRecording()
                            }
                        } label: {
                            Text(openShortcut.isRecording ? strings.typeNewShortcut : openShortcut.shortcut.description)
                                .frame(minWidth: 150)
                        }
                        .help(openShortcut.isRecording ? strings.escCancels : strings.clickThenPress)
                        Button(strings.reset) { openShortcut.reset() }
                            .disabled(openShortcut.shortcut == .standard && !openShortcut.isRecording)
                            .help(strings.backTo(Shortcut.standard.description))
                    }
                }
                if let error = openShortcut.error {
                    Text(strings.shortcutError(error))
                        .foregroundStyle(.red)
                }
            } header: {
                Text(strings.shortcut)
            } footer: {
                Text(openShortcut.isRecording ? strings.recordingFooter : strings.shortcutFooter)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear { launchAtLogin.refresh() }
    }

    private var usage: String {
        strings.usage(items: store.items.count, size: ByteCountFormatter.string(fromByteCount: Int64(store.totalBytes), countStyle: .file))
    }
}
