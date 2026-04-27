import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var preferences: Preferences

    var body: some View {
        TabView {
            ShortcutsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 320)
        .padding()
    }
}

// MARK: - Shortcuts tab

private struct ShortcutsTab: View {
    @EnvironmentObject var preferences: Preferences

    var body: some View {
        Form {
            Section {
                ShortcutRow(
                    label: "Open Terminal at Finder Path",
                    enabled: $preferences.finderShortcutEnabled,
                    shortcut: $preferences.finderShortcut
                )
                ShortcutRow(
                    label: "Open Terminal at Home",
                    enabled: $preferences.homeShortcutEnabled,
                    shortcut: $preferences.homeShortcut
                )
            } footer: {
                Text("Click a shortcut field, then press the key combination you want to use. Click ✕ to clear.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutRow: View {
    let label: String
    @Binding var enabled: Bool
    @Binding var shortcut: Shortcut?

    var body: some View {
        HStack {
            Toggle("", isOn: $enabled).labelsHidden()
            Text(label)
            Spacer()
            ShortcutRecorder(shortcut: $shortcut)
                .frame(width: 160)
                .disabled(!enabled)
        }
    }
}

// MARK: - General tab

private struct GeneralTab: View {
    @EnvironmentObject var preferences: Preferences

    var body: some View {
        Form {
            Picker("Terminal app:", selection: $preferences.terminalApp) {
                ForEach(TerminalApp.allCases) { app in
                    Text(app.displayName).tag(app)
                }
            }

            Picker("When a window already exists:", selection: $preferences.windowBehavior) {
                ForEach(WindowBehavior.allCases) { b in
                    Text(b.displayName).tag(b)
                }
            }

            Picker("Menu-bar icon:", selection: $preferences.menuBarIconName) {
                ForEach(MenuBarIcon.allCases) { icon in
                    HStack {
                        Image(systemName: icon.rawValue)
                        Text(icon.displayName)
                    }
                    .tag(icon.rawValue)
                }
            }

            Toggle("Launch at login", isOn: $preferences.launchAtLogin)
        }
        .formStyle(.grouped)
    }
}

// MARK: - About tab

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal.fill")
                .resizable().scaledToFit().frame(width: 48, height: 48)
                .foregroundStyle(.secondary)
            Text("ShellHopper").font(.title2).bold()
            Text("Quick keyboard shortcuts to open Terminal at the current Finder path or home directory.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            Text("ShellHopper needs to control Terminal. macOS will prompt you for permission the first time a shortcut runs — grant it once and you're set.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
