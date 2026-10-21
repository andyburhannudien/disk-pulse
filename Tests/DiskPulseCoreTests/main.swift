import Foundation
import DiskPulseCore

private var failures = 0
private var checks = 0

private func check(_ condition: Bool, _ message: @autoclosure () -> String, line: UInt = #line) {
    checks += 1
    if !condition {
        failures += 1
        print("FAIL (line \(line)): \(message())")
    }
}

private func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String, line: UInt = #line) {
    check(actual == expected, "\(label): expected \(expected), got \(actual)", line: line)
}

private func checkClose(_ actual: Double, _ expected: Double, _ tolerance: Double, _ label: String, line: UInt = #line) {
    check(abs(actual - expected) <= tolerance, "\(label): expected \(expected) ± \(tolerance), got \(actual)", line: line)
}

private func smartDictionary(
    spare: Int = 99,
    spareThreshold: Int = 50,
    percentageUsed: Int = 5,
    temperatureKelvin: Int = 300,
    writtenLow: Int = 67_528_787,
    writtenHigh: Int = 0,
    readLow: Int = 117_264_542,
    readHigh: Int = 0,
    powerOnHours: Int = 3_286,
    mediaErrors: Int = 0
) -> [String: Any] {
    return [
        "AVAILABLE_SPARE": spare,
        "AVAILABLE_SPARE_THRESHOLD": spareThreshold,
        "PERCENTAGE_USED": percentageUsed,
        "TEMPERATURE": temperatureKelvin,
        "DATA_UNITS_WRITTEN_0": writtenLow,
        "DATA_UNITS_WRITTEN_1": writtenHigh,
        "DATA_UNITS_READ_0": readLow,
        "DATA_UNITS_READ_1": readHigh,
        "HOST_WRITE_COMMANDS_0": 1_809_043_164,
        "HOST_READ_COMMANDS_0": 3_814_719_286,
        "CONTROLLER_BUSY_TIME_0": 1_234,
        "POWER_CYCLES_0": 1_378,
        "POWER_ON_HOURS_0": powerOnHours,
        "UNSAFE_SHUTDOWNS_0": 88,
        "MEDIA_ERRORS_0": mediaErrors,
        "NUM_ERROR_INFO_LOG_ENTRIES_0": 0
    ]
}

private func testKnownValues() {
    guard let metrics = DiskPulseScanner.metrics(from: smartDictionary()) else {
        check(false, "expected metrics for a populated SMART dictionary")
        return
    }

    checkEqual(metrics.availableSpare, 99, "availableSpare")
    checkEqual(metrics.availableSpareThreshold, 50, "availableSpareThreshold")
    checkEqual(metrics.percentageUsed, 5, "percentageUsed")
    checkEqual(metrics.healthPercentage, 95, "healthPercentage")
    checkEqual(metrics.temperatureKelvin, 300, "temperatureKelvin")
    checkClose(metrics.temperatureCelsius, 26.85, 0.001, "temperatureCelsius")
    checkClose(metrics.temperatureFahrenheit, 80.33, 0.001, "temperatureFahrenheit")

    checkClose(metrics.tbw, 34.5747, 0.001, "tbw")
    checkClose(metrics.tbr, 60.0394, 0.001, "tbr")
    checkClose(metrics.dailyWriteRateGB, 258.58, 0.5, "dailyWriteRateGB")
}

private func testHighWordContributesToTotal() {
    guard let metrics = DiskPulseScanner.metrics(from: smartDictionary(writtenLow: 0, writtenHigh: 1)) else {
        check(false, "expected metrics for high-word fixture")
        return
    }

    let expectedUnits = 18_446_744_073_709_551_616.0
    let expectedTBW = expectedUnits * DiskPulseScanner.dataUnitBytes / 1_000_000_000_000.0
    checkClose(metrics.dataUnitsWrittenTotal, expectedUnits, 1, "dataUnitsWrittenTotal")
    checkClose(metrics.tbw, expectedTBW, expectedTBW * 1e-9, "tbw with high word")
}

private func testNegativeLowWordDoesNotTrap() {
    guard let metrics = DiskPulseScanner.metrics(from: smartDictionary(writtenLow: -1)) else {
        check(false, "expected metrics for negative low-word fixture")
        return
    }

    checkEqual(metrics.dataUnitsWrittenRaw, UInt64.max, "negative Int is reinterpreted as UInt64")
    check(metrics.tbw > 9_000_000_000_000.0, "tbw should reflect the full 64-bit low word")
}

private func testMissingKeysUseSafeDefaults() {
    guard let metrics = DiskPulseScanner.metrics(from: ["PERCENTAGE_USED": 3]) else {
        check(false, "expected metrics when only PERCENTAGE_USED is present")
        return
    }

    checkEqual(metrics.availableSpare, 100, "default availableSpare")
    checkEqual(metrics.availableSpareThreshold, 0, "default availableSpareThreshold")
    checkClose(metrics.temperatureCelsius, -0.15, 0.001, "default temperature")
    checkClose(metrics.tbw, 0, 0.0001, "default tbw")
    checkEqual(metrics.thermalStatus, "Cool", "thermalStatus")
}

private func testUnrelatedDictionaryReturnsNil() {
    check(DiskPulseScanner.metrics(from: [:]) == nil, "empty dictionary should not produce metrics")
    check(DiskPulseScanner.metrics(from: ["SPINDLE_MOTOR_START_COUNT": 12]) == nil, "non-NVMe dictionary should not produce metrics")
}

private func testHealthGrades() {
    checkEqual(DiskPulseScanner.metrics(from: smartDictionary(percentageUsed: 0))?.healthGrade, .excellent, "0% used grade")
    checkEqual(DiskPulseScanner.metrics(from: smartDictionary(percentageUsed: 20))?.healthGrade, .good, "20% used grade")
    checkEqual(DiskPulseScanner.metrics(from: smartDictionary(percentageUsed: 70))?.healthGrade, .fair, "70% used grade")
    checkEqual(DiskPulseScanner.metrics(from: smartDictionary(percentageUsed: 90))?.healthGrade, .warning, "90% used grade")
    checkEqual(DiskPulseScanner.metrics(from: smartDictionary(mediaErrors: 1))?.healthGrade, .critical, "media error grade")
    checkEqual(DiskPulseScanner.metrics(from: smartDictionary(spare: 40, spareThreshold: 50))?.healthGrade, .critical, "spare below threshold grade")
}

private func testDiskReportIdentity() {
    let report = DiskReport(
        deviceIdentifier: "disk0",
        deviceNode: "/dev/disk0",
        mediaName: "Test NVMe",
        protocolType: "PCI-Express",
        isSolidState: true,
        isInternal: true,
        totalSizeBytes: 512_110_190_592,
        totalSizeFormatted: "512.1 GB",
        smartStatus: "Verified",
        nvmeMetrics: nil
    )

    checkEqual(report.id, "disk0", "DiskReport.id")
    checkEqual(report.isNVMe, false, "DiskReport.isNVMe")
}

testKnownValues()
testHighWordContributesToTotal()
testNegativeLowWordDoesNotTrap()
testMissingKeysUseSafeDefaults()
testUnrelatedDictionaryReturnsNil()
testHealthGrades()
testDiskReportIdentity()

if failures == 0 {
    print("PASS: \(checks) checks")
    exit(0)
} else {
    print("FAIL: \(failures) of \(checks) checks failed")
    exit(1)
}
