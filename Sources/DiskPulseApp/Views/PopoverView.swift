import AppKit
import DiskPulseCore
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var store: MonitorStore

    let openDashboard: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
        }
        .frame(width: 360, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        if let report = store.selectedReport {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(report)

                    if let metrics = report.nvmeMetrics {
                        health(metrics)
                        metricsGrid(metrics)
                        chartSection(report)
                    } else {
                        EmptyStateView(
                            icon: "externaldrive.badge.questionmark",
                            title: "S.M.A.R.T. details unavailable",
                            message: "NVMe metrics can only be read from a whole physical disk such as disk0."
                        )
                    }

                    if !AppEnvironment.isBundled {
                        Text("Running outside DiskPulse.app — notifications and launch at login are unavailable.")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
            }
        } else {
            VStack(spacing: 10) {
                if store.isScanning {
                    ProgressView()
                }

                Text(store.isScanning ? "Scanning disks…" : (store.lastError ?? "No disks found"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if !store.isScanning {
                    Button("Scan Again") { store.refresh() }
                        .font(.system(size: 11))
                }
            }
            .padding(20)
        }
    }

    private func header(_ report: DiskReport) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: report.isSolidState ? "internaldrive.fill" : "externaldrive.fill")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(report.mediaName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("\(report.deviceIdentifier) · \(report.totalSizeFormatted)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 6)

            if let metrics = report.nvmeMetrics {
                GradeBadge(grade: metrics.healthGrade)
            }
        }
    }

    private func health(_ metrics: NVMeSMARTMetrics) -> some View {
        HStack(spacing: 14) {
            HealthGaugeView(percentage: metrics.healthPercentage, size: 92, lineWidth: 8)

            VStack(alignment: .leading, spacing: 5) {
                InfoRow(label: "Wear level", value: "\(metrics.percentageUsed)% used")
                InfoRow(
                    label: "Spare reserve",
                    value: "\(metrics.availableSpare)% / \(metrics.availableSpareThreshold)%",
                    valueColor: HealthPalette.color(
                        forSpare: metrics.availableSpare,
                        threshold: metrics.availableSpareThreshold
                    )
                )
                InfoRow(label: "Updated", value: Formatters.relative(store.lastUpdated))

                if store.isScanning {
                    Text("Refreshing…")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func metricsGrid(_ metrics: NVMeSMARTMetrics) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            MetricTile(
                icon: "thermometer",
                title: "TEMPERATURE",
                value: Formatters.temperature(metrics.temperatureCelsius),
                valueColor: HealthPalette.color(forTemperature: metrics.temperatureCelsius)
            )
            MetricTile(icon: "square.and.arrow.up", title: "WRITTEN", value: Formatters.terabytes(metrics.tbw))
            MetricTile(icon: "square.and.arrow.down", title: "READ", value: Formatters.terabytes(metrics.tbr))
            MetricTile(
                icon: "calendar",
                title: "DAILY WRITES",
                value: Formatters.gigabytes(metrics.dailyWriteRateGB)
            )
            MetricTile(icon: "clock", title: "POWER ON", value: Formatters.hours(metrics.powerOnHours))
            MetricTile(
                icon: "exclamationmark.triangle",
                title: "MEDIA ERRORS",
                value: Formatters.decimal(metrics.mediaErrors),
                valueColor: metrics.mediaErrors > 0 ? .red : .primary
            )
        }
    }

    private func chartSection(_ report: DiskReport) -> some View {
        let samples = store.history[report.id] ?? []

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("THERMAL HISTORY")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(samples.count) samples")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            ThermalChartView(samples: samples, height: 56, compact: true)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button { store.refresh() } label: {
                if store.isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .help("Refresh now")

            if let metrics = store.selectedReport?.nvmeMetrics {
                Text("\(metrics.healthGrade.rawValue.capitalized) · \(Formatters.time(store.lastUpdated))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            GitHubButton(size: 13)

            Button(action: openDashboard) {
                Image(systemName: "macwindow")
            }
            .help("Open dashboard")

            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .help("Settings")

            Button(action: quit) {
                Image(systemName: "power")
            }
            .help("Quit DiskPulse")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
