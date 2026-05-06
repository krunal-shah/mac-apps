import SwiftUI
import AppKit

struct GoLinkRow: View {
    let link: GoLink
    let isSelected: Bool
    let isCopied: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var confirmingDelete = false

    private var isFocused: Bool { isSelected || isHovering }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppTheme.spacing10) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 0) {
                        Text("\(AppConfig.hostName)/")
                            .foregroundStyle(AppTheme.shelfInkTertiary)
                        Text(link.shortName)
                            .foregroundStyle(AppTheme.shelfInk)
                    }
                    .font(AppTheme.mono(13, weight: .medium))
                    .lineLimit(1)

                    Text(link.destinationURL)
                        .font(AppTheme.sans(11, weight: .regular))
                        .foregroundStyle(AppTheme.shelfInkTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
                }
            }
            .padding(.horizontal, AppTheme.spacing12)
            .padding(.vertical, AppTheme.spacing10)
            .frame(minHeight: 50)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppTheme.hoverAnimation) { isHovering = hovering }
            if !hovering { confirmingDelete = false }
        }
        .accessibilityLabel("\(AppConfig.hostName)/\(link.shortName)")
        .accessibilityHint(link.destinationURL)
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
                KbdGlyph(symbol: "↵", label: "Open")
            }

            if isHovering {
                ToolIconButton(systemName: "doc.on.doc", help: "Copy URL", size: AppTheme.microControlSize, action: onCopy)
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
}
