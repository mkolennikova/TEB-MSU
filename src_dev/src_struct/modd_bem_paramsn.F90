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
!!    TEB-MSU: TEB_MSU_containers.md, section 2 (the contract)
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

SUBROUTINE ALLOC_BEM_PARAMS(YBEM_PARAMS, KFLOOR_LAYER)
TYPE(BEM_PARAMS_t), INTENT(INOUT) :: YBEM_PARAMS
INTEGER, INTENT(IN) :: KFLOOR_LAYER
CALL BEM_PARAMS_INIT(YBEM_PARAMS)
ALLOCATE(YBEM_PARAMS%XHC_FLOOR(1,KFLOOR_LAYER)) ! floor layers heat capacity        (J/K/m3)
ALLOCATE(YBEM_PARAMS%XTC_FLOOR(1,KFLOOR_LAYER)) ! floor layers thermal conductivity (W/K/m)
ALLOCATE(YBEM_PARAMS%XD_FLOOR (1,KFLOOR_LAYER)) ! depth of floor layers             (m)
ALLOCATE(YBEM_PARAMS%XTCOOL_TARGET(1)) ! cooling setpoint of indoor air
ALLOCATE(YBEM_PARAMS%XTHEAT_TARGET(1)) ! heating setpoint of indoor air
ALLOCATE(YBEM_PARAMS%XF_WASTE_CAN (1)) ! fraction of waste heat released into the canyon
ALLOCATE(YBEM_PARAMS%XEFF_HEAT    (1)) ! efficiency of the heating system
ALLOCATE(YBEM_PARAMS%XQIN(1))           ! internal heat gains [W m-2(floor)]
ALLOCATE(YBEM_PARAMS%XQIN_FRAD(1))      ! radiant fraction of internal heat gains
ALLOCATE(YBEM_PARAMS%XSHGC(1))          ! solar heat gain coef. of windows
ALLOCATE(YBEM_PARAMS%XSHGC_SH(1))       ! solar heat gain coef. of windows + shading
ALLOCATE(YBEM_PARAMS%XU_WIN(1))         ! window U-factor [K m W-2]
ALLOCATE(YBEM_PARAMS%XGR(1))            ! glazing ratio
ALLOCATE(YBEM_PARAMS%XFLOOR_HEIGHT(1))  ! building floor height [m]
ALLOCATE(YBEM_PARAMS%XINF(1))           ! infiltration/ventilation flow rate [AC/H]
ALLOCATE(YBEM_PARAMS%XF_WATER_COND(1)) ! fraction of evaporation for condensers (cooling system)
ALLOCATE(YBEM_PARAMS%XQIN_FLAT(1))     ! Latent franction of internal heat gains
ALLOCATE(YBEM_PARAMS%XHR_TARGET(1))    ! Relative humidity setpoint
ALLOCATE(YBEM_PARAMS%XV_VENT(1))       ! Ventilation flow rate [AC/H]
ALLOCATE(YBEM_PARAMS%XCAP_SYS_HEAT(1)) ! Capacity of the heating system
ALLOCATE(YBEM_PARAMS%XCOP_RAT(1))      ! Rated COP of the cooling system
ALLOCATE(YBEM_PARAMS%CNATVENT(1))      ! flag to activate natural ventilation 'NONE', 'MANU', 'AUTO'
ALLOCATE(YBEM_PARAMS%XN_FLOOR(1))        ! Number of floors
ALLOCATE(YBEM_PARAMS%XGLAZ_O_BLD(1))     ! Window area [m2_win/m2_bld]
ALLOCATE(YBEM_PARAMS%XMASS_O_BLD(1))     ! Mass area [m2_mass/m2_bld]
ALLOCATE(YBEM_PARAMS%XFLOOR_HW_RATIO(1)) ! H/W ratio of 1 floor level
ALLOCATE(YBEM_PARAMS%XF_FLOOR_MASS(1))   ! View factor floor-mass
ALLOCATE(YBEM_PARAMS%XF_FLOOR_WALL(1))   ! View factor floor-wall
ALLOCATE(YBEM_PARAMS%XF_FLOOR_WIN(1))    ! View factor floor-window
ALLOCATE(YBEM_PARAMS%XF_FLOOR_ROOF(1))   ! View factor floor-roof
ALLOCATE(YBEM_PARAMS%XF_WALL_FLOOR(1))   ! View factor wall-floor
ALLOCATE(YBEM_PARAMS%XF_WALL_MASS(1))    ! View factor wall-mass
ALLOCATE(YBEM_PARAMS%XF_WALL_WIN(1))     ! View factor wall-win
ALLOCATE(YBEM_PARAMS%XF_WIN_FLOOR(1))    ! View factor win-floor
ALLOCATE(YBEM_PARAMS%XF_WIN_MASS(1))     ! View factor win-mass
ALLOCATE(YBEM_PARAMS%XF_WIN_WALL(1))     ! View factor win-wall
ALLOCATE(YBEM_PARAMS%XF_WIN_WIN(1))      ! indoor View factor win-win
ALLOCATE(YBEM_PARAMS%XF_MASS_FLOOR(1))   ! View factor mass-floor
ALLOCATE(YBEM_PARAMS%XF_MASS_WALL(1))    ! View factor mass-wall
ALLOCATE(YBEM_PARAMS%XF_MASS_WIN(1))     ! View factor mass-window
END SUBROUTINE ALLOC_BEM_PARAMS

SUBROUTINE DEALLOC_BEM_PARAMS(YBEM_PARAMS)
TYPE(BEM_PARAMS_t), INTENT(INOUT) :: YBEM_PARAMS
DEALLOCATE(YBEM_PARAMS%XHC_FLOOR) ! floor layers heat capacity        (J/K/m3)
DEALLOCATE(YBEM_PARAMS%XTC_FLOOR) ! floor layers thermal conductivity (W/K/m)
DEALLOCATE(YBEM_PARAMS%XD_FLOOR ) ! depth of floor layers             (m)
DEALLOCATE(YBEM_PARAMS%XTCOOL_TARGET) ! cooling setpoint of indoor air
DEALLOCATE(YBEM_PARAMS%XTHEAT_TARGET) ! heating setpoint of indoor air
DEALLOCATE(YBEM_PARAMS%XF_WASTE_CAN ) ! fraction of waste heat released into the canyon
DEALLOCATE(YBEM_PARAMS%XEFF_HEAT    ) ! efficiency of the heating system
DEALLOCATE(YBEM_PARAMS%XQIN)           ! internal heat gains [W m-2(floor)]
DEALLOCATE(YBEM_PARAMS%XQIN_FRAD)      ! radiant fraction of internal heat gains
DEALLOCATE(YBEM_PARAMS%XSHGC)          ! solar heat gain coef. of windows
DEALLOCATE(YBEM_PARAMS%XSHGC_SH)       ! solar heat gain coef. of windows + shading
DEALLOCATE(YBEM_PARAMS%XU_WIN)         ! window U-factor [K m W-2]
DEALLOCATE(YBEM_PARAMS%XGR)            ! glazing ratio
DEALLOCATE(YBEM_PARAMS%XFLOOR_HEIGHT)  ! building floor height [m]
DEALLOCATE(YBEM_PARAMS%XINF)           ! infiltration/ventilation flow rate [AC/H]
DEALLOCATE(YBEM_PARAMS%XF_WATER_COND) ! fraction of evaporation for condensers (cooling system)
DEALLOCATE(YBEM_PARAMS%XQIN_FLAT)     ! Latent franction of internal heat gains
DEALLOCATE(YBEM_PARAMS%XHR_TARGET)    ! Relative humidity setpoint
DEALLOCATE(YBEM_PARAMS%XV_VENT)       ! Ventilation flow rate [AC/H]
DEALLOCATE(YBEM_PARAMS%XCAP_SYS_HEAT) ! Capacity of the heating system
DEALLOCATE(YBEM_PARAMS%XCOP_RAT)      ! Rated COP of the cooling system
DEALLOCATE(YBEM_PARAMS%CNATVENT)      ! flag to activate natural ventilation 'NONE', 'MANU', 'AUTO'
DEALLOCATE(YBEM_PARAMS%XN_FLOOR)        ! Number of floors
DEALLOCATE(YBEM_PARAMS%XGLAZ_O_BLD)     ! Window area [m2_win/m2_bld]
DEALLOCATE(YBEM_PARAMS%XMASS_O_BLD)     ! Mass area [m2_mass/m2_bld]
DEALLOCATE(YBEM_PARAMS%XFLOOR_HW_RATIO) ! H/W ratio of 1 floor level
DEALLOCATE(YBEM_PARAMS%XF_FLOOR_MASS)   ! View factor floor-mass
DEALLOCATE(YBEM_PARAMS%XF_FLOOR_WALL)   ! View factor floor-wall
DEALLOCATE(YBEM_PARAMS%XF_FLOOR_WIN)    ! View factor floor-window
DEALLOCATE(YBEM_PARAMS%XF_FLOOR_ROOF)   ! View factor floor-roof
DEALLOCATE(YBEM_PARAMS%XF_WALL_FLOOR)   ! View factor wall-floor
DEALLOCATE(YBEM_PARAMS%XF_WALL_MASS)    ! View factor wall-mass
DEALLOCATE(YBEM_PARAMS%XF_WALL_WIN)     ! View factor wall-win
DEALLOCATE(YBEM_PARAMS%XF_WIN_FLOOR)    ! View factor win-floor
DEALLOCATE(YBEM_PARAMS%XF_WIN_MASS)     ! View factor win-mass
DEALLOCATE(YBEM_PARAMS%XF_WIN_WALL)     ! View factor win-wall
DEALLOCATE(YBEM_PARAMS%XF_WIN_WIN)      ! indoor View factor win-win
DEALLOCATE(YBEM_PARAMS%XF_MASS_FLOOR)   ! View factor mass-floor
DEALLOCATE(YBEM_PARAMS%XF_MASS_WALL)    ! View factor mass-wall
DEALLOCATE(YBEM_PARAMS%XF_MASS_WIN)     ! View factor mass-window
END SUBROUTINE DEALLOC_BEM_PARAMS

END MODULE MODD_BEM_PARAMS_n

