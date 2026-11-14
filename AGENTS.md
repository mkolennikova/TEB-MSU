# Instructions for coding agents

These instructions apply throughout this repository, regardless of the agent or
editor. Follow the user's current task and preserve unrelated working changes.
The directory and approval rules below take precedence over older examples in
README files, test scripts or tool-specific build instructions.

## 1. Source trees and their purpose

`src_dev/` and `src_ctrl/` are independent source directories in the same Git
repository, not separate Git branches. Each has its own Makefile and executable;
they share supporting Python code, test cases and documentation.

| Tree | Purpose | Change policy |
| --- | --- | --- |
| `src_dev/` | Active development line, derived from `MV_devs`: corrected physics, CBS surface exchange, diagnostic garden/greenroof schemes, additional diagnostics and the container-based API. | Default target for model development, within the user's requested scope. |
| `src_ctrl/` | Control/reference line based on the original commit `582c3ab`, with modern I/O and already accepted fixes, including D7-D9. It is not an untouched copy of upstream. | Preserve its established physical behavior as a comparison baseline. |

Do not automatically port development physics into `src_ctrl` or make the two
trees numerically identical. Their physical differences are intentional.
The optional `TEB_UPSTREAM_CONS_BUGS` switch in dev and `TEB_UPSTREAM_CONS` in ctrl
have different scopes; consult `docs/TEB_MSU_source_defects.md` before using them.

## 2. Explicit approval for changes to control physics

**Any change that alters the physics of `src_ctrl` requires explicit user
approval before implementation.** This includes numerical bug fixes and changes
to equations, constants, parameterizations, initialization, material profiles,
forcing transformations, physical defaults or time integration. Shared code,
configuration and compiler settings are covered when they change ctrl's physical
or numerical behavior, even if no file under `src_ctrl/` is edited.

Approval must cover the specific change to control physics. A request limited to
dev, a general cleanup or a desire to keep interfaces consistent does not grant
that approval. If the user has already explicitly approved the specific control
change in the current conversation, proceed without asking again.

Without that approval, prepare a concrete proposal and explain the expected
physical or numerical effect, then request confirmation before applying it.
Continue independent work that is already authorized. If unsure whether an edit
changes control physics, resolve that uncertainty before applying it.

I/O, logging, diagnostics, interface and build-plumbing changes may proceed within
the authorized task when they preserve physical inputs, numerical operations and
results. Do not classify an edit as physics-neutral merely because of its filename
or because it fixes a bug.

## 3. Temporary files and external workspaces

Inside the repository, create temporary files only under `_temp/<task>/`.
Use this for small scratch scripts, extracted snippets and draft patches.
An ignored path is not permission to put generated artifacts there.

Keep all builds, model runs and test execution artifacts outside the repository.
Use `TEB_WORK_ROOT` as the external root; on this Windows workstation its default
is `W:\Work_TEB`. On another machine, select a suitable external root explicitly.
Resolve the paths and verify that the task workspace is outside the checkout.

Suggested layout:

```text
<TEB_WORK_ROOT>/TEB-Ru/<task>/
    build/       # separate objects, modules and executables for each build
    runs/        # case working directories, namelists and model output
    logs/        # compiler and execution logs
    checks/      # one-off validation scripts, reports and plots
```

Do not create new build or run artifacts under repository `build/`, `output/`,
`python_tests/`, `tests/` or source directories. Existing artifacts do not create
an exception. Disable or redirect Python bytecode, test caches and other
incidental generated files so they do not appear beside source files.
If an external workspace is unavailable, report the problem instead of silently
falling back to an in-repository output directory.

Clean up only scratch files created for the current task. Preserve external
results for review and report their location; do not delete other tasks' files.

## 4. Building and running

For Fortran layout, follow the upstream [TEB/SURFEX sources](https://github.com/teb-model/teb/):
use two spaces per nested executable block, align continuation lists and comments
on declarations, and preserve existing procedure/module headings, license and
section comments. Keep fixed-form labels, continuation columns and statement
widths intact, and retain Makefile recipe tabs. Formatting must preserve
statements, literals and compiler directives.

Use absolute external paths for Makefile `OBJDIR` and `EXEC`, and capture build
logs externally. The Makefiles' in-repository output defaults are not compliant
with these instructions. Separate ctrl/dev, before/after builds, compiler
toolchains and flag sets; never mix their object or module files.

On Windows, use the matching MSYS2 UCRT64 toolchain in
`C:\msys64\ucrt64\bin`, keep it on the process PATH and pass
`FC=gfortran LD=gfortran` explicitly. Preserve required precision and FPE settings.
Check the exit code, logs for compiler errors and ignored recipe failures, and
the resulting executable. Do not run a broad `make clean` on shared outputs.

Run model cases from an external case directory, copying required inputs there
when relative paths demand it. Set `-param_nml`, `-forcing_nml` and `-output`
explicitly as appropriate. For existing test scripts, inspect their output and
working-directory defaults and override them or use an external copy when needed.

## 5. Tests and verification

Run checks appropriate to the actual change. After they pass, repeat or expand
them only when further changes, failures or unresolved concerns justify it.
Check actual output and completion markers as well as process exit codes.

Keep one-off validation benches in the external task workspace. Do not add new
permanent test benches to the repository unless the user explicitly requests
their inclusion. Existing tracked tests may be used without adding a new bench;
their generated files still belong outside the repository.

Do not overwrite reference outputs, golden files or committed case inputs unless
that update is explicitly part of the task. Compare implementations using the
same forcing, configuration, initial state and compiler settings, and distinguish
expected physical differences from interface or regression errors.

## 6. Documentation and scope

Follow `docs/TEB_MSU_documentation_rules.md` when changing documentation. Keep
current scheme descriptions separate from history and measurement protocols.
Use UTF-8 without BOM and CRLF for documentation, including this file.

Consult the relevant model documents rather than duplicating their details here:

- `docs/TEB_MSU_source_defects.md`: inherited defects and consistency switches.
- `docs/TEB_MSU_containers.md`: container ownership and public API.
- `docs/TEB_MSU_coupling_checklist.md`: COSMO coupling contract and planned work.

Do not edit neighboring repositories, including COSMO-TEB, unless the user
explicitly authorizes that scope. Do not commit or push unless requested.
In the final response, state what changed, what was verified, any remaining
limitations, and the external location of build and test results when applicable.
