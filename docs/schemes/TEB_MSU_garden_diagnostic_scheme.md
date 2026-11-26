# Diagnostic garden proxy model in TEB-MSU

This document describes the **implemented** TEB-MSU diagnostic garden scheme:
its physical formulation, mathematics, code structure, parameters, diagnostics
and external modes (`EXT` / `EXT_NEU`).

Related documents:

* `TEB_MSU_CBS_scheme_T_CAN_reformulation.md` — road CBS scheme and the
  meaning of the canyon temperatures (`T_CAN0`, `T_CAN1`, `T_CAN`) to
  which the garden is coupled;
* `../TEB_MSU_source_defects.md` — defects of the original TEB found and
  fixed during development;
* `../TEB_MSU_containers.md` — the `DIAG_MISC_TEB_t` diagnostics
  container (garden and greenroof diagnostics are its fields);
* `../TEB_MSU_change_history.md` — concise change history with a link to
  the protocol archive.

> Code state: `main`, commit `0287dfa` and the `src_dev` working tree;
> the external greenroof mode and its coefficient carried between steps
> are described in §9.1.

**Abstract.** The legacy garden proxy uses a fixed Bowen ratio and has no
nighttime longwave cooling, condensation or coupling to canyon air
(`PAC_GARDEN = 0`). The implemented scheme replaces it with a
**diagnostic** surface energy balance using surface relative humidity:
surface temperature is obtained by solving the nonlinear equation
`Rn(Ts) = H(Ts) + LE(Ts)` with Newton's method. Ground heat exchange is
not modeled (`G = 0`), since the TEB garden has no prognostic soil column.
The scheme also provides τ splitting of garden coupling to canyon air
and forcing-level air, analogous to the road CBS scheme.

---

## 1. Purpose, modes and code location

**Purpose.** The scheme provides a consistent garden surface energy balance
and participates in the implicit coupling of canyon-air temperature and
humidity (`PAC_GARDEN` is nonzero), unlike the legacy proxy.

**Modes (`namelist tebopts`, key `teb_ctype_garden`):**

| Value | Meaning |
| --- | --- |
| `'PROXY_NEW'` | Diagnostic energy balance (default) |
| `'PROXY_OLD'` | Legacy Bowen proxy (`PH = 0.2·Rn`, `LE = 0.8·Rn`, `PAC = 0`) |
| `'EXT'` | External garden model (TEB receives external fluxes); exchange coefficients use the full `URBAN_EXCH_COEF` (with stability and thermal roughness) |
| `'EXT_NEU'` | External garden model whose diagnostic exchange coefficients use the internal scheme's **neutral** formulation (no stratification; the same thermal roughness `z0h` and minimum wind speed) |

The garden type is stored in `TOP%CTYPE_GARDEN`
(`src/src_struct/modd_teb_optionn.F90`); an invalid value stops execution
(`STOP 1`).

**Surface parameters** (namelist keys and defaults):

| Key | Meaning | Default |
| --- | --- | --- |
| `urb_z0_gdn` | Garden momentum roughness, m | `0.1` (`XZ0_GD` from `src/src_proxi_SVAT/modd_proxi_svat_par.F90`) |
| `urb_z0_o_z0h_gdn` | Ratio `z0/z0h` (`z0h = z0/R`, `R ≥ 1`) | `4.0` (`XZ0_O_Z0H_GD` from `src/src_proxi_SVAT/modd_proxi_svat_par.F90`) |
| `urb_alb_gdn` | Garden albedo | `0.15` |
| `urb_emis_gdn` | Garden emissivity | `0.98` |
| `proxy_phu_gdn` | Garden surface relative humidity `PHU` (in **both** schemes: `'PROXY_NEW'` defines `LE = ρ·Lv·Ca·(PHU·qs(Ts) − qa)`; `'PROXY_OLD'` defines `PHU_AGG_GARDEN`) | `0.7` (default in the `proxy_phu_gdn` declaration; the base model used `0.8`) |

All **five** keys are checked in the driver (roughness `<= 0` or
`>= XUNDEF`, ratio `z0/z0h < 1` or `>= XUNDEF`, albedo outside
`[0, 1)`, emissivity outside `(0, 1]` → `STOP 1`), written to the model
log and passed to all consumers: the internal proxy
(`PZ0_GD`/`PALB_GD`/`PEMIS_GD` for `GARDEN`, `GARDEN_CBS`),
external models (the `ZZ0_GARDEN_EXT`/`PALB_GD_EXT`/`PEMIS_GD_EXT`
family) and the canyon radiation budget (`URBAN_SOLAR_ABS` with
`ZALB_GD`, `URBAN_LW_COEF` with `ZEMIS_GD`). Thus TEB and the internal
proxies cannot use inconsistent parameters by construction.

**Files:**

| File | Contents |
| --- | --- |
| `src/src_proxi_SVAT/garden.F90` | `MODE_GARDEN_BALANCE` module (scheme parameters and the single solver) and three garden subroutines (§3) |
| `src/src_proxi_SVAT/modi_garden.F90` | Interfaces for `GARDEN`, `GARDEN_PCD`, `GARDEN_CBS` |
| `src/src_proxi_SVAT/modd_proxi_svat_par.F90` | Defaults: roughness `XZ0_GD` and ratio `XZ0_O_Z0H_GD` |
| `src/src_teb/teb_garden.F90` (+ `modi`) | Mode selection, τ calculation and `GARDEN_CBS` call; does not recompute exchange coefficients, which are returned by the proxy |
| `src/src_teb/urban_drag.F90` | Garden exchange coefficients for canyon and atmospheric air (including `'EXT_NEU'`) |
| `src_dev/src_offline/teb_offline_surfaces.F90` | External-surface emulators for individual cells (§9) |
| `src_dev/src_api/teb_log.F90` | Model CSV columns |
| `src_dev/src_offline/teb_offline_output.F90` | Emulator and interval-runoff CSV output |

---

## 2. Physical formulation

The vegetation surface energy-balance equation is:

```
Rn(Ts) = H(Ts) + LE(Ts)
```

Ground heat flux is omitted (`G = 0`): the TEB garden is a diagnostic surface
without a soil column or heat store.

| Term | Formula | Meaning |
| --- | --- | --- |
| `Rn` | `(1 − alb)·SW + emis·(LW − σ·Ts⁴)` | Net radiation (shortwave + longwave) |
| `H` | `ρ·cp·Ca_h·(Ts − Ta)` | Sensible heat flux |
| `LE` | `ρ·Lv·Ca_h·(PHU·qs(Ts) − qa)` | Latent heat flux |
| `G` | `0` | Ground heat exchange is not modeled |

Notation:

* `alb`, `emis` — surface albedo and emissivity (namelist keys in §1);
* `SW`, `LW` — incoming shortwave and longwave radiation (TEB passes the
  fluxes absorbed by the garden into the scheme);
* `σ` — Stefan–Boltzmann constant (`XSTEFAN` from `MODD_CSTS`);
* `Ta`, `qa` — reference-air temperature and specific humidity (a mixture
  for τ splitting; see §2.3);
* `ρ` — air density, `cp` — moist-air specific heat at constant pressure
  (`XCPD`), `Lv` — latent heat of vaporization (`XLVTT`);
* `Ca_h` — aerodynamic conductance **for heat and moisture** (scalar),
  m/s (§2.1); stress uses a separate conductance `Ca_m`;
* `PHU` — surface relative humidity (namelist `proxy_phu_gdn`, default
  `0.7`; the base model used `0.8`);
* `qs(Ts)` — saturation specific humidity at surface temperature
  (`QSAT`/`DQSAT` from `MODE_THERMOS`).

### 2.1 Conductances, thermal roughness and surface stress

The garden exchanges **heat and moisture** through a scalar (thermal)
log-profile coefficient based on thermal roughness `z0h`, and
**momentum** through a coefficient based on `z0`:

```fortran
PCD = (kappa / LOG(PZ/PZ0))**2                         ! momentum, 0 when PZ <= PZ0
PCH = kappa**2 / ( LOG(PZ/PZ0) * LOG(PZ/PZ0H) )        ! heat and moisture
    = PCD * ZFH,     ZFH = LOG(PZ/PZ0)/LOG(PZ/PZ0H) <= 1
Z0H = PZ0 / PZ0_O_Z0H                                  ! PZ0_O_Z0H >= 1

Ca_m = PCD * MAX(PV, XVMIN_GD)                          ! stress only
Ca_h = PCH * MAX(PV, XVMIN_GD)                          ! H and LE balance, canyon coupling
PUW  = -Ca_m * MAX(PV, XVMIN_GD)                        ! momentum flux
PAC  = Ca_h                                             ! conductance for TEB
```

where `κ` is the von Kármán constant (`XKARMAN`), `PZ` the reference
height, `PZ0` the momentum roughness (`urb_z0_gdn`),
`PZ0H = PZ0/PZ0_O_Z0H` the thermal roughness, `PZ0_O_Z0H` the namelist
key `urb_z0_o_z0h_gdn` (default `4.0`), and `PV` the wind-speed
magnitude at the reference height.

**Reason for this form.** `PCH = PCD·ZFH` is the neutral limit of
`SURFACE_AERO_COND`, the same formulation used for the TEB road, roof and
town (and the external-model garden in `'EXT'` mode): the ratio of the
momentum and scalar profile logarithms multiplies the momentum coefficient.
The alternative `PCH = (κ/ln(PZ/PZ0H))²` gives a stronger reduction
(at `z = 10 m`, `z0 = 0.1 m`, `R = 4`: 0.59 versus 0.77), but is
neither the TEB scheme's limit nor the classical similarity-theory result
(`H = ρ·cp·κ²·V·ΔT/(ln(z/z0)·ln(z/z0h))`) and was not adopted.

**Thermal roughness is scalar.** It affects only heat and moisture;
`PCD`, `PUW` and town momentum are unchanged, so garden stress is
independent of `R` at the same canyon state.

**`R = 1` gives exact reduction.** At `z0h = z0`,
`GARDEN_PCH_NEUTRAL` returns **exactly** `GARDEN_PCD_NEUTRAL` (the same
expression and rounding), reproducing the formulation without thermal
roughness bit for bit.

**Single source of the formulation.** Neutral expressions are grouped in
`MODE_GARDEN_BALANCE` (`src/src_proxi_SVAT/garden.F90`) as four
`ELEMENTAL` functions:

| Function | Formula |
| --- | --- |
| `GARDEN_PCD_NEUTRAL(PZ, PZ0)` | `PCD = (κ/ln(PZ/PZ0))²`, `0` when `PZ ≤ PZ0` |
| `GARDEN_CA_NEUTRAL(PZ, PZ0, PV)` | `Ca_m = PCD·max(PV, XVMIN_GD)` |
| `GARDEN_PCH_NEUTRAL(PZ, PZ0, PZ0_O_Z0H)` | `PCH = κ²/(ln(PZ/PZ0)·ln(PZ/PZ0H))`, `= PCD` when `PZ0_O_Z0H ≤ 1` |
| `GARDEN_CAH_NEUTRAL(PZ, PZ0, PZ0_O_Z0H, PV)` | `Ca_h = PCH·max(PV, XVMIN_GD)` |

These quantities are computed and returned by the garden models themselves:

* `GARDEN` — the `PCD`/`PCH` pair (and `PAC_GARDEN` conductance) for
  the internal garden without τ splitting; the model handles its own mode
  (`'PROXY_NEW'` — neutral pair, `'PROXY_OLD'` (Bowen) — zeros);
* `GARDEN_CBS` — canyon-branch coefficients and the conductances derived
  from them: scalar canyon (`Ca_h_C`), momentum (`Ca_m_C`) and
  atmospheric (`Ca_h_A`);
* `URBAN_DRAG` — the `TOP%CTYPE_GARDEN == 'EXT_NEU'` block (canyon:
  height `PZ_LOWCAN = H/2` and wind `PU_LOWCAN`; atmosphere:
  `PUREF` and `PVMOD`);
* the offline driver's external-model emulator `PCD_GARDEN` (§9).

`TEB_GARDEN` neither computes nor zeros these quantities: it passes its
`PCH_GD`/`PCD_GD` arrays directly in the proxy call's argument list (§4).
In external mode, the proxy is not called, so the arrays retain the
`URBAN_DRAG` values.

Thus the minimum wind speed is never duplicated, and the exported
coefficients and internal scheme describe **the same** object. For
`'EXT_NEU'`, this means `PCD = PCDN > PCH = PCDN·ZFH` (momentum and
heat are separate), `ZZ0H_GARDEN_*` equals the thermal roughness used,
and `PRI_GARDEN_*` remains undefined at `XUNDEF` (no stratification).
In `'EXT'`, coefficients use the full `URBAN_EXCH_COEF` (with stability
and the same `z0h = z0/urb_z0_o_z0h_gdn`), making the exchange coefficient
16–35 % lower than the neutral value; this is the distinction between
`'EXT_NEU'` and `'EXT'`.

**Why a minimum wind speed is needed.** Without it, calm conditions give
`Ca_h = 0`, completely decoupling the surface from the air; its
temperature is no longer tied to `Ta` (in the radiative limit,
`Ts → (LW/σ)^(1/4) = T_sky`). The lower wind-speed bound ensures nonzero
heat exchange and makes the problem well posed **without artificial
limits on `Ts`**: `Vmin = 0.5` m/s gives
`ρ·cp·Ca_h ≈ 5…9 W/m²/K`, which on a clear night with
`Rn ≈ −70 W/m²` yields `Ts ≈ Ta − 4…14 K`, within a physical range.

### 2.2 Solving the nonlinear equation (Newton's method)

The equation `F(Ts) = 0` and its derivative are:

```
F(Ts)  = (1 − alb)·SW + emis·(LW − σ·Ts⁴)
         − ρ·cp·Ca_h·(Ts − Ta)
         − ρ·Lv·Ca_h·(PHU·qs(Ts) − qa)

F'(Ts) = −[ 4·emis·σ·Ts³ + ρ·cp·Ca_h + ρ·Lv·Ca_h·PHU·dqsat/dT ]
```

Iteration (`ZDEN = −F' > 0`):

```fortran
DO JITER = 1, NITER_GD          ! NITER_GD = 8
   ZQSAT  = QSAT (ZTS_GD, PPS)
   ZDQSAT = DQSAT(ZTS_GD, PPS, ZQSAT)          ! exact dqsat/dT from MODE_THERMOS
   ZNUM   = (1-alb)*SW + emis*(LW - XSTEFAN*ZTS_GD**4)                     &
            - rho*XCPD*Ca_h*(ZTS_GD - T_REF) - rho*XLVTT*Ca_h*(PHU*ZQSAT - Q_REF)
   ZDEN   = 4.*emis*XSTEFAN*ZTS_GD**3 + rho*XCPD*Ca_h + rho*XLVTT*Ca_h*PHU*ZDQSAT
   ZDELTA = ZNUM / ZDEN                        ! = F / (−F'), 0 when ZDEN <= 1e-8
   ZTS_GD = ZTS_GD + MAX(-XDTSTEP_GD, MIN(XDTSTEP_GD, ZDELTA))   ! |dTs| <= 5 K
   ZTS_GD = MAX(XTSMIN_GD, MIN(XTSMAX_GD, ZTS_GD))                ! [230, 350] K
ENDDO
```

Numerical details:

* the initial guess is `PTS_GARDEN` (an `INOUT` argument), using the
  previous step's value. Repeated calls with the same inputs therefore
  depend on the initial guess (the sandbox accounts for this by resetting
  `Ts` before each call; otherwise, bit-for-bit comparisons are invalid
  because the number of effective Newton steps differs);
* each step is limited to `5 K`; absolute bounds `[230, 350] K` are
  numerical safeguards only (needed for valid `qs(Ts)` and `σ·Ts⁴`).
  There is no `|Ts − Ta|` limit: the minimum wind speed makes it
  unnecessary;
* the solver returns **unclipped** fluxes; the calling subroutine applies
  clipping (`XHMAX_GD`, `XLEMAX_GD`, `XLEMIN_GD`). Clipping can
  therefore slightly violate the exact equality `Rn = H + LE`
  (it is inactive under normal conditions).

### 2.3 Garden τ branches (canyon and atmosphere coupling)

The garden remains **one surface** with one temperature `Ts`; τ
interpolates its coupling to two air masses, as in the road budget:

```fortran
PCH_C  = kappa**2/(LOG(PZ_LOWCAN/PZ0_GD)*LOG(PZ_LOWCAN/PZ0H_GD))    ! heat and moisture
Ca_h_C = PCH_C * MAX(PU_LOWCAN, XVMIN_GD)                          ! canyon, level H/2
PCH_A  = kappa**2/(LOG(PUREF/PZ0_GD)*LOG(PUREF/PZ0H_GD))
Ca_h_A = PCH_A * MAX(PVMOD,     XVMIN_GD)                          ! atmosphere, level PUREF
Ca_eff = PTAU*Ca_h_C + (1.-PTAU)*Ca_h_A
T_ref  = (PTAU*Ca_h_C*PT_LOWCAN + (1.-PTAU)*Ca_h_A*PTA) / Ca_eff    ! guard Ca_eff > 0
q_ref  = (PTAU*Ca_h_C*PQ_LOWCAN + (1.-PTAU)*Ca_h_A*PQA) / Ca_eff
Ca_m_C = (kappa/LOG(PZ_LOWCAN/PZ0_GD))**2 * MAX(PU_LOWCAN, XVMIN_GD) ! for PUW only
```

`PZ0H_GD = PZ0_GD/PZ0_O_Z0H` is thermal roughness (§2.1). The reference-air
τ mixture is weighted by **scalar** conductances `Ca_h_*`, which are used
to compute `H`/`LE`, so the blend remains an identity.

The balance equation is solved **once** using the aggregate
`(Ca_eff, T_ref, q_ref)` (one surface, one radiation budget), after which
the actual flux and branch fluxes are:

```
H_GARDEN  = ρ·cp·Ca_eff·(Ts − T_ref)     H_GARDEN_CAN = ρ·cp·Ca_h_C·(Ts − PT_LOWCAN)
                                        H_GARDEN_ATM = ρ·cp·Ca_h_A·(Ts − PTA)
LE_GARDEN = ρ·Lv·Ca_eff·(PHU·qs(Ts) − q_ref)   LE_GARDEN_CAN/ATM — likewise
```

Thus the identities hold exactly:

```
H_GARDEN  = τ·H_GARDEN_CAN + (1−τ)·H_GARDEN_ATM        (likewise for LE)
Rn_GARDEN = H_GARDEN + LE_GARDEN                       (G = 0)
```

**Three cases** (activation:
`LCBS_SPLIT = TOP%LCBS_SCHEME .AND. TOP%CTYPE_GARDEN == 'PROXY_NEW'`):

| `teb_ctype_garden` | CAN branch | ATM branch | `H_GARDEN` | Effect of τ |
| --- | --- | --- | --- | --- |
| `'PROXY_NEW'` | Solution with canyon coupling | Same solution with mixed coupling | `τ·H_CAN + (1−τ)·H_ATM` | Yes |
| `'PROXY_OLD'` | Prescribed `0.2·Rn` | **Same value** | `0.2·Rn` | No |
| `'EXT'`, `'EXT_NEU'` | External-model flux | **Same value** | External-model flux | No |

For `'PROXY_OLD'` and external modes, and when the scheme is off,
`Ca_h_A = 0`, no mixing is performed, and **both branches are forced to
equal the actual flux**. By construction, these modes are insensitive to
which forcing was used to compute the flux, so equal branches are
appropriate (and `H = τ·H_CAN + (1−τ)·H_ATM` holds trivially).

**Where branches are used:**

| Recipient | Contribution |
| --- | --- |
| `T_CAN0` (`avg_urban_fluxes.F90`) | `Ts·PAC_GD·ZGD` — canyon conductance without τ (as with `T_rd`/`PAC_RD` for the road) |
| `PQ_CAN0` | `qsat(Ts)·PAC_GD·PHU·ZGD` |
| `T_CAN1` (free-layer input) | `ZGD·PH_GARDEN_ATM` |
| `PQ_CAN1` | `ZGD·PLE_GARDEN_ATM` |
| Town balance (`PH_TWN`, `PH_GRND`, `PLE_TWN`, `LE_GRND`, `PEVAP_TWN`) | `PH_GARDEN`/`PLE_GARDEN` — τ blend |

Garden radiation quantities (`XABS_SW_GARDEN`, `XABS_LW_GARDEN`,
`ZEMIT_LW_GD`) and the `PQ_CAN0` humidity node use the single `Ts`,
so radiation terms need no averaging.

**Limits and properties:**

* `teb_lcbs_scheme = .FALSE.` (any garden type): mixing is off, branches
  equal the actual flux, and model behavior before CBS is reproduced
  bit for bit;
* `τ = 1` with the scheme enabled: mixing is skipped, the solution matches
  the canyon solution, and `H_GARDEN = H_GARDEN_CAN` **exactly**. Only
  free-layer diagnostics (`T_CAN1`, `PHI_CAN1`) change, now including
  the garden's atmospheric branch;
* `τ → 0`: `H_GARDEN = H_GARDEN_ATM`, `T_CAN = T_CAN1`;
* flux clipping (`XHMAX_GD`, `XLEMAX_GD`, `XLEMIN_GD`) applies to the
  actual flux. The §2.3 identities hold exactly wherever clipping is
  inactive; when active, the residual is of the order of the clipping;
* there is no degeneracy: `Ca_h_A = 0` when `z0 ≥ PUREF`, and the canyon
  branch's minimum wind guarantees `Ca_eff > 0`; a `Ca_eff > 0` guard
  protects `T_ref`/`q_ref`;
* garden momentum flux (`PUW_GARDEN`) remains canyon-based, as for the
  road: CBS does not split momentum;
* **one surface temperature** is a deliberate choice: two independent
  `Ts` values (shaded/open garden parts) require either breaking
  `Rn = H + LE` closure or making `T_CAN0`/`T_CAN1` nodes
  inconsistent, while the flux improvement is ≤ 1 W/m² (see §5.3 of the
  [archived history](https://github.com/mkolennikova/TEB-MSU/blob/12c3fbf52092e84431f9dfbabef3e76741a0ac8d/docs/TEB_MSU_change_history.md)).

---

## 3. Code structure

`src/src_proxi_SVAT/garden.F90` contains the `MODE_GARDEN_BALANCE`
module and **three** garden subroutines.

| Subroutine | Purpose | Conductance | Stress / branches | Caller |
| --- | --- | --- | --- | --- |
| `GARDEN_CBS` | TEB garden **with CBS**: `_CAN`/`_ATM` branches, one surface temperature | Computes `PCH_C`, `PCH_A` (scalar; heights `H/2` and `PUREF` handled internally) and `PCD` for stress | Computes internally (`PUW = −Ca_m_C·max(u_c, Vmin)`, branches) | Model (`TEB_GARDEN`) — sole TEB entry point |
| `GARDEN` | Reduced diagnostic garden **without τ** (model behavior before CBS) | Computes `PCD = (κ/ln(z/z0))²` and calls `GARDEN_PCD` | **One** flux set (no branches in the signature) | Experiment only |
| `GARDEN_PCD` | Same balance with **external** dimensionless `PCD` (momentum), `PCH` (heat and moisture), and reference state (`PT_REF`, `PQ_REF`, wind `PV_GD`) | **Does not compute coefficients**: `Ca_m = PCD·max(V, Vmin)`, `Ca_h = PCH·max(V, Vmin)` | **One** flux set; computes `PUW` internally | Experiment only |

The `MODE_GARDEN_BALANCE` module (in the same file) contains scheme
parameters (`proxy_phu_gdn`, `XVMIN_GD`, Newton step and bounds, clipping),
the **single** solver `GARDEN_BALANCE(PCA, PT_REF, PQ_REF, …)`, and four
`ELEMENTAL` neutral-formulation functions (`GARDEN_PCD_NEUTRAL`,
`GARDEN_CA_NEUTRAL`, `GARDEN_PCH_NEUTRAL`, `GARDEN_CAH_NEUTRAL`, §2.1).
Both `GARDEN_PCD` and `GARDEN_CBS` call the solver (the latter uses
τ-mixed conductance, which cannot be expressed as `PCD·max(V, Vmin)`).

Mutual calls use interfaces from `MODI_GARDEN`
(`USE MODI_GARDEN, ONLY : GARDEN_PCD` in `GARDEN`, `ONLY : GARDEN`
in `GARDEN_CBS`), so there are no intermediate core routines.

All three support `'PROXY_NEW'` and `'PROXY_OLD'`/`'EXT'` (the legacy
Bowen proxy: `PAC = 0`, with `PCD` used only for stress
`PUW = −PCD·V²`). Only `GARDEN_CBS` returns the **branch decomposition**
(`PH_GARDEN_CAN/ATM`, `PLE_GARDEN_CAN/ATM`): it alone knows both
conductances and both reference-air states. `GARDEN` and `GARDEN_PCD`
return **one** flux set; the caller supplies the flat substitution (both
branches = flux, making `H = τ·H_CAN + (1−τ)·H_ATM` trivial):
`GARDEN_CBS` itself in its non-τ branch, and TEB for the external garden.

Argument lists are compact: **`GARDEN_PCD` has neither height nor `z0`
arguments** (already incorporated in the supplied `PCD`). Unused legacy
parameters (`HIMPLICIT_WIND`, `TPTIME`, `PTSUN`, `PPEW_*`,
`PPET/PPEQ_*`, `PTSTEP`, `PEXNS`, `PCO2`, `PRR`, `PSR`,
`PZENITH`) were removed from all three routines, and the call in
`teb_garden.F90` was shortened accordingly.

Debug runs use an external sandbox (outside the repository): the
`test_garden.F90` driver and `build.ps1` compile physics **directly from
the repository** (`garden.F90`, `modi_garden.F90` and dependencies:
`hook`, `modd_csts`, `modd_reprod_oper`, `modd_surf_par`,
`mode_thermos`, `ini_csts`). It supports bit-for-bit comparison of
`GARDEN`/`GARDEN_PCD`/`GARDEN_CBS` across conditions (summer day and
night, winter, calm, dry heat, degenerate `z0`).

---

## 4. Outputs and diagnostics

`GARDEN_CBS` populates the same output arguments as the legacy scheme
(`RN_GARDEN`, `H_GARDEN`, `LE_GARDEN`, `EVAP_GARDEN`, `PUW_GARDEN`,
`PAC_GARDEN`, `PQSAT_GARDEN`, `TS_GARDEN`, `PRUNOFF_GARDEN`,
`PDRAIN_GARDEN`, `PIRRIG_GARDEN`), and additionally returns branches
`PH_GARDEN_CAN/ATM`, `PLE_GARDEN_CAN/ATM`.

Exchange coefficients are also proxy outputs: `GARDEN` and `GARDEN_CBS`
return the `PPCD_GD`/`PPCH_GD` pair (arguments at the end of the lists),
and `TEB_GARDEN` passes it directly into its own `PCH_GD`/`PCD_GD`
outputs in the call's argument list. `TEB_GARDEN` neither computes nor
zeros the coefficients (except in the disabled-garden branch, which calls
no model and resets all garden outputs uniformly). For `'PROXY_OLD'`,
the proxy returns zeros: the Bowen proxy has no exchange coefficient.

**Both** internal schemes return the canyon-node humidity multiplier
(`PHU_AGG_GD`): `PHU_AGG_GARDEN` = β = `proxy_phu_gdn`, a proxy-model
parameter (§5). For an external garden, `TEB_GARDEN` derives it from
host surface humidity as `clamp(q_v/q_sat(Ts))` (§9): an external surface
is not described by the proxy model.

`TEB_output.csv` columns (per m² of garden):

| Column | Meaning |
| --- | --- |
| `TS_GARDEN` | Garden surface temperature |
| `RN_GARDEN`, `H_GARDEN`, `LE_GARDEN`, `EVAP_GARDEN` | Net radiation, sensible and latent heat fluxes, evaporation |
| `QSAT_GARDEN`, `PHU_GARDEN` | Saturation humidity at `Ts` and canyon-node humidity multiplier: internal-scheme β (`proxy_phu_gdn`) or external-garden `clamp(q_v/q_sat(Ts))` (§9) |
| `PAC_GARDEN` | Scalar (heat and moisture) garden↔canyon-air conductance; the humidity node uses `PAC_GARDEN·PHU_GARDEN` |
| `PCD_GARDEN_CAN`, `PCH_GARDEN_CAN` | Dimensionless garden↔canyon-air coefficients: `PCD` (momentum, stress only) and `PCH` (heat and moisture, using `z0h`); `0` for a disabled garden and the legacy proxy |
| `PCD_GARDEN_ATM`, `PCH_GARDEN_ATM` | Corresponding coefficients for forcing-level air (populated only in external modes, §9) |
| `ZZ0H_GARDEN_CAN`, `ZZ0H_GARDEN_ATM` | Thermal roughness `z0h` used in `'EXT_NEU'`; `XUNDEF` for the internal garden (thermal roughness is reflected in `PCH_GARDEN_CAN`) |
| `H_GARDEN_CAN`, `H_GARDEN_ATM`, `LE_GARDEN_CAN`, `LE_GARDEN_ATM` | Branches from §2.3 (`XUNDEF` when the scheme is off) |
| `EMU_*` (13 columns) | External-model emulator diagnostics (§9): `EMU_TAU`, `EMU_CD_EFF`, `EMU_CH_EFF`, `EMU_CH_NAIVE`, `EMU_V`, `EMU_T`, `EMU_Q`, `EMU_CA_CAN`, `EMU_CA_EFF`, `EMU_TS`, `EMU_H`, `EMU_LE`, `EMU_EVAP` |

Common (zero) scheme diagnostics:

```fortran
PSFCO2  = 0      ! no photosynthesis
PRUNOFF = 0      ! no runoff
PDRAIN  = 0      ! no drainage
PIRRIG  = 0      ! no irrigation
PGFLUX  = 0      ! no ground exchange
```

---

## 5. Scheme parameters

| Parameter | Value | Source |
| --- | --- | --- |
| `PALB` (albedo) | `urb_alb_gdn` = `0.15` | Namelist → `PALB_GD` |
| `PEMIS` (emissivity) | `urb_emis_gdn` = `0.98` | Namelist → `PEMIS_GD` |
| `PHU` (surface relative humidity) | `0.7` (default in the variable declaration; `0.8` in the base version) | Namelist `proxy_phu_gdn` → `PHU_GD` |
| `z0` (momentum roughness) | `urb_z0_gdn` = `0.1` m | Namelist → `PZ0_GD` |
| `z0h` (thermal, scalar roughness) | `urb_z0_gdn/urb_z0_o_z0h_gdn` = `0.025` m | Namelist → `PZ0_O_Z0H_GD` |
| `Vmin` (minimum wind speed) | `0.5` m/s (`XVMIN_GD`) | `MODE_GARDEN_BALANCE` constant |
| `G` (ground heat flux) | `0` | Not modeled |

`PHU` is the same for all `'PROXY_NEW'` modes. The default
`urb_emis_gdn = 0.98` matches the emissivity TEB uses in the canyon
radiation budget, so the internal proxies and TEB are consistent by
construction.

---

## 6. Numerical safeguards

| Quantity | Value | Purpose |
| --- | --- | --- |
| `NITER_GD` | 8 | Number of Newton iterations |
| `XDTSTEP_GD` | 5 K | Newton-step limit |
| `XTSMIN_GD` | 230 K | Lower `Ts` bound (numerical safeguard) |
| `XTSMAX_GD` | 350 K | Upper `Ts` bound (numerical safeguard) |
| `XHMAX_GD` | 1000 W/m² | Limit on `\|H\|` |
| `XLEMAX_GD` | 1000 W/m² | Limit on `LE` |
| `XLEMIN_GD` | −200 W/m² | Condensation limit (downward `LE`) |
| `ZDEN` threshold | 1e-8 | Set the Newton step to zero below this threshold |

There is no limit on `|Ts − Ta|`: it is unnecessary because minimum wind
speed (`Vmin`) guarantees nonzero heat exchange and keeps `Ts` near
`Ta`. Absolute bounds `[230, 350] K` are needed only for valid
`qs(Ts)` and `σ·Ts⁴`. Flux clipping is a safeguard: it slightly
violates the exact equality `Rn = H + LE`, but is inactive under normal
conditions, so closure is achieved to Newton-convergence precision.

---

## 7. Physical notes

* **`PHU` is surface relative humidity, not saturation.** Surface humidity
  is `q_surf = PHU·qs(Ts)`: `PHU = 1` denotes a saturated surface,
  while `PHU < 1` represents drying (stomatal resistance, substrate
  moisture). Evaporation is positive when `PHU·qs(Ts) > qa`, i.e. when
  `PHU` exceeds ambient relative humidity; at a lower `PHU`, the
  surface condenses moisture.
* **`PHU = 0` is an artifact of the linear scheme.** The formula gives
  `LE = ρ·Lv·Ca·(0 − qa) < 0`: a dry surface condenses atmospheric
  moisture. In practice, `PHU` should not be zero. A more appropriate
  dry surface requires `q_surf = min(PHU·qs(Ts), qa)`, beyond the
  linear diagnostic scheme.
* **No ground exchange (`G = 0`).** The garden is a diagnostic surface
  without a soil column or heat store (unlike prognostic ISBA, for
  example, with layer memory). Energy balance closes instantaneously:
  `Rn = H + LE`.
* **Minimum wind speed is a well-posedness condition.** It replaces
  artificial limits on `Ts`: on a clear, calm night it keeps `Ts`
  near `Ta` (see §2.1).
* **Thermal roughness weakens only scalar exchange.** `z0h < z0`
  reduces `PCH` relative to `PCD` by the factor
  `ZFH = ln(z/z0)/ln(z/z0h)` (at canyon level `H/2` and the forcing
  level), so garden heat coupling is weaker than momentum coupling.
  At the same net radiation, the `Ts` amplitude increases, the
  magnitudes of `H` and `LE` decrease, and the garden contribution
  to canyon air weakens. The default `R = 4` gives `ZFH ≈ 0.77`
  (dense canyon) and `≈ 0.71` (low buildings).
* **At night** (`SW = 0`), longwave cooling operates: the scheme gives
  negative `H` (cooling) and possibly negative `LE` (dew) if
  `PHU·qs(Ts) < qa`. This is the main physical improvement over the
  Bowen proxy, whose fluxes vanish at `SW = 0`.
* **During daytime at high `PHU`**, an oasis regime is possible:
  `LE` exceeds `Rn`, and the surface draws the missing heat from
  the air (`H < 0`, `Ts < Ta`). This is physically appropriate
  for a very wet surface; at `PHU = 0.8` it occurs during a
  substantial fraction of daytime steps. The default `0.7` is a
  compromise between wet conditions and physical transpiration:
  at ambient `RH ≈ 0.5–0.6`, `PHU ≲ 0.5` already gives daytime
  condensation rather than transpiration (see above). Literature
  estimates of the urban-lawn β factor give `PHU ≈ 0.7–0.85`.

---

## 8. Integration into TEB

* **`PAC_GARDEN` is nonzero.** In
  `src/src_teb/avg_urban_fluxes.F90`, the canyon temperature node
  receives `PTSRAD_GD·PAC_GD·ZGD`, and the humidity node receives
  `PQSAT_GD·PAC_GD·PHU_AGG_GD·ZGD`. The garden thus enters implicit
  canyon-air coupling with the same conductance `PAC_GD` (humidity
  multiplier `PHU_AGG_GD`).
* **`PGFLUX_GARDEN` remains zero** in both schemes (no ground exchange),
  so `PGFLX_GRND` and `PGFLX_TWN` are unchanged.
* **Diagnostic consistency.** `DMT%XABS_SW_GARDEN`,
  `DMT%XABS_LW_GARDEN` and `ZEMIT_LW_GD` are recomputed in
  `teb_garden.F90` from the same solved `ZTSRAD_GD`; with the same
  `PALB`/`PEMIS`, returned `RN` matches the recomputed diagnostic.
* **Garden diagnostics are written to `TEB_output.csv`** (per m² of
  garden, §4).
* **τ branches** (§2.3) enter the `T_CAN0` node through the canyon branch
  and the free layer `T_CAN1` through the atmospheric branch. See
  `TEB_MSU_CBS_scheme_T_CAN_reformulation.md` for the meaning of
  `T_CAN0`/`T_CAN1`/`T_CAN`.

---

## 9. External garden and offline-driver emulator

**Modes `'EXT'` and `'EXT_NEU'`.** The garden is supplied externally:
TEB receives `teb_ts_gd`, `teb_qs_gd`, `teb_shfl_gd`,
`teb_lhfl_gd`, `teb_qvfl_gd`, `teb_runoff_gd` from the external
model through the standard interface. The modes differ in the diagnostic
exchange coefficients computed by `URBAN_DRAG`:

| Mode | Coefficient formulation | Use |
| --- | --- | --- |
| `'EXT'` | Full `URBAN_EXCH_COEF` (with `SURFACE_RI` stability and `z0h = z0/urb_z0_o_z0h_gdn`) | External-model coupling; coefficients 16–35 % below neutral values |
| `'EXT_NEU'` | Internal-garden neutral formulation (`GARDEN_PCD_NEUTRAL`/`GARDEN_CA_NEUTRAL` for momentum, `GARDEN_PCH_NEUTRAL`/`GARDEN_CAH_NEUTRAL` for heat and moisture) | Recommended coupling mode: exported coefficients match those used by the diagnostic balance |

**Proxy models are not called in external mode** (for either garden or
greenroof). For `'EXT'`/`'EXT_NEU'`, `GARDEN_CBS` is skipped:
`TEB_GARDEN` takes state (`Ts` in `ZTSRAD_GD`) and fluxes from the
host and constructs only `q_sat(Ts)` (the `QSAT_GARDEN` argument),
stress `PUW_GARDEN = −PCD_CAN·U_lowcan²`, and zero `PGFLUX`/`SFCO2`.
The canyon-node humidity multiplier is `clamp(q_v/q_sat(Ts))` (the
COSMO-TEB formula in `garden.F90:164/166/167`), and conductance comes
from `URBAN_DRAG`. Thus the external garden contains no surface-model
code: neither Bowen fluxes nor the internal-scheme β are computed.
Stress uses the **momentum coefficient of the same mode** computed by
`URBAN_DRAG` and exported to the host (`PCD_GARDEN_CAN`:
stratified `URBAN_EXCH_COEF` in `'EXT'`, neutral in `'EXT_NEU'`).
This is the previous substep's value (`URBAN_DRAG` is called after
this section); on the first substep, before it is available, the neutral
formula is used. Garden momentum has one channel (the canyon branch
`Ca_m_C`): τ splitting does not apply (§10, item 9). Likewise,
`GREENROOF` is not called in these modes, and its humidity multiplier
is derived from host surface moisture (`teb_qs_gr` → `PQV_GR_EXT`, §9.1).

**Garden exchange coefficients returned to the caller.** The
`PCH_GD`/`PCD_GD` pair (`ZCH_GD`/`ZCD_GD` in `CALL_DRIVER` →
host `teb_tch_gd`/`teb_tcm_gd`; CSV columns
`PCH_GARDEN_CAN`/`PCD_GARDEN_CAN`) belongs entirely to garden models:
`GARDEN`/`GARDEN_CBS` return it (§4), and in external mode it comes
from `URBAN_DRAG` (the proxy is not called, so values remain in the
arrays). `TEB_GARDEN` neither computes nor zeros it: external-mode
coefficients describe exchange using host roughness; internal-mode
coefficients come from the proxy (`'PROXY_OLD'` returns zeros because
the Bowen proxy has no exchange coefficient). External-garden roughness
is a host quantity (`teb_z0_gd` → `ZZ0_GD_EXT` →
`PZ0_GARDEN_EXT`): `CALL_DRIVER` checks it and stops (`STOP 1`)
if an enabled external garden has an unphysical value.

**Offline-driver emulator.** In `'EXT_NEU'`, the offline driver
(`src_dev/src_offline/teb_offline_surfaces.F90`) itself acts as the
external garden model (contained subroutine `PCD_GARDEN`).
`call_driver`/TEB remain unchanged and cannot distinguish emulation
from a real external model: they see the standard `EXT` interface.

Data flow at each substep (immediately after `CALL teb_interface`):

1. Construct both garden τ-splitting paths with the same formulas,
   heights/`z0`/`z0h` as `GARDEN_CBS` (coefficients come directly
   from `GARDEN_PCD_NEUTRAL`/`GARDEN_PCH_NEUTRAL`):
   `PCD_C = (κ/ln((H/2)/z0))²`,
   `PCH_C = κ²/(ln((H/2)/z0)·ln((H/2)/z0h))`,
   `V_C = max(ZU_CANYON, Vmin)`;
   `PCD_A = (κ/ln(hlev_teb/z0))²`,
   `PCH_A = κ²/(ln(hlev_teb/z0)·ln(hlev_teb/z0h))`,
   `V_A = max(|V_forc|, Vmin)`; τ is the same tanh blend based on H/W.
2. Forcing supplied to the external model:
   `V* = τ·V_C + (1−τ)·V_A` (τ-average wind), `T* = T_CAN`,
   `q* = Q_CAN`; radiation is `SW`/`LW` recovered from TEB's
   garden-absorbed fluxes (`XABS_SW = (1−alb)·SW_rec`,
   `XABS_LW = ε·(LW_rec − σTs⁴)`).
3. **Effective coefficients** (τ-averaging covariance correction):
   `Ca_eff = τ·Ca_h_C + (1−τ)·Ca_h_A` is scalar (thermal) conductance,
   and `CH_eff = Ca_eff/max(V*, Vmin)`, so
   `CH_eff·max(V*, Vmin) ≡ Ca_eff` (the covariance term
   `τ(1−τ)(Cd_C−Cd_A)(V_A−V_C)` is removed identically).
   `CD_eff = PCD_C·max(V_C, Vmin)²/max(V*, Vmin)²`: as in the model,
   momentum remains on the canyon branch (this coefficient determines
   emulator `PUW`).
4. Call `GARDEN_PCD('PROXY_NEW', CD_eff, CH_eff, V*, T*, q*, …)`:
   the same diagnostic balance and parameters as the internal scheme.
   The resulting `Ts`, `H`, `LE`, `EVAP` and
   `qs = PHU·QSAT(Ts)` are written to driver prognostic variables,
   which TEB reads at the next substep.

**Emulator diagnostics:** a log line identifies the mode and a one-time
check reports `CH_eff·max(V*, Vmin) − Ca_eff`; CSV includes 13
`EMU_*` columns (§4), only in `EXT`/`EXT_NEU` modes.

**Structural differences from the internal scheme:**

* in `EXT`/`EXT_NEU`, `PAC_GD = 0`: the garden **does not enter**
  the implicit `T_CAN0`/`Q_CAN0` nodes, whereas the internal scheme
  modifies canyon air itself. This is the main remaining source of
  differences, and it grows with τ;
* branch decomposition is not emulated: both branches carry the same
  flux (`H_GARDEN_CAN = H_GARDEN_ATM = H_GARDEN`), whereas the internal
  scheme provides distinct branches;
* coupling is one-way with a one-substep lag; the first substep spins
  up the coupling (`Ts = T` of the air, zero fluxes) and should
  preferably be excluded from statistics.

### 9.1 Greenroof: `EXT`/`EXT_NEU` modes and the `PCD_GREENROOF` emulator

The greenroof uses **the same** diagnostic balance (`GARDEN_BALANCE`)
and neutral coefficients (`GARDEN_PCD_NEUTRAL`/`GARDEN_PCH_NEUTRAL`),
but is a **roof** surface: it exchanges only with forcing-level air.
Therefore:

* there is no canyon branch or τ splitting, only one branch (the special
  case of the garden's atmospheric branch at τ = 0). Greenroof conductance
  (`PAC_GREENROOF`) does not participate in the equations: it is passed
  to neither `TEB` nor `AVG_URBAN_FLUXES` (the `PAC_GREENROOF` CSV
  column is diagnostic). Only greenroof state, fluxes
  (`H_GREENROOF`/`LE_GREENROOF`/`EVAP_GREENROOF`/`RUNOFF`) and
  fraction `T%XGREENROOF` enter roof and town budgets;
* radiation is that of the town: the roof is neither shaded by the canyon
  nor exposed to its multiple reflections (`URBAN_SOLAR_ABS`:
  `PREC_SW_RF = (dir+sca)·(1−fr_panel)`, `ZREC_LW_RF = PLW_RAD`).
  Unlike garden radiation, it can therefore be taken directly from
  driver forcing;
* no τ-averaging covariance correction is needed by construction:
  `CH_eff = PCH`, so `CH_eff·max(V*,Vmin) ≡ Ca` exactly (the garden's
  `CH_eff` incorporates `τ(1−τ)(Cd_C−Cd_A)(V_A−V_C)`).

Greenroof modes (key `teb_ctype_greenroof`) mirror garden modes:

| Mode | Coefficient formulation | Driver emulator |
| --- | --- | --- |
| `'PROXY_NEW'` | Internal diagnostic balance (neutral coefficients) | — |
| `'PROXY_OLD'` | Legacy Bowen proxy, 1:1 | — |
| `'EXT'` | Full `URBAN_EXCH_COEF` (stability, `z0h = z0/urb_z0_o_z0h_grf`, `HZ0H = 'MASC95'`) | Uses **its own** neutral coefficients, so `EMU_GR_*` differs from `*_GREENROOF_ATM`: the difference measures the effect of stability (`3.1e-3` in `PCD` in the bench) |
| `'EXT_NEU'` | Internal-greenroof neutral formulation | Matches exported coefficients exactly (`EMU_GR_CD = PCD_GREENROOF_ATM`, etc.) |

**The greenroof proxy is not called in external modes.** For
`'EXT'`/`'EXT_NEU'`, `GREENROOF` is skipped (the
`CASE ('EXT','EXT_NEU')` branch was removed from the proxy).
`TEB_GARDEN` takes state (`Ts`) and fluxes from the host and constructs
`q_sat(Ts)` (the `QSAT_GREENROOF` column), humidity multiplier
`clamp(q_v/q_sat(Ts))` from host surface moisture `teb_qs_gr`
(a new interface input, analogous to garden `teb_qs_gd`), and stress
`−PCD_GREENROOF_ATM·V²`. Here, `PCD_GREENROOF_ATM` is the forcing-level
momentum coefficient from `URBAN_DRAG`: stratified in `'EXT'`, neutral
in `'EXT_NEU'`; the previous substep's value is used, with a neutral
value on the first substep. `PAC_GREENROOF`, `XG_GREENROOF_ROOF`,
drainage and irrigation are zero in this mode. Unlike the garden
multiplier (§4), the greenroof multiplier remains diagnostic and enters
no budget.

In the `src_dev` public API, the previous/new `PCD_GREENROOF_ATM` is
passed through the mandatory INOUT array `teb_cd_greenroof_atm`.
The host stores it separately for each column; offline, the driver
retains it between model substeps. At `ntstep == 0`,
`TEB_INIT_STATE` sets `XUNDEF` so that the first stress estimate uses
the neutral coefficient. At `ntstep > 0`, the API restores the saved
value before physics and returns the new coefficient afterward.
On restart, the host restores this array with the rest of the state;
cold-start is not called again. The API contract is in §3 of
`../TEB_MSU_containers.md`; the column-independence check and protocol
are in §0 of the
[archived history](https://github.com/mkolennikova/TEB-MSU/blob/12c3fbf52092e84431f9dfbabef3e76741a0ac8d/docs/TEB_MSU_change_history.md).

**The `PCD_GREENROOF` emulator** (offline driver,
`src_dev/src_offline/teb_offline_surfaces.F90`) is the roof equivalent
of `PCD_GARDEN`: one exchange path, `V* = max(|V_forc|, Vmin)`,
`T* = T` of forcing-level air, `q* = q`, `CD_eff = PCD`,
`CH_eff = PCH`, radiation `(swdir_s+swdifd_s)·(1−fr_panel)` and
`lwd_s·(1−fr_panel)`, followed by one
`GARDEN_PCD('PROXY_NEW', …)` call. The resulting `Ts`, `H`,
`LE`, `EVAP` are written to driver prognostic variables and read by
TEB at the next substep (one-substep lag; the first row spins up the
coupling).

CSV columns (13, only in `EXT`/`EXT_NEU` modes): `EMU_GR_CD`,
`EMU_GR_CH`, `EMU_GR_CA`, `EMU_GR_V`, `EMU_GR_T`, `EMU_GR_Q`,
`EMU_GR_PSW`, `EMU_GR_PLW`, `EMU_GR_TS`, `EMU_GR_RN`, `EMU_GR_H`,
`EMU_GR_LE`, `EMU_GR_EVAP`.

**Bench:** `python_tests/greenroof_emu_compare.py` (3 morphologies × 3
greenroof modes, garden off, `dt = forc_step`) — 126 checks, 96 substantive,
all passed. Unlike the garden, where `PAC_GD = 0` creates a structural
residual, the greenroof has no structural error:
`EMU_GR_TS/H/LE/EVAP/RN` reproduces `'PROXY_NEW'` bit for bit in the
same row (`max|d| = 1.1e-13` K for `Ts`, `8.0e-12` W/m² for `LE`,
`3.2e-18` kg/m²/s for `EVAP`), and the `'EXT_NEU'` prognostic
columns equal those values shifted by one row.

---

## 10. Limitations and open questions

1. **Atmospheric-branch conductance `Ca_h_A` has no separate output
   column** (it can be recovered from `H_GARDEN_ATM`, `Ts` and
   `PTA`): `PAC_GARDEN_ATM` is already used by the `URBAN_DRAG`
   diagnostic in `EXT` mode.
2. **Incoming garden radiation is not partitioned** between shaded and
   open parts (SVF): τ changes only aerodynamic coupling, as for the road.
3. **Wind speed in the atmospheric branch** is taken at roof level
   (`PVMOD`), rather than from a local profile above the garden.
4. **In `EXT`/`EXT_NEU`, the garden does not enter implicit canyon-air
   coupling** (`PAC_GD = 0`, §9). At realistic τ (about 0.06 for LCZ9),
   the effect is small; in a dense canyon it becomes dominant, requiring
   the external model to supply its canyon conductance as well
   (a new `EXT` interface input).
5. **The remaining emulator error is structural** (a single
   `T* = T_CAN` mixture, no implicit coupling, a one-substep lag), rather
   than a time shift. Its magnitudes by site and morphology are in the
   [archived history](https://github.com/mkolennikova/TEB-MSU/blob/12c3fbf52092e84431f9dfbabef3e76741a0ac8d/docs/TEB_MSU_change_history.md).
6. **No vegetation physiology:** `PHU` is fixed; there is no
   photosynthesis (`PSFCO2 = 0`), soil-moisture or CO₂ dependence of
   stomatal resistance, irrigation, runoff or drainage
   (`PIRRIG = PRUNOFF = PDRAIN = 0`), or ground exchange (`G = 0`).
7. **The same roughness is used for heat and moisture** (`z0q = z0h`):
   no separate vapor roughness (second key) is introduced. TEB road,
   roof and town use the same approach (one scalar coefficient for
   `H` and `LE`).
8. **`PHU = 0` has no physical meaning** in the linear scheme (§7).
9. **τ splitting is not applied to garden momentum:** stress uses a
   single canyon conductance `Ca_m_C` (canyon wind), while heat and
   moisture are split into `_CAN`/`_ATM` branches. A future extension
   should also split momentum (internal schemes via τ weights,
   external modes via `URBAN_DRAG` coefficients, §9/§9.1), so stress
   consistently represents both branches.

---

## 11. Invariants and reproduction

| No. | Invariant | Criterion |
| --- | --- | --- |
| G1 | `Rn_GARDEN = H_GARDEN + LE_GARDEN` (`G = 0`) | Residual at 1e-11 W/m² |
| G2 | `H_GARDEN = τ·H_GARDEN_CAN + (1−τ)·H_GARDEN_ATM` (likewise for `LE`) | ≤ 3.6e-12 W/m² (summer and winter), ≤ 3.4e-13 for `LE` |
| G3 | τ → 1 limit | `H_GARDEN = H_GARDEN_CAN` (exactly, 0.0) |
| G4 | τ → 0 limit | `H_GARDEN = H_GARDEN_ATM` (~2e-12 W/m²), `T_CAN = T_CAN1` (0.0 K) |
| G5 | τ recovered from fluxes `(H_GARDEN − H_ATM)/(H_CAN − H_ATM)` | Matches the analytical value (σ ≤ 1.6e-13) |
| G6 | Regression: scheme off / `PROXY_OLD` / `EXT` | Bit-for-bit match in all shared CSV columns (summer, winter, garden enabled and disabled) |
| G7 | `PAC_GARDEN_CAN ≡ EMU_CA_CAN` in `'EXT_NEU'` | 0 (at each step) |
| G8 | `PCDN_GARDEN_CAN = (κ/ln((H/2)/urb_z0_gdn))²`; `PCH_GARDEN_CAN = κ²/(ln((H/2)/z0)·ln((H/2)/z0h))`; `EMU_CH_NAIVE = τ·PCH_CAN + (1−τ)·PCH_ATM` | Exact (0) |
| G9 | `PCD = PCDN` and `PCH = PCDN·ZFH` in `'EXT_NEU'`; `ZZ0H_GARDEN_* = z0/R`; `PRI_GARDEN_*` | First relations exact; `XUNDEF` |
| G10 | Town energy balance | Residual unchanged relative to runs without a garden |
| G11 | Thermal roughness: `R = 1` (`z0h = z0`) | `PCH_GARDEN_CAN = PCD_GARDEN_CAN` exactly; all other columns match the case without `z0h` bit for bit |
| G12 | `PAC_GARDEN = PCH_GARDEN_CAN·max(U_CANYON, Vmin)`; `PAC_GARDEN(R)/PAC_GARDEN(1) = ZFH(R)` | Exact (≤ 1e-15 and ≤ 1e-12) |
| G13 | Coefficient pair returned by the proxy (`GARDEN`/`GARDEN_CBS`); no computation or zeroing in `TEB_GARDEN` (except the disabled-garden branch) | `PCH_GD`/`PCD_GD` occur in `teb_garden.F90` only in the proxy call's argument list and the reset branch |
| G14 | External-surface stress uses the mode's momentum coefficient (`PCD_GARDEN_CAN` for the garden canyon branch, `PCD_GREENROOF_ATM` for the greenroof), with a neutral fallback if unavailable | In `'EXT_NEU'`, stress matches the neutral formula at each step (0 differences); in `'EXT'`, only stress changes (CSV matches bit for bit); the first substep is neutral |

Reproduction (repository scripts in `python_tests/`):

* `compare_garden_scheme.py` — A/B bench for garden modes
  (`PROXY_OLD`/`PROXY_NEW`/`EXT`/OFF) using the full CSV, garden
  balance closure and town-budget effects;
* `garden_z0_sensitivity.py` — sensitivity to `urb_z0_gdn`, with an
  analytical check of the conductance log law;
* `garden_z0h_sensitivity.py` — sensitivity to thermal roughness
  (`urb_z0_o_z0h_gdn` = 1…8, τ on/off, three LCZs): analytical
  `PCD`/`PCH` coefficients, §2.3 identities, `R = 1` reduction
  and effect tables;
* `garden_surface_par_sensitivity.py` — sensitivity to
  `urb_alb_gdn`/`urb_emis_gdn` (inactivity with the surface disabled,
  balance closure, recovery of received shortwave/longwave fluxes);
* `garden_proxy_compare.py`, `garden_proxy_sensitivity.py` — scheme
  comparison and sensitivity to (`PHU`, `z0`);
* `check_anthro_heat.py`, `compare_exch_coef.py` — garden coupling to
  the canyon and exchange coefficients.

Numerical protocols for individual runs (morphologies, dates, effect
tables, emulator comparison with the internal scheme) are in the
[archived history](https://github.com/mkolennikova/TEB-MSU/blob/12c3fbf52092e84431f9dfbabef3e76741a0ac8d/docs/TEB_MSU_change_history.md).

---

## 12. References

Code:

* `src/src_proxi_SVAT/garden.F90` — `MODE_GARDEN_BALANCE`,
  `GARDEN_CBS`, `GARDEN`, `GARDEN_PCD`;
* `src/src_proxi_SVAT/modi_garden.F90`,
  `src/src_proxi_SVAT/modd_proxi_svat_par.F90` — interfaces and defaults;
* `src/src_teb/teb_garden.F90` — mode selection, `CBS_TAU`,
  `GARDEN_CBS` call (the proxy returns exchange coefficients and
  conductances; `TEB_GARDEN` only passes them through);
* `src/src_teb/urban_drag.F90` — garden exchange coefficients
  (including `'EXT_NEU'`);
* `src/src_teb/avg_urban_fluxes.F90` — garden contribution to canyon nodes;
* `src_dev/src_offline/teb_offline_surfaces.F90` — `PCD_GARDEN` and
  `PCD_GREENROOF` emulators;
* `src_dev/src_offline/teb_offline_output.F90` — emulator CSV output.

Documents: `TEB_MSU_CBS_scheme_T_CAN_reformulation.md`,
`../TEB_MSU_source_defects.md`, `../TEB_MSU_change_history.md`,
`../TEB_MSU_variables_description.md`.
