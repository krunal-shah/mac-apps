import Foundation
import AppKit

enum PaletteResult: Identifiable, Equatable {
    case goLink(GoLink)
    case paste(PasteItem)
    case trigger(TriggerDefinition, input: String)

    var id: String {
        switch self {
        case .goLink(let link): return "go:\(link.id.uuidString)"
        case .paste(let paste): return "paste:\(paste.id)"
        case .trigger(let def, _): return "trigger:\(def.id)"
        }
    }

    var title: String {
        switch self {
        case .goLink(let link):
            return "go/\(link.shortName)"
        case .paste(let paste):
            return paste.title
        case .trigger(let def, let input):
            return input.isEmpty ? def.keyword : "\(def.keyword) \(input)"
        }
    }

    var subtitle: String {
        switch self {
        case .goLink(let link):
            return link.destinationURL
        case .paste(let paste):
            let collapsed = paste.body
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return String(collapsed.prefix(120))
        case .trigger(let def, _):
            return def.description ?? def.label
        }
    }

    var systemImage: String {
        switch self {
        case .goLink: return "link"
        case .paste: return "doc.on.clipboard"
        case .trigger(let def, _): return def.action.systemImage
        }
    }

    var kindLabel: String {
        switch self {
        case .goLink: return "Open"
        case .paste: return "Copy"
        case .trigger(let def, _): return def.action.kindLabel
        }
    }

    var sectionTitle: String {
        switch self {
        case .goLink: return "Go Links"
        case .paste: return "Pastes"
        case .trigger: return "Triggers"
        }
    }
}

enum PaletteSearch {
    /// Maximum items shown when the query is empty (mixed providers).
    static let emptyStateLimit = 6

    static func rank(
        query rawQuery: String,
        goLinks: [GoLink],
        pastes: [PasteItem],
        triggers: [TriggerDefinition] = []
    ) -> [PaletteResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if query.isEmpty {
            // Empty-state ordering matches the section ordering rendered by the view:
            // explicit shortcuts (go-links) first, recent clipboard history second.
            let topLinks = goLinks.prefix(emptyStateLimit).map(PaletteResult.goLink)
            let topPastes = pastes.prefix(emptyStateLimit).map(PaletteResult.paste)
            return Array(topLinks) + Array(topPastes)
        }

        // Triggers always lead when the keyword matches. Even on a prefix match
        // they're surfaced so the user discovers what's available.
        let triggerResults = matchTriggers(query: query, triggers: triggers)

        var scored: [(score: Int, result: PaletteResult)] = []
        for link in goLinks {
            let s = score(query: query, primary: link.shortName, secondary: link.destinationURL)
            if s > 0 { scored.append((s, .goLink(link))) }
        }
        for paste in pastes {
            let s = score(query: query, primary: paste.title, secondary: paste.body)
            if s > 0 { scored.append((s, .paste(paste))) }
        }
        let providerResults = scored
            .sorted { $0.score > $1.score }
            .map(\.result)

        return triggerResults + providerResults
    }

    private static func matchTriggers(
        query: String,
        triggers: [TriggerDefinition]
    ) -> [PaletteResult] {
        guard !triggers.isEmpty, !query.isEmpty else { return [] }

        let parts = query.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let firstToken = parts.isEmpty ? query : String(parts[0]).lowercased()
        let rest = parts.count > 1 ? String(parts[1]) : ""

        var exact: [PaletteResult] = []
        var prefix: [PaletteResult] = []

        for trigger in triggers {
            let keyword = trigger.keyword.lowercased()
            if keyword == firstToken {
                exact.append(.trigger(trigger, input: rest))
            } else if rest.isEmpty,
                      keyword.hasPrefix(firstToken),
                      firstToken.count >= 1 {
                prefix.append(.trigger(trigger, input: ""))
            }
        }

        return exact + prefix
    }

    /// Score one candidate's two text fields against the query.
    /// Primary field hits weigh more than secondary. Prefix > word-prefix > substring.
    private static func score(query: String, primary: String, secondary: String) -> Int {
        let p = primary.lowercased()
        let s = secondary.lowercased()

        if p == query { return 1000 }
        if p.hasPrefix(query) { return 500 }
        if wordPrefixMatch(query: query, in: p) { return 300 }
        if p.contains(query) { return 200 }
        if s.hasPrefix(query) { return 120 }
        if s.contains(query) { return 60 }
        return 0
    }

    private static func wordPrefixMatch(query: String, in text: String) -> Bool {
        for separator in [" ", "-", "_", "/"] {
            for token in text.components(separatedBy: separator) {
                if token.hasPrefix(query) { return true }
            }
        }
        return false
    }
}

