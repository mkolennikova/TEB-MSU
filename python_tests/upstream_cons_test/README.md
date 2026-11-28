# `upstream_cons_test`: control line (`-DTEB_UPSTREAM_CONS`) ↔ official TEB 4.0.0

The test deploys a self-contained bench into a specified directory and compares
the **responses** of two models to enabling/disabling individual urban-surface
components on CAPITOUL forcing.

* `teb_msu_ctrl` — the repository control line (`src_ctrl`), built with
  `-DTEB_UPSTREAM_CONS`;
* `teb_orig_2020` — official TEB 4.0.0 (`github.com/TEB-model/teb`, tag `4.0.0`,
  commit `fb11cad0ae3a1bdb9b676924b5f7f3dc1d6d0343`).

What `TEB_UPSTREAM_CONS` changes to align the control line with official 4.0.0:

| File | Change |
| --- | --- |
| `src_driver/call_driver.F90:1088` | Initial solar position: `XTSTEP_SURF = dt` and an additional `SUNPOS` at `ZTIME - dt` |
| `src_teb/bem.F90:216,403` | Natural-ventilation threshold `XNATVENT_THRESH = 1.0` instead of `0.5` |
| `src_teb/ini_csts.F90:125` | `XSTEFAN` from fundamental constants instead of `5.6697E-8` |
| `src_teb/ini_csts.F90:139` | `XRD/XRV/XCPD` from `XAVOGADRO*XBOLTZ/XM…` instead of rounded literals |
| `src_driver/call_driver.F90`, `src_teb/urban_drag.F90` | D7: legacy `2H/3` wind profile and `+XZD_TOWN` aerodynamic correction instead of consistent `H−XZD_TOWN` |

At the default `teb_ctype_zd_town='H/3'`, the D7 branch reproduces the original
formulas. With another `zd`, it retains the previous `src_ctrl` behavior, whereas
official TEB 4.0.0 had no such parameter. Ordinary `src_ctrl` uses `H−XZD_TOWN`
in both formulas.

## Files

| File | Purpose |
| --- | --- |
| `common.py` | Paths, driver execution, generation of the 2020 initial state from control cold start, output reading and metrics (stdlib only) |
| [`teb_namelist.py`](../teb_namelist.py) | Shared line-based namelist patching (stdlib only) |
| `cases.py` | Cases: `C0_control` + `D1…D5` |
| `deploy.py` | Deployment into `--target`, template preparation and builds of both programs |
| `sensitivity.py` | Execution and metrics: `prepare → run → compare → report` |

The 2020 model code is **not stored** in this repository: `deploy.py` clones it
from its own Git repository into the target directory and checks the revision.

## Deployment

```powershell
python python_tests/upstream_cons_test/deploy.py --target D:\teb_bench --build
```

Options: `--exe-ctrl` / `--exe-2020` (existing executables instead of building),
`--teb2020-src PATH` (copy an existing checkout instead of cloning),
`--teb2020-url` / `--teb2020-tag` / `--teb2020-rev`, `--strip-git`,
`--toolchain-dir DIR` (directory containing `gfortran`/`make`/`cmake`, e.g.
`C:/msys64/ucrt64/bin`), `--runtime-dir DIR`, `--generator`, `--jobs`, `--force`,
`--dry-run`.

Contents created under `--target`:

```
config/provenance.json      revisions, input/executable sha256 hashes, tool versions
config/templates/           namelist templates for both models
data/capitoul/input/        repository CAPITOUL forcing (11 files, 18000 steps)
src/teb_msu_ctrl/src_ctrl/  copy of the control tree
src/teb_orig_2020/          TEB 4.0.0 clone (tag 4.0.0)
tools/                      common.py, cases.py, deploy.py, sensitivity.py, teb_namelist.py
build/, cases/, report/     control executable, run directories, reports
README.md, run.ps1          description and one-command execution
```

Build: control tree — `make … CPPDEFS=-DTEB_UPSTREAM_CONS` (the Makefile adds
`-static-libgfortran` and the UCRT `setlocale` workaround); 2020 model —
`cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_Fortran_FLAGS_RELEASE="-O0 -g"
-DUSE_REAL8=ON` + `cmake --build`.

## Execution

```powershell
python tools/sensitivity.py --target <target> --stage all
```

Stages: `prepare` (case namelists), `run` (both models for each case), `compare`
(`report/sensitivity/summary.csv`), `report` (`report/sensitivity/SUMMARY.md`,
`report/logs/sensitivity.md`). `--smoke N` limits execution to the first `N`
forcing steps, `--cases …` selects cases, and `--runtime-dir DIR` specifies the
gfortran runtime DLL directory.

## Cases

The control template starts from the shared CAPITOUL parameter file.
`&tebopts` contains switches, exchange schemes,
`z0/z0h` rules and the town `z0` and `zd` rules. Surface roughness lengths
and other physical parameters go in `&tebparams`. `C0_control` explicitly
sets `MASC95` and ratio `200` for the road and roof, ratio `200` for the
town, and the default town rules and surface roughness lengths.

| Case | Component | Control (`&tebopts` and `&tebparams`) | 2020 (`&parameters`) |
| --- | --- | --- | --- |
| `C0_control` | — | Original CAPITOUL namelist scenario: garden 0.11, roof 0.3, `teb_frac_gz=0.1`, natvent `'NONE'`, `teb_cap_sys_rat=100/7`, `teb_ti_bld_init=292.15`, `teb_dt_res/off=3`, `urb_emis_*` instead of legacy `urb_alb_*_th` | Pristine namelist + `XTSTEP_SURF=300`, `HZ0H='MASC95'`, `CCH_BEM=' '`; initial state from control-line cold start (292.15 K anchor) |
| `D1_garden_off` | Garden | `teb_lgarden=.FALSE.`, `fr_garden=0.0` | `LGARDEN=.FALSE.`, `ZGARDEN=0.0` |
| `D2_greenroof_off` | Greenroof | `teb_lgreenroof=.FALSE.`, `teb_frac_gr=0.0` | `LGREENROOF=.FALSE.`, `ZFRAC_GR=0.0` |
| `D3_solar_on` | Solar panels | `teb_lsolar_panel=.TRUE.`, `teb_fr_panel=0.5` | `LSOLAR_PANEL=.TRUE.`, `ZFRAC_PANEL=0.5` |
| `D4_shading_on` | Window shading | `teb_lshade=.TRUE.` | `LSHADE=.TRUE.`, `ZSHADE=1.` |
| `D5_no_bem` | BEM (disabled) | `teb_ctype_bem='DEF'`, `teb_frac_gz=0.0` | `CBEM="DEF"`, `ZGR=0.0` |

`D1…D5` inherit the `C0_control` namelists, so the pristine scenario and initial
state are retained on the 2020 side; only the component switch differs. Glazing
fraction is part of the `D5` switch: **both** drivers stop with
`Building Energy Module (BEM) is not activated but a non-zero glazing
ratio is given` (`call_driver.F90:1063`) if `ZGR ≠ 0` is retained with BEM disabled.

## Metric

For each case and variable, responses are compared rather than absolute fields:

```
d_ctrl   = ctrl(case)     - ctrl(C0_control)
d_2020   = upstream(case) - upstream(C0_control)
residual = d_2020 - d_ctrl
signal   = max(|d_ctrl|, |d_2020|)
rel      = max|residual| / signal
```

Verdicts: `identical` (`rel ≤ 1e-3`), `close` (`rel ≤ 1e-2`), `different`
(otherwise), `inactive` (signal does not exceed baseline residual `base_residual`
— model-to-model noise in `C0_control`), `no-output` (the 2020 driver does not
write the variable's file in this configuration: `HVAC_*` with BEM disabled,
`PHOT/THER_PROD_PANEL` with panels disabled).

The target is `identical`: the component is connected consistently; `different`
indicates a difference in component integration or namelist-key mapping.

## Reference result

Full year (17999 rows), from the bench where the test originated:

| Case | identical | close | different | inactive | no-output |
| --- | ---: | ---: | ---: | ---: | ---: |
| `D1_garden_off` | 13 | 0 | **0** | 2 | 0 |
| `D2_greenroof_off` | 12 | 1 | **0** | 2 | 0 |
| `D3_solar_on` | 13 | 0 | **0** | 2 | 0 |
| `D4_shading_on` | 11 | 2 | **0** | 2 | 0 |
| `D5_no_bem` | 11 | 0 | **0** | 2 | 2 |

Totals: 60 `identical`, 3 `close` (maximum `rel = 1.72e-3`: `D4/H_TOWN`, row
16462), **0 `different`**. `inactive` applies to `P_CANYON` and `U_CANYON`
(the switches do not affect them). Re-running with a new build must reproduce
the verdicts; absolute executable sha256 hashes may differ with compiler version.

**Verified in this deployment**: `deploy.py --build` + `sensitivity.py
--stage all` reproduced these verdicts and numbers (`rel`, maximum-error rows,
`base_residual`) — 12 runs of 17999 rows, 0 nonfinite values.

In `D5_no_bem`, the test checks that `HVAC_COOL`, `HVAC_HEAT` and `H_WASTE` are zero
in the control output. Upstream writes empty files for `HVAC_COOL` and
`HVAC_HEAT`, so these two rows receive `no-output`.

## Requirements

* Python ≥ 3.10 (standard library only);
* `git` (2020-model clone), `gfortran`, `make`, `cmake` + `ninja` (or `make`) for
  `--build`; if missing from `PATH`, supply `--toolchain-dir`;
* gfortran runtime: if a driver exits with `rc=0xC0000135`
  (STATUS_DLL_NOT_FOUND), supply `--runtime-dir` (the directory containing
  `libgfortran-5.dll`); during deployment, the deployer copies required DLLs
  beside the executables if it finds the runtime.

## Limitations

* Only CAPITOUL and the `C0` + `D1…D5` cases are compared;
* the 2020 initial state is synthesized from control-line cold start (the 2020
  model has no cold start), so the first weeks retain initial-state memory;
  the response metric does not rely on that;
* the `E01…E10` feature matrix and spin-up are outside this test's scope.
