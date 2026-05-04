import SwiftUI

struct GoLinkRow: View {
    let link: GoLink
    @EnvironmentObject var store: GoLinkStore

    @State private var showingEdit = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Left: go link name + destination
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("go/")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                    Text(link.shortName)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
                Text(link.destinationURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Right: actions (visible on hover)
            if isHovered {
                HStack(spacing: 4) {
                    // Open in browser
                    actionButton(icon: "arrow.up.right.square", help: "Open in browser") {
                        if let url = URL(string: "http://go/\(link.shortName)") {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    // Copy go link
                    actionButton(icon: "doc.on.doc", help: "Copy go link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("http://go/\(link.shortName)",
                                                       forType: .string)
                    }

                    // Edit
                    actionButton(icon: "pencil", help: "Edit") {
                        showingEdit = true
                    }

                    // Delete
                    actionButton(icon: "trash", help: "Delete", tint: .red) {
                        store.delete(link)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.08)
                               : Color.clear)
        .onHover { isHovered = $0 }
        .sheet(isPresented: $showingEdit) {
            AddEditLinkView(mode: .edit(link))
                .environmentObject(store)
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private func actionButton(icon: String, help: String,
                               tint: Color = .secondary,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(tint)
                .frame(width: 22, height: 22)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
