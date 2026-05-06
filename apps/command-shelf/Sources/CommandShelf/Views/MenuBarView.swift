import SwiftUI
import AppKit

enum AppTool: String, CaseIterable, Identifiable {
    case pastes
    case links

    var id: String { rawValue }

    var title: String {
        switch self {
        case .links:    return "Links"
        case .pastes:   return "Pastes"
        }
    }

    var icon: String {
        switch self {
        case .links:    return "link"
        case .pastes:   return "doc.on.clipboard"
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
        HStack(spacing: 0) {
            sideRail

            toolContent
                .frame(width: AppTheme.menuWidth - AppTheme.railWidth)
        }
        .frame(width: AppTheme.menuWidth, height: AppTheme.menuHeight, alignment: .top)
        .background(AppTheme.shelfBase)
        .preferredColorScheme(.light)
        .background(
            MenuWindowActivationObserver {
                resetForMenuOpen()
            }
            .frame(width: 0, height: 0)
        )
        .animation(AppTheme.selectAnimation, value: screen)
    }

    // MARK: Rail

    private var sideRail: some View {
        VStack(spacing: AppTheme.spacing6) {
            Spacer().frame(height: AppTheme.spacing12)

            ForEach(AppTool.allCases) { tool in
                RailItem(
                    icon: tool.icon,
                    label: tool.title,
                    isActive: screen == .tool(tool)
                ) {
                    selectedTool = tool
                    screen = .tool(tool)
                }
            }

            Spacer()

            RailItem(
                icon: "slider.horizontal.3",
                label: "Setup",
                isActive: screen == .setup
            ) {
                screen = .setup
            }

            RailItem(
                icon: "power",
                label: "Quit",
                isActive: false
            ) {
                NSApplication.shared.terminate(nil)
            }

            Spacer().frame(height: AppTheme.spacing12)
        }
        .frame(width: AppTheme.railWidth, height: AppTheme.menuHeight)
        .background(AppTheme.shelfRail)
    }

    // MARK: Content

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
