import SwiftUI

struct SetupView: View {
    let onClose: () -> Void

    @EnvironmentObject private var setup: SetupManager

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            actions
        }
        .onAppear {
            setup.refresh()
            setup.runDiagnostics()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Status")

                VStack(spacing: 8) {
                    StatusRow(
                        title: "Hostname",
                        value: "127.0.0.1 \(AppConfig.hostName)",
                        isComplete: setup.hostsConfigured
                    )
                    StatusRow(
                        title: "Port Forwarding",
                        value: "80 -> \(AppConfig.httpPort), 443 -> \(AppConfig.httpsPort)",
                        isComplete: setup.pfConfigured
                    )
                    StatusRow(
                        title: "Active Rule",
                        value: setup.pfActiveInKernel ? "Reachable on port 80" : "Not active",
                        isComplete: setup.pfActiveInKernel
                    )
                    StatusRow(
                        title: "HTTPS Certificate",
                        value: setup.tlsCertConfigured ? "Installed" : "Missing",
                        isComplete: setup.tlsCertConfigured
                    )
                }

                sectionTitle("Diagnostics")

                if let diagnostics = setup.diagnostics {
                    VStack(alignment: .leading, spacing: 8) {
                        DiagnosticRow(label: "Port 80", value: diagnostics.port80Process ?? "No listener")
                        DiagnosticRow(label: "Port \(AppConfig.httpPort)", value: diagnostics.port9876Process ?? "No listener")
                        DiagnosticRow(label: "Port \(AppConfig.httpsPort)", value: diagnostics.port9877Process ?? "No listener")
                        DiagnosticRow(label: "Forward Check", value: diagnostics.httpForwardReachable ? "Reachable" : "Not reachable")
                        if let hostsLine = diagnostics.hostsGoLine {
                            DiagnosticRow(label: "Hosts", value: hostsLine)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Button {
                        setup.runDiagnostics()
                    } label: {
                        Label("Run Diagnostics", systemImage: "stethoscope")
                    }
                }

                if let lastError = setup.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
        }
    }

    private var actions: some View {
        HStack {
            Button {
                setup.refresh()
                setup.runDiagnostics()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(setup.isRunningSetup)

            if setup.hostsConfigured || setup.pfConfigured || setup.tlsCertConfigured {
                Button(role: .destructive) {
                    Task { await setup.removeSetup() }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .disabled(setup.isRunningSetup)
            }

            Spacer()

            Button("Done") {
                onClose()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button {
                Task { await setup.runSetup() }
            } label: {
                if setup.isRunningSetup {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 72)
                } else {
                    Label(setup.hostsConfigured && setup.pfConfigured ? "Repair" : "Install", systemImage: "lock.shield")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(setup.isRunningSetup)
        }
        .padding(16)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DiagnosticRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }
}
