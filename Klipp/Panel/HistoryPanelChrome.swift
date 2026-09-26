import AppKit

final class HistoryPanelChrome: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    let rootView: NSView
    private let store: ClipboardStore
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "Todavía no hay recortes")
    private let footerLabel = NSTextField(labelWithString: "↑↓ navegar   ⏎ pegar   ⌘P pin   ⌘⌫ borrar   ⎋ cerrar")

    var onPaste: ((ClipboardItem) -> Void)?
    var onClose: (() -> Void)?

    init(store: ClipboardStore) {
        self.store = store
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true
        self.rootView = effect
        super.init()
        build(in: effect)
        reload()
    }

    func focusSearch() {
        searchField.stringValue = store.searchQuery
        searchField.window?.makeFirstResponder(searchField)
    }

    func reload() {
        let items = store.visibleItems
        emptyLabel.isHidden = !items.isEmpty
        tableView.reloadData()
        if let selected = store.selectedID,
           let row = items.firstIndex(where: { $0.id == selected }) {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
        } else if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            store.selectedID = items[0].id
        } else {
            tableView.deselectAll(nil)
        }
    }

    func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53:
            onClose?()
            return true
        case 125:
            moveSelection(by: 1)
            return true
        case 126:
            moveSelection(by: -1)
            return true
        case 36, 76:
            pasteSelected()
            return true
        default:
            break
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) && event.keyCode == 35 {
            if let id = store.selectedID { store.togglePin(id); reload() }
            return true
        }
        if flags.contains(.command) && event.keyCode == 51 {
            if let id = store.selectedID { store.delete(id); reload() }
            return true
        }
        return false
    }

    private func pasteSelected() {
        guard let item = store.selectedItem else { return }
        onPaste?(item)
    }

    private func moveSelection(by offset: Int) {
        let items = store.visibleItems
        guard !items.isEmpty else { return }
        let current = items.firstIndex(where: { $0.id == store.selectedID }) ?? 0
        let next = min(items.count - 1, max(0, current + offset))
        store.selectedID = items[next].id
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func build(in parent: NSView) {
        let title = NSTextField(labelWithString: "KLIPP")
        title.font = .systemFont(ofSize: 11, weight: .heavy)
        title.textColor = NSColor(calibratedRed: 0.965, green: 0.62, blue: 0.145, alpha: 1)
        title.isBezeled = false
        title.drawsBackground = false

        searchField.placeholderString = "Buscar recortes…"
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.target = self
        searchField.action = #selector(searchSubmitted)

        tableView.headerView = nil
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = 52
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(rowDoubleClicked)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.usesAlternatingRowBackgroundColors = false

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        emptyLabel.font = .systemFont(ofSize: 13, weight: .medium)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true

        footerLabel.font = .systemFont(ofSize: 11)
        footerLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [title, searchField, scroll, footerLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 12, right: 14)
        stack.setHuggingPriority(.defaultLow, for: .horizontal)
        stack.setHuggingPriority(.defaultLow, for: .vertical)
        stack.translatesAutoresizingMaskIntoConstraints = false

        parent.addSubview(stack)
        parent.addSubview(emptyLabel)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            stack.topAnchor.constraint(equalTo: parent.topAnchor),
            stack.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            searchField.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 360),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor)
        ])
    }

    @objc private func searchSubmitted() {
        store.searchQuery = searchField.stringValue
        reload()
    }

    @objc private func rowDoubleClicked() {
        pasteSelected()
    }

    func controlTextDidChange(_ obj: Notification) {
        store.searchQuery = searchField.stringValue
        reload()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        store.visibleItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let items = store.visibleItems
        guard items.indices.contains(row) else { return nil }
        let item = items[row]
        let id = NSUserInterfaceItemIdentifier("HistoryCell")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? HistoryCellView) ?? HistoryCellView()
        cell.identifier = id
        cell.configure(item: item, thumbnail: store.thumbnail(for: item), selected: item.id == store.selectedID)
        cell.onPin = { [weak self] in
            self?.store.togglePin(item.id)
            self?.reload()
        }
        cell.onDelete = { [weak self] in
            self?.store.delete(item.id)
            self?.reload()
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        let items = store.visibleItems
        guard items.indices.contains(row) else { return }
        store.selectedID = items[row].id
    }
}

private final class HistoryCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let pinButton = NSButton()
    private let deleteButton = NSButton()
    var onPin: (() -> Void)?
    var onDelete: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 6
        iconView.layer?.masksToBounds = true

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        metaLabel.font = .systemFont(ofSize: 11)
        metaLabel.textColor = .secondaryLabelColor

        configureIconButton(pinButton, symbol: "pin")
        pinButton.action = #selector(pinTapped)
        pinButton.target = self

        configureIconButton(deleteButton, symbol: "trash")
        deleteButton.action = #selector(deleteTapped)
        deleteButton.target = self

        let text = NSStackView(views: [titleLabel, metaLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2

        let row = NSStackView(views: [iconView, text, pinButton, deleteButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            text.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        text.setHuggingPriority(.defaultLow, for: .horizontal)
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(item: ClipboardItem, thumbnail: NSImage?, selected: Bool) {
        titleLabel.stringValue = item.preview.isEmpty ? (item.kind == .image ? "Imagen" : "Texto") : item.preview
        let kind = item.kind == .image ? "Imagen" : "Texto"
        let pin = item.isPinned ? " · anclado" : ""
        metaLabel.stringValue = kind + pin
        if let thumbnail {
            iconView.image = thumbnail
        } else {
            iconView.image = NSImage(systemSymbolName: item.kind == .image ? "photo" : "doc.on.clipboard", accessibilityDescription: nil)
        }
        pinButton.isHidden = !selected
        deleteButton.isHidden = !selected
        pinButton.image = NSImage(systemSymbolName: item.isPinned ? "pin.slash" : "pin", accessibilityDescription: nil)
    }

    private func configureIconButton(_ button: NSButton, symbol: String) {
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
    }

    @objc private func pinTapped() { onPin?() }
    @objc private func deleteTapped() { onDelete?() }
}
