# Device testing

**Nothing in this checklist has been run.** No Apple Watch was available to the
session that wrote this code, and no claim about sensor behaviour in this
repository should be read as validated. That is what this document is for.

## Before anything else

The app targets have never been compiled — CI covers the engine package only.
Get them building in Xcode first; see [BUILD_STATUS.md](BUILD_STATUS.md).

## Setup

1. **Signing.** `project.yml` leaves `DEVELOPMENT_TEAM` empty deliberately — a
   team ID is not committed. Set it in Xcode after `make project`, or via a
   local `.xcconfig`.
2. **Bundle identifiers.** The watch app's
   `INFOPLIST_KEY_WKCompanionAppBundleIdentifier` must match the iOS app's
   bundle ID exactly, and the watch app's own ID must be the iOS ID suffixed
   with `.watchkitapp`. Both are set in `project.yml`; if you change one,
   change both.
3. **Pairing.** A physically paired Apple Watch — the simulator cannot test any
   of this.
4. **Hardware.** Apple Watch **Series 5 or later**. Earlier models have no
   magnetometer and `CLLocationManager.headingAvailable()` returns false. On
   those, the app should show "No compass on this watch" rather than a dead
   display; that path is worth testing explicitly if such hardware is at hand.
5. **Usage description.** `NSLocationWhenInUseUsageDescription` is set on both
   targets. iOS groups heading under location permission even though no
   position fix is needed.

## Installation

- [ ] iOS app installs and launches
- [ ] Watch app appears on the paired watch and launches independently
- [ ] Watch app launches with the phone out of range
  (`WKRunsIndependentlyOfCompanionApp` is YES)

## Permissions

- [ ] First launch prompts for location once, with the expected copy
- [ ] Granting it moves the watch from "Allow compass access" to "Finding
      north" and then to a live heading
- [ ] Denying it shows "Compass access is off" and the composition still
      renders with the spatial component at 0.5
- [ ] Revoking in Settings while the app runs is handled — the app should fall
      back, not freeze
- [ ] Re-granting recovers without a relaunch

## Heading

- [ ] A heading arrives at all, and within a few seconds
- [ ] Rotating the wrist moves the composition smoothly
- [ ] **No jitter when stationary.** This is the one most likely to disappoint.
      The 0.35 s time constant and 2° `headingFilter` are reasoned guesses, not
      measured values. If the display shimmers at rest, raise
      `HeadingSmoother.defaultTimeConstant` first.
- [ ] Turning 360° passes the 0/360 seam with no visible jump
- [ ] Compare against the built-in Compass app — how close, and is there a
      consistent offset?
- [ ] Near metal or a magnet, readings degrade *gracefully*: `coherence` should
      fall and imprecise samples should be rejected rather than displayed
- [ ] After deliberate interference, does it recover on its own or does watchOS
      require a calibration gesture?

Record actual numbers: time to first fix, observed jitter amplitude at rest,
and lag behind a deliberate 90° turn.

## The interaction

- [ ] A full slow rotation crosses at least three states
- [ ] The state name matches the composition — no visible disagreement
- [ ] Approaching 生氣 visibly organises the composition
- [ ] `Aligned` is reachable on a day when the temporal component is high, and
      not reachable on a poor day from direction alone
- [ ] The brand phrase appears only at `Aligned`
- [ ] The direction cue points the short way round, never the long way

## Haptics

- [ ] → Strong fires a light cue
- [ ] → Aligned fires a distinct cue
- [ ] → Favourable fires nothing
- [ ] **Falling fires nothing** at any level
- [ ] Standing still near a threshold produces no repeated buzzing
- [ ] A full slow rotation produces at most two cues
- [ ] Cues are legible on the wrist — distinguishable from each other, and not
      startling

## Battery

- [ ] Measure drain over 30 minutes of active use with the app foregrounded
- [ ] Measure over 30 minutes of intermittent use
- [ ] Confirm no location updates run in magnetic mode (Xcode energy gauge)
- [ ] Confirm nothing wakes the app when the wrist is down
- [ ] Confirm the solar-term solver does not appear in a time profile of the
      heading path — if it does, `TemporalSnapshot.validUntil` is not working

## Accessibility

- [ ] VoiceOver reads the state name and the direction value
- [ ] Reduce Motion removes travel but keeps state changes visible
- [ ] All six states are distinguishable in bright sunlight
- [ ] Check with a colour-vision simulation — the lightness ordering should
      carry the state on its own

## Correctness on device

- [ ] Long-press opens the inspector
- [ ] Its pillars match the iPhone summary for the same profile
- [ ] Its component values explain the displayed score
- [ ] Cross-check the natal chart against an independent Four Pillars
      calculator for two or three known birth data, including one near a 立春
      boundary and one with an unknown birth time

## Simulator gaps to expect

| Behaviour | Simulator | Device |
| --- | --- | --- |
| Heading | never delivered | real |
| `headingAvailable()` | unreliable | authoritative |
| Haptics | silent | real |
| Battery | meaningless | real |

`CoreLocationHeadingProvider` reports `.unsupportedEnvironment` in the
simulator and the app substitutes `SimulatedHeadingProvider`, so the
composition can be developed without hardware — but none of that is evidence
about the device.
