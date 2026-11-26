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

Keep documentation synchronized with the implementation. A change to a scheme,
mode, parameter or public interface is incomplete until its documentation is
updated. For namelist keys and output fields, update the variable reference,
including names, units, valid values and defaults. State which source tree and
modes the description applies to, preserving the dev/control distinction.

Keep each explanation in one primary document and link to it from other files:

| Document | Purpose |
| --- | --- |
| `README.md` | Model overview, build/run instructions and documentation navigation. |
| `docs/TEB_MSU_variables_description.md` | Namelist keys and output fields; interface details rather than physics derivations. |
| [docs/schemes/](docs/schemes/README.md) | Physical-scheme descriptions: current equations, assumptions, applicability, limitations and invariants. |
| `docs/TEB_MSU_containers.md` | Data ownership, lifecycle and public API. |
| `docs/TEB_MSU_source_defects.md` | Confirmed inherited defects of the original model and consistency switches. |
| `docs/TEB_MSU_change_history.md` | Concise commit table maintained under section 8. |

Place new physical-scheme descriptions in `docs/schemes/` and add them to its
README index. Keep the variable reference, API documentation, source-defect
registry and commit history directly under `docs/`.
Store diagram images in `illustrations/img/` and drawing scripts in
`illustrations/draw/`.

Scheme documents describe the current implementation. Keep chronology, rejected
variants and per-run result tables out of them. Retain verification methods,
invariants and tolerances with their conditions of applicability and reproduction
commands. Store measured effects, detailed run protocols and reports in external
task results; summarize changes in the commit table. Keep any code-state statement
accurate and distinguish uncommitted work from a committed implementation.

Do not classify bugs introduced by our driver, interfaces or development changes
as inherited model defects. Describe current limitations in the relevant scheme
or API document, fixes in the commit history, and detailed analysis/reproduction
in commit messages and external reports. Preserve existing defect and check IDs
without renumbering them or maintaining a duplicate label registry here.

- Use UTF-8 without BOM and CRLF for documentation, including this file.
- Preserve the document's established language unless the task requests a change.
  Keep README, the variable reference, commit history and AGENTS.md in English.
- Keep one first-level heading per file and preserve its established structure.
  Where sections are numbered, keep their numbering contiguous and update section
  references. Use language tags for code/command blocks when appropriate.
- Keep code identifiers, spelling/case and units consistent with the source.
- Use ordinary Markdown links and tables; do not put HTML anchors in table cells.

When adding, renaming or removing a document, update README navigation and related
document links. Check incoming references across the repository after file or
section changes. Point historical references to the relevant Git revision rather
than a removed current section; record the reason for removal in the history.

Before finishing documentation work, compare the task's own changes with the
initial working state. Check heading/section structure, balanced code fences,
missing files or link targets, leftover template markers, encoding and line
endings. Check the rendered layout of changed tables. Preserve unrelated edits.

For COSMO coupling, consult `docs/TEB_MSU_COSMO_coupling.md` on the coupling branch
of the adjacent [COSMO-TEB repository](https://github.com/mkolennikova/COSMO-TEB).
Do not edit neighboring repositories, including COSMO-TEB, unless the user
explicitly authorizes that scope. Do not commit or push unless requested.
In the final response, state what changed, what was verified, any remaining
limitations, and the external location of build and test results when applicable.

## 7. Maintaining MODIFICATIONS

Update the affected source files' `MODIFICATIONS` sections as part of major
development work. Add a section when needed, using the file's comment syntax.

- Preserve upstream author credits, licenses and modification records. Group
  project contributions under the common label `TEB-MSU development`.
- Record major parameterizations, diagnostic methods, coupling interfaces and
  code reorganizations. Consolidate related edits into milestones; omit routine
  formatting and minor local changes. Do not add placeholder entries to files
  without major project changes. Commit chronology belongs in
  `docs/TEB_MSU_change_history.md`; detailed measurements remain in external
  task results.
- Write concise English entries with a verified developer and date or period,
  following the existing `MM/YYYY -- <developer>` layout. Use `Pre-repository`
  when an imported contribution has no reliable development date. An import or
  file-move date is not necessarily the implementation date.
- For retrospective attribution, compare the designated upstream import with
  initial commit `582c3ab`, then follow subsequent Git history, renames and copies.
  Use user-confirmed attribution, source differences and legacy author markers
  as evidence; commit metadata alone does not establish authorship. Do not invent
  names or dates, or substitute a different upstream version.
- Maintain histories separately for `src_dev`, `src_ctrl`, explicit interfaces
  and retained experimental variants. Describe what changed in that particular
  file; distinguish an original implementation from later adaptation or
  integration. Do not present dormant/commented-out code as active physics.
- Keep dated, initials-based change markers out of code bodies. When retiring
  legacy markers, retain useful explanations of the current physics and API,
  repairing any sentence fragments left by their removal.
- Follow existing comment indentation and keep new history lines within
  80 columns. For comment-only edits, verify that code, literals, compiler
  directives, executable indentation, fixed-form columns and build recipes are
  unchanged; run relevant static checks when they depend on source comments.

## 8. Maintaining the commit history table

Every repository commit you create after explicit user authorization must have
one row in `docs/TEB_MSU_change_history.md`. This includes code, documentation,
tests, build/configuration changes, bookkeeping and merge commits. Historical
omissions do not exempt new commits. This rule does not authorize committing,
amending or pushing on its own.

Use commit subjects in the form `type(scope): subject`, with a type such as
`feat`, `fix`, `refactor`, `test`, `chore` or `docs` and a scope matching the
changed component. In the body, describe the main changes, how they were verified
and which documentation was updated. Keep detailed logs in external task results.

Keep the existing English Markdown table and this exact column order:

| Commit | Date | Author | Files changed | Brief description |
| --- | --- | --- | ---: | --- |

- **Commit:** display the short SHA as an ordinary Markdown link to the full SHA
  at `https://github.com/mkolennikova/TEB-MSU/commit/<full-sha>`. Mark unpublished
  commits `(local)`. Do not use HTML anchors or other HTML in table cells.
- **Date:** use the Git author date as `YYYY-MM-DD`. Order rows from oldest to
  newest; ties follow Git ancestry order. Preserve actual dates even when they
  differ from the dates of earlier work sessions.
- **Author:** use the verified account username, not a full name. Normalize
  Mikhail Varensov, Mikhail Varentsov and the historical root identity associated
  with the same email to `mvarentsov`; retain `mkolennikova` for that account.
  Verify other identities from account/email metadata rather than guessing.
  A tool credit such as `codex` is not the Git author of a human-authored commit.
- **Files changed:** count added, modified, deleted and renamed files against
  the first parent, or the empty tree for an initial commit. Enable Git rename
  detection and count each rename once. Include documentation and the history
  file itself when changed; count the committed diff, not all working files.
- **Brief description:** write one or two concise English sentences describing
  the main changes. Expand enough to cover multiple components of a large
  commit. Keep detailed test logs, measurements and protocols outside the table.

Before each authorized commit, include a pending `Uncommitted` row for that
commit and finalize pending rows for earlier commits. A commit cannot contain
its own final SHA: obtain its SHA, author date, username and file count after
creation, then carry that row's finalization into the next authorized commit.
Until finalized, use the recorded work date, verified work credits and N/A for
an unavailable file count. Replace or consolidate existing pending rows to match
the actual commit boundaries; do not retain duplicate session entries for one
commit. Do not create an extra bookkeeping commit or amend history solely to
fill in a SHA without user authorization.

Before finishing a commit task, verify the row against Git, check the five
columns, chronology, links and absence of duplicate commits, and keep the
coverage header current. Preserve UTF-8 without BOM and CRLF. The scope and
commit workflow in this section take precedence over older history conventions.
