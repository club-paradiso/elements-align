import Foundation
import ElementsCore

/// Smooths a noisy heading stream.
///
/// Averaging headings as plain numbers is wrong: the mean of 359 and 1 is 180,
/// pointing south when the device points north. So samples are accumulated as
/// unit vectors and the smoothed heading is read back with `atan2`, which makes
/// wraparound simply not exist as a case.
///
/// The filter is a first-order exponential moving average with a time constant
/// rather than a fixed weight, so its behaviour does not change when the sensor
/// delivers samples at a different rate — which it does, between devices and
/// between foreground and background.
public struct HeadingSmoother: Sendable {

    /// Time for the filter to cover about 63% of a step change.
    ///
    /// Chosen as a compromise the interaction depends on: long enough that a
    /// resting wrist does not shimmer, short enough that deliberately turning
    /// feels immediate rather than dragged.
    public static let defaultTimeConstant: TimeInterval = 0.35

    /// Readings less precise than this are discarded. Core Location reports
    /// large values near magnetic interference, and letting those through
    /// makes the display wander while the user is standing still.
    public static let defaultAccuracyLimit: Double = 25.0

    public let timeConstant: TimeInterval
    public let accuracyLimit: Double

    private var x = 0.0
    private var y = 0.0
    private var lastTimestamp: Date?
    private var hasValue = false

    public init(timeConstant: TimeInterval = HeadingSmoother.defaultTimeConstant,
                accuracyLimit: Double = HeadingSmoother.defaultAccuracyLimit) {
        self.timeConstant = timeConstant
        self.accuracyLimit = accuracyLimit
    }

    /// The current smoothed heading, or nil before any usable sample.
    public var smoothedHeading: Double? {
        guard hasValue, x != 0 || y != 0 else { return nil }
        return Angle.normalizedDegrees(Angle.radiansToDegrees(atan2(x, y)))
    }

    /// Length of the accumulated vector, in [0, 1].
    ///
    /// Near 1 the recent samples agree; near 0 they disagree, which is what
    /// magnetic interference looks like. Useful as a confidence signal.
    public var coherence: Double { min(1.0, (x * x + y * y).squareRoot()) }

    /// Feeds in a sample. Returns the new smoothed heading, or nil if the
    /// sample was rejected and no value has been established yet.
    @discardableResult
    public mutating func add(_ sample: HeadingSample) -> Double? {
        guard sample.isValid, sample.accuracyDegrees <= accuracyLimit else {
            return smoothedHeading
        }

        let radians = Angle.degreesToRadians(sample.degrees)
        let sx = sin(radians)
        let sy = cos(radians)

        guard hasValue, let last = lastTimestamp else {
            x = sx
            y = sy
            lastTimestamp = sample.timestamp
            hasValue = true
            return smoothedHeading
        }

        // Out-of-order or duplicate timestamps would otherwise produce a
        // negative dt and an alpha outside [0, 1].
        let dt = max(0.0, sample.timestamp.timeIntervalSince(last))
        let alpha = timeConstant > 0 ? 1.0 - exp(-dt / timeConstant) : 1.0

        x += (sx - x) * alpha
        y += (sy - y) * alpha
        lastTimestamp = sample.timestamp
        return smoothedHeading
    }

    public mutating func reset() {
        x = 0
        y = 0
        hasValue = false
        lastTimestamp = nil
    }
}
