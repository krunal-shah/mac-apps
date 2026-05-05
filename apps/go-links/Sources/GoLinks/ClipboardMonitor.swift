import AppKit
import Foundation

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastCapturedAt: Date?

    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int
    private var timer: Timer?
    private weak var store: PasteStore?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(store: PasteStore) {
        self.store = store
        captureCurrentString()

        guard timer == nil else {
            isRunning = true
            return
        }

        let timer = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        isRunning = true
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }

        lastChangeCount = changeCount
        captureCurrentString()
    }

    private func captureCurrentString() {
        guard let store, let value = pasteboard.string(forType: .string) else { return }

        switch store.captureClipboard(value) {
        case .created, .refreshed:
            lastCapturedAt = Date()
        case .ignored:
            break
        }
    }
}
