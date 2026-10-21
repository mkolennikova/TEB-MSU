#!/usr/bin/env python
"""Inventory of the dev driver diagnostics: what may move into a container.

Phase 1 of the diagnostics-container refactor. The script reads the dev sources
(read-only) and produces the working table for the review:

  * every `REAL, DIMENSION(...)` declaration of `run_teb_offline.F90`, with the
    class it belongs to (forcing / urban parameter / emulator / exchange
    coefficient / TEB diagnostic / TEB state) and the reason for the class;
  * the CSV contract: the ordered list of `out_names(nout) = 'COLUMN'` items
    next to the ordered list of `CALL CSV_APPEND(out_line, <source>)` values,
    so that every column can be traced to the variable that feeds it;
  * the list of fields the container would need (`X` + the current name), with
    the collisions against the fields that `DIAG_MISC_TEB_t` already has, and
    the names that already exist in the type under a different meaning.

The classification is a review aid, not an authority: `INTENT(OUT)` of
`teb_interface` is used as the signal "this is a diagnostic of the physics", and
everything else is listed for a manual decision (the `state` class of TEB holds
both the model state and the surface diagnostics declared without INTENT).

Usage
-----
    python python_tests/diag_container_inventory.py
    python python_tests/diag_container_inventory.py --out-root python_tests/diag_container

Files written into `<out-root>` (ignored by git): `summary.md`,
`driver_declarations.csv`, `csv_contract.csv`.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parent

#: forcing / driver input carriers (they stay explicit arguments)
FORCING = {
    'lon_teb', 'lat_teb', 'hlev_teb', 'sa_uc', 'u', 'v', 't', 'qv', 'ps', 'rho',
    'prr_con', 'prs_con', 'prr_gsp', 'prs_gsp', 'prg_gsp', 'lwd_s', 'swdir_s',
    'swdifd_s', 'fr_garden', 'ahf_traffic', 'ahf_industry',
}

#: exchange-coefficient families (diagnostics of URBAN_DRAG / URBAN_EXCH_COEF)
RE_COEF = re.compile(r'^(PCD|PCDN|PAC|PCH|PRI|ZZ0H)')

#: the CBS / snow / water diagnostics that are spelled in upper case in the driver
CBS_DIAG = {
    'PH_ROAD_CAN', 'PLE_ROAD_CAN', 'PH_ROAD_ATM', 'PLE_ROAD_ATM', 'PT_CAN0',
    'PT_CAN1', 'PPHI_CAN1', 'PH_ROAD', 'PLE_ROAD', 'PDN_RD', 'LE_ROAD_WAT',
    'LE_ROAD_SNOW', 'PDN_RF', 'LE_ROOF_WAT', 'LE_ROOF_SNOW', 'ahf_traffic_now',
}

#: container field name of the driver names whose automatic transform
#: ('X' + the name without the `teb_` prefix) would be wrong or misleading.
#: The targets that DIAG_MISC_TEB_t already declares are REUSED, not added.
FIELD_OVERRIDES = {
    # aggregates of the town budget: the type has only the per-surface fields
    'teb_shfl': 'XH_TOWN',              # CSV column H_TOWN
    'teb_lhfl': 'XLE_TOWN',             # CSV column LE_TOWN
    'teb_rn_town': 'XRN_TOWN',          # CSV column RN_TOWN
    'teb_gflux': 'XGFLUX_TOWN',         # CSV column GFLUX_TOWN
    # surface temperatures: the type has no XTS_* field (X.._ROOF in TEB_t are the layers)
    'teb_tsroof': 'XTS_ROOF',
    'teb_tsroad': 'XTS_ROAD',
    'teb_tswalla': 'XTS_WALL_A',
    'teb_tswallb': 'XTS_WALL_B',
    # per-surface fluxes: the SURFEX names of the fractions (cf. ZH_ROOF_FR in CALL_DRIVER)
    'teb_shfl_rf': 'XH_ROOF_FR',
    'teb_shfl_rd': 'XH_ROAD_FR',
    'teb_shfl_wl': 'XH_WALL_FR',
    # quantities that the type already carries under its own name: REUSE
    'teb_hwaste': 'XH_WASTE',
    'teb_lewaste': 'XLE_WASTE',
    'teb_hvac_cool': 'XHVAC_COOL',
    'teb_hvac_heat': 'XHVAC_HEAT',
    'teb_dqs_town': 'XDQS_TOWN',
    # exported URBAN_DRAG coefficients of the external garden (CSV PCD/PCH_GARDEN_ATM)
    'teb_cd_garden_atm': 'XCD_GARDEN_ATM',
    'teb_ch_garden_atm': 'XCH_GARDEN_ATM',
}

#: declarations that carry no comment: classified by hand
MANUAL = {
    'teb_cd_garden_atm': ('DIAG', 'exported URBAN_DRAG coefficient of the external garden'),
    'teb_ch_garden_atm': ('DIAG', 'exported URBAN_DRAG coefficient of the external garden'),
}

RE_DECL = re.compile(r'^REAL\s*,\s*DIMENSION\(([^)]*)\)\s*::\s*(\w+)\s*(!:?.*)?$')
RE_OUTNAME = re.compile(r"out_names\(nout\)\s*=\s*'([^']+)'")
RE_APPEND = re.compile(r'CALL\s+CSV_APPEND\(out_line,\s*(.+?)\)\s*$')
RE_FIELD = re.compile(r'^\s*REAL\s*,\s*POINTER\s*,\s*DIMENSION\(:\)\s*::\s*(X\w+)', re.I)
RE_INTENT_OUT = re.compile(r'INTENT\(OUT\)\s*::\s*(\w+)', re.I)


def read_lines(tree: Path, rel: str) -> list:
    path = tree / rel
    if not path.is_file():
        sys.exit(f'ERROR: file not found: {path}')
    return path.read_text(encoding='utf-8', errors='ignore').splitlines()


def declarations(tree: Path):
    """(name, dimension, comment) of every REAL DIMENSION declaration of the driver."""
    out = []
    for line in read_lines(tree, 'src_driver/run_teb_offline.F90'):
        m = RE_DECL.match(line.strip())
        if m:
            out.append((m.group(2), m.group(1).strip(), (m.group(3) or '').lstrip('!: ').strip()))
    return out


def csv_contract(tree: Path):
    """(column names, source expressions) of the CSV writer of the tree.

    Two formats are understood:

    * the table-driven writer of the current dev code: one
      `CALL CSV_ADD(hdr_line, out_line, ncol, col_name, 'NAME', <source>)` per
      column and nothing else;
    * the historical pair of parallel lists (`out_names(nout) = 'NAME'` and
      `CALL CSV_APPEND(out_line, <source>)`), still used by the control tree.
    """
    lines = read_lines(tree, 'src_driver/run_teb_offline.F90')
    prefix = 'CALL CSV_ADD(hdr_line, out_line, ncol, col_name,'
    names, sources = [], []
    for line in lines:
        s = line.strip()
        if not s.startswith(prefix):
            continue
        rest = s[len(prefix):].strip()
        if not rest.endswith(')'):
            sys.exit(f'unexpected CSV_ADD line: {s!r}')
        rest = rest[:-1].rstrip()               # drop the closing paren of the CALL
        m = re.match(r"'([^']+)'\s*,\s*(.*)$", rest)
        if not m:
            sys.exit(f'cannot read the column name out of: {s!r}')
        names.append(m.group(1))
        sources.append(m.group(2).strip())
    if names:
        return names, sources
    for line in lines:                          # legacy two-list writer
        m = RE_OUTNAME.search(line)
        if m:
            names.append(m.group(1))
        m = RE_APPEND.search(line.strip())
        if m:
            sources.append(m.group(1).strip())
    return names, sources


def intent_out(tree: Path) -> set:
    """Names declared `INTENT(OUT)` in teb_interface: the physics diagnostics."""
    return {m.group(1) for m in
            (RE_INTENT_OUT.search(l) for l in read_lines(tree, 'src_driver/sfc_teb.F90')) if m}


def dmt_fields(tree: Path) -> list:
    """Fields already declared in DIAG_MISC_TEB_t."""
    return [m.group(1) for m in
            (RE_FIELD.match(l) for l in read_lines(tree, 'src_struct/modd_diag_misc_tebn.F90')) if m]


def classify(name: str, comment: str):
    """(class, reason) of one driver declaration.

    The declarations of `run_teb_offline.F90` carry their own `!IN`, `!INOUT` or
    `!OUT` comment, which is the authoritative signal of the driver:

    * `!IN` - the driver prescribes the value (namelist, configuration, or the
      state of the external garden / greenroof model): it stays an argument;
    * `!INOUT` - the model state, carried from one sub-step to the next: it stays
      an argument (the container holds diagnostics only);
    * `!OUT` - the value is produced by the physics and only read by the driver:
      it moves into the diagnostics container.

    The families added by TEB-MSU (exchange coefficients, CBS road diagnostics)
    are diagnostics by construction, and a few declarations have no comment and
    are classified by hand (MANUAL).
    """
    if name.startswith('emu_'):
        return 'EMU', 'stays: offline-driver emulator variable'
    if name.startswith('urb_'):
        return 'PARAM', 'stays: urban parameter (namelist)'
    if name in FORCING:
        return 'FORCING', 'stays: forcing / driver input'
    if name in CBS_DIAG or RE_COEF.match(name):
        return 'DIAG', 'moves: exchange / CBS diagnostic of the physics'
    if name in MANUAL:
        return MANUAL[name]
    head = comment.split()[0].upper() if comment else ''
    if head == 'OUT':
        return 'DIAG', 'moves: declared !OUT by the driver'
    if head == 'INOUT':
        return 'STATE', 'stays: model state (!INOUT), carried across sub-steps'
    if head == 'IN':
        return 'INPUT', 'stays: driver input (!IN), prescribed by the driver'
    return 'UNCLASSIFIED', f'review: no usable comment ({comment!r})'


def container_field(name: str) -> str:
    """Container field name of a driver diagnostic (automatic or overridden)."""
    if name in FIELD_OVERRIDES:
        return FIELD_OVERRIDES[name]
    return 'X' + name.replace('teb_', '').upper()


def norm(text: str) -> str:
    """Underscore-insensitive key, to find the same quantity under another name."""
    return text.lower().replace('_', '')


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--tree', default='src_dev', help='source tree (default: src_dev)')
    ap.add_argument('--out-root', default='python_tests/diag_container', help='output directory')
    args = ap.parse_args(argv)

    tree = (MODEL_DIR / args.tree).resolve()
    out_root = (MODEL_DIR / args.out_root).resolve()
    out_root.mkdir(parents=True, exist_ok=True)

    rows = [(n, d, c, *classify(n, c)) for n, d, c in declarations(tree)]
    counts = {}
    for r in rows:
        counts[r[3]] = counts.get(r[3], 0) + 1
    cls_of = {r[0]: r[3] for r in rows}

    fields = dmt_fields(tree)
    moves = sorted([r for r in rows if r[3] == 'DIAG'], key=lambda r: r[0])
    stays = sorted([r for r in rows if r[3] in ('STATE', 'INPUT', 'PARAM', 'FORCING', 'EMU')],
                   key=lambda r: (r[3], r[0]))
    unclassified = [r for r in rows if r[3] == 'UNCLASSIFIED']

    # the CSV contract, and the reverse map (driver variable -> column)
    columns, sources = csv_contract(tree)
    col_of = {}
    for i, col in enumerate(columns):
        src = sources[i] if i < len(sources) else '<missing>'
        m = re.match(r'[A-Za-z_]\w*', src)
        col_of.setdefault(m.group(0) if m else src, col)

    container, new_fields, reused = [], [], []
    for name, dim, comment, _cls, reason in moves:
        field = container_field(name)
        if field in fields:
            note = 'REUSE: the type already declares this field'
            reused.append(field)
        elif any(norm(field) == norm(f) for f in fields):
            same = next(f for f in fields if norm(f) == norm(field))
            note = f'check: the type already has {same}'
            new_fields.append(field)
        else:
            note = 'new field'
            new_fields.append(field)
        note += f', CSV column {col_of[name]}' if name in col_of else ', no direct CSV column'
        container.append((name, field, dim, reason, note))

    # cross-check: every INTENT(OUT) dummy of teb_interface must be a diagnostic
    moved = {r[0] for r in moves}
    mismatch = sorted(n for n in intent_out(tree) if n in cls_of and n not in moved)

    contract = []
    for i, col in enumerate(columns):
        src = sources[i] if i < len(sources) else '<missing>'
        m = re.match(r'[A-Za-z_]\w*', src)
        base = m.group(0) if m else src
        cls = cls_of.get(base, 'driver/other')
        if cls == 'DIAG':
            feed = container_field(base)
        elif cls in ('STATE', 'INPUT', 'PARAM', 'FORCING'):
            feed = '(stays: ' + cls.lower() + ')'
        else:
            feed = '(driver-level expression)'
        contract.append((i + 1, col, src, cls, feed))

    write_csv(out_root / 'driver_declarations.csv',
              ['name', 'dimension', 'comment', 'class', 'reason'], rows)
    write_csv(out_root / 'container_fields.csv',
              ['driver_name', 'container_field', 'dimension', 'reason', 'note'], container)
    write_csv(out_root / 'csv_contract.csv',
              ['order', 'column', 'source', 'source_class', 'container_field_or_driver'],
              contract)
    write_summary(out_root / 'summary.md', args.tree, counts, container, stays,
                  contract, fields, mismatch, unclassified)

    print(f'inventory of {args.tree}: {len(rows)} declared arrays, {len(columns)} CSV columns')
    for cls in ('DIAG', 'STATE', 'INPUT', 'PARAM', 'FORCING', 'EMU', 'UNCLASSIFIED'):
        if counts.get(cls):
            print(f'  {cls:<13} {counts[cls]}')
    print(f'  container fields: {len(container)}'
          f' ({len(reused)} reuse an existing field, {len(new_fields)} new)')
    internal = [c for c in container if c[4].endswith('no direct CSV column')]
    print(f'      of them, no direct CSV column (internal, or aggregated by the driver):'
          f' {len(internal)}')
    if reused:
        print(f'      reuse: {", ".join(reused)}')
    if unclassified:
        print(f'  UNCLASSIFIED: {", ".join(r[0] for r in unclassified)}')
    if mismatch:
        print(f'  INTENT(OUT) but not a diagnostic here: {", ".join(mismatch)}')
    print(f'  CSV contract: {len(sources)} sources for {len(columns)} columns'
          f' -> {"consistent" if len(sources) == len(columns) else "MISMATCH"}')
    driver_level = [c for c in contract if c[3] == 'driver/other']
    print(f'  columns fed by driver-level expressions: {len(driver_level)}'
          f' (e.g. {", ".join(c[1] for c in driver_level[:8])})')
    print(f'  written: {out_root}')
    return 1 if (unclassified or mismatch) else 0


def write_csv(path: Path, header: list, rows: list) -> None:
    lines = [';'.join(header)]
    for r in rows:
        lines.append(';'.join(str(v).replace(';', ',') for v in r))
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def write_summary(path: Path, tree: str, counts: dict, container: list, stays: list,
                  contract: list, fields: list, mismatch: list, unclassified: list) -> None:
    """Markdown working table of the Phase 1 inventory (not a documentation page)."""
    meaning = {
        'DIAG': 'moves into the diagnostics container (declared !OUT by the driver, or an '
                'exchange / CBS diagnostic added by TEB-MSU)',
        'STATE': 'stays an argument: the model state (!INOUT), carried across sub-steps',
        'INPUT': 'stays an argument: prescribed by the driver (!IN: namelist, configuration, '
                 'or the state of the external garden / greenroof model)',
        'PARAM': 'stays an argument: urban parameter of the namelist (urb_*)',
        'FORCING': 'stays an argument: forcing of the run',
        'EMU': 'stays a separate variable: the offline-driver emulator (emu_*), by decision',
        'UNCLASSIFIED': 'MUST BE EMPTY: a declaration the classification did not cover',
    }
    out = [f'# Diagnostics container inventory ({tree})', '',
           'Generated by `python_tests/diag_container_inventory.py` (read-only analysis of the'
           ' dev sources): the Phase 1 working table of the diagnostics-container refactor.',
           '',
           'The class of a declaration comes from its own `!IN` / `!INOUT` / `!OUT` comment in'
           ' `run_teb_offline.F90`; the families added by TEB-MSU (exchange coefficients, CBS'
           ' road diagnostics) are diagnostics by construction, and the two declarations'
           ' without a comment are classified by hand in `MANUAL`.',
           '', '## Driver declarations by class', '',
           '| class | count | meaning |', '| --- | --- | --- |']
    for cls, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        out.append(f'| `{cls}` | {n} | {meaning.get(cls, "")} |')

    out += ['', f'## Container fields ({len(container)})', '',
            '| driver name | container field | dim | why it moves | note |',
            '| --- | --- | --- | --- | --- |']
    for name, field, dim, reason, note in container:
        out.append(f'| `{name}` | `{field}` | `{dim}` | {reason} | {note} |')

    out += ['', f'## Declarations that stay arguments or separate variables ({len(stays)})', '',
            '| name | class | dim | declaration comment |', '| --- | --- | --- | --- |']
    for name, dim, comment, cls, _reason in stays:
        out.append(f'| `{name}` | {cls} | `{dim}` | {comment} |')

    out += ['', '## Cross-checks', '',
            f'* declarations not covered by the classification: {len(unclassified)}'
            + (f' (`{"`, `".join(n for n, *_ in unclassified)}`)' if unclassified else ''),
            f'* `INTENT(OUT)` in `teb_interface` but not a diagnostic here: {len(mismatch)}'
            + (f' (`{"`, `".join(mismatch)}`)' if mismatch else '')]

    out += ['', f'## CSV contract ({len(contract)} columns)', '',
            'Every column of the reference configuration with the variable that feeds it and'
            ' the class of that variable (a container field, a state/input argument, or a'
            ' driver-level expression).', '',
            '| # | column | source | class | fed by |', '| --- | --- | --- | --- | --- |']
    for i, col, src, cls, feed in contract:
        out.append(f'| {i} | `{col}` | `{src}` | {cls} | `{feed}` |')

    out += ['', f'## DIAG_MISC_TEB_t fields already declared ({len(fields)})', '',
            ', '.join(f'`{f}`' for f in fields)]
    path.write_text('\n'.join(out) + '\n', encoding='utf-8')


if __name__ == '__main__':
    sys.exit(main())
