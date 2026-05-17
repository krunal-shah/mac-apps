import Foundation

/// Lightweight async HTTP client for the Syl FastAPI server.
///
/// Base URL defaults to the Tailscale Serve endpoint, which is reachable
/// from any Mac on the tailnet. Identity is forwarded as `X-User`.
@MainActor
final class SylClient {
    static let defaultBaseURL = URL(string: "https://homeservers-mbp.tailb2984e.ts.net")!

    let baseURL: URL
    private let identity: Identity
    private let session: URLSession

    init(baseURL: URL = SylClient.defaultBaseURL, identity: Identity, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.identity = identity
        self.session = session
    }

    // MARK: - Stream event

    private struct LauncherStreamEvent: Decodable {
        let text: String?
        let done: Bool?
    }

    // MARK: - Errors

    enum SylClientError: LocalizedError {
        case invalidEndpoint(String)
        case http(status: Int, body: String?)
        case transport(Error)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint(let endpoint):
                return "Invalid endpoint: \(endpoint)"
            case .http(let status, let body):
                if let body, !body.isEmpty {
                    return "HTTP \(status): \(body)"
                }
                return "HTTP \(status)"
            case .transport(let error):
                return error.localizedDescription
            case .decoding(let error):
                return "Decoding error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Request building

    private func makeRequest(
        method: String,
        endpoint: String,
        body: [String: String]? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw SylClientError.invalidEndpoint(endpoint)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.uppercased()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(identity.activeUser.rawValue, forHTTPHeaderField: "X-User")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        return request
    }

    // MARK: - Calls

    /// Fire-and-acknowledge JSON request. Throws on non-2xx.
    @discardableResult
    func send(
        method: String,
        endpoint: String,
        body: [String: String]? = nil
    ) async throws -> Data {
        let request = try makeRequest(method: method, endpoint: endpoint, body: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SylClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SylClientError.http(status: 0, body: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw SylClientError.http(status: http.statusCode, body: body)
        }
        return data
    }

    /// Stream an SSE response, calling `onChunk` for each text chunk that
    /// arrives. The closure runs on the main actor (the client is itself
    /// main-isolated, so the for-await loop resumes here between awaits).
    ///
    /// Terminates when the server sends `{"done": true}` or the connection
    /// closes. Throws on transport / HTTP / decode failures.
    func stream(
        method: String = "POST",
        endpoint: String,
        body: [String: String]? = nil,
        onChunk: (String) -> Void
    ) async throws {
        let request = try makeRequest(method: method, endpoint: endpoint, body: body)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw SylClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SylClientError.http(status: 0, body: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SylClientError.http(status: http.statusCode, body: nil)
        }

        for try await line in bytes.lines {
            // SSE protocol: lines starting with `data:` carry the payload;
            // blank lines separate events; comment lines (`:`) ignored.
            guard line.hasPrefix("data:") else { continue }
            let payload = line
                .dropFirst("data:".count)
                .trimmingCharacters(in: .whitespaces)
            guard !payload.isEmpty, payload != "[DONE]" else { continue }

            guard let data = payload.data(using: .utf8) else { continue }
            let event: LauncherStreamEvent
            do {
                event = try JSONDecoder().decode(LauncherStreamEvent.self, from: data)
            } catch {
                // Malformed chunks shouldn't kill the stream — log and continue.
                NSLog("[CommandShelf] Stream decode error: %@ payload: %@", String(describing: error), payload)
                continue
            }

            if let text = event.text, !text.isEmpty {
                onChunk(text)
            }
            if event.done == true {
                return
            }
        }
    }

    /// Cheap reachability probe — used by the palette to show a status badge.
    func ping() async -> Bool {
        guard let url = URL(string: "/", relativeTo: baseURL) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<500).contains(http.statusCode) // 4xx still means Syl is up
        } catch {
            return false
        }
    }
}
