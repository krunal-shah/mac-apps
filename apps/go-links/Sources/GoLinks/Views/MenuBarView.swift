import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: GoLinkStore
    @EnvironmentObject var setup: SetupManager

    @State private var showingAdd = false
    @State private var searchText = ""

    var filteredLinks: [GoLink] {
        if searchText.isEmpty { return store.links.sorted { $0.shortName < $1.shortName } }
        let q = searchText.lowercased()
        return store.links
            .filter { $0.shortName.contains(q) || $0.destinationURL.lowercased().contains(q) }
            .sorted { $0.shortName < $1.shortName }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()
            linkContent
            Divider()
            footer
        }
        .frame(width: 420, height: 520)
        .sheet(isPresented: $showingAdd) {
            AddEditLinkView(mode: .add)
                .environmentObject(store)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("Go Links")
                .font(.headline)
            Spacer()
            Button {
                showingAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Add a new go link")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            TextField("Search go links…", text: $searchText)
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
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private var linkContent: some View {
        if store.links.isEmpty {
            emptyState
        } else if filteredLinks.isEmpty {
            noResultsState
        } else {
            List {
                ForEach(filteredLinks) { link in
                    GoLinkRow(link: link)
                        .environmentObject(store)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .onDelete { offsets in
                    // Map filtered offsets back to store
                    let ids = offsets.map { filteredLinks[$0].id }
                    ids.forEach { id in
                        if let link = store.links.first(where: { $0.id == id }) {
                            store.delete(link)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No go links yet")
                .font(.headline)
            Text("Tap + to add your first go link.\nThen type **go/linkname** in any browser.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No results for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            // Port conflict warning
            if let conflict = setup.diagnostics?.port80Process,
               conflict != "GoLinks" {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    Text("Port 80 in use by \"\(conflict)\" – go links won't work until it's stopped.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))

                Divider()
            }

            HStack(spacing: 6) {
                let fullyActive = setup.hostsConfigured && setup.pfActiveInKernel
                Circle()
                    .fill(fullyActive ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(fullyActive
                     ? "Active – \(store.links.count) link\(store.links.count == 1 ? "" : "s")"
                     : "Setup required")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Setup") { SetupPanel.shared.show() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)

                Text("·").foregroundColor(.secondary).font(.caption)

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .onAppear {
            setup.refresh()
            setup.runDiagnostics()
        }
    }
}
