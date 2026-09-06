import XCTest
@testable import ElementsCore

final class BaZiTests: XCTestCase {

    // MARK: - Sexagenary components

    func testYearPillarsMatchFixtures() {
        for testCase in Fixtures.root.yearPillars {
            let pillar = BaZiCalculator.yearPillar(baziYear: testCase.baziYear)
            XCTAssertEqual(pillar.stem.rawValue, testCase.stem, "\(testCase.baziYear)")
            XCTAssertEqual(pillar.branch.rawValue, testCase.branch, "\(testCase.baziYear)")
            XCTAssertEqual(pillar.name, testCase.name)
        }
    }

    func testYearPillarsMatchPublishedZodiacYears() {
        // External check: these are the widely published sexagenary years.
        XCTAssertEqual(BaZiCalculator.yearPillar(baziYear: 1984).chineseName, "甲子")
        XCTAssertEqual(BaZiCalculator.yearPillar(baziYear: 2024).chineseName, "甲辰")
        XCTAssertEqual(BaZiCalculator.yearPillar(baziYear: 2025).chineseName, "乙巳")
        XCTAssertEqual(BaZiCalculator.yearPillar(baziYear: 2026).chineseName, "丙午")
    }

    func testYearPillarCycleIsSixtyYears() {
        for year in 1900...1960 {
            XCTAssertEqual(BaZiCalculator.yearPillar(baziYear: year),
                           BaZiCalculator.yearPillar(baziYear: year + 60))
        }
    }

    func testDayPillarsMatchFixtures() {
        for testCase in Fixtures.root.dayPillars {
            let pillar = BaZiCalculator.dayPillar(julianDayNumber: testCase.jdn)
            XCTAssertEqual(pillar.stem.rawValue, testCase.stem, testCase.date)
            XCTAssertEqual(pillar.branch.rawValue, testCase.branch, testCase.date)
            XCTAssertEqual(pillar.name, testCase.name, testCase.date)
        }
    }

    func testDayPillarAnchorAndCycle() {
        // 2000-01-07 is a 甲子 day, the start of a sexagenary cycle.
        let anchor = JulianDayConversion.julianDayNumber(year: 2000, month: 1, day: 7)
        XCTAssertEqual(BaZiCalculator.dayPillar(julianDayNumber: anchor).chineseName, "甲子")

        // The count runs unbroken: one step per day, repeating every 60.
        for offset in 0..<200 {
            let today = BaZiCalculator.dayPillar(julianDayNumber: anchor + offset)
            let tomorrow = BaZiCalculator.dayPillar(julianDayNumber: anchor + offset + 1)
            XCTAssertEqual(tomorrow.stem.rawValue, (today.stem.rawValue + 1) % 10)
            XCTAssertEqual(tomorrow.branch.rawValue, (today.branch.rawValue + 1) % 12)
            XCTAssertEqual(today, BaZiCalculator.dayPillar(julianDayNumber: anchor + offset + 60))
        }
    }

    func testMonthStemFollowsFiveTigersRule() {
        // 五虎遁: the year stem fixes the stem of the 寅 month.
        let expected: [(HeavenlyStem, HeavenlyStem)] = [
            (.jia, .bing), (.yi, .wu), (.bing, .geng), (.ding, .ren), (.wu, .jia),
            (.ji, .bing), (.geng, .wu), (.xin, .geng), (.ren, .ren), (.gui, .jia),
        ]
        for (yearStem, yinMonthStem) in expected {
            XCTAssertEqual(BaZiCalculator.monthStem(yearStem: yearStem, monthBranch: .yin),
                           yinMonthStem, "year stem \(yearStem.chineseName)")
        }
        // Months then advance one stem at a time from 寅.
        XCTAssertEqual(BaZiCalculator.monthStem(yearStem: .jia, monthBranch: .mao), .ding)
        XCTAssertEqual(BaZiCalculator.monthStem(yearStem: .jia, monthBranch: .chen), .wu)
    }

    func testHourStemFollowsFiveRatsRule() {
        // 五鼠遁: the day stem fixes the stem of the 子 hour.
        let expected: [(HeavenlyStem, HeavenlyStem)] = [
            (.jia, .jia), (.yi, .bing), (.bing, .wu), (.ding, .geng), (.wu, .ren),
            (.ji, .jia), (.geng, .bing), (.xin, .wu), (.ren, .geng), (.gui, .ren),
        ]
        for (dayStem, ziHourStem) in expected {
            XCTAssertEqual(BaZiCalculator.hourStem(dayStem: dayStem, hourBranch: .zi),
                           ziHourStem, "day stem \(dayStem.chineseName)")
        }
    }

    func testHourBranchBoundaries() {
        // 子 spans 23:00 to 01:00 and therefore straddles midnight; every other
        // branch occupies a plain two-hour block.
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 23.0), .zi)
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 23.99), .zi)
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 0.0), .zi)
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 0.99), .zi)
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 1.0), .chou)
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 2.99), .chou)
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 3.0), .yin)
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 11.0), .wu)
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 12.99), .wu)
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 13.0), .wei)
        XCTAssertEqual(BaZiCalculator.hourBranch(solarHour: 22.99), .hai)
    }

    func testEveryHourOfTheDayMapsToABranch() {
        var seen = Set<EarthlyBranch>()
        for step in 0..<(24 * 60) {
            seen.insert(BaZiCalculator.hourBranch(solarHour: Double(step) / 60.0))
        }
        XCTAssertEqual(seen.count, 12, "all twelve branches must be reachable")
    }

    // MARK: - Whole charts

    func testFourPillarsMatchFixtures() {
        let calculator = BaZiCalculator()
        for testCase in Fixtures.root.fourPillars {
            let policy: LateZiPolicy = testCase.lateZiPolicy == "dayChangesAt23"
                ? .dayChangesAt23 : .dayChangesAtMidnight
            let options = BaZiOptions(lateZiPolicy: policy)
            let instant = JulianDayConversion.julianDay(from: Fixtures.date(testCase.utc))

            let pillars = calculator.pillars(at: instant,
                                             longitude: testCase.longitude,
                                             precision: .exact,
                                             options: options)

            let label = "\(testCase.label) [\(testCase.lateZiPolicy)]"
            XCTAssertEqual([pillars.year.stem.rawValue, pillars.year.branch.rawValue],
                           testCase.year, "year: \(label)")
            XCTAssertEqual([pillars.month.stem.rawValue, pillars.month.branch.rawValue],
                           testCase.month, "month: \(label)")
            XCTAssertEqual([pillars.day.stem.rawValue, pillars.day.branch.rawValue],
                           testCase.day, "day: \(label)")
            XCTAssertEqual([pillars.hour?.stem.rawValue, pillars.hour?.branch.rawValue]
                            .compactMap { $0 },
                           testCase.hour, "hour: \(label)")
            XCTAssertEqual(pillars.boundaryProximityMinutes,
                           testCase.boundaryProximityMinutes, accuracy: 0.05,
                           "boundary proximity: \(label)")
        }
    }

    func testYearAndMonthPillarsBothTurnAtLichun() {
        // The BaZi year begins at 立春, not at the lunar new year, and the 寅
        // month begins at the same instant. Both must change together.
        let calculator = BaZiCalculator()
        let lichun = calculator.solarTerms.instant(of: .lichun, year: 2026)

        let before = calculator.pillars(at: lichun.adding(days: -0.002), longitude: 120)
        let after = calculator.pillars(at: lichun.adding(days: 0.002), longitude: 120)

        XCTAssertEqual(before.year.chineseName, "乙巳")
        XCTAssertEqual(after.year.chineseName, "丙午")
        XCTAssertNotEqual(before.month, after.month)
        XCTAssertEqual(after.month.branch, .yin)

        // And both sides are flagged as boundary-sensitive.
        XCTAssertTrue(before.isNearMonthBoundary)
        XCTAssertTrue(after.isNearMonthBoundary)
    }

    func testJanuaryBirthBelongsToThePreviousBaziYear() {
        // A classic source of wrong charts: the calendar year has rolled over
        // but 立春 has not been reached.
        let calculator = BaZiCalculator()
        let january = JulianDayConversion.julianDay(
            from: GregorianDate(year: 2026, month: 1, day: 15.5))
        XCTAssertEqual(calculator.solarTerms.baziYear(at: JulianDay(january)), 2025)
    }

    func testLateZiPolicyChangesTheDayPillarButOnlyAfterElevenPm() {
        let calculator = BaZiCalculator()
        // A time comfortably inside the late 子 hour in local solar terms.
        let instant = JulianDayConversion.julianDay(
            from: GregorianDate(year: 2000, month: 6, day: 15.0 + 23.5 / 24.0))

        let shifting = calculator.pillars(
            at: JulianDay(instant), longitude: 0,
            options: BaZiOptions(lateZiPolicy: .dayChangesAt23, usesEquationOfTime: false))
        let notShifting = calculator.pillars(
            at: JulianDay(instant), longitude: 0,
            options: BaZiOptions(lateZiPolicy: .dayChangesAtMidnight, usesEquationOfTime: false))

        XCTAssertEqual(shifting.hour?.branch, .zi)
        XCTAssertEqual(notShifting.hour?.branch, .zi)
        XCTAssertEqual(shifting.day.stem.rawValue,
                       (notShifting.day.stem.rawValue + 1) % 10,
                       "the day pillar should advance by exactly one under dayChangesAt23")

        // Midday is unaffected by the policy either way.
        let midday = JulianDayConversion.julianDay(
            from: GregorianDate(year: 2000, month: 6, day: 15.5))
        XCTAssertEqual(
            calculator.pillars(at: JulianDay(midday), longitude: 0,
                               options: BaZiOptions(lateZiPolicy: .dayChangesAt23)).day,
            calculator.pillars(at: JulianDay(midday), longitude: 0,
                               options: BaZiOptions(lateZiPolicy: .dayChangesAtMidnight)).day)
    }

    func testUnknownBirthTimeOmitsTheHourPillarRatherThanInventingOne() {
        let calculator = BaZiCalculator()
        let instant = JulianDayConversion.julianDay(
            from: GregorianDate(year: 1990, month: 5, day: 15.5))

        let chart = calculator.pillars(at: JulianDay(instant), longitude: 126.978,
                                       precision: .dayOnly)
        XCTAssertNil(chart.hour)
        XCTAssertEqual(chart.precision, .dayOnly)
        XCTAssertEqual(chart.pillars.count, 3)

        // The remaining pillars are still real, and the distribution still
        // normalises without the missing one.
        let distribution = chart.elementDistribution()
        XCTAssertEqual(distribution.values.values.reduce(0, +), 1.0, accuracy: 1e-9)
    }

    func testUnknownBirthTimeIsStableAcrossTheSolarDay() {
        // A dayOnly chart is evaluated at the solar noon of the solar day
        // containing the instant, so any instant within that solar day yields
        // the same chart. Note that a solar day is not a UTC day: at Seoul's
        // longitude the two are about eight and a half hours apart, which is
        // why this is anchored on solar noon rather than on midnight UTC.
        let calculator = BaZiCalculator()
        let longitude = 126.978
        // Local solar noon on 1990-05-15 at this longitude falls near 03:28 UTC.
        let solarNoonUTC = JulianDayConversion.julianDay(
            from: GregorianDate(year: 1990, month: 5, day: 15.0 + 3.47 / 24.0))

        var pillars = Set<Pillar>()
        for offsetHours in stride(from: -11.0, through: 11.0, by: 1.0) {
            let instant = JulianDay(solarNoonUTC + offsetHours / 24.0)
            pillars.insert(calculator.pillars(at: instant, longitude: longitude,
                                              precision: .dayOnly).day)
        }
        XCTAssertEqual(pillars.count, 1,
                       "a dayOnly chart must be constant across its solar day")

        // And it must still advance across a solar day boundary, rather than
        // being constant because the calculation collapsed.
        let dayBefore = calculator.pillars(at: JulianDay(solarNoonUTC - 13.0 / 24.0),
                                           longitude: longitude, precision: .dayOnly).day
        let dayAfter = calculator.pillars(at: JulianDay(solarNoonUTC + 13.0 / 24.0),
                                          longitude: longitude, precision: .dayOnly).day
        guard let middle = pillars.first else { return XCTFail("no pillar computed") }
        XCTAssertEqual(middle.stem.rawValue, (dayBefore.stem.rawValue + 1) % 10)
        XCTAssertEqual(dayAfter.stem.rawValue, (middle.stem.rawValue + 1) % 10)
    }

    func testSolarTimeCorrectionMovesTheHourPillar() {
        // Seoul sits about 8.5 degrees west of the 135E meridian its clocks
        // follow, roughly 34 minutes of solar time. Near an hour boundary that
        // is the difference between two branches.
        let calculator = BaZiCalculator()
        let jd = JulianDayConversion.julianDay(
            from: GregorianDate(year: 2000, month: 6, day: 15.0 + (13.0 + 10.0 / 60.0) / 24.0))

        let corrected = calculator.solarTime(at: JulianDay(jd), longitude: 126.978)
        let uncorrected = calculator.solarTime(
            at: JulianDay(jd), longitude: 126.978,
            options: BaZiOptions(usesEquationOfTime: false))

        XCTAssertNotEqual(corrected.value, uncorrected.value)
        // The equation of time never exceeds about 17 minutes.
        XCTAssertLessThan(abs(corrected.minutes(since: uncorrected)), 17.0)
    }
}
