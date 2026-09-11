import XCTest
@testable import ElementsCore

final class CivilBirthTimeTests: XCTestCase {

    private func civil(_ c: Fixtures.TimeZoneCase) -> CivilBirthTime {
        CivilBirthTime(year: c.year, month: c.month, day: c.day,
                       hour: c.hour, minute: c.minute,
                       timeZoneIdentifier: c.timeZone)
    }

    func testTimeZoneDataIsAvailableAtAll() {
        // If the platform has no tz database, every other test here would fail
        // in a confusing way. Fail clearly instead.
        XCTAssertNotNil(TimeZone(identifier: "Asia/Seoul"),
                        "no tz database available; historical offsets cannot be resolved")
        XCTAssertNotNil(TimeZone(identifier: "America/New_York"))
    }

    func testResolutionsMatchFixtures() {
        for testCase in Fixtures.root.timeZones {
            let resolution = civil(testCase).resolve()
            let label = "\(testCase.year)-\(testCase.month)-\(testCase.day) "
                + "\(testCase.hour):\(testCase.minute) \(testCase.timeZone)"

            switch (resolution, testCase.kind) {
            case let (.unique(date), "unique"):
                XCTAssertEqual(date, Fixtures.date(testCase.instant), label)
            case let (.skipped(date), "skipped"):
                XCTAssertEqual(date, Fixtures.date(testCase.instant), label)
            case let (.ambiguous(earlier, later), "ambiguous"):
                XCTAssertEqual(earlier, Fixtures.date(testCase.instant), "\(label) earlier")
                guard let expectedLater = testCase.laterInstant else {
                    return XCTFail("fixture missing laterInstant for \(label)")
                }
                XCTAssertEqual(later, Fixtures.date(expectedLater), "\(label) later")
            default:
                XCTFail("expected \(testCase.kind) at \(label), got \(resolution)")
            }

            XCTAssertEqual(civil(testCase).utcOffsetSeconds(), testCase.offsetSeconds, label)
        }
    }

    // MARK: - The cases a naive conversion gets wrong

    func testKoreaUsedAHalfHourOffsetBetween1954And1961() {
        // The whole reason this type exists. Resolving a 1955 Seoul birth
        // against modern KST puts it half an hour out, which is enough to
        // cross an hour-pillar boundary.
        let birth = CivilBirthTime(year: 1955, month: 6, day: 15, hour: 9, minute: 0,
                                   timeZoneIdentifier: "Asia/Seoul")
        guard let offset = birth.utcOffsetSeconds() else {
            return XCTFail("could not resolve Asia/Seoul")
        }
        // 1955 was also under Korean summer time, so +8:30 plus an hour.
        XCTAssertEqual(offset, 9 * 3600 + 1800, "expected UTC+9:30 in June 1955")

        let modern = CivilBirthTime(year: 2026, month: 6, day: 15, hour: 9, minute: 0,
                                    timeZoneIdentifier: "Asia/Seoul")
        XCTAssertEqual(modern.utcOffsetSeconds(), 9 * 3600)
    }

    func testTheOffsetChangesAcrossKoreasNineteenSixtyOneTransition() {
        let before = CivilBirthTime(year: 1961, month: 6, day: 1, hour: 12, minute: 0,
                                    timeZoneIdentifier: "Asia/Seoul")
        let after = CivilBirthTime(year: 1961, month: 9, day: 1, hour: 12, minute: 0,
                                   timeZoneIdentifier: "Asia/Seoul")
        XCTAssertEqual(before.utcOffsetSeconds(), 8 * 3600 + 1800)
        XCTAssertEqual(after.utcOffsetSeconds(), 9 * 3600)
    }

    func testAClockReadingInsideASpringForwardGapIsReportedAsSkipped() {
        // Korea 1987: clocks went 02:00 -> 03:00 on 10 May, so 02:30 never was.
        let birth = CivilBirthTime(year: 1987, month: 5, day: 10, hour: 2, minute: 30,
                                   timeZoneIdentifier: "Asia/Seoul")
        guard case let .skipped(instant) = birth.resolve() else {
            return XCTFail("expected a skipped reading, got \(birth.resolve())")
        }
        XCTAssertTrue(birth.resolve().isUncertain)
        // The clock jumped to 03:30 local, which is 17:30 UTC the day before.
        XCTAssertEqual(instant, Fixtures.date("1987-05-09T17:30:00Z"))
    }

    func testAClockReadingInsideAFallBackRepeatIsReportedAsAmbiguous() {
        // Korea 1987: clocks went 03:00 -> 02:00 on 11 October, so 02:30 twice.
        let birth = CivilBirthTime(year: 1987, month: 10, day: 11, hour: 2, minute: 30,
                                   timeZoneIdentifier: "Asia/Seoul")
        guard case let .ambiguous(earlier, later) = birth.resolve() else {
            return XCTFail("expected an ambiguous reading, got \(birth.resolve())")
        }
        XCTAssertTrue(birth.resolve().isUncertain)
        XCTAssertEqual(later.timeIntervalSince(earlier), 3600,
                       "the two readings should be an hour apart")
        // The engine takes the earlier of the two, and says that it did.
        XCTAssertEqual(birth.resolve().instant, earlier)
    }

    func testUnitedStatesDaylightEdgesBehaveTheSameWay() {
        let gap = CivilBirthTime(year: 2023, month: 3, day: 12, hour: 2, minute: 30,
                                 timeZoneIdentifier: "America/New_York")
        let repeated = CivilBirthTime(year: 2023, month: 11, day: 5, hour: 1, minute: 30,
                                      timeZoneIdentifier: "America/New_York")
        if case .skipped = gap.resolve() {} else { XCTFail("expected skipped, got \(gap.resolve())") }
        if case .ambiguous = repeated.resolve() {} else { XCTFail("expected ambiguous") }
    }

    func testOrdinaryReadingsAreUniqueAndNotFlagged() {
        for identifier in ["Asia/Seoul", "Asia/Tokyo", "Europe/London",
                           "America/New_York", "Asia/Kolkata", "Australia/Sydney"] {
            let birth = CivilBirthTime(year: 1990, month: 5, day: 15, hour: 14, minute: 30,
                                       timeZoneIdentifier: identifier)
            let resolution = birth.resolve()
            XCTAssertFalse(resolution.isUncertain, identifier)
            if case .unique = resolution {} else { XCTFail("expected unique for \(identifier)") }
        }
    }

    func testHalfHourAndQuarterHourZonesResolve() {
        XCTAssertEqual(
            CivilBirthTime(year: 1995, month: 12, day: 25, hour: 6, minute: 15,
                           timeZoneIdentifier: "Asia/Kolkata").utcOffsetSeconds(),
            5 * 3600 + 1800)
        XCTAssertEqual(
            CivilBirthTime(year: 2020, month: 6, day: 1, hour: 12, minute: 0,
                           timeZoneIdentifier: "Asia/Kathmandu").utcOffsetSeconds(),
            5 * 3600 + 2700)
    }

    func testAnUnknownZoneIsReportedRatherThanGuessed() {
        let birth = CivilBirthTime(year: 1990, month: 5, day: 15, hour: 14, minute: 30,
                                   timeZoneIdentifier: "Not/AZone")
        XCTAssertEqual(birth.resolve(), .unknownTimeZone)
        XCTAssertNil(birth.resolve().instant)
        XCTAssertNil(birth.utcOffsetSeconds())
        XCTAssertTrue(birth.resolve().isUncertain)
    }

    // MARK: - Effect on a chart

    func testTheZoneActuallyChangesTheChart() {
        // A reading that lands either side of an hour-pillar boundary
        // depending on which offset is applied. This is the bug the type was
        // written for, asserted end to end.
        let calculator = BaZiCalculator()
        let seoul = GeoLocation(latitude: 37.567, longitude: 126.978)

        let correct = BirthMoment(
            civil: CivilBirthTime(year: 1955, month: 6, day: 15, hour: 9, minute: 0,
                                  timeZoneIdentifier: "Asia/Seoul"),
            location: seoul)
        let wrong = BirthMoment(
            civil: CivilBirthTime(year: 1955, month: 6, day: 15, hour: 9, minute: 0,
                                  timeZoneIdentifier: "Asia/Tokyo"),
            location: seoul)

        XCTAssertNotEqual(correct.instant, wrong.instant,
                          "1955 Korea ran 30 minutes behind Japan")
        XCTAssertEqual(wrong.instant.timeIntervalSince(correct.instant), -1800)

        let correctChart = PersonalChart(
            profile: PersonalProfile(birth: correct, polarity: .yang),
            calculator: calculator)
        XCTAssertEqual(correctChart.pillars.precision, .exact)
        XCTAssertFalse(correct.timeResolution.isUncertain)
    }

    func testBirthMomentCarriesTheResolutionForwards() {
        let ambiguous = BirthMoment(
            civil: CivilBirthTime(year: 1987, month: 10, day: 11, hour: 2, minute: 30,
                                  timeZoneIdentifier: "Asia/Seoul"),
            location: GeoLocation(latitude: 37.567, longitude: 126.978))
        XCTAssertTrue(ambiguous.timeResolution.isUncertain)
        XCTAssertEqual(ambiguous.instant, ambiguous.timeResolution.instant)

        // And a direct-instant birth is never flagged.
        let direct = BirthMoment(instant: Date(timeIntervalSince1970: 0),
                                 location: GeoLocation(latitude: 0, longitude: 0))
        XCTAssertFalse(direct.timeResolution.isUncertain)
        XCTAssertNil(direct.civil)
    }

    func testAnUnknownZoneStillProducesAUsableInstant() {
        // Degrading to UTC is a choice the interface reports; it must not
        // crash or produce a nonsense date.
        let birth = BirthMoment(
            civil: CivilBirthTime(year: 1990, month: 5, day: 15, hour: 14, minute: 30,
                                  timeZoneIdentifier: "Not/AZone"),
            location: GeoLocation(latitude: 0, longitude: 0))
        XCTAssertEqual(birth.timeResolution, .unknownTimeZone)
        XCTAssertEqual(birth.instant, Fixtures.date("1990-05-15T14:30:00Z"))
    }
}
