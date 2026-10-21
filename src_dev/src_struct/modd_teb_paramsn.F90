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
!!    TEB-MSU: TEB_MSU_containers.md, section 2 (the contract)
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
  REAL, POINTER, DIMENSION(:)   :: XLE_TRAFFIC   ! anthropogenic latent
!                                                  ! heat fluxes due to traffic       (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XH_INDUSTRY   ! anthropogenic sensible
!                                                  ! heat fluxes due to factories     (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XLE_INDUSTRY  ! anthropogenic latent
!MV202610 annual-mean traffic flux (the daily cycle of CALL_DRIVER reads it)
  REAL, POINTER, DIMENSION(:)   :: XH_TRAFFIC_MEAN ! annual-mean traffic sensible heat (W/m2)
!MV202610 frontal area index of the urban surface (8 wind directions)
  REAL, POINTER, DIMENSION(:,:) :: XFAI        ! frontal area index (-)
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
  NULLIFY(YTEB_PARAMS%XLE_TRAFFIC)
  NULLIFY(YTEB_PARAMS%XH_INDUSTRY)
  NULLIFY(YTEB_PARAMS%XLE_INDUSTRY)
  NULLIFY(YTEB_PARAMS%XH_TRAFFIC_MEAN)
  NULLIFY(YTEB_PARAMS%XFAI)
  YTEB_PARAMS%XDT_RES = 0.
  YTEB_PARAMS%XDT_OFF = 0.
IF (LHOOK) CALL DR_HOOK("MODD_TEB_PARAMS_n:TEB_PARAMS_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE TEB_PARAMS_INIT

SUBROUTINE ALLOC_TEB_PARAMS(YTEB_PARAMS, KROOF_LAYER, KROAD_LAYER, KWALL_LAYER)
TYPE(TEB_PARAMS_t), INTENT(INOUT) :: YTEB_PARAMS
INTEGER, INTENT(IN) :: KROOF_LAYER, KROAD_LAYER, KWALL_LAYER
CALL TEB_PARAMS_INIT(YTEB_PARAMS)
ALLOCATE(YTEB_PARAMS%XROAD_DIR(1))     ! Road direction (deg from North, clockwise)
ALLOCATE(YTEB_PARAMS%XGARDEN(1))       ! fraction of veg in the streets   (-)
ALLOCATE(YTEB_PARAMS%XGREENROOF(1))    ! fraction of greenroofs on roofs  (-)
ALLOCATE(YTEB_PARAMS%XBLD(1))          ! fraction of buildings            (-)
ALLOCATE(YTEB_PARAMS%XROAD(1))         ! fraction of roads                (-)
ALLOCATE(YTEB_PARAMS%XCAN_HW_RATIO(1)) ! canyon    h/W                    (-)
ALLOCATE(YTEB_PARAMS%XBLD_HEIGHT(1))   ! buildings height 'h'             (m)
ALLOCATE(YTEB_PARAMS%XWALL_O_HOR(1))   ! wall surf. / hor. surf.          (-)
ALLOCATE(YTEB_PARAMS%XROAD_O_GRND(1))  ! road surf. / (road + garden surf.) (-)
ALLOCATE(YTEB_PARAMS%XGARDEN_O_GRND(1))! gard. surf. / (road + garden surf.)(-)
ALLOCATE(YTEB_PARAMS%XWALL_O_GRND(1))  ! wall surf. / (road + garden surf.) (-)
ALLOCATE(YTEB_PARAMS%XWALL_O_BLD(1))   ! wall surf. / bld surf. (-)
ALLOCATE(YTEB_PARAMS%XZ0_TOWN(1))      ! roughness length for momentum    (m)
ALLOCATE(YTEB_PARAMS%XZD_TOWN(1))      ! displacement height of the town  (m)
ALLOCATE(YTEB_PARAMS%XSVF_ROAD(1))     ! road sky view factor             (-)
ALLOCATE(YTEB_PARAMS%XSVF_GARDEN(1))   ! green area sky view factor       (-)
ALLOCATE(YTEB_PARAMS%XSVF_WALL(1))     ! wall sky view factor             (-)
ALLOCATE(YTEB_PARAMS%XALB_ROOF(1))     ! roof albedo                      (-)
ALLOCATE(YTEB_PARAMS%XEMIS_ROOF(1))    ! roof emissivity                  (-)
ALLOCATE(YTEB_PARAMS%XHC_ROOF(1,KROOF_LAYER))      ! roof layers heat capacity        (J/K/m3)
ALLOCATE(YTEB_PARAMS%XTC_ROOF(1,KROOF_LAYER))      ! roof layers thermal conductivity (W/K/m)
ALLOCATE(YTEB_PARAMS%XD_ROOF(1,KROOF_LAYER))       ! depth of roof layers             (m)
ALLOCATE(YTEB_PARAMS%XROUGH_ROOF(1))   ! roof roughness coef
ALLOCATE(YTEB_PARAMS%XALB_ROAD(1))     ! road albedo                      (-)
ALLOCATE(YTEB_PARAMS%XEMIS_ROAD(1))    ! road emissivity                  (-)
ALLOCATE(YTEB_PARAMS%XHC_ROAD(1,KROAD_LAYER))      ! road layers heat capacity        (J/K/m3)
ALLOCATE(YTEB_PARAMS%XTC_ROAD(1,KROAD_LAYER))      ! road layers thermal conductivity (W/K/m)
ALLOCATE(YTEB_PARAMS%XD_ROAD(1,KROAD_LAYER))       ! depth of road layers             (m)
ALLOCATE(YTEB_PARAMS%XALB_WALL(1))     ! wall albedo                      (-)
ALLOCATE(YTEB_PARAMS%XEMIS_WALL(1))    ! wall emissivity                  (-)
ALLOCATE(YTEB_PARAMS%XHC_WALL(1,KWALL_LAYER))      ! wall layers heat capacity        (J/K/m3)
ALLOCATE(YTEB_PARAMS%XTC_WALL(1,KWALL_LAYER))      ! wall layers thermal conductivity (W/K/m)
ALLOCATE(YTEB_PARAMS%XD_WALL(1,KWALL_LAYER))       ! depth of wall layers             (m)
ALLOCATE(YTEB_PARAMS%XROUGH_WALL(1))   ! wall roughness coef
ALLOCATE(YTEB_PARAMS%XRESIDENTIAL(1))  ! fraction of Residential use      (-)
ALLOCATE(YTEB_PARAMS%XLE_TRAFFIC(1))   ! anthropogenic latent
ALLOCATE(YTEB_PARAMS%XH_INDUSTRY(1))   ! anthropogenic sensible
ALLOCATE(YTEB_PARAMS%XLE_INDUSTRY(1))  ! anthropogenic latent
ALLOCATE(YTEB_PARAMS%XH_TRAFFIC_MEAN(1)) ! annual-mean traffic sensible heat
ALLOCATE(YTEB_PARAMS%XFAI(1,8))       ! frontal area index (8 directions)
END SUBROUTINE ALLOC_TEB_PARAMS

SUBROUTINE DEALLOC_TEB_PARAMS(YTEB_PARAMS)
TYPE(TEB_PARAMS_t), INTENT(INOUT) :: YTEB_PARAMS
DEALLOCATE(YTEB_PARAMS%XROAD_DIR)     ! Road direction (deg from North, clockwise)
DEALLOCATE(YTEB_PARAMS%XGARDEN)       ! fraction of veg in the streets   (-)
DEALLOCATE(YTEB_PARAMS%XGREENROOF)    ! fraction of greenroofs on roofs  (-)
DEALLOCATE(YTEB_PARAMS%XBLD)          ! fraction of buildings            (-)
DEALLOCATE(YTEB_PARAMS%XROAD)         ! fraction of roads                (-)
DEALLOCATE(YTEB_PARAMS%XCAN_HW_RATIO) ! canyon    h/W                    (-)
DEALLOCATE(YTEB_PARAMS%XBLD_HEIGHT)   ! buildings height 'h'             (m)
DEALLOCATE(YTEB_PARAMS%XWALL_O_HOR)   ! wall surf. / hor. surf.          (-)
DEALLOCATE(YTEB_PARAMS%XROAD_O_GRND)  ! road surf. / (road + garden surf.) (-)
DEALLOCATE(YTEB_PARAMS%XGARDEN_O_GRND)! gard. surf. / (road + garden surf.)(-)
DEALLOCATE(YTEB_PARAMS%XWALL_O_GRND)  ! wall surf. / (road + garden surf.) (-)
DEALLOCATE(YTEB_PARAMS%XWALL_O_BLD)   ! wall surf. / bld surf. (-)
DEALLOCATE(YTEB_PARAMS%XZ0_TOWN)      ! roughness length for momentum    (m)
DEALLOCATE(YTEB_PARAMS%XZD_TOWN)      ! displacement height of the town  (m)
DEALLOCATE(YTEB_PARAMS%XSVF_ROAD)     ! road sky view factor             (-)
DEALLOCATE(YTEB_PARAMS%XSVF_GARDEN)   ! green area sky view factor       (-)
DEALLOCATE(YTEB_PARAMS%XSVF_WALL)     ! wall sky view factor             (-)
DEALLOCATE(YTEB_PARAMS%XALB_ROOF)     ! roof albedo                      (-)
DEALLOCATE(YTEB_PARAMS%XEMIS_ROOF)    ! roof emissivity                  (-)
DEALLOCATE(YTEB_PARAMS%XHC_ROOF)      ! roof layers heat capacity        (J/K/m3)
DEALLOCATE(YTEB_PARAMS%XTC_ROOF)      ! roof layers thermal conductivity (W/K/m)
DEALLOCATE(YTEB_PARAMS%XD_ROOF)       ! depth of roof layers             (m)
DEALLOCATE(YTEB_PARAMS%XROUGH_ROOF)   ! roof roughness coef
DEALLOCATE(YTEB_PARAMS%XALB_ROAD)     ! road albedo                      (-)
DEALLOCATE(YTEB_PARAMS%XEMIS_ROAD)    ! road emissivity                  (-)
DEALLOCATE(YTEB_PARAMS%XHC_ROAD)      ! road layers heat capacity        (J/K/m3)
DEALLOCATE(YTEB_PARAMS%XTC_ROAD)      ! road layers thermal conductivity (W/K/m)
DEALLOCATE(YTEB_PARAMS%XD_ROAD)       ! depth of road layers             (m)
DEALLOCATE(YTEB_PARAMS%XALB_WALL)     ! wall albedo                      (-)
DEALLOCATE(YTEB_PARAMS%XEMIS_WALL)    ! wall emissivity                  (-)
DEALLOCATE(YTEB_PARAMS%XHC_WALL)      ! wall layers heat capacity        (J/K/m3)
DEALLOCATE(YTEB_PARAMS%XTC_WALL)      ! wall layers thermal conductivity (W/K/m)
DEALLOCATE(YTEB_PARAMS%XD_WALL)       ! depth of wall layers             (m)
DEALLOCATE(YTEB_PARAMS%XROUGH_WALL)   ! wall roughness coef
DEALLOCATE(YTEB_PARAMS%XRESIDENTIAL)  ! fraction of Residential use      (-)
DEALLOCATE(YTEB_PARAMS%XLE_TRAFFIC)   ! anthropogenic latent
DEALLOCATE(YTEB_PARAMS%XH_INDUSTRY)   ! anthropogenic sensible
DEALLOCATE(YTEB_PARAMS%XLE_INDUSTRY)  ! anthropogenic latent
DEALLOCATE(YTEB_PARAMS%XH_TRAFFIC_MEAN)
DEALLOCATE(YTEB_PARAMS%XFAI)
END SUBROUTINE DEALLOC_TEB_PARAMS

END MODULE MODD_TEB_PARAMS_n

