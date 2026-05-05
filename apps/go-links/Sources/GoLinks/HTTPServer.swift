import Foundation
import Network

final class HTTPServer {
    let port: UInt16
    private let router: GoLinkRouter
    private let queue = DispatchQueue(label: "com.golinks.http-server")
    private var listener: NWListener?

    init(port: UInt16 = AppConfig.httpPort, router: GoLinkRouter) {
        self.port = port
        self.router = router
    }

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            print("[CommandShelf] Invalid HTTP port: \(port)")
            return
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        do {
            listener = try NWListener(using: parameters, on: endpointPort)
        } catch {
            print("[CommandShelf] HTTP listener failed: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener?.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("[CommandShelf] HTTP server failed: \(error)")
            }
        }

        listener?.start(queue: queue)
        print("[CommandShelf] HTTP server listening on port \(port)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data, !data.isEmpty else {
                connection.cancel()
                return
            }

            let response = self.router.responseData(for: data, scheme: "http")
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
