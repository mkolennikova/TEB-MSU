#!/usr/bin/env python
"""Checks of the pedestrian MRT scheme on the road (MV202610).

The scheme (``docs/TEB_MSU_MRT_pedestrian_scheme.md``, ``src_teb/urban_mrt.F90``)
computes the mean radiant temperature of a person standing on the road at the
canyon axis (``z = 1.1 m``, body = sphere) from the radiative fluxes of the
current sub-step. The diagnostic writes the two physical outputs ``MRT_ROAD``
(beam weighted by the sunlit area fraction of the road) and ``MRT_ROAD_SUN``
(full beam) plus its components, so the whole budget can be recomputed here
from the CSV alone: the incident shortwave components of the road
(``SW_DIR_ROAD``, ``SW_WALL_ROAD``, ``SW_TOT_ROAD``), the surface temperatures,
the sky longwave and the solar position.

Checks
------
M1  view factors: ``MRT_F_SKY``/``MRT_F_WALL``/``MRT_F_ROAD`` equal the analytic
    2D-canyon values of the scheme document and sum to one;
M2  shortwave identity at road level:
    ``SW_DIR_ROAD + SW_SKY_ROAD + SW_WALL_ROAD = SW_TOT_ROAD``
    (the three incident components of the road sum to its total incident
    shortwave, the quantity the pedestrian road-reflection term is built on);
M3  ``MRT_ROAD`` and ``MRT_ROAD_SUN`` recomputed from the output columns agree
    with the model (snow-free rows only: the snow albedo and emissivity are not
    written, see the document);
M4  no sun on the road: ``MRT_ROAD = MRT_ROAD_SUN`` exactly;
M5  ``MRT_ROAD_SUN >= MRT_ROAD`` (the sunlit variant adds beam energy);
M6  night bounds: the MRT lies between the coldest and the warmest emitter the
    pedestrian sees (the view-factor mean of the emitted irradiances
    ``eps*sigma*T^4`` of the sky, the walls and the road);
M7  the scheme is not inert: there are rows with ``MRT_ROAD_SUN - MRT_ROAD``
    materially positive;
M8  physical range: ``150 K < MRT < 400 K``;
M10 roof companion (same body and formula, only the sky and the roof surface):
    ``SW_DIR_ROOF + SW_SKY_ROOF = SW_TOT_ROOF``;
M11 ``MRT_ROOF`` recomputed from the output columns agrees with the model;
M12 roof night bounds (the emitted irradiances of the sky and of the roof);
M13 the roof value is materially different from the road one (``MRT_ROOF`` is
    not a copy of ``MRT_ROAD``), with the mean difference in daylight.

Usage
-----
    python python_tests/check_mrt.py build/out/TEB_output_b1_c1.csv \
        --param-nml tests/CAPITOUL/namelist/namelist.nml

Exit code: 0 when every check passes, 1 otherwise.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd

XUNDEF = 1e19
SEP = ';'

#: constants of the scheme, mirrored from src_teb/urban_mrt.F90
Z_PED = 1.1        # height of the centre of the pedestrian (m)
ABS_BODY = 0.70    # shortwave absorption of the body (-)
EMIS_BODY = 0.97   # longwave emissivity of the body (-)
F_DIR = 0.25       # projected area factor of a sphere for the beam (-)
COSZ_MIN = 0.02    # lower bound of cos(zenith)
SIGMA = 5.6697e-8  # MODD_CSTS:XSTEFAN (set in INI_CSTS), not the CODATA value

RE_ITEM = r'^\s*%s\s*=\s*([^,\n/!]+)'


def read_output(path: Path) -> pd.DataFrame:
    """CSV of a TEB-MSU offline run: numeric columns, XUNDEF masked to NaN."""
    d = pd.read_csv(path, sep=SEP)
    num = d.select_dtypes(include='number').columns
    d[num] = d[num].mask(d[num] >= XUNDEF)
    return d


def namelist_item(text: str, name: str, cast=float):
    """Value of one item of the /tebparam/ namelist."""
    m = re.search(RE_ITEM % name, text, re.M | re.I)
    if m is None:
        sys.exit(f'ERROR: item {name!r} not found in the parameter namelist')
    return cast(m.group(1).strip().strip("'\""))


def required(d: pd.DataFrame, names) -> None:
    missing = [n for n in names if n not in d.columns]
    if missing:
        sys.exit('ERROR: the output has no column(s): ' + ', '.join(missing))


def view_factors(h_bld: float, h2w: float):
    """Analytic view factors of the pedestrian (sphere) of the scheme."""
    if h_bld > 0. and h2w > 0.:
        a_eff = h2w * max(0., 1. - Z_PED / h_bld)
        psi = np.sqrt(a_eff ** 2 + 1.) - a_eff
        f_sky = 0.5 * psi
        zb = 2. * Z_PED * h2w / h_bld
        f_road = 0.5 * (1. - zb / np.sqrt(1. + zb ** 2))
        f_wall = max(0., 1. - f_sky - f_road)
    else:
        psi, f_sky, f_road, f_wall = 1., 0.5, 0.5, 0.
    return psi, f_sky, f_wall, f_road


def report(name: str, ok: bool, detail: str) -> bool:
    print(f'{"PASS" if ok else "FAIL"}  {name:<58s} {detail}')
    return ok


def run_checks(d: pd.DataFrame, alb_rd: float, emis_rd: float, emis_wl: float,
               alb_rf: float, emis_rf: float, h_bld: float, h2w: float) -> bool:
    """All checks of the scheme; returns True when every one of them passes."""
    psi, f_sky, f_wall, f_road = view_factors(h_bld, h2w)
    ok = True

    # ---- M1: view factors ---------------------------------------------------
    fsum = d['MRT_F_SKY'] + d['MRT_F_WALL'] + d['MRT_F_ROAD']
    err = max(abs(d['MRT_F_SKY'] - f_sky).max(),
              abs(d['MRT_F_WALL'] - f_wall).max(),
              abs(d['MRT_F_ROAD'] - f_road).max(),
              abs(fsum - 1.).max())
    ok &= report('M1 view factors (analytic 2D canyon, sum = 1)', err <= 1e-12,
                 f'max|dF| = {err:.2e}  (F_sky = {f_sky:.6f}, F_wall = {f_wall:.6f}, '
                 f'F_road = {f_road:.6f})')

    # ---- M2: shortwave identity at road level -------------------------------
    ident = (d['SW_DIR_ROAD'] + d['SW_SKY_ROAD'] + d['SW_WALL_ROAD']
             - d['SW_TOT_ROAD'])
    scale = max(1., float(d['SW_TOT_ROAD'].abs().max()))
    err = float(ident.abs().max())
    ok &= report('M2 SW_DIR + SW_SKY + SW_WALL = SW_TOT_ROAD', err <= 1e-9 * scale,
                 f'max|residual| = {err:.2e} W/m2')

    # ---- M3: MRT recomputed from the output columns -------------------------
    snow_free = d['PDN_RD'].fillna(1.).eq(0.) & d['TSNOW_RD'].isna()
    n_skip = int((~snow_free).sum())
    x = d.loc[snow_free]
    cosz = np.cos(np.radians(x['SOLAR_ZENITH'].to_numpy()))
    cosz_eff = np.maximum(cosz, COSZ_MIN)
    sw_dir = x['SW_DIR_ROAD'].to_numpy()
    sun_frac = np.clip(x['SUN_FRAC_ROAD'].to_numpy(), 0., 1.)
    sun_on = (sw_dir > 0.) & (cosz > 0.)
    # the area-averaged beam of the "smeared" pedestrian, and the sunlit variant
    q_dir = np.where(sun_on, ABS_BODY * F_DIR * sw_dir / cosz_eff, 0.)
    q_dir_sun = np.where(sun_on & (sun_frac > 0.), q_dir / np.maximum(sun_frac, 1e-12), 0.)
    q_sky = ABS_BODY * 0.5 * x['SW_SKY_ROAD'].to_numpy()
    q_wall = ABS_BODY * f_wall * x['SW_WALL_ROAD'].to_numpy() / max(1. - psi, 0.05)
    q_road = ABS_BODY * f_road * alb_rd * x['SW_TOT_ROAD'].to_numpy()
    q_lw = (EMIS_BODY * f_sky * x['Forc_LW'].to_numpy()
            + EMIS_BODY * f_wall * emis_wl * SIGMA
            * 0.5 * (x['T_WALLA1'].to_numpy() ** 4 + x['T_WALLB1'].to_numpy() ** 4)
            + EMIS_BODY * f_road * emis_rd * SIGMA * x['T_ROAD1'].to_numpy() ** 4)
    base = q_sky + q_wall + q_road + q_lw
    t_mrt = ((base + q_dir) / (EMIS_BODY * SIGMA)) ** 0.25
    t_sun = ((base + q_dir_sun) / (EMIS_BODY * SIGMA)) ** 0.25
    err = max(float(np.abs(t_mrt - x['MRT_ROAD'].to_numpy()).max()),
              float(np.abs(t_sun - x['MRT_ROAD_SUN'].to_numpy()).max()))
    ok &= report('M3 MRT recomputed from the output columns', err <= 1e-6,
                 f'max|dT| = {err:.2e} K  ({len(x)} snow-free rows, {n_skip} skipped: snow)')

    # ---- M4: no sun on the road -> the two variants coincide ----------------
    dark = d['SW_DIR_ROAD'].fillna(0.).eq(0.)
    err = float((d.loc[dark, 'MRT_ROAD_SUN'] - d.loc[dark, 'MRT_ROAD']).abs().max()) \
        if dark.any() else 0.
    ok &= report('M4 no beam on the road: MRT_ROAD = MRT_ROAD_SUN', err == 0.,
                 f'max|dT| = {err:.2e} K  ({int(dark.sum())} rows)')

    # ---- M5: the sunlit variant is never colder -----------------------------
    dmrt = (d['MRT_ROAD_SUN'] - d['MRT_ROAD']).to_numpy()
    ok &= report('M5 MRT_ROAD_SUN >= MRT_ROAD', float(np.nanmin(dmrt)) >= -1e-9,
                 f'min(dT) = {float(np.nanmin(dmrt)):.2e} K')

    # ---- M6: night bounds ---------------------------------------------------
    # with grey surfaces the MRT is a view-factor mean of the EMITTED irradiances
    # (eps*sigma*T^4), not of the temperatures: the bounds are taken on those
    night = d['SW_TOT_ROAD'].fillna(0.).eq(0.) & d['PDN_RD'].fillna(1.).eq(0.) \
        & d['TSNOW_RD'].isna()
    if night.any():
        n = d.loc[night]
        l_sky = n['Forc_LW'].to_numpy()
        l_wall = emis_wl * SIGMA * 0.5 * (n['T_WALLA1'].to_numpy() ** 4
                                          + n['T_WALLB1'].to_numpy() ** 4)
        l_road = emis_rd * SIGMA * n['T_ROAD1'].to_numpy() ** 4
        lo = (np.minimum(np.minimum(l_sky, l_wall), l_road) / SIGMA) ** 0.25
        hi = (np.maximum(np.maximum(l_sky, l_wall), l_road) / SIGMA) ** 0.25
        bad_lo = float((n['MRT_ROAD'].to_numpy() - lo).min())
        bad_hi = float((hi - n['MRT_ROAD'].to_numpy()).min())
        ok &= report('M6 night: MRT between the coldest and warmest emitter',
                     bad_lo >= -1e-9 and bad_hi >= -1e-9,
                     f'min(MRT - lo) = {bad_lo:.2e}, min(hi - MRT) = {bad_hi:.2e} K '
                     f'({int(night.sum())} rows)')
    else:
        print('SKIP  M6 night bounds: the run has no night rows')

    # ---- M7: the scheme is not inert ---------------------------------------
    n_sun = int((dmrt > 1e-3).sum())
    ok &= report('M7 material effect of the sunlit variant', n_sun > 0,
                 f'{n_sun} rows with MRT_ROAD_SUN - MRT_ROAD > 1e-3 K '
                 f'(max {float(np.nanmax(dmrt)):.2f} K)')

    # ---- M8: physical range -------------------------------------------------
    lo = float(d['MRT_ROAD'].min())
    hi = float(d['MRT_ROAD'].max())
    ok &= report('M8 physical range of MRT_ROAD', 150. < lo and hi < 400.,
                 f'{lo:.2f} ... {hi:.2f} K')

    # ---- M10: incident shortwave identity on the roof -----------------------
    ident = d['SW_DIR_ROOF'] + d['SW_SKY_ROOF'] - d['SW_TOT_ROOF']
    scale = max(1., float(d['SW_TOT_ROOF'].abs().max()))
    err = float(ident.abs().max())
    ok &= report('M10 SW_DIR_ROOF + SW_SKY_ROOF = SW_TOT_ROOF', err <= 1e-9 * scale,
                 f'max|residual| = {err:.2e} W/m2')

    # ---- M11: MRT_ROOF recomputed from the output columns -------------------
    # (snow-free roof rows only: the snow temperature on the roof is not written,
    #  the road counterpart MRT check uses TSNOW_RD that does exist)
    snow_free = d['PDN_RF'].fillna(1.).eq(0.)
    n_skip = int((~snow_free).sum())
    x = d.loc[snow_free]
    cosz = np.cos(np.radians(x['SOLAR_ZENITH'].to_numpy()))
    cosz_eff = np.maximum(cosz, COSZ_MIN)
    sw_dir = x['SW_DIR_ROOF'].to_numpy()
    q_dir = np.where((sw_dir > 0.) & (cosz > 0.),
                     ABS_BODY * F_DIR * sw_dir / cosz_eff, 0.)
    q_sky = ABS_BODY * 0.5 * x['SW_SKY_ROOF'].to_numpy()
    q_roof = ABS_BODY * 0.5 * alb_rf * x['SW_TOT_ROOF'].to_numpy()
    q_lw = EMIS_BODY * (0.5 * x['Forc_LW'].to_numpy()
                        + 0.5 * emis_rf * SIGMA * x['T_ROOF1'].to_numpy() ** 4)
    t_mrt = ((q_dir + q_sky + q_roof + q_lw) / (EMIS_BODY * SIGMA)) ** 0.25
    err = float(np.abs(t_mrt - x['MRT_ROOF'].to_numpy()).max())
    ok &= report('M11 MRT_ROOF recomputed from the output columns', err <= 1e-6,
                 f'max|dT| = {err:.2e} K  ({len(x)} snow-free rows, {n_skip} skipped: snow)')

    # ---- M12: roof longwave bound ------------------------------------------
    # rows where the shortwave of the body is negligible: then the MRT is the
    # view-factor mean of the emitted irradiances of the sky and of the roof
    q_sw = q_dir + q_sky + q_roof
    calm = q_sw < 0.01
    if calm.any():
        l_sky = x['Forc_LW'].to_numpy()[calm]
        l_roof = emis_rf * SIGMA * x['T_ROOF1'].to_numpy()[calm] ** 4
        mrt = x['MRT_ROOF'].to_numpy()[calm]
        lo = (np.minimum(l_sky, l_roof) / SIGMA) ** 0.25
        hi = (np.maximum(l_sky, l_roof) / SIGMA) ** 0.25
        bad_lo = float((mrt - lo).min())
        bad_hi = float((hi - mrt).min())
        ok &= report('M12 roof: MRT_ROOF between sky and roof emitters',
                     bad_lo >= -1e-9 and bad_hi >= -1e-9,
                     f'min(MRT - lo) = {bad_lo:.2e}, min(hi - MRT) = {bad_hi:.2e} K '
                     f'({int(calm.sum())} rows without shortwave)')
    else:
        print('SKIP  M12 roof bound: no row without a shortwave contribution')

    # ---- M13: the roof and the road are not the same object -----------------
    droof = (d['MRT_ROOF'] - d['MRT_ROAD']).to_numpy()
    day = d['SW_TOT_ROOF'].fillna(0.).to_numpy() > 0.
    n_diff = int((np.abs(droof) > 0.5).sum())
    mean_day = float(np.nanmean(droof[day])) if day.any() else float('nan')
    ok &= report('M13 roof vs road: materially different values', n_diff > 0,
                 f'{n_diff} rows with |MRT_ROOF - MRT_ROAD| > 0.5 K; '
                 f'mean difference in daylight = {mean_day:+.2f} K '
                 f'(range {float(np.nanmin(droof)):+.1f} ... {float(np.nanmax(droof)):+.1f} K)')
    return ok


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('path', help='TEB_output_b<block>_c<cell>.csv of a dev run')
    ap.add_argument('--param-nml', default='namelist/namelist.nml',
                    help='parameter namelist of the run (geometry, albedo, emissivity)')
    args = ap.parse_args(argv)

    d = read_output(Path(args.path))
    required(d, ['time', 'MRT_ROAD', 'MRT_ROAD_SUN', 'MRT_F_SKY', 'MRT_F_WALL',
                 'MRT_F_ROAD', 'SW_DIR_ROAD', 'SW_SKY_ROAD', 'SW_WALL_ROAD',
                 'SW_TOT_ROAD', 'SUN_FRAC_ROAD', 'MRT_SW_DIR', 'MRT_LW_SKY',
                 'PDN_RD', 'TSNOW_RD', 'T_ROAD1', 'T_WALLA1', 'T_WALLB1',
                 'Forc_LW', 'SOLAR_ZENITH',
                 'MRT_ROOF', 'SW_DIR_ROOF', 'SW_SKY_ROOF', 'SW_TOT_ROOF',
                 'PDN_RF', 'T_ROOF1'])

    txt = Path(args.param_nml).read_text(encoding='utf-8', errors='ignore')
    h_bld = namelist_item(txt, 'urb_h_bld')
    h2w = namelist_item(txt, 'urb_h2w')
    alb_rd = namelist_item(txt, 'urb_alb_rd_so')
    # urb_alb_*_th are the THERMAL albedos: emissivity = 1 - albedo
    emis_rd = 1. - namelist_item(txt, 'urb_alb_rd_th')
    emis_wl = 1. - namelist_item(txt, 'urb_alb_wl_th')
    alb_rf = namelist_item(txt, 'urb_alb_rf_so')
    emis_rf = 1. - namelist_item(txt, 'urb_alb_rf_th')

    print(f'MRT of a pedestrian: road and roof  [{args.path}]')
    print(f'  geometry: H = {h_bld} m, H/W = {h2w}, z_ped = {Z_PED} m; '
          f'road alb/emis = {alb_rd}/{emis_rd}, wall emis = {emis_wl}, '
          f'roof alb/emis = {alb_rf}/{emis_rf}')
    print(f'  rows: {len(d)}')
    ok = run_checks(d, alb_rd, emis_rd, emis_wl, alb_rf, emis_rf, h_bld, h2w)
    print(f'  RESULT: {"OK" if ok else "FAIL"}')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
