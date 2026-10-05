#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_puddle_water.py - consistency tests of the road puddle (liquid water) path
of the cbs scheme of TEB-MSU.

The cbs scheme splits the road energy/moisture exchange into a canyon branch
(weight tau) and a forcing-level branch (weight 1 - tau). This script checks,
on the CSV diagnostics of an offline run (columns added by the puddle-diagnostics
revision: PAC_ROAD_WAT, PAC_ROAD_ATM_WAT, PDN_RD, LE_ROAD_WAT, LE_ROAD_SNOW,
WS_ROAD):

1. tau decomposition of the actual road fluxes:
       H_ROAD   = tau*H_ROAD_CAN   + (1-tau)*H_ROAD_ATM
       LE_ROAD  = tau*LE_ROAD_CAN  + (1-tau)*LE_ROAD_ATM
   (exact by construction, checked with the effective tau inferred from LE).

2. single-bucket water limitation of the road reservoir (both branches share the
   same available water):
       PAC_ROAD_WAT/PAC_ROAD_CAN == PAC_ROAD_ATM_WAT/PAC_ROAD_ATM
   and, when the aggregate limit is active (factor f < 1), the actual liquid
   latent flux saturates at the available water:
       LE_ROAD == ZLE_MAX = WS_ROAD(t-1)/dt * XLVTT

3. water budget of the road puddle + road snow (combined, the melt is internal):
       d(WS_ROAD + WSNOW_RD) + runoff = rain + snowfall - LE_ROAD_WAT/XLVTT
                                           - LE_ROAD_SNOW/XLSTT
   evaluated on rain-free hours with WS_ROAD below the effective capacity
   (1 mm * (1 - PDN_RD)), where runoff vanishes; the residual is reported for
   both the fixed (LE_ROAD_WAT) and the production (LE_ROAD) liquid drains.

Usage:
    python check_puddle_water.py <csv> [--dt SECONDS] [--diff <other csv>]
"""

import argparse
import sys

import numpy as np
import pandas as pd

XLVTT = 2.5008e6          # vaporization heat constant of the model (J/kg)
XLSTT = 2.8345e6          # sublimation heat constant of the model (J/kg)
WS_ROAD_CAP = 1.0         # maximum deepness of the road water reservoir (mm)
TOL_TAU = 1e-6            # W/m2 - tau decomposition residual
TOL_FRAC = 1e-9           # factor equality (relative)
TOL_LIM = 1e-6            # reservoir limit (relative)


def effective_tau(d):
    """tau inferred from the LE_ROAD decomposition (uses the exported columns)."""
    den = d['LE_ROAD_CAN'].values - d['LE_ROAD_ATM'].values
    tau = np.full(len(d), np.nan)
    m = np.abs(den) > 1e-6
    tau[m] = (d['LE_ROAD'].values[m] - d['LE_ROAD_ATM'].values[m]) / den[m]
    return tau


def check_tau_decomposition(d):
    tau = effective_tau(d)
    res_h = d['H_ROAD'].values - (tau * d['H_ROAD_CAN'].values
                                  + (1. - tau) * d['H_ROAD_ATM'].values)
    res_le = d['LE_ROAD'].values - (tau * d['LE_ROAD_CAN'].values
                                    + (1. - tau) * d['LE_ROAD_ATM'].values)
    m = np.isfinite(res_h) & np.isfinite(res_le)
    rh = np.nanmax(np.abs(res_h[m])) if m.any() else 0.
    rl = np.nanmax(np.abs(res_le[m])) if m.any() else 0.
    ok = rh <= TOL_TAU and rl <= TOL_TAU
    return ok, rh, rl, np.nanmedian(tau)


def check_shared_limit(d):
    """Both branches must share the same water-availability factor."""
    pc = d['PAC_ROAD_CAN'].values
    pa = d['PAC_ROAD_ATM'].values
    pwc = d['PAC_ROAD_WAT'].values
    pwa = d['PAC_ROAD_ATM_WAT'].values
    with np.errstate(invalid='ignore'):
        fc = np.where(np.abs(pc) > 1e-12, pwc / np.maximum(pc, 1e-30), np.nan)
        fa = np.where(np.abs(pa) > 1e-12, pwa / np.maximum(pa, 1e-30), np.nan)
    both = np.isfinite(fc) & np.isfinite(fa)
    if not both.any():
        return True, 0., 0
    dmax = float(np.max(np.abs(fc[both] - fa[both])))
    ok = bool(np.all(np.abs(fc[both] - fa[both]) <= TOL_FRAC))
    return ok, dmax, int(both.sum())


def check_reservoir_limit(d, dt):
    """When the aggregate factor f < 1 and LE_ROAD > 0, the actual liquid latent
    flux equals the available water of the reservoir (single bucket)."""
    w = d['WS_ROAD'].shift(1).values
    zlem = w * XLVTT / dt
    pc = d['PAC_ROAD_CAN'].values
    pwc = d['PAC_ROAD_WAT'].values
    with np.errstate(invalid='ignore'):
        f = np.where(np.abs(pc) > 1e-12, pwc / np.maximum(pc, 1e-30), np.nan)
    lim = (np.isfinite(f)) & (f < 0.999999) & (d['LE_ROAD'].values > 0.) \
        & np.isfinite(zlem)
    if not lim.any():
        return True, 0., 0
    rel = np.abs(d['LE_ROAD'].values[lim] - zlem[lim]) \
        / np.maximum(1e-9, np.abs(zlem[lim]))
    return bool(np.max(rel) <= TOL_LIM), float(rel.max()), int(lim.sum())


def water_budget_residual(d, dt):
    """Combined puddle + road-snow budget on rain-free, non-full (no runoff)
    hours. Returns residuals for the corrected liquid drain (PLEW_RD, tile-mean)
    and the previous double-weighted drain (PDF_RD*PLEW_RD), with the snow mass
    taken either per tile or per snow-covered area."""
    d = d.copy()
    d['dWS'] = d['WS_ROAD'].diff()
    d['dSN1'] = d['WSNOW_RD'].diff()
    d['dSNp'] = (d['WSNOW_RD'] * d['PDN_RD']).diff()
    # runoff-free hours: the effective capacity of the road reservoir is scaled
    # by the snow-free fraction (WS_ROAD_MAX*(1-PDN_RD) in TEB), so the reservoir
    # overflows well below 1 mm when the road is snow-covered
    cap = (1.0 - d['PDN_RD'].values)
    sel = (d['Forc_RAIN'].values < 1e-9) & (d['WS_ROAD'].values < 0.999 * cap) \
        & (d['dWS'].notna().values)
    dt_ = d[sel]
    if len(dt_) < 3:
        return None
    snow_in = dt_['Forc_SNOW'].values * dt
    # the corrected code drains the puddle with the tile-mean liquid flux of the
    # road (PLEW_RD = CSV column LE_ROAD, no extra PDF_RD weight); the 'old'
    # variant PDF_RD*PLEW_RD (= (1-PDN_RD)*LE_ROAD) was the double-weighted one
    li_fixed = dt_['LE_ROAD'].values / XLVTT * dt
    li_old = dt_['LE_ROAD'].values * (1.0 - dt_['PDN_RD'].values) / XLVTT * dt
    sn_le = dt_['LE_ROAD_SNOW'].values / XLSTT * dt
    res = {}
    for kname, d_sn in (('snow_tile', dt_['dSN1'].values), ('snow_frac', dt_['dSNp'].values)):
        res[kname] = {
            'fixed_liq_PLEW_RD': float((dt_['dWS'].values + d_sn + li_fixed + sn_le - snow_in).sum()),
            'old_liq_PDF_PLEW_RD': float((dt_['dWS'].values + d_sn + li_old + sn_le - snow_in).sum()),
        }
    return res


def check_tilemean_normalization(d):
    """The road energy budget computes PLEW_RD as a tile-mean quantity (per m2 of
    road): at tau = 1 the CSV LE_ROAD (= PLEW_RD) equals LE_ROAD_CAN exactly even
    when the snow fraction is large (both carry the same 1-PDN_RD factor inside
    the flux). Under the alternative 'per m2 of snow-free road' normalization the
    ratio would be ~ 1/(1-PDN_RD) instead of ~ 1."""
    pdn = d['PDN_RD'].values
    m = (pdn > 0.3) & (np.abs(d['LE_ROAD_CAN'].values) > 0.05)
    if int(m.sum()) < 5:
        return True, float('nan'), float('nan'), 0
    ratio = d['LE_ROAD'].values[m] / d['LE_ROAD_CAN'].values[m]
    med_r = float(np.nanmedian(ratio))
    med_inv = float(np.nanmedian(1.0 / (1.0 - pdn[m])))
    ok = abs(med_r - 1.0) <= 0.15 and med_r <= 0.5 * med_inv
    return ok, med_r, med_inv, int(m.sum())


def diff_csv(d, ref, tol=1e-9):
    shr = [c for c in ref.columns if c in d.columns and c != 'time']
    bad = {}
    for c in shr:
        v = float(np.max(np.abs(d[c].values - ref[c].values)))
        if v > tol:
            bad[c] = v
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('csv')
    ap.add_argument('--dt', type=float, default=3600.,
                    help='model time step in seconds used to build the run (default 3600)')
    ap.add_argument('--diff', default=None, help='reference CSV for an A/B comparison')
    args = ap.parse_args()

    d = pd.read_csv(args.csv, sep=';')
    need = ['H_ROAD', 'H_ROAD_CAN', 'H_ROAD_ATM', 'LE_ROAD', 'LE_ROAD_CAN',
            'LE_ROAD_ATM', 'PAC_ROAD_CAN', 'PAC_ROAD_ATM', 'PAC_ROAD_WAT',
            'PAC_ROAD_ATM_WAT', 'PDN_RD', 'LE_ROAD_WAT', 'LE_ROAD_SNOW',
            'WS_ROAD', 'WSNOW_RD', 'Forc_RAIN', 'Forc_SNOW']
    missing = [c for c in need if c not in d.columns]
    if missing:
        print('FATAL: missing columns:', missing)
        sys.exit(2)

    print('file: %s' % args.csv)
    print('=' * 90)

    ok1, rh, rl, tau = check_tau_decomposition(d)
    print('T1 tau decomposition : %s  (max |res H| = %.3e  |res LE| = %.3e, eff tau = %.4g)'
          % ('PASS' if ok1 else 'FAIL', rh, rl, tau))

    ok2, dmax, n2 = check_shared_limit(d)
    print('T2 shared water limit: %s  (max |f_can - f_atm| = %.3e, n = %d)'
          % ('PASS' if ok2 else 'FAIL', dmax, n2))

    ok3, rlim, n3 = check_reservoir_limit(d, args.dt)
    if args.dt < 3600.:
        print('T3 reservoir limit   : SKIP (sub-hour steps; use --dt 3600 to check exactly)')
        n3 = 0
    else:
        print('T3 reservoir limit   : %s  (max |LE_ROAD - ZLE_MAX|/ZLE_MAX = %.3e, active rows = %d)'
              % ('PASS' if ok3 else 'FAIL', rlim, n3))

    ok5, med_r5, med_inv5, n5 = check_tilemean_normalization(d)
    if n5 == 0:
        print('T5 tile-mean LE_ROAD : SKIP (needs snow: PDN_RD > 0.3, n >= 5)')
    else:
        print('T5 tile-mean LE_ROAD : %s  (median LE_ROAD/LE_ROAD_CAN = %.3f vs 1/(1-PDN) = %.3f, n = %d)'
              % ('PASS' if ok5 else 'FAIL', med_r5, med_inv5, n5))

    res = water_budget_residual(d, args.dt)
    if args.dt < 3600.:
        print('T4 water budget      : SKIP (sub-hour steps; use --dt 3600 to close the budget exactly)')
    elif res is None:
        print('T4 water budget      : SKIP (too few runoff-free rows)')
    else:
        for k, v in res.items():
            print('T4 water budget (snow mass %s): fixed_liq(PLEW_RD) = %+.4f   old_liq(PDF*PLEW_RD) = %+.4f  kg/m2'
                  % (k, v['fixed_liq_PLEW_RD'], v['old_liq_PDF_PLEW_RD']))

    if args.diff:
        ref = pd.read_csv(args.diff, sep=';')
        bad = diff_csv(d, ref)
        print('A/B vs %s : %s'
              % (args.diff, ('mismatches: %s' % bad) if bad else 'bit-identical on shared columns'))

    ok = ok1 and ok2 and (ok3 or args.dt < 3600.) and ok5
    print('=' * 90)
    print('RESULT: %s' % ('ALL PASS' if ok else 'SOME TESTS FAILED'))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
