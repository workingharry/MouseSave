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

// MARK: - Gesture Trajectory Model & Generator (Pure Function)
struct GestureFrame: Equatable {
    let phase: UInt32      // 1 = began, 2 = changed, 4 = ended
    let progress: Double   // signed progress (-1.0 to 1.0)
    let velocity: Double   // velocity on ended frame
}

struct GestureTrajectoryGenerator {
    static func generateTrajectory(
        duration: Double,
        frequency: Double = 120.0,
        directionSign: Double,
        exitSpeed: Double = 150.0
    ) -> [GestureFrame] {
        let totalFrames = max(3, Int(round(duration * frequency)))
        var frames: [GestureFrame] = []
        frames.reserveCapacity(totalFrames)

        // 1. Began frame
        frames.append(GestureFrame(phase: 1, progress: 0.0, velocity: 0.0))

        // 2. Intermediate changed frames (ease-out curve: 1 - pow(1 - t, 2.5))
        let intermediateCount = totalFrames - 2
        for i in 1...intermediateCount {
            let t = Double(i) / Double(totalFrames - 1)
            let eased = 1.0 - pow(1.0 - t, 2.5) // smooth ease-out
            let p = directionSign * min(1.0, max(0.0, eased))
            frames.append(GestureFrame(phase: 2, progress: p, velocity: 0.0))
        }

        // 3. Ended frame
        frames.append(GestureFrame(phase: 4, progress: directionSign * 1.0, velocity: directionSign * exitSpeed))
        return frames
    }
}

/// Low-level macOS mouse interceptor using Quartz Event Services (CGEventTap).
final class MouseHookHelper {
    static let shared = MouseHookHelper()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?
    private var isRunning = false

    // Dedicated serial queue for non-blocking gesture & Space operations (P0)
    private let gestureQueue = DispatchQueue(label: "com.mousesave.gesture", qos: .userInteractive)
    private var isSwitching = false // Reentrancy protection flag
    private var dockSwipeConsecutiveFailures = 0

    // Smooth scrolling velocity & on-demand physics state
    private var scrollVelocity: Double = 0.0
    private var physicsTimer: Timer?
    private let physicsQueue = DispatchQueue(label: "com.mousesave.physics", qos: .userInteractive)

    // Gesture Hold-and-Drag State Machine (with Mac Mouse Fix style flick velocity tracking)
    private var isGestureTracking = false
    private var gestureFired = false
    private var gestureStartPoint: CGPoint = .zero
    private var gestureStartTime: Date = Date()
    private var gestureTrackingButton: Int = -1
    private var gestureLastPoint: CGPoint = .zero
    private var gestureLastTime: Date = Date()
    private var gestureVelocity: Double = 0.0

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

        logStartupDiagnostics()

        // P0: Run CGEventTap on a dedicated background Thread with its own CFRunLoop.
        // This completely eliminates tapDisabledByTimeout caused by main-thread UI/Hangs.
        let thread = Thread { [weak self] in
            guard let self = self else { return }
            self.tapRunLoop = CFRunLoopGetCurrent()

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
            CFRunLoopAddSource(self.tapRunLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            self.isRunning = true
            print("[MouseSave] CGEventTap running on dedicated background thread with isolated CFRunLoop.")

            CFRunLoopRun()
        }

        thread.name = "com.mousesave.eventtap"
        thread.qualityOfService = .userInteractive
        self.tapThread = thread
        thread.start()
    }

    private func logStartupDiagnostics() {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let screens = NSScreen.screens.count
        let separateSpaces = UserDefaults.standard.persistentDomain(forName: "com.apple.spaces")?["spans-displays"] as? Bool ?? false
        print("""
        [MouseSave Diagnostics]
        • macOS Version: \(osVersion)
        • Connected Displays: \(screens)
        • Displays have separate Spaces: \(!separateSpaces)
        • Selected Space Switch Engine: \(AppSettings.shared.spaceSwitchEngine)
        """)
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
            if let source = runLoopSource, let loop = tapRunLoop {
                CFRunLoopRemoveSource(loop, source, .commonModes)
                self.runLoopSource = nil
            }
            self.eventTap = nil
        }
        if let loop = tapRunLoop {
            CFRunLoopStop(loop)
            self.tapRunLoop = nil
        }
        self.tapThread = nil
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
                gestureLastPoint = event.location
                gestureStartTime = Date()
                gestureLastTime = Date()
                gestureVelocity = 0.0
                gestureTrackingButton = buttonNumber
                return nil // Suppress initial down event to discriminate click vs gesture
            } else {
                let action = getButtonAction(for: buttonNumber)
                if action != "default" && !action.isEmpty {
                    gestureQueue.async { [weak self] in
                        _ = self?.handleButtonAction(action)
                    }
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

                let now = Date()
                let duration = now.timeIntervalSince(gestureStartTime)
                // Filter out thumb-press micro-jitter (must hold for at least 40ms)
                guard duration >= 0.04 else {
                    return nil
                }

                // Calculate instantaneous flick velocity (points per second)
                let dt = now.timeIntervalSince(gestureLastTime)
                if dt >= 0.008 { // Sample velocity at ~120Hz window
                    let stepDist = hypot(event.location.x - gestureLastPoint.x, event.location.y - gestureLastPoint.y)
                    let currentInstVelocity = stepDist / dt
                    // Exponential moving average for smooth velocity estimation
                    gestureVelocity = (gestureVelocity * 0.4) + (currentInstVelocity * 0.6)
                    gestureLastPoint = event.location
                    gestureLastTime = now
                }

                let dx = event.location.x - gestureStartPoint.x
                let dy = event.location.y - gestureStartPoint.y
                let distance = hypot(dx, dy)
                let threshold = settings.gestureThreshold

                // Mac Mouse Fix inspired dual threshold:
                // Normal swipe distance >= threshold (e.g. 45px), OR
                // High-velocity flick: distance >= threshold * 0.50 (e.g. 22px) AND velocity >= 450 px/s
                let isFlickCommit = (distance >= threshold * 0.50 && gestureVelocity >= 450.0)
                let isDistanceCommit = (distance >= threshold)

                guard isDistanceCommit || isFlickCommit else {
                    return nil
                }

                let absDx = abs(dx)
                let absDy = abs(dy)
                let dominanceRatio: Double = 1.15

                // Evaluate direction: dominant axis check, or fallback if dragged significantly far
                if absDx > absDy * dominanceRatio || (distance >= threshold * 1.5 && absDx > absDy) {
                    gestureFired = true
                    let action = dx < 0 ? settings.gestureSwipeLeftAction : settings.gestureSwipeRightAction
                    let loc = event.location
                    gestureQueue.async { [weak self] in
                        self?.executeGestureAction(action, cursorLocation: loc)
                    }
                    postGestureFired(dx: dx, dy: dy)
                } else if absDy > absDx * dominanceRatio || (distance >= threshold * 1.6 && absDy > absDx) {
                    // In Quartz coordinate system, upward drag has dy < 0
                    gestureFired = true
                    let action = dy < 0 ? settings.gestureSwipeUpAction : settings.gestureSwipeDownAction
                    let loc = event.location
                    gestureQueue.async { [weak self] in
                        self?.executeGestureAction(action, cursorLocation: loc)
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
                        gestureQueue.async { [weak self] in
                            _ = self?.handleButtonAction(action)
                        }
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
        case "back":
            // Browser history back (Command + [ or Command + Left)
            postHardwareShortcut(modifierKey: 55, targetKey: 33, modifierFlag: .maskCommand)
        case "forward":
            // Browser history forward (Command + ] or Command + Right)
            postHardwareShortcut(modifierKey: 55, targetKey: 30, modifierFlag: .maskCommand)
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

    private struct TargetSpaceContext {
        let displayID: String
        let currentSpaceID: CGSSpaceID
        let currentSpaceType: Int
        let hasTargetSpace: Bool
        let targetSpaceID: CGSSpaceID?
        let targetSpaceType: Int?
    }

    private func getSpaceContext(direction: SpaceDirection, at cursorLocation: CGPoint? = nil) -> TargetSpaceContext? {
        let cid = CGSMainConnectionID()
        guard let displays = CGSCopyManagedDisplaySpaces(cid) as? [[String: Any]], !displays.isEmpty else {
            return nil
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
              let curType = currentSpace["type"] as? Int,
              let spaces = display["Spaces"] as? [[String: Any]] else {
            return nil
        }

        let spaceIDs = spaces.compactMap { $0["id64"] as? CGSSpaceID }
        guard let curIndex = spaceIDs.firstIndex(of: curID) else {
            return TargetSpaceContext(displayID: displayID, currentSpaceID: curID, currentSpaceType: curType, hasTargetSpace: false, targetSpaceID: nil, targetSpaceType: nil)
        }

        let nextIndex = (direction == .left) ? curIndex - 1 : curIndex + 1
        if nextIndex >= 0 && nextIndex < spaces.count {
            let targetDict = spaces[nextIndex]
            let targetID = targetDict["id64"] as? CGSSpaceID
            let targetType = targetDict["type"] as? Int
            return TargetSpaceContext(displayID: displayID, currentSpaceID: curID, currentSpaceType: curType, hasTargetSpace: true, targetSpaceID: targetID, targetSpaceType: targetType)
        } else {
            // At boundary (e.g. leftmost or rightmost space)
            return TargetSpaceContext(displayID: displayID, currentSpaceID: curID, currentSpaceType: curType, hasTargetSpace: false, targetSpaceID: nil, targetSpaceType: nil)
        }
    }

    private func getCurrentSpaceID() -> CGSSpaceID? {
        let cid = CGSMainConnectionID()
        guard let displays = CGSCopyManagedDisplaySpaces(cid) as? [[String: Any]], !displays.isEmpty,
              let display = displays.first,
              let currentSpace = display["Current Space"] as? [String: Any],
              let curID = currentSpace["id64"] as? CGSSpaceID else {
            return nil
        }
        return curID
    }

    private func switchSpace(direction: SpaceDirection, at cursorLocation: CGPoint? = nil) {
        // P0 Reentrancy protection: ignore rapid duplicate triggers while transition is active
        guard !isSwitching else {
            print("[MouseSave] Space switch dropped due to active in-flight transition.")
            return
        }
        isSwitching = true

        let engine = AppSettings.shared.spaceSwitchEngine

        if engine == "dockSwipe" {
            switchSpaceViaDockSwipe(direction: direction, at: cursorLocation)
        } else {
            switchSpaceViaCGS(direction: direction, at: cursorLocation)
        }
    }

    /// P1: Native Dock Swipe Synthesis driven by DispatchSourceTimer (approx 120Hz)
    private func switchSpaceViaDockSwipe(direction: SpaceDirection, at cursorLocation: CGPoint? = nil) {
        // Check if there is a valid target Space before sending gesture
        guard let context = getSpaceContext(direction: direction, at: cursorLocation) else {
            self.isSwitching = false
            return
        }

        if !context.hasTargetSpace {
            // Already at screen boundary! Native trackpad gives rubber-band or haptic alignment feedback.
            // MUST NOT count as failure, MUST NOT trigger downgrade!
            print("[MouseSave] Reached boundary (no target space in direction: \(direction)). Skipping dockSwipe without failure penalty.")
            DispatchQueue.main.async {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            self.gestureQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.isSwitching = false
            }
            return
        }

        let initialSpaceID = context.currentSpaceID
        let initialSpaceType = context.currentSpaceType
        let targetSpaceID = context.targetSpaceID ?? 0
        let targetSpaceType = context.targetSpaceType ?? -1
        let isFullscreenInvolved = (initialSpaceType == 4 || targetSpaceType == 4)

        let settings = AppSettings.shared
        let baseDuration = max(0.12, min(0.40, settings.spaceTransitionDuration))
        let duration = isFullscreenInvolved ? max(0.25, baseDuration * 1.25) : baseDuration
        let frequency = 120.0
        let directionSign: Double = (direction == .right) ? 1.0 : -1.0

        let frames = GestureTrajectoryGenerator.generateTrajectory(
            duration: duration,
            frequency: frequency,
            directionSign: directionSign
        )

        let tBegan = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let beganIso = ISO8601DateFormatter().string(from: Date())
        print("""
        [MouseSave Transition Start]
        • Engine: dockSwipe
        • From Space: \(initialSpaceID) (type: \(initialSpaceType)) -> To Space: \(targetSpaceID) (type: \(targetSpaceType))
        • Is Fullscreen Involved: \(isFullscreenInvolved)
        • Began Timestamp: \(beganIso)
        • Gesture Frame Count: \(frames.count) (\(String(format: "%.2f", duration))s @ \(frequency)Hz)
        """)

        var frameIndex = 0
        let intervalNs = Int(1_000_000_000 / frequency)
        let timer = DispatchSource.makeTimerSource(queue: gestureQueue)
        timer.schedule(deadline: .now(), repeating: .nanoseconds(intervalNs), leeway: .nanoseconds(0))

        timer.setEventHandler { [weak self] in
            guard let self = self else {
                timer.cancel()
                return
            }

            if frameIndex < frames.count {
                let frame = frames[frameIndex]
                self.postDockSwipeEvent(frame: frame)
                frameIndex += 1
            } else {
                timer.cancel()
                let tEnded = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                let endedIso = ISO8601DateFormatter().string(from: Date())
                let gestureElapsedMs = Double(tEnded - tBegan) / 1_000_000.0
                print("[MouseSave Gesture Ended] Timestamp: \(endedIso), Gesture Duration: \(String(format: "%.1f", gestureElapsedMs)) ms")

                // Fix A & C:
                // 1. Wait 300ms before starting polling so Dock finishes native compositor handoff
                // 2. Poll interval: 100ms. Max timeout: 1.5s for fullscreen, 1.0s for normal desktop
                let initialWaitSeconds = 0.30
                let pollIntervalMs = 100
                let maxWaitSeconds = isFullscreenInvolved ? 1.50 : 1.00
                let maxPolls = Int(ceil((maxWaitSeconds - initialWaitSeconds) / (Double(pollIntervalMs) / 1000.0)))

                var pollCount = 0
                let pollTimer = DispatchSource.makeTimerSource(queue: self.gestureQueue)
                pollTimer.schedule(
                    deadline: .now() + initialWaitSeconds,
                    repeating: .milliseconds(pollIntervalMs),
                    leeway: .milliseconds(5)
                )

                pollTimer.setEventHandler { [weak self] in
                    guard let self = self else {
                        pollTimer.cancel()
                        return
                    }

                    pollCount += 1
                    let curSpace = self.getCurrentSpaceID()

                    if let cur = curSpace, cur != initialSpaceID {
                        // Space successfully changed!
                        pollTimer.cancel()
                        let tFinish = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                        let totalElapsedMs = Double(tFinish - tBegan) / 1_000_000.0
                        print("""
                        [MouseSave Transition Success]
                        • Total Elapsed: \(String(format: "%.1f", totalElapsedMs)) ms (after \(pollCount) polls)
                        • Final Space: \(cur)
                        • Downgrade Triggered: NO
                        """)
                        self.dockSwipeConsecutiveFailures = 0
                        self.isSwitching = false

                        // Fix C: Delay haptic until transition is confirmed complete (in background)
                        DispatchQueue.global(qos: .userInteractive).async {
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                        }
                        return
                    }

                    if pollCount >= maxPolls {
                        pollTimer.cancel()
                        let tFinish = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                        let totalElapsedMs = Double(tFinish - tBegan) / 1_000_000.0

                        // Check if Space changed before replaying or counting failure
                        let finalSpaceID = self.getCurrentSpaceID()
                        if let final = finalSpaceID, final != initialSpaceID {
                            print("[MouseSave Transition Success at Deadline] Final Space: \(final), Total Elapsed: \(String(format: "%.1f", totalElapsedMs)) ms")
                            self.dockSwipeConsecutiveFailures = 0
                            self.isSwitching = false
                            DispatchQueue.global(qos: .userInteractive).async {
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                            }
                            return
                        }

                        // Space truly did not change
                        self.dockSwipeConsecutiveFailures += 1
                        print("""
                        [MouseSave Transition Failed / Timeout]
                        • Total Elapsed: \(String(format: "%.1f", totalElapsedMs)) ms
                        • Consecutive Failures: \(self.dockSwipeConsecutiveFailures)/3
                        • Downgrade Triggered: \(self.dockSwipeConsecutiveFailures >= 3 ? "YES" : "NO (Log Only)")
                        """)

                        if self.dockSwipeConsecutiveFailures >= 3 {
                            print("[MouseSave] Reached 3 consecutive failures. Downgrading spaceSwitchEngine to 'cgsTransition'.")
                            AppSettings.shared.spaceSwitchEngine = "cgsTransition"
                            self.dockSwipeConsecutiveFailures = 0
                        }

                        // Replay once via CGS only if still on the initial space
                        if let verifySpace = self.getCurrentSpaceID(), verifySpace == initialSpaceID {
                            print("[MouseSave] Replaying space switch via fallback CGS transition once.")
                            self.switchSpaceViaCGS(direction: direction, at: cursorLocation)
                        } else {
                            self.isSwitching = false
                        }
                    }
                }
                pollTimer.resume()
            }
        }
        timer.resume()
    }

    /// Posts synthesized Dock Control swipe event
    private func postDockSwipeEvent(frame: GestureFrame) {
        // Event type 30 is kCGSEventDockControl
        guard let cgEvent = CGEvent(source: nil) else { return }
        cgEvent.type = CGEventType(rawValue: 30) ?? .null
        cgEvent.setIntegerValueField(.eventSourceUserData, value: MouseHookHelper.synthesizedEventUserData)

        // Field 130: Gesture Phase (1 = began, 2 = changed, 4 = ended)
        cgEvent.setIntegerValueField(CGEventField(rawValue: 130)!, value: Int64(frame.phase))

        // Field 110: Subtype (dock control)
        cgEvent.setIntegerValueField(CGEventField(rawValue: 110)!, value: 1)

        // Field 132: Signed progress
        let fixedPtProgress = Int64(frame.progress * 65536.0)
        cgEvent.setIntegerValueField(CGEventField(rawValue: 132)!, value: fixedPtProgress)

        // Field 134: Velocity on ended
        if frame.phase == 4 {
            let fixedPtVelocity = Int64(frame.velocity * 65536.0)
            cgEvent.setIntegerValueField(CGEventField(rawValue: 134)!, value: fixedPtVelocity)
        }

        cgEvent.post(tap: .cgSessionEventTap)
    }

    /// P0: CGS Transition Path (Zero usleep, completely non-blocking async queue)
    private func switchSpaceViaCGS(direction: SpaceDirection, at cursorLocation: CGPoint? = nil) {
        let cid = CGSMainConnectionID()
        guard let context = getSpaceContext(direction: direction, at: cursorLocation) else {
            // Fallback chain: fallback to hardware keyboard shortcut (Control + Arrow)
            let targetKey: CGKeyCode = (direction == .left) ? 123 : 124
            postHardwareShortcut(modifierKey: 59, targetKey: targetKey, modifierFlag: .maskControl)
            self.gestureQueue.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.isSwitching = false
            }
            return
        }

        guard context.hasTargetSpace, let targetSpaceID = context.targetSpaceID else {
            // Reached boundary: gentle feedback & release reentrancy
            DispatchQueue.global(qos: .userInteractive).async {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            self.gestureQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.isSwitching = false
            }
            return
        }

        let displayID = context.displayID
        let settings = AppSettings.shared
        let isFullscreenInvolved = (context.currentSpaceType == 4 || (context.targetSpaceType ?? -1) == 4)

        let tBegan = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let beganIso = ISO8601DateFormatter().string(from: Date())
        print("""
        [MouseSave Transition Start]
        • Engine: cgsTransition
        • From Space: \(context.currentSpaceID) (type: \(context.currentSpaceType)) -> To Space: \(targetSpaceID) (type: \(context.targetSpaceType ?? -1))
        • Is Fullscreen Involved: \(isFullscreenInvolved)
        • Began Timestamp: \(beganIso)
        """)

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
                let baseDuration = Float(max(0.10, min(0.60, settings.spaceTransitionDuration)))
                let duration = isFullscreenInvolved ? max(0.22, baseDuration * 1.15) : baseDuration

                // P0: Replace synchronous usleep(10000) with non-blocking queue asyncAfter!
                self.gestureQueue.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                    guard let self = self else { return }
                    _ = CGSInvokeTransition(cid, transID, duration)

                    self.gestureQueue.asyncAfter(deadline: .now() + Double(duration) + 0.05) { [weak self] in
                        _ = CGSReleaseTransition(cid, transID)
                        self?.isSwitching = false
                        let tFinish = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                        let totalElapsedMs = Double(tFinish - tBegan) / 1_000_000.0
                        print("[MouseSave Transition Success] Engine: cgsTransition, Total Elapsed: \(String(format: "%.1f", totalElapsedMs)) ms")

                        // Fix C: Delay haptic until completion
                        DispatchQueue.global(qos: .userInteractive).async {
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                        }
                    }
                }
            } else {
                self.isSwitching = false
            }
        } else {
            CGSManagedDisplaySetCurrentSpace(cid, displayID as CFString, targetSpaceID)
            self.isSwitching = false
            DispatchQueue.global(qos: .userInteractive).async {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
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
