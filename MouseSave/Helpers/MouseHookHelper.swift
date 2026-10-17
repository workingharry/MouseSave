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
                                (1 << CGEventType.otherMouseUp.rawValue)

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
            // Retry automatically when permissions are granted
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
                    }
                    return nil // Suppress raw tick, let physics loop synthesize smooth ticks
                } else if settings.invertScrollDirection {
                    // Invert all scroll delta fields for modern and legacy macOS apps
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

        // 2. Extra Button Handling (Middle = 2, Button 4 = 3, Button 5 = 4)
        if type == .otherMouseDown || type == .otherMouseUp {
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

            let action: String
            if buttonNumber == 2 {
                action = settings.middleClickAction
            } else if buttonNumber == 3 {
                action = settings.button4Action
            } else if buttonNumber == 4 {
                action = settings.button5Action
            } else {
                action = "default"
            }

            if action != "default" && !action.isEmpty {
                if type == .otherMouseDown {
                    _ = handleButtonAction(action)
                }
                return nil // Suppress raw button event so system doesn't register stray clicks
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleButtonAction(_ action: String) -> Bool {
        guard action != "default" && !action.isEmpty else { return false }

        if action == "none" { return true }

        if action == "back" {
            // Trigger Command + [ (macOS standard back in Safari, Chrome, Finder)
            postSyntheticKeyEvent(keyCode: 33, flags: .maskCommand)
            return true
        }

        if action == "forward" {
            // Trigger Command + ] (macOS standard forward in Safari, Chrome, Finder)
            postSyntheticKeyEvent(keyCode: 30, flags: .maskCommand)
            return true
        }

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
        let source = CGEventSource(stateID: .combinedSessionState)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyDown.flags = flags
            keyUp.flags = flags
            keyDown.setIntegerValueField(.eventSourceUserData, value: MouseHookHelper.synthesizedEventUserData)
            keyUp.setIntegerValueField(.eventSourceUserData, value: MouseHookHelper.synthesizedEventUserData)
            keyDown.post(tap: .cgSessionEventTap)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                keyUp.post(tap: .cgSessionEventTap)
            }
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

            if abs(self.scrollVelocity) < 1.0 {
                self.scrollVelocity = 0.0
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
