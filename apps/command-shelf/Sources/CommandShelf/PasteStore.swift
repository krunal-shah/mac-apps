import Foundation

struct PasteItem: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(id: String = PasteID.make(), title: String, body: String, createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.title = PasteInput.normalizedTitle(title)
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

enum PasteCaptureResult: Equatable {
    case created(PasteItem)
    case refreshed(PasteItem)
    case ignored
}

enum PasteValidationError: LocalizedError, Equatable {
    case emptyBody

    var errorDescription: String? {
        switch self {
        case .emptyBody:
            return "Paste content is required."
        }
    }
}

enum PasteInput {
    static func normalizedTitle(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Paste" : trimmed
    }

    static func normalizedBody(_ rawValue: String) throws -> String {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PasteValidationError.emptyBody
        }
        return rawValue
    }

    static func titleForClipboardBody(_ body: String) -> String {
        let firstLine = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        let collapsed = firstLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard !collapsed.isEmpty else {
            return normalizedTitle("")
        }
        guard collapsed.count > 72 else {
            return collapsed
        }
        return String(collapsed.prefix(69)) + "..."
    }
}

enum PasteID {
    private static let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")

    static func make(length: Int = 8) -> String {
        String((0..<length).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
    }
}

@MainActor
final class PasteStore: ObservableObject {
    @Published private(set) var pastes: [PasteItem] = []

    private let defaults: UserDefaults
    private let resolver: PasteResolver

    init(defaults: UserDefaults = .standard, resolver: PasteResolver) {
        self.defaults = defaults
        self.resolver = resolver
        load()
    }

    @discardableResult
    func add(title: String, body rawBody: String) throws -> PasteItem {
        let body = try PasteInput.normalizedBody(rawBody)
        let paste = PasteItem(id: uniqueID(), title: title, body: body)
        pastes.insert(paste, at: 0)
        persist()
        return paste
    }

    @discardableResult
    func captureClipboard(_ rawBody: String, capturedAt: Date = Date()) -> PasteCaptureResult {
        guard let body = try? PasteInput.normalizedBody(rawBody) else {
            return .ignored
        }

        if let index = pastes.firstIndex(where: { $0.body == body }) {
            pastes[index].updatedAt = capturedAt
            let updated = pastes[index]
            sort()
            persist()
            return .refreshed(updated)
        }

        let paste = PasteItem(
            id: uniqueID(),
            title: PasteInput.titleForClipboardBody(body),
            body: body,
            createdAt: capturedAt,
            updatedAt: capturedAt
        )
        pastes.insert(paste, at: 0)
        persist()
        return .created(paste)
    }

    func update(_ paste: PasteItem, title: String, body rawBody: String) throws {
        guard let index = pastes.firstIndex(where: { $0.id == paste.id }) else { return }
        var updated = pastes[index]
        updated.title = PasteInput.normalizedTitle(title)
        updated.body = try PasteInput.normalizedBody(rawBody)
        updated.updatedAt = Date()
        pastes[index] = updated
        sort()
        persist()
    }

    func delete(_ paste: PasteItem) {
        pastes.removeAll { $0.id == paste.id }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: AppConfig.pasteDefaultsKey),
              let decoded = try? JSONDecoder().decode([PasteItem].self, from: data)
        else {
            resolver.replace(with: [])
            return
        }

        pastes = sanitized(decoded)
        sort()
        resolver.replace(with: pastes)
    }

    private func persist() {
        save()
        resolver.replace(with: pastes)
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(pastes) else { return }
        defaults.set(encoded, forKey: AppConfig.pasteDefaultsKey)
    }

    private func sort() {
        pastes.sort {
            if $0.updatedAt == $1.updatedAt {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func uniqueID() -> String {
        var id = PasteID.make()
        let existing = Set(pastes.map(\.id))
        while existing.contains(id) {
            id = PasteID.make()
        }
        return id
    }

    private func sanitized(_ decoded: [PasteItem]) -> [PasteItem] {
        var seen = Set<String>()
        var sanitizedPastes: [PasteItem] = []

        for paste in decoded {
            let id = paste.id.lowercased()
            guard !id.isEmpty,
                  !seen.contains(id),
                  !paste.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }

            seen.insert(id)
            var clean = paste
            clean.id = id
            clean.title = PasteInput.normalizedTitle(paste.title)
            sanitizedPastes.append(clean)
        }

        return sanitizedPastes
    }
}
