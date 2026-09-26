import AppKit
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case permissions = "Permisos"
    case data = "Datos"

    var id: String { rawValue }
}

struct SettingsView: View {
    @ObservedObject private var runtime = AppRuntime.shared
    @ObservedObject private var settings = AppRuntime.shared.settings
    @ObservedObject private var store = AppRuntime.shared.store
    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Sección", selection: $tab) {
                ForEach(SettingsTab.allCases) { item in
                    Text(verbatim: item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case .general:
                        generalContent
                    case .permissions:
                        permissionsContent
                    case .data:
                        dataContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .frame(minWidth: 560, minHeight: 440)
        .onAppear {
            runtime.refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            runtime.refreshPermissions()
        }
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard(title: "Atajo global") {
                HStack(alignment: .center, spacing: 12) {
                    Text(verbatim: "Abrir historial")
                    Spacer(minLength: 12)
                    HotkeyRecorder(combo: $settings.hotkey)
                }
                SettingsNote("El atajo funciona con Klipp en segundo plano. No hace falta Input Monitoring: usa RegisterEventHotKey de Carbon.")
            }

            SettingsCard(title: "Historial") {
                Stepper(value: $settings.maxItems, in: AppSettings.minMaxItems...AppSettings.maxMaxItems, step: 10) {
                    Text(verbatim: "Máximo de recortes no anclados: \(settings.maxItems)")
                }
                SettingsNote("Los pines quedan fuera de este número y no se borran solos cuando el historial se llena.")
            }

            SettingsCard(title: "Inicio") {
                Toggle("Abrir Klipp al iniciar sesión", isOn: $settings.launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: settings.launchAtLogin) { _, enabled in
                        runtime.applyLaunchAtLogin(enabled)
                    }
                SettingsNote("macOS puede pedir confirmación en Ajustes del Sistema → Generales → Elementos de inicio.")
            }
        }
    }

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard(title: "Estado") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: runtime.accessibilityTrusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(runtime.accessibilityTrusted ? Color.green : Color.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: runtime.accessibilityTrusted ? "Permiso activo" : "Klipp no está habilitado todavía")
                            .font(.headline)
                        SettingsNote(
                            runtime.accessibilityTrusted
                                ? "Ya puede pegar solo con Enter."
                                : "Activá Klipp en Accesibilidad. Si hay varias entradas, usá solo la de Aplicaciones. Después cerrá Klipp desde la barra de menú y volvé a abrirla."
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsNote("App actual: \(Bundle.main.bundlePath)")

                HStack(spacing: 10) {
                    Button {
                        runtime.requestAccessibility()
                    } label: {
                        Text(verbatim: "Abrir Accesibilidad")
                    }
                    Button {
                        runtime.relaunch()
                    } label: {
                        Text(verbatim: "Cerrar y reabrir")
                    }
                }
            }

            SettingsCard(title: "Qué pide Klipp") {
                permissionRow(
                    title: "Accesibilidad",
                    reason: "Sirve para enviar Cmd+V a la app anterior. Sin este permiso, el recorte queda en el portapapeles y hay que pegarlo a mano."
                )
                permissionRow(
                    title: "Portapapeles",
                    reason: "No pide permiso. Lee el portapapeles del sistema y saltea tipos sensibles para no guardar contraseñas."
                )
                permissionRow(
                    title: "Input Monitoring",
                    reason: "No se pide. El atajo global no usa un event tap."
                )
                permissionRow(
                    title: "Pantalla y disco",
                    reason: "No se usan. El historial vive solo en la carpeta local de Klipp."
                )
                permissionRow(
                    title: "Red y telemetría",
                    reason: "Klipp no abre conexiones. Todo queda en esta Mac."
                )
            }
        }
    }

    private var dataContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard(title: "Almacenamiento local") {
                SettingsFact(label: "Recortes", value: "\(store.items.count)")
                SettingsFact(label: "Anclados", value: "\(store.items.filter(\.isPinned).count)")

                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "Carpeta")
                        .foregroundStyle(.secondary)
                    Text(verbatim: runtime.repository.directory.path)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Button {
                    runtime.revealDataFolder()
                } label: {
                    Text(verbatim: "Abrir carpeta en Finder")
                }
            }

            SettingsCard(title: "Borrar") {
                Button {
                    store.clearUnpinned()
                } label: {
                    Text(verbatim: "Vaciar recortes no anclados")
                }
                Button(role: .destructive) {
                    store.clearAll()
                } label: {
                    Text(verbatim: "Borrar todo el historial")
                }
            }
        }
    }

    private func permissionRow(title: String, reason: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: title)
                .font(.subheadline.weight(.semibold))
            SettingsNote(reason)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SettingsNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 13))
            .foregroundStyle(.primary.opacity(0.78))
            .multilineTextAlignment(.leading)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsFact: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(verbatim: value)
                .fontWeight(.medium)
        }
    }
}

struct HotkeyRecorder: View {
    @Binding var combo: KeyCombo
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(recording ? "Presioná el atajo…" : combo.displayString) {
            beginRecording()
        }
        .frame(minWidth: 120)
        .onDisappear { endRecording() }
    }

    private func beginRecording() {
        endRecording()
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                endRecording()
                return nil
            }
            if let captured = KeyCombo.from(event: event) {
                combo = captured
                endRecording()
                return nil
            }
            return event
        }
    }

    private func endRecording() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
