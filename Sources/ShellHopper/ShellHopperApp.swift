import SwiftUI

@main
struct ShellHopperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Empty scene — accessory apps have no main window. The settings
        // window is opened manually from AppDelegate so it works reliably
        // when triggered from the status-bar menu.
        Settings { EmptyView() }
    }
}
