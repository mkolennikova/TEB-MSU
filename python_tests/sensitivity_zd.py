#!/usr/bin/env python
"""
Sensitivity of the TEB-MSU roof-level wind (U_TOP -> WIND_TOP) and canyon wind
(U_CANYON -> U_CANYON) to the way the displacement height zd is prescribed.

Experiment design
-----------------
Base configuration: the Moscow ERA5 forcing and the model configuration of
`run_on_windows.ipynb` (site <work_dir>/Moscow, params_CTRL.nml, hlev_teb = 10 m,
period 2022-08-01 .. 2022-09-01).

Varied parameters:
  * zd prescription: 'H/3' (1/3 H), 'H/1.5' (2/3 H), 'MACDONALD1998' (staggered
    arrays) and 'MACDONALD1998SQ' (square arrays)
  * z0 prescription: '0.1H' in the zd-sensitivity group, plus the two
    combinations in which zd and z0 are both taken from the same Macdonald
    parameterization (staggered and square)
  * wind scheme: teb_itype_wind = 0 (default) and 1 (Wang 2012)
  * urban morphology: LCZ 2 (compact mid-rise, city centre) and LCZ 9
    (sparse low-rise, suburban, H/W = 0.15)

All other settings are taken from the base namelist (materials, BEM, etc.).

Runs, namelists, logs, statistics and plots are written into
<work_dir>/<site>/sensitivity_zd/ and are NOT deleted (re-run with --force to
repeat a simulation, or with --skip-run to only post-process existing data).

Usage
-----
    python python_tests/sensitivity_zd.py                 # run everything
    python python_tests/sensitivity_zd.py --list          # list the cases
    python python_tests/sensitivity_zd.py --only LCZ2_zdMACD_w0,LCZ9_zd23H_w1
    python python_tests/sensitivity_zd.py --skip-run      # statistics/plots only
    python python_tests/sensitivity_zd.py --force         # re-run existing cases
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
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
try:
    from forcing_utils import read_forcing       # read the Forc_*.txt used by a run
except Exception:                                # pragma: no cover
    read_forcing = None

# building configurations of the cases: the descriptions live in the shared
# module morphology.py; LCZ (the single set) is imported here and re-exported,
# so the benches keep importing it from sensitivity_zd
from morphology import LCZ                       # noqa: E402

# ---------------------------------------------------------------------------
# Experiment configuration
# ---------------------------------------------------------------------------

#: z0 variants: case-tag -> (namelist value, description). '0.1H' is the value of
#: the base namelist and is used in the zd-sensitivity group, so that only zd is
#: varied there; the two Macdonald variants are combined with the matching zd
#: prescription (see CASE_MATRIX)
Z0_VARIANTS = {
    'z0_01H':   ('0.1H',            '0.1 H (reference)'),
    'z0MACD':   ('MACDONALD1998',   'Macdonald et al. (1998), staggered'),
    'z0MACDSQ': ('MACDONALD1998SQ', 'Macdonald et al. (1998), square'),
}

#: z0 of the reference group; its tag is omitted from the case names
DEFAULT_Z0_TAG = 'z0_01H'

#: displacement height variants: case-tag -> (namelist value, description)
#: NOTE: 'H/1.5' is exactly 2/3 H (the namelist parser accepts 'H/<n>',
#: '<value>H', '<value>m' or a plain number, but not '<a>/<b>H')
ZD_VARIANTS = {
    'zd13H':    ('H/3',             '1/3 H'),
    'zd23H':    ('H/1.5',           '2/3 H'),
    'zdMACD':   ('MACDONALD1998',   'Macdonald et al. (1998), staggered'),
    'zdMACDSQ': ('MACDONALD1998SQ', 'Macdonald et al. (1998), square'),
}

#: the cases of the experiment: (z0 tag, zd tag, label), in plot order
CASE_MATRIX = [
    ('z0_01H',   'zd13H',    '1/3 H'),
    ('z0_01H',   'zd23H',    '2/3 H'),
    ('z0_01H',   'zdMACD',   'Macdonald (staggered)'),
    ('z0_01H',   'zdMACDSQ', 'Macdonald (square)'),
    ('z0MACD',   'zdMACD',   'Macdonald, zd + z0'),
    ('z0MACDSQ', 'zdMACDSQ', 'Macdonald square, zd + z0'),
]

#: labels of the variants in plot order
VARIANT_ORDER = [lab for _, _, lab in CASE_MATRIX]

#: wind schemes: teb_itype_wind -> case tag
WIND_TYPES = {0: 'w0', 1: 'w1'}

RE_Z0 = re.compile(r'urb_z0_town\s*=\s*(\S+)\s*->\s*z0\s*=\s*([0-9EeDd.+-]+)')
RE_ZD = re.compile(r'urb_zd_town\s*=\s*(\S+)\s*->\s*zd\s*=\s*([0-9EeDd.+-]+)')


def _f(x: str) -> float:
    """Fortran-style real -> float (D/d exponents, e.g. 1.0D-3)."""
    return float(x.replace('D', 'E').replace('d', 'e'))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def cases():
    """Deterministic list of (case, lcz_tag, wind_type, z0_tag, zd_tag).

    The z0 tag appears in the case name only when z0 is not the reference value
    (urb_z0_town = '0.1H'), so that the zd-sensitivity cases keep their names.
    """
    out = []
    for lcz_tag in LCZ:
        for wind_type, wind_tag in WIND_TYPES.items():
            for z0_tag, zd_tag, _ in CASE_MATRIX:
                parts = [lcz_tag]
                if z0_tag != DEFAULT_Z0_TAG:
                    parts.append(z0_tag)
                parts.extend([zd_tag, wind_tag])
                out.append(('_'.join(parts), lcz_tag, wind_type, z0_tag, zd_tag))
    return out


def variant_label(z0_tag: str, zd_tag: str) -> str:
    """Label of the (z0, zd) variant used in the tables and the figures."""
    return next(lab for t0, tz, lab in CASE_MATRIX if t0 == z0_tag and tz == zd_tag)


def build_namelist(base_nml: Path, lcz_tag: str, wind_type: int, z0_tag: str,
                   zd_tag: str, path: Path) -> Path:
    """Write the namelist of one case: base namelist + LCZ + wind scheme + z0/zd."""
    nml = f90nml.read(str(base_nml))
    p = nml['tebparam']
    lcz = LCZ[lcz_tag]
    p['urb_h_bld'] = float(lcz['h_bld'])
    p['urb_fr_bld'] = float(lcz['fr_bld'])
    p['urb_h2w'] = float(lcz['h2w'])
    p['teb_fai'] = [float(lcz['fai'])] * 8
    p['teb_itype_wind'] = int(wind_type)
    p['urb_z0_town'] = Z0_VARIANTS[z0_tag][0]
    p['urb_zd_town'] = ZD_VARIANTS[zd_tag][0]
    path.parent.mkdir(parents=True, exist_ok=True)
    nml.write(str(path), force=True)
    return path


def read_text(path: Path) -> str | None:
    """Content of a text file, or None if it does not exist."""
    if not path.is_file():
        return None
    return path.read_text(encoding='utf-8', errors='ignore')


def run_case(exe: Path, forcing_nml: Path, params_nml: Path, out_dir: Path, log_file: Path) -> int:
    """Run one simulation; the model output and the log are kept."""
    out_dir.mkdir(parents=True, exist_ok=True)
    log_file.parent.mkdir(parents=True, exist_ok=True)
    cmd = [str(exe),
           '-forcing_nml', str(forcing_nml),
           '-param_nml', str(params_nml),
           '-output', str(out_dir) + os.sep]
    with open(log_file, 'w', encoding='utf-8') as fh:
        proc = subprocess.run(cmd, cwd=str(MODEL_DIR), stdout=fh, stderr=subprocess.STDOUT)
    return proc.returncode


def banner_values(log_file: Path):
    """Effective z0 and zd as printed by the model configuration banner."""
    z0 = zd = np.nan
    txt = log_file.read_text(encoding='utf-8', errors='ignore') if log_file.exists() else ''
    m = RE_Z0.search(txt)
    if m:
        z0 = _f(m.group(2))
    m = RE_ZD.search(txt)
    if m:
        zd = _f(m.group(2))
    return z0, zd


def series(out_dir: Path, name: str):
    """Read one output variable (one value per forcing step) as an array.

    Both output formats are supported: the single CSV file ``TEB_output.csv``
    (columns: ``time``, model variables, ``Forc_*``) and the legacy per-variable
    ``<NAME>.txt`` files. ``name`` is the variable name, optionally with '.txt'.
    Returns None when the variable is not available.
    """
    name = str(name)
    if name.endswith('.txt'):
        name = name[:-4]
    csv_file = out_dir / 'TEB_output.csv'
    if csv_file.is_file():
        try:
            # converters=float: the pandas fast float parser may lose 1 ULP
            return pd.read_csv(csv_file, sep=';', usecols=[name],
                               converters={name: float})[name].to_numpy(dtype=float)
        except ValueError:                      # column not present in the CSV
            return None
    f = out_dir / f'{name}.txt'
    if not f.exists():
        return None
    return pd.read_csv(f, header=None, converters={0: float}).iloc[:, 0].to_numpy(dtype=float)


def stats_of(x):
    """Basic statistics of a time series."""
    if x is None or len(x) == 0:
        return dict(n=0, mean=np.nan, std=np.nan, p05=np.nan, p50=np.nan, p95=np.nan,
                    min=np.nan, max=np.nan)
    return dict(n=len(x), mean=float(np.mean(x)), std=float(np.std(x)),
                p05=float(np.percentile(x, 5)), p50=float(np.percentile(x, 50)),
                p95=float(np.percentile(x, 95)),
                min=float(np.min(x)), max=float(np.max(x)))


# ---------------------------------------------------------------------------
# Statistics, plots, report
# ---------------------------------------------------------------------------

def collect_statistics(cases_list, out_root: Path, forcing_nml: Path) -> pd.DataFrame:
    """Statistics of U_TOP and U_CANYON for every case."""
    forcing = None
    if read_forcing is not None:
        try:
            forcing = read_forcing(str(forcing_nml))
        except Exception as exc:
            print(f'WARNING: forcing could not be read ({exc})')
    v_forc = np.nan
    if forcing is not None and 'Forc_WIND' in forcing.columns:
        v_forc = float(forcing['Forc_WIND'].mean())

    rows = []
    for case, lcz_tag, wind_type, z0_tag, zd_tag in cases_list:
        out_dir = out_root / f'output_{case}'
        log_file = out_root / 'logs' / f'{case}.log'
        st_top = stats_of(series(out_dir, 'WIND_TOP.txt'))
        st_can = stats_of(series(out_dir, 'U_CANYON.txt'))
        z0_eff, zd_eff = banner_values(log_file)
        h_bld = float(LCZ[lcz_tag]['h_bld'])
        rows.append(dict(
            case=case, lcz=lcz_tag, lcz_label=LCZ[lcz_tag]['label'],
            wind_type=wind_type,
            variant=variant_label(z0_tag, zd_tag),
            z0_tag=z0_tag, zd_tag=zd_tag,
            z0_namelist=Z0_VARIANTS[z0_tag][0], z0_description=Z0_VARIANTS[z0_tag][1],
            zd_namelist=ZD_VARIANTS[zd_tag][0], zd_description=ZD_VARIANTS[zd_tag][1],
            h_bld=h_bld,
            lambda_p=LCZ[lcz_tag]['fr_bld'], lambda_f=LCZ[lcz_tag]['fai'], h2w=LCZ[lcz_tag]['h2w'],
            z0_effective=z0_eff, zd_effective=zd_eff,
            z0_over_h=(z0_eff / h_bld if z0_eff == z0_eff else np.nan),
            zd_over_h=(zd_eff / h_bld if zd_eff == zd_eff else np.nan),
            n_steps=st_top['n'],
            u_top_mean=st_top['mean'], u_top_std=st_top['std'],
            u_top_p05=st_top['p05'], u_top_p95=st_top['p95'],
            u_canyon_mean=st_can['mean'], u_canyon_std=st_can['std'],
            u_canyon_p05=st_can['p05'], u_canyon_p95=st_can['p95'],
            canyon_over_top=(st_can['mean'] / st_top['mean'] if st_top['mean'] else np.nan),
            u_top_over_forcing=(st_top['mean'] / v_forc if v_forc == v_forc and v_forc else np.nan),
            u_canyon_over_forcing=(st_can['mean'] / v_forc if v_forc == v_forc and v_forc else np.nan),
            forcing_wind_mean=v_forc,
            output_dir=str(out_dir), log=str(log_file)))
    return pd.DataFrame(rows)


def plot_bars(df: pd.DataFrame, columns, ylabel, title, path: Path):
    """2x2 panel bar chart: rows = LCZ, columns = wind scheme."""
    fig, axes = plt.subplots(2, 2, figsize=(13, 8.5), sharex=True)
    for i, lcz_tag in enumerate(LCZ):
        for j, wind_type in enumerate(WIND_TYPES):
            ax = axes[i, j]
            sub = df[(df.lcz == lcz_tag) & (df.wind_type == wind_type)].set_index('variant')
            sub = sub.reindex(VARIANT_ORDER)
            x = np.arange(len(sub))
            w = 0.8 / max(len(columns), 1)
            for k, (col, lab, c) in enumerate(columns):
                ax.bar(x + (k - (len(columns) - 1) / 2) * w, sub[col], w, label=lab, color=c)
            ax.set_xticks(x)
            ax.set_xticklabels(VARIANT_ORDER, fontsize=7.5, rotation=20, ha='right')
            ax.set_title(f'{LCZ[lcz_tag]["label"]}\nteb_itype_wind = {wind_type}', fontsize=9)
            ax.set_ylabel(ylabel)
            ax.grid(True, axis='y', alpha=0.3)
            ax.legend(fontsize=8)
    fig.suptitle(title, fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_effective_lengths(df: pd.DataFrame, path: Path):
    """z0/H and zd/H actually imposed by every prescription (wind-scheme independent)."""
    sub = df[df.wind_type == next(iter(WIND_TYPES))]
    z0 = sub.pivot_table(index='variant', columns='lcz',
                         values='z0_over_h').reindex(VARIANT_ORDER)
    zd = sub.pivot_table(index='variant', columns='lcz',
                         values='zd_over_h').reindex(VARIANT_ORDER)
    fig, axes = plt.subplots(1, 2, figsize=(13, 5))
    x = np.arange(len(VARIANT_ORDER))
    w = 0.35
    for k, lcz_tag in enumerate(LCZ):
        axes[0].bar(x + (k - 0.5) * w, z0[lcz_tag], w, label=LCZ[lcz_tag]['label'])
        axes[1].bar(x + (k - 0.5) * w, zd[lcz_tag], w, label=LCZ[lcz_tag]['label'])
    for ax, ttl, ylab in ((axes[0], 'Effective roughness length', 'z0 / H (-)'),
                          (axes[1], 'Effective displacement height', 'zd / H (-)')):
        ax.set_xticks(x)
        ax.set_xticklabels(VARIANT_ORDER, fontsize=7.5, rotation=20, ha='right')
        ax.set_title(ttl, fontsize=10)
        ax.set_ylabel(ylab)
        ax.grid(True, axis='y', alpha=0.3)
        ax.legend(fontsize=8)
    fig.suptitle('Aerodynamic parameters imposed by urb_z0_town / urb_zd_town', fontsize=11)
    fig.tight_layout(rect=[0, 0, 1, 0.93])
    fig.savefig(path, dpi=150)
    plt.close(fig)


def write_readme(out_root: Path, base_nml: Path, forcing_nml: Path, df: pd.DataFrame):
    """Describe the experiment next to the data."""
    txt = f"""# Sensitivity of U_TOP and U_CANYON to the displacement height (zd)

Generated by `python_tests/sensitivity_zd.py` (TEB-MSU). The simulation data are kept here.

## Configuration

* Forcing: `{forcing_nml}` (Moscow ERA5, hlev_teb = 10 m above the roof)
* Base model namelist: `{base_nml}` (configuration of `run_on_windows.ipynb`)
* Varied: (`urb_z0_town`, `urb_zd_town`) x `teb_itype_wind` x urban morphology (LCZ)
* Number of cases: {len(df)}

Variants of `urb_z0_town` / `urb_zd_town` (a scheme name may be given in either
entry or in both of them; all other forms are a value in m, `<value>H` or `H/<n>`):

| tag | namelist value | meaning |
| --- | --- | --- |
""" + '\n'.join(f'| `{t}` | `{v[0]}` | {v[1]} |'
                for t, v in list(Z0_VARIANTS.items()) + list(ZD_VARIANTS.items())) + f"""

Case matrix ((z0, zd) pairs); the z0 tag appears in the case name only when z0 is
not the reference value, e.g. `LCZ2_zdMACD_w0` is LCZ 2 with z0 = 0.1H and
zd = Macdonald (staggered), and `LCZ2_z0MACD_zdMACD_w0` is LCZ 2 with both z0 and
zd from the Macdonald (staggered) scheme:

| `urb_z0_town` | `urb_zd_town` | variant |
| --- | --- | --- |
""" + '\n'.join(f'| `{Z0_VARIANTS[t0][0]}` | `{ZD_VARIANTS[tz][0]}` | {lab} |'
                for t0, tz, lab in CASE_MATRIX) + f"""

(zd = 2/3 H is written as `H/1.5`, because the namelist parser accepts
`H/<n>`, `<value>H`, `<value>m` or a plain number.)

Note: with the default canyon-wind scheme (`teb_itype_wind = 0`) the canyon wind
depends on the canyon aspect ratio `urb_h2w` (wake factor and `exp(-H/W/4)`),
while the Wang scheme (`teb_itype_wind = 1`, `WIND_CALCULATION_WANG`) uses the
frontal area index and the building height instead, so `urb_h2w` affects the
canyon wind only with `teb_itype_wind = 0`.

If a morphology parameter used below changes (for instance H/W of an LCZ), the
namelist of the affected cases differs from the stored one and those cases are
re-run automatically instead of being skipped.

Local climate zones:

| tag | description | H (m) | lambda_p | lambda_f | H/W |
| --- | --- | --- | --- | --- | --- |
""" + '\n'.join(
        f'| `{t}` | {p["label"]} | {p["h_bld"]} | {p["fr_bld"]} | {p["fai"]} | {p["h2w"]} |'
        for t, p in LCZ.items()) + """

## Files

* `namelists/<case>.nml` - namelist of every case
* `output_<case>/` - full model output (`TEB_output.csv`, columns `WIND_TOP` = U_TOP,
  `U_CANYON`, ...; old runs keep the legacy per-variable `<NAME>.txt` files)
* `logs/<case>.log` - model log; contains the effective z0 and zd
* `summary_statistics.csv` - mean/std/percentiles of U_TOP and U_CANYON per case
* `plots/mean_winds.png`, `plots/attenuation.png` - summary figures
* `plots/effective_lengths.png` - the effective z0/H and zd/H of every variant

## Re-running

```
python python_tests/sensitivity_zd.py            # run missing cases + statistics
python python_tests/sensitivity_zd.py --force    # re-run everything
python python_tests/sensitivity_zd.py --skip-run # statistics and plots only
```
"""
    (out_root / 'README.md').write_text(txt, encoding='utf-8')


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

DEFAULT_WORK_DIR = r'D:\TEB_work'


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description='Sensitivity of U_TOP and U_CANYON to the zd prescription (TEB-MSU)')
    ap.add_argument('--work-dir', default=DEFAULT_WORK_DIR,
                    help='working directory of run_on_windows.ipynb (default: %(default)s)')
    ap.add_argument('--site', default='Moscow', help='site name (default: %(default)s)')
    ap.add_argument('--base-namelist', default=None,
                    help='model parameters namelist to start from '
                         '(default: <site>/params_CTRL.nml, else <repo>/namelist/namelist.nml)')
    ap.add_argument('--forcing-nml', default=None,
                    help='forcing namelist (default: <site>/forcing_ERA5/namelist_forcing.nml)')
    ap.add_argument('--out-root', default=None,
                    help='directory of the experiment (default: <site>/sensitivity_zd)')
    ap.add_argument('--exe', default=None,
                    help='model executable (default: <repo>/build/TEB_offline.exe)')
    ap.add_argument('--only', default=None, help='comma separated list of case names')
    ap.add_argument('--skip-run', action='store_true',
                    help='do not run the model, only (re)build statistics and plots')
    ap.add_argument('--force', action='store_true',
                    help='run the cases even if their output already exists')
    ap.add_argument('--list', action='store_true', help='list the cases and exit')
    args = ap.parse_args(argv)

    work = Path(args.work_dir)
    base = Path(args.base_namelist) if args.base_namelist else (work / args.site / 'params_CTRL.nml')
    if not base.is_file():
        base = MODEL_DIR / 'namelist' / 'namelist.nml'
    forcing_nml = (Path(args.forcing_nml) if args.forcing_nml
                   else work / args.site / 'forcing_ERA5' / 'namelist_forcing.nml')
    out_root = Path(args.out_root) if args.out_root else work / args.site / 'sensitivity_zd'
    exe = Path(args.exe) if args.exe else MODEL_DIR / 'build' / 'TEB_offline.exe'

    all_cases = cases()
    if args.list:
        for case, lcz_tag, wind_type, z0_tag, zd_tag in all_cases:
            print(f'{case:<26} {LCZ[lcz_tag]["label"]:<42} '
                  f'z0={Z0_VARIANTS[z0_tag][0]:<16} zd={ZD_VARIANTS[zd_tag][0]:<16} '
                  f'itype_wind={wind_type}')
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
    print('TEB-MSU sensitivity of U_TOP / U_CANYON to the displacement height')
    print('  model          :', exe)
    print('  forcing nml    :', forcing_nml)
    print('  base nml       :', base)
    print('  output root    :', out_root)
    print('  cases          :', len(all_cases))
    print('  variants       :', len(CASE_MATRIX), '-', '; '.join(VARIANT_ORDER))
    print('==================================================================')

    for case, lcz_tag, wind_type, z0_tag, zd_tag in all_cases:
        nml_path = out_root / 'namelists' / f'{case}.nml'
        out_dir = out_root / f'output_{case}'
        log_file = out_root / 'logs' / f'{case}.log'
        previous = read_text(nml_path)
        build_namelist(base, lcz_tag, wind_type, z0_tag, zd_tag, nml_path)
        # a case whose stored namelist differs from the current one is stale
        # (e.g. after a change of the morphology of its LCZ) and is re-run
        unchanged = (previous == read_text(nml_path))
        done = (out_dir / 'TEB_output.csv').is_file() or (out_dir / 'U_CANYON.txt').is_file()
        if args.skip_run or (done and unchanged and not args.force):
            print(f'  [skip] {case}')
            continue
        if done and not unchanged:
            print(f'  [stale] {case}  (namelist changed, re-running)')
        rc = run_case(exe, forcing_nml, nml_path, out_dir, log_file)
        print(f'  [run ] {case}  (return code {rc})')
        if rc != 0:
            print(f'         see {log_file}')

    df = collect_statistics(all_cases, out_root, forcing_nml)
    out_root.mkdir(parents=True, exist_ok=True)
    stats_csv = out_root / 'summary_statistics.csv'
    df.to_csv(stats_csv, index=False, float_format='%.6f')

    plots = out_root / 'plots'
    plots.mkdir(parents=True, exist_ok=True)
    plot_bars(df,
              [('u_top_mean', 'U_TOP (roof level)', '#1f77b4'),
               ('u_canyon_mean', 'U_CANYON (canyon)', '#ff7f0e')],
              'wind speed (m/s)', 'Mean wind speed vs displacement height prescription',
              plots / 'mean_winds.png')
    plot_bars(df,
              [('u_top_over_forcing', 'U_TOP / V_forcing', '#1f77b4'),
               ('u_canyon_over_forcing', 'U_CANYON / V_forcing', '#ff7f0e')],
              'U / V_forcing (-)', 'Wind attenuation vs displacement height prescription',
              plots / 'attenuation.png')
    plot_effective_lengths(df, plots / 'effective_lengths.png')
    write_readme(out_root, base, forcing_nml, df)

    pd.set_option('display.width', 200)
    for col, ttl in (('z0_effective', 'Effective z0 (m)'),
                     ('zd_effective', 'Effective zd (m)')):
        print(f'\n{ttl}:')
        print(df.pivot_table(index='variant', columns='lcz', values=col)
              .reindex(VARIANT_ORDER).round(4).to_string())
    for wind_type in WIND_TYPES:
        sub = df[df.wind_type == wind_type]
        for col, ttl in (('u_top_mean', 'Mean U_TOP (m/s)'),
                         ('u_canyon_mean', 'Mean U_CANYON (m/s)'),
                         ('canyon_over_top', 'U_CANYON / U_TOP')):
            print(f'\n{ttl}, teb_itype_wind = {wind_type}:')
            print(sub.pivot_table(index='variant', columns='lcz', values=col)
                  .reindex(VARIANT_ORDER).round(3).to_string())

    print('\nStatistics :', stats_csv)
    print('Plots      :', plots)
    print('Data kept  :', out_root)
    return 0


if __name__ == '__main__':
    sys.exit(main())

