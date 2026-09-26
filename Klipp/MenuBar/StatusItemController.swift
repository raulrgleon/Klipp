import AppKit

final class StatusItemController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let countItem = NSMenuItem()
    private let hotkeyItem = NSMenuItem()
    private let listenItem = NSMenuItem()

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "list.clipboard.fill", accessibilityDescription: "Klipp")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        countItem.isEnabled = false
        hotkeyItem.isEnabled = false

        listenItem.title = "Escuchar portapapeles"
        listenItem.target = self
        listenItem.action = #selector(toggleListening)

        menu.delegate = self
        menu.addItem(withTitle: "Mostrar historial", action: #selector(showHistory), keyEquivalent: "")
        menu.addItem(hotkeyItem)
        menu.addItem(countItem)
        menu.addItem(.separator())
        menu.addItem(listenItem)
        menu.addItem(withTitle: "Vaciar recortes no anclados", action: #selector(clearUnpinned), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Ajustes…", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(withTitle: "Salir de Klipp", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items {
            item.target = self
        }
        listenItem.target = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let runtime = AppRuntime.shared
        hotkeyItem.title = "Atajo: \(runtime.settings.hotkey.displayString)"
        let count = runtime.store.items.count
        countItem.title = count == 0 ? "Sin recortes" : "\(count) recortes"
        listenItem.state = runtime.settings.monitoringEnabled ? .on : .off
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp, let event {
            NSMenu.popUpContextMenu(menu, with: event, for: sender)
            return
        }
        AppRuntime.shared.panelController.toggle()
    }

    @objc private func showHistory() {
        AppRuntime.shared.panelController.show()
    }

    @objc private func toggleListening() {
        AppRuntime.shared.settings.monitoringEnabled.toggle()
    }

    @objc private func clearUnpinned() {
        AppRuntime.shared.store.clearUnpinned()
    }

    @objc private func openSettings() {
        AppRuntime.shared.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
