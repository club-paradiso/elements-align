# Roadmap

## Milestone 1 — Directional Alignment Prototype

**Status: everything compiles and the engine's tests pass. Nothing has been
run.** See [BUILD_STATUS.md](BUILD_STATUS.md).

- [x] Five Element domain model
- [x] Personal profile model
- [x] Four Pillars calculation on a validated astronomical foundation
- [x] Eight Mansions directional profile
- [x] Alignment engine, tuned against measured design goals
- [x] Heading service with circular smoothing
- [x] Live directional comparison
- [x] Reactive Five Element visualisation
- [x] Alignment states with hysteresis
- [x] Haptic state transitions
- [x] iOS onboarding, profile configuration, permissions
- [x] Historical time zones, including daylight-saving gaps and repeats
- [x] Debug inspectors on both platforms
- [x] 131 tests against externally validated fixtures
- [x] English and Korean localisation
- [x] **Engine compiles** — Swift 6.0.3 on Linux, green in CI
- [x] **Engine tests pass** — 131 tests, 0 failures
- [x] **App targets compile** — Xcode 26.6, unsigned simulator builds in CI
- [ ] **Apps actually run** — never launched, in a simulator or otherwise
- [ ] **Validated on real hardware** — see [DEVICE_TESTING.md](DEVICE_TESTING.md)

## Milestone 2 — Make it real

The next session's work, in priority order.

1. **Launch the apps.** They compile; that is not the same as working. Run
   both in a simulator and see whether the composition draws, the onboarding
   flows, and the debug inspectors agree with the engine.
2. **Read the compiler warnings.** The build passes and nobody has looked;
   `apple.yml` prints a count and the top offenders to the run summary.
2. **Run the device checklist.** Nothing about compass behaviour on hardware
   is currently verified.
3. **Widen the birth-place table**, or add offline geocoding. Manual longitude
   entry covers the gap today but is a poor experience.

## Milestone 3 — Presence

- Complications and Smart Stack widgets.
- WatchConnectivity so profile changes propagate without a reinstall.
- An "explain this state" view on iPhone that walks the actual computation.
- Optional true-north mode with declination shown.

## Milestone 4 — Xuan Kong Flying Stars

The most likely next traditional system, and the one the architecture already
anticipates. It needs a time-varying spatial layer over the same compass
sectors. `AlignmentEngine.spatialComponent` already takes a directional profile
as a parameter, so this becomes a `DirectionalScoring` protocol with Eight
Mansions as one conformer — a local change rather than a rewrite.

Requires: annual and monthly star charts, period handling, and a decision about
how to combine two directional systems without double-counting.

## Milestone 5 — Rooms and seats

The long-term product question: *where should I sit in this room?*

- iPhone room understanding via ARKit, and RoomPlan where supported.
- Candidate seat positions scored symbolically.
- Watch guidance by direction, motion and haptic intensity.

Explicitly **not** dependent on centimetre-level indoor positioning. GPS is
nowhere near accurate enough for chair-level placement and the product will
not pretend otherwise. Relative geometry from a scan, plus heading, is the
tractable path.

## Deliberately not planned

Western astrology, tarot, numerology, generative-AI fortune generation, a
backend, accounts, or any analytics carrying personal data.

## Known limitations carried forward

| Limitation | Where |
| --- | --- |
| Apps never launched | [BUILD_STATUS.md](BUILD_STATUS.md) |
| Compiler warnings unaudited | [BUILD_STATUS.md](BUILD_STATUS.md) |
| Sensor behaviour unvalidated | [DEVICE_TESTING.md](DEVICE_TESTING.md) |
| Favourable elements use one school (扶抑法) | [ALIGNMENT_ENGINE.md](ALIGNMENT_ENGINE.md) |
| Eight 45° sectors, not 24 mountains | [TRADITIONAL_SYSTEMS.md](TRADITIONAL_SYSTEMS.md) |
| Solar terms accurate to ~10 s | [TRADITIONAL_SYSTEMS.md](TRADITIONAL_SYSTEMS.md) |
| Small offline birth-place table | Milestone 2 |
