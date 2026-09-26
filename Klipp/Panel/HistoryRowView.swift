import SwiftUI

struct HistoryRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let thumbnail: NSImage?
    let onSelect: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    let onPaste: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            leadingVisual
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: item.preview.isEmpty ? (item.kind == .image ? "Imagen" : "Texto vacío") : item.preview)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(verbatim: item.kind == .image ? "Imagen" : "Texto")
                    Text(verbatim: "·")
                    Text(verbatim: relativeDate)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isSelected {
                HStack(spacing: 4) {
                    iconButton(item.isPinned ? "pin.slash" : "pin", action: onPin)
                    iconButton("trash", action: onDelete)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(count: 2, perform: onPaste)
        .onTapGesture(perform: onSelect)
    }

    private var leadingVisual: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                    Image(systemName: item.kind == .image ? "photo" : "doc.on.clipboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
            )
    }

    private var relativeDate: String {
        HistoryRowView.dateFormatter.localizedString(for: item.lastCopiedAt, relativeTo: Date())
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
