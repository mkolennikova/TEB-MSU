#!/usr/bin/env python
"""
Sensitivity of the TEB-Ru garden and greenroof to their radiative surface
properties taken from the namelist:

    urb_alb_gdn / urb_emis_gdn   garden albedo / emissivity
    urb_alb_grf / urb_emis_grf   greenroof albedo / emissivity

Both surfaces receive these values from the driver in EVERY mode (internal
proxy schemes and external models), and the very same values feed the radiation
budget of the canyon (URBAN_SOLAR_ABS with PALB_G and URBAN_LW_COEF with
PEMIS_G), so the TEB budget and the internal proxies are consistent by
construction.

Checks (one row per LCZ / mode / parameter)
-------------------------------------------
  S1  no-op: when the surface is switched OFF (garden or greenroof), changing
      its albedo / emissivity must not change ANY column (bit-for-bit),
  S2  closure: with the garden ON the surface energy balance must stay closed,
      i.e. the residual |RN - H - LE| must not grow,
  S3  effect: list of the columns that change, with their mean and maximum
      differences - this is also the answer to "how much do these parameters
      matter",
  S4  coherence: the recovery of the received fluxes from the two runs,
        albedo     -> SW_implied = -dRN_GARDEN / d(alb)  (received short wave)
        emissivity -> LW_implied = sigma*Ts**4 + dRN_GARDEN / d(emis)
      SW_implied must vanish when the incoming short wave vanishes (the albedo
      acts on the short wave only) and follow its diurnal cycle; LW_implied must
      stay close to the atmospheric long wave of the forcing.

Outputs
-------
  <out-root>/namelists/<case>.nml            namelist of each case
  <out-root>/logs/<case>.log                 model log
  <out-root>/output_<case>/TEB_output.csv    model output
  <out-root>/effects_surface_par.csv         one row per LCZ/mode/parameter
  <out-root>/columns_surface_par.csv         changed columns (mean/max effect)
  <out-root>/plots/garden_par_diurnal.png    garden diurnal cycle vs albedo
  <out-root>/plots/par_effect_fluxes.png     effect on the fluxes (garden, roof)
  <out-root>/plots/par_effect_town.png       effect on the town/canyon state
  <out-root>/README.md                       description and results

Usage
-----
    python python_tests/garden_surface_par_sensitivity.py
    python python_tests/garden_surface_par_sensitivity.py --alb-list 0.15,0.30,0.45
    python python_tests/garden_surface_par_sensitivity.py --emis-list 0.98,0.90,0.80
    python python_tests/garden_surface_par_sensitivity.py --list
    python python_tests/garden_surface_par_sensitivity.py --skip-run   # post-process
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
    LCZ, DEFAULT_WORK_DIR, run_case,
)
from garden_z0_sensitivity import (                                   # noqa: E402
    read_all, mask_undefined, diff_columns,
)

#: Stefan-Boltzmann constant as used by TEB (MODD_CST:XSTEFAN)
STEFAN = 5.670374419e-8

#: values of the two albedo parameters compared (first = reference)
ALB_VALUES = (0.15, 0.30)
#: values of the two emissivity parameters compared (first = reference).
#: 0.90 is the value the driver used before the unification (and the value the
#: external models received), so the 0.98 -> 0.90 pair also quantifies the
#: change brought by the unified default.
EMIS_VALUES = (0.98, 0.90)


#: garden / greenroof modes: tag -> (lgarden, gtype, fr_garden,
#:                                    lgreenroof, fr_greenroof)
MODES = {
    'gOFF': (False, 'PROXY_NEW', 0.0, False, 0.0),
    'gNEW': (True,  'PROXY_NEW', 0.3, False, 0.0),
    'grOFF': (True, 'PROXY_NEW', 0.3, True,  0.0),
    'grON': (True,  'PROXY_NEW', 0.3, True,  0.5),
}

#: parameters under study: tag -> (namelist key, surface)
PARAMS = {
    'alb_gdn': ('urb_alb_gdn', 'garden'),
    'emis_gdn': ('urb_emis_gdn', 'garden'),
    'alb_grf': ('urb_alb_grf', 'greenroof'),
    'emis_grf': ('urb_emis_grf', 'greenroof'),
}

#: surface whose parameters are sampled in each mode. The OFF modes sample the
#: parameters of the surface that is switched off: that is the S1 no-op check
#: (with the surface OFF the parameter must be completely inert).
TARGETED = {'gOFF': 'garden', 'gNEW': 'garden',
            'grOFF': 'greenroof', 'grON': 'greenroof'}

#: columns whose sensitivity is reported explicitly
REPORT_COLS = ('TS_GARDEN', 'RN_GARDEN', 'H_GARDEN', 'LE_GARDEN',
               'T_ROOF1', 'T_CANYON', 'Q_CANYON', 'H_TOWN', 'LE_TOWN',
               'RN_TOWN')

#: short-wave and long-wave parameters (for the S4 coherence check)
SW_PARAMS = ('alb_gdn', 'alb_grf')
LW_PARAMS = ('emis_gdn', 'emis_grf')


def tag(value: float) -> str:
    """Case-name tag of a value: 0.15 -> '015', 0.98 -> '098'."""
    return '%03d' % round(value * 100.0)


def param_values(param: str, alb_values, emis_values):
    """Reference + perturbed values of one parameter."""
    if param in SW_PARAMS:
        return list(alb_values)
    return list(emis_values)


def cases(alb_values, emis_values, lcz_tags=None):
    """Deterministic list of (case, lcz_tag, mode_tag, param, value).

    The reference run of a (LCZ, mode) pair is shared by both parameters of the
    mode, so it is generated once and only the perturbed values add cases.
    """
    out = []
    for lcz_tag in (lcz_tags or list(LCZ)):
        for mode_tag, _mode in MODES.items():
            out.append((f'{lcz_tag}_{mode_tag}_ref', lcz_tag, mode_tag, None, None))
            for param, (_key, surface) in PARAMS.items():
                if surface != TARGETED[mode_tag]:
                    continue
                for v in param_values(param, alb_values, emis_values)[1:]:
                    out.append((f'{lcz_tag}_{mode_tag}_{param}{tag(v)}', lcz_tag,
                                mode_tag, param, float(v)))
    return out


def build_namelist(base_nml: Path, lcz_tag: str, mode_tag: str, param, value,
                   path: Path, alb_values, emis_values) -> Path:
    """Namelist of one case: base namelist + LCZ + modes + one parameter.

    The road cbs scheme is switched OFF: the experiment isolates the two
    vegetation surfaces. The four parameters under study are always written
    explicitly, so that the reference run of each mode is well defined.
    """
    import f90nml
    nml = f90nml.read(str(base_nml))
    p = nml['tebparam']
    lcz = LCZ[lcz_tag]
    lgarden, gtype, fr_gd, lgreenroof, fr_gr = MODES[mode_tag]
    p['urb_h_bld'] = float(lcz['h_bld'])
    p['urb_fr_bld'] = float(lcz['fr_bld'])
    p['urb_h2w'] = float(lcz['h2w'])
    p['teb_fai'] = [float(lcz['fai'])] * 8
    p['teb_lgarden'] = bool(lgarden)
    p['fr_garden'] = float(fr_gd) if lgarden else 0.0
    p['teb_type_garden'] = gtype
    p['teb_lgreenroof'] = bool(lgreenroof)
    p['teb_frac_gr'] = float(fr_gr)
    p['teb_lcbs_scheme'] = False
    p['urb_z0_gdn'] = 0.1                      # roughness: not studied here
    p['urb_z0_grf'] = 0.01
    p['urb_alb_gdn'] = float(alb_values[0])
    p['urb_alb_grf'] = float(alb_values[0])
    p['urb_emis_gdn'] = float(emis_values[0])
    p['urb_emis_grf'] = float(emis_values[0])
    if param is not None:
        p[PARAMS[param][0]] = float(value)     # the item under study
    path.parent.mkdir(parents=True, exist_ok=True)
    nml.write(str(path), force=True)
    return path


def diurnal(v, time):
    """Mean diurnal cycle of a series (one value per hour)."""
    s = pd.Series(np.asarray(v, dtype=float), index=pd.to_datetime(time))
    return s.groupby(s.index.hour).mean()


def closure(df):
    """Residual RN - H - LE of the garden surface balance (W/m2)."""
    if df is None or 'RN_GARDEN' not in df.columns:
        return None
    rn = mask_undefined(df['RN_GARDEN'].to_numpy(dtype=float))
    h = mask_undefined(df['H_GARDEN'].to_numpy(dtype=float))
    le = mask_undefined(df['LE_GARDEN'].to_numpy(dtype=float))
    ok = np.isfinite(rn) & np.isfinite(h) & np.isfinite(le)
    res = np.full(rn.shape, np.nan)
    res[ok] = rn[ok] - h[ok] - le[ok]
    return res


def received_flux(df_ref, df_new, param, value, ref_value):
    """Received flux implied by the garden net radiation (S4).

    albedo     : SW_implied = -dRN_GARDEN / d(alb)
    emissivity : LW_implied = sigma*Ts**4 + dRN_GARDEN / d(emis)
    """
    if df_ref is None or df_new is None or param not in PARAMS:
        return None
    if not param.startswith('alb_gdn') and not param.startswith('emis_gdn'):
        return None
    dpar = float(value) - float(ref_value)
    if dpar == 0.0:
        return None
    rn0 = mask_undefined(df_ref['RN_GARDEN'].to_numpy(dtype=float))
    rn1 = mask_undefined(df_new['RN_GARDEN'].to_numpy(dtype=float))
    ok = np.isfinite(rn0) & np.isfinite(rn1)
    out = np.full(rn0.shape, np.nan)
    if param.startswith('alb'):
        out[ok] = -(rn1[ok] - rn0[ok]) / dpar
    else:
        ts = mask_undefined(df_ref['TS_GARDEN'].to_numpy(dtype=float))
        ok = ok & np.isfinite(ts)
        out[ok] = STEFAN * ts[ok] ** 4 + (rn1[ok] - rn0[ok]) / dpar
    return out



def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--work-dir', default=DEFAULT_WORK_DIR,
                    help='root of the run_on_windows.ipynb working directory')
    ap.add_argument('--site', default='Moscow', help='site name (default: %(default)s)')
    ap.add_argument('--base-namelist', default=None,
                    help='base parameter namelist (default: <site>/params_CTRL.nml)')
    ap.add_argument('--forcing-nml', default=None,
                    help='forcing namelist (default: <site>/forcing_ERA5/namelist_forcing.nml)')
    ap.add_argument('--out-root', default=None,
                    help='output root (default: <site>/garden_surface_par_sensitivity)')
    ap.add_argument('--exe', default=None, help='model executable')
    ap.add_argument('--only', default=None, help='comma separated list of cases')
    ap.add_argument('--skip-run', action='store_true', help='post-process only')
    ap.add_argument('--force', action='store_true', help='re-run existing cases')
    ap.add_argument('--list', action='store_true', help='list the cases and exit')
    ap.add_argument('--alb-list', default=','.join('%g' % v for v in ALB_VALUES),
                    help='garden/greenroof albedo values, first = reference'
                         ' (default: %(default)s)')
    ap.add_argument('--emis-list', default=','.join('%g' % v for v in EMIS_VALUES),
                    help='garden/greenroof emissivity values, first = reference'
                         ' (default: %(default)s)')
    args = ap.parse_args(argv)

    alb_values = [float(x) for x in str(args.alb_list).split(',')]
    emis_values = [float(x) for x in str(args.emis_list).split(',')]
    if len(alb_values) < 2 or len(emis_values) < 2:
        print('ERROR: --alb-list and --emis-list need a reference and at least'
              ' one perturbed value')
        return 2

    work = Path(args.work_dir)
    site_dir = work / args.site
    base = (Path(args.base_namelist) if args.base_namelist
            else site_dir / 'params_CTRL.nml')
    if not base.is_file():
        base = MODEL_DIR / 'namelist' / 'namelist.nml'
    forcing_nml = (Path(args.forcing_nml) if args.forcing_nml
                   else site_dir / 'forcing_ERA5' / 'namelist_forcing.nml')
    out_root = (Path(args.out_root) if args.out_root
                else site_dir / 'garden_surface_par_sensitivity')
    exe = Path(args.exe) if args.exe else MODEL_DIR / 'build' / 'TEB_offline.exe'

    all_cases = cases(alb_values, emis_values)
    if args.only:
        selected = {c.strip() for c in args.only.split(',')}
        all_cases = [c for c in all_cases if c[0] in selected]

    if args.list:
        print(f'{"case":<26} {"LCZ":<44} {"param":<10} value')
        for case, lcz_tag, _mode, param, value in all_cases:
            print(f'{case:<26} {LCZ[lcz_tag]["label"]:<44} '
                  f'{param or "-":<10} {"" if value is None else "%g" % value}')
        return 0

    out_root.mkdir(parents=True, exist_ok=True)
    (out_root / 'namelists').mkdir(exist_ok=True)
    (out_root / 'logs').mkdir(exist_ok=True)

    print('=' * 78)
    print('  base namelist :', base)
    print('  forcing       :', forcing_nml)
    print('  output root   :', out_root)
    print('  albedo        :', ', '.join('%g' % v for v in alb_values))
    print('  emissivity    :', ', '.join('%g' % v for v in emis_values))
    print('  cases         :', len(all_cases))
    print('=' * 78)

    for case, lcz_tag, mode_tag, param, value in all_cases:
        nml_path = out_root / 'namelists' / f'{case}.nml'
        out_dir = out_root / f'output_{case}'
        log_file = out_root / 'logs' / f'{case}.log'
        build_namelist(base, lcz_tag, mode_tag, param, value, nml_path,
                       alb_values, emis_values)
        if args.skip_run:
            continue
        if (out_dir / 'TEB_output.csv').is_file() and not args.force:
            print(f'  [skip] {case}')
            continue
        print(f'  [run ] {case}  ({LCZ[lcz_tag]["label"]}, {mode_tag}, '
              f'{param or "reference"}'
              f'{"" if value is None else " = %g" % value})')
        rc = run_case(exe, forcing_nml, nml_path, out_dir, log_file)
        if rc != 0:
            print(f'    WARNING: {case} returned code {rc}')


    # ------------------------------------------------------------------
    # Post-processing: reference runs, effects, checks
    # ------------------------------------------------------------------
    data = {}
    for case, _lcz, _mode, _param, _value in all_cases:
        df = read_all(out_root / f'output_{case}')
        if df is None:
            print(f'  WARNING: no output for {case}')
            continue
        data[case] = df
    if not data:
        print('ERROR: no output found')
        return 1

    def col(df, name):
        if df is None or name not in df.columns:
            return None
        return mask_undefined(df[name].to_numpy(dtype=float))

    rows, col_rows, rep_rows, curves = [], [], [], []
    for lcz_tag in LCZ:
        for mode_tag, mode in MODES.items():
            ref_case = f'{lcz_tag}_{mode_tag}_ref'
            if ref_case not in data:
                continue
            df_ref = data[ref_case]
            t = pd.to_datetime(df_ref['time']) if 'time' in df_ref.columns else None
            res_ref = closure(df_ref)
            for param, (_key, surface) in PARAMS.items():
                if surface != TARGETED[mode_tag]:
                    continue
                values = param_values(param, alb_values, emis_values)
                ref_value = values[0]
                for value in values[1:]:
                    case = f'{lcz_tag}_{mode_tag}_{param}{tag(value)}'
                    if case not in data:
                        continue
                    df_new = data[case]
                    diffs = diff_columns(df_ref, df_new)
                    max_abs = max([d['max_abs'] for d in diffs], default=0.0)
                    for d in diffs:
                        col_rows.append(dict(case=case, lcz=LCZ[lcz_tag]['label'],
                                             mode=mode_tag, param=param,
                                             value=value, **d))
                    for rc in REPORT_COLS:
                        a, b = col(df_ref, rc), col(df_new, rc)
                        if a is None or b is None:
                            continue
                        ok = np.isfinite(a) & np.isfinite(b)
                        if not ok.any():
                            continue
                        d = b[ok] - a[ok]
                        rep_rows.append(dict(
                            case=case, lcz=LCZ[lcz_tag]['label'], mode=mode_tag,
                            param=param, value=value, column=rc,
                            mean_delta=float(np.mean(d)),
                            max_abs=float(np.max(np.abs(d)))))
                    # S1: a surface that is off must not react at all
                    surface_off = (
                        (mode_tag == 'gOFF' and surface == 'garden') or
                        (mode_tag == 'grOFF' and surface == 'greenroof'))
                    if surface_off:
                        check = 'S1 ok (no-op)' if not diffs else \
                                'S1 FAIL (%d columns)' % len(diffs)
                    else:
                        check = 'S3 effect (%d columns)' % len(diffs)
                    # S2: closure of the garden surface balance
                    res_new = closure(df_new)
                    clo_ref = np.nan if res_ref is None else \
                        float(np.nanmax(np.abs(res_ref)))
                    clo_new = np.nan if res_new is None else \
                        float(np.nanmax(np.abs(res_new)))

                    # S4: received flux recovered from the pair of runs
                    sw_day = sw_ratio = sw_night = lw_day = lw_ratio = np.nan
                    drn_day = np.nan
                    if not surface_off and t is not None:
                        sw_in = col(df_ref, 'Forc_DIR_SW')
                        sw_sca = col(df_ref, 'Forc_SCA_SW')
                        lw_forc = col(df_ref, 'Forc_LW')
                        sw_tot = None if sw_in is None else \
                            sw_in + (sw_sca if sw_sca is not None else 0.0)
                        flux = received_flux(df_ref, df_new, param, value, ref_value)
                        if flux is not None and sw_tot is not None:
                            day, night = sw_tot > 1.0, sw_tot <= 1.0
                            fin = np.isfinite(flux)
                            if param in SW_PARAMS:
                                if np.count_nonzero(day & fin):
                                    sw_day = float(np.nanmean(flux[day & fin]))
                                    den = float(np.nanmean(sw_tot[day & fin]))
                                    sw_ratio = sw_day / den if den else np.nan
                                if np.count_nonzero(night & fin):
                                    sw_night = float(
                                        np.nanmax(np.abs(flux[night & fin])))
                            else:
                                if np.count_nonzero(day & fin):
                                    lw_day = float(np.nanmean(flux[day & fin]))
                                    if lw_forc is not None:
                                        den = float(np.nanmean(lw_forc[day & fin]))
                                        lw_ratio = lw_day / den if den else np.nan
                        rn0, rn1 = col(df_ref, 'RN_GARDEN'), col(df_new, 'RN_GARDEN')
                        if rn0 is not None and rn1 is not None and sw_tot is not None:
                            d = rn1 - rn0
                            okd = np.isfinite(d) & (sw_tot > 1.0)
                            if okd.any():
                                drn_day = float(np.nanmean(d[okd]))
                    rows.append(dict(
                        case=case, lcz=LCZ[lcz_tag]['label'], mode=mode_tag,
                        surface=surface, param=param, value=value,
                        ncol_diff=len(diffs), max_abs=max_abs,
                        closure_ref=clo_ref, closure_new=clo_new,
                        drn_garden_day=drn_day, sw_implied_day=sw_day,
                        sw_implied_ratio=sw_ratio, sw_implied_nightmax=sw_night,
                        lw_implied_day=lw_day, lw_forc_ratio=lw_ratio,
                        check=check))
                    if not surface_off and t is not None:
                        curves.append((case, lcz_tag, mode_tag, param, value,
                                       df_new, df_ref, t))

    df_eff = pd.DataFrame(rows)
    df_cols = pd.DataFrame(col_rows)
    df_rep = pd.DataFrame(rep_rows)
    eff_csv = out_root / 'effects_surface_par.csv'
    cols_csv = out_root / 'columns_surface_par.csv'
    rep_csv = out_root / 'report_surface_par.csv'
    df_eff.to_csv(eff_csv, index=False)
    if not df_cols.empty:
        df_cols = df_cols.sort_values(['case', 'max_abs'],
                                      ascending=[True, False])
    df_cols.to_csv(cols_csv, index=False)
    if not df_rep.empty:
        df_rep = df_rep.sort_values(['param', 'column'])
    df_rep.to_csv(rep_csv, index=False)

    # ------------------------------------------------------------------
    # Report on the console
    # ------------------------------------------------------------------
    print()
    print('=== effect of the surface parameters (reference run -> perturbed) ===')
    for _, r in df_eff.iterrows():
        print(f'  {r["case"]:<26} {r["mode"]:<6} {r["param"]:<9} '
              f'{r["value"]:>6g}  columns changed: {r["ncol_diff"]:>2}'
              f'  max|d|: {r["max_abs"]:>10.3e}  {r["check"]}')
    if not df_cols.empty:
        print()
        print('=== columns with the largest effect ===')
        print(df_cols.head(12)[['case', 'column', 'max_abs', 'n_diff']]
              .to_string(index=False))


    # ------------------------------------------------------------------
    # Plots
    # ------------------------------------------------------------------
    plots = out_root / 'plots'
    plots.mkdir(exist_ok=True)
    made = []
    alb_curves = [c for c in curves if c[3] in SW_PARAMS]
    emis_curves = [c for c in curves if c[3] in LW_PARAMS]
    if alb_curves:
        case, lcz_tag, mode_tag, cparam, value, df_new, df_ref, t = alb_curves[0]
        emis = None
        for c in emis_curves:
            if c[1] == lcz_tag and c[2] == mode_tag:
                emis = c
                break
        fig, axes = plt.subplots(2, 2, figsize=(12, 7), sharex=True)
        for ax, name in zip(axes.ravel(), ('RN_GARDEN', 'H_GARDEN',
                                           'LE_GARDEN', 'TS_GARDEN')):
            a = diurnal(col(df_ref, name), t)
            b = diurnal(col(df_new, name), t)
            ax.plot(a.index, a.values, 'o-', color='tab:blue',
                    label='reference (alb = %g, emis = %g)' % (ALB_VALUES[0],
                                                               EMIS_VALUES[0]))
            ax.plot(b.index, b.values, 's--', color='tab:orange',
                    label='%s = %g' % (PARAMS[cparam][0], value))
            if emis is not None:
                e_ref = diurnal(col(emis[6], name), emis[7])
                e_new = diurnal(col(emis[5], name), emis[7])
                ax.plot(e_ref.index, e_ref.values, '-', lw=1.0, color='tab:green',
                        label='emis = %g' % EMIS_VALUES[0])
                ax.plot(e_new.index, e_new.values, '--', lw=1.0, color='tab:red',
                        label='emis = %g' % emis[4])
            ax.set_title(name)
            ax.grid(alpha=0.3)
            ax.legend(fontsize=7)
        fig.suptitle('Garden diurnal cycle vs the namelist surface properties'
                     ' (%s, %s)' % (LCZ[lcz_tag]['label'], mode_tag))
        fig.tight_layout()
        fig.savefig(plots / 'garden_par_diurnal.png', dpi=130)
        plt.close(fig)
        made.append('plots/garden_par_diurnal.png')

    if not df_rep.empty:
        for fname, cols, title in (
                ('par_effect_fluxes.png',
                 ('RN_GARDEN', 'H_GARDEN', 'LE_GARDEN', 'TS_GARDEN', 'T_ROOF1'),
                 'Effect of the surface parameters on the fluxes (mean over the LCZ)'),
                ('par_effect_town.png',
                 ('T_CANYON', 'Q_CANYON', 'H_TOWN', 'LE_TOWN', 'RN_TOWN'),
                 'Effect of the surface parameters on the town (mean over the LCZ)')):
            sub = df_rep[df_rep['column'].isin(cols)]
            if sub.empty:
                continue
            piv = sub.pivot_table(index='column', columns='param',
                                  values='mean_delta', aggfunc='mean')
            piv = piv.reindex([c for c in cols if c in piv.index])
            fig, ax = plt.subplots(figsize=(9, 4.5))
            piv.plot(kind='bar', ax=ax)
            ax.axhline(0., color='k', lw=0.8)
            ax.set_ylabel('mean difference (perturbed - reference)')
            ax.set_title(title)
            ax.grid(axis='y', alpha=0.3)
            fig.tight_layout()
            fig.savefig(plots / fname, dpi=130)
            plt.close(fig)
            made.append('plots/' + fname)


    # ------------------------------------------------------------------
    # README
    # ------------------------------------------------------------------
    md = ['# Sensitivity of the garden and greenroof to their namelist surface properties',
          '',
          'Generated by `python_tests/garden_surface_par_sensitivity.py`.',
          '',
          'The four parameters under study are read by the driver in every garden /',
          'greenroof mode (internal proxy schemes and external models) and feed both',
          'the internal schemes and the radiation budget of the canyon:',
          '',
          '| namelist item | meaning | reference value | perturbed value(s) |',
          '|---|---|---|---|',
          '| `urb_alb_gdn` | garden albedo | %g | %s |' % (alb_values[0], ', '.join('%g' % v for v in alb_values[1:])),
          '| `urb_alb_grf` | greenroof albedo | %g | %s |' % (alb_values[0], ', '.join('%g' % v for v in alb_values[1:])),
          '| `urb_emis_gdn` | garden emissivity | %g | %s |' % (emis_values[0], ', '.join('%g' % v for v in emis_values[1:])),
          '| `urb_emis_grf` | greenroof emissivity | %g | %s |' % (emis_values[0], ', '.join('%g' % v for v in emis_values[1:])),
          '',
          'Configuration: %d cases (LCZ x mode x parameter), the road cbs scheme is' % len(all_cases),
          'switched off so that the experiment isolates the two vegetation surfaces.',
          '',
          '## Checks',
          '',
          '| check | meaning | result |',
          '|---|---|---|',
          '| S1 | the surface is OFF: changing its albedo / emissivity must not change any column | see the `check` column below |',
          '| S2 | the garden surface balance stays closed: `max abs(RN - H - LE)` | `closure_ref` / `closure_new` |',
          '| S3 | the effect itself: number of changed columns and maximum difference | `ncol_diff` / `max_abs` |',
          '| S4 | the received flux recovered from the pair of runs: albedo -> `SW_implied = -dRN/dalb`, emissivity -> `LW_implied = sigma*Ts**4 + dRN/demis` | `sw_implied_*` / `lw_implied_*` |',
          '',
          '## Effect of each parameter',
          '',
          '| case | LCZ | mode | surface | param | value | columns changed | max abs diff | closure ref | closure new | check |',
          '|---|---|---|---|---|---|---|---|---|---|---|']
    for _, r in df_eff.iterrows():
        md.append('| `%s` | %s | %s | %s | `%s` | %g | %d | %.3e | %s | %s | %s |' % (
            r['case'], r['lcz'], r['mode'], r['surface'], r['param'], r['value'],
            r['ncol_diff'], r['max_abs'],
            '-' if not np.isfinite(r['closure_ref']) else '%.2e' % r['closure_ref'],
            '-' if not np.isfinite(r['closure_new']) else '%.2e' % r['closure_new'],
            r['check']))
    md.append('')
    md.append('## Received fluxes recovered from the runs (S4, garden)')
    md.append('')
    md.append('`sw_implied_ratio` = `SW_implied` / incoming short wave (diurnal mean over'
              ' the day steps), `lw_forc_ratio` = `LW_implied` / atmospheric long wave.')
    md.append('')
    md.append('| case | param | value | dRN_GARDEN day (W/m2) | SW_implied day (W/m2) | SW_implied ratio | SW_implied night max | LW_implied day (W/m2) | LW_implied ratio |')
    md.append('|---|---|---|---|---|---|---|---|---|')
    def _fmt(x):
        return '-' if not np.isfinite(x) else ('%.3g' % x)

    for _, r in df_eff.iterrows():
        if r['surface'] != 'garden':
            continue
        md.append('| `%s` | `%s` | %g | %s | %s | %s | %s | %s | %s |' % (
            r['case'], r['param'], r['value'], _fmt(r['drn_garden_day']),
            _fmt(r['sw_implied_day']), _fmt(r['sw_implied_ratio']),
            _fmt(r['sw_implied_nightmax']), _fmt(r['lw_implied_day']),
            _fmt(r['lw_forc_ratio'])))
    md.append('')
    md.append('## Main columns affected (mean and max difference)')
    md.append('')
    md.append('| case | param | value | column | mean diff | max abs diff |')
    md.append('|---|---|---|---|---|---|')
    for _, r in df_rep.iterrows():
        md.append('| `%s` | `%s` | %g | `%s` | %.3e | %.3e |' % (
            r['case'], r['param'], r['value'], r['column'], r['mean_delta'],
            r['max_abs']))
    md.append('')
    md.append('## Files')
    md.append('')
    md.append('- `effects_surface_par.csv` - one row per case (checks S1-S4)')
    md.append('- `columns_surface_par.csv` - every changed column of every case')
    md.append('- `report_surface_par.csv` - main columns of every case')
    for p in made:
        md.append('- `%s`' % p)
    md.append('- `namelists/`, `logs/`, `output_<case>/` - namelists, model logs, outputs')
    md.append('')
    md.append('## Reproduction')
    md.append('')
    md.append('```')
    md.append('python python_tests/garden_surface_par_sensitivity.py')
    md.append('```')
    (out_root / 'README.md').write_text('\n'.join(md) + '\n', encoding='utf-8')

    print()
    print('Output root :', out_root)
    print('  effects   :', eff_csv)
    print('  columns   :', cols_csv)
    print('  report    :', rep_csv)
    for p in made:
        print('  plot      :', plots / Path(p).name)
    print('  report    :', out_root / 'README.md')
    return 0


if __name__ == '__main__':
    sys.exit(main())

