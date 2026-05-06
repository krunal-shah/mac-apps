import SwiftUI
import AppKit

struct LinksToolView: View {
    let onSwitchTool: (Int) -> Void

    @EnvironmentObject private var store: GoLinkStore
    @EnvironmentObject private var setup: SetupManager

    @State private var screen: Screen = .list
    @State private var searchText = ""
    @State private var selectedLinkID: UUID?
    @State private var copiedLinkID: UUID?
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

    private var filteredLinkIDs: [UUID] {
        filteredLinks.map(\.id)
    }

    private var selectedLink: GoLink? {
        filteredLinks.first { $0.id == selectedLinkID }
    }

    var body: some View {
        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.shelfBase)
            .background(
                KeyboardCaptureView(focusToken: focusToken, onKeyDown: handleKeyDown)
                    .frame(width: 0, height: 0)
            )
            .onAppear {
                normalizeSelection()
                focusToken += 1
            }
            .onChange(of: filteredLinkIDs) { _ in
                normalizeSelection()
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch screen {
        case .list:
            listContent
        case .add:
            VStack(spacing: 0) {
                editToolBar(title: "New link", subtitle: "")
                AddEditLinkView(mode: .add) {
                    screen = .list
                }
                .environmentObject(store)
            }
        case .edit(let link):
            VStack(spacing: 0) {
                editToolBar(title: "\(AppConfig.hostName)/\(link.shortName)", subtitle: "")
                AddEditLinkView(mode: .edit(link)) {
                    screen = .list
                }
                .environmentObject(store)
            }
        }
    }

    private func editToolBar(title: String, subtitle: String) -> some View {
        HStack(spacing: AppTheme.spacing10) {
            ToolIconButton(systemName: "chevron.left", help: "Back", size: AppTheme.controlSize) {
                screen = .list
            }

            Text(title)
                .font(AppTheme.sans(15, weight: .semibold))
                .foregroundStyle(AppTheme.shelfInk)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: AppTheme.headerHeight)
        .background(AppTheme.shelfBase)
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            listControls
            linkContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var listControls: some View {
        HStack(spacing: AppTheme.spacing10) {
            SearchField(text: $searchText, placeholder: "Search links")

            Button {
                screen = .add
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.shelfInk)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(AppTheme.shelfAccentSoft)
                    )
            }
            .buttonStyle(.plain)
            .help("New link")
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: AppTheme.listControlsHeight)
        .background(AppTheme.shelfBase)
    }

    @ViewBuilder
    private var linkContent: some View {
        if store.links.isEmpty {
            emptyState
        } else if filteredLinks.isEmpty {
            EmptyToolState(icon: "magnifyingglass", title: "No matches", detail: "No links match your search.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredLinks) { link in
                            GoLinkRow(
                                link: link,
                                isSelected: link.id == selectedLinkID,
                                isCopied: copiedLinkID == link.id,
                                onSelect: { select(link) },
                                onOpen: { open(link) },
                                onCopy: { copy(link) },
                                onEdit: { screen = .edit(link) },
                                onDelete: { delete(link) }
                            )
                            .id(link.id)
                        }
                    }
                    .padding(.horizontal, AppTheme.spacing8)
                    .padding(.vertical, AppTheme.spacing6)
                }
                .onChange(of: selectedLinkID) { id in
                    guard let id else { return }
                    withAnimation(AppTheme.selectAnimation) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacing16) {
            EmptyToolState(icon: "link", title: "No links yet", detail: "Add your first shortcut.")
            Button {
                screen = .add
            } label: {
                HStack(spacing: AppTheme.spacing6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                    Text("Add link")
                        .font(AppTheme.sans(12, weight: .medium))
                }
                .padding(.horizontal, AppTheme.spacing12)
                .padding(.vertical, AppTheme.spacing8)
                .foregroundStyle(AppTheme.shelfInk)
                .background(
                    Capsule(style: .continuous).fill(AppTheme.shelfAccentSoft)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: AppTheme.spacing12) {
            KbdGlyph(symbol: "↵", label: "Open")
            KbdGlyph(symbol: "C", label: "Copy")
            KbdGlyph(symbol: "⌘⌫", label: "Delete")

            Spacer()

            StatusDot(color: setupHealthy ? AppTheme.shelfReady : AppTheme.shelfWarn)

            Text(statusText)
                .font(AppTheme.sans(11, weight: .regular))
                .foregroundStyle(AppTheme.shelfInkTertiary)
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: AppTheme.footerHeight)
    }

    private var setupHealthy: Bool {
        setup.hostsConfigured && setup.pfActiveInKernel
    }

    private var statusText: String {
        if setupHealthy { return "Ready" }
        if setup.hostsConfigured && setup.pfConfigured { return "Refresh setup" }
        return "Setup required"
    }

    // MARK: Keyboard

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard screen == .list else { return false }

        switch event.keyCode {
        case 123:  // left
            onSwitchTool(-1)
            return true
        case 124:  // right
            onSwitchTool(1)
            return true
        case 125:  // down
            moveSelection(by: 1)
            return true
        case 126:  // up
            moveSelection(by: -1)
            return true
        case 36, 76:  // return → open
            openSelected()
            return true
        case 53:  // esc
            if !searchText.isEmpty {
                searchText = ""
                return true
            }
            NSApp.keyWindow?.close()
            return true
        case 51:  // backspace — search edit, or delete row when cmd held
            if event.modifierFlags.contains(.command) {
                deleteSelected()
                return true
            }
            if !searchText.isEmpty {
                searchText.removeLast()
                return true
            }
            return true
        case 117:  // forward delete → delete row
            deleteSelected()
            return true
        default:
            return interceptShortcuts(from: event) || appendSearchText(from: event)
        }
    }

    private func interceptShortcuts(from event: NSEvent) -> Bool {
        // Shortcuts that fire only when the search field is empty so plain letters can still type
        guard searchText.isEmpty else { return false }
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return false }
        switch characters {
        case "c":
            copySelected()
            return true
        case "e":
            editSelected()
            return true
        default:
            return false
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

    private func normalizeSelection() {
        guard !filteredLinks.isEmpty else {
            selectedLinkID = nil
            return
        }
        if let selectedLinkID, filteredLinks.contains(where: { $0.id == selectedLinkID }) {
            return
        }
        selectedLinkID = filteredLinks.first?.id
    }

    private func select(_ link: GoLink) {
        selectedLinkID = link.id
        focusToken += 1
    }

    private func moveSelection(by offset: Int) {
        guard !filteredLinks.isEmpty else { return }
        let currentIndex = selectedLinkID.flatMap { id in
            filteredLinks.firstIndex { $0.id == id }
        } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), filteredLinks.count - 1)
        selectedLinkID = filteredLinks[nextIndex].id
    }

    private func openSelected() {
        normalizeSelection()
        guard let selectedLink else { return }
        open(selectedLink)
    }

    private func copySelected() {
        normalizeSelection()
        guard let selectedLink else { return }
        copy(selectedLink)
    }

    private func editSelected() {
        normalizeSelection()
        guard let selectedLink else { return }
        screen = .edit(selectedLink)
    }

    private func deleteSelected() {
        normalizeSelection()
        guard let selectedLink else { return }
        delete(selectedLink)
    }

    private func open(_ link: GoLink) {
        if let url = URL(string: "http://\(AppConfig.hostName)/\(link.shortName)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func copy(_ link: GoLink) {
        Clipboard.copy("http://\(AppConfig.hostName)/\(link.shortName)")
        copiedLinkID = link.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if copiedLinkID == link.id {
                copiedLinkID = nil
            }
        }
    }

    private func delete(_ link: GoLink) {
        store.delete(link)
        if selectedLinkID == link.id {
            selectedLinkID = nil
            normalizeSelection()
        }
    }
}
