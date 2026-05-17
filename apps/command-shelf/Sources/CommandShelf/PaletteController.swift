import SwiftUI
import AppKit

@MainActor
final class PaletteController: ObservableObject {
    static let preferredWidth: CGFloat = 640
    static let preferredHeight: CGFloat = 420

    @Published private(set) var isVisible = false
    @Published var actionStatus: ActionStatus?
    @Published var streamingResponse: String?
    @Published var streamingDone: Bool = false
    @Published var streamingHeader: String = ""

    let goLinkStore: GoLinkStore
    let pasteStore: PasteStore
    let triggerStore: TriggerStore
    let identity: Identity
    let sylClient: SylClient

    private let hotKey = GlobalHotKey()
    private var panel: PalettePanel?
    private var resignObserver: NSObjectProtocol?
    private var lastActiveAppBundleID: String?
    private var statusClearTask: Task<Void, Never>?

    init(
        goLinkStore: GoLinkStore,
        pasteStore: PasteStore,
        triggerStore: TriggerStore,
        identity: Identity,
        sylClient: SylClient
    ) {
        self.goLinkStore = goLinkStore
        self.pasteStore = pasteStore
        self.triggerStore = triggerStore
        self.identity = identity
        self.sylClient = sylClient
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
        // Re-read triggers from the vault each show so Obsidian edits land
        // immediately without restarting Command Shelf.
        triggerStore.reload()
        actionStatus = nil
        streamingResponse = nil
        streamingDone = false
        streamingHeader = ""
        statusClearTask?.cancel()

        let panel = ensurePanel()
        rememberFrontApp()
        positionAboveScreenCenter(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        isVisible = true
    }

    func close() {
        statusClearTask?.cancel()
        actionStatus = nil
        streamingResponse = nil
        streamingDone = false
        streamingHeader = ""
        guard let panel else { return }
        panel.orderOut(nil)
        isVisible = false
        restoreFrontApp()
    }

    // MARK: - Activation

    func activate(_ result: PaletteResult) {
        switch result {
        case .goLink(let link):
            open(urlString: link.destinationURL)
            close()
        case .paste(let paste):
            copyToClipboard(paste.body)
            close()
        case .trigger(let def, let input):
            Task { await runTrigger(def, input: input) }
        }
    }

    private func runTrigger(_ def: TriggerDefinition, input: String) async {
        switch def.action {
        case .clipboard:
            await runClipboardTrigger(def, input: input)

        case .streamInline(let context):
            await runStreamingTrigger(def, input: input, context: context)

        case .sylApi(let method, let endpoint, let bodyTemplate):
            actionStatus = .running("Sending to Syl…")
            let body = bodyTemplate?.mapValues { def.hydrate(template: $0, input: input) }
            do {
                _ = try await sylClient.send(method: method, endpoint: endpoint, body: body)
                actionStatus = .success("Sent to \(endpoint)")
                scheduleStatusClear(after: 0.9, andClose: true)
                NSLog("[CommandShelf] Trigger '%@' → %@ OK", def.keyword, endpoint)
            } catch {
                let message = (error as? SylClient.SylClientError)?.errorDescription
                    ?? error.localizedDescription
                actionStatus = .failure(message)
                scheduleStatusClear(after: 2.4, andClose: false)
                NSLog("[CommandShelf] Trigger '%@' → %@ FAILED: %@", def.keyword, endpoint, message)
            }
        }
    }

    private func runClipboardTrigger(_ def: TriggerDefinition, input: String) async {
        guard let prompt = def.prompt, !prompt.isEmpty else {
            actionStatus = .failure("Trigger has no prompt template.")
            scheduleStatusClear(after: 2.0, andClose: false)
            return
        }
        let hydrated = def.hydrate(template: prompt, input: input)
        actionStatus = .running("Drafting with Claude…")

        var accumulated = ""
        do {
            try await sylClient.stream(
                endpoint: "/api/launcher/generate",
                body: ["prompt": hydrated]
            ) { chunk in
                accumulated += chunk
            }
            let trimmed = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                actionStatus = .failure("Claude returned an empty response.")
                scheduleStatusClear(after: 2.0, andClose: false)
                return
            }
            copyToClipboard(trimmed)
            actionStatus = .success("Copied draft (\(trimmed.count) chars)")
            scheduleStatusClear(after: 1.2, andClose: true)
            NSLog("[CommandShelf] Trigger '%@' clipboard draft copied (%d chars)", def.keyword, trimmed.count)
        } catch {
            let message = (error as? SylClient.SylClientError)?.errorDescription
                ?? error.localizedDescription
            actionStatus = .failure(message)
            scheduleStatusClear(after: 2.4, andClose: false)
            NSLog("[CommandShelf] Trigger '%@' clipboard FAILED: %@", def.keyword, message)
        }
    }

    private func runStreamingTrigger(_ def: TriggerDefinition, input: String, context: String) async {
        guard let prompt = def.prompt, !prompt.isEmpty else {
            actionStatus = .failure("Trigger has no prompt template.")
            scheduleStatusClear(after: 2.0, andClose: false)
            return
        }
        let hydrated = def.hydrate(template: prompt, input: input)

        streamingResponse = ""
        streamingDone = false
        streamingHeader = def.label

        var body: [String: String] = ["prompt": hydrated]
        if !context.isEmpty, context != "none" {
            body["context"] = context
        }

        do {
            try await sylClient.stream(
                endpoint: "/api/launcher/generate",
                body: body
            ) { [weak self] chunk in
                guard let self else { return }
                self.streamingResponse = (self.streamingResponse ?? "") + chunk
            }
            streamingDone = true
            // Auto-copy the full response so the user can dismiss + paste anywhere.
            if let final = streamingResponse?.trimmingCharacters(in: .whitespacesAndNewlines),
               !final.isEmpty {
                copyToClipboard(final)
            }
            NSLog("[CommandShelf] Trigger '%@' stream done (%d chars)", def.keyword, streamingResponse?.count ?? 0)
        } catch {
            let message = (error as? SylClient.SylClientError)?.errorDescription
                ?? error.localizedDescription
            streamingResponse = "Error: \(message)"
            streamingDone = true
            NSLog("[CommandShelf] Trigger '%@' stream FAILED: %@", def.keyword, message)
        }
    }

    private func scheduleStatusClear(after seconds: Double, andClose shouldClose: Bool) {
        statusClearTask?.cancel()
        statusClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.actionStatus = nil
            if shouldClose { self.close() }
        }
    }

    // MARK: - Synchronous helpers

    private func open(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Panel

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
                .environmentObject(triggerStore)
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

enum ActionStatus: Equatable {
    case running(String)
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .running(let m), .success(let m), .failure(let m): return m
        }
    }

    var symbol: String {
        switch self {
        case .running: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.triangle.fill"
        }
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
