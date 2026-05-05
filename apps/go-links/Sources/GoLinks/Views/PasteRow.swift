import SwiftUI
import AppKit

struct PasteRow: View {
    let paste: PasteItem
    let isSelected: Bool
    let isPreviewing: Bool
    let isCopied: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var confirmingDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacing8) {
            Button(action: onSelect) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(primaryText)
            .accessibilityHint(isSelected ? "Press Return to copy." : "Select this paste.")

            HStack(spacing: AppTheme.spacing4) {
                ToolIconButton(systemName: isPreviewing ? "eye.fill" : "eye", help: "Preview", size: AppTheme.compactControlSize, action: onPreview)
                ToolIconButton(systemName: isCopied ? "checkmark" : "doc.on.doc", help: "Copy Text", size: AppTheme.compactControlSize, action: onCopy)
                ToolIconButton(systemName: "pencil", help: "Edit", size: AppTheme.compactControlSize, action: onEdit)
                ToolIconButton(systemName: "trash", help: "Delete", tint: .red, size: AppTheme.compactControlSize) {
                    confirmingDelete = true
                }
            }
            .frame(width: 124)
        }
        .padding(.horizontal, AppTheme.spacing12)
        .padding(.vertical, AppTheme.spacing8)
        .background(rowBackground)
        .overlay(rowBorder)
        .confirmationDialog("Delete \(paste.title)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: AppTheme.spacing8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 16)
                .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacing8) {
                Text(displayText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(isPreviewing ? 10 : 2)
                    .textSelection(.enabled)

                Spacer(minLength: AppTheme.spacing8)

                Text(relativeUpdatedText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var primaryText: String {
        displayText
    }

    private var displayText: String {
        let body = normalizedBody
        return body.isEmpty ? "Untitled Paste" : body
    }

    private var normalizedBody: String {
        paste.body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var relativeUpdatedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: paste.updatedAt, relativeTo: Date())
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            .fill(isSelected ? Color.accentColor.opacity(0.15) : AppTheme.groupedBackground)
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            .stroke(isSelected ? Color.accentColor.opacity(0.3) : AppTheme.separator.opacity(0.3), lineWidth: 1)
    }
}
