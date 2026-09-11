# Traditional systems

How the three systems this product uses are computed, what is traditional,
what is a product decision, and how each claim was checked.

## Positioning

These are traditional belief systems with long histories, not validated
descriptions of physical processes. The engineering commitment here is
narrower and more testable than "does this work": **the rules are applied
correctly and deterministically.** Where practitioners genuinely disagree, the
disagreement is recorded and one option is chosen explicitly rather than
smuggled in.

## The astronomical foundation

Everything rests on the Sun's apparent geocentric longitude, because the BaZi
year and every BaZi month begin at exact solar longitudes.

The chain is the standard one: VSOP87 heliocentric longitude of the Earth →
geocentric solar longitude → FK5 correction → nutation → annual aberration.

`Packages/ElementsAlign/Sources/ElementsCore/Calendar/VSOP87Earth.swift` is
**generated, not hand-written**. `Tools/oracle/gen_vsop87.py` reads the VSOP87
tables out of the PyMeeus distribution programmatically and truncates them, so
there is no transcription-error path. Truncation is validated at generation
time against the untruncated series:

- 95 longitude terms kept of 1080; 16 radius terms of 997
- worst-case error over 1900–2100: **0.395 arcseconds**
- equivalent solar-term timing error: **~9.6 seconds**

For comparison, the commonly used low-accuracy series (Meeus ch. 25) was
measured at up to ~10 *minutes* against published equinox times. The
difference is why the fuller series was worth generating.

Delta-T uses the Espenak & Meeus piecewise polynomials. Terrestrial Time and
Universal Time are separate Swift types, because conflating them puts every
solar term about a minute out.

**Verified against published data:**

| | Published | Computed |
| --- | --- | --- |
| March equinox 2026 | 14:46 UTC | 14:45:50 |
| June solstice 2026 | 08:25 UTC | 08:24:22 |
| September equinox 2026 | 00:05 UTC | 00:05:08 |
| December solstice 2026 | 20:50 UTC | 20:50:08 |
| March equinox 2000 | 07:35 UTC | 07:35:19 |

The equation of time reproduces every textbook landmark: −14.17 min in
mid-February, +3.67 in mid-May, −6.56 in late July, +16.45 in early November,
and zero crossings in mid-April and late December.

## Four Pillars (四柱 / BaZi)

### Year pillar

The BaZi year turns at **立春 Lichun** (solar longitude 315°), not at the lunar
new year. This is the more widely used convention in Four Pillars practice and
the product commits to it. A January birth therefore belongs to the *previous*
BaZi year — a classic source of wrong charts, and something the test suite
asserts directly.

    stem   = (year − 4) mod 10
    branch = (year − 4) mod 12

1984 is 甲子, the start of a cycle.

**Checked** against published sexagenary years: 1984 甲子, 2024 甲辰 (Wood
Dragon), 2025 乙巳 (Wood Snake), 2026 丙午 (Fire Horse), 1900 庚子.

### Month pillar

The branch comes from the 12 month-defining **節** terms — the even-indexed
solar terms, at 315°, 345°, 15°, … — with 立春 beginning the 寅 month. The
mid-month **氣** terms play no part in the pillars.

The stem follows **五虎遁**, the "five tigers" rule: the year stem fixes the
stem of the 寅 month, and months advance from there.

    yinMonthStem = (yearStem mod 5) × 2 + 2

Which reproduces the classical table: 甲/己 → 丙寅, 乙/庚 → 戊寅, 丙/辛 → 庚寅,
丁/壬 → 壬寅, 戊/癸 → 甲寅.

### Day pillar

An unbroken count across the whole calendar, so it needs no epoch table — just
a congruence on the Julian Day Number of the day's noon:

    stem   = (JDN − 1) mod 10
    branch = (JDN + 1) mod 12

**Checked** three ways: against two independent published statements of the
same formula; against 2000-01-07 being a 甲子 day; and for 60-day periodicity
with single-step advance over 200 consecutive days.

### Hour pillar

The branch comes from local **apparent solar time**, not clock time. 子 spans
23:00–01:00 and therefore straddles midnight, so the hour is shifted by one
before halving.

The stem follows **五鼠遁**, the "five rats" rule: the day stem fixes the stem
of the 子 hour, `ziHourStem = (dayStem mod 5) × 2`.

### Solar time

Clock time is a political construct; the pillars are defined against the Sun.

    local mean solar time = UT + longitude / 15 hours
    local apparent solar time = local mean + equation of time

Seoul sits about 8.5° west of the 135°E meridian its clocks follow — roughly
34 minutes of solar time. Near an hour boundary that is the difference between
two branches, which is why this is not optional in practice.

Before any of that, the wall-clock reading itself has to become an instant,
and the offset to use is the one that was in force on the date — not today's.
Korea ran on UTC+8:30 from 1954 to 1961 and observed summer time in 1950,
1960, 1987 and 1988. A 1955 Seoul birth resolved against modern KST lands half
an hour out, which is again enough to cross an hour boundary. `CivilBirthTime`
resolves through the tz database and reports the two readings that cannot
resolve cleanly: one inside a spring-forward gap never occurred, and one
inside a fall-back repeat occurred twice.

### The late Zi hour — a real fork

Two schools disagree about which day a 23:00–23:59 birth belongs to:

- **子時換日** — the day turns at 23:00. **The default here**, and the more
  common convention in modern practice.
- **子正換日** — the day turns at midnight.

This is a setting, not a hidden assumption. Neither is "the correct formula".

### Unknown birth time

Not blocked, and not guessed. The chart is built with **no hour pillar** and
carries `precision == .dayOnly`, which the interface surfaces. The day pillar
is evaluated at local solar *noon* — not an estimate of the birth time, but
the point of the day furthest from both candidate day boundaries, so the day
pillar it yields is the one least sensitive to the missing information.

### Boundary sensitivity

Charts within 30 minutes of a month-defining term are flagged. The threshold
is far above the engine's own ~10 second error on purpose: it reflects *user*
time uncertainty — rounded birth certificates, unrecorded seconds — not ours.

## Five Elements (五行)

Case order is the generating cycle, so both classical cycles fall out of
modular arithmetic rather than lookup tables:

    generates   = (element + 1) mod 5     Wood → Fire → Earth → Metal → Water
    controls    = (element + 2) mod 5     Wood parts Earth, Metal cuts Wood

Stems: element is the index halved, polarity is its parity.

Branches carry **hidden stems** (藏干), one to three each, in the classical
本氣 / 中氣 / 餘氣 order. A chart that ignores them loses most of its texture.

Their weights are a **product decision**, documented here: `[1.0]`,
`[0.7, 0.3]`, `[0.6, 0.3, 0.1]`. They always sum to 1, so every branch
contributes equally regardless of how many stems it hides.

## Eight Mansions (八宅 Ba Zhai)

### Life gua, derived rather than tabulated

The classical rules are stated per century — "for 1900s males, ten minus the
reduced digit sum of the last two digits; for 2000s males, nine minus it",
with separate rules for females. Both centuries reduce to a single congruence,
because 1900 and 2000 differ by exactly the offset the two rules differ by:

    yang: (11 − year) mod 9          yin: (year + 4) mod 9

with 0 mapped to 9. The central 5 has no trigram and is reassigned to 2 (坤)
for yang, 8 (艮) for yin.

**Checked** against the per-century statements for every year from 1900 to
2060, for both polarities: **zero mismatches.**

The year must be the 立春-based BaZi year. Using the calendar year here is
another classic source of wrong charts.

### The eight relationships, derived from the changing-line rule

Trigrams are encoded by their lines — bit 0 bottom, bit 1 middle, bit 2 top,
set means solid. That encoding lets the relationships be *derived* from the
classical **變爻** rule instead of transcribed from a table.

Flipping lines in the classical order — top, middle, bottom, middle, top,
middle, bottom, middle — yields, in order: 生氣, 五鬼, 延年, 六煞, 禍害, 天醫,
絕命, 伏位, returning to the start. Each relationship is therefore an XOR mask
over the line encoding:

| Relationship | Mask | Lines changed |
| --- | --- | --- |
| 伏位 Fu Wei | `000` | none |
| 生氣 Sheng Qi | `100` | top |
| 五鬼 Wu Gui | `110` | top + middle |
| 延年 Yan Nian | `111` | all three |
| 六煞 Liu Sha | `101` | top + bottom |
| 禍害 Huo Hai | `001` | bottom |
| 天醫 Tian Yi | `011` | bottom + middle |
| 絕命 Jue Ming | `010` | middle |

Directions come from the Later Heaven arrangement (後天八卦): 坎 N, 艮 NE,
震 E, 巽 SE, 離 S, 坤 SW, 兌 W, 乾 NW.

**Checked three ways.** It reproduces the published 坎 row on all eight
directions. Its relation pairing is perfectly symmetric across all eight gua —
a structural property of the classical system, which XOR guarantees and the
tests assert. And 伏位 always lands on your own direction.

Groups: East (東四命) is gua 1, 3, 4, 9; West (西四命) is 2, 6, 7, 8.

### Compass conventions

Sectors are 45° wide, centred on multiples of 45°, so a sector spans 22.5°
either side of its centre.

Heading defaults to **magnetic** north. Two reasons: a luopan measures
magnetic north, and magnetic heading needs no position fix, whereas Core
Location only resolves true heading while location updates are running. True
north is selectable.

## Not in V1

Deliberately excluded from the calculation engine: Western astrology, Zi Wei
Dou Shu, Thai astrology, tarot, numerology, generative-AI interpretation, and
Xuan Kong Flying Stars.

Flying Stars is the most likely next system and the architecture anticipates
it — it needs a time-varying spatial layer over the same compass sectors,
which is why direction scoring is already separated from the Eight Mansions
profile that currently produces it. It is not prematurely implemented.
