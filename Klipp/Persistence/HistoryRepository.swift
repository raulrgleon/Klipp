import Foundation

struct HistoryFile: Codable {
    var version: Int
    var items: [ClipboardItem]
}

/// Lector del historial JSON viejo. Klipp guarda en SQLite; esto solo sirve para migrar.
final class HistoryRepository {
    let directory: URL
    private let fileURL: URL
    private let decoder: JSONDecoder

    init(directory: URL = AppPaths.supportDirectory) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("history.json")
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let file = try decoder.decode(HistoryFile.self, from: data)
            return file.items
        } catch {
            NSLog("Klipp: no se pudo leer history.json (%@)", error.localizedDescription)
            return []
        }
    }
}
