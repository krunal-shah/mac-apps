import Foundation
import Network
import Security

final class TLSServer {

    // MARK: - Config (referenced by SetupManager too)

    static let port = AppConfig.httpsNWPort
    static let certDir = AppConfig.certificateDirectory
    static let p12Path = AppConfig.p12Path
    static let p12Password = AppConfig.p12Password

    // MARK: - State

    private let router: GoLinkRouter
    private let queue = DispatchQueue(label: "com.krunalshah.commandshelf.https-server")
    private var listener: NWListener?

    init(router: GoLinkRouter) {
        self.router = router
    }

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }

        guard let identity = loadIdentity() else {
            print("[CommandShelf] TLS identity not found; HTTPS is disabled until setup runs")
            return
        }

        let tlsOpts = NWProtocolTLS.Options()
        guard let localIdentity = sec_identity_create(identity) else {
            print("[CommandShelf] TLS identity conversion failed")
            return
        }
        sec_protocol_options_set_local_identity(tlsOpts.securityProtocolOptions, localIdentity)

        let params = NWParameters(tls: tlsOpts)
        params.allowLocalEndpointReuse = true

        do {
            listener = try NWListener(using: params, on: Self.port)
        } catch {
            print("[CommandShelf] TLS listener init failed: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] conn in
            self?.handle(connection: conn)
        }
        listener?.stateUpdateHandler = { state in
            if case .failed(let err) = state {
                print("[CommandShelf] TLS server error: \(err)")
            }
        }
        listener?.start(queue: queue)
        print("[CommandShelf] HTTPS server listening on port \(Self.port.rawValue)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Identity loading

    private func loadIdentity() -> SecIdentity? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.p12Path)) else {
            return nil
        }
        let opts: [String: Any] = [kSecImportExportPassphrase as String: Self.p12Password]
        var items: CFArray?
        guard SecPKCS12Import(data as CFData, opts as CFDictionary, &items) == errSecSuccess,
              let arr = items as? [[String: Any]],
              let identityRef = arr.first?[kSecImportItemIdentity as String]
        else { return nil }
        guard CFGetTypeID(identityRef as CFTypeRef) == SecIdentityGetTypeID() else {
            return nil
        }
        return (identityRef as! SecIdentity)
    }

    // MARK: - Connection handling

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data, !data.isEmpty else {
                connection.cancel()
                return
            }
            let response = self.router.responseData(for: data, scheme: "https")
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
