import Foundation
import XCTest
import ElementsCore
@testable import ElementsProfile

final class ProfileTests: XCTestCase {
    private func profile(precision: ChartPrecision = .exact,
                         longitude: Double = 126.978) -> PersonalProfile {
        PersonalProfile(birth: BirthMoment(
            instant: Date(timeIntervalSince1970: 631_195_200),
            location: GeoLocation(latitude: 37.566, longitude: longitude),
            precision: precision), polarity: .yin,
            options: BaZiOptions(lateZiPolicy: .dayChangesAtMidnight, usesEquationOfTime: false))
    }

    private func withStore(_ test: (ProfileStore, UserDefaults) throws -> Void) throws {
        let name = "elements-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try test(ProfileStore(defaults: defaults), defaults)
    }

    /// A profile whose birth is a wall-clock reading rather than a bare
    /// instant. 1955 Seoul is the case that matters: Korea ran on UTC+8:30 at
    /// the time, so an instant frozen against modern KST would be half an hour
    /// out.
    private func civilProfile(
        year: Int = 1955, month: Int = 6, day: Int = 15,
        hour: Int = 9, minute: Int = 0,
        zone: String = "Asia/Seoul"
    ) -> PersonalProfile {
        PersonalProfile(birth: BirthMoment(
            civil: CivilBirthTime(year: year, month: month, day: day,
                                  hour: hour, minute: minute,
                                  timeZoneIdentifier: zone),
            location: GeoLocation(latitude: 37.566, longitude: 126.978),
            precision: .exact), polarity: .yin)
    }

    func testWallClockReadingSurvivesARoundTrip() throws {
        try withStore { store, _ in
            let original = civilProfile()
            XCTAssertTrue(store.save(original))
            let loaded = try XCTUnwrap(store.load())
            XCTAssertEqual(loaded, original)
            XCTAssertEqual(loaded.birth.civil?.timeZoneIdentifier, "Asia/Seoul")
            XCTAssertEqual(loaded.birth.civil?.year, 1955)
            // Re-resolved, not read back from a frozen instant.
            XCTAssertEqual(loaded.birth.civil?.utcOffsetSeconds(), 9 * 3600 + 1800)
        }
    }

    func testALoadedReadingIsResolvedRatherThanReplayed() throws {
        // The stored instant is what the reading resolved to when saved. On
        // load the reading is resolved again, so a tz database correction
        // would change the answer instead of being frozen out.
        try withStore { store, defaults in
            XCTAssertTrue(store.save(civilProfile()))
            let data = try XCTUnwrap(defaults.data(forKey: "elements.profile.v1"))
            var json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: data) as? [String: Any])
            // Corrupt only the cached instant, leaving the reading intact.
            json["birthInstant"] = 0.0
            defaults.set(try JSONSerialization.data(withJSONObject: json),
                         forKey: "elements.profile.v1")

            let loaded = try XCTUnwrap(store.load())
            XCTAssertEqual(loaded.birth.instant,
                           civilProfile().birth.instant,
                           "the reading should drive the instant, not the cached value")
        }
    }

    func testProfilesWithoutAWallClockReadingStillLoad() throws {
        // Records written before the reading existed carry only the instant.
        try withStore { store, _ in
            let original = profile()
            XCTAssertTrue(store.save(original))
            let loaded = try XCTUnwrap(store.load())
            XCTAssertEqual(loaded, original)
            XCTAssertNil(loaded.birth.civil)
        }
    }

    func testPartialOrUnresolvableReadingsAreRejectedNotDowngraded() throws {
        // Silently reverting to the cached instant would hand back a less
        // accurate chart without saying so. Damaged records fail closed.
        let base = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: try JSONEncoder().encode(ProfileRecord(civilProfile())))
            as? [String: Any])

        var missingZone = base
        missingZone["birthTimeZone"] = nil
        var missingField = base
        missingField["birthMinute"] = nil
        var badZone = base
        badZone["birthTimeZone"] = "Not/AZone"
        var badMonth = base
        badMonth["birthMonth"] = 13

        for (label, json) in [("missing zone", missingZone), ("missing field", missingField),
                              ("unresolvable zone", badZone), ("month 13", badMonth)] {
            let data = try JSONSerialization.data(withJSONObject: json)
            let record = try JSONDecoder().decode(ProfileRecord.self, from: data)
            XCTAssertThrowsError(try record.validatedProfile(), label) { error in
                XCTAssertEqual(error as? ProfileDataError, .invalidProfile, label)
            }
        }
    }

    func testDaylightEdgeReadingsRoundTrip() throws {
        // A reading inside a spring-forward gap, and one inside a fall-back
        // repeat. Both must survive storage with their resolution intact.
        try withStore { store, _ in
            let skipped = civilProfile(year: 1987, month: 5, day: 10, hour: 2, minute: 30)
            XCTAssertTrue(store.save(skipped))
            let loadedSkipped = try XCTUnwrap(store.load())
            if case .skipped = loadedSkipped.birth.timeResolution {} else {
                XCTFail("expected a skipped reading, got \(loadedSkipped.birth.timeResolution)")
            }
        }
        try withStore { store, _ in
            let repeated = civilProfile(year: 1987, month: 10, day: 11, hour: 2, minute: 30)
            XCTAssertTrue(store.save(repeated))
            let loadedRepeated = try XCTUnwrap(store.load())
            if case .ambiguous = loadedRepeated.birth.timeResolution {} else {
                XCTFail("expected an ambiguous reading")
            }
        }
    }

    func testSnapshotCarriesTheWallClockReadingToTheWatch() throws {
        let snapshot = try ProfileSnapshot(profile: civilProfile())
        let decoded = try ProfileSnapshot.decode(try snapshot.encoded())
        let delivered = try XCTUnwrap(try decoded.validatedProfile())
        XCTAssertEqual(delivered.birth.civil?.timeZoneIdentifier, "Asia/Seoul")
        XCTAssertEqual(delivered, civilProfile())
    }

    func testRoundTripPreservesAllCalculationInputs() throws {
        for precision in [ChartPrecision.exact, .dayOnly] {
            let original = profile(precision: precision)
            let encoded = try ProfileSnapshot(profile: original).encoded()
            XCTAssertEqual(try ProfileSnapshot.decode(encoded).validatedProfile(), original)
        }
    }

    func testExplicitDeletionRoundTrip() throws {
        let data = try ProfileSnapshot(profile: nil).encoded()
        XCTAssertNil(try ProfileSnapshot.decode(data).validatedProfile())
        XCTAssertLessThan(data.count, 100)
    }

    func testCorruptUnknownAndInconsistentSnapshotsAreRejected() throws {
        for json in ["{}", "{\"version\":2,\"state\":\"deleted\"}",
                     "{\"version\":1,\"state\":\"profile\"}",
                     "{\"version\":1,\"state\":\"unknown\"}"] {
            XCTAssertThrowsError(try ProfileSnapshot.decode(Data(json.utf8)))
        }
        XCTAssertThrowsError(try ProfileSnapshot.decode(Data(repeating: 0, count: 16_385)))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(
            with: ProfileSnapshot(profile: profile()).encoded()) as? [String: Any])
        json["state"] = "deleted"
        XCTAssertThrowsError(try ProfileSnapshot.decode(JSONSerialization.data(withJSONObject: json)))
    }

    func testInvalidCoordinatesAndDatesFailWithoutTrapping() throws {
        for value in [181.0, -181.0, Double.nan, .infinity] {
            XCTAssertThrowsError(try ProfileSnapshot(profile: profile(longitude: value)))
        }
        for time in [Double.nan, .infinity, 1e100, -1e100] {
            let invalid = PersonalProfile(birth: BirthMoment(
                instant: Date(timeIntervalSince1970: time),
                location: GeoLocation(latitude: 0, longitude: 0)), polarity: .yang)
            XCTAssertThrowsError(try ProfileSnapshot(profile: invalid))
        }
    }

    func testUnknownEnumsNeverBecomeExactOrDefault() throws {
        let data = try ProfileSnapshot(profile: profile()).encoded()
        for (key, value) in [("precision", "guess"), ("polarity", "other"), ("lateZiPolicy", "new")] {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            var record = try XCTUnwrap(json["record"] as? [String: Any])
            record[key] = value
            json["record"] = record
            XCTAssertThrowsError(try ProfileSnapshot.decode(JSONSerialization.data(withJSONObject: json)))
        }
    }

    func testLegacyV1StorageStillLoads() throws {
        try withStore { store, defaults in
            defaults.set(try JSONEncoder().encode(ProfileRecord(profile())), forKey: "elements.profile.v1")
            XCTAssertEqual(store.load(), profile())
        }
    }

    func testPhoneWatchSaveReplaceDeleteAndRelaunch() throws {
        try withStore { phone, _ in
            try withStore { watch, watchDefaults in
                XCTAssertTrue(phone.save(profile()))
                try watch.apply(ProfileSnapshot.decode(phone.snapshotData()))
                XCTAssertEqual(watch.load(), phone.load())
                XCTAssertTrue(phone.save(profile(precision: .dayOnly)))
                try watch.apply(ProfileSnapshot.decode(phone.snapshotData()))
                XCTAssertEqual(ProfileStore(defaults: watchDefaults).load(), phone.load())
                phone.clear()
                let deletion = try ProfileSnapshot.decode(phone.snapshotData())
                try watch.apply(deletion)
                try watch.apply(deletion) // Idempotent replay of the latest state.
                XCTAssertNil(ProfileStore(defaults: watchDefaults).load())
                XCTAssertNil(watchDefaults.object(forKey: "elements.profile.v1"))
            }
        }
    }

    func testInvalidSaveDoesNotDestroyExistingProfile() throws {
        try withStore { store, _ in
            XCTAssertTrue(store.save(profile()))
            XCTAssertFalse(store.save(profile(longitude: .infinity)))
            XCTAssertEqual(store.load(), profile())
        }
    }
}
