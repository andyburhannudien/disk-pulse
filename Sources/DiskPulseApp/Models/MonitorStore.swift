import Combine
import DiskPulseCore
import Foundation

final class MonitorStore: ObservableObject {
    @Published private(set) var reports: [DiskReport] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var history: [String: [ThermalSample]] = [:]

    @Published var selectedDiskID: String? {
        didSet { onUpdate?() }
    }

    let settings: AppSettings
    var onUpdate: (() -> Void)?

    private let historyStore: HistoryStore
    private let notifications: NotificationService
    private let scanQueue = DispatchQueue(label: "dev.diskpulse.scan", qos: .utility)
    private var timer: Timer?
    private var previousReports: [String: DiskReport] = [:]

    init(settings: AppSettings, historyStore: HistoryStore, notifications: NotificationService) {
        self.settings = settings
        self.historyStore = historyStore
        self.notifications = notifications
        self.history = historyStore.samples
        self.selectedDiskID = settings.preferredDiskID
    }

    var primaryReport: DiskReport? {
        if let preferred = settings.preferredDiskID,
           let match = reports.first(where: { $0.id == preferred }) {
            return match
        }
        return reports.first(where: { $0.isInternal && $0.isNVMe })
            ?? reports.first(where: { $0.isNVMe })
            ?? reports.first
    }

    var selectedReport: DiskReport? {
        if let id = selectedDiskID, let match = reports.first(where: { $0.id == id }) {
            return match
        }
        return primaryReport
    }

    func refresh() {
        guard !isScanning else { return }

        isScanning = true
        lastError = nil

        scanQueue.async { [weak self] in
            let scanned = DiskPulseScanner.scanAllDisks()
            DispatchQueue.main.async {
                self?.apply(scanned)
            }
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()

        let interval = settings.refreshInterval
        guard interval >= 5 else { return }

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = min(5, interval * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    func restartTimer() {
        startAutoRefresh()
    }

    func clearHistory() {
        historyStore.clear()
        history = [:]
    }

    private func apply(_ scanned: [DiskReport]) {
        isScanning = false

        guard !scanned.isEmpty else {
            lastError = "No disks could be scanned."
            onUpdate?()
            return
        }

        let now = Date()
        reports = scanned
        lastUpdated = now
        lastError = nil

        historyStore.persistenceEnabled = settings.keepHistory
        for report in scanned where report.nvmeMetrics != nil {
            history[report.id] = historyStore.record(report, at: now)
        }

        if let id = selectedDiskID, !scanned.contains(where: { $0.id == id }) {
            selectedDiskID = nil
        }
        if selectedDiskID == nil {
            selectedDiskID = primaryReport?.id
        }

        notifications.evaluate(reports: scanned, previous: previousReports, settings: settings)
        previousReports = Dictionary(scanned.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        onUpdate?()
    }
}
