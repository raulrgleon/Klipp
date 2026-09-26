import AppKit
import Combine
import Foundation

final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published var searchQuery: String = "" {
        didSet { refreshSelectionIfNeeded() }
    }
    @Published var selectedID: ClipboardItem.ID?

    let imageStore: ImageStore
    private let repository: HistoryRepository
    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    var visibleItems: [ClipboardItem] {
        FuzzySearch.filter(items, query: searchQuery)
    }

    var selectedItem: ClipboardItem? {
        visibleItems.first(where: { $0.id == selectedID }) ?? visibleItems.first
    }

    init(repository: HistoryRepository, settings: AppSettings, imageStore: ImageStore) {
        self.repository = repository
        self.settings = settings
        self.imageStore = imageStore
        items = Self.sanitize(repository.load(), imageStore: imageStore)
        selectedID = visibleItems.first?.id

        settings.$maxItems
            .dropFirst()
            .sink { [weak self] _ in
                self?.evictIfNeeded()
                self?.persist()
            }
            .store(in: &cancellables)
    }

    func ingest(_ captured: CapturedContent) {
        let hash = captured.contentHash
        if let index = items.firstIndex(where: { $0.contentHash == hash }) {
            var existing = items.remove(at: index)
            existing.lastCopiedAt = Date()
            items.insert(existing, at: 0)
            persist()
            return
        }

        switch captured {
        case .text(let text):
            let item = ClipboardItem(
                kind: .text,
                text: text,
                contentHash: hash,
                preview: captured.preview,
                byteSize: captured.byteSize
            )
            items.insert(item, at: 0)
        case .image(let image, let pngData):
            let id = UUID()
            let filename = "\(id.uuidString).png"
            let thumbName = "\(id.uuidString)-thumb.png"
            do {
                try imageStore.savePNG(pngData, filename: filename)
                if let thumb = PasteboardCapture.thumbnailPNG(from: image) {
                    try imageStore.savePNG(thumb, filename: thumbName)
                }
            } catch {
                NSLog("Klipp: no se pudo guardar imagen (%@)", error.localizedDescription)
                return
            }
            let item = ClipboardItem(
                id: id,
                kind: .image,
                imageFilename: filename,
                thumbnailFilename: imageStore.exists(filename: thumbName) ? thumbName : filename,
                contentHash: hash,
                preview: "Imagen",
                byteSize: captured.byteSize
            )
            items.insert(item, at: 0)
        }

        evictIfNeeded()
        persist()
    }

    func togglePin(_ id: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        persist()
    }

    func delete(_ id: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: index)
        imageStore.delete(filename: item.imageFilename)
        imageStore.delete(filename: item.thumbnailFilename)
        if selectedID == id {
            selectedID = visibleItems.first?.id
        }
        persist()
    }

    func clearUnpinned() {
        let removed = items.filter { !$0.isPinned }
        items.removeAll { !$0.isPinned }
        for item in removed {
            imageStore.delete(filename: item.imageFilename)
            imageStore.delete(filename: item.thumbnailFilename)
        }
        selectedID = visibleItems.first?.id
        persist()
    }

    func clearAll() {
        for item in items {
            imageStore.delete(filename: item.imageFilename)
            imageStore.delete(filename: item.thumbnailFilename)
        }
        items = []
        selectedID = nil
        persist()
    }

    func resetForPanel() {
        searchQuery = ""
        selectedID = visibleItems.first?.id
    }

    func selectNext() {
        moveSelection(by: 1)
    }

    func selectPrevious() {
        moveSelection(by: -1)
    }

    func thumbnail(for item: ClipboardItem) -> NSImage? {
        guard item.kind == .image else { return nil }
        if let thumb = item.thumbnailFilename, let image = imageStore.loadImage(filename: thumb) {
            return image
        }
        if let filename = item.imageFilename {
            return imageStore.loadImage(filename: filename)
        }
        return nil
    }

    func fullImage(for item: ClipboardItem) -> NSImage? {
        guard let filename = item.imageFilename else { return thumbnail(for: item) }
        return imageStore.loadImage(filename: filename)
    }

    private func moveSelection(by offset: Int) {
        let visible = visibleItems
        guard !visible.isEmpty else {
            selectedID = nil
            return
        }
        let current = visible.firstIndex(where: { $0.id == selectedID }) ?? 0
        let next = min(visible.count - 1, max(0, current + offset))
        selectedID = visible[next].id
    }

    private func refreshSelectionIfNeeded() {
        let visible = visibleItems
        if let selectedID, visible.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = visible.first?.id
    }

    private func evictIfNeeded() {
        let limit = settings.maxItems
        let victims = items
            .filter { !$0.isPinned }
            .sorted { $0.lastCopiedAt < $1.lastCopiedAt }
        let overflow = victims.count - limit
        guard overflow > 0 else { return }
        for item in victims.prefix(overflow) {
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { continue }
            let removed = items.remove(at: index)
            imageStore.delete(filename: removed.imageFilename)
            imageStore.delete(filename: removed.thumbnailFilename)
        }
    }

    private func persist() {
        repository.save(items)
    }

    private static func sanitize(_ items: [ClipboardItem], imageStore: ImageStore) -> [ClipboardItem] {
        items.filter { item in
            switch item.kind {
            case .text:
                return item.text?.isEmpty == false
            case .image:
                return imageStore.exists(filename: item.imageFilename)
            }
        }
    }
}
