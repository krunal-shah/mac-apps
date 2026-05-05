import SwiftUI
import AppKit

enum AppTheme {
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let cornerRadius: CGFloat = 10
    static let compactCornerRadius: CGFloat = 8
    static let controlSize: CGFloat = 32
    static let compactControlSize: CGFloat = 28
    static let rowIconWidth: CGFloat = 20

    static let appBackground = Color(NSColor.windowBackgroundColor)
    static let groupedBackground = Color(NSColor.controlBackgroundColor)
    static let contentBackground = Color(NSColor.textBackgroundColor)
    static let separator = Color(NSColor.separatorColor)
}

struct ToolIconButton: View {
    let systemName: String
    let help: String
    var tint: Color = .secondary
    var background: Color?
    var size: CGFloat = AppTheme.controlSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(help, systemImage: systemName)
                .labelStyle(.iconOnly)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(buttonBackground)
        .accessibilityLabel(help)
        .help(help)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if let background {
            RoundedRectangle(cornerRadius: AppTheme.compactCornerRadius)
                .fill(background)
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: AppTheme.spacing8) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Label("Clear Search", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Search")
            }
        }
        .padding(.horizontal, AppTheme.spacing12)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.compactCornerRadius)
                .fill(AppTheme.groupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.compactCornerRadius)
                .stroke(AppTheme.separator.opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }
}

struct EmptyToolState: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

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
