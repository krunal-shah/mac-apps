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

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Set by GoLinksApp.init() before applicationDidFinishLaunching fires
    static var store: GoLinkStore?
    static var server: HTTPServer?
    static var tlsServer: TLSServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let store = Self.store, let server = Self.server else { return }
        server.start(store: store)
        Self.tlsServer?.start(store: store)
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
        let store = GoLinkStore()
        let server = HTTPServer(port: 9876)
        let tlsServer = TLSServer()

        _store = StateObject(wrappedValue: store)
        _setup = StateObject(wrappedValue: SetupManager.shared)
        self.server = server
        self.tlsServer = tlsServer

        // Share with delegate for lifecycle management
        AppDelegate.store = store
        AppDelegate.server = server
        AppDelegate.tlsServer = tlsServer
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(setup)
                .onChange(of: setup.isRunningSetup) { isRunning in
                    if !isRunning { tlsServer.start(store: store) }
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
