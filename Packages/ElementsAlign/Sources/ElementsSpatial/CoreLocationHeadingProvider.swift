import Foundation
import ElementsCore

#if canImport(CoreLocation)
import CoreLocation

/// Core Location backed compass.
///
/// Platform notes, verified against Apple's published availability data rather
/// than assumed:
///
/// * `startUpdatingHeading()`, `headingAvailable()` and `CLHeading` are all
///   available on watchOS 2.0 and later. The API has never been the constraint.
/// * The *hardware* is. Apple Watch gained a magnetometer in Series 5, so
///   `headingAvailable()` is the runtime gate that actually matters and is
///   checked before starting.
/// * Heading requires location authorisation even though it is not a position
///   fix, so the app must carry NSLocationWhenInUseUsageDescription.
/// * `trueHeading` is only valid while location updates are also running, and
///   is reported as a negative value otherwise. `magneticHeading` needs no
///   position fix, which is one reason it is the default here; the other is
///   that a luopan reads magnetic north.
/// * The watchOS simulator does not synthesise heading. This class reports
///   `.unsupportedEnvironment` there rather than appearing to work, so the
///   simulator falls back to `SimulatedHeadingProvider`.
///
/// Sensor behaviour on real hardware has NOT been validated by the author of
/// this file; see Documentation/DEVICE_TESTING.md for the checklist that must
/// be run on a paired Apple Watch before any claim about it is made.
public final class CoreLocationHeadingProvider: NSObject, HeadingProviding {

    /// Minimum change in degrees before Core Location delivers an update.
    ///
    /// Not the default of 1 degree: at 1 degree a resting wrist generates a
    /// continuous stream of updates that wakes the app for no visible benefit.
    /// Two degrees is below the smoother's noise floor and roughly halves the
    /// wake rate.
    public static let headingFilterDegrees: CLLocationDegrees = 2.0

    private let manager: CLLocationManager
    private let reference: HeadingReference

    public private(set) var status: HeadingStatus {
        didSet {
            guard status != oldValue else { return }
            onChange?(status)
        }
    }

    public var onChange: ((HeadingStatus) -> Void)?

    /// Must be constructed on the main thread: `CLLocationManager` delivers
    /// its callbacks on the run loop it was created on.
    public init(reference: HeadingReference = .magnetic) {
        self.manager = CLLocationManager()
        self.reference = reference
        self.status = .unavailable(.permissionNotDetermined)
        super.init()
        manager.delegate = self
        manager.headingFilter = Self.headingFilterDegrees
    }

    public func start() {
        #if targetEnvironment(simulator)
        // The simulator reports headingAvailable() inconsistently and never
        // delivers a reading on watchOS. Failing loudly here is better than a
        // display that sits at zero and looks like a bug in the engine.
        status = .unavailable(.unsupportedEnvironment)
        return
        #else
        guard CLLocationManager.headingAvailable() else {
            status = .unavailable(.noHardware)
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            status = .unavailable(.permissionNotDetermined)
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = .unavailable(.permissionDenied)
        default:
            beginUpdates()
        }
        #endif
    }

    public func stop() {
        manager.stopUpdatingHeading()
        if reference == .trueNorth {
            manager.stopUpdatingLocation()
        }
    }

    private func beginUpdates() {
        if case .unavailable(.calibrating) = status {} else {
            status = .unavailable(.calibrating)
        }
        // True north is derived from magnetic north plus local declination,
        // which Core Location can only supply once it knows where it is.
        if reference == .trueNorth {
            manager.startUpdatingLocation()
        }
        manager.startUpdatingHeading()
    }
}

extension CoreLocationHeadingProvider: CLLocationManagerDelegate {

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        case .denied, .restricted:
            status = .unavailable(.permissionDenied)
        case .notDetermined:
            status = .unavailable(.permissionNotDetermined)
        @unknown default:
            status = .unavailable(.permissionNotDetermined)
        }
    }

    public func locationManager(_ manager: CLLocationManager,
                                didUpdateHeading newHeading: CLHeading) {
        let raw = reference == .trueNorth ? newHeading.trueHeading : newHeading.magneticHeading
        // Core Location signals an unusable reading with a negative accuracy,
        // and an unresolved trueHeading with a negative heading.
        guard newHeading.headingAccuracy >= 0, raw >= 0 else {
            status = .unavailable(.calibrating)
            return
        }
        status = .available(Angle.normalizedDegrees(raw))
    }

    public func locationManager(_ manager: CLLocationManager,
                                didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .denied {
            status = .unavailable(.permissionDenied)
        } else {
            status = .unavailable(.calibrating)
        }
    }
}
#endif
