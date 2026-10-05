# TEB-Ru Model Variables Description

This document provides a comprehensive description of all input (namelist) and output variables used in the TEB-Ru model.

## Namelist Variables

These variables are defined in the Fortran namelist files (`namelist.nml` and `namelist_forcing.nml`) and control the model configuration.

### Basic Building Characteristics

| Variable | Type | Dimension/Value | Comment |
|:---------|:-----|:----------------|:--------|
| `dt` | External parameter | s | Model time step |
| `urb_h_bld` | External parameter | m | Average canyon height |
| `urb_fr_bld` | External parameter | - | Building area fraction |
| `urb_h2w` | External parameter | - | Canyon aspect ratio |
| `teb_road_dir` | External parameter | ° | Canyon azimuth |
| `teb_hroad_dir` | Control variable | "UNIF" / "ORIE" | Canyon orientation: ORIE - with orientation, UNIF - without |
| `teb_wall_opt` | Control variable | "UNIF" / "TWO" | Wall energy balance: TWO - separate walls, UNIF - uniform |
| `teb_ti_bld` | Prognostic variable | K | Indoor air temperature |
| `teb_qi_bld` | Prognostic variable | kg/kg | Indoor specific humidity |

<!-- MV202609 z0 and zd to namelist -->
### Urban Aerodynamics

Aerodynamic parameters of the urban (town) surface. Each of the two values below
accepts the following forms (case insensitive):

| Form | Example | Meaning |
|:-----|:--------|:--------|
| number | `0.5` or `'0.5'` | value in metres |
| number with `m` | `'0.5m'` | value in metres |
| fraction of the building height | `'0.1H'` | `urb_h_bld * 0.1` |
| building height divided by n | `'H/3'` | `urb_h_bld / 3` |
| parameterization name | `'MACDONALD1998'` | Macdonald et al. (1998) scheme, staggered arrays; `'MACDONALD1998SQ'` selects the square-array coefficients. The scheme sets the value of the entry in which it is given (only `z0` in `urb_z0_town`, only `zd` in `urb_zd_town`) |
| ... | `'MACDONALD1998SQ'` | same scheme with A = 3.59 and beta = 0.55 (square arrays) |

| Variable | Type | Dimension/Value | Comment |
|:---------|:-----|:----------------|:--------|
| `urb_z0_town` | External parameter | m, `H`, `H/n` or name | Roughness length for momentum of the urban surface (default `'0.1H'`, i.e. `0.1*urb_h_bld`) |
| `urb_zd_town` | External parameter | m, `H`, `H/n` or name | Displacement height of the urban surface, measured from the road level (default `'H/3'`) |

`urb_zd_town` is used both in the wind profile of the driver and inside TEB: all
aerodynamic formulas use the height above the displacement surface, i.e.
`urb_h_bld - urb_zd_town` above the roof level plus the forcing height.

<!-- MV202609 z0 and zd to namelist -->
**Macdonald et al. (1998)** (doi 10.1016/S1352-2310(97)00403-2), staggered arrays
(`'MACDONALD1998'`: A = 4.43, beta = 1.0) or square arrays (`'MACDONALD1998SQ'`:
A = 3.59, beta = 0.55), with Cd = 1.2 and kappa = 0.4 (von Karman):

```
d/h  = 1 + A^(-lambda_p) * (lambda_p - 1)                                         eq. (23)
z0/h = (1 - d/h) * exp( -( 0.5*beta*(Cd/kappa^2)*(1 - d/h)*lambda_f )^(-0.5) )    eq. (22)
```

where `lambda_p = urb_fr_bld` (plan area index) and `lambda_f = mean(teb_fai)`
(frontal area index, isotropic variant). The two namelist entries are resolved
independently, so a scheme name can be combined with an explicit value in the
other entry, e.g. `urb_z0_town = '0.1H'` with `urb_zd_town = 'MACDONALD1998'`,
or the same scheme name can be given in both entries.

Notes:
- the official TEB has no displacement-height parameter (only the roughness length
  `ZZ0`, given in metres) and uses a hard-coded `+ urb_h_bld/3.` shift in
  `urban_drag.F90`, which corresponds to `zd = 2/3*urb_h_bld` and is inconsistent
  with its own wind profile, where `2/3*urb_h_bld = urb_h_bld - zd` gives
  `zd = 1/3*urb_h_bld`; in TEB-Ru both places use the single value `urb_zd_town`;
- with the default wind scheme (`teb_itype_wind = 0`) the town exchange coefficient
  affects only the friction velocity (diagnostics and the coupling with an
  atmospheric model); it changes the offline results when the Wang scheme
  (`teb_itype_wind = 1`) is used.

### Surface Properties

| Variable | Type | Dimension/Value | Comment |
|:---------|:-----|:----------------|:--------|
| `urb_alb_rf_so` | External parameter | - | Roof surface albedo |
| `urb_alb_rf_th` | External parameter | - | Roof surface emissivity |
| `urb_hcap_rf` | External parameter | J/m³/K | Roof layers volumetric heat capacity |
| `urb_hcon_rf` | External parameter | W/m/K | Roof layers thermal conductivity |
| `urb_alb_rd_so` | External parameter | - | Road surface albedo |
| `urb_alb_rd_th` | External parameter | - | Road surface emissivity |
| `urb_hcap_rd` | External parameter | J/m³/K | Road layers volumetric heat capacity |
| `urb_hcon_rd` | External parameter | W/m/K | Road layers thermal conductivity |
| `urb_alb_wl_so` | External parameter | - | Wall surface albedo |
| `urb_alb_wl_th` | External parameter | - | Wall surface emissivity |
| `urb_hcap_wl` | External parameter | J/m³/K | Wall layers volumetric heat capacity |
| `urb_hcon_wl` | External parameter | W/m/K | Wall layers thermal conductivity |

### Building Energy Model (BEM)

| Variable | Type | Dimension/Value | Comment |
|:---------|:-----|:----------------|:--------|
| `teb_itype_bem` | Control variable | "BEM" / "DEF" | Activate BEM model |
| `teb_lbem_ac` | Flag | True / False | Activate air conditioning |
| `teb_itype_natvent` | Control variable | "NONE" / "MANU" / "AUTO" / "MECH" | Natural ventilation mode |
| `teb_itype_bem_cool` | Control variable | "DXCOIL" / "IDEAL " | Cooling system type |
| `teb_itype_bem_heat` | Control variable | "FINCAP" / "IDEAL " | Heating system type |
| `teb_frac_gz` | External parameter | - | Glazing ratio |
| `teb_tcool_target` | External parameter | K | Cooling setpoint temperature |
| `teb_theat_target` | External parameter | K | Heating setpoint temperature |
| `teb_zresidential` | External parameter | - | Residential fraction of building |
| `teb_dt_res` | External parameter | K | Temperature change threshold for unoccupied residential building |
| `teb_dt_off` | External parameter | K | Temperature change threshold for unoccupied office building |
| `teb_bem_inf` | External parameter | AC/H | Infiltration rate |
| `teb_bem_vent` | External parameter | AC/H | Ventilation rate |
| `teb_bem_cop` | External parameter | - | Nominal COP of cooling system |
| `teb_cap_sys_rat` | External parameter | W/m²(building) | Nominal cooling system capacity (for "DXCOIL" type) |
| `teb_m_sys_rat` | External parameter | kg/s/m²(building) | Nominal HVAC mass flow rate |
| `teb_cap_sys_heat` | External parameter | W/m²(building) | Heating system capacity |
| `teb_lshade` | External parameter | True / False | Activate window shading (not verified) |

### Anthropogenic Heat Fluxes

| Variable | Type | Dimension/Value | Comment |
|:---------|:-----|:----------------|:--------|
| `ahf_traffic` | External parameter | W/m² | Sensible heat flux from traffic |
| `ahf_industry` | External parameter | W/m² | Sensible heat flux from industry |

### Wind Inside Urban Canopy

| Variable | Type | Dimension/Value | Comment |
|:---------|:-----|:----------------|:--------|
| `teb_itype_wind` | Control variable | 0 / 1 | Wind speed calculation: 0 - basic scheme, 1 - Wang (2012) parameterization |
| `teb_fai` | External parameter | - | Frontal area index for 8 wind directions |

### Green Infrastructure

| Variable | Type | Dimension/Value | Comment |
|:---------|:-----|:----------------|:--------|
| `teb_lgarden` | Flag | True / False | Activate garden module |
| `fr_garden` | External parameter | - | Garden area fraction |
| `teb_type_garden` | Character | `'PROXY_OLD'` / `'PROXY_NEW'` / `'EXT'` / `'EXT_NEU'` | Garden model type (default `'PROXY_NEW'`) |
<!-- MV202609 garden thermal roughness (z0h) -->
| `urb_z0_gdn` | External parameter | m | Garden roughness length for **momentum**, used by **all** the garden models (default `0.1` = `MODD_PROXI_SVAT_PAR:XZ0_GD`; must be `> 0` and `< XUNDEF`, otherwise the run stops) |
| `urb_z0_o_z0h_gdn` | External parameter | - | Garden `z0/z0h` ratio (`z0h = urb_z0_gdn/urb_z0_o_z0h_gdn` is the **thermal, scalar** roughness of the garden: heat and moisture exchange through it, the momentum keeps `urb_z0_gdn`; default `4.0` = `MODD_PROXI_SVAT_PAR:XZ0_O_Z0H_GD`; must be `>= 1` and `< XUNDEF`, otherwise the run stops; `1.0` reproduces the garden without thermal roughness bit for bit) |
| `urb_alb_gdn` | External parameter | - | Garden albedo (default `0.15`; must be `>= 0` and `< 1`, otherwise the run stops) |
| `urb_emis_gdn` | External parameter | - | Garden emissivity (default `0.98`; must be `> 0` and `<= 1`, otherwise the run stops) |
| `teb_lgreenroof` | Flag | True / False | Activate green roof module |
| `teb_frac_gr` | External parameter | - | Green roof fraction |
| `urb_z0_grf` | External parameter | m | Green roof roughness length, used by **all** the greenroof models (default `0.01` = `MODD_PROXI_SVAT_PAR:XZ0_GR`; validated like the garden one) |
| `urb_alb_grf` | External parameter | - | Green roof albedo (default `0.15`) |
| `urb_emis_grf` | External parameter | - | Green roof emissivity (default `0.98`) |
<!-- MV202609 proxy parameters to namelist -->
> **Rename.** The two parameters below were called `urb_phu_gdn` / `urb_phu_grf`. They are now
> named after the model that owns them (`proxy_phu_*`, the `PHU` parameter of the proxy module
> `MODD_PROXI_SVAT_PAR`, read by the proxies themselves): `TEB_GARDEN` no longer sees the
> parameter, it receives the moisture multiplier from the model. A namelist file that still
> carries the former names is reported by the driver (an undeclared item is silently ignored).
| `urb_z0_o_z0h_grf` | External parameter | - | Green roof `z0/z0h` ratio (`z0h = urb_z0_grf/urb_z0_o_z0h_grf` is the **thermal, scalar** roughness of the greenroof, used by the diagnostic greenroof exactly as `urb_z0_o_z0h_gdn` is used by the garden; default `4.0` = `MODD_PROXI_SVAT_PAR:XZ0_O_Z0H_GR`; must be `>= 1` and `< XUNDEF`) |
| `proxy_phu_gdn` | External parameter | - | Garden surface relative humidity `PHU`, used by **both** garden schemes: `'PROXY_NEW'` drives `LE = rho*Lv*Ca*(PHU*qsat(Ts) - qa)`, `'PROXY_OLD'` drives `PHU_AGG_GARDEN` (default `0.7` = `MODD_PROXI_SVAT_PAR:proxy_phu_gdn`; the **base model** value was `0.8` — set `proxy_phu_gdn = 0.8` to reproduce the base model; must be `> 0` and `<= 1`; read by `src_dev` only — `src_ctrl` keeps the base-model constant `0.8`; an external garden (`'EXT'`/`'EXT_NEU'`) does not use it, its multiplier being the host surface humidity ratio) |
| `proxy_phu_grf` | External parameter | - | Green roof surface relative humidity `PHU`, used by **both** greenroof schemes (default `0.7` = `MODD_PROXI_SVAT_PAR:proxy_phu_grf`; the **base model** value was `0.3` — set `proxy_phu_grf = 0.3` to reproduce the base model; must be `> 0` and `<= 1`) |

#### Garden model type (`teb_type_garden`)

Used only when `teb_lgarden = .TRUE.`:

| Value | Model |
|:------|:------|
| `'PROXY_NEW'` | **Default.** Diagnostic surface energy balance solved for the garden surface temperature by Newton iteration (`Rn = H + LE`, i.e. no heat flux into the soil; surface relative humidity `PHU`; zero-flux CO2; non-zero aerodynamic conductance feeding back on the canyon air; a minimum wind speed of 0.5 m/s keeps `Ts` anchored to the air). Heat and moisture exchange through the neutral scalar coefficient `PCH = kappa**2/(ln(z/z0)*ln(z/z0h))` (thermal roughness `z0h = urb_z0_gdn/urb_z0_o_z0h_gdn`), the friction flux through `PCD = (kappa/ln(z/z0))**2`. |
| `'PROXY_OLD'` | Historical proxy with a fixed Bowen ratio (0.25) and the namelist albedo (`urb_alb_gdn`), driven by the short-wave radiation only; conduction and aerodynamic conductance neglected. |
| `'EXT'` | The garden fluxes are provided by an external model (the internal call is a placeholder). The diagnostic garden exchange coefficients of `URBAN_DRAG` (`PCD*_GARDEN_*`) use the full `URBAN_EXCH_COEF` set: Richardson number, `z0h = z0/urb_z0_o_z0h_gdn`, `WIND_THRESHOLD`. The **friction flux** of the garden uses the momentum coefficient of that model (`PCD_GARDEN_CAN`, i.e. the value exported to the host as `teb_tcm_gd`; that of the previous sub-step, neutral on the first sub-step of a run). |
| `'EXT_NEU'` | Same external garden, but the garden exchange coefficients follow the **neutral** formulation of the internal diagnostic garden (`PCD`/`Ca_m` for momentum, `PCH`/`Ca_h` for heat and moisture with the same thermal roughness `z0h` and the same wind floor `XVMIN_GD = 0.5 m/s`), so `PCD = PCDN > PCH = PCDN*ZFH`, `ZZ0H_GARDEN_*` is the thermal roughness used and only `PRI` stays undefined (`XUNDEF`). This is the coefficient set a coupled external garden model is meant to be driven with: it is identical to the canyon-path coefficients of `'PROXY_NEW'` and to the emulator of the offline driver. The friction flux uses the same exported momentum coefficient (the neutral one here). |

#### Greenroof model type (`teb_type_greenroof`)

Used only when `teb_lgreenroof = .TRUE.` (the external greenroof keeps its own flag
`teb_lgreenroof_ext`):

| Value | Model |
|:------|:------|
| `'PROXY_NEW'` | **Default.** The same diagnostic surface energy balance as the garden (`Rn = H + LE` solved by Newton iteration, `G = 0`, no soil column), but the greenroof is a **roof** surface: it exchanges only with the air of the forcing level (`PTA`/`PQA` at `PUREF`, wind `PVMOD`), so there is no canyon branch and no tau split. Heat and moisture use `PCH = kappa**2/(ln(z/z0)*ln(z/z0h))` with `z0h = urb_z0_grf/urb_z0_o_z0h_grf`, momentum uses `PCD`; the surface relative humidity is `proxy_phu_grf`; `PAC_GREENROOF` is the non-zero roof-level conductance (it does **not** feed back on the canyon air). |
| `'PROXY_OLD'` | Historical proxy with a fixed Bowen ratio (1.0: `H = LE = 0.5*Rn`) and the namelist albedo, driven by the short-wave radiation only; `PAC_GREENROOF = 0`, `PHU_AGG_GREENROOF = proxy_phu_grf`. |
| `'EXT'` | **External greenroof.** The surface state and the fluxes come from the host model through the standard `EXT` interface (`teb_ts_gr`, `teb_shfl_gr`, `teb_lhfl_gr`, `teb_qvfl_gr`, `teb_runoff_gr`). The diagnostic exchange coefficients of `URBAN_DRAG` (`*_GREENROOF_ATM`) use the full `URBAN_EXCH_COEF` set (Richardson number, `z0h = z0/urb_z0_o_z0h_grf`, `WIND_THRESHOLD`) at `PZREF`/`PUREF`, so they are 16-35 % below the neutral ones. Setting this type forces `teb_lgreenroof_ext = .TRUE.`. The greenroof proxy is **not** called
in this mode (nor in `'EXT_NEU'`): `TEB_GARDEN` builds `QSAT_GREENROOF` at the host surface
temperature and takes the surface humidity of the host (`teb_qs_gr`, new input of the
interface, the counterpart of `teb_qs_gd` of the garden) to form the multiplier
`clamp(q_v/qsat(TS_GREENROOF))`; `PAC_GREENROOF`, `XG_GREENROOF_ROOF`, the drainage and the
irrigation are zero in this mode. The friction flux uses the exported momentum coefficient `PCD_GREENROOF_ATM` (that of the previous sub-step, neutral on the first sub-step of a run). |
| `'EXT_NEU'` | Same external greenroof, but the diagnostic coefficients follow the **neutral** formulation of the internal diagnostic greenroof (`GARDEN_PCD_NEUTRAL`/`GARDEN_PCH_NEUTRAL`/`GARDEN_CAH_NEUTRAL` at `PUREF` with the wind floor `XVMIN_GD = 0.5 m/s` and the same thermal roughness `z0h`): `PCD = PCDN > PCH = PCDN*ZFH`, `ZZ0H_GREENROOF_ATM` is the thermal roughness used and `PRI_GREENROOF_ATM` stays undefined (`XUNDEF`). This is the coefficient set a coupled external greenroof is meant to be driven with. |

#### Surface properties of the garden and of the greenroof

One single value **per surface and per property**, shared by all the models of that
surface (the internal proxy schemes and the external ones) and by the radiation
budget of the canyon, so that TEB and the internal schemes use the same values by
construction:

| Surface | Roughness length (m) | Albedo | Emissivity |
|:--------|:---------------------|:-------|:-----------|
| Garden (`gdn`) | `urb_z0_gdn` = `0.1` (`XZ0_GD`) | `urb_alb_gdn` = `0.15` | `urb_emis_gdn` = `0.98` |
| Green roof (`grf`) | `urb_z0_grf` = `0.01` (`XZ0_GR`) | `urb_alb_grf` = `0.15` | `urb_emis_grf` = `0.98` |

The values are validated by the driver (roughness length `> 0` and `< XUNDEF`, ratio
`z0/z0h >= 1` and `< XUNDEF`, albedo in `[0, 1)`, emissivity in `(0, 1]`) and printed
in the banner (`TEB-Ru offline: urb_z0_gdn = ...`, `urb_z0_o_z0h_gdn = ... -> z0h(garden) = ...`,
`urb_z0_grf = ...`, `garden alb/emis = ...`, `greenroof alb/emis = ...`); an
out-of-range value stops the run (`STOP 1`).

Propagation: the roughness lengths travel along
`teb_z0_gd`/`teb_z0_gr` → `ZZ0_GD_EXT`/`ZZ0_GR_EXT` → `PZ0_GARDEN_EXT`/`PZ0_GR_EXT` →
`PZ0_GD` of `GARDEN` and `PZ0_GR` of `GREENROOF`; the albedo and the emissivity travel
along `PALB_GD_EXT`/`PEMIS_GD_EXT` (garden) and `PALB_GR_EXT`/`PEMIS_GR_EXT`
(greenroof) → `PALB_GD`/`PEMIS_GD` and `PALB_GR`/`PEMIS_GR` of the two schemes, and
into the canyon radiation budget: `URBAN_SOLAR_ABS` (`ZALB_GD`, `ZALB_GRF`) and
`URBAN_LW_COEF` (`ZEMIS_GD`, `ZEMIS_GR`).

**What changes with respect to the constants.** Before the unification the internal
garden proxies used the `TEB_VEG_PROPERTIES` constants (albedo `0.15`, emissivity
`0.98`) while the `'EXT'` mode received the driver default emissivity `0.9`, and the
greenroof roughness length was hard-coded (`0.01`). The unified defaults keep the
internal modes bit-for-bit identical (`python_tests/compare_garden_scheme.py`, A/B: 0
differing columns over 12 cases x 92 columns), but they **do change** `'EXT'` runs
(emissivity `0.9` → `0.98`: 41…45 columns, up to about 53 W/m² on the road/canyon
latent heat flux in LCZ 2, `RN_GARDEN` up to about 9.7 W/m²) - use
`urb_emis_gdn = 0.9` to reproduce the old `'EXT'` numbers. The greenroof defaults
(`0.01`, `0.15`, `0.98`) reproduce the previous hard-coded values; with the greenroof
ON the greenroof albedo acts on the roof/canyon short-wave budget (`URBAN_SOLAR_ABS`,
3 exported columns change in LCZ 2: `RN_TOWN`, `H_TOWN`, `LE_TOWN`), while the
greenroof emissivity (town equivalent emissivity `PEMIS_TWN`/`PTS_TWN`, used by the
town snow scheme, and the greenroof long-wave absorption diagnostic) and the
greenroof roughness length (the blended roof momentum flux `PUW_RF` and the Dupuit
drag `PDUWDU_RF`, which are not exported and do not feed back) do not modify any
exported column of a snow-free run. The garden parameters, by contrast, are all
active (albedo + emissivity in the garden and canyon budgets, roughness length in
the garden conductance and in `URBAN_DRAG`). See
`python_tests/garden_surface_par_sensitivity.py`.


<!-- MV202609 garden thermal roughness (z0h) -->
##### Garden roughness length (`urb_z0_gdn`) and thermal roughness (`urb_z0_o_z0h_gdn`)

The driver uses `urb_z0_gdn` as the default of `teb_z0_gd` (see the propagation above);
inside the canyon it fixes the momentum coefficient and, together with the ratio
`urb_z0_o_z0h_gdn` (`z0h = urb_z0_gdn/urb_z0_o_z0h_gdn`), the scalar (thermal)
coefficient of the exchange:

```
PCD = (k / ln(zref/z0))²                       momentum (friction flux only)
PCH = k² / (ln(zref/z0)·ln(zref/z0h)) = PCD·ZFH   heat and moisture
Ca_h = PCH · max(V, 0.5 m/s)                   conductance used by the balance
                                               zref = H/2 (canyon reference level)
```

so a larger `z0` (or a smaller ratio, i.e. a larger `z0h`) means a stronger
garden/canyon exchange of heat and moisture: larger `Ca_h`, larger `|H|` and `LE`
(per m² of garden), smaller `Ts − Ta` contrast. With `'PROXY_OLD'` the values are
inert (`PAC_GARDEN = 0`, the historical Bowen proxy does not use the conductance);
with `'EXT'` `urb_z0_gdn` and the ratio set the garden/canyon conductance used by
TEB's implicit canyon budget.

| Value (m) | Meaning |
|:----------|:--------|
| `0.1` | Default (`MODD_PROXI_SVAT_PAR:XZ0_GD`), reference value of the internal proxies |
| `0.8` | Well vegetated (rough) garden, used in `python_tests/garden_z0_sensitivity.py` |

| `urb_z0_o_z0h_gdn` (-) | Meaning |
|:-----------------------|:--------|
| `1.0` | `z0h = z0`: the garden without thermal roughness, reproduced bit for bit (reference case of `python_tests/garden_z0h_sensitivity.py`) |
| `4.0` | Default (`MODD_PROXI_SVAT_PAR:XZ0_O_Z0H_GD`): `PCH/PCD = ZFH = 0.71…0.77` for the reference heights of TEB |
| `2`, `8` | Weaker / stronger thermal-roughness effect, used in the sensitivity bench |

#### Garden output columns

Written by every garden model (per m² of garden); when `teb_lgarden = .FALSE.`
they are undefined (`XUNDEF`):

| Column | Dimension | Comment |
|:-------|:----------|:--------|
| `TS_GARDEN` | K | Garden surface (radiative) temperature |
| `RN_GARDEN` | W/m² | Net radiation over the garden |
| `H_GARDEN` | W/m² | Sensible heat flux over the garden |
| `LE_GARDEN` | W/m² | Latent heat flux over the garden |
| `EVAP_GARDEN` | kg/m²/s | Total evaporation over the garden |
| `QSAT_GARDEN` | kg/kg | Saturation specific humidity at `TS_GARDEN` |
| `PHU_GARDEN` | - | Moisture multiplier of the canyon node for the garden: the surface relative humidity of the internal scheme (`proxy_phu_gdn`) or, for an external garden, `clamp(q_v/qsat(TS_GARDEN))` of the host |
<!-- MV202609 garden thermal roughness (z0h) -->
| `PAC_GARDEN` | m/s | Aerodynamic conductance of the garden **for heat and moisture** (the scalar coefficient `PCH` times `max(U_CANYON, 0.5)`) used by the canyon budget (`0` for `'PROXY_OLD'`) |
| `PCD_GARDEN_CAN`, `PCH_GARDEN_CAN` | - | Garden/canyon exchange coefficients used by the garden of the model: momentum (`PCD`, friction only) and thermal (`PCH`, heat and moisture, from `urb_z0_o_z0h_gdn`); returned by the garden model itself (`GARDEN`/`GARDEN_CBS`) in the internal modes and by `URBAN_DRAG` in the external ones; `0` for `'PROXY_OLD'` and when the garden is off |
| `ZZ0H_GARDEN_CAN`, `ZZ0H_GARDEN_ATM` | m | Thermal roughness `z0h` used by the `'EXT_NEU'` garden coefficients (`XUNDEF` for the internal garden, whose `z0h` is visible through `PCH_GARDEN_CAN`) |
| `H_GARDEN_CAN` | W/m² | Garden sensible heat flux of the canyon branch (`_CAN`) of the cbs scheme |
| `H_GARDEN_ATM` | W/m² | Garden sensible heat flux of the direct garden/atmosphere branch (`_ATM`) |
| `LE_GARDEN_CAN` | W/m² | Garden latent heat flux of the canyon branch (`_CAN`) |
| `LE_GARDEN_ATM` | W/m² | Garden latent heat flux of the direct garden/atmosphere branch (`_ATM`) |

**External garden model (emulator).** With `teb_type_garden = 'EXT'` (or `'EXT_NEU'`)
the garden of TEB is prescribed from the outside (surface temperature, surface humidity and
fluxes). In the offline driver `run_teb_offline.F90` this external model is
EMULATED by the contained subroutine `PCD_GARDEN`, which is called at every model
sub-step right after `CALL teb_interface` and which uses `GARDEN_PCD` (the same
diagnostic surface energy balance as the internal garden scheme). The state
(`TS_GARDEN`, `H_GARDEN`, `LE_GARDEN`, `EVAP_GARDEN`) is then read by TEB at the
NEXT sub-step, so `TS_GARDEN` of one output line is the emulator state of the
previous sub-step. The following columns are written only in this mode:

| Column | Dimension | Comment |
|:-------|:----------|:--------|
| `EMU_TAU` | - | Weight of the canyon path of the garden exchange (the tanh relaxation of the canyon H/W ratio used by the cbs scheme) |
| `EMU_CD_EFF` | - | Effective momentum coefficient given to the external model: `PCD_canyon*max(V_canyon,Vmin)^2/max(V*,Vmin)^2` (TEB keeps the garden momentum on the canyon path only; the emulator friction uses this coefficient) |
| `EMU_CH_EFF` | - | Effective heat/moisture coefficient: `Ca_eff/max(V*,Vmin)`, where `Ca_eff = tau*Ca_h_canyon+(1-tau)*Ca_h_atmosphere` are the **scalar** (thermal) conductances: the coefficient absorbs the covariance term `tau(1-tau)(Cd_C-Cd_A)(V_A-V_C)` of the averaging, so that `EMU_CH_EFF*max(V*,Vmin) = EMU_CA_EFF` exactly |
| `EMU_CH_NAIVE` | - | Tau-averaged (naive) coefficient `tau*PCH_C+(1-tau)*PCH_A`, i.e. what an averaging without the covariance correction would give |
| `EMU_V`, `EMU_T`, `EMU_Q` | m/s, K, kg/kg | The one complete set (wind, air) given to the external model: `EMU_V` is the tau-averaged wind, `EMU_T`/`EMU_Q` the air of the canyon |
| `EMU_CA_CAN`, `EMU_CA_EFF` | m/s | Conductance of the canyon path and tau-aggregated conductance |
| `EMU_TS`, `EMU_H`, `EMU_LE`, `EMU_EVAP` | K, W/m², W/m², kg/m²/s | State and fluxes returned by the external model (prescribed to TEB at the next sub-step) |

The diagnostic garden columns of `URBAN_DRAG` (`PCDN/PRI/ZZ0H_GARDEN_CAN`,
`PAC/PCDN/PRI/ZZ0H/PCD/PCH_GARDEN_ATM`) are filled in **both** external modes, but
with two different coefficient sets:

* `'EXT'` - `URBAN_EXCH_COEF` (Richardson number, `z0h = urb_z0_gdn/urb_z0_o_z0h_gdn`,
  `WIND_THRESHOLD`): the description of the coefficients a *coupled* host model
  would need, not the coefficients actually used by the emulator;
* `'EXT_NEU'` - the neutral formulation of the internal diagnostic garden
  (`GARDEN_PCD_NEUTRAL`/`GARDEN_CA_NEUTRAL` for momentum,
  `GARDEN_PCH_NEUTRAL`/`GARDEN_CAH_NEUTRAL` for heat and moisture, of
  `src/src_proxi_SVAT/garden.F90`): `PCD = PCDN`, `PCH = PCDN*ZFH`, `PRI_GARDEN_*`
  keeps `XUNDEF`, `ZZ0H_GARDEN_*` is the thermal roughness used, and
  `PAC_GARDEN_CAN` equals `EMU_CA_CAN` of the emulator exactly. This is the mode
  in which the exported coefficients and the emulated model are consistent
  (`'EXT'` includes stratification in the export while the emulator does not).


### Greenroof output columns and the emulator of the external greenroof

The greenroof is a **roof** surface: it exchanges with the air of the forcing level
only, so it has a single exchange path (no canyon branch, no tau split).

| Column | Dimension | Comment |
|:-------|:----------|:--------|
| `TS_GREENROOF`, `RN_GREENROOF`, `H_GREENROOF`, `LE_GREENROOF` | K, W/m² | Surface temperature and net radiation / sensible / latent heat flux per m² of greenroof |
| `EVAP_GREENROOF`, `QSAT_GREENROOF`, `PHU_GREENROOF` | kg/m²/s, kg/kg, - | Evaporation, saturation specific humidity at `TS_GREENROOF` and aggregated relative humidity of the surface (for `'EXT'`/`'EXT_NEU'` it is
`clamp(q_v/qsat(TS_GREENROOF))` built from the host surface humidity `teb_qs_gr`; `PHU_GREENROOF`
is a diagnostic only -- it enters no budget, unlike `PHU_GARDEN`) |
| `PAC_GREENROOF` | m/s | Aerodynamic conductance of the greenroof (the scalar coefficient `PCH` times `max(V, Vmin)` of the selected greenroof model: `ZCA_GR` for `'PROXY_NEW'`, `0` for `'PROXY_OLD'`/`'EXT'`/`'EXT_NEU'` and when the greenroof is off). Diagnostic only: it enters no equation |
| `PAC_GREENROOF_ATM`, `PCD_GREENROOF_ATM`, `PCDN_GREENROOF_ATM`, `PCH_GREENROOF_ATM` | m/s, -, -, - | Greenroof/atmosphere coefficients computed by `URBAN_DRAG` in the external modes: conductance, momentum coefficient, neutral momentum coefficient and thermal coefficient |
| `PRI_GREENROOF_ATM` | - | Richardson number of the greenroof/atmosphere exchange (`XUNDEF` in `'EXT_NEU'`, whose coefficients are neutral) |
| `ZZ0H_GREENROOF_ATM` | m | Thermal roughness used (`z0/urb_z0_o_z0h_grf`) |

**External greenroof model (emulator).** With `teb_type_greenroof = 'EXT'` (or
`'EXT_NEU'`) the greenroof is prescribed from the outside. In the offline driver the
external model is EMULATED by the contained subroutine `PCD_GREENROOF` (the same
diagnostic balance `GARDEN_PCD` as the internal greenroof, with a single path). The
following columns are written only in these modes:

| Column | Dimension | Comment |
|:-------|:----------|:--------|
| `EMU_GR_CD`, `EMU_GR_CH`, `EMU_GR_CA` | -, -, m/s | Neutral momentum coefficient, neutral thermal coefficient and thermal conductance `PCH*max(V,Vmin)` given to the external model |
| `EMU_GR_V`, `EMU_GR_T`, `EMU_GR_Q` | m/s, K, kg/kg | The one complete set (wind, air) given to the external model: the wind of the forcing level floored at `XVMIN_GD` and its air (`Forc_TA`, `Forc_QV`) |
| `EMU_GR_PSW`, `EMU_GR_PLW` | W/m² | Short-wave and long-wave radiation received by the roof, `(Forc_DIR+Forc_SCA)*(1-frac_panel)` and `Forc_LW*(1-frac_panel)` (a roof is not shadowed by the canyon) |
| `EMU_GR_TS`, `EMU_GR_RN`, `EMU_GR_H`, `EMU_GR_LE`, `EMU_GR_EVAP` | K, W/m², W/m², W/m², kg/m²/s | State and fluxes returned by the external model, prescribed to TEB at the next sub-step (one output row behind `TS_GREENROOF`, `H_GREENROOF`, `LE_GREENROOF`, `EVAP_GREENROOF`) |

Because there is a single exchange path there is no covariance correction:
`EMU_GR_CH*max(EMU_GR_V,Vmin) = EMU_GR_CA` exactly, and in `'EXT_NEU'`
`EMU_GR_CD = PCD_GREENROOF_ATM`, `EMU_GR_CH = PCH_GREENROOF_ATM` and
`EMU_GR_CA = PAC_GREENROOF_ATM` (in `'EXT'` the exported coefficients carry the
Richardson-number correction of `URBAN_EXCH_COEF` while the emulator keeps its
neutral ones). The coupling is validated by
`python_tests/greenroof_emu_compare.py`.


**Interaction with the cbs scheme of the road.** With `teb_lcbs_scheme = .TRUE.` and
`teb_type_garden = 'PROXY_NEW'` the garden exchange is split in exactly the same way
as the road one: the tau-aggregated conductance and reference air feed the diagnostic
surface energy balance (`Ca_eff = tau*Ca_canyon + (1-tau)*Ca_atmosphere`,
`T_ref = (tau*Ca_canyon*T_canyon + (1-tau)*Ca_atmosphere*PTA)/Ca_eff`, the same for
`q_ref`), so that the actual flux is identically
`H_GARDEN = tau*H_GARDEN_CAN + (1-tau)*H_GARDEN_ATM` (and the same for `LE_GARDEN`),
the canyon branch uses the low canyon air at the height `H/2` and the atmosphere
branch the wind `PVMOD` at `PUREF` with the air `PTA`/`PQA`. The canyon branch feeds
`T_CAN0`, the atmosphere branch feeds the free layer `T_CAN1`, and both branches are
computed from the single garden surface temperature. With `'PROXY_OLD'` (the
prescribed Bowen proxy does not depend on the meteorological forcing) and with
`'EXT'` (a single set of fluxes, already computed for the averaged forcing) both
branches are set equal to the actual flux, so the cbs scheme does not change them.
See `TEB_Ru_garden_diagnostic_scheme.md` (section 2.3) and
`TEB_Ru_cbs_scheme_T_CAN_reformulation.md` (sections 4.3 and 4.7).


### Solar Panels

| Variable | Type | Dimension/Value | Comment |
|:---------|:-----|:----------------|:--------|
| `teb_lsolar_panel` | Flag | True / False | Activate solar panel module |
| `teb_fr_panel` | External parameter | - | Solar panel fraction on roofs |

### Street Watering

| Variable | Type | Dimension/Value | Comment |
|:---------|:-----|:----------------|:--------|
| `teb_lroad_irrig` | Flag | True / False | Activate street watering module |
| `teb_rd_irrig_start_m` | External parameter | - | Start month for watering |
| `teb_rd_irrig_end_m` | External parameter | - | End month for watering |
| `teb_rd_irrig_start_h` | External parameter | - | Start hour for watering |
| `teb_rd_irrig_end_h` | External parameter | - | End hour for watering |
| `teb_rd_irrig_sum` | External parameter | liter/m² | 24-hour water amount for road watering |

---

## Output Variables

The model writes all its output variables to a single file
`<output_dir>/TEB_output.csv` (semicolon-separated, one line per forcing step).
Column 1 is the time of the model state, then the model variables, then the
atmospheric forcing used by the model at that step (`Forc_*`).

### Time column

| Column | Dimension | Comment |
|:-------|:----------|:--------|
| `time` | ISO 8601 (UTC) | Time of the model state, i.e. the end of the forcing interval: `t0 + n * forc_step` |

The file has `nsteps - 1` lines, where `t0` = `teb_year`/`teb_month`/`teb_day` and
`teb_hour`/`teb_min` from the forcing namelist. The initial state at `t0` is a model
input (namelist `teb_ti_bld`, `teb_qi_bld`, ... and the internal TEB initialization),
it is not a computed step and is therefore not written. With the default namelists
(`forc_step = 1800 s`) the first line is `2004-02-20 00:30:00`.

<!-- MV202609 strict namelist date/time reading -->
#### Start date and time of a run (forcing namelist)

`teb_year`, `teb_month`, `teb_day`, `teb_hour`, `teb_min` and `nsteps` are **INTEGER**
namelist items: write them **without a decimal point** (`teb_hour = 0`, not
`teb_hour = 0.0`). With a real value the namelist `READ` fails at that entry and every
item that follows it in the file keeps the value of the program, i.e. the run would
silently use another date (and therefore another solar position and building calendar).
The driver therefore

* **stops with an error when a namelist cannot be read** - for both groups,
  `/tebforcing/` and `/tebparam/` (no warning-and-continue, no silent defaults): the
  log lists every declared item of the failing group with its line number and its
  state (read / not read / not in the file) and reports the **first line at which the
  READ fails**; the items that are not present in the file are reported separately
  with the notice that the driver default is used for them;
* has **no default date** any more: a run without a valid start date/time (item missing
  from the file, not read, or out of range) stops with an error;
* checks `nsteps >= 2`, `forc_step > 0`, `dt > 0` and `forc_step/dt` integer;
* echoes the start date, the end date of the run (`start + (nsteps-1)*forc_step`), the
  forcing window and the timestamp of the first output line in its log.

### Model variables

| Variable | Dimension | Comment |
|:---------|:-----------|:--------|
| `T_CANYON` | K | Canyon air temperature |
| `Q_CANYON` | kg/kg | Canyon air specific humidity |
| `U_CANYON` | m/s | Canyon wind speed |
| `P_CANYON` | Pa | Atmospheric pressure at the surface |
| `T_ROOF1` | K | Roof surface temperature |
| `T_ROAD1` | K | Road surface temperature |
| `T_WALLA1` | K | Wall A surface temperature |
| `T_WALLB1` | K | Wall B surface temperature |
| `TI_BLD` | K | Indoor air temperature |
| `H_TOWN` | W/m² | Sensible heat flux from urban canyon |
| `LE_TOWN` | W/m² | Latent heat flux from urban canyon |
| `RN_TOWN` | W/m² | Net radiation of urban canyon effective surface |
| `WIND_TOP` | m/s | Wind speed at the canyon top |
| `HVAC_COOL` | W/m²(building) | Cooling energy consumption |
| `HVAC_HEAT` | W/m²(building) | Heating energy consumption |
| `SOLAR_PROD` | W/m²(building) | Average solar panel energy production |

`HVAC_COOL` and `HVAC_HEAT` are written only with the Building Energy Model
(`teb_itype_bem = 'BEM'`); `SOLAR_PROD` is written only when the solar panels module is
activated (`teb_lsolar_panel = .TRUE.`). The set of columns therefore depends on the
model options of the run.

<!-- MV202609 solar position diagnostics -->
### Solar position (`SOLAR_*` columns)

The position of the sun that the physics of the step used, computed by `SUNPOS` from
the date of the run at the **last model sub-step** of the forcing interval, i.e. at the
timestamp of the output line.

| Variable | Dimension | Comment |
|:---------|:-----------|:--------|
| `SOLAR_ZENITH` | ° | Zenith angle of the sun (from the vertical; > 90° at night) |
| `SOLAR_ELEV` | ° | Elevation above the horizon (`90 - SOLAR_ZENITH`, negative at night) |
| `SOLAR_AZIM` | ° | Azimuth, measured clockwise from the north (0-360°) |

These columns make the date of the run verifiable from the output itself: the maximum
elevation of the day is a strong function of the season (Moscow: ~52° on 1 August, ~11°
on 1 January). They are checked against the `pysolar` library with

```bash
python python_tests/check_solar_position.py <output_dir>/TEB_output.csv --forcing-nml <forcing namelist>
```

which validates the internal consistency of the angles, the elevation and azimuth
against pysolar, the daily maximum and the day length, and (test 5) that the first
timestamp of the CSV is the start date of the forcing namelist plus one forcing step.

### Atmospheric forcing (`Forc_*` columns)

The forcing the model used at the current step: the interpolated forcing of the last
model sub-step `dt` of the forcing interval (i.e. at `time - dt`).

| Variable | Dimension | Comment |
|:---------|:-----------|:--------|
| `Forc_TA` | K | Air temperature |
| `Forc_QA` | kg/m³ | Air humidity as read from the forcing file (TEB converts it: `qv = QA / rho`) |
| `Forc_QV` | kg/kg | Air specific humidity as passed to TEB |
| `Forc_U`, `Forc_V` | m/s | Zonal and meridional wind components (`u = WIND*sin(DIR)`, `v = WIND*cos(DIR)`) |
| `Forc_WIND` | m/s | Wind speed, `sqrt(u² + v²)` |
| `Forc_DIR` | ° | Wind direction from North, clockwise (`atan2(u, v)`), as in `Forc_DIR.txt` |
| `Forc_PS` | Pa | Pressure at the forcing level (not the model surface pressure `P_CANYON`) |
| `Forc_RHOA` | kg/m³ | Air density at the forcing level |
| `Forc_RAIN`, `Forc_SNOW` | kg/m²/s | Liquid and snow precipitation |
| `Forc_LW` | W/m² | Downward longwave radiation |
| `Forc_DIR_SW`, `Forc_SCA_SW` | W/m² | Direct and diffuse shortwave radiation |

Reading the output with the Python utilities
([`python/output_utils.py`](../python/output_utils.py)):

```python
import output_utils

df = output_utils.read_output('output/')                        # TEB_output.csv
df = output_utils.read_output('output_old/', fmt='txt',         # legacy <VAR>.txt files
                              namelist_path='namelist/namelist_forcing.nml')
df = output_utils.read_output('output/', include_forcing=False)  # model variables only
```

---

## Notes

- **External parameters**: Set in namelist files and remain constant during simulation
- **Control variables**: Enable/disable specific model features
- **Flags**: Boolean switches for module activation
- **Prognostic variables**: Evolve over time during the simulation
- **Output variables**: Model results written to output files

For more information, see the model documentation and the original TEB references.
