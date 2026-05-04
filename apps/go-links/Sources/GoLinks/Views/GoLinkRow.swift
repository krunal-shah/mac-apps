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
                ToolIconButton(systemName: "arrow.up.right.square", help: "Open", size: 23) {
                    if let url = URL(string: "http://\(AppConfig.hostName)/\(link.shortName)") {
                        NSWorkspace.shared.open(url)
                    }
                }

                ToolIconButton(systemName: copied ? "checkmark" : "doc.on.doc", help: "Copy", size: 23) {
                    Clipboard.copy("http://\(AppConfig.hostName)/\(link.shortName)")
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        copied = false
                    }
                }

                ToolIconButton(systemName: "pencil", help: "Edit", size: 23, action: onEdit)

                ToolIconButton(systemName: "trash", help: "Delete", tint: .red, size: 23) {
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

}
