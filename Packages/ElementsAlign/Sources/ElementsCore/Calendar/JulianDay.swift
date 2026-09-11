import Foundation

/// A Julian Day number.
///
/// The engine works in Julian Days rather than `Date` components because every
/// calculation here — solar longitude, solar terms, the sexagenary day count —
/// is naturally expressed that way, and because it keeps the arithmetic free of
/// calendar/time-zone behaviour that varies between platforms.
///
/// Two distinct time scales appear throughout, and confusing them is the single
/// easiest way to get this wrong, so they are separate types:
/// `JulianDay` is Universal Time; ``JulianEphemerisDay`` is Terrestrial Time.
public struct JulianDay: Hashable, Comparable, Sendable {
    public var value: Double

    public init(_ value: Double) { self.value = value }

    public static func < (lhs: JulianDay, rhs: JulianDay) -> Bool { lhs.value < rhs.value }

    /// Days added to this instant.
    public func adding(days: Double) -> JulianDay { JulianDay(value + days) }

    /// Difference in minutes, `self - other`.
    public func minutes(since other: JulianDay) -> Double {
        (value - other.value) * 1440.0
    }
}

/// A Julian Day in Terrestrial Time, the scale the VSOP87 series is defined in.
public struct JulianEphemerisDay: Hashable, Comparable, Sendable {
    public var value: Double

    public init(_ value: Double) { self.value = value }

    public static func < (lhs: JulianEphemerisDay, rhs: JulianEphemerisDay) -> Bool {
        lhs.value < rhs.value
    }
}

/// A date in the proleptic Gregorian calendar, with a fractional day.
public struct GregorianDate: Hashable, Sendable {
    public var year: Int
    public var month: Int
    /// Day of month including a fractional part: 3.5 is noon on the 3rd.
    public var day: Double

    public init(year: Int, month: Int, day: Double) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Whole day of month.
    public var wholeDay: Int { Int(day.rounded(.down)) }

    /// Hour of day in [0, 24).
    public var hourOfDay: Double { (day - day.rounded(.down)) * 24.0 }
}

public enum JulianDayConversion {
    /// Meeus, *Astronomical Algorithms*, ch. 7. Gregorian calendar only, which
    /// is all this product needs: the earliest supported birth date is well
    /// after the Gregorian reform.
    public static func julianDay(from date: GregorianDate) -> Double {
        var y = date.year
        var m = date.month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = Int((Double(y) / 100.0).rounded(.down))
        let b = 2 - a + a / 4
        return (365.25 * Double(y + 4716)).rounded(.down)
            + (30.6001 * Double(m + 1)).rounded(.down)
            + date.day + Double(b) - 1524.5
    }

    /// Inverse of ``julianDay(from:)``. Meeus ch. 7.
    public static func gregorianDate(from julianDay: Double) -> GregorianDate {
        let shifted = julianDay + 0.5
        let z = shifted.rounded(.down)
        let f = shifted - z
        let a: Double
        if z < 2_299_161 {
            a = z
        } else {
            let alpha = ((z - 1_867_216.25) / 36524.25).rounded(.down)
            a = z + 1 + alpha - (alpha / 4).rounded(.down)
        }
        let b = a + 1524
        let c = ((b - 122.1) / 365.25).rounded(.down)
        let d = (365.25 * c).rounded(.down)
        let e = ((b - d) / 30.6001).rounded(.down)
        let day = b - d - (30.6001 * e).rounded(.down) + f
        let month = e < 14 ? Int(e) - 1 : Int(e) - 13
        let year = month > 2 ? Int(c) - 4716 : Int(c) - 4715
        return GregorianDate(year: year, month: month, day: day)
    }

    /// The integer Julian Day Number of the noon belonging to a civil date.
    ///
    /// This is the value the sexagenary day count is defined against, so it
    /// must be the *noon* JDN, not a rounded instant.
    public static func julianDayNumber(year: Int, month: Int, day: Int) -> Int {
        let jd = julianDay(from: GregorianDate(year: year, month: month,
                                               day: Double(day) + 0.5))
        return Int(jd.rounded(.down))
    }

    /// Unix epoch (1970-01-01T00:00:00Z) as a Julian Day.
    public static let unixEpochJulianDay: Double = 2_440_587.5

    public static func julianDay(from date: Date) -> JulianDay {
        JulianDay(unixEpochJulianDay + date.timeIntervalSince1970 / 86400.0)
    }

    public static func date(from julianDay: JulianDay) -> Date {
        Date(timeIntervalSince1970: (julianDay.value - unixEpochJulianDay) * 86400.0)
    }
}
