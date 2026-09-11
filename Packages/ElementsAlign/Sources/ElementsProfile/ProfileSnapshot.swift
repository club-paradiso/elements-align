import Foundation
import ElementsCore

public enum ProfileDataError: Error, Equatable {
    case unsupportedVersion
    case invalidProfile
    case invalidSnapshot
}

/// Versioned state, not a queue of edits. iPhone is the only writer; an explicit
/// deletion replaces any pending profile in WatchConnectivity's latest context.
public struct ProfileSnapshot: Codable, Sendable {
    private let version: Int
    private let state: State
    private let record: ProfileRecord?

    private enum State: String, Codable { case profile, deleted }

    public init(profile: PersonalProfile?) throws {
        version = 1
        state = profile == nil ? .deleted : .profile
        record = profile.map(ProfileRecord.init)
        if let record { _ = try record.validatedProfile() }
    }

    public func validatedProfile() throws -> PersonalProfile? {
        guard version == 1 else { throw ProfileDataError.unsupportedVersion }
        switch (state, record) {
        case (.deleted, nil): return nil
        case let (.profile, record?): return try record.validatedProfile()
        default: throw ProfileDataError.invalidSnapshot
        }
    }

    public static func decode(_ data: Data) throws -> ProfileSnapshot {
        // The payload is under 1 KB. Reject unexpectedly large counterpart data
        // before decoding, rather than allocating an unbounded object graph.
        guard data.count <= 16_384 else { throw ProfileDataError.invalidSnapshot }
        let snapshot = try JSONDecoder().decode(Self.self, from: data)
        _ = try snapshot.validatedProfile()
        return snapshot
    }

    public func encoded() throws -> Data {
        _ = try validatedProfile()
        return try JSONEncoder().encode(self)
    }
}

/// Matches the existing v1 disk schema. Never silently turn an unknown precision
/// or policy into an exact/default calculation: damaged data must fail closed.
struct ProfileRecord: Codable, Sendable {
    let birthInstant: Date
    let latitude: Double
    let longitude: Double
    let precision: String
    let polarity: String
    let lateZiPolicy: String
    let usesEquationOfTime: Bool

    init(_ profile: PersonalProfile) {
        birthInstant = profile.birth.instant
        latitude = profile.birth.location.latitude
        longitude = profile.birth.location.longitude
        precision = profile.birth.precision.rawValue
        polarity = profile.polarity.identifier
        lateZiPolicy = profile.options.lateZiPolicy.rawValue
        usesEquationOfTime = profile.options.usesEquationOfTime
    }

    func validatedProfile() throws -> PersonalProfile {
        // UTC 1900-01-01 inclusive through 2101-01-01 exclusive: the
        // astronomical model's validated range. Check before any Double→Int.
        let supportedInstants = -2_208_988_800.0..<4_133_980_800.0
        guard birthInstant.timeIntervalSinceReferenceDate.isFinite,
              supportedInstants.contains(birthInstant.timeIntervalSince1970),
              latitude.isFinite, (-90...90).contains(latitude),
              longitude.isFinite, (-180...180).contains(longitude),
              let precision = ChartPrecision(rawValue: precision),
              let policy = LateZiPolicy(rawValue: lateZiPolicy),
              polarity == "yin" || polarity == "yang" else {
            throw ProfileDataError.invalidProfile
        }
        return PersonalProfile(
            birth: BirthMoment(instant: birthInstant,
                               location: GeoLocation(latitude: latitude, longitude: longitude),
                               precision: precision),
            polarity: polarity == "yin" ? .yin : .yang,
            options: BaZiOptions(lateZiPolicy: policy, usesEquationOfTime: usesEquationOfTime))
    }
}
