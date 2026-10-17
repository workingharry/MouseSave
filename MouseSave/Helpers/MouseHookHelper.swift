import AppKit
import CoreGraphics
import Foundation

extension Notification.Name {
    static let mouseSaveGestureFired = Notification.Name("com.mousesave.gestureFired")
    static let mouseSaveButtonEvent  = Notification.Name("com.mousesave.buttonEvent")
}

// MARK: - CoreGraphics Services (CGS) Private API Bindings for WindowServer Spaces
typealias CGSConnectionID = UInt32
typealias CGSSpaceID = UInt64

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray?

@_silgen_name("CGSManagedDisplaySetCurrentSpace")
private func CGSManagedDisplaySetCurrentSpace(_ cid: CGSConnectionID, _ displayID: CFString, _ spaceID: CGSSpaceID)

typealias CGSTransitionID = UInt32

struct CGSTransitionSpec {
    var unknown1: UInt32 = 0
    var type: UInt32 = 4       // 4 = CGSSlide
    var option: UInt32 = 1     // 1 = CGSLeft, 2 = CGSRight
    var wid: UInt32 = 0        // 0 = entire screen
    var backColour: UnsafeMutablePointer<Float>? = nil
}

@_silgen_name("CGSNewTransition")
private func CGSNewTransition(_ cid: CGSConnectionID, _ spec: UnsafePointer<CGSTransitionSpec>, _ outTransitionID: UnsafeMutablePointer<CGSTransitionID>) -> Int32

@_silgen_name("CGSInvokeTransition")
private func CGSInvokeTransition(_ cid: CGSConnectionID, _ transitionID: CGSTransitionID, _ duration: Float) -> Int32

@_silgen_name("CGSReleaseTransition")
private func CGSReleaseTransition(_ cid: CGSConnectionID, _ transitionID: CGSTransitionID) -> Int32

enum SpaceDirection {
    case left
    case right
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
    private var gestureStartTime: Date = Date()
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
                gestureStartTime = Date()
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
                guard !gestureFired else {
                    return nil // Already triggered for this drag sequence
                }

                let duration = Date().timeIntervalSince(gestureStartTime)
                // Filter out thumb-press micro-jitter (must hold for at least 50ms)
                guard duration >= 0.05 else {
                    return nil
                }

                let dx = event.location.x - gestureStartPoint.x
                let dy = event.location.y - gestureStartPoint.y
                let distance = hypot(dx, dy)
                let threshold = settings.gestureThreshold

                guard distance >= threshold else {
                    return nil
                }

                let absDx = abs(dx)
                let absDy = abs(dy)
                let dominanceRatio: Double = 1.15

                // Evaluate direction: dominant axis check, or fallback if dragged significantly far
                if absDx > absDy * dominanceRatio || (distance >= threshold * 1.6 && absDx > absDy) {
                    gestureFired = true
                    if dx < 0 {
                        executeGestureAction(settings.gestureSwipeLeftAction, cursorLocation: event.location)
                    } else {
                        executeGestureAction(settings.gestureSwipeRightAction, cursorLocation: event.location)
                    }
                    postGestureFired(dx: dx, dy: dy)
                } else if absDy > absDx * dominanceRatio || (distance >= threshold * 1.8 && absDy > absDx) {
                    // In Quartz coordinate system, upward drag has dy < 0
                    gestureFired = true
                    if dy < 0 {
                        executeGestureAction(settings.gestureSwipeUpAction, cursorLocation: event.location)
                    } else {
                        executeGestureAction(settings.gestureSwipeDownAction, cursorLocation: event.location)
                    }
                    postGestureFired(dx: dx, dy: dy)
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

    private func postGestureFired(dx: Double, dy: Double) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .mouseSaveGestureFired,
                object: nil,
                userInfo: ["dx": dx, "dy": dy]
            )
        }
    }

    private func executeGestureAction(_ action: String, cursorLocation: CGPoint? = nil) {
        switch action {
        case "leftSpace":
            switchSpace(direction: .left, at: cursorLocation)
        case "rightSpace":
            switchSpace(direction: .right, at: cursorLocation)
        case "missionControl":
            triggerMissionControl()
        case "appExpose":
            triggerMissionControl(argument: "2")
        case "desktop":
            triggerMissionControl(argument: "1")
        default:
            break
        }
    }

    private func triggerMissionControl(argument: String? = nil) {
        DispatchQueue.main.async {
            let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
            let config = NSWorkspace.OpenConfiguration()
            if let arg = argument {
                config.arguments = [arg]
            }
            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }

    private func switchSpace(direction: SpaceDirection, at cursorLocation: CGPoint? = nil) {
        let cid = CGSMainConnectionID()
        guard let displays = CGSCopyManagedDisplaySpaces(cid) as? [[String: Any]], !displays.isEmpty else {
            // Fallback to hardware shortcut if CGS returns nil
            let targetKey: CGKeyCode = (direction == .left) ? 123 : 124
            postHardwareShortcut(modifierKey: 59, targetKey: targetKey, modifierFlag: .maskControl)
            return
        }

        var targetDisplay: [String: Any]? = displays.first
        if cursorLocation != nil {
            let mouseLoc = NSEvent.mouseLocation
            if let activeScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }),
               let screenNum = activeScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               let uuidCF = CGDisplayCreateUUIDFromDisplayID(screenNum)?.takeRetainedValue() {
                let uuidStr = CFUUIDCreateString(nil, uuidCF) as String
                if let match = displays.first(where: { ($0["Display Identifier"] as? String) == uuidStr }) {
                    targetDisplay = match
                }
            }
        }

        guard let display = targetDisplay,
              let displayID = display["Display Identifier"] as? String,
              let currentSpace = display["Current Space"] as? [String: Any],
              let curID = currentSpace["id64"] as? CGSSpaceID,
              let spaces = display["Spaces"] as? [[String: Any]] else {
            return
        }

        let spaceIDs = spaces.compactMap { $0["id64"] as? CGSSpaceID }
        guard let curIndex = spaceIDs.firstIndex(of: curID) else { return }

        let nextIndex: Int
        switch direction {
        case .left:
            nextIndex = curIndex - 1
        case .right:
            nextIndex = curIndex + 1
        }

        guard nextIndex >= 0 && nextIndex < spaceIDs.count else {
            // Reached boundary: gentle feedback
            DispatchQueue.main.async {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            return
        }

        let targetSpaceID = spaceIDs[nextIndex]
        let settings = AppSettings.shared

        if settings.spaceSlideAnimationEnabled {
            // Direction option:
            // When moving to the left space, the old screen slides off to the right (option = 2, CGSRight)
            // When moving to the right space, the old screen slides off to the left (option = 1, CGSLeft)
            let slideOption: UInt32 = (direction == .left) ? 2 : 1
            var spec = CGSTransitionSpec(unknown1: 0, type: 4, option: slideOption, wid: 0, backColour: nil)
            var transID: CGSTransitionID = 0
            let err = CGSNewTransition(cid, &spec, &transID)

            // Switch to target space in WindowServer
            CGSManagedDisplaySetCurrentSpace(cid, displayID as CFString, targetSpaceID)

            if err == 0 {
                let duration = Float(max(0.10, min(0.60, settings.spaceTransitionDuration)))
                // Yield 10ms so WindowServer compositor commits destination space surface before starting slide
                usleep(10000)
                _ = CGSInvokeTransition(cid, transID, duration)
                DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + Double(duration) + 0.05) {
                    _ = CGSReleaseTransition(cid, transID)
                }
            }
        } else {
            CGSManagedDisplaySetCurrentSpace(cid, displayID as CFString, targetSpaceID)
        }

        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
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
