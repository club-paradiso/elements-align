# Architecture

## Shape

```
elements-align/
├── Packages/ElementsAlign/          one Swift package, three modules
│   ├── Sources/
│   │   ├── ElementsCore/            deterministic domain logic
│   │   │   ├── Calendar/            Julian day, Delta-T, VSOP87, solar terms
│   │   │   ├── BaZi/                stems, branches, pillars, calculator
│   │   │   ├── FiveElements/        elements, distributions
│   │   │   ├── BaZhai/              trigrams, life gua, directional profile
│   │   │   ├── Temporal/            moment snapshot
│   │   │   ├── Alignment/           engine, levels, tracker
│   │   │   ├── Profile/             profile, chart
│   │   │   └── Geometry/            angle arithmetic
│   │   ├── ElementsSpatial/         heading maths + sensor adapters
│   │   └── ElementsDesign/          tokens + presentation logic
│   └── Tests/                       104 tests, golden fixtures
├── Apps/
│   ├── iOS/                         onboarding, profile, settings, debug
│   ├── watchOS/                     the ambient experience
│   └── Shared/                      profile store, places, localisation
├── Tools/
│   ├── oracle/                      Python reference implementation
│   └── syntaxcheck/                 tree-sitter parse check
├── Documentation/
├── project.yml                      XcodeGen spec
└── Makefile
```

## The one rule

**Computation never touches presentation.**

`ElementsCore` imports Foundation and nothing else. No SwiftUI, no
CoreLocation, no WatchKit, no networking. It holds no display strings — it
emits localisation keys and the UI resolves them. It can be built and tested
on Linux, which is not incidental: it means the part of this product that has
to be correct is verifiable anywhere, without a Mac.

Everything above it is a thin layer that reads values and draws them.

## Why one package, three modules

The product tree lists ElementsCore, ElementsSpatial and ElementsDesign as
separate concerns, and they are separate *modules*. They are not separate
packages: the app targets add one local dependency instead of three, and the
three always move in lockstep. The boundary that matters — ElementsCore
depending on nothing — is enforced by the manifest either way.

## Cross-platform by construction

Platform code is gated, not segregated:

| Module | Cross-platform part | Gated part |
| --- | --- | --- |
| ElementsCore | all of it | — |
| ElementsSpatial | heading maths, smoother, protocols | `#if canImport(CoreLocation)` |
| ElementsDesign | tokens as data, presentation logic | `#if canImport(SwiftUI)` |

This is why the smoothing filter, the hysteresis tracker, the colour contrast
ratios and the scatter/convergence behaviour all have real tests: none of them
needs a device or a simulator to run.

## The performance boundary

This is the single most load-bearing structural decision.

Heading updates arrive several times a second. Solving for a solar term takes
roughly 175 trigonometric terms per Newton iteration, several iterations per
solve, and up to 36 solves to determine a month pillar. Those two facts must
never meet.

```
PersonalChart       built once, when the profile loads
TemporalSnapshot    rebuilt only when validUntil passes  (≤ every 2 solar hours)
AlignmentEngine     runs per heading update              (arithmetic only)
```

`TemporalSnapshot.validUntil` is what makes the third line cheap: it names the
instant the hour pillar next changes, so callers recompute exactly then and not
one moment sooner. `SolarTermCalculator` additionally memoises, behind a lock.

## Dependency injection where it earns its place

`HeadingProviding` exists because the watchOS simulator never synthesises a
heading. Without the protocol the entire central interaction would be
untestable off-device. `SimulatedHeadingProvider` is driven explicitly — it
does not pretend to be a sensor.

`HapticPlaying` exists so the *decision* to play something stays in
ElementsCore, where it can be reasoned about and tested, separate from what it
feels like. `RecordingHapticPlayer` records instead of playing.

`SolarTermCalculator` is injected into `BaZiCalculator` so a test can supply a
pre-warmed cache.

## Value types

Nearly everything is a `struct`, `Hashable` and `Sendable`. The exceptions are
deliberate: `SolarTermCalculator` (a memoising cache), the heading providers
(they wrap delegate callbacks), and the two `@Observable` view models.

There is no `ObservableObject` carrying business logic. The view models own no
calculation of their own; everything they report comes from ElementsCore.

## Extension points

The architecture anticipates one specific V2 system without implementing it.

**Xuan Kong Flying Stars** needs a time-varying spatial layer over the same
compass sectors. `AlignmentEngine.spatialComponent` already takes a
`BaZhaiProfile` as a parameter rather than reaching for one, so introducing a
`DirectionalScoring` protocol with Eight Mansions as one conformer is a local
change, not a rewrite.

**Room and seat scoring** is the long-term product goal: candidate seats each
receive a symbolic score and the watch guides the wearer toward one.
`GeoLocation` already carries latitude, unused by V1, for this reason. V1
deliberately does not depend on indoor positioning — GPS is nowhere near
accurate enough for chair-level placement and the product does not pretend
otherwise.

## Generated code

Two files are generated and marked as such:

- `VSOP87Earth.swift` — from PyMeeus's VSOP87 tables via
  `Tools/oracle/gen_vsop87.py`. Machine extraction means no transcription
  errors, and the truncation error is measured before the file is written.
- `golden.json` — test fixtures from the validated oracle.

`ElementsAlign.xcodeproj` is generated from `project.yml` and not committed;
see [BUILD_STATUS.md](BUILD_STATUS.md) for why.

## What is deliberately absent

No backend. No account system. No analytics SDK. No third-party dependencies
of any kind — every line is Foundation, SwiftUI, CoreLocation or WatchKit. No
generative AI in the calculation path, and none required for V1 at all.
