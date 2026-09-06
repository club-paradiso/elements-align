import XCTest
@testable import ElementsCore

final class CalendarTests: XCTestCase {

    // MARK: - Julian day

    func testJulianDayRoundTrip() {
        for (year, month, day) in [(1900, 1, 1.0), (1984, 2, 2.5), (2000, 1, 1.5),
                                   (2026, 9, 6.25), (2050, 12, 31.75)] {
            let date = GregorianDate(year: year, month: month, day: day)
            let jd = JulianDayConversion.julianDay(from: date)
            let back = JulianDayConversion.gregorianDate(from: jd)
            XCTAssertEqual(back.year, year)
            XCTAssertEqual(back.month, month)
            XCTAssertEqual(back.day, day, accuracy: 1e-6)
        }
    }

    func testKnownJulianDayValues() {
        // J2000.0 is 2000 January 1.5 TT, the anchor the whole solar model uses.
        XCTAssertEqual(
            JulianDayConversion.julianDay(from: GregorianDate(year: 2000, month: 1, day: 1.5)),
            2_451_545.0, accuracy: 1e-9)
        // The Unix epoch.
        XCTAssertEqual(
            JulianDayConversion.julianDay(from: GregorianDate(year: 1970, month: 1, day: 1.0)),
            2_440_587.5, accuracy: 1e-9)
    }

    func testDateBridgeRoundTrip() {
        let date = Date(timeIntervalSince1970: 1_234_567_890)
        let jd = JulianDayConversion.julianDay(from: date)
        let back = JulianDayConversion.date(from: jd)
        XCTAssertEqual(back.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1e-3)
    }

    func testLeapDayJulianDayNumberIsContiguous() {
        // 2024 is a leap year: 28 Feb, 29 Feb and 1 Mar must be consecutive.
        let feb28 = JulianDayConversion.julianDayNumber(year: 2024, month: 2, day: 28)
        let feb29 = JulianDayConversion.julianDayNumber(year: 2024, month: 2, day: 29)
        let mar01 = JulianDayConversion.julianDayNumber(year: 2024, month: 3, day: 1)
        XCTAssertEqual(feb29, feb28 + 1)
        XCTAssertEqual(mar01, feb29 + 1)

        // 1900 was not a leap year under the Gregorian rule.
        let feb28_1900 = JulianDayConversion.julianDayNumber(year: 1900, month: 2, day: 28)
        let mar01_1900 = JulianDayConversion.julianDayNumber(year: 1900, month: 3, day: 1)
        XCTAssertEqual(mar01_1900, feb28_1900 + 1)
    }

    // MARK: - Delta-T

    func testDeltaTMatchesFixtures() {
        for testCase in Fixtures.root.deltaT {
            XCTAssertEqual(DeltaT.seconds(year: testCase.year, month: testCase.month),
                           testCase.seconds, accuracy: 1e-6,
                           "Delta-T for \(testCase.year)")
        }
    }

    func testDeltaTIsContinuousAcrossPiecewiseBoundaries() {
        // The polynomial branches meet at these years; a discontinuity would
        // make a solar term jump when a chart crosses one.
        for boundary in [1920, 1941, 1961, 1986, 2005, 2050] {
            let before = DeltaT.seconds(year: boundary - 1, month: 12)
            let after = DeltaT.seconds(year: boundary, month: 1)
            XCTAssertEqual(before, after, accuracy: 2.0,
                           "Delta-T jumps at \(boundary)")
        }
    }

    // MARK: - Solar position

    func testEquationOfTimeMatchesFixtures() {
        for testCase in Fixtures.root.equationOfTime {
            let jd = JulianDayConversion.julianDay(from: Fixtures.date(testCase.utc))
            let jde = DeltaT.ephemerisDay(from: jd)
            XCTAssertEqual(SolarPosition.equationOfTimeMinutes(jde),
                           testCase.minutes, accuracy: 1e-3,
                           "equation of time at \(testCase.utc)")
        }
    }

    func testEquationOfTimeHitsPublishedAnnualExtremes() {
        // Independent of the fixtures: these are textbook landmarks. The
        // equation of time bottoms out near -14.2 minutes in mid-February and
        // peaks near +16.4 minutes in early November.
        func value(_ month: Int, _ day: Int) -> Double {
            let jd = JulianDayConversion.julianDay(
                from: GregorianDate(year: 2026, month: month, day: Double(day) + 0.5))
            return SolarPosition.equationOfTimeMinutes(DeltaT.ephemerisDay(from: JulianDay(jd)))
        }
        XCTAssertEqual(value(2, 11), -14.2, accuracy: 0.3)
        XCTAssertEqual(value(11, 3), 16.4, accuracy: 0.3)
        XCTAssertEqual(value(4, 15), 0.0, accuracy: 0.5)
    }

    // MARK: - Solar terms

    func testSolarTermsMatchFixtures() {
        let calculator = SolarTermCalculator()
        for testCase in Fixtures.root.solarTerms {
            guard let term = SolarTerm(rawValue: testCase.index) else {
                return XCTFail("bad term index \(testCase.index)")
            }
            XCTAssertEqual(term.name, testCase.name)
            XCTAssertEqual(term.solarLongitude, testCase.longitude, accuracy: 1e-9)

            let expected = JulianDayConversion.julianDay(from: Fixtures.date(testCase.utc))
            let actual = calculator.instant(of: term, year: testCase.year)
            // Two seconds. The fixture's own timestamps are second-rounded, so
            // this is tight enough to catch any real divergence.
            XCTAssertEqual(actual.value, expected.value, accuracy: 2.0 / 86400.0,
                           "\(testCase.name) \(testCase.year)")
        }
    }

    func testSolarTermsAgreeWithPublishedEquinoxes() {
        // External check, independent of the fixtures. The March equinox is by
        // definition the moment apparent solar longitude reaches 0 degrees.
        let calculator = SolarTermCalculator()
        let published: [(Int, SolarTerm, String)] = [
            (2026, .chunfen, "2026-03-20T14:46:00Z"),
            (2026, .xiazhi, "2026-06-21T08:25:00Z"),
            (2026, .qiufen, "2026-09-23T00:05:00Z"),
            (2026, .dongzhi, "2026-12-21T20:50:00Z"),
            (2000, .chunfen, "2000-03-20T07:35:00Z"),
        ]
        for (year, term, iso) in published {
            let expected = JulianDayConversion.julianDay(from: Fixtures.date(iso))
            let actual = calculator.instant(of: term, year: year)
            XCTAssertEqual(actual.minutes(since: expected), 0, accuracy: 2.0,
                           "\(term.name) \(year) differs from the published instant")
        }
    }

    func testSolarLongitudeIsMonotonicOverAYear() {
        // Catches a solver that has locked on to the wrong revolution.
        var previous = -1.0
        var wraps = 0
        for day in stride(from: 0.0, to: 365.0, by: 1.0) {
            let jde = JulianEphemerisDay(2_461_041.5 + day)
            let longitude = SolarPosition.apparentLongitude(jde)
            if longitude < previous { wraps += 1 }
            previous = longitude
        }
        XCTAssertEqual(wraps, 1, "solar longitude should wrap exactly once per year")
    }

    func testMonthDefiningTermsAreTheTwelveJie() {
        XCTAssertEqual(SolarTerm.monthDefining.count, 12)
        XCTAssertEqual(SolarTerm.lichun.solarLongitude, 315.0)
        XCTAssertEqual(SolarTerm.lichun.monthBranch, .yin)
        XCTAssertTrue(SolarTerm.lichun.isMonthDefining)
        // Mid-month qi terms never start a BaZi month.
        XCTAssertFalse(SolarTerm.yushui.isMonthDefining)
        XCTAssertNil(SolarTerm.yushui.monthBranch)
        // Branches advance in order from 寅.
        XCTAssertEqual(SolarTerm.jingzhe.monthBranch, .mao)
        XCTAssertEqual(SolarTerm.daxue.monthBranch, .zi)
    }

    func testSolarTermCacheReturnsIdenticalResults() {
        let calculator = SolarTermCalculator()
        let first = calculator.instant(of: .lichun, year: 2026)
        let second = calculator.instant(of: .lichun, year: 2026)
        XCTAssertEqual(first.value, second.value)
    }
}
