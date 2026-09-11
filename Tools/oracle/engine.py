"""
Reference implementation of the Elements, Align. domain engine.

Mirrors Packages/ElementsCore step for step. Used to (a) sanity-check the
model against external published data and (b) emit golden fixtures that the
Swift test suite asserts against.
"""
import math, sys, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from oracle import (gregorian_to_jd, jd_to_gregorian, jdn_for_date,
                    delta_t_seconds, jd_to_iso_utc, SOLAR_TERMS, JIE_INDICES)

ARCSEC = 1.0 / 3600.0
_VSOP = {}

def load_vsop(pymeeus_src):
    """Load the same truncated tables that were emitted to Swift."""
    sys.path.insert(0, pymeeus_src)
    from pymeeus.Earth import VSOP87_L, VSOP87_R
    from pymeeus.Coordinates import NUTATION_ARG_TABLE, NUTATION_SINE_COEF_TABLE
    _VSOP['L'] = [[t for t in s if abs(t[0]) >= 20.0] for s in VSOP87_L]
    _VSOP['R'] = [[t for t in s if abs(t[0]) >= 300.0] for s in VSOP87_R]
    _VSOP['NA'] = NUTATION_ARG_TABLE
    _VSOP['NS'] = NUTATION_SINE_COEF_TABLE

def _series(series, tau):
    total = 0.0
    for k, terms in enumerate(series):
        total += sum(a * math.cos(b + c * tau) for a, b, c in terms) * (tau ** k)
    return total * 1e-8

def nutation_longitude_deg(t):
    d = 297.85036 + t * (445267.111480 + t * (-0.0019142 + t / 189474.0))
    m = 357.52772 + t * (35999.050340 + t * (-0.0001603 - t / 300000.0))
    mp = 134.96298 + t * (477198.867398 + t * (0.0086972 + t / 56250.0))
    f = 93.27191 + t * (483202.017538 + t * (-0.0036825 + t / 327270.0))
    om = 125.04452 + t * (-1934.136261 + t * (0.0020708 + t / 450000.0))
    args = [d, m, mp, f, om]
    dpsi = 0.0
    for i, (c0, c1) in enumerate(_VSOP['NS']):
        arg = sum(_VSOP['NA'][i][j] * args[j] for j in range(5))
        dpsi += (c0 + c1 * t) * math.sin(math.radians(arg))
    return (dpsi / 10000.0) * ARCSEC

def apparent_solar_longitude(jde):
    tau = (jde - 2451545.0) / 365250.0
    t = (jde - 2451545.0) / 36525.0
    lon = math.degrees(_series(_VSOP['L'], tau)) % 360.0
    r = _series(_VSOP['R'], tau)
    lon += 180.0 - 0.09033 * ARCSEC + nutation_longitude_deg(t) - 20.4898 * ARCSEC / r
    return lon % 360.0

def mean_obliquity_deg(t):
    """Meeus 22.2, mean obliquity of the ecliptic."""
    return (23.0 + 26.0 / 60.0 + 21.448 / 3600.0
            - (46.8150 * t + 0.00059 * t * t - 0.001813 * t ** 3) / 3600.0)

def equation_of_time_minutes(jde):
    """Meeus 28.3. Returns apparent solar time minus mean solar time, minutes."""
    t = (jde - 2451545.0) / 36525.0
    tau = (jde - 2451545.0) / 365250.0
    l0 = (280.4664567 + 360007.6982779 * tau + 0.03032028 * tau ** 2
          + tau ** 3 / 49931.0 - tau ** 4 / 15300.0 - tau ** 5 / 2000000.0) % 360.0
    lam = apparent_solar_longitude(jde)
    eps = mean_obliquity_deg(t)
    lam_r, eps_r = math.radians(lam), math.radians(eps)
    alpha = math.degrees(math.atan2(math.cos(eps_r) * math.sin(lam_r), math.cos(lam_r))) % 360.0
    dpsi = nutation_longitude_deg(t)
    e = l0 - 0.0057183 - alpha + dpsi * math.cos(eps_r)
    e = (e + 180.0) % 360.0 - 180.0
    return e * 4.0

def solve_longitude(target, guess):
    jde = guess
    for _ in range(60):
        d = (apparent_solar_longitude(jde) - target + 180.0) % 360.0 - 180.0
        if abs(d) < 1e-9:
            break
        jde -= d / 0.9856473
    return jde

def solar_term_jd_ut(year, term_index):
    lon = SOLAR_TERMS[term_index][2]
    approx = ((lon - 280.0) % 360.0) * 365.2422 / 360.0
    jde = solve_longitude(lon, gregorian_to_jd(year, 1, 1.0) + approx)
    y, m, _ = jd_to_gregorian(jde)
    return jde - delta_t_seconds(y, m) / 86400.0

# ------------------------------------------------------------ sexagenary
STEMS = ["Jia", "Yi", "Bing", "Ding", "Wu", "Ji", "Geng", "Xin", "Ren", "Gui"]
STEMS_CN = list("甲乙丙丁戊己庚辛壬癸")
BRANCHES = ["Zi", "Chou", "Yin", "Mao", "Chen", "Si",
            "Wu", "Wei", "Shen", "You", "Xu", "Hai"]
BRANCHES_CN = list("子丑寅卯辰巳午未申酉戌亥")

WOOD, FIRE, EARTH, METAL, WATER = "Wood", "Fire", "Earth", "Metal", "Water"
ELEMENTS = [WOOD, FIRE, EARTH, METAL, WATER]
GENERATES = {WOOD: FIRE, FIRE: EARTH, EARTH: METAL, METAL: WATER, WATER: WOOD}
CONTROLS = {WOOD: EARTH, EARTH: WATER, WATER: FIRE, FIRE: METAL, METAL: WOOD}
GENERATED_BY = {v: k for k, v in GENERATES.items()}
CONTROLLED_BY = {v: k for k, v in CONTROLS.items()}

STEM_ELEMENT = [WOOD, WOOD, FIRE, FIRE, EARTH, EARTH, METAL, METAL, WATER, WATER]
STEM_YANG = [True, False] * 5
BRANCH_ELEMENT = [WATER, EARTH, WOOD, WOOD, EARTH, FIRE,
                  FIRE, EARTH, METAL, METAL, EARTH, WATER]
# Hidden stems (藏干), principal first.
HIDDEN = {
    0: [9], 1: [5, 9, 7], 2: [0, 2, 4], 3: [1], 4: [4, 1, 9], 5: [2, 6, 4],
    6: [3, 5], 7: [5, 3, 1], 8: [6, 8, 4], 9: [7], 10: [4, 7, 3], 11: [8, 0],
}
HIDDEN_WEIGHTS = {1: [1.0], 2: [0.7, 0.3], 3: [0.6, 0.3, 0.1]}
MONTH_PILLAR_EMPHASIS = 1.5

def day_pillar_indices(jdn):
    """stem/branch (0-based) for the civil day whose noon has this JDN."""
    return (jdn - 1) % 10, (jdn + 1) % 12

def year_pillar_indices(bazi_year):
    return (bazi_year - 4) % 10, (bazi_year - 4) % 12

def month_stem_index(year_stem, month_branch):
    """五虎遁. month_branch is 0-based with 2 == 寅, the first BaZi month."""
    yin_stem = (year_stem % 5) * 2 + 2
    ordinal = (month_branch - 2) % 12
    return (yin_stem + ordinal) % 10

def hour_stem_index(day_stem, hour_branch):
    """五鼠遁."""
    return ((day_stem % 5) * 2 + hour_branch) % 10

# ------------------------------------------------------------- four pillars
class LateZiPolicy:
    DAY_CHANGES_AT_23 = "dayChangesAt23"
    DAY_CHANGES_AT_MIDNIGHT = "dayChangesAtMidnight"

def solar_time_jd(jd_ut, longitude_deg, use_equation_of_time=True):
    """Local apparent solar time expressed as a Julian Day.

    Longitude correction converts UT to local mean solar time; the equation
    of time then converts local mean to local apparent (true) solar time,
    which is what classical BaZi hour boundaries are defined against.
    """
    jd = jd_ut + longitude_deg / 360.0
    if use_equation_of_time:
        jd += equation_of_time_minutes(jd_ut) / 1440.0
    return jd

def bazi_year_for(jd_ut):
    """The BaZi year begins at 立春 (solar longitude 315 deg), not at the
    lunar new year. Returns the civil year whose Lichun the instant follows."""
    y, m, _ = jd_to_gregorian(jd_ut)
    lichun = solar_term_jd_ut(y, 0)
    return y if jd_ut >= lichun else y - 1

def month_branch_for(jd_ut):
    """Earthly branch of the BaZi month, from the 12 month-defining 節 terms.
    寅 (index 2) starts at Lichun."""
    y, _, _ = jd_to_gregorian(jd_ut)
    best = None
    for yy in (y - 1, y, y + 1):
        for k, ti in enumerate(JIE_INDICES):
            start = solar_term_jd_ut(yy, ti)
            if start <= jd_ut:
                if best is None or start > best[0]:
                    best = (start, (2 + k) % 12)
    return best[1]

def four_pillars(jd_ut, longitude_deg,
                 late_zi=LateZiPolicy.DAY_CHANGES_AT_23,
                 use_equation_of_time=True):
    """Returns the four pillars as (stem, branch) index pairs, plus metadata."""
    solar_jd = solar_time_jd(jd_ut, longitude_deg, use_equation_of_time)

    ys, yb = year_pillar_indices(bazi_year_for(jd_ut))
    mb = month_branch_for(jd_ut)
    ms = month_stem_index(ys, mb)

    # Civil-ish date in local apparent solar time, and hour of that day.
    y, m, d = jd_to_gregorian(solar_jd)
    day = int(math.floor(d))
    hour = (d - day) * 24.0
    jdn = jdn_for_date(y, m, day)

    # Hour branch: 子 spans 23:00-01:00, so shift by one hour before halving.
    hb = int(math.floor(((hour + 1.0) % 24.0) / 2.0)) % 12
    if late_zi == LateZiPolicy.DAY_CHANGES_AT_23 and hour >= 23.0:
        jdn += 1
    ds, db = day_pillar_indices(jdn)
    hs = hour_stem_index(ds, hb)

    return {
        "year": (ys, yb), "month": (ms, mb), "day": (ds, db), "hour": (hs, hb),
        "solarJD": solar_jd, "solarHour": hour,
    }

def boundary_proximity_minutes(jd_ut):
    """Minutes to the nearest month-defining solar term. Small values mean the
    month (and possibly year) pillar is sensitive to input precision."""
    y, _, _ = jd_to_gregorian(jd_ut)
    best = 1e9
    for yy in (y - 1, y, y + 1):
        for ti in JIE_INDICES:
            best = min(best, abs(solar_term_jd_ut(yy, ti) - jd_ut) * 1440.0)
    return best

# ------------------------------------------------------------ five elements
# Pillar weighting. Two different profiles are used, for two different
# questions. See Documentation/ALIGNMENT_ENGINE.md.
#
#   NATAL_WEIGHTS  - "what is this person made of?" The month pillar carries
#                    extra weight because seasonal command (得令) is the
#                    classical basis for judging day-master strength.
#   MOMENT_WEIGHTS - "what is right now made of?" The day and hour pillars
#                    lead, because they are what actually changes while the
#                    user is wearing the watch; year and month are slow
#                    background. This is a product decision, not a classical
#                    rule, and it is the reason the temporal component has
#                    usable dynamic range instead of being pinned by season.
NATAL_WEIGHTS = (1.0, 1.5, 1.0, 1.0)
MOMENT_WEIGHTS = (0.5, 1.0, 1.5, 1.5)
PILLAR_ORDER = ("year", "month", "day", "hour")

def element_distribution(pillars, weights=NATAL_WEIGHTS):
    """Weighted five-element distribution of a chart. Returns dict summing to 1."""
    dist = {e: 0.0 for e in ELEMENTS}
    for name, w in zip(PILLAR_ORDER, weights):
        stem, branch = pillars[name]
        dist[STEM_ELEMENT[stem]] += w
        hidden = HIDDEN[branch]
        for hw, hs in zip(HIDDEN_WEIGHTS[len(hidden)], hidden):
            dist[STEM_ELEMENT[hs]] += hw * w
    total = sum(dist.values())
    return {k: v / total for k, v in dist.items()}

def day_master_element(pillars):
    return STEM_ELEMENT[pillars["day"][0]]

def day_master_strength(pillars):
    """扶抑法 support/suppress analysis. Returns supportive share in [0,1]."""
    dist = element_distribution(pillars, NATAL_WEIGHTS)
    dm = day_master_element(pillars)
    return dist[dm] + dist[GENERATED_BY[dm]]

def favourable_elements(pillars):
    """One school (扶抑用神): strong day masters want draining/controlling
    elements, weak day masters want supporting elements."""
    dm = day_master_element(pillars)
    if day_master_strength(pillars) > 0.5:
        return {GENERATES[dm], CONTROLS[dm], CONTROLLED_BY[dm]}, "strong"
    return {dm, GENERATED_BY[dm]}, "weak"

def natal_balance(pillars):
    """Normalised Shannon entropy of the natal element distribution, [0,1]."""
    dist = element_distribution(pillars, NATAL_WEIGHTS)
    h = -sum(p * math.log(p) for p in dist.values() if p > 0)
    return h / math.log(5.0)

# ----------------------------------------------------------------- ba zhai
TRIGRAMS = {
    0: ("Kun", "坤", 225.0), 1: ("Zhen", "震", 90.0),
    2: ("Kan", "坎", 0.0), 3: ("Dui", "兌", 270.0),
    4: ("Gen", "艮", 45.0), 5: ("Li", "離", 180.0),
    6: ("Xun", "巽", 135.0), 7: ("Qian", "乾", 315.0),
}
GUA_TO_TRIGRAM = {1: 2, 2: 0, 3: 1, 4: 6, 6: 7, 7: 3, 8: 4, 9: 5}

# 變爻 (changing-line) rule. Flipping lines in the classical order
# top/middle/bottom/middle/top/middle/bottom/middle yields, in order:
# 生氣 五鬼 延年 六煞 禍害 天醫 絕命 伏位. As XOR masks over
# (bottom=1, middle=2, top=4):
RELATIONS = [
    ("ShengQi", "生氣", 0b100, 1.00),
    ("TianYi", "天醫", 0b011, 0.75),
    ("YanNian", "延年", 0b111, 0.50),
    ("FuWei", "伏位", 0b000, 0.25),
    ("HuoHai", "禍害", 0b001, -0.25),
    ("LiuSha", "六煞", 0b101, -0.50),
    ("WuGui", "五鬼", 0b110, -0.75),
    ("JueMing", "絕命", 0b010, -1.00),
]

class Polarity:
    YANG = "yang"   # traditionally 男
    YIN = "yin"     # traditionally 女

def life_gua(bazi_year, polarity):
    """本命卦. Derived rather than tabulated; see TRADITIONAL_SYSTEMS.md."""
    g = (11 - bazi_year) % 9 if polarity == Polarity.YANG else (bazi_year + 4) % 9
    if g == 0:
        g = 9
    if g == 5:
        g = 2 if polarity == Polarity.YANG else 8
    return g

def bazhai_sectors(gua):
    own = GUA_TO_TRIGRAM[gua]
    return {TRIGRAMS[own ^ mask][2]: (name, cn, weight)
            for name, cn, mask, weight in RELATIONS}

def is_east_group(gua):
    return gua in (1, 3, 4, 9)

# --------------------------------------------------------------- alignment
def normalise_degrees(d):
    return d % 360.0

def signed_angular_difference(a, b):
    """Shortest signed rotation from a to b, in (-180, 180]."""
    return (b - a + 180.0) % 360.0 - 180.0

def angular_distance(a, b):
    return abs(signed_angular_difference(a, b))

def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)

def directional_value(heading, gua):
    """Continuous Ba Zhai value in [-1, 1] for an arbitrary heading."""
    sectors = bazhai_sectors(gua)
    h = normalise_degrees(heading)
    idx = int(math.floor(h / 45.0))
    t = (h - idx * 45.0) / 45.0
    v0 = sectors[(idx * 45.0) % 360.0][2]
    v1 = sectors[((idx + 1) * 45.0) % 360.0][2]
    return v0 + (v1 - v0) * smoothstep(t)

def clamp01(x):
    return max(0.0, min(1.0, x))

# Product-specific normalisation. Chosen against explicit design goals and
# measured over 8 synthetic profiles x a year x the full compass; see
# Documentation/ALIGNMENT_ENGINE.md for the goals and the measured outcome.
W_SPATIAL, W_TEMPORAL, W_PERSONAL = 0.50, 0.35, 0.15
TEMPORAL_GAIN = 1.5
UNFAVOURABLE_COMPRESSION = 0.25
BALANCE_FLOOR, BALANCE_RANGE = 0.60, 0.35

def spatial_component(heading, gua):
    """Ba Zhai direction value mapped to [0.25, 1.0].

    The mapping is deliberately asymmetric. Auspicious directions use the
    whole upper half; inauspicious directions are compressed into 0.25-0.5
    rather than running to zero. Traditional ranking is preserved exactly
    (the map is monotonic in the underlying value), but the product presents
    an unfavourable direction as unresolved, not as harmful.
    """
    if heading is None:
        return 0.5
    v = directional_value(heading, gua)
    return clamp01(0.5 + (0.5 if v >= 0 else UNFAVOURABLE_COMPRESSION) * v)

def temporal_component(natal_pillars, now_pillars):
    fav, _ = favourable_elements(natal_pillars)
    dist = element_distribution(now_pillars, MOMENT_WEIGHTS)
    share = sum(dist[e] for e in fav)
    baseline = len(fav) / 5.0
    return clamp01(0.5 + (share - baseline) * TEMPORAL_GAIN)

def personal_component(natal_pillars):
    return clamp01((natal_balance(natal_pillars) - BALANCE_FLOOR) / BALANCE_RANGE)

LEVELS = [("low", 0.0), ("unfavourable", 30.0), ("neutral", 45.0),
          ("favourable", 58.0), ("strong", 71.0), ("aligned", 84.0)]

def level_for(score):
    name = LEVELS[0][0]
    for n, threshold in LEVELS:
        if score >= threshold:
            name = n
    return name

def alignment(natal_pillars, now_pillars, gua, heading):
    sp = spatial_component(heading, gua)
    tp = temporal_component(natal_pillars, now_pillars)
    pe = personal_component(natal_pillars)
    score = 100.0 * (W_SPATIAL * sp + W_TEMPORAL * tp + W_PERSONAL * pe)
    dist = element_distribution(now_pillars, MOMENT_WEIGHTS)
    return {
        "score": score, "level": level_for(score),
        "spatial": sp, "temporal": tp, "personal": pe,
        "dominantElement": max(dist, key=lambda k: dist[k]),
    }
