#!/usr/bin/env python
"""Shared helpers of the ``upstream_cons_test`` bench.

The bench compares the control line of this repository, built with
``-DTEB_UPSTREAM_CONS`` (the "upstream consistency" build: the sun position at
run start, the natural-ventilation threshold, the Stefan-Boltzmann constant and
the gas constants follow the official TEB 4.0.0), against the official TEB
4.0.0 driver, on the CAPITOUL forcing of the repository.

The test set is ``C0_control`` (the scenario of the upstream CAPITOUL namelist
mirrored into the control tree) plus one case per model block (``D1``..``D5``).
``sensitivity.py`` compares the *responses* of the two models to a switch, not
the absolute fields.

Only the standard library is used: the bench must run in a bare Python.
Nothing in this module writes outside the run directory given by the caller.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

#: directory of this file (imports are by sibling name)
HERE = Path(__file__).resolve().parent

#: repository root (the parent of python_tests/)
REPO = HERE.parents[1]

VERSION_CTRL = 'teb_msu_ctrl'
VERSION_UPSTREAM = 'teb_orig_2020'
VERSIONS = (VERSION_CTRL, VERSION_UPSTREAM)

#: the upstream model the test is pinned to
TEB_URL = 'https://github.com/TEB-model/teb.git'
TEB_TAG = '4.0.0'
TEB_COMMIT = 'fb11cad0ae3a1bdb9b676924b5f7f3dc1d6d0343'

#: CAPITOUL case of the repository: the forcing and the base namelists
CAPITOUL = REPO / 'tests' / 'CAPITOUL'
CAPITOUL_INPUT = CAPITOUL / 'input'
CAPITOUL_PARAM_NML = CAPITOUL / 'namelist' / 'namelist.nml'
CAPITOUL_FORCING_NML = CAPITOUL / 'namelist' / 'namelist_forcing.nml'

#: source tree of the control line and the build define of the test
CTRL_SRC = REPO / 'src_ctrl'
CTRL_CPPDEFS = '-DTEB_UPSTREAM_CONS'

#: forcing shape of the repository CAPITOUL case
FORCING_FILES = ('Forc_CO2.txt', 'Forc_DIR.txt', 'Forc_DIR_SW.txt', 'Forc_LW.txt',
                 'Forc_PS.txt', 'Forc_QA.txt', 'Forc_RAIN.txt', 'Forc_SCA_SW.txt',
                 'Forc_SNOW.txt', 'Forc_TA.txt', 'Forc_WIND.txt')
FORCING_STEPS = 18000
FORCING_STEP_SECONDS = 1800

#: namelist groups of the two drivers
GROUP_CTRL = 'tebparam'
GROUP_CTRL_FORCING = 'tebforcing'
GROUP_UPSTREAM = 'parameters'

#: path of the forcing relative to a ``cases/<case>/teb_msu_ctrl`` run directory
CTRL_FORCING_PATH = "'../../../data/capitoul/input/'"

#: variables written by both drivers
COMMON_VARIABLES = (
    'T_ROOF1', 'T_CANYON', 'T_ROAD1', 'T_WALLA1', 'T_WALLB1', 'TI_BLD',
    'Q_CANYON', 'P_CANYON', 'U_CANYON', 'H_TOWN', 'LE_TOWN', 'RN_TOWN',
    'HVAC_COOL', 'HVAC_HEAT',
)

#: extra diagnostics written by both drivers, when the module is active
EXTRA_VARIABLES = ('GFLUX_TOWN',)

#: tolerances (same classes as the bench: round-off / precision / physical)
TOLERANCE_ROUNDOFF = 1e-12
TOLERANCE_PHYSICAL = 1e-3


# ---------------------------------------------------------------------------
# namelists
# ---------------------------------------------------------------------------
# The patching is deliberately line based (not f90nml): the drivers read the
# namelists strictly, the templates keep one item per line, and a rewrite would
# lose the comments and the exact formatting of the case files.


def _find_group(lines: List[str], group: str) -> Tuple[int, int]:
    """Return (start, end) line indices of ``&group`` ... ``/``."""
    token = '&' + group.lower()
    start = None
    for i, line in enumerate(lines):
        if line.strip().lower().startswith(token):
            start = i
            break
    if start is None:
        raise SystemExit(f'ERROR: namelist group &{group} not found')
    for j in range(start + 1, len(lines)):
        if lines[j].strip().startswith('/'):
            return start, j
    raise SystemExit(f'ERROR: namelist group &{group} has no terminating /')


def _replace_item(line: str, key: str, value: str) -> str | None:
    """Replace ``key = ...`` in a single namelist line, or return None."""
    code, sep, comment = line.partition('!')
    pattern = re.compile(
        r'^(\s*)(' + re.escape(key) + r')(\s*=\s*)(.*?)(\s*),?\s*$', re.I)
    m = pattern.match(code)
    if not m:
        return None
    prefix, name, eq = m.group(1), m.group(2), m.group(3)
    tail = ''
    if sep:
        tail = ' !' + comment
    return f'{prefix}{name}{eq}{value},{tail}'.rstrip()


def apply_namelist_overrides(text: str, group: str,
                             overrides: Dict[str, str]) -> str:
    """Apply ``overrides`` to one namelist group, preserving the rest.

    A missing item is inserted just before the terminating ``/`` of the group.
    """
    newline = '\r\n' if '\r\n' in text else '\n'
    lines = text.replace('\r\n', '\n').split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    start, end = _find_group(lines, group)
    for key, value in overrides.items():
        replaced = False
        for i in range(start + 1, end):
            new_line = _replace_item(lines[i], key, value)
            if new_line is not None:
                lines[i] = new_line
                replaced = True
                break
        if not replaced:
            # Insert before the terminating '/'. The previous item must be
            # terminated by a comma (a newline is also a valid Fortran namelist
            # separator, but the generated file is easier to audit when every
            # item ends with a comma).
            prev = end - 1
            while prev > start and (not lines[prev].strip()
                                    or lines[prev].strip().startswith('!')):
                prev -= 1
            code, sep, comment = lines[prev].partition('!')
            if code.strip() and not code.rstrip().endswith(','):
                tail = (' !' + comment) if sep else ''
                lines[prev] = code.rstrip() + ',' + tail
            lines.insert(end, f' {key}={value},')
            end += 1
    return newline.join(lines) + newline


def remove_namelist_items(text: str, group: str, keys: Iterable[str]) -> str:
    """Delete the ``key = ...`` lines of one namelist group.

    Used when a case must switch to an alternative item for the same quantity
    (the emissivity items ``urb_emis_*`` instead of the legacy longwave albedo
    ``urb_alb_*_th``: the driver stops when both are given). An item that is
    not in the file is an error.
    """
    newline = '\r\n' if '\r\n' in text else '\n'
    lines = text.replace('\r\n', '\n').split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    start, end = _find_group(lines, group)
    wanted = set(keys)
    removed = set()
    kept = []
    for i, line in enumerate(lines):
        if start < i < end:
            code = line.partition('!')[0]
            m = re.match(r'^\s*([^=\s]+)\s*=', code)
            if m and m.group(1) in wanted:
                removed.add(m.group(1))
                continue
        kept.append(line)
    missing = sorted(wanted - removed)
    if missing:
        raise SystemExit(f'ERROR: cannot remove missing items of &{group}: '
                         f'{missing}')
    return newline.join(kept) + newline


def render_namelist(template: Path, group: str,
                    overrides: Dict[str, str]) -> str:
    """Read a namelist template and apply the overrides of one group.

    ``newline=''`` keeps the original line endings: the control driver is
    sensitive to CRLF vs LF in its strict namelist reader.
    """
    with open(template, 'r', encoding='utf-8', errors='ignore', newline='') as fh:
        text = fh.read()
    return apply_namelist_overrides(text, group, overrides)


def group_values(text: str, group: str) -> Dict[str, str]:
    """Return ``{lowercase item: raw value}`` of one namelist group."""
    lines = text.replace('\r\n', '\n').split('\n')
    start, end = _find_group(lines, group)
    values: Dict[str, str] = {}
    duplicates = []
    for line in lines[start + 1:end]:
        code = line.partition('!')[0]
        m = re.match(r'\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*,?\s*$', code)
        if not m:
            continue
        key = m.group(1).lower()
        if key in values:
            duplicates.append(key)
        values[key] = m.group(2).strip()
    if duplicates:
        raise SystemExit(f'ERROR: duplicate namelist items in &{group}: '
                         f'{duplicates}')
    return values


def _normalise(value: str) -> str:
    return value.strip().strip("'").strip('"').strip()


def assert_overrides(text: str, group: str, overrides: Dict[str, str],
                     where: str) -> None:
    """Fail when a generated namelist does not carry the expected values."""
    values = group_values(text, group)
    for key, expected in overrides.items():
        actual = values.get(key.lower())
        if actual is None:
            raise SystemExit(f'ERROR: {where}: override {key} is absent '
                             f'from &{group}')
        if _normalise(actual) != _normalise(expected):
            raise SystemExit(f'ERROR: {where}: override {key} = {actual!r}, '
                             f'expected {expected!r}')


# ---------------------------------------------------------------------------
# files and outputs
# ---------------------------------------------------------------------------


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8', newline='')


def read_ctrl_csv(path: Path) -> Tuple[List[str], List[List[str]]]:
    """Read the semicolon-separated universal table as ``(header, rows)``."""
    lines = path.read_text(encoding='utf-8', errors='ignore').splitlines()
    if not lines:
        return [], []
    header = lines[0].split(';')
    rows = [line.split(';') for line in lines[1:] if line.strip()]
    return header, rows


def read_upstream_var(path: Path) -> List[float] | None:
    """Read one ``<VAR>.txt`` of the upstream driver, or None when empty.

    The upstream driver writes a zero-byte file for the variables of a module
    that is switched off (``HVAC_*`` with ``CBEM = 'DEF'``,
    ``PHOT_PROD_PANEL`` with the panels off), so an empty file means "no
    output", not "zero".
    """
    if not path.is_file():
        raise SystemExit(f'ERROR: missing upstream output: {path}')
    if path.stat().st_size == 0:
        return None
    values = []
    for line in path.read_text(encoding='utf-8', errors='ignore').splitlines():
        if line.strip():
            values.append(float(line.split()[0]))
    return values


def count_nonfinite(values: Iterable[float]) -> int:
    return sum(1 for v in values if not math.isfinite(v))


# ---------------------------------------------------------------------------
# initial state of the upstream driver
# ---------------------------------------------------------------------------
# The upstream driver has no cold start: every initial field is read from its
# namelist. This reproduces the state the control tree builds at ntstep == 0
# (call_driver.F90), anchored to the initial building temperature
# (teb_ti_bld_init of the control case):
#
#   * ZT_ROOF / ZT_WALL_A: layer 1 = t, layers 2..N-1 = A - (A - t)*w/W with w
#     the thickness of the layers inside (towards the interior) and W the sum
#     of the thicknesses of layers 1..N-1, layer N = A (ZT_WALL_B is not a
#     namelist item: the driver sets it to ZT_WALL_A);
#   * ZT_ROAD: t in every layer;
#   * ZT_FLOOR / ZT_MASS: A in every layer;
#   * ZT_CANYON = t, ZT_WIN1 = t, ZT_WIN2 = A, ZQ_CANYON = q, ZTI_BLD = A.
#
# ``t`` and ``q`` are the first values of the forcing (Forc_TA / Forc_QA), i.e.
# what CALL_DRIVER sees at ntstep == 0. ZQI_BLD is left untouched (it is the
# control teb_qi_bld_init, already present in the namelist).

LAYER_GROUPS = (
    ('ZT_ROOF', 'NROOF_LAYER', 'ZD_ROOF'),
    ('ZT_WALL_A', 'NWALL_LAYER', 'ZD_WALL'),
    ('ZT_ROAD', 'NROAD_LAYER', None),
    ('ZT_FLOOR', 'NFLOOR_LAYER', None),
    ('ZT_MASS', 'NFLOOR_LAYER', None),
)


def _int_item(text: str, key: str, default: int) -> int:
    m = re.search(r'^\s*' + re.escape(key) + r'\s*=\s*(\d+)', text, re.M)
    return int(m.group(1)) if m else default


def _float_item(text: str, key: str) -> float | None:
    m = re.search(r'^\s*' + re.escape(key) + r'\s*=\s*([0-9eEdD.+-]+)', text, re.M)
    return float(m.group(1).replace('d', 'e').replace('D', 'e')) if m else None


def layer_thicknesses(text: str, prefix: str, nlayers: int) -> List[float]:
    out = []
    for k in range(1, nlayers + 1):
        value = _float_item(text, f'{prefix}(1,{k})')
        if value is None:
            raise SystemExit(f'ERROR: {prefix}(1,{k}) not found in the namelist')
        out.append(value)
    return out


def first_forcing_value(forcing_dir: Path, name: str) -> float:
    path = forcing_dir / name
    if not path.is_file():
        raise SystemExit(f'ERROR: forcing file not found: {path}')
    with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
        for line in fh:
            if line.strip():
                return float(line.split()[0])
    raise SystemExit(f'ERROR: no value in {path}')


def profile(nlayers: int, zd: List[float], anchor: float, t: float) -> List[float]:
    """Control cold-start profile: t outside -> anchor inside, by thickness."""
    total = sum(zd[:nlayers - 1])
    if total <= 0.:
        raise SystemExit('ERROR: the sum of the layer thicknesses is not positive')
    values = [t]
    for k in range(2, nlayers):
        w = sum(zd[k - 1:nlayers - 1])
        values.append(anchor - (anchor - t) * w / total)
    values.append(anchor)
    return values


def compute_initial_state(text: str, forcing_dir: Path,
                          anchor: float) -> Tuple[Dict[str, str], Dict[str, str]]:
    """Return ``(values, comments)`` of the initial-state items."""
    t = first_forcing_value(forcing_dir, 'Forc_TA.txt')
    q = first_forcing_value(forcing_dir, 'Forc_QA.txt')
    values, comments = {}, {}
    for key, nkey, zdkey in LAYER_GROUPS:
        nlayers = _int_item(text, nkey, 5)
        if key == 'ZT_ROAD':
            vals = [t] * nlayers
            cmts = ['ctrl cold start: all road layers = T_air'] * nlayers
        elif key in ('ZT_FLOOR', 'ZT_MASS'):
            label = 'floor' if key == 'ZT_FLOOR' else 'mass'
            vals = [anchor] * nlayers
            cmts = [f'ctrl cold start: all {label} layers = ZTI_BLD'] * nlayers
        else:
            label = 'roof' if key == 'ZT_ROOF' else 'wall'
            vals = profile(nlayers, layer_thicknesses(text, zdkey, nlayers),
                           anchor, t)
            cmts = [f'ctrl cold start: {label} layer 1 = T_air']
            for k in range(2, nlayers):
                cmts.append(f'ctrl cold start: {label} layer {k} = ZTI_BLD '
                            '(thickness weighted)')
            cmts.append(f'ctrl cold start: {label} layer {nlayers} = ZTI_BLD')
        for k, (value, comment) in enumerate(zip(vals, cmts), start=1):
            values[f'{key}(:,{k})'] = f'{value:.8f}'
            comments[f'{key}(:,{k})'] = comment
    values['ZT_CANYON'] = f'{t:.8f}'
    comments['ZT_CANYON'] = 'ctrl cold start: first T_air'
    values['ZT_WIN1'] = f'{t:.8f}'
    comments['ZT_WIN1'] = 'ctrl cold start: external window = T_air'
    values['ZT_WIN2'] = f'{anchor:.8f}'
    comments['ZT_WIN2'] = 'ctrl cold start: internal window = ZTI_BLD'
    values['ZQ_CANYON'] = f'{q:.8f}'
    comments['ZQ_CANYON'] = 'ctrl cold start: Forc_QA at TEB entry'
    values['ZTI_BLD'] = f'{anchor:.8f}'
    comments['ZTI_BLD'] = 'ctrl cold start: teb_ti_bld_init'
    return values, comments


def apply_initial_state(text: str, forcing_dir: Path, anchor: float) -> str:
    """Rewrite the initial-state items (values and comments) of &parameters."""
    values, comments = compute_initial_state(text, forcing_dir, anchor)
    newline = '\r\n' if '\r\n' in text else '\n'
    lines = text.replace('\r\n', '\n').split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    start, end = _find_group(lines, GROUP_UPSTREAM)
    seen = set()
    for i in range(start + 1, end):
        code, _sep, _comment = lines[i].partition('!')
        m = re.match(r'^(\s*)([^=\s]+)\s*=\s*.*?$', code)
        if not m:
            continue
        key = m.group(2)
        if key in values:
            lines[i] = f'{m.group(1)}{key} = {values[key]}, ! {comments[key]}'
            seen.add(key)
    missing = sorted(set(values) - seen)
    if missing:
        raise SystemExit('ERROR: initial-state items not found in '
                         '&parameters: ' + ', '.join(missing))
    return newline.join(lines) + newline


# ---------------------------------------------------------------------------
# statistics of a difference series
# ---------------------------------------------------------------------------


def _corr(a: List[float], b: List[float]) -> float:
    """Pearson correlation over the finite pairs (nan when undefined)."""
    pairs = [(x, y) for x, y in zip(a, b)
             if math.isfinite(x) and math.isfinite(y)]
    n = len(pairs)
    if n < 2:
        return float('nan')
    ma = sum(x for x, _ in pairs) / n
    mb = sum(y for _, y in pairs) / n
    va = sum((x - ma) ** 2 for x, _ in pairs)
    vb = sum((y - mb) ** 2 for _, y in pairs)
    if va <= 0. or vb <= 0.:
        return float('nan')
    cov = sum((x - ma) * (y - mb) for x, y in pairs)
    return cov / math.sqrt(va * vb)


def stats(a: List[float], b: List[float], tol: float) -> dict:
    """Statistics of ``b - a``: the same fields as the comparison bench.

    ``max_rel`` is the maximum of ``|d| / max(|a|, |b|)``, ``first_diff_row``
    the first row where ``|d|`` exceeds ``tol * max(1, |a|)``, ``max_row`` the
    row of the largest relative difference (1-based, as in the CSV).
    """
    n = min(len(a), len(b))
    a = a[:n]
    b = b[:n]
    diff = [b[i] - a[i] for i in range(n)]
    ad = [abs(d) for d in diff]
    rel = [ad[i] / max(abs(a[i]), abs(b[i]), 1e-300) for i in range(n)]
    finite = [d for d in diff if math.isfinite(d)]
    finite_ad = [d for d in ad if math.isfinite(d)]
    finite_rel = [r for r in rel if math.isfinite(r)]
    first = None
    for i in range(n):
        if math.isfinite(ad[i]) and ad[i] > tol * max(1.0, abs(a[i])):
            first = i + 1
            break
    max_row = None
    best = -1.0
    for i in range(n):
        if math.isfinite(rel[i]) and rel[i] > best:
            best = rel[i]
            max_row = i + 1
    return {
        'n': n,
        'finite': len(finite),
        'exact': sum(1 for d in diff if d == 0),
        'max_abs': max(finite_ad) if finite_ad else float('nan'),
        'max_rel': max(finite_rel) if finite_rel else float('nan'),
        'mean_abs': (sum(finite_ad) / len(finite_ad)) if finite_ad
                    else float('nan'),
        'rmsd': math.sqrt(sum(d * d for d in finite) / len(finite)) if finite
                else float('nan'),
        'bias': (sum(finite) / len(finite)) if finite else float('nan'),
        'corr': _corr(a, b),
        'max_row': max_row,
        'first_diff_row': first,
        'max_ref': a[max_row - 1] if max_row else float('nan'),
        'max_cur': b[max_row - 1] if max_row else float('nan'),
    }


# ---------------------------------------------------------------------------
# running the drivers
# ---------------------------------------------------------------------------


def clear_dir(path: Path) -> None:
    """Empty a directory (or create it)."""
    if path.exists():
        for child in path.iterdir():
            if child.is_dir():
                rmtree(child)
            else:
                child.unlink()
    path.mkdir(parents=True, exist_ok=True)


def rmtree(path: Path) -> None:
    """Remove a directory tree, clearing the read-only attribute first.

    Windows keeps the pack files of a git clone read-only, and ``shutil.rmtree``
    fails with ``WinError 5`` on them.
    """
    if not path.exists():
        return
    for root, _dirs, files in os.walk(path):
        for name in files:
            try:
                os.chmod(os.path.join(root, name), 0o700)
            except OSError:
                pass
    shutil.rmtree(path, ignore_errors=True)


def subprocess_env(runtime_dir: Path | None = None) -> dict:
    """Environment for the drivers; ``runtime_dir`` is prepended to PATH.

    The executables are built with gfortran: on Windows they need the MinGW
    runtime DLLs (``libgfortran-5.dll``, ``libgcc_s_seh-1.dll``,
    ``libquadmath-0.dll``, ``libwinpthread-1.dll``), otherwise they exit with
    ``rc=0xC0000135`` (STATUS_DLL_NOT_FOUND).
    """
    env = dict(os.environ)
    if runtime_dir is not None:
        env['PATH'] = str(runtime_dir) + os.pathsep + env.get('PATH', '')
    return env


def run_command(cmd: List[str], cwd: Path, log: Path,
                timeout: float | None = None, env: dict | None = None) -> int:
    """Run a command, write its console log, return the return code.

    The program is resolved through the PATH of ``env`` when one is given:
    Windows ``CreateProcess`` searches the PATH of the *calling* process, so a
    toolchain directory prepended to ``env['PATH']`` would otherwise be ignored.
    """
    resolved = shutil.which(str(cmd[0]), path=(env or {}).get('PATH'))
    if resolved:
        cmd = [resolved] + [str(c) for c in cmd[1:]]
    log.parent.mkdir(parents=True, exist_ok=True)
    started = time.time()
    with open(log, 'w', encoding='utf-8', errors='ignore') as fh:
        fh.write('CMD: ' + ' '.join(str(c) for c in cmd) + '\n')
        fh.write('CWD: ' + str(cwd) + '\n\n')
        fh.flush()
        proc = subprocess.run([str(c) for c in cmd], cwd=cwd, stdout=fh,
                              stderr=subprocess.STDOUT, text=True,
                              timeout=timeout, env=env)
    elapsed = time.time() - started
    print(f'  rc={proc.returncode}  {elapsed:.1f} s  log={log.name}')
    return proc.returncode


def rel(path: Path, root: Path) -> str:
    """Path relative to ``root`` when possible, with forward slashes."""
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def fmt(value, spec: str = '.3e') -> str:
    """Format a number for the reports ('nan'/' - ' for missing values)."""
    if value is None:
        return '-'
    try:
        number = float(value)
    except (TypeError, ValueError):
        return str(value)
    if not math.isfinite(number):
        return 'nan'
    return format(number, spec)


# ---------------------------------------------------------------------------
# layout of a deployed bench
# ---------------------------------------------------------------------------
# ``CAPITOUL_*`` and ``CTRL_SRC`` above point into the repository and are used
# by deploy.py only; everything inside a deployed bench goes through Layout.

CTRL_EXE_NAME = 'TEB_offline_ctrl_upstream_cons.exe'
CTRL_OBJDIR_NAME = 'obj_ctrl_upstream_cons'


class Layout:
    """Paths of one deployed bench (``root`` = the --target directory)."""

    def __init__(self, root: Path):
        self.root = Path(root).resolve()
        self.config = self.root / 'config'
        self.templates = self.config / 'templates'
        self.data_input = self.root / 'data' / 'capitoul' / 'input'
        self.cases = self.root / 'cases'
        self.report = self.root / 'report'
        self.logs = self.report / 'logs'
        self.runs = self.report / 'runs'
        self.sensitivity = self.report / 'sensitivity'
        self.tools = self.root / 'tools'
        self.build = self.root / 'build'
        self.ctrl_src = self.root / 'src' / 'teb_msu_ctrl' / 'src_ctrl'
        self.upstream_src = self.root / 'src' / 'teb_orig_2020'

    # -- templates (written by the deployer) --------------------------------
    def template_ctrl(self) -> Path:
        return self.templates / 'teb_msu_ctrl.nml'

    def template_ctrl_forcing(self) -> Path:
        return self.templates / 'teb_msu_ctrl_forcing.nml'

    def template_upstream(self) -> Path:
        return self.templates / 'teb_orig_2020_pristine.nml'

    # -- run directories ----------------------------------------------------
    def case_dir(self, case: str, version: str) -> Path:
        return self.cases / case / version

    def param_nml(self, case: str, version: str) -> Path:
        cdir = self.case_dir(case, version)
        if version == VERSION_CTRL:
            return cdir / 'namelist' / 'namelist.nml'
        return cdir / 'input.nml'

    def forcing_nml(self, case: str, version: str) -> Path | None:
        if version == VERSION_CTRL:
            return self.case_dir(case, version) / 'namelist' / 'namelist_forcing.nml'
        return None

    def upstream_input_dir(self, case: str) -> Path:
        return self.case_dir(case, VERSION_UPSTREAM) / 'input'

    def output_dir(self, case: str, version: str) -> Path:
        return self.case_dir(case, version) / 'output'

    def ctrl_csv(self, case: str) -> Path:
        return self.output_dir(case, VERSION_CTRL) / 'TEB_output.csv'

    def upstream_var(self, case: str, name: str) -> Path:
        return self.output_dir(case, VERSION_UPSTREAM) / f'{name}.txt'

    # -- executables --------------------------------------------------------
    def exe_ctrl(self) -> Path:
        return self.build / CTRL_EXE_NAME

    def exe_upstream(self) -> Path:
        return self.upstream_src / 'build' / 'driver.exe'

    def exe(self, version: str) -> Path:
        return self.exe_ctrl() if version == VERSION_CTRL else self.exe_upstream()
