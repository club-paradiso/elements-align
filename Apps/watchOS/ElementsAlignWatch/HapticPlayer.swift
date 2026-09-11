import Foundation
import ElementsCore

#if canImport(WatchKit)
import WatchKit
#endif

/// Plays a haptic cue.
///
/// A protocol so the model can be tested without a device, and so that the
/// decision of *whether* to play something stays in ElementsCore where it can
/// be reasoned about, separate from what it feels like.
public protocol HapticPlaying: AnyObject {
    func play(_ cue: HapticCue)
}

/// Maps the domain's cues onto watchOS haptics.
public final class WatchHapticPlayer: HapticPlaying {
    public init() {}

    public func play(_ cue: HapticCue) {
        #if canImport(WatchKit)
        switch cue {
        case .subtle:
            // The lightest thing watchOS offers.
            WKInterfaceDevice.current().play(.click)
        case .affirm:
            // Reads as movement in a direction rather than as a notification,
            // which is what "the composition is coming together" should feel
            // like.
            WKInterfaceDevice.current().play(.directionUp)
        case .aligned:
            // The one distinct moment in the product.
            WKInterfaceDevice.current().play(.success)
        }
        #endif
    }
}

/// Records cues instead of playing them.
public final class RecordingHapticPlayer: HapticPlaying {
    public private(set) var played: [HapticCue] = []
    public init() {}
    public func play(_ cue: HapticCue) { played.append(cue) }
}
