import DiskPulseCore
import Foundation
import os
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private enum Rule: String {
        case thermal
        case spare
        case mediaErrors
        case gradeDrop
        case healthDrop
    }

    static var isBundleAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "dev.diskpulse", category: "notifications")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
    }

    func configure(delegate: UNUserNotificationCenterDelegate) {
        guard let center = notificationCenter else { return }
        center.delegate = delegate
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard let center = notificationCenter else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error = error {
                self?.logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            }
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        guard let center = notificationCenter else {
            DispatchQueue.main.async { completion(.denied) }
            return
        }

        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    func evaluate(reports: [DiskReport], previous: [String: DiskReport], settings: AppSettings) {
        guard Self.isBundleAvailable,
              settings.notificationsEnabled,
              notificationCenter != nil else {
            return
        }

        for report in reports {
            guard let metrics = report.nvmeMetrics else { continue }

            updateHealthBaseline(for: report, metrics: metrics, settings: settings)

            guard let previousReport = previous[report.id],
                  let previousMetrics = previousReport.nvmeMetrics else {
                continue
            }

            if metrics.temperatureCelsius >= settings.temperatureThreshold,
               canNotify(.thermal, disk: report.id, cooldown: 30 * 60) {
                deliver(
                    title: "SSD temperature high",
                    body: "\(report.mediaName) is at \(String(format: "%.1f", metrics.temperatureCelsius))°C (threshold \(Int(settings.temperatureThreshold))°C)."
                )
            }

            if metrics.isSpareCritical,
               canNotify(.spare, disk: report.id, cooldown: 24 * 60 * 60) {
                deliver(
                    title: "Spare blocks below threshold",
                    body: "\(report.mediaName) has \(metrics.availableSpare)% spare blocks (threshold \(metrics.availableSpareThreshold)%)."
                )
            }

            if settings.notifyMediaErrors,
               metrics.mediaErrors > previousMetrics.mediaErrors,
               canNotify(.mediaErrors, disk: report.id, cooldown: 6 * 60 * 60) {
                deliver(
                    title: "Media errors detected",
                    body: "\(report.mediaName) reported \(metrics.mediaErrors) media errors. Back up important data."
                )
            }

            if metrics.healthGrade.severityRank > previousMetrics.healthGrade.severityRank,
               canNotify(.gradeDrop, disk: report.id, cooldown: 24 * 60 * 60) {
                deliver(
                    title: "Drive health degraded",
                    body: "\(report.mediaName) changed from \(previousMetrics.healthGrade.rawValue) to \(metrics.healthGrade.rawValue)."
                )
            }
        }
    }

    func sendTestNotification() {
        guard notificationCenter != nil else { return }

        requestAuthorization { [weak self] granted in
            guard granted else { return }
            self?.deliver(title: "DiskPulse", body: "Test notification — SSD alerts are working.")
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private var notificationCenter: UNUserNotificationCenter? {
        guard Self.isBundleAvailable else { return nil }
        return UNUserNotificationCenter.current()
    }

    private func updateHealthBaseline(for report: DiskReport, metrics: NVMeSMARTMetrics, settings: AppSettings) {
        let baselineKey = "healthBaseline.\(report.id)"

        guard defaults.object(forKey: baselineKey) != nil else {
            defaults.set(metrics.healthPercentage, forKey: baselineKey)
            return
        }

        guard settings.notifyHealthDrop else { return }

        let baseline = defaults.integer(forKey: baselineKey)
        let drop = baseline - metrics.healthPercentage
        if drop >= 5, canNotify(.healthDrop, disk: report.id, cooldown: 24 * 60 * 60) {
            deliver(
                title: "SSD health dropped",
                body: "\(report.mediaName) fell from \(baseline)% to \(metrics.healthPercentage)% health. Consider a backup."
            )
            defaults.set(metrics.healthPercentage, forKey: baselineKey)
        }
    }

    private func canNotify(_ rule: Rule, disk: String, cooldown: TimeInterval) -> Bool {
        let key = "lastNotified.\(rule.rawValue).\(disk)"
        let now = Date().timeIntervalSince1970
        let last = defaults.double(forKey: key)

        guard now - last >= cooldown else { return false }
        defaults.set(now, forKey: key)
        return true
    }

    private func deliver(title: String, body: String) {
        guard let center = notificationCenter else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}
