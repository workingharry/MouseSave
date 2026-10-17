import AppKit
import CoreGraphics
import Foundation

extension Notification.Name {
    static let mouseSaveGestureFired = Notification.Name("com.mousesave.gestureFired")
    static let mouseSaveButtonEvent  = Notification.Name("com.mousesave.buttonEvent")
}

/// Low-level macOS mouse interceptor using Quartz Event Services (CGEventTap).
final class MouseHookHelper {
    static let shared = MouseHookHelper()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    // Smooth scrolling velocity & on-demand physics state
    private var scrollVelocity: Double = 0.0
    private var physicsTimer: Timer?
    private let physicsQueue = DispatchQueue(label: "com.mousesave.physics", qos: .userInteractive)

    // Gesture Hold-and-Drag State Machine
    private var isGestureTracking = false
    private var gestureFired = false
    private var gestureStartPoint: CGPoint = .zero
    private var gestureTrackingButton: Int = -1

    // Workspace observer for active/foreground application
    private var activeAppObserver: NSObjectProtocol?
    private var currentActiveAppName: String = ""
    private var currentActiveAppBundleId: String = ""

    // Synthesized event marker (prevents infinite loop when posting modified scroll events)
    private static let synthesizedEventUserData: Int64 = 0x53415645 // 'SAVE'

    private init() {}

    func start() {
        guard AppSettings.shared.isEnabled else { return }
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
                                (1 << CGEventType.otherMouseUp.rawValue) |
                                (1 << CGEventType.otherMouseDragged.rawValue)

        let observer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: observer
        ) ?? CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: observer
        ) else {
            print("[MouseSave] Failed to create CGEventTap. Ensure Accessibility permissions are granted.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if self?.isRunning == false && AppSettings.shared.isEnabled {
                    self?.start()
                }
            }
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isRunning = true
        print("[MouseSave] CGEventTap successfully started with Gesture Engine.")
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

    private func getButtonAction(for buttonNumber: Int) -> String {
        let settings = AppSettings.shared
        if buttonNumber == 2 {
            return settings.middleClickAction
        } else if buttonNumber == 3 {
            return settings.button4Action
        } else if buttonNumber == 4 {
            return settings.button5Action
        }
        return "default"
    }

    private func getTargetGestureButtonNumber() -> Int {
        let settings = AppSettings.shared
        switch settings.gestureTriggerButton {
        case "button4": return 3
        case "button5": return 4
        case "middle":  return 2
        default:        return -1
        }
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
        if isForegroundExcluded() {
            return Unmanaged.passUnretained(event)
        }

        // 1. Scroll Wheel Handling (with Trackpad Bypass)
        if type == .scrollWheel {
            // Trackpad Bypass: Continuous scroll events come from MacBook Trackpads / Magic Mouse
            let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            if settings.trackpadBypass && isContinuous {
                return Unmanaged.passUnretained(event) // Bypass trackpad 100%
            }

            let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let pointDeltaY = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
            let fixedPtDeltaY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)

            let rawDelta = deltaY != 0 ? Double(deltaY) : (fixedPtDeltaY != 0 ? fixedPtDeltaY : Double(pointDeltaY))
            if rawDelta != 0 {
                let direction = rawDelta > 0 ? 1.0 : -1.0
                let effectiveDirection = settings.invertScrollDirection ? -direction : direction

                if settings.smoothScrolling {
                    let basePixels: Double = 36.0
                    let impulse = effectiveDirection * abs(rawDelta) * basePixels * settings.scrollAcceleration
                    physicsQueue.async {
                        self.scrollVelocity += impulse
                        self.schedulePhysicsTickIfNeeded()
                    }
                    return nil // Suppress raw tick, let physics loop synthesize smooth ticks
                } else if settings.invertScrollDirection {
                    if deltaY != 0 {
                        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -deltaY)
                    }
                    if pointDeltaY != 0 {
                        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -pointDeltaY)
                    }
                    if fixedPtDeltaY != 0 {
                        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixedPtDeltaY)
                    }
                    return Unmanaged.passUnretained(event)
                }
            }
        }

        // 2. Extra Button & Gesture Drag Handling
        let targetGestureButton = getTargetGestureButtonNumber()

        if type == .otherMouseDown {
            let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))

            // Notify UI canvas for live feedback
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .mouseSaveButtonEvent,
                    object: nil,
                    userInfo: ["button": buttonNumber, "isDown": true]
                )
            }

            if settings.gestureEnabled && buttonNumber == targetGestureButton && targetGestureButton != -1 {
                isGestureTracking = true
                gestureFired = false
                gestureStartPoint = event.location
                gestureTrackingButton = buttonNumber
                return nil // Suppress initial down event to discriminate click vs gesture
            } else {
                let action = getButtonAction(for: buttonNumber)
                if action != "default" && !action.isEmpty {
                    _ = handleButtonAction(action)
                    return nil
                }
            }
        }

        if type == .otherMouseDragged {
            let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            if isGestureTracking && buttonNumber == gestureTrackingButton {
                let dx = event.location.x - gestureStartPoint.x
                let dy = event.location.y - gestureStartPoint.y
                let threshold = settings.gestureThreshold

                if !gestureFired && (abs(dx) >= threshold || abs(dy) >= threshold) {
                    gestureFired = true
                    if abs(dx) > abs(dy) {
                        if dx < 0 {
                            executeGestureAction(settings.gestureSwipeLeftAction)
                        } else {
                            executeGestureAction(settings.gestureSwipeRightAction)
                        }
                    } else {
                        // CGEvent coordinate system has (0,0) at upper-left; moving UP has dy < 0
                        if dy < 0 {
                            executeGestureAction(settings.gestureSwipeUpAction)
                        } else {
                            executeGestureAction(settings.gestureSwipeDownAction)
                        }
                    }

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .mouseSaveGestureFired,
                            object: nil,
                            userInfo: ["dx": dx, "dy": dy]
                        )
                    }
                }
                return nil // Suppress dragging events during gesture window
            }
        }

        if type == .otherMouseUp {
            let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .mouseSaveButtonEvent,
                    object: nil,
                    userInfo: ["button": buttonNumber, "isDown": false]
                )
            }

            if isGestureTracking && buttonNumber == gestureTrackingButton {
                isGestureTracking = false
                if !gestureFired {
                    // Quick Click without drag: trigger normal click action!
                    let action = getButtonAction(for: buttonNumber)
                    if action != "default" && !action.isEmpty {
                        _ = handleButtonAction(action)
                    }
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func executeGestureAction(_ action: String) {
        switch action {
        case "leftSpace":
            // Control + Left Arrow (macOS switch to left space)
            postHardwareShortcut(modifierKey: 59, targetKey: 123, modifierFlag: .maskControl)
        case "rightSpace":
            // Control + Right Arrow (macOS switch to right space)
            postHardwareShortcut(modifierKey: 59, targetKey: 124, modifierFlag: .maskControl)
        case "missionControl":
            // Open Mission Control directly via System URL for 100% reliable system response
            DispatchQueue.main.async {
                let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
            }
        case "appExpose":
            // Control + Down Arrow (Application Windows)
            postHardwareShortcut(modifierKey: 59, targetKey: 125, modifierFlag: .maskControl)
        case "desktop":
            // Command + F3 / Desktop
            postHardwareShortcut(modifierKey: 55, targetKey: 99, modifierFlag: .maskCommand)
        default:
            break
        }
    }

    private func handleButtonAction(_ action: String) -> Bool {
        guard action != "default" && !action.isEmpty else { return false }
        if action == "none" { return true }

        if action == "back" {
            // Command + [
            postHardwareShortcut(modifierKey: 55, targetKey: 33, modifierFlag: .maskCommand)
            return true
        }

        if action == "forward" {
            // Command + ]
            postHardwareShortcut(modifierKey: 55, targetKey: 30, modifierFlag: .maskCommand)
            return true
        }

        if action == "taskView" {
            executeGestureAction("missionControl")
            return true
        }

        if action == "desktop" {
            executeGestureAction("desktop")
            return true
        }

        if action == "closeWindow" {
            // Command + W
            postHardwareShortcut(modifierKey: 55, targetKey: 13, modifierFlag: .maskCommand)
            return true
        }

        return false
    }

    /// Posts a full hardware-level keyboard event sequence with explicit modifier down/up
    /// to ensure system-wide WindowServer / Dock shortcuts (like Spaces & Mission Control) recognize it.
    private func postHardwareShortcut(modifierKey: CGKeyCode, targetKey: CGKeyCode, modifierFlag: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        // 1. Modifier Key Down
        let modDown = CGEvent(keyboardEventSource: source, virtualKey: modifierKey, keyDown: true)
        modDown?.flags = modifierFlag
        modDown?.setIntegerValueField(.eventSourceUserData, value: MouseHookHelper.synthesizedEventUserData)
        modDown?.post(tap: .cghidEventTap)

        // 2. Target Key Down
        let targetDown = CGEvent(keyboardEventSource: source, virtualKey: targetKey, keyDown: true)
        targetDown?.flags = modifierFlag
        targetDown?.setIntegerValueField(.eventSourceUserData, value: MouseHookHelper.synthesizedEventUserData)
        targetDown?.post(tap: .cghidEventTap)

        // 3. Small hardware delay (30ms) for WindowServer event registration
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.03) {
            // 4. Target Key Up
            let targetUp = CGEvent(keyboardEventSource: source, virtualKey: targetKey, keyDown: false)
            targetUp?.flags = modifierFlag
            targetUp?.setIntegerValueField(.eventSourceUserData, value: MouseHookHelper.synthesizedEventUserData)
            targetUp?.post(tap: .cghidEventTap)

            // 5. Modifier Key Up
            let modUp = CGEvent(keyboardEventSource: source, virtualKey: modifierKey, keyDown: false)
            modUp?.flags = []
            modUp?.setIntegerValueField(.eventSourceUserData, value: MouseHookHelper.synthesizedEventUserData)
            modUp?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - On-Demand Smooth Scrolling Physics (0% Idle CPU)

    private func schedulePhysicsTickIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.physicsTimer == nil {
                self.physicsTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
                    self?.physicsTick()
                }
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

            if abs(self.scrollVelocity) < 1.0 {
                self.scrollVelocity = 0.0
                DispatchQueue.main.async { [weak self] in
                    self?.stopPhysicsTimer()
                }
                return
            }

            let step = Int32(round(self.scrollVelocity * 0.25))
            self.scrollVelocity *= AppSettings.shared.scrollFriction

            if step != 0 {
                DispatchQueue.main.async {
                    if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: step, wheel2: 0, wheel3: 0) {
                        scrollEvent.setIntegerValueField(.eventSourceUserData, value: MouseHookHelper.synthesizedEventUserData)
                        scrollEvent.post(tap: .cgSessionEventTap)
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
