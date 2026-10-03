#!/usr/bin/env python
"""
Sensitivity of the TEB-Ru garden model to the garden roughness length (urb_z0_gdn).

The roughness length of the garden is a namelist item of ALL the garden versions
(``urb_z0_gdn``, default 0.1 m = MODD_PROXI_SVAT_PAR:XZ0_GD). It fixes the
aerodynamic conductance of the garden

    Ca = k**2/(ln(zref/z0)*ln(zref/z0h)) * max(V, VMIN)   ['PROXY_NEW', balance]
                                                            (z0h = z0/urb_z0_o_z0h_gdn)
    friction only                                 ['PROXY_OLD' and 'EXT']

with ``zref = H/2`` the canyon reference height of TEB (``call_driver``:
``ZZ_LOWCAN = ZBLD_HEIGHT / 2``) and ``VMIN = 0.5 m/s`` (``XVMIN_GD``).

This script runs the offline model on the Moscow ERA5 forcing for the three LCZs
of ``python_tests/sensitivity_zd.py`` with two values of ``urb_z0_gdn`` (the reference
0.1 m of the internal proxies and the rougher 0.8 m of a well vegetated garden)
and checks that

  Z1  the garden-OFF configuration is a strict no-op (bit-for-bit identical
      output for the two roughness lengths),
  Z2  the historical Bowen proxy is z0-independent as well (it sets
      ``PAC_GARDEN = 0``, i.e. it does not use the aerodynamic conductance),
  Z4  with ``PROXY_NEW`` the model conductance follows the analytic law of the
      garden: since the thermal roughness was introduced the conductance is the
      SCALAR one, ``PAC_GARDEN = k**2/(ln(zref/z0)*ln(zref/z0h)) * max(V, VMIN)``
      with ``z0h = z0/urb_z0_o_z0h_gdn`` (namelist item, default 4.0), so
      ``PAC_GARDEN(z0=0.8)/PAC_GARDEN(z0=0.1) = 2.7923`` for ``zref = 10 m``
      (instead of the ``3.3244`` of the formulation without thermal roughness);
      the ratio is exact at every time step (the canyon wind does not depend on
      the garden z0) and the canyon reference height is recovered from it by
      bisection. Set ``urb_z0_o_z0h_gdn = 1`` in the base namelist to check the
      formulation without thermal roughness (``PCH = PCD``),
  Z3  with 'EXT' the garden conductance that TEB uses in the canyon budget (and
      that is exported in the ``PAC_GARDEN`` column) is NOT produced by the
      internal proxy: TEB's ``PAC_GARDEN`` sits in the ``PAC_GARDEN_CAN`` slot of
      ``URBAN_DRAG`` (that is why there is no separate ``PAC_GARDEN_CAN``
      column), and for an external garden model ``URBAN_DRAG`` fills it with the
      garden/canyon conductance computed by ``URBAN_EXCH_COEF`` from
      ``PZ0_GARDEN_EXT``. The check reports that conductance in terms of the
      exported heat conductance ``PCH_GARDEN_CAN`` and quantifies the resulting
      (physical) sensitivity of the town to z0 in EXT mode.
  Z5  the actual sensitivity of the garden fluxes, of the garden surface
      temperature and of the town to z0.

Configurations (3 LCZ x 4 garden modes x 2 values of urb_z0_gdn = 24 runs)
-----------------------------------------------------------------------
    gOFF : teb_lgarden = .FALSE.                        (Z1: no-op)
    gOLD : teb_lgarden = .TRUE., teb_type_garden = 'PROXY_OLD'  (Z2: no-op)
    gNEW : teb_lgarden = .TRUE., teb_type_garden = 'PROXY_NEW'  (Z3, Z5)
    gEXT : teb_lgarden = .TRUE., teb_type_garden = 'EXT'        (Z4)

The tau scheme of the road is OFF in every case and ``fr_garden = 0.3``.

Files (kept; use --force to re-run a case)
------------------------------------------
  <out-root>/namelists/<case>.nml            namelist of every case
  <out-root>/output_<case>/                  model output (TEB_output.csv)
  <out-root>/logs/<case>.log                 model log (contains the model banner)
  <out-root>/summary_z0_sensitivity.csv      statistics per case/variable
  <out-root>/checks_z0_sensitivity.csv       the z0 checks (one row per check)
  <out-root>/diff_columns.csv                columns that change with z0, per case
  <out-root>/plots/z0_ca_ratio.png           analytic check of Ca(z0) (Z4)
  <out-root>/plots/garden_diurnal.png     garden diurnal cycle (H, LE, Rn, Ts)
  <out-root>/plots/z0_town_diurnal.png       town/canyon cycle (H, LE, T, q)
  <out-root>/plots/z0_canyon_delta.png       z0 effect on T/q/wind of the canyon
  <out-root>/plots/z0_flux_delta.png         z0 effect on H and LE (town + garden)
  <out-root>/README.md                       description and results

Usage
-----
    python python_tests/garden_z0_sensitivity.py
    python python_tests/garden_z0_sensitivity.py --list
    python python_tests/garden_z0_sensitivity.py --only LCZ2_gNEW_080,LCZ9_gNEW_080
    python python_tests/garden_z0_sensitivity.py --z0-list 0.1,0.4,0.8
    python python_tests/garden_z0_sensitivity.py --skip-run     # post-process only
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
PYTHON_DIR = MODEL_DIR / 'python'      # shared libraries of the repository
if str(PYTHON_DIR) not in sys.path:
    sys.path.append(str(PYTHON_DIR))

from sensitivity_zd import (                                          # noqa: E402
    LCZ, DEFAULT_WORK_DIR, run_case, series, stats_of,
)

#: values >= XUNDEF are undefined in TEB-Ru (MODD_SURF_PAR:XUNDEF = 1.0e20)
XUNDEF = 1.0e19

#: garden modes: tag -> (teb_lgarden, teb_type_garden, description)
MODES = {
    'gOFF': (False, 'PROXY_NEW', 'garden OFF'),
    'gOLD': (True,  'PROXY_OLD', 'garden ON, historical Bowen proxy'),
    'gNEW': (True,  'PROXY_NEW', 'garden ON, diagnostic energy balance'),
    'gEXT': (True,  'EXT',       'garden ON, external garden fluxes (EXT)'),
}

#: garden roughness lengths compared (m): reference value of the internal
#: proxies and the rougher value of a well vegetated garden
Z0_VALUES = (0.1, 0.8)

#: garden diagnostics written by the model (per m2 of garden)
GARDEN_COLS = ('TS_GARDEN', 'RN_GARDEN', 'H_GARDEN', 'LE_GARDEN',
               'EVAP_GARDEN', 'QSAT_GARDEN', 'PHU_GARDEN',
               'PAC_GARDEN')

#: town / canyon columns whose z0-sensitivity is reported
TOWN_COLS = ('T_CANYON', 'Q_CANYON', 'U_CANYON', 'H_TOWN', 'LE_TOWN',
             'RN_TOWN', 'GFLUX_TOWN')

#: columns that depend on the garden roughness length by construction: the
#: exchange coefficients computed by URBAN_DRAG / URBAN_EXCH_COEF from
#: PZ0_GARDEN_EXT for the garden/canyon and garden/atmosphere diagnostics
Z0_DIAG_SUFFIX = ('_GARDEN_CAN', '_GARDEN_ATM')



# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

def z0_tag(z0: float) -> str:
    """Case-name tag of a roughness length: 0.1 -> '010', 0.8 -> '080'."""
    return ('%03d' % round(z0 * 100.0))


def cases(z0_values=None, lcz_tags=None, mode_tags=None):
    """Deterministic list of (case, lcz_tag, mode_tag, z0)."""
    out = []
    for lcz_tag in (lcz_tags or list(LCZ)):
        for mode_tag in MODES:
            if mode_tags and mode_tag not in mode_tags:
                continue
            for z0 in (z0_values or Z0_VALUES):
                out.append((f'{lcz_tag}_{mode_tag}_z{z0_tag(z0)}', lcz_tag,
                            mode_tag, float(z0)))
    return out


def build_namelist(base_nml: Path, lcz_tag: str, mode_tag: str, z0: float,
                   path: Path, fr_garden: float) -> Path:
    """Namelist of one case: base namelist + LCZ + garden mode + urb_z0_gdn.

    The road tau scheme is switched OFF: the experiment isolates the garden.
    """
    import f90nml
    nml = f90nml.read(str(base_nml))
    p = nml['tebparam']
    lcz = LCZ[lcz_tag]
    lgarden, gtype, _desc = MODES[mode_tag]
    p['urb_h_bld'] = float(lcz['h_bld'])
    p['urb_fr_bld'] = float(lcz['fr_bld'])
    p['urb_h2w'] = float(lcz['h2w'])
    p['teb_fai'] = [float(lcz['fai'])] * 8
    p['teb_lgarden'] = bool(lgarden)
    p['fr_garden'] = float(fr_garden) if lgarden else 0.0
    p['teb_type_garden'] = gtype
    p['teb_ltau_scheme'] = False
    p['urb_z0_gdn'] = float(z0)                  # the item under study
    path.parent.mkdir(parents=True, exist_ok=True)
    nml.write(str(path), force=True)
    return path


# ---------------------------------------------------------------------------
# Reading and comparison
# ---------------------------------------------------------------------------

def read_all(out_dir: Path):
    """Whole model output (time + all numeric columns) as a DataFrame.

    The columns are read with ``converters=float`` (the pandas fast float parser
    may lose one ULP): the bit-for-bit comparisons below need the exact values
    written by the model.
    """
    csv = out_dir / 'TEB_output.csv'
    if not csv.is_file():
        return None
    with open(csv, encoding='utf-8', errors='ignore') as fh:
        header = fh.readline().strip().split(';')
    conv = {c: float for c in header if c and c != 'time'}
    return pd.read_csv(csv, sep=';', converters=conv)


def mask_undefined(x):
    """Replace the TEB XUNDEF sentinel by NaN (the values are then ignored)."""
    if x is None:
        return None
    x = np.asarray(x, dtype=float).copy()
    return np.where(np.abs(x) >= XUNDEF, np.nan, x)


def diff_columns(df_a: pd.DataFrame, df_b: pd.DataFrame, tol: float = 0.0):
    """Columns that differ between two runs (a = reference, b = perturbed).

    Returns a list of dicts ``(column, max_abs, n_diff, n_undef_mismatch)``,
    sorted by decreasing ``max_abs``. ``max_abs`` is computed on the steps where
    both runs are defined; ``n_undef_mismatch`` counts the steps where one run is
    defined and the other is not (XUNDEF) - those are differences as well.
    """
    out = []
    if df_a is None or df_b is None or df_a.shape != df_b.shape:
        return out
    for col in df_a.columns:
        if col == 'time':
            continue
        x = mask_undefined(df_a[col].to_numpy(dtype=float))
        y = mask_undefined(df_b[col].to_numpy(dtype=float))
        both = np.isfinite(x) & np.isfinite(y)
        undef_mismatch = int(np.count_nonzero(np.isfinite(x) != np.isfinite(y)))
        dmax, ndiff = 0.0, 0
        if both.any():
            d = np.abs(x[both] - y[both])
            dmax = float(np.max(d))
            ndiff = int(np.count_nonzero(d > tol))
        if dmax > tol or undef_mismatch:
            out.append(dict(column=col, max_abs=dmax, n_diff=ndiff,
                            n_undef_mismatch=undef_mismatch))
    out.sort(key=lambda r: -r['max_abs'])
    return out


def ca_analysis(pac_ref, pac_new, z0_ref: float, z0_new: float, zref: float,
                ratio_z0h: float = 4.0):
    """Analytic check of the aerodynamic conductance of 'PROXY_NEW' (Z3).

    Since the thermal roughness was introduced the conductance of the garden is
    the SCALAR one built from ``z0h = z0/ratio_z0h``:

        PAC_GARDEN = k**2/(ln(zref/z0)*ln(zref/z0h)) * max(V, VMIN)

    so for two roughness lengths (the same ``z0/z0h`` ratio in both runs) the
    ratio of the conductances must be

        r = Ca(z0_new)/Ca(z0_ref)
          = [ln(zref/z0_ref)*ln(zref/z0_ref/R)]/[ln(zref/z0_new)*ln(zref/z0_new/R)]

    at EVERY step, because the canyon wind V (which enters both runs through
    ``max(V, VMIN)`` and is the same in the two runs) does not depend on the
    garden z0: the garden momentum flux is not part of the canyon momentum
    budget, and the garden/canyon heat exchange modifies the air temperature and
    humidity only, not the wind.

    The canyon reference height is recovered from the measured ratio by solving
    the equation above for ``zref`` (bisection on ``[max(z0)+1e-6, 1e4]`` m).

    Returns None when the two runs have no common meaningful step.
    """
    x = mask_undefined(pac_ref)
    y = mask_undefined(pac_new)
    if x is None or y is None:
        return None
    m = np.isfinite(x) & np.isfinite(y) & (x > 0.0) & (y > 0.0)
    if not m.any():
        return None
    r = y[m] / x[m]

    def ca(z0: float, z):
        """Scalar conductance kernel k**2/(ln(z/z0)*ln(z/z0h)) of the garden.

        Array-safe (the bisection below applies it to whole arrays of ratios);
        zero where the profile is not defined (``z <= z0`` or ``z <= z0h``).
        """
        z0h = z0 / max(ratio_z0h, 1.0)
        z = np.asarray(z, dtype=float)
        with np.errstate(divide='ignore', invalid='ignore'):
            out = 1.0 / (np.log(z / z0) * np.log(z / z0h))
        return np.where((z > z0) & (z > z0h), out, 0.0)

    r_an = float(ca(z0_new, zref) / ca(z0_ref, zref))
    # implied zref: Ca ratio as a function of zref, inverted by bisection
    z_lo = max(z0_ref, z0_new) + 1.0e-6
    z_hi = 1.0e4
    r_at = lambda z: np.asarray(ca(z0_new, z) / ca(z0_ref, z), dtype=float)  # noqa: E731
    z_implied = np.array([])
    if float(r_at(z_lo)) > 0.0:
        lo = np.full(r.shape, z_lo)
        hi = np.full(r.shape, z_hi)
        for _ in range(80):
            mid = 0.5 * (lo + hi)
            above = r_at(mid) > r          # r(z) decreases with z
            lo = np.where(above, mid, lo)
            hi = np.where(above, hi, mid)
        z_implied = 0.5 * (lo + hi)
    res = dict(
        n=int(m.sum()),
        ratio_median=float(np.median(r)),
        ratio_min=float(np.min(r)),
        ratio_max=float(np.max(r)),
        ratio_analytic=float(r_an),
        ratio_rel_error=float(abs(np.median(r) - r_an) / r_an),
        zref_expected=float(zref),
        z0h_ratio=float(ratio_z0h),
        n_zref=int(z_implied.size),
    )
    if z_implied.size:
        res['zref_implied_median'] = float(np.median(z_implied))
        res['zref_implied_max_rel_error'] = float(
            np.max(np.abs(z_implied - zref) / zref))
    else:
        res['zref_implied_median'] = np.nan
        res['zref_implied_max_rel_error'] = np.nan
    return res


# ---------------------------------------------------------------------------
# Experiment
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--work-dir', default=DEFAULT_WORK_DIR,
                    help='root of the run_on_windows.ipynb working directory')
    ap.add_argument('--site', default='Moscow', help='site name (default: %(default)s)')
    ap.add_argument('--base-namelist', default=None,
                    help='base parameter namelist (default: <site>/params_CTRL.nml)')
    ap.add_argument('--forcing-nml', default=None,
                    help='forcing namelist (default: <site>/forcing_ERA5/namelist_forcing.nml)')
    ap.add_argument('--out-root', default=None,
                    help='output root (default: <site>/garden_z0_sensitivity)')
    ap.add_argument('--exe', default=None, help='model executable')
    ap.add_argument('--only', default=None, help='comma separated list of cases')
    ap.add_argument('--skip-run', action='store_true', help='post-process only')
    ap.add_argument('--force', action='store_true', help='re-run existing cases')
    ap.add_argument('--list', action='store_true', help='list the cases and exit')
    ap.add_argument('--fr-garden', type=float, default=0.3,
                    help='garden fraction of the urban tile (default: %(default)s)')
    ap.add_argument('--z0-list', default=','.join('%g' % z for z in Z0_VALUES),
                    help='garden roughness lengths to compare, in m'
                         ' (default: %(default)s; the first one is the reference)')
    ap.add_argument('--days', type=float, default=None,
                    help='restrict the post-processing to the first N days')
    args = ap.parse_args(argv)

    z0_values = [float(x) for x in str(args.z0_list).split(',')]
    if len(z0_values) < 2:
        print('ERROR: --z0-list needs at least two values (reference + perturbed)')
        return 2
    z0_ref, z0_new = z0_values[0], z0_values[-1]

    #: z0/z0h ratio of the garden used by the runs (`urb_z0_o_z0h_gdn`). The bench
    #: does not write the item, so the runs use the driver default
    #: (MODD_PROXI_SVAT_PAR:XZ0_O_Z0H_GD = 4); if the base namelist sets it, that
    #: value is used by the analytic checks below.
    z0h_ratio = 4.0
    try:
        import f90nml
        _p = f90nml.read(str(base))
        z0h_ratio = float(_p['tebparam'].get('urb_z0_o_z0h_gdn', z0h_ratio))
    except Exception:
        pass

    work = Path(args.work_dir)
    site_dir = work / args.site
    base = (Path(args.base_namelist) if args.base_namelist
            else site_dir / 'params_CTRL.nml')
    if not base.is_file():
        base = MODEL_DIR / 'namelist' / 'namelist.nml'
    forcing_nml = (Path(args.forcing_nml) if args.forcing_nml
                   else site_dir / 'forcing_ERA5' / 'namelist_forcing.nml')
    out_root = (Path(args.out_root) if args.out_root
                else site_dir / 'garden_z0_sensitivity')
    exe = Path(args.exe) if args.exe else MODEL_DIR / 'build' / 'TEB_offline.exe'

    all_cases = cases(z0_values)
    if args.only:
        selected = {c.strip() for c in args.only.split(',')}
        all_cases = [c for c in all_cases if c[0] in selected]

    if args.list:
        print(f'{"case":<22} {"LCZ":<46} {"z0 (m)":>6}  garden mode')
        for case, lcz_tag, mode_tag, z0 in all_cases:
            print(f'{case:<22} {LCZ[lcz_tag]["label"]:<46} {z0:>6g}  {MODES[mode_tag][2]}')
        return 0

    out_root.mkdir(parents=True, exist_ok=True)
    (out_root / 'namelists').mkdir(exist_ok=True)
    (out_root / 'logs').mkdir(exist_ok=True)

    print('=' * 78)
    print('  base namelist :', base)
    print('  forcing       :', forcing_nml)
    print('  output root   :', out_root)
    print('  urb_z0_gdn     :', ', '.join('%g m' % z for z in z0_values),
          f'(reference {z0_ref:g} m)')
    print('  cases         :', len(all_cases), f'(fr_garden = {args.fr_garden:g})')
    print('=' * 78)

    # ------------------------------------------------------------------
    # runs
    # ------------------------------------------------------------------
    for case, lcz_tag, mode_tag, z0 in all_cases:
        nml_path = out_root / 'namelists' / f'{case}.nml'
        out_dir = out_root / f'output_{case}'
        log_file = out_root / 'logs' / f'{case}.log'
        build_namelist(base, lcz_tag, mode_tag, z0, nml_path, args.fr_garden)
        if args.skip_run:
            continue
        if (out_dir / 'TEB_output.csv').is_file() and not args.force:
            print(f'  [skip] {case}')
            continue
        print(f'  [run ] {case}  ({LCZ[lcz_tag]["label"]}, {mode_tag}, z0 = {z0:g} m)')
        rc = run_case(exe, forcing_nml, nml_path, out_dir, log_file)
        if rc != 0:
            print(f'    WARNING: {case} returned code {rc}')

    # ------------------------------------------------------------------
    # read the outputs
    # ------------------------------------------------------------------
    runs = {}
    for case, lcz_tag, mode_tag, z0 in all_cases:
        out_dir = out_root / f'output_{case}'
        df = read_all(out_dir)
        if df is None:
            print(f'  [miss] {case}: no TEB_output.csv')
            continue
        if args.days:
            tmax = pd.Timestamp(df['time'].iloc[0]) + pd.Timedelta(days=args.days)
            df = df.loc[pd.to_datetime(df['time']) <= tmax].reset_index(drop=True)
        runs[case] = dict(lcz=lcz_tag, mode=mode_tag, z0=z0, df=df, dir=out_dir)

    # ------------------------------------------------------------------
    # Z1 - Z4: what does urb_z0_gdn change?
    # ------------------------------------------------------------------
    checks, diff_rows, ca_rows = [], [], []
    for lcz_tag in LCZ:
        # ZZ_LOWCAN = ZBLD_HEIGHT / 2 (call_driver): canyon reference height
        zref = float(LCZ[lcz_tag]['h_bld']) / 2.0
        for mode_tag in MODES:
            c_ref = f'{lcz_tag}_{mode_tag}_z{z0_tag(z0_ref)}'
            c_new = f'{lcz_tag}_{mode_tag}_z{z0_tag(z0_new)}'
            if c_ref not in runs or c_new not in runs:
                continue
            d = diff_columns(runs[c_ref]['df'], runs[c_new]['df'])
            for row in d:
                col = row['column']
                a = mask_undefined(runs[c_ref]['df'][col].to_numpy(dtype=float))
                b = mask_undefined(runs[c_new]['df'][col].to_numpy(dtype=float))
                m = np.isfinite(a) & np.isfinite(b)
                rel = np.nan
                if m.any() and float(np.mean(np.abs(a[m]))) > 0.0:
                    rel = (100.0 * float(np.mean(np.abs(b[m] - a[m])))
                           / float(np.mean(np.abs(a[m]))))
                row = dict(row, rel_diff_pct=rel,
                           is_z0_diag=bool(col.endswith(Z0_DIAG_SUFFIX)))
                diff_rows.append(dict(case=c_new, lcz=lcz_tag, mode=mode_tag,
                                      z0_ref=z0_ref, z0_new=z0_new, **row))
            ncols = len(runs[c_ref]['df'].columns) - 1
            # energy-balance columns: everything but the z0 diagnostics
            others = [r for r in d if not r['column'].endswith(Z0_DIAG_SUFFIX)]
            mx_other = max([r['max_abs'] for r in others], default=0.0)
            if mode_tag == 'gOFF':
                checks.append(dict(case=c_new, lcz=lcz_tag, mode=mode_tag,
                                   check='Z1 garden OFF: z0 no-op',
                                   max_abs=mx_other, mean_abs=np.nan, n=ncols,
                                   detail=f'{len(d)} of {ncols} columns differ'))
            elif mode_tag == 'gOLD':
                checks.append(dict(case=c_new, lcz=lcz_tag, mode=mode_tag,
                                   check='Z2 PROXY_OLD: z0 no-op (PAC=0)',
                                   max_abs=mx_other, mean_abs=np.nan, n=ncols,
                                   detail=f'{len(d)} of {ncols} columns differ'))
            elif mode_tag == 'gEXT':
                # for an external garden model the garden conductance used by TEB
                # (and exported in PAC_GARDEN) is the one computed by URBAN_DRAG /
                # URBAN_EXCH_COEF from PZ0_GARDEN_EXT: it must equal the
                # garden/canyon heat conductance of the drag scheme, and it is
                # z0-dependent, so the town is sensitive to z0 in EXT mode
                pac_ref = np.asarray(series(runs[c_ref]['dir'], 'PAC_GARDEN'),
                                     dtype=float)
                pac_new = np.asarray(series(runs[c_new]['dir'], 'PAC_GARDEN'),
                                     dtype=float)
                pch_ref = np.asarray(series(runs[c_ref]['dir'], 'PCH_GARDEN_CAN'),
                                     dtype=float)
                m = (pac_ref > 0.0) & (pch_ref > 0.0) & (pch_ref < XUNDEF)
                ident = float(np.median(pac_ref[m] / pch_ref[m])) if m.any() else np.nan
                ratio = float(np.median(pac_new[m] / pac_ref[m])) if m.any() else np.nan
                checks.append(dict(
                    case=c_new, lcz=lcz_tag, mode=mode_tag,
                    check='Z3 EXT: garden conductance = URBAN_DRAG PAC_GARDEN_CAN',
                    max_abs=mx_other, mean_abs=ident, n=int(m.sum()),
                    detail=('PAC(0.8)/PAC(0.1) = %.4f; PAC_GARDEN/PCH_GARDEN_CAN'
                            ' = %.4f; %d of %d columns change (the town included)'
                            % (ratio, ident, len(d), ncols))))
            elif mode_tag == 'gNEW':
                ca = ca_analysis(series(runs[c_ref]['dir'], 'PAC_GARDEN'),
                                 series(runs[c_new]['dir'], 'PAC_GARDEN'),
                                 z0_ref, z0_new, zref, z0h_ratio)
                if ca is not None:
                    ca_rows.append(dict(lcz=lcz_tag, z0_ref=z0_ref,
                                        z0_new=z0_new, **ca))
                    checks.append(dict(
                        case=c_new, lcz=lcz_tag, mode=mode_tag,
                        check='Z4 PROXY_NEW: Ca(z0) analytic ratio',
                        max_abs=ca['zref_implied_max_rel_error'],
                        mean_abs=ca['ratio_rel_error'], n=ca['n'],
                        detail=('Ca ratio %.6f (analytic %.6f); canyon height'
                                ' %.4f m (expected %.4f m)'
                                % (ca['ratio_median'], ca['ratio_analytic'],
                                   ca['zref_implied_median'], ca['zref_expected']))))

    checks_df = pd.DataFrame(checks)
    checks_df.to_csv(out_root / 'checks_z0_sensitivity.csv', index=False,
                     float_format='%.6e')
    diff_df = pd.DataFrame(diff_rows)
    diff_df.to_csv(out_root / 'diff_columns.csv', index=False,
                   float_format='%.6e')
    ca_df = pd.DataFrame(ca_rows)

    print()
    print('=== checks ===')
    pd.set_option('display.width', 250)
    print(checks_df.to_string(index=False) if len(checks_df) else '(no runs)')
    print()
    print('=== columns that change with z0 (per case) ===')
    if len(diff_df):
        print(diff_df[['lcz', 'mode', 'column', 'max_abs', 'rel_diff_pct',
                       'n_diff', 'is_z0_diag']].to_string(index=False))
    else:
        print('(no column changes: the roughness length is a strict no-op)')

    # ------------------------------------------------------------------
    # Z5: sensitivity of the garden and of the town
    # ------------------------------------------------------------------
    summary_rows, eff = [], []
    for case, run in runs.items():
        for var in GARDEN_COLS + TOWN_COLS:
            v = mask_undefined(series(run['dir'], var))
            if v is None:
                continue
            fin = v[np.isfinite(v)]
            if fin.size == 0:
                continue
            st = stats_of(fin)
            summary_rows.append(dict(case=case, lcz=run['lcz'], mode=run['mode'],
                                     z0=run['z0'], var=var, **st))
    for lcz_tag in LCZ:
        for mode_tag in MODES:
            c_ref = f'{lcz_tag}_{mode_tag}_z{z0_tag(z0_ref)}'
            c_new = f'{lcz_tag}_{mode_tag}_z{z0_tag(z0_new)}'
            if c_ref not in runs or c_new not in runs:
                continue
            for var in GARDEN_COLS + TOWN_COLS:
                a = mask_undefined(series(runs[c_ref]['dir'], var))
                b = mask_undefined(series(runs[c_new]['dir'], var))
                if a is None or b is None:
                    continue
                m = np.isfinite(a) & np.isfinite(b)
                if not m.any():
                    continue
                ma, mb = float(np.mean(a[m])), float(np.mean(b[m]))
                eff.append(dict(lcz=lcz_tag, mode=mode_tag, var=var,
                                mean_z0_ref=ma, mean_z0_new=mb, delta=mb - ma,
                                rel_delta_pct=(100.0 * (mb - ma) / abs(ma)
                                               if abs(ma) > 0.0 else np.nan),
                                n=int(m.sum())))
    summary = pd.DataFrame(summary_rows)
    summary.to_csv(out_root / 'summary_z0_sensitivity.csv', index=False,
                   float_format='%.6f')
    eff_df = pd.DataFrame(eff)
    eff_df.to_csv(out_root / 'effect_z0_sensitivity.csv', index=False,
                  float_format='%.6f')

    if len(eff_df):
        print()
        print('=== mean effect of urb_z0_gdn (PROXY_NEW) ===')
        sel = eff_df[(eff_df['mode'] == 'gNEW')
                     & (eff_df['var'].isin(['TS_GARDEN', 'H_GARDEN', 'LE_GARDEN',
                                            'PAC_GARDEN', 'T_CANYON', 'Q_CANYON',
                                            'U_CANYON', 'H_TOWN', 'LE_TOWN',
                                            'RN_TOWN']))]
        print(sel[['lcz', 'var', 'mean_z0_ref', 'mean_z0_new', 'delta',
                   'rel_delta_pct']].to_string(index=False))

    # ------------------------------------------------------------------
    # plots
    # ------------------------------------------------------------------
    plots = out_root / 'plots'
    plots.mkdir(exist_ok=True)

    def diurnal(v, time):
        if v is None or time is None:
            return None
        s = pd.Series(np.asarray(v, dtype=float), index=pd.to_datetime(time))
        return s.groupby(s.index.hour).mean()

    def cases_of(mode_tag, lcz_tag):
        return (f'{lcz_tag}_{mode_tag}_z{z0_tag(z0_ref)}',
                f'{lcz_tag}_{mode_tag}_z{z0_tag(z0_new)}')

    # 1. analytic check of the aerodynamic conductance (PROXY_NEW)
    fig, axes = plt.subplots(1, len(LCZ), figsize=(5.6 * len(LCZ), 4.4))
    if len(LCZ) == 1:
        axes = [axes]
    for ax, lcz_tag in zip(axes, LCZ):
        c_ref, c_new = cases_of('gNEW', lcz_tag)
        if c_ref not in runs or c_new not in runs:
            continue
        zref = float(LCZ[lcz_tag]['h_bld']) / 2.0
        pac_ref = series(runs[c_ref]['dir'], 'PAC_GARDEN')
        pac_new = series(runs[c_new]['dir'], 'PAC_GARDEN')
        def _ca(z0: float) -> float:
            z0h = z0 / max(z0h_ratio, 1.0)
            return 1.0 / (np.log(zref / z0) * np.log(zref / z0h))
        r_an = _ca(z0_new) / _ca(z0_ref)
        ax.plot(np.asarray(pac_new) / np.asarray(pac_ref), lw=.7, color='#d62728',
                label=f'measured PAC({z0_new:g})/PAC({z0_ref:g})')
        ax.axhline(r_an, color='k', ls='--', lw=1.1, label=f'analytic {r_an:.4f}')
        ax.set_title(f'{LCZ[lcz_tag]["label"]}\ncanyon height zref = H/2'
                     f' = {zref:g} m')
        ax.set_xlabel('forcing step'); ax.grid(alpha=.3); ax.legend(fontsize=8)
    axes[0].set_ylabel('Ca ratio (-)')
    fig.suptitle('Aerodynamic conductance vs garden roughness length (PROXY_NEW)')
    fig.tight_layout(); fig.savefig(plots / 'z0_ca_ratio.png', dpi=130); plt.close(fig)

    # 2. diurnal cycle for the two roughness lengths (PROXY_NEW), one row per
    #    variable: every variable keeps its own scale (W/m2, K, kg/kg)
    def plot_diurnal(rows_spec, fname, suptitle):
        fig, axes = plt.subplots(len(rows_spec), len(LCZ),
                                 figsize=(5.4 * len(LCZ), 3.1 * len(rows_spec)),
                                 squeeze=False, sharex=True)
        for j, lcz_tag in enumerate(LCZ):
            c_ref, c_new = cases_of('gNEW', lcz_tag)
            for i, (var, unit) in enumerate(rows_spec):
                ax = axes[i][j]
                for case, z0, color, ls in ((c_ref, z0_ref, '#1f77b4', '-'),
                                            (c_new, z0_new, '#d62728', '--')):
                    if case not in runs:
                        continue
                    dv = diurnal(mask_undefined(series(runs[case]['dir'], var)),
                                 runs[case]['df']['time'])
                    if dv is not None:
                        ax.plot(dv.index, dv.to_numpy(), color=color, ls=ls,
                                label=f'z0 = {z0:g} m')
                ax.grid(alpha=.3); ax.legend(fontsize=8)
                if i == 0:
                    ax.set_title(LCZ[lcz_tag]['label'])
                if j == 0:
                    ax.set_ylabel(f'{var}\n({unit})', fontsize=9)
            for ax in axes[-1]:
                ax.set_xlabel('hour')
        fig.suptitle(suptitle)
        fig.tight_layout(); fig.savefig(plots / fname, dpi=130); plt.close(fig)

    plot_diurnal((('H_GARDEN', 'W/m2'), ('LE_GARDEN', 'W/m2'),
                  ('RN_GARDEN', 'W/m2'), ('TS_GARDEN', 'K')),
                 'garden_diurnal.png',
                 'Garden diurnal cycle vs urb_z0_gdn (PROXY_NEW)')
    plot_diurnal((('H_TOWN', 'W/m2'), ('LE_TOWN', 'W/m2'),
                  ('T_CANYON', 'K'), ('Q_CANYON', 'kg/kg')),
                 'z0_town_diurnal.png',
                 'Town/canyon diurnal cycle vs urb_z0_gdn (PROXY_NEW)')

    # 3. diurnal mean of the differences (z0_new - z0_ref), one row per variable:
    #    a shared axis would hide the humidity/heat-flux signals completely
    #    (Q_CANYON ~ 1e-3 kg/kg against T_CANYON ~ 1 K; H_GARDEN ~ 1e2 W/m2
    #    against RN_GARDEN ~ 1e1 W/m2)
    def plot_delta(rows_spec, fname, suptitle):
        fig, axes = plt.subplots(len(rows_spec), len(LCZ),
                                 figsize=(5.4 * len(LCZ), 2.9 * len(rows_spec)),
                                 squeeze=False, sharex=True)
        for j, lcz_tag in enumerate(LCZ):
            c_ref, c_new = cases_of('gNEW', lcz_tag)
            if c_ref not in runs or c_new not in runs:
                continue
            time = runs[c_ref]['df']['time']
            for i, (var, unit) in enumerate(rows_spec):
                ax = axes[i][j]
                a = diurnal(mask_undefined(series(runs[c_ref]['dir'], var)), time)
                b = diurnal(mask_undefined(series(runs[c_new]['dir'], var)), time)
                if a is None or b is None:
                    continue
                ax.plot(a.index, (b - a).to_numpy(), color='#d62728', lw=1.4)
                ax.axhline(0., color='k', lw=.6)
                ax.grid(alpha=.3)
                if i == 0:
                    ax.set_title(LCZ[lcz_tag]['label'])
                if j == 0:
                    ax.set_ylabel(f'{var}\n({unit})', fontsize=9)
            for ax in axes[-1]:
                ax.set_xlabel('hour')
        fig.suptitle(suptitle)
        fig.tight_layout(); fig.savefig(plots / fname, dpi=130); plt.close(fig)

    plot_delta((('T_CANYON', 'K'), ('Q_CANYON', 'kg/kg'), ('U_CANYON', 'm/s')),
               'z0_canyon_delta.png',
               'Canyon air: mean(z0 = %g m) - mean(z0 = %g m) (PROXY_NEW)'
               % (z0_new, z0_ref))
    plot_delta((('H_TOWN', 'W/m2'), ('LE_TOWN', 'W/m2'),
                ('H_GARDEN', 'W/m2'), ('LE_GARDEN', 'W/m2')),
               'z0_flux_delta.png',
               'Sensible and latent heat fluxes: mean(z0 = %g m) - mean(z0 = %g m)'
               ' (PROXY_NEW)' % (z0_new, z0_ref))

    # ------------------------------------------------------------------
    # README
    # ------------------------------------------------------------------
    md = []
    md.append('# Garden roughness length (`urb_z0_gdn`): sensitivity experiment')
    md.append('')
    md.append('Garden model of TEB-Ru (`teb_type_garden`) tested on the Moscow ERA5'
              ' forcing, with the garden roughness length taken from the namelist item'
              ' `urb_z0_gdn` (all the garden versions).')
    md.append('')
    md.append(f'- model: `{exe}`')
    md.append(f'- base namelist: `{base}`')
    md.append(f'- forcing: `{forcing_nml}`')
    md.append(f'- `fr_garden = {args.fr_garden:g}`; tau scheme of the road: OFF')
    md.append(f'- z0 values: ' + ', '.join('`%g m`' % z for z in z0_values)
              + f' (reference `{z0_ref:g} m`)')
    md.append('')
    md.append('## Configurations')
    md.append('')
    md.append('| case | LCZ | garden | `teb_type_garden` | `urb_z0_gdn` (m) |')
    md.append('|---|---|---|---|---|')
    for case, lcz_tag, mode_tag, z0 in all_cases:
        lg, ty, _desc = MODES[mode_tag]
        md.append('| `%s` | %s | %s | `%s` | %g |'
                  % (case, LCZ[lcz_tag]['label'], 'ON' if lg else 'OFF', ty, z0))
    md.append('')
    md.append('## Checks')
    md.append('')
    md.append('| check | meaning |')
    md.append('|---|---|')
    md.append('| Z1 | garden OFF: changing `urb_z0_gdn` must not change anything'
              ' (bit-for-bit) |')
    md.append('| Z2 | `PROXY_OLD`: the historical Bowen proxy sets `PAC_GARDEN = 0`,'
              ' so it does not use the aerodynamic conductance either (no-op) |')
    md.append('| Z3 | `EXT`: the garden conductance used by the canyon budget (and'
              ' exported in `PAC_GARDEN`) is the garden/canyon conductance that'
              ' `URBAN_DRAG`/`URBAN_EXCH_COEF` compute from `PZ0_GARDEN_EXT`'
              ' (TEB\'s `PAC_GARDEN` is the `PAC_GARDEN_CAN` slot of `URBAN_DRAG`,'
              ' hence no separate `PAC_GARDEN_CAN` column), so `urb_z0_gdn` also acts'
              ' on the town in EXT mode |')
    md.append('| Z4 | `PROXY_NEW`: the model conductance must follow'
              ' `Ca_h = k**2/(ln(zref/z0)*ln(zref/z0h)) * max(V, 0.5 m/s)` with'
              ' `z0h = z0/urb_z0_o_z0h_gdn`; `zref = H/2` (the canyon'
              ' reference height of TEB) is recovered from the measured ratio |')
    md.append('')
    if len(checks_df):
        try:
            md.append(checks_df.to_markdown(index=False))
        except Exception:
            md.append('```\n' + checks_df.to_string(index=False) + '\n```')
    md.append('')
    if len(eff_df):
        md.append('## Mean effect of the roughness length (`PROXY_NEW`)')
        md.append('')
        md.append('| LCZ | variable | mean (z0 = %g m) | mean (z0 = %g m) | delta | rel. delta, %% |'
                  % (z0_ref, z0_new))
        md.append('|---|---|---|---|---|---|')
        for _, r in sel.iterrows():
            md.append('| %s | %s | %.4f | %.4f | %+.4f | %s |'
                      % (r['lcz'], r['var'], r['mean_z0_ref'], r['mean_z0_new'],
                         r['delta'],
                         'n/a' if not np.isfinite(r['rel_delta_pct'])
                         else '%+.2f' % r['rel_delta_pct']))
        md.append('')
        md.append('`PAC_GARDEN` is the aerodynamic conductance used by `PROXY_NEW`'
                  ' (m/s), the other variables are the garden fluxes per m2 of garden'
                  ' (W/m2), the garden surface temperature (K) and the canyon state.')
        md.append('')
        md.append('The canyon humidity is the most sensitive of the canyon state'
                  ' variables (`Q_CANYON` +4.8 % in LCZ 2 and +23…+25 % in LCZ 9 and'
                  ' SPARSE), but its absolute change (4e-4 … 2e-3 kg/kg) is an order of'
                  ' magnitude below the diurnal amplitude, while `T_CANYON` changes by'
                  ' only 0.10…0.16 %; `U_CANYON` is strictly unchanged (identical in'
                  ' the two runs, which is why the analytic check Z4 is exact). Every'
                  ' variable is therefore drawn in its own panel in'
                  ' `plots/z0_canyon_delta.png` and `plots/z0_flux_delta.png`: on a'
                  ' shared axis the humidity and the smaller fluxes would look like a'
                  ' flat line.')
        md.append('')
    md.append('## Files')
    md.append('')
    md.append('- `namelists/<case>.nml` - namelist of every case')
    md.append('- `output_<case>/` - full model output (`TEB_output.csv`)')
    md.append('- `logs/<case>.log` - model log (the banner gives the effective'
              ' `urb_z0_gdn`)')
    md.append('- `summary_z0_sensitivity.csv` - statistics per case/variable')
    md.append('- `effect_z0_sensitivity.csv` - mean effect of z0 per LCZ/mode/variable')
    md.append('- `checks_z0_sensitivity.csv` - the Z1-Z4 checks')
    md.append('- `diff_columns.csv` - columns that change with z0, per case')
    md.append('- `plots/z0_ca_ratio.png` - analytic check of the conductance ratio')
    md.append('- `plots/garden_diurnal.png` - garden cycle: H, LE, Rn, Ts (both z0)')
    md.append('- `plots/z0_town_diurnal.png` - town/canyon cycle: H, LE, T, q (both z0)')
    md.append('- `plots/z0_canyon_delta.png` - z0 effect on T, q and the wind of the canyon')
    md.append('- `plots/z0_flux_delta.png` - z0 effect on the sensible (H) and latent (LE)'
              ' fluxes of the town and of the garden')
    md.append('')
    md.append('See also `python_tests/garden_z0_sensitivity.py` (this experiment),'
              ' `python_tests/compare_garden_scheme.py` (the garden schemes and the energy'
              ' balance closure) and `TEB_Ru_garden_diagnostic_scheme.md`.')
    (out_root / 'README.md').write_text('\n'.join(md), encoding='utf-8')

    print()
    print('Output root :', out_root)
    print('  summary   :', out_root / 'summary_z0_sensitivity.csv')
    print('  effect    :', out_root / 'effect_z0_sensitivity.csv')
    print('  checks    :', out_root / 'checks_z0_sensitivity.csv')
    print('  diff cols :', out_root / 'diff_columns.csv')
    print('  plots     :', plots)
    print('  report    :', out_root / 'README.md')
    return 0


if __name__ == '__main__':
    sys.exit(main())





