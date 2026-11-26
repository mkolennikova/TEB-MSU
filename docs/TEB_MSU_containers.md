# TEB-MSU containers: structure, ownership and paths from teb_interface to teb_garden

This document describes the **implemented** organization of all TEB-MSU model containers: eleven objects for parameters, options, state, diagnostics, substep forcing and external garden/roof surfaces; their ownership and lifecycle, field composition, and path through `run_teb_offline → TEB_OFFLINE_DRIVER → teb_interface → CALL_DRIVER → TEB_GARDEN`. The `TEB_GARDEN_STRUCT` wrapper is removed: `CALL_DRIVER` calls `TEB_GARDEN` physics directly.

> Code state: `main`, commit `1ecb04e`, and working changes to the `src_dev` API.

Related documents:

* `schemes/TEB_MSU_CBS_scheme_T_CAN_reformulation.md` — road CBS (diagnostics `H_ROAD`, `LE_ROAD`, `T_CAN0`, `T_CAN1`, `PCD_ROAD_*`, `PAC_ROAD_*` are `DMT` fields);
* `schemes/TEB_MSU_garden_diagnostic_scheme.md` — diagnostic garden and external roof model;
* `TEB_MSU_source_defects.md` — original TEB defects;
* `TEB_MSU_change_history.md` — development history, including containers, interface deduplication and moving forcing into `FORC`;
* COSMO coupling is described in `docs/TEB_MSU_COSMO_coupling.md` on the working branch of [COSMO-TEB](https://github.com/mkolennikova/COSMO-TEB).

---

## 1. Purpose

**Problem.** TEB-MSU physics handles five kinds of quantities:

* **Static data** (configuration, geometry, materials): specified once from the namelist and unchanged during a run.
* **State** (prognostic temperatures, humidity, snow): carried between substeps and forcing steps.
* **Diagnostics** (fluxes, absorption, town aggregates): computed by physics for the host/output; two `DMT` fields also feed the next substep (§3).
* **Substep forcing** (host meteorological inputs and derivatives): updated every substep and read-only to physics.
* **External surfaces** (host-computed external garden/greenroof state and fluxes): updated every substep and read-only to physics.

Previously all five kinds used flat arguments: physics signatures grew to hundreds of dummies, with no compiler checking mismatched order, type or rank. Quantities are now grouped into **eleven containers**, created once per run and passed through the call chain as one argument each.

**Solution.**

* State, parameters, options, diagnostics, substep forcing and external surfaces use eleven aggregates: `TOPTS, TPARAMS, TSTATE, BOPTS, BPARAMS, BSTATE, TPN, TIR, DMT, FORC, EXT`.
* Time, cell indices, coordinates and two garden conductances (`teb_tch_gd`/`teb_tcm_gd`, returned by TEB to the host) remain flat arguments: the callee needs them directly and they change each step/cell.
* Procedures have module interfaces checked by the compiler at every call.

---

## 2. Eleven containers

| Name | Type | File | Fields | Role |
| --- | --- | --- | --- | --- |
| `DMT` | `DIAG_MISC_TEB_t` | `src_struct/modd_diag_misc_tebn.F90` | 246 | Fluxes, absorption, town aggregates, snow, garden/roof, road/roof MRT, canyon UTCI and two interstep inputs (§3) |
| `TOPTS` | `TEB_OPTIONS_t` | `src_struct/modd_teb_optionn.F90` | 28 param + 2 work + 3 reserved | TEB options: schemes, flags, garden/roof type |
| `TPARAMS` | `TEB_PARAMS_t` | `src_struct/modd_teb_paramsn.F90` | 39 param + 4 flux | TEB static parameters: geometry, materials, anthropogenic fluxes |
| `TSTATE` | `TEB_t` | `src_struct/modd_tebn.F90` | 10 state + 1 reserved | TEB prognostic state: roof, road, walls, canyon, snow |
| `BOPTS` | `BEM_OPTIONS_t` | `src_struct/modd_bem_optionn.F90` | 5 param | BEM options: air-conditioning type, coil, autosize |
| `BPARAMS` | `BEM_PARAMS_t` | `src_struct/modd_bem_paramsn.F90` | 40 param | BEM static parameters: floors, HVAC, windows |
| `BSTATE` | `BEM_t` | `src_struct/modd_bemn.F90` | 9 state + 8 work + 2 reserved | BEM state: floor/mass temperatures, windows, HVAC accumulators |
| `TPN` | `TEB_PANEL_t` | `src_struct/modd_teb_paneln.F90` | 4 param + 1 state | Solar panels: fraction, albedo, efficiency, temperature |
| `TIR` | `TEB_IRRIG_t` | `src_struct/modd_teb_irrign.F90` | 6 param + 13 reserved | Road irrigation schedule |
| `FORC` | `TEB_FORCING_t` | `src_struct/modd_teb_forcingn.F90` | 22 work | Substep forcing: 14 raw host quantities + 8 derivatives (pressure/Exner functions, density, wind speed, solar time/position, direct/diffuse SW) |
| `EXT` | `TEB_EXT_SURF_t` | `src_struct/modd_teb_ext_surfn.F90` | 18 work | Host-computed external garden/greenroof state and fluxes: roughness, albedo, emissivity, temperature, humidity, fluxes, evaporation, runoff |

Total: **461 fields** in eleven containers (246 in `DMT` + 215 in the ten types covered by `container_fields_inventory.py`). Categories (`param`/`flux`/`state`/`work`/`reserved`) follow the contract in `python_tests/container_fields_inventory.py`; `DMT` has its own `python_tests/check_diag_container.py` check.

---

## 3. Container layer: TEB_HOST module

For roof, road and walls, `TEB_HOST` allocates arrays using the positive layer counts supplied to `teb_interface`. Work containers are recreated when sizes change between calls; prognostic state remains host-owned and is loaded before each column calculation. Building floor and internal mass retain five layers.

`urb_d_rf`, `urb_d_rd`, `urb_d_wl` are optional one-dimensional thickness profiles shared by the entire API call. `TEB_CHECK_LAYER_DEPTHS` checks length, finiteness and positivity before calculation. Omitting a profile is allowed for five layers and selects standard depths. `TEB_FILL_DERIVED` writes profiles into `TPARAMS%XD_ROOF/XD_ROAD/XD_WALL` and applies input `urb_hcap_*` and `urb_hcon_*` to every layer of the corresponding surface. Initial temperatures use actual layer counts. Namelist parameters and defaults are in [§2.9 of the variable reference](TEB_MSU_variables_description.md#29-layer-configuration).

Containers are module variables of `TEB_HOST` in `src_api/teb_host.F90`:

```fortran
TYPE(TEB_OPTIONS_t),  SAVE :: TOPTS     ! options of TEB
TYPE(TEB_PARAMS_t),   SAVE :: TPARAMS   ! parameters of TEB
TYPE(TEB_t),          SAVE :: TSTATE    ! state of TEB
TYPE(BEM_OPTIONS_t),  SAVE :: BOPTS     ! options of BEM
TYPE(BEM_PARAMS_t),   SAVE :: BPARAMS   ! parameters of BEM
TYPE(BEM_t),          SAVE :: BSTATE    ! state of BEM
TYPE(TEB_PANEL_t),    SAVE :: TPN       ! solar panels
TYPE(TEB_IRRIG_t),    SAVE :: TIR       ! irrigation
TYPE(DIAG_MISC_TEB_t),SAVE :: DMT       ! diagnostics
TYPE(TEB_FORCING_t),  SAVE :: FORC      ! atmospheric forcing of the sub-step
TYPE(TEB_EXT_SURF_t), SAVE :: EXT       ! external garden / greenroof surface (host -> TEB)
```

Layer procedures:

| Procedure | Action |
| --- | --- |
| `TEB_HOST_ENSURE(KNVEC, KROOF, KROAD, KWALL, KFLOOR)` | Lazy allocation of all eleven containers per thread; recreation when layer counts change |
| `TEB_FILL_PARAMS(KSTART, KEND, …)` | Write namelist configuration into `TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR`, only within `KSTART:KEND` |
| `TEB_FILL_DERIVED(KSTART, KEND, …)` | Derive static geometry, sky-view factors, BEM morphology and window optics |
| `TEB_FILL_FORCING(KSTART, KEND, …)` | Populate raw host forcing and derivatives in `FORC` |
| `TEB_FILL_EXT(KSTART, KEND, PDT, …)` | Populate host garden/roof state and fluxes in `EXT`; convert runoff to rate (`/PDT`) |
| `TEB_BIND_STATE(KSTART, KEND, …)` | Copy host state into the `TSTATE`/`BSTATE` window |
| `TEB_INIT_STATE(KSTART, KEND)` | Cold-start state at the first model step (`ntstep == 0`), called by `teb_interface` before `CALL_DRIVER` |
| `TEB_UNBIND_STATE(KSTART, KEND, …)` | Copy updated state back to the host |
| `TEB_HOST_FINAL` | Deallocate all containers at run end |

**Allocation.** `TEB_HOST_ENSURE` calls `ALLOC_TEB_STRUCT` for `TOPTS`, `TSTATE`, `BOPTS`, `BSTATE`, `TPN`, `TIR`; `ALLOC_TEB_PARAMS` for `TPARAMS`; `ALLOC_BEM_PARAMS` for `BPARAMS`; `DIAG_MISC_TEB_ALLOC` for `DMT`; `ALLOC_TEB_FORCING` for `FORC`; and `ALLOC_TEB_EXT_SURF` for `EXT`. `TPARAMS`/`BPARAMS` were separated from `TEB_t`/`BEM_t` so state holds only prognostic quantities and static data are stored separately and passed through explicit `TPARAMS`/`BPARAMS` arguments.

**Population.** `TEB_FILL_PARAMS` writes namelist values directly in `teb_interface`, where configuration is known. `CALL_DRIVER` no longer copies arguments into containers; only derived assignments computed from its local variables remain (`TEB_FILL_DERIVED`, history records 63–67).

**State.** `TEB_BIND_STATE` and `TEB_UNBIND_STATE` copy values using `=`, although container fields are pointers. They transfer 30 host-state fields (20 in `TSTATE`, 10 in `BSTATE`, including snow components). `LSHADE` is additionally loaded as an option and `XALB_WIN` exported as a derived diagnostic. The host owns the state of all columns.

**Interstep coefficients.** The mandatory `teb_interface` signature ends with two required `REAL, DIMENSION(nvec), INTENT(INOUT)` arrays:

| Argument | Work field | Initial value at `ntstep == 0` | Use in the next substep |
| --- | --- | --- | --- |
| `teb_ustar_town` | `DMT%XUSTAR_TOWN` | `0.2 m/s` | Wang input before the new `u*` calculation |
| `teb_cd_greenroof_atm` | `DMT%XPCD_GREENROOF_ATM` | `XUNDEF` | External-roof friction; neutral formula on the first substep |

At `ntstep > 0`, both values are copied from host arrays to `DMT` before `CALL_DRIVER` and returned afterwards. Cold start sets the table values independently of input arrays. The offline driver retains them across all model substeps. On restart, the host restores both arrays with the rest of the state and passes a nonzero step number; restart format is outside this API. External roofs do not require a separate copy of all `DMT`.

If either `teb_ctype_z0_town_dyncorr` or `teb_ctype_zd_town_dyncorr` is `'ZIL2008'`, the host supplies shared `teb_inv_l_town_prev`, length `nvec`, with attributes `REAL, OPTIONAL, INTENT(INOUT)`. It stores inverse Obukhov length in the paper's convention (`1/L = −F_b/u_*³`, m⁻¹) for each column. At `ntstep == 0`, calculation uses neutral `1/L=0`. At `ntstep > 0`, the API loads active-column history before `WIND_TOP` and returns the new value from `CALL_DRIVER` after physics. With both options `'OFF'`, the array can be omitted. The offline host includes it in checkpoints.

**Optional outputs.** After required arguments, the API has 44 `OPTIONAL, INTENT(OUT)` arrays: current `DMT` results and a road snapshot after loading/cold start, before physics (`teb_troad_before`). Omitting them does not change the model step. Export retains TEB units and area normalization; DEF HVAC powers are zero without reading undefined diagnostics. Module `sfc_teb` publicly exports `teb_interface`, `teb_finalize`, `teb_real_kind = KIND(0.0)` and `teb_undef` (exact `XUNDEF` value with the same REAL kind). Inputs, state and results have explicit INTENT attributes.

**Call configuration and finalization.** The API accepts scalar `LOGICAL, OPTIONAL, INTENT(IN), VALUE :: teb_snow_check`, shared by the block. If present, it sets the module flag before physics; if absent, the current setting is retained (initially `.FALSE.`). Offline passes the namelist choice each step. An external host can pass `.TRUE.` on every call without directly accessing the physical-parameter module.

Three optional strings, `teb_ctype_exch_road`, `teb_ctype_exch_roof` and `teb_ctype_exch_canyon`, select exchange algorithms for the entire block. Each omitted argument defaults to `'MASC95'` on that call. Offline passes `teb_ctype_exch_rd`, `teb_ctype_exch_rf` and `teb_ctype_exch_canyon` from `&tebopts`, respectively.

Optional strings `teb_ctype_z0_town_dyncorr` and `teb_ctype_zd_town_dyncorr` independently select dynamic town roughness/displacement corrections for the block. Each defaults to `'OFF'`. Offline loads the identically named `&tebopts` keys.

`teb_finalize()` closes logs, resets their settings and releases work containers through `TEB_HOST_FINAL`. It is safe before the first step and on repeated calls. Host-column state, constants and the snow flag are unchanged. To continue after release, the host passes saved state with nonzero `ntstep`; work memory is lazily allocated. Releasing memory does not imply cold start.

**Columns.** The public API accepts a block with `nvec>=1` and window `ivstart:ivend`; only points with `sa_uc(i)>0` are processed. Physics containers have size 1. For each urban column, `teb_interface` loads parameters, forcing, external surfaces and state into work position 1, calls `CALL_DRIVER(icell=1)` and returns results to host position `i`. INOUT values outside the urban window mask are preserved; OUT values are defined only for processed points. An empty window is `ivend=ivstart-1` with `1<=ivstart<=nvec+1`; it does not call physics. Both offline executables use the shared driver with `nvec>=1`, set by `tebopts`.

Before filling containers, the API checks window bounds, five floor layers and consistency of roof/road/wall layer counts with depth profiles. `TEB_HOST_ENSURE` receives work size 1 and validates sizes when reusing memory. COSMO calls the API on an `nproma` block.

**Offline configuration and output.** Shared modules `src_offline/teb_offline_host.F90`, `teb_offline_namelists.F90`, `teb_offline_driver.F90`, `teb_offline_surfaces.F90` and `teb_offline_output.F90` serve both main programs. Physical parameters come from `tebparams`; `dt` and common options from `tebopts`. `teb_ctype_wind` accepts `DEF` or `WANG`, and its API counterpart passes the string into `TOPTS%CTYPE_WIND`. State and runoff accumulators belong to each host column. CSVs use logical column IDs; diagnostic permutations pass the logger a mapping from current positions to persistent IDs. Without it, ordinary API indexing is retained. Input/output format is in `TEB_MSU_variables_description.md`.

**Cold start.** `TEB_INIT_STATE(KSTART, KEND)` fills window state on the first model step. It is called inside the `teb_interface` urban loop under `ntstep == 0`, before that column's `CALL_DRIVER`. Offline passes `(nstep-1)*INB_ATM + (JSURF_STEP-1)`; a coupled host supplies its own zero-based step number. On restart with `nstart > 0`, initialization is not called. `teb_interface` calls `INI_CSTS` before parameter/forcing preparation at every step, including a first call with urban points and nonzero step number. After that column's `CALL_DRIVER` at `ntstep == 0`, it synchronizes `DMT%XTSTOWN_S_NOW` with post-`TEB_GARDEN` `DMT%XTSTOWN_S`. Initial roof/wall profiles, internal-window temperature and `XT_FLOOR`/`XT_MASS` are anchored to `XTI_BLD` (initial `teb_ti_bld_init`, falling back to `XTCOOL_TARGET`); `XUNDEF` is resolved for `XTI_BLD`/`XQI_BLD` before state is filled. `src_ctrl` implements the same order in `CALL_DRIVER` under `IF (ntstep == 0)`.

---

## 4. Containers through the call chain

The common API/physics chain is built as static library `libteb.a`. The offline host in `src_dev/src_offline/` links against it; its `MODD_FORC_ATM` arrays and reading/interpolation procedures are outside the library. Common `.mod` files and objects are separate from offline `.mod` files and objects. Source/include manifests are in `src_dev/make/teb_sources.mk`; module dependencies in `src_dev/make/teb_dependencies.mk`. External `BUILD_ROOT` sets build paths; commands and compiler requirements are in README.

```
run_teb_offline
  → teb_interface (211: 158 required + 44 OPTIONAL OUT + 8 OPTIONAL IN + 1 OPTIONAL INOUT) src_api/sfc_teb.F90
      → block/layer validation; ivstart:ivend mask, sa_uc>0
      → TEB_LOG_AT_CADENCE(ntstep)   one decision for all blocks of the step
      → INI_CSTS             physical constants
      → TEB_HOST_ENSURE(1,…) allocate 11 containers (first nonempty call)
      → loop over urban columns i:
          → TEB_FILL_PARAMS      TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR ← inputs i
          → TEB_FILL_DERIVED     derived static data (morphology, window optics)
          → TEB_FILL_FORCING     FORC ← forcing of column i
          → TEB_FILL_EXT         EXT ← external surfaces of column i
          → TEB_BIND_STATE       TSTATE/BSTATE ← state of column i
          → TEB_INIT_STATE       cold start, only at ntstep == 0
            or load              previous u*, roof CD and 1/L for ZIL2008, ntstep > 0
          → road snapshot        OPTIONAL teb_troad_before, after cold start
          → CALL_DRIVER (28 dummy), icell=1       src_driver/call_driver.F90
              → TEB_GARDEN (29 arguments)         src_teb/teb_garden.F90
                  reads/writes TOPTS/TPARAMS/TSTATE/BOPTS/BPARAMS/BSTATE/TPN/TIR/DMT
                  reads FORC and EXT
          → export u*/CD/1/L    values for the next host substep
          → TEB_UNBIND_STATE     state of column i ← TSTATE/BSTATE
          → OPTIONAL OUT         current results into host position i
          → TEB_LOG_EMIT         KHOST_CELL=i, data from work position 1
  → teb_finalize             close logs and TEB_HOST_FINAL (run end)
```

Containers are **not local declarations** in `teb_interface`/`CALL_DRIVER`: they are `TEB_HOST` module variables passed through the chain as actual arguments (dummy arguments in `CALL_DRIVER` and `TEB_GARDEN` signatures).

Paths by quantity kind:

| Kind | Path | Writer | Reader |
| --- | --- | --- | --- |
| Static `TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR` | `TEB_FILL_PARAMS`/`TEB_FILL_DERIVED` in `teb_interface` → `CALL_DRIVER` → `TEB_GARDEN` | `TEB_HOST` layer, each urban column/substep | Physics: `TEB_GARDEN` and its subroutines |
| State `TSTATE/BSTATE` | Host → `TEB_BIND_STATE` → `CALL_DRIVER` → `TEB_GARDEN` → `TEB_UNBIND_STATE` → host | Host and physics | Physics and `TEB_LOG_EMIT` |
| Diagnostics `DMT` | `TEB_HOST_ENSURE` allocation → `CALL_DRIVER` → `TEB_GARDEN` | Physics: `TEB_GARDEN` and its subroutines | `TEB_LOG_EMIT` (CSV), `CALL_DRIVER` (aggregates) |
| Forcing `FORC` | `ALLOC_TEB_FORCING` ⇒ `TEB_FILL_FORCING` each column/substep → `CALL_DRIVER` → `TEB_GARDEN` | `TEB_HOST` layer | Physics: `TEB_GARDEN` and its subroutines; `TEB_LOG_EMIT` (`P_CANYON`, `SOLAR_*` columns) |
| External surfaces `EXT` | `ALLOC_TEB_EXT_SURF` ⇒ `TEB_FILL_EXT` each column/substep → `CALL_DRIVER` → `TEB_GARDEN` | `TEB_HOST` layer | Physics: `TEB_GARDEN` and its subroutines; `CALL_DRIVER` (albedo aggregates/z0 validation) |

`TEB_GARDEN` receives all eleven containers: `TPARAMS`, `FORC` and `EXT` are `INTENT(IN)` (read-only); the other eight are `INTENT(INOUT)`.


---

## 5. Containers in detail

### 5.1 `DMT` — diagnostics (`DIAG_MISC_TEB_t`, 246 fields)

**Physics** fills this container; **host and output** read it. Two interstep fields are restored from host arguments before physics (§3). Fields are `REAL, POINTER, DIMENSION(:)` with length set at allocation (`KNVEC`, 1 in the offline driver). Contents include SURFEX fields (`XH_WALL_A`, `XRN_ROOF`, `XGFLUX_*`, `XHVAC_*`), TEB-MSU fields (road CBS, garden/roof, snow branch), and the CBS branch-diagnostic record used twice (below).

* Allocation: `DIAG_MISC_TEB_ALLOC(DMT, KNVEC)` in `TEB_HOST_ENSURE`.
* `NULLIFY`/`ALLOCATE`/`DEALLOCATE` are three mirrored lists (246/246/246), checked by `check_diag_container.py`.
* Every field has a **producer**: direct assignment or `INTENT(OUT/INOUT)` dummy (legacy `!OUT` marker), checked by `check_diag_producers.py`. The only exception is `XIRRIG_GARDEN` (`reserved`: garden irrigation is not implemented; `GARDEN_CBS` returns `PIRRIG_GARDEN = 0.`).
* `XUNDEF` initialization of 15 output fields read before being written moved from the wrapper to `TEB_GARDEN`.
* `CALL_DRIVER` computes town aggregates (`H_TOWN`, `LE_TOWN`, `RUNOFF_*`, `HSNOW_TOWN`, etc.) from physical quantities.
* `CALL_DRIVER` writes neutral/effective town roughness and displacement, the shared stability argument, limiter flags and neutral-fallback flags to `DMT`.
* `URBAN_SOLAR_ABS` writes road/roof irradiation (`XSW_*_ROAD`, `XSW_*_ROOF`) and road sunlit surface fraction (`XSUN_FRAC_ROAD`). `TEB_GARDEN` supplies geometric body-height fraction `XSUN_FRAC_PED` and four outgoing fluxes from canyon floor/accessible roof (`XMRT_K_FLOOR`, `XMRT_L_FLOOR`, `XMRT_K_OPEN`, `XMRT_L_OPEN`). `URBAN_MRT` and `URBAN_MRT_ROOF` compute `XMRT`, `XMRT_SUN`, `XMRT_SHADE`, `XMRT_ROOF` and `XMRT_F_*`, `XMRT_SW_*`, `XMRT_LW_*` components. [MRT scheme](schemes/TEB_MSU_MRT_pedestrian_scheme.md)
* `CALL_DRIVER` passes three ground-level MRTs, air temperature, humidity, pressure and pedestrian-height wind to `CANYON_UTCI`. Four results are stored in `XUTCI_ROAD`, `XUTCI_ROAD_SUN`, `XUTCI_ROAD_SHADE`, `XUTCI_WIND_10M`.

**CBS branches (`TEB_CBS_BRANCH_t`).** Road, garden and road snow exchange with two air reservoirs: canyon (`CAN`) and forcing level (`ATM`). Both branches carry the same quantities, declared as **one record** used twice in `DMT`: `DMT%CAN%…` and `DMT%ATM%…`, as with `TSTATE%TSNOW_ROOF%T`.

| Component | Meaning | CSV columns (`CAN` / `ATM`) |
| --- | --- | --- |
| `PCD_ROAD`, `PCDN_ROAD`, `PRI_ROAD`, `ZZ0H_ROAD` | Road exchange coefficients | `PCD_ROAD_CAN`/`_ATM`, `PCDN_…`, `PRI_…`, `ZZ0H_…` |
| `PAC_ROAD`, `PAC_ROAD_WAT`, `PCH_ROAD` | Road conductances: dry, water, heat | `PAC_ROAD_CAN`/`PAC_ROAD_ATM`, `PAC_ROAD_WAT`/`PAC_ROAD_ATM_WAT`, `PCH_ROAD_CAN`/`PCH_ROAD_ATM` |
| `PH_ROAD`, `PLE_ROAD` | Road fluxes into the branch | `H_ROAD_CAN`/`_ATM`, `LE_ROAD_CAN`/`_ATM` |
| `PCD_GARDEN`, `PCH_GARDEN`, `PCDN_GARDEN`, `PRI_GARDEN`, `ZZ0H_GARDEN`, `PAC_GARDEN` | Garden coefficients and conductances | `PCD_GARDEN_CAN`/`_ATM`, `PCH_…`, `PCDN_…`, `PRI_…`, `ZZ0H_…`, `PAC_GARDEN`/`PAC_GARDEN_ATM` |
| `H_GARDEN`, `LE_GARDEN` | Garden fluxes into the branch | `H_GARDEN_CAN`/`_ATM`, `LE_GARDEN_CAN`/`_ATM` |
| `PHSN_RD`, `PLESN_RD` | Road snow → branch | Not written |

The record owns its lifecycle: `INIT_CBS_BRANCH` (`NULLIFY`), `ALLOC_CBS_BRANCH` and `DEALLOC_CBS_BRANCH` in `MODD_DIAG_MISC_TEB_n` operate on one instance and are called for `CAN` and `ATM` by `DIAG_MISC_TEB_INIT` / `DIAG_MISC_TEB_ALLOC` / `DIAG_MISC_TEB_DEALLOC`.

Two qualifications:

* `PHSN_RD`/`PLESN_RD` are **persistent**: canyon nodes read them at substep start and `URBAN_SNOW_EVOL` writes at its end, so these are **previous-substep** values.
* In `PROXY_*`, the garden model returns one conductance, stored in `CAN%PAC_GARDEN` (column `PAC_GARDEN`); `ATM%PAC_GARDEN` remains `XUNDEF`. `EXT`/`EXT_NEU` fill both branches through `URBAN_DRAG`.

Six `_ATM` fields remain flat: `PAC_GREENROOF_ATM`, `PCD_GREENROOF_ATM`, `PCDN_GREENROOF_ATM`, `PCH_GREENROOF_ATM`, `PRI_GREENROOF_ATM`, `ZZ0H_GREENROOF_ATM`. Greenroofs have no branches and exchange only with forcing level.

### 5.2 `TOPTS` — TEB options (`TEB_OPTIONS_t`, 28 param + 2 work + 3 reserved)

Schemes and flags: `CGARDEN`/`LGARDEN`, `LGREENROOF(_EXT)`, `CTYPE_GARDEN`/`CTYPE_GREENROOF`, `CBEM`, `CTYPE_WIND`, `LSOLAR_PANEL`, `LCBS_SCHEME`, `XTAU_HW_THRESH`/`XTAU_HW_WIDTH`, `NUTC_HOUR`, `XZ0_O_Z0H_GD/GR`, `CEXCH_ROAD/ROOF/CANYON`, `CTYPE_Z0_TOWN_DYNCORR`, `CTYPE_ZD_TOWN_DYNCORR` and `TZ0H`. `CALL_DRIVER` fills `work` fields `TTIME`, `XTSTEP` every step.

`TZ0H` holds road, roof and town thermal-roughness rules. For each call, the offline host supplies shared `&tebopts` rules and current-column `XZ0_O_Z0H_GD/GR` ratios. On checkpoint loading, garden/greenroof ratios come from the namelist using saved column IDs. Checkpoint format 5 stores per-cell shared `1/L` history. Format 4 is accepted with matching configuration and both options `'OFF'`.

### 5.3 `TPARAMS` — TEB parameters (`TEB_PARAMS_t`, 39 param + 4 flux)

Static geometry/materials: fractions (`XBLD`, `XROAD`, `XGARDEN`, `XGREENROOF`), `XCAN_HW_RATIO`, `XBLD_HEIGHT`, roof/road/wall albedo, emissivity, heat capacity, conductivity, sky-view factors, `XZ0_TOWN`/`XZD_TOWN`, building use (`XRESIDENTIAL`, `XDT_RES/OFF`). The `flux` fields are anthropogenic `XH_/XLE_TRAFFIC`, `XH_/XLE_INDUSTRY`. `INTENT(IN)` throughout physics. `TPARAMS%XZ0_TOWN` and `TPARAMS%XZD_TOWN` hold neutral values; each substep `URBAN_DRAG` receives effective roughness/displacement as separate arguments.

`TZ0` holds momentum roughnesses of road, roof and snow. The offline host passes them from block parameters into `TPARAMS` for the call and restores the previous setting afterwards. Restart reads values from the same namelist.

### 5.4 `TSTATE` — TEB state (`TEB_t`, 10 state + 1 reserved)

Surface prognostics: `XT_ROOF/ROAD/WALL_A/WALL_B`, `XT_CANYON`, `XQ_CANYON`, `XWS_ROOF/ROAD`, snow (`TSNOW_ROOF/ROAD` with `WSNOW`, `T`, `RHO`, `ALB`, `EMIS`, `TS`, `SCHEME`). `TEB_GARDEN` sets `TSNOW_*%SCHEME` from `HSNOW_ROOF/HSNOW_ROAD` (previously the wrapper did this).

### 5.5 `BOPTS` — BEM options (`BEM_OPTIONS_t`, 5 param)

Air-conditioning/coil type: `CCOOL_COIL`, `CHEAT_COIL`, `LBEM_AC`, `LAUTOSIZE`, `NFLOOR_LAYER` (layer count from `teb_nfloor_layer`).

### 5.6 `BPARAMS` — BEM parameters (`BEM_PARAMS_t`, 40 param)

Building static data: floor materials (`XHC_FLOOR`, `XTC_FLOOR`, `XD_FLOOR`), HVAC setpoints (`XTCOOL_TARGET`, `XTHEAT_TARGET`, `XCAP_SYS_HEAT`, `XCOP_RAT`), ventilation/infiltration (`XV_VENT`, `XINF`), windows (`XU_WIN`, `XTRAN_WIN`, `XALB_WIN`, `XABS_WIN`, `XSHGC_WIN`), internal geometry and view factors. `INTENT(INOUT)` in physics: BEM still recalculates window optics and autosizing; this can be removed by moving one-time calculations into initialization.

### 5.7 `BSTATE` — BEM state (`BEM_t`, 9 state + 8 work + 2 reserved)

Building prognostics: `XT_FLOOR`, `XT_MASS`, `XTI_BLD`, `XQI_BLD`, `XT_WIN1/2`, `XCAP_SYS_RAT`, `XM_SYS_RAT`. The `work` fields are nonprognostic: window optics `XALB_WIN`/`XABS_WIN`/`XTRAN_WIN`/`XUGG_WIN`, accumulator `XAUX_MAX`, dew point `XT_ADP`, and flags `LSHADE`/`LSHAD_DAY`/`LNATVENT_NIGHT`. `RESERVED` fields `XSHADE`, `XNATVENT` are REAL mirrors of I/O flags marked `TODO`.

### 5.8 `TPN` — solar panels (`TEB_PANEL_t`, 4 param + 1 state)

`TEB_FILL_PARAMS` sets `XEMIS_PANEL`, `XALB_PANEL`, `XEFF_PANEL`, `XFRAC_PANEL` (moved from `CALL_DRIVER`, P-C4); physics (`SOLAR_PANEL`) sets state (production, temperature).

### 5.9 `TIR` — road irrigation (`TEB_IRRIG_t`, 6 param + 13 reserved)

Irrigation schedule: `LPAR_RD_IRRIG`, `XRD_START/END_MONTH`, `XRD_START/END_HOUR`, `XRD_SUM`, populated by `TEB_FILL_PARAMS`.


---

### 5.10 `FORC` — substep forcing (`TEB_FORCING_t`, 22 work)

The **layer** (`TEB_FILL_FORCING`) fills this container; only physics/output read it. It replaced 19 separate arguments carrying the same quantities from `CALL_DRIVER` to `TEB_GARDEN` and removed driver reads of global `MODD_FORC_ATM` arrays.

| Group | Fields | Source |
| --- | --- | --- |
| Raw | `XU`, `XV`, `XTA`, `XQA`, `XPS`, `XZS`, `XRAIN`, `XSNOW`, `XLW`, `XDIR_SW`, `XSCA_SW`, `XZREF`, `XUREF`, `XCO2` | `teb_interface` arguments, `KSTART:KEND` window |
| Derived | `XPA`, `XEXNS`, `XEXNA`, `XRHOA`, `XVMOD`, `XTSUN`, `XZENITH`, `XAZIM` | `TEB_FILL_FORCING` |

* `XDIR_SW`/`XSCA_SW` are **after** horizon correction (`ZCOEF`) and circumsolar partitioning (`CIRCUMSOLAR_RAD`): physics inputs, not raw host `swdir_s`/`swdifd_s`.
* `XQA` is **specific** humidity in kg/kg (host `qv`, physics `PQA`), distinct from offline-reader `MODD_FORC_ATM%XQA` in kg/m³.
* Offline does not set `XZS` (`XUNDEF`): fallback pressure `101325·(1−0.0065·XZS/288.15)^5.31` retains historical behavior.
* The host does not set `XCO2`; it remains zero.
* Formulas, operation order and `XUNDEF` substitutions are copied verbatim from the previous `CALL_DRIVER` block, including computing forcing density/pressure before substituting fallback pressure.

**Offline heights `XZREF`/`XUREF`.** `OL_TIME_INTERP_ATM` computes atmospheric density using `MODD_FORC_ATM`'s `XZREF`; offline converts absolute humidity with it (`qv = XQA/XRHOA`, `rho = XRHOA`). The shared offline host therefore sets both heights from `hlev_teb` immediately after `OL_ALLOC_ATM`, before the first interpolation. Shared `CALL_DRIVER` does not use `MODD_FORC_ATM` or `MODI_OL_*`; physics receives heights through `FORC`. For CSV, original cell index is passed separately as `KHOST_CELL`, with data read from work position 1. Output cadence uses the zero-based model-step number shared by all blocks; empty filter lists create no CSV.


---

### 5.11 `EXT` — external surfaces (`TEB_EXT_SURF_t`, 18 work)

The **layer** (`TEB_FILL_EXT`) fills this container; only physics reads it. It replaced 18 separate arguments carrying external garden/greenroof state and fluxes from `teb_interface` to `TEB_GARDEN` (`EXT`/`EXT_NEU` interface).

| Group | Fields | Source |
| --- | --- | --- |
| Greenroof | `XZ0_GR`, `XALB_GR`, `XEMIS_GR`, `XTSRAD_GR`, `XQV_GR`, `XH_GR`, `XLE_GR`, `XEVAP_GR`, `XRUNOFF_GR` | `teb_z0_gr` … `teb_runoff_gr` |
| Garden | `XZ0_GD`, `XALB_GD`, `XEMIS_GD`, `XTSRAD_GD`, `XQV_GD`, `XH_GD`, `XLE_GD`, `XEVAP_GD`, `XRUNOFF_GD` | `teb_z0_gd` … `teb_runoff_gd` |

* Direction is **host → TEB**: an external garden/roof model computes these quantities (`PCD_GARDEN`/`PCD_GREENROOF` offline emulators), and TEB inserts them into the town budget. Garden `CH`/`CD` travel the other way (TEB → host) and remain flat `ZCH_GD`/`ZCD_GD` dummies (`PCH_GD`/`PCD_GD` in `TEB_GARDEN`).
* `XTSRAD_*` is surface radiative temperature (host `teb_ts_*`), `XQV_*` surface specific humidity (host `teb_qs_*`).
* The host supplies both runoff values (`XRUNOFF_GR`/`XRUNOFF_GD`) accumulated over the step in kg/m². `TEB_FILL_EXT` divides by `PDT`, the same `/dt` previously applied in `CALL_DRIVER`, so the container holds rates in kg/m²/s.


---

## 6. Call-chain signatures

| Procedure | File | Arguments |
| --- | --- | --- |
| `teb_interface` | `src_api/sfc_teb.F90` | **212** (158 required + 44 OPTIONAL OUT + 9 OPTIONAL IN + 1 OPTIONAL INOUT), including `teb_inv_l_town_prev` for `ZIL2008` |
| `CALL_DRIVER` | `src_driver/call_driver.F90` | **28** dummy = 14 transient + 2 host-export + 1 host-state + 11 container |
| `TEB_GARDEN` | `src_teb/teb_garden.F90` | **29** = 2 indices + 11 containers + 5 flags/strings + 4 coupling coefficients + 1 `KSW` + 2 (`PH_TRAFFIC`, `PTSTEP`) + 2 (`KDAY`, `PTIME`) + 2 conductances (`PCH_GD`, `PCD_GD`) |

`CALL_DRIVER` belongs to `MODI_CALL_DRIVER`, with signatures checked by the compiler on every call. Its eleven container dummies are `DMT, TOPTS, TPARAMS, BOPTS, BPARAMS, TSTATE, BSTATE, TPN, TIR, FORC, EXT`. The 14 transient arguments are time, cell indices, coordinates and urban fraction; two host exports are garden conductances `ZCH_GD` (OUT) and `ZCD_GD` (INOUT: previous host CD and new result). `PINV_L_TOWN_PREV` passes active-column `1/L` history.

Five `TEB_GARDEN` flags/strings (`OGREENROOF_EXT`, `HIMPLICIT_WIND`, `PBEM_AC`, `HSNOW_ROOF`, `HSNOW_ROAD`) are call options/parameters not moved into containers; `CALL_DRIVER` passes them as actual arguments. `KSW` (spectral-band count) remains an argument, bounding the loop over the single `PDIR_SW`/`PSCA_SW` band.

---

## 7. Rules and checks

| Bench | Check |
| --- | --- |
| `python_tests/check_diag_container.py` | Four matching lists (`DMT`, `NULLIFY`, `ALLOCATE`, `DEALLOCATE`) of 246 fields, including `TEB_CBS_BRANCH_t` components for both instances (`CAN`, `ATM`) |
| `python_tests/check_diag_producers.py` | Producer for each flat/two-level `DMT` field (`CAN%…`/`ATM%…`): direct assignment or `INTENT(OUT/INOUT)` dummy (legacy `!OUT`); `= XUNDEF` is not a producer; `XIRRIG_GARDEN` is `reserved` |
| `python_tests/container_fields_inventory.py` | Categories for ten types (`param`/`flux`/`state`/`work`/`reserved`/`dead`), including `FORC` (22 `work`) and `EXT` (18 `work`), with bidirectional contract checking: undeclared field → `UNCLASSIFIED`, declared but unreferenced → `dead`, removed from code → `STALE TABLE`; `--strict` treats `dead` as an error; `--enforce-param` allows only the driver or `TEB_HOST` layer to write `param`/`flux`. Field counts: 33/11/43/5/19/40/5/19/22/18 |
| `python_tests/call_signature_inventory.py` | `CALL_DRIVER` signature classes `transient`/`container`/`host-export`/`host-state`/`deferred`/`violation` (`--strict --expect 28`) |
| `python_tests/container_ab_compare.py` | Two binaries on `tests/CAPITOUL`: bitwise field-by-field CSV comparison, header, row count and SHA-256 |
| `python_tests/container_ab_matrix.py` | Same across configurations; `--set`: `base` — 13 namelist configurations (BEM, garden/roof modes, panels, CBS); `ext` — 13 container-coverage configurations (3/50 m forcing heights, roof `EXT_NEU`, both external surfaces, CBS at `urb_h_bld` 10/40 and `urb_h2w` 0.1/0.3/0.5/0.75, external garden + CBS); `opt` — 3; `all` — 29. Physics compared by column name, `RUNOFF_*` and `EMU_*` against separate candidate files; summaries `summary_matrix.csv` / `summary_matrix_<set>.csv` |
| `python_tests/bem_option_sensitivity.py` | BEM option sensitivity and A/B: two namelists (off/on), four runs (ref/new x off/on) per option. Checks both bitwise candidate/reference equality for the same namelist and a material off/on response in observed columns (`max_rel > 1e-6`, excluding 1 ulp artifacts). Options: shading (`teb_lshade`), air conditioning (`teb_lbem_ac`), ventilation (`teb_itype_natvent` = `AUTO`, `MECH`); summary `bem_sensitivity/summary_bem_sensitivity.csv` |

```powershell
python python_tests/check_diag_container.py
python python_tests/check_diag_producers.py
python python_tests/container_fields_inventory.py
python python_tests/call_signature_inventory.py
python python_tests/container_ab_compare.py --ref-exe build/TEB_offline_dev_ref.exe `
    --new-exe build/TEB_offline_dev.exe
python python_tests/container_ab_matrix.py                  # --set base (default)
python python_tests/container_ab_matrix.py --set ext        # container coverage
python python_tests/container_ab_matrix.py --set all        # base + ext + opt
python python_tests/bem_option_sensitivity.py      # BEM options: A/B + sensitivity
```

**Why `ext` is needed.** The base matrix varies only the namelist on one geometry and forcing: `hlev_teb = 28`, `urb_h_bld = 20`, `urb_h2w = 1.38158`. The latter gives `τ = 0.5·(1 + tanh((H/W − 0.5)/0.25)) = 0.999`: both `baseline` and `cbs_on` are at the canyon end of relaxation, leaving the transition and `τ ≈ 0` untested. `ext` adds:

* Forcing heights 3 and 50 m: `ZREF·G` in `XRHOA`/`XPA`/`XEXNA`, the `DMT%XWIND_TOP` profile, neutral emulator coefficients and the `XZREF`/`XUREF` bridge, including both external surfaces.
* Greenroof `EXT_NEU` and `combined_ext`: both external surfaces in one step, together with panels and CBS (base `combined` uses internal proxies).
* `urb_h2w` = 0.1 / 0.3 / 0.5 / 0.75 (`τ` = 0.04 / 0.17 / 0.50 / 0.88) and `urb_h_bld` = 10 / 40 m; `urb_z0_town='0.1H'` and `urb_zd_town='H/3'` scale with height to keep aerodynamics consistent.

**BEM options.** `bem_option_sensitivity.py` checks that options are active: a pair of off/on namelists, four runs, A/B identity for each, and material response (`max_rel > 1e-6`). Measured over 18 000 steps: shading up to 28.97 on 13 842 rows; air conditioning up to 54.02 on 13 848; `AUTO`/`MECH` ventilation up to 11.48/19.74. All four are `IDENTICAL` and material.

Reference case: `tests/CAPITOUL` (18 000 steps), with 130 columns in `TEB_output_b1_c1.csv` and 26 emulator columns in `TEB_emu.csv`. Acceptance: **bitwise CSV equality** (identical SHA-256) and `RESULT: OK` from every bench.

---

## 8. Changes over the last three days

Before these changes, the chain ended in `TEB_GARDEN_STRUCT`, which assembled flat arguments into containers and copied fields back to output dummies after `TEB_GARDEN`. Three days of deduplication removed the wrapper entirely:

| Step | Result |
| --- | --- |
| P-C4 / Step 1 | Panel/irrigation inputs moved to `TEB_FILL_PARAMS` |
| P-C2b / P-C3 / Step 2a-2b | State accessed through `TSTATE`/`BSTATE` (`TEB_BIND_STATE`/`TEB_UNBIND_STATE`) |
| Step 2c | Garden/roof diagnostics, exchange and town aggregates moved to `DMT` |
| Step E | ~33 wrapper-internal arguments became locals |
| Step E2 | Wrapper copy-out arguments (29 flux + 47 absorption/BEM-HVAC + 15 state/parameter) moved to `DMT`/`BSTATE`/`BPARAMS` |
| Step F | Snow branch (`PHSN_RD_*`, `PLESN_RD_*`) moved to `DMT`; `HSNOW_*` to `T%TSNOW_*%SCHEME`; `XUNDEF` initialization to `TEB_GARDEN` |
| Step G | `CALL_DRIVER` calls `TEB_GARDEN` directly; `TEB_GARDEN_STRUCT` and `modi_teb_garden_struct.f90` removed; `Makefile` cleaned |

Final counts: `TEB_GARDEN_STRUCT` had 411 → 326 → 304 → 83 → 68 arguments and was then removed; `TEB_GARDEN` has **29** (formerly 46/65); `CALL_DRIVER` **27** dummy arguments (formerly 44/57; 11 containers); `teb_interface` had **154** at the deduplication stage (current signature in §6). `DMT` grew to **208** fields, then **205** after removal of unproduced `XSOBS`/`XTHBS`/`XALB_TH` (see [N3 fix](https://github.com/mkolennikova/TEB-MSU/commit/d0c92f2f253e0d901f4473eb55f42f0df954f25e)), and **207** after CBS branches were consolidated into `TEB_CBS_BRANCH_t`. All deduplication is bitwise identical to reference: full A/B (18 000 steps) `IDENTICAL`, CSV SHA-256 `30499e1f…`.

| Step | Result |
| --- | --- |
| Step H1 | Substep forcing moved to `FORC` (`TEB_FORCING_t`, 22 fields): `TEB_FILL_FORCING` in `TEB_HOST`, `CALL_DRIVER` 57 → 44 (19 flat dummies → `FORC`) |
| Step H2 | `TEB_GARDEN` receives `FORC` (65 → 46); dead `PSW_BANDS` removed |
| Step H3 | `teb_log` reads `FORC%XPS`/`XZENITH`/`XAZIM`; `MODD_FORC_ATM` stays host-only (`XZREF`/`XUREF` bridge) |
| Step H4 | External garden/roof inputs moved to `EXT` (`TEB_EXT_SURF_t`, 18 fields): `TEB_FILL_EXT` in `TEB_HOST`, `CALL_DRIVER` 44 → 27, `TEB_GARDEN` 46 → 29; `CH`/`CD` remain flat (TEB → host) |
