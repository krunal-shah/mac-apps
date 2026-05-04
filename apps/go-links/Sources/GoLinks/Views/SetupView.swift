import SwiftUI

struct SetupView: View {
    @EnvironmentObject var setup: SetupManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("System Setup")
                    .font(.headline)
                Spacer()
                Button("Done") { SetupPanel.shared.close() }
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Status ──────────────────────────────────────────
                    GroupBox("System Status") {
                        VStack(spacing: 8) {
                            StatusRow(
                                title: "/etc/hosts entry",
                                description: "Maps the hostname `go` → 127.0.0.1.",
                                isComplete: setup.hostsConfigured
                            )
                            StatusRow(
                                title: "pf.conf anchor (persistent)",
                                description: "Survives reboots. Redirects :80 → :\(setup.serverPort).",
                                isComplete: setup.pfConfigured
                            )
                            StatusRow(
                                title: "pf rule active in kernel",
                                description: "Port forwarding is live right now.",
                                isComplete: setup.pfActiveInKernel
                            )
                        }
                    }

                    // ── Chrome Note ─────────────────────────────────────
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Chrome / Arc tip", systemImage: "info.circle")
                                .font(.subheadline).fontWeight(.semibold)

                            Text("""
                            Chrome treats single-word addresses without a dot (like `go`) \
                            as search queries. **Two fixes:**
                            """)
                            .font(.caption)
                            .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                tipRow(
                                    number: "1",
                                    title: "Type the full URL once",
                                    detail: "In Chrome's address bar type http://go/ (with http://) once. Chrome will remember go is a hostname from then on."
                                )
                                tipRow(
                                    number: "2",
                                    title: "Add a Chrome search shortcut (alternative)",
                                    detail: "Settings → Search engines → Site Search → Add. Set keyword to go and URL to http://localhost:\(setup.serverPort)/%s. Then type: go [tab] mylink."
                                )
                            }

                            Button {
                                NSWorkspace.shared.open(URL(string: "http://go/")!)
                            } label: {
                                Label("Open http://go/ in browser", systemImage: "arrow.up.right.square")
                                    .font(.caption)
                            }
                            .disabled(!setup.hostsConfigured || !setup.pfActiveInKernel)
                        }
                    }

                    // ── Diagnostics ─────────────────────────────────────
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Port Diagnostics", systemImage: "stethoscope")
                                    .font(.subheadline).fontWeight(.semibold)
                                Spacer()
                                Button("Refresh") {
                                    setup.refresh()
                                    setup.runDiagnostics()
                                }
                                .font(.caption)
                            }

                            if let d = setup.diagnostics {
                                diagRow(port: 80,  process: d.port80Process)
                                diagRow(port: Int(setup.serverPort), process: d.port9876Process)

                                if let hosts = d.hostsGoLine {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green).font(.caption)
                                        Text(hosts)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if d.port80Process != nil && d.port80Process != "GoLinks" {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange).font(.caption)
                                        Text("Another process is on port 80. The pf redirect can't reach our server. Quit that process or uninstall any other go-link tool before running Setup.")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(8)
                                    .background(Color.orange.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            } else {
                                Button("Run Diagnostics") {
                                    setup.runDiagnostics()
                                }
                                .font(.caption)
                            }
                        }
                    }

                    // ── Error ───────────────────────────────────────────
                    if let err = setup.lastError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(16)
            }

            Divider()

            // ── Actions ─────────────────────────────────────────────────
            HStack {
                if setup.hostsConfigured || setup.pfConfigured {
                    Button(role: .destructive) {
                        Task { await setup.removeSetup() }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .disabled(setup.isRunningSetup)
                }

                Spacer()

                Button {
                    Task { await setup.runSetup() }
                } label: {
                    if setup.isRunningSetup {
                        ProgressView().controlSize(.small).padding(.horizontal, 6)
                    } else {
                        Label(
                            setup.hostsConfigured && setup.pfConfigured
                                ? "Re-apply Setup" : "Run Setup",
                            systemImage: "lock.shield"
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(setup.isRunningSetup)
            }
            .padding(16)
        }
        .frame(width: 440)
        .onAppear {
            setup.refresh()
            setup.runDiagnostics()
        }
    }

    // MARK: - Private helpers

    private func tipRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2).fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Color.accentColor)
                .clipShape(Circle())
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).fontWeight(.medium)
                Text(detail).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func diagRow(port: Int, process: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: process != nil ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundColor(process != nil ? .green : .secondary)
                .font(.caption)
            Text(":\(port)")
                .font(.system(.caption, design: .monospaced))
            Text(process ?? "nothing listening")
                .font(.caption)
                .foregroundColor(process != nil ? .primary : .secondary)
            Spacer()
        }
    }
}

private struct StatusRow: View {
    let title: String
    let description: String
    let isComplete: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .secondary)
                .font(.system(size: 16))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
