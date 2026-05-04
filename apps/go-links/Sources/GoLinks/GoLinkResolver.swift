import Foundation

final class GoLinkResolver {
    private let queue = DispatchQueue(label: "com.golinks.resolver", attributes: .concurrent)
    private var orderedLinks: [GoLink] = []
    private var linksByName: [String: GoLink] = [:]

    func replace(with links: [GoLink]) {
        let ordered = links.sorted {
            $0.shortName.localizedStandardCompare($1.shortName) == .orderedAscending
        }
        let indexed = Dictionary(uniqueKeysWithValues: ordered.map { ($0.shortName, $0) })

        queue.sync(flags: .barrier) {
            orderedLinks = ordered
            linksByName = indexed
        }
    }

    func snapshot() -> [GoLink] {
        queue.sync { orderedLinks }
    }

    func destination(for rawName: String) -> String? {
        let key = (try? GoLinkInput.normalizedName(rawName)) ?? rawName.lowercased()
        return queue.sync { linksByName[key]?.destinationURL }
    }
}
