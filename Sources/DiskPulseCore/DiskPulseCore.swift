import Foundation
import os

public struct NVMeSMARTMetrics: Codable, Sendable {
    public let availableSpare: Int
    public let availableSpareThreshold: Int
    public let percentageUsed: Int
    public let temperatureKelvin: Int
    public let temperatureCelsius: Double
    public let temperatureFahrenheit: Double

    public let dataUnitsWrittenRaw: UInt64
    public let dataUnitsReadRaw: UInt64
    public let tbw: Double // Terabytes Written
    public let tbr: Double // Terabytes Read

    public let hostReadCommands: UInt64
    public let hostWriteCommands: UInt64

    public let controllerBusyTimeMinutes: UInt64
    public let powerCycles: UInt64
    public let powerOnHours: UInt64
    public let unsafeShutdowns: UInt64
    public let mediaErrors: UInt64
    public let numErrorInfoEntries: UInt64

    /// Full 128-bit data-unit counters, safe above the 64-bit boundary.
    public let dataUnitsWrittenTotal: Double
    public let dataUnitsReadTotal: Double

    public init(
        availableSpare: Int,
        availableSpareThreshold: Int,
        percentageUsed: Int,
        temperatureKelvin: Int,
        temperatureCelsius: Double,
        temperatureFahrenheit: Double,
        dataUnitsWrittenRaw: UInt64,
        dataUnitsReadRaw: UInt64,
        tbw: Double,
        tbr: Double,
        hostReadCommands: UInt64,
        hostWriteCommands: UInt64,
        controllerBusyTimeMinutes: UInt64,
        powerCycles: UInt64,
        powerOnHours: UInt64,
        unsafeShutdowns: UInt64,
        mediaErrors: UInt64,
        numErrorInfoEntries: UInt64,
        dataUnitsWrittenTotal: Double = 0,
        dataUnitsReadTotal: Double = 0
    ) {
        self.availableSpare = availableSpare
        self.availableSpareThreshold = availableSpareThreshold
        self.percentageUsed = percentageUsed
        self.temperatureKelvin = temperatureKelvin
        self.temperatureCelsius = temperatureCelsius
        self.temperatureFahrenheit = temperatureFahrenheit
        self.dataUnitsWrittenRaw = dataUnitsWrittenRaw
        self.dataUnitsReadRaw = dataUnitsReadRaw
        self.tbw = tbw
        self.tbr = tbr
        self.hostReadCommands = hostReadCommands
        self.hostWriteCommands = hostWriteCommands
        self.controllerBusyTimeMinutes = controllerBusyTimeMinutes
        self.powerCycles = powerCycles
        self.powerOnHours = powerOnHours
        self.unsafeShutdowns = unsafeShutdowns
        self.mediaErrors = mediaErrors
        self.numErrorInfoEntries = numErrorInfoEntries
        self.dataUnitsWrittenTotal = dataUnitsWrittenTotal
        self.dataUnitsReadTotal = dataUnitsReadTotal
    }

    public var healthPercentage: Int {
        return max(0, 100 - percentageUsed)
    }

    public var dailyWriteRateGB: Double {
        guard powerOnHours > 0 else { return 0 }
        let totalGigabytes = tbw * 1024.0
        let days = Double(powerOnHours) / 24.0
        return totalGigabytes / max(1.0, days)
    }

    public var thermalStatus: String {
        if temperatureCelsius < 45 {
            return "Cool"
        } else if temperatureCelsius < 60 {
            return "Normal"
        } else if temperatureCelsius < 70 {
            return "Warm"
        } else {
            return "Hot (Warning)"
        }
    }

    public var isThermalWarning: Bool {
        return temperatureCelsius >= 65
    }

    public var isSpareCritical: Bool {
        return availableSpare < availableSpareThreshold
    }

    public var healthGrade: HealthGrade {
        if mediaErrors > 0 || isSpareCritical {
            return .critical
        } else if percentageUsed >= 90 || availableSpare < 80 {
            return .warning
        } else if percentageUsed >= 70 {
            return .fair
        } else if percentageUsed >= 20 {
            return .good
        } else {
            return .excellent
        }
    }
}

public enum HealthGrade: String, Codable, Sendable, CaseIterable {
    case excellent = "EXCELLENT"
    case good = "GOOD"
    case fair = "FAIR"
    case warning = "WARNING"
    case critical = "CRITICAL"

    /// Higher values are worse. Used to detect degradation between scans.
    public var severityRank: Int {
        switch self {
        case .excellent: return 0
        case .good: return 1
        case .fair: return 2
        case .warning: return 3
        case .critical: return 4
        }
    }
}

public struct DiskReport: Codable, Identifiable, Sendable {
    public let deviceIdentifier: String
    public let deviceNode: String
    public let mediaName: String
    public let protocolType: String
    public let isSolidState: Bool
    public let isInternal: Bool
    public let totalSizeBytes: Int64
    public let totalSizeFormatted: String
    public let smartStatus: String
    public let nvmeMetrics: NVMeSMARTMetrics?

    public var id: String { deviceIdentifier }

    public var isNVMe: Bool {
        return nvmeMetrics != nil
    }

    public init(
        deviceIdentifier: String,
        deviceNode: String,
        mediaName: String,
        protocolType: String,
        isSolidState: Bool,
        isInternal: Bool,
        totalSizeBytes: Int64,
        totalSizeFormatted: String,
        smartStatus: String,
        nvmeMetrics: NVMeSMARTMetrics?
    ) {
        self.deviceIdentifier = deviceIdentifier
        self.deviceNode = deviceNode
        self.mediaName = mediaName
        self.protocolType = protocolType
        self.isSolidState = isSolidState
        self.isInternal = isInternal
        self.totalSizeBytes = totalSizeBytes
        self.totalSizeFormatted = totalSizeFormatted
        self.smartStatus = smartStatus
        self.nvmeMetrics = nvmeMetrics
    }
}

public class DiskPulseScanner {
    private static let logger = Logger(subsystem: "dev.diskpulse", category: "scanner")

    /// NVMe specification: one data unit is 1000 × 512 bytes.
    public static let dataUnitBytes: Double = 512_000.0

    public static func getDiskIdentifiers() -> [String] {
        guard let data = runDiskutil(["list", "-plist"]),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let allDisks = plist["WholeDisks"] as? [String] else {
            logger.error("Unable to list whole disks; falling back to disk0")
            return ["disk0"]
        }
        return allDisks
    }

    /// Scans every physical whole disk, removes duplicates, and puts internal NVMe drives first.
    public static func scanAllDisks() -> [DiskReport] {
        var seen = Set<String>()
        var reports: [DiskReport] = []

        for identifier in getDiskIdentifiers() where seen.insert(identifier).inserted {
            guard let plist = infoPlist(identifier) else { continue }

            // Skip synthesized APFS containers/volumes; they inherit the physical disk's SMART data.
            guard (plist["VirtualOrPhysical"] as? String) != "Virtual" else { continue }

            reports.append(makeReport(from: plist, identifier: identifier))
        }

        return reports.sorted { lhs, rhs in
            if lhs.isInternal != rhs.isInternal { return lhs.isInternal }
            if lhs.isNVMe != rhs.isNVMe { return lhs.isNVMe }
            return lhs.deviceIdentifier.localizedStandardCompare(rhs.deviceIdentifier) == .orderedAscending
        }
    }

    /// Prefers the boot/internal NVMe disk, then any internal disk, then the first disk found.
    public static func primaryDiskIdentifier() -> String? {
        let reports = scanAllDisks()
        if let boot = reports.first(where: { $0.deviceIdentifier == "disk0" && $0.isNVMe }) {
            return boot.deviceIdentifier
        }
        return reports.first(where: { $0.isInternal && $0.isNVMe })?.deviceIdentifier
            ?? reports.first(where: { $0.isInternal })?.deviceIdentifier
            ?? reports.first?.deviceIdentifier
    }

    public static func inspectDisk(_ identifier: String) -> DiskReport? {
        guard let plist = infoPlist(identifier) else { return nil }
        return makeReport(from: plist, identifier: identifier)
    }

    private static func infoPlist(_ identifier: String) -> [String: Any]? {
        guard let data = runDiskutil(["info", "-plist", identifier]),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }

    private static func makeReport(from plist: [String: Any], identifier: String) -> DiskReport {
        let devId = plist["DeviceIdentifier"] as? String ?? identifier
        let devNode = plist["DeviceNode"] as? String ?? "/dev/\(identifier)"
        let mediaName = plist["MediaName"] as? String ?? (plist["IORegistryEntryName"] as? String ?? "Unknown Drive")
        let proto = plist["BusProtocol"] as? String ?? "Unknown"
        let isSSD = plist["SolidState"] as? Bool ?? false
        let isInternal = plist["Internal"] as? Bool ?? false
        let sizeBytes = int64Value(plist["TotalSize"]) ?? int64Value(plist["Size"]) ?? 0
        let smartStatus = plist["SMARTStatus"] as? String ?? "Unknown"

        var nvmeMetrics: NVMeSMARTMetrics? = nil
        if let smartDict = plist["SMARTDeviceSpecificKeysMayVaryNotGuaranteed"] as? [String: Any] {
            nvmeMetrics = metrics(from: smartDict)
        }

        let sizeGB = Double(sizeBytes) / 1_000_000_000.0
        let sizeFormatted = String(format: "%.1f GB", sizeGB)

        return DiskReport(
            deviceIdentifier: devId,
            deviceNode: devNode,
            mediaName: mediaName,
            protocolType: proto,
            isSolidState: isSSD,
            isInternal: isInternal,
            totalSizeBytes: sizeBytes,
            totalSizeFormatted: sizeFormatted,
            smartStatus: smartStatus,
            nvmeMetrics: nvmeMetrics
        )
    }

    /// Parses the `SMARTDeviceSpecificKeysMayVaryNotGuaranteed` dictionary from `diskutil info -plist`.
    public static func metrics(from smartDictionary: [String: Any]) -> NVMeSMARTMetrics? {
        guard smartDictionary["PERCENTAGE_USED"] != nil
                || smartDictionary["AVAILABLE_SPARE"] != nil
                || smartDictionary["DATA_UNITS_WRITTEN_0"] != nil else {
            return nil
        }

        let spare = intValue(smartDictionary["AVAILABLE_SPARE"]) ?? 100
        let spareThreshold = intValue(smartDictionary["AVAILABLE_SPARE_THRESHOLD"]) ?? 0
        let percentageUsed = intValue(smartDictionary["PERCENTAGE_USED"]) ?? 0

        let tempKelvin = intValue(smartDictionary["TEMPERATURE"]) ?? 273
        let tempC = Double(tempKelvin) - 273.15
        let tempF = (tempC * 9.0 / 5.0) + 32.0

        let writtenLow = uint64Value(smartDictionary["DATA_UNITS_WRITTEN_0"])
        let writtenHigh = uint64Value(smartDictionary["DATA_UNITS_WRITTEN_1"])
        let writtenTotal = totalDataUnits(low: writtenLow, high: writtenHigh)

        let readLow = uint64Value(smartDictionary["DATA_UNITS_READ_0"])
        let readHigh = uint64Value(smartDictionary["DATA_UNITS_READ_1"])
        let readTotal = totalDataUnits(low: readLow, high: readHigh)

        let tbw = writtenTotal * dataUnitBytes / 1_000_000_000_000.0
        let tbr = readTotal * dataUnitBytes / 1_000_000_000_000.0

        return NVMeSMARTMetrics(
            availableSpare: spare,
            availableSpareThreshold: spareThreshold,
            percentageUsed: percentageUsed,
            temperatureKelvin: tempKelvin,
            temperatureCelsius: tempC,
            temperatureFahrenheit: tempF,
            dataUnitsWrittenRaw: writtenLow,
            dataUnitsReadRaw: readLow,
            tbw: tbw,
            tbr: tbr,
            hostReadCommands: uint64Value(smartDictionary["HOST_READ_COMMANDS_0"]),
            hostWriteCommands: uint64Value(smartDictionary["HOST_WRITE_COMMANDS_0"]),
            controllerBusyTimeMinutes: uint64Value(smartDictionary["CONTROLLER_BUSY_TIME_0"]),
            powerCycles: uint64Value(smartDictionary["POWER_CYCLES_0"]),
            powerOnHours: uint64Value(smartDictionary["POWER_ON_HOURS_0"]),
            unsafeShutdowns: uint64Value(smartDictionary["UNSAFE_SHUTDOWNS_0"]),
            mediaErrors: uint64Value(smartDictionary["MEDIA_ERRORS_0"]),
            numErrorInfoEntries: uint64Value(smartDictionary["NUM_ERROR_INFO_LOG_ENTRIES_0"]),
            dataUnitsWrittenTotal: writtenTotal,
            dataUnitsReadTotal: readTotal
        )
    }

    private static func runDiskutil(_ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = arguments
        process.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                logger.error("diskutil \(arguments.joined(separator: " "), privacy: .public) exited with \(process.terminationStatus)")
                return nil
            }
            return data
        } catch {
            logger.error("Failed to run diskutil: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func totalDataUnits(low: UInt64, high: UInt64) -> Double {
        return Double(high) * 18_446_744_073_709_551_616.0 + Double(low)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func uint64Value(_ value: Any?) -> UInt64 {
        if let value = value as? UInt64 { return value }
        if let value = value as? Int { return UInt64(bitPattern: Int64(value)) }
        if let value = value as? NSNumber { return value.uint64Value }
        return 0
    }

    private static func int64Value(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }
}
