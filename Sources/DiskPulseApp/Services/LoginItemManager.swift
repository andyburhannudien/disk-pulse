import Foundation

enum LoginItemError: LocalizedError {
    case notRunningFromAppBundle

    var errorDescription: String? {
        switch self {
        case .notRunningFromAppBundle:
            return "Launch at login is only available when DiskPulse runs from DiskPulse.app."
        }
    }
}

final class LoginItemManager {
    private let label = "dev.diskpulse.app"
    private let fileManager = FileManager.default

    var appPath: String? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return Bundle.main.bundleURL.path
    }

    var isEnabled: Bool {
        fileManager.fileExists(atPath: agentURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }

    private var agentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    private func enable() throws {
        guard let appPath = appPath else {
            throw LoginItemError.notRunningFromAppBundle
        }

        let directory = agentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-a", appPath],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive"
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: agentURL, options: .atomic)

        runLaunchctl(["bootstrap", "gui/\(getuid())", agentURL.path])
    }

    private func disable() throws {
        runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])

        if fileManager.fileExists(atPath: agentURL.path) {
            try fileManager.removeItem(at: agentURL)
        }
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
