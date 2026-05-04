import SwiftUI
import AppKit

enum AppTool: String, CaseIterable, Identifiable {
    case links
    case pastes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .links:
            return "Links"
        case .pastes:
            return "Pastes"
        }
    }

    var icon: String {
        switch self {
        case .links:
            return "arrow.triangle.branch"
        case .pastes:
            return "doc.text"
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var links: GoLinkStore
    @EnvironmentObject private var pastes: PasteStore

    @State private var selectedTool: AppTool = .links

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            toolSwitcher
            Divider()
            toolContent
        }
        .frame(width: 500, height: 600)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedTool.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(AppConfig.suiteName)
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            ToolIconButton(systemName: "gearshape", help: "Setup") {
                SetupPanel.shared.show()
            }

            ToolIconButton(systemName: "power", help: "Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var headerSubtitle: String {
        switch selectedTool {
        case .links:
            return "\(links.links.count) link\(links.links.count == 1 ? "" : "s")"
        case .pastes:
            return "\(pastes.pastes.count) paste\(pastes.pastes.count == 1 ? "" : "s")"
        }
    }

    private var toolSwitcher: some View {
        Picker("Tool", selection: $selectedTool) {
            ForEach(AppTool.allCases) { tool in
                Label(tool.title, systemImage: tool.icon)
                    .tag(tool)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private var toolContent: some View {
        switch selectedTool {
        case .links:
            LinksToolView()
        case .pastes:
            PastesToolView()
        }
    }
}
