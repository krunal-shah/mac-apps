import SwiftUI
import AppKit

struct PastesToolView: View {
    @EnvironmentObject private var store: PasteStore
    @EnvironmentObject private var setup: SetupManager
    @EnvironmentObject private var clipboardMonitor: ClipboardMonitor

    @State private var screen: Screen = .list
    @State private var searchText = ""

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

    var body: some View {
        VStack(spacing: 0) {
            toolBar
            Divider()
            mainContent
        }
    }

    private var toolBar: some View {
        HStack(spacing: 10) {
            if screen.isEditing {
                ToolIconButton(systemName: "chevron.left", help: "Back") {
                    screen = .list
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(titleText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color(NSColor.windowBackgroundColor))
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
            return "Clipboard history on \(AppConfig.hostName)/\(AppConfig.pastePath)"
        case .edit(let paste):
            return "\(AppConfig.hostName)/\(AppConfig.pastePath)/\(paste.id)"
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
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredPastes) { paste in
                        PasteRow(
                            paste: paste,
                            onEdit: { screen = .edit(paste) },
                            onDelete: { store.delete(paste) }
                        )

                        if paste.id != filteredPastes.last?.id {
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
            EmptyToolState(icon: "doc.on.clipboard", title: "No Pastes", detail: "Copy text anywhere to add it here.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            StatusDot(color: setup.hostsConfigured && setup.pfActiveInKernel && clipboardMonitor.isRunning ? .green : .orange)

            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                if let url = URL(string: "https://\(AppConfig.hostName)/\(AppConfig.pastePath)") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open", systemImage: "safari")
            }
            .font(.caption)
            .buttonStyle(.plain)
            .disabled(!setup.hostsConfigured || !setup.pfActiveInKernel)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Color(NSColor.controlBackgroundColor))
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
