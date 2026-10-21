import DiskPulseCore
import SwiftUI

enum HealthPalette {
    static func color(for grade: HealthGrade) -> Color {
        switch grade {
        case .excellent, .good:
            return .green
        case .fair:
            return .yellow
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    static func color(for report: DiskReport) -> Color {
        guard let metrics = report.nvmeMetrics else { return .gray }
        return color(for: metrics.healthGrade)
    }

    static func color(forHealth percentage: Int) -> Color {
        if percentage >= 85 {
            return .green
        } else if percentage >= 60 {
            return .yellow
        } else {
            return .red
        }
    }

    static func color(forTemperature celsius: Double) -> Color {
        if celsius < 55 {
            return .green
        } else if celsius < 65 {
            return .yellow
        } else {
            return .red
        }
    }

    static func color(forSpare spare: Int, threshold: Int) -> Color {
        if spare < threshold {
            return .red
        } else if spare < 80 {
            return .yellow
        } else {
            return .green
        }
    }
}
