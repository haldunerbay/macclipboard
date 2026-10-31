import Foundation

/// A key combination for a system-wide shortcut.
public struct Shortcut: Codable, Equatable, Sendable {
    /// Virtual key code: the physical key, whatever the keyboard layout.
    public var keyCode: UInt16
    /// What the key shows, such as "V" or "Space".
    public var keyLabel: String
    public var command: Bool
    public var shift: Bool
    public var option: Bool
    public var control: Bool

    public init(keyCode: UInt16, keyLabel: String, command: Bool = false, shift: Bool = false, option: Bool = false, control: Bool = false) {
        self.keyCode = keyCode
        self.keyLabel = keyLabel
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    /// In the order macOS menus show it: ⌃⌥⇧⌘, then the key.
    public var description: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + keyLabel
    }

    /// A system-wide shortcut needs ⌘, ⌥ or ⌃, or it would swallow normal typing.
    /// Function keys may stand alone.
    public var isValid: Bool {
        command || option || control || Self.functionKeyLabels[keyCode] != nil
    }

    /// Labels for keys that type no visible character.
    public static func specialKeyLabel(for keyCode: UInt16) -> String? {
        functionKeyLabels[keyCode] ?? otherKeyLabels[keyCode]
    }

    private static let functionKeyLabels: [UInt16: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
        109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17",
        79: "F18", 80: "F19", 90: "F20",
    ]

    private static let otherKeyLabels: [UInt16: String] = [
        36: "↩", 76: "⌅", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
    ]
}
