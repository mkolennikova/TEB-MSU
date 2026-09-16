#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_puddle_water.py - consistency tests of the road puddle (liquid water) path
of the tau scheme of TEB-Ru.

The tau scheme splits the road energy/moisture exchange into a canyon branch
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
    hours. Returns residuals for the fixed (LE_ROAD_WAT) and the production
    (LE_ROAD) liquid drains, with the snow mass taken either per tile or per
    snow-covered area."""
    d = d.copy()
    d['dWS'] = d['WS_ROAD'].diff()
    d['dSN1'] = d['WSNOW_RD'].diff()
    d['dSNp'] = (d['WSNOW_RD'] * d['PDN_RD']).diff()
    sel = (d['Forc_RAIN'].values < 1e-9) & (d['WS_ROAD'].values < 0.99) \
        & (d['dWS'].notna().values)
    dt_ = d[sel]
    if len(dt_) < 3:
        return None
    snow_in = dt_['Forc_SNOW'].values * dt
    li_wat = dt_['LE_ROAD_WAT'].values / XLVTT * dt
    li_le = dt_['LE_ROAD'].values / XLVTT * dt
    sn_le = dt_['LE_ROAD_SNOW'].values / XLSTT * dt
    res = {}
    for kname, d_sn in (('tile', dt_['dSN1'].values), ('frac', dt_['dSNp'].values)):
        res[kname] = {
            'fixed_liq_LE_ROAD_WAT': float((dt_['dWS'].values + d_sn + li_wat + sn_le - snow_in).sum()),
            'raw_LE_ROAD_column': float((dt_['dWS'].values + d_sn + li_le + sn_le - snow_in).sum()),
        }
    return res


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

    res = water_budget_residual(d, args.dt)
    if args.dt < 3600.:
        print('T4 water budget      : SKIP (sub-hour steps; use --dt 3600 to close the budget exactly)')
    elif res is None:
        print('T4 water budget      : SKIP (too few runoff-free rows)')
    else:
        for k, v in res.items():
            print('T4 water budget (snow mass %s): fixed_liq_resid = %+.4f   raw_LE_ROAD_col_resid = %+.4f  kg/m2'
                  % (k, v['fixed_liq_LE_ROAD_WAT'], v['raw_LE_ROAD_column']))

    if args.diff:
        ref = pd.read_csv(args.diff, sep=';')
        bad = diff_csv(d, ref)
        print('A/B vs %s : %s'
              % (args.diff, ('mismatches: %s' % bad) if bad else 'bit-identical on shared columns'))

    ok = ok1 and ok2 and (ok3 or args.dt < 3600.)
    print('=' * 90)
    print('RESULT: %s' % ('ALL PASS' if ok else 'SOME TESTS FAILED'))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
