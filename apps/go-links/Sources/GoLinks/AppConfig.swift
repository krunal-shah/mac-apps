import Foundation
import Network

enum AppConfig {
    static let suiteName = "Mac Apps"
    static let appName = "Go Links"
    static let processName = "GoLinks"
    static let hostName = "go"
    static let pastePath = "paste"
    static let pathPlaceholder = "{path}"
    static let reservedShortNames = Set([pastePath])

    static let httpPort: UInt16 = 9876
    static let httpsPort: UInt16 = 9877

    static let pfAnchorName = "golinks"
    static let pfAnchorFile = "/etc/pf.anchors/golinks"
    static let setupMarker = "go-links-app"

    static let certificateDirectory = "/Library/GoLinks"
    static let certificatePath = "/Library/GoLinks/server.crt"
    static let privateKeyPath = "/Library/GoLinks/server.key"
    static let p12Path = "/Library/GoLinks/server.p12"
    static let p12Password = "golinks123"

    static let defaultsKey = "go_links_v2"
    static let legacyDefaultsKey = "go_links_v1"
    static let pasteDefaultsKey = "pastebin_v1"

    static var httpURL: URL {
        URL(string: "http://\(hostName)/")!
    }

    static func pasteURL(for pasteID: String, scheme: String = "https") -> String {
        "\(scheme)://\(hostName)/\(pastePath)/\(pasteID)"
    }

    static var httpsNWPort: NWEndpoint.Port {
        NWEndpoint.Port(rawValue: httpsPort)!
    }
}
