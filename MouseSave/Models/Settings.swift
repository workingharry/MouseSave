import Combine
import Foundation
import ServiceManagement

/// Single source of truth for all app settings, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Published properties (auto-persisted)

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var showInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showInMenuBar, forKey: Keys.showInMenuBar) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    // Excluded Apps (Game Mode)
    @Published var excludedApps: [String] {
        didSet { UserDefaults.standard.set(excludedApps, forKey: Keys.excludedApps) }
    }

    // Scrolling Settings
    @Published var smoothScrolling: Bool {
        didSet { UserDefaults.standard.set(smoothScrolling, forKey: Keys.smoothScrolling) }
    }

    @Published var scrollAcceleration: Double {
        didSet { UserDefaults.standard.set(scrollAcceleration, forKey: Keys.scrollAcceleration) }
    }

    @Published var scrollFriction: Double {
        didSet { UserDefaults.standard.set(scrollFriction, forKey: Keys.scrollFriction) }
    }

    @Published var invertScrollDirection: Bool {
        didSet { UserDefaults.standard.set(invertScrollDirection, forKey: Keys.invertScrollDirection) }
    }

    // Buttons Settings
    @Published var middleClickAction: String {
        didSet { UserDefaults.standard.set(middleClickAction, forKey: Keys.middleClickAction) }
    }

    @Published var button4Action: String {
        didSet { UserDefaults.standard.set(button4Action, forKey: Keys.button4Action) }
    }

    @Published var button5Action: String {
        didSet { UserDefaults.standard.set(button5Action, forKey: Keys.button5Action) }
    }

    // MARK: - Keys

    private enum Keys {
        static let isEnabled             = "isEnabled"
        static let showInMenuBar         = "showInMenuBar"
        static let launchAtLogin         = "launchAtLogin"
        static let excludedApps          = "excludedApps"
        static let smoothScrolling       = "smoothScrolling"
        static let scrollAcceleration    = "scrollAcceleration"
        static let scrollFriction        = "scrollFriction"
        static let invertScrollDirection = "invertScrollDirection"
        static let middleClickAction     = "middleClickAction"
        static let button4Action         = "button4Action"
        static let button5Action         = "button5Action"
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        // First launch defaults
        if defaults.object(forKey: Keys.showInMenuBar) == nil {
            defaults.set(true, forKey: Keys.showInMenuBar)
        }
        if defaults.object(forKey: Keys.smoothScrolling) == nil {
            defaults.set(true, forKey: Keys.smoothScrolling)
        }
        if defaults.object(forKey: Keys.scrollAcceleration) == nil {
            defaults.set(1.25, forKey: Keys.scrollAcceleration)
        }
        if defaults.object(forKey: Keys.scrollFriction) == nil {
            defaults.set(0.88, forKey: Keys.scrollFriction)
        }
        if defaults.object(forKey: Keys.middleClickAction) == nil {
            defaults.set("default", forKey: Keys.middleClickAction)
        }
        if defaults.object(forKey: Keys.button4Action) == nil {
            defaults.set("back", forKey: Keys.button4Action)
        }
        if defaults.object(forKey: Keys.button5Action) == nil {
            defaults.set("forward", forKey: Keys.button5Action)
        }
        if defaults.object(forKey: Keys.excludedApps) == nil {
            defaults.set([
                "cs2",
                "valorant",
                "League of Legends",
                "Overwatch",
                "Apex",
                "Blender"
            ], forKey: Keys.excludedApps)
        }

        self.isEnabled             = defaults.bool(forKey: Keys.isEnabled)
        self.showInMenuBar         = defaults.bool(forKey: Keys.showInMenuBar)
        self.launchAtLogin         = defaults.bool(forKey: Keys.launchAtLogin)
        self.excludedApps          = defaults.stringArray(forKey: Keys.excludedApps) ?? []
        self.smoothScrolling       = defaults.bool(forKey: Keys.smoothScrolling)
        self.scrollAcceleration    = defaults.double(forKey: Keys.scrollAcceleration)
        self.scrollFriction        = defaults.double(forKey: Keys.scrollFriction)
        self.invertScrollDirection = defaults.bool(forKey: Keys.invertScrollDirection)
        self.middleClickAction     = defaults.string(forKey: Keys.middleClickAction) ?? "default"
        self.button4Action         = defaults.string(forKey: Keys.button4Action) ?? "back"
        self.button5Action         = defaults.string(forKey: Keys.button5Action) ?? "forward"
    }

    // MARK: - Helpers

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[MouseSave] Failed to update launch-at-login: \(error)")
        }
    }
}
