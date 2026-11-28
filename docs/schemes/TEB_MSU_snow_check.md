# Trace snowfall filtering (`teb_snow_check`)

> The verification below used [commit `878c93f`](https://github.com/mkolennikova/TEB-MSU/commit/878c93fa85b1dac2e09e59003308b97e2e5071cc).

## 1. Purpose of the flag

The snow correction originated in the coupled COSMO–TEB version, where it ran
at every step. Both TEB-MSU offline drivers read `teb_snow_check` from
`&tebopts`. Its default is `.FALSE.`. With zero snow storage, any positive
snowfall in the base scheme assigns snow to 1 % of the road or roof area.
Trace solid precipitation can therefore change the albedo returned by TEB to
COSMO even if the snow melts during the same step.
[Snow-fraction calculation](../../src_dev/src_teb/mode_surf_snow_frac.F90)

The old correction populated `WSNOW_*_CHECK` only for snowfall onto bare ground.
With positive storage, the check value remained zero, so the cover fraction was
reset to zero and radiation properties were reset to `XUNDEF`. The snow scheme
still ran whenever storage or snowfall was positive. At the end of a substep,
conversion back to the full surface area multiplied the remaining snow by the
zero fraction. In the Moscow run on 3 December 2023 at 11:10 UTC, the snow solver
received approximately `0.105 kg/m²` of road snow with `PDN_RD = 0`.
Using `XUNDEF` for albedo produced an absorbed shortwave flux of approximately
`−2.10×10²¹ W/m²`. The computed snow temperature became negative in Kelvin.
The `LOG(T)` call in the saturation formula terminated the run with `SIGFPE`.
[D8 recheck](../TEB_MSU_source_defects.md#protecting-calculations-from-xundef)

## 2. Behavior after the fix

With `.TRUE.`, the threshold `XTEB_SNOW_RATE_MIN = 1.e-8 kg/(m²·s)` is applied
before computing the snow fraction. The road and conventional roof each use
their own `WSNOW` storage.

| Surface storage at the start of the substep | Input snowfall rate | Action with `.TRUE.` |
| --- | --- | --- |
| `WSNOW = 0` | Below the threshold | Snow fraction is zero. The snow branch is skipped for this surface |
| `WSNOW = 0` | At or above the threshold | A snow fraction is formed and fresh-snow properties are initialized |
| `WSNOW > 0` | Any rate, including zero | Snow fraction is computed from storage; snow evolves with the original precipitation rate |

`TEB_GARDEN` passes `GNEW_SNOW` to `SNOW_FRAC_ROAD` and `SNOW_FRAC_ROOF`.
`URBAN_SNOW_EVOL` runs the snow branch for positive `PDN` and converts `PSR / PDN`
to a rate per unit snow-covered area. With `.FALSE.`, new cover is formed using
the original condition `PSR > 0`.
[Snow-state preparation](../../src_dev/src_teb/teb_garden.F90),
[snow evolution](../../src_dev/src_teb/urban_snow_evol.F90)

On existing cover, even positive snowfall below the threshold makes `PSR == 0`
false in the rule that removes small residual snow during melting.
[Single-layer snow-cover evolution](../../src_dev/src_teb/snow_cover_1layer.F90)

## 3. Protection against using `XUNDEF`

The protection applies to `src_dev` and `src_ctrl` for both values of
`teb_snow_check`. The shortwave calculation uses the substep snow fractions,
whereas state diagnostics account for snow remaining at its end.

### 3.1 Snow diagnostics at the end of the substep

Snow can melt completely during a substep in which its snow fraction was
positive. Its temperature and density can contain `XUNDEF` at the end of that
substep. In `CALL_DRIVER`, the two local weights `ZPDN_RF_DIAG` and
`ZPDN_RD_DIAG` use the substep snow fraction only if `WSNOW > 0` on the
corresponding surface at the end of the substep. With no remaining snow, the
weight is zero. These weights are used only for the final temperature, density
and snow-fraction diagnostics. Flux and meltwater calculations use the snow
fractions of the physical scheme.

The four local variables `ZTSSNOW_RF_TERM`, `ZTSSNOW_RD_TERM`, `ZRSNOW_RF_TERM`
and `ZRSNOW_RD_TERM` hold separate roof and road contributions to snow temperature
and density. At zero diagnostic weight, the contribution is zero and the snow
property is skipped. At positive weight, the property is checked before
multiplication by the surface-area and snow fractions. If the property equals
`XUNDEF`, the corresponding town diagnostic receives `XUNDEF` directly.
Temperature and density are checked independently. Sums of defined values are
normalized by snow-covered area: `XBLD*ZPDN_RF_DIAG + XROAD*ZPDN_RD_DIAG`.
At zero snow-covered area, temperature and density are `XUNDEF`, while snow
fraction and storage are zero. Coupling code must read temperature and density
only when both snow fraction and storage are positive. After `URBAN_SNOW_EVOL`,
`WSNOW` already includes the snow-fraction weight, so town storage is summed with
roof and road area weights without multiplying by `PDN` again.

The unused `ZALB_AVE_TWN` calculation was removed to eliminate another access
to the albedo of snow that has already melted.
[`CALL_DRIVER` in `src_dev`](../../src_dev/src_driver/call_driver.F90),
[`CALL_DRIVER` in `src_ctrl`](../../src_ctrl/src_driver/call_driver.F90)

### 3.2 Shortwave radiation

In `URBAN_SOLAR_ABS`, snow terms are computed only when the corresponding surface
has a positive snow fraction.

* On the roof, at `PDN_RF = 0`, snow absorption of direct and diffuse radiation
  beneath solar panels is zero.
* On the road, at `PDN_RD = 0`, effective albedo contains only the snow-free
  contribution. Absorbed and incident road-snow fluxes are zero. Division by
  `1 − ALB` to recover the incident flux is performed only at `PDN_RD > 0`.

With positive snow fraction and `ALB == XUNDEF`, the procedure reports the
surface type and point index and stops through `STOP 1` before computing with
that albedo.
[`URBAN_SOLAR_ABS` in `src_dev`](../../src_dev/src_teb/urban_solar_abs.F90),
[`URBAN_SOLAR_ABS` in `src_ctrl`](../../src_ctrl/src_teb/urban_solar_abs.F90)

## 4. Verification

### 4.1 Trace snowfall filter

* In both trees, at `PSR = 1.e-9 kg/(m²·s)` on a bare surface, physical outputs
  matched the run without snowfall. At `1.e-8` and `2.e-8`, snowfall was included.
  In experiments with snow only on the road or only on the roof, trace
  precipitation replenished existing storage. After complete melting, the
  surface remained snow-free.
* On Moscow ERA5 forcing for December 2023–April 2024 (LCZ4, 300 s substeps), both
  offline builds with `.TRUE.` completed all 3648 h. With `.FALSE.`, the CSVs
  before and after the fix were byte-identical. After the fix, `.TRUE.` and
  `.FALSE.` also produced identical CSVs. The minimum positive rate in this
  forcing was `1.e-5 kg/(m²·s)`.

External summaries: `D:\TEB_work\TEB_snow_check\synthetic_summary.json` and
`D:\TEB_work\TEB_snow_check\winter_summary.json`.

### 4.2 Protection and town snow diagnostics

A copy of the CAPITOUL case was used for 16 short offline runs: both trees,
both values of `teb_snow_check` and four forcings (no snow; snowfall of
`1.e-4 kg/(m²·s)`; below-threshold snowfall of `1.e-9 kg/(m²·s)`; snowfall followed
by warming and complete melting). Each run produced 60 CSV rows without
crashing. Under below-threshold snowfall, new cover formed only with the filter
disabled. The melting experiment included an interval with snow only on the road;
by the end, snow had disappeared from both surfaces.

In a diagnostic check of both trees, without snow the town fraction and storage
were zero and temperature and density were `XUNDEF`. With snow on both surfaces,
snow-covered-area weights and the absence of a repeated storage weight were
verified: at a fraction of `0.01`, town temperature was `263 K`, density was
`100 kg/m³`, and storage was `3.0010511972e-5 m H2O` in both trees. With snow only
on the road, town temperature, density and storage remained defined.

Forced substitution of `XUNDEF` into existing-snow properties and albedo was
checked when protection was introduced in [commit `f7857c2`](https://github.com/mkolennikova/TEB-MSU/commit/f7857c2bac2e16a6f954974bff17d7bd423603c9);
that protection was unchanged when normalization was ported. External summaries
of the earlier checks are `D:\TEB_work\TEB_snow_xundef\synthetic_summary.json` and
`D:\TEB_work\TEB_snow_xundef\winter_summary.json`.

The checks used TEB-MSU offline builds. The coupled build was not run after this
port; when using these trees in it, the new-snowfall threshold requires
`teb_snow_check` to be enabled.
