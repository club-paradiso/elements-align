import Foundation
import ElementsCore

/// Turns an alignment state into the numbers the view draws.
///
/// This is deliberately not inside a View. It is pure, so the visual behaviour
/// the product is built around — elements scattering at low states and
/// converging at high ones — can be asserted in tests instead of being
/// verified by squinting at a simulator.
public struct AlignmentPresentation: Hashable, Sendable {

    /// 0 when the composition is fully dispersed, 1 when fully converged.
    public let convergence: Double

    /// How far each node sits from its orbital position, as a fraction of the
    /// orbit radius.
    public let scatter: Double

    /// Opacity of the connecting geometry between nodes. The relationships
    /// between elements only become visible as things come together.
    public let linkOpacity: Double

    /// Whether the brand moment is earned. Reserved for full alignment, and
    /// nothing else in the product is allowed to use it.
    public let showsBrandConvergence: Bool

    public init(state: AlignmentState) {
        // Convergence is driven by the continuous score rather than the
        // discrete level, so the composition responds while the wearer turns
        // instead of snapping only when a threshold is crossed.
        let normalized = Angle.clamp01(
            (state.score - AlignmentLevel.neutral.lowerBound)
            / (100.0 - AlignmentLevel.neutral.lowerBound))
        self.convergence = normalized
        self.scatter = Layout.maximumScatter * (1.0 - normalized)
        self.linkOpacity = Angle.clamp01((normalized - 0.35) / 0.5)
        self.showsBrandConvergence = state.level == .aligned
    }

    /// Angular position of an element node.
    ///
    /// Nodes sit on a ring that is anchored to the compass, so the composition
    /// is fixed to the world rather than to the watch: turning the wrist moves
    /// the ring past the wearer, which is what makes the interface feel spatial
    /// rather than animated.
    public static func nodeAngle(index: Int,
                                 count: Int,
                                 heading: Double,
                                 convergence: Double) -> Double {
        guard count > 0 else { return 0 }
        let spread = 360.0 / Double(count)
        let base = Double(index) * spread
        // As things converge the nodes draw together towards the top of the
        // ring instead of staying evenly spaced.
        let gathered = base * (1.0 - convergence * 0.55)
        return Angle.normalizedDegrees(gathered - heading)
    }
}
