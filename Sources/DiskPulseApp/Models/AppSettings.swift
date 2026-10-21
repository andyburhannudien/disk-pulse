import Combine
import Foundation

final class AppSettings: ObservableObject {
    enum MenuBarDisplay: String, CaseIterable, Identifiable {
        case iconOnly
        case health
        case temperature
        case healthAndTemperature

        var id: String { rawValue }

        var label: String {
            switch self {
            case .iconOnly: return "Icon only"
            case .health: return "Health percentage"
            case .temperature: return "Temperature"
            case .healthAndTemperature: return "Health and temperature"
            }
        }
    }

    private enum Keys {
        static let refreshInterval = "refreshInterval"
        static let menuBarDisplay = "menuBarDisplay"
        static let notificationsEnabled = "notificationsEnabled"
        static let temperatureThreshold = "temperatureThreshold"
        static let notifyHealthDrop = "notifyHealthDrop"
        static let notifyMediaErrors = "notifyMediaErrors"
        static let launchAtLogin = "launchAtLogin"
        static let preferredDiskID = "preferredDiskID"
        static let keepHistory = "keepHistory"
    }

    @Published var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    @Published var menuBarDisplay: MenuBarDisplay {
        didSet { defaults.set(menuBarDisplay.rawValue, forKey: Keys.menuBarDisplay) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published var temperatureThreshold: Double {
        didSet { defaults.set(temperatureThreshold, forKey: Keys.temperatureThreshold) }
    }

    @Published var notifyHealthDrop: Bool {
        didSet { defaults.set(notifyHealthDrop, forKey: Keys.notifyHealthDrop) }
    }

    @Published var notifyMediaErrors: Bool {
        didSet { defaults.set(notifyMediaErrors, forKey: Keys.notifyMediaErrors) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var preferredDiskID: String? {
        didSet {
            if let id = preferredDiskID {
                defaults.set(id, forKey: Keys.preferredDiskID)
            } else {
                defaults.removeObject(forKey: Keys.preferredDiskID)
            }
        }
    }

    @Published var keepHistory: Bool {
        didSet { defaults.set(keepHistory, forKey: Keys.keepHistory) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let interval = defaults.object(forKey: Keys.refreshInterval) as? TimeInterval
        self.refreshInterval = interval ?? 60

        let storedDisplay = defaults.string(forKey: Keys.menuBarDisplay) ?? ""
        self.menuBarDisplay = MenuBarDisplay(rawValue: storedDisplay) ?? .healthAndTemperature

        self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)

        let threshold = defaults.object(forKey: Keys.temperatureThreshold) as? Double
        self.temperatureThreshold = threshold ?? 65

        self.notifyHealthDrop = defaults.object(forKey: Keys.notifyHealthDrop) as? Bool ?? true
        self.notifyMediaErrors = defaults.object(forKey: Keys.notifyMediaErrors) as? Bool ?? true
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.keepHistory = defaults.object(forKey: Keys.keepHistory) as? Bool ?? true
        self.preferredDiskID = defaults.string(forKey: Keys.preferredDiskID)
    }
}
