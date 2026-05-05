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
            VStack(alignment: .leading, spacing: AppTheme.spacing16) {
                sectionTitle("Status")

                VStack(spacing: AppTheme.spacing8) {
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
                    VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                        DiagnosticRow(label: "Port 80", value: diagnostics.port80Process ?? "No listener")
                        DiagnosticRow(label: "Port \(AppConfig.httpPort)", value: diagnostics.port9876Process ?? "No listener")
                        DiagnosticRow(label: "Port \(AppConfig.httpsPort)", value: diagnostics.port9877Process ?? "No listener")
                        DiagnosticRow(label: "Forward Check", value: diagnostics.httpForwardReachable ? "Reachable" : "Not reachable")
                        if let hostsLine = diagnostics.hostsGoLine {
                            DiagnosticRow(label: "Hosts", value: hostsLine)
                        }
                    }
                    .padding(AppTheme.spacing12)
                    .background(AppTheme.groupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
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
                        .foregroundStyle(.red)
                        .padding(AppTheme.spacing12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }
            }
            .padding(AppTheme.spacing16)
        }
    }

    private var actions: some View {
        HStack(spacing: AppTheme.spacing8) {
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
        .padding(AppTheme.spacing16)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .bold()
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? Color.green : .secondary)
                .frame(width: AppTheme.rowIconWidth)

            VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                Text(title)
                    .font(.subheadline)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(AppTheme.spacing12)
        .background(AppTheme.groupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

private struct DiagnosticRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacing8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }
}
