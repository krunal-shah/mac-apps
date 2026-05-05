import SwiftUI
import AppKit

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Set by CommandShelfApp.init() before applicationDidFinishLaunching fires.
    static var server: HTTPServer?
    static var tlsServer: TLSServer?
    static var pasteStore: PasteStore?
    static var clipboardMonitor: ClipboardMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.server?.start()
        Self.tlsServer?.start()
        if let pasteStore = Self.pasteStore {
            Self.clipboardMonitor?.start(store: pasteStore)
        }
        Task { @MainActor in await SetupManager.shared.reapplyPFIfNeeded() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.server?.stop()
        Self.tlsServer?.stop()
        Self.clipboardMonitor?.stop()
    }
}

// MARK: - SwiftUI App

@main
struct CommandShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var store: GoLinkStore
    @StateObject private var pasteStore: PasteStore
    @StateObject private var clipboardMonitor: ClipboardMonitor
    @StateObject private var setup: SetupManager

    private let server: HTTPServer
    private let tlsServer: TLSServer

    init() {
        let linkResolver = GoLinkResolver()
        let pasteResolver = PasteResolver()
        let store = GoLinkStore(resolver: linkResolver)
        let pasteStore = PasteStore(resolver: pasteResolver)
        let clipboardMonitor = ClipboardMonitor()
        let router = GoLinkRouter(linkResolver: linkResolver, pasteResolver: pasteResolver)
        let server = HTTPServer(router: router)
        let tlsServer = TLSServer(router: router)

        _store = StateObject(wrappedValue: store)
        _pasteStore = StateObject(wrappedValue: pasteStore)
        _clipboardMonitor = StateObject(wrappedValue: clipboardMonitor)
        _setup = StateObject(wrappedValue: SetupManager.shared)
        self.server = server
        self.tlsServer = tlsServer

        // Share with delegate for lifecycle management
        AppDelegate.server = server
        AppDelegate.tlsServer = tlsServer
        AppDelegate.pasteStore = pasteStore
        AppDelegate.clipboardMonitor = clipboardMonitor
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(pasteStore)
                .environmentObject(clipboardMonitor)
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
            Image(nsImage: AppIconImage.menuBar)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .frame(width: 18, height: 18)
            if !setup.hostsConfigured || !setup.pfConfigured {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                    .offset(x: 3, y: -3)
            }
        }
    }
}

private enum AppIconImage {
    static let menuBar: NSImage = {
        if
            let url = Bundle.main.url(forResource: "MenuBarIconTemplate", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }

        let fallback = NSApp.applicationIconImage ?? NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil) ?? NSImage()
        fallback.size = NSSize(width: 18, height: 18)
        fallback.isTemplate = true
        return fallback
    }()
}
