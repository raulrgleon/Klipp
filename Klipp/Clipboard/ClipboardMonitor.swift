import AppKit
import Foundation

final class ClipboardMonitor {
    var onCapture: ((PasteboardSnapshot) -> Void)?
    var isEnabled: Bool = true
    var ignoredBundleIDs: () -> [String] = { [] }

    private var lastChangeCount: Int
    private var timer: Timer?
    private var ignoreOwnWrites = false
    private let interval: TimeInterval

    init(interval: TimeInterval = 0.4) {
        self.interval = interval
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call after Klipp writes to the pasteboard so we don't store our own paste.
    func syncAfterOwnWrite() {
        ignoreOwnWrites = true
        lastChangeCount = NSPasteboard.general.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.ignoreOwnWrites = false
            self?.lastChangeCount = NSPasteboard.general.changeCount
        }
    }

    private func poll() {
        guard isEnabled else { return }
        let pasteboard = NSPasteboard.general
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        if ignoreOwnWrites { return }

        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let source, ignoredBundleIDs().contains(source) {
            return
        }

        guard let snapshot = PasteboardCapture.snapshot(pasteboard, sourceBundleID: source) else { return }
        onCapture?(snapshot)
    }
}
