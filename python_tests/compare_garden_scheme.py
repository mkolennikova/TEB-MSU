#!/usr/bin/env python
"""
Extended testing of the garden scheme of TEB-Ru over Moscow local climate zones.

Purpose
-------
Run the garden model in the configurations of the Moscow LCZs (LCZ 2, LCZ 9 and
the extreme SPARSE case of ``python_tests/sensitivity_zd.py``) with the three garden
options of the namelist key ``teb_type_garden`` and check that

  * the new diagnostic proxy (``PROXY_NEW``) works in very different canyon
    geometries (H/W = 1.5, 0.15 and 0.0086),
  * **all the energy balances close**:
      - garden surface      : RN_GARDEN = H_GARDEN + LE_GARDEN          (G = 0)
      - garden radiation    : RN_GARDEN vs (1-a)*SW_abs + em*LW - em*sig*TS**4
      - historical proxy    : H + LE = 0.2*RN + 0.8*RN (identity check)
      - town                : RN_TOWN + AHF + H_WASTE + LE_WASTE
                              - H_TOWN - LE_TOWN - GFLUX_TOWN = 0
  * the garden diagnostics stay in physical bounds and that the new scheme does
    not leak into the runs where the garden is switched off (bit-for-bit no-op).

Configurations (4 per LCZ, tau scheme OFF in all of them)
---------------------------------------------------------
    gOFF_OLD : teb_lgarden = .FALSE., teb_type_garden = 'PROXY_OLD'
    gOFF_NEW : teb_lgarden = .FALSE., teb_type_garden = 'PROXY_NEW'
    gOLD     : teb_lgarden = .TRUE.,  teb_type_garden = 'PROXY_OLD'
    gNEW     : teb_lgarden = .TRUE.,  teb_type_garden = 'PROXY_NEW'

The two ``gOFF_*`` runs must give identical model output (the garden model must
not be entered at all); the two ``g*`` runs give the garden with the historical
Bowen proxy and with the new diagnostic balance.

Files (kept; use --force to re-run a case)
------------------------------------------
  <out-root>/namelists/<case>.nml          namelist of every case
  <out-root>/output_<case>/                model output (TEB_output.csv)
  <out-root>/logs/<case>.log               model log
  <out-root>/summary_garden_scheme.csv     statistics per case
  <out-root>/checks_garden_scheme.csv      the balance checks (one row per check)
  <out-root>/plots/*.png                   comparison figures
  <out-root>/README.md                     description and results

Usage
-----
    python python_tests/compare_garden_scheme.py
    python python_tests/compare_garden_scheme.py --list
    python python_tests/compare_garden_scheme.py --only LCZ2_gNEW,LCZ9_gOLD
    python python_tests/compare_garden_scheme.py --skip-run      # post-process only
    python python_tests/compare_garden_scheme.py --force         # re-run existing
    python python_tests/compare_garden_scheme.py --fr-garden 0.4
    python python_tests/compare_garden_scheme.py --z0-garden 0.8

The namelist item ``urb_z0_gdn`` (garden roughness length, used by all the garden
versions) is left to the model default when ``--z0-garden`` is not given; see
``python_tests/garden_z0_sensitivity.py`` for the dedicated sensitivity experiment.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import f90nml

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
    'gOFF_OLD': (False, 'PROXY_OLD', 'garden OFF (type PROXY_OLD)'),
    'gOFF_NEW': (False, 'PROXY_NEW', 'garden OFF (type PROXY_NEW)'),
    'gOLD':     (True,  'PROXY_OLD', 'garden ON, historical Bowen proxy'),
    'gNEW':     (True,  'PROXY_NEW', 'garden ON, new diagnostic balance'),
}

#: garden diagnostics written by the model (per m2 of garden)
GARDEN_COLS = ('TS_GARDEN', 'RN_GARDEN', 'H_GARDEN', 'LE_GARDEN',
               'EVAP_GARDEN', 'QSAT_GARDEN', 'PHU_GARDEN',
               'PAC_AGG_GARDEN', 'PAC_GARDEN')

#: town / canyon columns compared between the modes
TOWN_COLS = ('T_CANYON', 'Q_CANYON', 'H_TOWN', 'LE_TOWN', 'RN_TOWN',
             'GFLUX_TOWN', 'T_ROAD1')

#: anthropogenic heat diagnostics needed by the town energy balance check
ANTHRO_COLS = ('AHF_TRAFFIC', 'H_WASTE', 'LE_WASTE')

#: radiative columns needed by the garden radiation check
RAD_COLS = ('Forc_DIR_SW', 'Forc_SCA_SW', 'Forc_LW')


def cases(lcz_tags=None, mode_tags=None):
    """Deterministic list of (case, lcz_tag, mode_tag)."""
    out = []
    for lcz_tag in (lcz_tags or list(LCZ)):
        for mode_tag, (_lg, _ty, _desc) in MODES.items():
            if mode_tags and mode_tag not in mode_tags:
                continue
            out.append((f'{lcz_tag}_{mode_tag}', lcz_tag, mode_tag))
    return out


def build_namelist(base_nml: Path, lcz_tag: str, mode_tag: str, path: Path,
                   fr_garden: float, urb_z0_gdn: float | None = None) -> Path:
    """Namelist of one case: base namelist + LCZ + garden mode (tau scheme off)."""
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
    p['teb_ltau_scheme'] = False          # tau scheme of the road: OFF
    if urb_z0_gdn is not None:
        # garden roughness length, used by all the garden versions
        p['urb_z0_gdn'] = float(urb_z0_gdn)
    path.parent.mkdir(parents=True, exist_ok=True)
    nml.write(str(path), force=True)
    return path


def read_case(out_dir: Path) -> dict:
    """All the columns of interest of one run (+ time stamps)."""
    data = {}
    for name in GARDEN_COLS + TOWN_COLS + ANTHRO_COLS + RAD_COLS:
        data[name] = series(out_dir, name)
    csv = out_dir / 'TEB_output.csv'
    data['time'] = (pd.read_csv(csv, sep=';', usecols=['time'])['time']
                    if csv.is_file() else None)
    return data


def mask_undefined(x):
    """Replace the TEB XUNDEF sentinel by NaN (the values are then ignored)."""
    if x is None:
        return None
    x = np.asarray(x, dtype=float).copy()
    x = np.where(x >= XUNDEF, np.nan, x)
    return x


# ---------------------------------------------------------------------------
# Balance checks
# ---------------------------------------------------------------------------

def check_garden_closure(data):
    """B1: garden surface balance RN = H + LE (G = 0).

    Returns (max_abs_residual, mean_abs_residual, n_steps).

    NOTE: the net radiation of the garden is computed by TEB from the radiation
    INTERCEPTED inside the canyon (sky view factor, wall reflections, shadowing)
    and not from the horizontal atmospheric forcing, so the balance cannot be
    re-derived from the CSV columns alone; the residual below is the exact
    model-internal closure (its magnitude is the Newton convergence level).
    """
    rn = mask_undefined(data['RN_GARDEN'])
    h = mask_undefined(data['H_GARDEN'])
    le = mask_undefined(data['LE_GARDEN'])
    res = rn - (h + le)
    res = res[np.isfinite(res)]
    if res.size == 0:
        return np.nan, np.nan, 0
    return float(np.max(np.abs(res))), float(np.mean(np.abs(res))), int(res.size)


def canyon_radiation_offset(data, alb=0.15, emis=0.98, sig=5.6697e-8):
    """B4 (informational): offset between RN_GARDEN and the horizontal forcing.

    In a deep canyon the garden receives less short-wave radiation (shadowing)
    and more long-wave radiation (warm walls) than the atmosphere provides on a
    horizontal surface, so this offset is a measure of the canyon interception,
    NOT of an error. It must be small for a nearly free-standing configuration
    (SPARSE, H/W ~ 0.009) and may reach a few hundred W/m2 in a dense canyon
    (LCZ 2, H/W = 1.5).
    """
    rn = mask_undefined(data['RN_GARDEN'])
    ts = mask_undefined(data['TS_GARDEN'])
    sw = mask_undefined(data['Forc_DIR_SW']) + mask_undefined(data['Forc_SCA_SW'])
    lw = mask_undefined(data['Forc_LW'])
    rn_horiz = (1.0 - alb) * sw + emis * (lw - sig * ts**4)
    d = rn - rn_horiz
    d = d[np.isfinite(d)]
    if d.size == 0:
        return np.nan, np.nan
    return float(np.abs(d).max()), float(np.mean(d))


def check_old_identity(data, br=0.25):
    """B2: the historical proxy is a pure Bowen partition of the net radiation."""
    rn = mask_undefined(data['RN_GARDEN'])
    h = mask_undefined(data['H_GARDEN'])
    le = mask_undefined(data['LE_GARDEN'])
    res = rn - (h + le)
    res = res[np.isfinite(res)]
    if res.size == 0:
        return np.nan, 0
    return float(np.max(np.abs(res))), int(res.size)


def check_town_balance(data):
    """B3: RN_TOWN + AHF + H_WASTE + LE_WASTE - H_TOWN - LE_TOWN - GFLUX_TOWN.

    The town budget of TEB closes only to the accuracy with which every term of
    the town surface (roofs, walls, windows, ground, anthropogenic heat) is
    accounted for exactly once; the residual is compared between the garden
    modes, because the garden must not change it beyond its own share.
    """
    def g(name):
        return mask_undefined(data.get(name))
    rn = g('RN_TOWN'); h = g('H_TOWN'); le = g('LE_TOWN'); gf = g('GFLUX_TOWN')
    if any(v is None for v in (rn, h, le, gf)):
        return np.nan, np.nan, 0
    res = rn - h - le - gf
    for v in (g('AHF_TRAFFIC'), g('H_WASTE'), g('LE_WASTE')):
        if v is not None:
            res = res + v
    res = res[np.isfinite(res)]
    if res.size == 0:
        return np.nan, np.nan, 0
    return float(np.max(np.abs(res))), float(np.mean(res)), int(res.size)


def check_bounds(data):
    """B6: physical bounds of the garden surface state."""
    ts = mask_undefined(data['TS_GARDEN'])
    ts = ts[np.isfinite(ts)]
    pac = mask_undefined(data['PAC_GARDEN'])
    pac = pac[np.isfinite(pac)]
    out = dict(
        ts_min=float(ts.min()) if ts.size else np.nan,
        ts_max=float(ts.max()) if ts.size else np.nan,
        ts_n=ts.size,
        pac_min=float(pac.min()) if pac.size else np.nan,
        pac_max=float(pac.max()) if pac.size else np.nan,
        pac_n=pac.size,
        ts_at_bound=int(np.sum((ts <= 230.0) | (ts >= 350.0))) if ts.size else 0,
    )
    return out


# ---------------------------------------------------------------------------
# Main
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
                    help='output root (default: <site>/compare_garden_scheme)')
    ap.add_argument('--exe', default=None, help='model executable')
    ap.add_argument('--only', default=None, help='comma separated list of cases')
    ap.add_argument('--skip-run', action='store_true', help='post-process only')
    ap.add_argument('--force', action='store_true', help='re-run existing cases')
    ap.add_argument('--list', action='store_true', help='list the cases and exit')
    ap.add_argument('--fr-garden', type=float, default=0.3,
                    help='garden fraction of the urban tile (default: %(default)s)')
    ap.add_argument('--z0-garden', dest='urb_z0_gdn', type=float, default=None,
                    help='garden roughness length (m), written as the namelist item'
                         ' urb_z0_gdn (default: model default, 0.1 m)')
    ap.add_argument('--days', type=float, default=None,
                    help='restrict the post-processing to the first N days')
    args = ap.parse_args(argv)

    work = Path(args.work_dir)
    site_dir = work / args.site
    base = (Path(args.base_namelist) if args.base_namelist
            else site_dir / 'params_CTRL.nml')
    if not base.is_file():
        base = MODEL_DIR / 'namelist' / 'namelist.nml'
    forcing_nml = (Path(args.forcing_nml) if args.forcing_nml
                   else site_dir / 'forcing_ERA5' / 'namelist_forcing.nml')
    out_root = (Path(args.out_root) if args.out_root
                else site_dir / 'compare_garden_scheme')
    exe = Path(args.exe) if args.exe else MODEL_DIR / 'build' / 'TEB_offline.exe'

    all_cases = cases()
    if args.only:
        selected = {c.strip() for c in args.only.split(',')}
        all_cases = [c for c in all_cases if c[0] in selected]

    if args.list:
        print(f'{"case":<18} {"LCZ":<46} garden mode')
        for case, lcz_tag, mode_tag in all_cases:
            print(f'{case:<18} {LCZ[lcz_tag]["label"]:<46} {MODES[mode_tag][2]}')
        return 0

    out_root.mkdir(parents=True, exist_ok=True)
    (out_root / 'namelists').mkdir(exist_ok=True)
    (out_root / 'logs').mkdir(exist_ok=True)

    print('=' * 78)
    print('  base namelist :', base)
    print('  forcing       :', forcing_nml)
    print('  output root   :', out_root)
    print('  cases         :', len(all_cases), f'(fr_garden = {args.fr_garden:g})')
    print('  urb_z0_gdn     :', 'model default' if args.urb_z0_gdn is None
          else f'{args.urb_z0_gdn:g} m')
    print('=' * 78)

    info = {case: (lcz_tag, mode_tag) for case, lcz_tag, mode_tag in all_cases}

    # ------------------------------------------------------------------
    # runs
    # ------------------------------------------------------------------
    for case, lcz_tag, mode_tag in all_cases:
        nml_path = out_root / 'namelists' / f'{case}.nml'
        out_dir = out_root / f'output_{case}'
        log_file = out_root / 'logs' / f'{case}.log'
        build_namelist(base, lcz_tag, mode_tag, nml_path, args.fr_garden,
                       args.urb_z0_gdn)
        if args.skip_run:
            continue
        if (out_dir / 'TEB_output.csv').is_file() and not args.force:
            print(f'  [skip] {case}')
            continue
        print(f'  [run ] {case}  ({LCZ[lcz_tag]["label"]}, {mode_tag})')
        rc = run_case(exe, forcing_nml, nml_path, out_dir, log_file)
        if rc != 0:
            print(f'    WARNING: {case} returned code {rc}')

    # ------------------------------------------------------------------
    # read + statistics
    # ------------------------------------------------------------------
    runs = {}
    for case in info:
        d = out_root / f'output_{case}'
        if (d / 'TEB_output.csv').is_file():
            runs[case] = read_case(d)

    if args.days:
        for case, data in runs.items():
            if data['time'] is not None:
                t0 = pd.Timestamp(data['time'].iloc[0])
                tmax = t0 + pd.Timedelta(days=args.days)
                n = int((pd.to_datetime(data['time']) <= tmax).sum())
                for k, v in data.items():
                    if v is not None and k != 'time':
                        data[k] = np.asarray(v)[:n]

    rows = []
    for case, data in runs.items():
        lcz_tag, mode_tag = info[case]
        for var in GARDEN_COLS + TOWN_COLS + ANTHRO_COLS:
            v = mask_undefined(data.get(var))
            if v is None:
                continue
            fin = v[np.isfinite(v)]
            if fin.size == 0:
                continue
            st = stats_of(fin)
            rows.append(dict(case=case, lcz=lcz_tag, mode=mode_tag, var=var,
                             n=st['n'], mean=st['mean'], std=st['std'],
                             min=st['min'], max=st['max'],
                             p05=st['p05'], p50=st['p50'], p95=st['p95']))
    summary = pd.DataFrame(rows)
    summary.to_csv(out_root / 'summary_garden_scheme.csv', index=False,
                   float_format='%.6f')

    # ------------------------------------------------------------------
    # balance checks
    # ------------------------------------------------------------------
    checks = []
    for case, data in runs.items():
        lcz_tag, mode_tag = info[case]
        if mode_tag == 'gNEW':
            mx, mean, n = check_garden_closure(data)
            checks.append(dict(case=case, lcz=lcz_tag, mode=mode_tag,
                               check='B1 garden RN=H+LE',
                               max_abs=mx, mean_abs=mean, n=n))
            rad, rad_mean = canyon_radiation_offset(data)
            checks.append(dict(case=case, lcz=lcz_tag, mode=mode_tag,
                               check='B4 canyon interception offset (info)',
                               max_abs=rad, mean_abs=rad_mean, n=n))
        if mode_tag == 'gOLD':
            mx, n = check_old_identity(data)
            checks.append(dict(case=case, lcz=lcz_tag, mode=mode_tag,
                               check='B2 proxy H+LE=RN', max_abs=mx,
                               mean_abs=np.nan, n=n))
        mx, mean, n = check_town_balance(data)
        checks.append(dict(case=case, lcz=lcz_tag, mode=mode_tag,
                           check='B3 town balance', max_abs=mx,
                           mean_abs=mean, n=n))
        b = check_bounds(data)
        checks.append(dict(case=case, lcz=lcz_tag, mode=mode_tag,
                           check='B6 TS at the [230,350] K bound',
                           max_abs=(b['ts_at_bound'] if b['ts_n'] else np.nan),
                           mean_abs=np.nan, n=b['ts_n']))

    # B5: no-op between the two garden-OFF configurations
    for lcz_tag in LCZ:
        c_old, c_new = f'{lcz_tag}_gOFF_OLD', f'{lcz_tag}_gOFF_NEW'
        if c_old in runs and c_new in runs:
            mx, n = 0.0, 0
            for var in GARDEN_COLS + TOWN_COLS + ANTHRO_COLS:
                a = mask_undefined(runs[c_old].get(var))
                b = mask_undefined(runs[c_new].get(var))
                if a is None or b is None:
                    continue
                fin = np.isfinite(a) & np.isfinite(b)
                if fin.any():
                    mx = max(mx, float(np.max(np.abs(a[fin] - b[fin]))))
                    n += int(fin.sum())
            checks.append(dict(case=f'{lcz_tag}_gOFF', lcz=lcz_tag, mode='gOFF',
                               check='B5 no-op OLD vs NEW', max_abs=mx,
                               mean_abs=np.nan, n=n))
    checks_df = pd.DataFrame(checks)
    checks_df.to_csv(out_root / 'checks_garden_scheme.csv', index=False,
                     float_format='%.6e')

    print()
    print('=== balance checks ===')
    pd.set_option('display.width', 200)
    print(checks_df.to_string(index=False) if len(checks_df) else '(no runs)')

    # ------------------------------------------------------------------
    # plots
    # ------------------------------------------------------------------
    plots = out_root / 'plots'
    plots.mkdir(exist_ok=True)

    def diurnal(v, time):
        if v is None or time is None:
            return None
        s = pd.Series(np.asarray(v, dtype=float), index=pd.to_datetime(time))
        return s.groupby(s.index.hour).mean().to_numpy()

    # 1. garden diurnal cycle per LCZ (NEW vs OLD)
    for var, fname, ylab in (
            ('TS_GARDEN', 'garden_ts_diurnal.png', 'garden surface temperature (K)'),
            ('H_GARDEN', 'garden_h_diurnal.png', 'garden sensible heat flux (W/m2)'),
            ('LE_GARDEN', 'garden_le_diurnal.png', 'garden latent heat flux (W/m2)')):
        fig, axes = plt.subplots(1, len(LCZ), figsize=(5.5 * len(LCZ), 4.2), sharey=True)
        if len(LCZ) == 1:
            axes = [axes]
        for ax, lcz_tag in zip(axes, LCZ):
            for mode_tag, color, ls in (('gOLD', '#1f77b4', '-'), ('gNEW', '#d62728', '--')):
                case = f'{lcz_tag}_{mode_tag}'
                if case not in runs:
                    continue
                data = runs[case]
                dv = diurnal(mask_undefined(data.get(var)), data.get('time'))
                if dv is not None:
                    ax.plot(dv, color=color, ls=ls, label=mode_tag)
            ax.set_title(LCZ[lcz_tag]['label'])
            ax.set_xlabel('hour'); ax.grid(alpha=.3); ax.legend(fontsize=8)
        axes[0].set_ylabel(ylab)
        fig.suptitle(var)
        fig.tight_layout(); fig.savefig(plots / fname, dpi=130); plt.close(fig)

    # 2. NEW vs OLD scatter of the garden variables
    fig, axes = plt.subplots(1, 3, figsize=(15, 4.5))
    for ax, var in zip(axes, ('H_GARDEN', 'LE_GARDEN', 'TS_GARDEN')):
        for lcz_tag in LCZ:
            c_old, c_new = f'{lcz_tag}_gOLD', f'{lcz_tag}_gNEW'
            if c_old not in runs or c_new not in runs:
                continue
            a = mask_undefined(runs[c_old].get(var))
            b = mask_undefined(runs[c_new].get(var))
            if a is None or b is None:
                continue
            fin = np.isfinite(a) & np.isfinite(b)
            ax.scatter(a[fin], b[fin], s=3, alpha=.35, label=lcz_tag)
        ax.set_xlabel(f'{var} (PROXY_OLD)')
        ax.set_ylabel(f'{var} (PROXY_NEW)')
        ax.grid(alpha=.3); ax.legend(fontsize=8)
    fig.suptitle('Garden surface: historical proxy vs diagnostic scheme')
    fig.tight_layout(); fig.savefig(plots / 'garden_new_vs_old_scatter.png', dpi=130)
    plt.close(fig)

    # 3. effect of the garden scheme on the town, per LCZ (NEW - OLD)
    fig, ax = plt.subplots(figsize=(9, 4.5))
    cmp_vars = [('H_TOWN', 'dH'), ('LE_TOWN', 'dLE'),
                ('GFLUX_TOWN', 'dG'), ('T_CANYON', 'dT')]
    x = np.arange(len(LCZ)); w = 0.2
    for k, (var, lab) in enumerate(cmp_vars):
        vals = []
        for lcz_tag in LCZ:
            c_old, c_new = f'{lcz_tag}_gOLD', f'{lcz_tag}_gNEW'
            if c_old not in runs or c_new not in runs:
                vals.append(np.nan); continue
            a = mask_undefined(runs[c_old].get(var))
            b = mask_undefined(runs[c_new].get(var))
            if a is None or b is None:
                vals.append(np.nan); continue
            d = (b - a)[np.isfinite(b - a)]
            vals.append(float(np.mean(d)) if d.size else np.nan)
        ax.bar(x + (k - 1.5) * w, vals, w, label=lab)
    ax.set_xticks(x)
    ax.set_xticklabels([LCZ[t]['label'] for t in LCZ], rotation=12, ha='right')
    ax.axhline(0, color='k', lw=.5); ax.grid(alpha=.3, axis='y'); ax.legend()
    ax.set_title('Mean effect of the new garden scheme on the town (NEW - OLD)')
    fig.tight_layout(); fig.savefig(plots / 'garden_town_effect.png', dpi=130)
    plt.close(fig)

    # 4. closure residual of the new scheme (all LCZ)
    fig, ax = plt.subplots(figsize=(11, 4.5))
    for lcz_tag in LCZ:
        case = f'{lcz_tag}_gNEW'
        if case not in runs:
            continue
        data = runs[case]
        rn = mask_undefined(data['RN_GARDEN'])
        h = mask_undefined(data['H_GARDEN'])
        le = mask_undefined(data['LE_GARDEN'])
        ax.plot(pd.to_datetime(data['time']), rn - (h + le), lw=.7, label=lcz_tag)
    ax.set_ylabel('RN - H - LE (W/m2)'); ax.set_xlabel('time')
    ax.set_title('Garden energy balance closure (PROXY_NEW)')
    ax.grid(alpha=.3); ax.legend(fontsize=8)
    fig.tight_layout(); fig.savefig(plots / 'garden_closure.png', dpi=130); plt.close(fig)

    # ------------------------------------------------------------------
    # README
    # ------------------------------------------------------------------
    md = []
    md.append('# Garden scheme: extended testing over Moscow LCZs')
    md.append('')
    md.append('Garden model of TEB-Ru (`teb_type_garden`) tested on the Moscow ERA5'
              ' forcing (`%s`).' % forcing_nml)
    md.append('')
    md.append('## Configurations')
    md.append('')
    md.append('| case | LCZ | garden | `teb_type_garden` |')
    md.append('|---|---|---|---|')
    for case, lcz_tag, mode_tag in all_cases:
        lg, ty, _desc = MODES[mode_tag]
        md.append('| `%s` | %s | %s | `%s` |'
                  % (case, LCZ[lcz_tag]['label'], 'ON' if lg else 'OFF', ty))
    md.append('')
    md.append('The tau scheme of the road is OFF in every case; `fr_garden = %g`.'
              % args.fr_garden)
    md.append('')
    md.append('Garden roughness length (`urb_z0_gdn`): %s.'
              % ('model default (0.1 m)' if args.urb_z0_gdn is None
                 else '`%g m`' % args.urb_z0_gdn))
    md.append('')
    md.append('## Balance checks')
    md.append('')
    md.append('| check | meaning |')
    md.append('|---|---|')
    md.append('| B1 | garden surface balance `RN_GARDEN = H_GARDEN + LE_GARDEN` (G = 0) |')
    md.append('| B2 | historical proxy identity `H + LE = RN` (Bowen partition) |')
    md.append('| B3 | town balance `RN_TOWN + AHF + H_WASTE + LE_WASTE'
              ' - H_TOWN - LE_TOWN - GFLUX_TOWN = 0` |')
    md.append('| B4 | offset between `RN_GARDEN` and the horizontal forcing (informational:'
              ' the garden exchanges with the canyon radiation, not with the horizontal'
              ' forcing; expected to be small for SPARSE and large for LCZ 2) |')
    md.append('| B5 | no-op: the two garden-OFF configurations are identical |')
    md.append('| B6 | number of steps at the `[230,350] K` safety bound of `TS_GARDEN` |')
    md.append('')
    if len(checks_df):
        try:
            md.append(checks_df.to_markdown(index=False))
        except Exception:
            md.append('```\n' + checks_df.to_string(index=False) + '\n```')
    md.append('')
    md.append('## Files')
    md.append('')
    md.append('- `summary_garden_scheme.csv` - statistics per case/variable')
    md.append('- `checks_garden_scheme.csv` - the balance checks')
    md.append('- `plots/garden_*_diurnal.png` - garden diurnal cycle per LCZ')
    md.append('- `plots/garden_new_vs_old_scatter.png` - NEW vs OLD (H, LE, TS)')
    md.append('- `plots/garden_town_effect.png` - mean effect of the scheme on the town')
    md.append('- `plots/garden_closure.png` - closure residual of the new scheme')
    md.append('')
    (out_root / 'README.md').write_text('\n'.join(md), encoding='utf-8')

    print()
    print('Output root :', out_root)
    print('  summary   :', out_root / 'summary_garden_scheme.csv')
    print('  checks    :', out_root / 'checks_garden_scheme.csv')
    print('  plots     :', plots)
    print('  report    :', out_root / 'README.md')
    return 0


if __name__ == '__main__':
    sys.exit(main())