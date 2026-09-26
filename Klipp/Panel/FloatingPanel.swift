import AppKit

final class FloatingPanel: NSPanel {
    var onResignKey: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        // canJoinAllSpaces + moveToActiveSpace together asserts on macOS 26
        // and kills the process when the panel is first created.
        collectionBehavior = [.fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        title = "Klipp"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
