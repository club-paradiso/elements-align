import SwiftUI
import ElementsSpatial

// Explicitly main-actor isolated: the stored `model` is a @MainActor type and
// its initialiser runs in this struct's own init, which would otherwise be
// nonisolated under strict concurrency.
@main
@MainActor
struct ElementsAlignWatchApp: App {
    @State private var model = WatchAlignmentModel(provider: Self.makeProvider())

    var body: some Scene {
        WindowGroup {
            AlignmentView(model: model)
        }
    }

    /// Core Location on device; a driven stand-in in the simulator, which never
    /// synthesises a heading and would otherwise make the product look broken.
    private static func makeProvider() -> HeadingProviding {
        #if targetEnvironment(simulator)
        return SimulatedHeadingProvider(initialHeading: 135)
        #else
        return CoreLocationHeadingProvider(reference: .magnetic)
        #endif
    }
}
