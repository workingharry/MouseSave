import Foundation

// MARK: - Test Seam Definitions & Calculations

struct ScrollPhysicsCalculator {
    static let basePixelsPerTick: Double = 36.0

    static func calculateImpulse(deltaY: Int64, acceleration: Double, direction: Double) -> Double {
        return direction * abs(Double(deltaY)) * basePixelsPerTick * acceleration
    }

    static func calculateStep(velocity: Double) -> Int64 {
        return Int64(round(velocity * 0.25))
    }
}

enum ButtonActionHandler {
    static func keyCodeAndFlags(for action: String) -> (keyCode: UInt16, isCommand: Bool)? {
        switch action {
        case "back":
            return (33, true) // 33 = '[' with Command
        case "forward":
            return (30, true) // 30 = ']' with Command
        case "desktop":
            return (103, true)
        case "closeWindow":
            return (13, true)
        default:
            return nil
        }
    }
}

// MARK: - Tests

func testPhysicsStepNonZeroOnNormalTick() {
    print("Testing testPhysicsStepNonZeroOnNormalTick...")
    let impulse = ScrollPhysicsCalculator.calculateImpulse(deltaY: 1, acceleration: 1.25, direction: 1.0)
    let step = ScrollPhysicsCalculator.calculateStep(velocity: impulse)
    assert(step > 0, "Step must be greater than 0 on delta 1 tick! Got \(step)")
    print("✅ testPhysicsStepNonZeroOnNormalTick passed (step = \(step))")
}

func testButtonActionBackAndForward() {
    print("Testing testButtonActionBackAndForward...")
    let backResult = ButtonActionHandler.keyCodeAndFlags(for: "back")
    assert(backResult != nil, "Button action 'back' must be handled!")
    assert(backResult?.keyCode == 33, "Button action 'back' keyCode must be 33 ('[')")
    assert(backResult?.isCommand == true, "Button action 'back' must include Command flag")

    let forwardResult = ButtonActionHandler.keyCodeAndFlags(for: "forward")
    assert(forwardResult != nil, "Button action 'forward' must be handled!")
    assert(forwardResult?.keyCode == 30, "Button action 'forward' keyCode must be 30 (']')")
    assert(forwardResult?.isCommand == true, "Button action 'forward' must include Command flag")
    print("✅ testButtonActionBackAndForward passed")
}

// Run tests
testPhysicsStepNonZeroOnNormalTick()
testButtonActionBackAndForward()
print("All automated test assertions passed successfully!")
