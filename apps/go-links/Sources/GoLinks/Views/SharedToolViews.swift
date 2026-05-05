import SwiftUI
import AppKit

// MARK: - Theme

enum AppTheme {
    // Spacing scale
    static let spacing2: CGFloat = 2
    static let spacing4: CGFloat = 4
    static let spacing6: CGFloat = 6
    static let spacing8: CGFloat = 8
    static let spacing10: CGFloat = 10
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20

    // Radii — soft, fluid
    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 10
    static let radiusLarge: CGFloat = 14
    static let radiusPanel: CGFloat = 18

    // Layout
    static let menuWidth: CGFloat = 540
    static let menuHeight: CGFloat = 680
    static let railWidth: CGFloat = 52
    static let headerHeight: CGFloat = 48
    static let listControlsHeight: CGFloat = 52
    static let footerHeight: CGFloat = 32
    static let dividerHeight: CGFloat = 1
    static let toolHeight: CGFloat = menuHeight
    static let resultsHeight: CGFloat = menuHeight - listControlsHeight - footerHeight

    // Controls
    static let controlSize: CGFloat = 30
    static let compactControlSize: CGFloat = 26
    static let microControlSize: CGFloat = 22
    static let rowIconWidth: CGFloat = 18

    // Motion
    static let hoverAnimation = Animation.easeOut(duration: 0.18)
    static let selectAnimation = Animation.spring(response: 0.32, dampingFraction: 0.86)

    // Surfaces — neutral paper hierarchy
    static let shelfPaper     = Color(red: 0.988, green: 0.988, blue: 0.988)
    static let shelfBase      = Color(red: 0.957, green: 0.957, blue: 0.957)
    static let shelfTape      = Color(red: 0.929, green: 0.929, blue: 0.929)
    static let shelfRail      = Color(red: 0.902, green: 0.902, blue: 0.906)
    static let shelfHighlight = Color(red: 0.918, green: 0.918, blue: 0.922)

    // Rules — neutral charcoal overlays
    private static let inkRGB = (red: 0.102, green: 0.102, blue: 0.106)
    static let shelfRule       = Color(red: inkRGB.red, green: inkRGB.green, blue: inkRGB.blue).opacity(0.10)
    static let shelfRuleStrong = Color(red: inkRGB.red, green: inkRGB.green, blue: inkRGB.blue).opacity(0.20)

    // Ink — neutral charcoal hierarchy
    static let shelfInk          = Color(red: 0.102, green: 0.102, blue: 0.106)
    static let shelfInkSecondary = Color(red: 0.290, green: 0.290, blue: 0.298)
    static let shelfInkTertiary  = Color(red: 0.510, green: 0.510, blue: 0.522)
    static let shelfInkMuted     = Color(red: 0.710, green: 0.710, blue: 0.722)

    // Accent — no chroma; ink itself is the highlight, layered as tints
    static let shelfAccent       = Color(red: inkRGB.red, green: inkRGB.green, blue: inkRGB.blue)
    static let shelfAccentSoft   = Color(red: inkRGB.red, green: inkRGB.green, blue: inkRGB.blue).opacity(0.08)
    static let shelfAccentEdge   = Color(red: inkRGB.red, green: inkRGB.green, blue: inkRGB.blue).opacity(0.28)

    // Status — semantic chroma only, slightly muted
    static let shelfReady   = Color(red: 0.173, green: 0.475, blue: 0.314)
    static let shelfWarn    = Color(red: 0.690, green: 0.459, blue: 0.078)
    static let shelfDanger  = Color(red: 0.722, green: 0.235, blue: 0.176)

    // Type — Google Sans family. If a mono variant isn't installed, mono falls
    // back to Google Sans proportional rather than SF Mono so the voice stays unified.
    static let sansFamily: String = {
        let available = NSFontManager.shared.availableFontFamilies
        if available.contains("Google Sans") { return "Google Sans" }
        return ".AppleSystemUIFont"
    }()

    static let monoFamily: String = {
        let available = NSFontManager.shared.availableFontFamilies
        for candidate in ["Google Sans Mono", "Google Sans Code"] {
            if available.contains(candidate) { return candidate }
        }
        // No Google mono variant — prefer the unified Google Sans voice over SF Mono.
        return sansFamily
    }()

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(monoFamily, size: size).weight(weight)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(sansFamily, size: size).weight(weight)
    }

    // Convenience aliases — preserved for older call sites
    static func labelMono(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        mono(size, weight: weight)
    }

    static func chrome(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        sans(size, weight: weight)
    }
}

// MARK: - Status indicator

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }
}

// MARK: - Keyboard glyph

struct KbdGlyph: View {
    let symbol: String
    var label: String? = nil
    var prominent: Bool = false  // retained for source compatibility; no longer differentiates visually

    var body: some View {
        HStack(spacing: AppTheme.spacing6) {
            Text(symbol)
                .font(AppTheme.sans(10, weight: .medium))
                .foregroundStyle(AppTheme.shelfInkSecondary)
                .frame(minWidth: 14, minHeight: 14)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.shelfAccentSoft)
                )

            if let label {
                Text(label)
                    .font(AppTheme.sans(11, weight: .regular))
                    .foregroundStyle(AppTheme.shelfInkTertiary)
            }
        }
    }
}

// MARK: - Icon button

struct ToolIconButton: View {
    let systemName: String
    let help: String
    var tint: Color = AppTheme.shelfInkSecondary
    var background: Color?
    var size: CGFloat = AppTheme.controlSize
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(help, systemImage: systemName)
                .labelStyle(.iconOnly)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(buttonBackground)
        .onHover { isHovering = $0 }
        .accessibilityLabel(help)
        .help(help)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if let background {
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .fill(background)
        } else if isHovering {
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .fill(AppTheme.shelfRule)
        }
    }
}

// MARK: - Rail item

struct RailItem: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppTheme.hoverAnimation) { isHovering = hovering }
        }
        .help(label)
        .accessibilityLabel(label)
    }

    private var iconColor: Color {
        if isActive { return AppTheme.shelfInk }
        return isHovering ? AppTheme.shelfInk : AppTheme.shelfInkTertiary
    }

    private var backgroundColor: Color {
        if isActive { return AppTheme.shelfAccentSoft }
        if isHovering { return AppTheme.shelfRule.opacity(0.6) }
        return .clear
    }
}

// MARK: - Search field

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: AppTheme.spacing10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.shelfInkTertiary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppTheme.sans(13, weight: .regular))
                .foregroundStyle(AppTheme.shelfInk)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.shelfInkTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, AppTheme.spacing12)
        .frame(height: 34)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.shelfAccentSoft)
        )
    }
}

// MARK: - Empty state

struct EmptyToolState: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: AppTheme.spacing10) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(AppTheme.shelfInkMuted)
            Text(title)
                .font(AppTheme.sans(14, weight: .medium))
                .foregroundStyle(AppTheme.shelfInk)
            Text(detail)
                .font(AppTheme.sans(12, weight: .regular))
                .foregroundStyle(AppTheme.shelfInkTertiary)
        }
    }
}

// MARK: - Footer hints

struct ShortcutFooter: View {
    let hints: [(String, String)]
    let trailing: AnyView?

    init(hints: [(String, String)], trailing: AnyView? = nil) {
        self.hints = hints
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                KbdGlyph(symbol: hint.0, label: hint.1)
            }
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, AppTheme.spacing12)
        .frame(height: AppTheme.footerHeight)
        .background(AppTheme.shelfRail)
    }
}

// MARK: - Inline confirm

struct InlineConfirm: View {
    let prompt: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.spacing6) {
            Text(prompt)
                .font(AppTheme.sans(11, weight: .regular))
                .foregroundStyle(AppTheme.shelfInkSecondary)

            chip(label: "Cancel", tint: AppTheme.shelfInkSecondary, action: onCancel)
            chip(label: "Delete", tint: AppTheme.shelfDanger, action: onConfirm)
        }
    }

    private func chip(label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTheme.sans(11, weight: .medium))
                .foregroundStyle(tint)
                .padding(.horizontal, AppTheme.spacing8)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous).fill(tint.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Field label

struct FieldLabel: View {
    let title: String
    let systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.shelfInkTertiary)
            }
            Text(title)
                .font(AppTheme.sans(12, weight: .medium))
                .foregroundStyle(AppTheme.shelfInkSecondary)
        }
    }
}

// MARK: - Keyboard capture

struct KeyboardCaptureView: NSViewRepresentable {
    let focusToken: Int
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown

        guard nsView.focusToken != focusToken else { return }
        nsView.focusToken = focusToken
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class KeyCaptureNSView: NSView {
    var focusToken = 0
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Window activation

struct MenuWindowActivationObserver: NSViewRepresentable {
    let onOpen: () -> Void

    func makeNSView(context: Context) -> MenuWindowActivationNSView {
        let view = MenuWindowActivationNSView()
        view.onOpen = onOpen
        return view
    }

    func updateNSView(_ nsView: MenuWindowActivationNSView, context: Context) {
        nsView.onOpen = onOpen
    }
}

final class MenuWindowActivationNSView: NSView {
    var onOpen: (() -> Void)?

    private var isOpen = false
    private var observers: [NSObjectProtocol] = []

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installObservers()

        if window?.isKeyWindow == true {
            notifyOpenIfNeeded()
        }
    }

    private func installObservers() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()

        guard let window else { return }
        let center = NotificationCenter.default

        observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
            self?.notifyOpenIfNeeded()
        })

        observers.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
            self?.isOpen = false
        })

        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.isOpen = false
        })
    }

    private func notifyOpenIfNeeded() {
        guard !isOpen else { return }
        isOpen = true
        onOpen?()
    }
}
