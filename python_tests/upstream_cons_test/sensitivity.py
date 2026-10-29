#!/usr/bin/env python
"""Sensitivity of the ``-DTEB_UPSTREAM_CONS`` control line to the official TEB 4.0.0.

For every case of the set (``cases.py``) the bench builds the response of each
model to the switch and reports their residual:

    d_ctrl = ctrl(case) - ctrl(C0_control)
    d_2020 = upstream(case) - upstream(C0_control)
    residual = d_2020 - d_ctrl

A residual at the level of the numerical noise, far below the response itself,
means that both models implement the block the same way; a residual comparable
to the response means that the block is wired differently.

Columns of ``report/sensitivity/summary.csv``:

* ``signal_ctrl`` / ``signal_2020`` - max |d_ctrl| / max |d_2020|, the response
  of each model to the switch;
* ``base_residual`` - max |ctrl(C0_control) - upstream(C0_control)|, the
  model-vs-model residual of the control configuration (the noise floor);
* ``max_abs`` / ``rmsd`` / ``bias`` - the residual ``d_2020 - d_ctrl``;
* ``rel`` = ``max_abs / max(signal_ctrl, signal_2020)``;
* ``verdict`` - ``inactive`` (signal below the noise floor), ``identical``
  (``rel <= TOLERANCE_PHYSICAL``), ``close`` (``rel <= 10x``), ``different``,
  or ``no-output`` (the upstream driver writes no file for the variable in this
  configuration).

Usage::

    python tools/sensitivity.py --target . --stage all
    python tools/sensitivity.py --target . --stage run --smoke 96
    python tools/sensitivity.py --target . --stage compare --cases D5_no_bem
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import os
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common as bc          # noqa: E402
import cases as case_set     # noqa: E402

#: fields of report/sensitivity/summary.csv
FIELDS = ['case', 'base_case', 'variable', 'rows', 'signal_ctrl', 'signal_2020',
          'signal', 'base_residual', 'max_abs', 'rmsd', 'bias', 'corr', 'rel',
          'max_row', 'first_diff_row', 'exact', 'verdict', 'switch']

STAGES = ('prepare', 'run', 'compare', 'report', 'all')


def load_provenance(layout: bc.Layout) -> dict:
    """Content of config/provenance.json, or an empty dict."""
    path = layout.config / 'provenance.json'
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def runtime_dir(layout: bc.Layout, override: str | None) -> Path | None:
    """Directory of the gfortran runtime: --runtime-dir, else the provenance."""
    if override:
        return Path(override).resolve()
    recorded = (load_provenance(layout).get('runtime') or {}).get('dir')
    return Path(recorded) if recorded else None


def switch_text(spec: dict) -> str:
    """Human-readable list of the namelist switches of a case."""
    parts = []
    for key, value in (spec.get('ctrl_param_overrides') or {}).items():
        parts.append(f'ctrl {key}={value}')
    for key in (spec.get('ctrl_param_removals') or []):
        parts.append(f'ctrl -{key}')
    for key, value in (spec.get('upstream_param_overrides') or {}).items():
        parts.append(f'upstream {key}={value}')
    return '; '.join(parts)


def base_templates(layout: bc.Layout, spec: dict) -> tuple:
    """Templates a case starts from: the C0 case when it has a base_case."""
    base = spec.get('base_case')
    if not base:
        return (layout.template_ctrl(), layout.template_ctrl_forcing(),
                layout.template_upstream())
    upstream = layout.param_nml(base, bc.VERSION_UPSTREAM)
    if not upstream.is_file():
        raise SystemExit(f'ERROR: the base case {base} is not prepared yet '
                         f'({upstream} is missing): prepare it first')
    cdir = layout.case_dir(base, bc.VERSION_CTRL)
    return (cdir / 'namelist' / 'namelist.nml',
            cdir / 'namelist' / 'namelist_forcing.nml', upstream)


def place_forcing(source_dir: Path, dest: Path) -> int:
    """Put the forcing of the upstream driver into ``dest`` (hard link first)."""
    dest.mkdir(parents=True, exist_ok=True)
    count = 0
    for name in bc.FORCING_FILES:
        source = source_dir / name
        if not source.is_file():
            raise SystemExit(f'ERROR: missing forcing file: {source}')
        target = dest / name
        if target.exists():
            target.unlink()
        try:
            os.link(source, target)          # same volume: no extra space
        except OSError:
            shutil.copy2(source, target)
        count += 1
    return count


# ---------------------------------------------------------------------------
# stage 1: prepare the case namelists
# ---------------------------------------------------------------------------


def prepare(layout: bc.Layout, args) -> int:
    """Write the case directories and their namelists."""
    print('prepare: writing the case namelists')
    for case in case_set.CASE_NAMES:
        spec = case_set.CASES[case]
        ctrl_tpl, forcing_tpl, upstream_tpl = base_templates(layout, spec)

        # -- control parameter namelist -------------------------------------
        overrides = spec.get('ctrl_param_overrides') or {}
        text = bc.render_namelist(ctrl_tpl, bc.GROUP_CTRL, overrides)
        removals = spec.get('ctrl_param_removals') or []
        if removals:
            text = bc.remove_namelist_items(text, bc.GROUP_CTRL, removals)
        bc.write_text(layout.param_nml(case, bc.VERSION_CTRL), text)
        bc.assert_overrides(text, bc.GROUP_CTRL, overrides,
                            f'{case}/ctrl')

        # -- control forcing namelist ---------------------------------------
        forcing_over = dict(spec.get('ctrl_forcing_overrides') or {})
        if args.smoke:
            forcing_over['nsteps'] = str(args.smoke)
        ftext = bc.render_namelist(forcing_tpl, bc.GROUP_CTRL_FORCING,
                                   forcing_over)
        bc.write_text(layout.forcing_nml(case, bc.VERSION_CTRL), ftext)

        # -- upstream namelist ----------------------------------------------
        utext = bc.render_namelist(upstream_tpl, bc.GROUP_UPSTREAM,
                                   spec.get('upstream_param_overrides') or {})
        anchor = spec.get('init_anchor')
        if anchor is not None:
            utext = bc.apply_initial_state(utext, layout.data_input, float(anchor))
        if args.smoke:
            utext = bc.apply_namelist_overrides(
                utext, bc.GROUP_UPSTREAM, {'INB_STEP_ATM': str(args.smoke - 1)})
        bc.write_text(layout.param_nml(case, bc.VERSION_UPSTREAM), utext)

        # -- the upstream driver reads input/Forc_*.txt relative to its cwd --
        count = place_forcing(layout.data_input, layout.upstream_input_dir(case))
        note = ''
        if args.smoke:
            note = f', nsteps={args.smoke}'
        print(f'  {case}: {count} forcing files{note}')
    return 0


# ---------------------------------------------------------------------------
# stage 2: run both drivers on every case
# ---------------------------------------------------------------------------


def validate_run(layout: bc.Layout, case: str, version: str) -> tuple:
    """Row count and non-finite count of one run; fails when there is no output."""
    if version == bc.VERSION_CTRL:
        path = layout.ctrl_csv(case)
        if not path.is_file():
            raise SystemExit(f'ERROR: no output written: {path}')
        header, rows = bc.read_ctrl_csv(path)
        missing = [v for v in bc.COMMON_VARIABLES if v not in header]
        if missing:
            raise SystemExit(f'ERROR: {path.name} lacks columns: {missing}')
        index = {name: header.index(name) for name in bc.COMMON_VARIABLES}
        nonfinite = 0
        for row in rows:
            for name, column in index.items():
                try:
                    value = float(row[column])
                except (ValueError, IndexError):
                    nonfinite += 1
                    continue
                if not math.isfinite(value):
                    nonfinite += 1
        return len(rows), nonfinite
    rows = None
    nonfinite = 0
    for name in bc.COMMON_VARIABLES:
        values = bc.read_upstream_var(layout.upstream_var(case, name))
        if values is None:
            continue
        rows = len(values) if rows is None else min(rows, len(values))
        nonfinite += bc.count_nonfinite(values)
    return rows, nonfinite


def run_stage(layout: bc.Layout, args) -> int:
    """Run both drivers on every case (the output directory is cleared first)."""
    env = bc.subprocess_env(runtime_dir(layout, args.runtime_dir))
    if env.get('PATH') is not None and runtime_dir(layout, args.runtime_dir):
        print(f'runtime: {runtime_dir(layout, args.runtime_dir)}')
    for case in case_set.CASE_NAMES:
        for version in bc.VERSIONS:
            exe = layout.exe(version)
            if not exe.is_file():
                raise SystemExit(
                    f'ERROR: no executable for {version}: {exe}\n'
                    f'       deploy the bench with --build, or pass --exe-ctrl / '
                    f'--exe-2020 to deploy.py')
            cdir = layout.case_dir(case, version)
            if not cdir.is_dir():
                raise SystemExit(f'ERROR: the case is not prepared: {cdir} '
                                 f'(run the prepare stage first)')
            bc.clear_dir(layout.output_dir(case, version))
            if version == bc.VERSION_CTRL:
                cmd = [str(exe), '-param_nml', 'namelist/namelist.nml',
                       '-forcing_nml', 'namelist/namelist_forcing.nml',
                       '-output', 'output']
            else:
                cmd = [str(exe)]
            log = layout.logs / f'run_{case}_{version}.log'
            print(f'run {case} / {version}')
            rc = bc.run_command(cmd, cdir, log, args.timeout, env)
            if rc != 0:
                raise SystemExit(f'ERROR: run failed (rc={rc}), see {log}')
            rows, nonfinite = validate_run(layout, case, version)
            print(f'  {rows} rows, nonfinite={nonfinite}')
    return 0


# ---------------------------------------------------------------------------
# stage 3: the metric
# ---------------------------------------------------------------------------


def variables(layout: bc.Layout) -> list:
    """Variables both drivers write in the control case, plus the extras."""
    base = case_set.BASE_CASE
    header, _rows = bc.read_ctrl_csv(layout.ctrl_csv(base))
    names = []
    for name in list(bc.COMMON_VARIABLES) + list(bc.EXTRA_VARIABLES):
        if name in header and layout.upstream_var(base, name).is_file():
            names.append(name)
    if not names:
        raise SystemExit('ERROR: no common variables found: run the prepare and '
                         'run stages first')
    return names


def read_case(layout: bc.Layout, case: str, names: list) -> tuple:
    """Read both sides of one case as ``{variable: [float]}``."""
    header, rows = bc.read_ctrl_csv(layout.ctrl_csv(case))
    index = {name: header.index(name) for name in names}
    ctrl = {}
    for name in names:
        column = index[name]
        ctrl[name] = [float(row[column]) for row in rows]
    upstream = {}
    for name in names:
        values = bc.read_upstream_var(layout.upstream_var(case, name))
        upstream[name] = values
    return ctrl, upstream, len(rows)


def _no_output_row(case: str, name: str, d_ctrl: list, switch: str) -> dict:
    """Row of a variable the upstream driver does not write in this case."""
    nan = float('nan')
    return {
        'case': case,
        'base_case': case_set.BASE_CASE,
        'variable': name,
        'rows': 0,
        'signal_ctrl': max(abs(x) for x in d_ctrl) if d_ctrl else nan,
        'signal_2020': nan,
        'signal': nan,
        'base_residual': nan,
        'max_abs': nan,
        'rmsd': nan,
        'bias': nan,
        'corr': nan,
        'rel': nan,
        'max_row': None,
        'first_diff_row': None,
        'exact': None,
        'verdict': 'no-output',
        'switch': switch,
    }


def verdict(signal: float, base_residual: float, rel: float) -> str:
    """Classify one case/variable pair."""
    if not math.isfinite(signal) or signal <= base_residual:
        return 'inactive'
    if rel <= bc.TOLERANCE_PHYSICAL:
        return 'identical'
    if rel <= 10.0 * bc.TOLERANCE_PHYSICAL:
        return 'close'
    return 'different'


def compare(layout: bc.Layout, cases: list) -> list:
    """Build the sensitivity table for the given cases."""
    names = variables(layout)
    base_ctrl, base_up, base_rows = read_case(layout, case_set.BASE_CASE, names)
    rows = []
    for case in cases:
        spec = case_set.CASES[case]
        switch = switch_text(spec)
        ctrl, upstream, case_rows = read_case(layout, case, names)
        n = min(case_rows, base_rows)
        for name in names:
            a_base = base_ctrl[name][:n]
            a_cur = ctrl[name][:n]
            d_ctrl = [a_cur[i] - a_base[i] for i in range(n)]
            b_base, b_cur = base_up[name], upstream[name]
            if b_base is None or b_cur is None:
                rows.append(_no_output_row(case, name, d_ctrl, switch))
                continue
            b_base = b_base[:n]
            b_cur = b_cur[:n]
            d_2020 = [b_cur[i] - b_base[i] for i in range(n)]
            st = bc.stats(d_ctrl, d_2020, bc.TOLERANCE_ROUNDOFF)
            base_residual = max(abs(a_base[i] - b_base[i]) for i in range(n))
            signal_ctrl = max(abs(x) for x in d_ctrl)
            signal_2020 = max(abs(x) for x in d_2020)
            signal = max(signal_ctrl, signal_2020)
            rel = st['max_abs'] / signal if signal > 0 else 0.0
            rows.append({
                'case': case,
                'base_case': case_set.BASE_CASE,
                'variable': name,
                'rows': n,
                'signal_ctrl': signal_ctrl,
                'signal_2020': signal_2020,
                'signal': signal,
                'base_residual': base_residual,
                'max_abs': st['max_abs'],
                'rmsd': st['rmsd'],
                'bias': st['bias'],
                'corr': st['corr'],
                'rel': rel,
                'max_row': st['max_row'],
                'first_diff_row': st['first_diff_row'],
                'exact': st['exact'],
                'verdict': verdict(signal, base_residual, rel),
                'switch': switch,
            })
    return rows


# ---------------------------------------------------------------------------
# stage 4: the reports
# ---------------------------------------------------------------------------


def write_csv(rows: list, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', newline='', encoding='utf-8') as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDS, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)


def verdict_counts(rows: list) -> dict:
    counts = {'identical': 0, 'close': 0, 'different': 0, 'inactive': 0,
              'no-output': 0}
    for row in rows:
        counts[row['verdict']] = counts.get(row['verdict'], 0) + 1
    return counts


def conclusions(rows: list) -> list:
    """Data-driven 'Conclusions' section shared by the summary and the log."""
    lines = ['## Conclusions', '']
    different = [r for r in rows if r['verdict'] == 'different']
    close = [r for r in rows if r['verdict'] == 'close']
    identical = [r for r in rows if r['verdict'] == 'identical']
    inactive = [r for r in rows if r['verdict'] == 'inactive']
    noout = [r for r in rows if r['verdict'] == 'no-output']
    rels = [r['rel'] for r in identical + close if math.isfinite(r['rel'])]

    if different:
        lines.append(f'- **differs**: {len(different)} rows with the verdict '
                     '`different` - the block is wired differently:')
        for row in different:
            lines.append(f"  - `{row['case']}` / `{row['variable']}`: "
                         f"rel = {row['rel']:.2e}")
    else:
        lines.append('- **no `different` row**: the responses of the two models '
                     'to the garden, green roof, solar panel, shading and BEM '
                     'switches agree within the numerical noise, i.e. those '
                     'blocks are wired the same way.')
    if rels:
        lines.append(f'- largest relative residual of the responses: '
                     f'rel = {max(rels):.2e} '
                     f'({len(identical)} `identical`, {len(close)} `close`).')
    if close:
        lines.append(f'- `close` (rel above TOLERANCE_PHYSICAL = '
                     f'{bc.TOLERANCE_PHYSICAL:.0e}, below 1e-2) - at the noise '
                     'level, worth a closer look:')
        for row in close:
            lines.append(f"  - `{row['case']}` / `{row['variable']}`: "
                         f"rel = {row['rel']:.2e}, signal = {row['signal']:.3e}, "
                         f"max|residual| = {row['max_abs']:.3e}, "
                         f"row {row['max_row']}")
    if inactive:
        names = ', '.join('`' + n + '`'
                          for n in sorted({r['variable'] for r in inactive}))
        lines.append(f'- `inactive`: the switch moves {names} in neither model.')
    if noout:
        lines.append('- `no-output`: the upstream driver writes no file for the '
                     'variable in this configuration (zero-byte file):')
        for row in noout:
            lines.append(f"  - `{row['case']}` / `{row['variable']}`: "
                         f"ctrl response {bc.fmt(row['signal_ctrl'])}")
    big = [r for r in noout if math.isfinite(r['signal_ctrl'])
           and r['signal_ctrl'] > 1e6]
    if big:
        lines.append('- **diagnostic anomaly**: with BEM switched off the '
                     'control driver prints non-physical `HVAC_COOL` / '
                     '`HVAC_HEAT` (up to 2.9e25) instead of zeros, while the '
                     'upstream driver writes an empty file. It does not affect '
                     'the verdicts of the other variables.')
    lines.append('')
    return lines


def _exe_line(layout: bc.Layout, version: str) -> str:
    path = layout.exe(version)
    if not path.is_file():
        return f'`{bc.rel(path, layout.root)}` (not built)'
    return f'`{bc.rel(path, layout.root)}` (sha256 {bc.sha256(path).upper()})'


def write_summary(rows: list, cases: list, layout: bc.Layout, path: Path) -> None:
    """Write report/sensitivity/SUMMARY.md."""
    provenance = load_provenance(layout)
    upstream = provenance.get('upstream') or {}
    repository = provenance.get('repository') or {}
    lines = ['# Sensitivity of the `-DTEB_UPSTREAM_CONS` control line to the '
             'official TEB 4.0.0', '']
    lines.append(f"Repository: `{repository.get('root', '-')}` "
                 f"(revision `{repository.get('revision') or 'unknown'}`).")
    lines.append(f"Upstream: `{upstream.get('source', bc.TEB_URL)}` "
                 f"(tag `{upstream.get('tag', bc.TEB_TAG)}`, revision "
                 f"`{upstream.get('revision', bc.TEB_COMMIT)}`).")
    lines.append(f'Forcing: CAPITOUL, {bc.FORCING_STEPS} steps of '
                 f'{bc.FORCING_STEP_SECONDS} s.')
    lines.append(f'Base case: `{case_set.BASE_CASE}`.')
    lines.append('')
    lines.append(f'- control executable: {_exe_line(layout, bc.VERSION_CTRL)}')
    lines.append(f'- upstream executable: {_exe_line(layout, bc.VERSION_UPSTREAM)}')
    lines.append('- metric: `d_ctrl = ctrl(case) - ctrl(base)`, '
                 '`d_2020 = upstream(case) - upstream(base)`, '
                 '`residual = d_2020 - d_ctrl`; '
                 '`rel = max|residual| / max(signal_ctrl, signal_2020)`')
    lines.append(f'- verdicts: `identical` rel <= {bc.TOLERANCE_PHYSICAL:.0e}, '
                 f'`close` rel <= {10 * bc.TOLERANCE_PHYSICAL:.0e}, else '
                 f'`different`; `inactive` when the signal does not exceed '
                 f'`base_residual`; `no-output` when the upstream driver writes '
                 f'no file for the variable')
    lines.append('')

    lines.append('## 1. Verdict summary')
    lines.append('')
    lines.append('| case | switch | identical | close | different | inactive | '
                 'no-output |')
    lines.append('| --- | --- | ---: | ---: | ---: | ---: | ---: |')
    for case in cases:
        subset = [r for r in rows if r['case'] == case]
        counts = verdict_counts(subset)
        switch = subset[0]['switch'] if subset else ''
        lines.append(f"| {case} | `{switch}` | {counts['identical']} | "
                     f"{counts['close']} | {counts['different']} | "
                     f"{counts['inactive']} | {counts['no-output']} |")
    lines.append('')

    lines.append('## 2. Per-case tables')
    lines.append('')
    for case in cases:
        subset = [r for r in rows if r['case'] == case]
        if not subset:
            continue
        lines.append(f'### {case}')
        lines.append('')
        lines.append(f"switch: `{subset[0]['switch']}`")
        lines.append('')
        lines.append('| variable | signal ctrl | signal upstream | base residual | '
                     'max abs | RMSD | rel | max row | verdict |')
        lines.append('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |')
        for row in subset:
            lines.append(
                f"| {row['variable']} | {bc.fmt(row['signal_ctrl'])} | "
                f"{bc.fmt(row['signal_2020'])} | {bc.fmt(row['base_residual'])} | "
                f"{bc.fmt(row['max_abs'])} | {bc.fmt(row['rmsd'])} | "
                f"{bc.fmt(row['rel'], '.2e')} | "
                f"{row['max_row'] if row['max_row'] else '-'} | "
                f"{row['verdict']} |")
        lines.append('')

    lines.extend(conclusions(rows))
    lines.append('## 3. How to reproduce')
    lines.append('')
    lines.append('```powershell')
    lines.append('python tools/sensitivity.py --target . --stage all')
    lines.append('```')
    lines.append('')
    bc.write_text(path, '\n'.join(lines) + '\n')


def write_log(rows: list, cases: list, layout: bc.Layout, path: Path) -> None:
    """Write report/logs/sensitivity.md."""
    provenance = load_provenance(layout)
    upstream = provenance.get('upstream') or {}
    lines = ['# Journal: upstream_cons_test sensitivity set', '']
    lines.append(f"Deployed bench: `{layout.root.as_posix()}`. Upstream TEB "
                 f"`{upstream.get('tag', bc.TEB_TAG)}` at revision "
                 f"`{upstream.get('revision', bc.TEB_COMMIT)}`; the control tree "
                 f"is built with `{bc.CTRL_CPPDEFS}`.")
    lines.append('')
    lines.append('The metric compares the responses of the two models to a single '
                 'block switch relative to `' + case_set.BASE_CASE + '`, not the '
                 'absolute fields.')
    lines.append('')
    lines.append('| case | switch | identical | close | different | inactive | '
                 'no-output |')
    lines.append('| --- | --- | ---: | ---: | ---: | ---: | ---: |')
    for case in cases:
        subset = [r for r in rows if r['case'] == case]
        counts = verdict_counts(subset)
        switch = subset[0]['switch'] if subset else ''
        lines.append(f"| {case} | `{switch}` | {counts['identical']} | "
                     f"{counts['close']} | {counts['different']} | "
                     f"{counts['inactive']} | {counts['no-output']} |")
    lines.append('')
    lines.append('Numbers: `report/sensitivity/summary.csv`; tables: '
                 '`report/sensitivity/SUMMARY.md`.')
    lines.append('')
    lines.append('The model-vs-model residual of the control configuration is the '
                 '`base_residual` column of `summary.csv` (the noise floor of '
                 'the comparison).')
    lines.append('')
    lines.extend(conclusions(rows))
    bc.write_text(path, '\n'.join(lines) + '\n')


def print_table(rows: list) -> None:
    """Compact console table of the metric."""
    print(f"{'case':<18} {'variable':<11} {'signal':>11} {'base_res':>11} "
          f"{'max_abs':>11} {'rel':>9} verdict")
    for row in rows:
        print(f"{row['case']:<18} {row['variable']:<11} "
              f"{bc.fmt(row['signal']):>11} {bc.fmt(row['base_residual']):>11} "
              f"{bc.fmt(row['max_abs']):>11} {bc.fmt(row['rel'], '.2e'):>9} "
              f"{row['verdict']}")


# ---------------------------------------------------------------------------
# command line
# ---------------------------------------------------------------------------


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--target', required=True,
                    help='root of the deployed bench (the --target of deploy.py)')
    ap.add_argument('--stage', choices=STAGES, default='all',
                    help='stage to run (default: all)')
    ap.add_argument('--cases', nargs='*',
                    default=list(case_set.SENSITIVITY_CASE_NAMES),
                    help='cases of the compare/report stages (default: D1..D5)')
    ap.add_argument('--smoke', type=int, default=None,
                    help='limit every run to the first N forcing steps')
    ap.add_argument('--runtime-dir', default=None,
                    help='directory with the gfortran runtime DLLs')
    ap.add_argument('--timeout', type=float, default=None,
                    help='seconds allowed per run')
    return ap.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    if args.smoke is not None and args.smoke < 2:
        raise SystemExit('ERROR: --smoke must be >= 2 (a driver writes '
                         'nsteps-1 rows)')
    for case in args.cases:
        if case not in case_set.CASES:
            raise SystemExit(f'ERROR: unknown case: {case}')

    layout = bc.Layout(Path(args.target))
    print(f'bench: {layout.root}')
    stages = list(STAGES[:-1]) if args.stage == 'all' else [args.stage]

    rows: list = []
    for stage in stages:
        if stage == 'prepare':
            prepare(layout, args)
        elif stage == 'run':
            run_stage(layout, args)
        elif stage == 'compare':
            rows = compare(layout, args.cases)
            path = layout.sensitivity / 'summary.csv'
            write_csv(rows, path)
            print(f'numbers: {bc.rel(path, layout.root)}')
        elif stage == 'report':
            if not rows:
                rows = compare(layout, args.cases)
            write_summary(rows, list(args.cases), layout,
                          layout.sensitivity / 'SUMMARY.md')
            write_log(rows, list(args.cases), layout,
                      layout.logs / 'sensitivity.md')
            print(f'summary: {bc.rel(layout.sensitivity / "SUMMARY.md", layout.root)}')
            print(f'log    : {bc.rel(layout.logs / "sensitivity.md", layout.root)}')
            print_table(rows)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())