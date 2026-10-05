"""Verification of the anthropogenic heat fluxes of the town energy balance.

The town sensible heat flux H_TOWN of TEB-Ru contains, in addition to the
surface fluxes, the anthropogenic heat flux of the traffic (AHF_TRAFFIC, a daily
cycle applied to the annual mean `ahf_traffic` of the namelist) and the waste
heat of the buildings (H_WASTE: HVAC systems and infiltration/ventilation of
BEM). This script verifies, on simulations with BEM and with traffic, that

* the traffic flux used by the model is exactly the prescribed daily cycle;
* AHF_TRAFFIC and H_WASTE enter H_TOWN exactly once, in both cbs modes
  (`teb_lcbs_scheme = .FALSE.` and `.TRUE.`), i.e. they are neither weighted,
  nor duplicated, nor omitted by the cbs scheme;
* the effect of the cbs scheme on H_TOWN is due to the road term alone.

Method: the ground/building heat flux of the town is reconstructed from the
model output as

Method: the energy balance of the town is closed with model diagnostics only:

    R = RN_TOWN + AHF_TRAFFIC + AHF_INDUSTRY + H_WASTE + LE_WASTE + LE_TRAFFIC
        + LE_INDUSTRY - H_TOWN - LE_TOWN - GFLUX_TOWN   =   0

RN_TOWN, H_TOWN, LE_TOWN and GFLUX_TOWN (the heat flux conducted into the ground
and into the buildings) are independent diagnostics of the town surface budget,
while AHF_TRAFFIC and H_WASTE/LE_WASTE are the anthropogenic fluxes *as computed
by the model*. The residual vanishes only if the anthropogenic fluxes are
contained in H_TOWN and LE_TOWN exactly once and with their full weight: a
missing, duplicated or tau-weighted term would show up as a residual of the size
of the flux itself. (AHF_INDUSTRY, LE_TRAFFIC and LE_INDUSTRY are zero in these
experiments.) The closure is checked in every configuration and in both tau
modes.

Experiments (see `python_tests/compare_cbs_scheme.py`, `--no-garden`, BEM active):

| root | `ahf_traffic` | waste heat (BEM) |
| --- | --- | --- |
| `<site>/compare_cbs_scheme` | 0 | active |
| `<site>/compare_cbs_scheme_ahf20` | 20 W/m2 | active |
| `<site>/compare_cbs_scheme_nowaste` | 0 | switched off (control) |

Every root contains the reference (`teb_lcbs_scheme = .FALSE.`) and the cbs run
of each case, so that every check is done with the cbs scheme off and on.

Usage:

```
python python_tests/check_anthro_heat.py
python python_tests/check_anthro_heat.py --cases LCZ9_w0,SPARSE_w0
```

Files written into `<out-root>` (default `<site>/check_anthro_heat`):

* `summary_anthro_heat.csv` - every check, one row per case and cbs mode
* `plots/anthro_traffic.png` - town balance residual: traffic on/off
* `plots/anthro_waste.png` - town balance residual: waste heat on/off
* `README.md` - method, results and the code path of the fluxes
"""

from __future__ import annotations

import argparse
import math
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

from sensitivity_zd import LCZ, DEFAULT_WORK_DIR, series, stats_of      # noqa: E402

#: model columns used by the checks
COLS = ('RN_TOWN', 'H_TOWN', 'LE_TOWN', 'H_ROAD', 'T_CANYON', 'H_ROAD_CAN',
        'H_ROAD_ATM', 'TI_BLD', 'HVAC_COOL', 'HVAC_HEAT', 'AHF_TRAFFIC',
        'H_WASTE', 'LE_WASTE', 'GFLUX_TOWN')

#: cbs mode -> (suffix of the case name, label)
CBS_MODES = (('', 'cbs off'), ('_cbs', 'cbs on'))

#: relative thresholds of the verdicts: the prescribed traffic flux and the
#: switched anthropogenic fluxes must be accounted for at the round-off level


def ahf_traffic_weight(hour: float) -> float:
    """Daily cycle of the traffic heat flux (port of AHF_TRAFFIC_NOW).

    Same constants as `ahf_traffic_weight` of `src/src_driver/ahf_traffic_now.F90`
    (cb1, cb2, csig, cmu, cA1, cff, calph, ceps).
    """
    cb1, cb2, csig, cmu = 0.451, 0.4, 0.15, 0.5
    cA1, cff, calph, ceps = -0.3, 2.0, 10.0, 0.25
    #: the model wraps the hour into [0, 24] and NOT into [0, 24): the two ends
    #: of the day differ slightly, which matters at midnight
    h = hour
    if h < 0.0:
        h = h + 24.0
    elif h > 24.0:
        h = h - 24.0
    td = h / 24.0
    z_htd = cA1 * math.cos(2.0 * math.pi * cff * td)
    z_ntd = (1.0 / csig / math.sqrt(2.0 * math.pi)
             * math.exp(-(td - cmu) ** 2 / (2.0 * csig ** 2)))
    z_e1 = 0.5 * math.erf(calph * (td - cmu + ceps) / csig) + 1.0
    z_e2 = 0.5 * math.erf(-calph * (td - cmu - ceps) / csig) + 1.0
    return z_ntd * z_e1 * cb1 + z_htd * z_e1 * z_e2 + cb2


def ahf_traffic_now(ahf_traffic: float, hour, minute, second, utc_hour: int,
                    dtshift: float = 2.0):
    """Traffic heat flux of the current time-step (port of H_TRAFFIC_NOW).

    The daily cycle is interpolated linearly between the two surrounding hours,
    with the time zone and shift of the model (`zhour = hour + utc_hour - 2`).
    """
    h1 = np.asarray(hour) + utc_hour - dtshift
    w1 = np.array([ahf_traffic_weight(h) for h in h1])
    w2 = np.array([ahf_traffic_weight(h) for h in h1 + 1.0])
    frac = (np.asarray(minute) * 60.0 + np.asarray(second)) / 3600.0
    return ahf_traffic * (w1 + frac * (w2 - w1))


def read_run(out_dir: Path) -> dict:
    """Model output of one run: the columns of the checks and the time stamps."""
    data = {name: series(out_dir, name) for name in COLS}
    csv = out_dir / 'TEB_output.csv'
    data['time'] = (pd.read_csv(csv, sep=';', usecols=['time'])['time']
                    if csv.is_file() else None)
    return data


def namelist_get(path: Path, key: str, default):
    """One value of a case namelist (ahf_traffic, teb_utc_hour, ...)."""
    try:
        return f90nml.read(str(path))['tebparam'][key]
    except Exception:                                              # noqa: BLE001
        return default


def clock(time) -> tuple:
    """Hours, minutes and seconds of the time stamps (hours are integers)."""
    t = pd.to_datetime(time)
    return t.dt.hour.to_numpy(), t.dt.minute.to_numpy(), t.dt.second.to_numpy()


def vec(x, size: int):
    """A series as a float array of the given length (NaN when unavailable)."""
    if x is None:
        return np.full(size, np.nan)
    return np.array(x, dtype=float)


def balance(data: dict, size: int) -> np.ndarray:
    """Residual of the town energy balance (W/m2), which must vanish.

    RN + AHF + waste - H - LE - G, where the anthropogenic fluxes are the model
    diagnostics of the fluxes that are already contained in H_TOWN and LE_TOWN
    (the waste heat of the buildings, sensible and latent) and G is the
    ground/building heat flux of the town. Every term is an independent
    diagnostic of the model, so the identity holds only if the anthropogenic
    fluxes are accounted for exactly once and with their full weight: a missing
    (or duplicated, or tau-weighted) term would show up as a residual of the size
    of the flux itself. AHF_INDUSTRY, LE_TRAFFIC and LE_INDUSTRY are zero in
    these experiments.
    """
    return (vec(data.get('RN_TOWN'), size) + vec(data.get('AHF_TRAFFIC'), size)
            + vec(data.get('H_WASTE'), size) + vec(data.get('LE_WASTE'), size)
            - vec(data.get('H_TOWN'), size) - vec(data.get('LE_TOWN'), size)
            - vec(data.get('GFLUX_TOWN'), size))


def diurnal_mean(y: np.ndarray, hours: np.ndarray):
    """Mean of a series for every hour of the day (None when unavailable)."""
    if y is None:
        return None
    xh = np.arange(24)
    return np.array([np.nanmean(y[hours == h]) if np.any(np.isfinite(y[hours == h]))
                     else np.nan for h in xh])

#: and must not produce a step larger than 5% of their own size
TOL_PRESCRIBED = 1.0e-6
TOL_JUMP = 0.05
TOL_ZERO = 1.0e-6

#: tolerance of the responses of H_TOWN: the traffic flux is expected to appear
#: in H_TOWN within 15% (part of the heat goes into storage), the waste heat of
#: the buildings within 50% (switching the BEM off also removes the thermal
#: buffer of the buildings), 10% for the invariance checks, which must hold far
#: below the signature of a tau weighting ((1 - tau) times the flux)
TOL_SENS_TRAFFIC = 0.15
TOL_SENS_BEM = 0.50
TOL_KEPT = 0.10



def diff(a, b):
    """a - b on the common length (None when one of the series is missing)."""
    if a is None or b is None:
        return None
    n = min(len(a), len(b))
    return np.array(a[:n], dtype=float) - np.array(b[:n], dtype=float)


def mean_abs(x) -> float:
    """Mean of the absolute value of a series (NaN when unavailable)."""
    if x is None or not np.any(np.isfinite(x)):
        return np.nan
    return float(np.nanmean(np.abs(x)))


def nan_mean(x) -> float:
    """Mean of a series (NaN when unavailable or missing)."""
    if x is None:
        return np.nan
    x = np.asarray(x, dtype=float)
    return float(np.nanmean(x)) if np.any(np.isfinite(x)) else np.nan


def result(case: str, cbs_label: str, check: str, quantity: str, y, reference: float,
           tol: float | None = None, absolute: bool = False,
           compare_mean: bool = False, window: bool = False) -> dict:
    """One checked quantity: statistics, the scale of the flux and the verdict.

    The verdict compares the extreme value of the series with `reference`
    (`compare_mean`: its mean instead, used for the sensitivities of H_TOWN).
    With `window` the ratio must lie in [1 - tol, 1 + tol]: this is the test of a
    sensitivity, which must be equal to the flux of the source within `tol`.
    """
    ok = y is not None and np.any(np.isfinite(y))
    y = np.array([]) if not ok else np.asarray(y)[np.isfinite(y)]
    st = stats_of(y if ok else None)
    abs_max = float(np.nanmax(np.abs(y))) if ok else np.nan
    value = abs(st['mean']) if compare_mean and ok else abs_max
    ratio = value / reference if ok and np.isfinite(reference) and reference > 0 else np.nan
    if tol is None or not ok or not np.isfinite(ratio):
        verdict = '-'
    elif window:
        verdict = 'OK' if abs(ratio - 1.0) <= tol else 'FAIL'
    elif absolute:
        verdict = 'OK' if value <= tol else 'FAIL'
    else:
        verdict = 'OK' if ratio <= tol else 'FAIL'
    return dict(case=case, cbs=cbs_label, check=check, quantity=quantity,
                n=int(st['n']), mean=st['mean'], min=st['min'], max=st['max'],
                abs_max=abs_max, reference=reference, ratio=ratio, verdict=verdict)


def plot_jump(path: Path, cases: list, curves: dict, reference: dict, title: str,
              ylabel: str, ref_label: str):
    """Diurnal cycles of the residual steps (one panel per case).

    `curves` maps a case to a list of (label, colour, series) and `reference`
    to the scale of the switched flux of the case, drawn as +-reference dashed
    lines: a missing or duplicated flux would show up at that level.
    """
    ncol = 2
    nrow = max(1, int(np.ceil(len(cases) / ncol)))
    fig, axes = plt.subplots(nrow, ncol, figsize=(13.0, 3.0 * nrow), squeeze=False)
    axes = list(axes.ravel())
    for ax, case in zip(axes, cases):
        sc = reference[case]
        ax.axhline(0.0, color='#444444', lw=1.0)
        if np.isfinite(sc):
            ax.axhline(+sc, color='#d62728', ls='--', lw=1.1,
                       label=f'+-{ref_label} = {sc:.1f} W/m2')
            ax.axhline(-sc, color='#d62728', ls='--', lw=1.1)
        for label, colour, y in curves.get(case, ()):
            if y is None:
                continue
            ax.plot(np.arange(24), y, color=colour, lw=1.2, label=label)
        ax.set_title(case, fontsize=9)
        ax.set_ylabel(ylabel)
        ax.set_xlabel('hour (UTC)')
        ax.grid(alpha=0.3)
        ax.legend(fontsize=6)
    for ax in axes[len(cases):]:
        ax.axis('off')
    fig.suptitle(title, fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    fig.savefig(path, dpi=150)
    plt.close(fig)



def col(runs: dict, key: tuple, name: str, size: int):
    """One column of one configuration (NaN when the configuration is missing)."""
    data = runs.get(key)
    return None if data is None else vec(data.get(name), size)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description='Verification of AHF_TRAFFIC and H_WASTE in H_TOWN '
                    '(with the cbs scheme off and on)')
    ap.add_argument('--work-dir', default=DEFAULT_WORK_DIR,
                    help='root of the simulation work (default: %(default)s)')
    ap.add_argument('--site', default='Moscow',
                    help='site name (default: %(default)s)')
    ap.add_argument('--base-root', default=None,
                    help='experiment with traffic 0 and waste heat '
                         '(default: <site>/compare_cbs_scheme)')
    ap.add_argument('--traffic-root', default=None,
                    help='experiment with the traffic heat flux '
                         '(default: <site>/compare_cbs_scheme_ahf20)')
    ap.add_argument('--nowaste-root', default=None,
                    help='control experiment without waste heat '
                         '(default: <site>/compare_cbs_scheme_nowaste)')
    ap.add_argument('--def-root', default=None,
                    help='experiment with the BEM switched off (teb_itype_bem = '
                         'DEF, optional; default: <site>/compare_cbs_scheme_def)')
    ap.add_argument('--out-root', default=None,
                    help='where the report is written '
                         '(default: <site>/check_anthro_heat)')
    ap.add_argument('--cases', default=None,
                    help='comma separated list of cases (default: all cases of '
                         'the reference experiment)')
    args = ap.parse_args(argv)

    site = Path(args.work_dir) / args.site
    root = {
        'base': Path(args.base_root) if args.base_root else site / 'compare_cbs_scheme',
        'traffic': Path(args.traffic_root) if args.traffic_root else site / 'compare_cbs_scheme_ahf20',
        'nowaste': Path(args.nowaste_root) if args.nowaste_root else site / 'compare_cbs_scheme_nowaste',
        'def': Path(args.def_root) if args.def_root else site / 'compare_cbs_scheme_def',
    }
    out_root = Path(args.out_root) if args.out_root else site / 'check_anthro_heat'
    for key, path in list(root.items()):
        if not path.is_dir():
            if key == 'def':                       # optional configuration
                print(f'WARNING: {key} root not found, BEM-off checks skipped: {path}')
                root.pop(key)
                continue
            print(f'ERROR: {key} root not found: {path}')
            return 2

    cases = []
    for path in sorted(root['base'].glob('output_*')):
        name = path.name[len('output_'):]
        if name.endswith('_cbs') or not (path / 'TEB_output.csv').is_file():
            continue
        cases.append(name)
    if args.cases:
        wanted = {s.strip() for s in args.cases.split(',') if s.strip()}
        cases = [c for c in cases if c in wanted]
    if not cases:
        print('ERROR: no case found in', root['base'])
        return 2

    print('==================================================================')
    print('Anthropogenic heat fluxes of the town balance (AHF_TRAFFIC, H_WASTE)')
    for key in ('base', 'traffic', 'nowaste'):
        print(f'  {key:<8}:', root[key])
    print('  cases   :', ', '.join(cases))
    print('==================================================================')


    rows = []
    curves_traffic, curves_waste, scale_traffic, scale_waste = {}, {}, {}, {}
    for case in cases:
        lcz_tag = next((t for t in LCZ if case.startswith(t)), None)
        fr_bld = float(LCZ[lcz_tag]['fr_bld']) if lcz_tag else np.nan

        #: model output of every configuration of the case
        runs = {}
        for key, path in root.items():
            for tag, label in CBS_MODES:
                out_dir = path / f'output_{case}{tag}'
                if (out_dir / 'TEB_output.csv').is_file():
                    runs[(key, label)] = read_run(out_dir)
        if ('base', 'cbs off') not in runs:
            print(f'  [skip] {case}: no reference run')
            continue

        hours, minutes, seconds = clock(runs[('base', 'cbs off')]['time'])
        size = len(hours)
        g = {key: balance(data, size) for key, data in runs.items()}

        #: traffic flux prescribed by the case namelist of the traffic run
        nml = root['traffic'] / 'namelists' / f'{case}.nml'
        ahf = float(namelist_get(nml, 'ahf_traffic', 0.0))
        utc_hour = int(namelist_get(nml, 'teb_utc_hour', 0))
        traf_scale = mean_abs(col(runs, ('traffic', 'cbs off'), 'AHF_TRAFFIC', size))
        anthro_waste = (mean_abs(col(runs, ('base', 'cbs off'), 'H_WASTE', size))
                        + mean_abs(col(runs, ('base', 'cbs off'), 'LE_WASTE', size)))
        waste_scale = anthro_waste

        #: response of H_TOWN to the anthropogenic fluxes of the case
        d_traf = {label: diff(col(runs, ('traffic', label), 'H_TOWN', size),
                              col(runs, ('base', label), 'H_TOWN', size))
                  for tag, label in CBS_MODES}
        d_bem = {label: diff(col(runs, ('base', label), 'H_TOWN', size),
                             col(runs, ('def', label), 'H_TOWN', size))
                 for tag, label in CBS_MODES}

        #: the cbs scheme must leave both sensitivities unchanged
        rows.append(result(case, '-', 'cbs: traffic sensitivity kept',
                           'dH_TOWN(traffic), cbs on - cbs off',
                           diff(d_traf['cbs on'], d_traf['cbs off']),
                           traf_scale, TOL_KEPT, compare_mean=True))
        rows.append(result(case, '-', 'cbs: BEM sensitivity kept',
                           'dH_TOWN(BEM), cbs on - cbs off',
                           diff(d_bem['cbs on'], d_bem['cbs off']),
                           anthro_waste, TOL_KEPT, compare_mean=True))

        for tag, label in CBS_MODES:
            # 1. the traffic flux of the model is exactly the prescribed cycle
            data = runs.get(('traffic', label))
            if data is not None and ahf:
                best = None
                for lag in (-1, 0, 1):
                    prescribed = ahf_traffic_now(ahf, hours + lag, minutes,
                                                 seconds, utc_hour)
                    err = vec(data['AHF_TRAFFIC'], size) - prescribed
                    cand = (float(np.nanmax(np.abs(err))), lag, prescribed, err)
                    if best is None or cand[0] < best[0]:
                        best = cand
                _, lag, prescribed, err = best
                rows.append(result(case, label, 'traffic prescribed',
                                   f'AHF_TRAFFIC - prescribed (lag {lag:+d} h)',
                                   err, mean_abs(prescribed), TOL_PRESCRIBED))
            # 2. H_TOWN must keep its sensitivity to the traffic heat flux
            if d_traf[label] is not None:
                rows.append(result(case, label, 'H_TOWN sensitivity to traffic',
                                   'H_TOWN(traffic on) - H_TOWN(traffic off)',
                                   d_traf[label], traf_scale, TOL_SENS_TRAFFIC,
                                   compare_mean=True, window=True))
            # 3. H_TOWN must keep its sensitivity to the BEM (waste heat)
            if d_bem[label] is not None:
                rows.append(result(case, label, 'H_TOWN sensitivity to BEM',
                                   'H_TOWN(BEM on) - H_TOWN(BEM off)',
                                   d_bem[label], anthro_waste, TOL_SENS_BEM,
                                   compare_mean=True, window=True))
            # 2. residual of the town balance of every configuration. The
            #    diagnostics of the model have an intrinsic leak of their own
            #    (a few W/m2, daytime), so this row has no verdict: what matters
            #    is that switching an anthropogenic flux on does not move the
            #    residual by the flux itself (rows 3 to 5)
            for key, cfg in (('base', 'traffic 0, waste on'),
                             ('traffic', 'traffic on, waste on'),
                             ('nowaste', 'traffic 0, waste off')):
                if (key, label) not in g:
                    continue
                scale = (mean_abs(col(runs, (key, label), 'AHF_TRAFFIC', size))
                         + mean_abs(col(runs, (key, label), 'H_WASTE', size))
                         + mean_abs(col(runs, (key, label), 'LE_WASTE', size)))
                rows.append(result(case, label, f'balance residual ({key})',
                                   f'RN + AHF + waste - H - LE - G ({cfg})',
                                   g.get((key, label)), scale))
            # 3. the traffic must be contained in H_TOWN exactly once: switching
            #    it on must not move the mean of the residual by the traffic flux
            rows.append(result(case, label, 'traffic in H_TOWN',
                               'mean of R(traffic on) - R(traffic off)',
                               diff(g.get(('traffic', label)), g.get(('base', label))),
                               traf_scale, TOL_JUMP, compare_mean=True))
            # 4. the control configuration must have no waste heat at all
            if ('nowaste', label) in runs:
                rows.append(result(case, label, 'waste control',
                                   'H_WASTE + LE_WASTE (control without waste)',
                                   vec(runs[('nowaste', label)].get('H_WASTE'), size)
                                   + vec(runs[('nowaste', label)].get('LE_WASTE'), size),
                                   waste_scale, TOL_ZERO, absolute=True))
                #: informative only: switching the waste heat off also changes the
                #: thermal state of the buildings, so the intrinsic leak of the
                #: balance changes with it
                rows.append(result(case, label, 'waste in H_TOWN',
                                   'R(waste on) - R(waste off), building state '
                                   'changes as well',
                                   diff(g.get(('base', label)), g.get(('nowaste', label))),
                                   waste_scale))

        # 5. the cbs scheme must not move the residual of the balance either
        #    (informative: the residual has its own spikes, so the mean is used)
        rows.append(result(case, '-', 'balance residual vs tau (traffic)',
                           'mean of R(cbs on) - R(cbs off), traffic on',
                           diff(g.get(('traffic', 'cbs on')), g.get(('traffic', 'cbs off'))),
                           traf_scale + anthro_waste))
        rows.append(result(case, '-', 'balance residual vs tau (waste)',
                           'mean of R(cbs on) - R(cbs off), waste on',
                           diff(g.get(('base', 'cbs on')), g.get(('base', 'cbs off'))),
                           traf_scale + anthro_waste))

        # 6. the cbs scheme only moves the town flux through the road term
        d_town = diff(col(runs, ('base', 'cbs on'), 'H_TOWN', size),
                      col(runs, ('base', 'cbs off'), 'H_TOWN', size))
        d_road = diff(col(runs, ('base', 'cbs on'), 'H_ROAD', size),
                      col(runs, ('base', 'cbs off'), 'H_ROAD', size))
        road_frac = 1.0 - fr_bld
        road_resid = (None if d_town is None or d_road is None
                      else d_town - road_frac * d_road)
        rows.append(result(case, '-', 'cbs effect on H_TOWN (informative)',
                           f'dH_TOWN - {road_frac:g}*dH_ROAD (road fraction)',
                           road_resid, mean_abs(d_town)))

        #: diurnal cycles of the sensitivity of H_TOWN (figures)
        h_waste = (np.asarray(vec(col(runs, ('base', 'cbs off'), 'H_WASTE', size), size))
                   + np.asarray(vec(col(runs, ('base', 'cbs off'), 'LE_WASTE', size), size)))
        curves_traffic[case] = [
            (f'H_TOWN(traffic) - H_TOWN(no traffic), {label}', colour,
             diurnal_mean(d_traf[label], hours))
            for label, colour in (('cbs off', '#1f77b4'), ('cbs on', '#d62728'))]
        curves_traffic[case].append(
            ('prescribed traffic flux', '#7f7f7f',
             diurnal_mean(vec(col(runs, ('traffic', 'cbs off'), 'AHF_TRAFFIC', size), size),
                          hours)))
        curves_waste[case] = [
            (f'H_TOWN(BEM) - H_TOWN(BEM off), {label}', colour,
             diurnal_mean(d_bem[label], hours))
            for label, colour in (('cbs off', '#2ca02c'), ('cbs on', '#9467bd'))]
        curves_waste[case].append(
            ('waste heat of the buildings', '#7f7f7f', diurnal_mean(h_waste, hours)))
        scale_traffic[case] = traf_scale
        scale_waste[case] = anthro_waste
        print(f'  [ok  ] {case}: dH_TOWN(traffic {traf_scale:6.2f} W/m2) = '
              f'{nan_mean(d_traf["cbs off"]):+7.2f} (cbs off) / '
              f'{nan_mean(d_traf["cbs on"]):+7.2f} W/m2 (cbs on); '
              f'dH_TOWN(BEM, waste {anthro_waste:5.2f} W/m2) = '
              f'{nan_mean(d_bem["cbs off"]):+7.2f} / '
              f'{nan_mean(d_bem["cbs on"]):+7.2f} W/m2')


    out_root.mkdir(parents=True, exist_ok=True)
    stats = pd.DataFrame(rows)
    stats_csv = out_root / 'summary_anthro_heat.csv'
    stats.to_csv(stats_csv, index=False, float_format='%.8f')

    plots = out_root / 'plots'
    plots.mkdir(parents=True, exist_ok=True)
    plot_jump(plots / 'anthro_traffic.png', list(curves_traffic), curves_traffic,
              scale_traffic, 'Sensitivity of H_TOWN to the traffic heat flux '
              '(cbs scheme off and on)', 'H_TOWN(traffic) - H_TOWN(no traffic) (W/m2)',
              'traffic')
    plot_jump(plots / 'anthro_bem.png', list(curves_waste), curves_waste,
              scale_waste, 'Sensitivity of H_TOWN to the BEM (waste heat of the '
              'buildings), cbs scheme off and on',
              'H_TOWN(BEM) - H_TOWN(BEM off) (W/m2)', 'waste heat')
    write_readme(out_root, root, cases, stats)
    print('\nCheck table:', stats_csv)
    print('Report     :', out_root / 'README.md')
    return 0


def write_readme(out_root: Path, root: dict, cases: list, stats: pd.DataFrame):
    """Method, code path and results of the verification."""
    table = []
    for check in stats.check.unique():
        sub = stats[stats.check == check]
        i = int(sub.abs_max.to_numpy().argmax())
        table.append(f'| {check} | {sub.quantity.iloc[0]} | {len(sub)} | '
                     f'{sub.abs_max.max():.3e} | {sub.reference.max():.3f} | '
                     f'{sub.ratio.max():.3e} | {sub.case.iloc[i]} | '
                     f'{int((sub.verdict == "OK").sum())}/{len(sub)} |')
    txt = (README_HEAD.format(base=root['base'].name, traffic=root['traffic'].name,
                              nowaste=root['nowaste'].name,
                              def_=root['def'].name if 'def' in root else 'not run',
                              cases=', '.join(f'`{c}`' for c in cases))
           + '\n'.join(table) + README_TAIL)
    (out_root / 'README.md').write_text(txt, encoding='utf-8')


#: report written next to the check table: the results table (built from the
#: checks) is inserted between README_HEAD and README_TAIL
README_HEAD = """# Anthropogenic heat fluxes of the town balance (AHF_TRAFFIC, H_WASTE)

Generated by `python_tests/check_anthro_heat.py`. It verifies, with the cbs scheme off
and on, that the anthropogenic heat fluxes are accounted for correctly in the
town sensible heat flux `H_TOWN`.

## Method

Two sensitivities of the town sensible heat flux are measured on pairs of runs
that differ by one source only (every pair is simulated twice, with
`teb_lcbs_scheme = .FALSE.` and `.TRUE.`):

| sensitivity | runs compared | expected response |
| --- | --- | --- |
| traffic | `ahf_traffic = 20` minus `ahf_traffic = 0` | `H_TOWN` increases by the traffic flux (up to the part going into storage) |
| BEM | `teb_itype_bem = BEM` minus `DEF` | `H_TOWN` increases by the waste heat of the buildings (HVAC + infiltration/ventilation) |

Both responses are compared with the flux itself (`reference` column) and the
response of the cbs run is compared with the response of the reference run: the
cbs scheme must not change them. In addition the energy balance of the town is
closed with model diagnostics only:

```
R = RN_TOWN + AHF_TRAFFIC + AHF_INDUSTRY + H_WASTE + LE_WASTE + LE_TRAFFIC
    + LE_INDUSTRY - H_TOWN - LE_TOWN - GFLUX_TOWN
```

`RN_TOWN`, `H_TOWN`, `LE_TOWN` and `GFLUX_TOWN` are independent diagnostics of the
town surface budget. `R` must not change when an anthropogenic flux is switched
on: a missing, duplicated or `tau`-weighted term would appear as a residual of
the size of the flux itself. (The residual has an intrinsic leak of a few W/m2 —
daytime, of radiative origin — in this model version, hence no verdict on the
absolute value of `R`; the rows with a verdict compare the *changes* of `R` and
the sensitivities.)

## Configurations

| experiment | traffic | BEM |
| --- | --- | --- |
| `{base}` | 0 | `BEM` (waste heat active) |
| `{traffic}` | `ahf_traffic` of the case namelists | `BEM` |
| `{nowaste}` | 0 | `BEM` without HVAC/infiltration/natural ventilation |
| `{def_}` | 0 | `DEF` (no building energy module) |

Cases: {cases}. Every case is available with `teb_lcbs_scheme = .FALSE.` (tau
off) and `.TRUE.` (cbs on).

## Results

| check | quantity | rows | max abs step | reference scale | ratio | worst case | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
"""

README_TAIL = """
* `traffic prescribed`: the traffic flux written by the model is exactly the
  daily cycle of `AHF_TRAFFIC_NOW` applied to `ahf_traffic` (round-off only).
* `H_TOWN sensitivity to traffic` / `H_TOWN sensitivity to BEM`: the response of
  the town sensible heat flux to the source, compared with the source itself
  (it must be positive and close to the flux; part of the heat goes into storage
  and into the other surface fluxes).
* `cbs: traffic sensitivity kept` / `cbs: BEM sensitivity kept`: the same
  response in the cbs run minus the response in the reference run: the cbs scheme
  must not modify the sensitivity (it weights the road exchange only).
* `traffic in H_TOWN`: change of the residual `R` of the town balance when the
  traffic is switched on: it must stay far below the traffic flux.
* `balance residual ...`: absolute value of `R` per configuration (informative:
  the model diagnostics have an intrinsic leak of their own).
* `waste control`: `H_WASTE + LE_WASTE` of the configuration without HVAC and
  without ventilation, which must be zero.
* `cbs effect on H_TOWN (informative)`: `dH_TOWN` of the tau pair minus
  `(1 - fr_bld) * dH_ROAD`: the cbs scheme modifies the road exchange only, so
  the change of the town flux must be the change of the road term.

## Code path of the anthropogenic fluxes

| where | what |
| --- | --- |
| `src/src_driver/ahf_traffic_now.F90` | daily cycle of the traffic flux (`ahf_traffic_weight`, Flanner 2009) |
| `src/src_driver/call_driver.F90:1350-1356` | `H_TRAFFIC_NOW`, scaling by the urban fraction (`FR_URB`), passed to TEB |
| `src/src_struct/teb_garden_struct.F90:995-997` | `T%XH_TRAFFIC = PH_TRAFFIC` |
| `src/src_teb/avg_urban_fluxes.F90:259-262` | traffic added to the ground flux (`PH_GRND`) of the canyon |
| `src/src_teb/avg_urban_fluxes.F90:280-286` | `H_TOWN`: surface fluxes `+ PH_TRAFFIC + XH_INDUSTRY`, without tau weight |
| `src/src_teb/avg_urban_fluxes.F90:474-482` | canyon air balance: only the road terms carry `PTAU`, the traffic enters with full weight |
| `src/src_teb/avg_urban_fluxes.F90:491-493` | canyon air balance: waste heat released into the canyon, full weight |
| `src/src_teb/avg_urban_fluxes.F90:510-519` | same for the canyon specific humidity (latent waste heat) |
| `src/src_teb/bem.F90:596-719` | `H_WASTE`: HVAC systems (cooling/heating) and infiltration/ventilation |
| `src/src_teb/teb.F90:868-877` | BEM call and waste heat scaled from the building area to the horizontal area (`* T%XBLD`) |
| `src/src_teb/urban_fluxes.F90:207-220` | canyon part of the waste heat added to the wall fluxes (`/ XWALL_O_HOR`) |
| `src/src_teb/urban_fluxes.F90:282-285` | remaining part added to the roof fluxes (`/ XBLD`) |
| `src/src_teb/urban_fluxes.F90:196-197` | wall ground fluxes computed *before* the waste heat is added: no double counting |
| `src/src_teb/teb.F90:752-784` | cbs scheme: only the effective conductance and the reference air of the road budget are weighted |
| `src/src_driver/run_teb_offline.F90` | output columns `AHF_TRAFFIC` and `H_WASTE` |

Conclusion: the cbs scheme replaces the road exchange (effective conductance and
reference air of `ROAD_LAYER_E_BUDGET`) and weights the road terms of the canyon
air and humidity balances. `AHF_TRAFFIC` and `H_WASTE` enter `H_TOWN` and the
canyon air outside those terms, with their full weight, in both cbs modes.

## Files

* `summary_anthro_heat.csv` - every check, one row per case and cbs mode
* `plots/anthro_traffic.png` - diurnal cycle of the response of `H_TOWN` to the
  traffic (grey: the prescribed traffic flux), cbs scheme off and on
* `plots/anthro_bem.png` - diurnal cycle of the response of `H_TOWN` to the BEM
  (grey: the waste heat of the buildings), cbs scheme off and on

## Re-running

```
python python_tests/check_anthro_heat.py
python python_tests/check_anthro_heat.py --cases LCZ9_w0,SPARSE_w0
```
"""


if __name__ == '__main__':
    sys.exit(main())

