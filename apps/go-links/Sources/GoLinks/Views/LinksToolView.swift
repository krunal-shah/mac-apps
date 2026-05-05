import SwiftUI

struct LinksToolView: View {
    let onSwitchTool: (Int) -> Void

    @EnvironmentObject private var store: GoLinkStore
    @EnvironmentObject private var setup: SetupManager

    @State private var screen: Screen = .list
    @State private var searchText = ""
    @State private var focusToken = 0

    private enum Screen: Equatable {
        case list
        case add
        case edit(GoLink)
    }

    private var filteredLinks: [GoLink] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.links }
        return store.links.filter {
            $0.shortName.contains(query) || $0.destinationURL.lowercased().contains(query)
        }
    }

    var body: some View {
        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                KeyboardCaptureView(focusToken: focusToken, onKeyDown: handleKeyDown)
                    .frame(width: 0, height: 0)
            )
            .onAppear {
                focusToken += 1
            }
    }

    private var editToolBar: some View {
        HStack(spacing: AppTheme.spacing12) {
            ToolIconButton(systemName: "chevron.left", help: "Back", size: AppTheme.compactControlSize) {
                screen = .list
            }

            VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                Text(titleText)
                    .font(.subheadline.weight(.semibold))
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: 44)
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
            listContent
        case .add:
            VStack(spacing: 0) {
                editToolBar
                Divider()
                AddEditLinkView(mode: .add) {
                    screen = .list
                }
                .environmentObject(store)
            }
        case .edit(let link):
            VStack(spacing: 0) {
                editToolBar
                Divider()
                AddEditLinkView(mode: .edit(link)) {
                    screen = .list
                }
                .environmentObject(store)
            }
        }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            listControls
            Divider()
            linkContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var listControls: some View {
        HStack(spacing: AppTheme.spacing8) {
            SearchField(text: $searchText, placeholder: "Search links")

            ToolIconButton(
                systemName: "plus",
                help: "Add Link",
                tint: .white,
                background: .accentColor,
                size: AppTheme.compactControlSize
            ) {
                screen = .add
            }
        }
        .padding(.horizontal, AppTheme.spacing12)
        .padding(.vertical, AppTheme.spacing8)
        .background(AppTheme.appBackground)
    }

    @ViewBuilder
    private var linkContent: some View {
        if store.links.isEmpty {
            emptyState
        } else if filteredLinks.isEmpty {
            EmptyToolState(icon: "magnifyingglass", title: "No Matches", detail: "No links match your search.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .padding(AppTheme.spacing20)
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
        .padding(.horizontal, AppTheme.spacing12)
        .frame(height: 32)
        .background(AppTheme.groupedBackground)
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard screen == .list else { return false }

        switch event.keyCode {
        case 123:
            onSwitchTool(-1)
            return true
        case 124:
            onSwitchTool(1)
            return true
        case 53:
            if !searchText.isEmpty {
                searchText = ""
                return true
            }
            return false
        case 51:
            if !searchText.isEmpty {
                searchText.removeLast()
            }
            return true
        default:
            return appendSearchText(from: event)
        }
    }

    private func appendSearchText(from event: NSEvent) -> Bool {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(blockedModifiers).isEmpty,
              let characters = event.characters,
              characters.count == 1,
              let scalar = characters.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar)
        else {
            return false
        }

        searchText.append(characters)
        return true
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
