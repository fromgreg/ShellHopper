import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let preferences = Preferences()
    let hotKeyManager = HotKeyManager()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock; this is a menu-bar-only app.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        wireHotKeys()
        applyLaunchAtLogin(preferences.launchAtLogin)

        // React to preference changes.
        preferences.onIconChanged = { [weak self] in self?.refreshIcon() }
        preferences.onHotKeysChanged = { [weak self] in self?.wireHotKeys() }
        preferences.onLaunchAtLoginChanged = { [weak self] in
            self?.applyLaunchAtLogin(self?.preferences.launchAtLogin ?? false)
        }
    }

    // MARK: - Status bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = buildMenu()
        statusItem = item
        refreshIcon()
    }

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let symbol = preferences.menuBarIconName
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "ShellHopper") {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = "⌥"
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Terminal at Finder Path",
                     action: #selector(triggerFinder), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Open Terminal at Home",
                     action: #selector(triggerHome), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…",
                     action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ShellHopper",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func triggerFinder() {
        TerminalLauncher.openAtFinderPath(using: preferences.terminalApp, behavior: preferences.windowBehavior)
    }
    @objc private func triggerHome() {
        TerminalLauncher.openAtHome(using: preferences.terminalApp, behavior: preferences.windowBehavior)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView()
                .environmentObject(preferences)
                .environmentObject(hotKeyManager)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "ShellHopper Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Hotkeys

    private func wireHotKeys() {
        hotKeyManager.unregisterAll()
        if let s = preferences.finderShortcut, preferences.finderShortcutEnabled {
            hotKeyManager.register(id: "finder", shortcut: s) { [weak self] in
                guard let self else { return }
                TerminalLauncher.openAtFinderPath(using: self.preferences.terminalApp, behavior: self.preferences.windowBehavior)
            }
        }
        if let s = preferences.homeShortcut, preferences.homeShortcutEnabled {
            hotKeyManager.register(id: "home", shortcut: s) { [weak self] in
                guard let self else { return }
                TerminalLauncher.openAtHome(using: self.preferences.terminalApp, behavior: self.preferences.windowBehavior)
            }
        }
    }

    // MARK: - Launch at login

    private func applyLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13, *) else { return }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("ShellHopper: failed to toggle launch-at-login: \(error)")
        }
    }
}
