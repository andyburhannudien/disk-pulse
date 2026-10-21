import DiskPulseCore
import Foundation
import os

final class HistoryStore {
    static let retentionInterval: TimeInterval = 24 * 60 * 60
    static let minimumSampleSpacing: TimeInterval = 60
    static let maxSamplesPerDisk = 1_440

    private(set) var samples: [String: [ThermalSample]] = [:]
    var persistenceEnabled = true

    private let fileURL: URL
    private let logger = Logger(subsystem: "dev.diskpulse", category: "history")
    private var pendingSave: DispatchWorkItem?

    init() {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("DiskPulse", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("history.json")
        load()
    }

    func record(_ report: DiskReport, at date: Date = Date()) -> [ThermalSample] {
        guard let metrics = report.nvmeMetrics else {
            return samples[report.id] ?? []
        }

        var list = samples[report.id] ?? []

        if let last = list.last, date.timeIntervalSince(last.date) < Self.minimumSampleSpacing {
            return list
        }

        list.append(ThermalSample(
            date: date,
            temperatureCelsius: metrics.temperatureCelsius,
            healthPercentage: metrics.healthPercentage,
            tbw: metrics.tbw,
            mediaErrors: metrics.mediaErrors
        ))

        let cutoff = date.addingTimeInterval(-Self.retentionInterval)
        list.removeAll { $0.date < cutoff }

        if list.count > Self.maxSamplesPerDisk {
            list.removeFirst(list.count - Self.maxSamplesPerDisk)
        }

        samples[report.id] = list
        scheduleSave()
        return list
    }

    func clear() {
        samples = [:]
        persistImmediately()
    }

    func persistImmediately() {
        pendingSave?.cancel()
        pendingSave = nil

        guard persistenceEnabled else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(samples)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save history: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleSave() {
        guard persistenceEnabled else { return }

        pendingSave?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistImmediately()
        }
        pendingSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            samples = try decoder.decode([String: [ThermalSample]].self, from: data)

            let cutoff = Date().addingTimeInterval(-Self.retentionInterval)
            for (disk, list) in samples {
                samples[disk] = list.filter { $0.date >= cutoff }
            }
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription, privacy: .public)")
        }
    }
}
