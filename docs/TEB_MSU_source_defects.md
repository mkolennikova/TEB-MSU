# Defects of the original TEB found and fixed in TEB-MSU

This document records **defects of the original model** (TEB/TEB-MSU before our
changes) discovered while developing CBS and the diagnostic garden scheme:
what was wrong, its consequences, the fix and verification. D1–D10 were
inherited from the original TEB, including upstream `TEB-model/teb`, branch
`master`, as of 2022. Rechecking D8 exposed a separate defect in the snow
correction inherited from coupled COSMO–TEB.

Driver, forcing-reader and bench defects (I1–I4), numerical defects of our own
changes (N1), and identified but unresolved issues outside the original model
(C2, C3, C5) are outside this document; see §5.5–§5.7 of the
[archived history](https://github.com/mkolennikova/TEB-MSU/blob/12c3fbf52092e84431f9dfbabef3e76741a0ac8d/docs/TEB_MSU_change_history.md).
Historical record numbers №N here refer to that archived registry.
Inherited diagnostics deliberately left unfixed are listed in §3.

For control comparisons, `src_dev` can be built with
`-DTEB_UPSTREAM_CONS_BUGS`: this reproduces D1–D5 and D10 while retaining the
tree's other schemes and interfaces. D6 is excluded because its result depends
on uninitialized memory. D7 is fixed in ordinary builds of both trees;
previous `src_ctrl` formulas are available under `-DTEB_UPSTREAM_CONS`, together
with other modes for comparison with official TEB 4.0.0. Use separate object
directories for different `CPPDEFS` sets.

Current schemes are described in `schemes/TEB_MSU_CBS_scheme_T_CAN_reformulation.md`
and `schemes/TEB_MSU_garden_diagnostic_scheme.md`; commit references for fixes
are in `TEB_MSU_change_history.md`.

> Initial audit snapshot: commit `91308a7` (2026-09-22), branch `MV_devs`.
> Additions to that snapshot are described under D5, D7, D8 and D10.

---

## 1. Defect registry

| ID | Defect | Location | Consequence | Fix | Commit |
| --- | --- | --- | --- | --- | --- |
| D1 | Snow sensible heat in the canyon-air node is normalized by road rather than ground area | `src/src_teb/avg_urban_fluxes.F90` | At `ZRD < 1`, snow contribution is too large by `1/ZRD` | Multiply by `ZRD` | `9da2ff7` (№9) |
| D2 | Snow latent heat in the canyon-humidity node was divided by `XLVTT` instead of `XLSTT` | `avg_urban_fluxes.F90` | Vapor flux overestimated by 13.3 % | `XLSTT`; free-layer conversion through `ZLE_CAN1_SN` | `ff7718e` (№10) |
| D3 | Duplicate `PDF_RD` weight (squared snow-free fraction) in road fluxes and puddle drainage | `urban_fluxes.F90`, `avg_urban_fluxes.F90`, `teb.F90` | Winter `H/LE ↔ GFLUX` partition distorted; water-budget residual +0.17…+0.19 kg/m²/month | Remove extra `PDF_RD`; drain puddle with `PLEW_RD` | `edeeb5d` (№14) |
| D4 | Snow sublimation counted twice in `URBAN_HYDRO`; drainage uses `XLVTT` instead of `XLSTT` | `teb.F90`, `urban_hydro.F90` | Puddle/roof budget −0.5…−0.25 kg/m²/month | Liquid-only drainage; snow accounted for in `WSNOW_RD` | `604eb6c` (№13) |
| D5 | Meltwater entered without snow-fraction weight, excess was discarded, and roof puddle drained by full `XLE_ROOF`. Complete road-snow disappearance still lost water after №15 | `teb.F90`, `urban_snow_evol.F90`, `urban_fluxes.F90` | Initial residual −75.4 (road), −66.8 (roof) kg/m² over 91 days. Residual loss in a separate LCZ4 winter run: 8.72 g/m² of road | Snow-fraction weight, taken before road melting; excess to runoff; `LE_ROOF_WAT` | `1edd967` (№15), `src_dev` addition — `07b41ee` (№91) |
| D6 | `XH_WASTE`/`XLE_WASTE` uninitialized with BEM off | `src/src_teb/teb.F90` | Garbage CSV values up to 1e18…1e21, `XUNDEF` in 6–17 % of hours; physics unaffected | Zero in `CASE("DEF")` | `9dc5ae2` (№11) |
| D7 | Different displacement heights in the wind profile and TEB aerodynamics; separately valid `zd` and `z0` could yield `H−zd ≤ z0` | `urban_drag.F90`, `call_driver.F90`, `teb_host.F90` | Inconsistent exchange calculation and risk of unphysical roof-level wind | Shared `H−zd` in both trees, Macdonald (1998) in `src_dev`, joint `H−zd > z0` validation; old `src_ctrl` formulas under `TEB_UPSTREAM_CONS` | `788ea00` (№1), addition in both trees — `07b41ee` (№91) |
| D8 | Uninitialized radiation properties of disabled garden/greenroof; longwave and shortwave arithmetic with `XUNDEF` for absent surfaces | `teb_garden.F90`, `urban_solar_abs.F90`, `urban_lw_coef.F90` | `NaN` and radiation-budget failures, single-precision overflow | Initialize properties and check surface activity before calculation; zero contributions from absent surfaces | Initial `MV_devs` fix, `src_ctrl` port, `07b41ee` addition (№91), and snow shortwave protection in both trees (№92) |
| D9 | `ZTS_GROUND` (ground = road + garden) used in canyon momentum budget although its computation, and the road term it replaced, were commented out | `src_teb/urban_drag.F90` | Stack garbage in `ZQ0` → `ZW_STAR`: `NaN`/`SIGFPE`/`SIGSEGV` after a few steps | Stop reading `ZTS_GROUND`; use weighted road contribution guarded by `XROAD>0` | `MV_devs` before the split; ported to `src_ctrl` |
| D10 | Incorrect snow-flux weights/sign in `PIMB_ROAD`, missing rain/irrigation heat, lost implicit correction in `PLEW_RD` | `road_layer_e_budget.F90`, `teb.F90` | Incorrect energy-budget diagnostic and mismatch between solver evaporation and puddle water loss | Correct weights/sign, include rain/irrigation heat, use solver linearization for liquid flux | №28, `src_dev` addition — `07b41ee` (№91) |

Defects outside the original model (driver, forcing reader, benches and our own
changes), and identified but unresolved issues, are in §5.5–§5.7 of the
[archived history](https://github.com/mkolennikova/TEB-MSU/blob/12c3fbf52092e84431f9dfbabef3e76741a0ac8d/docs/TEB_MSU_change_history.md);
inherited diagnostics deliberately left unfixed are in §3.

---

## 2. Inherited physics defects (D1–D10)

### D1. Canyon-node snow sensible-heat normalization (№9)

**Issue.** The canyon-air node combines terms as fluxes **per ground area**:
`ZRD` weights the road, road water, garden, walls/windows, traffic, waste heat
and `PAC_TOP`. Road-snow sensible heat instead entered per road area
(`PHSN_RD_CAN·PDN_RD`), whereas its latent counterpart in the humidity node
already carried `ZRD`.

**Consequence.** With a garden (`ZRD < 1`), the snow contribution was too large
by `1/ZRD`. This asymmetry within one node makes it a defect rather than a
normalization convention.

**Fix.** One multiplier:

```fortran
+ ZRD(JJ) * PHSN_RD_CAN(JJ) * PDN_RD(JJ) / PRHOA(JJ) / XCPD
```

At `ZRD = 1` (all archived benches, with garden off), this is a strict no-op,
so summer regression is bit-for-bit.

**Verification.** Direct A/B in the garden + snow experiment (LCZ2,
`ZRD = 0.5556`, `PDN_RD = 0.3…0.7`): `T_CAN` +1.11e-3 K, `T_WALL` +1.01e-3 K,
`T_ROAD1` +5.4e-4 K, `H_TOWN` −6.9e-3 W/m², `RN_TOWN` −1.4e-3,
`GFLUX_TOWN` +1.6e-3. An independent analytical node-shift estimate
`(ZRD−1)·Q_snow/(ρ·cp·ZINTER)` gave mean +1.06e-3 K, range [−6.8e-3, +5.1e-3] K,
agreeing with A/B. Road snow occurred in 7.8 % of hours; mean sensible snow
flux `PHSN_RD_CAN·PDN_RD` was −0.71 W/m² (up to ±3.7).

### D2. Sublimation latent heat in the canyon-humidity node (№10)

**Issue.** Snow latent heat is computed using `XLSTT = 2.8345e6` J/kg
(sublimation from ice). The snow scheme, town evaporation (`PEVAP_TWN`) and
snow-mass budget convert it with `XLSTT`; liquid evaporation from puddles,
walls, traffic and waste heat uses `XLVTT = 2.5008e6` J/kg. Two locations used
`XLVTT` for snow: the inherited canyon-humidity term and the free-layer
construction added with the τ revision (snow entered a sum divided by `XLVTT`).
The ratio is `XLSTT/XLVTT = 1.1334`.

**Consequence.** Vapor flux was overestimated by 13.3 % in the canyon-humidity
node and layer. The humidity effect is small (≤ 0.1 % of `q`), but this is a
systematic phase-change error.

**Fix.** Use `XLSTT` in the canyon node; isolate the free-layer snow term and
convert to its `XLVTT` equivalent **before** the layer formula's single division:

```fortran
ZLE_CAN1_SN = ZRD * PLESN_RD_ATM * PDN_RD * XLVTT / XLSTT
PQ_CAN1 = PQA + ( ZLE_CAN1 + ZLE_CAN1_SN ) / ( PRHOA * XLVTT * XKARMAN * ZU_ROAD_ATM ) * ZPHI_CAN1
```

Operation order is preserved, giving bit-for-bit results at `PDN_RD = 0`.

**Verification.** All 12 summer cases are bit-for-bit; winter cases change only
humidity and its slow feedback: mean `Q_CANYON` −7e-8 kg/kg (maximum 1.0e-6),
mean `T_CAN0` +1.5e-6 K, `LE_ROAD_CAN/ATM` ≤ 6e-3 W/m², `WSNOW_RD` ≤ 1.5e-5 kg/m².
Town energy balance is preserved (closure 30.6176 versus 30.6176).

### D3. Duplicate `PDF_RD` weight in road fluxes and puddle drainage (№14)

**Issue.** The road energy budget uses a tile-mean formulation:
`ZDF_ROAD = 1−PDN_ROAD` is included **inside** conductances
(`ZRHO_ACF_R_WAT = ρ·PAC_ROAD_WAT·ZDF_ROAD`), so `XH_ROAD`/`PLEW_RD` already
represent fluxes **per m² of road**. Consumers multiplied them by `PDF_RD`
again, squaring the snow-free fraction. The inherited defect also occurs in
upstream `TEB-model/teb` master (2022).

**Diagnosis (measured, not inferred).** At `τ = 1` and `PDN_RD = 0.3…0.7`,
measured `LE_ROAD/LE_ROAD_CAN = 1.0000`; a per-snow-free-m² interpretation would
give `1/(1−PDN) ≈ 3.33`.

**Fix.** Remove extra `PDF_RD` factors from `DMT%XH_ROAD`/`DMT%XLE_ROAD`
(snow terms retain a single `PDN_RD`), from `PLEW_RD` in `PEVAP_TWN`, and in
`URBAN_HYDRO` (puddle drained by tile-mean liquid flux `PLEW_RD`). Diagnostics:

```fortran
DMT%XGFLUX_ROAD =  PDF_RD*XRN_ROAD - XH_ROAD - PLEW_RD + PDN_RD*PGSN_RD
LE_ROAD_WAT     =  PLEW_RD                    ! matches the column LE_ROAD
LE_ROAD_SNOW    =  PDN_RD * PLESN_RD
```

**Consequence and verification.** Duplicate weighting did not create a town
balance residual because the error entered both `H`/`LE` and `GFLUX` and
canceled. It distorted the `H/LE ↔ GFLUX` partition (by up to `1/(1−PDN)` in
snowy winter conditions) and, through `URBAN_HYDRO`, puddle state, `PDELT_ROAD`
and subsequently the top road layer. The water budget in hours without rain or
runoff now closes to 0.0000 kg/m²/month; the former duplicate drainage produced
+0.17…+0.19, systematically under-draining the puddle. Test T5 gives median
`LE_ROAD/LE_ROAD_CAN` = 1.05–1.13 versus `1/(1−PDN) = 3.33`. Winter changes reach
`GFLUX_TOWN` ≈ 35 W/m², `H_TOWN` ≈ 25, `LE_TOWN` ≈ 10, `WS_ROAD` ≈ 0.2 mm,
`T_ROAD1` ≈ 0.17 K (mean ~0.015 K). Summer is bit-for-bit.

### D4. Snow sublimation counted twice in the water budget (№13)

**Issue.** `URBAN_HYDRO` drained the reservoir using a flux that already included
snow sublimation/deposition accounted for by the snow scheme in `WSNOW_RD`,
and used `XLVTT` instead of `XLSTT`.

**Fix.** Drain the puddle only with liquid flux from the snow-free road; the snow
part is accounted for by the snow budget with `XLSTT`.

**Verification.** The combined puddle + snow budget closes within
0.03–0.04 kg/m²/month (previously −0.5…−0.25).

### D5. Meltwater routing (№15)

**Issue and consequence.** Three related melting-season errors produced residuals
of −75.4 kg/m² (road) and −66.8 kg/m² (roof) over 91 days of the Moscow melt period:

1. Meltwater entered reservoirs 1:1, although `URBAN_SNOW_EVOL` computes `PMELT_*`
   per m² of snow (at `PDN = 0.7`, +43 % overestimation — a false source in the
   tile-mean balance).
2. `MIN(ZWS_*_MAX, …)` silently discarded water exceeding puddle capacity instead
   of routing the excess to runoff.
3. The roof puddle drained with full `DMT%XLE_ROOF`, including transpiration,
   building waste heat and snow sublimation already accounted for by the snow
   scheme: water evaporated twice, with `XLVTT` instead of `XLSTT`.

In fix №15, meltwater was weighted by `PDN_RD`/`PDN_RF` and the preliminary
capacity cap was removed so that `URBAN_HYDRO` could put excess into runoff.
Roof drainage was replaced by `LE_ROOF_WAT = (1−PDN_RF)·PLEW_RF`.
Diagnostics `PDN_RF`, `LE_ROOF_WAT`, `LE_ROOF_SNOW`, `RUNOFF_ROAD` and
`RUNOFF_ROOF` were added. Runoff is averaged over all hourly substeps to check
the hourly water budget.

The initial check (Moscow, 2024-01-01…2024-03-31, LCZ2/LCZ9/SPARSE) left a
budget residual within +0.05 kg/m². Period runoff rose from ~18 to ~94 kg/m² for
the road and ~15 to ~88 kg/m² for the roof.

#### Water transfer when road snow disappears completely

After fix №15, the road reservoir still lost meltwater on the substep of complete
snow disappearance. Once snow storage is exhausted, `URBAN_SNOW_EVOL` zeros
`PDN_RD` although `PMELT_RD` for that substep may remain positive. Mass has
already been deducted from snow storage. Multiplication by final `PDN_RD`
removed it from both puddle inflow and the road term in `PMELT_BLT`. Before the
addition, loss occurred when `PDN_RD` was positive before the call, zero after
it, and `PMELT_RD > 0`.

In `src_dev`, `TEB` saves the pre-call fraction in `ZPDN_RD_BEFORE_SNOW` before
`URBAN_SNOW_EVOL`. Afterwards,
`ZMELT_RD_TILE = ZPDN_RD_BEFORE_SNOW × PMELT_RD` gives the rate in kg/(m² road·s).
The puddle receives `ZMELT_RD_TILE × PTSTEP`, and `URBAN_HYDRO` sends excess to
runoff. `URBAN_FLUXES` uses the same rate in `PMELT_BLT`, weighted by road area.
Final `PDN_RD` describes snow cover after the substep.

The recheck compared two `src_dev` builds on identical hourly Moscow ERA5
forcing (55.75° N, 37.50° E, December 2023–April 2024, LCZ4, 300 s substeps).
The standard converter separated rain and snow using 2 m air temperature.
Among 43 776 substeps, the loss condition occurred twice, on 31 March and 6 April.
The pre-addition build lost 8.72 g/m² of road in total. The fixed build transferred
all that mass to the puddle within rounding precision. Seasonal road runoff
increased by 7.44 g/m².

Substep logs verified puddle inflow, runoff and `PMELT_BLT`. The first 2920 hourly
rows before the first event were byte-identical. A build without diagnostic
logging reproduced the fixed full-season hourly output byte for byte.
External source of the numbers: `D:\TEB_work\Moscow_D5_2023-24`
(`D5_summary.json`, `D5_events.csv`).

### D6. Uninitialized waste-heat diagnostics with BEM off (№11)

**Issue.** `DMT%XH_WASTE`/`DMT%XLE_WASTE` are filled only by BEM. With
`teb_itype_bem = 'DEF'` (simple `BLD_E_BUDGET`, without HVAC), they retained
values left by `ALLOCATE`.

**Consequence.** `TEB_output.csv` columns `H_WASTE`/`LE_WASTE` contained values up
to 1e18…1e21 and `XUNDEF` in 6–17 % of hours, making BEM-off configurations
unusable for town closure checks. **Physics was unaffected:** all computational
uses are guarded by `IF (TOP%CBEM=="BEM")`, so `H_TOWN` with BEM off was already
correct. The defect also occurs in archived summer runs predating the τ revision.

**Fix.** Explicit zeroing in the `CASE("DEF")` branch of `TEB`:

```fortran
DMT%XH_WASTE (:) = 0.
DMT%XLE_WASTE(:) = 0.
```

**Verification.** Winter site, 12 `def` cases: the other 63 columns are
bit-for-bit, and `H_WASTE`/`LE_WASTE` are exactly zero (before the fix, `XUNDEF`
occurred in 44–113 of 744 hours). A BEM-on control run is bit-for-bit on 65 shared
columns with nonzero `H_WASTE = 95.3 W/m²`; the BEM branch is unchanged.

### D7. Inconsistent displacement height in official TEB (№1)

**Issue.** Official TEB has no displacement-height parameter: roughness `ZZ0`
is in meters, while displacement is hard-coded as `+ urb_h_bld/3.` in the
aerodynamic formulas. Its wind profile uses height above displacement `H − zd`:
`H − zd = 2/3·H` implies `zd = 1/3·H`, whereas substituting `+ H/3` corresponds
to `zd = 2/3·H`. Two locations in one model therefore use different displacement
heights.

In `src_dev`, the driver wind profile and TEB aerodynamics share `teb_ctype_zd_town`
and `teb_ctype_z0_town`. Both parameters can be computed from building densities
with Macdonald et al. (1998). Defaults `teb_ctype_z0_town = '0.1H'` and
`teb_ctype_zd_town = 'H/3'` reproduce the previous driver profile. With these values,
TEB adds `H−zd = 2H/3` to forcing height instead of the original `H/3`.

```
d/h  = 1 + A^(−λp)·(λp − 1)                                        eq. (23)
z0/h = (1 − d/h)·exp( −( 0.5·β·(Cd/κ²)·(1 − d/h)·λf )^(−0.5) )     eq. (22)
```

With `teb_itype_wind = 0`, canyon wind is computed from roof-level wind. With
`teb_itype_wind = 1`, Wang also uses town friction velocity, so changing exchange
coefficients can affect canyon wind. In ordinary `src_ctrl`, both formulas use
shared height above displacement `H−XZD_TOWN`: in the logarithmic wind profile
and `URBAN_EXCH_COEF` reference heights. `TEB_UPSTREAM_CONS` restores the tree's
previous formulas: hard-coded `2H/3` wind profile and `+XZD_TOWN` aerodynamic
correction (`+H/3` by default). Original TEB hard-coded its displacement
height, so the exact original scenario requires the default rule `'H/3'`.
Named Macdonald schemes are available in `src_dev`.

#### Joint validation of `z0` and `zd`

Separate `z0` and `zd` limits allowed combinations with `H−zd ≤ z0`. At equality,
the `src_dev` profile gives zero roof-level wind despite nonzero forcing wind;
at `H−zd < z0`, the result can be negative. With positive above-roof forcing
height, `H−zd > z0` ensures positive logarithms in the profile numerator and
denominator.

After deriving both parameters, `src_dev` checks this in `TEB_FILL_DERIVED` and
`src_ctrl` in `CALL_DRIVER`. Both require `H−zd−z0 > SPACING(H)`, where
`SPACING(H)` provides a rounding tolerance at building-height scale. Violations
report `H`, `zd`, `z0` and the `H−z0` limit for `zd`; startup exits with code 1.

In 12 checks, both builds accepted defaults and `(H−zd)/z0 = 1.5`. Both rejected
equality, an exceeded limit and a positive difference within rounding tolerance.
In `src_dev`, a test pair computed entirely with Macdonald passed. In that same
configuration, the combination of `'0.2H'` for z0 and `'MACDONALD1998'` for
zd was rejected. See the external results in `D:\TEB_work\D7_joint_check\D7_summary.json`.

### D8. Uninitialized albedo/emissivity/radiative temperature of green surfaces

In original `TEB_GARDEN`, garden albedo, emissivity and radiative temperature
(`ZALB_GD`, `ZEMIS_GD`, `ZTSRAD_GD`) and greenroof properties (`ZALB_GR`,
`ZEMIS_GR`, `ZTSRAD_GR`) were assigned inside enabled-scheme branches. Radiation
could read disabled-surface values, e.g. `1.-PALB_GRF` in `URBAN_SOLAR_ABS`.
This caused `NaN` in canyon/building columns or `SIGFPE` and `SIGSEGV` failures.
In the original build with `-finit-real=snan`, `-fcheck=all` and
`-ffpe-trap=invalid,zero`, the trap fired at `urban_solar_abs.F90:352` called
from `TEB_GARDEN`. The first fix initialized all six arrays to `XUNDEF` before
the branches, allowing this location to pass.

#### Protecting calculations from `XUNDEF`

Rechecking showed that `XUNDEF` could enter arithmetic before accounting for
zero surface fraction. Full-length temperature arrays for a disabled garden
were passed to `URBAN_LW_COEF`, so `SIZE(PTS_G)>0` allowed calculation. Without
road snow, a repeated unconditional `PLW_S_TO_NR` assignment overwrote zero.
In the checked build, `XUNDEF = 10²⁰`; cubing a mean temperature with this value
gives order `10⁵⁹`, beyond `REAL(4)` limits.

In `src_dev` and `src_ctrl`, disabled gardens pass empty temperature and
emissivity arrays, and all garden longwave coefficients in that branch are zero.
The repeated `PLW_S_TO_NR` assignment was removed, so sky-to-road-snow exchange
is zero without snow. `URBAN_SOLAR_ABS` uses garden and greenroof albedo only
when the scheme is active. `XUNDEF` still marks missing diagnostics.

* On Moscow ERA5 forcing for December 2023–April 2024 with `teb_snow_check` off,
  all eight before/after run pairs produced byte-identical CSVs. Four garden/
  greenroof on/off combinations were checked in each tree.
  External summary: `D:\TEB_work\D8_radiation\D8_double_summary.json`.
* In a separate `URBAN_LW_COEF` test using `REAL(4)` with
  `invalid,zero,overflow` traps, original builds failed without garden or road
  snow. After the fix all combinations passed, coefficients for absent surfaces
  were zero, and garden/snow-present results were bit-identical.
  External summary: `D:\TEB_work\D8_radiation\D8_real32_summary.json`.

#### Failure in COSMO–TEB snow-correction mode

A run with `teb_snow_check = .TRUE.` exposed a separate defect. The inherited
correction zeroed existing snow fraction and reset its radiative properties to
`XUNDEF` while retaining mass at the snow-solver input. After D8 protection,
`LOG(T)` still failed because an erroneous shortwave flux produced negative
temperature. In both trees, the threshold was moved to new-snowfall detection
and the snow solver runs on the computed snow fraction. The fix is in
[`07b41ee`](https://github.com/mkolennikova/TEB-MSU/commit/07b41ee354e5b5598de2b6dfb4f94cab37d61d73).
[Filtering conditions](schemes/TEB_MSU_snow_check.md#2-behavior-after-the-fix),
[filter checks](schemes/TEB_MSU_snow_check.md#41-trace-snowfall-filter)

#### Shortwave protection for snow

Even after fixing the filter, snow terms in `URBAN_SOLAR_ABS` could use albedo
`XUNDEF` at zero snow fraction. In both trees, road and roof snow contributions
are evaluated only for positive fractions. At zero fraction, snow shortwave
contributions are zero. With positive fraction and albedo `XUNDEF`, the procedure
reports surface and point index and terminates before arithmetic with that
value. Protection applies to both values of `teb_snow_check`.
[Shortwave calculation](schemes/TEB_MSU_snow_check.md#32-shortwave-radiation),
[protection checks](schemes/TEB_MSU_snow_check.md#42-protection-and-town-snow-diagnostics)

Town-diagnostic protection from `XUNDEF` after melting belongs to `CALL_DRIVER`
and is described in [commit `f7857c2`](https://github.com/mkolennikova/TEB-MSU/commit/f7857c2bac2e16a6f954974bff17d7bd423603c9).
Snow-covered-area normalization and removal of repeated storage weighting are
in [commit `878c93f`](https://github.com/mkolennikova/TEB-MSU/commit/878c93fa85b1dac2e09e59003308b97e2e5071cc).

### D9. `ZTS_GROUND` in the canyon momentum budget

**Issue.** `URBAN_DRAG` uses `ZTS_GROUND` (ground surface temperature = road +
garden) in `ZQ0`, which determines `ZW_STAR`, the convective canyon-wind
increment. Its calculation in the base code was commented out, as was the road
term it replaced (unfinished ground refactoring). The array was read
uninitialized: stack garbage in momentum budget → `NaN`/`SIGFPE`/`SIGSEGV`
after a few steps.

**Fix.** Uninitialized `ZTS_GROUND` is no longer used. Current `ZQ0` contains
wall and road contributions, the latter using road temperature, canyon
conductance and weight `XROAD/(XROAD+XGARDEN)`. At `XROAD=0`, the road term is not
evaluated; no division by a zero fraction sum occurs. The formula is in §4.1 of
the [CBS description](schemes/TEB_MSU_CBS_scheme_T_CAN_reformulation.md#41-road-budget-effective-conductance-and-reference-air).
The initial uninitialized-memory fix restored mixed road/garden temperature;
its replacement with the road term in both trees is described in
[commit `ed53432`](https://github.com/mkolennikova/TEB-MSU/commit/ed534320f2c9109619e6712b537db9c434ac61b5).

**Verification of the initial fix.** In the same `-finit-real=snan` build, the
trap moved to `urban_drag.F90:535` after D8 and disappeared after D9. The full
`src_ctrl` run (18 000 CSV rows, 17 999 steps) completes **with
`-ffpe-trap=invalid,zero` enabled**, without `NaN`/`Inf` or `SIGFPE`.

**Note.** Both defects were found when the repository was split into `src_dev`
and `src_ctrl`: D8/D9 were fixed on `MV_devs` and present in `src_dev`, but
`src_ctrl` (first-commit physics) lacked them and produced `NaN`/`SIGFPE` on the
shared namelist. Exactly the dev implementation was ported to `src_ctrl`.

**The pre-split `main` snapshot contained both defects.** Byte comparison (see §0
of the [archived history](https://github.com/mkolennikova/TEB-MSU/blob/12c3fbf52092e84431f9dfbabef3e76741a0ac8d/docs/TEB_MSU_change_history.md))
showed that `src_teb/teb_garden.F90` and `src_teb/urban_drag.F90` on `main` matched
the initial commit, and the `main` namelist selected the degenerate configuration
(`teb_lgarden=.FALSE.`, `fr_garden=0.0`, `teb_lgreenroof=.FALSE.`, `teb_frac_gr=0.0`).
Thus comparison of `src_ctrl` with `main` on the shared namelist is meaningful
only after porting D8/D9 to `main`; before that, `main` reads uninitialized
memory in canyon radiation and momentum budgets, potentially producing `NaN`.

### D10. Road energy residual and liquid flux (№28)

`PIMB_ROAD` is the road-column energy residual in W/m² of total road area. The
original formula multiplied `PHFREE_ROAD` and `PLEFREE_ROAD` by snow-free
`ZDF_ROAD` again, although conductances already include it. Radiation lacked
this weight and snow conduction `ZDN_ROAD·PGSNOW_ROAD` was subtracted. Fix №28
moved the weight to radiation and made snow conduction an input. In winter LCZ2
(Moscow, 8916 steps, 84 % with snow), maximum absolute residual fell from 37.5
to 0.15 W/m² and mean residual from +3.97 to −0.0005 W/m². In summer, 109 shared
CSV columns were byte-identical.

#### Rain and irrigation heat

The road solver accounted for heat exchange with rain and irrigation water,
but `PIMB_ROAD` omitted it. In `ROAD_LAYER_E_BUDGET`, `PRR` is rain plus
irrigation, and `T_ref` below is reference air temperature `ZT_REF` passed from
`TEB`. Positive `ZHEAT_RR` means heat transfer from road to water. With this sign,
the final `src_dev` formula is

```fortran
ZHEAT_RR = PRR * XCL * (T_eff - T_ref)
PIMB_ROAD = ZDF_ROAD * (PABS_SW_ROAD + PABS_LW_ROAD - ZHEAT_RR) - PDQS_ROAD &
          - (PHFREE_ROAD + PLEFREE_ROAD) + ZDN_ROAD * PGSNOW_ROAD
```

#### Matching evaporation to the solver

The solver linearizes saturation humidity about surface temperature at substep
start. Previously, before evaluating `PLEFREE_ROAD`, the old temperature was
overwritten by budget temperature, equal to the new temperature at `ZIMPL = 1`.
The temperature difference in the correction vanished. This flux is used as
`PLEW_RD` for puddle water loss, so the error affected water storage and
subsequent fluxes.

Now `ZTS_ROAD` stores substep-start `T_old`, and `ZTS_ROAD_EFF` stores the budget
temperature `T_eff = ZEXPL·T_old + ZIMPL·T_new`. Liquid flux uses
`PQSAT_ROAD_EFF = q_sat(T_old) + (dq_sat/dT)_old·ZIMPL·(T_new−T_old)`.
The same value is passed to both CBS branches and the lower-canyon humidity
node. `PIMB_ROAD` remains local diagnostic `ZIMB_RD` in `TEB`.

#### Recheck

Three `src_dev` builds were compared on identical Moscow ERA5 forcing for
December 2023–April 2024 (LCZ4, 300 s substeps, 43 776 substeps per run).
The irrigation variant included 509 substeps with nonzero irrigation and no rain.

| Mode | Maximum absolute `PIMB_ROAD` before the addition, W/m² | Rain/irrigation heat only, W/m² | Both fixes, W/m² |
| --- | ---: | ---: | ---: |
| Without CBS | 6.72 | 6.24 | 7.71×10⁻¹⁰ |
| With CBS (`τ ≈ 0.31`) | 6.88 | 6.76 | 7.41×10⁻¹⁰ |
| Without CBS, with irrigation | 29.99 | 29.99 | 6.52×10⁻¹⁰ |

Adding rain/irrigation heat only to the residual retained byte-identical standard
CSVs in all three modes. At the first wet substep with nonzero correction and
identical inputs, road temperature matched, while the `PLEW_RD` difference
matched the restored correction. Substep logs also verified CBS liquid-flux
weighting, puddle storage and runoff, including complete snow disappearance
under D5. A build without logging reproduced the fixed build's hourly output
byte for byte. External source of the numbers:
`D:\TEB_work\Moscow_D10_2023-24\D10_summary.json`.

---

## 3. Inherited diagnostics deliberately left unfixed

### `PIMB_ROOF` residual (roof)

**Issue.** The `PIMB_ROOF` formula (`roof_layer_e_budget.F90:339`) does not close:
winter and summer LCZ2 experiments give −5.1 W/m² even **without snow** on the
roof. Closure is restored by removing `+ PFLX_BLD_ROOF` (internal building
coupling is already in the solved system). Radiation also lacks `ZDF_ROOF`
weight in the residual.

**Consequence.** This diagnostic cannot verify roof-budget closure.
**Physics is unaffected:** `ZIMB_RF` is neither read nor written to CSV.

**Unfixed.** Deferred pending a separate analysis of BEM coupling (which roof
budget terms belong to the internal boundary) and choice of residual formulation.

---

## 4. How the fixes were verified

1. **Bit-for-bit regression.** Each fix was compared with its pre-fix build on
   full CSV output (all numeric columns, summer and winter) where a strict no-op
   is claimed, e.g. at `ZRD = 1` or `PDN_RD = 0`.
2. **Direct A/B.** Where no-op does not apply (garden + snow at `ZRD < 1`, winter,
   melting), effects were measured with two runs using one namelist.
3. **Budget closure.** Puddle/roof water budgets, snow budget and town energy
   balance must improve, not merely change.
4. **Analytical estimates.** For D1 and D3, independent formulas were compared
   with measured A/B effects, agreeing within 5 %.
5. **Invariant benches:** `python_tests/check_puddle_water.py` (T1–T5, water path),
   `python_tests/compare_garden_scheme.py` (B1–B6, garden schemes and closure),
   `python_tests/check_anthro_heat.py` (anthropogenic fluxes and τ invariance),
   `python_tests/compare_cbs_scheme.py` (τ-run and τ-limit comparisons).

---

## 5. References

* [TEB_MSU_change_history.md](TEB_MSU_change_history.md) gives concise commit
  references for fixes. Detailed protocols, defects and open issues outside the
  original model remain in §5.5–§5.7 of the [archived history](https://github.com/mkolennikova/TEB-MSU/blob/12c3fbf52092e84431f9dfbabef3e76741a0ac8d/docs/TEB_MSU_change_history.md).
* `schemes/TEB_MSU_CBS_scheme_T_CAN_reformulation.md` — current CBS description,
  including normalization and snow terms;
* `schemes/TEB_MSU_garden_diagnostic_scheme.md` — current garden description;
* [TEB_MSU_snow_check.md](schemes/TEB_MSU_snow_check.md) — COSMO–TEB snow-correction fix.
* Upstream TEB: `https://github.com/TEB-model/teb`.
