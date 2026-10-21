#!/usr/bin/env python
"""Inventory of the CALL_DRIVER signature: what each dummy argument is.

`CALL_DRIVER` (``src_driver/call_driver.F90``) receives the containers of the
model (TOP, TP, BOP, BP, TSTATE, BSTATE, TPN, TIR, DMT) and, on top of them, a
long list of individual variables. Most of those variables duplicate fields of
the containers; the contract established here is:

    CALL_DRIVER may take, besides the containers,

      * ``transient``  - inputs that are not stored anywhere: the atmospheric
        forcing, the clock and the per-cell indices/coordinates;
      * ``host-emulator`` - the interface of the external garden / green-roof
        emulator, which the host fills (it is not a container of the model);
      * ``deferred``   - the duplicates that are knowingly still passed (each
        group has a phase that removes it, recorded in the history).

Every other dummy is a violation: `--strict` turns it into an error, so the
flag is the gate of the deduplication (after the last phase it passes).

Usage
-----
    python python_tests/call_signature_inventory.py
    python python_tests/call_signature_inventory.py --strict
    python python_tests/call_signature_inventory.py --expect 73

A markdown report is written into ``<out-root>/call_signature.md`` (ignored by
git). ``--expect N`` additionally fails if the signature length differs from N.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parent
DEV = MODEL_DIR / 'src_dev'

SIGNATURE_FILE = DEV / 'src_driver' / 'call_driver.F90'
CALL_FILE = DEV / 'src_api' / 'sfc_teb.F90'

#: the only structured data that may cross the call
CONTAINERS = ['TOP', 'TP', 'BOP', 'BP', 'TSTATE', 'BSTATE', 'TPN', 'TIR', 'DMT']

#: inputs that are not stored anywhere: forcing, clock, per-cell indices
TRANSIENT = [
    'ntstep', 'icell', 'iblock', 'dt',
    'IYEAR', 'IMONTH', 'IDAY', 'IHOUR', 'IMIN', 'ISEC', 'ZTIME',
    'FR_URB', 'ZLON', 'ZLAT', 'ZZREF',
    'u', 'v', 't', 'qv', 'ps',
    'prr_con', 'prs_con', 'prr_gsp', 'prs_gsp', 'prg_gsp',
    'lwd_s', 'swdir_s', 'swdifd_s',
]

#: the interface of the external garden / green-roof emulator (host-owned)
HOST_EMULATOR = [
    'ZZ0_GR_EXT', 'ZALB_GR_EXT', 'ZEMIS_GR_EXT', 'ZTSRAD_GR_EXT', 'ZQV_GR_EXT',
    'ZH_GR_EXT', 'ZLE_GR_EXT', 'ZEVAP_GR_EXT', 'ZRUNOFF_GR_EXT',
    'ZZ0_GD_EXT', 'ZALB_GD_EXT', 'ZEMIS_GD_EXT', 'ZTSRAD_GD_EXT', 'ZQV_GD_EXT',
    'ZH_GD_EXT', 'ZLE_GD_EXT', 'ZEVAP_GD_EXT', 'ZCH_GD', 'ZCD_GD',
    'ZRUNOFF_GD_EXT',
]

#: debt: still passed, with the phase that removes each group (see the history)
DEFERRED = {
    'solar panels and irrigation filled by TEB_GARDEN_STRUCT (P-C4)': [
        'ZFRAC_PANEL', 'LPAR_RD_IRRIG',
        'ZRD_START_MONTH', 'ZRD_END_MONTH', 'ZRD_START_HOUR', 'ZRD_END_HOUR',
        'ZRD_24H_IRRIG',
    ],
}

CONTAINER_SET = set(CONTAINERS)
TRANSIENT_SET = set(TRANSIENT)
HOST_EMULATOR_SET = set(HOST_EMULATOR)
DEFERRED_MAP = {n: g for g, names in DEFERRED.items() for n in names}


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding='utf-8', errors='replace').splitlines()


def extract_args(lines: list[str], marker: str, span: int = 120) -> list[str]:
    """Return the (dummy|actual) argument names of the first match of `marker`.

    The argument list is cut at its outermost parentheses and then split at the
    commas of nesting depth zero, so that ``teb_troad_now(i,:)`` stays one item.
    """
    start = next(i for i, l in enumerate(lines) if marker in l)
    text = ' '.join(l.rstrip() for l in lines[start:start + span])
    s = text.index('(')
    depth = 0
    end = None
    for j in range(s, len(text)):
        if text[j] == '(':
            depth += 1
        elif text[j] == ')':
            depth -= 1
            if depth == 0:
                end = j
                break
    inner = text[s + 1:end]
    items, depth, cur = [], 0, ''
    for ch in inner:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            items.append(cur)
            cur = ''
        else:
            cur += ch
    if cur.strip():
        items.append(cur)
    names = [' '.join(x.replace('&', ' ').split()) for x in items]
    return [n for n in names if n]


def classify(name: str) -> str:
    if name in CONTAINER_SET:
        return 'container'
    if name in TRANSIENT_SET:
        return 'transient'
    if name in HOST_EMULATOR_SET:
        return 'host-emulator'
    if name in DEFERRED_MAP:
        return 'deferred'
    return 'violation'


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--strict', action='store_true',
                    help='fail if any dummy is not container/transient/emulator/deferred')
    ap.add_argument('--expect', type=int, default=None,
                    help='fail if the signature length differs from N')
    ap.add_argument('--json', action='store_true', help='print the report as JSON')
    ap.add_argument('--out-root', default='python_tests/container_fields',
                    help='directory for the markdown report')
    args = ap.parse_args()

    dummies = extract_args(read_lines(SIGNATURE_FILE), 'SUBROUTINE CALL_DRIVER (')
    actuals = extract_args(read_lines(CALL_FILE), 'CALL CALL_DRIVER (')

    rows = []
    counts = {'container': 0, 'transient': 0, 'host-emulator': 0,
              'deferred': 0, 'violation': 0}
    for name in dummies:
        cat = classify(name)
        counts[cat] += 1
        rows.append({'name': name, 'class': cat,
                     'group': DEFERRED_MAP.get(name, '')})

    matched = len(dummies) == len(actuals)

    out_root = Path(args.out_root)
    out_root.mkdir(parents=True, exist_ok=True)
    md = ['# CALL_DRIVER signature inventory', '',
          'Generated by `python_tests/call_signature_inventory.py` (read-only analysis):',
          'the class of every dummy argument of `CALL_DRIVER`.', '',
          '| class | count | meaning |', '| --- | --- | --- |',
          '| `container` | %d | the model containers (TOP/TP/BOP/BP/TSTATE/BSTATE/TPN/TIR/DMT) |' % counts['container'],
          '| `transient` | %d | forcing, clock and per-cell indices (not stored) |' % counts['transient'],
          '| `host-emulator` | %d | interface of the external garden/green-roof emulator |' % counts['host-emulator'],
          '| `deferred` | %d | duplicates knowingly kept (see below) |' % counts['deferred'],
          '| `violation` | %d | duplicates of container fields, to remove |' % counts['violation'],
          '']
    if counts['deferred']:
        md += ['## Deferred (still passed, with the removing phase)', '']
        for g, names in DEFERRED.items():
            md.append('- ' + g + ': `' + '`, `'.join(names) + '`')
        md.append('')
    if counts['violation']:
        md += ['## Violations (duplicates of the containers)', '',
               '| dummy |', '| --- |']
        md += [f'| `{r["name"]}` |' for r in rows if r['class'] == 'violation']
        md.append('')
    (out_root / 'call_signature.md').write_text('\n'.join(md) + '\n', encoding='utf-8')

    if args.json:
        print(json.dumps({'dummies': rows, 'counts': counts,
                          'signature_matches_call': matched,
                          'signature_len': len(dummies), 'call_len': len(actuals)},
                         ensure_ascii=False, indent=2))
        return 0

    print('CALL_DRIVER signature inventory  [src_dev]')
    print(f'  dummies: {len(dummies)}  (transient {counts["transient"]},'
          f' container {counts["container"]}, host-emulator {counts["host-emulator"]},'
          f' deferred {counts["deferred"]}, violation {counts["violation"]})')
    if not matched:
        print(f'  signature/call lengths: {len(dummies)}/{len(actuals)} (should match)')
    if counts['violation']:
        print('  violations (duplicates to remove):')
        for r in rows:
            if r['class'] == 'violation':
                print(f'    {r["name"]}')
    if counts['deferred']:
        print('  deferred (kept on purpose):')
        for g, names in DEFERRED.items():
            print(f'    {g}: ' + ', '.join(names))
    print(f'  written: {out_root / "call_signature.md"}')

    failed = bool(counts['violation'] and args.strict) or not matched
    if args.expect is not None and len(dummies) != args.expect:
        print(f'  length {len(dummies)} != expected {args.expect}')
        failed = True
    print('  RESULT: ' + ('FAIL' if failed else 'OK'))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())

