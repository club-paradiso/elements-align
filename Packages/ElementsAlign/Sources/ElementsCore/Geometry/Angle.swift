import Foundation

/// Angle arithmetic on the compass circle.
///
/// Every bug this type exists to prevent is a wraparound bug: the difference
/// between 359 degrees and 1 degree is 2 degrees, not 358. Nothing in the
/// product should subtract two headings directly.
public enum Angle {
    /// Folds any angle into [0, 360).
    ///
    /// Uses a floored modulo rather than `truncatingRemainder`, which keeps the
    /// sign of the dividend and would return -10 for -10 degrees.
    public static func normalizedDegrees(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360.0)
        return remainder < 0 ? remainder + 360.0 : remainder
    }

    /// Folds any angle into [-180, 180).
    public static func signedDegrees(_ degrees: Double) -> Double {
        normalizedDegrees(degrees + 180.0) - 180.0
    }

    /// Shortest signed rotation from `a` to `b`, in [-180, 180).
    /// Positive means clockwise.
    public static func signedDifference(from a: Double, to b: Double) -> Double {
        signedDegrees(b - a)
    }

    /// Shortest unsigned angular distance between two headings, in [0, 180].
    public static func distance(_ a: Double, _ b: Double) -> Double {
        abs(signedDifference(from: a, to: b))
    }

    public static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180.0
    }

    public static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180.0 / .pi
    }

    /// Hermite smoothstep on [0, 1]. Zero first derivative at both ends, which
    /// is what keeps interpolated values from kinking at sector boundaries.
    public static func smoothstep(_ t: Double) -> Double {
        let clamped = min(max(t, 0.0), 1.0)
        return clamped * clamped * (3.0 - 2.0 * clamped)
    }

    public static func clamp01(_ x: Double) -> Double { min(max(x, 0.0), 1.0) }
}
