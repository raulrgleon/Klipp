import AppKit
import ApplicationServices
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
        let representations = store.representations(for: item)
        pasteboard.clearContents()

        if !representations.isEmpty {
            let types = representations.map { NSPasteboard.PasteboardType($0.type) }
            pasteboard.declareTypes(types, owner: nil)
            var wrote = false
            for representation in representations {
                guard let data = store.data(for: representation) else { continue }
                pasteboard.setData(data, forType: NSPasteboard.PasteboardType(representation.type))
                wrote = true
            }
            if let text = item.text, !text.isEmpty {
                pasteboard.setString(text, forType: .string)
                wrote = true
            }
            guard wrote else { return false }
        } else {
            switch item.kind {
            case .text, .richText, .files:
                guard let text = item.text, !text.isEmpty else { return false }
                pasteboard.setString(text, forType: .string)
            case .image:
                guard let image = store.fullImage(for: item) else { return false }
                pasteboard.writeObjects([image])
            }
        }

        monitor.syncAfterOwnWrite()
        return true
    }

    func pasteIntoPreviousApp(_ app: NSRunningApplication?, item: ClipboardItem) {
        DispatchQueue.main.async {
            if let app, !app.isTerminated, app != NSRunningApplication.current {
                app.activate()
            }
            Self.waitUntilActive(app, timeout: 0.45) {
                if AccessibilityPermission.isTrusted,
                   item.kind == .text,
                   let text = item.text,
                   Self.insertTextViaAccessibility(text) {
                    return
                }
                guard AccessibilityPermission.isTrusted else { return }
                Self.postCommandV()
            }
        }
    }

    private static func waitUntilActive(_ app: NSRunningApplication?, timeout: TimeInterval, done: @escaping () -> Void) {
        guard let app, !app.isTerminated else {
            done()
            return
        }
        let start = Date()
        func tick() {
            if app.isTerminated || app.isActive || NSWorkspace.shared.frontmostApplication == app {
                done()
                return
            }
            if Date().timeIntervalSince(start) >= timeout {
                done()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: tick)
        }
        tick()
    }

    private static func insertTextViaAccessibility(_ text: String) -> Bool {
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef
        else { return false }

        let focused = focusedRef as! AXUIElement
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(focused, kAXSelectedTextAttribute as CFString, &settable) == .success,
              settable.boolValue
        else { return false }

        return AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
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
