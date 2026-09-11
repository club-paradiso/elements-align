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
