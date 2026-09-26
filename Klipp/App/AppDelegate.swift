import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = AppRuntime.shared
        AppRuntime.shared.refreshPermissions()
        AppRuntime.shared.panelController.prepare()
        statusItem = StatusItemController()

        if ProcessInfo.processInfo.arguments.contains("--settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                AppRuntime.shared.openSettings()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppRuntime.shared.panelController.show()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppRuntime.shared.hotkeyManager.unregister()
        AppRuntime.shared.monitor.stop()
    }
}
