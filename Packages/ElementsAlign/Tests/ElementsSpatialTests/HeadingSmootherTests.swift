import XCTest
@testable import ElementsSpatial
import ElementsCore

final class HeadingSmootherTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func sample(_ degrees: Double, at offset: TimeInterval,
                        accuracy: Double = 5) -> HeadingSample {
        HeadingSample(degrees: degrees, accuracyDegrees: accuracy,
                      timestamp: start.addingTimeInterval(offset))
    }

    func testStartsWithNoValue() {
        let smoother = HeadingSmoother()
        XCTAssertNil(smoother.smoothedHeading)
    }

    func testFirstSampleIsAdoptedExactly() {
        var smoother = HeadingSmoother()
        smoother.add(sample(137.5, at: 0))
        XCTAssertEqual(smoother.smoothedHeading ?? .nan, 137.5, accuracy: 1e-9)
    }

    func testAveragingAcrossTheSeamDoesNotPointSouth() {
        // The whole reason this is done with vectors: the arithmetic mean of
        // 359 and 1 is 180.
        var smoother = HeadingSmoother(timeConstant: 1.0)
        smoother.add(sample(359, at: 0))
        for step in 1...200 {
            smoother.add(sample(step % 2 == 0 ? 359 : 1, at: Double(step) * 0.05))
        }
        guard let heading = smoother.smoothedHeading else { return XCTFail("no value") }
        XCTAssertLessThan(Angle.distance(heading, 0), 2.0,
                          "should settle near 0/360, not near 180")
    }

    func testConvergesTowardsASteadyReading() {
        var smoother = HeadingSmoother(timeConstant: 0.3)
        smoother.add(sample(0, at: 0))
        for step in 1...100 {
            smoother.add(sample(90, at: Double(step) * 0.05))
        }
        guard let heading = smoother.smoothedHeading else { return XCTFail("no value") }
        XCTAssertEqual(heading, 90, accuracy: 0.5)
    }

    func testSmoothingLagsASuddenJump() {
        // It must not snap: that is the point of the filter.
        var smoother = HeadingSmoother(timeConstant: 0.5)
        smoother.add(sample(0, at: 0))
        smoother.add(sample(90, at: 0.05))
        guard let heading = smoother.smoothedHeading else { return XCTFail("no value") }
        XCTAssertGreaterThan(heading, 0)
        XCTAssertLessThan(heading, 30, "one short step should not move most of the way")
    }

    func testInvalidAndImpreciseSamplesAreRejected() {
        var smoother = HeadingSmoother()
        smoother.add(sample(45, at: 0))
        let settled = smoother.smoothedHeading

        // Core Location marks an unusable reading with a negative accuracy.
        smoother.add(sample(200, at: 1, accuracy: -1))
        XCTAssertEqual(smoother.smoothedHeading ?? .nan, settled ?? .nan, accuracy: 1e-9)

        // And a reading too imprecise to trust is also ignored.
        smoother.add(sample(200, at: 2, accuracy: 90))
        XCTAssertEqual(smoother.smoothedHeading ?? .nan, settled ?? .nan, accuracy: 1e-9)
    }

    func testOutOfOrderTimestampsDoNotBreakTheFilter() {
        var smoother = HeadingSmoother()
        smoother.add(sample(10, at: 5))
        smoother.add(sample(20, at: 1))
        guard let heading = smoother.smoothedHeading else { return XCTFail("no value") }
        XCTAssertFalse(heading.isNaN)
        XCTAssertTrue((0...360).contains(heading))
    }

    func testSampleRateDoesNotChangeSettlingBehaviour() {
        // The filter uses a time constant, so covering the same wall-clock
        // interval should give the same result at 10 Hz and at 50 Hz.
        func settle(rate: Double) -> Double {
            var smoother = HeadingSmoother(timeConstant: 0.4)
            smoother.add(sample(0, at: 0))
            let steps = Int(2.0 * rate)
            for step in 1...steps {
                smoother.add(sample(120, at: Double(step) / rate))
            }
            return smoother.smoothedHeading ?? .nan
        }
        XCTAssertEqual(settle(rate: 10), settle(rate: 50), accuracy: 1.0)
    }

    func testCoherenceFallsWhenReadingsDisagree() {
        var steady = HeadingSmoother(timeConstant: 1.0)
        var noisy = HeadingSmoother(timeConstant: 1.0)
        for step in 0...100 {
            let t = Double(step) * 0.05
            steady.add(sample(90, at: t))
            noisy.add(sample(step % 2 == 0 ? 0 : 180, at: t))
        }
        XCTAssertGreaterThan(steady.coherence, 0.9)
        XCTAssertLessThan(noisy.coherence, steady.coherence)
    }

    func testResetClearsState() {
        var smoother = HeadingSmoother()
        smoother.add(sample(90, at: 0))
        smoother.reset()
        XCTAssertNil(smoother.smoothedHeading)
    }

    func testHeadingSampleNormalisesItsInput() {
        XCTAssertEqual(sample(-90, at: 0).degrees, 270, accuracy: 1e-9)
        XCTAssertEqual(sample(450, at: 0).degrees, 90, accuracy: 1e-9)
        XCTAssertFalse(sample(0, at: 0, accuracy: -1).isValid)
        XCTAssertTrue(sample(0, at: 0, accuracy: 0).isValid)
    }

    func testSimulatedProviderReportsChanges() {
        let provider = SimulatedHeadingProvider(initialHeading: 10)
        var received: [HeadingStatus] = []
        provider.onChange = { received.append($0) }

        provider.set(heading: 200)
        provider.set(unavailable: .permissionDenied)

        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.first?.degrees ?? .nan, 200, accuracy: 1e-9)
        XCTAssertNil(received.last?.degrees)
    }
}
