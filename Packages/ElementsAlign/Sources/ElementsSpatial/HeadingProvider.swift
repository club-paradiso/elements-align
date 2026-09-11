import Foundation
import ElementsCore

/// Why a heading is not available.
public enum HeadingUnavailableReason: String, Hashable, Sendable {
    /// The device has no compass. Apple Watch gained one in Series 5, so this
    /// is a real case on supported hardware, not a theoretical one.
    case noHardware
    /// The user declined location access, which heading requires.
    case permissionDenied
    /// Permission has not been requested yet.
    case permissionNotDetermined
    /// Hardware is present and permitted but has not produced a usable reading
    /// yet, or is reporting interference.
    case calibrating
    /// Running somewhere that does not synthesise heading, such as the
    /// watchOS simulator.
    case unsupportedEnvironment
}

/// The state of the heading stream.
public enum HeadingStatus: Hashable, Sendable {
    case available(Double)
    case unavailable(HeadingUnavailableReason)

    public var degrees: Double? {
        if case let .available(value) = self { return value }
        return nil
    }
}

/// A source of headings.
///
/// The protocol exists so the watch view model can be driven by a simulated
/// source in tests, in previews and in the simulator, where Core Location
/// produces no heading at all. Without it the entire interaction would be
/// untestable off-device.
public protocol HeadingProviding: AnyObject {
    var status: HeadingStatus { get }
    func start()
    func stop()
    /// Called on the main actor whenever the status changes.
    var onChange: ((HeadingStatus) -> Void)? { get set }
}

/// A deterministic heading source for previews, tests and the simulator.
///
/// It does not pretend to be a sensor. It is driven explicitly, which is what
/// makes it useful for asserting on the interaction.
public final class SimulatedHeadingProvider: HeadingProviding {
    public private(set) var status: HeadingStatus
    public var onChange: ((HeadingStatus) -> Void)?

    public init(initialHeading: Double = 0) {
        self.status = .available(Angle.normalizedDegrees(initialHeading))
    }

    public func start() {}
    public func stop() {}

    public func set(heading: Double) {
        status = .available(Angle.normalizedDegrees(heading))
        onChange?(status)
    }

    public func set(unavailable reason: HeadingUnavailableReason) {
        status = .unavailable(reason)
        onChange?(status)
    }
}
