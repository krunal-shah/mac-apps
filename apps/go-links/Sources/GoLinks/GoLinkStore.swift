import Foundation

struct GoLink: Identifiable, Codable, Equatable {
    let id: UUID
    var shortName: String
    var destinationURL: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), shortName: String, destinationURL: String) {
        self.id = id
        self.shortName = shortName
        self.destinationURL = destinationURL
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case shortName
        case destinationURL
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        shortName = try container.decode(String.self, forKey: .shortName)
        destinationURL = try container.decode(String.self, forKey: .destinationURL)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

enum GoLinkValidationError: LocalizedError, Equatable {
    case emptyName
    case invalidName
    case duplicateName
    case reservedName
    case emptyURL
    case invalidURL
    case unsupportedURLScheme

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Enter a short name."
        case .invalidName:
            return "Use 1-64 lowercase letters, numbers, hyphens, or underscores. Start with a letter or number."
        case .duplicateName:
            return "That short name already exists."
        case .reservedName:
            return "That short name is reserved for an app tool."
        case .emptyURL:
            return "Enter a destination URL."
        case .invalidURL:
            return "Enter a valid URL."
        case .unsupportedURLScheme:
            return "Use an http or https URL."
        }
    }
}

enum GoLinkInput {
    static func normalizedName(_ rawValue: String) throws -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        for prefix in [
            "https://\(AppConfig.hostName)/",
            "http://\(AppConfig.hostName)/",
            "\(AppConfig.hostName)/"
        ] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
        }

        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !value.isEmpty else {
            throw GoLinkValidationError.emptyName
        }

        let pattern = #"^[a-z0-9][a-z0-9_-]{0,63}$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else {
            throw GoLinkValidationError.invalidName
        }
        guard !AppConfig.reservedShortNames.contains(value) else {
            throw GoLinkValidationError.reservedName
        }

        return value
    }

    static func normalizedURL(_ rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GoLinkValidationError.emptyURL
        }
        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw GoLinkValidationError.invalidURL
        }

        let candidate: String
        if trimmed.range(of: "^[a-z][a-z0-9+.-]*://", options: [.regularExpression, .caseInsensitive]) == nil {
            candidate = "https://\(trimmed)"
        } else {
            candidate = trimmed
        }

        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty
        else {
            throw GoLinkValidationError.invalidURL
        }

        guard scheme == "http" || scheme == "https" else {
            throw GoLinkValidationError.unsupportedURLScheme
        }

        guard let normalized = components.url?.absoluteString else {
            throw GoLinkValidationError.invalidURL
        }

        return normalized
    }
}

@MainActor
final class GoLinkStore: ObservableObject {
    @Published private(set) var links: [GoLink] = []

    private let defaults: UserDefaults
    private let resolver: GoLinkResolver

    init(defaults: UserDefaults = .standard, resolver: GoLinkResolver) {
        self.defaults = defaults
        self.resolver = resolver
        load()
    }

    // MARK: - CRUD

    func add(shortName rawName: String, destinationURL rawURL: String) throws {
        let shortName = try GoLinkInput.normalizedName(rawName)
        guard !isNameTaken(shortName) else {
            throw GoLinkValidationError.duplicateName
        }

        let link = GoLink(
            shortName: shortName,
            destinationURL: try GoLinkInput.normalizedURL(rawURL)
        )
        links.append(link)
        persist()
    }

    func update(_ link: GoLink) throws {
        guard let idx = links.firstIndex(where: { $0.id == link.id }) else { return }
        let shortName = try GoLinkInput.normalizedName(link.shortName)
        guard !isNameTaken(shortName, excluding: link.id) else {
            throw GoLinkValidationError.duplicateName
        }

        var updated = links[idx]
        updated.shortName = shortName
        updated.destinationURL = try GoLinkInput.normalizedURL(link.destinationURL)
        updated.updatedAt = Date()
        links[idx] = updated
        persist()
    }

    func delete(_ link: GoLink) {
        links.removeAll { $0.id == link.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        links.remove(atOffsets: offsets)
        persist()
    }

    // MARK: - Lookup

    func destination(for shortName: String) -> String? {
        let key = (try? GoLinkInput.normalizedName(shortName)) ?? shortName.lowercased()
        return links.first { $0.shortName == key }?.destinationURL
    }

    func isNameTaken(_ name: String, excluding id: UUID? = nil) -> Bool {
        let key = (try? GoLinkInput.normalizedName(name)) ?? name.lowercased()
        return links.contains { $0.shortName == key && $0.id != id }
    }

    // MARK: - Persistence

    private func load() {
        let data = defaults.data(forKey: AppConfig.defaultsKey)
            ?? defaults.data(forKey: AppConfig.legacyDefaultsKey)

        guard let data,
              let decoded = try? JSONDecoder().decode([GoLink].self, from: data)
        else {
            resolver.replace(with: [])
            return
        }

        links = sanitized(decoded)
        resolver.replace(with: links)
        save()
    }

    private func persist() {
        links.sort { $0.shortName.localizedStandardCompare($1.shortName) == .orderedAscending }
        save()
        resolver.replace(with: links)
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(links) else { return }
        defaults.set(encoded, forKey: AppConfig.defaultsKey)
    }

    private func sanitized(_ decoded: [GoLink]) -> [GoLink] {
        var seen = Set<String>()
        var sanitizedLinks: [GoLink] = []

        for link in decoded {
            guard let shortName = try? GoLinkInput.normalizedName(link.shortName),
                  let destinationURL = try? GoLinkInput.normalizedURL(link.destinationURL),
                  !seen.contains(shortName)
            else { continue }

            seen.insert(shortName)
            var clean = link
            clean.shortName = shortName
            clean.destinationURL = destinationURL
            sanitizedLinks.append(clean)
        }

        return sanitizedLinks.sorted {
            $0.shortName.localizedStandardCompare($1.shortName) == .orderedAscending
        }
    }
}
