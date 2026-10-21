#!/usr/bin/env python
"""Sensitivity of the BEM options, with the A/B identity of the two binaries.

For every option the stand builds two parameter namelists from the CAPITOUL
case (option off / option on) and runs four cases: the reference (origin/main)
binary and the candidate, each with both namelists. Two checks follow:

  * **A/B identity** - the candidate is bit-for-bit identical to the reference
    for the *same* namelist (physics columns by name, RUNOFF_*, EMU_*). This is
    the same check as container_ab_matrix.py, applied to the new modes;
  * **sensitivity** - the candidate's own results must *change* between off and
    on in at least one of the watched columns, and the change must be material
    (a relative difference above a threshold, not a round-off). An option that
    is not wired to the physics would pass the A/B check and fail this one, so
    the second check is what makes the experiment meaningful.

The options (all with BEM active, the CAPITOUL base):

  * ``shade``   - window shading devices (``teb_lshade``, default TRUE):
    ``BSTATE%LSHADE`` feeds WINDOW_SHADING_AVAILABILITY and WINDOW_E_BUDGET;
  * ``ac``      - air conditioners (``teb_lbem_ac``, base TRUE): ``PBEM_AC``
    feeds BEM (the HVAC demand and the natural-ventilation condition);
  * ``natvent`` - natural ventilation through the open windows
    (``teb_itype_natvent``, default NONE): AUTO computes the opening rate from
    the wind and the canyon air, MECH prescribes five volumes per hour; the
    decision is kept in the state ``BSTATE%LNATVENT_NIGHT``.

Usage
-----
    python python_tests/bem_option_sensitivity.py
    python python_tests/bem_option_sensitivity.py --ref-exe build/TEB_offline_dev_ref.exe --new-exe build/TEB_offline_dev.exe

Output: ``python_tests/bem_sensitivity/<experiment>/<variant>/{ref,new}`` and the
summary ``python_tests/bem_sensitivity/summary_bem_sensitivity.csv``. Exit code
1 when an A/B check fails or an option shows no material sensitivity.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from container_ab_compare import MODEL_DIR, read_csv, run_case            # noqa: E402
from container_ab_matrix import (FORCING_NML, NEW_CSV_NAME, REF_CSV_NAME,  # noqa: E402
                                 CASE, compare_common, compare_emu,
                                 compare_runoff, make_param_namelist)

OUT_ROOT = MODEL_DIR / 'python_tests' / 'bem_sensitivity'

#: relative difference above which a change counts as material (not round-off)
MATERIAL_REL = 1.0e-6
#: experiment: (name, off overrides, on overrides, watched columns)
EXPERIMENTS = [
    ('shade',
     {'teb_lshade': '.FALSE.'},
     {'teb_lshade': '.TRUE.'},
     ('TI_BLD', 'HVAC_COOL', 'HVAC_HEAT', 'H_TOWN', 'LE_TOWN')),
    ('ac',
     {'teb_lbem_ac': '.FALSE.'},
     {'teb_lbem_ac': '.TRUE.'},
     ('HVAC_COOL', 'HVAC_HEAT', 'TI_BLD', 'H_TOWN', 'LE_TOWN')),
    ('natvent_auto',
     {'teb_itype_natvent': "'NONE'"},
     {'teb_itype_natvent': "'AUTO'"},
     ('TI_BLD', 'HVAC_COOL', 'HVAC_HEAT', 'Q_CANYON', 'T_CANYON')),
    ('natvent_mech',
     {'teb_itype_natvent': "'NONE'"},
     {'teb_itype_natvent': "'MECH'"},
     ('TI_BLD', 'HVAC_COOL', 'HVAC_HEAT', 'Q_CANYON', 'T_CANYON')),
]


def ab_ok(ref_csv: Path, new_csv: Path, runoff_csv: Path, emu_csv: Path) -> tuple:
    """(ok, message): the candidate equals the reference for the same namelist."""
    if not ref_csv.is_file() or not new_csv.is_file():
        return False, f'missing CSV: {ref_csv} / {new_csv}'
    res = compare_common(ref_csv, new_csv)
    runoff = compare_runoff(ref_csv, runoff_csv) if runoff_csv.is_file() else {'differing': []}
    emu = compare_emu(ref_csv, emu_csv) if emu_csv.is_file() else {'differing': []}
    ok = (res['n_rows_ref'] == res['n_rows_new'] and not res['differing']
          and not runoff['differing'] and not emu['differing'])
    if ok:
        return True, f'{res["n_rows"]} rows, {res["common"]} columns'
    parts = []
    for d in res['differing'][:3]:
        parts.append(f'{d[0]} row {d[1]}: {d[2]} != {d[3]}')
    for d in emu['differing'][:2]:
        parts.append(f'EMU {d[0]} row {d[1]}: {d[2]} != {d[3]}')
    for d in runoff['differing'][:2]:
        parts.append(f'RUNOFF {d[0]} row {d[1]}: {d[2]} != {d[3]}')
    return False, '; '.join(parts)


def sensitivity(off_csv: Path, on_csv: Path, watch: tuple) -> list:
    """Per watched column: (name, n_rows_differing, max_abs, max_rel)."""
    h_off, r_off = read_csv(off_csv)
    h_on, r_on = read_csv(on_csv)
    n = min(len(r_off), len(r_on))
    out = []
    for name in watch:
        if name not in h_off or name not in h_on:
            continue
        i_off = h_off.index(name)
        i_on = h_on.index(name)
        n_diff = 0
        max_abs = 0.0
        max_rel = 0.0
        for i in range(n):
            try:
                a = float(r_off[i][i_off])
                b = float(r_on[i][i_on])
            except (ValueError, IndexError):
                continue
            d = abs(b - a)
            if d > 0.0:
                n_diff += 1
                max_abs = max(max_abs, d)
                scale = max(abs(a), abs(b))
                max_rel = max(max_rel, d / scale if scale > 0.0 else 1.0)
        out.append((name, n_diff, max_abs, max_rel))
    return out
def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--ref-exe', default='build/TEB_offline_dev_ref.exe')
    ap.add_argument('--new-exe', default='build/TEB_offline_dev.exe')
    ap.add_argument('--out-root', default=str(OUT_ROOT))
    args = ap.parse_args(argv)

    ref_exe = (MODEL_DIR / args.ref_exe).resolve()
    new_exe = (MODEL_DIR / args.new_exe).resolve()
    for exe in (ref_exe, new_exe):
        if not exe.is_file():
            sys.exit(f'ERROR: not found: {exe}')
    out_root = Path(args.out_root)
    out_root.mkdir(parents=True, exist_ok=True)

    print('BEM option sensitivity  [%s]' % CASE.name)
    rows = [('experiment', 'ab_result', 'sensitive_columns', 'max_abs', 'max_rel', 'result')]
    all_ok = True
    for name, off, on, watch in EXPERIMENTS:
        exp_dir = out_root / name
        nml = {'off': make_param_namelist(exp_dir / 'off' / 'namelist.nml', off),
               'on': make_param_namelist(exp_dir / 'on' / 'namelist.nml', on)}
        for variant in ('off', 'on'):
            run_case(ref_exe, CASE, FORCING_NML, exp_dir / variant / 'ref', None, nml[variant])
            run_case(new_exe, CASE, FORCING_NML, exp_dir / variant / 'new', None, nml[variant])

        ab = {}
        for variant in ('off', 'on'):
            base = exp_dir / variant
            ab[variant], msg = ab_ok(base / 'ref' / REF_CSV_NAME,
                                     base / 'new' / NEW_CSV_NAME,
                                     base / 'new' / 'TEB_runoff.csv',
                                     base / 'new' / 'TEB_emu.csv')
            print(f'  {name}/{variant}: A/B '
                  f'{"IDENTICAL" if ab[variant] else "DIFFERS"} ({msg})')

        sens = sensitivity(exp_dir / 'off' / 'new' / NEW_CSV_NAME,
                           exp_dir / 'on' / 'new' / NEW_CSV_NAME, watch)
        material = [s for s in sens if s[3] > MATERIAL_REL]
        touched = [s for s in sens if s[1] > 0]
        ok = ab['off'] and ab['on'] and bool(material)
        all_ok &= ok
        max_abs = max((s[2] for s in sens), default=0.0)
        max_rel = max((s[3] for s in sens), default=0.0)
        desc = ', '.join(f'{s[0]}({s[1]})' for s in touched) or '-'
        print(f'  {name}: sensitivity {"MATERIAL" if material else "NONE"} '
              f'[{desc}] max_abs={max_abs:.6g} max_rel={max_rel:.3g}'
              f' -> {"OK" if ok else "FAIL"}')
        rows.append((name, 'IDENTICAL' if ab['off'] and ab['on'] else 'DIFFERS',
                     desc, f'{max_abs:.6g}', f'{max_rel:.3g}', 'OK' if ok else 'FAIL'))

    summary = out_root / 'summary_bem_sensitivity.csv'
    summary.write_text('\n'.join(';'.join(r) for r in rows) + '\n', encoding='utf-8')
    print('summary:', summary)
    print('RESULT:', 'ALL OK (A/B identical, all options sensitive)' if all_ok else 'FAIL')
    return 0 if all_ok else 1


if __name__ == '__main__':
    sys.exit(main())