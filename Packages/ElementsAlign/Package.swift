// swift-tools-version: 5.9
import PackageDescription

// One package, three modules. The product tree in Documentation/ARCHITECTURE.md
// lists ElementsCore / ElementsSpatial / ElementsDesign as separate concerns;
// they are separate *modules* here rather than separate packages so that the
// app targets add a single local dependency and the three always move in
// lockstep. ElementsCore has no dependencies at all, which is what keeps the
// domain layer honest.
let package = Package(
    name: "ElementsAlign",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "ElementsCore", targets: ["ElementsCore"]),
        .library(name: "ElementsSpatial", targets: ["ElementsSpatial"]),
        .library(name: "ElementsDesign", targets: ["ElementsDesign"]),
        .library(name: "ElementsProfile", targets: ["ElementsProfile"]),
    ],
    targets: [
        // Pure deterministic domain logic. Foundation only: no UI, no sensors,
        // no networking, no platform frameworks. Builds and tests on Linux,
        // which is how it is verified in CI.
        .target(name: "ElementsCore"),

        // Validated persistence and paired-device payloads, separate from maths.
        .target(name: "ElementsProfile", dependencies: ["ElementsCore"]),
        .testTarget(name: "ElementsProfileTests", dependencies: ["ElementsProfile", "ElementsCore"]),

        // Heading maths and sensor plumbing. The maths is platform-neutral and
        // tested on Linux; the CoreLocation adapter is compiled only where
        // CoreLocation exists.
        .target(name: "ElementsSpatial", dependencies: ["ElementsCore"]),

        // Design tokens as plain data, plus SwiftUI conveniences compiled only
        // where SwiftUI exists.
        .target(name: "ElementsDesign", dependencies: ["ElementsCore"]),

        .testTarget(
            name: "ElementsCoreTests",
            dependencies: ["ElementsCore"],
            resources: [.copy("Fixtures")]
        ),
        // ElementsCore is listed explicitly even though it arrives
        // transitively: these test files import it directly, and relying on a
        // transitive module being in the import search path is a failure mode
        // that only shows up at build time.
        .testTarget(name: "ElementsSpatialTests",
                    dependencies: ["ElementsSpatial", "ElementsCore"]),
        .testTarget(name: "ElementsDesignTests",
                    dependencies: ["ElementsDesign", "ElementsCore"]),
    ]
)
