import AppKit
import DiskPulseCore
import SwiftUI

struct DiskDetailView: View {
    let report: DiskReport
    let samples: [ThermalSample]
    let lastUpdated: Date?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if let metrics = report.nvmeMetrics {
                    health(metrics)
                    thermal(metrics)
                    endurance(metrics)
                    integrity(metrics)
                    advice(metrics)
                    rawData
                } else {
                    EmptyStateView(
                        icon: "externaldrive.badge.questionmark",
                        title: "S.M.A.R.T. details unavailable",
                        message: "NVMe metrics are only available for whole internal disks. Select the parent disk (for example disk0) rather than a partition."
                    )
                    .padding(.vertical, 30)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: report.isSolidState ? "internaldrive.fill" : "externaldrive.fill")
                .font(.system(size: 30))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(report.mediaName)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)

                Text("\(report.deviceIdentifier) · \(report.deviceNode) · \(report.protocolType)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("\(report.totalSizeFormatted) · \(report.isInternal ? "Internal" : "External") · SMART \(report.smartStatus)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let metrics = report.nvmeMetrics {
                GradeBadge(grade: metrics.healthGrade)
            }
        }
    }

    private func health(_ metrics: NVMeSMARTMetrics) -> some View {
        SectionCard("Health") {
            HStack(spacing: 24) {
                HealthGaugeView(percentage: metrics.healthPercentage, size: 124, lineWidth: 10)

                VStack(alignment: .leading, spacing: 7) {
                    InfoRow(label: "Wear level", value: "\(metrics.percentageUsed)% used")
                    InfoRow(
                        label: "Spare reserve",
                        value: "\(metrics.availableSpare)%",
                        valueColor: HealthPalette.color(
                            forSpare: metrics.availableSpare,
                            threshold: metrics.availableSpareThreshold
                        )
                    )
                    InfoRow(label: "Spare threshold", value: "\(metrics.availableSpareThreshold)%")
                    InfoRow(label: "SMART status", value: report.smartStatus)
                    InfoRow(label: "Last updated", value: Formatters.relative(lastUpdated))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func thermal(_ metrics: NVMeSMARTMetrics) -> some View {
        let values = samples.map(\.temperatureCelsius)
        let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)

        return SectionCard("Thermal & History") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Formatters.temperature(metrics.temperatureCelsius))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(HealthPalette.color(forTemperature: metrics.temperatureCelsius))

                Text(Formatters.temperatureFahrenheit(metrics.temperatureFahrenheit))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                Text(metrics.thermalStatus)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            ThermalChartView(samples: samples, height: 120)

            HStack(spacing: 20) {
                stat("MIN", values.isEmpty ? "—" : Formatters.temperature(values.min() ?? 0))
                stat("AVG", average.map { Formatters.temperature($0) } ?? "—")
                stat("MAX", values.isEmpty ? "—" : Formatters.temperature(values.max() ?? 0))
                Spacer()
                stat("SAMPLES", "\(values.count)")
            }
        }
    }

    private func endurance(_ metrics: NVMeSMARTMetrics) -> some View {
        SectionCard("Endurance & Workload") {
            LazyVGrid(columns: columns, spacing: 8) {
                MetricTile(icon: "square.and.arrow.up", title: "TOTAL WRITTEN", value: Formatters.terabytes(metrics.tbw))
                MetricTile(icon: "square.and.arrow.down", title: "TOTAL READ", value: Formatters.terabytes(metrics.tbr))
                MetricTile(icon: "calendar", title: "AVG DAILY WRITES", value: Formatters.gigabytes(metrics.dailyWriteRateGB) + "/day")
                MetricTile(icon: "clock", title: "POWER ON HOURS", value: Formatters.hours(metrics.powerOnHours))
                MetricTile(icon: "arrow.up.circle", title: "HOST WRITES", value: Formatters.decimal(metrics.hostWriteCommands))
                MetricTile(icon: "arrow.down.circle", title: "HOST READS", value: Formatters.decimal(metrics.hostReadCommands))
            }

            InfoRow(
                label: "Raw data units written",
                value: String(format: "%.0f", metrics.dataUnitsWrittenTotal)
            )
            InfoRow(
                label: "Raw data units read",
                value: String(format: "%.0f", metrics.dataUnitsReadTotal)
            )
        }
    }

    private func integrity(_ metrics: NVMeSMARTMetrics) -> some View {
        SectionCard("Integrity & Reliability") {
            LazyVGrid(columns: columns, spacing: 8) {
                MetricTile(
                    icon: "exclamationmark.triangle",
                    title: "MEDIA ERRORS",
                    value: Formatters.decimal(metrics.mediaErrors),
                    valueColor: metrics.mediaErrors > 0 ? .red : .primary
                )
                MetricTile(
                    icon: "list.bullet.rectangle",
                    title: "ERROR LOG ENTRIES",
                    value: Formatters.decimal(metrics.numErrorInfoEntries)
                )
                MetricTile(
                    icon: "power",
                    title: "UNSAFE SHUTDOWNS",
                    value: Formatters.decimal(metrics.unsafeShutdowns),
                    valueColor: metrics.unsafeShutdowns > 0 ? .orange : .primary
                )
                MetricTile(icon: "arrow.clockwise", title: "POWER CYCLES", value: Formatters.decimal(metrics.powerCycles))
                MetricTile(
                    icon: "timer",
                    title: "CONTROLLER BUSY",
                    value: "\(Formatters.decimal(metrics.controllerBusyTimeMinutes)) min"
                )
                MetricTile(icon: "internaldrive", title: "CAPACITY", value: report.totalSizeFormatted)
            }
        }
    }

    private func advice(_ metrics: NVMeSMARTMetrics) -> some View {
        SectionCard("Diagnostic Summary") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(adviceLines(metrics), id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var rawData: some View {
        let json = ReportExporter.jsonString(report: report)

        return SectionCard("Raw Data") {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(json)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxHeight: 220)

                    HStack {
                        Button("Copy JSON") { ReportExporter.copyToPasteboard(json) }
                        Button("Export") { ReportExporter.export(reports: [report]) }
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.top, 6)
            } label: {
                Text("SMART JSON")
                    .font(.system(size: 11, weight: .medium))
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
    }

    private func adviceLines(_ metrics: NVMeSMARTMetrics) -> [String] {
        switch metrics.healthGrade {
        case .excellent, .good:
            return [
                "✔ SSD is in prime operating condition.",
                "• Minimal NAND flash wear (\(metrics.percentageUsed)% utilized).",
                "• Spare block reserves at \(metrics.availableSpare)%.",
                metrics.mediaErrors == 0
                    ? "• ECC reporting shows zero unrecoverable failures."
                    : "• Media errors detected — back up data immediately."
            ]
        case .fair:
            return [
                "▲ Moderate wear detected (\(metrics.percentageUsed)% used).",
                "• Keep regular backups running."
            ]
        case .warning:
            return [
                "▲ SSD wear is significant or spare blocks are depleting.",
                "• Ensure Time Machine or cloud backups are active.",
                "• Plan a replacement if health continues to drop."
            ]
        case .critical:
            return [
                "✖ IMMEDIATE ACTION RECOMMENDED: SSD health is critical.",
                "• Back up all essential data immediately.",
                "• Replace the drive to prevent data loss."
            ]
        }
    }
}
