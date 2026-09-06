import Foundation
import XCTest

/// Golden fixtures produced by Tools/oracle.
///
/// These are not the engine's own output recorded back as expectations. They
/// come from an independent Python implementation whose astronomy was checked
/// against published equinox and solstice instants and equation-of-time
/// landmarks, whose sexagenary years were checked against published zodiac
/// years, and whose Eight Mansions derivation was checked against the classical
/// table. Asserting against them is therefore a real test of this
/// implementation, not a tautology.
enum Fixtures {

    struct Root: Decodable {
        let solarTerms: [SolarTermCase]
        let deltaT: [DeltaTCase]
        let equationOfTime: [EquationOfTimeCase]
        let yearPillars: [YearPillarCase]
        let dayPillars: [DayPillarCase]
        let fourPillars: [FourPillarsCase]
        let lifeGua: [LifeGuaCase]
        let baZhai: [BaZhaiCase]
        let angular: [AngularCase]
        let directionalValue: [DirectionalValueCase]
        let alignmentProfile: AlignmentProfileCase
        let alignmentSweep: [AlignmentSweepCase]
    }

    struct SolarTermCase: Decodable {
        let year: Int, index: Int, name: String, longitude: Double, utc: String
    }
    struct DeltaTCase: Decodable {
        let year: Int, month: Int, seconds: Double
    }
    struct EquationOfTimeCase: Decodable {
        let utc: String, minutes: Double
    }
    struct YearPillarCase: Decodable {
        let baziYear: Int, stem: Int, branch: Int, name: String
    }
    struct DayPillarCase: Decodable {
        let date: String, jdn: Int, stem: Int, branch: Int, name: String
    }
    struct FourPillarsCase: Decodable {
        let label: String, utc: String, longitude: Double, lateZiPolicy: String
        let year: [Int], month: [Int], day: [Int], hour: [Int]
        let solarHour: Double, boundaryProximityMinutes: Double
    }
    struct LifeGuaCase: Decodable {
        let baziYear: Int, polarity: String, gua: Int
    }
    struct BaZhaiCase: Decodable {
        struct Sector: Decodable { let degrees: Double, relation: String, weight: Double }
        let gua: Int, eastGroup: Bool, sectors: [Sector]
    }
    struct AngularCase: Decodable {
        let a: Double, b: Double, signed: Double, distance: Double
    }
    struct DirectionalValueCase: Decodable {
        let gua: Int, heading: Double, value: Double
    }
    struct AlignmentProfileCase: Decodable {
        let natalUTC: String, nowUTC: String, longitude: Double
        let polarity: String, gua: Int
        let dayMaster: String, dayMasterStrength: Double
        let favourableElements: [String], natalBalance: Double
        let natalDistribution: [String: Double]
        let natalPillars: [String: [Int]]
        let nowPillars: [String: [Int]]
    }
    struct AlignmentSweepCase: Decodable {
        let heading: Double, score: Double, level: String
        let spatial: Double, temporal: Double, personal: Double
    }

    static let root: Root = {
        guard let url = Bundle.module.url(forResource: "golden",
                                          withExtension: "json",
                                          subdirectory: "Fixtures") else {
            fatalError("golden.json missing from the test bundle")
        }
        do {
            return try JSONDecoder().decode(Root.self, from: Data(contentsOf: url))
        } catch {
            fatalError("golden.json could not be decoded: \(error)")
        }
    }()

    /// Parses the fixture's ISO-8601 UTC timestamps.
    static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let parsed = formatter.date(from: iso) else {
            fatalError("unparseable fixture timestamp: \(iso)")
        }
        return parsed
    }
}
