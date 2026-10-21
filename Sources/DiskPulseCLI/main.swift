import Foundation
import DiskPulseCore

// ANSI Color helper
struct Ansi {
    static let reset   = "\u{001B}[0m"
    static let bold    = "\u{001B}[1m"
    static let dim     = "\u{001B}[2m"
    
    static let red     = "\u{001B}[31m"
    static let green   = "\u{001B}[32m"
    static let yellow  = "\u{001B}[33m"
    static let blue    = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan    = "\u{001B}[36m"
    static let white   = "\u{001B}[37m"
    
    static let bgGreen  = "\u{001B}[42m\u{001B}[30m"
    static let bgYellow = "\u{001B}[43m\u{001B}[30m"
    static let bgRed    = "\u{001B}[41m\u{001B}[37m"
}

func makeProgressBar(percentage: Int, width: Int = 28) -> String {
    let filledCount = Int(round(Double(percentage) / 100.0 * Double(width)))
    let emptyCount = max(0, width - filledCount)
    
    let color: String
    if percentage >= 85 {
        color = Ansi.green
    } else if percentage >= 60 {
        color = Ansi.yellow
    } else {
        color = Ansi.red
    }
    
    let filledBar = String(repeating: "█", count: max(0, filledCount))
    let emptyBar = String(repeating: "░", count: emptyCount)
    
    return "\(color)\(filledBar)\(Ansi.dim)\(emptyBar)\(Ansi.reset)"
}

func formatNumber(_ number: UInt64) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

func printDiskReport(_ report: DiskReport) {
    print("""
    \(Ansi.bold)\(Ansi.cyan)╔══════════════════════════════════════════════════════════════════════════════════╗
    ║                     DISKPULSE - macOS SSD HEALTH MONITOR                         ║
    ╚══════════════════════════════════════════════════════════════════════════════════╝\(Ansi.reset)
    """)
    
    print("  \(Ansi.bold)Drive Model:\(Ansi.reset)         \(report.mediaName)")
    print("  \(Ansi.bold)Device Node:\(Ansi.reset)         \(report.deviceIdentifier) (\(report.deviceNode))")
    print("  \(Ansi.bold)Protocol / Bus:\(Ansi.reset)      \(report.isSolidState ? "Solid State Drive (SSD)" : "Mechanical Drive (HDD)") via \(report.protocolType) (\(report.isInternal ? "Internal" : "External"))")
    print("  \(Ansi.bold)Total Capacity:\(Ansi.reset)      \(report.totalSizeFormatted) (\(formatNumber(UInt64(report.totalSizeBytes))) bytes)")
    print("  \(Ansi.bold)SMART Driver Status:\(Ansi.reset) \(report.smartStatus.uppercased() == "VERIFIED" ? "\(Ansi.green)● VERIFIED\(Ansi.reset)" : report.smartStatus)")
    
    guard let m = report.nvmeMetrics else {
        print("\n  \(Ansi.yellow)Notice:\(Ansi.reset) Detailed NVMe S.M.A.R.T. metrics are not available for this partition/drive.")
        print("  \(Ansi.dim)Tip: Run diskpulse against the physical whole disk (e.g. diskpulse --disk disk0).\(Ansi.reset)\n")
        return
    }
    
    let gradeBadge: String
    switch m.healthGrade {
    case .excellent:
        gradeBadge = "\(Ansi.bgGreen) EXCELLENT \(Ansi.reset)"
    case .good:
        gradeBadge = "\(Ansi.bgGreen) GOOD \(Ansi.reset)"
    case .fair:
        gradeBadge = "\(Ansi.bgYellow) FAIR \(Ansi.reset)"
    case .warning:
        gradeBadge = "\(Ansi.bgYellow) WARNING \(Ansi.reset)"
    case .critical:
        gradeBadge = "\(Ansi.bgRed) CRITICAL \(Ansi.reset)"
    }
    
    print("\n  \(Ansi.bold)─── OVERALL HEALTH ASSESSMENT ──────────────────────────────────────────────────\(Ansi.reset)")
    let progressBar = makeProgressBar(percentage: m.healthPercentage, width: 28)
    print("  Health Score:      [\(progressBar)] \(Ansi.bold)\(m.healthPercentage)%\(Ansi.reset)  Status: \(gradeBadge)")
    print("  Wear Level:        \(m.percentageUsed)% used")
    print("  Spare Reserve:     \(m.availableSpare)% (Threshold: \(m.availableSpareThreshold)%)")
    
    let tempColor: String
    if m.temperatureCelsius < 55 {
        tempColor = Ansi.green
    } else if m.temperatureCelsius < 65 {
        tempColor = Ansi.yellow
    } else {
        tempColor = Ansi.red
    }
    
    print("\n  \(Ansi.bold)─── THERMAL & OPERATIONAL CONDITIONS ───────────────────────────────────────────\(Ansi.reset)")
    let tempCStr = String(format: "%.1f°C", m.temperatureCelsius)
    let tempFStr = String(format: "%.1f°F", m.temperatureFahrenheit)
    print("  Current Temp:      \(tempColor)\(tempCStr) / \(tempFStr)\(Ansi.reset) [\(m.thermalStatus)]")
    let daysActive = Double(m.powerOnHours) / 24.0
    let daysStr = String(format: "%.1f", daysActive)
    print("  Power On Hours:    \(formatNumber(m.powerOnHours)) hours (~\(daysStr) days active)")
    print("  Power Cycles:      \(formatNumber(m.powerCycles)) reboots/starts")
    print("  Unsafe Shutdowns:  \(m.unsafeShutdowns == 0 ? "\(Ansi.green)0\(Ansi.reset)" : "\(Ansi.yellow)\(m.unsafeShutdowns)\(Ansi.reset)")")
    
    print("\n  \(Ansi.bold)─── ENDURANCE & WORKLOAD (TBW) ────────────────────────────────────────────────\(Ansi.reset)")
    print("  Total Written:     \(Ansi.cyan)\(String(format: "%.2f TB", m.tbw))\(Ansi.reset) (\(formatNumber(m.dataUnitsWrittenRaw)) NVMe Data Units)")
    print("  Total Read:        \(Ansi.cyan)\(String(format: "%.2f TB", m.tbr))\(Ansi.reset) (\(formatNumber(m.dataUnitsReadRaw)) NVMe Data Units)")
    print("  Avg Daily Writes:  \(String(format: "%.2f GB/day", m.dailyWriteRateGB))")
    print("  Host I/O Commands: \(formatNumber(m.hostWriteCommands)) Writes | \(formatNumber(m.hostReadCommands)) Reads")
    
    print("\n  \(Ansi.bold)─── INTEGRITY & RELIABILITY ───────────────────────────────────────────────────\(Ansi.reset)")
    let mediaErrStr = m.mediaErrors == 0 ? "\(Ansi.green)0 (No bad sectors/errors)\(Ansi.reset)" : "\(Ansi.red)\(m.mediaErrors) (CRITICAL ERRORS DETECTED)\(Ansi.reset)"
    print("  Media Errors:      \(mediaErrStr)")
    print("  Error Log Entries: \(m.numErrorInfoEntries)")
    
    print("\n  \(Ansi.bold)─── DIAGNOSTIC SUMMARY & ADVICE ───────────────────────────────────────────────\(Ansi.reset)")
    if m.healthGrade == .excellent || m.healthGrade == .good {
        print("  \(Ansi.green)✔ SSD is in prime operating condition.\(Ansi.reset)")
        print("  • Minimal NAND flash wear (\(m.percentageUsed)% utilized).")
        print("  • Spare block reserves are at \(m.availableSpare)%, indicating zero physical cell depletion.")
        print("  • ECC reporting shows zero unrecoverable read/write failures.")
    } else if m.healthGrade == .warning {
        print("  \(Ansi.yellow)▲ SSD wear is significant or spare memory blocks are depleting.\(Ansi.reset)")
        print("  • Ensure Time Machine or cloud backups are actively running.")
    } else {
        print("  \(Ansi.red)✖ IMMEDIATE ACTION RECOMMENDED: SSD health is critical.\(Ansi.reset)")
        print("  • Backup all essential data immediately to prevent data loss.")
    }
    print("  \(Ansi.cyan)──────────────────────────────────────────────────────────────────────────────────\(Ansi.reset)\n")
}

// CLI Argument Handling
let args = CommandLine.arguments

if args.contains("--help") || args.contains("-h") {
    print("""
    DiskPulse - Modern macOS SSD Health & S.M.A.R.T. Monitor
    
    Usage:
      diskpulse [options]
    
    Options:
      --disk <id>       Target specific disk identifier (e.g. disk0)
      --json            Output report in structured JSON format
      --all             Scan and print report for all detected disks
      -h, --help        Show this help message
      -v, --version     Show version information
    """)
    exit(0)
}

if args.contains("--version") || args.contains("-v") {
    print("diskpulse version 1.1.0")
    exit(0)
}

let isJson = args.contains("--json")
let targetDiskIndex = args.firstIndex(of: "--disk").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }

var reports: [DiskReport] = []
if let target = targetDiskIndex {
    if let report = DiskPulseScanner.inspectDisk(target) {
        reports.append(report)
    }
} else if args.contains("--all") {
    reports = DiskPulseScanner.scanAllDisks()
} else {
    let all = DiskPulseScanner.getDiskIdentifiers()
    let physicalDisks = all.filter { $0.hasPrefix("disk0") }
    for disk in (physicalDisks.isEmpty ? ["disk0"] : physicalDisks) {
        if let report = DiskPulseScanner.inspectDisk(disk) {
            reports.append(report)
        }
    }
}

if isJson {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let jsonData = try? encoder.encode(reports),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
    }
} else {
    for report in reports {
        printDiskReport(report)
    }
}
