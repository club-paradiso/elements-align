import Foundation

/// The states the experience moves through.
///
/// Categories lead and the number follows, deliberately. A score of 73.4 looks
/// like a measurement, and this is not a measurement — it is a symbolic value
/// derived from traditional rules. The named states are the honest unit.
public enum AlignmentLevel: Int, CaseIterable, Comparable, Hashable, Sendable {
    case low = 0
    case unfavourable
    case neutral
    case favourable
    case strong
    case aligned

    /// Score at or above which this level begins.
    public var lowerBound: Double {
        [0.0, 30.0, 45.0, 58.0, 71.0, 84.0][rawValue]
    }

    public static func forScore(_ score: Double) -> AlignmentLevel {
        var result = AlignmentLevel.low
        for level in AlignmentLevel.allCases where score >= level.lowerBound {
            result = level
        }
        return result
    }

    public static func < (lhs: AlignmentLevel, rhs: AlignmentLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var identifier: String {
        ["low", "unfavourable", "neutral", "favourable", "strong", "aligned"][rawValue]
    }

    public var localizationKey: String { "alignment.level.\(identifier)" }

    /// Whether this level is one the interface should visibly celebrate.
    public var isElevated: Bool { self >= .strong }
}
