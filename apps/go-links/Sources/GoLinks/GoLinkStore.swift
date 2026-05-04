import Foundation

struct GoLink: Identifiable, Codable, Equatable {
    let id: UUID
    var shortName: String
    var destinationURL: String

    init(id: UUID = UUID(), shortName: String, destinationURL: String) {
        self.id = id
        self.shortName = shortName.lowercased().trimmingCharacters(in: .whitespaces)
        self.destinationURL = destinationURL
    }
}

@MainActor
final class GoLinkStore: ObservableObject {
    @Published private(set) var links: [GoLink] = []

    private let saveKey = "go_links_v1"

    init() {
        load()
    }

    // MARK: - CRUD

    func add(shortName: String, destinationURL: String) {
        let link = GoLink(shortName: shortName, destinationURL: ensureScheme(destinationURL))
        links.append(link)
        save()
    }

    func update(_ link: GoLink) {
        guard let idx = links.firstIndex(where: { $0.id == link.id }) else { return }
        var updated = link
        updated.shortName = link.shortName.lowercased().trimmingCharacters(in: .whitespaces)
        updated.destinationURL = ensureScheme(link.destinationURL)
        links[idx] = updated
        save()
    }

    func delete(_ link: GoLink) {
        links.removeAll { $0.id == link.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        links.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Lookup

    func destination(for shortName: String) -> String? {
        let key = shortName.lowercased().trimmingCharacters(in: .whitespaces)
        return links.first { $0.shortName == key }?.destinationURL
    }

    func isNameTaken(_ name: String, excluding id: UUID? = nil) -> Bool {
        let key = name.lowercased().trimmingCharacters(in: .whitespaces)
        return links.contains { $0.shortName == key && $0.id != id }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([GoLink].self, from: data)
        else { return }
        links = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(links) else { return }
        UserDefaults.standard.set(encoded, forKey: saveKey)
    }

    // MARK: - Helpers

    private func ensureScheme(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "https://" + trimmed
    }
}
