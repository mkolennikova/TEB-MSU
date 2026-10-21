!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!   ##########################################################################
    SUBROUTINE DEALLOC_TEB_STRUCT(TOP,T,BOP,B,TPN,TIR)
!   ##########################################################################
!
!!****  *DEALLOC_TEB_STRUCT*
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
TYPE(TEB_OPTIONS_t),   INTENT(INOUT) :: TOP
TYPE(TEB_t),           INTENT(INOUT) :: T
TYPE(BEM_OPTIONS_t),   INTENT(INOUT) :: BOP
TYPE(BEM_t),           INTENT(INOUT) :: B
TYPE(TEB_PANEL_t),     INTENT(INOUT) :: TPN
TYPE(TEB_IRRIG_t),     INTENT(INOUT) :: TIR
!
!
!*      0.2    Declarations of local variables
!

!
!-------------------------------------------------------------------------------
!
! BEM structure
!
!
! Floor parameters
!
!
! HVAC parameters
!
!
! Indoor parameters
!
DEALLOCATE(B%XTI_BLD)                    ! building interior temperature    (K)
DEALLOCATE(B%XT_FLOOR ) ! floor layer temperatures         (K)
DEALLOCATE(B%XT_MASS  ) ! Air cooled building internal th. mass temperature (K)
!
DEALLOCATE(B%XTRAN_WIN)      ! window transmittance (-)
!
! New parameters
!
DEALLOCATE(B%XAUX_MAX)      ! Auxiliar variable for autosize calcs
DEALLOCATE(B%XT_WIN2)       ! Indoor window temperature [K]
DEALLOCATE(B%XQI_BLD)       ! Indoor air specific humidity [kg kg-1]
                             ! [W m-2(bld)]
DEALLOCATE(B%XCAP_SYS_RAT)  ! Rated capacity of the cooling system
                             ! [W m-2(bld)]
DEALLOCATE(B%XT_ADP)        ! Apparatus dewpoint temperature of the
                             ! cooling coil [K]
DEALLOCATE(B%XM_SYS_RAT)    ! Rated HVAC mass flow rate 
                             ! [kg s-1 m-2(bld)]
DEALLOCATE(B%XT_WIN1)       ! outdoor window temperature [K]
DEALLOCATE(B%XALB_WIN)      ! window albedo
DEALLOCATE(B%XABS_WIN)      ! window absortance
DEALLOCATE(B%XUGG_WIN)      ! Window glass-to-glass U-factor [K m W-2]
DEALLOCATE(B%LSHADE)        ! flag to activate shading devices -> LOGICAL in the code
DEALLOCATE(B%XSHADE)        ! flag to activate shading devices -> REAL for i/o 0. or 1.
DEALLOCATE(B%XNATVENT)      ! flag to describe surventilation system for i/o 
                             ! 0 for NONE, 1 for MANU and 2 for AUTO
DEALLOCATE(B%LSHAD_DAY)     !Has shading been necessary this day ?
DEALLOCATE(B%LNATVENT_NIGHT)!Has nocturnal surventilation been necessary and possible this night ?
  !
  !indoor relative surfaces and view factors
!
! Static parameters of the building (component P)
!
!
!-------------------------------------------------------------------------------
!
! TEB structure
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
DEALLOCATE(T%XWS_ROOF)      ! roof water reservoir             (kg/m2)
DEALLOCATE(T%XWS_ROAD)      ! road water reservoir             (kg/m2)
DEALLOCATE(T%XT_ROOF)       ! roof layer temperatures          (K)
DEALLOCATE(T%XT_ROAD)       ! road layer temperatures          (K)
DEALLOCATE(T%XT_WALL_A)     ! wall layer temperatures          (K)
DEALLOCATE(T%XT_WALL_B)     ! wall layer temperatures          (K)
!
! Semi-prognostic variables:
!
DEALLOCATE(T%XT_CANYON)     ! canyon air temperature           (K)
DEALLOCATE(T%XQ_CANYON)     ! canyon air specific humidity     (kg/kg)
!
!
! Prognostic snow:
!
DEALLOCATE(T%TSNOW_ROOF%WSNOW)     ! snow (& liq. water) content      (kg/m2) 
DEALLOCATE(T%TSNOW_ROOF%T    )     ! temperature                      (K)
DEALLOCATE(T%TSNOW_ROOF%RHO  )     ! density                          (kg m-3)
DEALLOCATE(T%TSNOW_ROOF%ALB  )     ! albedo                           (-)
DEALLOCATE(T%TSNOW_ROOF%EMIS )     ! emissivity                       (-)
DEALLOCATE(T%TSNOW_ROOF%TS   )     ! Surface temperature              (K)

DEALLOCATE(T%TSNOW_ROAD%WSNOW)     ! snow (& liq. water) content      (kg/m2) 
DEALLOCATE(T%TSNOW_ROAD%T    )     ! temperature                      (K)
DEALLOCATE(T%TSNOW_ROAD%RHO  )     ! density                          (kg m-3)
DEALLOCATE(T%TSNOW_ROAD%ALB  )     ! albedo                           (-)
DEALLOCATE(T%TSNOW_ROAD%EMIS )     ! emissivity                       (-)
DEALLOCATE(T%TSNOW_ROAD%TS   )     ! Surface temperature              (K)
!
! Static parameters of the surface (component P)
!

!-------------------------------------------------------------------------------
!
! solar panels
!
DEALLOCATE(TPN%XEMIS_PANEL)       ! emissivity of solar panels               (-)
DEALLOCATE(TPN%XALB_PANEL)        ! albedo of soolar panels                  (-)
DEALLOCATE(TPN%XEFF_PANEL)        ! Efficiency coefficient of solar panels   (-)
DEALLOCATE(TPN%XFRAC_PANEL)       ! Fraction of SOLAR panels on roofs        (-)
DEALLOCATE(TPN%XTHER_PRODC_DAY)   ! Present day integrated thermal production of energy    (J/m2 panel)


!-------------------------------------------------------------------------------
!
! Irrigation
!
DEALLOCATE(TIR%XRD_START_MONTH)   ! roads : start month for irrigation (included)
DEALLOCATE(TIR%XRD_END_MONTH)     ! roads : end   month for irrigation (included)
DEALLOCATE(TIR%XRD_START_HOUR)    ! roads : start solar hour for irrigation (included, hour)
DEALLOCATE(TIR%XRD_END_HOUR)      ! roads : end   solar hour for irrigation (excluded, hour)
DEALLOCATE(TIR%XRD_24H_IRRIG)     ! roads : total irrigation over 24 hours (kg/m2)
!
!-------------------------------------------------------------------------------
!
! TEB diagnostics structure
!
!MV202609 diagnostics moved into the container (Phase 4a)
!* The fields carry the diagnostics listed in
!* python_tests/diag_container/container_fields.csv (driver variable -> CSV column):
!* they are declared, allocated and deallocated here so that the diagnostics can
!* leave the argument lists of RUN_TEB_OFFLINE -> TEB_INTERFACE -> CALL_DRIVER in
!* the following sub-phases of the refactor.

!
!MV202609 CBS scheme of the road (snow-to-atmosphere branch diagnostics)
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

!-------------------------------------------------------------------------------
!
!
END SUBROUTINE DEALLOC_TEB_STRUCT
