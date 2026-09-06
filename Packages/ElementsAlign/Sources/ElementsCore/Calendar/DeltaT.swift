import Foundation

/// Delta-T, the difference between Terrestrial Time and Universal Time.
///
/// The VSOP87 series is defined in Terrestrial Time, but users are born, and
/// look at their watch, in Universal Time. Ignoring the distinction would put
/// every solar term about a minute out.
///
/// Polynomial expressions from Espenak & Meeus. Values beyond the observed
/// record are extrapolations and become progressively less reliable; for the
/// 1900-2100 span this product cares about, the residual error is a few
/// seconds at most, which is far below the ~10 second accuracy of the
/// truncated solar series.
public enum DeltaT {
    /// Delta-T in seconds for the given year and month.
    public static func seconds(year: Int, month: Int) -> Double {
        let y = Double(year) + (Double(month) - 0.5) / 12.0

        switch y {
        case ..<1900:
            // Before the range the Espenak & Meeus piecewise fits cover. The
            // product does not support birth dates this early, but returning
            // the long-term parabola here keeps the function total rather than
            // silently extrapolating the 1900-1920 fit backwards.
            return -20 + 32 * pow((y - 1820) / 100.0, 2)
        case ..<1920:
            let t = y - 1900
            return -2.79 + 1.494119 * t - 0.0598939 * pow(t, 2)
                + 0.0061966 * pow(t, 3) - 0.000197 * pow(t, 4)
        case ..<1941:
            let t = y - 1920
            return 21.20 + 0.84493 * t - 0.076100 * pow(t, 2) + 0.0020936 * pow(t, 3)
        case ..<1961:
            let t = y - 1950
            return 29.07 + 0.407 * t - pow(t, 2) / 233 + pow(t, 3) / 2547
        case ..<1986:
            let t = y - 1975
            return 45.45 + 1.067 * t - pow(t, 2) / 260 - pow(t, 3) / 718
        case ..<2005:
            let t = y - 2000
            return 63.86 + 0.3345 * t - 0.060374 * pow(t, 2) + 0.0017275 * pow(t, 3)
                + 0.000651814 * pow(t, 4) + 0.00002373599 * pow(t, 5)
        case ..<2050:
            let t = y - 2000
            return 62.92 + 0.32217 * t + 0.005589 * pow(t, 2)
        case ..<2150:
            return -20 + 32 * pow((y - 1820) / 100.0, 2) - 0.5628 * (2150 - y)
        default:
            return -20 + 32 * pow((y - 1820) / 100.0, 2)
        }
    }

    /// Terrestrial Time from Universal Time.
    public static func ephemerisDay(from julianDay: JulianDay) -> JulianEphemerisDay {
        let date = JulianDayConversion.gregorianDate(from: julianDay.value)
        let dt = seconds(year: date.year, month: date.month)
        return JulianEphemerisDay(julianDay.value + dt / 86400.0)
    }

    /// Universal Time from Terrestrial Time.
    public static func julianDay(from ephemerisDay: JulianEphemerisDay) -> JulianDay {
        let date = JulianDayConversion.gregorianDate(from: ephemerisDay.value)
        let dt = seconds(year: date.year, month: date.month)
        return JulianDay(ephemerisDay.value - dt / 86400.0)
    }
}
