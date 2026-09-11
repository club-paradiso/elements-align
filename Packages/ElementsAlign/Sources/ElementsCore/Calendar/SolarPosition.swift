import Foundation

/// Apparent geocentric position of the Sun.
///
/// This is the astronomical foundation the whole calendar rests on: the BaZi
/// year begins at solar longitude 315 degrees, and each BaZi month begins at a
/// fixed solar longitude. Everything downstream is only as good as this.
///
/// Implementation follows the standard chain — VSOP87 heliocentric longitude of
/// the Earth, converted to a geocentric solar longitude, corrected to FK5, then
/// for nutation and annual aberration. The series coefficients live in the
/// generated ``VSOP87Earth`` and were validated at generation time against the
/// untruncated series (worst case 0.395 arcsec over 1900-2100, about 9.6
/// seconds of solar-term timing error).
public enum SolarPosition {
    static let arcsecond = 1.0 / 3600.0

    /// Evaluates a VSOP87 series in Julian millennia.
    static func series(_ terms: [[VSOPTerm]], tau: Double) -> Double {
        var total = 0.0
        var tauPower = 1.0
        for group in terms {
            var sum = 0.0
            for term in group {
                sum += term.amplitude * cos(term.phase + term.frequency * tau)
            }
            total += sum * tauPower
            tauPower *= tau
        }
        return total * 1e-8
    }

    /// Nutation in longitude (Delta psi), in degrees.
    ///
    /// IAU 1980 series. `t` is Julian centuries of Terrestrial Time from J2000.
    public static func nutationInLongitude(julianCenturies t: Double) -> Double {
        let d = 297.85036 + t * (445_267.111480 + t * (-0.0019142 + t / 189_474.0))
        let m = 357.52772 + t * (35_999.050340 + t * (-0.0001603 - t / 300_000.0))
        let mPrime = 134.96298 + t * (477_198.867398 + t * (0.0086972 + t / 56_250.0))
        let f = 93.27191 + t * (483_202.017538 + t * (-0.0036825 + t / 327_270.0))
        let omega = 125.04452 + t * (-1934.136261 + t * (0.0020708 + t / 450_000.0))

        var deltaPsi = 0.0
        for term in VSOP87Earth.nutation {
            let argument = Double(term.d) * d
                + Double(term.m) * m
                + Double(term.mPrime) * mPrime
                + Double(term.f) * f
                + Double(term.omega) * omega
            let amplitude = term.coefficient + term.coefficientRate * t
            deltaPsi += amplitude * sin(Angle.degreesToRadians(argument))
        }
        // Table coefficients are in units of 0.0001 arcsecond.
        return (deltaPsi / 10_000.0) * arcsecond
    }

    /// Mean obliquity of the ecliptic in degrees. Meeus ch. 22.
    public static func meanObliquity(julianCenturies t: Double) -> Double {
        23.0 + 26.0 / 60.0 + 21.448 / 3600.0
            - (46.8150 * t + 0.00059 * t * t - 0.001813 * t * t * t) / 3600.0
    }

    /// Earth's distance from the Sun in astronomical units.
    public static func radiusVector(_ jde: JulianEphemerisDay) -> Double {
        series(VSOP87Earth.radius, tau: (jde.value - 2_451_545.0) / 365_250.0)
    }

    /// Apparent geocentric longitude of the Sun, in degrees [0, 360).
    public static func apparentLongitude(_ jde: JulianEphemerisDay) -> Double {
        let tau = (jde.value - 2_451_545.0) / 365_250.0
        let t = (jde.value - 2_451_545.0) / 36_525.0

        let heliocentric = series(VSOP87Earth.longitude, tau: tau) * 180.0 / .pi
        var longitude = heliocentric.truncatingRemainder(dividingBy: 360.0)

        // Earth's heliocentric longitude to the Sun's geocentric longitude.
        longitude += 180.0

        // FK5 conversion. The latitude-dependent part of the correction is
        // below 0.00001 arcsec for the Sun, because the Earth's heliocentric
        // latitude never exceeds about one arcsecond, so only the constant
        // term is retained.
        longitude += -0.09033 * arcsecond

        longitude += nutationInLongitude(julianCenturies: t)
        longitude += -20.4898 * arcsecond / radiusVector(jde)

        return Angle.normalizedDegrees(longitude)
    }

    /// The equation of time, in minutes: apparent solar time minus mean solar
    /// time. Meeus ch. 28.
    ///
    /// This matters because classical BaZi hour boundaries are boundaries of
    /// *apparent* (true) solar time, not of clock time. Ignoring it shifts the
    /// hour pillar by up to about a quarter of an hour.
    public static func equationOfTimeMinutes(_ jde: JulianEphemerisDay) -> Double {
        let t = (jde.value - 2_451_545.0) / 36_525.0
        let tau = (jde.value - 2_451_545.0) / 365_250.0

        // Geometric mean longitude of the Sun, in Julian millennia form.
        let l0 = Angle.normalizedDegrees(
            280.4664567 + 360_007.6982779 * tau + 0.03032028 * tau * tau
                + pow(tau, 3) / 49_931.0
                - pow(tau, 4) / 15_300.0
                - pow(tau, 5) / 2_000_000.0)

        let lambda = apparentLongitude(jde)
        let epsilon = meanObliquity(julianCenturies: t)
        let lambdaRad = lambda * .pi / 180.0
        let epsilonRad = epsilon * .pi / 180.0

        let alpha = Angle.normalizedDegrees(
            atan2(cos(epsilonRad) * sin(lambdaRad), cos(lambdaRad)) * 180.0 / .pi)

        let deltaPsi = nutationInLongitude(julianCenturies: t)
        var e = l0 - 0.0057183 - alpha + deltaPsi * cos(epsilonRad)
        e = Angle.signedDegrees(e)
        return e * 4.0
    }
}
