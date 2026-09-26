import AppKit
import SwiftUI

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        let window = ensureWindow()
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            return window
        }

        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Ajustes de Klipp"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 520))
        window.minSize = NSSize(width: 560, height: 440)
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        return window
    }
}
