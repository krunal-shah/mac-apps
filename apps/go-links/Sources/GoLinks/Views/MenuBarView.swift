import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var store: GoLinkStore
    @EnvironmentObject private var setup: SetupManager

    @State private var activeSheet: ActiveSheet?
    @State private var searchText = ""

    private enum ActiveSheet: Identifiable {
        case add
        case edit(GoLink)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let link):
                return link.id.uuidString
            }
        }
    }

    private var filteredLinks: [GoLink] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.links }
        return store.links.filter {
            $0.shortName.contains(query) || $0.destinationURL.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 460, height: 540)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                AddEditLinkView(mode: .add)
                    .environmentObject(store)
            case .edit(let link):
                AddEditLinkView(mode: .edit(link))
                    .environmentObject(store)
            }
        }
        .onAppear {
            setup.refresh()
            setup.runDiagnostics()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(AppConfig.appName)
                    .font(.headline)
                Text("\(store.links.count) link\(store.links.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            iconButton("gearshape", help: "Setup") {
                SetupPanel.shared.show()
            }

            iconButton("plus", help: "Add Link") {
                activeSheet = .add
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
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

    @ViewBuilder
    private var content: some View {
        if store.links.isEmpty {
            emptyState
        } else if filteredLinks.isEmpty {
            unavailableState(
                icon: "magnifyingglass",
                title: "No Matches",
                detail: "No links match your search."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredLinks) { link in
                        GoLinkRow(
                            link: link,
                            onEdit: { activeSheet = .edit(link) },
                            onDelete: { store.delete(link) }
                        )

                        if link.id != filteredLinks.last?.id {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 34, weight: .regular))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text("No Links")
                    .font(.headline)
                Text("Add your first shortcut.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                activeSheet = .add
            } label: {
                Label("Add Link", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func unavailableState(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            StatusDot(color: setup.hostsConfigured && setup.pfActiveInKernel ? .green : .orange)

            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                NSWorkspace.shared.open(AppConfig.httpURL)
            } label: {
                Label("Open", systemImage: "safari")
            }
            .font(.caption)
            .buttonStyle(.plain)
            .disabled(!setup.hostsConfigured || !setup.pfActiveInKernel)

            Text("|")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var statusText: String {
        if setup.hostsConfigured && setup.pfActiveInKernel {
            return "Ready"
        }
        if setup.hostsConfigured && setup.pfConfigured {
            return "Setup needs refresh"
        }
        return "Setup required"
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .help(help)
    }
}

private struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}
