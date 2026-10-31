import AppKit
import ClipCore

@main
enum ClipHistoryApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = HistoryStore(directory: HistoryStore.defaultDirectory)
    private lazy var pasteboardWatcher = PasteboardWatcher(store: store)
    private lazy var screenshotWatcher = ScreenshotWatcher(store: store)
    private let launchAtLogin = LaunchAtLogin()
    private let language = LanguageSettings()
    private lazy var historyLimit = HistoryLimitSettings(store: store)
    private lazy var openShortcut: OpenShortcut = OpenShortcut { [weak self] in self?.panelController.toggle() }
    private lazy var panelController: PanelController = PanelController(
        store: store, pasteboardWatcher: pasteboardWatcher, launchAtLogin: launchAtLogin, openShortcut: openShortcut,
        historyLimit: historyLimit, language: language
    )
    private var statusItem: NSStatusItem?
    private var expiryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.limit = historyLimit.limit // the saved limit and expiry, before anything is recorded
        store.maxAge = historyLimit.maxAge
        store.removeExpired()
        startExpiryTimer()
        pasteboardWatcher.start()
        screenshotWatcher.start()
        openShortcut.start()
        setUpStatusItem()
        launchAtLogin.enableOnFirstLaunch()

        let defaults = UserDefaults.standard
        if !Paster.hasAccessibility, !defaults.bool(forKey: "askedForAccessibility") {
            defaults.set(true, forKey: "askedForAccessibility")
            Paster.requestAccessibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
        screenshotWatcher.recordRun()
    }

    /// `open cliphistory://show` opens the popup (handy for Shortcuts or Raycast),
    /// `cliphistory://settings` the settings.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: { $0.scheme == "cliphistory" }) else { return }
        panelController.show(settings: url.host == "settings")
    }

    /// Expired items also go while nothing is copied.
    private func startExpiryTimer() {
        let timer = Timer(timeInterval: 600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.store.removeExpired() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clip History")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let strings = language.strings
        let shortcut = openShortcut.shortcut
        let show = addItem(to: menu, strings.showHistory, #selector(showHistory), key: shortcut.menuKeyEquivalent)
        show.keyEquivalentModifierMask = shortcut.menuModifiers
        menu.addItem(.separator())
        addItem(to: menu, strings.pauseRecording, #selector(togglePause)).state = pasteboardWatcher.isPaused ? .on : .off
        addItem(to: menu, strings.settingsMenu, #selector(showSettings), key: ",")
        if !Paster.hasAccessibility {
            addItem(to: menu, strings.allowAutoPasteMenu, #selector(allowAutoPaste))
        }
        menu.addItem(.separator())
        addItem(to: menu, strings.clearHistoryMenu, #selector(clearHistory))
        menu.addItem(.separator())
        addItem(to: menu, strings.quit, #selector(quit), key: "q")
    }

    @discardableResult
    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func showHistory() {
        panelController.show()
    }

    @objc private func togglePause() {
        pasteboardWatcher.isPaused.toggle()
        statusItem?.button?.appearsDisabled = pasteboardWatcher.isPaused
    }

    @objc private func showSettings() {
        panelController.show(settings: true)
    }

    @objc private func allowAutoPaste() {
        Paster.requestAccessibility()
        Paster.openAccessibilitySettings()
    }

    @objc private func clearHistory() {
        NSApp.activate()
        let alert = NSAlert()
        let strings = language.strings
        alert.messageText = strings.clearHistoryQuestion
        alert.informativeText = strings.clearHistoryDetails(store.items.count)
        alert.addButton(withTitle: strings.clearHistory)
        alert.addButton(withTitle: strings.cancel)
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            store.removeAll()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
