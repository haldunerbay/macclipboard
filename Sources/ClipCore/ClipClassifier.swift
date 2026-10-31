import CryptoKit
import Foundation

public enum ClipClassifier {
    private static let schemesWithHost: Set<String> = ["http", "https", "ftp", "ftps", "sftp", "ssh", "ws", "wss"]
    private static let schemesWithoutHost: Set<String> = ["mailto", "tel", "sms", "facetime"]

    /// The link a copied text consists of, or nil when the text is more (or other) than one link.
    public static func link(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 4096, !trimmed.contains(where: \.isWhitespace) else { return nil }
        if trimmed.lowercased().hasPrefix("www.") {
            guard let url = URL(string: "https://" + trimmed), let host = url.host, host.split(separator: ".").count >= 3 else { return nil }
            return url
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return nil }
        if schemesWithHost.contains(scheme) {
            return url.host?.isEmpty == false ? url : nil
        }
        if schemesWithoutHost.contains(scheme) {
            return trimmed.count > scheme.count + 1 ? url : nil
        }
        return nil
    }

    /// Whether a copied text shows anything. Rich text views put U+FFFC (object replacement)
    /// in the plain text for an attachment, which on its own shows nothing.
    public static func hasVisibleText(_ text: String) -> Bool {
        text.unicodeScalars.contains { !$0.properties.isWhitespace && $0 != "\u{FFFC}" }
    }

    public static func contentHash(text: String) -> String {
        "t:" + sha256(Data(text.utf8))
    }

    public static func contentHash(imageData: Data) -> String {
        "i:" + sha256(imageData)
    }

    public static func contentHash(filePaths: [String]) -> String {
        "f:" + sha256(Data(filePaths.joined(separator: "\n").utf8))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public enum ScreenshotFile {
    /// macOS marks every screenshot file it saves with this extended attribute.
    public static let attribute = "com.apple.metadata:kMDItemIsScreenCapture"

    public static func isScreenshot(atPath path: String) -> Bool {
        getxattr(path, attribute, nil, 0, 0, 0) >= 0
    }
}
