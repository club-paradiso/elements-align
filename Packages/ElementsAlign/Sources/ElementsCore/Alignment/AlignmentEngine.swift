import Foundation

/// Everything the engine needs to produce a state.
public struct AlignmentContext: Sendable {
    public let chart: PersonalChart
    public let temporal: TemporalSnapshot
    /// Current compass heading in degrees, or nil when heading is unavailable
    /// — no compass hardware, permission refused, or the sensor is still
    /// settling. Nil is a first-class case, not an error.
    public let heading: Double?

    public init(chart: PersonalChart, temporal: TemporalSnapshot, heading: Double?) {
        self.chart = chart
        self.temporal = temporal
        self.heading = heading
    }
}

/// The result of an evaluation.
public struct AlignmentState: Hashable, Sendable {
    public let score: Double
    public let level: AlignmentLevel

    /// The three components, each in [0, 1], before weighting. Exposed so the
    /// debug screen can explain a score rather than assert it.
    public let spatialScore: Double
    public let temporalScore: Double
    public let personalScore: Double

    public let dominantElement: Element
    /// The user's single most favourable direction (生氣).
    public let favourableDirection: CompassSector
    /// The Eight Mansions relationship of the direction currently faced.
    public let headingRelation: BaZhaiRelation?
    /// Signed shortest rotation to the most favourable direction, or nil when
    /// heading is unavailable. Positive means turn clockwise.
    public let degreesToFavourable: Double?
    /// True when heading was unavailable and the spatial component fell back
    /// to neutral. The interface must not imply a direction in this case.
    public let isHeadingAvailable: Bool

    /// Memberwise initialiser.
    ///
    /// Public so that presentation code and tests can construct a state
    /// directly. Producing one this way bypasses the engine and therefore
    /// carries no guarantee of internal consistency; use ``AlignmentEngine``
    /// for anything the user will see.
    public init(score: Double,
                level: AlignmentLevel,
                spatialScore: Double,
                temporalScore: Double,
                personalScore: Double,
                dominantElement: Element,
                favourableDirection: CompassSector,
                headingRelation: BaZhaiRelation?,
                degreesToFavourable: Double?,
                isHeadingAvailable: Bool) {
        self.score = score
        self.level = level
        self.spatialScore = spatialScore
        self.temporalScore = temporalScore
        self.personalScore = personalScore
        self.dominantElement = dominantElement
        self.favourableDirection = favourableDirection
        self.headingRelation = headingRelation
        self.degreesToFavourable = degreesToFavourable
        self.isHeadingAvailable = isHeadingAvailable
    }
}

/// Combines a person, a moment and a direction into a single symbolic value.
///
/// This is a deterministic function of its inputs. Given the same profile, the
/// same instant and the same heading it returns the same state, always. There
/// is no randomness anywhere in it, and no language model: an LLM may one day
/// help *explain* a result, but it can never be where the result comes from.
///
/// What the score is and is not is set out in
/// Documentation/ALIGNMENT_ENGINE.md. In short: it is a symbolic value derived
/// from selected traditional rules and current context. It is not a
/// measurement of anything physical, and nothing in this file should ever be
/// described as one.
public struct AlignmentEngine: Sendable {

    // MARK: - Tuning

    /// Component weights. Spatial leads because turning the body is the
    /// interaction the product is built around; if direction did not dominate,
    /// rotating would barely move the display.
    public static let spatialWeight = 0.50
    public static let temporalWeight = 0.35
    public static let personalWeight = 0.15

    /// Spread applied to the temporal component's deviation from its baseline.
    public static let temporalGain = 1.5

    /// How far the unfavourable half of the compass is allowed to fall.
    ///
    /// Auspicious directions use the whole upper half of the range; the four
    /// inauspicious ones are compressed into 0.25...0.5 instead of running to
    /// zero. The traditional ordering is preserved exactly — the mapping is
    /// monotonic in the underlying value — but an unfavourable direction reads
    /// as unresolved rather than as a warning. This product does not tell
    /// people that where they are standing is bad for them.
    public static let unfavourableCompression = 0.25

    /// Natal balance is remapped from this floor across this range. Real charts
    /// cluster in the upper part of the entropy scale, so the raw value would
    /// otherwise vary too little between people to be worth including.
    public static let balanceFloor = 0.60
    public static let balanceRange = 0.35

    public init() {}

    // MARK: - Components

    /// Where you are facing, as Eight Mansions sees it. Range [0.25, 1].
    public func spatialComponent(heading: Double?, baZhai: BaZhaiProfile) -> Double {
        guard let heading else { return 0.5 }
        let value = baZhai.directionalValue(heading: heading)
        let slope = value >= 0 ? 0.5 : Self.unfavourableCompression
        return Angle.clamp01(0.5 + slope * value)
    }

    /// How much of the present moment is made of the elements this chart wants.
    ///
    /// The share is compared against the baseline a neutral moment would give —
    /// which depends on how many elements the chart favours, two or three — so
    /// that charts wanting three elements are not flattered relative to charts
    /// wanting two.
    public func temporalComponent(chart: PersonalChart,
                                  temporal: TemporalSnapshot) -> Double {
        let favourable = chart.favourableElements
        guard !favourable.isEmpty else { return 0.5 }
        let share = temporal.distribution.share(of: favourable)
        let baseline = Double(favourable.count) / 5.0
        return Angle.clamp01(0.5 + (share - baseline) * Self.temporalGain)
    }

    /// A stable per-person baseline: how evenly the five elements are spread
    /// across the natal chart. Constant for a given person by design — it
    /// shifts where someone sits, it does not drive movement.
    public func personalComponent(chart: PersonalChart) -> Double {
        Angle.clamp01((chart.natalBalance - Self.balanceFloor) / Self.balanceRange)
    }

    // MARK: - Evaluation

    public func evaluate(_ context: AlignmentContext) -> AlignmentState {
        let baZhai = context.chart.baZhai
        let spatial = spatialComponent(heading: context.heading, baZhai: baZhai)
        let temporal = temporalComponent(chart: context.chart, temporal: context.temporal)
        let personal = personalComponent(chart: context.chart)

        let score = 100.0 * (Self.spatialWeight * spatial
                             + Self.temporalWeight * temporal
                             + Self.personalWeight * personal)

        let favourableDirection = baZhai.primaryDirection
        let headingRelation = context.heading.map {
            baZhai.relation(for: CompassSector.containing(heading: $0))
        }
        let degreesToFavourable = context.heading.map {
            Angle.signedDifference(from: $0, to: favourableDirection.centerDegrees)
        }

        return AlignmentState(
            score: score,
            level: AlignmentLevel.forScore(score),
            spatialScore: spatial,
            temporalScore: temporal,
            personalScore: personal,
            dominantElement: context.temporal.dominantElement,
            favourableDirection: favourableDirection,
            headingRelation: headingRelation,
            degreesToFavourable: degreesToFavourable,
            isHeadingAvailable: context.heading != nil)
    }
}
