import AppKit
import Foundation

final class PasteSimulator {
    private let store: ClipboardStore
    private let monitor: ClipboardMonitor

    init(store: ClipboardStore, monitor: ClipboardMonitor) {
        self.store = store
        self.monitor = monitor
    }

    func writeToPasteboard(_ item: ClipboardItem) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            guard let text = item.text, !text.isEmpty else { return false }
            pasteboard.setString(text, forType: .string)
        case .image:
            guard let image = store.fullImage(for: item) else { return false }
            pasteboard.writeObjects([image])
        }

        monitor.syncAfterOwnWrite()
        return true
    }

    func pasteIntoPreviousApp(_ app: NSRunningApplication?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if let app, !app.isTerminated, app != NSRunningApplication.current {
                app.activate()
            }
            guard AccessibilityPermission.isTrusted else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                Self.postCommandV()
            }
        }
    }

    private static func postCommandV() {
        guard AccessibilityPermission.isTrusted else { return }

        let source = CGEventSource(stateID: .combinedSessionState)
        source?.localEventsSuppressionInterval = 0
        let keyCode: CGKeyCode = 9

        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
