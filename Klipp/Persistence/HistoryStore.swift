import Foundation
import SQLite3

final class HistoryStore {
    let directory: URL
    private var db: OpaquePointer?

    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(directory: URL = AppPaths.supportDirectory) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("history.sqlite")
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &db, flags, nil) != SQLITE_OK {
            NSLog("Klipp: no se pudo abrir history.sqlite (%s)", sqlite3_errmsg(db))
            sqlite3_close(db)
            db = nil
            return
        }
        exec("PRAGMA foreign_keys = ON;")
        exec("PRAGMA journal_mode = WAL;")
        migrateSchema()
        importLegacyJSONIfNeeded()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func loadItems() -> [ClipboardItem] {
        guard let db else { return [] }
        let sql = """
        SELECT id, created_at, last_copied_at, kind, preview, content_hash, byte_size,
               is_pinned, text, image_filename, thumbnail_filename
        FROM items
        ORDER BY last_copied_at DESC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            NSLog("Klipp sqlite load: %s", sqlite3_errmsg(db))
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var items: [ClipboardItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let item = item(from: stmt) {
                items.append(item)
            }
        }
        return items
    }

    func representations(for id: UUID) -> [ClipboardRepresentation] {
        guard let db else { return [] }
        let sql = "SELECT type, data, filename FROM representations WHERE item_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)

        var result: [ClipboardRepresentation] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let typePtr = sqlite3_column_text(stmt, 0) else { continue }
            let type = String(cString: typePtr)
            var data: Data?
            if let bytes = sqlite3_column_blob(stmt, 1) {
                let count = Int(sqlite3_column_bytes(stmt, 1))
                data = Data(bytes: bytes, count: count)
            }
            let filename = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            result.append(ClipboardRepresentation(type: type, data: data, filename: filename))
        }
        return result
    }

    func upsert(_ item: ClipboardItem, representations: [ClipboardRepresentation]) {
        guard db != nil else { return }
        exec("BEGIN IMMEDIATE;")
        let sql = """
        INSERT OR REPLACE INTO items
            (id, created_at, last_copied_at, kind, preview, content_hash, byte_size,
             is_pinned, text, image_filename, thumbnail_filename)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        guard let stmt = prepare(sql) else {
            exec("ROLLBACK;")
            return
        }
        defer { sqlite3_finalize(stmt) }
        bindItem(stmt, item)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            NSLog("Klipp sqlite upsert: %s", sqlite3_errmsg(db))
            exec("ROLLBACK;")
            return
        }

        deleteRepresentations(itemID: item.id.uuidString)
        for representation in representations {
            insertRepresentation(itemID: item.id.uuidString, representation)
        }
        exec("COMMIT;")
    }

    func touch(id: UUID, lastCopiedAt: Date) {
        guard let stmt = prepare("UPDATE items SET last_copied_at = ? WHERE id = ?;") else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, lastCopiedAt.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
    }

    func setPinned(id: UUID, isPinned: Bool) {
        guard let stmt = prepare("UPDATE items SET is_pinned = ? WHERE id = ?;") else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, isPinned ? 1 : 0)
        sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
    }

    func delete(id: UUID) -> [String] {
        let files = filenames(for: id)
        guard let stmt = prepare("DELETE FROM items WHERE id = ?;") else { return files }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
        return files
    }

    func delete(ids: [UUID]) -> [String] {
        var files: [String] = []
        exec("BEGIN IMMEDIATE;")
        for id in ids {
            files.append(contentsOf: delete(id: id))
        }
        exec("COMMIT;")
        return files
    }

    func clearAll() -> [String] {
        let files = allFilenames()
        exec("DELETE FROM representations;")
        exec("DELETE FROM items;")
        return files
    }

    private func migrateSchema() {
        exec("""
        CREATE TABLE IF NOT EXISTS items (
            id TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            last_copied_at REAL NOT NULL,
            kind TEXT NOT NULL,
            preview TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            byte_size INTEGER NOT NULL,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            text TEXT,
            image_filename TEXT,
            thumbnail_filename TEXT
        );
        """)
        exec("""
        CREATE TABLE IF NOT EXISTS representations (
            item_id TEXT NOT NULL,
            type TEXT NOT NULL,
            data BLOB,
            filename TEXT,
            PRIMARY KEY (item_id, type),
            FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
        );
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_items_hash ON items(content_hash);")
        exec("CREATE INDEX IF NOT EXISTS idx_items_copied ON items(last_copied_at);")
    }

    private func importLegacyJSONIfNeeded() {
        let json = directory.appendingPathComponent("history.json")
        let migrated = directory.appendingPathComponent("history.json.migrated")
        guard FileManager.default.fileExists(atPath: json.path) else { return }

        if !loadItems().isEmpty {
            try? FileManager.default.moveItem(at: json, to: migrated)
            return
        }

        let legacy = HistoryRepository(directory: directory).load()
        for item in legacy {
            var representations: [ClipboardRepresentation] = []
            if let text = item.text, let data = text.data(using: .utf8) {
                representations.append(ClipboardRepresentation(
                    type: "public.utf8-plain-text",
                    data: data,
                    filename: nil
                ))
            }
            if let filename = item.imageFilename {
                representations.append(ClipboardRepresentation(
                    type: "public.png",
                    data: nil,
                    filename: filename
                ))
            }
            upsert(item, representations: representations)
        }
        try? FileManager.default.moveItem(at: json, to: migrated)
        NSLog("Klipp: historial JSON migrado a SQLite (%d recortes)", legacy.count)
    }

    private func item(from stmt: OpaquePointer) -> ClipboardItem? {
        guard let idPtr = sqlite3_column_text(stmt, 0),
              let id = UUID(uuidString: String(cString: idPtr)),
              let kindPtr = sqlite3_column_text(stmt, 3),
              let previewPtr = sqlite3_column_text(stmt, 4),
              let hashPtr = sqlite3_column_text(stmt, 5)
        else { return nil }

        let kind = ClipboardItemKind(rawValue: String(cString: kindPtr)) ?? .text
        return ClipboardItem(
            id: id,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
            lastCopiedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
            kind: kind,
            text: sqlite3_column_text(stmt, 8).map { String(cString: $0) },
            imageFilename: sqlite3_column_text(stmt, 9).map { String(cString: $0) },
            thumbnailFilename: sqlite3_column_text(stmt, 10).map { String(cString: $0) },
            isPinned: sqlite3_column_int(stmt, 7) != 0,
            contentHash: String(cString: hashPtr),
            preview: String(cString: previewPtr),
            byteSize: Int(sqlite3_column_int64(stmt, 6))
        )
    }

    private func bindItem(_ stmt: OpaquePointer, _ item: ClipboardItem) {
        sqlite3_bind_text(stmt, 1, item.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, item.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 3, item.lastCopiedAt.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 4, item.kind.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, item.preview, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, item.contentHash, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 7, Int64(item.byteSize))
        sqlite3_bind_int(stmt, 8, item.isPinned ? 1 : 0)
        if let text = item.text {
            sqlite3_bind_text(stmt, 9, text, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        if let filename = item.imageFilename {
            sqlite3_bind_text(stmt, 10, filename, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 10)
        }
        if let filename = item.thumbnailFilename {
            sqlite3_bind_text(stmt, 11, filename, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 11)
        }
    }

    private func insertRepresentation(itemID: String, _ representation: ClipboardRepresentation) {
        guard let stmt = prepare("INSERT OR REPLACE INTO representations (item_id, type, data, filename) VALUES (?, ?, ?, ?);") else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, itemID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, representation.type, -1, SQLITE_TRANSIENT)
        if let data = representation.data, representation.filename == nil {
            _ = data.withUnsafeBytes { raw in
                sqlite3_bind_blob(stmt, 3, raw.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        if let filename = representation.filename {
            sqlite3_bind_text(stmt, 4, filename, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        _ = sqlite3_step(stmt)
    }

    private func deleteRepresentations(itemID: String) {
        guard let stmt = prepare("DELETE FROM representations WHERE item_id = ?;") else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, itemID, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
    }

    private func filenames(for id: UUID) -> [String] {
        guard let db else { return [] }
        var names: [String] = []
        let sql = """
        SELECT image_filename, thumbnail_filename FROM items WHERE id = ?
        UNION
        SELECT filename, NULL FROM representations WHERE item_id = ? AND filename IS NOT NULL;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let a = sqlite3_column_text(stmt, 0) { names.append(String(cString: a)) }
            if let b = sqlite3_column_text(stmt, 1) { names.append(String(cString: b)) }
        }
        return names
    }

    private func allFilenames() -> [String] {
        guard let db else { return [] }
        var names: [String] = []
        let sql = """
        SELECT image_filename FROM items WHERE image_filename IS NOT NULL
        UNION
        SELECT thumbnail_filename FROM items WHERE thumbnail_filename IS NOT NULL
        UNION
        SELECT filename FROM representations WHERE filename IS NOT NULL;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let name = sqlite3_column_text(stmt, 0) {
                names.append(String(cString: name))
            }
        }
        return names
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        guard let db else { return nil }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            NSLog("Klipp sqlite prepare: %s", sqlite3_errmsg(db))
            return nil
        }
        return stmt
    }

    private func exec(_ sql: String) {
        guard let db else { return }
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            NSLog("Klipp sqlite: %s", sqlite3_errmsg(db))
        }
    }
}
