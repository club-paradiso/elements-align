import Foundation
import ElementsCore

/// One reading from a compass.
public struct HeadingSample: Hashable, Sendable {
    /// Degrees clockwise from the reference direction, in [0, 360).
    public let degrees: Double

    /// Reported accuracy in degrees. Core Location uses a negative value to
    /// mean the reading is invalid, and that convention is preserved here so
    /// adapters do not have to invent a separate flag.
    public let accuracyDegrees: Double

    public let timestamp: Date

    public init(degrees: Double, accuracyDegrees: Double, timestamp: Date) {
        self.degrees = Angle.normalizedDegrees(degrees)
        self.accuracyDegrees = accuracyDegrees
        self.timestamp = timestamp
    }

    public var isValid: Bool { accuracyDegrees >= 0 }
}

/// Which north a heading is measured from.
public enum HeadingReference: String, CaseIterable, Hashable, Sendable {
    /// Magnetic north. The default, because a luopan measures magnetic north
    /// and Eight Mansions sectors are traditionally read off one. Also the
    /// reading that is always available, since true north additionally
    /// requires a location fix.
    case magnetic
    /// True north. Requires location services to resolve declination.
    case trueNorth
}
