import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject private var runtime = AppRuntime.shared
    @ObservedObject private var store = AppRuntime.shared.store
    @ObservedObject private var settings = AppRuntime.shared.settings

    var body: some View {
        Button("Mostrar historial") {
            runtime.refreshPermissions()
            runtime.panelController.show()
        }
        Text("Atajo: \(settings.hotkey.displayString)")
        Text(store.items.isEmpty ? "Sin recortes" : "\(store.items.count) recortes")
        Divider()
        Toggle("Escuchar portapapeles", isOn: $settings.monitoringEnabled)
        Button("Vaciar recortes no anclados") {
            store.clearUnpinned()
        }
        .disabled(store.items.allSatisfy(\.isPinned))
        Divider()
        Button("Ajustes…") {
            runtime.openSettings()
        }
        Button("Salir de Klipp") {
            NSApp.terminate(nil)
        }
    }
}
