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
        HStack(alignment: .top, spacing: AppTheme.spacing12) {
            Button(action: onSelect) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(primaryText)
            .accessibilityHint(isSelected ? "Press Return to copy." : "Select this paste.")

            HStack(spacing: AppTheme.spacing4) {
                ToolIconButton(systemName: isPreviewing ? "eye.fill" : "eye", help: "Preview", size: 32, action: onPreview)
                ToolIconButton(systemName: isCopied ? "checkmark" : "doc.on.doc", help: "Copy Text", size: 32, action: onCopy)
                ToolIconButton(systemName: "pencil", help: "Edit", size: 32, action: onEdit)
                ToolIconButton(systemName: "trash", help: "Delete", tint: .red, size: 32) {
                    confirmingDelete = true
                }
            }
            .frame(width: 140)
        }
        .padding(.horizontal, AppTheme.spacing16)
        .padding(.vertical, AppTheme.spacing12)
        .background(rowBackground)
        .overlay(rowBorder)
        .confirmationDialog("Delete \(paste.title)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: AppTheme.spacing12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: AppTheme.rowIconWidth)
                .padding(.top, AppTheme.spacing4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacing8) {
                    VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                        Text(primaryText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(summaryText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(isPreviewing ? 12 : 2)
                            .textSelection(.enabled)
                    }

                    Spacer(minLength: AppTheme.spacing12)

                    Text(relativeUpdatedText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if isPreviewing {
                    Divider()
                    HStack(spacing: AppTheme.spacing8) {
                        Label("Preview", systemImage: "eye")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var primaryText: String {
        firstLine.isEmpty ? "Untitled Paste" : firstLine
    }

    private var summaryText: String {
        if isPreviewing {
            return paste.body
        }

        let summary = flattenedBody
        if summary == firstLine {
            return "\(paste.body.count) character\(paste.body.count == 1 ? "" : "s")"
        }
        return summary
    }

    private var firstLine: String {
        paste.body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var flattenedBody: String {
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
