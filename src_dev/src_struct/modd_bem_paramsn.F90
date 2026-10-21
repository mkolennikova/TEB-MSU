!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt
!SFX_LIC for details. version 1.
!     ######################
      MODULE MODD_BEM_PARAMS_n
!     ######################
!
!!****  *MODD_BEM_PARAMS_n - static parameters of the building (BEM)
!!
!!    PURPOSE
!!    -------
!!    Static parameters of the building energy model, split out of BEM_t so
!!    that BEM_t keeps the indoor state, the workspace and the ventilation /
!!    shading flags only:
!!
!!      * floor material (heat capacity, conductivity, layer depths);
!!      * HVAC setpoints, capacities, flows, COP and the autosize helpers that
!!        come from the namelist;
!!      * windows: U-factor, transmittance, albedo, absorptance, SHGC;
!!      * indoor geometry and the view factors of the building cavity.
!!
!!    The fields are written once per run by the driver (category `param`) and
!!    are reached as the component `P` of BEM_t (`BP%XU_WIN`).
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

TYPE BEM_PARAMS_t
!* CONTRACT (checked by python_tests/container_fields_inventory.py):
!*   param - static parameters of the building, set once by the driver
!
! Floor parameters
!
  REAL, POINTER, DIMENSION(:,:) :: XHC_FLOOR     ! floor layers heat capacity        (J/K/m3)
  REAL, POINTER, DIMENSION(:,:) :: XTC_FLOOR     ! floor layers thermal conductivity (W/K/m)
  REAL, POINTER, DIMENSION(:,:) :: XD_FLOOR      ! depth of floor layers             (m)
!
! HVAC parameters
!
  REAL, POINTER, DIMENSION(:)   :: XTCOOL_TARGET ! cooling setpoint of indoor air
  REAL, POINTER, DIMENSION(:)   :: XTHEAT_TARGET ! heating setpoint of indoor air
  REAL, POINTER, DIMENSION(:)   :: XF_WASTE_CAN  ! fraction of waste heat released into the canyon
  REAL, POINTER, DIMENSION(:)   :: XEFF_HEAT     ! efficiency of the heating system
!
! Indoor parameters
!
  REAL, POINTER, DIMENSION(:)   :: XQIN          ! base internal heat gains [W m-2(floor)]
  REAL, POINTER, DIMENSION(:)   :: XQIN_FRAD     ! radiant fraction of internal heat gains
  REAL, POINTER, DIMENSION(:)   :: XSHGC         ! solar heat gain coef. of windows
  REAL, POINTER, DIMENSION(:)   :: XSHGC_SH      ! solar heat gain coef. of windows + shading
  REAL, POINTER, DIMENSION(:)   :: XU_WIN        ! window U-factor [K m W-2]
  REAL, POINTER, DIMENSION(:)   :: XGR           ! glazing ratio
  REAL, POINTER, DIMENSION(:)   :: XFLOOR_HEIGHT ! building floor height [m]
  REAL, POINTER, DIMENSION(:)   :: XINF          ! infiltration/ventilation flow rate [AC/H]
!
! New parameters
!
  REAL, POINTER, DIMENSION(:)   :: XF_WATER_COND  ! fraction of evaporation for condensers (cooling system)
  REAL, POINTER, DIMENSION(:)   :: XQIN_FLAT     ! Latent franction of internal heat gains
  REAL, POINTER, DIMENSION(:)   :: XHR_TARGET    ! Relative humidity setpoint
  REAL, POINTER, DIMENSION(:)   :: XV_VENT       ! Ventilation flow rate [AC/H]
  REAL, POINTER, DIMENSION(:)   :: XCAP_SYS_HEAT ! Capacity of the heating system
!                                                  ! [W m-2(bld)]
  REAL, POINTER, DIMENSION(:)   :: XCOP_RAT      ! Rated COP of the cooling system
  CHARACTER(LEN=4), POINTER, DIMENSION(:) :: CNATVENT ! flag to activate natural ventilation 'NONE', 'MANU', 'AUTO'
!
  !indoor relative surfaces and view factors
  REAL, POINTER, DIMENSION(:) :: XN_FLOOR        ! Number of floors
  REAL, POINTER, DIMENSION(:) :: XGLAZ_O_BLD    ! Window area [m2_win/m2_bld]
  REAL, POINTER, DIMENSION(:) :: XMASS_O_BLD    ! Mass area [m2_mass/m2_bld]
  REAL, POINTER, DIMENSION(:) :: XFLOOR_HW_RATIO ! H/W ratio of 1 floor level
  REAL, POINTER, DIMENSION(:) :: XF_FLOOR_MASS   ! View factor floor-mass
  REAL, POINTER, DIMENSION(:) :: XF_FLOOR_WALL   ! View factor floor-wall
  REAL, POINTER, DIMENSION(:) :: XF_FLOOR_WIN    ! View factor floor-window
  REAL, POINTER, DIMENSION(:) :: XF_FLOOR_ROOF   ! View factor floor-roof
  REAL, POINTER, DIMENSION(:) :: XF_WALL_FLOOR   ! View factor wall-floor
  REAL, POINTER, DIMENSION(:) :: XF_WALL_MASS    ! View factor wall-mass
  REAL, POINTER, DIMENSION(:) :: XF_WALL_WIN     ! View factor wall-win
  REAL, POINTER, DIMENSION(:) :: XF_WIN_FLOOR    ! View factor win-floor
  REAL, POINTER, DIMENSION(:) :: XF_WIN_MASS     ! View factor win-mass
  REAL, POINTER, DIMENSION(:) :: XF_WIN_WALL     ! View factor win-wall
  REAL, POINTER, DIMENSION(:) :: XF_WIN_WIN      ! indoor View factor win-win
  REAL, POINTER, DIMENSION(:) :: XF_MASS_FLOOR   ! View factor mass-floor
  REAL, POINTER, DIMENSION(:) :: XF_MASS_WALL    ! View factor mass-wall
  REAL, POINTER, DIMENSION(:) :: XF_MASS_WIN     ! View factor mass-window
!
END TYPE BEM_PARAMS_t

CONTAINS
!----------------------------------------------------------------------------

SUBROUTINE BEM_PARAMS_INIT(YBEM_PARAMS)
TYPE(BEM_PARAMS_t), INTENT(INOUT) :: YBEM_PARAMS
REAL(KIND=JPRB) :: ZHOOK_HANDLE
IF (LHOOK) CALL DR_HOOK("MODD_BEM_PARAMS_n:BEM_PARAMS_INIT",0,ZHOOK_HANDLE)
  NULLIFY(YBEM_PARAMS%XHC_FLOOR)
  NULLIFY(YBEM_PARAMS%XTC_FLOOR)
  NULLIFY(YBEM_PARAMS%XD_FLOOR)
  NULLIFY(YBEM_PARAMS%XTCOOL_TARGET)
  NULLIFY(YBEM_PARAMS%XTHEAT_TARGET)
  NULLIFY(YBEM_PARAMS%XF_WASTE_CAN)
  NULLIFY(YBEM_PARAMS%XEFF_HEAT)
  NULLIFY(YBEM_PARAMS%XQIN)
  NULLIFY(YBEM_PARAMS%XQIN_FRAD)
  NULLIFY(YBEM_PARAMS%XSHGC)
  NULLIFY(YBEM_PARAMS%XSHGC_SH)
  NULLIFY(YBEM_PARAMS%XU_WIN)
  NULLIFY(YBEM_PARAMS%XGR)
  NULLIFY(YBEM_PARAMS%XFLOOR_HEIGHT)
  NULLIFY(YBEM_PARAMS%XINF)
  NULLIFY(YBEM_PARAMS%XF_WATER_COND)
  NULLIFY(YBEM_PARAMS%XQIN_FLAT)
  NULLIFY(YBEM_PARAMS%XHR_TARGET)
  NULLIFY(YBEM_PARAMS%XV_VENT)
  NULLIFY(YBEM_PARAMS%XCAP_SYS_HEAT)
  NULLIFY(YBEM_PARAMS%XCOP_RAT)
  NULLIFY(YBEM_PARAMS%CNATVENT)
  NULLIFY(YBEM_PARAMS%XN_FLOOR)
  NULLIFY(YBEM_PARAMS%XGLAZ_O_BLD)
  NULLIFY(YBEM_PARAMS%XMASS_O_BLD)
  NULLIFY(YBEM_PARAMS%XFLOOR_HW_RATIO)
  NULLIFY(YBEM_PARAMS%XF_FLOOR_MASS)
  NULLIFY(YBEM_PARAMS%XF_FLOOR_WALL)
  NULLIFY(YBEM_PARAMS%XF_FLOOR_WIN)
  NULLIFY(YBEM_PARAMS%XF_FLOOR_ROOF)
  NULLIFY(YBEM_PARAMS%XF_WALL_FLOOR)
  NULLIFY(YBEM_PARAMS%XF_WALL_MASS)
  NULLIFY(YBEM_PARAMS%XF_WALL_WIN)
  NULLIFY(YBEM_PARAMS%XF_WIN_FLOOR)
  NULLIFY(YBEM_PARAMS%XF_WIN_MASS)
  NULLIFY(YBEM_PARAMS%XF_WIN_WALL)
  NULLIFY(YBEM_PARAMS%XF_WIN_WIN)
  NULLIFY(YBEM_PARAMS%XF_MASS_FLOOR)
  NULLIFY(YBEM_PARAMS%XF_MASS_WALL)
  NULLIFY(YBEM_PARAMS%XF_MASS_WIN)
IF (LHOOK) CALL DR_HOOK("MODD_BEM_PARAMS_n:BEM_PARAMS_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE BEM_PARAMS_INIT

END MODULE MODD_BEM_PARAMS_n

