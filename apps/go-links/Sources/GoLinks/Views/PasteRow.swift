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

    @State private var isHovering = false
    @State private var confirmingDelete = false

    private var isFocused: Bool { isSelected || isHovering }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppTheme.spacing10) {
                Text(displayText)
                    .font(AppTheme.sans(13, weight: .regular))
                    .foregroundStyle(AppTheme.shelfInk)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)

                Spacer(minLength: AppTheme.spacing8)

                if confirmingDelete {
                    InlineConfirm(
                        prompt: "Delete?",
                        onConfirm: {
                            onDelete()
                            confirmingDelete = false
                        },
                        onCancel: { confirmingDelete = false }
                    )
                } else if isFocused {
                    focusActions
                } else {
                    Text(relativeUpdatedText)
                        .font(AppTheme.sans(11, weight: .regular))
                        .foregroundStyle(AppTheme.shelfInkTertiary)
                }
            }
            .padding(.horizontal, AppTheme.spacing12)
            .frame(height: 38)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppTheme.hoverAnimation) { isHovering = hovering }
            if !hovering { confirmingDelete = false }
        }
        .accessibilityLabel(displayText)
        .accessibilityHint(isSelected ? "Press Return to copy." : "Select this paste.")
    }

    private var focusActions: some View {
        HStack(spacing: AppTheme.spacing6) {
            if isCopied {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Copied")
                        .font(AppTheme.sans(11, weight: .medium))
                }
                .foregroundStyle(AppTheme.shelfReady)
            } else if isSelected {
                KbdGlyph(symbol: "↵", label: "Copy")
            }

            if isHovering {
                ToolIconButton(systemName: "eye", help: "Preview", size: AppTheme.microControlSize, action: onPreview)
                ToolIconButton(systemName: "pencil", help: "Edit", size: AppTheme.microControlSize, action: onEdit)
                ToolIconButton(systemName: "trash", help: "Delete", tint: AppTheme.shelfDanger, size: AppTheme.microControlSize) {
                    confirmingDelete = true
                }
            }
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(AppTheme.shelfHighlight)
        } else if isHovering {
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(AppTheme.shelfRule.opacity(0.5))
        } else {
            Color.clear
        }
    }

    private var displayText: String {
        let body = normalizedBody
        return body.isEmpty ? "Untitled paste" : body
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
}
