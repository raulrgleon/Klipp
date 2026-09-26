import SwiftUI

struct HistoryPanelView: View {
    @ObservedObject var store: ClipboardStore
    var onPaste: (ClipboardItem) -> Void
    var onClose: () -> Void
    var onOpenSettings: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            content
            Divider().opacity(0.35)
            footer
        }
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .onAppear {
            searchFocused = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: "KLIPP")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text(verbatim: "\(store.visibleItems.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar recortes…", text: $store.searchQuery)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit {
                        if let item = store.selectedItem {
                            onPaste(item)
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if store.visibleItems.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.visibleItems) { item in
                            HistoryRowView(
                                item: item,
                                isSelected: item.id == store.selectedID,
                                thumbnail: store.thumbnail(for: item),
                                onSelect: { store.selectedID = item.id },
                                onPin: { store.togglePin(item.id) },
                                onDelete: { store.delete(item.id) },
                                onPaste: { onPaste(item) }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .onChange(of: store.selectedID) { _, id in
                    if let id {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: store.searchQuery.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text(verbatim: store.searchQuery.isEmpty ? "Todavía no hay recortes" : "Sin resultados")
                .font(.system(size: 14, weight: .semibold))
            Text(verbatim: store.searchQuery.isEmpty ? "Copiá texto o una imagen con ⌘C. Klipp lo guarda acá." : "Probá otra búsqueda.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                hint("↑↓", "navegar")
                hint("⏎", "pegar")
                hint("⌘P", "pin")
                hint("⌘⌫", "borrar")
                hint("⎋", "cerrar")
                Spacer()
            }
            if !AccessibilityPermission.isTrusted {
                HStack(alignment: .top, spacing: 8) {
                    Text(verbatim: "El recorte queda en el portapapeles. Para pegarlo solo, activá Accesibilidad.")
                        .foregroundStyle(.orange)
                    Button {
                        onOpenSettings()
                    } label: {
                        Text(verbatim: "Ajustes")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
                .font(.system(size: 10))
            }
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(verbatim: key).fontWeight(.semibold)
            Text(verbatim: label)
        }
    }
}
