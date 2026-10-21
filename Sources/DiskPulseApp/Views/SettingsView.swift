import AppKit
import DiskPulseCore
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: MonitorStore

    @State private var notificationStatus = "Unknown"
    @State private var notificationMessage: String?
    @State private var loginError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                generalSection
                alertsSection
                disksSection
                historySection
                aboutSection
            }
            .padding(18)
        }
        .frame(width: 460, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { refreshNotificationStatus() }
    }

    private var generalSection: some View {
        SectionCard("General") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Refresh interval")
                        .font(.system(size: 11))
                    Spacer()
                    Picker("", selection: $settings.refreshInterval) {
                        Text("15 seconds").tag(TimeInterval(15))
                        Text("30 seconds").tag(TimeInterval(30))
                        Text("60 seconds").tag(TimeInterval(60))
                        Text("5 minutes").tag(TimeInterval(300))
                        Text("Manual").tag(TimeInterval(0))
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .onChange(of: settings.refreshInterval) { _ in
                        store.restartTimer()
                    }
                }

                HStack {
                    Text("Menu bar display")
                        .font(.system(size: 11))
                    Spacer()
                    Picker("", selection: $settings.menuBarDisplay) {
                        ForEach(AppSettings.MenuBarDisplay.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }

                Toggle("Launch at login", isOn: loginBinding)
                    .font(.system(size: 11))

                if let loginError = loginError {
                    warning(loginError)
                } else if let appPath = env.loginItem.appPath, !appPath.hasPrefix("/Applications/") {
                    warning("Move DiskPulse to /Applications for reliable launch at login.")
                }
            }
        }
    }

    private var alertsSection: some View {
        SectionCard("Alerts") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
                    .font(.system(size: 11))
                    .onChange(of: settings.notificationsEnabled) { enabled in
                        guard enabled else {
                            notificationMessage = nil
                            return
                        }

                        env.notifications.requestAuthorization { granted in
                            refreshNotificationStatus()
                            if !granted {
                                settings.notificationsEnabled = false
                                notificationMessage = "Permission was denied. Enable notifications for DiskPulse in System Settings."
                            }
                        }
                    }

                HStack {
                    Text("Thermal alert threshold")
                        .font(.system(size: 11))
                    Spacer()
                    Stepper(
                        "\(Int(settings.temperatureThreshold))°C",
                        value: $settings.temperatureThreshold,
                        in: 50...90,
                        step: 1
                    )
                    .font(.system(size: 11))
                    .fixedSize()
                }

                Toggle("Alert when health drops 5 points", isOn: $settings.notifyHealthDrop)
                    .font(.system(size: 11))

                Toggle("Alert on new media errors", isOn: $settings.notifyMediaErrors)
                    .font(.system(size: 11))

                Text("Status: \(notificationStatus)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                if !AppEnvironment.isBundled {
                    warning("Notifications require running DiskPulse from its app bundle.")
                }

                if let notificationMessage = notificationMessage {
                    warning(notificationMessage)
                }

                HStack {
                    Button("Send Test Notification") {
                        env.notifications.sendTestNotification()
                    }
                    .font(.system(size: 11))

                    Spacer()

                    Button("Notification Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 11))
                }
            }
        }
    }

    private var disksSection: some View {
        SectionCard("Disks") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Preferred disk")
                        .font(.system(size: 11))
                    Spacer()
                    Picker("", selection: preferredDiskBinding) {
                        Text("Automatic").tag(Optional<String>.none)
                        ForEach(store.reports) { report in
                            Text("\(report.mediaName) (\(report.deviceIdentifier))")
                                .tag(Optional(report.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 230)
                }

                Text("Automatic selects the internal NVMe boot disk.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var historySection: some View {
        SectionCard("History") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Keep temperature history on disk", isOn: $settings.keepHistory)
                    .font(.system(size: 11))
                    .onChange(of: settings.keepHistory) { enabled in
                        env.historyStore.persistenceEnabled = enabled
                    }

                Text("\(sampleCount) samples stored across \(store.reports.count) disks.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Button("Clear History") { store.clearHistory() }
                    .font(.system(size: 11))
                    .disabled(sampleCount == 0)
            }
        }
    }

    private var aboutSection: some View {
        SectionCard("About") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("DiskPulse \(env.version)")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    if let url = URL(string: "https://github.com/andyburhannudien/disk-pulse") {
                        Link("GitHub", destination: url)
                            .font(.system(size: 11))
                    }
                }

                Text("Bundled CLI: \(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/diskpulse").path)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)

                Text("NVMe S.M.A.R.T. data is read through diskutil. No kernel extensions required.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { newValue in
                do {
                    try env.loginItem.setEnabled(newValue)
                    settings.launchAtLogin = newValue
                    loginError = nil
                } catch {
                    settings.launchAtLogin = env.loginItem.isEnabled
                    loginError = error.localizedDescription
                }
            }
        )
    }

    private var preferredDiskBinding: Binding<String?> {
        Binding(
            get: { settings.preferredDiskID },
            set: { newValue in
                settings.preferredDiskID = newValue
                store.selectedDiskID = newValue ?? store.primaryReport?.id
            }
        )
    }

    private var sampleCount: Int {
        store.history.values.reduce(0) { $0 + $1.count }
    }

    private func refreshNotificationStatus() {
        env.notifications.authorizationStatus { status in
            notificationStatus = statusText(status)
        }
    }

    private func statusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not requested"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private func warning(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(.orange)
    }
}
