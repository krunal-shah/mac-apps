import Foundation
import AppKit

enum PaletteResult: Identifiable, Equatable {
    case goLink(GoLink)
    case paste(PasteItem)

    var id: String {
        switch self {
        case .goLink(let link): return "go:\(link.id.uuidString)"
        case .paste(let paste): return "paste:\(paste.id)"
        }
    }

    var title: String {
        switch self {
        case .goLink(let link): return "go/\(link.shortName)"
        case .paste(let paste): return paste.title
        }
    }

    var subtitle: String {
        switch self {
        case .goLink(let link): return link.destinationURL
        case .paste(let paste):
            let collapsed = paste.body
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return String(collapsed.prefix(120))
        }
    }

    var systemImage: String {
        switch self {
        case .goLink: return "link"
        case .paste: return "doc.on.clipboard"
        }
    }

    var kindLabel: String {
        switch self {
        case .goLink: return "Open"
        case .paste: return "Copy"
        }
    }
}

enum PaletteSearch {
    /// Maximum items shown when the query is empty (mixed providers).
    static let emptyStateLimit = 6

    static func rank(
        query rawQuery: String,
        goLinks: [GoLink],
        pastes: [PasteItem]
    ) -> [PaletteResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if query.isEmpty {
            // Empty-state ordering matches the section ordering rendered by the view:
            // explicit shortcuts (go-links) first, recent clipboard history second.
            let topLinks = goLinks.prefix(emptyStateLimit).map(PaletteResult.goLink)
            let topPastes = pastes.prefix(emptyStateLimit).map(PaletteResult.paste)
            return Array(topLinks) + Array(topPastes)
        }

        var scored: [(score: Int, result: PaletteResult)] = []
        for link in goLinks {
            let s = score(query: query, primary: link.shortName, secondary: link.destinationURL)
            if s > 0 { scored.append((s, .goLink(link))) }
        }
        for paste in pastes {
            let s = score(query: query, primary: paste.title, secondary: paste.body)
            if s > 0 { scored.append((s, .paste(paste))) }
        }
        return scored
            .sorted { $0.score > $1.score }
            .map(\.result)
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

enum PaletteAction {
    @MainActor
    static func activate(_ result: PaletteResult) {
        switch result {
        case .goLink(let link):
            open(urlString: link.destinationURL)
        case .paste(let paste):
            copy(text: paste.body)
        }
    }

    @MainActor
    private static func open(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    private static func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
