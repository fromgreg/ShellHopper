# ShellHopper

A tiny menu-bar app for macOS that gives you global keyboard shortcuts to open Terminal:

- **Open Terminal at the current Finder window's path**
- **Open Terminal at your home directory**

Shortcuts work from anywhere — you grant ShellHopper permission to control Terminal **once**, and it works regardless of which app is focused.

## Features

- Global hotkeys (configurable from Settings)
- Choose between Terminal.app and iTerm2
- Configurable behavior when a terminal window already exists: **new tab**, **new window**, or **reuse the front window's active session**
- "Open at Finder Path" only fires when Finder is the frontmost app — it never silently grabs the path of a stale background Finder window
- Customizable menu-bar icon
- Launch at login
- No Dock presence — it stays in the menu bar
- New session always starts on a clean prompt at the target directory, and any keystrokes you type at the still-warming-up shell prompt are discarded — your input never garbles the `cd` command

## Build

Requires Xcode or the Command Line Tools (`xcode-select --install`).

```bash
./build.sh
```

This produces `build/ShellHopper.app`. Drag it to `/Applications`.

## First launch

1. Right-click `ShellHopper.app` → **Open** (the build is ad-hoc signed; macOS asks for confirmation the first time).
2. Click the menu-bar icon → **Settings…** to set your shortcuts.
3. Trigger a shortcut. macOS will prompt: *"ShellHopper wants to control Terminal."* → click **Allow**. This happens once, ever.
4. If you use the **New tab** behavior, also grant **Accessibility** access to ShellHopper in *System Settings → Privacy & Security → Accessibility*. (Terminal.app has no native AppleScript verb for "new tab", so ShellHopper synthesizes ⌘T via System Events, which requires this permission. The other two behaviors don't need it.)
5. Done.

## Default shortcuts

- ⌃⌥⌘O — Open Terminal at Finder Path
- ⌃⌥⌘T — Open Terminal at Home

Both are reconfigurable in Settings.

## How it works

ShellHopper registers global hotkeys via Carbon's `RegisterEventHotKey` (the same API Alfred, Raycast, and Rectangle use). When a hotkey fires, ShellHopper itself runs an AppleScript that targets Terminal or iTerm2. Because the script runs from ShellHopper's process — not from whatever app happens to be frontmost — only ShellHopper needs Automation permission.

For the **New tab** behavior on Terminal.app, ShellHopper also synthesizes a ⌘T keystroke via System Events (since Terminal.app has no native AppleScript "new tab" verb), which requires Accessibility permission. The **New window** and **Existing window** behaviors don't need it.

## Project layout

```
ShellHopper/
├── Package.swift              Swift package manifest
├── build.sh                   Builds the .app bundle
├── Resources/
│   └── Info.plist             Bundle metadata (LSUIElement, etc.)
└── Sources/ShellHopper/
    ├── ShellHopperApp.swift   @main entry point
    ├── AppDelegate.swift      Status bar, hotkey wiring, launch-at-login
    ├── Preferences.swift      UserDefaults-backed settings
    ├── HotKeyManager.swift    Carbon RegisterEventHotKey wrapper
    ├── KeyCodeMap.swift       Virtual key code → display name
    ├── TerminalLauncher.swift Inline AppleScripts for Terminal/iTerm
    ├── SettingsView.swift     SwiftUI Settings window
    └── ShortcutRecorder.swift NSView-backed shortcut input field
```

## Uninstalling

Quit ShellHopper from its menu, then drag the app to the Trash. Optionally remove its preferences:

```bash
defaults delete com.shellhopper.app
```
