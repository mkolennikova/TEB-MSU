#!/usr/bin/env python
"""
Comparison of the TEB-Ru cbs scheme for the road fluxes.

Purpose
-------
With the cbs scheme the actual road fluxes are the weighted mean of the
road/canyon and road/forcing-level exchanges, with the weights tau and 1-tau:

    tau = 0.5 * (1 + tanh((H/W - teb_tau_hw_thresh) / teb_tau_hw_width))

so that tau -> 0 for very sparse buildings (the road exchanges directly with the
air of the forcing level) and tau = 1 for a dense canyon (the road exchanges
with the canyon air only).

This script runs every case twice - with teb_lcbs_scheme = .FALSE. (reference)
and .TRUE. (cbs scheme) - and compares the effect of the scheme on

  * the canyon air temperature T_CANYON and specific humidity Q_CANYON,
  * the actual road fluxes H_ROAD / LE_ROAD (as used by the road energy budget),
  * their potential components: H/LE_ROAD_CAN (as if tau = 1, all to the canyon
    air) and H/LE_ROAD_ATM (as if tau = 0, all to the forcing level air),
  * the town fluxes H_TOWN / LE_TOWN.

Experiment design
-----------------
Same forcing and building parameters as `python_tests/sensitivity_zd.py`: the Moscow
ERA5 forcing (hlev_teb = 10 m), the LCZ 2, LCZ 6D, LCZ 9 and SPARSE morphologies
(LCZ 6D is the extra low but dense one) and the two canyon-wind schemes
(teb_itype_wind = 0 and 1). The urban roughness length and the displacement height
keep their default prescriptions (urb_z0_town = '0.1H' and urb_zd_town = 'H/3').

The cbs scheme is driven by the canyon H/W ratio of the morphology (urb_h2w):
LCZ 2 (compact midrise) is a dense canyon (tau close to 1), LCZ 6D (low but dense
buildings) sits exactly on the driver default of the threshold, urb_h2w = 0.5 =
teb_tau_hw_thresh, so that tau = 0.5 (the worst case of the cbs averaging, where
the canyon path and the atmosphere path carry the same weight), and LCZ 9 and
SPARSE (sparsely built) are close to the free atmosphere (small tau).

Files (kept, not deleted; use --force to re-run a simulation):
  <out_root>/namelists/<case>.nml      namelist of every case
  <out_root>/output_<case>/            model output (TEB_output.csv)
  <out_root>/logs/<case>.log           model log
  <out_root>/summary_cbs_scheme.csv    statistics per case (ref, tau, difference)
  <out_root>/plots/cbs_*.png           comparison figures
  <out_root>/README.md                 description of the experiment

Usage
-----
    python python_tests/compare_cbs_scheme.py                   # run everything
    python python_tests/compare_cbs_scheme.py --list            # list the cases
    python python_tests/compare_cbs_scheme.py --skip-run        # statistics/plots only
    python python_tests/compare_cbs_scheme.py --force           # re-run existing cases
    python python_tests/compare_cbs_scheme.py --no-cbs          # reference runs only
    python python_tests/compare_cbs_scheme.py --tau-hw-thresh 0.5 --tau-hw-width 0.2
    python python_tests/compare_cbs_scheme.py --no-garden       # garden off
    python python_tests/compare_cbs_scheme.py --days 3          # length of the series
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

# the experiment reuses the site/forcing/base-namelist logic of sensitivity_zd.py;
# the building configurations come from the shared morphology.py (the single set
# LCZ, which includes the low but dense LCZ6D with tau = 0.5)
from morphology import LCZ                                           # noqa: E402
from sensitivity_zd import (                                         # noqa: E402
    WIND_TYPES, DEFAULT_WORK_DIR,
    run_case, series, stats_of, banner_values, read_forcing,
)

#: values >= XUNDEF are undefined in TEB-Ru (MODD_SURF_PAR:XUNDEF = 1.0e20)
XUNDEF = 1.0e19

#: variables compared between the reference and the cbs runs: column ->
#: (label, unit, colour)
CMP = {
    'T_CANYON':    ('canyon air temperature',                'K',     '#1f77b4'),
    'T_CAN0':      ('canyon air temperature without tau',    'K',     '#17becf'),
    'T_CAN1':      ('free layer (second canopy) air temperature', 'K', '#ff7f0e'),
    'PHI_CAN1':    ('free layer air temperature / theta* ratio of the MOST profile', '-', '#8c564b'),
    'Q_CANYON':    ('canyon air specific humidity',          'kg/kg', '#e377c2'),
    'H_TOWN':      ('town sensible heat flux',               'W/m2',  '#d62728'),
    'LE_TOWN':     ('town latent heat flux',                 'W/m2',  '#2ca02c'),
    'H_ROAD':      ('road sensible heat flux (actual)',      'W/m2',  '#9467bd'),
    'LE_ROAD':     ('road latent heat flux (actual)',        'W/m2',  '#8c564b'),
    'H_ROAD_CAN':  ('road H with the canyon air (tau = 1)',  'W/m2',  '#17becf'),
    'H_ROAD_ATM':  ('road H with the forcing level air (tau = 0)', 'W/m2', '#bcbd22'),
    'LE_ROAD_CAN': ('road LE with the canyon air (tau = 1)', 'W/m2',  '#7f7f7f'),
    'LE_ROAD_ATM': ('road LE with the forcing level air (tau = 0)', 'W/m2', '#e377c2'),
}

#: auxiliary columns (diagnostics of the run, not compared)
AUX = ('T_ROAD1', 'Forc_TA', 'Forc_WIND', 'U_CANYON', 'WIND_TOP')

#: diurnal-cycle figures: (variable, file name, y label). One variable per
#: figure: temperature and humidity differ by orders of magnitude, and a single
#: curve pair per panel keeps the effect of the cbs scheme readable
DIURNAL = (
    ('T_CANYON', 'cbs_canyon_diurnal.png',   'canyon air temperature (K)'),
    ('T_CAN1',   'cbs_tcan1_diurnal.png',    'free layer air temperature (K)'),
    ('Q_CANYON', 'cbs_humidity_diurnal.png', 'canyon air sp. humidity (kg/kg)'),
    ('H_TOWN',   'cbs_htown_diurnal.png',    'H town (W/m2)'),
    ('LE_TOWN',  'cbs_letown_diurnal.png',   'LE town (W/m2)'),
    ('H_ROAD',   'cbs_hroad_diurnal.png',    'H road, actual (W/m2)'),
    ('LE_ROAD',  'cbs_lroad_diurnal.png',    'LE road, actual (W/m2)'),
)

#: time-series figures: (variable, file name, y label)
TIMESERIES = (
    ('T_CANYON', 'cbs_canyon_timeseries.png', 'canyon air temperature (K)'),
    ('H_TOWN',   'cbs_htown_timeseries.png',  'H town (W/m2)'),
)

#: potential components of the road flux drawn with the actual road flux of the
#: cbs run (they show that the actual flux is their tau-weighted mean)
ROAD_COMPONENTS = ('H_ROAD_CAN', 'H_ROAD_ATM')

#: the reference (cbs scheme off) is drawn in grey and dashed, the cbs run in
#: the colour of the variable and solid
COLOUR_REF = '#7f7f7f'

#: further curves drawn on some figures: figure variable -> (variable, label,
#: colour, style, line width, source). The air temperature of the forcing level
#: is an input: it is identical in the two runs, so it is drawn once per panel
#: ('ref') and shows how far the canyon air follows the forcing. All the other
#: curves are model diagnostics, which differ between the two runs: they must be
#: taken from the cbs run ('run'), otherwise the figure shows the reference
#: canyon air instead of the tau-relaxed one.
EXTRA = {
    'T_CANYON': (('Forc_TA', 'T forcing level', '#000000', ':', 1.8, 'ref'),),
    'T_CAN1':   (('T_CAN0', 'T_CAN0 (no tau)', '#17becf', '--', 1.6, 'run'),
                 ('T_CANYON', 'T canyon (tau relaxed)', '#1f77b4', '-.', 1.6, 'run'),
                 ('Forc_TA', 'T forcing level', '#000000', ':', 1.8, 'ref')),
}

#: default prescriptions of the urban roughness length and displacement height
Z0_DEFAULT = '0.1H'
ZD_DEFAULT = 'H/3'

#: default cbs scheme parameters (same as the driver defaults)
TAU_THRESH_DEFAULT = 0.5
TAU_WIDTH_DEFAULT = 0.25

#: control configuration without waste heat of the buildings: the HVAC system is
#: off and the set-points are impossible to reach, so that H_WASTE vanishes
WASTE_OFF_TCOOL = 350.0
WASTE_OFF_THEAT = 200.0


def tau_of(hw_ratio: float, thresh: float, width: float) -> float:
    """tau of the cbs scheme: tanh relaxation of the canyon H/W ratio.

    tau -> 0 for very sparse buildings (H/W -> 0) and tau -> 1 for a dense
    canyon (H/W well above the threshold). Same formula as (and kept in sync
    with) the CBS_TAU function of TEB_GARDEN.
    """
    return 0.5 * (1.0 + math.tanh((hw_ratio - thresh) / max(width, 1.0e-12)))


def cases(use_cbs: bool = True):
    """Deterministic list of (case, lcz_tag, wind_type, cbs_scheme)."""
    out = []
    for lcz_tag in LCZ:
        for wind_type, wind_tag in WIND_TYPES.items():
            out.append((f'{lcz_tag}_{wind_tag}', lcz_tag, wind_type, False))
            if use_cbs:
                out.append((f'{lcz_tag}_{wind_tag}_cbs', lcz_tag, wind_type, True))
    return out


def pairs(use_cbs: bool = True):
    """Reference/tau case pairs: (case, case_cbs or None, lcz_tag, wind_type)."""
    return [(f'{lcz_tag}_{wind_tag}', f'{lcz_tag}_{wind_tag}_cbs' if use_cbs else None,
             lcz_tag, wind_type)
            for lcz_tag in LCZ for wind_type, wind_tag in WIND_TYPES.items()]


def build_namelist(base_nml: Path, lcz_tag: str, wind_type: int, path: Path,
                   garden: bool, fr_garden: float, tau: bool,
                   tau_thresh: float, tau_width: float,
                   ahf_traffic: float = 0.0, waste: bool = True) -> Path:
    """Namelist of one case: base namelist + LCZ + wind scheme + cbs scheme.

    `ahf_traffic` is the annual mean anthropogenic heat flux due to traffic
    [W/m2] of the namelist (a daily cycle is applied by the driver, see
    AHF_TRAFFIC_NOW). With `waste = False` the HVAC system and the
    infiltration/ventilation of BEM are switched off, so that the waste heat of
    the buildings (H_WASTE) vanishes: this is the control configuration of the
    verification of the anthropogenic heat accounting.
    """
    nml = f90nml.read(str(base_nml))
    p = nml['tebparam']
    lcz = LCZ[lcz_tag]
    p['urb_h_bld'] = float(lcz['h_bld'])
    p['urb_fr_bld'] = float(lcz['fr_bld'])
    p['urb_h2w'] = float(lcz['h2w'])
    p['teb_fai'] = [float(lcz['fai'])] * 8
    p['teb_itype_wind'] = int(wind_type)
    p['urb_z0_town'] = Z0_DEFAULT
    p['urb_zd_town'] = ZD_DEFAULT
    p['teb_lgarden'] = bool(garden)
    p['fr_garden'] = float(fr_garden) if garden else 0.0
    p['teb_lcbs_scheme'] = bool(tau)
    p['teb_tau_hw_thresh'] = float(tau_thresh)
    p['teb_tau_hw_width'] = float(tau_width)
    p['ahf_traffic'] = float(ahf_traffic)
    p['ahf_industry'] = 0.0
    if not waste:
        p['teb_lbem_ac'] = False
        p['teb_tcool_target'] = WASTE_OFF_TCOOL
        p['teb_theat_target'] = WASTE_OFF_THEAT
        p['teb_bem_inf'] = 0.0
        p['teb_bem_vent'] = 0.0
        #: natural ventilation must be off as well: it injects canyon air into
        #: the buildings and contributes to the waste heat (H_WASTE)
        p['teb_itype_natvent'] = 'NONE'
    path.parent.mkdir(parents=True, exist_ok=True)
    nml.write(str(path), force=True)
    return path


def mask_undefined(x):
    """Replace the TEB-Ru undefined values (XUNDEF) by NaN."""
    if x is None:
        return None
    x = np.array(x, dtype=float)
    x[np.abs(x) >= XUNDEF] = np.nan
    return x


def read_case(out_dir: Path) -> dict:
    """Compared and auxiliary time series (and the time stamps) of one case."""
    data = {name: mask_undefined(series(out_dir, name)) for name in CMP}
    for name in AUX:
        data[name] = mask_undefined(series(out_dir, name))
    csv = out_dir / 'TEB_output.csv'
    data['time'] = (pd.read_csv(csv, sep=';', usecols=['time'])['time']
                    if csv.is_file() else None)
    return data


def mean_of(x):
    """Mean of a masked series (NaN when nothing is available)."""
    if x is None or not np.any(np.isfinite(x)):
        return np.nan
    return float(np.nanmean(x))


def case_statistics(case: str, ref: dict, run: dict, tau_val: float) -> list:
    """One row per compared variable: reference, cbs run and their difference."""
    rows = []
    for name, (label, unit, _) in CMP.items():
        a, b = ref.get(name), run.get(name)
        st_a = stats_of(None if a is None else a[np.isfinite(a)])
        st_b = stats_of(None if b is None else b[np.isfinite(b)])
        d = np.array([])
        if a is not None and b is not None and a.shape == b.shape:
            m = np.isfinite(a) & np.isfinite(b)
            d = b[m] - a[m]
        rows.append(dict(case=case, variable=name, label=label, unit=unit,
                         tau=tau_val, n=int(d.size),
                         mean_ref=st_a['mean'], mean_cbs=st_b['mean'],
                         mean_diff=float(np.mean(d)) if d.size else np.nan,
                         min_diff=float(np.min(d)) if d.size else np.nan,
                         max_diff=float(np.max(d)) if d.size else np.nan,
                         std_ref=st_a['std'], std_cbs=st_b['std']))
    return rows


def _grid(n: int):
    """A grid of 2 panels per row, large enough for n panels."""
    ncol = 2
    nrow = int(np.ceil(n / ncol))
    fig, axes = plt.subplots(nrow, ncol, figsize=(13.6, 3.3 * nrow), squeeze=False)
    return fig, list(axes.ravel())


def _case_title(case: str, info: dict, tau_val: float) -> str:
    """Title of a panel: case name + morphology + the tau value of the case."""
    lcz_tag, wind_type = info[case]
    hw = float(LCZ[lcz_tag]['h2w'])
    return (f'{case}\n{LCZ[lcz_tag]["label"]}, teb_itype_wind = {wind_type}, '
            f'tau(H/W = {hw:g}) = {tau_val:.3f}')


def _panel(ax, case, info, tau_val, x, series_list, ylabel):
    """One panel: several (label, y, colour, style[, line width]) series."""
    for label, y, col, ls, *rest in series_list:
        if y is None or not np.any(np.isfinite(y)):
            continue
        ax.plot(x, y, label=label, color=col, ls=ls,
                lw=rest[0] if rest else 1.1)
    ax.set_title(_case_title(case, info, tau_val), fontsize=9)
    ax.set_ylabel(ylabel)
    ax.grid(alpha=0.3)
    ax.legend(fontsize=6)
    ax.tick_params(axis='x', labelsize=7, labelrotation=15)


def plot_timeseries(ref: dict, run: dict, info: dict, tau_vals: dict, name: str,
                    ylabel: str, days: float, path: Path, extra=()):
    """Time series of one variable, first `days` days: reference versus tau.

    `extra` lists further curves (variable, label, colour, style, line width,
    source): 'ref' for the forcing (an input, identical in both runs) and 'run'
    for the model diagnostics of the cbs run.
    """
    label, unit, col = CMP[name]
    keys = list(info)
    fig, axes = _grid(len(keys))
    for ax, case in zip(axes, keys):
        t = ref[case].get('time')
        y_ref, y_run = ref[case].get(name), run[case].get(name)
        if t is None or y_ref is None or y_run is None:
            ax.axis('off')
            continue
        nshow = int(days * 24) if t is not None else None
        x = (pd.to_datetime(t[:nshow]) if t is not None
             else np.arange(len(y_ref)))
        series = [
            (f'{label}, tau off', y_ref[:nshow], COLOUR_REF, '--'),
            (f'{label}, tau on', y_run[:nshow], col, '-'),
        ]
        for vname, vlabel, vcol, vls, vlw, src in extra:
            #: 'ref' for the forcing (an input, identical in both runs),
            #: 'run' for the model diagnostics of the cbs run
            y = (run[case] if src == 'run' else ref[case]).get(vname)
            series.append((vlabel, None if y is None else y[:nshow], vcol, vls, vlw))
        _panel(ax, case, info, tau_vals[case], x, series, ylabel)
    for ax in axes[len(keys):]:
        ax.axis('off')
    fig.suptitle(f'{label}, first {days:g} days: '
                 f'reference (cbs scheme off) versus cbs scheme', fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(path, dpi=150)
    plt.close(fig)


def _hourly_mean(y, hours, xh):
    """Mean of a series for every hour of the day."""
    return np.array([np.nanmean(y[hours == h])
                     if np.any(np.isfinite(y[hours == h])) else np.nan
                     for h in xh])


def plot_diurnal(ref: dict, run: dict, info: dict, tau_vals: dict, name: str,
                 ylabel: str, path: Path, ref_line: bool = True, run_only=(),
                 extra=()):
    """Mean diurnal cycle of one variable: reference versus cbs scheme.

    With `ref_line = False` only the cbs run is drawn (used for the potential
    components figure). `run_only` lists further variables drawn for the tau
    run, in their own colour and dotted. `extra` lists further curves
    (variable, label, colour, style, line width, source): 'ref' for the forcing
    (an input, identical in both runs) and 'run' for the model diagnostics of
    the cbs run (T_CAN0 and T_CANYON differ between the two runs, so the
    reference values would draw the canyon air without relaxation).
    """
    label, unit, col = CMP[name]
    keys = list(info)
    fig, axes = _grid(len(keys))
    for ax, case in zip(axes, keys):
        t = ref[case].get('time')
        if t is None:
            ax.axis('off')
            continue
        hours = pd.to_datetime(t).dt.hour.to_numpy()
        xh = np.arange(24)
        lines = ((ref[case], 'tau off', COLOUR_REF, '--'),
                 (run[case], 'tau on', col, '-'))
        series = []
        for data, kind, c, ls in (lines if ref_line else lines[1:]):
            y = data.get(name)
            if y is None or not np.any(np.isfinite(y)):
                continue
            series.append((f'{label}, {kind}', _hourly_mean(y, hours, xh), c, ls))
        for extra_name in run_only:
            lab2, unit2, col2 = CMP[extra_name]
            y = run[case].get(extra_name)
            if y is None or not np.any(np.isfinite(y)):
                continue
            series.append((f'{lab2} (tau on)', _hourly_mean(y, hours, xh), col2, ':'))
        for vname, vlabel, vcol, vls, vlw, src in extra:
            #: 'ref' for the forcing (an input, identical in both runs),
            #: 'run' for the model diagnostics of the cbs run
            y = (run[case] if src == 'run' else ref[case]).get(vname)
            if y is None or not np.any(np.isfinite(y)):
                continue
            series.append((vlabel, _hourly_mean(y, hours, xh), vcol, vls, vlw))
        _panel(ax, case, info, tau_vals[case], xh, series, ylabel)
        ax.set_xlabel('hour (UTC)')
    for ax in axes[len(keys):]:
        ax.axis('off')
    fig.suptitle(f'Mean diurnal cycle of {label}: reference versus cbs scheme',
                 fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_scatter(ref: dict, run: dict, info: dict, name: str, path: Path):
    """cbs run versus reference: canyon temperature and road flux."""
    label, unit, col = CMP[name]
    fig, ax = plt.subplots(1, 1, figsize=(6.8, 6.0))
    lo, hi = np.inf, -np.inf
    for case in info:
        a, b = ref[case].get(name), run[case].get(name)
        if a is None or b is None:
            continue
        m = np.isfinite(a) & np.isfinite(b)
        if not np.any(m):
            continue
        ax.scatter(a[m], b[m], s=6, alpha=0.4, label=case)
        lo = min(lo, float(np.nanmin(a[m])), float(np.nanmin(b[m])))
        hi = max(hi, float(np.nanmax(a[m])), float(np.nanmax(b[m])))
    if np.isfinite(lo) and np.isfinite(hi):
        ax.plot([lo, hi], [lo, hi], color='k', lw=0.8, ls='--', label='1:1')
    ax.set_xlabel(f'{label}: reference, cbs scheme off ({unit})')
    ax.set_ylabel(f'{label}: cbs scheme on ({unit})')
    ax.set_title(f'{label}: cbs scheme versus reference', fontsize=10)
    ax.grid(alpha=0.3)
    ax.legend(fontsize=7)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def write_readme(out_root: Path, base: Path, forcing_nml: Path, info: dict,
                 tau_thresh: float, tau_width: float, days: float,
                 garden: bool, fr_garden: float, ahf_traffic: float = 0.0,
                 waste: bool = True, bem: str = 'unknown'):
    """Describe the experiment next to the data."""
    lines = []
    for case in info:
        lcz_tag, wind_type = info[case]
        hw = float(LCZ[lcz_tag]['h2w'])
        lines.append(f'| `{case}` | {LCZ[lcz_tag]["label"]} | {wind_type} | '
                     f'{hw:g} | {tau_of(hw, tau_thresh, tau_width):.3f} |')
    txt = f"""# Comparison of the cbs scheme of the road fluxes (TEB-Ru)

Generated by `python_tests/compare_cbs_scheme.py`. The simulation data are kept here.

## Configuration

* Forcing: `{forcing_nml}`
* Base model namelist: `{base}`
* Urban roughness length and displacement height: defaults
  (`urb_z0_town = {Z0_DEFAULT}`, `urb_zd_town = {ZD_DEFAULT}`)
* Garden: {'activated' if garden else 'NOT activated'} (`teb_lgarden = {str(garden).upper()}`,
  `fr_garden = {fr_garden if garden else 0.0:g}`)
* Buildings: `teb_itype_bem = '{bem}'` (base namelist); waste heat
  {'active' if waste else 'switched OFF (control configuration: `teb_lbem_ac = .FALSE.`, `teb_bem_inf = teb_bem_vent = 0`)'}
* Anthropogenic heat flux due to traffic: `ahf_traffic = {ahf_traffic:g}` W/m2
  (daily cycle applied by the driver, `teb_utc_hour` of the base namelist),
  `ahf_industry = 0`
* Every case is run twice: `teb_lcbs_scheme = .FALSE.` (reference) and `.TRUE.`
  (cbs scheme), with `teb_tau_hw_thresh = {tau_thresh:g}` and
  `teb_tau_hw_width = {tau_width:g}`

## Cases and tau

| case | morphology | teb_itype_wind | H/W | tau |
| --- | --- | --- | --- | --- |
""" + '\n'.join(lines) + f"""

## Variables compared

| column | meaning |
| --- | --- |
| `T_CANYON` | canyon air temperature seen by the surfaces (tau relaxed) |
| `T_CAN0` | canyon air temperature without tau (the classic canyon air node) |
| `T_CAN1` | free layer (second canopy) air temperature: the air of the layer at H/2 when all the canyon surfaces exchange directly with the atmosphere |
| `PHI_CAN1` | ratio between the free layer air temperature anomaly and theta* (neutral limit: `ln(z_ref/(H/2))`) |
| `Q_CANYON` | canyon air specific humidity |
| `H_ROAD`, `LE_ROAD` | actual road fluxes (as used by the road energy budget) |
| `H_ROAD_CAN`, `LE_ROAD_CAN` | road fluxes with the canyon air (potential, tau = 1) |
| `H_ROAD_ATM`, `LE_ROAD_ATM` | road fluxes with the air of the forcing level (potential, tau = 0) |
| `H_TOWN`, `LE_TOWN` | town fluxes (all surfaces) |
| `AHF_TRAFFIC` | anthropogenic sensible heat flux due to traffic at the current time-step |
| `H_WASTE` | sensible waste heat of the buildings (HVAC + infiltration/ventilation) |

`AHF_TRAFFIC` and `H_WASTE` are already contained in `H_TOWN` with their full
weight: the cbs scheme replaces the road exchange only and does not weight the
anthropogenic fluxes (verified numerically by `python_tests/check_anthro_heat.py`),
so that `H_TOWN - AHF_TRAFFIC - H_WASTE` is the flux of the urban surfaces.

With the cbs scheme the actual road flux is the weighted mean
`tau * *_ROAD_CAN + (1 - tau) * *_ROAD_ATM`: only the tau fraction of the road
exchange heats the canyon air, the remaining part exchanging directly with the
air of the forcing level.

The air temperature seen by the surfaces is the tau relaxation of two end
members (`T_CAN = tau * T_CAN0 + (1 - tau) * T_CAN1`):

* `T_CAN0` - the classic canyon air node: the road exchanges with the canyon air
  (through `PAC_RD`), the walls/windows and the volumetric sources (traffic,
  waste heat) heat the same volume, and the volume is ventilated through the
  canyon top (through `PAC_TOP`);
* `T_CAN1` - the air of the layer [0, H] when all the canyon surfaces exchange
  directly with the atmosphere: the road and the garden through their
  surface-to-atmosphere fluxes, the walls/windows heat and the volumetric sources
  released inside the layer. Its temperature is taken at the height H/2 (as for
  the other canyon variables of TEB, see `ZZ_LOWCAN` in `CALL_DRIVER`) from the
  MOST profile of the direct flux (`u* = sqrt(PCD_ROAD_ATM) * PVMOD`, `theta*`
  and the Obukhov length of the road-to-atmosphere path, Businger-Dyer stability
  function for heat with the coefficients of `SURFACE_CD`/`SURFACE_AERO_COND`).
  With `tau = 0` the morphology disappears from this path: `T_CAN1` contains no
  canyon top conductance, no canyon wind and no canyon length, and the
  contributions of the walls, the waste heat and the traffic vanish with the
  building density.

With `teb_lcbs_scheme = .FALSE.` the driver sets `tau = 1`, so
`T_CAN = T_CAN0` and the reference run is exactly the former model (verified
bit-for-bit); the two tau limits are also reachable through the namelist without
any code switch (`teb_tau_hw_thresh = -1000` gives `tau = 1`,
`teb_tau_hw_thresh = +100` gives `tau = 0`).

## Files

* `namelists/<case>.nml` - namelist of every case
* `output_<case>/TEB_output.csv` - full model output
* `logs/<case>.log` - model log
* `summary_cbs_scheme.csv` - statistics of every variable per case
* `plots/cbs_canyon_timeseries.png` - canyon temperature, first {days:g} days,
  with the forcing-level temperature
* `plots/cbs_htown_timeseries.png` - town sensible heat flux, first {days:g} days
* `plots/cbs_canyon_diurnal.png` - mean diurnal cycle of the canyon temperature,
  with the forcing-level temperature (the temperature and the humidity are drawn
  separately: they differ by orders of magnitude)
* `plots/cbs_tcan1_diurnal.png` - mean diurnal cycle of the free layer air
  temperature, with the canyon air without tau (`T_CAN0`), the tau relaxed canyon
  air and the forcing-level temperature
* `plots/cbs_humidity_diurnal.png` - mean diurnal cycle of the canyon humidity
* `plots/cbs_htown_diurnal.png` - mean diurnal cycle of the town sensible heat
  flux (the main effect of the cbs scheme)
* `plots/cbs_letown_diurnal.png` - mean diurnal cycle of the town latent heat flux
* `plots/cbs_hroad_diurnal.png` - mean diurnal cycle of the actual road sensible
  heat flux: reference versus cbs scheme
* `plots/cbs_hroad_components_diurnal.png` - cbs run: actual road sensible heat
  flux and its potential components (tau = 1 and tau = 0)
* `plots/cbs_lroad_diurnal.png` - mean diurnal cycle of the actual road latent
  heat flux
* `plots/cbs_tcanyon_scatter.png` - canyon temperature: cbs scheme versus reference
* `plots/cbs_hroad_scatter.png` - road sensible heat flux: cbs scheme versus reference

## Re-running

```
python python_tests/compare_cbs_scheme.py             # missing cases + figures
python python_tests/compare_cbs_scheme.py --force     # re-run everything
python python_tests/compare_cbs_scheme.py --skip-run  # figures and statistics only
```
"""
    (out_root / 'README.md').write_text(txt, encoding='utf-8')


def _read_text(path: Path):
    """Content of a text file, or None if it does not exist."""
    return path.read_text(encoding='utf-8', errors='ignore') if path.is_file() else None


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description='cbs scheme of the TEB-Ru road fluxes: reference versus cbs run')
    ap.add_argument('--work-dir', default=DEFAULT_WORK_DIR,
                    help='working directory of run_on_windows.ipynb (default: %(default)s)')
    ap.add_argument('--site', default='Moscow', help='site name (default: %(default)s)')
    ap.add_argument('--base-namelist', default=None,
                    help='model parameters namelist to start from '
                         '(default: <site>/params_CTRL.nml, else <repo>/namelist/namelist.nml)')
    ap.add_argument('--forcing-nml', default=None,
                    help='forcing namelist (default: <site>/forcing_ERA5/namelist_forcing.nml)')
    ap.add_argument('--out-root', default=None,
                    help='directory of the experiment (default: <site>/compare_cbs_scheme)')
    ap.add_argument('--exe', default=None,
                    help='model executable (default: <repo>/build/TEB_offline.exe)')
    ap.add_argument('--only', default=None, help='comma separated list of case names')
    ap.add_argument('--skip-run', action='store_true',
                    help='do not run the model, only (re)build statistics and figures')
    ap.add_argument('--force', action='store_true',
                    help='run the cases even if their output already exists')
    ap.add_argument('--list', action='store_true', help='list the cases and exit')
    ap.add_argument('--no-cbs', action='store_true',
                    help='run only the reference cases (cbs scheme off)')
    ap.add_argument('--no-garden', action='store_true',
                    help='do not activate the garden')
    ap.add_argument('--ahf-traffic', type=float, default=0.0,
                    help='annual mean anthropogenic heat flux due to traffic '
                         '(namelist ahf_traffic, W/m2; default: %(default)s)')
    ap.add_argument('--no-waste', action='store_true',
                    help='control configuration: BEM active, but without HVAC '
                         'system and without infiltration/ventilation, so that '
                         'the waste heat of the buildings (H_WASTE) vanishes')
    ap.add_argument('--fr-garden', type=float, default=0.2,
                    help='garden area fraction when the garden is activated '
                         '(default: %(default)s)')
    ap.add_argument('--tau-hw-thresh', type=float, default=TAU_THRESH_DEFAULT,
                    help='H/W giving tau = 0.5 (default: %(default)s)')
    ap.add_argument('--tau-hw-width', type=float, default=TAU_WIDTH_DEFAULT,
                    help='width of the tanh relaxation of tau (default: %(default)s)')
    ap.add_argument('--days', type=float, default=2.0,
                    help='length (days) of the time series shown (default: %(default)s)')
    args = ap.parse_args(argv)

    work = Path(args.work_dir)
    base = (Path(args.base_namelist) if args.base_namelist
            else work / args.site / 'params_CTRL.nml')
    if not base.is_file():
        base = MODEL_DIR / 'namelist' / 'namelist.nml'
    forcing_nml = (Path(args.forcing_nml) if args.forcing_nml
                   else work / args.site / 'forcing_ERA5' / 'namelist_forcing.nml')
    out_root = (Path(args.out_root) if args.out_root
                else work / args.site / 'compare_cbs_scheme')
    exe = Path(args.exe) if args.exe else MODEL_DIR / 'build' / 'TEB_offline.exe'
    garden = not args.no_garden
    use_cbs = not args.no_cbs
    waste = not args.no_waste
    # BEM option of the base configuration (the cbs scheme is evaluated with it)
    try:
        bem = str(f90nml.read(str(base))['tebparam']['teb_itype_bem']).strip()
    except Exception:                                     # noqa: BLE001
        bem = 'unknown'
    #: cases of the experiment that actually have an output: a partial run (e.g.
    #: with --only) produces statistics and figures for the available cases only
    info, tau_vals = {}, {}

    all_cases = cases(use_cbs)
    if args.list:
        for case, lcz_tag, wind_type, tau in all_cases:
            hw = float(LCZ[lcz_tag]['h2w'])
            tv = tau_of(hw, args.tau_hw_thresh, args.tau_hw_width)
            print(f'{case:<18} {LCZ[lcz_tag]["label"]:<44} teb_itype_wind={wind_type} '
                  f'H/W={hw:g} tau={tv:.3f} lcbs_scheme={tau}')
        return 0

    if args.only:
        wanted = {s.strip() for s in args.only.split(',') if s.strip()}
        unknown = wanted - {c[0] for c in all_cases}
        if unknown:
            print('WARNING: unknown cases ignored: ' + ', '.join(sorted(unknown)))
        all_cases = [c for c in all_cases if c[0] in wanted]

    for path, what in ((exe, 'model executable'), (forcing_nml, 'forcing namelist'),
                       (base, 'base namelist')):
        if not path.exists():
            print(f'ERROR: {what} not found: {path}')
            return 2

    print('==================================================================')
    print('TEB-Ru cbs scheme of the road fluxes: reference versus cbs run')
    print('  model          :', exe)
    print('  forcing nml    :', forcing_nml)
    print('  base nml       :', base)
    print('  output root    :', out_root)
    print('  cases          :', len(all_cases))
    print('  tau parameters : teb_tau_hw_thresh =', args.tau_hw_thresh,
          ', teb_tau_hw_width =', args.tau_hw_width)
    print('  z0, zd         :', Z0_DEFAULT, ',', ZD_DEFAULT, '(defaults)')
    print('  BEM            :', bem, '(base namelist teb_itype_bem)')
    print('  AHF traffic    :', args.ahf_traffic, 'W/m2 (namelist ahf_traffic)')
    print('  BEM waste heat :', 'on' if waste else 'OFF (control configuration)')
    print('==================================================================')

    for case, lcz_tag, wind_type, tau in all_cases:
        nml_path = out_root / 'namelists' / f'{case}.nml'
        out_dir = out_root / f'output_{case}'
        log_file = out_root / 'logs' / f'{case}.log'
        previous = _read_text(nml_path)
        build_namelist(base, lcz_tag, wind_type, nml_path, garden, args.fr_garden,
                       tau, args.tau_hw_thresh, args.tau_hw_width,
                       args.ahf_traffic, waste)
        unchanged = previous == _read_text(nml_path)
        done = (out_dir / 'TEB_output.csv').is_file()
        if args.skip_run or (done and unchanged and not args.force):
            print(f'  [skip] {case}')
            continue
        if done and not unchanged:
            print(f'  [stale] {case}  (namelist changed, re-running)')
        rc = run_case(exe, forcing_nml, nml_path, out_dir, log_file)
        print(f'  [run ] {case}  (return code {rc})')

    for case, case_cbs, lcz_tag, wind_type in pairs(use_cbs):
        if not (out_root / f'output_{case}' / 'TEB_output.csv').is_file():
            print(f'  [none] {case}  (no output: statistics and figures skipped)')
            continue
        info[case] = (lcz_tag, wind_type)
        tau_vals[case] = tau_of(float(LCZ[lcz_tag]['h2w']),
                                args.tau_hw_thresh, args.tau_hw_width)

    ref_data, run_data, rows = {}, {}, []
    for case, case_cbs, lcz_tag, wind_type in pairs(use_cbs):
        if case not in info:
            continue
        ref = read_case(out_root / f'output_{case}')
        ref_data[case] = ref
        if case_cbs is None:
            continue
        if not (out_root / f'output_{case_cbs}' / 'TEB_output.csv').is_file():
            print(f'  [none] {case_cbs}  (no output: statistics and figures skipped)')
            continue
        run = read_case(out_root / f'output_{case_cbs}')
        run_data[case] = run
        rows.extend(case_statistics(case, ref, run, tau_vals[case]))

    out_root.mkdir(parents=True, exist_ok=True)
    stats_csv = out_root / 'summary_cbs_scheme.csv'
    stats = pd.DataFrame(rows)
    stats.to_csv(stats_csv, index=False, float_format='%.8f')

    if run_data:
        plots = out_root / 'plots'
        plots.mkdir(parents=True, exist_ok=True)
        for name, fname, ylabel in TIMESERIES:
            plot_timeseries(ref_data, run_data, info, tau_vals, name, ylabel,
                            args.days, plots / fname,
                            extra=EXTRA.get(name, ()))
        for name, fname, ylabel in DIURNAL:
            plot_diurnal(ref_data, run_data, info, tau_vals, name, ylabel,
                         plots / fname, extra=EXTRA.get(name, ()))
        plot_diurnal(ref_data, run_data, info, tau_vals, 'H_ROAD',
                     'H road (W/m2)',
                     plots / 'cbs_hroad_components_diurnal.png',
                     ref_line=False, run_only=ROAD_COMPONENTS)
        plot_scatter(ref_data, run_data, info, 'T_CANYON',
                     plots / 'cbs_tcanyon_scatter.png')
        plot_scatter(ref_data, run_data, info, 'H_ROAD',
                     plots / 'cbs_hroad_scatter.png')
    write_readme(out_root, base, forcing_nml, info, args.tau_hw_thresh,
                 args.tau_hw_width, args.days, garden, args.fr_garden,
                 args.ahf_traffic, waste, bem)

    pd.set_option('display.width', 200)
    if run_data:
        print('\nEffect of the cbs scheme (cbs run minus reference):')
        for name in ('T_CANYON', 'T_CAN0', 'T_CAN1', 'Q_CANYON', 'H_ROAD', 'LE_ROAD',
                     'H_TOWN', 'LE_TOWN'):
            sub = stats[stats.variable == name]
            print(f'\n{name} ({CMP[name][0]}, {CMP[name][1]}):')
            print(sub.set_index('case')[['tau', 'mean_ref', 'mean_cbs',
                                         'mean_diff', 'min_diff', 'max_diff']]
                  .round(4).to_string())
    else:
        print('\nNo cbs runs: only the reference cases were simulated (--no-cbs)')

    print('\nStatistics :', stats_csv)
    print('Data kept  :', out_root)
    return 0


if __name__ == '__main__':
    sys.exit(main())


