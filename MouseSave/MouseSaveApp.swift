import SwiftUI

@main
struct MouseSaveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — this is a menu-bar-only app.
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        AccessibilityHelper.checkAndPrompt()
        MouseHookHelper.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        MouseHookHelper.shared.stop()
    }
}
