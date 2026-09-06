import Foundation

/// What the current moment is made of.
///
/// This exists to keep expensive work off the heading path. Heading updates
/// arrive many times a second; the pillars of the current moment change at most
/// once every two solar hours. The snapshot carries `validUntil` so callers can
/// recompute exactly when it stops being true and not one moment sooner —
/// which is the difference between a watch face that costs nothing to run and
/// one that solves Kepler's equation sixty times a second.
public struct TemporalSnapshot: Hashable, Sendable {
    public let instant: Date
    public let pillars: FourPillars
    public let distribution: ElementDistribution
    public let dominantElement: Element
    /// The instant at which the hour pillar next changes.
    public let validUntil: Date

    public init(instant: Date,
                location: GeoLocation,
                calculator: BaZiCalculator,
                options: BaZiOptions = .default) {
        let jd = JulianDayConversion.julianDay(from: instant)
        let pillars = calculator.pillars(at: jd,
                                         longitude: location.longitude,
                                         precision: .exact,
                                         options: options)
        let distribution = pillars.elementDistribution(weights: .moment)

        self.instant = instant
        self.pillars = pillars
        self.distribution = distribution
        self.dominantElement = distribution.dominant

        // Hour branches turn on odd hours of apparent solar time. The solar
        // time offset drifts by well under a second over a two-hour window, so
        // the same delta can be applied to UT.
        let solar = calculator.solarTime(at: jd,
                                         longitude: location.longitude,
                                         options: options)
        let solarHour = JulianDayConversion.gregorianDate(from: solar.value).hourOfDay
        let hoursIntoBranch = (solarHour + 1.0).truncatingRemainder(dividingBy: 2.0)
        let hoursRemaining = 2.0 - hoursIntoBranch
        self.validUntil = instant.addingTimeInterval(hoursRemaining * 3600.0)
    }

    public func isValid(at date: Date) -> Bool { date < validUntil }
}
