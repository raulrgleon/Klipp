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
    private let historyStore: HistoryStore
    private let settings: AppSettings
    private var stored: [ClipboardItem] = []
    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "app.klipp.store", qos: .utility)
    private let queueKey = DispatchSpecificKey<UInt8>()

    var visibleItems: [ClipboardItem] {
        FuzzySearch.filter(items, query: searchQuery)
    }

    var selectedItem: ClipboardItem? {
        visibleItems.first(where: { $0.id == selectedID }) ?? visibleItems.first
    }

    init(historyStore: HistoryStore, settings: AppSettings, imageStore: ImageStore) {
        self.historyStore = historyStore
        self.settings = settings
        self.imageStore = imageStore
        queue.setSpecific(key: queueKey, value: 1)

        stored = historyStore.loadItems().filter { Self.isValid($0, imageStore: imageStore) }
        items = stored
        selectedID = visibleItems.first?.id

        settings.$maxItems
            .dropFirst()
            .sink { [weak self] _ in
                self?.queue.async {
                    self?.evictIfNeeded()
                    self?.publish()
                }
            }
            .store(in: &cancellables)
    }

    func ingest(_ snapshot: PasteboardSnapshot) {
        queue.async { [weak self] in
            self?.ingestOnQueue(snapshot)
        }
    }

    func representations(for item: ClipboardItem) -> [ClipboardRepresentation] {
        onStoreQueue {
            self.historyStore.representations(for: item.id)
        }
    }

    func data(for representation: ClipboardRepresentation) -> Data? {
        if let data = representation.data, !data.isEmpty {
            return data
        }
        if let filename = representation.filename {
            return imageStore.loadData(filename: filename)
        }
        return nil
    }

    func togglePin(_ id: ClipboardItem.ID) {
        queue.async { [weak self] in
            guard let self, let index = self.stored.firstIndex(where: { $0.id == id }) else { return }
            self.stored[index].isPinned.toggle()
            self.historyStore.setPinned(id: id, isPinned: self.stored[index].isPinned)
            self.publish()
        }
    }

    func delete(_ id: ClipboardItem.ID) {
        queue.async { [weak self] in
            guard let self else { return }
            self.stored.removeAll { $0.id == id }
            let files = self.historyStore.delete(id: id)
            files.forEach { self.imageStore.delete(filename: $0) }
            self.publish { store in
                if store.selectedID == id {
                    store.selectedID = store.visibleItems.first?.id
                }
            }
        }
    }

    func clearUnpinned() {
        queue.async { [weak self] in
            guard let self else { return }
            let removed = self.stored.filter { !$0.isPinned }
            self.stored.removeAll { !$0.isPinned }
            let files = self.historyStore.delete(ids: removed.map(\.id))
            files.forEach { self.imageStore.delete(filename: $0) }
            self.publish { store in
                store.selectedID = store.visibleItems.first?.id
            }
        }
    }

    func clearAll() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stored = []
            let files = self.historyStore.clearAll()
            files.forEach { self.imageStore.delete(filename: $0) }
            self.publish { store in
                store.selectedID = nil
            }
        }
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

    private func ingestOnQueue(_ snapshot: PasteboardSnapshot) {
        guard let captured = PasteboardCapture.process(snapshot) else { return }

        if let index = stored.firstIndex(where: { $0.contentHash == captured.contentHash }) {
            var existing = stored.remove(at: index)
            existing.lastCopiedAt = Date()
            stored.insert(existing, at: 0)
            historyStore.touch(id: existing.id, lastCopiedAt: existing.lastCopiedAt)
            publish()
            return
        }

        let id = UUID()
        var imageFilename: String?
        var thumbFilename: String?

        if let png = captured.displayPNG {
            let name = "\(id.uuidString).png"
            do {
                try imageStore.save(png, filename: name)
                imageFilename = name
            } catch {
                NSLog("Klipp: no se pudo guardar imagen (%@)", error.localizedDescription)
            }
        }
        if let thumb = captured.thumbnailPNG {
            let name = "\(id.uuidString)-thumb.png"
            if (try? imageStore.save(thumb, filename: name)) != nil {
                thumbFilename = name
            }
        }

        let item = ClipboardItem(
            id: id,
            kind: captured.kind,
            text: captured.text,
            imageFilename: imageFilename,
            thumbnailFilename: thumbFilename,
            contentHash: captured.contentHash,
            preview: captured.preview,
            byteSize: captured.byteSize
        )
        let representations = persistRepresentations(id: id, captured: captured, imageFilename: imageFilename)
        historyStore.upsert(item, representations: representations)
        stored.insert(item, at: 0)
        evictIfNeeded()
        publish()
    }

    private func persistRepresentations(
        id: UUID,
        captured: CapturedPayload,
        imageFilename: String?
    ) -> [ClipboardRepresentation] {
        var result: [ClipboardRepresentation] = []
        for (index, pair) in captured.representations.enumerated() {
            let type = pair.type
            let data = pair.data
            if let imageFilename, Self.isPNGType(type) {
                result.append(ClipboardRepresentation(type: type, data: nil, filename: imageFilename))
                continue
            }
            if Self.shouldStoreInFile(type: type, data: data) {
                let name = "\(id.uuidString)-\(index).\(Self.fileExtension(for: type))"
                do {
                    try imageStore.save(data, filename: name)
                    result.append(ClipboardRepresentation(type: type, data: nil, filename: name))
                } catch {
                    result.append(ClipboardRepresentation(type: type, data: data, filename: nil))
                }
            } else {
                result.append(ClipboardRepresentation(type: type, data: data, filename: nil))
            }
        }
        return result
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
        let victims = stored
            .filter { !$0.isPinned }
            .sorted { $0.lastCopiedAt < $1.lastCopiedAt }
        let overflow = victims.count - limit
        guard overflow > 0 else { return }
        let doomed = Array(victims.prefix(overflow))
        let ids = Set(doomed.map(\.id))
        stored.removeAll { ids.contains($0.id) }
        let files = historyStore.delete(ids: doomed.map(\.id))
        files.forEach { imageStore.delete(filename: $0) }
    }

    private func publish(then extra: ((ClipboardStore) -> Void)? = nil) {
        let snapshot = stored
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.items = snapshot
            extra?(self)
        }
    }

    private func onStoreQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return work()
        }
        return queue.sync(execute: work)
    }

    private static func isValid(_ item: ClipboardItem, imageStore: ImageStore) -> Bool {
        switch item.kind {
        case .text, .richText, .files:
            return item.text?.isEmpty == false || item.preview.isEmpty == false
        case .image:
            return imageStore.exists(filename: item.imageFilename)
        }
    }

    private static func isPNGType(_ type: String) -> Bool {
        type == "public.png" || type == NSPasteboard.PasteboardType.png.rawValue
    }

    private static func shouldStoreInFile(type: String, data: Data) -> Bool {
        if type.contains("png") || type.contains("tiff") || type.contains("jpeg") {
            return true
        }
        return data.count > 64 * 1024
    }

    private static func fileExtension(for type: String) -> String {
        if type.contains("tiff") { return "tiff" }
        if type.contains("jpeg") { return "jpg" }
        if type.contains("png") { return "png" }
        if type.contains("rtf") { return "rtf" }
        if type.contains("html") { return "html" }
        return "bin"
    }
}
