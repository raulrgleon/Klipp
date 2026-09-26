import Foundation

struct HistoryFile: Codable {
    var version: Int
    var items: [ClipboardItem]
}

final class HistoryRepository {
    static var defaultDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent("Klipp", isDirectory: true)
    }

    let directory: URL
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL = HistoryRepository.defaultDirectory) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

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

    func save(_ items: [ClipboardItem]) {
        let file = HistoryFile(version: 1, items: items)
        do {
            let data = try encoder.encode(file)
            let temp = fileURL.appendingPathExtension("tmp")
            try data.write(to: temp, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temp)
        } catch {
            NSLog("Klipp: no se pudo guardar history.json (%@)", error.localizedDescription)
        }
    }
}
