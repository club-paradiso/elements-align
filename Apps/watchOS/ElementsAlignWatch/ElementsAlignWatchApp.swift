import SwiftUI
import ElementsSpatial

@main
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
