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

    // The wall-clock reading and the zone it was read in. Optional because
    // records written before these existed carry only the instant, and those
    // must keep loading. When present they take precedence: re-resolving means
    // a profile picks up tz database corrections, where a frozen instant would
    // keep an answer that is now known to be wrong.
    let birthYear: Int?
    let birthMonth: Int?
    let birthDay: Int?
    let birthHour: Int?
    let birthMinute: Int?
    let birthTimeZone: String?

    init(_ profile: PersonalProfile) {
        birthInstant = profile.birth.instant
        latitude = profile.birth.location.latitude
        longitude = profile.birth.location.longitude
        precision = profile.birth.precision.rawValue
        polarity = profile.polarity.identifier
        lateZiPolicy = profile.options.lateZiPolicy.rawValue
        usesEquationOfTime = profile.options.usesEquationOfTime
        birthYear = profile.birth.civil?.year
        birthMonth = profile.birth.civil?.month
        birthDay = profile.birth.civil?.day
        birthHour = profile.birth.civil?.hour
        birthMinute = profile.birth.civil?.minute
        birthTimeZone = profile.birth.civil?.timeZoneIdentifier
    }

    /// The stored wall-clock reading, or nil when the record predates it.
    ///
    /// A record carrying *some* civil fields, or an unresolvable zone, is
    /// damaged rather than old, and is rejected by ``validatedProfile()``
    /// rather than quietly falling back to the instant: silently reverting to
    /// a less accurate reading is exactly the kind of failure this schema
    /// refuses elsewhere.
    private var civilFields: (CivilBirthTime?, isDamaged: Bool) {
        let present = [birthYear, birthMonth, birthDay, birthHour, birthMinute]
            .compactMap { $0 }.count
        switch (present, birthTimeZone) {
        case (0, nil):
            return (nil, false)
        case let (5, identifier?):
            guard let year = birthYear, let month = birthMonth, let day = birthDay,
                  let hour = birthHour, let minute = birthMinute,
                  (1...12).contains(month), (1...31).contains(day),
                  (0...23).contains(hour), (0...59).contains(minute),
                  TimeZone(identifier: identifier) != nil else {
                return (nil, true)
            }
            return (CivilBirthTime(year: year, month: month, day: day,
                                   hour: hour, minute: minute,
                                   timeZoneIdentifier: identifier), false)
        default:
            return (nil, true)
        }
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
        let (civil, isDamaged) = civilFields
        guard !isDamaged else { throw ProfileDataError.invalidProfile }

        let location = GeoLocation(latitude: latitude, longitude: longitude)
        // Prefer the wall-clock reading, which re-resolves through the current
        // tz database; fall back to the instant for records written before it.
        let birth = civil.map {
            BirthMoment(civil: $0, location: location, precision: precision)
        } ?? BirthMoment(instant: birthInstant, location: location, precision: precision)

        return PersonalProfile(
            birth: birth,
            polarity: polarity == "yin" ? .yin : .yang,
            options: BaZiOptions(lateZiPolicy: policy, usesEquationOfTime: usesEquationOfTime))
    }
}
