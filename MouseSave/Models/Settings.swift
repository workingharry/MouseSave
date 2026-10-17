import Combine
import Foundation
import ServiceManagement

/// Single source of truth for all app settings, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Published properties (auto-persisted)

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled)
            if isEnabled {
                MouseHookHelper.shared.start()
            } else {
                MouseHookHelper.shared.stop()
            }
        }
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

    // Gesture & Space Switching Settings
    @Published var gestureEnabled: Bool {
        didSet { UserDefaults.standard.set(gestureEnabled, forKey: Keys.gestureEnabled) }
    }

    @Published var gestureTriggerButton: String {
        didSet { UserDefaults.standard.set(gestureTriggerButton, forKey: Keys.gestureTriggerButton) }
    }

    @Published var gestureThreshold: Double {
        didSet { UserDefaults.standard.set(gestureThreshold, forKey: Keys.gestureThreshold) }
    }

    @Published var gestureSwipeLeftAction: String {
        didSet { UserDefaults.standard.set(gestureSwipeLeftAction, forKey: Keys.gestureSwipeLeftAction) }
    }

    @Published var gestureSwipeRightAction: String {
        didSet { UserDefaults.standard.set(gestureSwipeRightAction, forKey: Keys.gestureSwipeRightAction) }
    }

    @Published var gestureSwipeUpAction: String {
        didSet { UserDefaults.standard.set(gestureSwipeUpAction, forKey: Keys.gestureSwipeUpAction) }
    }

    @Published var gestureSwipeDownAction: String {
        didSet { UserDefaults.standard.set(gestureSwipeDownAction, forKey: Keys.gestureSwipeDownAction) }
    }

    // Trackpad Bypass (Protect native MacBook gestures)
    @Published var trackpadBypass: Bool {
        didSet { UserDefaults.standard.set(trackpadBypass, forKey: Keys.trackpadBypass) }
    }

    // Native Slide Transition Animation (Trackpad Fluid Feel)
    @Published var spaceSlideAnimationEnabled: Bool {
        didSet { UserDefaults.standard.set(spaceSlideAnimationEnabled, forKey: Keys.spaceSlideAnimationEnabled) }
    }

    @Published var spaceTransitionDuration: Double {
        didSet { UserDefaults.standard.set(spaceTransitionDuration, forKey: Keys.spaceTransitionDuration) }
    }

    // Space Switching Engine ("dockSwipe" vs "cgsTransition")
    @Published var spaceSwitchEngine: String {
        didSet { UserDefaults.standard.set(spaceSwitchEngine, forKey: Keys.spaceSwitchEngine) }
    }

    // MARK: - Keys

    private enum Keys {
        static let isEnabled                  = "isEnabled"
        static let showInMenuBar              = "showInMenuBar"
        static let launchAtLogin              = "launchAtLogin"
        static let excludedApps               = "excludedApps"
        static let smoothScrolling            = "smoothScrolling"
        static let scrollAcceleration         = "scrollAcceleration"
        static let scrollFriction             = "scrollFriction"
        static let invertScrollDirection      = "invertScrollDirection"
        static let middleClickAction          = "middleClickAction"
        static let button4Action              = "button4Action"
        static let button5Action              = "button5Action"
        static let gestureEnabled             = "gestureEnabled"
        static let gestureTriggerButton       = "gestureTriggerButton"
        static let gestureThreshold           = "gestureThreshold"
        static let gestureSwipeLeftAction     = "gestureSwipeLeftAction"
        static let gestureSwipeRightAction    = "gestureSwipeRightAction"
        static let gestureSwipeUpAction       = "gestureSwipeUpAction"
        static let gestureSwipeDownAction     = "gestureSwipeDownAction"
        static let trackpadBypass             = "trackpadBypass"
        static let spaceSlideAnimationEnabled = "spaceSlideAnimationEnabled"
        static let spaceTransitionDuration    = "spaceTransitionDuration"
        static let spaceSwitchEngine          = "spaceSwitchEngine"
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        // First launch defaults
        if defaults.object(forKey: Keys.isEnabled) == nil {
            defaults.set(true, forKey: Keys.isEnabled)
        }
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
        if defaults.object(forKey: Keys.gestureEnabled) == nil {
            defaults.set(true, forKey: Keys.gestureEnabled)
        }
        if defaults.object(forKey: Keys.gestureTriggerButton) == nil {
            defaults.set("button4", forKey: Keys.gestureTriggerButton)
        }
        if defaults.object(forKey: Keys.gestureThreshold) == nil {
            defaults.set(45.0, forKey: Keys.gestureThreshold)
        }
        if defaults.object(forKey: Keys.gestureSwipeLeftAction) == nil {
            defaults.set("rightSpace", forKey: Keys.gestureSwipeLeftAction)
        }
        if defaults.object(forKey: Keys.gestureSwipeRightAction) == nil {
            defaults.set("leftSpace", forKey: Keys.gestureSwipeRightAction)
        }
        if defaults.object(forKey: Keys.gestureSwipeUpAction) == nil {
            defaults.set("missionControl", forKey: Keys.gestureSwipeUpAction)
        }
        if defaults.object(forKey: Keys.gestureSwipeDownAction) == nil {
            defaults.set("appExpose", forKey: Keys.gestureSwipeDownAction)
        }
        if defaults.object(forKey: Keys.trackpadBypass) == nil {
            defaults.set(true, forKey: Keys.trackpadBypass)
        }
        if defaults.object(forKey: Keys.spaceSlideAnimationEnabled) == nil {
            defaults.set(true, forKey: Keys.spaceSlideAnimationEnabled)
        }
        if defaults.object(forKey: Keys.spaceTransitionDuration) == nil {
            defaults.set(0.22, forKey: Keys.spaceTransitionDuration)
        }
        if defaults.object(forKey: Keys.spaceSwitchEngine) == nil {
            defaults.set("dockSwipe", forKey: Keys.spaceSwitchEngine)
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

        // Migrate trackpad horizontal swipe direction for existing installations
        if !defaults.bool(forKey: "hasMigratedTrackpadSwipeDirection_v1_3_1") {
            let oldLeft = defaults.string(forKey: Keys.gestureSwipeLeftAction)
            let oldRight = defaults.string(forKey: Keys.gestureSwipeRightAction)
            if oldLeft == "leftSpace" && oldRight == "rightSpace" {
                defaults.set("rightSpace", forKey: Keys.gestureSwipeLeftAction)
                defaults.set("leftSpace", forKey: Keys.gestureSwipeRightAction)
            }
            defaults.set(true, forKey: "hasMigratedTrackpadSwipeDirection_v1_3_1")
        }

        self.isEnabled                  = defaults.bool(forKey: Keys.isEnabled)
        self.showInMenuBar              = defaults.bool(forKey: Keys.showInMenuBar)
        self.launchAtLogin              = defaults.bool(forKey: Keys.launchAtLogin)
        self.excludedApps               = defaults.stringArray(forKey: Keys.excludedApps) ?? []
        self.smoothScrolling            = defaults.bool(forKey: Keys.smoothScrolling)
        self.scrollAcceleration         = defaults.double(forKey: Keys.scrollAcceleration)
        self.scrollFriction             = defaults.double(forKey: Keys.scrollFriction)
        self.invertScrollDirection      = defaults.bool(forKey: Keys.invertScrollDirection)
        self.middleClickAction          = defaults.string(forKey: Keys.middleClickAction) ?? "default"
        self.button4Action              = defaults.string(forKey: Keys.button4Action) ?? "back"
        self.button5Action              = defaults.string(forKey: Keys.button5Action) ?? "forward"
        self.gestureEnabled             = defaults.bool(forKey: Keys.gestureEnabled)
        self.gestureTriggerButton       = defaults.string(forKey: Keys.gestureTriggerButton) ?? "button4"
        let savedThreshold              = defaults.double(forKey: Keys.gestureThreshold)
        self.gestureThreshold           = savedThreshold >= 20.0 ? savedThreshold : 45.0
        self.gestureSwipeLeftAction     = defaults.string(forKey: Keys.gestureSwipeLeftAction) ?? "rightSpace"
        self.gestureSwipeRightAction    = defaults.string(forKey: Keys.gestureSwipeRightAction) ?? "leftSpace"
        self.gestureSwipeUpAction       = defaults.string(forKey: Keys.gestureSwipeUpAction) ?? "missionControl"
        self.gestureSwipeDownAction     = defaults.string(forKey: Keys.gestureSwipeDownAction) ?? "appExpose"
        self.trackpadBypass             = defaults.bool(forKey: Keys.trackpadBypass)
        self.spaceSlideAnimationEnabled = defaults.object(forKey: Keys.spaceSlideAnimationEnabled) != nil ? defaults.bool(forKey: Keys.spaceSlideAnimationEnabled) : true
        let savedDuration               = defaults.double(forKey: Keys.spaceTransitionDuration)
        self.spaceTransitionDuration    = (savedDuration >= 0.10 && savedDuration <= 0.60) ? savedDuration : 0.22
        self.spaceSwitchEngine          = defaults.string(forKey: Keys.spaceSwitchEngine) ?? "dockSwipe"
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
