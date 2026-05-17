import SwiftUI
import AppKit

struct PaletteView: View {
    @EnvironmentObject private var controller: PaletteController
    @EnvironmentObject private var goLinks: GoLinkStore
    @EnvironmentObject private var pastes: PasteStore
    @EnvironmentObject private var triggers: TriggerStore

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var keyMonitor: Any?

    private var results: [PaletteResult] {
        PaletteSearch.rank(
            query: query,
            goLinks: goLinks.links,
            pastes: pastes.pastes,
            triggers: triggers.triggers
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            queryField
            Divider().background(AppTheme.shelfRule)
            resultsArea
            footer
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusPanel, style: .continuous)
                .fill(.thickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusPanel, style: .continuous)
                .strokeBorder(AppTheme.shelfRule, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusPanel, style: .continuous))
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
        .onChange(of: controller.isVisible) { visible in
            if visible {
                query = ""
                selectedIndex = 0
            }
        }
        .onChange(of: query) { _ in
            selectedIndex = 0
        }
    }

    // MARK: - Query field

    private var queryField: some View {
        HStack(spacing: AppTheme.spacing12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.shelfInkTertiary)

            TextField("Search or trigger…", text: $query)
                .textFieldStyle(.plain)
                .font(AppTheme.sans(18, weight: .regular))
                .foregroundStyle(AppTheme.shelfInk)
        }
        .padding(.horizontal, AppTheme.spacing20)
        .frame(height: 56)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsArea: some View {
        if let status = controller.actionStatus {
            StatusBanner(status: status)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(slots) { slot in
                            switch slot {
                            case .header(let title):
                                SectionHeader(title: title)
                            case .row(let result, let flatIndex):
                                PaletteResultRow(
                                    result: result,
                                    isSelected: flatIndex == clampedSelectedIndex
                                )
                                .id(result.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedIndex = flatIndex
                                    activateSelected()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.spacing6)
                    .padding(.vertical, AppTheme.spacing6)
                }
                .onChange(of: clampedSelectedIndex) { idx in
                    guard idx < results.count else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(results[idx].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacing8) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(AppTheme.shelfInkMuted)
            Text(query.isEmpty ? "Nothing here yet" : "No matches")
                .font(AppTheme.sans(13, weight: .medium))
                .foregroundStyle(AppTheme.shelfInkSecondary)
            Text(query.isEmpty
                 ? "Add a go-link or copy something to your clipboard."
                 : "Try a different query.")
                .font(AppTheme.sans(11, weight: .regular))
                .foregroundStyle(AppTheme.shelfInkTertiary)
        }
        .padding(.vertical, AppTheme.spacing20)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: AppTheme.spacing12) {
            if let selected = currentResult {
                KbdGlyph(symbol: "↵", label: selected.kindLabel)
            } else {
                KbdGlyph(symbol: "↵", label: "Run")
            }
            Spacer()
            KbdGlyph(symbol: "↑↓", label: "Navigate")
            KbdGlyph(symbol: "⎋", label: "Dismiss")
        }
        .padding(.horizontal, AppTheme.spacing12)
        .frame(height: AppTheme.footerHeight)
        .background(AppTheme.shelfRail.opacity(0.4))
    }

    // MARK: - Slots (interleaved headers + rows)

    private enum Slot: Identifiable {
        case header(String)
        case row(PaletteResult, flatIndex: Int)

        var id: String {
            switch self {
            case .header(let title): return "hdr:\(title)"
            case .row(let result, _): return "row:\(result.id)"
            }
        }
    }

    private var slots: [Slot] {
        // With a query active we always show headers — they help disambiguate
        // a trigger keyword match from a same-letter go-link/paste match.
        var out: [Slot] = []
        var lastKind: String? = nil
        for (idx, result) in results.enumerated() {
            let kind = result.sectionTitle
            if kind != lastKind {
                out.append(.header(kind))
                lastKind = kind
            }
            out.append(.row(result, flatIndex: idx))
        }
        return out
    }

    // MARK: - Selection

    private var clampedSelectedIndex: Int {
        guard !results.isEmpty else { return 0 }
        return max(0, min(selectedIndex, results.count - 1))
    }

    private var currentResult: PaletteResult? {
        guard !results.isEmpty else { return nil }
        return results[clampedSelectedIndex]
    }

    private func activateSelected() {
        // Suppress accidental re-fire while an async action is in flight.
        if case .running = controller.actionStatus { return }
        guard let target = currentResult else { return }
        controller.activate(target)
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Carbon virtual key codes — stable across keyboard layouts.
            switch event.keyCode {
            case 125: // down arrow
                if results.isEmpty { return event }
                selectedIndex = min(clampedSelectedIndex + 1, results.count - 1)
                return nil
            case 126: // up arrow
                if results.isEmpty { return event }
                selectedIndex = max(clampedSelectedIndex - 1, 0)
                return nil
            case 36, 76: // return / numpad enter
                activateSelected()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }
}

// MARK: - Status banner

private struct StatusBanner: View {
    let status: ActionStatus

    var body: some View {
        VStack(spacing: AppTheme.spacing10) {
            Image(systemName: status.symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(tint)
            Text(status.message)
                .font(AppTheme.sans(13, weight: .medium))
                .foregroundStyle(AppTheme.shelfInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.spacing20)
        }
        .padding(.vertical, AppTheme.spacing20)
    }

    private var tint: Color {
        switch status {
        case .running: return AppTheme.shelfInkSecondary
        case .success: return AppTheme.shelfReady
        case .failure: return AppTheme.shelfDanger
        }
    }
}

// MARK: - Section header

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppTheme.sans(10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(AppTheme.shelfInkTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.spacing10)
            .padding(.top, AppTheme.spacing10)
            .padding(.bottom, 4)
    }
}

// MARK: - Result row

private struct PaletteResultRow: View {
    let result: PaletteResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppTheme.spacing10) {
            Image(systemName: result.systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? AppTheme.shelfInk : AppTheme.shelfInkTertiary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                        .fill(isSelected ? AppTheme.shelfAccentSoft : AppTheme.shelfRule.opacity(0.4))
                )

            VStack(alignment: .leading, spacing: 0) {
                Text(result.title)
                    .font(AppTheme.sans(13, weight: .medium))
                    .foregroundStyle(AppTheme.shelfInk)
                    .lineLimit(1)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(AppTheme.sans(11, weight: .regular))
                        .foregroundStyle(AppTheme.shelfInkTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: AppTheme.spacing8)

            if isSelected {
                KbdGlyph(symbol: "↵", label: result.kindLabel)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, AppTheme.spacing10)
        .padding(.vertical, 6)
        .frame(minHeight: 38)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(isSelected ? AppTheme.shelfAccentSoft : Color.clear)
        )
    }
}
