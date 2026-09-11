# Build status

**Short version: the Swift in this repository has never been compiled.**

That is a real limitation and it is stated first because nothing else in this
document is worth reading if it is missed.

## What failed, exactly

The session that authored this repository ran on Linux with no Swift
toolchain, and could not obtain one:

| Attempt | Result |
| --- | --- |
| `swift --version` | not installed |
| `download.swift.org` toolchain tarball | `curl (56) CONNECT tunnel failed, 403` — denied by the environment's egress proxy |
| `swiftly` installer | same host, same denial |
| `apt-get install swift` | the Ubuntu `swift` package is OpenStack Swift, unrelated |
| Docker image `swift:6` | Docker unavailable in the sandbox |
| `xcodebuild` | macOS only |

So `swift build`, `swift test` and `xcodebuild` have **not** been run. No
claim anywhere in this repository should be read as "this compiles".

## What was verified instead

Not being able to compile is not a reason to verify nothing. Three things were
done in its place.

### 1. Every Swift file parses

`Tools/syntaxcheck/check_swift_syntax.py` parses all 49 Swift files with
tree-sitter and reports zero syntax errors. This catches unbalanced braces and
malformed declarations. It does **not** type-check, resolve names, or verify
API availability, so it cannot tell you the code compiles — only that it is
not obviously broken.

    make syntax

One known grammar limitation: tree-sitter rejects a continuation line starting
with `*`, which Swift itself accepts. Rather than suppress the diagnostic, such
expressions are written with the operator at the end of the line.

### 2. The mathematics was validated against external published data

The part of this product that has to be correct is the engine, and the engine
was checked independently of Swift. `Tools/oracle/` is a second implementation
in Python, and it was validated against sources outside this project:

| Claim | Checked against | Result |
| --- | --- | --- |
| Apparent solar longitude | Untruncated VSOP87 via PyMeeus, 1900–2100 | worst case 0.395″ (~9.6 s of solar-term timing) |
| Solar terms | Published 2026 and 2000 equinox/solstice instants | within ~1 minute |
| Equation of time | Textbook annual landmarks | −14.17 Feb, +3.67 May, −6.56 Jul, +16.45 Nov, zero in Apr and Dec |
| Year pillars | Published sexagenary years (1984 甲子, 2024 甲辰, 2025 乙巳, 2026 丙午) | exact |
| Day pillar congruence | Two independent published statements; 2000-01-07 = 甲子 | exact, with 60-day periodicity |
| Eight Mansions derivation | The classical 坎 row, all eight directions | exact |
| Relation symmetry | Structural property of the system | 0 asymmetric pairs across all 8 gua |
| Life gua congruence | Per-century classical rules, 1900–2060, both polarities | 0 mismatches |

The golden fixtures the Swift tests assert against come from this validated
oracle, so those tests are a genuine check of the Swift and not a tautology.
Several tests additionally assert against the external values directly, so a
shared mistake in both implementations would still be caught.

### 3. Every numeric assertion was pre-checked

Because the tests cannot be run here, each numeric expectation in them was
computed through the oracle before being committed. That process found two
real bugs, both now fixed:

- `dayOnly` charts computed solar noon as `floor(jd) + 0.5`, which is
  *midnight* — a Julian Day begins at noon, so the integer Julian Day already
  is noon. Any afternoon input rolled into the following day.
- The alignment ramp's `low` colour failed 3:1 contrast on the watch
  background, and the light ramp was not monotonic in lightness.

It also found one wrong *test*: the first version of the `dayOnly` stability
test sampled a UTC day rather than a solar day, which at Seoul's longitude are
about eight and a half hours apart.

## What has to happen next

On any machine with a Swift toolchain:

    make test          # engine + tests, no Xcode needed
    make syntax        # parse check

On macOS with Xcode, for the apps:

    brew install xcodegen
    make project
    open ElementsAlign.xcodeproj

**Expect compile errors on the first run.** Roughly 3,000 lines of Swift
written without a compiler will not be clean. The likely categories, in
rough order of probability:

1. SwiftUI API details — `Canvas` and `GraphicsContext` call signatures,
   `onChange` arity, `ToolbarItem` placements.
2. `@Observable` and `@MainActor` interaction, particularly `@Bindable` usage
   in the watch views.
3. Access-control mismatches between the app targets and the package.
4. Strict concurrency diagnostics; `project.yml` sets
   `SWIFT_STRICT_CONCURRENCY: complete`, which may need relaxing to `targeted`
   initially.
5. `Bundle.module` resource lookup for the test fixtures.

The domain layer is the least likely to need changes: it is plain Foundation
value types with no platform APIs. The app layer is the most likely.

## Sensor behaviour

Nothing about compass behaviour on real hardware has been validated. See
[DEVICE_TESTING.md](DEVICE_TESTING.md) for the checklist that must be run on a
paired Apple Watch before any claim about it is made. The API availability
facts in the code comments were taken from Apple's published documentation
data, not from memory and not from a device.
