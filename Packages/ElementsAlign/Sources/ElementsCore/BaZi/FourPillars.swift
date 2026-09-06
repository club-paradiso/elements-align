import Foundation

/// How precisely a chart could be determined from what the user told us.
public enum ChartPrecision: String, Hashable, Sendable {
    /// Birth time was supplied: all four pillars are available.
    case exact
    /// Birth time was not supplied. The hour pillar is absent rather than
    /// guessed, and the chart carries correspondingly less information.
    case dayOnly
}

/// A Four Pillars chart (四柱).
public struct FourPillars: Hashable, Sendable {
    public let year: Pillar
    public let month: Pillar
    public let day: Pillar
    /// Nil when the birth time is unknown. The engine never invents one.
    public let hour: Pillar?

    public let precision: ChartPrecision

    /// Minutes to the nearest month-defining solar term.
    ///
    /// When this is small the month pillar, and at 立春 the year pillar too,
    /// turns on the exactness of the birth time. The product surfaces the
    /// uncertainty instead of presenting a boundary result as settled.
    public let boundaryProximityMinutes: Double

    public init(year: Pillar, month: Pillar, day: Pillar, hour: Pillar?,
                precision: ChartPrecision, boundaryProximityMinutes: Double) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.precision = precision
        self.boundaryProximityMinutes = boundaryProximityMinutes
    }

    /// The Day Master (日主): the day pillar's stem, which represents the
    /// person in Four Pillars analysis.
    public var dayMaster: HeavenlyStem { day.stem }
    public var dayMasterElement: Element { day.stem.element }

    /// A birth within this many minutes of a solar term is flagged as
    /// boundary-sensitive. Chosen well above the engine's own ~10 second
    /// astronomical error so the flag reflects *user* time uncertainty
    /// (rounded birth certificates, unrecorded seconds), not ours.
    public static let boundaryWarningMinutes: Double = 30.0

    public var isNearMonthBoundary: Bool {
        boundaryProximityMinutes < Self.boundaryWarningMinutes
    }

    public var pillars: [Pillar] { [year, month, day, hour].compactMap { $0 } }

    public var name: String {
        pillars.map(\.name).joined(separator: " ")
    }

    public var chineseName: String {
        pillars.map(\.chineseName).joined()
    }
}

/// How the four pillars are weighted when building an element distribution.
///
/// Two profiles exist because two different questions are being asked, and
/// answering both with one weighting is what made an earlier version of this
/// engine unusable — see Documentation/ALIGNMENT_ENGINE.md.
public struct PillarWeights: Hashable, Sendable {
    public let year: Double
    public let month: Double
    public let day: Double
    public let hour: Double

    public init(year: Double, month: Double, day: Double, hour: Double) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
    }

    /// "What is this person made of?"
    ///
    /// The month pillar carries extra weight because seasonal command (得令)
    /// is the classical basis for judging whether a Day Master is strong.
    public static let natal = PillarWeights(year: 1.0, month: 1.5, day: 1.0, hour: 1.0)

    /// "What is right now made of?"
    ///
    /// Day and hour lead, because they are what actually changes while the
    /// user is wearing the watch; year and month are slow background. This is
    /// a product decision rather than a classical rule.
    public static let moment = PillarWeights(year: 0.5, month: 1.0, day: 1.5, hour: 1.5)
}

public extension FourPillars {
    /// Weighted Five Element distribution of the chart.
    ///
    /// Each pillar contributes its stem at full pillar weight and its branch's
    /// hidden stems at weights summing to the same, so stems and branches carry
    /// equal total influence. An absent hour pillar simply contributes nothing;
    /// normalisation handles the rest.
    func elementDistribution(weights: PillarWeights = .natal) -> ElementDistribution {
        var raw: [Element: Double] = [:]
        let entries: [(Pillar?, Double)] = [
            (year, weights.year), (month, weights.month),
            (day, weights.day), (hour, weights.hour),
        ]
        for (pillar, weight) in entries {
            guard let pillar else { continue }
            raw[pillar.stem.element, default: 0] += weight
            for hidden in pillar.branch.weightedHiddenStems {
                raw[hidden.stem.element, default: 0] += hidden.weight * weight
            }
        }
        return ElementDistribution(weights: raw)
    }

    /// Share of the chart that supports the Day Master: its own element plus
    /// the element that produces it (比劫 and 印).
    func dayMasterStrength() -> Double {
        let distribution = elementDistribution(weights: .natal)
        let master = dayMasterElement
        return distribution[master] + distribution[master.generatedBy]
    }

    var isDayMasterStrong: Bool { dayMasterStrength() > 0.5 }

    /// The elements this chart benefits from (喜用神).
    ///
    /// This applies the support/suppress school (扶抑法): a strong Day Master
    /// wants elements that drain or restrain it, a weak one wants elements that
    /// feed it. It is one school among several and the engine does not pretend
    /// otherwise; special-structure charts (從格, 專旺) are out of scope for V1.
    func favourableElements() -> Set<Element> {
        let master = dayMasterElement
        if isDayMasterStrong {
            return [master.generates, master.controls, master.controlledBy]
        }
        return [master, master.generatedBy]
    }

    /// Normalised entropy of the natal distribution, in [0, 1].
    func natalBalance() -> Double {
        elementDistribution(weights: .natal).balance
    }
}
