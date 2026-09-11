# Build status

| | |
| --- | --- |
| Engine builds | **Yes** — `swift build`, Swift 6.0.3, Linux |
| Engine tests | **Yes** — 131 tests, 0 failures, ~1.4 s |
| iOS / watchOS app targets | **Yes** — `xcodebuild`, Xcode 26.6, simulator |
| Compiler warnings | Not yet audited |
| Sensor behaviour on hardware | **Not validated** — no device |

Two workflows.

`engine.yml` runs `swift build` and `swift test` against
`Packages/ElementsAlign` in a `swift:6.0-noble` container on every push to
`main` and every pull request. No Xcode, no macOS runner, no third-party
actions.

`apple.yml` builds both app targets for the simulators, unsigned, on a macOS
runner. It does **not** run on every commit: a macOS runner costs roughly ten
times a Linux one, so it triggers by hand or when a pull request touches
`Apps/`, `project.yml`, the package manifest, or the workflow itself.

    make test          # the engine, the same thing locally
    make apple-build   # both app targets (macOS)
    make syntax        # parse check, needs no toolchain at all

## How this repository got here

It was authored on Linux with no Swift toolchain, and one could not be
obtained: `download.swift.org` was denied by the egress proxy (403 on
CONNECT), the Ubuntu `swift` package is OpenStack Swift, Docker was
unavailable, and `xcodebuild` is macOS-only. So roughly 3,000 lines of Swift
were written without a compiler ever seeing them.

That is worth recording because it shaped what is in here. Three things stood
in for a compiler, and it is worth knowing which of them worked.

### What held up

**The mathematics was validated against external published data.**
`Tools/oracle/` is an independent Python implementation of the same
deterministic maths, checked against sources outside this project:

| Claim | Checked against | Result |
| --- | --- | --- |
| Apparent solar longitude | Untruncated VSOP87 via PyMeeus, 1900–2100 | 0.395″ worst case (~9.6 s) |
| Solar terms | Published 2026 and 2000 equinox/solstice instants | within ~1 minute |
| Equation of time | Textbook annual landmarks | −14.17 Feb, +3.67 May, −6.56 Jul, +16.45 Nov |
| Year pillars | Published sexagenary years | exact |
| Day pillar congruence | Two independent published statements; 2000-01-07 = 甲子 | exact, 60-day periodic |
| Eight Mansions derivation | The classical 坎 row, all eight directions | exact |
| Relation symmetry | Structural property of the system | 0 asymmetric pairs |
| Life gua congruence | Per-century classical rules, 1900–2060 | 0 mismatches |

This worked. Every one of those assertions passed first time when the tests
finally ran. The golden fixtures the Swift tests assert against come from this
validated oracle, so those tests check the implementation rather than
themselves.

**Pre-computing every numeric expectation through the oracle.** This caught
two real bugs and one wrong test before anything was committed:

- `dayOnly` charts computed solar noon as `floor(jd) + 0.5`, which is
  *midnight* — a Julian Day begins at noon, so the integer Julian Day already
  is noon. Any afternoon input rolled into the following day.
- The alignment ramp's `low` colour failed 3:1 contrast on the watch
  background, and the light ramp was not monotonic in lightness.
- The first `dayOnly` stability test sampled a UTC day rather than a solar
  day, which at Seoul's longitude are about eight and a half hours apart.

### What did not hold up

**The tree-sitter parse check was not enough.** It reported all 49 files clean,
and the first CI run failed anyway:

1. **A string interpolation spanning a newline.** `CompassSector`
   built its localisation key by indexing an array literal inside an
   interpolation, and the literal wrapped onto a second line. Swift does not
   allow a single-line string literal to span a newline, so the file failed to
   lex and took the whole module with it. tree-sitter accepts the construct;
   Swift does not. The checker now verifies quote balance directly, and that
   check was itself verified both ways against fixtures — it flags the exact
   construct that failed and does not fire on multi-line literals, escaped
   quotes, or comments containing quotes.

2. **A fixture precision mismatch.** Delta-T values were stored rounded to 4
   decimals and asserted to within 1e-6, so the rounding failed the test while
   the engine agreed with the oracle to fourteen significant figures. Fixtures
   are now written at a precision that exceeds the tolerance asserted against
   them, and the remaining groups were audited for the same mistake.

Everything else compiled and passed on the first attempt, including the
strict-concurrency annotations, the `@Observable` view models, `Bundle.module`
resource lookup, and the generated VSOP87 tables.

The honest summary: validating the *mathematics* independently was worth the
effort and paid off completely. A parser is not a compiler, and treating one
as a substitute is where this went wrong.

## The app targets

They now compile. This was the repository's largest open question, and the
answer turned out to be better than expected: roughly 1,500 lines of SwiftUI
written without a compiler built clean on the first run, on Xcode 26.6, with
`SWIFT_STRICT_CONCURRENCY: complete` and the watch app correctly embedded at
`ElementsAlign.app/Watch/ElementsAlignWatch.app`.

The categories of error this document previously predicted -- `Canvas`
signatures, `onChange` arity, `@Observable` and `@MainActor` interaction,
strict concurrency -- did not materialise. Checking Apple's published
availability data instead of working from memory is the most likely reason,
along with marking the app entry points and `RootView` `@MainActor`
explicitly rather than hoping.

What this does **not** mean: that the apps behave correctly. Compiling is not
running, and nothing here has been launched in a simulator, let alone worn.

## What is still unverified

**Compiler warnings.** The build passes, but nobody has read what it warns
about. `apple.yml` now prints a count and the top offenders to the run summary
so that stops being invisible.

**Runtime behaviour.** The apps have never been launched. Compilation says the
types line up, not that the composition draws, the onboarding flows, or the
haptics fire.

**Sensor behaviour on real hardware.** Nothing about compass behaviour has
been validated on a device. See [DEVICE_TESTING.md](DEVICE_TESTING.md) for the
checklist that must be run first. The API availability facts in the code came
from Apple's published documentation data, not from memory and not from a
device.
