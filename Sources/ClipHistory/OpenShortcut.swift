import AppKit
import Carbon.HIToolbox
import ClipCore

/// Why a recorded shortcut was not taken; the settings word it in the chosen language.
enum ShortcutError: Equatable {
    case needsModifier(String)
    case taken(String)
}

/// The system-wide shortcut that opens the history: registered, recorded in the settings and saved.
@MainActor
final class OpenShortcut: ObservableObject {
    @Published private(set) var shortcut: Shortcut
    @Published private(set) var isRecording = false
    @Published private(set) var error: ShortcutError?

    private let action: () -> Void
    private var hotKey: HotKey?
    private let defaults = UserDefaults.standard
    private static let storageKey = "openShortcut"

    init(action: @escaping () -> Void) {
        self.action = action
        let saved = defaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
        shortcut = saved ?? .standard
    }

    func start() {
        if !register(shortcut) {
            NSLog("ClipHistory: \(shortcut.description) is taken by another app")
        }
    }

    /// While recording, the current shortcut is switched off so pressing it reaches the recorder.
    func startRecording() {
        hotKey = nil
        error = nil
        isRecording = true
    }

    func cancelRecording() {
        guard isRecording else { return }
        isRecording = false
        error = nil
        register(shortcut)
    }

    func record(_ event: NSEvent) {
        guard isRecording else { return }
        let flags = event.modifierFlags
        let candidate = Shortcut(
            keyCode: event.keyCode,
            keyLabel: Shortcut.specialKeyLabel(for: event.keyCode)
                ?? KeyboardLayout.character(for: event.keyCode)?.uppercased(with: .current)
                ?? "#\(event.keyCode)",
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            option: flags.contains(.option),
            control: flags.contains(.control)
        )
        guard candidate.isValid else {
            error = .needsModifier(candidate.description)
            return
        }
        apply(candidate)
    }

    func reset() {
        isRecording = false
        apply(.standard)
    }

    private func apply(_ candidate: Shortcut) {
        isRecording = false
        if register(candidate) {
            shortcut = candidate
            error = nil
            if candidate == .standard {
                defaults.removeObject(forKey: Self.storageKey)
            } else if let data = try? JSONEncoder().encode(candidate) {
                defaults.set(data, forKey: Self.storageKey)
            }
        } else {
            error = .taken(candidate.description)
            register(shortcut)
        }
    }

    @discardableResult
    private func register(_ shortcut: Shortcut) -> Bool {
        hotKey = nil
        hotKey = HotKey(keyCode: UInt32(shortcut.keyCode), modifiers: shortcut.carbonModifiers) { [weak self] in
            MainActor.assumeIsolated { self?.action() }
        }
        return hotKey != nil
    }
}

extension Shortcut {
    /// ⇧⌘V, on whichever key types V in the current layout.
    static var standard: Shortcut {
        Shortcut(keyCode: KeyboardLayout.keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V), keyLabel: "V", command: true, shift: true)
    }

    var carbonModifiers: UInt32 {
        var modifiers = 0
        if command { modifiers |= cmdKey }
        if shift { modifiers |= shiftKey }
        if option { modifiers |= optionKey }
        if control { modifiers |= controlKey }
        return UInt32(modifiers)
    }

    var menuModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if command { flags.insert(.command) }
        if shift { flags.insert(.shift) }
        if option { flags.insert(.option) }
        if control { flags.insert(.control) }
        return flags
    }

    /// The key as a menu key equivalent; empty for keys a menu cannot show this way.
    var menuKeyEquivalent: String {
        Shortcut.specialKeyLabel(for: keyCode) == nil && keyLabel.count == 1 ? keyLabel.lowercased() : ""
    }
}
