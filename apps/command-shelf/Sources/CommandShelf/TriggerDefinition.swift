import Foundation

/// User-authored entry in the Obsidian vault `Launcher/triggers.json` file.
struct TriggerDefinition: Codable, Identifiable, Equatable {
    let keyword: String
    let label: String
    let description: String?
    let prompt: String?
    let action: TriggerAction

    var id: String { keyword.lowercased() }

    /// Substitute the typed input into a template string (`{input}` placeholder).
    func hydrate(template: String, input: String) -> String {
        template.replacingOccurrences(of: "{input}", with: input)
    }
}

enum TriggerAction: Equatable {
    case clipboard
    case sylApi(method: String, endpoint: String, body: [String: String]?)
    case streamInline(context: String)

    var kindLabel: String {
        switch self {
        case .clipboard: return "Draft"
        case .sylApi: return "Send"
        case .streamInline: return "Ask"
        }
    }

    var systemImage: String {
        switch self {
        case .clipboard: return "doc.on.clipboard.fill"
        case .sylApi: return "arrow.up.forward.app"
        case .streamInline: return "sparkles"
        }
    }
}

extension TriggerAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, method, endpoint, body, context
    }

    private enum Kind: String {
        case clipboard
        case sylApi = "syl_api"
        case streamInline = "stream_inline"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)
        guard let kind = Kind(rawValue: rawType) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown action type: \(rawType)"
            )
        }
        switch kind {
        case .clipboard:
            self = .clipboard
        case .sylApi:
            let method = try container.decodeIfPresent(String.self, forKey: .method) ?? "POST"
            let endpoint = try container.decode(String.self, forKey: .endpoint)
            let body = try container.decodeIfPresent([String: String].self, forKey: .body)
            self = .sylApi(method: method, endpoint: endpoint, body: body)
        case .streamInline:
            let context = try container.decodeIfPresent(String.self, forKey: .context) ?? "general"
            self = .streamInline(context: context)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .clipboard:
            try container.encode(Kind.clipboard.rawValue, forKey: .type)
        case .sylApi(let method, let endpoint, let body):
            try container.encode(Kind.sylApi.rawValue, forKey: .type)
            try container.encode(method, forKey: .method)
            try container.encode(endpoint, forKey: .endpoint)
            try container.encodeIfPresent(body, forKey: .body)
        case .streamInline(let context):
            try container.encode(Kind.streamInline.rawValue, forKey: .type)
            try container.encode(context, forKey: .context)
        }
    }
}

/// On-disk JSON shape: `{ "triggers": [TriggerDefinition, ...] }`
struct TriggerFile: Codable {
    let triggers: [TriggerDefinition]
}
