# TEB-MSU Model Variables Description

**Contents**

- [1. Namelist variables](#1-namelist-variables)
  - [1.1 tebopts](#11-tebopts)
  - [1.2 tebparams](#12-tebparams)
    - [1.2.1 Basic Building Characteristics](#121-basic-building-characteristics)
    - [1.2.2 Urban Aerodynamics](#122-urban-aerodynamics)
    - [1.2.3 Surface Properties](#123-surface-properties)
    - [1.2.4 Building Energy Model (BEM)](#124-building-energy-model-bem)
    - [1.2.5 Anthropogenic Heat Fluxes](#125-anthropogenic-heat-fluxes)
    - [1.2.6 CBS Exchange Parameters](#126-cbs-exchange-parameters)
    - [1.2.7 Wind Inside Urban Canopy](#127-wind-inside-urban-canopy)
    - [1.2.8 Green Infrastructure](#128-green-infrastructure)
    - [1.2.9 Solar Panels](#129-solar-panels)
    - [1.2.10 Street Watering](#1210-street-watering)
  - [1.3 tebforcing](#13-tebforcing)
- [2. Parameter notes](#2-parameter-notes)
  - [2.1 Input rules](#21-input-rules)
  - [2.2 Initial conditions and BEM](#22-initial-conditions-and-bem)
  - [2.3 Urban Aerodynamics](#23-urban-aerodynamics)
  - [2.4 CBS and Canopy Wind](#24-cbs-and-canopy-wind)
  - [2.5 Garden and Greenroof Schemes](#25-garden-and-greenroof-schemes)
  - [2.6 Solar Panels and Road Watering](#26-solar-panels-and-road-watering)
  - [2.7 Snowfall Filter](#27-snowfall-filter)
  - [2.8 Emissivity and Longwave Albedo](#28-emissivity-and-longwave-albedo)
- [3. Output variables](#3-output-variables)
  - [3.1 Files and Time Sampling](#31-files-and-time-sampling)
  - [3.2 Main Model Diagnostics](#32-main-model-diagnostics)
  - [3.3 Surface Exchange Diagnostics](#33-surface-exchange-diagnostics)
  - [3.4 Garden and Greenroof Outputs](#34-garden-and-greenroof-outputs)
  - [3.5 Mean Radiant Temperature](#35-mean-radiant-temperature)
  - [3.6 Solar Position](#36-solar-position)
  - [3.7 Atmospheric Forcing](#37-atmospheric-forcing)
  - [3.8 External Surface Emulators](#38-external-surface-emulators)
  - [3.9 Runoff](#39-runoff)
  - [3.10 Reading CSV Output](#310-reading-csv-output)

## 1. Namelist variables

This reference describes the current `src_dev` offline model. Defaults are the
values used by its namelist reader when an entry is omitted; initialization
expressions are explained in [§2.2](#22-initial-conditions-and-bem).

The model file contains `&tebopts` and `&tebparams`; the forcing file contains
`&tebforcing`. Options and atmospheric forcing are common to all cells.
In the `List` column, ✓ means one value for the whole block or exactly `nvec`
values in input-cell order. A — means no per-cell list. `teb_fai` always takes
eight directional values shared by every cell.

### 1.1 tebopts

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `nvec` | Integer | >= 1 | `1` | — | Number of cells in the block. |
| `dt` | Real | s | `300` | — | Model timestep; `forc_step/dt` must be an integer. |
| `teb_lbem_ac` | Logical | True / False | `.TRUE.` | — | Enable building air conditioning. |
| `teb_lgarden` | Logical | True / False | `.TRUE.` | — | Enable the garden surface. |
| `teb_lgreenroof` | Logical | True / False | `.FALSE.` | — | Enable the greenroof surface. |
| `teb_lsolar_panel` | Logical | True / False | `.FALSE.` | — | Enable solar panels. |
| `teb_lroad_irrig` | Logical | True / False | `.FALSE.` | — | Enable road watering; [schedule](#26-solar-panels-and-road-watering). |
| `teb_lshade` | Logical | True / False | `.TRUE.` | — | Enable window shading. |
| `teb_lcbs_scheme` | Logical | True / False | `.FALSE.` | — | Enable CBS exchange; [scheme notes](#24-cbs-and-canopy-wind). |
| `teb_snow_check` | Logical | True / False | `.FALSE.` | — | Filter weak snowfall when forming snow cover; [snow filter](#27-snowfall-filter). |
| `teb_ctype_bem` | Character | `'BEM'` / `'DEF'` | `'BEM'` | — | Building energy scheme; [BEM notes](#22-initial-conditions-and-bem). |
| `teb_ctype_natvent` | Character | `'NONE'` / `'MANU'` / `'AUTO'` / `'MECH'` | `'NONE'` | — | Natural ventilation mode. |
| `teb_ctype_bem_cool` | Character | `'IDEAL'` / `'DXCOIL'` | `'IDEAL'` | — | Cooling system type. |
| `teb_ctype_bem_heat` | Character | `'IDEAL'` / `'FINCAP'` | `'IDEAL'` | — | Heating system type. |
| `teb_ctype_wind` | Character | `'DEF'` / `'WANG'` | `'DEF'` | — | Canopy wind scheme; [wind notes](#24-cbs-and-canopy-wind). |
| `teb_ctype_garden` | Character | `'PROXY_NEW'` / `'PROXY_OLD'` / `'EXT'` / `'EXT_NEU'` | `'PROXY_NEW'` | — | [Garden scheme](#25-garden-and-greenroof-schemes). |
| `teb_ctype_greenroof` | Character | `'PROXY_NEW'` / `'PROXY_OLD'` / `'EXT'` / `'EXT_NEU'` | `'PROXY_NEW'` | — | [Greenroof scheme](#25-garden-and-greenroof-schemes). |
| `teb_hroad_dir` | Character | `'UNIF'` / `'ORIE'` | `'UNIF'` | — | Uniform road orientations or the specified canyon azimuth. |
| `teb_wall_opt` | Character | `'UNIF'` / `'TWO'` | `'UNIF'` | — | One wall energy balance or two opposite walls. |
| `teb_lwrite_output` | Logical | True / False | `.TRUE.` | — | Write the main per-cell CSV; [files](#31-files-and-time-sampling). |
| `teb_lwrite_emu` | Logical | True / False | `.TRUE.` | — | Write external-surface emulator CSV. |
| `teb_lwrite_runoff` | Logical | True / False | `.TRUE.` | — | Write interval-mean road and roof runoff. |
| `teb_lwrite_test_dump` | Logical | True / False | `.FALSE.` | — | Write full API input/output dumps and their schema. |

### 1.2 tebparams

#### 1.2.1 Basic Building Characteristics

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `urb_h_bld` | Real | m | `20` | ✓ | Average building/canyon height. |
| `urb_fr_bld` | Real | 1 | `0.62` | ✓ | Building plan-area fraction. |
| `urb_h2w` | Real | 1 | `1.38158` | ✓ | Canyon height-to-width ratio. |
| `teb_road_dir` | Real | ° | `0.0` | ✓ | Canyon azimuth for `teb_hroad_dir='ORIE'`. |
| `teb_ti_bld_init` | Real | K | `teb_tcool_target` | ✓ | Initial indoor temperature; [initialization](#22-initial-conditions-and-bem). |
| `teb_qi_bld_init` | Real | kg/kg | `0.5*qsat(T_init, ps)` | ✓ | Initial indoor specific humidity; [initialization](#22-initial-conditions-and-bem). |

#### 1.2.2 Urban Aerodynamics

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `urb_z0_town` | Character | m, height expression or scheme name | `'0.1H'` | — | Town momentum roughness; [accepted forms](#23-urban-aerodynamics). |
| `urb_zd_town` | Character | m, height expression or scheme name | `'H/3'` | — | Town displacement height; [accepted forms](#23-urban-aerodynamics). |

#### 1.2.3 Surface Properties

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `urb_alb_rf_so` | Real | 1 | `0.40` | ✓ | Roof shortwave albedo. |
| `urb_alb_rf_th` | Real | 1 | `0.03` | ✓ | Roof longwave albedo; [alternative to emissivity](#28-emissivity-and-longwave-albedo). |
| `urb_emis_rf` | Real | 1 | `0.97` | ✓ | Roof emissivity; [input rule](#28-emissivity-and-longwave-albedo). |
| `urb_hcap_rf` | Real | J/(m³ K) | `1580000` | ✓ | Roof material volumetric heat capacity. |
| `urb_hcon_rf` | Real | W/(m K) | `1.15` | ✓ | Roof material thermal conductivity. |
| `urb_alb_rd_so` | Real | 1 | `0.08` | ✓ | Road shortwave albedo. |
| `urb_alb_rd_th` | Real | 1 | `0.04` | ✓ | Road longwave albedo; [alternative to emissivity](#28-emissivity-and-longwave-albedo). |
| `urb_emis_rd` | Real | 1 | `0.96` | ✓ | Road emissivity; [input rule](#28-emissivity-and-longwave-albedo). |
| `urb_hcap_rd` | Real | J/(m³ K) | `1740000` | ✓ | Road material volumetric heat capacity. |
| `urb_hcon_rd` | Real | W/(m K) | `0.82` | ✓ | Road material thermal conductivity. |
| `urb_alb_wl_so` | Real | 1 | `0.32` | ✓ | Wall shortwave albedo. |
| `urb_alb_wl_th` | Real | 1 | `0.03` | ✓ | Wall longwave albedo; [alternative to emissivity](#28-emissivity-and-longwave-albedo). |
| `urb_emis_wl` | Real | 1 | `0.97` | ✓ | Wall emissivity; [input rule](#28-emissivity-and-longwave-albedo). |
| `urb_hcap_wl` | Real | J/(m³ K) | `1580000` | ✓ | Wall material volumetric heat capacity. |
| `urb_hcon_wl` | Real | W/(m K) | `1.15` | ✓ | Wall material thermal conductivity. |

#### 1.2.4 Building Energy Model (BEM)

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `teb_frac_gz` | Real | 1 | `0.1` | ✓ | Glazing fraction. |
| `teb_tcool_target` | Real | K | `297.16` | ✓ | Cooling setpoint. |
| `teb_theat_target` | Real | K | `292.16` | ✓ | Heating setpoint. |
| `teb_zresidential` | Real | 1 | `1` | ✓ | Residential fraction of building use. |
| `teb_dt_res` | Real | K | `3` | ✓ | Unoccupied residential temperature offset. |
| `teb_dt_off` | Real | K | `3` | ✓ | Unoccupied office temperature offset. |
| `teb_bem_inf` | Real | air changes/h | `0.5` | ✓ | Infiltration rate. |
| `teb_bem_vent` | Real | air changes/h | `0.0` | ✓ | Ventilation rate. |
| `teb_bem_cop` | Real | 1 | `2.5` | ✓ | Nominal cooling coefficient of performance. |
| `teb_cap_sys_rat` | Real | W/m²(floor) | `100` | ✓ | Initial rated cooling capacity for `DXCOIL`; [BEM initialization](#22-initial-conditions-and-bem). |
| `teb_m_sys_rat` | Real | kg/(m²(building) s) | `0.0067` | ✓ | Initial rated HVAC mass-flow parameter; [BEM initialization](#22-initial-conditions-and-bem). |
| `teb_cap_sys_heat` | Real | W/m²(building) | `90` | ✓ | Heating system capacity. |

#### 1.2.5 Anthropogenic Heat Fluxes

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `ahf_traffic` | Real | W/m² | `0.0` | ✓ | Traffic sensible heat-flux parameter. |
| `ahf_industry` | Real | W/m² | `0.0` | ✓ | Industrial sensible heat-flux parameter. |
| `teb_utc_hour` | Integer | h | `3` | — | Time-zone offset for the traffic daily cycle. |

#### 1.2.6 CBS Exchange Parameters

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `teb_tau_hw_thresh` | Real | 1 | `0.5` | — | Canyon H/W at CBS canyon-path weight 0.5; [CBS notes](#24-cbs-and-canopy-wind). |
| `teb_tau_hw_width` | Real | 1 | `0.25` | — | Width of the CBS transition in H/W; [CBS notes](#24-cbs-and-canopy-wind). |

#### 1.2.7 Wind Inside Urban Canopy

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `teb_fai` | Real | 1 | `0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5` | — | Eight directional frontal-area indices; [wind notes](#24-cbs-and-canopy-wind). |

#### 1.2.8 Green Infrastructure

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `fr_garden` | Real | 1 | `0.2` | ✓ | Garden area fraction. |
| `urb_z0_gdn` | Real | m | `0.1` | ✓ | Garden momentum roughness; [surface properties](#25-garden-and-greenroof-schemes). |
| `urb_z0_o_z0h_gdn` | Real | >= 1 | `4.0` | — | Garden momentum/thermal roughness ratio. |
| `urb_alb_gdn` | Real | 1 | `0.15` | ✓ | Garden albedo. |
| `urb_emis_gdn` | Real | 1 | `0.98` | ✓ | Garden emissivity. |
| `teb_frac_gr` | Real | 1 | `0.0` | ✓ | Greenroof fraction of roofs. |
| `urb_z0_grf` | Real | m | `0.01` | ✓ | Greenroof momentum roughness. |
| `urb_alb_grf` | Real | 1 | `0.15` | ✓ | Greenroof albedo. |
| `urb_emis_grf` | Real | 1 | `0.98` | ✓ | Greenroof emissivity. |
| `urb_z0_o_z0h_grf` | Real | >= 1 | `4.0` | — | Greenroof momentum/thermal roughness ratio. |
| `proxy_phu_gdn` | Real | 0 < PHU <= 1 | `0.7` | — | Garden proxy surface relative humidity. |
| `proxy_phu_grf` | Real | 0 < PHU <= 1 | `0.7` | — | Greenroof proxy surface relative humidity. |

#### 1.2.9 Solar Panels

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `teb_fr_panel` | Real | 1 | `0` | ✓ | Solar-panel fraction of roofs; [panel notes](#26-solar-panels-and-road-watering). |

#### 1.2.10 Street Watering

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `teb_rd_irrig_start_m` | Real | month | `6` | ✓ | First watering month, included. |
| `teb_rd_irrig_end_m` | Real | month | `8` | ✓ | Last watering month, included. |
| `teb_rd_irrig_start_h` | Real | h | `6` | ✓ | Daily watering start hour, included. |
| `teb_rd_irrig_end_h` | Real | h | `9` | ✓ | Daily watering end hour, excluded. |
| `teb_rd_irrig_sum` | Real | L/m²/day | `1` | ✓ | Daily road-watering amount; [schedule](#26-solar-panels-and-road-watering). |

### 1.3 tebforcing

| Variable | Type | Units / values | Default | List | Description |
| --- | --- | --- | --- | --- | --- |
| `forcing_path` | Character | path | Required | — | Directory containing the ASCII forcing files. |
| `lon_teb` | Real | ° east | `1.3` | — | Longitude. |
| `lat_teb` | Real | ° north | `43.484` | — | Latitude. |
| `hlev_teb` | Real | m | `28` | — | Atmospheric forcing reference height above roof level. |
| `teb_year` | Integer | year | Required | — | UTC start year. |
| `teb_month` | Integer | 1–12 | Required | — | UTC start month. |
| `teb_day` | Integer | day | Required | — | UTC start day. |
| `teb_hour` | Integer | 0–23 | Required | — | UTC start hour. |
| `teb_min` | Integer | 0–59 | Required | — | UTC start minute. |
| `nsteps` | Integer | >= 2 | Required | — | Number of forcing records; [time sampling](#31-files-and-time-sampling). |
| `forc_step` | Real | s | `1800` | — | Forcing interval; a positive integer multiple of `dt`. |

## 2. Parameter notes

### 2.1 Input rules

The model namelist must contain `&tebparams`. Omitted `&tebopts` entries use
their defaults. Scheme selectors are common to the block and use the uppercase
names shown in the tables.

For list-enabled parameters, supply one literal or exactly `nvec` literals.
Repetition syntax (`3*10.`), missing elements (`,,`), indexed assignments,
duplicate keys/groups and incorrect list lengths are rejected in the model
namelist. Comments, line breaks and a trailing comma are allowed.

In `&tebforcing`, write integer items without a decimal point
(`teb_hour=0`). Supply a valid UTC start date/time and at least two records.
Use finite physical values and a positive `dt` with integer `forc_step/dt`.

### 2.2 Initial conditions and BEM

Initial conditions are applied once per cell at the first model step.
If `teb_ti_bld_init` is omitted, it takes the cell's `teb_tcool_target`.
If `teb_qi_bld_init` is omitted, it is set to `0.5*qsat(T_init, ps)` using
the initial indoor temperature and first forcing pressure. Initial indoor
temperature also anchors the building's cold-start material temperatures.

`teb_ctype_bem='BEM'` enables the building energy model. With `'DEF'`,
set `teb_frac_gz=0`. The shading, air-conditioning and ventilation switches
apply to BEM. `IDEAL` selects ideal cooling/heating; `DXCOIL` selects a
direct-expansion cooling coil, and `FINCAP` selects finite-capacity heating.

The capacity and mass-flow entries initialize BEM state. During cold start,
cooling capacity is scaled by the number of floors and the rated HVAC mass
flow is initialized to `0.0067 kg/(m²(building) s)`; the model can subsequently
update these state variables.

### 2.3 Urban Aerodynamics

`urb_z0_town` and `urb_zd_town` accept the following case-insensitive forms,
with `H=urb_h_bld`. Each entry is resolved independently.

| Form | Example | Meaning |
| --- | --- | --- |
| Metres | `'0.5'` or `'0.5m'` | A fixed length in metres. |
| Fraction of height | `'0.1H'` | 0.1 times the building height. |
| Height divided by a number | `'H/3'` | One third of the building height. |
| Staggered-array scheme | `'MACDONALD1998'` | Macdonald et al. roughness/displacement parameterization. |
| Square-array scheme | `'MACDONALD1998SQ'` | Square-array coefficients of the same parameterization. |

A fixed value can be combined with a scheme name in the other entry.
Displacement height is measured from road level. The town drag coefficient
determines `USTAR_TOWN` and supplies the friction velocity used by the Wang
wind scheme.

### 2.4 CBS and Canopy Wind

CBS partitions road/garden exchange between canyon and atmosphere paths.
`teb_tau_hw_thresh` sets the canyon H/W giving a canyon-path weight of 0.5;
`teb_tau_hw_width` sets the transition width. See the
[CBS scheme description](TEB_MSU_CBS_scheme_T_CAN_reformulation.md).

`DEF` selects the basic canopy wind scheme. `WANG` selects the Wang (2012)
profile: `U_CANYON` is evaluated at half building height, and `U_CAN_PED` /
`U_CAN_10M` at 1.1 m / 10 m above the road. These height-specific outputs are
undefined above roof level. `teb_fai` is one set of eight directional indices
shared by the entire block, including when `nvec=8`.

### 2.5 Garden and Greenroof Schemes

The selectors apply when the corresponding `teb_lgarden` or
`teb_lgreenroof` switch is true.

| Value | Garden | Greenroof |
| --- | --- | --- |
| `'PROXY_NEW'` | Diagnostic surface energy balance for surface temperature. | Diagnostic surface energy balance at roof level. |
| `'PROXY_OLD'` | Shortwave-driven fixed Bowen ratio 0.25. | Shortwave-driven fixed Bowen ratio 1.0. |
| `'EXT'` | Prescribed external state/fluxes; stability-dependent exchange diagnostics. | Prescribed external state/fluxes; stability-dependent roof exchange diagnostics. |
| `'EXT_NEU'` | Prescribed external state/fluxes; neutral exchange diagnostics. | Prescribed external state/fluxes; neutral roof exchange diagnostics. |

The offline driver emulates the external surfaces. Their updated state is
used by TEB on the next model substep; `EXT_NEU` exposes the neutral
coefficients used by these emulators. The garden exchanges with canyon air
and, with CBS, with the atmosphere; the greenroof exchanges at roof level.

Surface albedo, emissivity and momentum roughness apply to the selected
surface model. Thermal roughness is `z0h=z0/(z0/z0h)`. Roughness must be
positive, albedo must be in `[0,1)`, emissivity in `(0,1]` and `z0/z0h>=1`.
The `proxy_phu_*` inputs prescribe surface humidity for the internal proxies
and their offline external-surface emulators.

See the [garden and greenroof scheme description](TEB_MSU_garden_diagnostic_scheme.md)
for exchange paths and surface budgets.

### 2.6 Solar Panels and Road Watering

Solar panels are enabled by `teb_lsolar_panel` with roof coverage
`teb_fr_panel`. `SOLAR_PROD` is reported when this switch is enabled.

Road watering requires `teb_lroad_irrig=.TRUE.`. The start/end months are
included; the daily hour interval includes its start and excludes its end.
`teb_rd_irrig_sum` is the daily amount per unit road area.

### 2.7 Snowfall Filter

With `teb_snow_check=.TRUE.`, snowfall below
`XTEB_SNOW_RATE_MIN=1.e-8 kg/(m² s)` does not create a new snow cover on a bare
road or roof. An existing snow cover receives the full snowfall rate.

### 2.8 Emissivity and Longwave Albedo

For each built surface, choose either `urb_emis_*` or `urb_alb_*_th`.
Supplying both is an error. The driver computes the other quantity from
`albedo=1-emissivity`. If both are omitted, the table defaults apply.
Emissivity must be in `(0,1]`; longwave albedo must be in `[0,1)`.

## 3. Output variables

### 3.1 Files and Time Sampling

CSV files use a semicolon separator and a header row. `B` is the block
number and `C` the cell ID in input order. IDs remain stable through a
diagnostic permutation; inactive cells produce no computed output.

| File | Contents |
| --- | --- |
| `TEB_output_b<B>_c<C>.csv` | Main model diagnostics, solar position and forcing. |
| `TEB_emu_b<B>_c<C>.csv` | External-surface emulator diagnostics. |
| `TEB_runoff_b<B>_c<C>.csv` | Interval-mean road/roof runoff. |
| `cells.csv` | Cell IDs, storage positions and activity. |
| `parameters.csv` | Expanded per-cell configuration at the start of a run segment. |
| `fields.csv` / `records.bin` | Optional schema and full-precision API before/after dump. |

For one block with one cell, emulator/runoff files are `TEB_emu.csv` and
`TEB_runoff.csv`. The main model file includes the block/cell suffix.

All CSV streams use the forcing interval `forc_step`. The `time` column is
the end of the interval in UTC: `t0 + k*forc_step`. A complete file-forcing
run writes `nsteps-1` rows; the initial state at `t0` is not an output row.
Main diagnostics are sampled after the model call, emulator diagnostics
after the external-surface update, and runoff is averaged over substeps.

Restart writes a separate segment and preserves timestamps, cell IDs and
partly accumulated runoff. Join segments with one CSV header.
Undefined values are marked `XUNDEF`; coefficients of disabled paths can be zero.

### 3.2 Main Model Diagnostics

| Column | Units | Meaning |
| --- | --- | --- |
| `time` | UTC timestamp | Model-state time at the end of the forcing interval. |
| `T_CANYON`, `Q_CANYON`, `P_CANYON` | K; kg/kg; Pa | Canyon air temperature, specific humidity and surface pressure. |
| `U_CANYON`, `U_CAN_PED`, `U_CAN_10M` | m/s | [Canopy wind outputs](#24-cbs-and-canopy-wind); with `DEF` all three equal `U_CANYON`. |
| `T_ROOF1`, `T_ROAD1`, `T_WALLA1`, `T_WALLB1` | K | Surface temperatures of roof, road and both walls. |
| `TI_BLD` | K | Indoor air temperature. |
| `H_TOWN`, `LE_TOWN`, `RN_TOWN` | W/m² | Town sensible/latent heat flux and net radiation. |
| `WIND_TOP`, `USTAR_TOWN` | m/s | Canopy-top wind diagnostic and town friction velocity. |
| `ALB_TOWN`, `EMIS_TOWN` | 1 | Effective town shortwave albedo and emissivity. |
| `Z0_TOWN` | m | Resolved town momentum roughness. |
| `HVAC_COOL`, `HVAC_HEAT` | W/m²(building) | BEM cooling/heating energy consumption; written with `BEM`. |
| `SOLAR_PROD` | W/m²(building) | Solar-panel energy production; written when panels are enabled. |
| `AHF_TRAFFIC` | W/m² | Traffic sensible heat flux after its daily modulation. |
| `H_WASTE`, `LE_WASTE` | W/m² | Building sensible and latent waste heat. |
| `GFLUX_TOWN` | W/m² | Town ground/conduction heat-flux diagnostic. |
| `T_CAN0`, `T_CAN1` | K | CBS canyon and free-layer air temperatures. |
| `PHI_CAN1` | 1 | MOST profile factor used to diagnose the free-layer temperature. |
| `H_ROAD`, `LE_ROAD` | W/m²(road) | Road sensible and latent heat fluxes. |
| `H_ROAD_CAN`, `H_ROAD_ATM`, `LE_ROAD_CAN`, `LE_ROAD_ATM` | W/m²(road) | CBS road branch heat fluxes. |
| `WS_ROAD`, `WS_ROOF` | kg/m² | Road and roof liquid-water reservoirs. |
| `WSNOW_RD`, `WSNOW_RF` | kg/m² | Water-equivalent snow mass in the top road/roof snow layer. |
| `TSNOW_RD` | K | Top road-snow layer temperature. |
| `PDN_RD`, `PDN_RF` | 0–1 | Road and roof snow-covered fractions. |
| `LE_ROAD_WAT`, `LE_ROOF_WAT` | W/m² | Latent heat fluxes from liquid-water reservoirs. |
| `LE_ROAD_SNOW`, `LE_ROOF_SNOW` | W/m² | Latent heat fluxes over snow. |

### 3.3 Surface Exchange Diagnostics

`CAN` denotes the canyon exchange path and `ATM` the direct atmospheric
path. `PCD` is the momentum coefficient, `PCDN` its neutral value, `PCH`
the heat/moisture coefficient, `PAC` the scalar conductance, `PRI` the
Richardson number and `ZZ0H` thermal roughness.

| Column | Units | Meaning |
| --- | --- | --- |
| `PCD_ROAD_CAN`, `PCDN_ROAD_CAN`, `PCH_ROAD_CAN`, `PRI_ROAD_CAN` | 1 | Road/canyon coefficients and stability. |
| `PAC_ROAD_CAN`, `PAC_ROAD_ATM` | m/s | Road scalar conductances. |
| `PCD_ROAD_ATM`, `PCDN_ROAD_ATM`, `PCH_ROAD_ATM`, `PRI_ROAD_ATM` | 1 | Road/atmosphere coefficients and stability. |
| `ZZ0H_ROAD_CAN`, `ZZ0H_ROAD_ATM` | m | Road thermal roughnesses. |
| `PAC_ROAD_WAT`, `PAC_ROAD_ATM_WAT` | m/s | Road liquid-water exchange conductances. |
| `PCD_GARDEN_CAN`, `PCDN_GARDEN_CAN`, `PCH_GARDEN_CAN`, `PRI_GARDEN_CAN` | 1 | Garden/canyon coefficients and stability. |
| `PAC_GARDEN`, `PAC_GARDEN_ATM` | m/s | Garden scalar conductances; `PAC_GARDEN` is used by the canyon budget. |
| `PCD_GARDEN_ATM`, `PCDN_GARDEN_ATM`, `PCH_GARDEN_ATM`, `PRI_GARDEN_ATM` | 1 | Garden/atmosphere coefficients and stability. |
| `ZZ0H_GARDEN_CAN`, `ZZ0H_GARDEN_ATM` | m | Thermal roughnesses reported by the external garden exchange. |
| `PCD_GREENROOF_ATM`, `PCDN_GREENROOF_ATM`, `PCH_GREENROOF_ATM`, `PRI_GREENROOF_ATM` | 1 | External greenroof/atmosphere coefficients and stability. |
| `PAC_GREENROOF_ATM` | m/s | External greenroof atmospheric conductance. |
| `ZZ0H_GREENROOF_ATM` | m | Greenroof thermal roughness. |

Neutral external modes leave Richardson-number diagnostics undefined.
Coefficients requiring an inactive surface or exchange path are not physical
results for that run.

### 3.4 Garden and Greenroof Outputs

Surface fluxes are per unit garden or greenroof area. Disabled-surface
state/flux diagnostics are undefined. Garden CBS branch fluxes use the
same garden-area normalization.

| Column | Units | Meaning |
| --- | --- | --- |
| `TS_GARDEN`, `TS_GREENROOF` | K | Radiative surface temperature. |
| `RN_GARDEN`, `RN_GREENROOF` | W/m²(surface) | Surface net radiation. |
| `H_GARDEN`, `H_GREENROOF` | W/m²(surface) | Surface sensible heat flux. |
| `LE_GARDEN`, `LE_GREENROOF` | W/m²(surface) | Surface latent heat flux. |
| `EVAP_GARDEN`, `EVAP_GREENROOF` | kg/(m²(surface) s) | Surface evaporation. |
| `QSAT_GARDEN`, `QSAT_GREENROOF` | kg/kg | Saturation specific humidity at surface temperature. |
| `PHU_GARDEN`, `PHU_GREENROOF` | 1 | Surface humidity multiplier; external surfaces use their humidity/saturation ratio. |
| `H_GARDEN_CAN`, `H_GARDEN_ATM`, `LE_GARDEN_CAN`, `LE_GARDEN_ATM` | W/m²(garden) | Canyon and atmosphere branch heat fluxes. |
| `PAC_GREENROOF` | m/s | Internal greenroof scalar conductance; zero for fixed-Bowen/external modes. |

### 3.5 Mean Radiant Temperature

MRT describes a standing pedestrian at 1.1 m above the road. The roof
diagnostic uses an unobstructed roof surface. These diagnostics do not
feed back on the model budgets; see the [MRT scheme](TEB_MSU_MRT_pedestrian_scheme.md).

| Column | Units | Meaning |
| --- | --- | --- |
| `MRT_ROAD` | K | Road-area-averaged pedestrian MRT, including the sunlit fraction. |
| `MRT_ROAD_SUN` | K | Pedestrian MRT with the full available direct beam. |
| `SW_DIR_ROAD`, `SW_SKY_ROAD`, `SW_WALL_ROAD`, `SW_TOT_ROAD` | W/m² | Direct, sky-diffuse, wall-reflected and total shortwave incident on the snow-free road. |
| `SUN_FRAC_ROAD` | 0–1 | Sunlit road fraction. |
| `MRT_F_SKY`, `MRT_F_WALL`, `MRT_F_ROAD` | 1 | Pedestrian view factors, summing to one. |
| `MRT_SW_DIR`, `MRT_SW_SKY`, `MRT_SW_WALL`, `MRT_SW_ROAD` | W/m² | Shortwave absorbed by the pedestrian. |
| `MRT_LW_SKY`, `MRT_LW_WALL`, `MRT_LW_ROAD` | W/m² | Longwave absorbed by the pedestrian. |
| `MRT_ROOF` | K | Pedestrian MRT over the roof. |
| `SW_DIR_ROOF`, `SW_SKY_ROOF`, `SW_TOT_ROOF` | W/m² | Direct, sky-diffuse and total shortwave incident on the snow-free roof. |

### 3.6 Solar Position

Solar geometry used at the last model substep of the output interval.

| Column | Units | Meaning |
| --- | --- | --- |
| `SOLAR_ZENITH` | ° | Zenith angle from the vertical. |
| `SOLAR_ELEV` | ° | Elevation above the horizon. |
| `SOLAR_AZIM` | ° | Azimuth clockwise from north. |

### 3.7 Atmospheric Forcing

Interpolated forcing used by the last model substep, at `time-dt`.
All cells receive the same atmospheric series.

| Column | Units | Meaning |
| --- | --- | --- |
| `Forc_TA` | K | Air temperature. |
| `Forc_QA` | kg/m³ | Air water-vapor density, `Forc_QV*Forc_RHOA`. |
| `Forc_QV` | kg/kg | Air specific humidity passed to TEB. |
| `Forc_U`, `Forc_V`, `Forc_WIND` | m/s | Zonal/meridional wind components and wind speed. |
| `Forc_DIR` | ° | Wind direction clockwise from north, `atan2(u,v)`. |
| `Forc_PS` | Pa | Pressure at the forcing level. |
| `Forc_RHOA` | kg/m³ | Air density at the forcing level. |
| `Forc_RAIN`, `Forc_SNOW` | kg/(m² s) | Rain and snow precipitation rates. |
| `Forc_LW` | W/m² | Downward longwave radiation. |
| `Forc_DIR_SW`, `Forc_SCA_SW` | W/m² | Direct and diffuse downward shortwave radiation. |

### 3.8 External Surface Emulators

These fields are written to the emulator CSV for enabled external
surfaces. The updated emulator state supplies the next TEB substep.

| Column | Units | Meaning |
| --- | --- | --- |
| `EMU_TAU` | 1 | Garden canyon-path exchange weight. |
| `EMU_CD_EFF`, `EMU_CH_EFF` | 1 | Effective garden momentum and heat/moisture coefficients. |
| `EMU_CH_NAIVE` | 1 | Garden heat coefficient averaged without the covariance correction. |
| `EMU_V`, `EMU_T`, `EMU_Q` | m/s; K; kg/kg | Wind, air temperature and specific humidity supplied to the garden emulator. |
| `EMU_CA_CAN`, `EMU_CA_EFF` | m/s | Canyon and effective garden scalar conductances. |
| `EMU_TS`, `EMU_H`, `EMU_LE`, `EMU_EVAP` | K; W/m²; W/m²; kg/(m² s) | Updated garden state and surface fluxes. |
| `EMU_GR_CD`, `EMU_GR_CH`, `EMU_GR_CA` | 1; 1; m/s | Greenroof momentum/thermal coefficients and scalar conductance. |
| `EMU_GR_V`, `EMU_GR_T`, `EMU_GR_Q` | m/s; K; kg/kg | Atmospheric wind, temperature and humidity supplied to the greenroof emulator. |
| `EMU_GR_PSW`, `EMU_GR_PLW` | W/m² | Shortwave and longwave radiation received by the greenroof emulator. |
| `EMU_GR_TS`, `EMU_GR_RN`, `EMU_GR_H`, `EMU_GR_LE`, `EMU_GR_EVAP` | K; W/m²; W/m²; W/m²; kg/(m² s) | Updated greenroof state, net radiation and surface fluxes. |

### 3.9 Runoff

| Column | Units | Meaning |
| --- | --- | --- |
| `RUNOFF_ROAD` | kg/(m²(road) s) | Mean road runoff rate over the forcing interval. |
| `RUNOFF_ROOF` | kg/(m²(roof) s) | Mean roof runoff rate over the forcing interval. |

### 3.10 Reading CSV Output

Read a selected cell with [`python/output_utils.py`](../python/output_utils.py):

```python
import output_utils

df = output_utils.read_output('output/TEB_output_b1_c1.csv', fmt='csv')
model_only = output_utils.read_output(
    'output/TEB_output_b1_c1.csv', fmt='csv', include_forcing=False)
```
