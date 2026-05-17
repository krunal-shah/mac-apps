import SwiftUI
import AppKit

@MainActor
final class PaletteController: ObservableObject {
    static let preferredWidth: CGFloat = 640
    static let preferredHeight: CGFloat = 420

    @Published private(set) var isVisible = false

    let goLinkStore: GoLinkStore
    let pasteStore: PasteStore

    private let hotKey = GlobalHotKey()
    private var panel: PalettePanel?
    private var resignObserver: NSObjectProtocol?
    private var lastActiveAppBundleID: String?

    init(goLinkStore: GoLinkStore, pasteStore: PasteStore) {
        self.goLinkStore = goLinkStore
        self.pasteStore = pasteStore
    }

    func install() {
        let didRegister = hotKey.register(
            keyCode: PaletteHotKey.keyCode,
            modifiers: PaletteHotKey.modifiers
        ) { [weak self] in
            self?.toggle()
        }
        if !didRegister {
            NSLog("[CommandShelf] Failed to register palette hotkey (⌥Space). Another app may have claimed it.")
        }
    }

    func toggle() {
        if isVisible {
            close()
        } else {
            open()
        }
    }

    func open() {
        let panel = ensurePanel()
        rememberFrontApp()
        positionAboveScreenCenter(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        isVisible = true
    }

    func close() {
        guard let panel else { return }
        panel.orderOut(nil)
        isVisible = false
        restoreFrontApp()
    }

    private func ensurePanel() -> PalettePanel {
        if let panel { return panel }

        let panel = PalettePanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.preferredWidth,
                height: Self.preferredHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.onCancel = { [weak self] in self?.close() }

        let host = NSHostingView(
            rootView: PaletteView()
                .environmentObject(self)
                .environmentObject(goLinkStore)
                .environmentObject(pasteStore)
        )
        host.autoresizingMask = [.width, .height]
        if let contentView = panel.contentView {
            host.frame = contentView.bounds
            contentView.addSubview(host)
        } else {
            panel.contentView = host
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.close()
            }
        }

        self.panel = panel
        return panel
    }

    private func positionAboveScreenCenter(_ panel: PalettePanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        // Bias upward so it feels Spotlight-like rather than dead-center.
        let y = frame.midY - size.height / 2 + frame.height * 0.15
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func rememberFrontApp() {
        let frontApp = NSWorkspace.shared.frontmostApplication
        if frontApp?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        lastActiveAppBundleID = frontApp?.bundleIdentifier
    }

    private func restoreFrontApp() {
        guard let bundleID = lastActiveAppBundleID,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        else { return }
        app.activate(options: [])
        lastActiveAppBundleID = nil
    }
}

final class PalettePanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
