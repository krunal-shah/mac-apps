import Foundation
import AppKit

@MainActor
final class SetupManager: ObservableObject {
    static let shared = SetupManager()

    @Published var hostsConfigured = false
    @Published var pfConfigured = false
    @Published var pfActiveInKernel = false
    @Published var tlsCertConfigured = false
    @Published var isRunningSetup = false
    @Published var lastError: String?
    @Published var diagnostics: Diagnostics?

    let serverPort = AppConfig.httpPort

    struct Diagnostics {
        var port80Process: String?
        var port9876Process: String?
        var port9877Process: String?
        var pfNatRules: String
        var hostsGoLine: String?
        var tlsCertExists: Bool
        var httpForwardReachable: Bool
    }

    private init() { refresh() }

    // MARK: - Status checks

    func refresh() {
        hostsConfigured = checkHostsEntry()
        pfConfigured = checkPFConf()
        pfActiveInKernel = checkPFKernel()
        tlsCertConfigured = FileManager.default.fileExists(atPath: AppConfig.p12Path)
    }

    private func checkHostsEntry() -> Bool {
        let lines = (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8))?.components(separatedBy: "\n") ?? []
        return lines.contains { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.hasPrefix("#"), t.hasPrefix("127.0.0.1") else { return false }
            return t.split(whereSeparator: \.isWhitespace)
                .dropFirst()
                .contains { $0 == AppConfig.hostName }
        }
    }

    private func checkPFConf() -> Bool {
        let pfConf = (try? String(contentsOfFile: "/etc/pf.conf", encoding: .utf8)) ?? ""
        let anchorExists = FileManager.default.fileExists(atPath: AppConfig.pfAnchorFile)
        return anchorExists
            && pfConf.contains("rdr-anchor \"\(AppConfig.pfAnchorName)\"")
            && pfConf.contains("load anchor \"\(AppConfig.pfAnchorName)\"")
    }

    private func checkPFKernel() -> Bool {
        let anchorHasRule = (try? String(contentsOfFile: AppConfig.pfAnchorFile, encoding: .utf8))?
            .contains("\(serverPort)") ?? false
        guard anchorHasRule else { return false }
        return shellExitCode("/usr/bin/nc -z -G 1 127.0.0.1 80 >/dev/null 2>&1") == 0
    }

    // MARK: - Diagnostics

    func runDiagnostics() {
        let port80 = processOnPort(80)
        let port9876 = processOnPort(Int(AppConfig.httpPort))
        let port9877 = processOnPort(Int(AppConfig.httpsPort))
        let nat = shell("pfctl -s nat 2>/dev/null")
        let hosts = (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8))?
            .components(separatedBy: "\n")
            .first { $0.contains("127.0.0.1 \(AppConfig.hostName)") }
        diagnostics = Diagnostics(
            port80Process: port80,
            port9876Process: port9876,
            port9877Process: port9877,
            pfNatRules: nat.isEmpty ? "(none / pf disabled)" : nat,
            hostsGoLine: hosts,
            tlsCertExists: FileManager.default.fileExists(atPath: AppConfig.p12Path),
            httpForwardReachable: shellExitCode("/usr/bin/nc -z -G 1 127.0.0.1 80 >/dev/null 2>&1") == 0
        )
    }

    private func processOnPort(_ port: Int) -> String? {
        // lsof -i :PORT -sTCP:LISTEN -Fc outputs lines like "pNAME"
        let out = shell("lsof -i :\(port) -sTCP:LISTEN -Fc 2>/dev/null")
        // grab the first "p" prefixed line (process name)
        for line in out.components(separatedBy: "\n") where line.hasPrefix("c") {
            return String(line.dropFirst())
        }
        return nil
    }

    // MARK: - Full Setup

    func runSetup() async {
        isRunningSetup = true
        lastError = nil
        defer {
            isRunningSetup = false
            refresh()
            runDiagnostics()
        }

        if let err = runAdminScript(setupShellScript(), prefix: "golinks-setup") {
            lastError = err
        }
    }

    private func setupShellScript() -> String {
        return """
        #!/bin/bash
        set -e

        HOST_NAME="\(AppConfig.hostName)"
        HOST_MARKER="# \(AppConfig.setupMarker)"
        PF_ANCHOR_NAME="\(AppConfig.pfAnchorName)"
        PF_ANCHOR_FILE="\(AppConfig.pfAnchorFile)"
        HTTP_PORT="\(AppConfig.httpPort)"
        HTTPS_PORT="\(AppConfig.httpsPort)"
        CERT_DIR="\(AppConfig.certificateDirectory)"
        CERT_PATH="\(AppConfig.certificatePath)"
        KEY_PATH="\(AppConfig.privateKeyPath)"
        P12_PATH="\(AppConfig.p12Path)"
        P12_PASSWORD_PATH="\(AppConfig.p12PasswordPath)"
        USER_HOME="\(NSHomeDirectory())"

        if ! /usr/bin/grep -Eq "^[[:space:]]*127[.]0[.]0[.]1[[:space:]]+([^#[:space:]]+[[:space:]]+)*${HOST_NAME}([[:space:]]|$)" /etc/hosts; then
            /usr/bin/printf '\\n127.0.0.1 %s  %s\\n' "$HOST_NAME" "$HOST_MARKER" >> /etc/hosts
        fi

        /bin/mkdir -p /etc/pf.anchors
        /usr/bin/printf 'rdr pass on lo0 inet proto tcp from any to 127.0.0.1 port 80 -> 127.0.0.1 port %s\\n' "$HTTP_PORT" > "$PF_ANCHOR_FILE"
        /usr/bin/printf 'rdr pass on lo0 inet proto tcp from any to 127.0.0.1 port 443 -> 127.0.0.1 port %s\\n' "$HTTPS_PORT" >> "$PF_ANCHOR_FILE"

        /usr/bin/sed -i '' "/rdr-anchor \\"${PF_ANCHOR_NAME}\\"/d" /etc/pf.conf
        /usr/bin/sed -i '' "/load anchor \\"${PF_ANCHOR_NAME}\\"/d" /etc/pf.conf

        PF_TMP="$(/usr/bin/mktemp /tmp/golinks-pf.XXXXXX)"
        /usr/bin/awk -v anchor="$PF_ANCHOR_NAME" -v file="$PF_ANCHOR_FILE" '
            BEGIN { inserted = 0 }
            inserted == 0 && $1 == "anchor" {
                printf "rdr-anchor \\"%s\\"\\n", anchor
                inserted = 1
            }
            { print }
            END {
                if (inserted == 0) {
                    printf "rdr-anchor \\"%s\\"\\n", anchor
                }
                printf "load anchor \\"%s\\" from \\"%s\\"\\n", anchor, file
            }
        ' /etc/pf.conf > "$PF_TMP"
        /bin/cp "$PF_TMP" /etc/pf.conf
        /bin/rm -f "$PF_TMP"

        /sbin/pfctl -e 2>/dev/null || true
        /sbin/pfctl -f /etc/pf.conf 2>&1
        /sbin/pfctl -a "$PF_ANCHOR_NAME" -f "$PF_ANCHOR_FILE" 2>&1

        /bin/mkdir -p "$CERT_DIR"
        NEEDS_CERT=0
        if [ ! -f "$CERT_PATH" ] || [ ! -f "$P12_PATH" ]; then
            NEEDS_CERT=1
        elif ! /usr/bin/openssl x509 -in "$CERT_PATH" -noout -text 2>/dev/null | /usr/bin/grep -q "Digital Signature"; then
            NEEDS_CERT=1
        elif /usr/bin/openssl x509 -in "$CERT_PATH" -noout -issuer 2>/dev/null | /usr/bin/grep -q "issuer=CN = go\\|issuer=CN=go"; then
            NEEDS_CERT=1
        fi

        if [ "$NEEDS_CERT" -eq 1 ]; then
            MKCERT_BIN=""
            if [ -x /opt/homebrew/bin/mkcert ]; then
                MKCERT_BIN="/opt/homebrew/bin/mkcert"
            elif [ -x /usr/local/bin/mkcert ]; then
                MKCERT_BIN="/usr/local/bin/mkcert"
            fi

            MKCERT_CAROOT="$USER_HOME/Library/Application Support/mkcert"
            USED_MKCERT=0
            if [ -n "$MKCERT_BIN" ] && [ -f "$MKCERT_CAROOT/rootCA.pem" ]; then
                CAROOT="$MKCERT_CAROOT" "$MKCERT_BIN" \\
                    -cert-file "$CERT_PATH" \\
                    -key-file "$KEY_PATH" \\
                    "$HOST_NAME" 127.0.0.1 >/dev/null
                USED_MKCERT=1
            else
                SSL_CONFIG="$(/usr/bin/mktemp /tmp/golinks-ssl.XXXXXX)"
                /usr/bin/printf '[req]\\ndistinguished_name=dn\\nx509_extensions=v3\\nprompt=no\\n[dn]\\nCN=%s\\n[v3]\\nbasicConstraints=critical,CA:TRUE\\nsubjectAltName=DNS:%s,IP:127.0.0.1\\nkeyUsage=critical,digitalSignature,keyEncipherment,keyCertSign\\nextendedKeyUsage=serverAuth\\n' "$HOST_NAME" "$HOST_NAME" > "$SSL_CONFIG"
                /usr/bin/openssl req -x509 -newkey rsa:2048 \\
                    -keyout "$KEY_PATH" \\
                    -out "$CERT_PATH" \\
                    -days 3650 -nodes -config "$SSL_CONFIG" 2>/dev/null
                /bin/rm -f "$SSL_CONFIG"
            fi

            P12_PASSWORD="$(/usr/bin/openssl rand -base64 24 | /usr/bin/tr -d '\\n')"
            /usr/bin/openssl pkcs12 -export \\
                -inkey "$KEY_PATH" \\
                -in "$CERT_PATH" \\
                -out "$P12_PATH" \\
                -passout pass:"$P12_PASSWORD" 2>/dev/null
            /usr/bin/printf '%s' "$P12_PASSWORD" > "$P12_PASSWORD_PATH"
            /bin/chmod 644 "$CERT_PATH" "$P12_PATH"
            /bin/chmod 600 "$KEY_PATH" "$P12_PASSWORD_PATH"

            if [ "$USED_MKCERT" -eq 0 ]; then
                /usr/bin/security add-trusted-cert -d -r trustRoot \\
                    -p ssl -p basic \\
                    -k /Library/Keychains/System.keychain \\
                    "$CERT_PATH" 2>/dev/null || true
            fi
        fi
        """
    }

    // MARK: - Remove Setup

    func removeSetup() async {
        isRunningSetup = true
        lastError = nil
        defer {
            isRunningSetup = false
            refresh()
            runDiagnostics()
        }

        let scriptContent = """
        #!/bin/bash
        PF_ANCHOR_NAME="\(AppConfig.pfAnchorName)"
        PF_ANCHOR_FILE="\(AppConfig.pfAnchorFile)"
        CERT_DIR="\(AppConfig.certificateDirectory)"
        CERT_PATH="\(AppConfig.certificatePath)"

        /usr/bin/sed -i '' '/# \(AppConfig.setupMarker)/d' /etc/hosts 2>/dev/null || true
        /usr/bin/sed -i '' "/rdr-anchor \\"${PF_ANCHOR_NAME}\\"/d" /etc/pf.conf 2>/dev/null || true
        /usr/bin/sed -i '' "/load anchor \\"${PF_ANCHOR_NAME}\\"/d" /etc/pf.conf 2>/dev/null || true
        /bin/rm -f "$PF_ANCHOR_FILE"
        /sbin/pfctl -a "$PF_ANCHOR_NAME" -F all 2>/dev/null || true
        /sbin/pfctl -f /etc/pf.conf 2>/dev/null || true
        /usr/bin/security remove-trusted-cert "$CERT_PATH" 2>/dev/null || true
        /bin/rm -rf "$CERT_DIR"
        """
        if let err = runAdminScript(scriptContent, prefix: "golinks-teardown") {
            lastError = err
        }
    }

    // MARK: - Re-apply pf on launch

    func reapplyPFIfNeeded() async {
        refresh()
        guard pfConfigured && !pfActiveInKernel else { return }
        let appleScript = """
        do shell script "/sbin/pfctl -e 2>/dev/null || true; /sbin/pfctl -f /etc/pf.conf 2>&1; /sbin/pfctl -a \(AppConfig.pfAnchorName) -f \(AppConfig.pfAnchorFile) 2>&1" with administrator privileges
        """
        if let err = runAppleScript(appleScript) {
            lastError = err
        }
        refresh()
    }

    // MARK: - Helpers

    private func runAdminScript(_ script: String, prefix: String) -> String? {
        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix)-\(UUID().uuidString).sh")

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        } catch {
            return "Failed to prepare setup script: \(error.localizedDescription)"
        }

        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let command = "/bin/bash \(shellQuote(scriptURL.path))"
        let appleScript = "do shell script \"\(appleScriptQuote(command))\" with administrator privileges"
        return runAppleScript(appleScript)
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else {
            return "Failed to create AppleScript"
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let err = errorInfo {
            return err["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
        }
        return nil
    }

    private func shellExitCode(_ command: String) -> Int32 {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return 127
        }
    }

    func shell(_ command: String) -> String {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptQuote(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
