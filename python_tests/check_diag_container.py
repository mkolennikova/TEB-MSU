#!/usr/bin/env python
"""Consistency check of the DIAG_MISC_TEB_t field lists (refactor guard).

The diagnostics container of the TEB physics is declared in four places that
must stay in sync:

  1. `src_struct/modd_diag_misc_tebn.F90`
       * `TYPE(DIAG_MISC_TEB_t)` - every field is declared as
         `REAL, POINTER, DIMENSION(:) :: X<NAME>`;
       * `SUBROUTINE DIAG_MISC_TEB_INIT` - every field is NULLIFY-ed there;
  2. `src_struct/alloc_teb_struct.F90`   - `ALLOCATE(DMT%X<NAME>(...))`
  3. `src_struct/dealloc_teb_struct.F90` - `DEALLOCATE(DMT%X<NAME>)`

A field that is missing from the allocation list is a crash (used but never
allocated), a field missing from the deallocation list is a leak, and a field
missing from the type is a compile error at best. All of them are silent in
Fortran, and the container refactor adds dozens of fields by hand, so the check
is run before and after every step of the refactor.

The CBS branch diagnostics are a single record `TEB_CBS_BRANCH_t` used twice
(`CAN` = canyon air, `ATM` = forcing level): its components are declared once and
their lifecycle lives in `INIT_CBS_BRANCH`/`ALLOC_CBS_BRANCH`/`DEALLOC_CBS_BRANCH`
of `MODI_DIAG_MISC_TEB_UTIL`. The check expands them into `<INSTANCE>%<COMPONENT>`
names and also fails when the driver never calls a helper for one of the instances
or when a component is missing from a helper body.

Usage
-----
    python python_tests/check_diag_container.py              # src_dev
    python python_tests/check_diag_container.py --tree src_ctrl
    python python_tests/check_diag_container.py --json       # machine-readable

Exit code: 0 when the four lists agree, 1 otherwise.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parent

#: field of the type: `REAL, POINTER, DIMENSION(:)   :: XFOO`
RE_TYPE = re.compile(r'^\s*REAL\s*,\s*POINTER\s*,\s*DIMENSION\(:\)\s*::\s*(X\w+)', re.I)
#: inside DIAG_MISC_TEB_INIT: `NULLIFY(YDIAG_MISC_TEB%XFOO)`
RE_NULLIFY = re.compile(r'NULLIFY\(\s*YDIAG_MISC_TEB%(\w+)\s*\)', re.I)
#: `ALLOCATE(DMT%XFOO(1))` (the historical location) or
#: `ALLOCATE(YDIAG_MISC_TEB%XFOO(KB))` (modi_diag_misc_teb_util, Phase 4b)
RE_ALLOC = re.compile(r'ALLOCATE\(\s*(?:DMT|YDIAG_MISC_TEB)%(\w+)\s*\(', re.I)
#: `DEALLOCATE(DMT%XFOO)` or `DEALLOCATE(YDIAG_MISC_TEB%XFOO)`
RE_DEALLOC = re.compile(r'DEALLOCATE\(\s*(?:DMT|YDIAG_MISC_TEB)%(\w+)\s*\)', re.I)

FILES = {
    'type': 'src_struct/modd_diag_misc_tebn.F90',
    'nullify': 'src_struct/modd_diag_misc_tebn.F90',
    # the allocation lists live in the utilities module since the driver owns the
    # container (Phase 4b); they used to sit in alloc/dealloc_teb_struct.F90
    'alloc': 'src_struct/modi_diag_misc_teb_util.F90',
    'dealloc': 'src_struct/modi_diag_misc_teb_util.F90',
}

#: nested record shared by the two CBS exchange paths and its two instances
BRANCH_TYPE = 'TEB_CBS_BRANCH_t'
BRANCH_INSTANCES = ('CAN', 'ATM')
#: one lifecycle helper per list, each acting on one instance (`YBRANCH`); the
#: checks below expand them into `<INSTANCE>%<COMPONENT>` names
BRANCH_HELPERS = {'nullify': 'INIT_CBS_BRANCH',
                  'alloc': 'ALLOC_CBS_BRANCH',
                  'dealloc': 'DEALLOC_CBS_BRANCH'}

RE_BRANCH_TYPE = re.compile(r'^\s*TYPE\s+' + BRANCH_TYPE + r'\b', re.I)
RE_END_TYPE = re.compile(r'^\s*END\s*TYPE\b', re.I)
RE_BRANCH_COMPONENT = re.compile(r'^\s*REAL[^!\n]*?::\s*(\w+)', re.I)
RE_BRANCH_REF = re.compile(r'\bYBRANCH%(\w+)', re.I)


def _resolve(tree: Path, key: str) -> Path:
    """Path of one list; the allocation lists moved in Phase 4b (dev only)."""
    path = tree / FILES[key]
    if key in ('alloc', 'dealloc') and not path.is_file():
        legacy = 'src_struct/alloc_teb_struct.F90' if key == 'alloc' \
            else 'src_struct/dealloc_teb_struct.F90'
        return tree / legacy
    return path


def _read(tree: Path, rel: str) -> list:
    path = tree / rel
    if not path.is_file():
        sys.exit(f'ERROR: file not found: {path}')
    return path.read_text(encoding='utf-8', errors='ignore').splitlines()


def _branch_components(type_lines: list) -> list:
    """Components of the nested `TEB_CBS_BRANCH_t` record (empty when absent)."""
    out, inside = [], False
    for line in type_lines:
        if not inside:
            if RE_BRANCH_TYPE.match(line):
                inside = True
            continue
        if RE_END_TYPE.match(line):
            break
        m = RE_BRANCH_COMPONENT.match(line)
        if m:
            out.append(m.group(1))
    return out


def _helper_body(util_lines: list, name: str) -> list:
    """Lines of one lifecycle helper of the nested record."""
    start = next((i for i, l in enumerate(util_lines)
                  if re.match(r'\s*SUBROUTINE\s+' + name + r'\b', l, re.I)), None)
    if start is None:
        return []
    end = next((i for i in range(start, len(util_lines))
                if re.match(r'\s*END\s+SUBROUTINE\b', util_lines[i], re.I)), len(util_lines))
    return util_lines[start:end + 1]


def _branch_lists(util_lines: list, components: list) -> dict:
    """Expand the lifecycle helpers into `<INSTANCE>%<COMPONENT>` names.

    A helper covers an instance only when the driver calls it for that instance; a
    missing call leaves the whole instance out of the list and `compare()` reports
    it as missing. A component missing from a helper body is reported the same way.
    """
    out = {}
    for key, helper in BRANCH_HELPERS.items():
        handled = {m.group(1) for l in _helper_body(util_lines, helper)
                   for m in [RE_BRANCH_REF.search(l)] if m}
        names = []
        for inst in BRANCH_INSTANCES:
            called = any(re.search(r'CALL\s+' + helper + r'\s*\(\s*YDIAG_MISC_TEB%'
                                   + inst + r'\b', l, re.I) for l in util_lines)
            if called:
                names += [f'{inst}%{c}' for c in components if c in handled]
        out[key] = names
    return out


def collect(tree: Path) -> dict:
    """Return the four field lists of the tree (order of appearance)."""
    type_lines = _read(tree, FILES['type'])
    alloc_lines = _read(tree, str(_resolve(tree, 'alloc').relative_to(tree)))
    dealloc_lines = _read(tree, str(_resolve(tree, 'dealloc').relative_to(tree)))
    util_lines = _read(tree, FILES['alloc'])

    fields = [m.group(1) for m in (RE_TYPE.match(l) for l in type_lines) if m]

    # the NULLIFY list lives in DIAG_MISC_TEB_INIT: restrict the scan to it
    start = next((i for i, l in enumerate(type_lines)
                  if l.strip().upper().startswith('SUBROUTINE DIAG_MISC_TEB_INIT')), None)
    if start is None:
        sys.exit(f'ERROR: SUBROUTINE DIAG_MISC_TEB_INIT not found in {FILES["type"]}')
    end = next((i for i in range(start, len(type_lines))
                if type_lines[i].strip().upper().startswith('END SUBROUTINE DIAG_MISC_TEB_INIT')),
               len(type_lines))
    nullified = [m.group(1) for m in (RE_NULLIFY.search(l) for l in type_lines[start:end]) if m]

    allocated = [m.group(1) for m in (RE_ALLOC.search(l) for l in alloc_lines) if m]
    deallocated = [m.group(1) for m in (RE_DEALLOC.search(l) for l in dealloc_lines) if m]

    # the nested record used twice by the CBS scheme: one logical field per instance
    components = _branch_components(type_lines)
    if components:
        fields += [f'{inst}%{c}' for inst in BRANCH_INSTANCES for c in components]
        branch = _branch_lists(type_lines + util_lines, components)
        nullified += branch['nullify']
        allocated += branch['alloc']
        deallocated += branch['dealloc']

    return {'tree': str(tree), 'type': fields, 'nullify': nullified,
            'alloc': allocated, 'dealloc': deallocated}


def compare(lists: dict) -> dict:
    """Set differences between the lists, with the severity of each difference.

    * a field that is ALLOCATED but never DEALLOCATED is a leak, and the other way
      round it is a crash - both are errors;
    * a field that is missing from the NULLIFY list of DIAG_MISC_TEB_INIT breaks the
      SURFEX `_INIT` contract but is harmless while ALLOC_TEB_STRUCT allocates the
      field right after the call (the pointer is associated anyway), so it is a
      warning; `--strict` turns it into an error.
    """
    fields = lists['type']
    out = {'n_type': len(fields)}
    for name in ('nullify', 'alloc', 'dealloc'):
        other = lists[name]
        out[f'n_{name}'] = len(other)
        out[f'{name}_missing'] = sorted(set(fields) - set(other))
        out[f'{name}_extra'] = sorted(set(other) - set(fields))
    out['type_duplicates'] = sorted({f for f in fields if fields.count(f) > 1})
    errors = ([out[f'{n}_{k}'] for n in ('alloc', 'dealloc') for k in ('missing', 'extra')]
              + [out['type_duplicates']])
    out['n_errors'] = sum(len(e) for e in errors)
    out['n_warnings'] = len(out['nullify_missing']) + len(out['nullify_extra'])
    out['ok'] = out['n_errors'] == 0
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--tree', default='src_dev', help='source tree (default: src_dev)')
    ap.add_argument('--json', action='store_true', help='print the result as JSON')
    ap.add_argument('--strict', action='store_true',
                    help='treat the NULLIFY warnings as errors (exit 1)')
    args = ap.parse_args(argv)

    tree = (MODEL_DIR / args.tree).resolve()
    lists = collect(tree)
    res = compare(lists)
    res['tree'] = str(tree)

    if args.json:
        print(json.dumps(res, indent=2, ensure_ascii=False))
        return 0 if (res['ok'] and (not args.strict or res['n_warnings'] == 0)) else 1

    print(f"DIAG_MISC_TEB_t field lists  [{args.tree}]")
    print(f"  type fields          : {res['n_type']}")
    for name in ('nullify', 'alloc', 'dealloc'):
        bad = res[f'{name}_missing'] or res[f'{name}_extra']
        tag = ('ok' if not bad else
               ('WARN' if name == 'nullify' else 'ERROR'))
        print(f"  {name + ' list':<21}: {res[f'n_{name}']:<4} {tag}")
        if res[f'{name}_missing']:
            print(f"      missing ({len(res[f'{name}_missing'])}): "
                  f"{', '.join(res[f'{name}_missing'])}")
        if res[f'{name}_extra']:
            print(f"      extra   : {', '.join(res[f'{name}_extra'])}")
    if res['type_duplicates']:
        print(f"  duplicate fields     : {', '.join(res['type_duplicates'])}")
    verdict = 'OK' if res['ok'] else 'INCONSISTENT'
    if res['ok'] and res['n_warnings']:
        verdict = f'OK with {res["n_warnings"]} warning(s)'
    print(f'  RESULT: {verdict}')
    return 0 if (res['ok'] and (not args.strict or res['n_warnings'] == 0)) else 1


if __name__ == '__main__':
    sys.exit(main())
