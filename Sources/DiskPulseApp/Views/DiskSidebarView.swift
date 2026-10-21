import DiskPulseCore
import SwiftUI

struct DiskSidebarView: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DISKS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(store.reports.count)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)

            List(selection: selection) {
                ForEach(store.reports) { report in
                    row(report)
                        .tag(report.id)
                }
            }
            .listStyle(.sidebar)
        }
        .background(Color.primary.opacity(0.02))
    }

    private var selection: Binding<String?> {
        Binding(
            get: { store.selectedDiskID },
            set: { newValue in
                store.selectedDiskID = newValue
                store.settings.preferredDiskID = newValue
            }
        )
    }

    private func row(_ report: DiskReport) -> some View {
        HStack(spacing: 8) {
            Image(systemName: report.isSolidState ? "internaldrive.fill" : "externaldrive.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(report.mediaName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Text("\(report.deviceIdentifier) · \(report.totalSizeFormatted)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            if report.isNVMe {
                Circle()
                    .fill(HealthPalette.color(for: report))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 3)
    }
}
