import AppKit

enum TerminalLauncher {

    static func openAtFinderPath(using app: TerminalApp, behavior: WindowBehavior) {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder",
              let path = currentFinderPath() else { return }
        run(path: path, using: app, behavior: behavior)
    }

    static func openAtHome(using app: TerminalApp, behavior: WindowBehavior) {
        run(path: NSHomeDirectory(), using: app, behavior: behavior)
    }

    // MARK: - Path resolution

    private static func currentFinderPath() -> String? {
        let source = """
        try
            tell application "Finder"
                if (count of Finder windows) is 0 then return ""
                set theFolder to target of front Finder window as alias
                return POSIX path of theFolder
            end tell
        on error
            return ""
        end try
        """
        guard let result = runAppleScript(source) else { return nil }
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Script dispatch

    private static func run(path: String, using app: TerminalApp, behavior: WindowBehavior) {
        let escaped = shellQuote(path)
        let cdCommand = "cd \(escaped) && clear"

        // If the terminal app isn't running yet, `activate` will spawn a fresh
        // window for us. In that case "new tab" should land in that just-created
        // window rather than opening a second tab inside it.
        let effectiveBehavior: WindowBehavior = {
            if behavior == .newTab && !isRunning(app) { return .existingWindow }
            return behavior
        }()

        let source: String
        switch app {
        case .terminal:
            source = terminalScript(command: cdCommand, behavior: effectiveBehavior)
        case .iterm:
            source = itermScript(command: cdCommand, behavior: effectiveBehavior)
        }
        _ = runAppleScript(source)
    }

    private static func isRunning(_ app: TerminalApp) -> Bool {
        let bundleId: String
        switch app {
        case .terminal: bundleId = "com.apple.Terminal"
        case .iterm:    bundleId = "com.googlecode.iterm2"
        }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    private static func terminalScript(command: String, behavior: WindowBehavior) -> String {
        let escapedCmd = appleScriptEscape(command)
        // Ctrl-U (ASCII 0x15) kills whatever's in the readline/ZLE editing
        // buffer when the shell finally consumes the queued bytes — neutralizes
        // the race where the user types into the still-warming-up prompt and
        // their chars concatenate into our cd command.
        let escapedCmdKill = appleScriptEscape("\u{15}" + command)
        switch behavior {
        case .newTab:
            // Terminal.app has no native AppleScript verb for "new tab", so we
            // synthesize ⌘T via System Events. Two timing hazards:
            //   1. The keystroke is delivered to whichever app is frontmost
            //      *right now*. `activate` returns before focus has actually
            //      settled, so we both `set frontmost` and then add a post-poll
            //      delay before sending the keystroke.
            //   2. After ⌘T, `selected tab of front window` is not updated
            //      atomically, so we run the command in `last tab` (the one
            //      we just created) — and only after the tab count has
            //      actually increased.
            // Requires Accessibility permission for ShellHopper.
            return """
            set _cmd to "\(escapedCmd)"
            set _cmdKill to "\(escapedCmdKill)"
            tell application "Terminal" to activate
            tell application "System Events"
                set frontmost of process "Terminal" to true
            end tell
            repeat with _i from 1 to 40
                tell application "System Events"
                    if frontmost of process "Terminal" then exit repeat
                end tell
                delay 0.05
            end repeat
            delay 0.15
            tell application "Terminal"
                if (count of windows) is 0 then
                    do script _cmd
                else
                    set _oldTabCount to count of tabs of front window
                    tell application "System Events" to keystroke "t" using {command down}
                    repeat with _i from 1 to 40
                        if (count of tabs of front window) > _oldTabCount then exit repeat
                        delay 0.02
                    end repeat
                    do script _cmdKill in last tab of front window
                end if
            end tell
            """
        case .newWindow:
            return """
            set _cmd to "\(escapedCmd)"
            tell application "Terminal"
                activate
                do script _cmd
            end tell
            """
        case .existingWindow:
            return """
            set _cmd to "\(escapedCmd)"
            tell application "Terminal"
                activate
                if (count of windows) is 0 then
                    do script _cmd
                else
                    do script _cmd in selected tab of first window
                end if
            end tell
            """
        }
    }

    private static func itermScript(command: String, behavior: WindowBehavior) -> String {
        let escapedCmd = appleScriptEscape(command)
        switch behavior {
        case .newTab:
            return """
            set _cmd to "\(escapedCmd)"
            tell application "iTerm"
                activate
                if (count of windows) is 0 then
                    set _win to (create window with default profile)
                    tell current session of _win to write text _cmd
                else
                    tell current window
                        set _tab to (create tab with default profile)
                        tell current session of _tab to write text _cmd
                    end tell
                end if
            end tell
            """
        case .newWindow:
            return """
            set _cmd to "\(escapedCmd)"
            tell application "iTerm"
                activate
                set _win to (create window with default profile)
                tell current session of _win to write text _cmd
            end tell
            """
        case .existingWindow:
            return """
            set _cmd to "\(escapedCmd)"
            tell application "iTerm"
                activate
                if (count of windows) is 0 then
                    set _win to (create window with default profile)
                    tell current session of _win to write text _cmd
                else
                    tell current session of current window to write text _cmd
                end if
            end tell
            """
        }
    }

    // MARK: - Helpers

    private static func runAppleScript(_ source: String) -> String? {
        var errorDict: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let descriptor = script.executeAndReturnError(&errorDict)
        if let err = errorDict {
            NSLog("ShellHopper AppleScript error: \(err)")
            return nil
        }
        return descriptor.stringValue
    }

    /// POSIX shell single-quote a string.
    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escape a string for safe inclusion inside an AppleScript double-quoted literal.
    private static func appleScriptEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
