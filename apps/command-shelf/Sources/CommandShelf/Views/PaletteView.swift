import SwiftUI
import AppKit

struct PaletteView: View {
    @EnvironmentObject private var controller: PaletteController
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            queryField
            Divider().background(AppTheme.shelfRule)
            placeholderBody
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusPanel, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusPanel, style: .continuous)
                .strokeBorder(AppTheme.shelfRule, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusPanel, style: .continuous))
    }

    private var queryField: some View {
        HStack(spacing: AppTheme.spacing12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.shelfInkTertiary)

            TextField("Search or trigger…", text: $query)
                .textFieldStyle(.plain)
                .font(AppTheme.sans(18, weight: .regular))
                .foregroundStyle(AppTheme.shelfInk)
                .focusable(true)
        }
        .padding(.horizontal, AppTheme.spacing20)
        .frame(height: 56)
    }

    private var placeholderBody: some View {
        VStack(spacing: AppTheme.spacing8) {
            Image(systemName: "command")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(AppTheme.shelfInkMuted)
            Text("Palette online")
                .font(AppTheme.sans(13, weight: .medium))
                .foregroundStyle(AppTheme.shelfInkSecondary)
            Text("Results coming next.")
                .font(AppTheme.sans(11, weight: .regular))
                .foregroundStyle(AppTheme.shelfInkTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, AppTheme.spacing20)
    }
}
