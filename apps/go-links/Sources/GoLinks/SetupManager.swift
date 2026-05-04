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

    let serverPort: UInt16 = 9876
    private let pfAnchorName = "golinks"
    private let pfAnchorFile = "/etc/pf.anchors/golinks"

    struct Diagnostics {
        var port80Process: String?
        var port9876Process: String?
        var pfNatRules: String
        var hostsGoLine: String?
        var tlsCertExists: Bool
    }

    private init() { refresh() }

    // MARK: - Status checks

    func refresh() {
        hostsConfigured = checkHostsEntry()
        pfConfigured = checkPFConf()
        pfActiveInKernel = checkPFKernel()
        tlsCertConfigured = FileManager.default.fileExists(atPath: TLSServer.p12Path)
    }

    private func checkHostsEntry() -> Bool {
        let lines = (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8))?.components(separatedBy: "\n") ?? []
        return lines.contains { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.hasPrefix("#"), t.hasPrefix("127.0.0.1") else { return false }
            return t.split(whereSeparator: \.isWhitespace).dropFirst().contains("go")
        }
    }

    private func checkPFConf() -> Bool {
        let pfConf = (try? String(contentsOfFile: "/etc/pf.conf", encoding: .utf8)) ?? ""
        return pfConf.contains("rdr-anchor \"\(pfAnchorName)\"")
    }

    private func checkPFKernel() -> Bool {
        // pfctl needs root to list rules. Use two proxy checks:
        // 1. The anchor file exists and contains the expected port (rules written to disk).
        // 2. nc can open a TCP connection to :80 (pf rdr is live and our server is running).
        let anchorHasRule = (try? String(contentsOfFile: pfAnchorFile, encoding: .utf8))?
            .contains("\(serverPort)") ?? false
        guard anchorHasRule else { return false }
        let exitCode = shell("nc -z -w1 127.0.0.1 80 2>/dev/null; echo $?")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return exitCode == "0"
    }

    // MARK: - Diagnostics

    func runDiagnostics() {
        let port80 = processOnPort(80)
        let port9876 = processOnPort(9876)
        let nat = shell("pfctl -s nat 2>/dev/null")
        let hosts = (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8))?
            .components(separatedBy: "\n")
            .first { $0.contains("127.0.0.1 go") }
        diagnostics = Diagnostics(
            port80Process: port80,
            port9876Process: port9876,
            pfNatRules: nat.isEmpty ? "(none / pf disabled)" : nat,
            hostsGoLine: hosts,
            tlsCertExists: FileManager.default.fileExists(atPath: TLSServer.p12Path)
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

        // Write setup shell script to a temp file to avoid escaping hell
        let scriptContent = setupShellScript()
        let tmpPath = "/tmp/golinks_setup.sh"
        do {
            try scriptContent.write(toFile: tmpPath, atomically: true, encoding: .utf8)
        } catch {
            lastError = "Failed to write setup script: \(error.localizedDescription)"
            return
        }

        let appleScript = "do shell script \"bash '\(tmpPath)'\" with administrator privileges"
        if let err = runAppleScript(appleScript) {
            lastError = err
        }
    }

    private func setupShellScript() -> String {
        let httpsPort = TLSServer.port.rawValue
        let certDir = TLSServer.certDir
        let p12Path = TLSServer.p12Path
        let p12Password = TLSServer.p12Password

        return """
        #!/bin/bash
        set -e

        # 1. /etc/hosts – add "127.0.0.1 go" if missing
        if ! grep -q '# go-links-app' /etc/hosts; then
            printf '\\n127.0.0.1 go  # go-links-app\\n' >> /etc/hosts
        fi

        # 2. pf anchor file – redirect :80 → :\(serverPort), :443 → :\(httpsPort)
        mkdir -p /etc/pf.anchors
        printf 'rdr pass on lo0 proto tcp from any to 127.0.0.1 port 80 -> 127.0.0.1 port \(serverPort)\\n' > \(pfAnchorFile)
        printf 'rdr pass on lo0 proto tcp from any to 127.0.0.1 port 443 -> 127.0.0.1 port \(httpsPort)\\n' >> \(pfAnchorFile)

        # 3. Insert rdr-anchor into pf.conf in the correct position
        #    pf requires: options, normalization, queueing, translation, filtering
        #    rdr-anchor (translation) MUST come before anchor (filtering)
        sed -i '' '/rdr-anchor "\(pfAnchorName)"/d' /etc/pf.conf
        sed -i '' '/load anchor "\(pfAnchorName)"/d' /etc/pf.conf

        LAST_RDR=$(grep -n 'rdr-anchor' /etc/pf.conf | tail -1 | cut -d: -f1)
        if [ -n "$LAST_RDR" ]; then
            head -n "$LAST_RDR" /etc/pf.conf > /tmp/pf_golinks.tmp
            echo 'rdr-anchor "\(pfAnchorName)"' >> /tmp/pf_golinks.tmp
            tail -n +"$((LAST_RDR + 1))" /etc/pf.conf >> /tmp/pf_golinks.tmp
            mv /tmp/pf_golinks.tmp /etc/pf.conf
        else
            echo 'rdr-anchor "\(pfAnchorName)"' >> /etc/pf.conf
        fi
        echo 'load anchor "\(pfAnchorName)" from "\(pfAnchorFile)"' >> /etc/pf.conf

        # 4. Enable pf and reload
        pfctl -e 2>/dev/null || true
        pfctl -f /etc/pf.conf 2>&1
        pfctl -a \(pfAnchorName) -f \(pfAnchorFile) 2>&1

        # 5. Generate TLS cert for https://go/ (if not already present)
        mkdir -p \(certDir)
        if [ ! -f "\(certDir)/server.crt" ]; then
            printf '[req]\\ndistinguished_name=dn\\nx509_extensions=v3\\nprompt=no\\n[dn]\\nCN=go\\n[v3]\\nsubjectAltName=DNS:go,IP:127.0.0.1\\nkeyUsage=keyEncipherment,dataEncipherment\\nextendedKeyUsage=serverAuth\\n' > /tmp/golinks_ssl.cnf
            /usr/bin/openssl req -x509 -newkey rsa:2048 \\
                -keyout \(certDir)/server.key \\
                -out \(certDir)/server.crt \\
                -days 3650 -nodes -config /tmp/golinks_ssl.cnf 2>/dev/null
            /usr/bin/openssl pkcs12 -export \\
                -inkey \(certDir)/server.key \\
                -in \(certDir)/server.crt \\
                -out \(p12Path) \\
                -passout pass:\(p12Password) 2>/dev/null
            rm -f /tmp/golinks_ssl.cnf
            chmod 644 \(certDir)/server.crt \(p12Path)
            chmod 600 \(certDir)/server.key
        fi

        # 6. Trust the cert in the System keychain (so Chrome accepts it)
        security add-trusted-cert -d -r trustRoot \\
            -k /Library/Keychains/System.keychain \\
            \(certDir)/server.crt 2>/dev/null || true
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
        sed -i '' '/# go-links-app/d' /etc/hosts 2>/dev/null || true
        sed -i '' '/rdr-anchor "\(pfAnchorName)"/d' /etc/pf.conf 2>/dev/null || true
        sed -i '' '/load anchor "\(pfAnchorName)"/d' /etc/pf.conf 2>/dev/null || true
        rm -f \(pfAnchorFile)
        pfctl -a \(pfAnchorName) -F all 2>/dev/null || true
        pfctl -f /etc/pf.conf 2>/dev/null || true
        security remove-trusted-cert \(TLSServer.certDir)/server.crt 2>/dev/null || true
        rm -rf \(TLSServer.certDir)
        """
        let tmpPath = "/tmp/golinks_teardown.sh"
        try? scriptContent.write(toFile: tmpPath, atomically: true, encoding: .utf8)
        let appleScript = "do shell script \"bash '\(tmpPath)'\" with administrator privileges"
        if let err = runAppleScript(appleScript) {
            lastError = err
        }
    }

    // MARK: - Re-apply pf on launch

    func reapplyPFIfNeeded() async {
        refresh()
        guard pfConfigured && !pfActiveInKernel else { return }
        let appleScript = """
        do shell script "pfctl -e 2>/dev/null || true; pfctl -f /etc/pf.conf 2>&1; pfctl -a \(pfAnchorName) -f \(pfAnchorFile) 2>&1" with administrator privileges
        """
        if let err = runAppleScript(appleScript) {
            lastError = err
        }
        refresh()
    }

    // MARK: - Helpers

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
}
