"""
Generate a truncated VSOP87 solar-longitude table as Swift source.

Provenance
----------
Coefficients are NOT hand-typed. They are read programmatically from the
PyMeeus distribution's VSOP87 tables for Earth (pymeeus.Earth.VSOP87_L /
VSOP87_R) and its IAU 1980 nutation series (pymeeus.Coordinates), then
truncated by amplitude and emitted as Swift. The truncation error is
measured against the untruncated series before the file is written.

Run:  python3 gen_vsop87.py <path-to-pymeeus-src> <output.swift>
"""
import sys, math, datetime

PYMEEUS_SRC = sys.argv[1]
OUT = sys.argv[2]
sys.path.insert(0, PYMEEUS_SRC)

from pymeeus.Earth import VSOP87_L, VSOP87_R
from pymeeus.Coordinates import (NUTATION_ARG_TABLE, NUTATION_SINE_COEF_TABLE)
from pymeeus.Sun import Sun
from pymeeus.Epoch import Epoch

ARCSEC = 1.0 / 3600.0

# --- truncation thresholds (units of 1e-8 rad for L, 1e-8 AU for R) --------
# 1 arcsec = 4.8481e-6 rad = 484.81 units. A threshold of 20 units keeps every
# term worth more than ~0.004 arcsec individually.
L_THRESHOLD = 20.0
R_THRESHOLD = 300.0

def truncate(series, threshold):
    return [[t for t in s if abs(t[0]) >= threshold] for s in series]

L_T = truncate(VSOP87_L, L_THRESHOLD)
R_T = truncate(VSOP87_R, R_THRESHOLD)

def series_value(series, tau):
    total = 0.0
    for k, terms in enumerate(series):
        s = sum(a * math.cos(b + c * tau) for a, b, c in terms)
        total += s * (tau ** k)
    return total * 1e-8

def nutation_longitude_deg(t):
    """Delta psi in degrees. t = Julian centuries TT from J2000."""
    d = 297.85036 + t * (445267.111480 + t * (-0.0019142 + t / 189474.0))
    m = 357.52772 + t * (35999.050340 + t * (-0.0001603 - t / 300000.0))
    mp = 134.96298 + t * (477198.867398 + t * (0.0086972 + t / 56250.0))
    f = 93.27191 + t * (483202.017538 + t * (-0.0036825 + t / 327270.0))
    om = 125.04452 + t * (-1934.136261 + t * (0.0020708 + t / 450000.0))
    args = [d, m, mp, f, om]
    dpsi = 0.0
    for i, (c0, c1) in enumerate(NUTATION_SINE_COEF_TABLE):
        arg = sum(NUTATION_ARG_TABLE[i][j] * args[j] for j in range(5))
        dpsi += (c0 + c1 * t) * math.sin(math.radians(arg))
    return (dpsi / 10000.0) * ARCSEC

def apparent_sun_longitude(jde, L=L_T, R=R_T):
    """Our model: apparent geocentric solar longitude in degrees [0,360)."""
    tau = (jde - 2451545.0) / 365250.0          # Julian millennia
    t = (jde - 2451545.0) / 36525.0             # Julian centuries
    lon_rad = series_value(L, tau)
    r = series_value(R, tau)
    lon = math.degrees(lon_rad) % 360.0
    lon += 180.0                                 # heliocentric Earth -> geocentric Sun
    # FK5 correction. The latitude-dependent part is < 0.00001 arcsec for the
    # Sun (Earth's heliocentric latitude is under 1 arcsec) and is dropped.
    lon += -0.09033 * ARCSEC
    lon += nutation_longitude_deg(t)
    lon += -20.4898 * ARCSEC / r                 # annual aberration
    return lon % 360.0, r

# ---------------------------------------------------------------- validate
def truth(jde):
    l, b, r = Sun.apparent_geocentric_position(Epoch(jde))
    return float(l) % 360.0

def ang_err(a, b):
    return abs((a - b + 180.0) % 360.0 - 180.0)

worst = 0.0
worst_at = None
jd0 = 2415020.0   # 1900-01-01
jd1 = 2488070.0   # 2100-01-01
n = 4000
for i in range(n):
    jde = jd0 + (jd1 - jd0) * i / (n - 1)
    e = ang_err(apparent_sun_longitude(jde)[0], truth(jde))
    if e > worst:
        worst, worst_at = e, jde

# Also check the untruncated series through our own pipeline, to separate
# truncation error from pipeline error.
worst_full = 0.0
for i in range(400):
    jde = jd0 + (jd1 - jd0) * i / 399
    worst_full = max(worst_full, ang_err(
        apparent_sun_longitude(jde, VSOP87_L, VSOP87_R)[0], truth(jde)))

kept_l = sum(len(s) for s in L_T)
kept_r = sum(len(s) for s in R_T)
full_l = sum(len(s) for s in VSOP87_L)
full_r = sum(len(s) for s in VSOP87_R)
print("L terms kept %d/%d, R terms kept %d/%d, nutation terms %d"
      % (kept_l, full_l, kept_r, full_r, len(NUTATION_SINE_COEF_TABLE)))
print("worst error 1900-2100 (truncated pipeline vs PyMeeus full VSOP87): %.4f arcsec"
      % (worst / ARCSEC))
print("  -> equivalent solar-term timing error: %.1f seconds"
      % (worst / 0.9856473 * 86400.0))
print("worst error with UNtruncated series through same pipeline: %.4f arcsec"
      % (worst_full / ARCSEC))

if worst / ARCSEC > 5.0:
    sys.exit("Truncation error too large; lower the threshold.")

# ------------------------------------------------------------------ emit
def swift_terms(series):
    out = []
    for terms in series:
        rows = ",\n".join("        T(%.6f, %.10f, %.10f)" % (a, b, c) for a, b, c in terms)
        out.append("    [\n%s\n    ]" % rows)
    return ",\n".join(out)

nut_rows = ",\n".join(
    "    N(%d, %d, %d, %d, %d, %.1f, %.1f)" % (
        NUTATION_ARG_TABLE[i][0], NUTATION_ARG_TABLE[i][1], NUTATION_ARG_TABLE[i][2],
        NUTATION_ARG_TABLE[i][3], NUTATION_ARG_TABLE[i][4],
        NUTATION_SINE_COEF_TABLE[i][0], NUTATION_SINE_COEF_TABLE[i][1])
    for i in range(len(NUTATION_SINE_COEF_TABLE)))

header = '''// Generated by Tools/oracle/gen_vsop87.py — DO NOT EDIT BY HAND.
//
// Truncated VSOP87 series for the Earth's heliocentric longitude and radius
// vector, plus the IAU 1980 nutation-in-longitude series. Coefficients are
// extracted programmatically from the PyMeeus distribution's VSOP87 tables
// rather than transcribed, so there is no hand-copying error path.
//
// Truncation was validated against the untruncated series over 1900-2100:
//   L terms kept: %d of %d
//   R terms kept: %d of %d
//   worst-case apparent-longitude error: %.3f arcsec
//   equivalent solar-term timing error: %.1f seconds
//
// Generated: %s

import Foundation

/// One periodic term of a VSOP87 series: amplitude * cos(phase + frequency * tau).
struct VSOPTerm: Sendable {
    let amplitude: Double
    let phase: Double
    let frequency: Double
    init(_ amplitude: Double, _ phase: Double, _ frequency: Double) {
        self.amplitude = amplitude
        self.phase = phase
        self.frequency = frequency
    }
}

/// One term of the IAU 1980 nutation-in-longitude series.
struct NutationTerm: Sendable {
    let d: Int, m: Int, mPrime: Int, f: Int, omega: Int
    let coefficient: Double
    let coefficientRate: Double
    init(_ d: Int, _ m: Int, _ mPrime: Int, _ f: Int, _ omega: Int,
         _ coefficient: Double, _ coefficientRate: Double) {
        self.d = d; self.m = m; self.mPrime = mPrime; self.f = f; self.omega = omega
        self.coefficient = coefficient; self.coefficientRate = coefficientRate
    }
}

enum VSOP87Earth {
    typealias T = VSOPTerm
    typealias N = NutationTerm

    /// Heliocentric longitude series L0...L5, in units of 1e-8 radian.
    static let longitude: [[VSOPTerm]] = [
%s
    ]

    /// Radius-vector series R0...R%d, in units of 1e-8 AU.
    static let radius: [[VSOPTerm]] = [
%s
    ]

    /// IAU 1980 nutation in longitude, coefficients in units of 0.0001 arcsec.
    static let nutation: [NutationTerm] = [
%s
    ]
}
''' % (kept_l, full_l, kept_r, full_r, worst / ARCSEC, worst / 0.9856473 * 86400.0,
       datetime.date.today().isoformat(),
       swift_terms(L_T), len(R_T) - 1, swift_terms(R_T), nut_rows)

with open(OUT, "w") as fh:
    fh.write(header)
print("wrote", OUT)
