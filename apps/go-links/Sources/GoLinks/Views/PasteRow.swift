import SwiftUI
import AppKit

struct PasteRow: View {
    let paste: PasteItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var copiedURL = false
    @State private var copiedBody = false
    @State private var confirmingDelete = false

    private var pasteURL: String {
        AppConfig.pasteURL(for: paste.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(paste.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(relativeUpdatedText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text(pasteURL)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(previewText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 10)

            HStack(spacing: 4) {
                ToolIconButton(systemName: "arrow.up.right.square", help: "Open", size: 23) {
                    if let url = URL(string: pasteURL) {
                        NSWorkspace.shared.open(url)
                    }
                }

                ToolIconButton(systemName: copiedURL ? "checkmark" : "link", help: "Copy URL", size: 23) {
                    copyURL()
                }

                ToolIconButton(systemName: copiedBody ? "checkmark" : "doc.on.doc", help: "Copy Text", size: 23) {
                    copyBody()
                }

                ToolIconButton(systemName: "pencil", help: "Edit", size: 23, action: onEdit)

                ToolIconButton(systemName: "trash", help: "Delete", tint: .red, size: 23) {
                    confirmingDelete = true
                }
            }
            .frame(width: 131)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .confirmationDialog("Delete \(paste.title)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var previewText: String {
        let flattened = paste.body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flattened.isEmpty ? "Empty paste" : flattened
    }

    private var relativeUpdatedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: paste.updatedAt, relativeTo: Date())
    }

    private func copyURL() {
        Clipboard.copy(pasteURL)
        copiedURL = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            copiedURL = false
        }
    }

    private func copyBody() {
        Clipboard.copy(paste.body)
        copiedBody = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            copiedBody = false
        }
    }
}
