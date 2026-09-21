#!/usr/bin/env python
"""
Comparison of the TEB-Ru surface/atmosphere exchange coefficients.

Purpose
-------
Charts comparing the heat transfer coefficients computed by URBAN_DRAG for the
exchange of the road and of the garden surfaces with the air of the canyon

    CH_ROAD_CAN   (PCH_ROAD_CAN)     CH_GARDEN_CAN   (PCH_GARDEN_CAN)

and with the air of the forcing level (the "direct to the atmosphere" diagnostic
introduced together with the road/atmosphere coefficients)

    CH_ROAD_ATM   (PCH_ROAD_ATM)     CH_GARDEN_ATM   (PCH_GARDEN_ATM)

The corresponding diagnostic turbulent heat fluxes of the road, derived from the
road surface temperature of the energy-budget solve and from the road/canyon and
road/atmosphere conductances (same surface temperature and same water
limitation, only the reference air is changed),

    H_ROAD_CAN / LE_ROAD_CAN   (road with the canyon air)
    H_ROAD_ATM / LE_ROAD_ATM   (road directly with the air of the forcing level)

are compared as well: time series, mean diurnal cycle and the ATM versus CAN
scatter, plus their correlation and RMS difference.

Experiment design
-----------------
Same forcing and building parameters as `python_tests/sensitivity_zd.py`: the Moscow
ERA5 forcing (hlev_teb = 10 m, 2022-08-01 .. 2022-09-01), the LCZ 2 and LCZ 9
morphologies and the two canyon-wind schemes (teb_itype_wind = 0 and 1).

The urban roughness length and the displacement height keep their DEFAULT
prescriptions: urb_z0_town = '0.1H' and urb_zd_town = 'H/3' (values of the base
namelist); z0 and zd are not varied in this experiment.

The garden model is activated (teb_lgarden = .TRUE. and fr_garden > 0, see
--fr-garden), so that the garden fluxes are included in the town energy budget.
The garden exchange coefficients (with the canyon air and with the air of the
forcing level) are computed only when the garden is provided by an EXTERNAL
model (teb_type_garden = 'EXT'); with the internal proxy-SVAT garden
PCH_GARDEN_CAN is reported as 0 (set in TEB_GARDEN) and the garden/atmosphere
coefficients stay undefined (XUNDEF, reported as not available).

Files (kept, not deleted; use --force to re-run a simulation):
  <out_root>/namelists/<case>.nml      namelist of every case
  <out_root>/output_<case>/            model output (TEB_output.csv)
  <out_root>/logs/<case>.log           model log (effective z0 and zd)
  <out_root>/summary_exch_coef.csv     statistics of the coefficients per case
  <out_root>/plots/ch_*.png            comparison figures (coefficients)
  <out_root>/plots/flux_*.png          comparison figures (road heat fluxes)
  <out_root>/README.md                 description of the experiment

Usage
-----
    python python_tests/compare_exch_coef.py                  # run everything
    python python_tests/compare_exch_coef.py --list           # list the cases
    python python_tests/compare_exch_coef.py --skip-run       # statistics/plots only
    python python_tests/compare_exch_coef.py --force          # re-run existing cases
    python python_tests/compare_exch_coef.py --no-garden      # garden off (road only)
    python python_tests/compare_exch_coef.py --days 3         # length of the series
"""
from __future__ import annotations

import argparse
import os
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

# the experiment reuses the site/forcing/base-namelist logic of sensitivity_zd.py
from sensitivity_zd import (                                          # noqa: E402
    LCZ, WIND_TYPES, DEFAULT_WORK_DIR,
    run_case, series, stats_of, banner_values, read_forcing,
)

#: values >= XUNDEF are undefined in TEB-Ru (MODD_SURF_PAR:XUNDEF = 1.0e20)
XUNDEF = 1.0e19

#: the coefficients compared here: column -> (label, colour)
COEF = {
    'PCH_ROAD_CAN':    ('CH road / canyon',       '#1f77b4'),
    'PCH_ROAD_ATM':    ('CH road / atmosphere',   '#d62728'),
    'PCH_GARDEN_CAN':  ('CH garden / canyon',     '#2ca02c'),
    'PCH_GARDEN_ATM':  ('CH garden / atmosphere', '#ff7f0e'),
}

#: the same surface/air pairs also provide the momentum coefficients; they are
#: reported in the summary table (not plotted) for a complete picture
COEF_EXTRA = ('PAC_ROAD_CAN', 'PCH_ROAD_CAN', 'PAC_ROAD_ATM', 'PCH_ROAD_ATM',
              'PCD_GARDEN_CAN', 'PCH_GARDEN_CAN', 'PAC_GARDEN_ATM',
              'PCD_GARDEN_ATM', 'PCH_GARDEN_ATM')

#: diagnostic turbulent heat fluxes of the road (W/m2 of road surface): column ->
#: (label, colour). They are derived from the road surface temperature of the
#: energy-budget solve and from the road/canyon and road/atmosphere conductances:
#: same surface temperature and water limitation, only the reference air
#: (canyon air vs air of the forcing level) differs.
FLUX = {
    'H_ROAD_CAN':  ('H road / canyon',       '#1f77b4'),
    'H_ROAD_ATM':  ('H road / atmosphere',   '#d62728'),
    'LE_ROAD_CAN': ('LE road / canyon',      '#2ca02c'),
    'LE_ROAD_ATM': ('LE road / atmosphere',  '#ff7f0e'),
}

#: the sensible heat flux pair, compared separately (canyon vs forcing level)
FLUX_H = ('H_ROAD_CAN', 'H_ROAD_ATM')

#: auxiliary columns of the road flux comparison: road surface temperature and
#: the air temperature of the forcing level (their difference drives H)
FLUX_AUX = ('T_ROAD1', 'Forc_TA')

#: default prescriptions of the urban roughness length and displacement height
Z0_DEFAULT = '0.1H'
ZD_DEFAULT = 'H/3'


def cases():
    """Deterministic list of (case, lcz_tag, wind_type)."""
    out = []
    for lcz_tag in LCZ:
        for wind_type, wind_tag in WIND_TYPES.items():
            out.append((f'{lcz_tag}_{wind_tag}', lcz_tag, wind_type))
    return out


def build_namelist(base_nml: Path, lcz_tag: str, wind_type: int, path: Path,
                   garden: bool, fr_garden: float) -> Path:
    """Namelist of one case: base namelist + LCZ + wind scheme + default z0/zd.

    z0 and zd keep the default prescriptions ('0.1H' and 'H/3'), so only the
    morphology, the canyon-wind scheme and the garden activation differ.
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
    """Coefficient/flux time series (and the time stamps) of one case."""
    data = {name: mask_undefined(series(out_dir, name)) for name in COEF}
    for name in COEF_EXTRA:
        data[name] = mask_undefined(series(out_dir, name))
    for name in FLUX:
        data[name] = mask_undefined(series(out_dir, name))
    for name in FLUX_AUX:
        data[name] = mask_undefined(series(out_dir, name))
    data['Forc_WIND'] = mask_undefined(series(out_dir, 'Forc_WIND'))
    csv = out_dir / 'TEB_output.csv'
    data['time'] = (pd.read_csv(csv, sep=';', usecols=['time'])['time']
                    if csv.is_file() else None)
    return data


def mean_of(x):
    """Mean of a masked series (NaN when nothing is available)."""
    if x is None or not np.any(np.isfinite(x)):
        return np.nan
    return float(np.nanmean(x))


def paired_stats(a, b):
    """Correlation coefficient and RMS difference of two masked series.

    Returns (NaN, NaN) when fewer than two pairs of valid values are available.
    """
    if a is None or b is None:
        return np.nan, np.nan
    m = np.isfinite(a) & np.isfinite(b)
    if np.sum(m) < 2:
        return np.nan, np.nan
    corr = float(np.corrcoef(a[m], b[m])[0, 1])
    rmsd = float(np.sqrt(np.mean((a[m] - b[m]) ** 2)))
    return corr, rmsd


def case_statistics(case: str, data: dict) -> list:
    """One row per coefficient/flux: statistics and the ATM/CAN comparisons."""
    rows = []
    for name, (label, _) in COEF.items():
        x = data.get(name)
        st = stats_of(None if x is None else x[np.isfinite(x)])
        rows.append(dict(case=case, coefficient=name, label=label,
                         n=st['n'], mean=st['mean'], std=st['std'],
                         p05=st['p05'], p50=st['p50'], p95=st['p95'],
                         min=st['min'], max=st['max']))
    for name, (label, _) in FLUX.items():
        x = data.get(name)
        st = stats_of(None if x is None else x[np.isfinite(x)])
        rows.append(dict(case=case, coefficient=name, label=label,
                         n=st['n'], mean=st['mean'], std=st['std'],
                         p05=st['p05'], p50=st['p50'], p95=st['p95'],
                         min=st['min'], max=st['max']))
    for surf in ('ROAD', 'GARDEN'):
        can, atm = data.get(f'PCH_{surf}_CAN'), data.get(f'PCH_{surf}_ATM')
        m_can, m_atm = mean_of(can), mean_of(atm)
        ratio = float(m_atm / m_can) if m_can and np.isfinite(m_can) and \
            np.isfinite(m_atm) else np.nan
        note = 'not computed in this run'
        if can is not None and np.any(np.isfinite(can)):
            note = 'constant (std = 0)' if not np.isfinite(np.nanstd(can)) or \
                np.nanstd(can) == 0.0 else ''
        rows.append(dict(case=case, coefficient=f'CH_{surf}_ATM_over_CAN',
                         label=f'CH {surf.lower()}, ATM/CAN',
                         n=int(np.sum(np.isfinite(can))) if can is not None else 0,
                         mean=ratio, std=np.nan, p05=np.nan, p50=np.nan,
                         p95=np.nan, min=np.nan, max=np.nan, note=note))
    for var, label in (('H', 'H road'), ('LE', 'LE road')):
        can, atm = data.get(f'{var}_ROAD_CAN'), data.get(f'{var}_ROAD_ATM')
        corr, rmsd = paired_stats(can, atm)
        if can is None or atm is None:
            n_pairs = 0
        else:
            n_pairs = int(np.sum(np.isfinite(can) & np.isfinite(atm)))
        rows.append(dict(case=case, coefficient=f'{var}_ROAD_ATM_vs_CAN',
                         label=f'{label}, ATM vs CAN', n=n_pairs,
                         mean=corr, std=np.nan, p05=np.nan, p50=np.nan,
                         p95=np.nan, min=np.nan, max=np.nan,
                         note=(f'rmsd = {rmsd:.3f} W/m2' if np.isfinite(rmsd)
                               else 'not computed in this run')))
    return rows

def _case_title(case: str, info: dict) -> str:
    """Title of a panel: case name + LCZ description."""
    lcz_tag, wind_type = info[case]
    return f'{case}\n{LCZ[lcz_tag]["label"]}, teb_itype_wind = {wind_type}'


def _grid(n: int):
    """A grid of 2 panels per row, large enough for n panels."""
    ncol = 2
    nrow = int(np.ceil(n / ncol))
    fig, axes = plt.subplots(nrow, ncol, figsize=(13.6, 3.1 * nrow), squeeze=False)
    return fig, list(axes.ravel())


def _legend_and_title(fig, axes, case_data, info):
    for ax in axes[len(case_data):]:
        ax.axis('off')


def plot_timeseries(case_data: dict, info: dict, days: float, path: Path):
    """Time series of the four coefficients for the first `days` days."""
    fig, axes = _grid(len(case_data))
    for ax, (case, data) in zip(axes, case_data.items()):
        t = data.get('time')
        nshow = int(days * 24) if t is not None else None
        x = pd.to_datetime(t[:nshow]) if t is not None else np.arange(len(data['Forc_WIND']))
        for name, (label, col) in COEF.items():
            y = data.get(name)
            if y is None or not np.any(np.isfinite(y)):
                continue
            ax.plot(x, y[:nshow], label=label, color=col, lw=1.0)
        ax.set_title(_case_title(case, info), fontsize=9)
        ax.set_ylabel('CH (m/s)')
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7)
        ax.tick_params(axis='x', labelsize=7, labelrotation=15)
    _legend_and_title(fig, axes, case_data, info)
    fig.suptitle(f'Heat transfer coefficient, first {days:g} days '
                 f'(z0 = {Z0_DEFAULT}, zd = {ZD_DEFAULT})', fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_diurnal(case_data: dict, info: dict, path: Path):
    """Mean diurnal cycle of the four coefficients (hourly means)."""
    fig, axes = _grid(len(case_data))
    for ax, (case, data) in zip(axes, case_data.items()):
        t = data.get('time')
        if t is None:
            ax.axis('off')
            continue
        hours = pd.to_datetime(t).dt.hour.to_numpy()
        xh = np.arange(24)
        for name, (label, col) in COEF.items():
            y = data.get(name)
            if y is None or not np.any(np.isfinite(y)):
                continue
            mean = np.array([np.nanmean(y[hours == h])
                             if np.any(np.isfinite(y[hours == h])) else np.nan
                             for h in xh])
            ax.plot(xh, mean, label=label, color=col, lw=1.3, marker='o', ms=3)
        ax.set_title(_case_title(case, info), fontsize=9)
        ax.set_xlabel('hour (UTC)')
        ax.set_ylabel('CH (m/s)')
        ax.set_xticks([0, 6, 12, 18, 23])
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7)
    _legend_and_title(fig, axes, case_data, info)
    fig.suptitle(f'Mean diurnal cycle of the heat transfer coefficient '
                 f'(z0 = {Z0_DEFAULT}, zd = {ZD_DEFAULT})', fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(path, dpi=150)
    plt.close(fig)

def plot_summary(case_data: dict, info: dict, stats: pd.DataFrame, path: Path):
    """Mean values of the coefficients and the ATM/CAN ratios per case."""
    cases_list = list(case_data)
    fig, axes = plt.subplots(1, 2, figsize=(14, 4.6))
    x = np.arange(len(cases_list))
    w = 0.8 / len(COEF)
    for k, (name, (label, col)) in enumerate(COEF.items()):
        sub = stats[stats.coefficient == name].set_index('case').reindex(cases_list)
        axes[0].bar(x + (k - (len(COEF) - 1) / 2) * w, sub['mean'], w,
                    yerr=sub['std'], capsize=2, label=label, color=col)
    axes[0].set_xticks(x)
    axes[0].set_xticklabels(cases_list, fontsize=8)
    axes[0].set_ylabel('CH (m/s)')
    axes[0].set_title('Mean heat transfer coefficients (bars: std)', fontsize=10)
    axes[0].grid(True, axis='y', alpha=0.3)
    axes[0].legend(fontsize=8)
    for k, (surf, col) in enumerate((('ROAD', '#9467bd'), ('GARDEN', '#8c564b'))):
        sub = stats[stats.coefficient == f'CH_{surf}_ATM_over_CAN'] \
            .set_index('case').reindex(cases_list)
        axes[1].bar(x + (k - 0.5) * 0.35, sub['mean'], 0.35, label=surf.lower(), color=col)
    axes[1].axhline(1.0, color='k', lw=0.8, ls='--')
    axes[1].set_xticks(x)
    axes[1].set_xticklabels(cases_list, fontsize=8)
    axes[1].set_ylabel('CH(ATM) / CH(CAN) (-)')
    axes[1].set_title('Ratio of the atmosphere and canyon coefficients', fontsize=10)
    axes[1].grid(True, axis='y', alpha=0.3)
    axes[1].legend(fontsize=8)
    fig.suptitle('Exchange coefficients with the canyon air and with the air of the '
                 f'forcing level (z0 = {Z0_DEFAULT}, zd = {ZD_DEFAULT})', fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.93])
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_vs_wind(case_data: dict, info: dict, path: Path):
    """CH versus the forcing wind speed: road (left) and garden (right)."""
    fig, axes = plt.subplots(1, 2, figsize=(14, 4.6))
    for ax, surf in zip(axes, ('ROAD', 'GARDEN')):
        for case, data in case_data.items():
            v = data.get('Forc_WIND')
            if v is None:
                continue
            for kind, marker in (('CAN', 'o'), ('ATM', '^')):
                y = data.get(f'PCH_{surf}_{kind}')
                if y is None or not np.any(np.isfinite(y)):
                    continue
                ax.scatter(v, y, s=6, marker=marker, alpha=0.5, label=f'{case} {kind}')
        ax.set_xlabel('forcing wind speed (m/s)')
        ax.set_ylabel(f'CH {surf.lower()} (m/s)')
        ax.set_title(f'{surf.lower()} surface: canyon air vs forcing level air',
                     fontsize=10)
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7, ncol=2)
    fig.suptitle('Heat transfer coefficient versus the wind speed at the forcing level',
                 fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.93])
    fig.savefig(path, dpi=150)
    plt.close(fig)

def plot_fluxes_timeseries(case_data: dict, info: dict, days: float, path: Path):
    """Time series of the road heat fluxes (canyon air vs forcing level air)."""
    fig, axes = _grid(len(case_data))
    for ax, (case, data) in zip(axes, case_data.items()):
        t = data.get('time')
        nshow = int(days * 24) if t is not None else None
        x = (pd.to_datetime(t[:nshow]) if t is not None
             else np.arange(len(data.get('H_ROAD_CAN', []))))
        for name, (label, col) in FLUX.items():
            y = data.get(name)
            if y is None or not np.any(np.isfinite(y)):
                continue
            ax.plot(x, y[:nshow], label=label, color=col, lw=1.0)
        ax.axhline(0.0, color='k', lw=0.6)
        ax.set_title(_case_title(case, info), fontsize=9)
        ax.set_ylabel('flux (W/m2)')
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7)
        ax.tick_params(axis='x', labelsize=7, labelrotation=15)
    _legend_and_title(fig, axes, case_data, info)
    fig.suptitle(f'Road turbulent heat fluxes, first {days:g} days '
                 f'(per m2 of road surface)', fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_fluxes_diurnal(case_data: dict, info: dict, path: Path):
    """Mean diurnal cycle of the road heat fluxes (hourly means)."""
    fig, axes = _grid(len(case_data))
    for ax, (case, data) in zip(axes, case_data.items()):
        t = data.get('time')
        if t is None:
            ax.axis('off')
            continue
        hours = pd.to_datetime(t).dt.hour.to_numpy()
        xh = np.arange(24)
        for name, (label, col) in FLUX.items():
            y = data.get(name)
            if y is None or not np.any(np.isfinite(y)):
                continue
            mean = np.array([np.nanmean(y[hours == h])
                             if np.any(np.isfinite(y[hours == h])) else np.nan
                             for h in xh])
            ax.plot(xh, mean, label=label, color=col, lw=1.3, marker='o', ms=3)
        ax.axhline(0.0, color='k', lw=0.6)
        ax.set_title(_case_title(case, info), fontsize=9)
        ax.set_xlabel('hour (UTC)')
        ax.set_ylabel('flux (W/m2)')
        ax.set_xticks([0, 6, 12, 18, 23])
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7)
    _legend_and_title(fig, axes, case_data, info)
    fig.suptitle('Mean diurnal cycle of the road turbulent heat fluxes '
                 '(per m2 of road surface)', fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_fluxes_scatter(case_data: dict, info: dict, path: Path):
    """Road flux with the air of the forcing level versus with the canyon air."""
    fig, axes = plt.subplots(1, 2, figsize=(12.6, 5.0))
    for ax, var in zip(axes, ('H', 'LE')):
        lim = 0.0
        for case, data in case_data.items():
            can, atm = data.get(f'{var}_ROAD_CAN'), data.get(f'{var}_ROAD_ATM')
            if can is None or atm is None:
                continue
            m = np.isfinite(can) & np.isfinite(atm)
            if not np.any(m):
                continue
            ax.scatter(can[m], atm[m], s=6, alpha=0.4, label=case)
            lim = max(lim, float(np.nanmax(np.abs(can[m]))),
                      float(np.nanmax(np.abs(atm[m]))))
        if lim > 0.0:
            ax.plot([-lim, lim], [-lim, lim], color='k', lw=0.8, ls='--',
                    label='1:1')
        ax.set_xlabel(f'{var}_ROAD_CAN (W/m2)')
        ax.set_ylabel(f'{var}_ROAD_ATM (W/m2)')
        ax.set_title(f'{var}: road with the forcing level air vs canyon air',
                     fontsize=10)
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7)
    fig.suptitle('Road heat fluxes: direct to the forcing level versus through '
                 'the canyon (per m2 of road surface)', fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.93])
    fig.savefig(path, dpi=150)
    plt.close(fig)


def write_readme(out_root: Path, base: Path, forcing_nml: Path, stats: pd.DataFrame,
                 info: dict, days: float, garden: bool, fr_garden: float):
    """Describe the experiment next to the data."""
    lines = [f'| `{c}` | {LCZ[info[c][0]]["label"]} | {info[c][1]} |' for c in info]
    txt = f"""# Comparison of the surface/atmosphere exchange coefficients (TEB-Ru)

Generated by `python_tests/compare_exch_coef.py`. The simulation data are kept here.

## Configuration

* Forcing: `{forcing_nml}`
* Base model namelist: `{base}`
* Urban roughness length and displacement height: **defaults**
  (`urb_z0_town = {Z0_DEFAULT}`, `urb_zd_town = {ZD_DEFAULT}`) - not varied
* Urban morphology and canyon-wind scheme: as in `python_tests/sensitivity_zd.py`
* Garden: {'activated' if garden else 'NOT activated'} (`teb_lgarden = {str(garden).upper()}`,
  `fr_garden = {fr_garden if garden else 0.0:g}`) - the garden fluxes enter the
  town energy budget; the garden exchange coefficients are computed only with
  the external garden model (`teb_type_garden = 'EXT'`)

## Cases

| case | morphology | teb_itype_wind |
| --- | --- | --- |
""" + '\n'.join(lines) + f"""

## Coefficient columns compared

| column | meaning |
| --- | --- |
| `PCH_ROAD_CAN` | heat transfer coefficient, road surface <-> canyon air (URBAN_DRAG section 8.2) |
| `PCH_ROAD_ATM` | heat transfer coefficient, road surface <-> air of the forcing level (section 8.3) |
| `PCH_GARDEN_CAN` | heat transfer coefficient, garden surface <-> canyon air (external garden model only) |
| `PCH_GARDEN_ATM` | heat transfer coefficient, garden surface <-> air of the forcing level (external garden model only) |

## Road heat flux columns compared

| column | meaning |
| --- | --- |
| `H_ROAD_CAN` | sensible heat flux, road <-> canyon air (W/m2 of road, road energy budget) |
| `LE_ROAD_CAN` | latent heat flux, road <-> canyon air (W/m2 of road) |
| `H_ROAD_ATM` | sensible heat flux, road <-> air of the forcing level, diagnostic (W/m2 of road) |
| `LE_ROAD_ATM` | latent heat flux, road <-> air of the forcing level, diagnostic (W/m2 of road) |

The `*_ATM` fluxes are derived in `TEB` from the road surface temperature
resulting from the energy-budget solve (`T%XT_ROAD(:,1)`, see
`ROAD_LAYER_E_BUDGET`) and from the road/atmosphere conductances: same surface
temperature, same water limitation (`PDELT_ROAD`, available water) and same
`cp/Exns` convention as the road/canyon fluxes; only the reference air - and
hence its conductance `PAC_ROAD_ATM` - is changed. They are diagnostics only and
do not feed back on the road energy budget.

Values equal to `1e20` (`XUNDEF`) mean "not computed" (e.g. the garden
coefficients when the garden is switched off or provided by the internal
proxy-SVAT model); they are masked in the figures and the statistics. The same
surface/air pairs also produce the momentum coefficients
`PAC/PCD/PCDN/PRI/ZZ0H_*`, which are present in `TEB_output.csv`.

Note on the garden coefficients: the canyon and forcing-level (TERRA-type)
exchange coefficients of the garden are computed in `URBAN_DRAG` only when the
garden is provided by an external model (`teb_type_garden = 'EXT'`), because
only then `PTS_GARDEN`/`PQS_GARDEN` describe a real garden surface state. With
the **internal** garden model (`teb_lgarden = .TRUE.`,
`teb_type_garden = 'PROXY_OLD'` or `'PROXY_NEW'`) the canyon exchange coefficient
of the garden is
set to zero in `TEB_GARDEN` right after the garden model call
(`ZQV_GD = 0; PCH_GD = 0; PCD_GD = 0`), because the proxy-SVAT garden provides
its own fluxes, and the garden/atmosphere coefficients are left undefined
(`XUNDEF`): the placeholder surface state of the internal garden (surface
temperature = canyon air temperature, surface humidity = 0) would make them
meaningless. Constant-zero series are reported as `constant (std = 0)` in
`summary_exch_coef.csv` and drawn as a flat line at zero; the undefined ones
are reported as not available.

## Files

* `namelists/<case>.nml` - namelist of every case
* `output_<case>/TEB_output.csv` - full model output
* `logs/<case>.log` - model log (effective z0 and zd)
* `summary_exch_coef.csv` - statistics of every coefficient per case
* `plots/ch_timeseries.png` - time series, first {days:g} days
* `plots/ch_diurnal.png` - mean diurnal cycle
* `plots/ch_summary.png` - means and the ATM/CAN ratios
* `plots/ch_vs_wind.png` - coefficients versus the forcing wind speed
* `plots/flux_road_timeseries.png` - road fluxes, first {days:g} days
* `plots/flux_road_diurnal.png` - mean diurnal cycle of the road fluxes
* `plots/flux_road_scatter.png` - road fluxes with the forcing level air vs canyon air

## Re-running

```
python python_tests/compare_exch_coef.py             # run missing cases + figures
python python_tests/compare_exch_coef.py --force     # re-run everything
python python_tests/compare_exch_coef.py --skip-run  # figures and statistics only
```
"""
    (out_root / 'README.md').write_text(txt, encoding='utf-8')

def _read_text(path: Path):
    """Content of a text file, or None if it does not exist."""
    return path.read_text(encoding='utf-8', errors='ignore') if path.is_file() else None


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description='CH_ROAD_CAN / CH_ROAD_ATM / CH_GARDEN_CAN / CH_GARDEN_ATM (TEB-Ru)')
    ap.add_argument('--work-dir', default=DEFAULT_WORK_DIR,
                    help='working directory of run_on_windows.ipynb (default: %(default)s)')
    ap.add_argument('--site', default='Moscow', help='site name (default: %(default)s)')
    ap.add_argument('--base-namelist', default=None,
                    help='model parameters namelist to start from '
                         '(default: <site>/params_CTRL.nml, else <repo>/namelist/namelist.nml)')
    ap.add_argument('--forcing-nml', default=None,
                    help='forcing namelist (default: <site>/forcing_ERA5/namelist_forcing.nml)')
    ap.add_argument('--out-root', default=None,
                    help='directory of the experiment (default: <site>/compare_exch_coef)')
    ap.add_argument('--exe', default=None,
                    help='model executable (default: <repo>/build/TEB_offline.exe)')
    ap.add_argument('--only', default=None, help='comma separated list of case names')
    ap.add_argument('--skip-run', action='store_true',
                    help='do not run the model, only (re)build statistics and figures')
    ap.add_argument('--force', action='store_true',
                    help='run the cases even if their output already exists')
    ap.add_argument('--list', action='store_true', help='list the cases and exit')
    ap.add_argument('--no-garden', action='store_true',
                    help='do not activate the garden (then only the road coefficients '
                         'are available)')
    ap.add_argument('--fr-garden', type=float, default=0.2,
                    help='garden area fraction when the garden is activated '
                         '(default: %(default)s)')
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
    out_root = Path(args.out_root) if args.out_root else work / args.site / 'compare_exch_coef'
    exe = Path(args.exe) if args.exe else MODEL_DIR / 'build' / 'TEB_offline.exe'
    garden = not args.no_garden

    all_cases = cases()
    if args.list:
        for case, lcz_tag, wind_type in all_cases:
            print(f'{case:<14} {LCZ[lcz_tag]["label"]:<44} teb_itype_wind={wind_type}')
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
    print('TEB-Ru exchange coefficients: canyon air vs air of the forcing level')
    print('  model          :', exe)
    print('  forcing nml    :', forcing_nml)
    print('  base nml       :', base)
    print('  output root    :', out_root)
    print('  cases          :', len(all_cases), '(garden:',
          f'on, fr_garden={args.fr_garden:g})' if garden else 'off)')
    print('  z0, zd         :', Z0_DEFAULT, ',', ZD_DEFAULT, '(defaults)')
    print('==================================================================')

    info = {case: (lcz_tag, wind_type) for case, lcz_tag, wind_type in all_cases}
    for case, lcz_tag, wind_type in all_cases:
        nml_path = out_root / 'namelists' / f'{case}.nml'
        out_dir = out_root / f'output_{case}'
        log_file = out_root / 'logs' / f'{case}.log'
        previous = _read_text(nml_path)
        build_namelist(base, lcz_tag, wind_type, nml_path, garden, args.fr_garden)
        unchanged = previous == _read_text(nml_path)
        done = ((out_dir / 'TEB_output.csv').is_file()
                or (out_dir / 'U_CANYON.txt').is_file())
        if args.skip_run or (done and unchanged and not args.force):
            print(f'  [skip] {case}')
            continue
        if done and not unchanged:
            print(f'  [stale] {case}  (namelist changed, re-running)')
        rc = run_case(exe, forcing_nml, nml_path, out_dir, log_file)
        print(f'  [run ] {case}  (return code {rc})')

    case_data, rows = {}, []
    for case in info:
        data = read_case(out_root / f'output_{case}')
        case_data[case] = data
        rows.extend(case_statistics(case, data))
    stats = pd.DataFrame(rows)

    out_root.mkdir(parents=True, exist_ok=True)
    stats_csv = out_root / 'summary_exch_coef.csv'
    stats.to_csv(stats_csv, index=False, float_format='%.8f')

    plots = out_root / 'plots'
    plots.mkdir(parents=True, exist_ok=True)
    plot_timeseries(case_data, info, args.days, plots / 'ch_timeseries.png')
    plot_diurnal(case_data, info, plots / 'ch_diurnal.png')
    plot_summary(case_data, info, stats, plots / 'ch_summary.png')
    plot_vs_wind(case_data, info, plots / 'ch_vs_wind.png')
    plot_fluxes_timeseries(case_data, info, args.days,
                           plots / 'flux_road_timeseries.png')
    plot_fluxes_diurnal(case_data, info, plots / 'flux_road_diurnal.png')
    plot_fluxes_scatter(case_data, info, plots / 'flux_road_scatter.png')
    write_readme(out_root, base, forcing_nml, stats, info, args.days, garden,
                 args.fr_garden)

    pd.set_option('display.width', 200)
    for name, (label, _) in COEF.items():
        sub = stats[stats.coefficient == name]
        if not np.any(np.isfinite(sub['mean'].to_numpy(dtype=float))):
            print(f'\nMean {label} (m/s): not available in these runs')
            continue
        print(f'\nMean {label} (m/s):')
        print(sub.set_index('case')['mean'].round(6).to_string())
    print('\nCH(ATM) / CH(CAN):')
    print(stats[stats.coefficient.str.contains('over_CAN')]
          .pivot_table(index='case', columns='coefficient', values='mean')
          .round(3).to_string())

    for name, (label, _) in FLUX.items():
        sub = stats[stats.coefficient == name]
        if not np.any(np.isfinite(sub['mean'].to_numpy(dtype=float))):
            print(f'\nMean {label} (W/m2): not available in these runs')
            continue
        print(f'\nMean {label} (W/m2):')
        print(sub.set_index('case')['mean'].round(2).to_string())
    print('\nRoad heat fluxes, ATM vs CAN (correlation, rmsd):')
    print(stats[stats.coefficient.str.contains('ROAD_ATM_vs_CAN')]
          .loc[:, ['case', 'coefficient', 'mean', 'note']]
          .set_index(['case', 'coefficient']).round(3).to_string())

    print('\nStatistics :', stats_csv)
    print('Plots      :', plots)
    print('Data kept  :', out_root)
    return 0


if __name__ == '__main__':
    sys.exit(main())






