#!/usr/bin/env python
"""
Stand-alone comparison of the two garden proxy schemes (no canyon, no Fortran).

Purpose
-------
Run the two garden surface schemes side by side on the Moscow ERA5 forcing and
compare the turbulent heat fluxes H and LE. The surface temperature Ts of the
diagnostic scheme is also reported (the Bowen proxy does not carry a surface
temperature).

The two schemes compared are:

A. Bowen proxy (the current ``src_proxi_SVAT/garden.F90``): a fixed Bowen ratio
   driven by the short-wave radiation only::

       RN = (1 - 0.15) * SW
       H  = 0.2 * RN
       LE = 0.8 * RN
       G  = 0             (conduction neglected)

B. Diagnostic proxy (the proposed ``VEG_SURF_BALANCE``, see
   ``TEB_Ru_garden_diagnostic_scheme.md``): a diagnostic surface energy balance
   with no heat flux into the soil::

       Rn = (1-alb)*SW + emis*(LW - sigma*Ts**4)
       H  = rho*cp*Ca*(Ts - Ta)
       LE = rho*Lv*Ca*(PHU*qsat(Ts) - qa)
       G  = 0

   solved for Ts by Newton iteration on the linearised sigma*Ts**4 and qsat(Ts).
   A minimum wind speed (vmin = 0.5 m/s) is used for Ca so that the surface is
   never decoupled from the air in calm conditions.

The saturation specific humidity qsat(Ts) and its temperature derivative are
computed with the exact formulas of ``MODE_THERMOS::QSAT`` / ``DQSAT`` (integrated
Clausius-Clapeyron with the vapor-pressure -> specific-humidity conversion), so
that this script is a numerical reference for the future Fortran implementation.

Input
-----
One ERA5-forcing CSV per hour (columns ``valid_time, Forc_TA, Forc_QA,
Forc_WIND, Forc_DIR_SW, Forc_SCA_SW, Forc_LW, Forc_PS, ...``).

The air density is not part of the ERA5 forcing: it is reconstructed from the
ideal gas law rho = p / (Rd * Tv), Tv = Ta * (1 + 0.61 * qa), Rd = 287.05 J/kg/K.

Usage
-----
    python python/garden_proxy_compare.py
    python python/garden_proxy_compare.py --csv D:/TEB_work/Moscow/forcing_ERA5/era5_forcing_2022-08-01_2022-09-01.csv
    python python/garden_proxy_compare.py --zref 10.0 --phu 0.8 --vmin 0.5
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np
import pandas as pd

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parent


# ---------------------------------------------------------------------------
# Physical constants (values from MODD_CSTS / INI_CSTS, reproduced verbatim)
# ---------------------------------------------------------------------------

def thermo_constants() -> dict:
    """Constants of MODD_CSTS / INI_CSTS (double precision, as real(8))."""
    XAVOGADRO = 6.0221367e23
    XBOLTZ = 1.380658e-23
    XMV = 18.0153e-3
    XMD = 28.9644e-3

    c = {}
    c['XKARMAN'] = 0.4
    c['XSTEFAN'] = 5.6697e-8
    c['XRD'] = 287.05
    c['XRV'] = XAVOGADRO * XBOLTZ / XMV
    c['XCPD'] = 1005.0
    c['XCPV'] = 4.0 * c['XRV']
    c['XCL'] = 4.218e3        # liquid water heat capacity
    c['XCI'] = 2.106e3        # ice heat capacity
    c['XTT'] = 273.16
    c['XLVTT'] = 2.5008e6     # latent heat of vaporization
    c['XLSTT'] = 2.8345e6     # latent heat of sublimation
    c['XESTT'] = 611.14
    # es(T) = exp(a - b/T - g ln T) ; water branch
    c['XGAMW'] = (c['XCL'] - c['XCPV']) / c['XRV']
    c['XBETAW'] = (c['XLVTT'] / c['XRV']) + (c['XGAMW'] * c['XTT'])
    c['XALPW'] = math.log(c['XESTT']) + (c['XBETAW'] / c['XTT']) \
        + (c['XGAMW'] * math.log(c['XTT']))
    # ice branch (CQSAT = 'NEW' switches to it for T <= XTT)
    c['XGAMI'] = (c['XCI'] - c['XCPV']) / c['XRV']
    c['XBETAI'] = (c['XLSTT'] / c['XRV']) + (c['XGAMI'] * c['XTT'])
    c['XALPI'] = math.log(c['XESTT']) + (c['XBETAI'] / c['XTT']) \
        + (c['XGAMI'] * math.log(c['XTT']))
    return c


# ---------------------------------------------------------------------------
# Saturation thermodynamics (exact MODE_THERMOS::QSAT / DQSAT)
# ---------------------------------------------------------------------------

def _sat_coefficients(T, c):
    """(alpha, beta, gamma) of es(T) = exp(a - b/T - g ln T), with ice branch."""
    T = np.asarray(T, dtype=float)
    alpha = np.full_like(T, c['XALPW'])
    beta = np.full_like(T, c['XBETAW'])
    gamm = np.full_like(T, c['XGAMW'])
    ice = T <= c['XTT']
    if ice.any():
        alpha = np.where(ice, c['XALPI'], alpha)
        beta = np.where(ice, c['XBETAI'], beta)
        gamm = np.where(ice, c['XGAMI'], gamm)
    return alpha, beta, gamm


def esat(T, c):
    """Saturation water-vapor pressure (Pa), MODE_THERMOS::PSAT."""
    T = np.asarray(T, dtype=float)
    alpha, beta, gamm = _sat_coefficients(T, c)
    return np.exp(alpha - beta / T - gamm * np.log(T))


def qsat(T, P, c):
    """Saturation specific humidity (kg/kg), MODE_THERMOS::QSATW_1D."""
    T = np.asarray(T, dtype=float)
    P = np.asarray(P, dtype=float)
    es = esat(T, c)
    z1 = es / P
    z2 = c['XRD'] / c['XRV']
    return z2 * z1 / (1.0 + (z2 - 1.0) * z1)


def dqsat_dT(T, P, qs, c):
    """d(qsat)/dT (kg/kg/K), MODE_THERMOS::DQSATW_O_DT_1D."""
    T = np.asarray(T, dtype=float)
    P = np.asarray(P, dtype=float)
    qs = np.asarray(qs, dtype=float)
    _, beta, gamm = _sat_coefficients(T, c)
    z1 = c['XRD'] / c['XRV']
    es = P / (1.0 + z1 * (1.0 / qs - 1.0))       # es recovered from qs
    dpsat = beta / T**2 - gamm / T               # d(ln es)/dT
    return dpsat * qs / (1.0 + (z1 - 1.0) * es / P)


# ---------------------------------------------------------------------------
# The two schemes
# ---------------------------------------------------------------------------

def bowen_fluxes(SW, alb=0.15, br=0.25):
    """Scheme A: fixed Bowen ratio proxy. Returns (RN, H, LE, G)."""
    SW = np.asarray(SW, dtype=float)
    RN = (1.0 - alb) * SW
    H = br * RN
    LE = (1.0 - br) * RN
    G = np.zeros_like(SW)
    return RN, H, LE, G


def veg_surf_balance(SW, LW, Ta, qa, P, rho, V, c, alb=0.15, emis=0.98,
                     phu=0.8, z0=0.1, zref=10.0, vmin=0.5,
                     niter=8, dt_step=5.0, ts_min=230.0,
                     ts_max=350.0, h_max=1000.0, le_max=1000.0, le_min=-200.0):
    """Scheme B: diagnostic surface energy balance solved for Ts by Newton.

    No heat flux into the soil (the garden is a diagnostic proxy without a soil
    reservoir), so the balance is ``Rn = H + LE``. A minimum wind speed `vmin`
    is used for the exchange coefficients so that the surface is never decoupled
    from the air (Ts is then anchored by the turbulent fluxes alone).

    Returns (RN, H, LE, G, Ts); G is identically zero.
    """
    SW = np.asarray(SW, dtype=float)
    LW = np.asarray(LW, dtype=float)
    Ta = np.asarray(Ta, dtype=float)
    qa = np.asarray(qa, dtype=float)
    P = np.asarray(P, dtype=float)
    rho = np.asarray(rho, dtype=float)
    V = np.asarray(V, dtype=float)

    # neutral log-profile aerodynamic conductance with a minimum wind speed
    k = c['XKARMAN']
    V = np.maximum(V, vmin)
    Ca = np.where(zref > z0, (k / np.log(zref / z0))**2 * V, 0.0)

    SWnet = (1.0 - alb) * SW
    LWin = emis * LW

    Ts = np.clip(Ta, ts_min, ts_max)
    for _ in range(niter):
        qs = qsat(Ts, P, c)
        dq = dqsat_dT(Ts, P, qs, c)
        sigT4 = c['XSTEFAN'] * Ts**4
        # residual F(Ts) = net radiation - H - LE
        F = (SWnet + LWin - emis * sigT4
             - rho * c['XCPD'] * Ca * (Ts - Ta)
             - rho * c['XLVTT'] * Ca * (phu * qs - qa))
        # denom = -F'(Ts) > 0
        denom = (4.0 * emis * c['XSTEFAN'] * Ts**3
                 + rho * c['XCPD'] * Ca
                 + rho * c['XLVTT'] * Ca * phu * dq)
        delta = np.where(denom > 1.0e-8, F / denom, 0.0)
        delta = np.clip(delta, -dt_step, dt_step)
        Ts = Ts + delta
        Ts = np.clip(Ts, ts_min, ts_max)

    # numerical safety bound only (no |Ts-Ta| limiter)
    Ts = np.clip(Ts, ts_min, ts_max)

    qs = qsat(Ts, P, c)
    H = rho * c['XCPD'] * Ca * (Ts - Ta)
    LE = rho * c['XLVTT'] * Ca * (phu * qs - qa)
    RN = SWnet + emis * (LW - c['XSTEFAN'] * Ts**4)

    H = np.clip(H, -h_max, h_max)
    LE = np.clip(LE, le_min, le_max)
    G = np.zeros_like(SW)          # no heat flux into the soil

    return RN, H, LE, G, Ts


# ---------------------------------------------------------------------------
# I/O helpers
# ---------------------------------------------------------------------------

def read_era5(csv_path: Path) -> pd.DataFrame:
    """Read the ERA5 forcing CSV indexed by valid_time."""
    df = pd.read_csv(csv_path, parse_dates=['valid_time'])
    df = df.set_index('valid_time')
    return df


def stats_of(x: np.ndarray) -> dict:
    x = np.asarray(x, dtype=float)
    x = x[np.isfinite(x)]
    if x.size == 0:
        return dict(n=0, mean=np.nan, std=np.nan, min=np.nan, max=np.nan,
                    p05=np.nan, p50=np.nan, p95=np.nan)
    return dict(n=int(x.size), mean=float(x.mean()), std=float(x.std()),
                min=float(x.min()), max=float(x.max()),
                p05=float(np.percentile(x, 5)), p50=float(np.percentile(x, 50)),
                p95=float(np.percentile(x, 95)))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--csv',
                    default='D:/TEB_work/Moscow/forcing_ERA5/era5_forcing_2022-08-01_2022-09-01.csv',
                    help='ERA5 forcing CSV (default: %(default)s)')
    ap.add_argument('--out-root',
                    default='D:/TEB_work/Moscow/garden_proxy_compare',
                    help='output directory (default: %(default)s)')
    ap.add_argument('--zref', type=float, default=10.0,
                    help='reference height for the wind (m), default %(default)s')
    ap.add_argument('--phu', type=float, default=0.8,
                    help='surface relative humidity of the garden, default %(default)s')
    ap.add_argument('--vmin', type=float, default=0.5,
                    help='minimum wind speed for the exchange coefficients (m/s), default %(default)s')
    args = ap.parse_args(argv)

    csv_path = Path(args.csv)
    if not csv_path.is_file():
        print(f'ERROR: no such forcing file: {csv_path}')
        return 2

    out_root = Path(args.out_root)
    out_root.mkdir(parents=True, exist_ok=True)
    (out_root / 'plots').mkdir(parents=True, exist_ok=True)

    c = thermo_constants()
    forc = read_era5(csv_path)

    need = ['Forc_TA', 'Forc_QA', 'Forc_WIND', 'Forc_DIR_SW', 'Forc_SCA_SW',
            'Forc_LW', 'Forc_PS']
    missing = [k for k in need if k not in forc.columns]
    if missing:
        print(f'ERROR: missing forcing columns: {missing}')
        return 2

    Ta = forc['Forc_TA'].to_numpy(dtype=float)
    qa = forc['Forc_QA'].to_numpy(dtype=float)
    V = forc['Forc_WIND'].to_numpy(dtype=float)
    SW = (forc['Forc_DIR_SW'] + forc['Forc_SCA_SW']).to_numpy(dtype=float)
    LW = forc['Forc_LW'].to_numpy(dtype=float)
    P = forc['Forc_PS'].to_numpy(dtype=float)

    # air density from the ideal gas law (the ERA5 file has no RHOA column)
    Tv = Ta * (1.0 + 0.61 * qa)
    rho = P / (c['XRD'] * Tv)

    # scheme A
    RN_b, H_b, LE_b, G_b = bowen_fluxes(SW)

    # scheme B
    RN_d, H_d, LE_d, G_d, Ts_d = veg_surf_balance(
        SW, LW, Ta, qa, P, rho, V, c, zref=args.zref,
        phu=args.phu, vmin=args.vmin)

    TS_minus_Ta = Ts_d - Ta

    out = pd.DataFrame({
        'SW': SW, 'LW': LW, 'Ta': Ta, 'qa': qa, 'V': V, 'rho': rho,
        'H_bowen': H_b, 'LE_bowen': LE_b,
        'H_diag': H_d, 'LE_diag': LE_d,
        'TS_diag': Ts_d, 'TS_minus_Ta': TS_minus_Ta, 'RN_diag': RN_d, 'G_diag': G_d,
    }, index=forc.index)
    out.index.name = 'time'
    out.to_csv(out_root / 'garden_fluxes.csv', float_format='%.8f')

    # energy closure of the diagnostic scheme: RN = H + LE  (G = 0)
    resid = RN_d - (H_d + LE_d + G_d)
    print('=' * 78)
    print('Diagnostic scheme closure  max|RN - H - LE| = %.3e W/m2' % resid.max())
    print('Diagnostic scheme closure  mean|residual|    = %.3e W/m2'
          % np.abs(resid).mean())
    print('=' * 78)

    # ------------------------------------------------------------------
    # statistics: all / day (SW > 0) / night (SW == 0)
    # ------------------------------------------------------------------
    day = SW > 0.0
    night = ~day
    rows = []
    cols = {
        'H': ('H_bowen', 'H_diag'),
        'LE': ('LE_bowen', 'LE_diag'),
    }
    for var, (a, b) in cols.items():
        for period, m in (('all', slice(None)), ('day', day), ('night', night)):
            sa = stats_of(out[a].to_numpy(dtype=float)[m])
            sb = stats_of(out[b].to_numpy(dtype=float)[m])
            diff = out[b].to_numpy(dtype=float)[m] - out[a].to_numpy(dtype=float)[m]
            rows.append(dict(var=var, period=period,
                             bowen_mean=sa['mean'], bowen_min=sa['min'],
                             bowen_max=sa['max'], bowen_p50=sa['p50'],
                             diag_mean=sb['mean'], diag_min=sb['min'],
                             diag_max=sb['max'], diag_p50=sb['p50'],
                             diff_mean=float(np.nanmean(diff)),
                             diff_min=float(np.nanmin(diff)),
                             diff_max=float(np.nanmax(diff))))
    for var, key in (('RN', 'RN_diag'), ('G', 'G_diag'), ('TS', 'TS_diag')):
        s_all = stats_of(out[key].to_numpy(dtype=float))
        rows.append(dict(var=var, period='all', diag_mean=s_all['mean'],
                         diag_min=s_all['min'], diag_max=s_all['max'],
                         diag_p50=s_all['p50'], bowen_mean=np.nan,
                         bowen_min=np.nan, bowen_max=np.nan, bowen_p50=np.nan,
                         diff_mean=np.nan, diff_min=np.nan, diff_max=np.nan))
    # TS - Ta (surface vs forcing air temperature), all / day / night
    for period, m in (('all', slice(None)), ('day', day), ('night', night)):
        s = stats_of(TS_minus_Ta[m])
        rows.append(dict(var='TS-Ta', period=period,
                         diag_mean=s['mean'], diag_min=s['min'], diag_max=s['max'],
                         diag_p50=s['p50'], bowen_mean=np.nan,
                         bowen_min=np.nan, bowen_max=np.nan, bowen_p50=np.nan,
                         diff_mean=np.nan, diff_min=np.nan, diff_max=np.nan))
    summary = pd.DataFrame(rows)
    summary.to_csv(out_root / 'summary_garden_proxy.csv', index=False,
                   float_format='%.6f')

    # ------------------------------------------------------------------
    # plots
    # ------------------------------------------------------------------
    plots = out_root / 'plots'

    def diurnal(x):
        return pd.Series(x, index=out.index).groupby(out.index.hour).mean().to_numpy()

    # 1. monthly diurnal cycle
    fig, axes = plt.subplots(2, 2, figsize=(12, 9))
    ax = axes[0, 0]
    ax.plot(diurnal(H_b), label='Bowen (H = 0.2·RN)', color='#1f77b4')
    ax.plot(diurnal(H_d), label='Diagnostic', color='#d62728')
    ax.set_title('Sensible heat flux H (W/m2)')
    ax.set_xlabel('hour (local)'); ax.legend(); ax.grid(alpha=.3)

    ax = axes[0, 1]
    ax.plot(diurnal(LE_b), label='Bowen (LE = 0.8·RN)', color='#1f77b4')
    ax.plot(diurnal(LE_d), label='Diagnostic', color='#2ca02c')
    ax.set_title('Latent heat flux LE (W/m2)')
    ax.set_xlabel('hour (local)'); ax.legend(); ax.grid(alpha=.3)

    ax = axes[1, 0]
    ax.plot(diurnal(Ts_d), label='TS diagnostic', color='#d62728')
    ax.plot(diurnal(Ta), label='Ta (forcing)', color='#7f7f7f', ls='--')
    ax.set_title('Garden surface temperature TS (K)')
    ax.set_xlabel('hour (local)'); ax.legend(); ax.grid(alpha=.3)

    ax = axes[1, 1]
    ax.plot(diurnal(RN_d), label='RN', color='#1f77b4')
    ax.plot(diurnal(H_d + LE_d), label='H + LE', color='#d62728', ls='--')
    ax.set_title('Energy balance closure (W/m2)')
    ax.set_xlabel('hour (local)'); ax.legend(); ax.grid(alpha=.3)

    fig.suptitle('Garden proxy: Bowen vs diagnostic (Moscow ERA5, August 2022)')
    fig.tight_layout()
    fig.savefig(plots / 'garden_diurnal.png', dpi=130)
    plt.close(fig)

    # 2. night-time (SW == 0) time series of H and LE
    night_idx = out.index[night]
    fig, axes = plt.subplots(2, 1, figsize=(12, 7), sharex=True)
    axes[0].plot(out.index, H_b, label='Bowen', color='#1f77b4', lw=1)
    axes[0].plot(night_idx, H_d[night], label='Diagnostic (night)',
                 color='#d62728', lw=1.5)
    axes[0].axhline(0, color='k', lw=.5)
    axes[0].set_title('H: night-time long-wave cooling (W/m2)')
    axes[0].legend(); axes[0].grid(alpha=.3)

    axes[1].plot(out.index, LE_b, label='Bowen', color='#1f77b4', lw=1)
    axes[1].plot(night_idx, LE_d[night], label='Diagnostic (night)',
                 color='#2ca02c', lw=1.5)
    axes[1].axhline(0, color='k', lw=.5)
    axes[1].set_title('LE: night-time dew / condensation (W/m2)')
    axes[1].legend(); axes[1].grid(alpha=.3)

    fig.suptitle('Night response (SW = 0): Bowen = 0, diagnostic carries cooling/condensation')
    fig.tight_layout()
    fig.savefig(plots / 'garden_night.png', dpi=130)
    plt.close(fig)

    # 3. scatter Bowen vs diagnostic (day only)
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    axes[0].scatter(H_b[day], H_d[day], s=4, alpha=.4)
    lim = max(np.nanmax(np.abs(H_b[day])), np.nanmax(np.abs(H_d[day])))
    axes[0].plot([-lim, lim], [-lim, lim], 'k--', lw=.8)
    axes[0].set_xlabel('H Bowen (W/m2)'); axes[0].set_ylabel('H diagnostic (W/m2)')
    axes[0].grid(alpha=.3)

    axes[1].scatter(LE_b[day], LE_d[day], s=4, alpha=.4)
    lim = max(np.nanmax(np.abs(LE_b[day])), np.nanmax(np.abs(LE_d[day])))
    axes[1].plot([-lim, lim], [-lim, lim], 'k--', lw=.8)
    axes[1].set_xlabel('LE Bowen (W/m2)'); axes[1].set_ylabel('LE diagnostic (W/m2)')
    axes[1].grid(alpha=.3)

    fig.suptitle('Daytime (SW > 0) Bowen vs diagnostic')
    fig.tight_layout()
    fig.savefig(plots / 'garden_scatter.png', dpi=130)
    plt.close(fig)

    # 4. diagnostic surface temperature vs the reanalysis air temperature
    fig, axes = plt.subplots(2, 1, figsize=(12, 7), sharex=True)
    axes[0].plot(out.index, Ta, label='Ta (reanalysis air)', color='#7f7f7f', lw=1)
    axes[0].plot(out.index, Ts_d, label='TS (diagnostic surface)', color='#d62728', lw=1)
    axes[0].set_ylabel('temperature (K)')
    axes[0].legend(loc='upper right'); axes[0].grid(alpha=.3)
    axes[1].plot(out.index, TS_minus_Ta, label='TS - Ta', color='#1f77b4', lw=1)
    axes[1].axhline(0, color='k', lw=.5)
    axes[1].set_ylabel('TS - Ta (K)')
    axes[1].set_xlabel('time')
    axes[1].legend(loc='upper right'); axes[1].grid(alpha=.3)

    fig.suptitle('Diagnostic garden surface temperature vs reanalysis air temperature')
    fig.tight_layout()
    fig.savefig(plots / 'garden_ts_vs_ta.png', dpi=130)
    plt.close(fig)

    # ------------------------------------------------------------------
    # README
    # ------------------------------------------------------------------
    md = []
    md.append('# Garden proxy: Bowen vs diagnostic (stand-alone)')
    md.append('')
    md.append('Two garden surface schemes run on the Moscow ERA5 forcing'
              ' (`%s`), no canyon model.' % csv_path)
    md.append('')
    md.append('## Schemes')
    md.append('')
    md.append('- **Bowen** (`H_bowen`/`LE_bowen`): fixed Bowen ratio 0.25,'
              ' albedo 0.15, driven by SW only.')
    md.append('- **Diagnostic** (`H_diag`/`LE_diag`/`TS_diag`/`RN_diag`/`G_diag`):'
              ' closed energy balance solved for Ts by Newton.')
    md.append('')
    md.append('## Parameters of the diagnostic scheme')
    md.append('')
    md.append('| parameter | value |')
    md.append('|---|---|')
    md.append('| albedo | 0.15 |')
    md.append('| emissivity | 0.98 |')
    md.append('| PHU (surface rel. humidity) | %g |' % args.phu)
    md.append('| z0 (roughness) | 0.1 m |')
    md.append('| zref (reference height) | %g m |' % args.zref)
    md.append('| Vmin (minimum wind speed) | %g m/s |' % args.vmin)
    md.append('')
    md.append('## Closure (diagnostic scheme)')
    md.append('')
    md.append('`max|RN - H - LE| = %.3e W/m2`  (G = 0)' % resid.max())
    md.append('')
    md.append('## Files')
    md.append('')
    md.append('- `garden_fluxes.csv` - per-hour fluxes of both schemes')
    md.append('- `summary_garden_proxy.csv` - monthly statistics (all/day/night)')
    md.append('- `plots/garden_diurnal.png` - monthly diurnal cycle')
    md.append('- `plots/garden_night.png` - night-time (SW = 0) H and LE')
    md.append('- `plots/garden_scatter.png` - Bowen vs diagnostic scatter (day)')
    md.append('- `plots/garden_ts_vs_ta.png` - diagnostic TS vs reanalysis Ta')
    md.append('')
    (out_root / 'README.md').write_text('\n'.join(md), encoding='utf-8')

    print('Output written to:', out_root)
    print('  fluxes :', out_root / 'garden_fluxes.csv')
    print('  summary:', out_root / 'summary_garden_proxy.csv')
    print('  plots  :', plots)
    print('  report :', out_root / 'README.md')
    return 0


if __name__ == '__main__':
    sys.exit(main())




