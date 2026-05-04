import Foundation
import Darwin

/// A minimal HTTP/1.1 server that listens on `port` and redirects
/// go-link requests to their configured destinations.
final class HTTPServer {
    let port: UInt16
    private var serverSocket: Int32 = -1
    private var running = false
    private weak var store: GoLinkStore?

    init(port: UInt16 = 9876) {
        self.port = port
    }

    // MARK: - Lifecycle

    func start(store: GoLinkStore) {
        guard !running else { return }
        self.store = store

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runAcceptLoop()
        }
    }

    func stop() {
        running = false
        if serverSocket >= 0 {
            Darwin.close(serverSocket)
            serverSocket = -1
        }
    }

    // MARK: - Accept loop

    private func runAcceptLoop() {
        serverSocket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("[GoLinks] socket() failed: \(errno)")
            return
        }

        var yes: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &yes,
                   socklen_t(MemoryLayout<Int32>.size))
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEPORT, &yes,
                   socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            print("[GoLinks] bind() failed: \(errno)")
            Darwin.close(serverSocket)
            return
        }
        guard Darwin.listen(serverSocket, 32) == 0 else {
            print("[GoLinks] listen() failed: \(errno)")
            Darwin.close(serverSocket)
            return
        }

        running = true
        print("[GoLinks] Server listening on port \(port)")

        while running {
            let client = Darwin.accept(serverSocket, nil, nil)
            guard client >= 0 else {
                if running { print("[GoLinks] accept() failed: \(errno)") }
                break
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handle(client: client)
            }
        }
    }

    // MARK: - Request handling

    private func handle(client socket: Int32) {
        defer { Darwin.close(socket) }

        // Read up to 8 KB (enough for HTTP headers)
        var buf = [UInt8](repeating: 0, count: 8192)
        let n = Darwin.read(socket, &buf, buf.count - 1)
        guard n > 0 else { return }

        let raw = String(bytes: buf.prefix(n), encoding: .utf8) ?? ""
        let response = buildResponse(for: raw)
        let bytes = Array(response.utf8)
        Darwin.write(socket, bytes, bytes.count)
    }

    private func buildResponse(for requestText: String) -> String {
        // Parse first line: "GET /path?query HTTP/1.1"
        let lines = requestText.components(separatedBy: "\r\n")
        guard let firstLine = lines.first, firstLine.hasPrefix("GET ") else {
            return httpResponse(status: "405 Method Not Allowed", body: "<h1>Method Not Allowed</h1>")
        }

        let parts = firstLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 2 else {
            return httpResponse(status: "400 Bad Request", body: "<h1>Bad Request</h1>")
        }

        var rawPath = String(parts[1])
        if rawPath.hasPrefix("/") { rawPath = String(rawPath.dropFirst()) }

        // Split path and query string
        let queryIdx = rawPath.firstIndex(of: "?")
        let shortName: String
        let queryString: String
        if let qi = queryIdx {
            shortName = String(rawPath[rawPath.startIndex..<qi])
            queryString = String(rawPath[qi...]) // includes "?"
        } else {
            shortName = rawPath
            queryString = ""
        }

        // Root path → index page
        if shortName.isEmpty {
            return indexPage()
        }

        // Look up the go link
        var destination: String?
        if let store = store {
            // GoLinkStore is @MainActor; safely read on main thread
            DispatchQueue.main.sync {
                destination = store.destination(for: shortName)
            }
        }

        if let dest = destination {
            let location = dest + queryString
            return "HTTP/1.1 302 Found\r\n" +
                   "Location: \(location)\r\n" +
                   "Cache-Control: no-cache\r\n" +
                   "Content-Length: 0\r\n" +
                   "\r\n"
        } else {
            let body = """
            <html><head><title>Go Link Not Found</title>
            <style>body{font-family:system-ui;padding:2rem;max-width:600px;margin:auto}
            a{color:#007aff}</style></head><body>
            <h1>🔗 go/<em>\(escapeHTML(shortName))</em> not found</h1>
            <p>This go link hasn't been configured yet.</p>
            <p>Open the <strong>Go Links</strong> menu bar app to add it.</p>
            <p><a href="http://go/">← View all go links</a></p>
            </body></html>
            """
            return httpResponse(status: "404 Not Found", body: body)
        }
    }

    // MARK: - Index page

    private func indexPage() -> String {
        var links: [GoLink] = []
        if let store = store {
            DispatchQueue.main.sync {
                links = store.links
            }
        }

        var rows = ""
        for link in links.sorted(by: { $0.shortName < $1.shortName }) {
            rows += """
            <tr>
              <td><a href="http://go/\(link.shortName)">go/\(escapeHTML(link.shortName))</a></td>
              <td><a href="\(escapeHTML(link.destinationURL))" target="_blank">\(escapeHTML(link.destinationURL))</a></td>
            </tr>
            """
        }

        let body = """
        <html><head><title>Go Links</title>
        <style>
          body{font-family:system-ui;padding:2rem;max-width:800px;margin:auto;background:#f5f5f5}
          h1{color:#1d1d1f}
          table{width:100%;border-collapse:collapse;background:#fff;border-radius:10px;overflow:hidden;
                box-shadow:0 1px 3px rgba(0,0,0,.1)}
          th{background:#007aff;color:#fff;padding:10px 14px;text-align:left}
          td{padding:10px 14px;border-bottom:1px solid #eee}
          tr:last-child td{border-bottom:none}
          a{color:#007aff;text-decoration:none}
          a:hover{text-decoration:underline}
          .empty{text-align:center;padding:2rem;color:#888}
        </style></head><body>
        <h1>🔗 Go Links</h1>
        \(links.isEmpty
            ? "<p class='empty'>No go links configured. Open the menu bar app to add some.</p>"
            : "<table><thead><tr><th>Go Link</th><th>Destination</th></tr></thead><tbody>\(rows)</tbody></table>"
        )
        </body></html>
        """
        return httpResponse(status: "200 OK", body: body, contentType: "text/html; charset=utf-8")
    }

    // MARK: - Helpers

    private func httpResponse(status: String, body: String,
                               contentType: String = "text/html; charset=utf-8") -> String {
        let bodyBytes = body.utf8.count
        return "HTTP/1.1 \(status)\r\n" +
               "Content-Type: \(contentType)\r\n" +
               "Content-Length: \(bodyBytes)\r\n" +
               "Cache-Control: no-cache\r\n" +
               "\r\n" +
               body
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
