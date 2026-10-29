#!/usr/bin/env python
"""Case set of the ``upstream_cons_test`` bench: ``C0_control`` + ``D1``..``D5``.

``C0_control`` mirrors the scenario of the upstream CAPITOUL namelist into the
control tree: garden 0.11 on, green roof 0.3 on, glazing ratio 0.1, natural
ventilation off, effective cooling capacity 100 W m-2(bld), initial building
temperature 292.15 K, emissivity items instead of the legacy longwave albedo.
The upstream side keeps the pristine CAPITOUL namelist except ``XTSTEP_SURF``,
``HZ0H`` and ``CCH_BEM`` (options the control tree does not have); its initial
state is written by ``common.apply_initial_state`` from the control cold start.

Every other case inherits ``C0_control`` (``base_case``) and switches exactly
one model block, so that the *responses* of the two models can be compared:

    D1_garden_off     garden (0.11 -> 0)
    D2_greenroof_off  green roof (0.3 -> 0)
    D3_solar_on       solar panels (0 -> 0.5)
    D4_shading_on     window shading (off -> on)
    D5_no_bem         building energy model (on -> off)

Keys of a case dict:

``level``, ``data``, ``description``      metadata
``base_case``                             inherit the namelists of that case
``init_anchor``                           initial building temperature [K]
``ctrl_param_overrides`` / ``..._removals``  &tebparam of the control driver
``ctrl_forcing_overrides``                &tebforcing of the control driver
``upstream_param_overrides``              &parameters of the upstream driver
"""
from __future__ import annotations

from common import CTRL_FORCING_PATH

#: the case every other case is relative to
BASE_CASE = 'C0_control'

CASE_NAMES = (
    'C0_control',
    'D1_garden_off',
    'D2_greenroof_off',
    'D3_solar_on',
    'D4_shading_on',
    'D5_no_bem',
)

#: cases that switch one block relative to BASE_CASE
SENSITIVITY_CASE_NAMES = CASE_NAMES[1:]

CASES = {
    'C0_control': {
        'level': 'control',
        'data': 'capitoul',
        'description': (
            'Control configuration: the scenario of the upstream CAPITOUL '
            'namelist mirrored into the control tree (garden 0.11 on, green '
            'roof 0.3 on, glazing ratio 0.1, natural ventilation off, '
            'teb_cap_sys_rat 100/7, teb_ti_bld_init 292.15, teb_dt_res/off 3, '
            'urb_emis_* instead of the legacy urb_alb_*_th). The upstream side '
            'keeps the pristine namelist except XTSTEP_SURF=300, '
            "HZ0H='MASC95' and CCH_BEM=' '; its initial state is the control "
            'cold start anchored to 292.15 K.'),
        'init_anchor': 292.15,
        'ctrl_param_overrides': {
            'teb_lgarden': '.TRUE.',
            'fr_garden': '0.11',
            'teb_lgreenroof': '.TRUE.',
            'teb_frac_gr': '0.3',
            'teb_frac_gz': '0.1',
            'teb_itype_natvent': "'NONE'",
            'teb_cap_sys_rat': '14.285714285714286',
            'teb_ti_bld_init': '292.15',
            'teb_dt_res': '3.',
            'teb_dt_off': '3.',
            'urb_emis_rf': '0.97',
            'urb_emis_rd': '0.96',
            'urb_emis_wl': '0.97',
        },
        'ctrl_param_removals': [
            'urb_alb_rf_th',
            'urb_alb_rd_th',
            'urb_alb_wl_th',
        ],
        'ctrl_forcing_overrides': {
            'forcing_path': CTRL_FORCING_PATH,
        },
        'upstream_param_overrides': {
            'XTSTEP_SURF': '300.',
            'HZ0H': "'MASC95'",
            'CCH_BEM': "' '",
        },
    },
    'D1_garden_off': {
        'level': 'sensitivity',
        'data': 'capitoul',
        'description': (
            'Garden OFF relative to C0_control (garden 0.11 -> 0): sensitivity '
            'of both models to the garden block (teb_lgarden/fr_garden vs '
            'LGARDEN/ZGARDEN).'),
        'base_case': BASE_CASE,
        'ctrl_param_overrides': {
            'teb_lgarden': '.FALSE.',
            'fr_garden': '0.0',
        },
        'upstream_param_overrides': {
            'LGARDEN': '.FALSE.',
            'ZGARDEN': '0.0',
        },
    },
    'D2_greenroof_off': {
        'level': 'sensitivity',
        'data': 'capitoul',
        'description': (
            'Green roof OFF relative to C0_control (0.3 -> 0): sensitivity to '
            'the green roof block (teb_lgreenroof/teb_frac_gr vs '
            'LGREENROOF/ZFRAC_GR).'),
        'base_case': BASE_CASE,
        'ctrl_param_overrides': {
            'teb_lgreenroof': '.FALSE.',
            'teb_frac_gr': '0.0',
        },
        'upstream_param_overrides': {
            'LGREENROOF': '.FALSE.',
            'ZFRAC_GR': '0.0',
        },
    },
    'D3_solar_on': {
        'level': 'sensitivity',
        'data': 'capitoul',
        'description': (
            'Solar panels ON relative to C0_control (fraction 0.5): sensitivity '
            'to the solar panel block (teb_lsolar_panel/teb_fr_panel vs '
            'LSOLAR_PANEL/ZFRAC_PANEL).'),
        'base_case': BASE_CASE,
        'ctrl_param_overrides': {
            'teb_lsolar_panel': '.TRUE.',
            'teb_fr_panel': '0.5',
        },
        'upstream_param_overrides': {
            'LSOLAR_PANEL': '.TRUE.',
            'ZFRAC_PANEL': '0.5',
        },
    },
    'D4_shading_on': {
        'level': 'sensitivity',
        'data': 'capitoul',
        'description': (
            'Window shading ON relative to C0_control: sensitivity to the '
            'shading block (teb_lshade vs LSHADE/ZSHADE).'),
        'base_case': BASE_CASE,
        'ctrl_param_overrides': {
            'teb_lshade': '.TRUE.',
        },
        'upstream_param_overrides': {
            'LSHADE': '.TRUE.',
            'ZSHADE': '1.',
        },
    },
    'D5_no_bem': {
        'level': 'sensitivity',
        'data': 'capitoul',
        'description': (
            'No BEM relative to C0_control (BEM -> DEF, glazing ratio -> 0): '
            'sensitivity to the building energy model block '
            '(teb_itype_bem/teb_frac_gz vs CBEM/ZGR). With BEM off the HVAC, '
            'window, shading and natural-ventilation branches are inactive, so '
            'this is the base (non-BEM) urban canopy configuration. The glazing '
            'ratio belongs to the switch: both drivers stop with "Building '
            'Energy Module (BEM) is not activated but a non-zero glazing ratio '
            'is given" (call_driver.F90) if it is left non-zero.'),
        'base_case': BASE_CASE,
        'ctrl_param_overrides': {
            'teb_itype_bem': "'DEF'",
            'teb_frac_gz': '0.0',
        },
        'upstream_param_overrides': {
            'CBEM': '"DEF"',
            'ZGR': '0.0',
        },
    },
}