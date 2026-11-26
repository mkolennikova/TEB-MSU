# Pedestrian mean radiant temperature and UTCI in TEB-MSU

> Code state: `src_dev` implementation in commit `ca3508e`, branch `main`.

The diagnostic computes the temperature of a uniform radiative environment in which the body would receive the same radiative flux as in the modeled environment. In the canyon, it represents a standing person at 1.1 m with position uniformly distributed across street width. On the roof, it represents an open area under an unobstructed sky. Body radiative properties are identical in both calculations. The diagnostic receives the state of every TEB substep. [Field reference](../TEB_MSU_variables_description.md) · [Containers](../TEB_MSU_containers.md) · [Change history](../TEB_MSU_change_history.md)

## 1. Meaning of the output quantities

| Column | Definition |
| --- | --- |
| `MRT_ROAD`, K | Equivalent MRT from the **mean absorbed flux** across street width, including the garden, with direct beam weighted by sunlit width at body height. |
| `MRT_ROAD_SUN`, K | MRT on the sunlit part of the street. The body receives the full available direct beam and the width-mean diffuse and longwave background. |
| `MRT_ROAD_SHADE`, K | MRT in geometric shade. The body receives the same background with zero direct-beam contribution. |
| `SUN_FRAC_PED`, 0–1 | Fraction of width at 1.1 m from which the solar disk is visible in canyon geometry. Defined even with zero direct forcing. |
| `MRT_ROOF`, K | MRT on the panel-free roof area, with conventional roofing, snow or vegetation beneath the person. |

If a class has zero area, its temperature is `XUNDEF` (`1.E+20` in CSV). With the Sun at or below the horizon, `SUN_FRAC_PED = 0` and `MRT_ROAD_SHADE = MRT_ROAD`. For a fully sunlit street, `MRT_ROAD_SUN = MRT_ROAD`. Under complete cloud cover, geometrically available classes can have identical MRT. These quantities do not resolve a specific sidewalk location or temperature at a fixed point.

![MRT_ROOF marks the rooftop pedestrian. Two pedestrians labeled MRT_ROAD_SHADE and MRT_ROAD_SUN stand side by side across the shadow edge on the paved road. Street radiation arrows converge on the sunlit figure. Braces group the surfaces whose outgoing fluxes are averaged on the roof and on the street.](../../illustrations/img/mrt_scheme.svg)

**Figure 1.** The vertical dimensions mark the 1.1 m calculation level for all three pedestrians. On the paved road, `MRT_ROAD_SHADE` and `MRT_ROAD_SUN` label adjacent pedestrians on either side of the shadow edge. Their diffuse, reflected and longwave background is the same. The sunlit case also receives the direct solar beam. The diagram shows the street radiation arrows and local viewing angles at the sunlit pedestrian. Sightlines from that receptor to the eaves and wall bases delimit the sky, wall and floor angles. TEB-MSU averages the corresponding view factors across street width. On the roof, `MRT_ROOF` marks the pedestrian whose horizon divides the sky and roof hemispheres. The two direct beams are parallel to the shadow edge from the left eave. Equal-width garden strips flank the paved road, with the left strip in shade and the right strip in sunlight. The scale below them shows the shaded and sunlit widths at 1.1 m. Each brace groups the surfaces used for an area average. The roof brace spans the green and conventional roof surfaces, and the street brace spans both garden strips and the paving. The two arrows from each brace represent reflected shortwave and outgoing longwave fluxes averaged separately. Blue dashes indicate diffuse or reflected shortwave radiation, and red wavy arrows indicate longwave radiation. [Figure-generation script](../../illustrations/draw/draw_mrt.py)

## 2. Street geometry

Buildings form a straight infinite canyon with uniform height $H$ and width $W$. For diffuse fluxes, the body has equal sensitivity in every direction, so each face's weight is its solid angle divided by $4\pi$. Equations (9)–(12) of Shonk et al. give these weights **at specified coordinates**. TEB-MSU integrates over all cross-street positions with equal probability. Reflection calculations also differ from that paper: here they use fluxes from the TEB radiation scheme. [Shonk et al., UCanWBGT, §2.3–2.5](https://doi.org/10.1002/qj.70082)

Let $x$ be distance to the left wall, $0\le x\le W$, and $d$ vertical distance to the floor or upper opening. The local strip weight and its mean are

$$
F(x,d)=\frac{\arctan(x/d)+\arctan((W-x)/d)}{2\pi},\qquad
A(r)=\frac{1}{W}\int_0^W F(x,d)\,dx
=\frac{\arctan(1/r)-\tfrac{r}{2}\ln(1+r^{-2})}{\pi},
\quad r=d/W .
$$

The limiting value is $A(0)=1/2$. At $z=1.1\ \mathrm{m}$, the weights are $F_s=A((H-z)/W)$ for the sky, $F_g=A(z/W)$ for the floor and $F_w=1-F_s-F_g$ for both walls. Each wall has mean weight $F_w/2$. These weights differ from the exchange factors between planar canyon faces in TEB. On an open site, sky and ground weights are $1/2$. For $0<H<1.1\ \mathrm{m}$, the three faces are evaluated at eave height ($z=H$), and direct sunlight is available across the entire width. This approximates low buildings, where neighboring roofs may be visible from a point above the eaves.

## 3. Sunlit width fraction

Let $\theta$ be solar zenith angle and $\phi_s$ and $\phi_c$ the azimuths of the Sun and street axis. With the Sun above the horizon, relative cross-street wall-shadow length is $q|\sin(\phi_s-\phi_c)|$, where $q=(H-z)_+\tan\theta/W$. For a specified orientation (`ORIE`),

$$
f=\max\bigl(0,1-q|\sin(\phi_s-\phi_c)|\bigr).
$$

In `UNIF` mode, the result is averaged over equally probable street orientations. For $q>1$, orientations with a fully shaded cross section are excluded first.

$$
f=\frac{2}{\pi}\int_0^{\pi/2}\max(0,1-q\sin\psi)\,d\psi
=\begin{cases}
1-2q/\pi, &0\le q\le1,\\
(2/\pi)\,[\arcsin(1/q)-q(1-\sqrt{1-q^{-2}})], &q>1.
\end{cases}
$$

`SUN_FRAC_PED` reports $f$ independently of beam intensity. The existing `SUN_FRAC_ROAD` refers to **surface level** and is returned by the solar solver as road direct flux divided by above-canyon direct horizontal flux when the denominator is positive, capped at 1. With a zero denominator, it is zero. Pedestrian class selection uses `SUN_FRAC_PED`.

## 4. Body radiation budget

Let $D$ and $K_s$ denote direct and diffuse horizontal shortwave components above the roofs, and $L_s$ atmospheric longwave radiation. The scheme obtains $D,K_s$ from `FORC%XDIR_SW` and `FORC%XSCA_SW` after low-Sun correction and circumsolar redistribution, summing spectral bands. The original `Forc_DIR_SW` and `Forc_SCA_SW` columns therefore generally differ from $D,K_s$.

With visible Sun and positive $D$, the body absorbs $B=\alpha_b p(\gamma)D/\cos\theta$; otherwise $B=0$. For a standing person, $\gamma=90^\circ-\theta$ in degrees and $p(\gamma)=0.308\cos[(\pi/180)\gamma(1-\gamma^2/48402)]$. For a sphere, $p=1/4$. Body parameters are constant: $\alpha_b=0.70$, $\varepsilon_b=0.97$. Diffuse-surroundings geometry is spherical in both options. [Di Napoli et al., 2020](https://doi.org/10.1007/s00484-020-01900-5) · [Redon et al., 2020, §5.1, equations (20)–(22)](https://gmd.copernicus.org/articles/13/385/2020/)

Let $J^K_w,J^L_w$ and $J^K_g,J^L_g$ be total outgoing shortwave and longwave fluxes from the facade and floor. The background per unit body area, in $\mathrm{W/m^2}$, and the conversion to K are

$$
Q_0=\alpha_b(F_sK_s+F_wJ^K_w+F_gJ^K_g)
+\varepsilon_b(F_sL_s+F_wJ^L_w+F_gJ^L_g),\qquad
T(Q)=\left(\frac{Q}{\varepsilon_b\sigma}\right)^{1/4}.
$$

$\sigma=5.6697\,10^{-8}\ \mathrm{W/(m^2\,K^4)}$ is the TEB constant. Then `MRT_ROAD` is $T(Q_0+fB)$, `MRT_ROAD_SUN` is $T(Q_0+B)$, and `MRT_ROAD_SHADE` is $T(Q_0)$ when the corresponding class exists. Fluxes are weighted before taking the root. With zero incoming shortwave flux, body shortwave absorption is zero, including when the solar solver imposes a numerical minimum on diffuse light.

The facade supplies mean outgoing fluxes `XREF_SW_FAC` and `XEMIT_LW_FAC`, accounting for walls and glazing enabled in TEB. Direct light reflected by the ground or walls enters the diffuse background of both conditional temperatures. Longwave emission and reflection are computed together.

## 5. Surface mixture on the canyon floor

The probability of the person standing over each surface type equals its area fraction. Surface type and cross-street position are independent, so the same weights apply in sun, shade and the full-width mean. For each band, $J_g=\sum_i w_i J_i$. Let $g$ be garden fraction of **road + garden** area (`XGARDEN_O_GRND`), and $s_d$ snow fraction within the mineral road.

| Surface | Weight $w_i$ | Shortwave and longwave contribution |
| --- | --- | --- |
| Snow-free road, including wet road | $(1-g)(1-s_d)$ | Road albedo × incident flux; total outgoing longwave flux `ZEMIT_LW_RD`. |
| Road snow | $(1-g)s_d$ | Snow albedo × flux onto snow; longwave flux from temperature and net absorption in the snow scheme. |
| Garden | $g$ | Garden albedo × flux onto garden; total longwave flux `ZEMIT_LW_GD`, including garden radiative temperature. |

For an opaque gray surface, $J_i^L=\varepsilon_i\sigma T_i^4+(1-\varepsilon_i)L_i^\downarrow$. If TEB supplies net absorption $N_i=\varepsilon_i(L_i^\downarrow-\sigma T_i^4)$, the equivalent form is $J_i^L=\sigma T_i^4+(1-\varepsilon_i)N_i/\varepsilon_i$. Snow-free road and facades use the outgoing TEB fluxes with the model's longwave-exchange linearization. For road snow, $T_i$ is taken at the time of its longwave-budget linearization. Cover fraction and snow albedo are taken at substep radiation calculation time, including first snowfall and the final melting substep. Snow-state fields in the output file refer to the end of the substep and may already show zero during melting.

Water films and puddles are part of the snow-free surface. In TEB, they affect heat and moisture fluxes and thereby surface temperature. Separate water albedo, emissivity and radiative temperature are not specified. The garden uses optics and radiative temperature from its own scheme. Road snow fraction applies only to mineral paving. Representing the garden as a horizontal patch does not introduce tree-crown shading or lateral radiation.

## 6. Open roof area

The person stands under an unobstructed sky. Sky and accessible roofing each occupy half the field of view. Panels and their shadows are excluded from that field. Let $p$ be panel-covered roof fraction, $v$ greenroof fraction and $s_r$ snow fraction on conventional roofing. With equal panel-overlap probability for different surfaces and $p<1$, normalization by accessible area $1-p$ gives weights $(1-v)(1-s_r)$, $(1-v)s_r$, $v$. Without buildings or with $p=1$, `MRT_ROOF` is `XUNDEF`.

Every accessible surface receives $D+K_s$ and reflects $\alpha_i(D+K_s)$. Its longwave flux includes its own emission and reflection of $L_s$. Conventional roofing and vegetation use their temperatures and emissivities. For roof snow, $J^L_{sn}=L_s-N_{sn}$, where $N_{sn}$ is net absorption per unit snow area in the roof snow scheme. Roof-surface temperatures come from TEB and can therefore depend indirectly on panels. TEB computes one temperature for the open and shaded parts of a given surface.

$$
Q_r=B+\frac{\alpha_b}{2}\left(K_s+\sum_i w_i\alpha_i(D+K_s)\right)
+\frac{\varepsilon_b}{2}\left(L_s+\sum_i w_i J_i^L\right),\qquad
\mathrm{MRT\_ROOF}=T(Q_r).
$$

`SW_DIR_ROOF`, `SW_SKY_ROOF` and `SW_TOT_ROOF` describe irradiation of the underlying roof per unit total roof area. With panels, these fluxes contain factor $1-p$. The person and the visible open surface receive full irradiation per unit accessible area.

## 7. Implementation and verifiable properties

| Code location | Purpose |
| --- | --- |
| [TEB_GARDEN](../../src_dev/src_teb/teb_garden.F90) | Saves initial snow fractions and properties. After solving the budgets, assembles four outgoing surface fluxes and the sunlit width fraction. |
| [MODE_URBAN_MRT, URBAN_MRT and URBAN_MRT_ROOF](../../src_dev/src_teb/urban_mrt.F90) | View factors, shadow geometry, beam projection, absorption and conversion to temperature. |
| [CALL_DRIVER](../../src_dev/src_driver/call_driver.F90) | Calls both diagnostics each substep with `PERSON`. `SPHERE` is available through the same interface. |
| [TEB_LOG](../../src_dev/src_api/teb_log.F90) | Writes results, view factors and seven components of the pedestrian absorbed flux. |

For $0<f<1$, $T_\mathrm{ROAD}^4=fT_\mathrm{SUN}^4+(1-f)T_\mathrm{SHADE}^4$ holds in K. At $B=0$, all existing classes give identical results. If the longwave environment, including the sky, is isothermal at $T$ and solar radiation is absent, MRT equals $T$ for any valid emissivity of gray surfaces. View factors sum to one.

The [CAPITOUL output check](../../python_tests/check_mrt.py) numerically integrates point view factors and shade, reconstructs solar forcing components, checks class masks and assembles MRT from fluxes. Independent recomputation from namelist surface optics is available for the snow-free roof and the shortwave flux of the snow-free floor. Snow-substep checks and version-comparison results are stored externally in `W:/Work_TEB/TEB-Ru/mrt_width_20261126/`; [change record](../TEB_MSU_change_history.md).

```powershell
python -B python_tests/check_mrt.py <path-to-CSV> --param-nml <run-namelist>
```

## 8. Canyon UTCI thermal comfort index

Universal Thermal Climate Index (UTCI) is the air temperature in a standard environment at which the human thermoregulation model produces the same physiological response as under the specified conditions. The UTCI standard assumes a walking person and accounts for clothing adaptation to air temperature. TEB-MSU represents radiation exposure with the MRT of a vertically oriented body (§4). The index is in °C. [Bröde et al., 2012](https://doi.org/10.1007/s00484-011-0454-1)

### 8.1 UTCI operational polynomial

`CANYON_UTCI` receives model air temperature $T_a$ (`T_CANYON`) and pedestrian $\mathrm{MRT}_c$ for each radiation condition $c$, both in K. For the polynomial, air temperature is converted to °C and radiative forcing is specified by difference $\Delta T_{r,c}$ in K. Wind $v_{10}$ in m/s and water-vapor partial pressure $e$ in kPa are shared by all three conditions (§8.2–8.3).

$$
t_a=T_a-273.15,\qquad \Delta T_{r,c}=\mathrm{MRT}_c-T_a.
$$

The Bröde et al. polynomial approximates the difference between equivalent temperature of the UTCI-Fiala physiological model and air temperature. Adding $t_a$ to this correction gives UTCI in °C.

$$
\mathrm{UTCI}_c=t_a+
\sum_{\substack{i,j,k,\ell\ge 0\\ i+j+k+\ell\le 6}}
a_{ijk\ell}\,t_a^i\,v_{10}^j\,(\Delta T_{r,c})^k\,e^\ell .
$$

All 210 coefficients $a_{ijk\ell}$ come from `UTCI_approx` in the authors' `UTCI_a002.f90` program (Peter Bröde, release a 0.002). The complete monomial/coefficient table is published in the paper's ESM 3 supplement, PDF pages 48–50. In TEB-MSU, `XCOEFF` holds these coefficients and `CANYON_UTCI` evaluates the polynomial in Horner form. [Bröde et al., ESM 3 supplement](https://static-content.springer.com/esm/art%3A10.1007%2Fs00484-011-0454-1/MediaObjects/484_2011_454_MOESM1_ESM.pdf#page=48) · [Original UTCI program and README](https://utci.org/resources/UTCI%20Program%20Code.zip) · [Coefficients and evaluation in TEB-MSU](../../src_dev/src_teb/mode_urban_utci.F90)

| Output, °C | Input MRT, K | Pedestrian conditions |
| --- | --- | --- |
| `UTCI_ROAD` | `MRT_ROAD` | Body-absorbed flux averaged across street width. |
| `UTCI_ROAD_SUN` | `MRT_ROAD_SUN` | Sunlit street area, full available direct beam. |
| `UTCI_ROAD_SHADE` | `MRT_ROAD_SHADE` | Geometric shade, no direct beam. |

Air temperature, humidity and wind are identical for all three calculations at a given substep, so equal MRT gives equal indices. For `UTCI_ROAD`, flux averaging precedes MRT and UTCI calculation. Because these transformations are nonlinear, the result generally differs from the area-weighted mean of sun and shade indices. [Passing three MRT values in the driver](../../src_dev/src_driver/call_driver.F90)

### 8.2 Equivalent 10 m wind

`U_CAN_PED` provides model wind speed $u_p$ at body height $z_p=1.1$ m. The polynomial requires the equivalent speed at 10 m that produces this same wind at $z_p$ in the standard neutral UTCI profile. From equation (3) of Bröde et al., with reference height $z_{10}=10$ m and roughness length $z_0=0.01$ m,

$$
v_{10}^{*}=u_p\frac{\ln(z_{10}/z_0)}{\ln(z_p/z_0)}
=u_p\frac{\ln(10/0.01)}{\ln(1.1/0.01)}
\simeq 1.469585\,u_p.
$$

Building effects on wind enter through $u_p$. In `WANG`, the TEB wind profile determines $u_p$ for building height $H>1.1$ m. In `DEF`, bulk canyon wind speed approximates $u_p$. `U_CAN_10M` is a separate TEB wind diagnostic. [Bröde et al., equation (3)](https://doi.org/10.1007/s00484-011-0454-1) · [Bröde and Kampmann, UTCI profile explanation](https://doi.org/10.3390/biology12060802)

For $0\le v_{10}^{*}\le17$ m/s, the polynomial uses $v_{10}=\max(0.5,v_{10}^{*})$. `UTCI_WIND_10M` contains this argument, including the lower bound for calm and weak wind. With negative or missing $u_p$, or $v_{10}^{*}>17$ m/s, UTCI wind and all three indices are `XUNDEF`. The 17 m/s upper bound follows the release a 0.002 README and official UTCI calculator. The ESM 3 table gives a wider range up to 30.3 m/s. [UTCI calculator and wind range](https://utci.org/utci_calc.php) · [Range in ESM 3](https://static-content.springer.com/esm/art%3A10.1007%2Fs00484-011-0454-1/MediaObjects/484_2011_454_MOESM1_ESM.pdf#page=48)

### 8.3 Water-vapor pressure

In the original `UTCI_approx`, vapor pressure is supplied in hPa and converted to kPa inside the function. TEB-MSU obtains the same pressure $e$ directly in kPa from specific humidity $q$ (`Q_CANYON`, kg/kg) and pressure $p$ (`P_CANYON`, Pa). Let $r=q/(1-q)$ be the water-vapor/dry-air mass ratio and $\epsilon=R_d/R_v\simeq0.622$ the dry-air/water-vapor gas-constant ratio. Then

$$
e=\frac{p}{1000}\frac{r}{\epsilon+r}
 =\frac{p}{1000}\frac{q}{\epsilon+(1-\epsilon)q}.
$$

Factor $1/1000$ converts Pa to kPa. [WMO equation 4.A.6 and conversion from specific humidity](https://unidata.github.io/MetPy/latest/api/generated/metpy.calc.dewpoint_from_specific_humidity.html)

Saturation checking uses vapor pressure over liquid water $e_s(T_a)$ from Hardy's ITS-90 formulation. With $T_a$ in K and $e_s$ in kPa,

$$
e_s(T_a)=10^{-3}\exp\!\left(\sum_{n=0}^{6}g_n T_a^{\,n-2}+g_7\ln T_a\right).
$$

Hardy gives coefficients $g_n$ beside equation (2); they also appear in `SATURATION_WATER_KPA`. Bröde et al. recommend substituting 5 % for relative humidity below 5 %. In TEB-MSU, as in the original program, the polynomial receives actual $e$ down to zero. [Hardy, equation (2) and ITS-90 coefficients](https://rhs.com/wp-content/uploads/2025/03/White_Paper_Wexler_Hardy_ITS-90-FORMULATIONS.pdf#page=2) · [Bröde et al., *Range of validity*](https://pstorage-loughborough-53465.s3.amazonaws.com/coversheet/16956833/1/PeterBrodeIJBM2011derivingoperationalprocedure.pdf)

### 8.4 Validity ranges and missing values

The code accepts $-50\le t_a\le50$ °C, $-30\le\Delta T_{r,c}\le70$ K and $0\le e\le\min(5,e_s(T_a))$ kPa. Invalid air temperature, humidity or pressure makes all three indices `XUNDEF`. If only one class MRT is unavailable or its $\Delta T_{r,c}$ lies outside the range, only that class is missing. `UTCI_WIND_10M` retains its value if wind is valid.

The diagnostics write the final substep of the output interval. Comparisons with Python packages `pythermalcomfort` and `thermofeel` on model and synthetic inputs are stored externally in `W:/Work_TEB/TEB-Ru/utci_canyon_20261126/`; [change record](../TEB_MSU_change_history.md).
