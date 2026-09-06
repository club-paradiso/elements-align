"""
Elements, Align. — reference oracle.

Purpose
-------
This is NOT product code. It is an independent second implementation of the
deterministic maths that ElementsCore implements in Swift, written so that:

  1. the astronomy can be validated against externally published values
     (equinox / solstice instants) before it is trusted, and
  2. golden fixtures can be generated for the Swift test suite, so those
     tests assert against reference data rather than against themselves.

Sources
-------
* Solar position: Jean Meeus, "Astronomical Algorithms", 2nd ed., ch. 25
  (low-accuracy apparent solar longitude, stated accuracy ~0.01 deg).
* Delta-T: Espenak & Meeus polynomial expressions, 2005-2050 branch.
* Day pillar: stem = (JDN - 1) mod 10, branch = (JDN + 1) mod 12, both
  0-based here. Cross-checked against two independent published statements
  of the same formula (see Documentation/TRADITIONAL_SYSTEMS.md).
* Ba Zhai: derived from the classical 變爻 (changing-line) rule rather than
  copied from a table; see trigram XOR model below.
"""

import math, json, datetime

DEG = math.pi / 180.0

# ---------------------------------------------------------------- calendar

def gregorian_to_jd(y, m, d_frac):
    """Meeus ch. 7. d_frac may carry a fractional day. Gregorian calendar."""
    if m <= 2:
        y -= 1
        m += 12
    a = y // 100
    b = 2 - a + a // 4
    return (math.floor(365.25 * (y + 4716)) + math.floor(30.6001 * (m + 1))
            + d_frac + b - 1524.5)

def jd_to_gregorian(jd):
    """Meeus ch. 7 inverse. Returns (y, m, day_with_fraction)."""
    jd += 0.5
    z = math.floor(jd)
    f = jd - z
    if z < 2299161:
        a = z
    else:
        alpha = math.floor((z - 1867216.25) / 36524.25)
        a = z + 1 + alpha - math.floor(alpha / 4)
    b = a + 1524
    c = math.floor((b - 122.1) / 365.25)
    d = math.floor(365.25 * c)
    e = math.floor((b - d) / 30.6001)
    day = b - d - math.floor(30.6001 * e) + f
    month = e - 1 if e < 14 else e - 13
    year = c - 4716 if month > 2 else c - 4715
    return int(year), int(month), day

def jdn_for_date(y, m, d):
    """Integer Julian Day Number of the *noon* belonging to civil date y-m-d."""
    return int(math.floor(gregorian_to_jd(y, m, d + 0.5)))

def delta_t_seconds(year, month):
    """Espenak & Meeus polynomial. We only need 1900-2100 for this product."""
    y = year + (month - 0.5) / 12.0
    if 1900 <= y < 1920:
        t = y - 1900
        return (-2.79 + 1.494119 * t - 0.0598939 * t**2
                + 0.0061966 * t**3 - 0.000197 * t**4)
    if 1920 <= y < 1941:
        t = y - 1920
        return 21.20 + 0.84493 * t - 0.076100 * t**2 + 0.0020936 * t**3
    if 1941 <= y < 1961:
        t = y - 1950
        return 29.07 + 0.407 * t - t**2 / 233 + t**3 / 2547
    if 1961 <= y < 1986:
        t = y - 1975
        return 45.45 + 1.067 * t - t**2 / 260 - t**3 / 718
    if 1986 <= y < 2005:
        t = y - 2000
        return (63.86 + 0.3345 * t - 0.060374 * t**2 + 0.0017275 * t**3
                + 0.000651814 * t**4 + 0.00002373599 * t**5)
    if 2005 <= y < 2050:
        t = y - 2000
        return 62.92 + 0.32217 * t + 0.005589 * t**2
    if 2050 <= y <= 2150:
        return -20 + 32 * ((y - 1820) / 100.0)**2 - 0.5628 * (2150 - y)
    t = (y - 1820) / 100.0
    return -20 + 32 * t * t

# ------------------------------------------------------------- solar model

def apparent_solar_longitude(jde):
    """Apparent geocentric longitude of the Sun in degrees [0,360).

    Meeus ch. 25, low-accuracy series. `jde` is a Julian Ephemeris Day
    (i.e. in Terrestrial Time, not UT).
    """
    t = (jde - 2451545.0) / 36525.0
    l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
    m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
    mr = m * DEG
    c = ((1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(mr)
         + (0.019993 - 0.000101 * t) * math.sin(2 * mr)
         + 0.000289 * math.sin(3 * mr))
    true_long = l0 + c
    omega = 125.04 - 1934.136 * t
    apparent = true_long - 0.00569 - 0.00478 * math.sin(omega * DEG)
    return apparent % 360.0

def solve_solar_longitude(target_deg, guess_jde):
    """Find the JDE at which apparent solar longitude == target_deg.

    Newton iteration on the ~0.9856 deg/day mean motion, with angle
    wraparound handled by folding the residual into (-180, 180].
    """
    jde = guess_jde
    for _ in range(60):
        diff = (apparent_solar_longitude(jde) - target_deg + 180.0) % 360.0 - 180.0
        if abs(diff) < 1e-9:
            break
        jde -= diff / 0.9856473
    return jde

# The 24 solar terms. Index 0 is 立春 (Lichun) at 315 deg, which is where the
# BaZi year and the 寅 month begin. Terms alternate 節 (jie, month-defining)
# and 氣 (qi, mid-month); only the 節 terms start a BaZi month.
SOLAR_TERMS = [
    ("Lichun",      "立春", 315), ("Yushui",      "雨水", 330),
    ("Jingzhe",     "驚蟄", 345), ("Chunfen",     "春分",   0),
    ("Qingming",    "清明",  15), ("Guyu",        "穀雨",  30),
    ("Lixia",       "立夏",  45), ("Xiaoman",     "小滿",  60),
    ("Mangzhong",   "芒種",  75), ("Xiazhi",      "夏至",  90),
    ("Xiaoshu",     "小暑", 105), ("Dashu",       "大暑", 120),
    ("Liqiu",       "立秋", 135), ("Chushu",      "處暑", 150),
    ("Bailu",       "白露", 165), ("Qiufen",      "秋分", 180),
    ("Hanlu",       "寒露", 195), ("Shuangjiang", "霜降", 210),
    ("Lidong",      "立冬", 225), ("Xiaoxue",     "小雪", 240),
    ("Daxue",       "大雪", 255), ("Dongzhi",     "冬至", 270),
    ("Xiaohan",     "小寒", 285), ("Dahan",       "大寒", 300),
]
# The 12 month-defining 節 terms are the even indices above.
JIE_INDICES = list(range(0, 24, 2))

def solar_term_jd_ut(year, term_index):
    """UT Julian Day of the given solar term, for the term occurring in `year`."""
    lon = SOLAR_TERMS[term_index][2]
    # Approximate day-of-year: solar longitude 0 is ~20 March (JD ~ Mar 20).
    approx_doy = ((lon - 280.0) % 360.0) * 365.2422 / 360.0
    guess = gregorian_to_jd(year, 1, 1.0) + approx_doy
    jde = solve_solar_longitude(lon, guess)
    y, m, _ = jd_to_gregorian(jde)
    return jde - delta_t_seconds(y, m) / 86400.0

def jd_to_iso_utc(jd):
    y, m, d = jd_to_gregorian(jd)
    day = int(math.floor(d))
    frac = d - day
    secs = frac * 86400.0
    # round to nearest second
    secs = round(secs)
    hh = int(secs // 3600) % 24
    mm = int((secs % 3600) // 60)
    ss = int(secs % 60)
    if secs >= 86400:
        base = datetime.datetime(y, m, day) + datetime.timedelta(days=1)
        y, m, day = base.year, base.month, base.day
        hh = mm = ss = 0
    return "%04d-%02d-%02dT%02d:%02d:%02dZ" % (y, m, day, hh, mm, ss)
