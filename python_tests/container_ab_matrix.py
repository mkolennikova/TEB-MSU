#!/usr/bin/env python
"""Extended A/B matrix over parameter-namelist configurations.

Runs the reference (origin/main) and candidate binaries on the CAPITOUL case
with several parameter namelists (BEM on/off, garden modes, green roofs, solar
panels, CBS scheme) and reports bit-for-bit identity of the physics columns.

The origin and candidate trees differ in the output layout (the P-log work):
the origin writes one `TEB_output.csv` (110 columns), the candidate writes
`TEB_output_b1_c1.csv` (109 columns) plus `TEB_runoff.csv` and `TEB_emu.csv`.
The physics columns (108 names) are compared by NAME, the runoff columns
(RUNOFF_ROAD/RUNOFF_ROOF) between the origin's main CSV and the candidate's
`TEB_runoff.csv`, and the emulator columns (EMU_*) between the origin's main
CSV and the candidate's `TEB_emu.csv` (they are outside the common set, so a
wrong emulator input would otherwise go unnoticed).

Usage
-----
    python python_tests/container_ab_matrix.py \
        --ref-exe build/TEB_offline_dev_ref.exe \
        --new-exe build/TEB_offline_dev.exe

Files are written into `python_tests/container_ab_matrix/<config>/` and the
summary into `summary_matrix.csv`. Exit code 1 when any configuration differs.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from container_ab_compare import MODEL_DIR, run_case, read_csv

CASE = MODEL_DIR / 'tests' / 'CAPITOUL'
BASE_NML = CASE / 'namelist' / 'namelist.nml'
FORCING_NML = CASE / 'namelist' / 'namelist_forcing.nml'
OUT_ROOT = MODEL_DIR / 'python_tests' / 'container_ab_matrix'

REF_CSV_NAME = 'TEB_output.csv'          # origin (before P-log) filename
NEW_CSV_NAME = 'TEB_output_b1_c1.csv'    # candidate filename

#: config name -> namelist overrides (key -> Fortran literal value)
CONFIGS = [
    ('baseline', {}),
    ('bem_off', {'teb_itype_bem': "'DEF'", 'teb_lbem_ac': '.FALSE.', 'teb_frac_gz': '0.'}),
    ('bem_ac_off', {'teb_lbem_ac': '.FALSE.'}),
    ('garden_proxy_new', {'teb_lgarden': '.TRUE.', 'fr_garden': '0.30'}),
    ('garden_proxy_old', {'teb_lgarden': '.TRUE.', 'fr_garden': '0.30',
                          'teb_type_garden': "'PROXY_OLD'"}),
    ('garden_ext', {'teb_lgarden': '.TRUE.', 'fr_garden': '0.30',
                    'teb_type_garden': "'EXT'"}),
    ('garden_ext_neu', {'teb_lgarden': '.TRUE.', 'fr_garden': '0.30',
                        'teb_type_garden': "'EXT_NEU'"}),
    ('greenroof_on', {'teb_lgreenroof': '.TRUE.', 'teb_frac_gr': '0.50'}),
    ('greenroof_ext', {'teb_lgreenroof': '.TRUE.', 'teb_frac_gr': '0.50',
                       'teb_type_greenroof': "'EXT'"}),
    ('solar_on', {'teb_lsolar_panel': '.TRUE.', 'teb_fr_panel': '0.50'}),
    ('cbs_off', {'teb_lcbs_scheme': '.FALSE.'}),
    ('cbs_on', {'teb_lcbs_scheme': '.TRUE.'}),
    ('combined', {'teb_lgarden': '.TRUE.', 'fr_garden': '0.30',
                  'teb_lgreenroof': '.TRUE.', 'teb_frac_gr': '0.50',
                  'teb_lsolar_panel': '.TRUE.', 'teb_fr_panel': '0.50',
                  'teb_lcbs_scheme': '.TRUE.'}),
]


def make_param_namelist(dst: Path, overrides: dict) -> Path:
    """Copy the base param namelist, applying the overrides; write to dst."""
    text = BASE_NML.read_text(encoding='utf-8')
    for key, value in overrides.items():
        pat = re.compile(r'^(\s*)' + re.escape(key) + r'\s*=\s*[^\n]*', re.M)
        if pat.search(text):
            text = pat.sub(lambda m: m.group(1) + key + '=' + value + ',', text, count=1)
        else:
            text = text.replace('\n/', '\n ' + key + '=' + value + ',\n/', 1)
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(text, encoding='utf-8')
    return dst


def compare_common(ref_csv: Path, new_csv: Path) -> dict:
    """Compare the columns common to both CSVs, by name, bit-for-bit."""
    h_ref, r_ref = read_csv(ref_csv)
    h_new, r_new = read_csv(new_csv)
    common = [c for c in h_ref if c in h_new]
    only_ref = [c for c in h_ref if c not in h_new]
    only_new = [c for c in h_new if c not in h_ref]
    differing = []
    n = min(len(r_ref), len(r_new))
    for name in common:
        i_ref = h_ref.index(name)
        i_new = h_new.index(name)
        for i in range(n):
            a = r_ref[i][i_ref] if i_ref < len(r_ref[i]) else '<missing>'
            b = r_new[i][i_new] if i_new < len(r_new[i]) else '<missing>'
            if a != b:
                differing.append((name, i + 1, a, b))
                break
    return {'common': len(common), 'only_ref': only_ref, 'only_new': only_new,
            'differing': differing, 'n_rows': n,
            'n_rows_ref': len(r_ref), 'n_rows_new': len(r_new)}


#: emulator state/fluxes of the external garden and greenroof; the candidate
#: writes them to TEB_emu.csv, the reference to the main CSV
EMU_COLUMNS = ('EMU_TAU', 'EMU_CD_EFF', 'EMU_CH_EFF', 'EMU_CH_NAIVE', 'EMU_V',
               'EMU_T', 'EMU_Q', 'EMU_CA_CAN', 'EMU_CA_EFF', 'EMU_TS', 'EMU_H',
               'EMU_LE', 'EMU_EVAP')


def compare_emu(ref_csv: Path, new_csv: Path) -> dict:
    """Compare the EMU_* columns: ref main CSV vs candidate TEB_emu.csv.

    They are moved out of the main CSV in the candidate, so `compare_common`
    never sees them; without this check a wrong emulator input changes only
    columns that are not compared (see change history, defect N3).
    """
    h_ref, r_ref = read_csv(ref_csv)
    h_new, r_new = read_csv(new_csv)
    differing = []
    n = min(len(r_ref), len(r_new))
    for name in EMU_COLUMNS:
        if name not in h_ref or name not in h_new:
            continue
        i_ref = h_ref.index(name)
        i_new = h_new.index(name)
        for i in range(n):
            if r_ref[i][i_ref] != r_new[i][i_new]:
                differing.append((name, i + 1, r_ref[i][i_ref], r_new[i][i_new]))
                break
    return {'differing': differing, 'n_rows': n}


def compare_runoff(ref_csv: Path, new_csv: Path) -> dict:
    """Compare RUNOFF_ROAD/RUNOFF_ROOF: ref main CSV vs candidate TEB_runoff.csv."""
    h_ref, r_ref = read_csv(ref_csv)
    h_new, r_new = read_csv(new_csv)
    differing = []
    n = min(len(r_ref), len(r_new))
    for name in ('RUNOFF_ROAD', 'RUNOFF_ROOF'):
        if name not in h_ref or name not in h_new:
            continue
        i_ref = h_ref.index(name)
        i_new = h_new.index(name)
        for i in range(n):
            if r_ref[i][i_ref] != r_new[i][i_new]:
                differing.append((name, i + 1, r_ref[i][i_ref], r_new[i][i_new]))
                break
    return {'differing': differing, 'n_rows': n}


def main(argv=None) -> int:
    import argparse
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--ref-exe', default='build/TEB_offline_dev_ref.exe')
    ap.add_argument('--new-exe', default='build/TEB_offline_dev.exe')
    args = ap.parse_args(argv)

    ref_exe = (MODEL_DIR / args.ref_exe).resolve()
    new_exe = (MODEL_DIR / args.new_exe).resolve()
    for exe in (ref_exe, new_exe):
        if not exe.is_file():
            sys.exit(f'ERROR: not found: {exe}')

    rows = [('config', 'common_cols', 'differing', 'runoff_differing',
             'emu_differing', 'result')]
    all_ok = True
    for name, overrides in CONFIGS:
        cfg_dir = OUT_ROOT / name
        param_nml = make_param_namelist(cfg_dir / 'namelist.nml', overrides)
        run_case(ref_exe, CASE, FORCING_NML, cfg_dir / 'ref', None, param_nml)
        run_case(new_exe, CASE, FORCING_NML, cfg_dir / 'new', None, param_nml)

        ref_csv = cfg_dir / 'ref' / REF_CSV_NAME
        new_csv = cfg_dir / 'new' / NEW_CSV_NAME
        res = compare_common(ref_csv, new_csv)

        runoff_csv = cfg_dir / 'new' / 'TEB_runoff.csv'
        runoff = {'differing': []}
        if runoff_csv.is_file():
            runoff = compare_runoff(ref_csv, runoff_csv)

        emu_csv = cfg_dir / 'new' / 'TEB_emu.csv'
        emu = {'differing': []}
        if emu_csv.is_file():
            emu = compare_emu(ref_csv, emu_csv)

        ok = (res['n_rows_ref'] == res['n_rows_new']
              and not res['differing'] and not runoff['differing']
              and not emu['differing'])
        all_ok &= ok
        tag = 'IDENTICAL' if ok else 'DIFF'
        rows.append((name, str(res['common']), str(len(res['differing'])),
                     str(len(runoff['differing'])), str(len(emu['differing'])), tag))
        print(f'{name:18s} rows={res["n_rows"]:6d} common={res["common"]:3d} '
              f'differ={len(res["differing"]):2d} runoff_diff={len(runoff["differing"])} '
              f'emu_diff={len(emu["differing"]):2d} {tag}')
        if res['differing']:
            for d in res['differing'][:5]:
                print(f'      {d[0]} row {d[1]}: {d[2]} != {d[3]}')
        for d in emu['differing'][:5]:
            print(f'      EMU {d[0]} row {d[1]}: {d[2]} != {d[3]}')

    summary = OUT_ROOT / 'summary_matrix.csv'
    summary.write_text('\n'.join(';'.join(r) for r in rows) + '\n', encoding='utf-8')
    print('summary:', summary)
    print('RESULT:', 'ALL IDENTICAL (bit-for-bit)' if all_ok else 'MISMATCH FOUND')
    return 0 if all_ok else 1


if __name__ == '__main__':
    sys.exit(main())

