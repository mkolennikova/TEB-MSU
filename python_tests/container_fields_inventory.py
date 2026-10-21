#!/usr/bin/env python
"""Inventory of the namelist / state containers of the dev tree: what each field is.

Step 0 of the namelist-container plan. The six containers of the offline driver
carry three different kinds of data, and the types do not always say which:

  * `param` - configuration and static parameters (namelist keys, geometry,
    material properties, BEM parameters). Written once per run by the driver;
  * `flux`  - anthropogenic fluxes derived from the namelist (`ahf_traffic`,
    `ahf_industry`); written once per run, read every sub-step;
  * `state` - prognostic state carried across sub-steps (layer temperatures,
    water and snow reservoirs, canyon air, indoor air);
  * `work`  - clock and per-step workspace (date, time step, autosize helpers);
  * `dead`  - declared but not referenced anywhere outside the type, its `*_INIT`
    and the allocation module: SURFEX leftovers of this tree.

The category of every live field is listed in `CATEGORY` below (the contract);
the script verifies that

  * every declared field is either categorised or reported as `dead`, and
  * no categorised field has become `dead` (otherwise the table is stale).

`dead` fields are reported as a warning; `--strict` turns them into an error, so
the flag is the gate of the cleanup step (after the removal it passes).

Usage
-----
    python python_tests/container_fields_inventory.py
    python python_tests/container_fields_inventory.py --strict

Files written into `<out-root>` (ignored by git): `summary.md`,
`container_fields.csv`.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parent

#: bookkeeping files of every type: a reference there does not count as a use
BOOKKEEPING = {'alloc_teb_struct.F90', 'dealloc_teb_struct.F90'}

#: the owner of the param / flux / work fields: the driver sets them once
OWNER = 'run_teb_offline.F90'

#: type -> (module file, code prefix)
TYPES = [
    ('TEB_OPTIONS_t', 'src_struct/modd_teb_optionn.F90', 'TOP'),
    ('TEB_t', 'src_struct/modd_tebn.F90', 'T'),
    ('BEM_OPTIONS_t', 'src_struct/modd_bem_optionn.F90', 'BOP'),
    ('BEM_t', 'src_struct/modd_bemn.F90', 'B'),
    ('TEB_PANEL_t', 'src_struct/modd_teb_paneln.F90', 'TPN'),
    ('TEB_IRRIG_t', 'src_struct/modd_teb_irrign.F90', 'TIR'),
]

#: the contract: category of every live field (dead fields must NOT be listed)
CATEGORY = {
    'TEB_OPTIONS_t': {
        'param': {
            'LCANOPY', 'LGARDEN', 'CROAD_DIR', 'CWALL_OPT', 'CBLD_ATYPE', 'CZ0H',
            'CCH_BEM', 'CBEM', 'CTREE', 'LGREENROOF', 'LHYDRO', 'LSOLAR_PANEL',
            'CTYPE_GARDEN', 'XZ0_O_Z0H_GD', 'CTYPE_GREENROOF', 'XZ0_O_Z0H_GR',
            'LCBS_SCHEME', 'XTAU_HW_THRESH', 'XTAU_HW_WIDTH',
            'NROOF_LAYER', 'NROAD_LAYER', 'NWALL_LAYER',
        },
        'work': {'TTIME', 'XTSTEP'},
        'reserved': {'CBLD_ATYPE', 'CTREE', 'LHYDRO'},
    },
    'TEB_t': {
        'param': {
            'XROAD_DIR', 'XGARDEN', 'XGREENROOF', 'XBLD', 'XROAD', 'XCAN_HW_RATIO',
            'XBLD_HEIGHT', 'XWALL_O_HOR', 'XROAD_O_GRND', 'XGARDEN_O_GRND',
            'XWALL_O_GRND', 'XWALL_O_BLD', 'XZ0_TOWN', 'XZD_TOWN',
            'XSVF_ROAD', 'XSVF_GARDEN', 'XSVF_WALL',
            'XALB_ROOF', 'XEMIS_ROOF', 'XHC_ROOF', 'XTC_ROOF', 'XD_ROOF', 'XROUGH_ROOF',
            'XALB_ROAD', 'XEMIS_ROAD', 'XHC_ROAD', 'XTC_ROAD', 'XD_ROAD',
            'XALB_WALL', 'XEMIS_WALL', 'XHC_WALL', 'XTC_WALL', 'XD_WALL', 'XROUGH_WALL',
            'XRESIDENTIAL', 'XDT_RES', 'XDT_OFF',
        },
        'flux': {'XH_TRAFFIC', 'XLE_TRAFFIC', 'XH_INDUSTRY', 'XLE_INDUSTRY'},
        'state': {
            'XWS_ROOF', 'XWS_ROAD', 'XT_ROOF', 'XT_ROAD', 'XT_WALL_A', 'XT_WALL_B',
            'XT_CANYON', 'XQ_CANYON',
            'TSNOW_ROOF', 'TSNOW_ROAD',
        },
        'reserved': {'TSNOW_GARDEN'},
    },
    'BEM_OPTIONS_t': {
        'param': {'NFLOOR_LAYER', 'CCOOL_COIL', 'CHEAT_COIL', 'LAUTOSIZE'},
    },
    'BEM_t': {
        'param': {
            'CNATVENT',
            'XABS_WIN', 'XALB_WIN', 'XCAP_SYS_HEAT', 'XCAP_SYS_RAT', 'XCOP_RAT',
            'XD_FLOOR', 'XEFF_HEAT',
            'XF_FLOOR_MASS', 'XF_FLOOR_ROOF', 'XF_FLOOR_WALL', 'XF_FLOOR_WIN',
            'XF_MASS_FLOOR', 'XF_MASS_WALL', 'XF_MASS_WIN',
            'XF_WALL_FLOOR', 'XF_WALL_MASS', 'XF_WALL_WIN',
            'XF_WASTE_CAN', 'XF_WATER_COND',
            'XF_WIN_FLOOR', 'XF_WIN_MASS', 'XF_WIN_WALL', 'XF_WIN_WIN',
            'XFLOOR_HEIGHT', 'XFLOOR_HW_RATIO', 'XGLAZ_O_BLD', 'XGR', 'XHC_FLOOR',
            'XHR_TARGET', 'XINF', 'XM_SYS_RAT', 'XMASS_O_BLD', 'XN_FLOOR',
            'XQIN_FLAT', 'XQIN_FRAD', 'XSHGC', 'XSHGC_SH', 'XTC_FLOOR',
            'XTCOOL_TARGET', 'XTHEAT_TARGET', 'XTRAN_WIN', 'XU_WIN', 'XUGG_WIN', 'XV_VENT',
        },
        'state': {
            'XTI_BLD', 'XT_FLOOR', 'XT_MASS', 'XQIN', 'XQI_BLD', 'XT_WIN1', 'XT_WIN2',
            'XSHADE', 'LSHADE', 'XNATVENT', 'LSHAD_DAY', 'LNATVENT_NIGHT',
        },
        'work': {'XAUX_MAX', 'XT_ADP'},
    },
    'TEB_PANEL_t': {
        'param': {'XEMIS_PANEL', 'XALB_PANEL', 'XEFF_PANEL', 'XFRAC_PANEL'},
        'state': {'XTHER_PRODC_DAY'},
    },
    'TEB_IRRIG_t': {
        'param': {
            'LPAR_RD_IRRIG',
            'XRD_START_MONTH', 'XRD_END_MONTH', 'XRD_START_HOUR', 'XRD_END_HOUR', 'XRD_24H_IRRIG',
        },
        'reserved': {
            'LTEB_IRRIG', 'LPAR_GD_IRRIG', 'LPAR_GR_IRRIG',
            'XGD_START_MONTH', 'XGD_END_MONTH', 'XGD_START_HOUR', 'XGD_END_HOUR', 'XGD_24H_IRRIG',
            'XGR_START_MONTH', 'XGR_END_MONTH', 'XGR_START_HOUR', 'XGR_END_HOUR', 'XGR_24H_IRRIG',
        },
    },
}

DECL = re.compile(r'::\s*([A-Z][A-Z0-9_]*)')


def type_fields(path: Path, typ: str) -> list:
    """(field, declaration comment) of the TYPE block of the module."""
    text = path.read_text(encoding='utf-8', errors='replace')
    start = text.find('TYPE ' + typ)
    if start < 0:
        sys.exit(f'{typ}: type block not found in {path}')
    end = text.find('END TYPE ' + typ, start)
    fields = []
    for line in text[start:end].splitlines():
        m = DECL.search(line)
        if m:
            comment = line.split('!', 1)[1].strip() if '!' in line else ''
            fields.append((m.group(1), comment))
    return fields


def sources(tree: Path) -> dict:
    """All sources of the tree, by name (bookkeeping files are filtered later)."""
    out = {}
    for p in sorted(tree.rglob('*')):
        if p.suffix.lower() in ('.f90', '.f') and p.is_file():
            out[p.name] = p.read_text(encoding='utf-8', errors='replace')
    return out


def scan(field: str, prefix: str, src: dict, own_module: str) -> tuple:
    """(references outside the bookkeeping, files that assign to the field)."""
    use = re.compile(r'\b' + prefix + r'%' + field + r'\b')
    write = re.compile(r'\b' + prefix + r'%' + field + r'\b\s*(\([^)]*\))?\s*=[^=]')
    refs, writers = 0, []
    for name, text in src.items():
        if name == own_module or name in BOOKKEEPING:
            continue
        found = use.findall(text)
        if found:
            refs += len(found)
            if write.search(text):
                writers.append(name)
    return refs, writers


LEGEND = {
    'param': 'configuration / static parameter, written once by the driver',
    'flux': 'anthropogenic flux from the namelist, written once per run',
    'state': 'prognostic state carried across sub-steps',
    'work': 'clock and per-step workspace',
    'reserved': 'unused in TEB-MSU, kept as a SURFEX feature placeholder',
    'dead': 'not referenced outside the type and its bookkeeping',
    'UNCLASSIFIED': 'MUST BE EMPTY: add the field to CATEGORY',
}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--tree', default='src_dev', help='source tree (default: src_dev)')
    ap.add_argument('--out-root', default=str(HERE / 'container_fields'),
                    help='output directory (default: python_tests/container_fields)')
    ap.add_argument('--strict', action='store_true',
                    help='treat dead fields as an error (the gate of the cleanup step)')
    ap.add_argument('--enforce-param', action='store_true',
                    help='treat param/flux/work fields assigned outside the driver as an error'
                         ' (the gate of the namelist-container step)')
    args = ap.parse_args()

    tree = (MODEL_DIR / args.tree).resolve()
    if not tree.is_dir():
        sys.exit(f'no such tree: {tree}')
    src = sources(tree)

    rows, dead, unclassified, stale = [], [], [], []
    violations = []
    counts = {}
    for typ, rel, prefix in TYPES:
        module = (tree / rel).resolve()
        if not module.is_file():
            sys.exit(f'{typ}: no module {module}')
        counts[typ] = {}
        known = {f: cat for cat, fields in CATEGORY.get(typ, {}).items() for f in fields}
        for field, comment in type_fields(module, typ):
            refs, writers = scan(field, prefix, src, module.name)
            cat = known.get(field)
            if refs == 0:
                if cat == 'reserved':
                    cat = 'reserved'
                else:
                    dead.append((typ, field))
                    if cat:
                        stale.append((typ, field, cat))
                    cat = 'dead'
            elif cat is None:
                unclassified.append((typ, field))
                cat = 'UNCLASSIFIED'
            rows.append((typ, field, cat, refs, ','.join(sorted(set(writers))), comment))
            counts[typ][cat] = counts[typ].get(cat, 0) + 1
            if cat in ('param', 'flux', 'work'):
                stray = sorted({w for w in writers if w != OWNER})
                if stray:
                    violations.append((typ, field, cat, ','.join(stray)))

    out_root = Path(args.out_root)
    out_root.mkdir(parents=True, exist_ok=True)
    lines = ['type;field;category;refs;writers;declaration']
    lines += [';'.join(str(v).replace(';', ',') for v in r) for r in rows]
    (out_root / 'container_fields.csv').write_text('\n'.join(lines) + '\n', encoding='utf-8')

    out = [f'# Container fields inventory ({args.tree})', '',
           'Generated by `python_tests/container_fields_inventory.py` (read-only analysis of the'
           ' dev sources): the working table of the namelist-container plan.', '',
           '## Fields by category', '',
           '| type | category | count | meaning |', '| --- | --- | --- | --- |']
    for typ, _rel, _prefix in TYPES:
        for cat, n in sorted(counts[typ].items()):
            out.append(f'| `{typ}` | `{cat}` | {n} | {LEGEND.get(cat, "")} |')
    for cat, title in (('state', 'Prognostic state'), ('flux', 'Anthropogenic fluxes'),
                       ('work', 'Clock and workspace'),
                       ('reserved', 'Reserved SURFEX placeholders'), ('dead', 'Dead fields')):
        sel = [r for r in rows if r[2] == cat]
        if not sel:
            continue
        out += ['', f'## {title} ({len(sel)})', '',
                '| type | field | refs | written by |', '| --- | --- | --- | --- |']
        for typ, field, _c, refs, writers, _cmt in sel:
            out.append(f'| `{typ}` | `{field}` | {refs} | {writers or "-"} |')
    out += ['', '## Contract: assignments outside the owner', '',
            f'`param`, `flux` and `work` fields are written once by `{OWNER}`; an assignment'
            ' elsewhere is a leftover of the copy block of the physics (removed by the'
            ' namelist-container step).', '']
    if violations:
        out += ['| type | field | category | assigned by |', '| --- | --- | --- | --- |']
        out += [f'| `{t}` | `{f}` | {c} | {w} |' for t, f, c, w in violations]
    else:
        out.append('No violations.')
    (out_root / 'summary.md').write_text('\n'.join(out) + '\n', encoding='utf-8')

    print(f'Container fields inventory  [{args.tree}]')
    for typ, _rel, _prefix in TYPES:
        print(f'  {typ:<15}: ' + ', '.join(f'{c} {n}' for c, n in sorted(counts[typ].items())))
    print(f'  state: {sum(1 for r in rows if r[2] == "state")},'
          f' flux: {sum(1 for r in rows if r[2] == "flux")},'
          f' reserved: {sum(1 for r in rows if r[2] == "reserved")},'
          f' dead: {len(dead)}')
    if unclassified:
        print('  UNCLASSIFIED: ' + ', '.join(f'{t}:{f}' for t, f in unclassified))
    if stale:
        print('  STALE TABLE: ' + ', '.join(f'{t}:{f}' for t, f, _ in stale))
    if dead:
        print('  dead to remove: ' + ', '.join(f'{t}:{f}' for t, f in dead))
    if violations:
        print(f'  contract: {len(violations)} param/flux/work fields assigned outside {OWNER}:')
        for typ, field, cat, files in violations[:8]:
            print(f'    {typ}:{field} ({cat}) <- {files}')
        if len(violations) > 8:
            print(f'    ... and {len(violations) - 8} more')
    print(f'  written: {out_root}')
    failed = bool(unclassified or stale or (args.strict and dead)
                  or (args.enforce_param and violations))
    print('  RESULT: ' + ('FAIL' if failed else 'OK'))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
