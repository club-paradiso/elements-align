import Foundation

/// A change of level.
public struct AlignmentTransition: Hashable, Sendable {
    public let from: AlignmentLevel
    public let to: AlignmentLevel
    public let date: Date

    public var isRising: Bool { to > from }
}

/// The feedback a transition earns.
///
/// Domain-level intent, not a watchOS type: the core layer decides *whether*
/// something deserves to be felt, and the watch layer decides what that feels
/// like. That split is what keeps this testable off-device.
public enum HapticCue: String, Hashable, Sendable {
    /// Something changed for the better. Barely there.
    case subtle
    /// The composition is coming together.
    case affirm
    /// Full alignment. The one moment in the product that gets to be distinct.
    case aligned
}

/// Turns a continuously varying score into a stable level, and decides when
/// that deserves to be felt.
///
/// Two problems are being solved here, both of them about restraint.
///
/// A raw score sitting near a threshold crosses it constantly as the wearer
/// breathes, so the level is guarded by hysteresis — a band that must be
/// cleared to rise and re-cleared to fall — plus a minimum dwell so that even a
/// large genuine swing cannot produce two transitions in quick succession.
///
/// And a watch that buzzes every time you turn your wrist is a watch people
/// take off. Falling transitions are silent, because this product does not
/// nag. Only the two upward transitions that mean something get a cue, and
/// even those are rate-limited.
public struct AlignmentTracker: Hashable, Sendable {

    /// Points a score must clear beyond a threshold before the level changes.
    public static let hysteresisMargin = 3.0

    /// Minimum time between level changes.
    public static let minimumDwell: TimeInterval = 1.5

    /// Minimum time between haptic cues, however many transitions occur.
    public static let minimumHapticInterval: TimeInterval = 4.0

    public private(set) var level: AlignmentLevel
    private var lastTransitionDate: Date?
    private var lastHapticDate: Date?

    public init(level: AlignmentLevel = .neutral) {
        self.level = level
    }

    /// Feeds a new score in. Returns a transition only when the level actually
    /// changed, so callers can drive animation and feedback off the return
    /// value rather than diffing state themselves.
    public mutating func update(score: Double, at date: Date) -> AlignmentTransition? {
        var candidate = level

        // Rise only once clearly past the next threshold. The loop allows a
        // jump of several levels, which happens when a snapshot refreshes.
        while candidate < .aligned,
              let next = AlignmentLevel(rawValue: candidate.rawValue + 1),
              score >= next.lowerBound + Self.hysteresisMargin {
            candidate = next
        }

        // Fall only once clearly below our own threshold.
        while candidate > .low,
              score < candidate.lowerBound - Self.hysteresisMargin,
              let previous = AlignmentLevel(rawValue: candidate.rawValue - 1) {
            candidate = previous
        }

        guard candidate != level else { return nil }

        if let last = lastTransitionDate,
           date.timeIntervalSince(last) < Self.minimumDwell {
            return nil
        }

        let transition = AlignmentTransition(from: level, to: candidate, date: date)
        level = candidate
        lastTransitionDate = date
        return transition
    }

    /// The cue a transition earns, or nil for silence.
    ///
    /// Rate limiting lives here rather than at the call site so that the policy
    /// cannot be accidentally bypassed by a caller that forgets it.
    public mutating func cue(for transition: AlignmentTransition) -> HapticCue? {
        guard let cue = Self.unlimitedCue(for: transition) else { return nil }
        if let last = lastHapticDate,
           transition.date.timeIntervalSince(last) < Self.minimumHapticInterval {
            return nil
        }
        lastHapticDate = transition.date
        return cue
    }

    /// The policy itself, without rate limiting. Exposed for testing.
    public static func unlimitedCue(for transition: AlignmentTransition) -> HapticCue? {
        // Falling is always silent. Being told you have moved away from
        // something good is exactly the fortune-telling tone this product is
        // trying not to have.
        guard transition.isRising else { return nil }

        switch transition.to {
        case .aligned:
            return .aligned
        case .strong:
            return .affirm
        case .favourable:
            // Deliberately silent. Reaching merely favourable is common enough
            // that a cue here would fire constantly and mean nothing.
            return nil
        case .low, .unfavourable, .neutral:
            return nil
        }
    }
}
