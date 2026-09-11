import Foundation

/// The 24 solar terms (二十四節氣).
///
/// Each term is defined by an exact apparent solar longitude, which is why this
/// is an astronomical calculation and not a lookup table of dates.
///
/// The 12 terms at even indices are 節 (jie); each one starts a BaZi month.
/// The 12 at odd indices are 氣 (qi), mid-month markers that the pillar
/// calculation does not use. ``lichun`` is index 0 because it is where both the
/// BaZi year and the first month begin.
public enum SolarTerm: Int, CaseIterable, Sendable {
    case lichun = 0, yushui, jingzhe, chunfen, qingming, guyu
    case lixia, xiaoman, mangzhong, xiazhi, xiaoshu, dashu
    case liqiu, chushu, bailu, qiufen, hanlu, shuangjiang
    case lidong, xiaoxue, daxue, dongzhi, xiaohan, dahan

    /// Apparent solar longitude that defines this term, in degrees.
    public var solarLongitude: Double {
        Double((rawValue * 15 + 315) % 360)
    }

    /// True for the 12 月建 terms that begin a BaZi month.
    public var isMonthDefining: Bool { rawValue % 2 == 0 }

    /// Romanised name.
    public var name: String {
        ["Lichun", "Yushui", "Jingzhe", "Chunfen", "Qingming", "Guyu",
         "Lixia", "Xiaoman", "Mangzhong", "Xiazhi", "Xiaoshu", "Dashu",
         "Liqiu", "Chushu", "Bailu", "Qiufen", "Hanlu", "Shuangjiang",
         "Lidong", "Xiaoxue", "Daxue", "Dongzhi", "Xiaohan", "Dahan"][rawValue]
    }

    public var chineseName: String {
        ["立春", "雨水", "驚蟄", "春分", "清明", "穀雨",
         "立夏", "小滿", "芒種", "夏至", "小暑", "大暑",
         "立秋", "處暑", "白露", "秋分", "寒露", "霜降",
         "立冬", "小雪", "大雪", "冬至", "小寒", "大寒"][rawValue]
    }

    /// The 12 month-defining terms, in BaZi month order starting at 立春.
    public static let monthDefining: [SolarTerm] = allCases.filter(\.isMonthDefining)

    /// Earthly branch of the month this term begins. 立春 begins 寅.
    public var monthBranch: EarthlyBranch? {
        guard isMonthDefining else { return nil }
        return EarthlyBranch(rawValue: (2 + rawValue / 2) % 12)
    }
}

/// Computes the instants of solar terms.
///
/// Results are memoised because the calculation is comparatively expensive
/// (roughly 175 trigonometric terms per iteration, several iterations per
/// solve) and because determining a month pillar needs up to 36 solves. On the
/// watch this must never run on a per-heading-update path; see
/// ``TemporalSnapshot``, which is what the alignment engine actually consumes.
public final class SolarTermCalculator: @unchecked Sendable {
    private struct Key: Hashable { let year: Int; let term: Int }

    private var cache: [Key: JulianDay] = [:]
    private let lock = NSLock()

    public init() {}

    /// Mean motion of the Sun in degrees per day, used as the Newton slope.
    private static let meanDailyMotion = 0.9856473

    /// The instant, in Universal Time, of `term` in the given Gregorian year.
    public func instant(of term: SolarTerm, year: Int) -> JulianDay {
        let key = Key(year: year, term: term.rawValue)

        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        let result = computeInstant(of: term, year: year)

        lock.lock()
        cache[key] = result
        lock.unlock()
        return result
    }

    private func computeInstant(of term: SolarTerm, year: Int) -> JulianDay {
        let longitude = term.solarLongitude
        // Solar longitude 280 degrees falls near 1 January, so this converts a
        // target longitude into an approximate day-of-year to seed Newton.
        let approximateDayOfYear =
            Angle.normalizedDegrees(longitude - 280.0) * 365.2422 / 360.0
        let seed = JulianDayConversion.julianDay(
            from: GregorianDate(year: year, month: 1, day: 1.0)) + approximateDayOfYear

        var jde = JulianEphemerisDay(seed)
        for _ in 0..<60 {
            let difference = Angle.signedDegrees(
                SolarPosition.apparentLongitude(jde) - longitude)
            if abs(difference) < 1e-9 { break }
            jde = JulianEphemerisDay(jde.value - difference / Self.meanDailyMotion)
        }
        return DeltaT.julianDay(from: jde)
    }

    /// The most recent month-defining term at or before `instant`, together with
    /// the branch of the month it begins.
    ///
    /// Searches the neighbouring years as well as the current one, because a
    /// January instant belongs to a month that began the previous December.
    public func currentMonthTerm(at instant: JulianDay) -> (term: SolarTerm, start: JulianDay) {
        let year = JulianDayConversion.gregorianDate(from: instant.value).year
        var best: (SolarTerm, JulianDay)?

        for candidateYear in (year - 1)...(year + 1) {
            for term in SolarTerm.monthDefining {
                let start = self.instant(of: term, year: candidateYear)
                guard start <= instant else { continue }
                if best == nil || start > best!.1 {
                    best = (term, start)
                }
            }
        }

        // The search window always contains at least 立春 of the previous year,
        // so `best` cannot be nil for any instant this product accepts.
        guard let found = best else {
            return (.lichun, self.instant(of: .lichun, year: year - 1))
        }
        return found
    }

    /// Minutes to the nearest month-defining solar term.
    ///
    /// Small values mean the month pillar — and at 立春 the year pillar too —
    /// is sensitive to the precision of the birth time the user gave us. The
    /// product surfaces this rather than pretending the boundary is exact.
    public func minutesToNearestMonthBoundary(from instant: JulianDay) -> Double {
        let year = JulianDayConversion.gregorianDate(from: instant.value).year
        var smallest = Double.greatestFiniteMagnitude
        for candidateYear in (year - 1)...(year + 1) {
            for term in SolarTerm.monthDefining {
                let start = self.instant(of: term, year: candidateYear)
                smallest = min(smallest, abs(start.minutes(since: instant)))
            }
        }
        return smallest
    }

    /// The BaZi year an instant belongs to.
    ///
    /// The BaZi year turns at 立春, not at the lunar new year. This is the more
    /// widely used convention in Four Pillars practice and is the one this
    /// product commits to; see Documentation/TRADITIONAL_SYSTEMS.md.
    public func baziYear(at instant: JulianDay) -> Int {
        let year = JulianDayConversion.gregorianDate(from: instant.value).year
        return instant >= self.instant(of: .lichun, year: year) ? year : year - 1
    }
}
