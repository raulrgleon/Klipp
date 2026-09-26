import AppKit

final class PanelController: NSObject {
    private let store: ClipboardStore
    private let pasteSimulator: PasteSimulator
    private var panel: FloatingPanel?
    private var chrome: HistoryPanelChrome?
    private var keyMonitor: Any?
    private var hideOnResign = true
    private var previousApp: NSRunningApplication?
    private var isPasting = false

    var isVisible: Bool { panel?.isVisible == true }

    init(store: ClipboardStore, pasteSimulator: PasteSimulator) {
        self.store = store
        self.pasteSimulator = pasteSimulator
        super.init()
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Crea el panel en segundo plano para que el atajo no construya la ventana por primera vez.
    func prepare() {
        _ = ensurePanel()
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        store.resetForPanel()
        let panel = ensurePanel()
        chrome?.reload()
        position(panel)
        hideOnResign = false
        isPasting = false
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
        chrome?.focusSearch()
        startKeyMonitor()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.hideOnResign = true
        }
    }

    func hide() {
        hideOnResign = false
        stopKeyMonitor()
        panel?.makeFirstResponder(nil)
        panel?.orderOut(nil)
    }

    func paste(_ item: ClipboardItem) {
        guard !isPasting else { return }
        isPasting = true
        hideOnResign = false
        stopKeyMonitor()
        panel?.makeFirstResponder(nil)

        guard pasteSimulator.writeToPasteboard(item) else {
            isPasting = false
            return
        }

        let target = previousApp
        panel?.orderOut(nil)
        pasteSimulator.pasteIntoPreviousApp(target)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.isPasting = false
        }
    }

    private func ensurePanel() -> FloatingPanel {
        if let panel { return panel }

        let chrome = HistoryPanelChrome(store: store)
        chrome.onPaste = { [weak self] item in self?.paste(item) }
        chrome.onClose = { [weak self] in self?.hide() }

        let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 560))
        panel.contentView = chrome.rootView
        panel.setContentSize(NSSize(width: 460, height: 560))
        panel.onResignKey = { [weak self] in
            guard let self, self.hideOnResign, !self.isPasting else { return }
            self.hide()
        }

        self.chrome = chrome
        self.panel = panel
        return panel
    }

    private func position(_ panel: FloatingPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2 + 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.chrome?.handleKey(event) == true ? nil : event
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}
