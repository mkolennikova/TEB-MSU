# Stability-dependent town roughness and displacement height

TEB-MSU applies the Zilitinkevich et al. (2008) corrections to town momentum
roughness and displacement height in `src_dev`. This document describes the
implemented equations, time stepping and use in wind and exchange calculations.

Related documentation includes the [namelist and output reference](../TEB_MSU_variables_description.md#23-urban-aerodynamics),
the [host and container interface](../TEB_MSU_containers.md), and the
[CBS canyon air formulation](TEB_MSU_CBS_scheme_T_CAN_reformulation.md).
See [commit `15f5f55` in the development history](https://github.com/mkolennikova/TEB-MSU/commit/15f5f55cbead3092151df07f7d0bf0a35f2cbca7).

## 1. Configuration and notation

| Namelist group | Variable | Meaning |
| --- | --- | --- |
| `&tebopts` | `teb_ctype_z0_town` | Neutral town momentum roughness z₀ₙ in m |
| `&tebopts` | `teb_ctype_zd_town` | Neutral displacement height dₙ above road level in m |
| `&tebopts` | `teb_ctype_z0_town_dyncorr` | Town roughness correction, `'OFF'` or `'ZIL2008'` |
| `&tebopts` | `teb_ctype_zd_town_dyncorr` | Town displacement height correction, `'OFF'` or `'ZIL2008'` |

The two correction selectors are independent and both default to `'OFF'`. Each
`'OFF'` selector uses its neutral value. An enabled correction uses the building
height H from `urb_h_bld` and the same cell's stability history.

## 2. Stability argument and time stepping

When either correction is enabled, `CALL_DRIVER` diagnoses the inverse
Obukhov length at the end of each completed TEB substep. It uses the town
sensible heat flux `H_TOWN` in W/m², positive upward, the town friction
velocity u∗ in m/s, and the air temperature Tₐ and density ρₐ at the forcing
level. The following equations give the dry kinematic buoyancy flux in m²/s³
and the inverse length in m⁻¹.

$$
F_b=\frac{g}{T_a}\frac{H_{\mathrm{TOWN}}}{\rho_a c_p},
\qquad
L^{-1}=-\frac{F_b}{u_*^3}.
$$

Here g is gravitational acceleration and cₚ is the specific heat of air
at constant pressure. This definition follows Eq. (4) of Zilitinkevich et
al. (2008). For the same buoyancy flux and friction velocity, the length
is related to the standard Monin–Obukhov length by the von Kármán constant κ.
[Zilitinkevich et al. (2008)](#7-reference).

$$
L=\kappa L_{\mathrm{MO}}.
$$

Before wind and exchange are computed on substep n, the model forms the
stability argument from the inverse length of the previous completed substep.

$$
s_n=H\left(L^{-1}\right)_{n-1}.
$$

Positive s denotes stable stratification and negative s denotes unstable
stratification. Zero heat flux and cold start give zero s. An unavailable
estimate, including one from a previous substep with u∗ below 0.1 m/s, triggers
a neutral fallback on the current substep. [Driver](../../src_dev/src_driver/call_driver.F90).

When either correction is enabled, the host passes the stability history to
`teb_interface` through the `teb_inv_l_town_prev` array with `nvec` entries and
`INTENT(INOUT)`. The routine updates the active cells. The offline driver
stores the array in checkpoints and restores it on restart.
[Public interface](../../src_dev/src_api/sfc_teb.F90) ·
[Offline checkpoint handling](../../src_dev/src_offline/teb_offline_host.F90).

## 3. Correction equations

Eqs. (12) and (15) give the raw town roughness before geometric limits are applied.

$$
z_{0,\mathrm{raw}} =
\begin{cases}
z_{0n}/(1+8.13s), & s>0,\\
z_{0n}, & s=0,\\
z_{0n}[1+1.15(-s)^{1/3}], & s<0,
\end{cases}
$$

Eqs. (16) and (17) give the raw displacement height.

$$
d_{\mathrm{raw}} =
\begin{cases}
d_n+(H-d_n)s/(1.05+s), & s>0,\\
d_n, & s=0,\\
d_n/[1+0.56(-s)^{1/3}], & s<0.
\end{cases}
$$

Thus stable conditions reduce roughness and increase displacement, while
unstable conditions increase roughness and reduce displacement. The driver
takes the neutral value as the raw value for each correction set to `'OFF'`.
[Zilitinkevich et al. (2008)](#7-reference) ·
[Driver](../../src_dev/src_driver/call_driver.F90).

## 4. Geometry and numerical bounds

The neutral geometry checks use the representable spacing at building height.
The bounds also use the machine epsilon of the model's real kind.

$$
\epsilon=\operatorname{EPSILON}(1.),
\qquad
\sigma_H=\operatorname{SPACING}(H).
$$

The neutral values satisfy the following conditions.

$$
0<z_{0n}\leq \frac{H}{2},
\qquad
0\leq d_n<H,
\qquad
H-d_n-z_{0n}>\sigma_H.
$$

For nonzero s, the driver applies the enabled bounds in the following order.

### 4.1 Displacement bound

The displacement bound reserves space for roughness. It uses the reduced
raw roughness in stable conditions when both corrections are enabled.

$$
\begin{aligned}
z_r &= \min\!\left(z_{0n},\max(z_{0,\mathrm{raw}},\epsilon z_{0n})\right),\\
d_{\max} &= \max\!\left(d_n,H-z_r-\max(0.001z_r,2\sigma_H)\right),\\
d &= \min(d_{\mathrm{raw}},d_{\max}).
\end{aligned}
$$

### 4.2 Roughness bound

The roughness bound uses the resulting displacement height and the wind
forcing height above roof level, `z_u,f`. The reference distance accounts
for the roof profile and the wind reference height used for canyon exchange.

$$
\begin{aligned}
h_{\log} &= \min\!\left(H-d,z_{u,f}+H/2\right),\\
z_{0,\max} &= \max\!\left(z_{0n},h_{\log}-\max(0.001h_{\log},\sigma_H)\right),\\
z_0 &= \min\!\left(\max(z_{0,\mathrm{raw}},\epsilon z_{0n}),z_{0,\max}\right).
\end{aligned}
$$

The bounds retain valid neutral geometry and keep the gap H − d − z₀
positive. In a debugger, compare `ZZD_RAW` and `ZZ0_RAW` with `DMT%XZD_TOWN`
and `DMT%XZ0_TOWN`, respectively, inside the correction block.
[Driver](../../src_dev/src_driver/call_driver.F90) ·
[Neutral geometry validation](../../src_dev/src_api/teb_host.F90).

## 5. Coupling to wind and exchange

`CALL_DRIVER` calculates the roof-level wind from the forcing wind speed
`U_f` and the scalar reference height above roof level, `z_t,f`.

$$
U_{\mathrm{top}}
=U_f\frac{\ln\!\left((H-d)/z_0\right)}
           {\ln\!\left((z_{t,f}+H-d)/z_0\right)}.
$$

| Calculation | Use of corrected lengths |
| --- | --- |
| Roof-level wind | Both `'DEF'` and `'WANG'` use the resulting `WIND_TOP`. |
| Bulk town drag | `URBAN_DRAG` passes the momentum roughness z₀ and the reference heights measured from the displacement plane. The drag coefficient determines u∗ for the next stability estimate. |
| Direct canyon exchange | `URBAN_DRAG` uses z₀ as the input length for momentum and thermal roughness. The reference heights are measured from the canyon air level `PZ_LOWCAN`, set at half the building height in the offline driver. |

For bulk town drag, the scalar and wind forcing heights passed to the exchange
routine are, respectively,

$$
z_t=z_{t,f}+H-d,
\qquad
z_u=z_{u,f}+H-d.
$$

[Wind driver](../../src_dev/src_driver/call_driver.F90) ·
[Bulk and canyon exchange](../../src_dev/src_teb/urban_drag.F90) ·
[Town friction velocity](../../src_dev/src_teb/urban_fluxes.F90).

## 6. Output

`Z0_TOWN` and `ZD_TOWN` are the lengths supplied to physics at the reported
substep, after applying the bounds. `Z0_TOWN_NEUTRAL` and `ZD_TOWN_NEUTRAL`
report the corresponding neutral values. `Z0_TOWN_S` reports the shared
argument used for both corrections. `Z0_TOWN_NEUTRAL_FALLBACK` is `1` when
an unusable previous estimate triggers neutral values. See
[§3.2 of the output reference](../TEB_MSU_variables_description.md#32-main-model-diagnostics).

## 7. Reference

Zilitinkevich, S. S., Mammarella, I., Baklanov, A. A., & Joffre, S. M. (2008).
The Effect of Stratification on the Aerodynamic Roughness Length and
Displacement Height. *Boundary-Layer Meteorology*, 129(2), 179–190.
[DOI 10.1007/s10546-008-9307-9](https://doi.org/10.1007/s10546-008-9307-9).
