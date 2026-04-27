import Foundation
import AppKit

enum TerminalApp: String, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iterm = "iTerm"
    var id: String { rawValue }
    var displayName: String { self == .terminal ? "Terminal.app" : "iTerm2" }
}

enum WindowBehavior: String, CaseIterable, Identifiable {
    case newTab          // open a new tab if a window exists; new window otherwise
    case newWindow       // always create a new window
    case existingWindow  // reuse the front window's active tab; new window if none exist
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .newTab:         return "New tab"
        case .newWindow:      return "New window"
        case .existingWindow: return "Existing window"
        }
    }
}

/// A captured keyboard shortcut. `keyCode` is a Carbon virtual key code,
/// `modifiers` is an NSEvent.ModifierFlags raw value (we filter to the
/// relevant flags before storing).
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32 // NSEvent.ModifierFlags raw value, masked

    var displayString: String {
        var s = ""
        let mods = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option)  { s += "⌥" }
        if mods.contains(.shift)   { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        s += KeyCodeMap.name(for: keyCode) ?? "?"
        return s
    }
}

final class Preferences: ObservableObject {
    private let defaults = UserDefaults.standard

    // Callbacks (set by AppDelegate to react to changes without binding).
    var onIconChanged: (() -> Void)?
    var onHotKeysChanged: (() -> Void)?
    var onLaunchAtLoginChanged: (() -> Void)?

    // MARK: - Stored values

    @Published var finderShortcut: Shortcut? {
        didSet { saveShortcut(finderShortcut, key: "finderShortcut"); onHotKeysChanged?() }
    }
    @Published var homeShortcut: Shortcut? {
        didSet { saveShortcut(homeShortcut, key: "homeShortcut"); onHotKeysChanged?() }
    }
    @Published var finderShortcutEnabled: Bool {
        didSet { defaults.set(finderShortcutEnabled, forKey: "finderShortcutEnabled"); onHotKeysChanged?() }
    }
    @Published var homeShortcutEnabled: Bool {
        didSet { defaults.set(homeShortcutEnabled, forKey: "homeShortcutEnabled"); onHotKeysChanged?() }
    }
    @Published var terminalApp: TerminalApp {
        didSet { defaults.set(terminalApp.rawValue, forKey: "terminalApp") }
    }
    @Published var windowBehavior: WindowBehavior {
        didSet { defaults.set(windowBehavior.rawValue, forKey: "windowBehavior") }
    }
    @Published var menuBarIconName: String {
        didSet { defaults.set(menuBarIconName, forKey: "menuBarIconName"); onIconChanged?() }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin"); onLaunchAtLoginChanged?() }
    }

    // MARK: - Init

    init() {
        let d = UserDefaults.standard
        self.finderShortcut = Self.loadShortcut(key: "finderShortcut", defaults: d)
            ?? Shortcut(keyCode: 31 /* O */, modifiers: Self.defaultModifiers)
        self.homeShortcut = Self.loadShortcut(key: "homeShortcut", defaults: d)
            ?? Shortcut(keyCode: 17 /* T */, modifiers: Self.defaultModifiers)
        self.finderShortcutEnabled = d.object(forKey: "finderShortcutEnabled") as? Bool ?? true
        self.homeShortcutEnabled   = d.object(forKey: "homeShortcutEnabled")   as? Bool ?? true
        self.terminalApp = TerminalApp(rawValue: d.string(forKey: "terminalApp") ?? "") ?? .terminal
        self.windowBehavior = WindowBehavior(rawValue: d.string(forKey: "windowBehavior") ?? "") ?? .newTab
        self.menuBarIconName = d.string(forKey: "menuBarIconName") ?? "terminal"
        self.launchAtLogin = d.bool(forKey: "launchAtLogin")
    }

    private static var defaultModifiers: UInt32 {
        let mods: NSEvent.ModifierFlags = [.control, .option, .command]
        return UInt32(mods.rawValue)
    }

    private func saveShortcut(_ shortcut: Shortcut?, key: String) {
        if let s = shortcut, let data = try? JSONEncoder().encode(s) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func loadShortcut(key: String, defaults: UserDefaults) -> Shortcut? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }
}

/// Available menu-bar icon options (SF Symbols).
enum MenuBarIcon: String, CaseIterable, Identifiable {
    case terminal = "terminal"
    case terminalFill = "terminal.fill"
    case command = "command"
    case keyboard = "keyboard"
    case bolt = "bolt"
    case folder = "folder"
    case house = "house"
    case chevronLeftForwardSlashChevronRight = "chevron.left.forwardslash.chevron.right"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .terminal: return "Terminal"
        case .terminalFill: return "Terminal (filled)"
        case .command: return "Command key"
        case .keyboard: return "Keyboard"
        case .bolt: return "Bolt"
        case .folder: return "Folder"
        case .house: return "House"
        case .chevronLeftForwardSlashChevronRight: return "Code brackets"
        }
    }
}
