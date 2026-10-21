import Combine
import Foundation

final class AppEnvironment: ObservableObject {
    let settings: AppSettings
    let historyStore: HistoryStore
    let notifications: NotificationService
    let loginItem: LoginItemManager
    let store: MonitorStore

    init() {
        let settings = AppSettings()
        let historyStore = HistoryStore()
        let notifications = NotificationService()

        self.settings = settings
        self.historyStore = historyStore
        self.notifications = notifications
        self.loginItem = LoginItemManager()
        self.store = MonitorStore(settings: settings, historyStore: historyStore, notifications: notifications)

        historyStore.persistenceEnabled = settings.keepHistory
    }

    static var isBundled: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"
    }
}
