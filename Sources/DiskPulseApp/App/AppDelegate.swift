import AppKit
import Combine
import SwiftUI
import UserNotifications

extension Notification.Name {
    static let diskPulseShowSettings = Notification.Name("DiskPulseShowSettings")
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let env = AppEnvironment()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var dashboardWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        env.notifications.configure(delegate: self)

        setupStatusItem()
        setupPopover()
        buildMainMenu()

        env.store.onUpdate = { [weak self] in
            self?.updateStatusItem()
        }

        env.settings.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusItem()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowSettings(_:)),
            name: .diskPulseShowSettings,
            object: nil
        )

        env.store.startAutoRefresh()
        env.store.refresh()

        if CommandLine.arguments.contains("--dashboard") {
            showDashboard()
        } else if CommandLine.arguments.contains("--settings") {
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        env.store.stopAutoRefresh()
        env.historyStore.persistImmediately()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "internaldrive.fill", accessibilityDescription: "DiskPulse")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusItem = item
        updateStatusItem()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showQuickMenu()
        } else {
            togglePopover()
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }

        guard let report = env.store.selectedReport, let metrics = report.nvmeMetrics else {
            button.title = ""
            button.toolTip = env.store.isScanning ? "DiskPulse — scanning…" : "DiskPulse — no NVMe metrics"
            return
        }

        switch env.settings.menuBarDisplay {
        case .iconOnly:
            button.title = ""
        case .health:
            button.title = " \(metrics.healthPercentage)%"
        case .temperature:
            button.title = String(format: " %.0f°", metrics.temperatureCelsius)
        case .healthAndTemperature:
            let temperature = Int(metrics.temperatureCelsius.rounded())
            button.title = " \(metrics.healthPercentage)% · \(temperature)°"
        }

        button.toolTip = String(
            format: "%@ — %@, %.1f°C",
            report.mediaName,
            metrics.healthGrade.rawValue.capitalized,
            metrics.temperatureCelsius
        )

        let isWarning = metrics.healthGrade == .warning || metrics.healthGrade == .critical
        let symbol = isWarning ? "exclamationmark.triangle.fill" : "internaldrive.fill"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "DiskPulse")
        button.image?.isTemplate = true
    }

    private func showQuickMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let dashboardItem = NSMenuItem(title: "Open Dashboard", action: #selector(openDashboardAction), keyEquivalent: "d")
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit DiskPulse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    // MARK: - Popover

    private func setupPopover() {
        let root = PopoverView(
            openDashboard: { [weak self] in self?.showDashboard() },
            openSettings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }
        )
        .environmentObject(env.store)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.contentViewController = NSHostingController(rootView: root)
        self.popover = popover
    }

    private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Windows

    @objc private func showDashboard() {
        popover?.performClose(nil)

        if let window = dashboardWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DiskPulse"
        window.minSize = NSSize(width: 900, height: 600)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: DashboardView()
                .environmentObject(env.store)
        )
        window.center()

        dashboardWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showSettings() {
        popover?.performClose(nil)

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DiskPulse Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsView()
                .environmentObject(env)
                .environmentObject(env.store)
                .environmentObject(env.settings)
        )
        window.center()

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Menu

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let aboutItem = NSMenuItem(
            title: "About DiskPulse",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = NSApp
        appMenu.addItem(aboutItem)

        appMenu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(title: "Hide DiskPulse", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.target = NSApp
        appMenu.addItem(hideItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit DiskPulse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        appMenu.addItem(quitItem)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Actions

    @objc private func refreshAction() {
        env.store.refresh()
    }

    @objc private func openDashboardAction() {
        showDashboard()
    }

    @objc private func openSettingsAction() {
        showSettings()
    }

    @objc private func handleShowSettings(_ notification: Notification) {
        showSettings()
    }
}
