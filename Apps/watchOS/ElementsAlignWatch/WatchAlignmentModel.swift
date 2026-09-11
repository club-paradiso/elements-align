import Foundation
import Observation
import ElementsCore
import ElementsProfile
import ElementsSpatial

/// Drives the watch experience.
///
/// The shape of this type is dictated by battery. Heading updates arrive many
/// times a second; solving for solar terms takes hundreds of trigonometric
/// terms. So the two are kept strictly apart:
///
/// * ``PersonalChart`` is built once, when the profile loads.
/// * ``TemporalSnapshot`` is rebuilt only when its `validUntil` passes, which
///   is at most once every two solar hours.
/// * Only the alignment evaluation runs per heading update, and that is
///   arithmetic over values already in memory.
///
/// It is a view model, not a god object: it owns no calculation of its own.
/// Everything it reports comes from ElementsCore.
@MainActor
@Observable
public final class WatchAlignmentModel {

    public private(set) var state: AlignmentState?
    public private(set) var presentationLevel: AlignmentLevel = .neutral
    public private(set) var headingStatus: HeadingStatus = .unavailable(.permissionNotDetermined)
    public private(set) var smoothedHeading: Double?
    public private(set) var chart: PersonalChart?

    /// Set when there is no profile yet: the watch cannot onboard, so it tells
    /// the user to finish setup on iPhone.
    public private(set) var needsProfile = false

    private let calculator = BaZiCalculator()
    private let engine = AlignmentEngine()
    private let haptics: HapticPlaying
    private let provider: HeadingProviding

    private var smoother = HeadingSmoother()
    private var tracker = AlignmentTracker()
    private var temporal: TemporalSnapshot?

    /// Where the user is now, used only for solar time. V1 does not use a
    /// position fix: the birth longitude drives the chart, and the current
    /// longitude only shifts the moment's hour pillar. Falling back to the
    /// birth longitude keeps the product working with no location fix at all.
    private var currentLocation: GeoLocation?

    public init(provider: HeadingProviding,
                haptics: HapticPlaying = WatchHapticPlayer(),
                profileStore: ProfileStore = ProfileStore()) {
        self.provider = provider
        self.haptics = haptics

        if let profile = profileStore.load() {
            self.chart = PersonalChart(profile: profile, calculator: calculator)
        } else {
            self.needsProfile = true
        }

        self.provider.onChange = { [weak self] status in
            Task { @MainActor in self?.handle(status: status) }
        }
    }

    public func start() {
        guard !needsProfile else { return }
        refreshTemporalIfNeeded(now: Date())
        provider.start()
        handle(status: provider.status)
    }

    public func stop() {
        provider.stop()
    }

    /// Feeds a raw sample through the filter and re-evaluates.
    ///
    /// Exposed so tests and previews can drive the whole pipeline without a
    /// sensor.
    public func ingest(sample: HeadingSample) {
        smoother.add(sample)
        smoothedHeading = smoother.smoothedHeading
        evaluate(at: sample.timestamp)
    }

    private func handle(status: HeadingStatus) {
        headingStatus = status
        switch status {
        case let .available(degrees):
            ingest(sample: HeadingSample(degrees: degrees,
                                         accuracyDegrees: 0,
                                         timestamp: Date()))
        case .unavailable:
            smoother.reset()
            smoothedHeading = nil
            evaluate(at: Date())
        }
    }

    private func refreshTemporalIfNeeded(now: Date) {
        guard let chart else { return }
        if let temporal, temporal.isValid(at: now) { return }
        let location = currentLocation ?? chart.profile.birth.location
        temporal = TemporalSnapshot(instant: now,
                                    location: location,
                                    calculator: calculator,
                                    options: chart.profile.options)
    }

    private func evaluate(at date: Date) {
        guard let chart else { return }
        refreshTemporalIfNeeded(now: date)
        guard let temporal else { return }

        let evaluated = engine.evaluate(AlignmentContext(chart: chart,
                                                         temporal: temporal,
                                                         heading: smoothedHeading))
        state = evaluated

        if let transition = tracker.update(score: evaluated.score, at: date) {
            presentationLevel = transition.to
            if let cue = tracker.cue(for: transition) {
                haptics.play(cue)
            }
        }
    }

    /// Updates the location used for solar time. Optional: the product works
    /// without it.
    public func update(location: GeoLocation) {
        currentLocation = location
        temporal = nil
        evaluate(at: Date())
    }
}
