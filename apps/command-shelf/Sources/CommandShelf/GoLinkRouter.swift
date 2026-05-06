import Foundation

struct GoLinkRouter {
    private let linkResolver: GoLinkResolver
    private let pasteResolver: PasteResolver

    init(linkResolver: GoLinkResolver, pasteResolver: PasteResolver) {
        self.linkResolver = linkResolver
        self.pasteResolver = pasteResolver
    }

    func responseData(for requestData: Data, scheme: String) -> Data {
        let request = HTTPRequest(data: requestData)
        guard let request else {
            return HTTPResponse.badRequest().data()
        }

        guard request.method == "GET" || request.method == "HEAD" else {
            return HTTPResponse.methodNotAllowed().data()
        }

        let route = routeTarget(request.target)
        let response: HTTPResponse

        switch route {
        case .index:
            response = indexResponse(scheme: scheme)
        case .pasteIndex:
            response = pasteIndexResponse(scheme: scheme)
        case .paste(let id, let raw):
            response = pasteResponse(id: id, raw: raw, scheme: scheme)
        case .lookup(let path, let query):
            if let resolution = linkResolver.resolution(for: path) {
                response = .redirect(
                    to: destinationURL(
                        base: resolution.link.destinationURL,
                        suffixPath: resolution.suffixPath,
                        query: query
                    )
                )
            } else {
                response = missingResponse(shortName: path, scheme: scheme)
            }
        case .invalid:
            response = .badRequest()
        }

        return response.data(includeBody: request.method != "HEAD")
    }

    private enum Route {
        case index
        case pasteIndex
        case paste(id: String, raw: Bool)
        case lookup(path: String, query: String?)
        case invalid
    }

    private func routeTarget(_ rawTarget: String) -> Route {
        let target = normalizedOriginTarget(rawTarget)
        guard target != "*" else { return .invalid }

        let parts = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let rawPath = parts.first.map(String.init) ?? "/"
        let query = parts.count > 1 ? String(parts[1]) : nil

        var path = rawPath
        while path.hasPrefix("/") {
            path.removeFirst()
        }

        guard !path.isEmpty else { return .index }

        let pathParts = path.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard let rawShortName = pathParts.first, !rawShortName.isEmpty else { return .invalid }

        let decodedName = String(rawShortName).removingPercentEncoding ?? String(rawShortName)

        if decodedName == AppConfig.pastePath {
            guard pathParts.count > 1 else { return .pasteIndex }
            let pasteParts = String(pathParts[1]).split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            guard let rawID = pasteParts.first, !rawID.isEmpty else { return .pasteIndex }
            let id = (String(rawID).removingPercentEncoding ?? String(rawID)).lowercased()
            let raw = pasteParts.count > 1 && pasteParts[1] == "raw"
            return .paste(id: id, raw: raw)
        }

        return .lookup(path: path, query: query)
    }

    private func normalizedOriginTarget(_ rawTarget: String) -> String {
        guard let components = URLComponents(string: rawTarget), components.scheme != nil else {
            return rawTarget
        }

        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        if let query = components.percentEncodedQuery {
            return "\(path)?\(query)"
        }
        return path
    }

    private func destinationURL(base: String, suffixPath: String, query: String?) -> String {
        if base.contains(AppConfig.pathPlaceholder) {
            return templatedDestinationURL(base: base, suffixPath: suffixPath, query: query)
        }

        guard var components = URLComponents(string: base) else {
            return base
        }

        appendRawQuery(query, to: &components)

        return components.url?.absoluteString ?? base
    }

    private func templatedDestinationURL(base: String, suffixPath: String, query: String?) -> String {
        let pathValue = suffixPath.hasPrefix("/") ? String(suffixPath.dropFirst()) : suffixPath
        let destination = base.replacingOccurrences(of: AppConfig.pathPlaceholder, with: pathValue)

        guard var components = URLComponents(string: destination) else {
            return appendRawQuery(query, to: destination)
        }

        appendRawQuery(query, to: &components)
        return components.url?.absoluteString ?? appendRawQuery(query, to: destination)
    }

    private func appendRawQuery(_ query: String?, to components: inout URLComponents) {
        guard let query, !query.isEmpty else { return }

        if let existing = components.percentEncodedQuery, !existing.isEmpty {
            components.percentEncodedQuery = "\(existing)&\(query)"
        } else {
            components.percentEncodedQuery = query
        }
    }

    private func appendRawQuery(_ query: String?, to destination: String) -> String {
        guard let query, !query.isEmpty else { return destination }
        return destination.contains("?") ? "\(destination)&\(query)" : "\(destination)?\(query)"
    }

    private func indexResponse(scheme: String) -> HTTPResponse {
        let links = linkResolver.snapshot()
        let pastes = pasteResolver.snapshot()
        let rows = links.map { link in
            """
            <tr>
              <td><a href="\(scheme)://\(AppConfig.hostName)/\(html(link.shortName))">\(AppConfig.hostName)/\(html(link.shortName))</a></td>
              <td><a href="\(html(link.destinationURL))">\(html(link.destinationURL))</a></td>
            </tr>
            """
        }.joined(separator: "\n")

        let content = links.isEmpty
            ? "<p class=\"empty\">No links have been added yet.</p>"
            : "<table><thead><tr><th>Shortcut</th><th>Destination</th></tr></thead><tbody>\(rows)</tbody></table>"

        let pasteLink = "\(scheme)://\(AppConfig.hostName)/\(AppConfig.pastePath)"

        return .html(
            status: "200 OK",
            body: page(
                title: AppConfig.suiteName,
                body: """
                <h1>\(AppConfig.suiteName)</h1>
                <nav><a href="\(html(pasteLink))">Pastes (\(pastes.count))</a></nav>
                <h2>Links</h2>
                \(content)
                """
            )
        )
    }

    private func pasteIndexResponse(scheme: String) -> HTTPResponse {
        let pastes = pasteResolver.snapshot()
        let rows = pastes.map { paste in
            let url = "\(scheme)://\(AppConfig.hostName)/\(AppConfig.pastePath)/\(paste.id)"
            return """
            <tr>
              <td><a href="\(html(url))">\(html(paste.title))</a></td>
              <td><code>\(html(paste.id))</code></td>
              <td>\(html(relativeDate(paste.updatedAt)))</td>
            </tr>
            """
        }.joined(separator: "\n")

        let content = pastes.isEmpty
            ? "<p class=\"empty\">No pastes have been added yet.</p>"
            : "<table><thead><tr><th>Title</th><th>ID</th><th>Updated</th></tr></thead><tbody>\(rows)</tbody></table>"

        return .html(
            status: "200 OK",
            body: page(title: "Pastes", body: "<h1>Pastes</h1>\(content)")
        )
    }

    private func pasteResponse(id: String, raw: Bool, scheme: String) -> HTTPResponse {
        guard let paste = pasteResolver.paste(id: id) else {
            return .html(
                status: "404 Not Found",
                body: page(
                    title: "Paste Not Found",
                    body: """
                    <h1>Paste not found</h1>
                    <p>No paste exists for <code>\(html(id))</code>.</p>
                    <p><a href="\(scheme)://\(AppConfig.hostName)/\(AppConfig.pastePath)">View all pastes</a></p>
                    """
                )
            )
        }

        if raw {
            return .text(status: "200 OK", body: paste.body)
        }

        let rawURL = "\(scheme)://\(AppConfig.hostName)/\(AppConfig.pastePath)/\(paste.id)/raw"
        return .html(
            status: "200 OK",
            body: page(
                title: paste.title,
                body: """
                <h1>\(html(paste.title))</h1>
                <p><a href="\(html(rawURL))">Raw text</a> · Updated \(html(relativeDate(paste.updatedAt)))</p>
                <pre>\(html(paste.body))</pre>
                """
            )
        )
    }

    private func missingResponse(shortName: String, scheme: String) -> HTTPResponse {
        .html(
            status: "404 Not Found",
            body: page(
                title: "Go Link Not Found",
                body: """
                <h1>\(AppConfig.hostName)/\(html(shortName)) was not found</h1>
                <p>Open \(AppConfig.appName) from the menu bar to add it.</p>
                <p><a href="\(scheme)://\(AppConfig.hostName)/">View all links</a></p>
                """
            )
        )
    }

    private func page(title: String, body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(html(title))</title>
          <style>
            :root { color-scheme: light dark; }
            body { margin: 0; padding: 40px 24px; font: 14px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: Canvas; color: CanvasText; }
            main { max-width: 820px; margin: 0 auto; }
            h1 { font-size: 24px; line-height: 1.2; margin: 0 0 20px; }
            h2 { font-size: 16px; margin: 28px 0 12px; }
            p { color: color-mix(in srgb, CanvasText 72%, transparent); }
            nav { margin: 0 0 20px; }
            table { width: 100%; border-collapse: collapse; border: 1px solid color-mix(in srgb, CanvasText 16%, transparent); border-radius: 8px; overflow: hidden; }
            th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid color-mix(in srgb, CanvasText 12%, transparent); }
            th { font-size: 12px; text-transform: uppercase; letter-spacing: 0; color: color-mix(in srgb, CanvasText 62%, transparent); background: color-mix(in srgb, CanvasText 6%, transparent); }
            tr:last-child td { border-bottom: 0; }
            pre { white-space: pre-wrap; overflow-wrap: anywhere; padding: 16px; border: 1px solid color-mix(in srgb, CanvasText 14%, transparent); border-radius: 8px; background: color-mix(in srgb, CanvasText 5%, transparent); }
            code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
            a { color: LinkText; text-decoration: none; }
            a:hover { text-decoration: underline; }
            .empty { padding: 24px; border: 1px solid color-mix(in srgb, CanvasText 14%, transparent); border-radius: 8px; }
          </style>
        </head>
        <body><main>\(body)</main></body>
        </html>
        """
    }

    private func html(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct HTTPRequest {
    let method: String
    let target: String

    init?(data: Data) {
        guard let text = String(data: data, encoding: .utf8),
              let firstLine = text.components(separatedBy: "\r\n").first
        else {
            return nil
        }

        let parts = firstLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        method = String(parts[0]).uppercased()
        target = String(parts[1])
    }
}

private struct HTTPResponse {
    let status: String
    let headers: [(String, String)]
    let body: Data

    static func html(status: String, body: String) -> HTTPResponse {
        HTTPResponse(
            status: status,
            headers: [
                ("Content-Type", "text/html; charset=utf-8"),
                ("Cache-Control", "no-cache")
            ],
            body: Data(body.utf8)
        )
    }

    static func text(status: String, body: String) -> HTTPResponse {
        HTTPResponse(
            status: status,
            headers: [
                ("Content-Type", "text/plain; charset=utf-8"),
                ("Cache-Control", "no-cache")
            ],
            body: Data(body.utf8)
        )
    }

    static func redirect(to location: String) -> HTTPResponse {
        HTTPResponse(
            status: "302 Found",
            headers: [
                ("Location", location),
                ("Cache-Control", "no-cache")
            ],
            body: Data()
        )
    }

    static func badRequest() -> HTTPResponse {
        .html(status: "400 Bad Request", body: "<h1>Bad Request</h1>")
    }

    static func methodNotAllowed() -> HTTPResponse {
        HTTPResponse(
            status: "405 Method Not Allowed",
            headers: [
                ("Allow", "GET, HEAD"),
                ("Content-Type", "text/html; charset=utf-8"),
                ("Cache-Control", "no-cache")
            ],
            body: Data("<h1>Method Not Allowed</h1>".utf8)
        )
    }

    func data(includeBody: Bool = true) -> Data {
        var headerLines = ["HTTP/1.1 \(status)"]
        var allHeaders = headers
        allHeaders.append(("Content-Length", "\(body.count)"))
        allHeaders.append(("Connection", "close"))
        headerLines.append(contentsOf: allHeaders.map { "\($0.0): \($0.1)" })
        headerLines.append("")
        headerLines.append("")

        var data = Data(headerLines.joined(separator: "\r\n").utf8)
        if includeBody {
            data.append(body)
        }
        return data
    }
}
