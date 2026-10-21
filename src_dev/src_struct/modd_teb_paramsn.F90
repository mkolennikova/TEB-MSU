!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt
!SFX_LIC for details. version 1.
!     ######################
      MODULE MODD_TEB_PARAMS_n
!     ######################
!
!!****  *MODD_TEB_PARAMS_n - static parameters of the urban surface
!!
!!    PURPOSE
!!    -------
!!    Static (per-column) parameters of TEB, split out of TEB_t so that the
!!    container of the model state holds the prognostic variables only:
!!
!!      * geometry: fractions, H/W, building height, wall/road/garden surfaces,
!!        roughness and displacement height of the town;
!!      * sky view factors of road, garden and wall;
!!      * roof, road and wall materials: albedo, emissivity, heat capacity,
!!        thermal conductivity, layer depths, roughness coefficients;
!!      * building use: residential fraction and the setback targets;
!!      * anthropogenic fluxes derived from the namelist (ahf_traffic,
!!        ahf_industry).
!!
!!    The fields are written once per run by the driver (category `param` and
!!    `flux` of python_tests/container_fields_inventory.py) and are reached as
!!    the component `P` of TEB_t (`TP%XALB_ROOF`); the model state lives in
!!    TEB_t itself.
!!
!!    REFERENCE
!!    ---------
!!    TEB-MSU: TEB_MSU_diagnostics_container.md, section 8.1 (the contract)
!!
USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
USE PARKIND1  ,ONLY : JPRB
!
IMPLICIT NONE
!--------------------------------------------------------------------------

TYPE TEB_PARAMS_t
!* CONTRACT (checked by python_tests/container_fields_inventory.py):
!*   param - static surface parameters, set once by the driver
!*   flux  - anthropogenic fluxes from the namelist, set once per run
!
! Geometric Parameters:
!
  REAL, POINTER, DIMENSION(:)   :: XROAD_DIR     ! Road direction (deg from North, clockwise)
  REAL, POINTER, DIMENSION(:)   :: XGARDEN       ! fraction of veg in the streets   (-)
  REAL, POINTER, DIMENSION(:)   :: XGREENROOF    ! fraction of greenroofs on roofs  (-)
  REAL, POINTER, DIMENSION(:)   :: XBLD          ! fraction of buildings            (-)
  REAL, POINTER, DIMENSION(:)   :: XROAD         ! fraction of roads                (-)
  REAL, POINTER, DIMENSION(:)   :: XCAN_HW_RATIO ! canyon    h/W                    (-)
  REAL, POINTER, DIMENSION(:)   :: XBLD_HEIGHT   ! buildings height 'h'             (m)
  REAL, POINTER, DIMENSION(:)   :: XWALL_O_HOR   ! wall surf. / hor. surf.          (-)
  REAL, POINTER, DIMENSION(:)   :: XROAD_O_GRND  ! road surf. / (road + garden surf.) (-)
  REAL, POINTER, DIMENSION(:)   :: XGARDEN_O_GRND! gard. surf. / (road + garden surf.)(-)
  REAL, POINTER, DIMENSION(:)   :: XWALL_O_GRND  ! wall surf. / (road + garden surf.) (-)
  REAL, POINTER, DIMENSION(:)   :: XWALL_O_BLD   ! wall surf. / bld surf. (-)
  REAL, POINTER, DIMENSION(:)   :: XZ0_TOWN      ! roughness length for momentum    (m)
!MV202609 z0 and zd to namelist
  REAL, POINTER, DIMENSION(:)   :: XZD_TOWN      ! displacement height of the town  (m)
  REAL, POINTER, DIMENSION(:)   :: XSVF_ROAD     ! road sky view factor             (-)
  REAL, POINTER, DIMENSION(:)   :: XSVF_GARDEN   ! green area sky view factor       (-)
  REAL, POINTER, DIMENSION(:)   :: XSVF_WALL     ! wall sky view factor             (-)
!
! Roof parameters
!
  REAL, POINTER, DIMENSION(:)   :: XALB_ROOF     ! roof albedo                      (-)
  REAL, POINTER, DIMENSION(:)   :: XEMIS_ROOF    ! roof emissivity                  (-)
  REAL, POINTER, DIMENSION(:,:) :: XHC_ROOF      ! roof layers heat capacity        (J/K/m3)
  REAL, POINTER, DIMENSION(:,:) :: XTC_ROOF      ! roof layers thermal conductivity (W/K/m)
  REAL, POINTER, DIMENSION(:,:) :: XD_ROOF       ! depth of roof layers             (m)
  REAL, POINTER, DIMENSION(:)   :: XROUGH_ROOF   ! roof roughness coef
!
! Road parameters
!
  REAL, POINTER, DIMENSION(:)   :: XALB_ROAD     ! road albedo                      (-)
  REAL, POINTER, DIMENSION(:)   :: XEMIS_ROAD    ! road emissivity                  (-)
  REAL, POINTER, DIMENSION(:,:) :: XHC_ROAD      ! road layers heat capacity        (J/K/m3)
  REAL, POINTER, DIMENSION(:,:) :: XTC_ROAD      ! road layers thermal conductivity (W/K/m)
  REAL, POINTER, DIMENSION(:,:) :: XD_ROAD       ! depth of road layers             (m)
!
! Wall parameters
!
  REAL, POINTER, DIMENSION(:)   :: XALB_WALL     ! wall albedo                      (-)
  REAL, POINTER, DIMENSION(:)   :: XEMIS_WALL    ! wall emissivity                  (-)
  REAL, POINTER, DIMENSION(:,:) :: XHC_WALL      ! wall layers heat capacity        (J/K/m3)
  REAL, POINTER, DIMENSION(:,:) :: XTC_WALL      ! wall layers thermal conductivity (W/K/m)
  REAL, POINTER, DIMENSION(:,:) :: XD_WALL       ! depth of wall layers             (m)
  REAL, POINTER, DIMENSION(:)   :: XROUGH_WALL   ! wall roughness coef
!
! Building's use type
!
  REAL, POINTER, DIMENSION(:)   :: XRESIDENTIAL  ! fraction of Residential use      (-)
  REAL                          :: XDT_RES       ! target temperature change when unoccupied (K) (residential buildings)
  REAL                          :: XDT_OFF       ! target temperature change when unoccupied (K) (offices buildings)
!
! anthropogenic fluxes
!
  REAL, POINTER, DIMENSION(:)   :: XH_TRAFFIC    ! anthropogenic sensible
!                                                  ! heat fluxes due to traffic       (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XLE_TRAFFIC   ! anthropogenic latent
!                                                  ! heat fluxes due to traffic       (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XH_INDUSTRY   ! anthropogenic sensible
!                                                  ! heat fluxes due to factories     (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XLE_INDUSTRY  ! anthropogenic latent
!                                                  ! heat fluxes due to factories     (W/m2)
!
END TYPE TEB_PARAMS_t

CONTAINS
!----------------------------------------------------------------------------

SUBROUTINE TEB_PARAMS_INIT(YTEB_PARAMS)
TYPE(TEB_PARAMS_t), INTENT(INOUT) :: YTEB_PARAMS
REAL(KIND=JPRB) :: ZHOOK_HANDLE
IF (LHOOK) CALL DR_HOOK("MODD_TEB_PARAMS_n:TEB_PARAMS_INIT",0,ZHOOK_HANDLE)
  NULLIFY(YTEB_PARAMS%XROAD_DIR)
  NULLIFY(YTEB_PARAMS%XGARDEN)
  NULLIFY(YTEB_PARAMS%XGREENROOF)
  NULLIFY(YTEB_PARAMS%XBLD)
  NULLIFY(YTEB_PARAMS%XROAD)
  NULLIFY(YTEB_PARAMS%XCAN_HW_RATIO)
  NULLIFY(YTEB_PARAMS%XBLD_HEIGHT)
  NULLIFY(YTEB_PARAMS%XWALL_O_HOR)
  NULLIFY(YTEB_PARAMS%XROAD_O_GRND)
  NULLIFY(YTEB_PARAMS%XGARDEN_O_GRND)
  NULLIFY(YTEB_PARAMS%XWALL_O_GRND)
  NULLIFY(YTEB_PARAMS%XWALL_O_BLD)
  NULLIFY(YTEB_PARAMS%XZ0_TOWN)
  NULLIFY(YTEB_PARAMS%XZD_TOWN)
  NULLIFY(YTEB_PARAMS%XSVF_ROAD)
  NULLIFY(YTEB_PARAMS%XSVF_GARDEN)
  NULLIFY(YTEB_PARAMS%XSVF_WALL)
  NULLIFY(YTEB_PARAMS%XALB_ROOF)
  NULLIFY(YTEB_PARAMS%XEMIS_ROOF)
  NULLIFY(YTEB_PARAMS%XHC_ROOF)
  NULLIFY(YTEB_PARAMS%XTC_ROOF)
  NULLIFY(YTEB_PARAMS%XD_ROOF)
  NULLIFY(YTEB_PARAMS%XROUGH_ROOF)
  NULLIFY(YTEB_PARAMS%XALB_ROAD)
  NULLIFY(YTEB_PARAMS%XEMIS_ROAD)
  NULLIFY(YTEB_PARAMS%XHC_ROAD)
  NULLIFY(YTEB_PARAMS%XTC_ROAD)
  NULLIFY(YTEB_PARAMS%XD_ROAD)
  NULLIFY(YTEB_PARAMS%XALB_WALL)
  NULLIFY(YTEB_PARAMS%XEMIS_WALL)
  NULLIFY(YTEB_PARAMS%XHC_WALL)
  NULLIFY(YTEB_PARAMS%XTC_WALL)
  NULLIFY(YTEB_PARAMS%XD_WALL)
  NULLIFY(YTEB_PARAMS%XROUGH_WALL)
  NULLIFY(YTEB_PARAMS%XRESIDENTIAL)
  NULLIFY(YTEB_PARAMS%XH_TRAFFIC)
  NULLIFY(YTEB_PARAMS%XLE_TRAFFIC)
  NULLIFY(YTEB_PARAMS%XH_INDUSTRY)
  NULLIFY(YTEB_PARAMS%XLE_INDUSTRY)
  YTEB_PARAMS%XDT_RES = 0.
  YTEB_PARAMS%XDT_OFF = 0.
IF (LHOOK) CALL DR_HOOK("MODD_TEB_PARAMS_n:TEB_PARAMS_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE TEB_PARAMS_INIT

END MODULE MODD_TEB_PARAMS_n

