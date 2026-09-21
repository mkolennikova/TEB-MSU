#!/usr/bin/env python
"""
Sensitivity of the diagnostic garden proxy to PHU (surface relative humidity)
and z0 (surface roughness length).

The Bowen proxy depends only on SW, so it is a single reference; the diagnostic
scheme (veg_surf_balance) is run over a grid of (PHU, z0) and the day-time
(and all-time) fluxes and surface temperature are tabulated.

PHU controls the latent flux: larger PHU -> stronger evaporation -> cooler
surface -> possibly negative H (the "oasis" regime). z0 controls the aerodynamic
conductance Ca = (k/ln(zref/z0))^2 * V: larger z0 -> stronger surface/air
coupling -> larger |H| and |LE|.

Output (kept, not deleted):
  <out-root>/summary_sensitivity.csv   one row per (PHU, z0) + metrics
  <out-root>/plots/sens_phu_curves.png day-mean H/LE/TS-Ta vs PHU, per z0
  <out-root>/plots/sens_z0_curves.png  day-mean H/LE/TS-Ta vs z0, per PHU
  <out-root>/plots/sens_heatmap_H.png  heatmap of day-mean H (PHU x z0)
  <out-root>/plots/sens_heatmap_LE.png heatmap of day-mean LE (PHU x z0)
  <out-root>/README.md                 description of the experiment

Usage
-----
    python python_tests/garden_proxy_sensitivity.py
    python python_tests/garden_proxy_sensitivity.py --phu-list 0.2,0.4,0.6,0.8
    python python_tests/garden_proxy_sensitivity.py --z0-list 0.01,0.1,1.0
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
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
PYTHON_DIR = HERE.parent / 'python'    # shared libraries of the repository
if str(PYTHON_DIR) not in sys.path:
    sys.path.append(str(PYTHON_DIR))

import garden_proxy_compare as g  # noqa: E402  (reuse thermo + scheme functions)

DEFAULT_PHU = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
DEFAULT_Z0 = [0.01, 0.03, 0.1, 0.3, 1.0]


def parse_list(text, default):
    if text is None:
        return list(default)
    return [float(x) for x in text.split(',')]


def load_forcing(csv_path: Path):
    c = g.thermo_constants()
    forc = g.read_era5(csv_path)
    Ta = forc['Forc_TA'].to_numpy(dtype=float)
    qa = forc['Forc_QA'].to_numpy(dtype=float)
    V = forc['Forc_WIND'].to_numpy(dtype=float)
    SW = (forc['Forc_DIR_SW'] + forc['Forc_SCA_SW']).to_numpy(dtype=float)
    LW = forc['Forc_LW'].to_numpy(dtype=float)
    P = forc['Forc_PS'].to_numpy(dtype=float)
    Tv = Ta * (1.0 + 0.61 * qa)
    rho = P / (c['XRD'] * Tv)
    return c, forc, SW, LW, Ta, qa, P, rho, V


def run_one(c, SW, LW, Ta, qa, P, rho, V, phu, z0, zref=10.0, vmin=0.5):
    RN, H, LE, Gc, Ts = g.veg_surf_balance(SW, LW, Ta, qa, P, rho, V, c,
                                            phu=phu, z0=z0, zref=zref,
                                            vmin=vmin)
    day = SW > 0.0
    dTS = Ts - Ta
    return dict(
        phu=phu, z0=z0,
        H_all=float(np.mean(H)), LE_all=float(np.mean(LE)),
        RN_all=float(np.mean(RN)),
        dTS_all=float(np.mean(dTS)),
        H_day=float(np.mean(H[day])), LE_day=float(np.mean(LE[day])),
        RN_day=float(np.mean(RN[day])),
        dTS_day=float(np.mean(dTS[day])),
        H_neg_frac=float(np.mean(H < 0.0)),
        H_neg_frac_day=float(np.mean(H[day] < 0.0)),
        LE_gt_RN_frac=float(np.mean(LE > RN)),
        LE_gt_RN_frac_day=float(np.mean(LE[day] > RN[day])),
    )


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--csv',
                    default='D:/TEB_work/Moscow/forcing_ERA5/era5_forcing_2022-08-01_2022-09-01.csv',
                    help='ERA5 forcing CSV (default: %(default)s)')
    ap.add_argument('--out-root',
                    default='D:/TEB_work/Moscow/garden_proxy_sensitivity',
                    help='output directory (default: %(default)s)')
    ap.add_argument('--phu-list', default=None,
                    help='comma-separated PHU values (default: 0.2..1.0)')
    ap.add_argument('--z0-list', default=None,
                    help='comma-separated z0 values in m (default: 0.01..1.0)')
    ap.add_argument('--zref', type=float, default=10.0,
                    help='reference height (m), default %(default)s')
    ap.add_argument('--vmin', type=float, default=0.5,
                    help='minimum wind speed for the exchange coefficients (m/s), default %(default)s')
    args = ap.parse_args(argv)

    csv_path = Path(args.csv)
    if not csv_path.is_file():
        print(f'ERROR: no such forcing file: {csv_path}')
        return 2

    phu_list = parse_list(args.phu_list, DEFAULT_PHU)
    z0_list = parse_list(args.z0_list, DEFAULT_Z0)

    out_root = Path(args.out_root)
    out_root.mkdir(parents=True, exist_ok=True)
    (out_root / 'plots').mkdir(parents=True, exist_ok=True)

    c, forc, SW, LW, Ta, qa, P, rho, V = load_forcing(csv_path)

    # Bowen reference (independent of PHU and z0)
    RN_b, H_b, LE_b, G_b = g.bowen_fluxes(SW)
    day = SW > 0.0
    H_bowen_day = float(np.mean(H_b[day]))
    LE_bowen_day = float(np.mean(LE_b[day]))

    rows = []
    for phu in phu_list:
        for z0 in z0_list:
            rows.append(run_one(c, SW, LW, Ta, qa, P, rho, V, phu, z0,
                                zref=args.zref, vmin=args.vmin))
    df = pd.DataFrame(rows)
    df.to_csv(out_root / 'summary_sensitivity.csv', index=False,
              float_format='%.6f')

    print('=' * 78)
    print(f'PHU grid : {phu_list}')
    print(f'z0 grid  : {z0_list} m')
    print(f'Bowen reference (day mean): H = {H_bowen_day:.1f}, '
          f'LE = {LE_bowen_day:.1f} W/m2')
    print('Summary written to:', out_root / 'summary_sensitivity.csv')
    print('=' * 78)

    plots = out_root / 'plots'

    # ------------------------------------------------------------------
    # curves: metric vs PHU, one line per z0
    # ------------------------------------------------------------------
    def curves(x_col, y_cols, xlabel, titles, fname):
        n = len(y_cols)
        fig, axes = plt.subplots(1, n, figsize=(5.5 * n, 4.5))
        if n == 1:
            axes = [axes]
        for ax, (ycol, title) in zip(axes, zip(y_cols, titles)):
            for z0 in z0_list:
                sub = df[df.z0 == z0].sort_values('phu')
                ax.plot(sub[x_col], sub[ycol], marker='o', ms=4,
                        label=f'z0 = {z0:g} m')
            ax.set_xlabel(xlabel)
            ax.set_title(title)
            ax.grid(alpha=.3)
            ax.legend(fontsize=8)
        fig.suptitle('Diagnostic garden proxy sensitivity')
        fig.tight_layout()
        fig.savefig(plots / fname, dpi=130)
        plt.close(fig)

    curves('phu',
           ['H_day', 'LE_day', 'dTS_day'],
           'PHU (-)',
           ['day mean H (W/m2)', 'day mean LE (W/m2)', 'day mean TS - Ta (K)'],
           'sens_phu_curves.png')

    curves('z0',
           ['H_day', 'LE_day', 'dTS_day'],
           'z0 (m)',
           ['day mean H (W/m2)', 'day mean LE (W/m2)', 'day mean TS - Ta (K)'],
           'sens_z0_curves.png')

    # ------------------------------------------------------------------
    # heatmaps over (PHU, z0)
    # ------------------------------------------------------------------
    phu_u = np.array(sorted(df.phu.unique()))
    z0_u = np.array(sorted(df.z0.unique()))
    PHU, Z0 = np.meshgrid(phu_u, z0_u, indexing='ij')

    def heatmap(col, title, fname, cmap):
        mat = df.pivot_table(index='phu', columns='z0', values=col).reindex(
            index=phu_u, columns=z0_u).to_numpy(dtype=float)
        fig, ax = plt.subplots(figsize=(6.5, 5))
        vmax = np.nanmax(np.abs(mat))
        im = ax.pcolormesh(Z0, PHU, mat, cmap=cmap, shading='auto',
                           vmin=-vmax, vmax=vmax)
        fig.colorbar(im, ax=ax, label=title)
        ax.set_xscale('log')
        ax.set_xticks(z0_u)
        ax.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
        ax.set_xlabel('z0 (m)')
        ax.set_ylabel('PHU (-)')
        ax.set_title(title)
        for i in range(mat.shape[0]):
            for j in range(mat.shape[1]):
                ax.text(Z0[i, j], PHU[i, j], f'{mat[i, j]:.0f}',
                        ha='center', va='center', fontsize=7,
                        color='white' if abs(mat[i, j]) > 0.5 * vmax else 'k')
        fig.tight_layout()
        fig.savefig(plots / fname, dpi=130)
        plt.close(fig)

    heatmap('H_day', 'day mean H (W/m2)', 'sens_heatmap_H.png', 'RdBu_r')
    heatmap('LE_day', 'day mean LE (W/m2)', 'sens_heatmap_LE.png', 'viridis')

    # ------------------------------------------------------------------
    # README
    # ------------------------------------------------------------------
    md = []
    md.append('# Garden proxy sensitivity to PHU and z0')
    md.append('')
    md.append('The diagnostic garden scheme (`veg_surf_balance`) is run over a'
              ' grid of surface relative humidity PHU and roughness length z0 on'
              ' the Moscow ERA5 forcing (`%s`).' % csv_path)
    md.append('')
    md.append('- `phu_list` = %s' % phu_list)
    md.append('- `z0_list` = %s m' % z0_list)
    md.append('- `zref` = %g m, `Vmin` = %g m/s' % (args.zref, args.vmin))
    md.append('- Bowen reference (day mean): H = %.1f, LE = %.1f W/m2'
              % (H_bowen_day, LE_bowen_day))
    md.append('')
    md.append('## Reading the results')
    md.append('')
    md.append('* `H_day`/`LE_day` - day-time (SW > 0) mean turbulent fluxes')
    md.append('* `dTS_day` - day-time mean surface-air temperature difference')
    md.append('* `H_neg_frac_day` - fraction of day steps with negative H (oasis'
              ' regime)')
    md.append('* `LE_gt_RN_frac_day` - fraction of day steps with LE > RN (latent'
              ' demand exceeds radiation)')
    md.append('')
    md.append('## Files')
    md.append('')
    md.append('- `summary_sensitivity.csv` - one row per (PHU, z0)')
    md.append('- `plots/sens_phu_curves.png` - metrics vs PHU, per z0')
    md.append('- `plots/sens_z0_curves.png` - metrics vs z0, per PHU')
    md.append('- `plots/sens_heatmap_H.png` / `sens_heatmap_LE.png` - heatmaps')
    md.append('')
    (out_root / 'README.md').write_text('\n'.join(md), encoding='utf-8')

    print('Plots and README written to:', out_root)
    for f in sorted(plots.glob('*.png')):
        print('  ', f)
    return 0


if __name__ == '__main__':
    sys.exit(main())


