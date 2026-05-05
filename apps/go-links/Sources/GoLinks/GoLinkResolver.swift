import Foundation

struct GoLinkResolution: Equatable {
    let link: GoLink
    let suffixPath: String
}

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

    func resolution(for rawPath: String) -> GoLinkResolution? {
        let rawSegments = rawPath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !rawSegments.isEmpty else { return nil }

        let normalizedSegments = rawSegments.map {
            (($0.removingPercentEncoding ?? $0).lowercased())
        }

        return queue.sync {
            for prefixLength in stride(from: normalizedSegments.count, through: 1, by: -1) {
                let candidate = normalizedSegments.prefix(prefixLength).joined(separator: "/")
                guard let link = linksByName[candidate] else { continue }

                let suffixSegments = rawSegments.dropFirst(prefixLength)
                let suffixPath = suffixSegments.isEmpty ? "" : "/" + suffixSegments.joined(separator: "/")
                return GoLinkResolution(link: link, suffixPath: suffixPath)
            }

            return nil
        }
    }
}
