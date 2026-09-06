import Foundation

/// Which day a late-night 子 hour (23:00-23:59) belongs to.
///
/// Two schools disagree, and neither is "the correct formula". This is a
/// genuine fork in the tradition, so it is a setting with a documented default
/// rather than a hidden assumption.
public enum LateZiPolicy: String, CaseIterable, Hashable, Sendable {
    /// 子時換日 — the day turns at 23:00, so a 23:30 birth already belongs to
    /// the next day's pillar. The default, and the more common convention in
    /// modern Four Pillars practice.
    case dayChangesAt23
    /// 子正換日 — the day turns at midnight.
    case dayChangesAtMidnight
}

/// Options governing how a birth instant becomes a chart.
public struct BaZiOptions: Hashable, Sendable {
    public var lateZiPolicy: LateZiPolicy

    /// Whether to apply the equation of time.
    ///
    /// Classical hour boundaries are boundaries of *apparent* solar time. With
    /// this off, only the longitude correction is applied, giving local mean
    /// solar time — which is what some practitioners use. On by default.
    public var usesEquationOfTime: Bool

    public init(lateZiPolicy: LateZiPolicy = .dayChangesAt23,
                usesEquationOfTime: Bool = true) {
        self.lateZiPolicy = lateZiPolicy
        self.usesEquationOfTime = usesEquationOfTime
    }

    public static let `default` = BaZiOptions()
}

/// Turns an instant and a longitude into a Four Pillars chart.
///
/// Every step here is deterministic arithmetic over the astronomical layer.
/// Nothing is randomised, nothing is interpreted, and nothing consults a
/// language model; interpretation happens strictly above this layer.
public struct BaZiCalculator: Sendable {
    public let solarTerms: SolarTermCalculator

    public init(solarTerms: SolarTermCalculator = SolarTermCalculator()) {
        self.solarTerms = solarTerms
    }

    // MARK: - Sexagenary components

    /// Year pillar from a BaZi year. 1984 is 甲子, the start of a cycle.
    public static func yearPillar(baziYear: Int) -> Pillar {
        let stem = ((baziYear - 4) % 10 + 10) % 10
        let branch = ((baziYear - 4) % 12 + 12) % 12
        return Pillar(stem: HeavenlyStem(rawValue: stem) ?? .jia,
                      branch: EarthlyBranch(rawValue: branch) ?? .zi)
    }

    /// Day pillar from an integer Julian Day Number.
    ///
    /// The sexagenary day count runs unbroken across the whole calendar, so it
    /// needs no epoch table — just a congruence. Cross-checked against two
    /// independent published statements of the same formula, and against
    /// 2000-01-07 being a 甲子 day.
    public static func dayPillar(julianDayNumber: Int) -> Pillar {
        let stem = ((julianDayNumber - 1) % 10 + 10) % 10
        let branch = ((julianDayNumber + 1) % 12 + 12) % 12
        return Pillar(stem: HeavenlyStem(rawValue: stem) ?? .jia,
                      branch: EarthlyBranch(rawValue: branch) ?? .zi)
    }

    /// Month stem via 五虎遁, the "five tigers" rule: the year stem fixes the
    /// stem of the 寅 month, and months advance from there.
    public static func monthStem(yearStem: HeavenlyStem, monthBranch: EarthlyBranch) -> HeavenlyStem {
        let yinMonthStem = (yearStem.rawValue % 5) * 2 + 2
        let ordinalFromYin = ((monthBranch.rawValue - 2) % 12 + 12) % 12
        return HeavenlyStem(rawValue: (yinMonthStem + ordinalFromYin) % 10) ?? .jia
    }

    /// Hour stem via 五鼠遁, the "five rats" rule: the day stem fixes the stem
    /// of the 子 hour.
    public static func hourStem(dayStem: HeavenlyStem, hourBranch: EarthlyBranch) -> HeavenlyStem {
        HeavenlyStem(rawValue: ((dayStem.rawValue % 5) * 2 + hourBranch.rawValue) % 10) ?? .jia
    }

    /// Earthly branch of a solar-time hour. 子 spans 23:00 to 01:00, so the
    /// hour is shifted by one before being halved.
    public static func hourBranch(solarHour: Double) -> EarthlyBranch {
        let shifted = (solarHour + 1.0).truncatingRemainder(dividingBy: 24.0)
        let positive = shifted < 0 ? shifted + 24.0 : shifted
        let index = Int((positive / 2.0).rounded(.down)) % 12
        return EarthlyBranch(rawValue: index) ?? .zi
    }

    // MARK: - Solar time

    /// Local apparent solar time, expressed as a Julian Day.
    ///
    /// Clock time is a political construct; the pillars are defined against the
    /// Sun. The longitude term converts UT to local mean solar time, and the
    /// equation of time converts that to apparent solar time. Together they can
    /// move an hour pillar by well over an hour near the edges of a wide time
    /// zone, which is why this is not optional in practice.
    public func solarTime(at instant: JulianDay,
                          longitude: Double,
                          options: BaZiOptions = .default) -> JulianDay {
        var jd = instant.value + longitude / 360.0
        if options.usesEquationOfTime {
            let jde = DeltaT.ephemerisDay(from: instant)
            jd += SolarPosition.equationOfTimeMinutes(jde) / 1440.0
        }
        return JulianDay(jd)
    }

    // MARK: - Chart

    /// Builds a chart for an instant observed at a given longitude.
    ///
    /// - Parameters:
    ///   - instant: The moment, in Universal Time.
    ///   - longitude: Degrees east of Greenwich, negative for west. This is the
    ///     birth longitude, not the current one — solar time is a property of
    ///     where the event happened.
    ///   - precision: `.dayOnly` omits the hour pillar entirely.
    public func pillars(at instant: JulianDay,
                        longitude: Double,
                        precision: ChartPrecision = .exact,
                        options: BaZiOptions = .default) -> FourPillars {
        let baziYear = solarTerms.baziYear(at: instant)
        let yearPillar = Self.yearPillar(baziYear: baziYear)

        let monthTerm = solarTerms.currentMonthTerm(at: instant).term
        let monthBranch = monthTerm.monthBranch ?? .yin
        let monthPillar = Pillar(
            stem: Self.monthStem(yearStem: yearPillar.stem, monthBranch: monthBranch),
            branch: monthBranch)

        // The day and hour pillars are read off local apparent solar time. When
        // the birth time is unknown we evaluate at local solar noon: that is
        // not a guess at the time of birth, it is the point of the day
        // furthest from both candidate day boundaries, so the *day* pillar it
        // yields is the one least sensitive to the missing information.
        let solarJD: JulianDay
        switch precision {
        case .exact:
            solarJD = solarTime(at: instant, longitude: longitude, options: options)
        case .dayOnly:
            let solar = solarTime(at: instant, longitude: longitude, options: options)
            let noon = solar.value.rounded(.down) + 0.5
            solarJD = JulianDay(noon)
        }

        let solarDate = JulianDayConversion.gregorianDate(from: solarJD.value)
        let solarHour = solarDate.hourOfDay
        var jdn = JulianDayConversion.julianDayNumber(
            year: solarDate.year, month: solarDate.month, day: solarDate.wholeDay)

        if precision == .exact,
           options.lateZiPolicy == .dayChangesAt23,
           solarHour >= 23.0 {
            jdn += 1
        }

        let dayPillar = Self.dayPillar(julianDayNumber: jdn)

        let hourPillar: Pillar?
        switch precision {
        case .exact:
            let branch = Self.hourBranch(solarHour: solarHour)
            hourPillar = Pillar(stem: Self.hourStem(dayStem: dayPillar.stem, hourBranch: branch),
                                branch: branch)
        case .dayOnly:
            hourPillar = nil
        }

        return FourPillars(
            year: yearPillar,
            month: monthPillar,
            day: dayPillar,
            hour: hourPillar,
            precision: precision,
            boundaryProximityMinutes:
                solarTerms.minutesToNearestMonthBoundary(from: instant))
    }
}
