import SwiftUI
import AppKit

struct GoLinkRow: View {
    let link: GoLink
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var copied = false
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: AppTheme.spacing8) {
            VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                HStack(spacing: 0) {
                    Text("\(AppConfig.hostName)/")
                        .foregroundStyle(.secondary)
                    Text(link.shortName)
                        .foregroundStyle(.primary)
                }
                .font(.subheadline.monospaced())
                .lineLimit(1)

                Text(link.destinationURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: AppTheme.spacing12)

            HStack(spacing: AppTheme.spacing4) {
                ToolIconButton(systemName: "arrow.up.right.square", help: "Open", size: AppTheme.compactControlSize) {
                    if let url = URL(string: "http://\(AppConfig.hostName)/\(link.shortName)") {
                        NSWorkspace.shared.open(url)
                    }
                }

                ToolIconButton(systemName: copied ? "checkmark" : "doc.on.doc", help: "Copy", size: AppTheme.compactControlSize) {
                    Clipboard.copy("http://\(AppConfig.hostName)/\(link.shortName)")
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        copied = false
                    }
                }

                ToolIconButton(systemName: "pencil", help: "Edit", size: AppTheme.compactControlSize, action: onEdit)

                ToolIconButton(systemName: "trash", help: "Delete", tint: .red, size: AppTheme.compactControlSize) {
                    confirmingDelete = true
                }
            }
            .frame(width: 124)
        }
        .padding(.horizontal, AppTheme.spacing12)
        .padding(.vertical, AppTheme.spacing8)
        .confirmationDialog("Delete \(AppConfig.hostName)/\(link.shortName)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

}
