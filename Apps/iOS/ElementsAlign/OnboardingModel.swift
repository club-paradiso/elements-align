import Foundation
import Observation
import ElementsCore

/// State for the onboarding flow.
///
/// Onboarding collects the four things the engine cannot work without — a
/// date, a time or an explicit statement that it is unknown, a place, and the
/// polarity Eight Mansions requires — and nothing else. No email, no account,
/// no optional profile fields collected "for later".
@MainActor
@Observable
public final class OnboardingModel {

    public enum Step: Int, CaseIterable {
        case welcome, birthDate, birthTime, birthPlace, polarity, permissions, summary
    }

    public var step: Step = .welcome
    public var birthDate = Calendar(identifier: .gregorian)
        .date(from: DateComponents(year: 1990, month: 1, day: 1)) ?? Date()
    public var birthTime = Calendar(identifier: .gregorian)
        .date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 12)) ?? Date()
    public var birthTimeIsKnown = true
    public var place: BirthPlace? = BirthPlace.table.first
    public var manualLongitude: Double?
    public var polarity: Polarity = .yang

    private let store: ProfileStore
    private let calculator = BaZiCalculator()

    public init(store: ProfileStore = ProfileStore()) {
        self.store = store
    }

    public var longitude: Double {
        manualLongitude ?? place?.location.longitude ?? 0
    }

    public var location: GeoLocation {
        if let manualLongitude {
            return GeoLocation(latitude: 0, longitude: manualLongitude)
        }
        return place?.location ?? GeoLocation(latitude: 0, longitude: 0)
    }

    /// Combines the date and time the user chose into a single instant.
    ///
    /// The pickers are interpreted in the device's current time zone. That is
    /// an approximation for someone born in a different zone from the one they
    /// live in now, and a known V1 limitation recorded in the roadmap: the
    /// right fix is to resolve the historical zone for the birth place and
    /// date, including the era's daylight-saving rules.
    public var birthInstant: Date {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.dateComponents([.year, .month, .day], from: birthDate)
        let time = birthTimeIsKnown
            ? calendar.dateComponents([.hour, .minute], from: birthTime)
            : DateComponents(hour: 12, minute: 0)

        var combined = DateComponents()
        combined.year = day.year
        combined.month = day.month
        combined.day = day.day
        combined.hour = time.hour
        combined.minute = time.minute
        return calendar.date(from: combined) ?? birthDate
    }

    public var profile: PersonalProfile {
        PersonalProfile(
            birth: BirthMoment(instant: birthInstant,
                               location: location,
                               precision: birthTimeIsKnown ? .exact : .dayOnly),
            polarity: polarity)
    }

    /// The chart as it currently stands, so the summary step can show the user
    /// what their answers produced before they commit to them.
    public var previewChart: PersonalChart {
        PersonalChart(profile: profile, calculator: calculator)
    }

    public func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    public func retreat() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    public func finish() {
        store.save(profile)
    }
}
