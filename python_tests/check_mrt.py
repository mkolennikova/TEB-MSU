#!/usr/bin/env python
"""Verify width-averaged pedestrian MRT against a single-cell TEB offline CSV."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import numpy as np
import pandas as pd

SIGMA = 5.6697e-8
EPS = 0.97
ABS = 0.70
HEIGHT = 1.1
XUNDEF = 1.e19


def item(text, name, default=None):
    match = re.search(r'^\s*' + name + r'\s*=\s*([^,!/\n]+)', text, re.M | re.I)
    if match:
        return match[1].strip().strip("'\x22")
    if default is None:
        raise ValueError(f'Missing namelist item {name}')
    return default


def strip_view(distance_ratio):
    """Numerically integrate the local solid angle of a strip over positions."""
    nodes, weights = np.polynomial.legendre.leggauss(96)
    t = (nodes + 1.) / 2.
    # Symmetry gives integral_0^1 atan(x/r)/pi dx. Resolve the near-wall region.
    return np.dot(weights / 2., 4.*t**3 * np.arctan2(t**4, distance_ratio)) / np.pi


def sunlit_width(zenith, azimuth, height, ratio, direction, mode):
    daylight = zenith < np.pi / 2.
    frac = daylight.astype(float)
    if height <= HEIGHT or ratio == 0.:
        return frac
    shadow = (1. - HEIGHT/height) * ratio * np.tan(zenith[daylight])
    if mode.upper() == 'UNIF':
        # Integrate the illuminated width of individual oriented streets.
        limit = np.full_like(shadow, np.pi/2.)
        clipped = shadow > 1.
        limit[clipped] = np.arcsin(1./shadow[clipped])
        nodes, weights = np.polynomial.legendre.leggauss(16)
        angles = (nodes + 1.) * limit[:, None] / 2.
        frac[daylight] = limit/np.pi * ((1. - shadow[:, None]*np.sin(angles)) @ weights)
    else:
        cross = np.abs(np.sin(azimuth[daylight] - np.radians(direction)))
        frac[daylight] = np.maximum(0., 1. - shadow * np.where(cross < 1.e-14, 0., cross))
    return frac


def atmospheric_solar(zenith, direct, diffuse):
    """Reconstruct horizontal forcing after TEB_FILL_FORCING and CIRCUMSOLAR_RAD."""
    elevation = np.pi/2. - zenith
    low_sun = np.clip((elevation - 0.05)/0.05, 0., 1.)
    sky = diffuse + direct*(1.-low_sun)
    beam = direct*low_sun
    clearness = np.full_like(sky, -1.)
    active = sky > 0.
    k = 1.041*elevation[active]**3
    clearness[active] = (1. + beam[active]/sky[active] + k)/(1. + k)
    bounds = [0., 1.065, 1.230, 1.500, 1.950, 2.800, 4.500, 6.200]
    f11 = np.array([0., -.0083117, .1299457, .3296958, .5682053, .8730280,
                    1.1326077, 1.0601591, .6777470])
    f13 = np.array([0., -.0620636, -.1513752, -.2210958, -.2951290, -.3616149,
                    -.4118494, -.3589221, -.2504286])
    i = np.searchsorted(bounds, clearness, side='right')
    circum = np.clip((f11[i]+f13[i]*elevation)/np.maximum(.087, np.cos(elevation)), 0., 1.)
    return np.maximum(0., beam+sky*circum), np.maximum(0., sky*(1.-circum))


def run_checks(d, nml, body):
    if d.empty:
        raise ValueError('Empty model output')
    def values(name):
        return d[name].to_numpy(dtype=float)
    def enabled(name):
        return item(nml, name, '.FALSE.').strip('.').upper() in ('TRUE', 'T')
    def number(name, default=None):
        return float(str(item(nml, name, default)).lower().replace('d', 'e'))
    passed = []
    def check(name, actual, expected, mask=None, tol=2.e-8):
        a, b = np.broadcast_arrays(actual, expected)
        if mask is not None:
            a, b = a[mask], b[mask]
        if not a.size:
            print(f'SKIP  {name} (no matching rows)')
            return
        residual = np.max(np.abs(a-b))
        passed.append(np.isfinite(residual) and residual <= tol)
        print(f'{"PASS" if passed[-1] else "FAIL"}  {name}: {len(a)} rows, max error {residual:.3g}')

    zen = np.radians(values('SOLAR_ZENITH'))
    azi = np.radians(values('SOLAR_AZIM'))
    height, bld = number('urb_h_bld'), number('urb_fr_bld')
    ratio = number('urb_h2w') if bld > 0. and height > 0. else 0.
    rel = min(1., HEIGHT/height) if height > 0. else 1.
    sky, floor = strip_view(ratio*(1.-rel)), strip_view(ratio*rel)
    wall = 1. - sky - floor
    for source, factor in [('SKY', sky), ('ROAD', floor), ('WALL', wall)]:
        check('solid angle ' + source, values('MRT_F_' + source), factor, tol=2.e-12)
    frac = sunlit_width(zen, azi, height, ratio, number('teb_road_dir', 0.), item(nml, 'teb_hroad_dir', 'UNIF'))
    check('sunlit width at 1.1 m', values('SUN_FRAC_PED'), frac, tol=5.e-13)
    direct, diffuse = atmospheric_solar(zen, values('Forc_DIR_SW'), values('Forc_SCA_SW'))
    panel = number('teb_fr_panel', 0.) if enabled('teb_lsolar_panel') else 0.
    check('horizontal direct over the roof substrate', values('SW_DIR_ROOF'), direct*(1.-panel))
    check('horizontal diffuse over the roof substrate', values('SW_SKY_ROOF'), np.maximum(diffuse, 1.e-6)*(1.-panel))
    # The native solar solver floors incident sky SW at 1e-6 W/m2 and also
    # clips wall reflection at zero when reporting these substrate components.
    check('incident SW on road', values('SW_TOT_ROAD'),
          values('SW_DIR_ROAD')+values('SW_SKY_ROAD')+values('SW_WALL_ROAD'), tol=1.e-6)
    e = 90. - values('SOLAR_ZENITH')
    projection = .25 if body == 'sphere' else .308*np.cos(np.radians(e*(1.-e**2/48402.)))
    beam = np.divide(ABS*projection*direct, np.cos(zen), out=np.zeros_like(zen), where=zen < np.pi/2.)
    check('direct SW absorbed by body', values('MRT_SW_DIR'), frac*beam)
    check('diffuse sky SW', values('MRT_SW_SKY'), ABS*sky*diffuse)
    lw = values('Forc_LW')
    check('sky LW', values('MRT_LW_SKY'), EPS*sky*lw)

    # A last melting sub-step can still see snow when PDN_RD is already zero.
    snow_free = (values('PDN_RD') == 0.) & (values('PDN_RF') == 0.) & (values('Forc_SNOW') == 0.)
    snow_free &= d.WSNOW_RD.shift(1).fillna(1.).eq(0.).to_numpy()
    g = number('fr_garden', 0.)/(1.-bld) if enabled('teb_lgarden') else 0.
    albedo = (1.-g)*number('urb_alb_rd_so')+g*number('urb_alb_gdn', .15)
    check('floor SW for known snow-free optics', values('MRT_SW_ROAD'),
          ABS*floor*albedo*np.where(direct+diffuse > 0., values('SW_TOT_ROAD'), 0.), snow_free)
    base = sum(values(k) for k in ('MRT_SW_SKY', 'MRT_SW_ROAD', 'MRT_SW_WALL',
                                    'MRT_LW_SKY', 'MRT_LW_ROAD', 'MRT_LW_WALL'))
    def temp(q):
        return (q/(SIGMA*EPS))**.25
    mean = values('MRT_ROAD')
    sun, shade = values('MRT_ROAD_SUN'), values('MRT_ROAD_SHADE')
    # For azimuths near alignment, classify using the stored exact end points
    # after the independent geometry comparison above.
    lit = values('SUN_FRAC_PED')
    check('sun class presence', np.isfinite(sun).astype(int), (lit > 0.).astype(int))
    check('shade class presence', np.isfinite(shade).astype(int), (lit < 1.).astype(int))
    check('MRT from width-mean energy [K]', mean, temp(base + frac*beam))
    check('sun MRT [K]', sun, temp(base + beam), lit > 0.)
    check('shade MRT [K]', shade, temp(base), lit < 1.)
    mixed = (lit > 0.) & (lit < 1.)
    check('fourth-power mixture [K]', mean, (lit*sun**4 + (1.-lit)*shade**4)**.25, mixed)
    roof = values('MRT_ROOF')
    accessible = bld > 0. and panel < 1.
    check('open roof presence', np.isfinite(roof).astype(int), int(accessible))
    if accessible:
        v = number('teb_frac_gr', 0.) if enabled('teb_lgreenroof') else 0.
        alb = (1.-v)*number('urb_alb_rf_so') + v*number('urb_alb_grf', .15)
        emis = number('urb_emis_rf', 1.-number('urb_alb_rf_th', .03))
        up = (1.-v)*(emis*SIGMA*values('T_ROOF1')**4+(1.-emis)*lw) if v < 1. else 0.
        if v > 0.:
            eg = number('urb_emis_grf', .98)
            up += v*(eg*SIGMA*values('TS_GREENROOF')**4 + (1.-eg)*lw)
        check('open roof MRT from tile properties [K]', roof,
              temp(beam + .5*ABS*(diffuse + alb*(direct + diffuse)) + .5*EPS*(lw+up)), values('PDN_RF') == 0.)
    return all(passed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path', type=Path)
    parser.add_argument('--param-nml', type=Path, default=Path('namelist/namelist.nml'))
    parser.add_argument('--body', choices=('person', 'sphere'), default='person')
    args = parser.parse_args()
    d = pd.read_csv(args.path, sep=';')
    for name in ('MRT_ROAD_SUN', 'MRT_ROAD_SHADE', 'MRT_ROOF'):
        raw = d[name].to_numpy()
        if not np.all(np.isfinite(raw) & ((raw < XUNDEF) | (raw == 1.e20))):
            raise ValueError(f'Invalid missing-value encoding in {name}')
    cols = d.select_dtypes('number').columns
    d[cols] = d[cols].mask(d[cols] >= XUNDEF)
    return 0 if run_checks(d, args.param_nml.read_text(encoding='utf-8-sig'), args.body) else 1


if __name__ == '__main__':
    raise SystemExit(main())
