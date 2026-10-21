#!/usr/bin/env python
"""A/B comparison of two TEB-MSU offline binaries: bit-for-bit CSV contract.

The refactor of the diagnostics plumbing (the diagnostics container) must not
change a single number of the reference case. This bench runs the same case
with two executables ("reference" = before the change, "candidate" = after the
change) and compares the two `TEB_output.csv` files field by field, as text, so
that the comparison is exact (no floating-point tolerance):

  * the header lines are split on ';' and compared column by column
    (name, order, count);
  * every data row is compared field by field for the columns present in both
    files;
  * SHA-256 of both files is reported (equality of the hashes is the strongest
    form of the check, when the two runs are on the same machine).

The executables are given explicitly, so that the bench never touches the
working tree of the sources: build the "before" tree into a separate name and
pass it as `--ref-exe`.

Usage
-----
    # reference case, short run (50 forcing steps)
    python python_tests/container_ab_compare.py \\
        --ref-exe build/TEB_offline_dev_ref.exe \\
        --new-exe build/TEB_offline_dev.exe --steps 50

    # full reference case (18000 steps) and a stored golden header
    python python_tests/container_ab_compare.py \\
        --ref-exe build/TEB_offline_dev_ref.exe \\
        --new-exe build/TEB_offline_dev.exe \\
        --golden python_tests/container_ab/csv_header_golden.txt

Files written into `<out-root>` (default `python_tests/container_ab`, ignored by
git): `ref/TEB_output.csv`, `new/TEB_output.csv`, the generated forcing namelist
and `summary_container_ab.csv`. Exit code 1 when the headers or any column
differ.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parent

#: the forcing namelist item that controls the length of the run
RE_NSTEPS = re.compile(r'(nsteps\s*=\s*)(\d+)', re.I)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def read_csv(path: Path):
    """Return (header, rows) of a semicolon-separated CSV, as raw text fields."""
    lines = path.read_text(encoding='utf-8', errors='ignore').splitlines()
    if not lines:
        return [], []
    header = lines[0].split(';')
    rows = [line.split(';') for line in lines[1:] if line.strip()]
    return header, rows


def make_short_namelist(src: Path, dst: Path, steps: int) -> Path:
    """Copy a forcing namelist, replacing the value of `nsteps`."""
    text = src.read_text(encoding='utf-8', errors='ignore')
    text, n = RE_NSTEPS.subn(lambda m: f'{m.group(1)}{steps}', text, count=1)
    if n != 1:
        sys.exit(f'ERROR: nsteps item not found in {src}')
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(text, encoding='utf-8')
    return dst


def run_case(exe: Path, case: Path, namelist: Path, out_dir: Path, timeout=None,
             param_nml=None) -> None:
    """Run one executable on the case, with the output written into out_dir."""
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd = [str(exe), '-forcing_nml', str(namelist), '-output', str(out_dir)]
    if param_nml is not None:
        cmd += ['-param_nml', str(param_nml)]
    print(f'  run: {exe.name} -> {out_dir}')
    t0 = time.time()
    proc = subprocess.run(cmd, cwd=str(case), capture_output=True, text=True,
                          errors='ignore', timeout=timeout)
    dt = time.time() - t0
    if proc.returncode != 0:
        tail = '\n'.join((proc.stdout or '').splitlines()[-15:])
        sys.exit(f'ERROR: {exe.name} failed (rc={proc.returncode}) after {dt:.1f} s\n{tail}')
    print(f'  ok ({dt:.1f} s)')


def compare(ref_csv: Path, new_csv: Path) -> dict:
    """Field-by-field (exact text) comparison of the two CSVs."""
    h_ref, r_ref = read_csv(ref_csv)
    h_new, r_new = read_csv(new_csv)
    res = {'header_ref': h_ref, 'header_new': h_new,
           'header_equal': h_ref == h_new,
           'n_rows_ref': len(r_ref), 'n_rows_new': len(r_new),
           'only_ref': [c for c in h_ref if c not in h_new],
           'only_new': [c for c in h_new if c not in h_ref],
           'columns': []}
    n = min(len(r_ref), len(r_new))
    for i_ref, name in enumerate(h_ref):
        if name not in h_new:
            continue
        i_new = h_new.index(name)
        differing, first = 0, None
        for i in range(n):
            a = r_ref[i][i_ref] if i_ref < len(r_ref[i]) else '<field missing>'
            b = r_new[i][i_new] if i_new < len(r_new[i]) else '<field missing>'
            if a != b:
                differing += 1
                if first is None:
                    first = (i + 1, a, b)
        res['columns'].append({'column': name, 'differing_rows': differing, 'first': first})
    res['n_rows_compared'] = n
    res['n_differing_columns'] = sum(1 for c in res['columns'] if c['differing_rows'])
    res['ok'] = (res['header_equal'] and len(r_ref) == len(r_new)
                 and res['n_differing_columns'] == 0)
    return res


def write_summary(path: Path, res: dict, ref_exe: Path, new_exe: Path,
                  sha_ref: str, sha_new: str) -> None:
    lines = ['# A/B comparison of two TEB-MSU binaries (exact text comparison)',
             f'# reference exe;{ref_exe.name}', f'# candidate exe;{new_exe.name}',
             f'# sha256 reference;{sha_ref}', f'# sha256 candidate;{sha_new}',
             f'# rows reference;{res["n_rows_ref"]}', f'# rows candidate;{res["n_rows_new"]}',
             f'# header equal;{res["header_equal"]}',
             f'# differing columns;{res["n_differing_columns"]}',
             'column;differing_rows;first_row;ref_value;new_value']
    for c in res['columns']:
        f = c['first']
        lines.append(';'.join([c['column'], str(c['differing_rows']),
                               '' if f is None else str(f[0]),
                               '' if f is None else f[1],
                               '' if f is None else f[2]]))
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def check_golden(path: Path, header: list, label: str) -> bool:
    """Compare a header with the golden list; write the golden file when missing."""
    if not path.is_file():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('\n'.join(header) + '\n', encoding='utf-8')
        print(f'  golden header written: {path.name} ({len(header)} columns)')
        return True
    golden = [l.strip() for l in path.read_text(encoding='utf-8').splitlines() if l.strip()]
    if golden == header:
        print(f'  golden header: {label} matches ({len(header)} columns)')
        return True
    print(f'  golden header: {label} MISMATCH')
    missing = [c for c in golden if c not in header]
    extra = [c for c in header if c not in golden]
    if missing:
        print(f'      missing: {", ".join(missing)}')
    if extra:
        print(f'      extra  : {", ".join(extra)}')
    if not missing and not extra:
        print('      the same columns in a different order')
    return False


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--ref-exe', required=True, help='executable of the reference sources')
    ap.add_argument('--new-exe', required=True, help='executable of the changed sources')
    ap.add_argument('--case', default='tests/CAPITOUL', help='case directory (default: tests/CAPITOUL)')
    ap.add_argument('--steps', type=int, default=None, help='run only the first N forcing steps')
    ap.add_argument('--param-nml', default=None, help='parameter namelist file (passed via -param_nml)')
    ap.add_argument('--out-root', default='python_tests/container_ab', help='root of the run outputs')
    ap.add_argument('--golden', default=None, help='file with the expected CSV header (one column per line)')
    ap.add_argument('--timeout', type=float, default=None, help='seconds allowed per run')
    args = ap.parse_args(argv)

    case = (MODEL_DIR / args.case).resolve()
    ref_exe = (MODEL_DIR / args.ref_exe).resolve()
    new_exe = (MODEL_DIR / args.new_exe).resolve()
    out_root = (MODEL_DIR / args.out_root).resolve()
    for path in (case, ref_exe, new_exe):
        if not path.exists():
            sys.exit(f'ERROR: not found: {path}')

    forcing_nml = case / 'namelist' / 'namelist_forcing.nml'
    if not forcing_nml.is_file():
        sys.exit(f'ERROR: forcing namelist not found: {forcing_nml}')
    if args.steps is not None:
        forcing_nml = make_short_namelist(
            forcing_nml, out_root / f'namelist_forcing_{args.steps}steps.nml', args.steps)
        print(f'short run: nsteps = {args.steps} ({forcing_nml.name})')

    param_nml = (MODEL_DIR / args.param_nml).resolve() if args.param_nml else None

    print(f'A/B comparison: {args.case}')
    run_case(ref_exe, case, forcing_nml, out_root / 'ref', args.timeout, param_nml)
    run_case(new_exe, case, forcing_nml, out_root / 'new', args.timeout, param_nml)

    ref_csv = out_root / 'ref' / 'TEB_output_b1_c1.csv'
    new_csv = out_root / 'new' / 'TEB_output_b1_c1.csv'
    for path in (ref_csv, new_csv):
        if not path.is_file():
            sys.exit(f'ERROR: no output written: {path}')

    res = compare(ref_csv, new_csv)
    sha_ref, sha_new = sha256(ref_csv), sha256(new_csv)
    write_summary(out_root / 'summary_container_ab.csv', res, ref_exe, new_exe, sha_ref, sha_new)

    print(f'  rows        : reference {res["n_rows_ref"]}, candidate {res["n_rows_new"]}'
          f' (compared {res["n_rows_compared"]})')
    print(f'  header      : {"equal" if res["header_equal"] else "MISMATCH"}')
    if res['only_ref']:
        print(f'      only in reference: {", ".join(res["only_ref"])}')
    if res['only_new']:
        print(f'      only in candidate: {", ".join(res["only_new"])}')
    print(f'  columns     : {res["n_differing_columns"]} of {len(res["columns"])} differ')
    for c in [c for c in res['columns'] if c['differing_rows']][:20]:
        f = c['first']
        print(f'      {c["column"]}: {c["differing_rows"]} rows,'
              f' first row {f[0]}: {f[1]} != {f[2]}')
    print(f'  sha256 ref  : {sha_ref}')
    print(f'  sha256 new  : {sha_new}')
    print(f'  summary     : {out_root / "summary_container_ab.csv"}')

    ok = True
    if args.golden:
        golden = (MODEL_DIR / args.golden).resolve()
        ok &= check_golden(golden, res['header_ref'], 'reference')
        ok &= check_golden(golden, res['header_new'], 'candidate')
    print('  RESULT: ' + ('IDENTICAL (bit-for-bit)' if res['ok'] else 'DIFFERS'))
    return 0 if (res['ok'] and ok) else 1


if __name__ == '__main__':
    sys.exit(main())
