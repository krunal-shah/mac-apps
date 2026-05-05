import SwiftUI

struct SetupView: View {
    let onClose: () -> Void

    @EnvironmentObject private var setup: SetupManager

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppTheme.shelfRule)
            content
            Divider().background(AppTheme.shelfRule)
            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.shelfBase)
        .onAppear {
            setup.refresh()
            setup.runDiagnostics()
        }
    }

    private var header: some View {
        HStack(spacing: AppTheme.spacing8) {
            Text("Setup")
                .font(AppTheme.sans(15, weight: .semibold))
                .foregroundStyle(AppTheme.shelfInk)
            Spacer()
            ToolIconButton(systemName: "xmark", help: "Close", size: AppTheme.compactControlSize, action: onClose)
        }
        .padding(.horizontal, AppTheme.spacing16)
        .frame(height: AppTheme.headerHeight)
        .background(AppTheme.shelfBase)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing20) {
                section(title: "System") {
                    VStack(spacing: AppTheme.spacing6) {
                        StatusRow(
                            title: "Hostname",
                            value: "127.0.0.1 \(AppConfig.hostName)",
                            isComplete: setup.hostsConfigured
                        )
                        StatusRow(
                            title: "Port forwarding",
                            value: "80 → \(AppConfig.httpPort), 443 → \(AppConfig.httpsPort)",
                            isComplete: setup.pfConfigured
                        )
                        StatusRow(
                            title: "Active rule",
                            value: setup.pfActiveInKernel ? "Reachable on port 80" : "Not active",
                            isComplete: setup.pfActiveInKernel
                        )
                        StatusRow(
                            title: "HTTPS certificate",
                            value: setup.tlsCertConfigured ? "Installed" : "Missing",
                            isComplete: setup.tlsCertConfigured
                        )
                    }
                }

                section(title: "Diagnostics") {
                    if let diagnostics = setup.diagnostics {
                        VStack(spacing: AppTheme.spacing6) {
                            DiagnosticRow(label: "Port 80", value: diagnostics.port80Process ?? "no listener")
                            DiagnosticRow(label: "Port \(AppConfig.httpPort)", value: diagnostics.port9876Process ?? "no listener")
                            DiagnosticRow(label: "Port \(AppConfig.httpsPort)", value: diagnostics.port9877Process ?? "no listener")
                            DiagnosticRow(label: "Forward", value: diagnostics.httpForwardReachable ? "reachable" : "not reachable")
                            if let hostsLine = diagnostics.hostsGoLine {
                                DiagnosticRow(label: "Hosts", value: hostsLine)
                            }
                        }
                    } else {
                        Button {
                            setup.runDiagnostics()
                        } label: {
                            HStack(spacing: AppTheme.spacing6) {
                                Image(systemName: "stethoscope")
                                    .font(.system(size: 11))
                                Text("Run diagnostics")
                                    .font(AppTheme.sans(12, weight: .medium))
                            }
                            .foregroundStyle(AppTheme.shelfInk)
                            .padding(.horizontal, AppTheme.spacing12)
                            .padding(.vertical, AppTheme.spacing8)
                            .background(
                                Capsule(style: .continuous).fill(AppTheme.shelfAccentSoft)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let lastError = setup.lastError {
                    HStack(alignment: .top, spacing: AppTheme.spacing8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.shelfDanger)
                            .padding(.top, 1)
                        Text(lastError)
                            .font(AppTheme.sans(12))
                            .foregroundStyle(AppTheme.shelfDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(AppTheme.spacing12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                            .fill(AppTheme.shelfDanger.opacity(0.08))
                    )
                }
            }
            .padding(AppTheme.spacing20)
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing10) {
            Text(title)
                .font(AppTheme.sans(13, weight: .semibold))
                .foregroundStyle(AppTheme.shelfInk)
            content()
        }
    }

    private var actions: some View {
        HStack(spacing: AppTheme.spacing8) {
            FormButton(label: "Refresh", style: .secondary) {
                setup.refresh()
                setup.runDiagnostics()
            }
            .disabled(setup.isRunningSetup)

            if setup.hostsConfigured || setup.pfConfigured || setup.tlsCertConfigured {
                FormButton(label: "Remove", style: .secondary) {
                    Task { await setup.removeSetup() }
                }
                .disabled(setup.isRunningSetup)
            }

            Spacer()

            FormButton(label: "Done", style: .secondary) {
                onClose()
            }
            .keyboardShortcut(.escape, modifiers: [])

            if setup.isRunningSetup {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, AppTheme.spacing12)
            } else {
                FormButton(label: setup.hostsConfigured && setup.pfConfigured ? "Repair" : "Install", style: .primary) {
                    Task { await setup.runSetup() }
                }
            }
        }
        .padding(AppTheme.spacing16)
        .background(AppTheme.shelfBase)
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: AppTheme.spacing10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isComplete ? AppTheme.shelfReady : AppTheme.shelfInkMuted)
                .frame(width: AppTheme.rowIconWidth)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTheme.sans(12, weight: .medium))
                    .foregroundStyle(AppTheme.shelfInk)
                Text(value)
                    .font(AppTheme.mono(11))
                    .foregroundStyle(AppTheme.shelfInkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacing12)
        .padding(.vertical, AppTheme.spacing10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(AppTheme.shelfAccentSoft)
        )
    }
}

private struct DiagnosticRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacing10) {
            Text(label)
                .font(AppTheme.sans(11, weight: .medium))
                .foregroundStyle(AppTheme.shelfInkTertiary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(AppTheme.mono(11))
                .foregroundStyle(AppTheme.shelfInk)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, AppTheme.spacing12)
        .padding(.vertical, AppTheme.spacing8)
    }
}
