#!/usr/bin/env python
"""
External greenroof emulator (``PCD_GREENROOF``) versus the internal greenroof.

Purpose
-------
The greenroof of TEB-MSU can be provided by an external model through the
``teb_type_greenroof = 'EXT'`` / ``'EXT_NEU'`` interface: the driver owns the
greenroof surface temperature and fluxes and TEB reads them back at every model
sub-step (see ``run_teb_offline.F90`` and ``TEB_MSU_garden_diagnostic_scheme.md``).

This script validates that interface by replacing the external model with the
emulator ``PCD_GREENROOF`` of the offline driver, i.e. with the *internal*
diagnostic greenroof of ``src/src_proxi_SVAT/greenroof.F90`` seen from outside
the model. It runs every configuration of

    PROXY_NEW  internal diagnostic greenroof                  (reference)
    EXT_NEU    external greenroof, NEUTRAL coefficients        (= the emulator)
    EXT        external greenroof, full URBAN_EXCH_COEF set    (Richardson number)

and checks the identities that the coupling must satisfy. The greenroof is a
*roof* surface: it exchanges with the air of the forcing level only, so there is
a single exchange path - no canyon branch and no tau split, unlike the garden.

Checks (written to ``checks_greenroof_emu.csv``, one row per check)
------------------------------------------------------------------
1. **Energy balance of the emulated surface** (external modes)

       EMU_GR_RN = EMU_GR_H + EMU_GR_LE                            (G = 0)

2. **Coupling lag** (external modes): the state and the fluxes prescribed to TEB
   by the emulator at one sub-step are the ones TEB uses at the next one, so the
   model column of a row must equal the emulator diagnostic of the previous row:

       TS_GREENROOF[k]   = EMU_GR_TS[k-1]
       H_GREENROOF[k]    = EMU_GR_H[k-1]
       LE_GREENROOF[k]   = EMU_GR_LE[k-1]
       EVAP_GREENROOF[k] = EMU_GR_EVAP[k-1]

   The runs are made with the model time step written as the ``forc_step`` of the
   case forcing namelist, so that one output row is exactly one model sub-step
   and the lag is one row (with a smaller time step there are several sub-steps
   per row and the relation cannot be seen in the CSV; see ``--dt``).

3. **Coefficients exported by TEB** (external modes): the coefficients the driver
   computes for the emulator must be the ones TEB describes as the greenroof
   coefficients:

       EMU_GR_CD = PCD_GREENROOF_ATM,  EMU_GR_CH = PCH_GREENROOF_ATM,
       EMU_GR_CA = PAC_GREENROOF_ATM

   This holds exactly in ``EXT_NEU`` (both are the neutral coefficients of the
   internal greenroof, ``GARDEN_PCD_NEUTRAL`` / ``GARDEN_PCH_NEUTRAL`` /
   ``GARDEN_CAH_NEUTRAL``). In ``EXT`` the exported coefficients carry the
   Richardson-number correction of ``URBAN_EXCH_COEF`` while the emulator keeps
   its neutral ones, so the difference measures the stability effect: the check
   reports it without failing.

4. **Spin-up of the first sub-step** (external modes): the coupling starts from
   ``Ts = air temperature`` (the temperature of the start of the run) and zero
   fluxes, so row 0 must have ``H_GREENROOF = LE_GREENROOF = 0`` (the surface
   temperature of that row is reported, not tested: it is the air temperature of
   the start of the run, whereas ``Forc_TA`` is the forcing of the first output
   row, stamped start + forc_step).

5. **Emulator versus internal model** (across cases): the emulator diagnostics
   must reproduce the internal greenroof output of the reference run bit for
   bit, on the same output row (``EMU_GR_TS`` = ``TS_GREENROOF`` of PROXY_NEW,
   ...), the only difference being the first row, which is the spin-up of the
   coupling. The prescribed columns of the external run are the same series
   shifted by one row.

6. **EXT versus EXT_NEU**: the exported coefficients differ (the Richardson
   number correction) whereas the emulated surface state and fluxes are
   identical, because the emulator always describes the neutral exchange - this
   is what the ``EXT``/``EXT_NEU`` switch is meant to expose.

Experiment design
-----------------
Same site and morphologies as ``python_tests/sensitivity_zd.py``: the Moscow ERA5
forcing, the LCZ 2 (compact mid-rise) and LCZ 9 (sparse low-rise) buildings. The
garden is switched off in every run so that the greenroof diagnostics are not
mixed with the garden ones, and the solar panels are left off (with a panel
fraction the roof receives an extra long-wave term, which the emulator of the
driver does not reproduce).

Files (kept; use --force to re-run a case)
------------------------------------------
  <out-root>/namelists/<case>.nml          namelist of every case
  <out-root>/forcing/<case>.nml            forcing namelist of every case
  <out-root>/output_<case>/                model output (TEB_output.csv)
  <out-root>/logs/<case>.log               model log
  <out-root>/summary_greenroof_emu.csv     statistics per case
  <out-root>/checks_greenroof_emu.csv      the checks above (one row per check)
  <out-root>/plots/*.png                   comparison figures
  <out-root>/README.md                     description and results

Usage
-----
    python python_tests/greenroof_emu_compare.py
    python python_tests/greenroof_emu_compare.py --list
    python python_tests/greenroof_emu_compare.py --only LCZ2_EXT_NEU
    python python_tests/greenroof_emu_compare.py --skip-run      # post-process only
    python python_tests/greenroof_emu_compare.py --force         # re-run existing
    python python_tests/greenroof_emu_compare.py --days 1 --fr-greenroof 0.3
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
    LCZ, DEFAULT_WORK_DIR, run_case, series,
)

#: values >= XUNDEF are undefined in TEB-MSU (MODD_SURF_PAR:XUNDEF = 1.0e20)
XUNDEF = 1.0e19

#: greenroof modes: tag -> (teb_type_greenroof, description)
MODES = {
    'PROXY_NEW': ('PROXY_NEW', 'internal diagnostic greenroof (reference)'),
    'EXT_NEU':   ('EXT_NEU',   'external greenroof, neutral coefficients (emulator)'),
    'EXT':       ('EXT',       'external greenroof, URBAN_EXCH_COEF coefficients'),
}

#: diagnostics written by the emulator PCD_GREENROOF (external modes only)
EMU_COLS = ('EMU_GR_CD', 'EMU_GR_CH', 'EMU_GR_CA', 'EMU_GR_V', 'EMU_GR_T',
            'EMU_GR_Q', 'EMU_GR_PSW', 'EMU_GR_PLW', 'EMU_GR_TS', 'EMU_GR_RN',
            'EMU_GR_H', 'EMU_GR_LE', 'EMU_GR_EVAP')

#: greenroof diagnostics of the model (per m2 of greenroof)
GR_COLS = ('TS_GREENROOF', 'RN_GREENROOF', 'H_GREENROOF', 'LE_GREENROOF',
           'EVAP_GREENROOF', 'QSAT_GREENROOF', 'PHU_GREENROOF',
           'PAC_GREENROOF_ATM', 'PCD_GREENROOF_ATM', 'PCDN_GREENROOF_ATM',
           'PCH_GREENROOF_ATM', 'PRI_GREENROOF_ATM', 'ZZ0H_GREENROOF_ATM')

#: (emulator diagnostic, model column prescribed with it): the model column of a
#: row must equal the diagnostic of the previous row (one sub-step of lag)
LAG_PAIRS = (('EMU_GR_TS', 'TS_GREENROOF'), ('EMU_GR_H', 'H_GREENROOF'),
             ('EMU_GR_LE', 'LE_GREENROOF'), ('EMU_GR_EVAP', 'EVAP_GREENROOF'))

#: (emulator diagnostic, column exported by TEB): both describe the exchange
#: coefficients of the greenroof, so they must agree in the neutral mode
COEF_PAIRS = (('EMU_GR_CD', 'PCD_GREENROOF_ATM'),
              ('EMU_GR_CH', 'PCH_GREENROOF_ATM'),
              ('EMU_GR_CA', 'PAC_GREENROOF_ATM'))

#: variables drawn in the figures: (column, label, unit, colour)
PLOT_VARS = (
    ('TS_GREENROOF',  'greenroof surface temperature', 'K',    '#1f77b4'),
    ('H_GREENROOF',   'greenroof sensible heat flux',  'W/m2', '#d62728'),
    ('LE_GREENROOF',  'greenroof latent heat flux',    'W/m2', '#2ca02c'),
    ('RN_GREENROOF',  'greenroof net radiation',       'W/m2', '#9467bd'),
)

#: absolute tolerance of the (floating point) identities
TOL = 1.0e-9

# ---------------------------------------------------------------------------
# Cases and namelists
# ---------------------------------------------------------------------------

def cases(lcz_tags=None, mode_tags=None):
    """Deterministic list of (case, lcz_tag, mode_tag)."""
    out = []
    for lcz_tag in (lcz_tags or list(LCZ)):
        for mode_tag in (mode_tags or list(MODES)):
            if mode_tag not in MODES:
                continue
            out.append((f'{lcz_tag}_{mode_tag}', lcz_tag, mode_tag))
    return out


def description(lcz_tag: str, mode_tag: str) -> str:
    """Human readable description of one case."""
    return f'{LCZ[lcz_tag]["label"]} / {MODES[mode_tag][1]}'


def build_namelist(base_nml: Path, lcz_tag: str, mode_tag: str, path: Path,
                   fr_greenroof: float, dt: float) -> Path:
    """Namelist of one case: base namelist + LCZ + greenroof mode.

    The garden is switched off and the solar panels are left off, so that the
    greenroof diagnostics are the only emulated ones. ``dt`` is set to the
    forcing step by the caller, so that one output row is one model sub-step
    and the coupling lag is directly visible in the CSV.
    """
    nml = f90nml.read(str(base_nml))
    p = nml['tebparam']
    lcz = LCZ[lcz_tag]
    p['urb_h_bld'] = float(lcz['h_bld'])
    p['urb_fr_bld'] = float(lcz['fr_bld'])
    p['urb_h2w'] = float(lcz['h2w'])
    p['teb_fai'] = [float(lcz['fai'])] * 8
    # the greenroof only: the garden is switched off
    p['teb_lgarden'] = False
    p['fr_garden'] = 0.0
    p['teb_lgreenroof'] = True
    p['teb_frac_gr'] = float(fr_greenroof)
    p['teb_type_greenroof'] = MODES[mode_tag][0]
    # no solar panel: the panel long-wave term is not part of the emulator
    p['teb_lsolar_panel'] = False
    p['teb_fr_panel'] = 0.0
    p['dt'] = float(dt)
    path.parent.mkdir(parents=True, exist_ok=True)
    nml.write(str(path), force=True)
    return path


def build_forcing_namelist(base_forcing_nml: Path, nsteps: int, forc_step: float,
                           path: Path) -> Path:
    """Copy of the forcing namelist: shorter series, time step = dt of the model.

    Writing ``forc_step = dt`` (instead of the resolution of the forcing files)
    makes the model integrate exactly one sub-step per output row, so that the
    coupling lag of the external greenroof appears as one row of the CSV.
    """
    nml = f90nml.read(str(base_forcing_nml))
    nml['tebforcing']['nsteps'] = int(nsteps)
    nml['tebforcing']['forc_step'] = float(forc_step)
    path.parent.mkdir(parents=True, exist_ok=True)
    nml.write(str(path), force=True)
    return path


def forcing_step(base_forcing_nml: Path) -> float:
    """Time step of the forcing (s), to run the model with dt = forc_step."""
    nml = f90nml.read(str(base_forcing_nml))
    return float(nml['tebforcing']['forc_step'])


# ---------------------------------------------------------------------------
# Reading and comparing the output
# ---------------------------------------------------------------------------

def read_case(out_dir: Path) -> dict:
    """Every column needed by the checks (None when the column is absent)."""
    cols = EMU_COLS + GR_COLS + ('Forc_TA', 'Forc_WIND', 'Forc_DIR_SW',
                                 'Forc_SCA_SW', 'Forc_LW')
    return {c: series(out_dir, c) for c in cols}


def finite(x):
    """Array with the undefined values (>= XUNDEF) replaced by NaN."""
    if x is None:
        return None
    x = np.asarray(x, dtype=float)
    return np.where(np.abs(x) >= XUNDEF, np.nan, x)


def compare(a, b, start: int = 0) -> tuple:
    """(max|a-b|, number of compared rows, number of undefined rows) from start.

    A missing column gives (nan, 0, 0); rows where one of the two values is
    undefined (>= XUNDEF) are counted but not compared.
    """
    if a is None or b is None:
        return np.nan, 0, 0
    fa, fb = finite(a)[start:], finite(b)[start:]
    n = min(len(fa), len(fb))
    if n <= 0:
        return np.nan, 0, 0
    fa, fb = fa[:n], fb[:n]
    bad = np.isnan(fa) | np.isnan(fb)
    n_undef = int(bad.sum())
    if bad.all():
        return np.nan, 0, n_undef
    return float(np.max(np.abs((fa - fb)[~bad]))), int(n - n_undef), n_undef




# ---------------------------------------------------------------------------
# The checks
# ---------------------------------------------------------------------------

def add_check(rows, case, lcz_tag, mode_tag, check, relation, res, tol=TOL, note=''):
    """Append one check (``res`` = (max|diff|, n compared, n undefined))."""
    diff, n_cmp, n_undef = res
    if n_cmp == 0:
        status = 'no data'
    elif np.isnan(diff):
        status = 'n/a'
    else:
        status = 'OK' if diff <= tol else 'FAILED'
    rows.append(dict(case=case, lcz=lcz_tag, mode=mode_tag, check=check,
                     relation=relation, max_abs_diff=diff, n_compared=n_cmp,
                     n_undefined=n_undef, tolerance=tol, status=status,
                     note=note))


def add_reported(rows, case, lcz_tag, mode_tag, check, relation, res, note=''):
    """Append one check that is measured but not a pass/fail test."""
    diff, n_cmp, n_undef = res
    rows.append(dict(case=case, lcz=lcz_tag, mode=mode_tag, check=check,
                     relation=relation, max_abs_diff=diff, n_compared=n_cmp,
                     n_undefined=n_undef, tolerance=np.nan, status='reported',
                     note=note))


def lag_compare(d: dict, gr_col: str, emu_col: str):
    """max|model_column[k] - emu_diagnostic[k-1]| over k >= 1."""
    a, b = d.get(gr_col), d.get(emu_col)
    if a is None or b is None or len(a) < 2:
        return np.nan, 0, 0
    return compare(np.asarray(a, dtype=float)[1:], np.asarray(b, dtype=float)[:-1])


def slice_compare(a, b, sl=slice(0, 1)):
    """compare() restricted to a slice of the two series."""
    if a is None or b is None:
        return np.nan, 0, 0
    return compare(np.asarray(a, dtype=float)[sl], np.asarray(b, dtype=float)[sl])


def case_checks(case: str, lcz_tag: str, mode_tag: str, d: dict):
    """All the checks of one case, as a list of rows (see ``add_check``)."""
    rows = []
    mode = MODES[mode_tag][0]
    if mode == 'PROXY_NEW':
        add_reported(rows, case, lcz_tag, mode_tag, 'emulator diagnostics',
                     'EMU_GR_* columns',
                     (np.nan, 0, 0),
                     'internal greenroof: the driver does not emulate, so the '
                     'EMU_GR_* columns are not written')
        return rows

    # 1. energy balance of the surface emulated by PCD_GREENROOF (G = 0)
    rn, h, le = d.get('EMU_GR_RN'), d.get('EMU_GR_H'), d.get('EMU_GR_LE')
    if rn is not None and h is not None and le is not None:
        add_check(rows, case, lcz_tag, mode_tag, 'surface balance',
                  'EMU_GR_RN = EMU_GR_H + EMU_GR_LE',
                  compare(rn, np.asarray(h, dtype=float) + np.asarray(le, dtype=float)))

    # 2. coupling lag: what the emulator wrote at one sub-step is used by TEB at
    #    the next one (one output row, because dt = forc_step in this test)
    for emu_col, gr_col in LAG_PAIRS:
        add_check(rows, case, lcz_tag, mode_tag, 'coupling lag',
                  f'{gr_col}[k] = {emu_col}[k-1]',
                  lag_compare(d, gr_col, emu_col))

    # 3. exchange coefficients: the ones the driver computes for the emulator and
    #    the ones TEB exports must be the same set of coefficients
    for emu_col, tex_col in COEF_PAIRS:
        res = compare(d.get(emu_col), d.get(tex_col))
        if mode == 'EXT_NEU':
            add_check(rows, case, lcz_tag, mode_tag, 'coefficients',
                      f'{emu_col} = {tex_col}', res)
        else:
            add_reported(rows, case, lcz_tag, mode_tag, 'coefficients',
                         f'{emu_col} vs {tex_col}', res,
                         'EXT: the coefficient exported by TEB carries the '
                         'Richardson-number correction of URBAN_EXCH_COEF, the '
                         'emulator keeps its neutral one')

    # 4. spin-up: the coupling starts from the air temperature and zero fluxes, so
    #    the first output row (the first sub-step) is a transient of the coupling
    #    (the thermal balance of the greenroof starts from the air temperature,
    #    which is the temperature of the start of the run, not the one of the
    #    first output row, stamped start + forc_step: the two differ)
    add_reported(rows, case, lcz_tag, mode_tag, 'spin-up',
                 'TS_GREENROOF[0] vs Forc_TA[0]',
                 slice_compare(d.get('TS_GREENROOF'), d.get('Forc_TA')),
                 'the driver initialises the coupled state with the air temperature '
                 'of the start of the run; Forc_TA[0] is the forcing of the first '
                 'output row (start + forc_step), so the two are not the same instant')
    zero = np.zeros(1)
    for col in ('H_GREENROOF', 'LE_GREENROOF'):
        add_check(rows, case, lcz_tag, mode_tag, 'spin-up',
                  f'{col}[0] = 0', slice_compare(d.get(col), zero))
    return rows


def cross_checks(keys, data: dict):
    """Checks that need two runs of the same morphology.

    ``data`` is keyed by (lcz_tag, mode_tag); the reference is the internal
    greenroof (PROXY_NEW).
    """
    rows = []
    for lcz_tag in sorted({lcz for lcz, _ in keys}):
        ref = data.get((lcz_tag, 'PROXY_NEW'))
        neu = data.get((lcz_tag, 'EXT_NEU'))
        ext = data.get((lcz_tag, 'EXT'))

        # 5. the emulator diagnostics reproduce the internal greenroof output on
        #    the same row, the first row of the external run (the spin-up of the
        #    coupling) being the only difference
        for emu_col, gr_col in LAG_PAIRS + (('EMU_GR_RN', 'RN_GREENROOF'),):
            res = (compare(np.asarray(neu[emu_col], dtype=float)[1:],
                           np.asarray(ref[gr_col], dtype=float)[1:])
                   if (neu is not None and ref is not None
                       and neu.get(emu_col) is not None and ref.get(gr_col) is not None)
                   else (np.nan, 0, 0))
            add_check(rows, f'{lcz_tag}_emulator_vs_internal', lcz_tag, 'EXT_NEU',
                      'emulator vs internal greenroof',
                      f'{emu_col}[k] = {gr_col}[k] (PROXY_NEW)',
                      res, note='same output row; row 0 (spin-up) excluded')

        # the prescribed columns of the external run are the reference series of
        # the previous row: the whole coupling is one sub-step behind. Row 1 is
        # the transient of the first sub-step (the emulator starts from the air
        # temperature and zero fluxes), so the comparison starts at row 2.
        for gr_col in ('TS_GREENROOF', 'H_GREENROOF', 'LE_GREENROOF',
                       'EVAP_GREENROOF'):
            res = (compare(np.asarray(neu[gr_col], dtype=float)[2:],
                           np.asarray(ref[gr_col], dtype=float)[1:-1])
                   if (neu is not None and ref is not None
                       and neu.get(gr_col) is not None and ref.get(gr_col) is not None)
                   else (np.nan, 0, 0))
            add_check(rows, f'{lcz_tag}_emulator_vs_internal', lcz_tag, 'EXT_NEU',
                      'emulator vs internal greenroof',
                      f'{gr_col}(EXT_NEU)[k] = {gr_col}(PROXY_NEW)[k-1]', res,
                      note='the transient row of the first sub-step is excluded')

        # 6. the emulated state and fluxes are the neutral ones in both external
        #    modes, whereas the exported coefficients carry the stability effect
        if neu is not None and ext is not None:
            for col in ('EMU_GR_TS', 'EMU_GR_H', 'EMU_GR_LE', 'EMU_GR_RN',
                        'EMU_GR_CD', 'EMU_GR_CH'):
                add_check(rows, f'{lcz_tag}_EXT_vs_EXT_NEU', lcz_tag, 'EXT',
                          'emulated surface is neutral in both modes',
                          f'{col}(EXT) = {col}(EXT_NEU)',
                          compare(neu.get(col), ext.get(col)),
                          note='the emulator always describes the neutral exchange')
            for col in ('PCD_GREENROOF_ATM', 'PCH_GREENROOF_ATM',
                        'PAC_GREENROOF_ATM', 'PRI_GREENROOF_ATM'):
                add_reported(rows, f'{lcz_tag}_EXT_vs_EXT_NEU', lcz_tag, 'EXT',
                             'exported coefficients',
                             f'{col}(EXT) vs {col}(EXT_NEU)',
                             compare(neu.get(col), ext.get(col)),
                             'the difference is the Richardson-number correction '
                             'of URBAN_EXCH_COEF applied to the exported coefficients')
    return rows


def summary_table(keys, data: dict) -> pd.DataFrame:
    """Mean/min/max of the greenroof diagnostics of every case."""
    rows = []
    for lcz_tag, mode_tag in keys:
        d = data.get((lcz_tag, mode_tag))
        row = dict(case=f'{lcz_tag}_{mode_tag}', lcz=lcz_tag, mode=mode_tag,
                   description=description(lcz_tag, mode_tag))
        for col in GR_COLS[:5] + ('PAC_GREENROOF_ATM', 'PCD_GREENROOF_ATM',
                                  'PCH_GREENROOF_ATM'):
            x = finite(d.get(col)) if d else None
            row[f'{col}_mean'] = float(np.nanmean(x)) if x is not None and not np.isnan(x).all() else np.nan
            row[f'{col}_min'] = float(np.nanmin(x)) if x is not None and not np.isnan(x).all() else np.nan
            row[f'{col}_max'] = float(np.nanmax(x)) if x is not None and not np.isnan(x).all() else np.nan
        rows.append(row)
    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# Figures
# ---------------------------------------------------------------------------

#: emulator diagnostic drawn on top of a model variable (they must coincide with
#: the reference run: the emulator reproduces the internal greenroof)
EMU_OF = {'TS_GREENROOF': 'EMU_GR_TS', 'H_GREENROOF': 'EMU_GR_H',
          'LE_GREENROOF': 'EMU_GR_LE', 'RN_GREENROOF': 'EMU_GR_RN'}

#: emulator diagnostic of each coefficient exported by TEB
EMU_COEF_OF = {'PCD_GREENROOF_ATM': 'EMU_GR_CD', 'PCH_GREENROOF_ATM': 'EMU_GR_CH',
               'PAC_GREENROOF_ATM': 'EMU_GR_CA'}


def plot_variable(fig_dir: Path, lcz_tag: str, data: dict, col: str, label: str,
                  unit: str, colour: str) -> Path:
    """One variable of the three modes, plus the emulator diagnostic."""
    fig, ax = plt.subplots(figsize=(11.0, 4.2))
    for mode_tag, style in (('PROXY_NEW', dict(color='0.35', lw=1.8)),
                            ('EXT_NEU', dict(color=colour, lw=1.8)),
                            ('EXT', dict(color=colour, lw=1.1, ls='--'))):
        d = data.get((lcz_tag, mode_tag))
        y = d.get(col) if d else None
        if y is None:
            continue
        ax.plot(np.arange(len(y)), y, label=f'{mode_tag}: {col}', **style)
    d = data.get((lcz_tag, 'EXT_NEU'))
    emu = EMU_OF.get(col)
    if d and emu and d.get(emu) is not None:
        y = d[emu]
        ax.plot(np.arange(len(y)), y, color='k', lw=0.9, ls=':',
                label=f'{emu} (emulator output)')
    ax.set_xlabel('output row (one forcing step = one model sub-step, dt = forc_step)')
    ax.set_ylabel(f'{label} ({unit})')
    ax.set_title(f'{LCZ[lcz_tag]["label"]} - {label}')
    ax.legend(fontsize=8, ncol=2)
    ax.grid(alpha=0.3)
    fig.tight_layout()
    path = fig_dir / f'{lcz_tag}_{col.lower()}.png'
    fig.savefig(path, dpi=110)
    plt.close(fig)
    return path


def plot_coefficients(fig_dir: Path, lcz_tag: str, data: dict) -> Path:
    """Coefficients exported by TEB (EXT vs EXT_NEU) and used by the emulator."""
    cols = (('PCD_GREENROOF_ATM', 'PCD - momentum'), ('PCH_GREENROOF_ATM', 'PCH - heat'),
            ('PAC_GREENROOF_ATM', 'PAC - conductance'))
    fig, axes = plt.subplots(len(cols), 1, figsize=(11.0, 2.9 * len(cols)), squeeze=False)
    for ax, (col, label) in zip(axes[:, 0], cols):
        for mode_tag, colour in (('EXT_NEU', '#1f77b4'), ('EXT', '#d62728')):
            d = data.get((lcz_tag, mode_tag))
            y = d.get(col) if d else None
            if y is not None:
                ax.plot(np.arange(len(y)), y, color=colour,
                        label=f'{mode_tag}: {col} (exported by TEB)')
        d = data.get((lcz_tag, 'EXT_NEU'))
        emu = EMU_COEF_OF.get(col)
        if d and emu and d.get(emu) is not None:
            y = d[emu]
            ax.plot(np.arange(len(y)), y, color='k', lw=0.9, ls=':',
                    label=f'{emu} (used by the emulator)')
        ax.set_ylabel(label)
        ax.legend(fontsize=8)
        ax.grid(alpha=0.3)
    axes[-1, 0].set_xlabel('output row')
    fig.suptitle(f'{LCZ[lcz_tag]["label"]} - greenroof exchange coefficients')
    fig.tight_layout()
    path = fig_dir / f'{lcz_tag}_coefficients.png'
    fig.savefig(path, dpi=110)
    plt.close(fig)
    return path


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def write_readme(out_root: Path, base_nml: Path, forcing_nml: Path, keys, checks,
                 summary: pd.DataFrame, days: float, fr_greenroof: float,
                 dt: float, nsteps: int) -> Path:
    """Description of the experiment and its results."""
    df = pd.DataFrame(checks)
    failed = df[df['status'] == 'FAILED'] if len(df) else df
    lines = []
    lines.append('# Greenroof emulator of the offline driver versus the internal greenroof')
    lines.append('')
    lines.append('Generated by `python_tests/greenroof_emu_compare.py`.')
    lines.append('')
    lines.append('## Configuration')
    lines.append('')
    lines.append(f'* site              : `{forcing_nml.parent.parent.name}`')
    lines.append(f'* base namelist     : `{base_nml}`')
    lines.append(f'* forcing namelist  : `{forcing_nml}`')
    lines.append(f'* series            : {days} days = {nsteps} forcing steps')
    lines.append(f'* model time step   : dt = forc_step = {dt:g} s (one model sub-step per '
                 'output row, so that the coupling lag is one row)')
    lines.append(f'* greenroof fraction: {fr_greenroof}')
    lines.append('* garden off, solar panels off, so that the greenroof is the only '
                 'emulated surface')
    lines.append('')
    lines.append('## Cases')
    lines.append('')
    lines.append('| case | morphology | greenroof |')
    lines.append('|------|-----------|-----------|')
    for lcz_tag, mode_tag in keys:
        lines.append(f'| `{lcz_tag}_{mode_tag}` | {LCZ[lcz_tag]["label"]} | '
                     f'{MODES[mode_tag][1]} |')
    lines.append('')
    lines.append('## Checks')
    lines.append('')
    lines.append(f'{len(df)} checks, {int((df["status"] == "OK").sum())} OK, '
                 f'{len(failed)} FAILED. The identities of the checks are described '
                 'in the module docstring of `python_tests/greenroof_emu_compare.py`.')
    lines.append('')
    lines.append('| case | check | relation | max abs. difference | rows | status |')
    lines.append('|------|-------|----------|--------------------:|-----:|--------|')
    for _, r in df.iterrows():
        diff = r['max_abs_diff']
        txt = '-' if (isinstance(diff, float) and np.isnan(diff)) else f'{diff:.3e}'
        lines.append(f'| `{r["case"]}` | {r["check"]} | `{r["relation"]}` | {txt} | '
                     f'{r["n_compared"]} | {r["status"]} |')
    lines.append('')
    lines.append('## Greenroof diagnostics per case')
    lines.append('')
    lines.append('Mean over the series (the coefficients are the ones exported by '
                 'TEB, undefined for the internal greenroof).')
    lines.append('')
    cols = [c for c in summary.columns if c.endswith('_mean')]
    lines.append('| case | ' + ' | '.join(c[:-5] for c in cols) + ' |')
    lines.append('|------|' + '|'.join(['------:'] * len(cols)) + '|')
    for _, r in summary.iterrows():
        vals = [f'{r[c]:.5g}' if pd.notna(r[c]) else '-' for c in cols]
        lines.append(f'| `{r["case"]}` | ' + ' | '.join(vals) + ' |')
    lines.append('')
    lines.append('## Figures')
    lines.append('')
    for lcz_tag in sorted({lcz for lcz, _ in keys}):
        lines.append(f'* `plots/{lcz_tag.lower()}_ts_greenroof.png`, '
                     f'`plots/{lcz_tag.lower()}_h_greenroof.png`, ...: the three modes '
                     'and the emulator diagnostic (which falls on the reference run)')
        lines.append(f'* `plots/{lcz_tag.lower()}_coefficients.png`: the coefficients '
                     'exported by TEB in the two external modes and the ones the '
                     'emulator uses')
    lines.append('')
    path = out_root / 'README.md'
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return path


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description='External greenroof emulator (PCD_GREENROOF) versus the '
                    'internal greenroof of TEB-MSU.')
    ap.add_argument('--work-dir', default=DEFAULT_WORK_DIR,
                    help='root of the experiments (default: %(default)s)')
    ap.add_argument('--site', default='Moscow', help='site name (default: %(default)s)')
    ap.add_argument('--base-namelist', default=None,
                    help='base TEB namelist (default: <work>/<site>/params_CTRL.nml)')
    ap.add_argument('--forcing-nml', default=None,
                    help='forcing namelist (default: <work>/<site>/forcing_ERA5/'
                         'namelist_forcing.nml)')
    ap.add_argument('--out-root', default=None,
                    help='output directory (default: <work>/<site>/greenroof_emu_compare)')
    ap.add_argument('--exe', default=None,
                    help='model executable (default: build/TEB_offline.exe)')
    ap.add_argument('--only', default=None, help='comma separated list of case names')
    ap.add_argument('--lcz', default=None, help='comma separated list of LCZ tags')
    ap.add_argument('--modes', default=None, help='comma separated list of greenroof modes')
    ap.add_argument('--skip-run', action='store_true',
                    help='post-process the existing runs only')
    ap.add_argument('--force', action='store_true',
                    help='re-run the cases even if their output exists')
    ap.add_argument('--list', action='store_true', help='list the cases and exit')
    ap.add_argument('--days', type=float, default=1.0,
                    help='length of the simulated series (default: %(default)s)')
    ap.add_argument('--dt', type=float, default=0.0,
                    help='model time step, also written as forc_step of the case '
                         'forcing namelists, so that one output row is one model '
                         'sub-step (default: 0 = automatic, min(forc_step of the '
                         'site, 1800 s); a time step of 3600 s, the resolution of '
                         'the ERA5 files, trips the floating-point checks)')
    ap.add_argument('--fr-greenroof', type=float, default=0.5,
                    help='greenroof fraction (default: %(default)s)')
    args = ap.parse_args(argv)

    work = Path(args.work_dir)
    base = (Path(args.base_namelist) if args.base_namelist
            else work / args.site / 'params_CTRL.nml')
    forcing_nml = (Path(args.forcing_nml) if args.forcing_nml
                   else work / args.site / 'forcing_ERA5' / 'namelist_forcing.nml')
    out_root = (Path(args.out_root) if args.out_root
                else work / args.site / 'greenroof_emu_compare')
    exe = Path(args.exe) if args.exe else MODEL_DIR / 'build' / 'TEB_offline.exe'

    for what, p in (('base namelist', base), ('forcing namelist', forcing_nml),
                    ('model executable', exe)):
        if not p.exists():
            print(f'ERROR: {what} not found: {p}')
            return 2

    site_step = forcing_step(forcing_nml)
    dt = float(args.dt) if args.dt > 0.0 else min(site_step, 1800.0)
    lcz_tags = ([s.strip() for s in args.lcz.split(',') if s.strip()]
                if args.lcz else list(LCZ))
    mode_tags = ([s.strip() for s in args.modes.split(',') if s.strip()]
                 if args.modes else list(MODES))
    case_list = cases(lcz_tags, mode_tags)
    if args.only:
        wanted = {s.strip() for s in args.only.split(',') if s.strip()}
        case_list = [c for c in case_list if c[0] in wanted]
    nsteps = max(2, int(round(args.days * 86400.0 / dt)))

    if args.list:
        print(f'dt = {dt:g} s (site forc_step = {site_step:g} s) -> nsteps = {nsteps}')
        for case, lcz_tag, mode_tag in case_list:
            print(f'  {case:<18} {description(lcz_tag, mode_tag)}')
        return 0

    print('Greenroof emulator comparison')
    print(f'  base namelist  : {base}')
    print(f'  forcing        : {forcing_nml} (site forc_step = {site_step:g} s -> '
          f'{nsteps} steps of {dt:g} s)')
    print(f'  output         : {out_root}')
    print(f'  executable     : {exe}')
    print(f'  greenroof      : fraction {args.fr_greenroof}, garden off, panels off')

    data = {}
    for case, lcz_tag, mode_tag in case_list:
        nml_path = out_root / 'namelists' / f'{case}.nml'
        fml_path = build_forcing_namelist(forcing_nml, nsteps, dt,
                                          out_root / 'forcing' / f'{case}.nml')
        build_namelist(base, lcz_tag, mode_tag, nml_path, args.fr_greenroof, dt)
        out_dir = out_root / f'output_{case}'
        log_file = out_root / 'logs' / f'{case}.log'
        csv_file = out_dir / 'TEB_output.csv'
        if args.skip_run:
            rc = 0 if csv_file.is_file() else 1
            print(f'  {case:<18} post-processed ({description(lcz_tag, mode_tag)})')
        elif csv_file.is_file() and not args.force:
            rc = 0
            print(f'  {case:<18} kept (use --force to re-run)')
        else:
            rc = run_case(exe, fml_path, nml_path, out_dir, log_file)
            print(f'  {case:<18} ran  ({description(lcz_tag, mode_tag)})')
        if rc != 0:
            print(f'  {case:<18} FAILED (return code {rc}, see {log_file})')
            return 1
        data[(lcz_tag, mode_tag)] = read_case(out_dir)

    keys = [(lcz_tag, mode_tag) for _, lcz_tag, mode_tag in case_list]
    checks = []
    for case, lcz_tag, mode_tag in case_list:
        checks += case_checks(case, lcz_tag, mode_tag, data[(lcz_tag, mode_tag)])
    checks += cross_checks(keys, data)
    df = pd.DataFrame(checks)
    df.to_csv(out_root / 'checks_greenroof_emu.csv', index=False)

    summary = summary_table(keys, data)
    summary.to_csv(out_root / 'summary_greenroof_emu.csv', index=False)

    fig_dir = out_root / 'plots'
    fig_dir.mkdir(parents=True, exist_ok=True)
    for lcz_tag in sorted({lcz for lcz, _ in keys}):
        for col, label, unit, colour in PLOT_VARS:
            plot_variable(fig_dir, lcz_tag, data, col, label, unit, colour)
        plot_coefficients(fig_dir, lcz_tag, data)

    write_readme(out_root, base, forcing_nml, keys, checks, summary,
                 args.days, args.fr_greenroof, dt, nsteps)

    n_ok = int((df['status'] == 'OK').sum())
    n_bad = int((df['status'] == 'FAILED').sum())
    print(f'  checks         : {len(df)} ({n_ok} OK, {n_bad} FAILED)')
    print(f'  checks file    : {out_root / "checks_greenroof_emu.csv"}')
    print(f'  report         : {out_root / "README.md"}')
    if n_bad:
        print(df[df['status'] == 'FAILED'][['case', 'check', 'relation',
                                            'max_abs_diff']].to_string(index=False))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
