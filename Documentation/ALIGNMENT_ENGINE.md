# The Alignment engine

## What Alignment is

> A deterministic symbolic score produced from selected traditional
> cosmological rules and current contextual inputs.

That sentence is the product's own definition and it is meant literally.
Alignment is **not** a measurement of a physical field, a health or
psychological assessment, financial advice, a safety judgement, or a
prediction. Four Pillars, Five Elements and Eight Mansions are traditional
belief systems. The engine applies their rules faithfully and deterministically;
it does not claim they describe physics.

Nothing in the calculation path involves a language model. An LLM may one day
help *explain* a result conversationally, but it can never be where the result
comes from.

## Inputs

| Input | Source | Changes |
| --- | --- | --- |
| Natal chart | Birth instant + birth longitude | Never |
| Life gua | BaZi year + polarity | Never |
| Moment chart | Current instant + current longitude | Every two solar hours |
| Heading | Compass, smoothed | Continuously |

The split matters for battery. Building a chart runs the solar-term solver;
evaluating alignment is arithmetic over values already in memory. Only the
latter may touch the heading path. `TemporalSnapshot` carries `validUntil` so
callers recompute exactly when it stops being true and not one moment sooner.

## The three components

Each is normalised to `[0, 1]` before weighting.

    score = 100 × (0.50 × spatial + 0.35 × temporal + 0.15 × personal)

### Spatial — where you are facing

Eight Mansions assigns each of the eight compass sectors one of eight
relationships to your life gua. The *ranking* is traditional:

| Relationship | | Value | |
| --- | --- | --- | --- |
| 生氣 Sheng Qi | most favourable | +1.00 | auspicious |
| 天醫 Tian Yi | | +0.75 | auspicious |
| 延年 Yan Nian | | +0.50 | auspicious |
| 伏位 Fu Wei | | +0.25 | auspicious |
| 禍害 Huo Hai | | −0.25 | inauspicious |
| 六煞 Liu Sha | | −0.50 | inauspicious |
| 五鬼 Wu Gui | | −0.75 | inauspicious |
| 絕命 Jue Ming | least favourable | −1.00 | inauspicious |

**Traditional:** the ordering, and which sector holds which relationship.
**Product decision:** the numbers. They spread the eight relationships evenly
so no two directions score the same.

Between sector centres the value is interpolated with a smoothstep. This is a
product decision with a clear reason: a watch face that snapped between eight
values as the wearer turned would feel broken. Smoothstep is continuous, has
zero derivative at each sector centre — so the value *peaks* exactly on a
centre rather than sliding past it — and preserves the traditional ordering
everywhere.

Mapping to `[0, 1]` is deliberately asymmetric:

    spatial = 0.5 + 0.50 × value   when value ≥ 0   →  0.50 … 1.00
    spatial = 0.5 + 0.25 × value   when value < 0   →  0.25 … 0.50

**Product decision, and a deliberate one.** Auspicious directions use the whole
upper half; inauspicious directions compress into 0.25–0.5 instead of running
to zero. The mapping is monotonic in the underlying value, so the traditional
ordering survives exactly — but the product presents an unfavourable direction
as *unresolved*, not as harmful. This app does not tell people that where they
are standing is bad for them.

Without this compression, measured over eight synthetic profiles across a year
and the full compass, the bottom two states occupied 30–50% of all samples. A
product positioned as calm cannot spend half its life telling you things are
wrong. With it, that figure is 16.5%.

### Temporal — what the moment is made of

1. Build the moment's four pillars.
2. Compute its weighted Five Element distribution.
3. Take the combined share of the elements the natal chart favours.
4. Compare against the baseline a neutral moment would give.

```
baseline = |favourable| / 5
temporal = clamp01(0.5 + (share − baseline) × 1.5)
```

The baseline correction matters: a chart favouring three elements would
otherwise be flattered relative to one favouring two.

**Which elements are favourable** comes from the support/suppress school
(扶抑法), the most commonly taught method. A strong Day Master wants elements
that drain or restrain it (output, wealth, officer); a weak one wants elements
that feed it (peer, resource). Strength is the combined share of the Day
Master's own element plus the element that produces it, strong above 0.5.

This is **one school among several**, and the engine does not pretend
otherwise. Special-structure charts (從格, 專旺) and seasonal-adjustment
methods (調候) are out of scope for V1.

#### Pillar weighting, and why there are two profiles

|  | Year | Month | Day | Hour |
| --- | --- | --- | --- | --- |
| Natal | 1.0 | **1.5** | 1.0 | 1.0 |
| Moment | 0.5 | 1.0 | **1.5** | **1.5** |

The natal profile weights the month pillar because seasonal command (得令) is
the classical basis for judging Day Master strength. **Traditional.**

The moment profile weights day and hour, because they are what actually
changes while someone is wearing the watch. **Product decision.**

This second profile is not cosmetic — it was the fix for a design failure.
With a single month-weighted profile, the temporal component was pinned by
season: across a full year, two of eight test profiles could never reach
`Aligned` at all, because their favourable elements never dominated a
month-weighted distribution. Raw favourable share spanned only about 0.3–0.6.
With the moment profile it spans 0.0–1.0, and all eight profiles reach
`Aligned`. The constants were left alone; the model was what needed fixing.

### Personal — a stable baseline

Normalised Shannon entropy of the natal element distribution, remapped:

    personal = clamp01((balance − 0.60) / 0.35)

**Product decision throughout.** Real charts cluster in the upper part of the
entropy scale, so the raw value would vary too little between people to be
worth including. This component is constant for a given person by design: it
shifts where someone sits, it does not drive movement.

## Weights

| Component | Weight | Why |
| --- | --- | --- |
| Spatial | 0.50 | Turning the body is the interaction the product is built around. If direction did not dominate, rotating would barely move the display. |
| Temporal | 0.35 | Enough that the same direction feels different on different days. |
| Personal | 0.15 | A nudge, not a verdict. |

## States

| State | Score | |
| --- | --- | --- |
| Quiet (`low`) | < 30 | |
| Unsettled (`unfavourable`) | 30–44 | |
| Neutral | 45–57 | |
| Favourable | 58–70 | |
| Strong | 71–83 | elevated |
| Aligned | ≥ 84 | elevated, brand moment |

Categories lead and the number follows. A score of 73.4 *looks* like a
measurement, and this is not one, so the named state is the honest unit. Raw
scores appear only in the debug inspector.

### Why these thresholds

They were chosen against explicit design goals and measured, not guessed:

| Goal | Target | Measured |
| --- | --- | --- |
| Bottom two states are not the common case | < 25% | 16.5% |
| `Aligned` is rare | 0.5–5% | 3.85% |
| Every person can reach `Aligned` some day of the year | all | all 8 profiles |
| A full rotation is legible | ≥ 3 levels | 4 levels |

Reaching `Aligned` requires the confluence the product is named for: facing
your 生氣 direction *and* a moment made of your favourable elements. Perfect
direction alone tops out around 75 — `Strong`, not `Aligned`.

## Hysteresis and haptics

A raw score sitting near a threshold crosses it constantly as the wearer
breathes. `AlignmentTracker` guards the level with:

- a **±3 point band** that must be cleared to rise and re-cleared to fall;
- a **1.5 s minimum dwell** between level changes.

Haptics are governed separately and sparingly:

| Transition | Cue |
| --- | --- |
| → Aligned | `.aligned` (distinct) |
| → Strong | `.affirm` (light) |
| → Favourable | none — common enough that a cue would mean nothing |
| any falling transition | none |

Falling is silent on purpose. Being told you have moved *away* from something
good is exactly the fortune-telling tone this product is avoiding. Cues are
additionally rate-limited to one per 4 seconds, enforced inside the tracker so
a caller cannot bypass the policy by forgetting it.

## Determinism

Given the same profile, instant and heading, the engine returns the same state
every time. There is no randomness, no time-dependent seeding, and no network
call. This is asserted directly in the test suite.

## Known ambiguities

Recorded rather than hidden:

- **Favourable elements** use one school (扶抑法). Others disagree.
- **Late Zi hour** is a genuine fork in the tradition; it is a setting with a
  documented default (`dayChangesAt23`), not a hidden assumption.
- **Magnetic vs true north.** Default is magnetic, matching luopan practice
  and available without a position fix. True north is selectable.
- **24 mountains.** Classical Eight Mansions subdivides each sector into three
  15° mountains. V1 uses the eight 45° sectors.
- **Solar term precision** is about ±10 seconds. Charts within 30 minutes of a
  boundary are flagged, because the uncertainty there is the *user's* recorded
  time, not ours.
- **Daylight-saving edges.** A birth time is resolved against the zone's
  historical offsets, so Korea's UTC+8:30 years and its 1987-88 summer time
  are applied correctly. Two readings still cannot resolve cleanly: one that
  fell in a spring-forward gap never occurred, and one in a fall-back repeat
  occurred twice. The engine reports both rather than choosing silently; for
  a repeat it takes the earlier instant, which is a product decision the
  interface states.
