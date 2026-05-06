import SwiftUI
import AppKit

struct PastesToolView: View {
    let openToken: Int
    let onSwitchTool: (Int) -> Void

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
            .onChange(of: openToken) { _ in
                resetForMenuOpen()
            }
            .onChange(of: filteredPasteIDs) { _ in
                normalizeSelection()
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch screen {
        case .list:
            listContent
        case .edit(let paste):
            VStack(spacing: 0) {
                editToolBar
                Divider().background(AppTheme.shelfRule)
                AddEditPasteView(mode: .edit(paste)) {
                    screen = .list
                }
                .environmentObject(store)
            }
        }
    }

    private var editToolBar: some View {
        HStack(spacing: AppTheme.spacing10) {
            ToolIconButton(systemName: "chevron.left", help: "Back", size: AppTheme.controlSize) {
                screen = .list
            }

            Text(editTitleText)
                .font(AppTheme.sans(15, weight: .semibold))
                .foregroundStyle(AppTheme.shelfInk)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: AppTheme.headerHeight)
        .background(AppTheme.shelfBase)
    }

    private var editTitleText: String {
        guard case .edit(let paste) = screen else { return "Edit paste" }
        return paste.title.isEmpty ? "Edit paste" : paste.title
    }

    private var listContent: some View {
        ZStack {
            VStack(spacing: 0) {
                listControls
                pasteContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if isPreviewing, let selectedPaste {
                PastePreviewPanel(
                    paste: selectedPaste,
                    isCopied: copiedPasteID == selectedPaste.id,
                    onCopy: { copy(selectedPaste) },
                    onClose: { isPreviewing = false }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.16), value: isPreviewing)
    }

    private var listControls: some View {
        HStack(spacing: AppTheme.spacing8) {
            SearchField(text: $searchText, placeholder: "Search pastes")
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: AppTheme.listControlsHeight)
        .background(AppTheme.shelfBase)
    }

    @ViewBuilder
    private var pasteContent: some View {
        if store.pastes.isEmpty {
            emptyState
        } else if filteredPastes.isEmpty {
            EmptyToolState(icon: "magnifyingglass", title: "No matches", detail: "No pastes match your search.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
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
                    .padding(.horizontal, AppTheme.spacing8)
                    .padding(.vertical, AppTheme.spacing6)
                }
                .onChange(of: selectedPasteID) { id in
                    guard let id else { return }
                    withAnimation(AppTheme.selectAnimation) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        EmptyToolState(icon: "doc.on.clipboard", title: "No pastes yet", detail: "Copy text anywhere to add it here.")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: AppTheme.spacing12) {
            KbdGlyph(symbol: "↵", label: "Copy")
            KbdGlyph(symbol: "␣", label: "Preview")
            KbdGlyph(symbol: "⌘⌫", label: "Delete")

            Spacer()

            StatusDot(color: setupHealthy ? AppTheme.shelfReady : AppTheme.shelfWarn)
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: AppTheme.footerHeight)
    }

    private var setupHealthy: Bool {
        setup.hostsConfigured && setup.pfActiveInKernel && clipboardMonitor.isRunning
    }

    // MARK: Keyboard

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard screen == .list else { return false }

        switch event.keyCode {
        case 123:  // left arrow
            onSwitchTool(-1)
            return true
        case 124:  // right arrow
            onSwitchTool(1)
            return true
        case 125:  // down arrow
            moveSelection(by: 1)
            return true
        case 126:  // up arrow
            moveSelection(by: -1)
            return true
        case 49:  // space
            togglePreviewForSelection()
            return true
        case 36, 76:  // return
            copySelectedPaste()
            return true
        case 117, 51:  // delete forward / backward
            if event.keyCode == 117 || event.modifierFlags.contains(.command) {
                deleteSelected()
                return true
            }
            if !searchText.isEmpty {
                searchText.removeLast()
                return true
            }
            return true
        case 53:  // esc
            if isPreviewing {
                isPreviewing = false
                return true
            }
            if !searchText.isEmpty {
                searchText = ""
                return true
            }
            NSApp.keyWindow?.close()
            return true
        default:
            return appendSearchText(from: event)
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

    private func resetForMenuOpen() {
        screen = .list
        searchText = ""
        selectedPasteID = nil
        isPreviewing = false
        copiedPasteID = nil
        normalizeSelection()
        focusToken += 1
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

        guard event.keyCode != 49 else { return false }

        searchText.append(characters)
        isPreviewing = false
        return true
    }

    private func copySelectedPaste() {
        normalizeSelection()
        guard let selectedPaste else { return }
        copy(selectedPaste)
    }

    private func deleteSelected() {
        guard let selectedPaste else { return }
        delete(selectedPaste)
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
}

// MARK: - Preview panel

private struct PastePreviewPanel: View {
    let paste: PasteItem
    let isCopied: Bool
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppTheme.spacing10) {
                Text(titleText)
                    .font(AppTheme.sans(15, weight: .semibold))
                    .foregroundStyle(AppTheme.shelfInk)
                    .lineLimit(1)

                Text(relativeUpdatedText)
                    .font(AppTheme.sans(11, weight: .regular))
                    .foregroundStyle(AppTheme.shelfInkTertiary)

                Spacer()

                ToolIconButton(systemName: isCopied ? "checkmark" : "doc.on.doc", help: "Copy", tint: isCopied ? AppTheme.shelfReady : AppTheme.shelfInkSecondary, size: AppTheme.compactControlSize, action: onCopy)
                ToolIconButton(systemName: "xmark", help: "Close", size: AppTheme.compactControlSize, action: onClose)
            }
            .padding(.horizontal, AppTheme.spacing16)
            .frame(height: 50)

            ScrollView {
                Text(displayBody)
                    .font(AppTheme.mono(12))
                    .foregroundStyle(AppTheme.shelfInk)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(AppTheme.spacing16)
            }
            .background(AppTheme.shelfPaper)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous))
            .padding(.horizontal, AppTheme.spacing10)
            .padding(.bottom, AppTheme.spacing10)
        }
        .frame(width: 440, height: 400)
        .background(AppTheme.shelfBase)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusPanel, style: .continuous))
        .shadow(color: AppTheme.shelfInk.opacity(0.14), radius: 28, y: 14)
        .shadow(color: AppTheme.shelfInk.opacity(0.06), radius: 4, y: 1)
        .accessibilityElement(children: .contain)
    }

    private var titleText: String {
        let title = firstLine
        return title.isEmpty ? "Untitled" : title
    }

    private var displayBody: String {
        paste.body.isEmpty ? "Empty paste" : paste.body
    }

    private var firstLine: String {
        paste.body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var relativeUpdatedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: paste.updatedAt, relativeTo: Date())
    }
}
