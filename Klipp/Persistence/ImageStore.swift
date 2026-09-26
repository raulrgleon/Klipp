import AppKit
import Foundation

final class ImageStore {
    let imagesDirectory: URL
    private let cache = NSCache<NSString, NSImage>()

    init(baseDirectory: URL? = nil) {
        let root = baseDirectory ?? HistoryRepository.defaultDirectory
        imagesDirectory = root.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        cache.countLimit = 80
    }

    func url(for filename: String) -> URL {
        imagesDirectory.appendingPathComponent(filename)
    }

    func savePNG(_ data: Data, filename: String) throws {
        try data.write(to: url(for: filename), options: .atomic)
    }

    func loadImage(filename: String) -> NSImage? {
        let key = filename as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(contentsOf: url(for: filename)) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func delete(filename: String?) {
        guard let filename, !filename.isEmpty else { return }
        cache.removeObject(forKey: filename as NSString)
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    func exists(filename: String?) -> Bool {
        guard let filename else { return false }
        return FileManager.default.fileExists(atPath: url(for: filename).path)
    }
}
