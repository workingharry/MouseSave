import AppKit
import CoreGraphics
import Foundation

/// Low-level macOS mouse interceptor using Quartz Event Services (CGEventTap).
final class MouseHookHelper {
    static let shared = MouseHookHelper()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    // Smooth scrolling velocity & physics state
    private var scrollVelocity: Double = 0.0
    private var physicsTimer: Timer?
    private let physicsQueue = DispatchQueue(label: "com.mousesave.physics", qos: .userInteractive)

    // Workspace observer for active/foreground application
    private var activeAppObserver: NSObjectProtocol?
    private var currentActiveAppName: String = ""
    private var currentActiveAppBundleId: String = ""

    // Synthesized event marker (prevents infinite loop when posting modified scroll events)
    private static let synthesizedEventUserData: Int64 = 0x53415645 // 'SAVE'

    private init() {}

    func start() {
        guard !isRunning else { return }

        // Start active application tracking
        updateCurrentActiveApp()
        activeAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateCurrentActiveApp()
        }

        let mask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue) |
                                (1 << CGEventType.otherMouseDown.rawValue) |
                                (1 << CGEventType.otherMouseUp.rawValue)

        let observer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: observer
        ) else {
            print("[MouseSave] Failed to create CGEventTap. Ensure Accessibility permissions are granted.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isRunning = true
        startPhysicsTimer()
        print("[MouseSave] CGEventTap successfully started.")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        if let observer = activeAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            activeAppObserver = nil
        }

        stopPhysicsTimer()

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                self.runLoopSource = nil
            }
            self.eventTap = nil
        }
        print("[MouseSave] CGEventTap stopped.")
    }

    private func updateCurrentActiveApp() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            self.currentActiveAppName = frontApp.localizedName ?? ""
            self.currentActiveAppBundleId = frontApp.bundleIdentifier ?? ""
        }
    }

    /// Check if currently focused application is in ExcludedApps (Game Mode)
    private func isForegroundExcluded() -> Bool {
        let excludedList = AppSettings.shared.excludedApps
        guard !excludedList.isEmpty else { return false }

        let name = currentActiveAppName.lowercased()
        let bundleId = currentActiveAppBundleId.lowercased()

        for item in excludedList {
            let target = item.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if target.isEmpty { continue }

            if name == target || name.contains(target) || bundleId == target || bundleId.contains(target) {
                return true
            }
        }
        return false
    }

    // MARK: - Event Tap Callback

    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Auto-reconnect if disabled by OS timeout or system sleep
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                print("[MouseSave] CGEventTap re-enabled after timeout/sleep.")
            }
            return Unmanaged.passUnretained(event)
        }

        // Ignore events synthesized by MouseSave
        if event.getIntegerValueField(.eventSourceUserData) == MouseHookHelper.synthesizedEventUserData {
            return Unmanaged.passUnretained(event)
        }

        let settings = AppSettings.shared
        guard settings.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        // Game Mode / Exclusion Check:
        // If an excluded application or game is active, bypass MouseSave completely!
        if isForegroundExcluded() {
            return Unmanaged.passUnretained(event)
        }

        // 1. Scroll Wheel Handling
        if type == .scrollWheel {
            let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            if deltaY != 0 {
                var direction = deltaY > 0 ? 1.0 : -1.0
                if settings.invertScrollDirection {
                    direction = -direction
                }

                if settings.smoothScrolling {
                    let impulse = direction * abs(Double(deltaY)) * settings.scrollAcceleration
                    physicsQueue.async {
                        self.scrollVelocity += impulse
                    }
                    return nil // Suppress raw tick, let physics loop synthesize smooth ticks
                } else if settings.invertScrollDirection {
                    // Just invert without smoothing
                    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -deltaY)
                    return Unmanaged.passUnretained(event)
                }
            }
        }

        // 2. Extra Button Handling (Middle = 2, Button 4 = 3, Button 5 = 4)
        if type == .otherMouseDown {
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

            if buttonNumber == 2 { // Middle click
                if handleButtonAction(settings.middleClickAction) {
                    return nil
                }
            } else if buttonNumber == 3 { // Button 4
                if handleButtonAction(settings.button4Action) {
                    return nil
                }
            } else if buttonNumber == 4 { // Button 5
                if handleButtonAction(settings.button5Action) {
                    return nil
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleButtonAction(_ action: String) -> Bool {
        guard action != "default" && !action.isEmpty else { return false }

        if action == "none" { return true }

        if action == "taskView" {
            // Trigger macOS Mission Control
            DispatchQueue.main.async {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
            }
            return true
        }

        if action == "desktop" {
            // Trigger macOS Show Desktop shortcut (F11 or gesture)
            postSyntheticKeyEvent(keyCode: 103, flags: .maskCommand)
            return true
        }

        if action == "closeWindow" {
            // Trigger Command + W
            postSyntheticKeyEvent(keyCode: 13, flags: .maskCommand)
            return true
        }

        return false
    }

    private func postSyntheticKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags) {
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            keyDown.flags = flags
            keyUp.flags = flags
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Smooth Scrolling Physics

    private func startPhysicsTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.physicsTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
                self?.physicsTick()
            }
        }
    }

    private func stopPhysicsTimer() {
        physicsTimer?.invalidate()
        physicsTimer = nil
    }

    private func physicsTick() {
        physicsQueue.async { [weak self] in
            guard let self = self else { return }

            if abs(self.scrollVelocity) < 0.5 {
                self.scrollVelocity = 0.0
                return
            }

            let step = Int64(round(self.scrollVelocity * 0.25))
            self.scrollVelocity *= AppSettings.shared.scrollFriction

            if step != 0 {
                DispatchQueue.main.async {
                    if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: Int32(step), wheel2: 0, wheel3: 0) {
                        scrollEvent.setIntegerValueField(.eventSourceUserData, value: MouseHookHelper.synthesizedEventUserData)
                        scrollEvent.post(tap: .cghidEventTap)
                    }
                }
            }
        }
    }
}

// Global C callback function for Quartz Event Services
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let helper = Unmanaged<MouseHookHelper>.fromOpaque(refcon).takeUnretainedValue()
    return helper.handleEvent(proxy: proxy, type: type, event: event)
}
