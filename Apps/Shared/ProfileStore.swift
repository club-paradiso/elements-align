import Foundation
import ElementsCore

/// Persists the user's profile.
///
/// Birth data is the most sensitive thing this product holds, so it is stored
/// locally and nowhere else. There is no account, no sync service and no
/// analytics event carrying any of it. The stored form is the small set of
/// values the engine needs, not a richer record kept "in case".
public final class ProfileStore {
    private enum Key {
        static let profile = "elements.profile.v1"
    }

    /// The stored shape. Deliberately separate from ``PersonalProfile`` so the
    /// on-disk format can change independently of the domain model.
    private struct Stored: Codable {
        var birthInstant: Date
        var latitude: Double
        var longitude: Double
        var precision: String
        var polarity: String
        var lateZiPolicy: String
        var usesEquationOfTime: Bool
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> PersonalProfile? {
        guard let data = defaults.data(forKey: Key.profile),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            return nil
        }
        return PersonalProfile(
            birth: BirthMoment(
                instant: stored.birthInstant,
                location: GeoLocation(latitude: stored.latitude, longitude: stored.longitude),
                precision: ChartPrecision(rawValue: stored.precision) ?? .exact),
            polarity: stored.polarity == "yin" ? .yin : .yang,
            options: BaZiOptions(
                lateZiPolicy: LateZiPolicy(rawValue: stored.lateZiPolicy) ?? .dayChangesAt23,
                usesEquationOfTime: stored.usesEquationOfTime))
    }

    public func save(_ profile: PersonalProfile) {
        let stored = Stored(
            birthInstant: profile.birth.instant,
            latitude: profile.birth.location.latitude,
            longitude: profile.birth.location.longitude,
            precision: profile.birth.precision.rawValue,
            polarity: profile.polarity.identifier,
            lateZiPolicy: profile.options.lateZiPolicy.rawValue,
            usesEquationOfTime: profile.options.usesEquationOfTime)
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: Key.profile)
        }
    }

    /// Removes everything. Offered in Settings so deletion is a real action the
    /// user can take, not a request they have to make of someone.
    public func clear() {
        defaults.removeObject(forKey: Key.profile)
    }
}
