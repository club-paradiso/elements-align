# CLAUDE.md

Repository guidance for Claude Code sessions working on **Elements, Align.**

## What this is

A location-, direction-, time- and person-aware ambient Apple Watch experience
built on East Asian traditional cosmology. Not a horoscope app.

The wearer turns; the composition responds. When person, time and direction
line up, the interface lines up.

Read [Documentation/PRODUCT.md](Documentation/PRODUCT.md) before making product
decisions.

## Start here

Everything compiles. The engine and its 131 tests are green in CI on every
push; both app targets build for the simulators on a macOS runner. **Nothing
has been run** — not in a simulator, not on a watch. Compiling says the types
line up, not that the composition draws or the haptics fire.

This repository was written without a Swift toolchain available. What that cost
and what caught it is recorded in
[Documentation/BUILD_STATUS.md](Documentation/BUILD_STATUS.md); the short
version is that validating the mathematics independently worked completely,
treating a parser as a substitute for a compiler did not, and the SwiftUI
turned out fine because availability was checked against Apple's published
data rather than recalled.

## Commands

```
make test         # swift test on the engine — no Xcode needed, works on Linux
make build        # swift build on the engine
make apple-build  # unsigned simulator build of both app targets (macOS)
make syntax       # tree-sitter parse check of every Swift file (no toolchain)
make fixtures   # regenerate golden test fixtures from the reference oracle
make vsop       # regenerate the truncated VSOP87 Swift tables
make project    # XcodeGen → ElementsAlign.xcodeproj (macOS only)
```

The oracle needs PyMeeus sources; point `PYMEEUS` at an extracted sdist.

## Layout

```
Packages/ElementsAlign/Sources/
  ElementsCore/      deterministic domain logic — Foundation only
  ElementsSpatial/   heading maths + CoreLocation adapter
  ElementsDesign/    design tokens + presentation logic
Apps/{iOS,watchOS,Shared}/
Tools/{oracle,syntaxcheck}/
```

## Non-negotiables

These are not style preferences. Breaking one breaks the product.

1. **ElementsCore imports Foundation and nothing else.** No SwiftUI, no
   CoreLocation, no networking, no display strings. It must keep building and
   testing on Linux — that is what makes the part that has to be correct
   verifiable without a Mac.

2. **The calculation engine never uses an LLM.** Calendar conversion, Four
   Pillars, Five Elements, Eight Mansions and Alignment are deterministic code.
   An LLM may one day *explain* a result. It may never produce one.

3. **No randomness anywhere in the engine.** Same profile, instant and heading
   → same state, always. There is a test asserting this.

4. **The solar-term solver never touches the heading path.** Heading updates
   arrive several times a second; a solve is hundreds of trig terms. Charts are
   built once, `TemporalSnapshot` is rebuilt only when `validUntil` passes, and
   only the alignment evaluation runs per update. Do not "simplify" this away.

5. **Birth data and location never leave the device.** No network calls, no
   analytics, no geocoding service. See
   [Documentation/PRIVACY.md](Documentation/PRIVACY.md) — the offline
   birth-place table exists specifically to keep this true.

6. **Never invent traditional rules.** If a value comes from a tradition, say
   which and cite it. If it is a product decision, label it as one in
   [Documentation/ALIGNMENT_ENGINE.md](Documentation/ALIGNMENT_ENGINE.md).
   "Wood = +20 points" without justification is exactly what this repository
   is built to avoid.

7. **Never claim Alignment measures anything physical.** It is a deterministic
   symbolic score from traditional rules. Not health, not psychology, not
   finance, not safety, not prediction.

8. **No third-party dependencies** without justifying them first. There are
   currently none.

## Verification

Run `make test` before committing. If you cannot — no toolchain — then the bar
is: **check numeric claims against the oracle before committing them.**

`Tools/oracle/` is an independent Python implementation of the same
mathematics, validated against published equinox instants, textbook
equation-of-time landmarks, published sexagenary years, and the classical
Eight Mansions table. The Swift tests assert against fixtures it generates, so
they are a real check rather than a tautology.

This process caught two real bugs and one wrong test before CI existed. If you
add a test with a numeric expectation and cannot run it, compute it through the
oracle first.

A fixture's stored precision must exceed the tolerance the test asserts with,
or the rounding itself fails the test. That has happened once.

`make syntax` is a parse check, not a compiler, and it has missed a real error
before — it now also checks quote balance, because tree-sitter accepts a string
interpolation spanning a newline and Swift does not. Run it, but do not trust
it as proof the code builds. `make test` is the real gate.

## Conventions

- Modern Swift, value types, `Hashable` + `Sendable` by default.
- No business logic in views. No `ObservableObject` god classes. The two
  `@Observable` view models own no calculation of their own.
- No force unwraps without a stated reason. Enum `init?(rawValue:)` calls use
  a defensible fallback.
- No magic numbers. A constant either has a traditional source or is a named
  product decision documented in ALIGNMENT_ENGINE.md.
- Comments explain *why*, not what. Existing comments carry real reasoning —
  match that register rather than adding narration.
- User-facing strings are localisation keys resolved in the UI layer. English
  and Korean both ship.
- `VSOP87Earth.swift` and `golden.json` are **generated**. Regenerate them;
  never hand-edit.

## Deployment targets

iOS 17.0, watchOS 10.0, Swift 5.9. watchOS 10 covers Series 4 and later; the
compass arrived in Series 5, so `headingAvailable()` is the runtime gate that
actually matters.

Apple API availability was checked against Apple's published documentation
data, not from memory. `startUpdatingHeading()`, `headingAvailable()` and
`CLHeading` are all watchOS 2.0+ — the API has never been the constraint, the
hardware is. Do not assert availability from memory; check.

## Current milestone

**Milestone 1 — Directional Alignment Prototype.** Everything compiles;
nothing has been run.

Next, in order:

1. Launch both apps in a simulator and see whether they behave.
2. Run [Documentation/DEVICE_TESTING.md](Documentation/DEVICE_TESTING.md).
3. Widen the birth-place table, or add offline geocoding.

See [Documentation/ROADMAP.md](Documentation/ROADMAP.md).

## Documentation

Keep it synchronised with the code. If you change a constant in the alignment
engine, change ALIGNMENT_ENGINE.md in the same commit. Documentation that
drifts is worse than none, because it is trusted.
