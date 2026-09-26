import AppKit
import Combine
import Foundation
import ServiceManagement

final class AppRuntime: ObservableObject {
    static let shared = AppRuntime()

    let settings: AppSettings
    let imageStore: ImageStore
    let repository: HistoryRepository
    let store: ClipboardStore
    let monitor: ClipboardMonitor
    let pasteSimulator: PasteSimulator
    let panelController: PanelController
    let hotkeyManager: HotkeyManager
    let settingsWindow: SettingsWindowController

    @Published var accessibilityTrusted: Bool = AccessibilityPermission.isTrusted

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let settings = AppSettings()
        let imageStore = ImageStore()
        let repository = HistoryRepository()
        let store = ClipboardStore(repository: repository, settings: settings, imageStore: imageStore)
        let monitor = ClipboardMonitor(interval: 0.4)
        let pasteSimulator = PasteSimulator(store: store, monitor: monitor)
        let panelController = PanelController(store: store, pasteSimulator: pasteSimulator)
        let hotkeyManager = HotkeyManager()
        let settingsWindow = SettingsWindowController()

        self.settings = settings
        self.imageStore = imageStore
        self.repository = repository
        self.store = store
        self.monitor = monitor
        self.pasteSimulator = pasteSimulator
        self.panelController = panelController
        self.hotkeyManager = hotkeyManager
        self.settingsWindow = settingsWindow

        monitor.isEnabled = settings.monitoringEnabled
        monitor.onCapture = { [store] content in
            store.ingest(content)
        }
        hotkeyManager.onPressed = {
            AppRuntime.shared.panelController.toggle()
        }
        hotkeyManager.register(settings.hotkey)
        monitor.start()

        settings.$monitoringEnabled
            .sink { [weak monitor] enabled in
                monitor?.isEnabled = enabled
            }
            .store(in: &cancellables)

        settings.$hotkey
            .dropFirst()
            .sink { [weak hotkeyManager] combo in
                hotkeyManager?.register(combo)
            }
            .store(in: &cancellables)

        applyLaunchAtLogin(settings.launchAtLogin)
    }

    func refreshPermissions() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }

    func requestAccessibility() {
        AccessibilityPermission.requestFromUser()
    }

    func relaunch() {
        let appPath = Bundle.main.bundlePath.replacingOccurrences(of: "\"", with: "\\\"")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", "sleep 0.5; open \"\(appPath)\""]
        do {
            try proc.run()
            NSApp.terminate(nil)
        } catch {
            NSLog("Klipp: no se pudo reiniciar (%@)", error.localizedDescription)
        }
    }

    func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Klipp: no se pudo actualizar el inicio de sesión (%@)", error.localizedDescription)
        }
    }

    func revealDataFolder() {
        NSWorkspace.shared.open(repository.directory)
    }

    func openSettings() {
        settingsWindow.show()
    }
}
