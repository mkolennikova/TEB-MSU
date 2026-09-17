#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_solar_position.py - validation of the solar position that TEB-Ru uses, on
the CSV diagnostics of an offline run (columns SOLAR_ZENITH, SOLAR_ELEV,
SOLAR_AZIM added by the solar-position revision of RUN_TEB_OFFLINE).

The model computes the solar zenith/azimuth angles with SUNPOS (simplified
declination / equation of time of Paltridge and Platt, 1976) from the start date
of the forcing namelist. A wrong date (e.g. the namelist items teb_year /
teb_month / teb_day written with a decimal point, which silently made every later
item keep its default value) used to be invisible in the output; these columns and
this test make it visible: the daily maximum elevation is a strong function of the
season (Moscow: ~48 deg in early August, ~13.5 deg in January).

Tests (all on the model output, compared with the independent pysolar library):
  1. internal consistency: SOLAR_ELEV = 90 - SOLAR_ZENITH, columns defined;
  2. elevation: model vs pysolar (geometric altitude, refraction excluded);
  3. azimuth: model vs pysolar, for hours with elevation > 5 deg (the azimuth of
     a low sun is ill-conditioned);
  4. daily statistics: maximum elevation and day length (hours with elevation > 0)
     of the model vs pysolar, day by day, plus the analytic value of the maximum
     elevation of the day (90 - |latitude - declination|);
  5. optional (--forcing-nml): the first timestamp of the CSV is the start date of
     the namelist + one forcing step (the timestamp convention of the output).

What the tests can and cannot detect:
  * T2/T3/T4 validate the IMPLEMENTATION of the solar position (SUNPOS against
    pysolar) and report the seasonal fingerprint (the daily maximum elevation of
    the period: ~52 deg on 2022-08-01, ~47.6 deg on average in August, ~11 deg on
    2024-01-01 in Moscow). They compare the model with pysolar AT THE TIMESTAMPS
    OF THE CSV, so a wrong date that is consistently used everywhere (model and
    timestamps) is geometrically correct and is not flagged - it is visible only
    as an unexpected season in the fingerprint table;
  * T5 closes that hole for the pipeline: it checks the first timestamp of the CSV
    against the start date of the forcing namelist (the date the Python tools wrote
    from the forcing data), so a run that silently used another date (e.g. the old
    default 2004-02 because the INTEGER items of the namelist were written with a
    decimal point and the READ stopped on them) fails loudly.
  The driver itself refuses such a namelist since the strict-reading revision
  (start date/time items are required and validated, no default date).

Measured agreement with pysolar 0.13 (Moscow cases, summer and winter):
  elevation <= 0.26 deg (mean ~0.17), azimuth <= 0.25 deg, daily maximum <= 0.23 deg,
  analytic 90 - |lat - declination| (pysolar simple declination) <= 0.65 deg - the
  differences come from the simplified declination / equation of time of SUNPOS, so
  the thresholds below (0.5, 1.0, 1.0 deg) leave a margin for the approximations
  while still failing on any real error of the geometry (degrees to tens of degrees).

Usage:
    python check_solar_position.py <csv> [--lat DEG] [--lon DEG]
                                   [--tol-elev DEG] [--tol-azim DEG]
                                   [--forcing-nml FILE] [--plot FIGURE]
Examples:
    python check_solar_position.py D:/TEB_work/Moscow/compare_tau_scheme/output_LCZ2_w0/TEB_output.csv
    python check_solar_position.py out.csv --lat 55.7 --lon 37.5 --plot solar.png
"""
from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pysolar.solar as ps

XUNDEF = 1e19
SEP = ';'


def read_output(path: Path) -> pd.DataFrame:
    """CSV of a TEB-Ru offline run: numeric columns, XUNDEF masked to NaN."""
    d = pd.read_csv(path, sep=SEP)
    num = d.select_dtypes(include='number').columns
    d[num] = d[num].mask(d[num] >= XUNDEF)
    return d


def solar_series(d: pd.DataFrame, lat: float, lon: float):
    """pysolar elevation (geometric and refracted) and azimuth for every row."""
    times = pd.to_datetime(d['time'], utc=True)
    alt = np.full(len(d), np.nan)
    refr = np.full(len(d), np.nan)
    azim = np.full(len(d), np.nan)
    for i, ts in enumerate(times):
        when = ts.to_pydatetime()
        topo = ps.get_altitude(lat, lon, when, pressure=0.)       # geometric
        alt[i] = topo
        refr[i] = ps.get_altitude(lat, lon, when)                  # + refraction
        azim[i] = ps.get_azimuth(lat, lon, when) % 360.
    return alt, refr, azim


def ps_max_fine(lat: float, lon: float, t_center, half_minutes: int = 30) -> float:
    """pysolar maximum elevation around a given moment (1-minute resolution)."""
    best = -90.
    for k in range(-half_minutes, half_minutes + 1):
        when = (t_center + pd.Timedelta(minutes=k)).to_pydatetime()
        best = max(best, ps.get_altitude(lat, lon, when, pressure=0.))
    return best


def check_internal(d: pd.DataFrame):
    """T1: SOLAR_ELEV = 90 - SOLAR_ZENITH and the columns are defined."""
    need = ['SOLAR_ZENITH', 'SOLAR_ELEV', 'SOLAR_AZIM']
    miss = [c for c in need if c not in d.columns]
    if miss:
        return False, 'missing columns: %s' % ', '.join(miss), 0
    z = d['SOLAR_ZENITH'].values
    e = d['SOLAR_ELEV'].values
    bad = ~np.isfinite(z) | ~np.isfinite(e) | ~np.isfinite(d['SOLAR_AZIM'].values)
    res = np.nanmax(np.abs(z + e - 90.)) if np.isfinite(z).any() else np.nan
    return (not bad.any()) and (res <= 1e-6), res, int(bad.sum())


def check_elevation(d: pd.DataFrame, alt: np.ndarray, tol: float):
    """T2: model elevation vs pysolar geometric elevation."""
    dif = d['SOLAR_ELEV'].values - alt
    mx = float(np.nanmax(np.abs(dif)))
    return mx <= tol, mx, float(np.nanmean(np.abs(dif)))


def check_azimuth(d: pd.DataFrame, azim: np.ndarray, tol: float):
    """T3: model azimuth vs pysolar azimuth, sun above 5 deg only."""
    sel = d['SOLAR_ELEV'].values > 5.
    if sel.sum() == 0:
        return True, np.nan, 0
    dif = (d['SOLAR_AZIM'].values[sel] - azim[sel] + 180.) % 360. - 180.
    mx = float(np.nanmax(np.abs(dif)))
    return mx <= tol, mx, int(sel.sum())


def check_daily(d: pd.DataFrame, alt: np.ndarray, lat: float, lon: float):
    """T4: daily maximum elevation and day length, model vs pysolar.

    The model and the reference are compared at the same (hourly) timestamps, so
    the two maxima are directly comparable. In addition the true maximum of the
    day is computed with pysolar at 1-minute resolution around the model maximum
    and compared with the analytic value 90 - |latitude - declination|.
    """
    ts = pd.to_datetime(d['time'], utc=True)
    grp = ts.dt.floor('D').values
    e_mod = d['SOLAR_ELEV'].values
    rows = []
    for dd in pd.unique(grp):
        m = grp == dd
        em = e_mod[m]
        er = alt[m]
        tt = ts[m]
        imax = int(np.nanargmax(em))
        tmax = tt.iloc[imax]
        fine = ps_max_fine(lat, lon, tmax)
        doy = tmax.timetuple().tm_yday + (tmax.hour + tmax.minute / 60.) / 24.
        dec = ps.get_declination(doy)
        rows.append((pd.Timestamp(dd), float(em[imax]), float(np.nanmax(er)), float(fine),
                     float(90. - abs(lat - dec)), int((em > 0).sum()), int((er > 0).sum())))
    tab = pd.DataFrame(rows, columns=['day', 'elev_mod', 'elev_ps', 'elev_ps_fine',
                                      'elev_analytic', 'h_up_mod', 'h_up_ps'])
    dmax = float(np.nanmax(np.abs(tab['elev_mod'] - tab['elev_ps'])))
    dlen = float(np.nanmax(np.abs(tab['h_up_mod'] - tab['h_up_ps'])))
    dana = float(np.nanmax(np.abs(tab['elev_ps_fine'] - tab['elev_analytic'])))
    return tab, dmax, dlen, dana


def check_start_date(d: pd.DataFrame, nml: Path):
    """T5: first timestamp of the CSV = start date of the namelist + forc_step."""
    txt = nml.read_text(encoding='utf-8', errors='ignore')

    def item(name):
        m = re.search(r'^\s*%s\s*=\s*([^,\n/!]+)' % name, txt, re.M | re.I)
        if m is None:
            raise SystemExit('ERROR: item %s not found in %s' % (name, nml))
        v = m.group(1).strip()
        if re.match(r'^[+-]?\d+\.\d*$', v):
            print('   WARNING: %s = %s is written as a REAL value, but it is an '
                  'INTEGER namelist item (write it without a decimal point)'
                  % (name, v))
        return int(float(v))

    t0 = dt.datetime(item('teb_year'), item('teb_month'), item('teb_day'),
                     item('teb_hour'), item('teb_min'), tzinfo=dt.timezone.utc)
    m = re.search(r'^\s*forc_step\s*=\s*([^,\n/!]+)', txt, re.M | re.I)
    step = float(m.group(1))
    first = pd.to_datetime(d['time'], utc=True).iloc[0].to_pydatetime()
    return first == t0 + dt.timedelta(seconds=step), t0, t0 + dt.timedelta(seconds=step), first


def make_plot(tab: pd.DataFrame, d: pd.DataFrame, lat: float, lon: float, fig: Path):
    """Model vs pysolar elevation: first day (hourly) and daily maxima."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    tser = pd.to_datetime(d['time'], utc=True)
    sub = d[tser.dt.floor('D') == tser.dt.floor('D').iloc[0]]
    alt, _, _ = solar_series(sub, lat, lon)
    t = pd.to_datetime(sub['time'], utc=True)
    hh = t.dt.hour + t.dt.minute / 60.
    _, ax = plt.subplots(2, 1, figsize=(9, 7))
    ax[0].plot(hh, sub['SOLAR_ELEV'].values, 'o-', label='TEB-Ru (SUNPOS)')
    ax[0].plot(hh, alt, 'x--', label='pysolar (geometric)')
    ax[0].axhline(0., color='k', lw=0.5)
    ax[0].set_title('solar elevation, %s' % t.dt.date.iloc[0])
    ax[0].set_xlabel('hour UTC')
    ax[0].set_ylabel('elevation (deg)')
    ax[0].legend()
    ax[0].grid(alpha=0.3)
    ax[1].plot(tab['day'], tab['elev_mod'], 'o-', label='TEB-Ru (SUNPOS)')
    ax[1].plot(tab['day'], tab['elev_ps'], 'x--', label='pysolar (geometric)')
    ax[1].plot(tab['day'], tab['elev_analytic'], ':', label='90 - |lat - decl|')
    ax[1].set_title('maximum elevation of the day')
    ax[1].set_ylabel('elevation (deg)')
    ax[1].legend()
    ax[1].grid(alpha=0.3)
    plt.gcf().tight_layout()
    plt.gcf().savefig(fig, dpi=120)
    print('   figure written to %s' % fig)

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('csv', help='TEB_output.csv of an offline run')
    ap.add_argument('--lat', type=float, default=55.7, help='latitude (deg), default %(default)s')
    ap.add_argument('--lon', type=float, default=37.5, help='longitude (deg), default %(default)s')
    ap.add_argument('--tol-elev', type=float, default=0.5,
                    help='tolerance on the elevation (deg), default %(default)s')
    ap.add_argument('--tol-azim', type=float, default=1.0,
                    help='tolerance on the azimuth (deg), default %(default)s')
    ap.add_argument('--forcing-nml', default=None,
                    help='forcing namelist (start date check, test 5)')
    ap.add_argument('--plot', default=None, help='save a figure of the comparison')
    args = ap.parse_args()

    path = Path(args.csv)
    d = read_output(path)
    print('=' * 90)
    print('file: %s' % path)
    print('period: %s .. %s  (%d rows, lat = %.3f, lon = %.3f)'
          % (d['time'].iloc[0], d['time'].iloc[-1], len(d), args.lat, args.lon))
    print('-' * 90)

    ok1, res1, nbad = check_internal(d)
    if isinstance(res1, str):
        print('T1 internal consistency : FAIL  (%s)' % res1)
    else:
        print('T1 internal consistency : %s  (max |SOLAR_ZENITH + SOLAR_ELEV - 90| = %.3e,'
              ' undefined values = %d)' % ('PASS' if ok1 else 'FAIL', res1, nbad))

    alt, refr, azim = solar_series(d, args.lat, args.lon)

    ok2, mx2, mean2 = check_elevation(d, alt, args.tol_elev)
    print('T2 elevation vs pysolar : %s  (max |d| = %.4f deg, mean |d| = %.4f deg,'
          ' tol = %.2f; max |d| to the refracted altitude = %.4f deg)'
          % ('PASS' if ok2 else 'FAIL', mx2, mean2, args.tol_elev,
             float(np.nanmax(np.abs(d['SOLAR_ELEV'].values - refr)))))

    ok3, mx3, n3 = check_azimuth(d, azim, args.tol_azim)
    print('T3 azimuth vs pysolar   : %s  (max |d| = %.4f deg, n = %d rows with'
          ' elevation > 5 deg, tol = %.2f)' % ('PASS' if ok3 else 'FAIL', mx3, n3,
                                               args.tol_azim))

    tab, dmax, dlen, dana = check_daily(d, alt, args.lat, args.lon)
    ok4 = (dmax <= args.tol_elev) and (dlen <= 1.01) and (dana <= 1.0)
    print('T4 daily max / daylength: %s  (max |d max elev| = %.4f deg, max |d daylight|'
          ' = %.2f h, max |analytic - pysolar(1 min)| = %.4f deg)'
          % ('PASS' if ok4 else 'FAIL', dmax, dlen, dana))
    print('   daily maximum elevation (model / pysolar hourly / pysolar 1-min /'
          ' analytic 90-|lat-decl|):')
    show = [0, 1, len(tab) // 2, len(tab) - 2, len(tab) - 1]
    for i in sorted(set(i for i in show if 0 <= i < len(tab))):
        r = tab.iloc[i]
        print('     %s %7.3f %7.3f %7.3f %7.3f   daylight %2d h / %2d h'
              % (r['day'].date(), r['elev_mod'], r['elev_ps'], r['elev_ps_fine'],
                 r['elev_analytic'], r['h_up_mod'], r['h_up_ps']))
    print('   mean daily maximum over the period: model %.3f deg, pysolar %.3f deg'
          % (tab['elev_mod'].mean(), tab['elev_ps'].mean()))

    ok5 = True
    if args.forcing_nml:
        ok5, t0, expect, first = check_start_date(d, Path(args.forcing_nml))
        print('T5 start date of the run : %s  (namelist start %s, expected first'
              ' timestamp %s, found %s)'
              % ('PASS' if ok5 else 'FAIL', t0.strftime('%Y-%m-%d %H:%M'),
                 expect.strftime('%Y-%m-%d %H:%M'), first.strftime('%Y-%m-%d %H:%M')))
    else:
        print('T5 start date of the run : SKIP (use --forcing-nml to check it)')

    if args.plot:
        make_plot(tab, d, args.lat, args.lon, Path(args.plot))

    ok = ok1 and ok2 and ok3 and ok4 and ok5
    print('=' * 90)
    print('RESULT: %s' % ('ALL PASS' if ok else 'SOME TESTS FAILED'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())