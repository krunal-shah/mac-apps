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
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        if isSelected {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.accentColor)
                        }

                        Text(primaryText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(relativeUpdatedText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text(summaryText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(isPreviewing ? 10 : 2)
                        .textSelection(.enabled)
                }

                HStack(spacing: 4) {
                    ToolIconButton(systemName: isPreviewing ? "eye.fill" : "eye", help: "Preview", size: 23, action: onPreview)
                    ToolIconButton(systemName: isCopied ? "checkmark" : "doc.on.doc", help: "Copy Text", size: 23, action: onCopy)
                    ToolIconButton(systemName: "pencil", help: "Edit", size: 23, action: onEdit)
                    ToolIconButton(systemName: "trash", help: "Delete", tint: .red, size: 23) {
                        confirmingDelete = true
                    }
                }
                .frame(width: 104)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .background(rowBackground)
        .overlay(rowBorder)
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onPreview)
        .confirmationDialog("Delete \(paste.title)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
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
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color(NSColor.separatorColor).opacity(0.38), lineWidth: 1)
    }
}
