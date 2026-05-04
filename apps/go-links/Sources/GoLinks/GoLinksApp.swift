import SwiftUI
import AppKit

// MARK: - Setup Panel

@MainActor
final class SetupPanel {
    static let shared = SetupPanel()
    private var controller: NSWindowController?

    private init() {}

    func close() { controller?.close() }

    func show() {
        if controller == nil {
            let root = SetupView().environmentObject(SetupManager.shared)
            let hosting = NSHostingController(rootView: root)
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "System Setup"
            panel.contentViewController = hosting
            panel.isReleasedWhenClosed = false
            panel.isFloatingPanel = false
            panel.center()
            controller = NSWindowController(window: panel)
        }
        NSApp.activate(ignoringOtherApps: true)
        controller?.showWindow(nil)
        controller?.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Link Editor Panel

@MainActor
final class LinkEditorPanel {
    static let shared = LinkEditorPanel()
    private var controller: NSWindowController?

    private init() {}

    func close() {
        controller?.close()
        controller = nil
    }

    func show(mode: LinkFormMode, store: GoLinkStore) {
        close()

        let root = AddEditLinkView(mode: mode) { [weak self] in
            self?.close()
        }
        .environmentObject(store)

        let hosting = NSHostingController(rootView: root)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = mode.title
        panel.contentViewController = hosting
        panel.isReleasedWhenClosed = false
        panel.center()

        controller = NSWindowController(window: panel)
        NSApp.activate(ignoringOtherApps: true)
        controller?.showWindow(nil)
        controller?.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Set by GoLinksApp.init() before applicationDidFinishLaunching fires
    static var server: HTTPServer?
    static var tlsServer: TLSServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.server?.start()
        Self.tlsServer?.start()
        Task { @MainActor in await SetupManager.shared.reapplyPFIfNeeded() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.server?.stop()
        Self.tlsServer?.stop()
    }
}

// MARK: - SwiftUI App

@main
struct GoLinksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var store: GoLinkStore
    @StateObject private var setup: SetupManager

    private let server: HTTPServer
    private let tlsServer: TLSServer

    init() {
        let resolver = GoLinkResolver()
        let store = GoLinkStore(resolver: resolver)
        let router = GoLinkRouter(resolver: resolver)
        let server = HTTPServer(router: router)
        let tlsServer = TLSServer(router: router)

        _store = StateObject(wrappedValue: store)
        _setup = StateObject(wrappedValue: SetupManager.shared)
        self.server = server
        self.tlsServer = tlsServer

        // Share with delegate for lifecycle management
        AppDelegate.server = server
        AppDelegate.tlsServer = tlsServer
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(setup)
                .onChange(of: setup.isRunningSetup) { isRunning in
                    if !isRunning { tlsServer.start() }
                }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarLabel: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "arrow.triangle.branch")
            if !setup.hostsConfigured || !setup.pfConfigured {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                    .offset(x: 3, y: -3)
            }
        }
    }
}
