# Watch interaction

## The interaction

A wearer turns. The composition responds. When person, time and direction
line up, the interface lines up.

That is the whole product, and everything below serves it.

## One composition, not a dashboard

The watch shows a single ambient composition: five element nodes on a ring,
anchored to the compass.

**Anchored to the compass** is the important part. The ring is fixed to the
world, not to the screen, so turning the wrist moves the ring *past* the
wearer. That is what makes the interface read as spatial rather than animated.
If the composition rotated with the watch it would just be decoration.

## How states look

| State | Composition |
| --- | --- |
| Quiet / Unsettled | Nodes scattered off the ring, links invisible, orbit faint |
| Neutral | Nodes settling toward the ring |
| Favourable | Links begin to show; geometry starts to read as ordered |
| Strong | Nodes gathered, links clear, dominant element haloed |
| Aligned | Nodes converged; the brand phrase appears |

Convergence is driven by the **continuous score**, not the discrete level, so
the composition responds while the wearer is turning instead of snapping only
when a threshold is crossed. The level drives colour and the state name; the
score drives geometry.

Scatter offsets are deterministic per node index — golden-angle phases — not
random. A random offset recomputed per frame would shimmer.

## The brand moment

`ELEMENTS,` / `ALIGN.` appears only at full alignment, and nowhere else in the
product. It is an event, not a label. Overusing it would make it worthless.

## Motion

Most movement here is *data moving*, not an animation playing. Three durations
govern the few genuine transitions:

| | Duration | |
| --- | --- | --- |
| `headingFollow` | 0.12 s | Direct manipulation — lag reads as broken |
| `levelTransition` | 0.6 s | Colour and state name settling |
| `convergence` | 0.9 s | The alignment moment |

Under **Reduce Motion** every duration collapses to zero. The composition still
changes; it simply stops travelling. That is asserted in tests.

## Haptics

Rare on purpose. A watch that buzzes every time you turn your wrist is a watch
people take off.

| Transition | Cue | watchOS haptic |
| --- | --- | --- |
| → Aligned | `.aligned` | `.success` |
| → Strong | `.affirm` | `.directionUp` |
| → Favourable | none | — |
| any falling | none | — |

`.directionUp` is chosen over a notification haptic because it reads as
movement in a direction, which is what "the composition is coming together"
should feel like.

**Falling transitions are silent.** Being told you have moved away from
something good is exactly the fortune-telling tone this product avoids.

Three guards keep cues meaningful: a ±3 point hysteresis band, a 1.5 s dwell
between level changes, and a 4 s minimum between cues. The rate limit lives
inside `AlignmentTracker` so a caller cannot bypass it by forgetting it. A test
sweeps a full simulated rotation and asserts no more than two cues fire.

## Compass handling

Raw heading is noisy, so it is filtered before anything sees it.

Samples accumulate as **unit vectors**, and the smoothed heading is read back
with `atan2`. This makes wraparound stop being a case that can be got wrong —
the arithmetic mean of 359° and 1° is 180°, pointing exactly backwards.

The filter uses a **time constant** (0.35 s) rather than a fixed weight, so its
behaviour does not change when the sensor delivers at a different rate. A test
asserts 10 Hz and 50 Hz settle to the same place.

Readings Core Location marks imprecise — negative accuracy, or worse than 25° —
are discarded. `coherence`, the length of the accumulated vector, falls when
recent samples disagree, which is what magnetic interference looks like.

`headingFilter` is set to 2° rather than the 1° default: at 1° a resting wrist
generates a continuous stream of wakeups for no visible benefit.

## When there is no heading

Heading unavailability is a first-class state, not an error. Each reason gets
its own message:

| Reason | Shown |
| --- | --- |
| `noHardware` | No compass on this watch |
| `permissionDenied` | Compass access is off |
| `permissionNotDetermined` | Allow compass access |
| `calibrating` | Finding north |
| `unsupportedEnvironment` | No compass in simulator |

The spatial component falls back to 0.5 and `isHeadingAvailable` is false, so
the interface knows not to imply a direction it does not have.

## Battery

- Nothing runs on a timer. The composition redraws when the data changes.
- One `Canvas` pass per update, not a tree of shape views being diffed.
- The solar-term solver never sits on the heading path; see
  [ARCHITECTURE.md](ARCHITECTURE.md).
- `headingFilter` at 2° roughly halves the wake rate versus the default.
- No background execution, no location updates unless true north is selected.

## Accessibility

- The composition is `accessibilityHidden`; the screen exposes one element with
  the state name as its label and the direction as its value.
- Reduce Motion collapses every duration.
- The state ramp is ordered by **lightness** in both colour schemes, so state
  is readable without relying on colour perception. Every step clears 3:1
  against its background, and both properties are asserted in tests.
- Text is minimal by design — a watch face, not a document.

## Not yet built

Complications and Smart Stack widgets are a natural fit and are on the
roadmap. They are not in V1 because the interaction had to be right first.
