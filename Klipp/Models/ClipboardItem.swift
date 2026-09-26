import Foundation

enum ClipboardItemKind: String, Codable, Hashable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date
    var lastCopiedAt: Date
    var kind: ClipboardItemKind
    var text: String?
    var imageFilename: String?
    var thumbnailFilename: String?
    var isPinned: Bool
    var contentHash: String
    var preview: String
    var byteSize: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        lastCopiedAt: Date = Date(),
        kind: ClipboardItemKind,
        text: String? = nil,
        imageFilename: String? = nil,
        thumbnailFilename: String? = nil,
        isPinned: Bool = false,
        contentHash: String,
        preview: String,
        byteSize: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastCopiedAt = lastCopiedAt
        self.kind = kind
        self.text = text
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
        self.isPinned = isPinned
        self.contentHash = contentHash
        self.preview = preview
        self.byteSize = byteSize
    }

    var searchableText: String {
        switch kind {
        case .text:
            return text ?? preview
        case .image:
            return preview
        }
    }
}
