!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt
!SFX_LIC for details. version 1.
!   ##########################################################################
    SUBROUTINE URBAN_MRT(KICELL, KIBLOCK, FORC, TPARAMS, TSTATE, DMT, EXT)
!   ##########################################################################
!
!!****  *URBAN_MRT*
!!
!!    PURPOSE
!!    -------
!
!     Mean radiant temperature (MRT) of a pedestrian standing on the road of
!     the canyon. Pure diagnostic: it reads the surface temperatures of the
!     current sub-step (DMT%XTS_*, written in CALL_DRIVER just before the call),
!     the incident shortwave components of URBAN_SOLAR_ABS (DMT%XSW_*) and the
!     canyon geometry (TPARAMS); nothing it computes feeds back on the physics.
!
!     Two values are produced (see docs/TEB_MSU_MRT_pedestrian_scheme.md):
!
!       DMT%XMRT     - beam weighted by the sunlit area fraction of the road
!                      (consistent with the other road-area-averaged
!                      diagnostics of TEB);
!       DMT%XMRT_SUN - the same with the full beam (a pedestrian standing in
!                      the sunlit part), i.e. the upper bound of the thermal
!                      stress; equal to DMT%XMRT when the road is in shadow.
!
!!**  METHOD
!!    ------
!
!     Body = sphere (globe-like): F_sky + F_wall + F_road = 1 over the 4 pi,
!     the beam projection factor is 0.25, the diffuse (sky, wall reflection,
!     road reflection and longwave) one is the view factor itself.
!
!       T_mrt = [ ( alpha_k * sum(I_i) + eps_p * sum(L_i) ) / (eps_p * sigma) ]^(1/4)
!
!     View factors of a point at the height z_p above the canyon axis of an
!     infinite 2D canyon (a = H/W):
!
!       a_eff  = a * (1 - z_p/H)
!       psi    = sqrt(a_eff^2 + 1) - a_eff          ! TEB sky view factor formula
!       F_sky  = 0.5 * psi
!       F_road = 0.5 * (1 - sin(phi_b)),  tan(phi_b) = 2*z_p*a/H
!       F_wall = max(0, 1 - F_sky - F_road)
!
!     Shortwave components at road level: the beam and the wall reflection are
!     the diagnostics of URBAN_SOLAR_ABS (DMT%XSW_DIR_ROAD, DMT%XSW_WALL_ROAD),
!     the diffuse sky part is XSCA_SW*XSVF_ROAD, the road reflection is the
!     incident shortwave of the road times the road (or snow) albedo.
!
!     Longwave: the sky irradiance FORC%XLW, the emission of the two walls and
!     the emission of the road (snow-weighted).
!
!!    REFERENCE
!!    ---------
!
!     Thorsson et al. (2007) and the MRT formulation used by the operational
!     urban comfort schemes (body = sphere, alpha_k = 0.70, eps_p = 0.97).
!
!!    AUTHOR
!!    ------
!
!     TEB-MSU
!
!!    MODIFICATIONS
!!    -------------
!
!      Original    10/2026  pedestrian MRT on the road (MV202610)
!
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_CSTS,            ONLY : XSTEFAN
USE MODD_SURF_PAR,        ONLY : XUNDEF
USE MODD_TEB_n,           ONLY : TEB_t
USE MODD_TEB_PARAMS_n,    ONLY : TEB_PARAMS_t
USE MODD_TEB_FORCING_n,   ONLY : TEB_FORCING_t
USE MODD_TEB_EXT_SURF_n,  ONLY : TEB_EXT_SURF_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE YOMHOOK,              ONLY : LHOOK, DR_HOOK
USE PARKIND1,             ONLY : JPRB
!
IMPLICIT NONE
!
!*      0.1    declarations of arguments
!
INTEGER,               INTENT(IN)    :: KICELL   ! index of the cell in the window
INTEGER,               INTENT(IN)    :: KIBLOCK  ! index of the block (unused, symmetry with the physics calls)
TYPE(TEB_FORCING_t),   INTENT(IN)    :: FORC     ! atmospheric forcing of the sub-step
TYPE(TEB_PARAMS_t),    INTENT(IN)    :: TPARAMS  ! static parameters of TEB (geometry, materials)
TYPE(TEB_t),           INTENT(IN)    :: TSTATE   ! state of TEB (snow on the road)
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT      ! diagnostics container
TYPE(TEB_EXT_SURF_t),  INTENT(IN)    :: EXT      ! external surfaces (unused, symmetry with the physics calls)
!
!*      0.2    declarations of local variables
!
!MV202610 pedestrian constants (see the scheme document)
REAL, PARAMETER :: XZ_PED     = 1.1     ! height of the centre of the pedestrian (m)
REAL, PARAMETER :: XABS_BODY  = 0.70    ! shortwave absorption of the body (-)
REAL, PARAMETER :: XEMIS_BODY = 0.97    ! longwave emissivity of the body (-)
REAL, PARAMETER :: XF_DIR     = 0.25    ! projected area factor of a sphere for the beam (-)
REAL, PARAMETER :: XCOSZ_MIN  = 0.02    ! lower bound of cos(zenith) (88.9 deg)
!
REAL :: ZH_CAN, ZA_RATIO, ZA_EFF, ZPSI, ZB, ZSKY, ZROAD, ZWALL
REAL :: ZCOSZ, ZSUNLIT, ZIDIR, ZIDIR_SUN, ZISKY, ZIWALL, ZSW_REF, ZIROAD
REAL :: ZPDN, ZALB_RD, ZALB_SN, ZEMIS_RD, ZEMIS_SN, ZEMIS_WL
REAL :: ZT_ROAD, ZT_SNOW, ZL_SKY, ZL_WALL, ZL_ROAD
REAL :: ZQ_SW, ZQ_SW_SUN, ZQ_LW, ZQ_TOT
REAL(KIND=JPRB) :: ZHOOK_HANDLE
!-------------------------------------------------------------------------------
IF (LHOOK) CALL DR_HOOK('URBAN_MRT',0,ZHOOK_HANDLE)
!
!*       1.     GEOMETRY: VIEW FACTORS OF THE PEDESTRIAN
!               --------------------------------------
!
!MV202610 the pedestrian is placed on the canyon axis at z_p: this is a
!* conscious simplification (the model carries road-area-averaged radiative
!* fluxes, so a pedestrian "smeared" over the road width is represented by its
!* axis point with the averaged fluxes)
!
ZH_CAN   = TPARAMS%XBLD_HEIGHT (KICELL)
ZA_RATIO = TPARAMS%XCAN_HW_RATIO(KICELL)
!
IF (ZH_CAN > 0. .AND. ZA_RATIO > 0.) THEN
  !* effective height of the walls above the pedestrian: it generalises the TEB
  !* sky view factor formula XSVF_ROAD = sqrt((H/W)^2+1) - H/W to the height z_p
  ZA_EFF = ZA_RATIO * MAX(0., 1. - XZ_PED/ZH_CAN)
  ZPSI   = SQRT(ZA_EFF**2 + 1.) - ZA_EFF
  ZSKY   = 0.5 * ZPSI
  !* the road fills the lower cap of the sphere down to the elevation of the
  !* wall bases, tan(phi_b) = 2*z_p/(H/a) = 2*z_p*a/H
  ZB     = 2. * XZ_PED * ZA_RATIO / ZH_CAN
  ZROAD  = 0.5 * (1. - ZB/SQRT(1. + ZB**2))
  ZWALL  = MAX(0., 1. - ZSKY - ZROAD)
ELSE
  !* no buildings: open surface (sky and road split the sphere in two halves)
  ZPSI   = 1.
  ZSKY   = 0.5
  ZROAD  = 0.5
  ZWALL  = 0.
ENDIF
!
DMT%XMRT_F_SKY (KICELL) = ZSKY
DMT%XMRT_F_WALL(KICELL) = ZWALL
DMT%XMRT_F_ROAD(KICELL) = ZROAD
!
!*       2.     SURFACE PROPERTIES OF THE CANYON FLOOR AND OF THE WALLS
!               -------------------------------------------------------
!
!* snow fraction of the road (DMT%XPDN_RD is written by the snow scheme)
ZPDN = DMT%XPDN_RD(KICELL)
IF (ZPDN /= ZPDN .OR. ZPDN >= XUNDEF .OR. ZPDN <= 0.) THEN
  ZPDN = 0.
ELSE
  ZPDN = MIN(1., ZPDN)
ENDIF
!
ZALB_RD  = TPARAMS%XALB_ROAD (KICELL)
ZEMIS_RD = TPARAMS%XEMIS_ROAD(KICELL)
ZEMIS_WL = TPARAMS%XEMIS_WALL(KICELL)
!
ZALB_SN  = TSTATE%TSNOW_ROAD%ALB (KICELL)
IF (ZALB_SN == XUNDEF .OR. ZALB_SN >= 1. .OR. ZALB_SN < 0.) ZALB_SN = ZALB_RD
ZEMIS_SN = TSTATE%TSNOW_ROAD%EMIS(KICELL)
IF (ZEMIS_SN == XUNDEF .OR. ZEMIS_SN <= 0. .OR. ZEMIS_SN > 1.) ZEMIS_SN = ZEMIS_RD
ZT_SNOW  = TSTATE%TSNOW_ROAD%TS  (KICELL)
IF (ZT_SNOW == XUNDEF .OR. ZT_SNOW <= 0.) ZT_SNOW = DMT%XTS_ROAD(KICELL)
!
ZT_ROAD  = DMT%XTS_ROAD(KICELL)
!
!*       3.     SHORTWAVE IRRADIANCE OF THE PEDESTRIAN
!               --------------------------------------
!
!* beam: XSW_DIR_ROAD is the direct shortwave on a horizontal surface at road
!* level, already averaged over the sunlit area fraction of the road. The body
!* intercepts XF_DIR of the beam on the plane normal to the sun, so the
!* "smeared" pedestrian receives exactly XF_DIR*XSW_DIR_ROAD/cos(zenith); the
!* sunlit variant undoes the area averaging with DMT%XSUN_FRAC_ROAD
ZCOSZ     = COS(FORC%XZENITH(KICELL))
ZIDIR     = 0.
ZIDIR_SUN = 0.
IF (DMT%XSW_DIR_ROAD(KICELL) > 0. .AND. ZCOSZ > 0.) THEN
  ZIDIR   = XF_DIR * DMT%XSW_DIR_ROAD(KICELL) / MAX(ZCOSZ,XCOSZ_MIN)
  ZSUNLIT = MIN(1., MAX(DMT%XSUN_FRAC_ROAD(KICELL),0.))
  IF (ZSUNLIT > 0.) ZIDIR_SUN = ZIDIR / ZSUNLIT
ENDIF
!
!* diffuse sky: XSW_SKY_ROAD is the diffuse sky shortwave at road level (the
!* plane view factor psi times the sky diffuse), so the pedestrian receives half
!* of it (its sky view factor is ZSKY = 0.5*psi)
ZISKY = 0.5 * DMT%XSW_SKY_ROAD(KICELL)
!
!* walls: XSW_WALL_ROAD is the wall-reflected shortwave at road level (the wall
!* radiance times the plane wall view factor 1-psi), so the flux seen by the
!* body is scaled by the ratio of the two view factors
ZIWALL = 0.
IF (ZWALL > 0.) ZIWALL = ZWALL * DMT%XSW_WALL_ROAD(KICELL) / MAX(1. - ZPSI,0.05)
!
!* road: the incident shortwave of the road (DMT%XSW_TOT_ROAD, the same for the
!* snow-free and for the snow-covered part: the geometry does not depend on the
!* albedo) times the albedo of the surface actually seen by the pedestrian
ZSW_REF = ((1. - ZPDN) * ZALB_RD + ZPDN * ZALB_SN) * MAX(DMT%XSW_TOT_ROAD(KICELL),0.)
ZIROAD  = ZROAD * MAX(ZSW_REF,0.)
!
DMT%XMRT_SW_DIR (KICELL) = XABS_BODY * MAX(ZIDIR ,0.)
DMT%XMRT_SW_SKY (KICELL) = XABS_BODY * MAX(ZISKY ,0.)
DMT%XMRT_SW_WALL(KICELL) = XABS_BODY * MAX(ZIWALL,0.)
DMT%XMRT_SW_ROAD(KICELL) = XABS_BODY * MAX(ZIROAD,0.)
!
!*       4.     LONGWAVE IRRADIANCE OF THE PEDESTRIAN
!               -------------------------------------
!
ZL_SKY  = FORC%XLW(KICELL)
ZL_WALL = 0.5 * ZEMIS_WL * XSTEFAN * (DMT%XTS_WALL_A(KICELL)**4 + DMT%XTS_WALL_B(KICELL)**4)
ZL_ROAD = (1. - ZPDN) * ZEMIS_RD * XSTEFAN * ZT_ROAD**4                       &
        +          ZPDN  * ZEMIS_SN * XSTEFAN * ZT_SNOW**4
!
DMT%XMRT_LW_SKY (KICELL) = XEMIS_BODY * ZSKY  * ZL_SKY
DMT%XMRT_LW_WALL(KICELL) = XEMIS_BODY * ZWALL * ZL_WALL
DMT%XMRT_LW_ROAD(KICELL) = XEMIS_BODY * ZROAD * ZL_ROAD
!
!*       5.     MEAN RADIANT TEMPERATURE
!               -------------------------
!
ZQ_LW = DMT%XMRT_LW_SKY(KICELL) + DMT%XMRT_LW_WALL(KICELL) + DMT%XMRT_LW_ROAD(KICELL)
ZQ_SW = DMT%XMRT_SW_DIR(KICELL) + DMT%XMRT_SW_SKY(KICELL)   &
      + DMT%XMRT_SW_WALL(KICELL) + DMT%XMRT_SW_ROAD(KICELL)
!
!* sunlit variant: replace the area-averaged beam by the full one (only when
!* the sun reaches the road at all, otherwise the two values coincide exactly)
ZQ_SW_SUN = ZQ_SW - DMT%XMRT_SW_DIR(KICELL) + XABS_BODY * ZIDIR_SUN
!
ZQ_TOT = ZQ_SW + ZQ_LW
IF (ZQ_TOT > 0. .AND. ZQ_TOT < XUNDEF) THEN
  DMT%XMRT(KICELL) = (ZQ_TOT / (XEMIS_BODY*XSTEFAN))**0.25
ELSE
  DMT%XMRT(KICELL) = XUNDEF
ENDIF
!
ZQ_TOT = ZQ_SW_SUN + ZQ_LW
IF (ZQ_TOT > 0. .AND. ZQ_TOT < XUNDEF) THEN
  DMT%XMRT_SUN(KICELL) = (ZQ_TOT / (XEMIS_BODY*XSTEFAN))**0.25
ELSE
  DMT%XMRT_SUN(KICELL) = XUNDEF
ENDIF
!
IF (LHOOK) CALL DR_HOOK('URBAN_MRT',1,ZHOOK_HANDLE)
!
END SUBROUTINE URBAN_MRT

!   ##########################################################################
    SUBROUTINE URBAN_MRT_ROOF(KICELL, KIBLOCK, FORC, TPARAMS, TSTATE, DMT, EXT)
!   ##########################################################################
!
!!****  *URBAN_MRT_ROOF*
!!
!!    PURPOSE
!!    -------
!
!     The same mean radiant temperature for a pedestrian standing on the ROOF,
!     i.e. the companion of URBAN_MRT used for the comparison of the two
!     locations. The roof is treated as a flat infinite surface: the pedestrian
!     sees only the sky and the roof itself (F_sky = F_roof = 0.5, no walls), and
!     the roof is never shadowed by the canyon, so the beam enters with its full
!     value (only the solar-panel coverage reduces the incident shortwave, as it
!     already does in URBAN_SOLAR_ABS). One output, DMT%XMRT_ROOF: the roof has
!     no shadow, hence no sunlit variant.
!
!!**  METHOD
!!    ------
!
!     Same constants and same formula as URBAN_MRT:
!
!       Q_sw = alpha_k * ( I_dir + I_sky + I_roof )
!       Q_lw = eps_p   * ( 0.5*L_sky + 0.5*L_roof )
!       T_mrt = [ (Q_sw + Q_lw) / (eps_p * sigma) ]^(1/4)
!
!     with I_dir = f_dir*XSW_DIR_ROOF/max(cos(zenith),0.02),
!     I_sky = 0.5*XSW_SKY_ROOF, I_roof = 0.5*alpha_roof*XSW_TOT_ROOF (the roof
!     reflection), L_sky = FORC%XLW and L_roof the emission of the roof (or of
!     the snow on it).
!
!!    AUTHOR
!!    ------
!
!     TEB-MSU
!
!!    MODIFICATIONS
!!    -------------
!
!      Original    10/2026  pedestrian MRT on the roof (MV202610)
!
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_CSTS,            ONLY : XSTEFAN
USE MODD_SURF_PAR,        ONLY : XUNDEF
USE MODD_TEB_n,           ONLY : TEB_t
USE MODD_TEB_PARAMS_n,    ONLY : TEB_PARAMS_t
USE MODD_TEB_FORCING_n,   ONLY : TEB_FORCING_t
USE MODD_TEB_EXT_SURF_n,  ONLY : TEB_EXT_SURF_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE YOMHOOK,              ONLY : LHOOK, DR_HOOK
USE PARKIND1,             ONLY : JPRB
!
IMPLICIT NONE
!
!*      0.1    declarations of arguments
!
INTEGER,               INTENT(IN)    :: KICELL   ! index of the cell in the window
INTEGER,               INTENT(IN)    :: KIBLOCK  ! index of the block (unused, symmetry with the physics calls)
TYPE(TEB_FORCING_t),   INTENT(IN)    :: FORC     ! atmospheric forcing of the sub-step
TYPE(TEB_PARAMS_t),    INTENT(IN)    :: TPARAMS  ! static parameters of TEB (roof materials)
TYPE(TEB_t),           INTENT(IN)    :: TSTATE   ! state of TEB (snow on the roof)
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT      ! diagnostics container
TYPE(TEB_EXT_SURF_t),  INTENT(IN)    :: EXT      ! external surfaces (unused, symmetry with the physics calls)
!
!*      0.2    declarations of local variables
!
!MV202610 pedestrian constants (the same as in URBAN_MRT) and the roof geometry
REAL, PARAMETER :: XABS_BODY  = 0.70    ! shortwave absorption of the body (-)
REAL, PARAMETER :: XEMIS_BODY = 0.97    ! longwave emissivity of the body (-)
REAL, PARAMETER :: XF_DIR     = 0.25    ! projected area factor of a sphere for the beam (-)
REAL, PARAMETER :: XCOSZ_MIN  = 0.02    ! lower bound of cos(zenith) (88.9 deg)
REAL, PARAMETER :: XF_SKY     = 0.5     ! sky view factor on a flat infinite roof (-)
REAL, PARAMETER :: XF_ROOF    = 0.5     ! roof view factor on a flat infinite roof (-)
!
REAL :: ZCOSZ, ZIDIR, ZISKY, ZIROOF
REAL :: ZPDN, ZALB_RF, ZALB_SN, ZEMIS_RF, ZEMIS_SN, ZT_ROOF, ZT_SNOW
REAL :: ZL_SKY, ZL_ROOF, ZQ_SW, ZQ_LW, ZQ_TOT
REAL(KIND=JPRB) :: ZHOOK_HANDLE
!-------------------------------------------------------------------------------
IF (LHOOK) CALL DR_HOOK('URBAN_MRT_ROOF',0,ZHOOK_HANDLE)
!
!*       1.     SURFACE PROPERTIES OF THE ROOF
!               -------------------------------
!
!* snow fraction of the roof (DMT%XPDN_RF is written by the snow scheme)
ZPDN = DMT%XPDN_RF(KICELL)
IF (ZPDN /= ZPDN .OR. ZPDN >= XUNDEF .OR. ZPDN <= 0.) THEN
  ZPDN = 0.
ELSE
  ZPDN = MIN(1., ZPDN)
ENDIF
!
ZALB_RF  = TPARAMS%XALB_ROOF (KICELL)
ZEMIS_RF = TPARAMS%XEMIS_ROOF(KICELL)
!
ZALB_SN  = TSTATE%TSNOW_ROOF%ALB (KICELL)
IF (ZALB_SN == XUNDEF .OR. ZALB_SN >= 1. .OR. ZALB_SN < 0.) ZALB_SN = ZALB_RF
ZEMIS_SN = TSTATE%TSNOW_ROOF%EMIS(KICELL)
IF (ZEMIS_SN == XUNDEF .OR. ZEMIS_SN <= 0. .OR. ZEMIS_SN > 1.) ZEMIS_SN = ZEMIS_RF
ZT_SNOW  = TSTATE%TSNOW_ROOF%TS  (KICELL)
IF (ZT_SNOW == XUNDEF .OR. ZT_SNOW <= 0.) ZT_SNOW = DMT%XTS_ROOF(KICELL)
!
ZT_ROOF  = DMT%XTS_ROOF(KICELL)
!
!*       2.     SHORTWAVE IRRADIANCE OF THE PEDESTRIAN
!               --------------------------------------
!
!* beam: the roof is not shadowed, so the whole incident beam reaches the body
ZCOSZ = COS(FORC%XZENITH(KICELL))
ZIDIR = 0.
IF (DMT%XSW_DIR_ROOF(KICELL) > 0. .AND. ZCOSZ > 0.) THEN
  ZIDIR = XF_DIR * DMT%XSW_DIR_ROOF(KICELL) / MAX(ZCOSZ,XCOSZ_MIN)
ENDIF
!
!* diffuse sky: half of the horizontal flux (the sphere sees half of the sky)
ZISKY = XF_SKY * DMT%XSW_SKY_ROOF(KICELL)
!
!* roof reflection: the albedo of the surface the pedestrian actually sees
ZIROOF = XF_ROOF * ((1. - ZPDN) * ZALB_RF + ZPDN * ZALB_SN) &
       * MAX(DMT%XSW_TOT_ROOF(KICELL),0.)
!
ZQ_SW = XABS_BODY * (MAX(ZIDIR,0.) + MAX(ZISKY,0.) + MAX(ZIROOF,0.))
!
!*       3.     LONGWAVE IRRADIANCE OF THE PEDESTRIAN
!               -------------------------------------
!
ZL_SKY  = FORC%XLW(KICELL)
ZL_ROOF = (1. - ZPDN) * ZEMIS_RF * XSTEFAN * ZT_ROOF**4 &
        +          ZPDN  * ZEMIS_SN * XSTEFAN * ZT_SNOW**4
!
ZQ_LW = XEMIS_BODY * (XF_SKY * ZL_SKY + XF_ROOF * ZL_ROOF)
!
!*       4.     MEAN RADIANT TEMPERATURE
!               -------------------------
!
ZQ_TOT = ZQ_SW + ZQ_LW
IF (ZQ_TOT > 0. .AND. ZQ_TOT < XUNDEF) THEN
  DMT%XMRT_ROOF(KICELL) = (ZQ_TOT / (XEMIS_BODY*XSTEFAN))**0.25
ELSE
  DMT%XMRT_ROOF(KICELL) = XUNDEF
ENDIF
!
IF (LHOOK) CALL DR_HOOK('URBAN_MRT_ROOF',1,ZHOOK_HANDLE)
!
END SUBROUTINE URBAN_MRT_ROOF
