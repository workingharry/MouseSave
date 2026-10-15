import AppKit
import ApplicationServices

enum AccessibilityHelper {

    /// Check whether the app is a trusted Accessibility client.
    /// If not, show the system prompt **and** a custom alert
    /// explaining why the permission is needed.
    static func checkAndPrompt() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            showAccessibilityAlert()
        }
    }

    // MARK: - Private

    private static func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Accessibility Permission Required"
        )
        alert.informativeText = String(
            localized: "MouseSave needs Accessibility permission to intercept and modify mouse events. Please grant access in System Settings > Privacy & Security > Accessibility."
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Open System Settings"))
        alert.addButton(withTitle: String(localized: "Later"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
