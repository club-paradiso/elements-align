import Foundation
import Observation
import ElementsCore
import ElementsProfile

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
    /// Zone for a manually entered longitude. A longitude alone cannot resolve
    /// a wall-clock reading: we also have to know whose clocks were being read.
    public var manualTimeZoneIdentifier: String = TimeZone.current.identifier
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

    /// IANA zone the wall-clock reading should be resolved against.
    public var timeZoneIdentifier: String {
        manualLongitude != nil
            ? manualTimeZoneIdentifier
            : (place?.timeZoneIdentifier ?? TimeZone.current.identifier)
    }

    /// The wall-clock reading the user entered, with the zone it belongs to.
    ///
    /// The pickers are read for their calendar fields only. Taking the `Date`
    /// they produce would bake in the *device's* current zone, which is the
    /// bug this replaced: someone born in Seoul in 1955 was on UTC+8:30, and
    /// resolving them against modern KST put their chart half an hour out --
    /// enough to cross an hour-pillar boundary.
    public var civilBirthTime: CivilBirthTime {
        var calendar = Calendar(identifier: .gregorian)
        // Read the pickers in the zone they were displayed in, so the fields
        // come back as the user saw them.
        calendar.timeZone = TimeZone.current
        let day = calendar.dateComponents([.year, .month, .day], from: birthDate)
        let time = birthTimeIsKnown
            ? calendar.dateComponents([.hour, .minute], from: birthTime)
            : DateComponents(hour: 12, minute: 0)

        return CivilBirthTime(year: day.year ?? 1990,
                              month: day.month ?? 1,
                              day: day.day ?? 1,
                              hour: time.hour ?? 12,
                              minute: time.minute ?? 0,
                              timeZoneIdentifier: timeZoneIdentifier)
    }

    public var birthMoment: BirthMoment {
        BirthMoment(civil: civilBirthTime,
                    location: location,
                    precision: birthTimeIsKnown ? .exact : .dayOnly)
    }

    /// How the reading resolved, so the summary can say when it did not
    /// resolve cleanly.
    public var timeResolution: CivilTimeResolution { birthMoment.timeResolution }

    /// The offset actually applied, formatted for display. Worth showing:
    /// "UTC+8:30" is how a user finds out the app knows about 1955.
    public var utcOffsetDescription: String? {
        guard let seconds = civilBirthTime.utcOffsetSeconds() else { return nil }
        let sign = seconds < 0 ? "-" : "+"
        let total = abs(seconds) / 60
        return String(format: "UTC%@%d:%02d", sign, total / 60, total % 60)
    }

    public var profile: PersonalProfile {
        PersonalProfile(birth: birthMoment, polarity: polarity)
    }

    private var cachedChart: (profile: PersonalProfile, chart: PersonalChart)?

    /// The chart as it currently stands, so the summary step can show the user
    /// what their answers produced before they commit to them.
    ///
    /// Cached against the profile it was built from. Building a chart runs the
    /// solar-term solver, and this is read from a SwiftUI body -- without the
    /// cache it would re-solve on every render of the summary step.
    public var previewChart: PersonalChart {
        let current = profile
        if let cachedChart, cachedChart.profile == current {
            return cachedChart.chart
        }
        let chart = PersonalChart(profile: current, calculator: calculator)
        cachedChart = (current, chart)
        return chart
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
