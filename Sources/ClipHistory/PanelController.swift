import AppKit
import ClipCore
import SwiftUI

/// A panel that takes the keyboard without activating the app, so the app you were in stays
/// frontmost and receives the paste.
final class HistoryPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 480),
            styleMask: [.nonactivatingPanel, .titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        minSize = NSSize(width: 720, height: 420)
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let store: HistoryStore
    private let pasteboardWatcher: PasteboardWatcher
    private let launchAtLogin: LaunchAtLogin
    private let openShortcut: OpenShortcut
    private let historyLimit: HistoryLimitSettings
    private let language: LanguageSettings
    private let model: PanelModel
    private lazy var panel = makePanel()
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(
        store: HistoryStore,
        pasteboardWatcher: PasteboardWatcher,
        launchAtLogin: LaunchAtLogin,
        openShortcut: OpenShortcut,
        historyLimit: HistoryLimitSettings,
        language: LanguageSettings
    ) {
        self.store = store
        self.pasteboardWatcher = pasteboardWatcher
        self.launchAtLogin = launchAtLogin
        self.openShortcut = openShortcut
        self.historyLimit = historyLimit
        self.language = language
        model = PanelModel(store: store)
        super.init()
    }

    func toggle() {
        panel.isVisible ? close() : show()
    }

    /// Opens the history, or with `settings` the settings inside it.
    func show(settings: Bool = false) {
        if panel.isVisible {
            settings ? model.showSettings() : model.showHistory()
            return
        }
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : frontmost
        store.removeExpired()
        model.prepareForShow(settings: settings)
        position()
        panel.makeKeyAndOrderFront(nil)
        model.requestFocus()
        installKeyMonitor()
    }

    func close() {
        openShortcut.cancelRecording()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    /// Puts the item on the clipboard and, with `paste`, pastes it into the app you were in.
    private func choose(_ item: ClipItem, paste: Bool) {
        guard Paster.write(item, store: store) else {
            NSSound.beep()
            return
        }
        pasteboardWatcher.ignoreCurrentContents()
        store.touch(item.id)
        close()
        guard paste else { return }
        guard Paster.hasAccessibility else {
            Paster.requestAccessibility()
            return
        }
        let target = previousApp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let target, !target.isActive { target.activate(options: []) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                Paster.sendPasteKeystroke()
            }
        }
    }

    private func makePanel() -> HistoryPanel {
        let panel = HistoryPanel()
        panel.delegate = self
        let view = HistoryView(
            model: model, store: store, launchAtLogin: launchAtLogin, openShortcut: openShortcut, historyLimit: historyLimit,
            language: language
        ) { [weak self] item in
            self?.choose(item, paste: true)
        }
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        hosting.frame = background.bounds
        hosting.autoresizingMask = [.width, .height]
        background.addSubview(hosting)
        panel.contentView = background
        return panel
    }

    /// Centers the panel in the upper part of the screen the pointer is on.
    private func position() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let top = visible.maxY - visible.height * 0.16
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: max(visible.minY, top - size.height)))
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    /// Keys the popup handles before the search field sees them. Returns true when consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if openShortcut.isRecording {
            if event.keyCode == 53, modifiers.isEmpty {
                openShortcut.cancelRecording()
            } else {
                openShortcut.record(event)
            }
            return true
        }
        if modifiers == .command, event.charactersIgnoringModifiers == "," {
            model.isShowingSettings ? model.showHistory() : model.showSettings()
            return true
        }
        if model.isShowingSettings {
            // esc goes back to the history; other keys work the settings controls.
            guard event.keyCode == 53 else { return false }
            model.showHistory()
            return true
        }
        // Typed letters go to the search field untouched; the keys below act on the results, so
        // the text typed so far is applied first.
        switch Int(event.keyCode) {
        case 125, 126, 121, 116, 36, 76, 48: model.commitSearch()
        case 51 where modifiers == .command: model.commitSearch()
        default: break
        }
        switch Int(event.keyCode) {
        case 125: model.move(by: modifiers.contains(.command) ? 100_000 : 1) // down
        case 126: model.move(by: modifiers.contains(.command) ? -100_000 : -1) // up
        case 121: model.move(by: 8) // page down
        case 116: model.move(by: -8) // page up
        case 36, 76: // return, enter
            guard let selected = model.selectedItem(in: model.results) else { NSSound.beep(); return true }
            choose(selected, paste: !modifiers.contains(.command))
        case 53: // escape: clear the search first, then close
            if model.searchText.text.isEmpty { close() } else { model.clearSearch() }
        case 48: model.cycleCategory(backwards: modifiers.contains(.shift)) // tab
        case 51 where modifiers == .command: model.deleteSelection() // ⌘⌫
        default:
            return handleCommandShortcut(event, modifiers: modifiers)
        }
        return true
    }

    /// ⌘1…⌘6 pick a category. The app has no menu bar, so the text-editing shortcuts are sent
    /// to the search field here.
    private func handleCommandShortcut(_ event: NSEvent, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard modifiers == .command || modifiers == [.command, .shift],
              let key = event.charactersIgnoringModifiers?.lowercased()
        else { return false }
        if modifiers == .command, let digit = Int(key), (1...PanelModel.categories.count).contains(digit) {
            model.selectCategory(at: digit - 1)
            return true
        }
        let action: Selector? = switch (key, modifiers == .command) {
        case ("a", true): #selector(NSText.selectAll(_:))
        case ("c", true): #selector(NSText.copy(_:))
        case ("v", true): #selector(NSText.paste(_:))
        case ("x", true): #selector(NSText.cut(_:))
        case ("z", true): Selector(("undo:"))
        case ("z", false): Selector(("redo:"))
        default: nil
        }
        guard let action else { return false }
        return NSApp.sendAction(action, to: nil, from: panel)
    }
}
