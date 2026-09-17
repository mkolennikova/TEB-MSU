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
| `teb_lgreenroof` | Flag | True / False | Activate green roof module |
| `teb_frac_gr` | External parameter | - | Green roof fraction |

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
python python/check_solar_position.py <output_dir>/TEB_output.csv --forcing-nml <forcing namelist>
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
([`python/output_utils.py`](python/output_utils.py)):

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
