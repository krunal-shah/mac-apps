import SwiftUI
import AppKit

struct PastesToolView: View {
    @EnvironmentObject private var store: PasteStore
    @EnvironmentObject private var setup: SetupManager
    @EnvironmentObject private var clipboardMonitor: ClipboardMonitor

    @State private var screen: Screen = .list
    @State private var searchText = ""
    @State private var selectedPasteID: String?
    @State private var isPreviewing = false
    @State private var copiedPasteID: String?
    @State private var focusToken = 0

    private enum Screen: Equatable {
        case list
        case edit(PasteItem)

        var isEditing: Bool {
            if case .list = self { return false }
            return true
        }
    }

    private var filteredPastes: [PasteItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.pastes }
        return store.pastes.filter {
            $0.id.contains(query)
                || $0.title.lowercased().contains(query)
                || $0.body.lowercased().contains(query)
        }
    }

    private var filteredPasteIDs: [String] {
        filteredPastes.map(\.id)
    }

    private var selectedPaste: PasteItem? {
        filteredPastes.first { $0.id == selectedPasteID }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolBar
            Divider()
            mainContent
        }
        .background(
            KeyboardCaptureView(focusToken: focusToken, onKeyDown: handleKeyDown)
                .frame(width: 0, height: 0)
        )
        .onAppear {
            normalizeSelection()
            focusToken += 1
        }
        .onChange(of: filteredPasteIDs) { _ in
            normalizeSelection()
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
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: 48)
        .background(AppTheme.appBackground)
    }

    private var titleText: String {
        switch screen {
        case .list:
            return "Pastebin"
        case .edit:
            return "Edit Paste"
        }
    }

    private var subtitleText: String {
        switch screen {
        case .list:
            return "Clipboard history"
        case .edit(let paste):
            return paste.title
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch screen {
        case .list:
            VStack(spacing: 0) {
                searchBar
                Divider()
                pasteContent
                Divider()
                footer
            }
        case .edit(let paste):
            AddEditPasteView(mode: .edit(paste)) {
                screen = .list
            }
            .environmentObject(store)
        }
    }

    private var searchBar: some View {
        SearchField(text: $searchText, placeholder: "Search pastes")
    }

    @ViewBuilder
    private var pasteContent: some View {
        if store.pastes.isEmpty {
            emptyState
        } else if filteredPastes.isEmpty {
            EmptyToolState(icon: "magnifyingglass", title: "No Matches", detail: "No pastes match your search.")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppTheme.spacing8) {
                        ForEach(filteredPastes) { paste in
                            PasteRow(
                                paste: paste,
                                isSelected: paste.id == selectedPasteID,
                                isPreviewing: isPreviewing && paste.id == selectedPasteID,
                                isCopied: copiedPasteID == paste.id,
                                onSelect: { select(paste) },
                                onPreview: { togglePreview(for: paste) },
                                onCopy: { copy(paste) },
                                onEdit: { screen = .edit(paste) },
                                onDelete: { delete(paste) }
                            )
                            .id(paste.id)
                        }
                    }
                    .padding(AppTheme.spacing12)
                }
                .onChange(of: selectedPasteID) { id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .background(AppTheme.contentBackground)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacing16) {
            EmptyToolState(icon: "doc.on.clipboard", title: "No Pastes", detail: "Copy text anywhere to add it here.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.spacing24)
    }

    private var footer: some View {
        HStack(spacing: AppTheme.spacing8) {
            StatusDot(color: setup.hostsConfigured && setup.pfActiveInKernel && clipboardMonitor.isRunning ? .green : .orange)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(filteredPastes.count) shown")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: 40)
        .background(AppTheme.groupedBackground)
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard screen == .list else { return false }

        switch event.keyCode {
        case 125:
            moveSelection(by: 1)
            return true
        case 126:
            moveSelection(by: -1)
            return true
        case 49:
            togglePreviewForSelection()
            return true
        case 36, 76:
            copySelectedPaste()
            return true
        case 53:
            if isPreviewing {
                isPreviewing = false
                return true
            }
            return false
        default:
            return false
        }
    }

    private func normalizeSelection() {
        guard !filteredPastes.isEmpty else {
            selectedPasteID = nil
            isPreviewing = false
            return
        }

        if let selectedPasteID, filteredPastes.contains(where: { $0.id == selectedPasteID }) {
            return
        }

        selectedPasteID = filteredPastes.first?.id
    }

    private func select(_ paste: PasteItem) {
        selectedPasteID = paste.id
        focusToken += 1
    }

    private func togglePreview(for paste: PasteItem) {
        selectedPasteID = paste.id
        isPreviewing.toggle()
        focusToken += 1
    }

    private func togglePreviewForSelection() {
        normalizeSelection()
        guard selectedPaste != nil else { return }
        isPreviewing.toggle()
    }

    private func moveSelection(by offset: Int) {
        guard !filteredPastes.isEmpty else { return }

        let currentIndex = selectedPasteID.flatMap { id in
            filteredPastes.firstIndex { $0.id == id }
        } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), filteredPastes.count - 1)
        selectedPasteID = filteredPastes[nextIndex].id
    }

    private func copySelectedPaste() {
        normalizeSelection()
        guard let selectedPaste else { return }
        copy(selectedPaste)
    }

    private func copy(_ paste: PasteItem) {
        Clipboard.copy(paste.body)
        copiedPasteID = paste.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if copiedPasteID == paste.id {
                copiedPasteID = nil
            }
        }
    }

    private func delete(_ paste: PasteItem) {
        store.delete(paste)
        if selectedPasteID == paste.id {
            selectedPasteID = nil
            normalizeSelection()
        }
    }

    private var statusText: String {
        guard setup.hostsConfigured && setup.pfActiveInKernel else {
            if setup.hostsConfigured && setup.pfConfigured {
                return "Setup needs refresh"
            }
            return "Setup required"
        }

        if clipboardMonitor.isRunning {
            return "Tracking clipboard"
        } else {
            return "Clipboard tracking stopped"
        }
    }
}
