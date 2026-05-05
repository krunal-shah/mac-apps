import SwiftUI

struct LinksToolView: View {
    @EnvironmentObject private var store: GoLinkStore
    @EnvironmentObject private var setup: SetupManager

    @State private var screen: Screen = .list
    @State private var searchText = ""

    private enum Screen: Equatable {
        case list
        case add
        case edit(GoLink)

        var isEditing: Bool {
            if case .list = self { return false }
            return true
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
            toolBar
            Divider()
            mainContent
        }
    }

    private var toolBar: some View {
        HStack(spacing: AppTheme.spacing12) {
            if screen.isEditing {
                ToolIconButton(systemName: "chevron.left", help: "Back") {
                    screen = .list
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                Text(titleText)
                    .font(.subheadline)
                    .bold()
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !screen.isEditing {
                ToolIconButton(systemName: "plus", help: "Add Link") {
                    screen = .add
                }
            }
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: 48)
        .background(AppTheme.appBackground)
    }

    private var titleText: String {
        switch screen {
        case .list:
            return "Go Links"
        case .add:
            return "Add Link"
        case .edit:
            return "Edit Link"
        }
    }

    private var subtitleText: String {
        switch screen {
        case .list:
            return "Browser shortcuts on \(AppConfig.hostName)"
        case .add:
            return "Create a shortcut"
        case .edit(let link):
            return "\(AppConfig.hostName)/\(link.shortName)"
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch screen {
        case .list:
            VStack(spacing: 0) {
                searchBar
                Divider()
                linkContent
                Divider()
                footer
            }
        case .add:
            AddEditLinkView(mode: .add) {
                screen = .list
            }
            .environmentObject(store)
        case .edit(let link):
            AddEditLinkView(mode: .edit(link)) {
                screen = .list
            }
            .environmentObject(store)
        }
    }

    private var searchBar: some View {
        SearchField(text: $searchText, placeholder: "Search links")
    }

    @ViewBuilder
    private var linkContent: some View {
        if store.links.isEmpty {
            emptyState
        } else if filteredLinks.isEmpty {
            EmptyToolState(icon: "magnifyingglass", title: "No Matches", detail: "No links match your search.")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredLinks) { link in
                        GoLinkRow(
                            link: link,
                            onEdit: { screen = .edit(link) },
                            onDelete: { store.delete(link) }
                        )

                        if link.id != filteredLinks.last?.id {
                            Divider()
                                .padding(.leading, AppTheme.spacing16)
                        }
                    }
                }
            }
            .background(AppTheme.contentBackground)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacing16) {
            EmptyToolState(icon: "link.badge.plus", title: "No Links", detail: "Add your first shortcut.")
            Button {
                screen = .add
            } label: {
                Label("Add Link", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.spacing24)
    }

    private var footer: some View {
        HStack(spacing: AppTheme.spacing8) {
            StatusDot(color: setup.hostsConfigured && setup.pfActiveInKernel ? .green : .orange)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                NSWorkspace.shared.open(AppConfig.httpURL)
            } label: {
                Label("Open", systemImage: "safari")
            }
            .font(.caption)
            .buttonStyle(.plain)
            .disabled(!setup.hostsConfigured || !setup.pfActiveInKernel)
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: 40)
        .background(AppTheme.groupedBackground)
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
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: AppTheme.spacing8, height: AppTheme.spacing8)
    }
}
