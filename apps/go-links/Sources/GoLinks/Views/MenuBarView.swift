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
            return "link"
        case .pastes:
            return "doc.on.clipboard"
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
    @State private var menuOpenToken = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            toolContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 520, height: 560, alignment: .top)
        .background(Color(NSColor.windowBackgroundColor))
        .background(
            MenuWindowActivationObserver {
                resetForMenuOpen()
            }
            .frame(width: 0, height: 0)
        )
        .animation(.easeInOut(duration: 0.16), value: screen)
    }

    private var header: some View {
        HStack(spacing: AppTheme.spacing12) {
            if screen == .setup {
                ToolIconButton(systemName: "chevron.left", help: "Back", size: AppTheme.compactControlSize) {
                    screen = .tool(selectedTool)
                }
            } else {
                Image(systemName: selectedTool.icon)
                    .font(.body)
                    .foregroundStyle(.tint)
                    .frame(width: AppTheme.compactControlSize, height: AppTheme.compactControlSize)
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
                compactToolSwitcher

                ToolIconButton(systemName: "gearshape", help: "Settings", size: AppTheme.compactControlSize) {
                    screen = .setup
                }
            }

            ToolIconButton(systemName: "power", help: "Quit", size: AppTheme.compactControlSize) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: 52)
        .background(AppTheme.appBackground)
    }

    private var headerTitle: String {
        switch screen {
        case .setup:
            return "Settings"
        case .tool(let tool):
            return tool.title
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

    private var compactToolSwitcher: some View {
        Picker("Tool", selection: $selectedTool) {
            ForEach(AppTool.allCases) { tool in
                Text(tool.title)
                    .tag(tool)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .labelsHidden()
        .frame(width: 152)
        .onChange(of: selectedTool) { tool in
            withAnimation(.easeInOut(duration: 0.16)) {
                screen = .tool(tool)
            }
        }
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
                LinksToolView(onSwitchTool: switchTool)
            case .pastes:
                PastesToolView(openToken: menuOpenToken, onSwitchTool: switchTool)
            }
        }
    }

    private func resetForMenuOpen() {
        selectedTool = .pastes
        screen = .tool(.pastes)
        menuOpenToken += 1
    }

    private func switchTool(by offset: Int) {
        guard screen != .setup,
              let currentIndex = AppTool.allCases.firstIndex(of: selectedTool)
        else { return }

        let count = AppTool.allCases.count
        let nextIndex = (currentIndex + offset + count) % count
        let nextTool = AppTool.allCases[nextIndex]
        selectedTool = nextTool
        screen = .tool(nextTool)
    }
}
