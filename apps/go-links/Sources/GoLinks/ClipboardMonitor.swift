import AppKit
import Foundation

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastCapturedAt: Date?

    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int
    private var pollingTask: Task<Void, Never>?
    private weak var store: PasteStore?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(store: PasteStore) {
        self.store = store
        captureCurrentString()

        guard pollingTask == nil else {
            isRunning = true
            return
        }

        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 750_000_000)
                guard !Task.isCancelled else { return }
                self?.poll()
            }
        }
        isRunning = true
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
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
