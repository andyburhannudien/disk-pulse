import AppKit
import DiskPulseCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.reports.isEmpty {
                emptyState
            } else {
                HSplitView {
                    DiskSidebarView()
                        .frame(minWidth: 220, idealWidth: 240, maxWidth: 300)

                    detail
                        .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("DiskPulse")
                    .font(.system(size: 14, weight: .semibold))
                Text("Updated \(Formatters.relative(store.lastUpdated))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if store.isScanning {
                ProgressView().controlSize(.small)
            }

            Button { store.refresh() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Button { copySelectedJSON() } label: {
                Label("Copy JSON", systemImage: "doc.on.doc")
            }

            Button { ReportExporter.export(reports: store.reports) } label: {
                Label("Export", systemImage: "square.and.arrow.down")
            }

            GitHubButton(size: 14)

            Button {
                NotificationCenter.default.post(name: .diskPulseShowSettings, object: nil)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            if store.isScanning {
                ProgressView()
            }

            Text(store.lastError ?? (store.isScanning ? "Scanning disks…" : "No disks found"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Button("Scan Again") { store.refresh() }
                .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var detail: some View {
        if let report = store.selectedReport {
            DiskDetailView(
                report: report,
                samples: store.history[report.id] ?? [],
                lastUpdated: store.lastUpdated
            )
        } else {
            EmptyStateView(
                icon: "internaldrive",
                title: "No disk selected",
                message: "Choose a disk from the sidebar."
            )
        }
    }

    private func copySelectedJSON() {
        guard let report = store.selectedReport else { return }
        ReportExporter.copyToPasteboard(ReportExporter.jsonString(report: report))
    }
}
