import AppKit
import ApplicationServices
import Carbon.HIToolbox
import ClipCore

@MainActor
enum Paster {
    /// Writes an item back to the general pasteboard.
    static func write(_ item: ClipItem, store: HistoryStore) -> Bool {
        let pasteboard = NSPasteboard.general
        switch item.category {
        case .text, .link:
            guard let text = item.text else { return false }
            pasteboard.clearContents()
            return pasteboard.setString(text, forType: .string)
        case .image:
            return writeStoredImage(of: item, store: store)
        case .screenshot where item.filePaths == nil: // taken to the clipboard (⌃⇧⌘4), so there is no file
            return writeStoredImage(of: item, store: store)
        case .screenshot, .file:
            let urls = (item.filePaths ?? []).map(URL.init(fileURLWithPath:)).filter { FileManager.default.fileExists(atPath: $0.path) }
            guard !urls.isEmpty else { return false }
            pasteboard.clearContents()
            if item.category == .screenshot, let url = urls.first, let png = pngData(of: url) {
                // The file for Finder, Slack, Mail…; the image for editors and chat apps.
                let entry = NSPasteboardItem()
                entry.setString(url.absoluteString, forType: .fileURL)
                entry.setData(png, forType: .png)
                return pasteboard.writeObjects([entry])
            }
            return pasteboard.writeObjects(urls as [NSURL])
        }
    }

    private static func writeStoredImage(of item: ClipItem, store: HistoryStore) -> Bool {
        guard let url = store.imageURL(for: item), let png = try? Data(contentsOf: url) else { return false }
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setData(png, forType: .png)
    }

    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that leads to Privacy & Security › Accessibility.
    static func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Presses ⌘V in the frontmost app. Needs the Accessibility permission.
    static func sendPasteKeystroke() {
        let keyCode = KeyboardLayout.keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }

    private static func pngData(of url: URL) -> Data? {
        if url.pathExtension.lowercased() == "png" { return try? Data(contentsOf: url) }
        guard let data = try? Data(contentsOf: url), let rep = NSBitmapImageRep(data: data) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

enum KeyboardLayout {
    /// The key that types `character` in the current keyboard layout (the ASCII-capable one,
    /// which macOS uses for ⌘ shortcuts). On Turkish F, V is not where it is on Q.
    static func keyCode(for character: Character) -> CGKeyCode? {
        let target = String(character).lowercased()
        let code = withCurrentLayout { layout in
            (0..<128).first { translate(UInt16($0), in: layout) == target }
        }
        return (code ?? nil).map(CGKeyCode.init)
    }

    /// What the key types without modifiers in the current layout, such as "v".
    static func character(for keyCode: UInt16) -> String? {
        withCurrentLayout { translate(keyCode, in: $0) } ?? nil
    }

    private static func withCurrentLayout<T>(_ body: (UnsafePointer<UCKeyboardLayout>) -> T) -> T? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { raw in
            raw.baseAddress.map { body($0.assumingMemoryBound(to: UCKeyboardLayout.self)) }
        }
    }

    private static func translate(_ keyCode: UInt16, in layout: UnsafePointer<UCKeyboardLayout>) -> String? {
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = UCKeyTranslate(
            layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, characters.count, &length, &characters
        )
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length).lowercased()
    }
}
