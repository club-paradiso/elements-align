import XCTest
@testable import ElementsCore

final class AngleTests: XCTestCase {

    func testAngularCasesMatchFixtures() {
        for testCase in Fixtures.root.angular {
            XCTAssertEqual(Angle.signedDifference(from: testCase.a, to: testCase.b),
                           testCase.signed, accuracy: 1e-9,
                           "signed \(testCase.a) -> \(testCase.b)")
            XCTAssertEqual(Angle.distance(testCase.a, testCase.b),
                           testCase.distance, accuracy: 1e-9,
                           "distance \(testCase.a) <-> \(testCase.b)")
        }
    }

    func testNormalizationFoldsNegativesCorrectly() {
        // truncatingRemainder would return -10 here; a compass heading of -10
        // degrees is 350.
        XCTAssertEqual(Angle.normalizedDegrees(-10), 350, accuracy: 1e-9)
        XCTAssertEqual(Angle.normalizedDegrees(-370), 350, accuracy: 1e-9)
        XCTAssertEqual(Angle.normalizedDegrees(0), 0, accuracy: 1e-9)
        XCTAssertEqual(Angle.normalizedDegrees(360), 0, accuracy: 1e-9)
        XCTAssertEqual(Angle.normalizedDegrees(725), 5, accuracy: 1e-9)
    }

    func testWraparoundIsTheShortWayRound() {
        // The bug this type exists to prevent.
        XCTAssertEqual(Angle.distance(359, 1), 2, accuracy: 1e-9)
        XCTAssertEqual(Angle.distance(1, 359), 2, accuracy: 1e-9)
        XCTAssertEqual(Angle.signedDifference(from: 350, to: 10), 20, accuracy: 1e-9)
        XCTAssertEqual(Angle.signedDifference(from: 10, to: 350), -20, accuracy: 1e-9)
    }

    func testDistanceIsSymmetricAndBounded() {
        for a in stride(from: 0.0, to: 360.0, by: 11.0) {
            for b in stride(from: 0.0, to: 360.0, by: 13.0) {
                let forward = Angle.distance(a, b)
                XCTAssertEqual(forward, Angle.distance(b, a), accuracy: 1e-9)
                XCTAssertGreaterThanOrEqual(forward, 0)
                XCTAssertLessThanOrEqual(forward, 180)
            }
        }
    }

    func testSmoothstepEndpointsAndMonotonicity() {
        XCTAssertEqual(Angle.smoothstep(0), 0, accuracy: 1e-12)
        XCTAssertEqual(Angle.smoothstep(1), 1, accuracy: 1e-12)
        XCTAssertEqual(Angle.smoothstep(0.5), 0.5, accuracy: 1e-12)
        XCTAssertEqual(Angle.smoothstep(-5), 0, accuracy: 1e-12)
        XCTAssertEqual(Angle.smoothstep(5), 1, accuracy: 1e-12)
        var previous = -1.0
        for step in 0...1000 {
            let value = Angle.smoothstep(Double(step) / 1000.0)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
    }
}

final class AlignmentTrackerTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testNoTransitionWithinTheHysteresisBand() {
        var tracker = AlignmentTracker(level: .neutral)
        // favourable begins at 58; the band requires clearing 61 to rise.
        XCTAssertNil(tracker.update(score: 58.0, at: start))
        XCTAssertNil(tracker.update(score: 60.9, at: start.addingTimeInterval(10)))
        XCTAssertEqual(tracker.level, .neutral)

        let transition = tracker.update(score: 61.1, at: start.addingTimeInterval(20))
        XCTAssertEqual(transition?.to, .favourable)
        XCTAssertEqual(tracker.level, .favourable)
    }

    func testFallingAlsoRequiresClearingTheBand() {
        var tracker = AlignmentTracker(level: .favourable)
        // Having risen to favourable, dropping to 56 is not enough to fall.
        XCTAssertNil(tracker.update(score: 56.0, at: start))
        XCTAssertEqual(tracker.level, .favourable)

        let transition = tracker.update(score: 54.9, at: start.addingTimeInterval(10))
        XCTAssertEqual(transition?.to, .neutral)
    }

    func testOscillatingAcrossAThresholdProducesOneTransition() {
        // A wrist resting near a boundary must not flicker.
        var tracker = AlignmentTracker(level: .neutral)
        var transitions = 0
        var time = start
        for step in 0..<200 {
            let score = 58.0 + (step % 2 == 0 ? 1.5 : -1.5)
            time = time.addingTimeInterval(0.05)
            if tracker.update(score: score, at: time) != nil { transitions += 1 }
        }
        XCTAssertEqual(transitions, 0,
                       "noise inside the hysteresis band must not move the level")
    }

    func testMinimumDwellSuppressesRapidChanges() {
        var tracker = AlignmentTracker(level: .neutral)
        XCTAssertNotNil(tracker.update(score: 62.0, at: start))
        // A large genuine swing, but too soon.
        XCTAssertNil(tracker.update(score: 90.0, at: start.addingTimeInterval(0.5)))
        XCTAssertEqual(tracker.level, .favourable)
        // Once the dwell has elapsed it is allowed through.
        let transition = tracker.update(score: 90.0, at: start.addingTimeInterval(2.0))
        XCTAssertEqual(transition?.to, .aligned)
    }

    func testTrackerCanJumpMultipleLevelsAtOnce() {
        var tracker = AlignmentTracker(level: .low)
        let transition = tracker.update(score: 95.0, at: start)
        XCTAssertEqual(transition?.from, .low)
        XCTAssertEqual(transition?.to, .aligned)
    }

    // MARK: - Haptics

    func testOnlyRisingTransitionsProduceCues() {
        for from in AlignmentLevel.allCases {
            for to in AlignmentLevel.allCases where to < from {
                let transition = AlignmentTransition(from: from, to: to, date: start)
                XCTAssertNil(AlignmentTracker.unlimitedCue(for: transition),
                             "falling \(from.identifier) -> \(to.identifier) must be silent")
            }
        }
    }

    func testCuePolicy() {
        func cue(_ from: AlignmentLevel, _ to: AlignmentLevel) -> HapticCue? {
            AlignmentTracker.unlimitedCue(
                for: AlignmentTransition(from: from, to: to, date: start))
        }
        // Reaching merely favourable is common; a cue there would mean nothing.
        XCTAssertNil(cue(.neutral, .favourable))
        XCTAssertEqual(cue(.favourable, .strong), .affirm)
        XCTAssertEqual(cue(.strong, .aligned), .aligned)
        XCTAssertEqual(cue(.neutral, .aligned), .aligned)
        XCTAssertNil(cue(.low, .neutral))
        XCTAssertNil(cue(.unfavourable, .neutral))
    }

    func testHapticsAreRateLimited() {
        var tracker = AlignmentTracker(level: .favourable)
        let first = AlignmentTransition(from: .favourable, to: .strong, date: start)
        XCTAssertEqual(tracker.cue(for: first), .affirm)

        // A second qualifying transition too soon after is suppressed.
        let tooSoon = AlignmentTransition(from: .strong, to: .aligned,
                                          date: start.addingTimeInterval(1.0))
        XCTAssertNil(tracker.cue(for: tooSoon))

        // After the interval it fires again.
        let later = AlignmentTransition(from: .strong, to: .aligned,
                                        date: start.addingTimeInterval(5.0))
        XCTAssertEqual(tracker.cue(for: later), .aligned)
    }

    func testASlowSweepThroughTheCompassDoesNotBuzzRepeatedly() {
        // Turning steadily through a full circle should feel like an event or
        // two, not a rattle.
        var tracker = AlignmentTracker(level: .neutral)
        var cues = 0
        var time = start
        for step in 0..<360 {
            // A smooth rise and fall across the whole level range.
            let phase = Double(step) / 360.0 * 2 * Double.pi
            let score = 55.0 + 35.0 * sin(phase)
            time = time.addingTimeInterval(0.05)
            if let transition = tracker.update(score: score, at: time),
               tracker.cue(for: transition) != nil {
                cues += 1
            }
        }
        XCTAssertLessThanOrEqual(cues, 2, "a single sweep should not produce a rattle")
    }
}
