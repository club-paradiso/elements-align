import Foundation

/// A birth time as a person records it: a wall-clock reading, plus the zone
/// whose clocks they were reading.
///
/// This is the source of truth for a birth, not the resulting instant. Storing
/// the instant alone loses the ability to re-resolve it, and the resolution
/// genuinely changes: the tz database is revised as historical records are
/// corrected, and a chart built from a saved instant would silently keep an
/// old answer.
///
/// The zone matters far more than it looks. Korea ran on UTC+8:30 from 1954 to
/// 1961, so a 1955 Seoul birth resolved against modern KST lands half an hour
/// out -- enough to cross an hour-pillar boundary. Korea also observed summer
/// time in 1950, 1960, 1987 and 1988.
public struct CivilBirthTime: Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let hour: Int
    public let minute: Int
    /// IANA identifier, e.g. "Asia/Seoul". Not a fixed offset: the whole point
    /// is to pick up the offset that was in force on that date.
    public let timeZoneIdentifier: String

    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int,
                timeZoneIdentifier: String) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public var timeZone: TimeZone? { TimeZone(identifier: timeZoneIdentifier) }

    /// The reading taken at face value, as though the clock had been on UTC.
    ///
    /// Computed in whole seconds rather than through a Julian Day. A Julian
    /// Day is a Double near 2.45 million, so a round trip through one loses
    /// the last fraction of a second -- enough that an instant which should be
    /// exactly 17:30:00 comes back as 17:29:59.9999997. That is invisible in
    /// the pillars, which only care about minutes, but it makes every instant
    /// compare unequal to the one it should be. Integers have no such problem.
    var naiveUTC: Date {
        // Julian Day Number 2440588 is the noon of 1970-01-01, so subtracting
        // it gives whole days since the Unix epoch.
        let dayNumber = JulianDayConversion.julianDayNumber(
            year: year, month: month, day: day)
        let seconds = (dayNumber - 2_440_588) * 86_400 + hour * 3_600 + minute * 60
        return Date(timeIntervalSince1970: Double(seconds))
    }
}

/// What happened when a wall-clock reading was resolved to an instant.
///
/// Most readings map to exactly one instant. Two do not, and both are real
/// situations a birth certificate can describe:
///
/// * On the night clocks go back, a reading occurs twice.
/// * On the night clocks go forward, a reading may never occur at all.
///
/// The engine surfaces these rather than silently picking one, in the same way
/// it surfaces a birth falling close to a solar term boundary.
public enum CivilTimeResolution: Hashable, Sendable {
    /// Exactly one instant matches.
    case unique(Date)
    /// The clock reading occurred twice. Both instants, earlier first.
    case ambiguous(earlier: Date, later: Date)
    /// The clock reading never occurred; the clock jumped over it. The instant
    /// carried is the one the clock skipped to.
    case skipped(Date)
    /// The time zone identifier could not be resolved at all.
    case unknownTimeZone

    /// The instant the engine should use.
    ///
    /// For an ambiguous reading this is the earlier of the two, which is the
    /// reading before the clocks went back. That is a product decision, not a
    /// fact about the birth: the interface says so rather than presenting it
    /// as settled.
    public var instant: Date? {
        switch self {
        case let .unique(date): return date
        case let .ambiguous(earlier, _): return earlier
        case let .skipped(date): return date
        case .unknownTimeZone: return nil
        }
    }

    /// True when the reading did not map cleanly and the chart is built on a
    /// choice rather than on the record.
    public var isUncertain: Bool {
        switch self {
        case .unique: return false
        case .ambiguous, .skipped, .unknownTimeZone: return true
        }
    }
}

public extension CivilBirthTime {

    /// Resolves this wall-clock reading to a UTC instant.
    ///
    /// Deliberately does not use `Calendar.date(from:)`. That silently applies
    /// its own disambiguation policy, which is undocumented, and gives no way
    /// to tell a clean reading from one that fell in a gap or a repeat. Here
    /// the candidates are enumerated explicitly:
    ///
    /// 1. Read the components as though they were UTC, giving a naive instant.
    /// 2. Collect the zone's offsets in a window around it, which captures
    ///    both sides of any transition nearby.
    /// 3. For each offset, an interpretation is *self-consistent* only if
    ///    subtracting it lands on an instant where the zone really is at that
    ///    offset.
    ///
    /// Two self-consistent candidates means the reading occurred twice; none
    /// means the clock jumped over it.
    func resolve() -> CivilTimeResolution {
        guard let zone = timeZone else { return .unknownTimeZone }

        let naive = naiveUTC

        // A day either side comfortably brackets any transition, which are at
        // most an hour or two and never more than a day apart.
        var offsets = Set<Int>()
        for delta in [-86_400.0, -3_600.0, 0.0, 3_600.0, 86_400.0] {
            offsets.insert(zone.secondsFromGMT(for: naive.addingTimeInterval(delta)))
        }

        var consistent: [Date] = []
        for offset in offsets {
            let candidate = naive.addingTimeInterval(-Double(offset))
            if zone.secondsFromGMT(for: candidate) == offset {
                consistent.append(candidate)
            }
        }
        consistent.sort()

        switch consistent.count {
        case 1:
            return .unique(consistent[0])
        case 2...:
            return .ambiguous(earlier: consistent[0], later: consistent[consistent.count - 1])
        default:
            // A gap. Interpreting the reading with the offset in force *before*
            // the jump lands after it, which is where the clock actually went.
            // That is the later of the two inconsistent candidates.
            let skipped = offsets
                .map { naive.addingTimeInterval(-Double($0)) }
                .max() ?? naive
            return .skipped(skipped)
        }
    }

    /// Offset from UTC in effect for this reading, in seconds, or nil when the
    /// zone is unknown. Exposed so the interface can show the user what was
    /// actually applied -- "UTC+8:30" is the kind of thing worth seeing.
    func utcOffsetSeconds() -> Int? {
        guard let zone = timeZone, let instant = resolve().instant else { return nil }
        return zone.secondsFromGMT(for: instant)
    }
}
