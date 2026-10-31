import Foundation

public enum ClipCategory: String, Codable, CaseIterable, Sendable {
    /// In the order of the category bar; screenshots come last, as they only show in their own
    /// tab while searching.
    case text, link, image, file, screenshot

    /// Name of one item ("Link").
    public var name: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        case .screenshot: "Screenshot"
        case .file: "File"
        }
    }

    /// Name of the filter that shows this category ("Links").
    public var title: String {
        switch self {
        case .text: "Text"
        case .link: "Links"
        case .image: "Images"
        case .screenshot: "Screenshots"
        case .file: "Files"
        }
    }

    public var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .screenshot: "camera.viewfinder"
        case .file: "doc"
        }
    }
}

public struct ClipItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var category: ClipCategory
    /// When the item was last copied.
    public var date: Date
    /// The copied text, or the address of a link.
    public var text: String?
    /// File name of a copied image, inside the store's image folder.
    public var imageName: String?
    /// Copied files, or the file of a screenshot.
    public var filePaths: [String]?
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    /// The app that was in front when the item was copied.
    public var sourceApp: String?
    /// Identifies the content: copying the same thing again moves the existing entry to the top.
    public var contentHash: String

    public init(
        id: UUID = UUID(),
        category: ClipCategory,
        date: Date = Date(),
        text: String? = nil,
        imageName: String? = nil,
        filePaths: [String]? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        sourceApp: String? = nil,
        contentHash: String
    ) {
        self.id = id
        self.category = category
        self.date = date
        self.text = text
        self.imageName = imageName
        self.filePaths = filePaths
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.sourceApp = sourceApp
        self.contentHash = contentHash
    }

    /// One-line label for the list.
    public var title: String {
        if let text, category == .text || category == .link {
            return text.prefix(600).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        if !fileNames.isEmpty { return fileNames.joined(separator: ", ") }
        return [category.name, pixelSizeDescription].compactMap { $0 }.joined(separator: " ")
    }

    public var fileNames: [String] {
        (filePaths ?? []).map { ($0 as NSString).lastPathComponent }
    }

    public var pixelSizeDescription: String? {
        guard let pixelWidth, let pixelHeight else { return nil }
        return "\(pixelWidth) × \(pixelHeight)"
    }

    /// Everything a search looks at. Very long texts are searched in their first 50 000 characters.
    public var searchableText: String {
        var parts: [String] = []
        if let text { parts.append(String(text.prefix(50_000))) }
        // A screenshot's folder is the same for all of them, so only its file name is searched.
        if category == .screenshot {
            parts.append(contentsOf: fileNames)
        } else if let filePaths {
            parts.append(contentsOf: filePaths)
        }
        if let sourceApp { parts.append(sourceApp) }
        return parts.joined(separator: "\n")
    }
}
