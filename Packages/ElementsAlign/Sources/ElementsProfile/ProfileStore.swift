import Foundation
import ElementsCore

/// Local storage shared by the two applications' code, NOT shared UserDefaults
/// containers. WatchConnectivity explicitly copies validated state to the Watch.
/// App callers serialize writes on the main actor. There is no server/cloud API.
public final class ProfileStore {
    public static let didChange = Notification.Name("elements.profile.changed")
    private static let key = "elements.profile.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> PersonalProfile? {
        guard let data = defaults.data(forKey: Self.key),
              let record = try? JSONDecoder().decode(ProfileRecord.self, from: data) else {
            return nil
        }
        return try? record.validatedProfile()
    }

    @discardableResult
    public func save(_ profile: PersonalProfile) -> Bool {
        let record = ProfileRecord(profile)
        guard (try? record.validatedProfile()) != nil,
              let data = try? JSONEncoder().encode(record) else { return false }
        guard load() != profile else { return true }
        defaults.set(data, forKey: Self.key)
        NotificationCenter.default.post(name: Self.didChange, object: self)
        return true
    }

    public func clear() {
        guard defaults.object(forKey: Self.key) != nil else { return }
        defaults.removeObject(forKey: Self.key)
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    /// Invalid or newer schemas leave the existing profile untouched; an absent
    /// field is never interpreted as a request to delete sensitive data.
    public func apply(_ snapshot: ProfileSnapshot) throws {
        if let profile = try snapshot.validatedProfile() {
            guard save(profile) else { throw ProfileDataError.invalidProfile }
        } else {
            clear()
        }
    }

    public func snapshotData() throws -> Data {
        try ProfileSnapshot(profile: load()).encoded()
    }
}
