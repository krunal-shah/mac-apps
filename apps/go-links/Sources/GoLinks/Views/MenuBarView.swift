import SwiftUI
import AppKit

enum AppTool: String, CaseIterable, Identifiable {
    case pastes
    case links

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

private enum MenuScreen: Equatable {
    case tool(AppTool)
    case setup
}

struct MenuBarView: View {
    @EnvironmentObject private var links: GoLinkStore
    @EnvironmentObject private var pastes: PasteStore

    @State private var selectedTool: AppTool = .pastes
    @State private var screen: MenuScreen = .tool(.pastes)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if screen != .setup {
                toolSwitcher
                Divider()
            }
            toolContent
        }
        .frame(width: 560, height: 660)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: AppTheme.spacing12) {
            if screen == .setup {
                ToolIconButton(systemName: "chevron.left", help: "Back") {
                    screen = .tool(selectedTool)
                }
            } else {
                Image(systemName: selectedTool.icon)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: AppTheme.controlSize, height: AppTheme.controlSize)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                Text(headerTitle)
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if screen != .setup {
                ToolIconButton(systemName: "gearshape", help: "Settings") {
                    screen = .setup
                }
            }

            ToolIconButton(systemName: "power", help: "Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, AppTheme.spacing16)
        .padding(.vertical, AppTheme.spacing12)
        .background(AppTheme.appBackground)
    }

    private var headerTitle: String {
        switch screen {
        case .setup:
            return "Settings"
        case .tool:
            return AppConfig.suiteName
        }
    }

    private var headerSubtitle: String {
        switch screen {
        case .setup:
            return "System setup and diagnostics"
        case .tool(let tool):
            switch tool {
            case .links:
                return "\(links.links.count) link\(links.links.count == 1 ? "" : "s")"
            case .pastes:
                return "\(pastes.pastes.count) paste\(pastes.pastes.count == 1 ? "" : "s")"
            }
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
        .onChange(of: selectedTool) { tool in
            screen = .tool(tool)
        }
        .padding(.horizontal, AppTheme.spacing16)
        .padding(.vertical, AppTheme.spacing12)
        .background(AppTheme.groupedBackground)
    }

    @ViewBuilder
    private var toolContent: some View {
        switch screen {
        case .setup:
            SetupView {
                screen = .tool(selectedTool)
            }
        case .tool(let tool):
            switch tool {
            case .links:
                LinksToolView()
            case .pastes:
                PastesToolView()
            }
        }
    }
}
