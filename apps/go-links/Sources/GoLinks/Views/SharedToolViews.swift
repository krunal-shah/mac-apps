import SwiftUI

struct ToolIconButton: View {
    let systemName: String
    let help: String
    var tint: Color = .secondary
    var background: Color = Color(NSColor.controlBackgroundColor)
    var size: CGFloat = 26
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(tint)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .help(help)
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct EmptyToolState: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .regular))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
