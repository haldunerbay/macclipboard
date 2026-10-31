import AppKit
import ImageIO
import SwiftUI

/// Downscaled images for the list and the preview, decoded off the main thread and cached.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()

    func cached(_ url: URL, maxPixel: Int) -> NSImage? {
        cache.object(forKey: key(url, maxPixel))
    }

    func load(_ url: URL, maxPixel: Int) async -> NSImage? {
        if let image = cached(url, maxPixel: maxPixel) { return image }
        let cgImage = await Task.detached(priority: .userInitiated) {
            Self.makeThumbnail(url, maxPixel: maxPixel)
        }.value
        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: key(url, maxPixel))
        return image
    }

    private func key(_ url: URL, _ maxPixel: Int) -> NSString {
        "\(maxPixel)|\(url.path)" as NSString
    }

    private static func makeThumbnail(_ url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

struct ThumbnailView: View {
    let url: URL
    let maxPixel: Int
    var fill = false
    /// Width / height of the image, so the space it needs is kept while it loads.
    var placeholderAspectRatio: CGFloat?
    @State private var image: NSImage?

    init(url: URL, maxPixel: Int, fill: Bool = false, placeholderAspectRatio: CGFloat? = nil) {
        self.url = url
        self.maxPixel = maxPixel
        self.fill = fill
        self.placeholderAspectRatio = placeholderAspectRatio
        _image = State(initialValue: ThumbnailCache.shared.cached(url, maxPixel: maxPixel))
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fill ? .fill : .fit)
            } else {
                Color.primary.opacity(0.06)
                    .aspectRatio(placeholderAspectRatio, contentMode: .fit)
            }
        }
        .task(id: url) {
            image = await ThumbnailCache.shared.load(url, maxPixel: maxPixel)
        }
    }
}
