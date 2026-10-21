import AppKit
import DiskPulseCore
import Foundation
import UniformTypeIdentifiers

enum ReportExporter {
    static func jsonString(reports: [DiskReport]) -> String {
        encode(reports)
    }

    static func jsonString(report: DiskReport) -> String {
        encode([report])
    }

    static func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    @discardableResult
    static func export(reports: [DiskReport]) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export DiskPulse Report"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = defaultFileName()
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            try jsonString(reports: reports).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func encode<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func defaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "DiskPulse-\(formatter.string(from: Date())).json"
    }
}
