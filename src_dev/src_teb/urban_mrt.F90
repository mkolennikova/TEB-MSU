!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt
!SFX_LIC for details. version 1.
!     #####################
MODULE MODE_URBAN_MRT
!     #####################
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      11/2026 -- OpenAI Codex
!!        Width-averaged geometry and common pedestrian radiation budget.
USE MODD_CSTS,     ONLY : XPI, XSTEFAN
USE MODD_SURF_PAR, ONLY : XUNDEF
IMPLICIT NONE
PRIVATE
PUBLIC :: MRT_STRIP_VIEW, MRT_SUN_FRACTION, MRT_BEAM, MRT_TEMPERATURE
REAL, PARAMETER, PUBLIC :: XZ_PED = 1.1, XABS_BODY = 0.70, XEMIS_BODY = 0.97
CONTAINS

PURE REAL FUNCTION MRT_STRIP_VIEW(PRATIO) RESULT(PVIEW)
! Width average of Shonk et al. (2026), Eqs. 9-10. PRATIO = distance / width.
REAL, INTENT(IN) :: PRATIO
REAL :: ZINV
IF (PRATIO <= 0.) THEN
  PVIEW = 0.5
ELSE IF (PRATIO <= 1.) THEN
  PVIEW = (ATAN2(1.,PRATIO) - PRATIO*(0.5*LOG(1.+PRATIO**2)-LOG(PRATIO))) / XPI
ELSE
  ZINV = 1./PRATIO
  IF (ZINV < 0.001) THEN
    PVIEW = ZINV*(0.5-ZINV**2/12.+ZINV**4/30.) / XPI
  ELSE
    PVIEW = (ATAN(ZINV)-0.5*PRATIO*LOG(1.+ZINV**2)) / XPI
  END IF
END IF
END FUNCTION MRT_STRIP_VIEW

PURE REAL FUNCTION MRT_SUN_FRACTION(PZENITH, PAZIM, PHEIGHT, PHW, PROAD_DIR, CROAD_DIR) RESULT(PFRAC)
REAL, INTENT(IN) :: PZENITH, PAZIM, PHEIGHT, PHW, PROAD_DIR
CHARACTER(LEN=*), INTENT(IN) :: CROAD_DIR
REAL :: ZSHADOW, ZINV, ZCROSS
PFRAC = 0.
IF (PZENITH >= 0.5*XPI) RETURN
PFRAC = 1.
IF (PHEIGHT <= XZ_PED .OR. PHW <= 0.) RETURN
ZSHADOW = PHW*(1.-XZ_PED/PHEIGHT)*TAN(PZENITH)
IF (CROAD_DIR == 'UNIF') THEN
  ! Integral of max(0, 1-shadow*sin(angle)) over uniformly oriented streets.
  IF (ZSHADOW <= 1.) THEN
    PFRAC = 1.-2.*ZSHADOW/XPI
  ELSE
    ZINV = 1./ZSHADOW
    PFRAC = 2./XPI*(ASIN(ZINV)-ZINV/(1.+SQRT(1.-ZINV**2)))
  END IF
ELSE
  ZCROSS = ABS(SIN(PAZIM-PROAD_DIR*XPI/180.))
  IF (ZCROSS > 4.*EPSILON(1.)) PFRAC = MAX(0.,1.-ZSHADOW*ZCROSS)
END IF
END FUNCTION MRT_SUN_FRACTION

PURE REAL FUNCTION MRT_BEAM(PDIRECT, PZENITH, CBODY) RESULT(PBEAM)
REAL, INTENT(IN) :: PDIRECT, PZENITH
CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: CBODY
REAL :: ZPROJ, ZELEV
CHARACTER(LEN=16) :: YBODY
PBEAM = 0.
IF (PZENITH >= 0.5*XPI .OR. PDIRECT <= 0.) RETURN
YBODY = 'SPHERE'
IF (PRESENT(CBODY)) YBODY = ADJUSTL(CBODY)
ZPROJ = 0.25
IF (YBODY(1:1) == 'P' .OR. YBODY(1:1) == 'p') THEN
  ZELEV = 90.-PZENITH*180./XPI
  ZPROJ = 0.308*COS(ZELEV*(1.-ZELEV**2/48402.)*XPI/180.)
END IF
PBEAM = XABS_BODY*ZPROJ*PDIRECT/COS(PZENITH)
END FUNCTION MRT_BEAM

PURE REAL FUNCTION MRT_TEMPERATURE(PABSORBED) RESULT(PTEMP)
REAL, INTENT(IN) :: PABSORBED
PTEMP = XUNDEF
IF (PABSORBED > 0. .AND. PABSORBED < XUNDEF) PTEMP = (PABSORBED/(XEMIS_BODY*XSTEFAN))**0.25
END FUNCTION MRT_TEMPERATURE
END MODULE MODE_URBAN_MRT

!   ##########################################################################
    SUBROUTINE URBAN_MRT(KICELL, KIBLOCK, FORC, TPARAMS, TSTATE, DMT, EXT, CBODY)
!   ##########################################################################
!!****  *URBAN_MRT*
!!
!!    PURPOSE
!!    -------
!!    Pedestrian radiation at 1.1 m, averaged uniformly across the canyon.
!!    Sun and shade share the diffuse and thermal environment of that ensemble.
!!
!!**  METHOD
!!    ------
!!    Average the spherical solid angles over the street width. Surface fluxes
!!    include diffuse reflections of the solar beam and longwave reflection.
!!    CBODY selects the direct projection only ('SPHERE' or standing 'PERSON').
!!
!!    REFERENCE
!!    ---------
!!    Shonk et al. (2026), doi:10.1002/qj.70082, and Redon et al. (2020),
!!    doi:10.5194/gmd-13-385-2020.
!!
!!    AUTHOR
!!    ------
!!    TEB-MSU
!!
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      10/2026 -- Mikhail Varentsov (MV)
!!        Create road-canyon pedestrian mean radiant temperature diagnostics
!!        with spherical and standing-person body options.
!!      11/2026 -- OpenAI Codex
!!        Average canyon fluxes across the width and diagnose sun and shade.
!-------------------------------------------------------------------------------
!*       0.     DECLARATIONS
!               ------------
USE MODE_URBAN_MRT
USE MODD_SURF_PAR,        ONLY : XUNDEF
USE MODD_TEB_n,           ONLY : TEB_t
USE MODD_TEB_PARAMS_n,    ONLY : TEB_PARAMS_t
USE MODD_TEB_FORCING_n,   ONLY : TEB_FORCING_t
USE MODD_TEB_EXT_SURF_n,  ONLY : TEB_EXT_SURF_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE YOMHOOK,              ONLY : LHOOK, DR_HOOK
USE PARKIND1,             ONLY : JPRB
IMPLICIT NONE
INTEGER,               INTENT(IN)    :: KICELL, KIBLOCK
TYPE(TEB_FORCING_t),   INTENT(IN)    :: FORC
TYPE(TEB_PARAMS_t),    INTENT(IN)    :: TPARAMS
TYPE(TEB_t),           INTENT(IN)    :: TSTATE
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT
TYPE(TEB_EXT_SURF_t),  INTENT(IN)    :: EXT
CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: CBODY
REAL :: ZHEIGHT, ZHW, ZREL, ZSKY, ZWALL, ZFLOOR, ZDIRECT, ZDIFFUSE
REAL :: ZBEAM, ZFRAC, ZBASE
REAL(KIND=JPRB) :: ZHOOK_HANDLE
!-------------------------------------------------------------------------------
IF (LHOOK) CALL DR_HOOK('URBAN_MRT',0,ZHOOK_HANDLE)
!*       1.     Width-mean solid angles
ZHEIGHT = TPARAMS%XBLD_HEIGHT(KICELL)
ZHW = TPARAMS%XCAN_HW_RATIO(KICELL)
ZSKY = 0.5
ZFLOOR = 0.5
IF (ZHEIGHT > 0. .AND. ZHW > 0. .AND. TPARAMS%XBLD(KICELL) > 0.) THEN
  ! The three-facet canyon ends at the eaves in very low buildings.
  ZREL = MIN(XZ_PED/ZHEIGHT,1.)
  ZSKY = MRT_STRIP_VIEW(ZHW*(1.-ZREL))
  ZFLOOR = MRT_STRIP_VIEW(ZHW*ZREL)
END IF
ZWALL = MAX(0.,1.-ZSKY-ZFLOOR)
DMT%XMRT_F_SKY(KICELL) = ZSKY
DMT%XMRT_F_ROAD(KICELL) = ZFLOOR
DMT%XMRT_F_WALL(KICELL) = ZWALL
!*       2.     Radiation absorbed per unit body area
ZDIRECT = MAX(0.,SUM(FORC%XDIR_SW(KICELL,:)))
ZDIFFUSE = MAX(0.,SUM(FORC%XSCA_SW(KICELL,:)))
ZBEAM = MRT_BEAM(ZDIRECT,FORC%XZENITH(KICELL),CBODY)
ZFRAC = DMT%XSUN_FRAC_PED(KICELL)
DMT%XMRT_SW_DIR(KICELL) = ZFRAC*ZBEAM
DMT%XMRT_SW_SKY(KICELL) = XABS_BODY*ZSKY*ZDIFFUSE
DMT%XMRT_SW_WALL(KICELL) = 0.
DMT%XMRT_SW_ROAD(KICELL) = 0.
! The solar solver has a small numerical diffuse floor at zero forcing.
IF (ZDIRECT+ZDIFFUSE > 0.) THEN
  IF (ZWALL > 0.) DMT%XMRT_SW_WALL(KICELL) = XABS_BODY*ZWALL*DMT%XREF_SW_FAC(KICELL)
  DMT%XMRT_SW_ROAD(KICELL) = XABS_BODY*ZFLOOR*DMT%XMRT_K_FLOOR(KICELL)
END IF
DMT%XMRT_LW_SKY(KICELL) = XEMIS_BODY*ZSKY*FORC%XLW(KICELL)
DMT%XMRT_LW_ROAD(KICELL) = XEMIS_BODY*ZFLOOR*DMT%XMRT_L_FLOOR(KICELL)
DMT%XMRT_LW_WALL(KICELL) = 0.
IF (ZWALL > 0.) DMT%XMRT_LW_WALL(KICELL) = XEMIS_BODY*ZWALL*DMT%XEMIT_LW_FAC(KICELL)
ZBASE = DMT%XMRT_SW_SKY(KICELL) + DMT%XMRT_SW_WALL(KICELL) + DMT%XMRT_SW_ROAD(KICELL) &
      + DMT%XMRT_LW_SKY(KICELL) + DMT%XMRT_LW_WALL(KICELL) + DMT%XMRT_LW_ROAD(KICELL)
!*       3.     Geometric exposure classes
DMT%XMRT(KICELL) = MRT_TEMPERATURE(ZBASE+DMT%XMRT_SW_DIR(KICELL))
DMT%XMRT_SUN(KICELL) = XUNDEF
DMT%XMRT_SHADE(KICELL) = XUNDEF
IF (ZFRAC > 0.) DMT%XMRT_SUN(KICELL) = MRT_TEMPERATURE(ZBASE+ZBEAM)
IF (ZFRAC < 1.) DMT%XMRT_SHADE(KICELL) = MRT_TEMPERATURE(ZBASE)
IF (LHOOK) CALL DR_HOOK('URBAN_MRT',1,ZHOOK_HANDLE)
END SUBROUTINE URBAN_MRT

!   ##########################################################################
    SUBROUTINE URBAN_MRT_ROOF(KICELL, KIBLOCK, FORC, TPARAMS, TSTATE, DMT, EXT, CBODY)
!   ##########################################################################
!!****  *URBAN_MRT_ROOF*
!!
!!    PURPOSE
!!    -------
!!    Pedestrian on the exposed part of a roof, with no panels in view.
!!
!!**  METHOD
!!    ------
!!    Open-sky direct beam and two equal hemispheres for diffuse radiation.
!!
!!    AUTHOR
!!    ------
!!    TEB-MSU
!!
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      10/2026 -- Mikhail Varentsov (MV)
!!        Create roof-level pedestrian mean radiant temperature diagnostics
!!        using sky and roof radiation.
!!      11/2026 -- OpenAI Codex
!!        Use panel-free exposure and mixed roof, snow and vegetation fluxes.
!-------------------------------------------------------------------------------
!*       0.     DECLARATIONS
!               ------------
USE MODE_URBAN_MRT
USE MODD_SURF_PAR,        ONLY : XUNDEF
USE MODD_TEB_n,           ONLY : TEB_t
USE MODD_TEB_PARAMS_n,    ONLY : TEB_PARAMS_t
USE MODD_TEB_FORCING_n,   ONLY : TEB_FORCING_t
USE MODD_TEB_EXT_SURF_n,  ONLY : TEB_EXT_SURF_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE YOMHOOK,              ONLY : LHOOK, DR_HOOK
USE PARKIND1,             ONLY : JPRB
IMPLICIT NONE
INTEGER,               INTENT(IN)    :: KICELL, KIBLOCK
TYPE(TEB_FORCING_t),   INTENT(IN)    :: FORC
TYPE(TEB_PARAMS_t),    INTENT(IN)    :: TPARAMS
TYPE(TEB_t),           INTENT(IN)    :: TSTATE
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT
TYPE(TEB_EXT_SURF_t),  INTENT(IN)    :: EXT
CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: CBODY
REAL :: ZBEAM, ZDIFFUSE, ZLW
REAL(KIND=JPRB) :: ZHOOK_HANDLE
!-------------------------------------------------------------------------------
IF (LHOOK) CALL DR_HOOK('URBAN_MRT_ROOF',0,ZHOOK_HANDLE)
DMT%XMRT_ROOF(KICELL) = XUNDEF
IF (DMT%XMRT_L_OPEN(KICELL) /= XUNDEF) THEN
  ZBEAM = MRT_BEAM(MAX(0.,SUM(FORC%XDIR_SW(KICELL,:))),FORC%XZENITH(KICELL),CBODY)
  ZDIFFUSE = MAX(0.,SUM(FORC%XSCA_SW(KICELL,:)))
  ZLW = FORC%XLW(KICELL) + DMT%XMRT_L_OPEN(KICELL)
  DMT%XMRT_ROOF(KICELL) = MRT_TEMPERATURE(ZBEAM + 0.5*XABS_BODY*(ZDIFFUSE+DMT%XMRT_K_OPEN(KICELL)) &
                                         + 0.5*XEMIS_BODY*ZLW)
END IF
IF (LHOOK) CALL DR_HOOK('URBAN_MRT_ROOF',1,ZHOOK_HANDLE)
END SUBROUTINE URBAN_MRT_ROOF
