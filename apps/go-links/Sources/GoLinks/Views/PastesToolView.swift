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

    private var editToolBar: some View {
        HStack(spacing: AppTheme.spacing12) {
            ToolIconButton(systemName: "chevron.left", help: "Back", size: AppTheme.compactControlSize) {
                screen = .list
            }

            VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                Text("Edit Paste")
                    .font(.subheadline.weight(.semibold))
                Text(editSubtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: 44)
        .background(AppTheme.appBackground)
    }

    private var editSubtitleText: String {
        guard case .edit(let paste) = screen else { return "" }
        return paste.title
    }

    @ViewBuilder
    private var mainContent: some View {
        switch screen {
        case .list:
            listContent
        case .edit(let paste):
            VStack(spacing: 0) {
                editToolBar
                Divider()
                AddEditPasteView(mode: .edit(paste)) {
                    screen = .list
                }
                .environmentObject(store)
            }
        }
    }

    private var listContent: some View {
        ZStack {
            VStack(spacing: 0) {
                listControls
                Divider()
                pasteContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.16), value: isPreviewing)
    }

    private var listControls: some View {
        HStack(spacing: AppTheme.spacing8) {
            SearchField(text: $searchText, placeholder: "Search pastes")
        }
        .padding(.horizontal, AppTheme.spacing12)
        .padding(.vertical, AppTheme.spacing8)
        .background(AppTheme.appBackground)
    }

    @ViewBuilder
    private var pasteContent: some View {
        if store.pastes.isEmpty {
            emptyState
        } else if filteredPastes.isEmpty {
            EmptyToolState(icon: "magnifyingglass", title: "No Matches", detail: "No pastes match your search.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppTheme.spacing4) {
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
                    .padding(AppTheme.spacing8)
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
        .padding(AppTheme.spacing20)
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

private struct PastePreviewPanel: View {
    let paste: PasteItem
    let isCopied: Bool
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppTheme.spacing12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: AppTheme.controlSize, height: AppTheme.controlSize)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                    Text(titleText)
                        .font(.headline)
                        .lineLimit(1)
                    Text(relativeUpdatedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ToolIconButton(systemName: isCopied ? "checkmark" : "doc.on.doc", help: "Copy Text", size: AppTheme.compactControlSize, action: onCopy)
                ToolIconButton(systemName: "xmark", help: "Close Preview", size: AppTheme.compactControlSize, action: onClose)
            }
            .padding(.horizontal, AppTheme.spacing16)
            .frame(height: 56)

            Divider()

            ScrollView {
                Text(displayBody)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(AppTheme.spacing16)
            }
            .background(AppTheme.contentBackground)
        }
        .frame(width: 424, height: 360)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.separator.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
    }

    private var titleText: String {
        let title = firstLine
        return title.isEmpty ? "Untitled Paste" : title
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
