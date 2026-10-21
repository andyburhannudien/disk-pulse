import Foundation

public struct NVMeSMARTMetrics: Codable {
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
        numErrorInfoEntries: UInt64
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
    
    public var healthGrade: HealthGrade {
        if mediaErrors > 0 || availableSpare < availableSpareThreshold {
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

public enum HealthGrade: String, Codable {
    case excellent = "EXCELLENT"
    case good = "GOOD"
    case fair = "FAIR"
    case warning = "WARNING"
    case critical = "CRITICAL"
}

public struct DiskReport: Codable {
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
    public static func getDiskIdentifiers() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["list", "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let allDisks = plist["WholeDisks"] as? [String] {
                return allDisks
            }
        } catch {
            print("Error scanning disks: \(error)")
        }
        return ["disk0"]
    }
    
    public static func inspectDisk(_ identifier: String) -> DiskReport? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", identifier]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                return nil
            }
            
            let devId = plist["DeviceIdentifier"] as? String ?? identifier
            let devNode = plist["DeviceNode"] as? String ?? "/dev/\(identifier)"
            let mediaName = plist["MediaName"] as? String ?? (plist["IORegistryEntryName"] as? String ?? "Unknown Drive")
            let proto = plist["BusProtocol"] as? String ?? "Unknown"
            let isSSD = plist["SolidState"] as? Bool ?? false
            let isInternal = plist["Internal"] as? Bool ?? false
            let sizeBytes = plist["TotalSize"] as? Int64 ?? (plist["Size"] as? Int64 ?? 0)
            let smartStatus = plist["SMARTStatus"] as? String ?? "Unknown"
            
            var metrics: NVMeSMARTMetrics? = nil
            if let smartDict = plist["SMARTDeviceSpecificKeysMayVaryNotGuaranteed"] as? [String: Any] {
                metrics = parseNVMeMetrics(smartDict)
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
                nvmeMetrics: metrics
            )
        } catch {
            return nil
        }
    }
    
    private static func parseNVMeMetrics(_ dict: [String: Any]) -> NVMeSMARTMetrics {
        let spare = dict["AVAILABLE_SPARE"] as? Int ?? 100
        let spareThreshold = dict["AVAILABLE_SPARE_THRESHOLD"] as? Int ?? 0
        let percentageUsed = dict["PERCENTAGE_USED"] as? Int ?? 0
        
        let tempKelvin = dict["TEMPERATURE"] as? Int ?? 273
        let tempC = Double(tempKelvin) - 273.15
        let tempF = (tempC * 9.0 / 5.0) + 32.0
        
        let written0 = UInt64(dict["DATA_UNITS_WRITTEN_0"] as? Int ?? 0)
        let written1 = UInt64(dict["DATA_UNITS_WRITTEN_1"] as? Int ?? 0)
        let totalWrittenUnits = (written1 << 64) | written0
        // NVMe spec: 1 unit = 1000 * 512 bytes = 512,000 bytes
        let tbw = (Double(totalWrittenUnits) * 512_000.0) / 1_000_000_000_000.0
        
        let read0 = UInt64(dict["DATA_UNITS_READ_0"] as? Int ?? 0)
        let read1 = UInt64(dict["DATA_UNITS_READ_1"] as? Int ?? 0)
        let totalReadUnits = (read1 << 64) | read0
        let tbr = (Double(totalReadUnits) * 512_000.0) / 1_000_000_000_000.0
        
        let hostRead = UInt64(dict["HOST_READ_COMMANDS_0"] as? Int ?? 0)
        let hostWrite = UInt64(dict["HOST_WRITE_COMMANDS_0"] as? Int ?? 0)
        
        let busyTime = UInt64(dict["CONTROLLER_BUSY_TIME_0"] as? Int ?? 0)
        let powerCycles = UInt64(dict["POWER_CYCLES_0"] as? Int ?? 0)
        let powerHours = UInt64(dict["POWER_ON_HOURS_0"] as? Int ?? 0)
        let unsafeShutdowns = UInt64(dict["UNSAFE_SHUTDOWNS_0"] as? Int ?? 0)
        let mediaErrors = UInt64(dict["MEDIA_ERRORS_0"] as? Int ?? 0)
        let errorEntries = UInt64(dict["NUM_ERROR_INFO_LOG_ENTRIES_0"] as? Int ?? 0)
        
        return NVMeSMARTMetrics(
            availableSpare: spare,
            availableSpareThreshold: spareThreshold,
            percentageUsed: percentageUsed,
            temperatureKelvin: tempKelvin,
            temperatureCelsius: tempC,
            temperatureFahrenheit: tempF,
            dataUnitsWrittenRaw: totalWrittenUnits,
            dataUnitsReadRaw: totalReadUnits,
            tbw: tbw,
            tbr: tbr,
            hostReadCommands: hostRead,
            hostWriteCommands: hostWrite,
            controllerBusyTimeMinutes: busyTime,
            powerCycles: powerCycles,
            powerOnHours: powerHours,
            unsafeShutdowns: unsafeShutdowns,
            mediaErrors: mediaErrors,
            numErrorInfoEntries: errorEntries
        )
    }
}
