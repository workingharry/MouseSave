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
    static func keyCodeAndFlags(for action: String) -> (keyCode: UInt16, isCommand: Bool, isControl: Bool)? {
        switch action {
        case "back":
            return (33, true, false) // 33 = '[' with Command
        case "forward":
            return (30, true, false) // 30 = ']' with Command
        case "desktop":
            return (103, true, false)
        case "closeWindow":
            return (13, true, false)
        case "leftSpace":
            return (123, false, true) // 123 = Left Arrow with Control
        case "rightSpace":
            return (124, false, true) // 124 = Right Arrow with Control
        case "missionControl":
            return (126, false, true) // 126 = Up Arrow with Control
        case "appExpose":
            return (125, false, true) // 125 = Down Arrow with Control
        default:
            return nil
        }
    }
}

// MARK: - Gesture Direction & Space Switching Logic

enum GestureDirection: String, Equatable {
    case left
    case right
    case up
    case down
}

enum SpaceDirection {
    case left
    case right
}

struct GestureEvaluator {
    static func evaluate(
        dx: Double,
        dy: Double,
        duration: TimeInterval,
        threshold: Double = 75.0,
        dominanceRatio: Double = 1.35
    ) -> GestureDirection? {
        guard duration >= 0.05 else { return nil }
        let distance = hypot(dx, dy)
        guard distance >= threshold else { return nil }

        let absDx = abs(dx)
        let absDy = abs(dy)

        if absDx > absDy * dominanceRatio {
            return dx < 0 ? .left : .right
        } else if absDy > absDx * dominanceRatio {
            // CGEvent coordinate system: upward drag has dy < 0
            return dy < 0 ? .up : .down
        }

        return nil
    }
}

struct SpaceIndexCalculator {
    static func nextSpaceID(currentID: UInt64, spaceIDs: [UInt64], direction: SpaceDirection) -> UInt64? {
        guard let curIndex = spaceIDs.firstIndex(of: currentID) else { return nil }
        switch direction {
        case .left:
            guard curIndex > 0 else { return nil }
            return spaceIDs[curIndex - 1]
        case .right:
            guard curIndex + 1 < spaceIDs.count else { return nil }
            return spaceIDs[curIndex + 1]
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

func testGestureNavigationSpaceSwitching() {
    print("Testing testGestureNavigationSpaceSwitching...")
    let leftResult = ButtonActionHandler.keyCodeAndFlags(for: "leftSpace")
    assert(leftResult != nil, "Gesture 'leftSpace' must be handled!")
    assert(leftResult?.keyCode == 123, "Left space keyCode must be 123 (Left Arrow)")

    let rightResult = ButtonActionHandler.keyCodeAndFlags(for: "rightSpace")
    assert(rightResult != nil, "Gesture 'rightSpace' must be handled!")
    assert(rightResult?.keyCode == 124, "Right space keyCode must be 124 (Right Arrow)")

    let mcResult = ButtonActionHandler.keyCodeAndFlags(for: "missionControl")
    assert(mcResult != nil, "Gesture 'missionControl' must be handled!")

    print("✅ testGestureNavigationSpaceSwitching passed")
}

func testGestureEvaluationAndDamping() {
    print("Testing testGestureEvaluationAndDamping...")
    // 1. Accidental thumb press jitter (small distance 35px, or quick click < 50ms)
    let jitter1 = GestureEvaluator.evaluate(dx: 15, dy: -35, duration: 0.08, threshold: 75.0)
    assert(jitter1 == nil, "35px jitter must NOT trigger gesture! (threshold is 75px)")

    let quickClickJitter = GestureEvaluator.evaluate(dx: 20, dy: -80, duration: 0.02, threshold: 75.0)
    assert(quickClickJitter == nil, "Rapid click under 50ms must be rejected as click jitter!")

    // 2. Diagonal ambiguous movement (should not prematurely trigger)
    let diagonal = GestureEvaluator.evaluate(dx: 65, dy: -65, duration: 0.12, threshold: 75.0)
    assert(diagonal == nil, "Diagonal ambiguous movement must not trigger without dominance ratio!")

    // 3. Clear upward swipe (dy < 0, dominant)
    let upward = GestureEvaluator.evaluate(dx: 10, dy: -85, duration: 0.12, threshold: 75.0)
    assert(upward == .up, "Upward drag must trigger .up gesture!")

    // 4. Clear downward swipe (dy > 0, dominant)
    let downward = GestureEvaluator.evaluate(dx: 8, dy: 80, duration: 0.15, threshold: 75.0)
    assert(downward == .down, "Downward drag must trigger .down gesture!")

    // 5. Clear leftward swipe (dx < 0, dominant)
    let leftward = GestureEvaluator.evaluate(dx: -90, dy: 12, duration: 0.10, threshold: 75.0)
    assert(leftward == .left, "Leftward drag must trigger .left gesture!")

    // 6. Clear rightward swipe (dx > 0, dominant)
    let rightward = GestureEvaluator.evaluate(dx: 95, dy: -10, duration: 0.11, threshold: 75.0)
    assert(rightward == .right, "Rightward drag must trigger .right gesture!")

    print("✅ testGestureEvaluationAndDamping passed")
}

func testSpaceIndexCalculation() {
    print("Testing testSpaceIndexCalculation...")
    let spaces: [UInt64] = [1, 165, 91]

    // From space 1, move right -> 165
    assert(SpaceIndexCalculator.nextSpaceID(currentID: 1, spaceIDs: spaces, direction: .right) == 165)
    // From space 1, move left -> nil (boundary)
    assert(SpaceIndexCalculator.nextSpaceID(currentID: 1, spaceIDs: spaces, direction: .left) == nil)

    // From space 165, move right -> 91
    assert(SpaceIndexCalculator.nextSpaceID(currentID: 165, spaceIDs: spaces, direction: .right) == 91)
    // From space 165, move left -> 1
    assert(SpaceIndexCalculator.nextSpaceID(currentID: 165, spaceIDs: spaces, direction: .left) == 1)

    // From space 91, move right -> nil (boundary)
    assert(SpaceIndexCalculator.nextSpaceID(currentID: 91, spaceIDs: spaces, direction: .right) == nil)
    // From space 91, move left -> 165
    assert(SpaceIndexCalculator.nextSpaceID(currentID: 91, spaceIDs: spaces, direction: .left) == 165)

    print("✅ testSpaceIndexCalculation passed")
}

struct SlideTransitionCalculator {
    static func slideOption(for direction: SpaceDirection) -> UInt32 {
        // Option 2 (CGSRight) moves old desktop right to reveal left desktop
        // Option 1 (CGSLeft) moves old desktop left to reveal right desktop
        return (direction == .left) ? 2 : 1
    }

    static func clampDuration(_ duration: Double) -> Float {
        let clamped = max(0.10, min(0.60, duration))
        return Float(clamped)
    }
}

func testSlideTransitionSpecConfiguration() {
    print("Testing testSlideTransitionSpecConfiguration...")
    assert(SlideTransitionCalculator.slideOption(for: .left) == 2, "Left direction must use option 2 (CGSRight)")
    assert(SlideTransitionCalculator.slideOption(for: .right) == 1, "Right direction must use option 1 (CGSLeft)")

    assert(SlideTransitionCalculator.clampDuration(0.22) == 0.22, "Silky 0.22s should be preserved")
    assert(SlideTransitionCalculator.clampDuration(0.01) == 0.10, "Minimum 0.10s clamp")
    assert(SlideTransitionCalculator.clampDuration(2.00) == 0.60, "Maximum 0.60s clamp")
    print("✅ testSlideTransitionSpecConfiguration passed")
}

struct TrackpadSwipeDirectionMapper {
    static func targetSpaceDirection(for swipe: GestureDirection) -> SpaceDirection? {
        switch swipe {
        case .left:
            // Swiping mouse left (like trackpad 3-finger swipe left) moves viewport left to reveal right desktop
            return .right
        case .right:
            // Swiping mouse right (like trackpad 3-finger swipe right) moves viewport right to reveal left desktop
            return .left
        default:
            return nil
        }
    }
}

func testTrackpadSwipeDirectionMapping() {
    print("Testing testTrackpadSwipeDirectionMapping...")
    assert(TrackpadSwipeDirectionMapper.targetSpaceDirection(for: .left) == .right, "Left swipe must navigate to .right space")
    assert(TrackpadSwipeDirectionMapper.targetSpaceDirection(for: .right) == .left, "Right swipe must navigate to .left space")
    print("✅ testTrackpadSwipeDirectionMapping passed")
}

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

protocol GestureEventSenderProtocol {
    func sendFrame(_ frame: GestureFrame)
}

final class MockGestureEventSender: GestureEventSenderProtocol {
    var sentFrames: [GestureFrame] = []
    func sendFrame(_ frame: GestureFrame) {
        sentFrames.append(frame)
    }
}

func testGestureTrajectoryGeneration() {
    print("Testing testGestureTrajectoryGeneration...")
    let duration = 0.22
    let frequency = 120.0
    let frames = GestureTrajectoryGenerator.generateTrajectory(
        duration: duration,
        frequency: frequency,
        directionSign: -1.0
    )

    let expectedCount = Int(round(duration * frequency))
    assert(frames.count == expectedCount, "Frame count must match duration * frequency! Expected \(expectedCount), got \(frames.count)")
    assert(frames.first?.phase == 1, "First frame must be began (phase 1)")
    assert(frames.first?.progress == 0.0, "First frame progress must be 0.0")
    assert(frames.last?.phase == 4, "Last frame must be ended (phase 4)")
    assert(frames.last?.progress == -1.0, "Last frame progress must reach -1.0")
    assert(frames.last?.velocity == -150.0, "Last frame must carry exit velocity")

    // Verify monotonic progress progression
    for i in 1..<frames.count {
        assert(abs(frames[i].progress) >= abs(frames[i - 1].progress), "Progress magnitude must be monotonically non-decreasing!")
        if i < frames.count - 1 {
            assert(frames[i].phase == 2, "Intermediate frames must be changed (phase 2)")
        }
    }

    // Verify mock sender
    let mockSender = MockGestureEventSender()
    for frame in frames {
        mockSender.sendFrame(frame)
    }
    assert(mockSender.sentFrames.count == expectedCount, "Mock sender must receive all frames")
    print("✅ testGestureTrajectoryGeneration passed (\(frames.count) frames generated)")
}

// Run tests
testPhysicsStepNonZeroOnNormalTick()
testButtonActionBackAndForward()
testGestureNavigationSpaceSwitching()
testGestureEvaluationAndDamping()
testSpaceIndexCalculation()
testSlideTransitionSpecConfiguration()
testTrackpadSwipeDirectionMapping()
testGestureTrajectoryGeneration()
print("All automated test assertions passed successfully!")


