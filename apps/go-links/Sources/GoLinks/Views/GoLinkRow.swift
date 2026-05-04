import SwiftUI
import AppKit

struct GoLinkRow: View {
    let link: GoLink
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var copied = false
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 0) {
                    Text("\(AppConfig.hostName)/")
                        .foregroundColor(.secondary)
                    Text(link.shortName)
                        .foregroundColor(.primary)
                }
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .lineLimit(1)

                Text(link.destinationURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 10)

            HStack(spacing: 4) {
                iconButton("arrow.up.right.square", help: "Open") {
                    if let url = URL(string: "http://\(AppConfig.hostName)/\(link.shortName)") {
                        NSWorkspace.shared.open(url)
                    }
                }

                iconButton(copied ? "checkmark" : "doc.on.doc", help: "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("http://\(AppConfig.hostName)/\(link.shortName)", forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        copied = false
                    }
                }

                iconButton("pencil", help: "Edit", action: onEdit)

                iconButton("trash", help: "Delete", tint: .red) {
                    confirmingDelete = true
                }
            }
            .frame(width: 104)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .confirmationDialog("Delete \(AppConfig.hostName)/\(link.shortName)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func iconButton(
        _ systemName: String,
        help: String,
        tint: Color = .secondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 23, height: 23)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .help(help)
    }
}
