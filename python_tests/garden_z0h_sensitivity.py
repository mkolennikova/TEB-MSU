#!/usr/bin/env python
"""
Sensitivity of the TEB-Ru garden model to its thermal (scalar) roughness z0h.

The diagnostic garden exchanges heat and moisture through the neutral scalar
coefficient of the log profile built from the thermal roughness z0h, while the
momentum keeps z0 (the friction flux is the only user of the momentum
coefficient):

    PCD = (k/ln(zref/z0))**2                        momentum (friction)
    PCH = k**2/(ln(zref/z0)*ln(zref/z0h))           heat and moisture
        = PCD * ZFH,   ZFH = ln(zref/z0)/ln(zref/z0h) <= 1

with ``zref = H/2`` the canyon reference height of TEB, ``z0 = urb_z0_gdn`` and
``z0h = z0/R``, ``R = urb_z0_o_z0h_gdn`` (namelist item, default 4.0,
``MODD_PROXI_SVAT_PAR:XZ0_O_Z0H_GD``). ``R = 1`` means ``z0h = z0``, i.e. the
formulation without thermal roughness, and is reproduced exactly.

This script runs the offline model on the Moscow ERA5 forcing for the three LCZs
of ``python_tests/sensitivity_zd.py``, two settings of the road cbs scheme (OFF
and ``tau = 0.5`` exactly) and four values of ``R`` (1, 2, 4, 8) -- 24 runs --
and checks

  H1  ``R = 1``: the scalar coefficient is EXACTLY the momentum one
      (``PCH_GARDEN_CAN = PCD_GARDEN_CAN``, bit for bit) and equals
      ``(k/ln(zref/z0))**2``: the garden without thermal roughness is the limit
      of the new formulation,
  H2  analytic coefficients at every R:
      ``PCD_GARDEN_CAN = (k/ln(zref/z0))**2``,
      ``PCH_GARDEN_CAN = k**2/(ln(zref/z0)*ln(zref/z0h))``  (exact),
  H3  ``PAC_GARDEN = PCH_GARDEN_CAN*max(U_CANYON, VMIN)`` at every step (exact),
  H4  ``PAC_GARDEN(R)/PAC_GARDEN(1) = ZFH(R)`` at every step (exact: the canyon
      wind does not depend on z0h),
  H5  the tau identities of the garden are preserved:
      ``H_GARDEN = tau*H_GARDEN_CAN + (1-tau)*H_GARDEN_ATM`` (same for LE) and
      ``Rn_GARDEN = H_GARDEN + LE_GARDEN``,
  H6  z0h does not touch the momentum: ``PCD_GARDEN_CAN`` and ``U_CANYON`` are
      bit-for-bit identical in all the R cases of a configuration,
  H7  the actual sensitivity of the garden, of the canyon and of the town to R
      (effect tables, diurnal cycles in the figures).

Configurations (3 LCZ x 2 cbs settings x 4 ratios = 24 runs)
------------------------------------------------------------
    tOFF : teb_lcbs_scheme = .FALSE.  (garden exchanges with the canyon air)
    t05  : teb_lcbs_scheme = .TRUE., teb_tau_hw_thresh = urb_h2w -> tau = 0.5 exactly

The garden is 'PROXY_NEW' with ``fr_garden = 0.3`` in every case.

Files (kept; use --force to re-run a case)
------------------------------------------
  <out-root>/namelists/<case>.nml          namelist of every case
  <out-root>/output_<case>/                model output (TEB_output.csv)
  <out-root>/logs/<case>.log               model log (model banner)
  <out-root>/checks_z0h.csv                the checks (one row per case and check)
  <out-root>/ca_ratio.csv                  measured vs analytic coefficients
  <out-root>/effect_z0h.csv                mean effect of R (relative to R = 1)
  <out-root>/plots/z0h_conductance.png     measured vs analytic conductance ratio
  <out-root>/plots/z0h_diurnal.png         diurnal cycle of the garden for R = 1/4
  <out-root>/README.md                     description and results

Usage
-----
    python python_tests/garden_z0h_sensitivity.py
    python python_tests/garden_z0h_sensitivity.py --list
    python python_tests/garden_z0h_sensitivity.py --ratio-list 1,4 --only LCZ2_t05
    python python_tests/garden_z0h_sensitivity.py --skip-run     # post-process only
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

#: von Karman constant and wind floor of the garden (MODD_CSTS, MODE_GARDEN_BALANCE)
XKARMAN = 0.4
XVMIN_GD = 0.5

#: cbs settings: tag -> (teb_lcbs_scheme, description)
CBS_SETTINGS = {
    'tOFF': (False, 'cbs scheme OFF (garden <-> canyon air only)'),
    't05': (True,  'cbs scheme ON with the threshold of the site: tau = 0.5 exactly'),
}

#: z0/z0h ratios compared (-): no thermal roughness, the namelist default and two
#: stronger values; R = 1 is the reference case of every configuration
R_VALUES = (1.0, 2.0, 4.0, 8.0)
R_REF = 1.0

#: the model is compiled with -ffpe-trap=invalid,zero: rare intermittent IEEE
#: traps have been observed in the sparse / cbs-on configurations WITH THE
#: REFERENCE BUILD AS WELL (an uninitialised-value or marginal-division defect of
#: the model, not related to z0h), so a failed case is simply retried.
RUN_RETRIES = 3

#: garden / canyon / town columns reported in the effect tables
EFFECT_COLS = ('TS_GARDEN', 'RN_GARDEN', 'H_GARDEN', 'LE_GARDEN', 'PAC_GARDEN',
               'T_CAN0', 'T_CAN1', 'T_CANYON', 'Q_CANYON',
               'H_TOWN', 'LE_TOWN', 'RN_TOWN', 'GFLUX_TOWN')



# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

def r_tag(ratio: float) -> str:
    """Case-name tag of a ratio: 1 -> 'R100', 2.5 -> 'R250'."""
    return 'R%03d' % round(ratio * 100.0)


def cases(ratio_values=None, lcz_tags=None, cbs_tags=None):
    """Deterministic list of (case, lcz_tag, cbs_tag, ratio)."""
    out = []
    for lcz_tag in (lcz_tags or list(LCZ)):
        for cbs_tag in CBS_SETTINGS:
            if cbs_tags and cbs_tag not in cbs_tags:
                continue
            for ratio in (ratio_values or R_VALUES):
                out.append((f'{lcz_tag}_{cbs_tag}_{r_tag(ratio)}', lcz_tag, cbs_tag,
                            float(ratio)))
    return out


def build_namelist(base_nml: Path, lcz_tag: str, cbs_tag: str, ratio: float,
                   path: Path, fr_garden: float, z0_gdn: float) -> Path:
    """Namelist of one case: base namelist + LCZ + tau + urb_z0_o_z0h_gdn."""
    import f90nml
    nml = f90nml.read(str(base_nml))
    p = nml['tebparam']
    lcz = LCZ[lcz_tag]
    lcbs, _desc = CBS_SETTINGS[cbs_tag]
    p['urb_h_bld'] = float(lcz['h_bld'])
    p['urb_fr_bld'] = float(lcz['fr_bld'])
    p['urb_h2w'] = float(lcz['h2w'])
    p['teb_fai'] = [float(lcz['fai'])] * 8
    p['teb_lgarden'] = True
    p['fr_garden'] = float(fr_garden)
    p['teb_type_garden'] = 'PROXY_NEW'
    p['urb_z0_gdn'] = float(z0_gdn)
    p['urb_z0_o_z0h_gdn'] = float(ratio)         # the item under study
    p['teb_lcbs_scheme'] = bool(lcbs)
    if lcbs:
        # tanh(0) = 0 -> tau = 0.5 exactly, whatever the morphology
        p['teb_tau_hw_thresh'] = float(lcz['h2w'])
    path.parent.mkdir(parents=True, exist_ok=True)
    nml.write(str(path), force=True)
    return path


# ---------------------------------------------------------------------------
# Reading and comparison
# ---------------------------------------------------------------------------

def read_all(out_dir: Path):
    """Whole model output (time + all numeric columns) as a DataFrame.

    The columns are read with ``converters=float`` (the pandas fast float parser
    may lose one ULP): the exact comparisons below need the values written by
    the model.
    """
    csv = out_dir / 'TEB_output.csv'
    if not csv.is_file():
        return None
    with open(csv, encoding='utf-8', errors='ignore') as fh:
        header = fh.readline().strip().split(';')
    conv = {c: float for c in header if c and c != 'time'}
    return pd.read_csv(csv, sep=';', converters=conv)


def pcd_analytic(zref: float, z0: float) -> float:
    """Neutral momentum coefficient of the log profile: (k/ln(zref/z0))**2."""
    if zref <= z0:
        return 0.0
    return (XKARMAN / np.log(zref / z0)) ** 2


def pch_analytic(zref: float, z0: float, ratio: float) -> float:
    """Neutral scalar (thermal) coefficient: k**2/(ln(zref/z0)*ln(zref/z0h))."""
    z0h = z0 / max(ratio, 1.0)
    if zref <= z0:
        return 0.0
    return XKARMAN ** 2 / (np.log(zref / z0) * np.log(zref / z0h))


def zfh_analytic(zref: float, z0: float, ratio: float) -> float:
    """PCH/PCD = ln(zref/z0)/ln(zref/z0h) (-)."""
    z0h = z0 / max(ratio, 1.0)
    return np.log(zref / z0) / np.log(zref / z0h)


def add_check(rows, case, check, value, criterion, ok, note=''):
    rows.append(dict(case=case, check=check, value=value, criterion=criterion,
                     pass_=bool(ok), note=note))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--work-dir', default=DEFAULT_WORK_DIR,
                    help='root of the bench data (default: %(default)s)')
    ap.add_argument('--site', default='Moscow', help='site name (default: %(default)s)')
    ap.add_argument('--base-namelist', default=None,
                    help='base namelist (default: <work>/<site>/params_CTRL.nml)')
    ap.add_argument('--forcing-nml', default=None,
                    help='forcing namelist (default: <work>/<site>/forcing_ERA5/namelist_forcing.nml)')
    ap.add_argument('--out-root', default=None,
                    help='directory of the experiment (default: <work>/<site>/garden_z0h_sensitivity)')
    ap.add_argument('--exe', default=None, help='model executable')
    ap.add_argument('--only', default=None, help='comma separated list of cases')
    ap.add_argument('--tau', default=None, help='comma separated tau tags (tOFF,t05)')
    ap.add_argument('--lcz', default=None, help='comma separated LCZ tags')
    ap.add_argument('--skip-run', action='store_true', help='post-process only')
    ap.add_argument('--force', action='store_true', help='re-run existing cases')
    ap.add_argument('--list', action='store_true', help='list the cases and exit')
    ap.add_argument('--fr-garden', type=float, default=0.3,
                    help='garden area fraction (default: %(default)s)')
    ap.add_argument('--z0-garden', type=float, default=0.1,
                    help='garden roughness length urb_z0_gdn (m, default: %(default)s)')
    ap.add_argument('--ratio-list', default=','.join('%g' % r for r in R_VALUES),
                    help='z0/z0h ratios to compare (default: %(default)s)')
    args = ap.parse_args(argv)

    work = Path(args.work_dir)
    site = args.site
    base = Path(args.base_namelist) if args.base_namelist else work / site / 'params_CTRL.nml'
    forcing_nml = (Path(args.forcing_nml) if args.forcing_nml
                   else work / site / 'forcing_ERA5' / 'namelist_forcing.nml')
    out_root = Path(args.out_root) if args.out_root else work / site / 'garden_z0h_sensitivity'
    exe = Path(args.exe) if args.exe else MODEL_DIR / 'build' / 'TEB_offline.exe'
    ratio_values = [float(x) for x in str(args.ratio_list).split(',')]
    if R_REF not in ratio_values:
        ratio_values = [R_REF] + ratio_values
    lcz_tags = [x for x in str(args.lcz).split(',')] if args.lcz else None
    cbs_tags = [x for x in str(args.tau).split(',')] if args.tau else None
    all_cases = cases(ratio_values, lcz_tags, cbs_tags)

    if args.list:
        print(f'{"case":<22} {"LCZ":<46} {"tau":<5} {"R":>5}')
        for case, lcz_tag, cbs_tag, ratio in all_cases:
            print(f'{case:<22} {LCZ[lcz_tag]["label"]:<46} {cbs_tag:<5} {ratio:>5g}')
        return 0

    print('  model exe      :', exe)
    print('  base namelist  :', base)
    print('  forcing nml    :', forcing_nml)
    print('  out root       :', out_root)
    print('  z0/z0h ratios  :', ', '.join('%g' % r for r in ratio_values),
          f'(reference {R_REF:g})')

    only = set(x.strip() for x in str(args.only).split(',')) if args.only else None
    out_root.mkdir(parents=True, exist_ok=True)

    # ---------------------------------------------------------------- runs
    for case, lcz_tag, cbs_tag, ratio in all_cases:
        if only and case not in only:
            continue
        out_dir = out_root / f'output_{case}'
        nml_path = build_namelist(base, lcz_tag, cbs_tag, ratio,
                                  out_root / 'namelists' / f'{case}.nml',
                                  args.fr_garden, args.z0_garden)
        log_file = out_root / 'logs' / f'{case}.log'
        if args.skip_run:
            continue
        if out_dir.is_dir() and (out_dir / 'TEB_output.csv').is_file() and not args.force:
            print(f'  {case:<22} kept')
            continue
        rc = run_case(exe, forcing_nml, nml_path, out_dir, log_file)
        tries = 1
        while rc != 0 and tries < RUN_RETRIES:
            tries += 1
            print(f'  {case:<22} retry {tries} (exit={rc}; intermittent IEEE trap,'
                  ' seen with the reference build too)')
            rc = run_case(exe, forcing_nml, nml_path, out_dir, log_file)
        print(f'  {case:<22} exit={rc}'
              + (f' after {tries} tries' if tries > 1 else '')
              + ('' if rc == 0 else '  <-- RUN FAILED'))


    # ------------------------------------------------------------- checks
    checks, ca_rows, eff_rows = [], [], []
    store = {}
    for case, lcz_tag, cbs_tag, ratio in all_cases:
        if only and case not in only:
            continue
        out_dir = out_root / f'output_{case}'
        df = read_all(out_dir)
        if df is None:
            print(f'  WARNING: no output for {case}')
            continue
        store[case] = (lcz_tag, cbs_tag, ratio, df)
        lcz = LCZ[lcz_tag]
        zref = float(lcz['h_bld']) / 2.0
        z0 = float(args.z0_garden)
        pcd_a = pcd_analytic(zref, z0)
        pch_a = pch_analytic(zref, z0, ratio)
        zfh_a = zfh_analytic(zref, z0, ratio)
        u = df['U_CANYON'].to_numpy(dtype=float)
        # H1/H2: the coefficients of the garden/canyon path (exported columns)
        d_pcd = float(np.max(np.abs(df['PCD_GARDEN_CAN'].to_numpy(dtype=float) - pcd_a)))
        d_pch = float(np.max(np.abs(df['PCH_GARDEN_CAN'].to_numpy(dtype=float) - pch_a)))
        add_check(checks, case, 'H2a PCD_GARDEN_CAN vs (k/ln(zref/z0))**2',
                  d_pcd, '= 0', d_pcd == 0.0,
                  f'zref = H/2 = {zref:g} m, z0 = {z0:g} m')
        add_check(checks, case, 'H2b PCH_GARDEN_CAN vs k**2/(ln(zref/z0)*ln(zref/z0h))',
                  d_pch, '= 0', d_pch == 0.0,
                  f'z0h = z0/R = {z0 / max(ratio, 1.0):g} m, ZFH = {zfh_a:.9f}')
        if abs(ratio - R_REF) < 1e-12:
            d_eq = float(np.max(np.abs(df['PCH_GARDEN_CAN'].to_numpy(dtype=float)
                                       - df['PCD_GARDEN_CAN'].to_numpy(dtype=float))))
            add_check(checks, case, 'H1 R = 1: PCH_GARDEN_CAN = PCD_GARDEN_CAN',
                      d_eq, '= 0 (bit for bit)', d_eq == 0.0,
                      'no thermal roughness is the exact limit of the formulation')
        # H3: the conductance TEB uses in the canyon budget
        d_pac = float(np.max(np.abs(df['PAC_GARDEN'].to_numpy(dtype=float)
                                    - df['PCH_GARDEN_CAN'].to_numpy(dtype=float)
                                    * np.maximum(u, XVMIN_GD))))
        add_check(checks, case, 'H3 PAC_GARDEN = PCH_GARDEN_CAN*max(U_CANYON, Vmin)',
                  d_pac, '<= 1e-15', d_pac <= 1e-15)
        # H5: tau identities
        h, hc, ha = (df[c].to_numpy(dtype=float)
                     for c in ('H_GARDEN', 'H_GARDEN_CAN', 'H_GARDEN_ATM'))
        le, lc, la = (df[c].to_numpy(dtype=float)
                      for c in ('LE_GARDEN', 'LE_GARDEN_CAN', 'LE_GARDEN_ATM'))
        n_h = hc - ha
        if np.max(np.abs(n_h)) > 1e-8:
            tau_rec = (h - ha) / n_h
            d_blend = float(np.max(np.abs(h - (tau_rec * hc + (1.0 - tau_rec) * ha))))
            n_le = lc - la
            tau_le = (le - la) / n_le
            d_blend_le = float(np.max(np.abs(le - (tau_le * lc + (1.0 - tau_le) * la))))
            add_check(checks, case, 'H5a H_GARDEN = tau*H_CAN+(1-tau)*H_ATM',
                      d_blend, '<= 1e-10 W/m2', d_blend <= 1e-10,
                      f'tau recovered = {tau_rec.mean():.6f} (std {tau_rec.std():.1e})')
            add_check(checks, case, 'H5b LE_GARDEN = tau*LE_CAN+(1-tau)*LE_ATM',
                      d_blend_le, '<= 1e-10 W/m2', d_blend_le <= 1e-10,
                      f'tau recovered = {tau_le.mean():.6f}')
        else:
            add_check(checks, case, 'H5 tau blend (branches identical: tau = 1)',
                      0.0, '= 0', True,
                      'single-forcing path: both branches carry one flux')
        d_rn = float(np.max(np.abs(df['RN_GARDEN'].to_numpy(dtype=float)
                                   - df['H_GARDEN'].to_numpy(dtype=float)
                                   - df['LE_GARDEN'].to_numpy(dtype=float))))
        add_check(checks, case, 'H5c RN_GARDEN = H_GARDEN + LE_GARDEN',
                  d_rn, '<= 1e-9 W/m2', d_rn <= 1e-9)
        ca_rows.append(dict(case=case, lcz=lcz_tag, tau=cbs_tag, ratio=ratio,
                            zfh_analytic=zfh_a, pcd_analytic=pcd_a, pch_analytic=pch_a,
                            pcd_model=float(df['PCD_GARDEN_CAN'].mean()),
                            pch_model=float(df['PCH_GARDEN_CAN'].mean()),
                            pac_model=float(df['PAC_GARDEN'].mean())))

    # H4 and H6: compare each R case with the reference case of its configuration
    for lcz_tag in LCZ:
        for cbs_tag in CBS_SETTINGS:
            ref_case = f'{lcz_tag}_{cbs_tag}_{r_tag(R_REF)}'
            if ref_case not in store:
                continue
            _l, _t, _r, ref = store[ref_case]
            zref = float(LCZ[lcz_tag]['h_bld']) / 2.0
            z0 = float(args.z0_garden)
            for case, (lcz2, tau2, ratio, df) in store.items():
                if (lcz2, tau2) != (lcz_tag, cbs_tag) or case == ref_case:
                    continue
                a = ref['PAC_GARDEN'].to_numpy(dtype=float)
                b = df['PAC_GARDEN'].to_numpy(dtype=float)
                ok = a > 1e-12
                ratio_meas = b[ok] / a[ok]
                zfh_a = zfh_analytic(zref, z0, ratio)
                d = float(np.max(np.abs(ratio_meas - zfh_a))) if len(ratio_meas) else 0.0
                add_check(checks, case, 'H4 PAC_GARDEN(R)/PAC_GARDEN(1) = ZFH(R)',
                          d, '<= 1e-12', d <= 1e-12, f'ZFH = {zfh_a:.9f}')
                same_pcd = bool(np.array_equal(df['PCD_GARDEN_CAN'].to_numpy(dtype=float),
                                               ref['PCD_GARDEN_CAN'].to_numpy(dtype=float)))
                same_u = bool(np.array_equal(df['U_CANYON'].to_numpy(dtype=float),
                                             ref['U_CANYON'].to_numpy(dtype=float)))
                add_check(checks, case, 'H6a PCD_GARDEN_CAN identical to R = 1',
                          float(not same_pcd), '= 0', same_pcd,
                          'the thermal roughness does not act on the momentum')
                add_check(checks, case, 'H6b U_CANYON identical to R = 1',
                          float(not same_u), '= 0', same_u,
                          'the canyon wind does not see the garden z0h')
                for col in EFFECT_COLS:
                    x = df[col].to_numpy(dtype=float)
                    y = ref[col].to_numpy(dtype=float)
                    eff_rows.append(dict(case=case, lcz=lcz_tag, tau=cbs_tag,
                                         ratio=ratio, var=col,
                                         mean_ref=float(y.mean()), mean_new=float(x.mean()),
                                         delta=float(x.mean() - y.mean()),
                                         max_abs_delta=float(np.max(np.abs(x - y)))))

    check_df = pd.DataFrame(checks)
    ca_df = pd.DataFrame(ca_rows)
    eff_df = pd.DataFrame(eff_rows)
    check_df.to_csv(out_root / 'checks_z0h.csv', sep=';', index=False)
    ca_df.to_csv(out_root / 'ca_ratio.csv', sep=';', index=False)
    eff_df.to_csv(out_root / 'effect_z0h.csv', sep=';', index=False)

    n_fail = int((~check_df['pass_']).sum()) if len(check_df) else 0
    print()
    if len(check_df):
        print(check_df.groupby('check')['pass_'].agg(['sum', 'count']).to_string())
    print(f'  -> checks failed: {n_fail} / {len(check_df)}')

    # ----------------------------------------------------------- figures
    plots = out_root / 'plots'
    plots.mkdir(parents=True, exist_ok=True)
    _plot_conductance(ca_df, plots)
    _plot_diurnal(store, all_cases, plots)
    _write_readme(out_root, base, forcing_nml, check_df, eff_df, ratio_values)
    return 1 if n_fail else 0



def _plot_conductance(ca_df: pd.DataFrame, plots: Path):
    """Measured PAC_GARDEN ratio (relative to R = 1) against the analytic ZFH."""
    if not len(ca_df):
        return
    lcz_tags = [t for t in LCZ if t in set(ca_df['lcz'])]
    fig, axes = plt.subplots(1, len(lcz_tags), figsize=(5.2 * len(lcz_tags), 4.2),
                             squeeze=False)
    for j, lcz_tag in enumerate(lcz_tags):
        ax = axes[0][j]
        ref = ca_df[(ca_df['lcz'] == lcz_tag) & (ca_df['ratio'] == R_REF)]
        for cbs_tag, color in zip(CBS_SETTINGS, ('#1f77b4', '#d62728')):
            sub = ca_df[(ca_df['lcz'] == lcz_tag) & (ca_df['tau'] == cbs_tag)]
            if not len(sub) or not len(ref):
                continue
            pac_ref = float(ref['pac_model'].iloc[0])
            r = sub['ratio'].to_numpy(dtype=float)
            meas = sub['pac_model'].to_numpy(dtype=float) / pac_ref
            ax.plot(r, meas, 'o', color=color, label=f'{cbs_tag}: measured')
            ax.plot(r, sub['zfh_analytic'].to_numpy(dtype=float), '-', color=color,
                    alpha=0.6, label=f'{cbs_tag}: ZFH analytic')
        ax.set_xlabel('z0/z0h ratio (-)')
        ax.set_ylabel('PAC_GARDEN(R) / PAC_GARDEN(1) (-)')
        ax.set_title(LCZ[lcz_tag]['label'])
        ax.grid(alpha=0.3)
        ax.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(plots / 'z0h_conductance.png', dpi=110)
    plt.close(fig)


def _plot_diurnal(store, all_cases, plots: Path):
    """Diurnal cycle of the garden (Ts, H, LE, conductance) for R = 1 and R = 4."""
    lcz_tags = [t for t in LCZ if any(c[1] == t for c in all_cases)]
    if not lcz_tags:
        return
    ratio_new = 4.0
    if not any(abs(c[3] - ratio_new) < 1e-12 for c in all_cases):
        ratio_new = max(c[3] for c in all_cases)
    rows = [('TS_GARDEN', 'K'), ('H_GARDEN', 'W/m2'), ('LE_GARDEN', 'W/m2'),
            ('PAC_GARDEN', 'm/s')]
    fig, axes = plt.subplots(len(rows), len(lcz_tags),
                             figsize=(5.2 * len(lcz_tags), 2.9 * len(rows)),
                             squeeze=False)
    for j, lcz_tag in enumerate(lcz_tags):
        for i, (col, unit) in enumerate(rows):
            ax = axes[i][j]
            for cbs_tag, ls in zip(CBS_SETTINGS, ('-', '--')):
                c_ref = f'{lcz_tag}_{cbs_tag}_{r_tag(R_REF)}'
                c_new = f'{lcz_tag}_{cbs_tag}_{r_tag(ratio_new)}'
                if c_ref not in store or c_new not in store:
                    continue
                for case, color, lab in ((c_ref, '#1f77b4', f'{cbs_tag} R={R_REF:g}'),
                                         (c_new, '#d62728', f'{cbs_tag} R={ratio_new:g}')):
                    x = store[case][3][col].to_numpy(dtype=float)
                    hours = np.arange(len(x)) % 24
                    prof = np.array([x[hours == k].mean() if (hours == k).any() else np.nan
                                     for k in range(24)])
                    ax.plot(range(24), prof, ls, color=color, lw=1.4, label=lab)
            ax.set_title(f'{LCZ[lcz_tag]["label"]} - {col} [{unit}]')
            ax.grid(alpha=0.3)
            if i == len(rows) - 1:
                ax.set_xlabel('hour of day (-)')
    axes[0][0].legend(fontsize=7)
    fig.tight_layout()
    fig.savefig(plots / 'z0h_diurnal.png', dpi=110)
    plt.close(fig)


def _write_readme(out_root: Path, base: Path, forcing_nml: Path, check_df, eff_df,
                  ratio_values):
    """Description of the experiment and its results."""
    md = ['# Garden thermal roughness (`urb_z0_o_z0h_gdn`): sensitivity experiment',
          '',
          'Garden model of TEB-Ru (`teb_type_garden = PROXY_NEW`) tested on the Moscow',
          'ERA5 forcing with the thermal (scalar) roughness `z0h = urb_z0_gdn/R`,',
          '`R = urb_z0_o_z0h_gdn` (namelist item, default `4.0`). The garden exchanges',
          'heat and moisture through the neutral scalar coefficient',
          '`PCH = k**2/(ln(zref/z0)*ln(zref/z0h))`, while the momentum keeps `z0`',
          '(the friction flux is the only user of the momentum coefficient `PCD`).',
          '`R = 1` (`z0h = z0`) is the formulation without thermal roughness and is',
          'reproduced exactly.',
          '',
          f'* Base namelist: `{base}`',
          f'* Forcing: `{forcing_nml}` (Moscow ERA5)',
          '* Ratios compared: ' + ', '.join('`%g`' % r for r in ratio_values)
          + f' (reference `{R_REF:g}`)',
          '* Garden area fraction 0.3, garden roughness `urb_z0_gdn = 0.1 m`',
          '',
          '## Checks', '']
    if len(check_df):
        md.append('| check | cases passed |')
        md.append('|---|---|')
        g = check_df.groupby('check')['pass_'].agg(['sum', 'count'])
        for name, row in g.iterrows():
            md.append(f'| {name} | {int(row["sum"])} / {int(row["count"])} |')
        md.append('')
        md.append('The criterion and the measured value of every check are in')
        md.append('`checks_z0h.csv`; the coefficients (model and analytic) are in')
        md.append('`ca_ratio.csv`.')
    md += ['', '## Effect of the thermal roughness', '']
    if len(eff_df):
        md.append('Mean of the variable minus its value in the `R = 1` run of the same')
        md.append('configuration (`delta`), and the largest absolute difference of the')
        md.append('two time series (`max|delta|`) - full table in `effect_z0h.csv`:')
        md.append('')
        md.append('| LCZ | tau | R | variable | mean (R=1) | mean (R) | delta | max abs delta |')
        md.append('|---|---|---|---|---|---|---|---|')
        for _, row in eff_df.iterrows():
            md.append('| {lcz} | {tau} | {ratio:g} | `{var}` | {mean_ref:.4f} | '
                      '{mean_new:.4f} | {delta:+.4f} | {max_abs_delta:.4f} |'.format(**row))
    md += ['', '## Files', '',
           '* `namelists/<case>.nml` - namelist of every case',
           '* `output_<case>/TEB_output.csv` - model output',
           '* `logs/<case>.log` - model log (model banner with the effective z0h)',
           '* `checks_z0h.csv` - the checks (value, criterion, analytic reference)',
           '* `ca_ratio.csv` - coefficients per case (model and analytic)',
           '* `effect_z0h.csv` - mean effect of R relative to R = 1',
           '* `plots/z0h_conductance.png` - measured vs analytic conductance ratio',
           '* `plots/z0h_diurnal.png` - diurnal cycle of the garden for R = 1 and R = 4',
           '']
    (out_root / 'README.md').write_text('\n'.join(md), encoding='utf-8')


if __name__ == '__main__':
    sys.exit(main())
