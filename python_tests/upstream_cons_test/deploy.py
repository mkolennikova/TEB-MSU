#!/usr/bin/env python
"""Deploy a self-contained ``upstream_cons_test`` bench into a target directory.

The deployer materialises, in ``--target``:

    config/templates/            namelist templates of the two drivers
    data/capitoul/input/         the CAPITOUL forcing of the repository
    src/teb_msu_ctrl/src_ctrl/   the control tree of the repository
    src/teb_orig_2020/           a clone of the official TEB 4.0.0
    tools/                       this kit (common/cases/sensitivity/deploy)
    build/, cases/, report/      created empty
    provenance.json, README.md, run.ps1

The upstream model is never vendored into the repository: it is cloned from its
own git repository at the pinned revision (``common.TEB_TAG`` /
``common.TEB_COMMIT``); an existing checkout can be copied instead with
``--teb2020-src``.

The two drivers are built with ``--build``:

  * control tree: ``make -C src/teb_msu_ctrl/src_ctrl FC=gfortran
    OBJDIR=<target>/build/obj_ctrl_upstream_cons
    EXEC=<target>/build/TEB_offline_ctrl_upstream_cons.exe
    CPPDEFS=-DTEB_UPSTREAM_CONS`` (the ``-DTEB_UPSTREAM_CONS`` build: sun
    position at run start, natural-ventilation threshold, Stefan-Boltzmann
    constant and gas constants as in the official TEB 4.0.0);
  * upstream: ``cmake -G Ninja -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_Fortran_FLAGS_RELEASE="-O0 -g" -DUSE_REAL8=ON`` + ``cmake --build``.

Usage::

    python python_tests/upstream_cons_test/deploy.py --target D:\\teb_bench --build
    python python_tests/upstream_cons_test/deploy.py --target /tmp/teb --dry-run
    python python_tests/upstream_cons_test/deploy.py --target D:\\teb_bench \\
        --teb2020-src W:\\bench\\src\\teb_orig_2020 --build
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import common as bc          # noqa: E402
import cases as case_set     # noqa: E402

#: kit files copied into <target>/tools
KIT_FILES = ('common.py', 'cases.py', 'deploy.py', 'sensitivity.py')

#: directories of the upstream clone that are not needed by the test
UPSTREAM_SKIP = ('.git', 'build', '__pycache__', 'docs', 'paper')

#: the upstream file whose NAMELIST declarations must be moved for gfortran >= 15
UPSTREAM_DRIVER = ('src', 'driver', 'driver.F90')

#: text left in place of the moved declarations
NAMELIST_NOTICE = (
    '! ---------------------------------------------------------------',
    '! NAMELIST declarations are placed below all declarations: gfortran >= 15',
    '! requires every namelist symbol to be declared before the NAMELIST statement.',
    '! ---------------------------------------------------------------',
)

#: the first statement that uses the namelists; the moved block goes above it
UPSTREAM_OPEN_ANCHOR = "OPEN(UNIT=99, FILE='input.nml', STATUS='old')"

#: candidate locations of the gfortran runtime (Windows / MSYS2 / POSIX)
RUNTIME_CANDIDATES = (
    'C:/msys64/ucrt64/bin', 'C:/msys64/mingw64/bin', 'C:/msys64/clang64/bin',
    'C:/MinGW/bin', '/ucrt64/bin', '/mingw64/bin', '/usr/bin',
)

#: candidate locations of the build toolchain (gfortran + make + cmake)
TOOLCHAIN_CANDIDATES = (
    'C:/msys64/ucrt64/bin', 'C:/msys64/mingw64/bin', 'C:/msys64/usr/bin',
    'C:/MinGW/bin', '/ucrt64/bin', '/mingw64/bin', '/usr/bin',
)

#: DLLs a gfortran executable may need at run time
RUNTIME_DLL_RE = re.compile(rb'[A-Za-z0-9_.+-]*lib[A-Za-z0-9_.+-]*\.dll')


def git_output(args: list, cwd: Path) -> str:
    """Run git and return its stdout (fails loudly)."""
    cmd = ['git', '-c', 'safe.directory=*', *args]
    proc = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)
    if proc.returncode != 0:
        raise SystemExit(f'ERROR: git {" ".join(args)} failed: '
                         f'{proc.stderr.strip()}')
    return proc.stdout.strip()


def needed_dlls(exe: Path) -> list:
    """Names of the ``lib*.dll`` files an executable references."""
    names = set()
    for m in RUNTIME_DLL_RE.finditer(exe.read_bytes()):
        names.add(m.group(0).decode('ascii'))
    return sorted(names)


def find_runtime_dir(explicit: Path | None) -> Path | None:
    """Directory that holds the gfortran runtime DLLs, if one can be found."""
    if explicit is not None:
        return explicit if explicit.is_dir() else None
    for candidate in RUNTIME_CANDIDATES:
        path = Path(candidate)
        if (path / 'libgfortran-5.dll').is_file() or (path / 'libgfortran.so').is_file():
            return path
    which = shutil.which('gfortran')
    if which:
        return Path(which).resolve().parent
    return None


def find_toolchain_dir(explicit: Path | None) -> Path | None:
    """Directory that holds gfortran and make, if one can be found."""
    if explicit is not None:
        return explicit if explicit.is_dir() else None
    for candidate in TOOLCHAIN_CANDIDATES:
        path = Path(candidate)
        if any((path / f'gfortran{suffix}').is_file()
               for suffix in ('.exe', '')) and any(
                (path / f'make{suffix}').is_file() for suffix in ('.exe', '')):
            return path
    which = shutil.which('gfortran')
    return Path(which).resolve().parent if which else None


def check_tools(names: tuple, env: dict) -> list:
    """Names of the tools that are not on ``env['PATH']``."""
    path = env.get('PATH')
    return [name for name in names if shutil.which(name, path=path) is None]


def install_runtime(exes: list, runtime_dir: Path | None) -> dict:
    """Copy the DLLs the executables need next to them (Windows).

    Windows loads a DLL from the directory of the executable first, so copying
    the runtime there makes the deployed bench self-contained. Returns the
    mapping ``{executable: [copied dll, ...]}``.
    """
    result: dict = {}
    if runtime_dir is None:
        return result
    for exe in exes:
        if not exe.is_file():
            continue
        copied = []
        for name in needed_dlls(exe):
            source = runtime_dir / name
            if source.is_file():
                target = exe.parent / name
                if not target.exists():
                    shutil.copy2(source, target)
                copied.append(name)
        result[str(exe)] = copied
    return result


def copy_tree(src: Path, dst: Path, skip: tuple = ()) -> int:
    """Copy a directory tree, skipping the given names; return the file count."""
    if dst.exists():
        bc.rmtree(dst)
    count = 0
    for path in src.rglob('*'):
        relative = path.relative_to(src)
        if any(part in skip for part in relative.parts):
            continue
        target = dst / relative
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        count += 1
    return count


def clone_upstream(layout: bc.Layout, args) -> dict:
    """Clone (or copy) the upstream model at the pinned revision."""
    dest = layout.upstream_src
    source = None
    if args.teb2020_src is not None:
        source = Path(args.teb2020_src).resolve()
        if not source.is_dir():
            raise SystemExit(f'ERROR: --teb2020-src is not a directory: {source}')
        print(f'upstream: copying an existing checkout from {source}')
        count = copy_tree(source, dest, skip=('.git', 'build', '__pycache__'))
        print(f'  copied {count} files')
    else:
        if dest.exists():
            bc.rmtree(dest)
        dest.parent.mkdir(parents=True, exist_ok=True)
        print(f'upstream: git clone --depth 1 --branch {args.teb2020_tag} '
              f'{args.teb2020_url}')
        cmd = ['git', 'clone', '--depth', '1', '--branch', args.teb2020_tag,
               args.teb2020_url, str(dest)]
        log = layout.logs / 'deploy_clone.log'
        if bc.run_command(cmd, layout.root, log) != 0:
            raise SystemExit(f'ERROR: git clone failed, see {log}')
    revision = git_output(['rev-parse', 'HEAD'], dest)
    if revision != args.teb2020_rev:
        raise SystemExit(
            f'ERROR: upstream revision mismatch: got {revision}, '
            f'expected {args.teb2020_rev}. Pass --teb2020-rev to accept another '
            f'revision (the test is pinned to {bc.TEB_TAG}).')
    if args.strip_git:
        bc.rmtree(dest / '.git')
    print(f'  revision: {revision}')
    return {'source': source.as_posix() if source else args.teb2020_url,
            'tag': args.teb2020_tag, 'revision': revision}


def _index_of(lines: list, predicate, what: str, path: Path) -> int:
    for i, line in enumerate(lines):
        if predicate(line):
            return i
    raise SystemExit(f'ERROR: cannot patch {path.name}: {what} not found')


def patch_upstream_driver(path: Path) -> dict:
    """Move the NAMELIST declarations below all declarations (gfortran >= 15).

    The upstream TEB 4.0.0 driver declares ``namelist /dimensions/`` and
    ``namelist /parameters/`` before the symbols they list, which gfortran >= 15
    rejects with "Symbol ... must be declared before the namelist is declared".
    The clone is not vendored, so the deployment moves the two statements (with
    their comment header) down to just before the first read of ``input.nml``
    and leaves a note in their place. Only this move is done: no other change.

    Returns a description of the change; the file is left untouched when it is
    already patched.
    """
    text = path.read_text(encoding='utf-8', errors='ignore')
    newline = '\r\n' if '\r\n' in text else '\n'
    lines = text.replace('\r\n', '\n').split('\n')
    if lines and lines[-1] == '':
        lines.pop()

    if any(line.strip().startswith('! NAMELIST declarations are placed below')
           for line in lines):
        return {'file': path.as_posix(), 'already_patched': True}

    head = _index_of(lines, lambda l: l.strip().startswith('! Namelist: Add to allow'),
                     'the namelist comment header', path)
    start = head - 1                       # the separator line above the header
    params = _index_of(lines,
                       lambda l: l.strip().lower().startswith('namelist /parameters/'),
                       'namelist /parameters/', path)
    end = params
    while lines[end].rstrip().endswith('&'):      # continuation lines
        end += 1
    block = lines[start:end + 1]
    joined = '\n'.join(block)
    for needed in ('namelist /dimensions/', 'namelist /parameters/'):
        if needed not in joined:
            raise SystemExit(f'ERROR: cannot patch {path.name}: {needed} is not '
                             f'in the block that would be moved')

    rest = lines[:start] + list(NAMELIST_NOTICE) + lines[end + 1:]
    anchor = _index_of(rest, lambda l: l.strip() == UPSTREAM_OPEN_ANCHOR,
                       UPSTREAM_OPEN_ANCHOR, path)
    patched = rest[:anchor] + block + [''] + rest[anchor:]

    before = bc.sha256(path)
    bc.write_text(path, newline.join(patched) + newline)
    return {'file': path.as_posix(),
            'already_patched': False,
            'sha256_before': before,
            'sha256_after': bc.sha256(path),
            'lines_moved': len(block),
            'reason': 'gfortran >= 15 requires every namelist symbol to be '
                      'declared before the NAMELIST statement'}


def materialize(layout: bc.Layout, args) -> dict:
    """Copy the forcing, the control tree, the templates and the kit."""
    info: dict = {}

    # -- forcing ------------------------------------------------------------
    if not bc.CAPITOUL_INPUT.is_dir():
        raise SystemExit(f'ERROR: no CAPITOUL forcing in the repository: '
                         f'{bc.CAPITOUL_INPUT}')
    hashes = {}
    for name in bc.FORCING_FILES:
        source = bc.CAPITOUL_INPUT / name
        if not source.is_file():
            raise SystemExit(f'ERROR: missing forcing file: {source}')
        target = layout.data_input / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        digest = bc.sha256(target)
        if digest != bc.sha256(source):
            raise SystemExit(f'ERROR: copy differs from the source: {name}')
        hashes[name] = digest
    print(f'forcing: {len(hashes)} files copied to '
          f'{bc.rel(layout.data_input, layout.root)}')
    info['forcing'] = hashes

    # -- control tree -------------------------------------------------------
    if not bc.CTRL_SRC.is_dir():
        raise SystemExit(f'ERROR: no control tree in the repository: '
                         f'{bc.CTRL_SRC}')
    count = copy_tree(bc.CTRL_SRC, layout.ctrl_src)
    print(f'control tree: {count} files copied to '
          f'{bc.rel(layout.ctrl_src, layout.root)}')
    info['ctrl_src_files'] = count

    # -- templates ----------------------------------------------------------
    layout.templates.mkdir(parents=True, exist_ok=True)
    pairs = (
        (bc.CAPITOUL_PARAM_NML, layout.template_ctrl()),
        (bc.CAPITOUL_FORCING_NML, layout.template_ctrl_forcing()),
    )
    templates = {}
    for source, target in pairs:
        if not source.is_file():
            raise SystemExit(f'ERROR: missing template: {source}')
        shutil.copy2(source, target)
        templates[target.name] = bc.sha256(target)
    upstream_nml = layout.upstream_src / 'examples' / 'CAPITOUL' / 'input.nml'
    if not upstream_nml.is_file():
        raise SystemExit(f'ERROR: the upstream clone has no CAPITOUL namelist: '
                         f'{upstream_nml}')
    shutil.copy2(upstream_nml, layout.template_upstream())
    templates[layout.template_upstream().name] = bc.sha256(layout.template_upstream())
    print(f'templates: {len(templates)} files in '
          f'{bc.rel(layout.templates, layout.root)}')
    info['templates'] = templates

    # -- kit ----------------------------------------------------------------
    layout.tools.mkdir(parents=True, exist_ok=True)
    for name in KIT_FILES:
        source = HERE / name
        if source.is_file():
            shutil.copy2(source, layout.tools / name)
    print(f'kit: {len(KIT_FILES)} files copied to '
          f'{bc.rel(layout.tools, layout.root)}')
    return info


# ---------------------------------------------------------------------------
# building
# ---------------------------------------------------------------------------


def build_ctrl(layout: bc.Layout, jobs: int, dry_run: bool,
               env: dict | None = None) -> Path:
    """Build the control tree with -DTEB_UPSTREAM_CONS."""
    exe = layout.exe_ctrl()
    objdir = layout.build / bc.CTRL_OBJDIR_NAME
    cmd = ['make', '-C', str(layout.ctrl_src), 'FC=gfortran',
           f'OBJDIR={objdir}', f'EXEC={exe}', f'CPPDEFS={bc.CTRL_CPPDEFS}']
    if jobs > 1:
        cmd.append(f'-j{jobs}')
    log = layout.logs / 'deploy_build_ctrl.log'
    print('building the control tree (-DTEB_UPSTREAM_CONS) ...')
    if dry_run:
        print('  dry run: ' + ' '.join(cmd))
        return exe
    if bc.run_command(cmd, layout.root, log, None, env) != 0:
        raise SystemExit(f'ERROR: control build failed, see {log}')
    if not exe.is_file():
        raise SystemExit(f'ERROR: expected executable not found: {exe}')
    return exe


def detect_generator(requested: str | None, path: str | None = None) -> str:
    """CMake generator: the requested one, Ninja when available, else make."""
    if requested:
        return requested
    return 'Ninja' if shutil.which('ninja', path=path) else 'Unix Makefiles'


def build_upstream(layout: bc.Layout, generator: str | None, jobs: int,
                   dry_run: bool, env: dict | None = None) -> Path:
    """Configure and build the upstream model (CMake, real(8), -O0 -g).

    The upstream tree needs three adaptations that are not patches of its
    sources (the clone stays pristine):

    * ``CMAKE_POLICY_VERSION_MINIMUM=3.5``: its ``CMakeLists.txt`` asks for
      CMake 3.1, which CMake >= 4 refuses. The variable is exported, so it also
      reaches the nested configure of the ``external/minimal-dx``
      ``ExternalProject``;
    * the ``minimaldx-project`` target is built first: with CMake >= 4 the path
      of the not-yet-built ``libMinimalDX.a`` is a hard file dependency of
      ``driver.exe``, and ninja refuses to build the default target before the
      file exists;
    * nothing else.
    """
    src = layout.upstream_src
    build = src / 'build'
    exe = layout.exe_upstream()
    env = dict(env) if env is not None else dict(os.environ)
    env.setdefault('CMAKE_POLICY_VERSION_MINIMUM', '3.5')
    gen = detect_generator(generator, env.get('PATH'))
    configure = ['cmake', '-G', gen, '-S', str(src), '-B', str(build),
                 '-DCMAKE_BUILD_TYPE=Release',
                 '-DCMAKE_Fortran_FLAGS_RELEASE=-O0 -g', '-DUSE_REAL8=ON',
                 '-DCMAKE_POLICY_VERSION_MINIMUM=3.5']
    external = ['cmake', '--build', str(build), '--target', 'minimaldx-project']
    compile_ = ['cmake', '--build', str(build)]
    if jobs > 1:
        compile_ += ['--parallel', str(jobs)]
    log = layout.logs / 'deploy_build_upstream.log'
    print(f'building the upstream model (generator: {gen}) ...')
    if dry_run:
        print('  dry run: ' + ' '.join(configure))
        print('  dry run: ' + ' '.join(external))
        print('  dry run: ' + ' '.join(compile_))
        return exe
    if bc.run_command(configure, layout.root, log, None, env) != 0:
        raise SystemExit(f'ERROR: cmake configure failed, see {log}')
    if bc.run_command(external, layout.root, log, None, env) != 0:
        print('  note: the minimaldx-project target failed or does not exist; '
              'continuing (the library may already be installed)')
    if bc.run_command(compile_, layout.root, log, None, env) != 0:
        raise SystemExit(f'ERROR: upstream build failed, see {log}')
    if not exe.is_file():
        found = list(build.rglob('driver.exe'))
        if not found:
            raise SystemExit(f'ERROR: expected executable not found: {exe}')
        return found[0]
    return exe


# ---------------------------------------------------------------------------
# provenance, README and the runner
# ---------------------------------------------------------------------------


def tool_versions() -> dict:
    """Versions of the tools the deployment depends on."""
    versions = {'python': sys.version.split()[0]}
    for name, cmd in (('gfortran', ['gfortran', '--version']),
                      ('cmake', ['cmake', '--version']),
                      ('ninja', ['ninja', '--version']),
                      ('make', ['make', '--version']),
                      ('git', ['git', '--version'])):
        path = shutil.which(cmd[0])
        if not path:
            versions[name] = None
            continue
        try:
            out = subprocess.run(cmd, capture_output=True, text=True,
                                 timeout=30)
            line = (out.stdout or out.stderr).splitlines()
            versions[name] = line[0].strip() if line else path
        except (OSError, subprocess.SubprocessError):
            versions[name] = path
    return versions


def repo_revision() -> dict:
    """HEAD of the repository this kit was copied from."""
    try:
        return {'revision': git_output(['rev-parse', 'HEAD'], bc.REPO),
                'branch': git_output(['rev-parse', '--abbrev-ref', 'HEAD'],
                                     bc.REPO)}
    except SystemExit:
        return {'revision': None, 'branch': None}


def write_provenance(layout: bc.Layout, args, info: dict,
                     runtime: dict) -> dict:
    """Write provenance.json and return its content."""
    def exe_info(version: str):
        path = layout.exe(version)
        if not path.is_file():
            return None
        return {'path': bc.rel(path, layout.root),
                'sha256': bc.sha256(path),
                'bytes': path.stat().st_size}

    data = {
        'bench': 'upstream_cons_test',
        'created': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        'target': layout.root.as_posix(),
        'repository': {'root': bc.REPO.as_posix(), **repo_revision()},
        'upstream': info.get('upstream'),
        'control': {'cppdefs': bc.CTRL_CPPDEFS,
                    'note': ('the control tree is built with '
                             '-DTEB_UPSTREAM_CONS: sun position at run start, '
                             'natural-ventilation threshold, Stefan-Boltzmann '
                             'constant and gas constants as in the official '
                             'TEB 4.0.0')},
        'forcing': {'files': info.get('forcing'),
                    'steps': bc.FORCING_STEPS,
                    'step_seconds': bc.FORCING_STEP_SECONDS},
        'templates': info.get('templates'),
        'toolchain': info.get('toolchain'),
        'upstream_patch': info.get('upstream_patch'),
        'executables': {bc.VERSION_CTRL: exe_info(bc.VERSION_CTRL),
                        bc.VERSION_UPSTREAM: exe_info(bc.VERSION_UPSTREAM)},
        'runtime': runtime,
        'tools': {name: (bc.sha256(layout.tools / name)
                         if (layout.tools / name).is_file() else None)
                  for name in KIT_FILES},
        'tool_versions': tool_versions(),
    }
    bc.write_text(layout.config / 'provenance.json',
                  json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    return data


README_TEMPLATE = """# upstream_cons_test bench

Deployed by `python_tests/upstream_cons_test/deploy.py` from
`{repo}` (revision `{repo_revision}`).

The bench compares the control tree of this repository, built with
`-DTEB_UPSTREAM_CONS`, against the official TEB {teb_tag} driver
(`{teb_url}`, revision `{teb_revision}`), on the CAPITOUL forcing of the
repository.

## Layout

| path | content |
| --- | --- |
| `config/provenance.json` | revisions, sha256 of the inputs and of the executables, tool versions |
| `config/templates/` | namelist templates of the two drivers |
| `data/capitoul/input/` | the CAPITOUL forcing (11 files, 18000 steps of 1800 s) |
| `src/teb_msu_ctrl/src_ctrl/` | control tree, built with `{cppdefs}` |
| `src/teb_orig_2020/` | upstream clone at revision `{teb_revision}` |
| `tools/` | the kit: `common.py`, `cases.py`, `sensitivity.py` |
| `build/`, `cases/`, `report/` | executable, run directories, reports |

## Upstream adaptation

The clone of TEB {teb_tag} is used as is, with one exception: in
`src/driver/driver.F90` the `namelist /dimensions/` and `namelist /parameters/`
statements are declared before the symbols they list, which gfortran >= 15
rejects (`Symbol ... must be declared before the namelist is declared`). The
deployment moves those two statements (with their comment header) below the
declarations and leaves a note in their place; nothing else is changed. The
sha256 before and after the move is recorded in `upstream_patch` of
`config/provenance.json` (use `--no-patch-upstream` to skip the move).

## Run the series

```powershell
python tools/sensitivity.py --target . --stage all
```

Stages: `prepare` (write the case namelists), `run` (both drivers per case),
`compare` (metric), `report` (markdown). `--smoke N` limits the runs to the
first `N` forcing steps.

The test set is `C0_control` (the scenario of the upstream CAPITOUL namelist
mirrored into the control tree) plus one case per model block: `D1_garden_off`,
`D2_greenroof_off`, `D3_solar_on`, `D4_shading_on`, `D5_no_bem`.

## Metric

For every case and variable the bench compares the *responses* of the two
models to the switch:

    d_ctrl = ctrl(case) - ctrl(C0_control)
    d_2020 = upstream(case) - upstream(C0_control)
    residual = d_2020 - d_ctrl

Verdicts: `identical` (`max|residual| / max(signal) <= 1e-3`), `close`
(`<= 1e-2`), `different`, `inactive` (the switch moves nothing) and `no-output`
(the upstream driver writes no file for that variable in this configuration).

Results: `report/sensitivity/summary.csv` and `report/sensitivity/SUMMARY.md`.

## Runtime DLLs

Both executables are built with gfortran. When the deployment found the MinGW
runtime, the DLLs each executable needs were copied next to it (see
`runtime` in `config/provenance.json`), so the bench runs without extra setup.
If a driver exits with `rc=0xC0000135` (STATUS_DLL_NOT_FOUND), pass the
directory that holds `libgfortran-5.dll`:

```powershell
python tools/sensitivity.py --target . --stage run --runtime-dir C:\\msys64\\ucrt64\\bin
```
"""


def write_readme(layout: bc.Layout, provenance: dict) -> None:
    """Write the README of the deployed bench."""
    upstream = provenance.get('upstream') or {}
    repository = provenance.get('repository') or {}
    text = README_TEMPLATE.format(
        repo=repository.get('root', bc.REPO.as_posix()),
        repo_revision=repository.get('revision') or 'unknown',
        teb_tag=upstream.get('tag', bc.TEB_TAG),
        teb_url=upstream.get('source', bc.TEB_URL),
        teb_revision=upstream.get('revision', bc.TEB_COMMIT),
        cppdefs=bc.CTRL_CPPDEFS,
    )
    bc.write_text(layout.root / 'README.md', text)


RUN_PS1 = """# upstream_cons_test bench: prepare -> run -> report.
# Usage:  powershell -File run.ps1 [-Stage all] [-Smoke 0] [-RuntimeDir <dir>]
param(
    [string]$Stage = 'all',
    [int]$Smoke = 0,
    [string]$RuntimeDir = ''
)
$ErrorActionPreference = 'Stop'
$Python = if ($env:PYTHON) { $env:PYTHON } else { 'python' }
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Args = @("$Here\\tools\\sensitivity.py", '--target', $Here, '--stage', $Stage)
if ($Smoke -gt 0) { $Args += @('--smoke', "$Smoke") }
if ($RuntimeDir) { $Args += @('--runtime-dir', $RuntimeDir) }
& $Python @Args
exit $LASTEXITCODE
"""


def write_runner(layout: bc.Layout) -> None:
    bc.write_text(layout.root / 'run.ps1', RUN_PS1)


# ---------------------------------------------------------------------------
# command line
# ---------------------------------------------------------------------------


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--target', required=True,
                    help='directory of the deployed bench (created/updated)')
    ap.add_argument('--build', action='store_true',
                    help='build both drivers after the deployment')
    ap.add_argument('--exe-ctrl', default=None,
                    help='use this control executable instead of building')
    ap.add_argument('--exe-2020', default=None,
                    help='use this upstream executable instead of building')
    ap.add_argument('--teb2020-url', default=bc.TEB_URL,
                    help=f'upstream git URL (default: {bc.TEB_URL})')
    ap.add_argument('--teb2020-tag', default=bc.TEB_TAG,
                    help=f'upstream tag to clone (default: {bc.TEB_TAG})')
    ap.add_argument('--teb2020-rev', default=bc.TEB_COMMIT,
                    help=f'expected revision of the upstream clone '
                         f'(default: {bc.TEB_COMMIT})')
    ap.add_argument('--teb2020-src', default=None,
                    help='copy an existing upstream checkout instead of cloning')
    ap.add_argument('--strip-git', action='store_true',
                    help='remove the .git directory of the upstream clone')
    ap.add_argument('--no-patch-upstream', action='store_true',
                    help='do not move the NAMELIST declarations of the upstream '
                         'driver below the declarations (needed by gfortran >= 15)')
    ap.add_argument('--runtime-dir', default=None,
                    help='directory with the gfortran runtime DLLs')
    ap.add_argument('--toolchain-dir', default=None,
                    help='directory with gfortran/make/cmake (e.g. '
                         'C:/msys64/ucrt64/bin); searched automatically when '
                         'omitted')
    ap.add_argument('--generator', default=None,
                    help='CMake generator (default: Ninja when available)')
    ap.add_argument('--jobs', type=int, default=4, help='parallel build jobs')
    ap.add_argument('--force', action='store_true',
                    help='deploy into a non-empty target directory')
    ap.add_argument('--dry-run', action='store_true',
                    help='print the plan without writing anything')
    return ap.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    layout = bc.Layout(Path(args.target))
    print(f'target: {layout.root}')
    if args.dry_run:
        print('dry run: nothing will be written')

    if (not args.dry_run and layout.root.exists()
            and any(layout.root.iterdir()) and not args.force):
        raise SystemExit(f'ERROR: {layout.root} is not empty; pass --force to '
                         f'update the deployment in place')

    info: dict = {}
    if args.dry_run:
        print(f'upstream: would clone {args.teb2020_url} (tag '
              f'{args.teb2020_tag}) -> {bc.rel(layout.upstream_src, layout.root)}')
        print('would copy: the CAPITOUL forcing, the control tree, the '
              'templates and the kit')
    else:
        for directory in (layout.config, layout.templates, layout.logs,
                          layout.runs, layout.sensitivity, layout.cases,
                          layout.build):
            directory.mkdir(parents=True, exist_ok=True)
        info['upstream'] = clone_upstream(layout, args)
        if args.no_patch_upstream:
            info['upstream_patch'] = {'skipped': True}
        else:
            driver = layout.upstream_src.joinpath(*UPSTREAM_DRIVER)
            if not driver.is_file():
                raise SystemExit(f'ERROR: the upstream clone has no '
                                 f'{"/".join(UPSTREAM_DRIVER)}: {driver}')
            patch = patch_upstream_driver(driver)
            info['upstream_patch'] = patch
            if patch.get('already_patched'):
                print(f'upstream: {bc.rel(driver, layout.root)} is already patched')
            else:
                print(f'upstream: patched {bc.rel(driver, layout.root)} '
                      f'({patch["lines_moved"]} lines moved below the declarations)')
        info.update(materialize(layout, args))

    toolchain = find_toolchain_dir(
        Path(args.toolchain_dir).resolve() if args.toolchain_dir else None)
    build_env = bc.subprocess_env(toolchain)
    if toolchain:
        print(f'toolchain: {toolchain}')
    info['toolchain'] = toolchain.as_posix() if toolchain else None

    ctrl_exe = Path(args.exe_ctrl).resolve() if args.exe_ctrl else layout.exe_ctrl()
    upstream_exe = (Path(args.exe_2020).resolve() if args.exe_2020
                    else layout.exe_upstream())
    if args.build:
        needed = []
        if not args.exe_ctrl:
            needed += ['make', 'gfortran']
        if not args.exe_2020:
            needed.append('cmake')
            generator = detect_generator(args.generator, build_env.get('PATH'))
            needed.append('ninja' if generator == 'Ninja' else 'make')
        missing = check_tools(tuple(needed), build_env)
        if missing and not args.dry_run:
            raise SystemExit(
                f'ERROR: missing build tools: {", ".join(missing)}\n'
                f'       pass --toolchain-dir with the directory that holds '
                f'gfortran/make/cmake (e.g. C:/msys64/ucrt64/bin)')
        if not args.exe_ctrl:
            ctrl_exe = build_ctrl(layout, args.jobs, args.dry_run, build_env)
        if not args.exe_2020:
            upstream_exe = build_upstream(layout, args.generator, args.jobs,
                                          args.dry_run, build_env)

    if args.dry_run:
        print('done (dry run)')
        return 0

    runtime_dir = find_runtime_dir(
        Path(args.runtime_dir).resolve() if args.runtime_dir else None)
    runtime = {
        'dir': runtime_dir.as_posix() if runtime_dir else None,
        'copied': install_runtime([ctrl_exe, upstream_exe], runtime_dir),
        'note': ('the DLLs each executable needs were copied next to it'
                 if runtime_dir else
                 'no gfortran runtime found: pass --runtime-dir if a driver '
                 'exits with rc=0xC0000135 (STATUS_DLL_NOT_FOUND)'),
    }
    if runtime_dir:
        print(f'runtime: {runtime_dir}')

    provenance = write_provenance(layout, args, info, runtime)
    write_readme(layout, provenance)
    write_runner(layout)

    print('deployed:')
    for label, path in (('control ', ctrl_exe), ('upstream', upstream_exe)):
        if path.is_file():
            print(f'  {label}: {bc.rel(path, layout.root)}  '
                  f'sha256={bc.sha256(path)}')
        else:
            print(f'  {label}: {path}  (not built)')
    print(f'  next    : python '
          f'{bc.rel(layout.tools / "sensitivity.py", layout.root)} '
          f'--target {layout.root} --stage all')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
