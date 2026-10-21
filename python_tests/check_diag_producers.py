#!/usr/bin/env python
"""Producer check of the DIAG_MISC_TEB_t fields (refactor guard).

`check_diag_container.py` verifies that every field of the diagnostics container
is declared, NULLIFY-ed, ALLOCATEd and DEALLOCATEd. It does not verify that the
field is ever *written*: the four lists can agree while a field stays a pure
placeholder, and a Fortran pointer that is never assigned silently reads as 0.

That is exactly how a real defect appeared (change history, defect N3): the
container refactor added `XSOBS`/`XTHBS` for `teb_sobs`/`teb_thbs` with the four
lists in sync but no producer, and a later step made `TEB_INTERFACE` read them.
`teb_thbs` became 0, the offline garden emulator lost the incoming longwave
radiation and the garden surface balance was 3.2 K off on the first sub-step.

A field is considered produced when it is

  * directly assigned:  `DMT%XFOO(:) = ...` or `DMT%XFOO => ...`, or
  * passed as an actual argument whose dummy is `INTENT(OUT)`/`INTENT(INOUT)`
    (positional or keyword form) of a routine defined in the same tree.

Fields that are deliberately left without a producer are listed in `ALLOWED`
with the reason; everything else is an error.

Usage
-----
    python python_tests/check_diag_producers.py             # src_dev
    python python_tests/check_diag_producers.py --json      # machine-readable
    python python_tests/check_diag_producers.py --tree src_ctrl

Exit code: 0 when every non-reserved field has a producer, 1 otherwise.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parent

TYPE_FILE = 'src_struct/modd_diag_misc_tebn.F90'

RE_FIELD = re.compile(r'^\s*REAL\s*,\s*POINTER\s*,\s*DIMENSION\(:\)\s*::\s*(X\w+)', re.I)
#: a direct assignment; `= XUNDEF` is only a guard against reading garbage, not a
#: producer, so it does not count
RE_ASSIGN = re.compile(r'\bDMT%(\w+)\s*(?:\([^)]*\))?\s*=(?!=)\s*(?!XUNDEF\b)', re.I)
RE_ASSOC = re.compile(r'\bDMT%(\w+)\s*=>')
RE_SUB = re.compile(r'\s*(?:SUBROUTINE|FUNCTION)\s+(\w+)\s*(?:\((.*)\))?\s*$', re.I)
RE_END_SUB = re.compile(r'\s*END\s+(?:SUBROUTINE|FUNCTION)\b', re.I)
RE_INTENT = re.compile(r'INTENT\s*\(\s*(OUT|INOUT)\s*\)', re.I)
RE_CALL = re.compile(r'\s*CALL\s+(\w+)\s*\((.*)\)\s*$', re.I)
#: legacy output marker of the SURFEX headers: `! teb_ac_rd - OUT ...`
RE_LEGACY_OUT = re.compile(r'\bOUT\b', re.I)

#: fields allowed to have no producer: name -> (label, reason)
ALLOWED = {
    'XIRRIG_GARDEN': ('reserved',
                      'garden irrigation is not implemented (PIRRIG_GARDEN = 0.)'),
    # The frozen control tree (src_ctrl) and origin/main keep the original layout,
    # where these six are copied from DMT into the caller AFTER the local wrapper
    # has computed them, and DMT itself is never written: they are dead in the
    # original model (uninitialised values returned to the host). src_dev passes
    # them straight to TEB as INTENT(OUT) arguments, so there they are produced.
    'XEMIT_LW_FAC': ('original', 'dead in the original model, computed in src_dev'),
    'XEMIT_LW_GRND': ('original', 'dead in the original model, computed in src_dev'),
    'XT_RAD_IND': ('original', 'dead in the original model, computed in src_dev'),
    'XREF_SW_GRND': ('original', 'dead in the original model, computed in src_dev'),
    'XREF_SW_FAC': ('original', 'dead in the original model, computed in src_dev'),
    'XHU_BLD': ('original', 'dead in the original model, computed in src_dev'),
}


def statements(path: Path):
    """Yield (first_line, joined code, joined comment) of every statement.

    Comment-only lines inside a continued statement must not terminate it (the
    long `CALL TEB` / `CALL AVG_URBAN_FLUXES` argument lists carry them), so
    they are skipped instead of flushing the buffer. The comments are kept
    separately: the legacy declarations mark the output dummies with `!OUT`
    instead of an `INTENT(OUT)`.
    """
    buf, cmt, start = '', '', 0
    for i, raw in enumerate(path.read_text(encoding='utf-8', errors='ignore').splitlines(), 1):
        code, _, comment = raw.partition('!')
        if not code.strip():
            cmt += ' ' + comment
            continue
        if not buf:
            start = i
        buf += ' ' + code
        if not code.rstrip().endswith('&'):
            yield start, buf.replace('&', ' '), cmt
            buf, cmt = '', ''
    if buf:
        yield start, buf.replace('&', ' '), cmt


def split_args(text: str) -> list:
    """Split an actual/dummy argument list at top-level commas."""
    out, depth, cur = [], 0, ''
    for ch in text:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur.strip())
            cur = ''
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def _name(decl: str) -> str:
    m = re.match(r'(\w+)', decl.strip())
    return m.group(1).upper() if m else ''


def collect(tree: Path) -> dict:
    """Return the fields, their producers and the reads that were seen."""
    type_path = tree / TYPE_FILE
    if not type_path.is_file():
        sys.exit(f'ERROR: file not found: {type_path}')
    fields = [m.group(1) for m in
              (RE_FIELD.match(l) for l in
               type_path.read_text(encoding='utf-8', errors='ignore').splitlines())
              if m]

    dummies, out_dummies = {}, {}
    current = None
    files = [p for p in tree.rglob('*') if p.suffix in ('.F90', '.f90', '.F')]
    for path in files:
        for _, st, cm in statements(path):
            m = RE_SUB.match(st)
            if m:
                current = m.group(1).upper()
                dummies[current] = [_name(a) for a in split_args(m.group(2) or '')]
                continue
            if RE_END_SUB.match(st):
                current = None
                continue
            if current and '::' in st and (RE_INTENT.search(st) or RE_LEGACY_OUT.search(cm)):
                for decl in split_args(st.split('::', 1)[1]):
                    out_dummies.setdefault(current, set()).add(_name(decl))

    assigned, produced, unknown = set(), set(), {}
    for path in files:
        for _, st, _ in statements(path):
            for m in RE_ASSIGN.finditer(st):
                assigned.add(m.group(1))
            for m in RE_ASSOC.finditer(st):
                assigned.add(m.group(1))
            mc = RE_CALL.match(st)
            if not mc:
                continue
            callee = mc.group(1).upper()
            for pos, arg in enumerate(split_args(mc.group(2))):
                kw = re.match(r'(\w+)\s*=\s*(.+)$', arg)
                if kw:
                    dummy, value = kw.group(1).upper(), kw.group(2)
                else:
                    dummy, value = None, arg
                mm = re.match(r'DMT%(\w+)', value)
                if not mm:
                    continue
                field = mm.group(1)
                if dummy is None:
                    guess = dummies.get(callee)
                    if guess is None or pos >= len(guess):
                        unknown.setdefault(field, set()).add(f'{callee}?')
                        continue
                    dummy = guess[pos]
                if dummy in out_dummies.get(callee, set()):
                    produced.add(field)
                else:
                    unknown.setdefault(field, set()).add(f'{callee}.{dummy}')

    return {'tree': str(tree), 'fields': fields, 'assigned': assigned,
            'produced': produced, 'unknown': unknown}


def compare(info: dict) -> dict:
    fields = info['fields']
    written = info['assigned'] | info['produced']
    dead = [f for f in fields if f not in written]
    errors = [f for f in dead if f not in ALLOWED]
    out = {
        'n_fields': len(fields),
        'n_assigned': len(set(fields) & info['assigned']),
        'n_call_argument': len(set(fields) & info['produced']),
        'dead': dead,
        'allowed': {f: ALLOWED[f] for f in dead if f in ALLOWED},
        'errors': errors,
        'unresolved': sorted(f for f in fields
                             if f in info['unknown'] and f not in written),
    }
    out['ok'] = not errors
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--tree', default='src_dev', help='source tree (default: src_dev)')
    ap.add_argument('--json', action='store_true', help='print the result as JSON')
    args = ap.parse_args(argv)

    tree = (MODEL_DIR / args.tree).resolve()
    res = compare(collect(tree))
    res['tree'] = str(tree)

    if args.json:
        print(json.dumps(res, indent=2, ensure_ascii=False))
        return 0 if res['ok'] else 1

    print(f'DIAG_MISC_TEB_t producers  [{args.tree}]')
    print(f'  type fields                 : {res["n_fields"]}')
    print(f'  assigned directly           : {res["n_assigned"]}')
    print(f'  written through OUT/INOUT   : {res["n_call_argument"]}')
    print(f'  without a producer          : {len(res["dead"])}')
    for f in res['dead']:
        label, reason = res['allowed'].get(f, ('ERROR', ''))
        print(f'      {f:<22} {label:<9} {reason}')
    if res['unresolved']:
        print(f'  provenance unresolved       : {", ".join(res["unresolved"])}'
              ' (passed to a routine whose dummy is neither INTENT(OUT/INOUT) nor !OUT)')
    print('  RESULT:', 'OK' if res['ok'] else 'MISSING PRODUCER(S)')
    return 0 if res['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
