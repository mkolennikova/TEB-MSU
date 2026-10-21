!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!   ##########################################################################
    SUBROUTINE ALLOC_TEB_STRUCT(KROOF_LAYER,KROAD_LAYER,KWALL_LAYER,KFLOOR_LAYER,&
                               TOPTS,TSTATE,BOPTS,BSTATE,TPN,TIR                           )
!   ##########################################################################
!
!!****  *ALLOC_TEB_STRUCT*
!!
!!    PURPOSE
!!    -------
!
!       To allocate all the structures used in Teb_garden and subsequent routines.
!
!!**  METHOD
!     ------
!
!
!!    EXTERNAL
!!    --------
!!
!!
!!    IMPLICIT ARGUMENTS
!!    ------------------
!!
!!      
!!    REFERENCE
!!    ---------
!!
!!      
!!    AUTHOR
!!    ------
!!
!!      V. Masson           * Meteo-France *
!!
!!    MODIFICATIONS
!!    -------------
!!    Original    03/2018
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t, TEB_OPTIONS_INIT
USE MODD_TEB_n, ONLY : TEB_t, TEB_INIT
USE MODD_TEB_PARAMS_n, ONLY : TEB_PARAMS_t, TEB_PARAMS_INIT
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t, BEM_OPTIONS_INIT
USE MODD_BEM_n, ONLY : BEM_t, BEM_INIT
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t, BEM_PARAMS_INIT
USE MODD_TEB_PANEL_n, ONLY : TEB_PANEL_t, TEB_PANEL_INIT
USE MODD_TEB_IRRIG_n, ONLY : TEB_IRRIG_t, TEB_IRRIG_INIT
!
!
IMPLICIT NONE
!
!*      0.1    Declarations of arguments
!
!
!
!
INTEGER, INTENT(IN) :: KROOF_LAYER   ! number of roof layers
INTEGER, INTENT(IN) :: KROAD_LAYER   ! number of road layers
INTEGER, INTENT(IN) :: KWALL_LAYER   ! number of wall layers
INTEGER, INTENT(IN) :: KFLOOR_LAYER  ! number of floor layers
TYPE(TEB_OPTIONS_t),   INTENT(INOUT) :: TOPTS
TYPE(TEB_t),           INTENT(INOUT) :: TSTATE
TYPE(BEM_OPTIONS_t),   INTENT(INOUT) :: BOPTS
TYPE(BEM_t),           INTENT(INOUT) :: BSTATE
TYPE(TEB_PANEL_t),     INTENT(INOUT) :: TPN
TYPE(TEB_IRRIG_t),     INTENT(INOUT) :: TIR
!
!
!*      0.2    Declarations of local variables
!
!
!-------------------------------------------------------------------------------
!
CALL TEB_INIT(TSTATE)
CALL TEB_PANEL_INIT(TPN)
CALL TEB_IRRIG_INIT(TIR)
CALL BEM_INIT(BSTATE)
!
!-------------------------------------------------------------------------------
!
! BEM structure
!
!
! Floor parameters
!
!
! Static parameters of the building (component P): allocated and initialised
! before the indoor state
!
!
! HVAC parameters
!
!
! Indoor parameters
!
ALLOCATE(BSTATE%XTI_BLD(1))                    ! building interior temperature    (K)
ALLOCATE(BSTATE%XT_FLOOR (1,KFLOOR_LAYER)) ! floor layer temperatures         (K)
ALLOCATE(BSTATE%XT_MASS  (1,KFLOOR_LAYER)) ! Air cooled building internal th. mass temperature (K)
!
ALLOCATE(BSTATE%XTRAN_WIN(1))      ! window transmittance (-)
!
! New parameters
!
ALLOCATE(BSTATE%XAUX_MAX(1))      ! Auxiliar variable for autosize calcs
ALLOCATE(BSTATE%XT_WIN2(1))       ! Indoor window temperature [K]
ALLOCATE(BSTATE%XQI_BLD(1))       ! Indoor air specific humidity [kg kg-1]
                             ! [W m-2(bld)]
ALLOCATE(BSTATE%XCAP_SYS_RAT(1))  ! Rated capacity of the cooling system
                             ! [W m-2(bld)]
ALLOCATE(BSTATE%XT_ADP(1))        ! Apparatus dewpoint temperature of the
                             ! cooling coil [K]
ALLOCATE(BSTATE%XM_SYS_RAT(1))    ! Rated HVAC mass flow rate 
                             ! [kg s-1 m-2(bld)]
ALLOCATE(BSTATE%XT_WIN1(1))       ! outdoor window temperature [K]
ALLOCATE(BSTATE%XALB_WIN(1))      ! window albedo
ALLOCATE(BSTATE%XABS_WIN(1))      ! window absortance
ALLOCATE(BSTATE%XUGG_WIN(1))      ! Window glass-to-glass U-factor [K m W-2]
ALLOCATE(BSTATE%LSHADE(1))        ! flag to activate shading devices -> LOGICAL in the code
ALLOCATE(BSTATE%XSHADE(1))        ! flag to activate shading devices -> REAL for i/o 0. or 1.
ALLOCATE(BSTATE%XNATVENT(1))      ! flag to describe surventilation system for i/o 
                             ! 0 for NONE, 1 for MANU and 2 for AUTO
ALLOCATE(BSTATE%LSHAD_DAY(1))     !Has shading been necessary this day ?
ALLOCATE(BSTATE%LNATVENT_NIGHT(1))!Has nocturnal surventilation been necessary and possible this night ?
  !
  !indoor relative surfaces and view factors
!
!-------------------------------------------------------------------------------
!
! TEB structure
!
! Static parameters of the surface (component P): allocated and initialised first,
! because the model state of the TEB structure does not depend on them.
!
!
! Geometric Parameters:
!
!MV202609 z0 and zd to namelist
!
! Roof parameters
!
!
!
! Road parameters
!
!
! Wall parameters
!
!
! Building's use type
!
  
!
! anthropogenic fluxes
!
!                                                  ! heat fluxes due to traffic       (W/m2)
!                                                  ! heat fluxes due to traffic       (W/m2)
!                                                  ! heat fluxes due to factories     (W/m2)
!                                                  ! heat fluxes due to factories     (W/m2)
!
! Prognostic variables:
!
ALLOCATE(TSTATE%XWS_ROOF(1))      ! roof water reservoir             (kg/m2)
ALLOCATE(TSTATE%XWS_ROAD(1))      ! road water reservoir             (kg/m2)
ALLOCATE(TSTATE%XT_ROOF(1,KROOF_LAYER))       ! roof layer temperatures          (K)
ALLOCATE(TSTATE%XT_ROAD(1,KROAD_LAYER))       ! road layer temperatures          (K)
ALLOCATE(TSTATE%XT_WALL_A(1,KWALL_LAYER))     ! wall layer temperatures          (K)
ALLOCATE(TSTATE%XT_WALL_B(1,KWALL_LAYER))     ! wall layer temperatures          (K)
!
! Semi-prognostic variables:
!
ALLOCATE(TSTATE%XT_CANYON(1))     ! canyon air temperature           (K)
ALLOCATE(TSTATE%XQ_CANYON(1))     ! canyon air specific humidity     (kg/kg)
!
!
! Prognostic snow:
!
ALLOCATE(TSTATE%TSNOW_ROOF%WSNOW(1,1))     ! snow (& liq. water) content      (kg/m2) 
ALLOCATE(TSTATE%TSNOW_ROOF%T    (1,1))     ! temperature                      (K)
ALLOCATE(TSTATE%TSNOW_ROOF%RHO  (1,1))     ! density                          (kg m-3)
ALLOCATE(TSTATE%TSNOW_ROOF%ALB  (1))     ! albedo                           (-)
ALLOCATE(TSTATE%TSNOW_ROOF%EMIS (1))     ! emissivity                       (-)
ALLOCATE(TSTATE%TSNOW_ROOF%TS   (1))     ! Surface temperature              (K)

ALLOCATE(TSTATE%TSNOW_ROAD%WSNOW(1,1))     ! snow (& liq. water) content      (kg/m2) 
ALLOCATE(TSTATE%TSNOW_ROAD%T    (1,1))     ! temperature                      (K)
ALLOCATE(TSTATE%TSNOW_ROAD%RHO  (1,1))     ! density                          (kg m-3)
ALLOCATE(TSTATE%TSNOW_ROAD%ALB  (1))     ! albedo                           (-)
ALLOCATE(TSTATE%TSNOW_ROAD%EMIS (1))     ! emissivity                       (-)
ALLOCATE(TSTATE%TSNOW_ROAD%TS   (1))     ! Surface temperature              (K)

!-------------------------------------------------------------------------------
!
! solar panels
!
ALLOCATE(TPN%XEMIS_PANEL(1))       ! emissivity of solar panels               (-)
ALLOCATE(TPN%XALB_PANEL(1))        ! albedo of soolar panels                  (-)
ALLOCATE(TPN%XEFF_PANEL(1))        ! Efficiency coefficient of solar panels   (-)
ALLOCATE(TPN%XFRAC_PANEL(1))       ! Fraction of SOLAR panels on roofs        (-)
ALLOCATE(TPN%XTHER_PRODC_DAY(1))   ! Present day integrated thermal production of energy    (J/m2 panel)
TPN%XTHER_PRODC_DAY = 0.           ! accumulator starts at zero (P-C4: state lives in TPN)


!-------------------------------------------------------------------------------
!
! Irrigation
!
ALLOCATE(TIR%XRD_START_MONTH(1))   ! roads : start month for irrigation (included)
ALLOCATE(TIR%XRD_END_MONTH(1))     ! roads : end   month for irrigation (included)
ALLOCATE(TIR%XRD_START_HOUR(1))    ! roads : start solar hour for irrigation (included, hour)
ALLOCATE(TIR%XRD_END_HOUR(1))      ! roads : end   solar hour for irrigation (excluded, hour)
ALLOCATE(TIR%XRD_24H_IRRIG(1))     ! roads : total irrigation over 24 hours (kg/m2)
!
!-------------------------------------------------------------------------------
!
! TEB diagnostics structure
!
!
!MV202609 CBS scheme of the road (snow-to-atmosphere branch diagnostics)
!* persistent branch diagnostics of the snow-on-road exchange: they are read by
!* the canyon air nodes of the NEXT sub-step (see MODD_DIAG_MISC_TEBN), so they
!* are allocated AND set to zero here (they must not start as undefined memory)
!
!
!

                                                     ! of the building [W m-2(bld)]
                                                     ! of the building [W m-2(bld)]
                                                     ! of the building [W m-2(bld)]
                                                     ! of the building [W m-2(bld)]
                                                     ! of the building [W m-2(bld)]
                                                     ! [W m-2(tot)]
                                                     ! [W m-2(tot)]
                                                     ! [W m-2(bld)]
                                                     ! [W m-2(bld)]
                                                     ! [W m-2(bld)] 
                                                     ! [kg s-1 m-2(bld)]
                                                     ! windows [W m-2(bld)]

!
!MV202609 diagnostics moved into the container (Phase 4a)
!* The fields carry the diagnostics listed in
!* python_tests/diag_container/container_fields.csv (driver variable -> CSV column):
!* they are declared, allocated and deallocated here so that the diagnostics can
!* leave the argument lists of RUN_TEB_OFFLINE -> TEB_INTERFACE -> CALL_DRIVER in
!* the following sub-phases of the refactor.

!-------------------------------------------------------------------------------
!
!
END SUBROUTINE ALLOC_TEB_STRUCT
