!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!   ##########################################################################
    SUBROUTINE ALLOC_TEB_STRUCT(KROOF_LAYER,KROAD_LAYER,KWALL_LAYER,KFLOOR_LAYER,&
                               TOP,TP,T,BOP,BP,B,TPN,TIR                           )
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
TYPE(TEB_OPTIONS_t),   INTENT(INOUT) :: TOP
TYPE(TEB_PARAMS_t),    INTENT(INOUT) :: TP
TYPE(TEB_t),           INTENT(INOUT) :: T
TYPE(BEM_OPTIONS_t),   INTENT(INOUT) :: BOP
TYPE(BEM_PARAMS_t),    INTENT(INOUT) :: BP
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
CALL TEB_INIT(T)
CALL TEB_PANEL_INIT(TPN)
CALL TEB_OPTIONS_INIT(TOP)
CALL TEB_IRRIG_INIT(TIR)
CALL BEM_INIT(B)
CALL BEM_OPTIONS_INIT(BOP)
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
CALL BEM_PARAMS_INIT(BP)
ALLOCATE(BP%XHC_FLOOR(1,KFLOOR_LAYER)) ! floor layers heat capacity        (J/K/m3)
ALLOCATE(BP%XTC_FLOOR(1,KFLOOR_LAYER)) ! floor layers thermal conductivity (W/K/m)
ALLOCATE(BP%XD_FLOOR (1,KFLOOR_LAYER)) ! depth of floor layers             (m)
!
! HVAC parameters
!
ALLOCATE(BP%XTCOOL_TARGET(1)) ! cooling setpoint of indoor air
ALLOCATE(BP%XTHEAT_TARGET(1)) ! heating setpoint of indoor air
ALLOCATE(BP%XF_WASTE_CAN (1)) ! fraction of waste heat released into the canyon
ALLOCATE(BP%XEFF_HEAT    (1)) ! efficiency of the heating system
!
! Indoor parameters
!
ALLOCATE(B%XTI_BLD(1))                    ! building interior temperature    (K)
ALLOCATE(B%XT_FLOOR (1,KFLOOR_LAYER)) ! floor layer temperatures         (K)
ALLOCATE(B%XT_MASS  (1,KFLOOR_LAYER)) ! Air cooled building internal th. mass temperature (K)
!
ALLOCATE(BP%XQIN(1))           ! internal heat gains [W m-2(floor)]
ALLOCATE(BP%XQIN_FRAD(1))      ! radiant fraction of internal heat gains
ALLOCATE(BP%XSHGC(1))          ! solar heat gain coef. of windows
ALLOCATE(BP%XSHGC_SH(1))       ! solar heat gain coef. of windows + shading
ALLOCATE(BP%XU_WIN(1))         ! window U-factor [K m W-2]
ALLOCATE(B%XTRAN_WIN(1))      ! window transmittance (-)
ALLOCATE(BP%XGR(1))            ! glazing ratio
ALLOCATE(BP%XFLOOR_HEIGHT(1))  ! building floor height [m]
ALLOCATE(BP%XINF(1))           ! infiltration/ventilation flow rate [AC/H]
!
! New parameters
!
ALLOCATE(BP%XF_WATER_COND(1)) ! fraction of evaporation for condensers (cooling system)
ALLOCATE(B%XAUX_MAX(1))      ! Auxiliar variable for autosize calcs
ALLOCATE(BP%XQIN_FLAT(1))     ! Latent franction of internal heat gains
ALLOCATE(BP%XHR_TARGET(1))    ! Relative humidity setpoint
ALLOCATE(B%XT_WIN2(1))       ! Indoor window temperature [K]
ALLOCATE(B%XQI_BLD(1))       ! Indoor air specific humidity [kg kg-1]
ALLOCATE(BP%XV_VENT(1))       ! Ventilation flow rate [AC/H]
ALLOCATE(BP%XCAP_SYS_HEAT(1)) ! Capacity of the heating system 
                             ! [W m-2(bld)]
ALLOCATE(B%XCAP_SYS_RAT(1))  ! Rated capacity of the cooling system
                             ! [W m-2(bld)]
ALLOCATE(B%XT_ADP(1))        ! Apparatus dewpoint temperature of the
                             ! cooling coil [K]
ALLOCATE(B%XM_SYS_RAT(1))    ! Rated HVAC mass flow rate 
                             ! [kg s-1 m-2(bld)]
ALLOCATE(BP%XCOP_RAT(1))      ! Rated COP of the cooling system
ALLOCATE(B%XT_WIN1(1))       ! outdoor window temperature [K]
ALLOCATE(B%XALB_WIN(1))      ! window albedo
ALLOCATE(B%XABS_WIN(1))      ! window absortance
ALLOCATE(B%XUGG_WIN(1))      ! Window glass-to-glass U-factor [K m W-2]
ALLOCATE(B%LSHADE(1))        ! flag to activate shading devices -> LOGICAL in the code
ALLOCATE(B%XSHADE(1))        ! flag to activate shading devices -> REAL for i/o 0. or 1.
ALLOCATE(BP%CNATVENT(1))      ! flag to activate natural ventilation 'NONE', 'MANU', 'AUTO'
ALLOCATE(B%XNATVENT(1))      ! flag to describe surventilation system for i/o 
                             ! 0 for NONE, 1 for MANU and 2 for AUTO
ALLOCATE(B%LSHAD_DAY(1))     !Has shading been necessary this day ?
ALLOCATE(B%LNATVENT_NIGHT(1))!Has nocturnal surventilation been necessary and possible this night ?
  !
  !indoor relative surfaces and view factors
ALLOCATE(BP%XN_FLOOR(1))        ! Number of floors     
ALLOCATE(BP%XGLAZ_O_BLD(1))     ! Window area [m2_win/m2_bld]
ALLOCATE(BP%XMASS_O_BLD(1))     ! Mass area [m2_mass/m2_bld]
ALLOCATE(BP%XFLOOR_HW_RATIO(1)) ! H/W ratio of 1 floor level
ALLOCATE(BP%XF_FLOOR_MASS(1))   ! View factor floor-mass
ALLOCATE(BP%XF_FLOOR_WALL(1))   ! View factor floor-wall
ALLOCATE(BP%XF_FLOOR_WIN(1))    ! View factor floor-window
ALLOCATE(BP%XF_FLOOR_ROOF(1))   ! View factor floor-roof
ALLOCATE(BP%XF_WALL_FLOOR(1))   ! View factor wall-floor
ALLOCATE(BP%XF_WALL_MASS(1))    ! View factor wall-mass
ALLOCATE(BP%XF_WALL_WIN(1))     ! View factor wall-win
ALLOCATE(BP%XF_WIN_FLOOR(1))    ! View factor win-floor
ALLOCATE(BP%XF_WIN_MASS(1))     ! View factor win-mass
ALLOCATE(BP%XF_WIN_WALL(1))     ! View factor win-wall
ALLOCATE(BP%XF_WIN_WIN(1))      ! indoor View factor win-win
ALLOCATE(BP%XF_MASS_FLOOR(1))   ! View factor mass-floor
ALLOCATE(BP%XF_MASS_WALL(1))    ! View factor mass-wall
ALLOCATE(BP%XF_MASS_WIN(1))     ! View factor mass-window
!
!-------------------------------------------------------------------------------
!
! TEB structure
!
! Static parameters of the surface (component P): allocated and initialised first,
! because the model state of the TEB structure does not depend on them.
!
CALL TEB_PARAMS_INIT(TP)
!
! Geometric Parameters:
!
ALLOCATE(TP%XROAD_DIR(1))     ! Road direction (deg from North, clockwise)
ALLOCATE(TP%XGARDEN(1))       ! fraction of veg in the streets   (-)
ALLOCATE(TP%XGREENROOF(1))    ! fraction of greenroofs on roofs  (-)
ALLOCATE(TP%XBLD(1))          ! fraction of buildings            (-)
ALLOCATE(TP%XROAD(1))         ! fraction of roads                (-)
ALLOCATE(TP%XCAN_HW_RATIO(1)) ! canyon    h/W                    (-)
ALLOCATE(TP%XBLD_HEIGHT(1))   ! buildings height 'h'             (m)
ALLOCATE(TP%XWALL_O_HOR(1))   ! wall surf. / hor. surf.          (-)
ALLOCATE(TP%XROAD_O_GRND(1))  ! road surf. / (road + garden surf.) (-)
ALLOCATE(TP%XGARDEN_O_GRND(1))! gard. surf. / (road + garden surf.)(-)
ALLOCATE(TP%XWALL_O_GRND(1))  ! wall surf. / (road + garden surf.) (-)
ALLOCATE(TP%XWALL_O_BLD(1))   ! wall surf. / bld surf. (-)
ALLOCATE(TP%XZ0_TOWN(1))      ! roughness length for momentum    (m)
!MV202609 z0 and zd to namelist
ALLOCATE(TP%XZD_TOWN(1))      ! displacement height of the town  (m)
ALLOCATE(TP%XSVF_ROAD(1))     ! road sky view factor             (-)
ALLOCATE(TP%XSVF_GARDEN(1))   ! green area sky view factor       (-)
ALLOCATE(TP%XSVF_WALL(1))     ! wall sky view factor             (-)
!
! Roof parameters
!
ALLOCATE(TP%XALB_ROOF(1))     ! roof albedo                      (-)
ALLOCATE(TP%XEMIS_ROOF(1))    ! roof emissivity                  (-)
ALLOCATE(TP%XHC_ROOF(1,KROOF_LAYER))      ! roof layers heat capacity        (J/K/m3)
ALLOCATE(TP%XTC_ROOF(1,KROOF_LAYER))      ! roof layers thermal conductivity (W/K/m)
ALLOCATE(TP%XD_ROOF(1,KROOF_LAYER))       ! depth of roof layers             (m)
ALLOCATE(TP%XROUGH_ROOF(1))   ! roof roughness coef
!
!
! Road parameters
!
ALLOCATE(TP%XALB_ROAD(1))     ! road albedo                      (-)
ALLOCATE(TP%XEMIS_ROAD(1))    ! road emissivity                  (-)
ALLOCATE(TP%XHC_ROAD(1,KROAD_LAYER))      ! road layers heat capacity        (J/K/m3)
ALLOCATE(TP%XTC_ROAD(1,KROAD_LAYER))      ! road layers thermal conductivity (W/K/m)
ALLOCATE(TP%XD_ROAD(1,KROAD_LAYER))       ! depth of road layers             (m)
!
! Wall parameters
!
ALLOCATE(TP%XALB_WALL(1))     ! wall albedo                      (-)
ALLOCATE(TP%XEMIS_WALL(1))    ! wall emissivity                  (-)
ALLOCATE(TP%XHC_WALL(1,KWALL_LAYER))      ! wall layers heat capacity        (J/K/m3)
ALLOCATE(TP%XTC_WALL(1,KWALL_LAYER))      ! wall layers thermal conductivity (W/K/m)
ALLOCATE(TP%XD_WALL(1,KWALL_LAYER))       ! depth of wall layers             (m)
ALLOCATE(TP%XROUGH_WALL(1))   ! wall roughness coef
!
! Building's use type
!
ALLOCATE(TP%XRESIDENTIAL(1))  ! fraction of Residential use      (-)
  
!
! anthropogenic fluxes
!
ALLOCATE(TP%XH_TRAFFIC(1))    ! anthropogenic sensible
!                                                  ! heat fluxes due to traffic       (W/m2)
ALLOCATE(TP%XLE_TRAFFIC(1))   ! anthropogenic latent
!                                                  ! heat fluxes due to traffic       (W/m2)
ALLOCATE(TP%XH_INDUSTRY(1))   ! anthropogenic sensible                   
!                                                  ! heat fluxes due to factories     (W/m2)
ALLOCATE(TP%XLE_INDUSTRY(1))  ! anthropogenic latent
!                                                  ! heat fluxes due to factories     (W/m2)
!
! Prognostic variables:
!
ALLOCATE(T%XWS_ROOF(1))      ! roof water reservoir             (kg/m2)
ALLOCATE(T%XWS_ROAD(1))      ! road water reservoir             (kg/m2)
ALLOCATE(T%XT_ROOF(1,KROOF_LAYER))       ! roof layer temperatures          (K)
ALLOCATE(T%XT_ROAD(1,KROAD_LAYER))       ! road layer temperatures          (K)
ALLOCATE(T%XT_WALL_A(1,KWALL_LAYER))     ! wall layer temperatures          (K)
ALLOCATE(T%XT_WALL_B(1,KWALL_LAYER))     ! wall layer temperatures          (K)
!
! Semi-prognostic variables:
!
ALLOCATE(T%XT_CANYON(1))     ! canyon air temperature           (K)
ALLOCATE(T%XQ_CANYON(1))     ! canyon air specific humidity     (kg/kg)
!
!
! Prognostic snow:
!
ALLOCATE(T%TSNOW_ROOF%WSNOW(1,1))     ! snow (& liq. water) content      (kg/m2) 
ALLOCATE(T%TSNOW_ROOF%T    (1,1))     ! temperature                      (K)
ALLOCATE(T%TSNOW_ROOF%RHO  (1,1))     ! density                          (kg m-3)
ALLOCATE(T%TSNOW_ROOF%ALB  (1))     ! albedo                           (-)
ALLOCATE(T%TSNOW_ROOF%EMIS (1))     ! emissivity                       (-)
ALLOCATE(T%TSNOW_ROOF%TS   (1))     ! Surface temperature              (K)

ALLOCATE(T%TSNOW_ROAD%WSNOW(1,1))     ! snow (& liq. water) content      (kg/m2) 
ALLOCATE(T%TSNOW_ROAD%T    (1,1))     ! temperature                      (K)
ALLOCATE(T%TSNOW_ROAD%RHO  (1,1))     ! density                          (kg m-3)
ALLOCATE(T%TSNOW_ROAD%ALB  (1))     ! albedo                           (-)
ALLOCATE(T%TSNOW_ROAD%EMIS (1))     ! emissivity                       (-)
ALLOCATE(T%TSNOW_ROAD%TS   (1))     ! Surface temperature              (K)

!-------------------------------------------------------------------------------
!
! solar panels
!
ALLOCATE(TPN%XEMIS_PANEL(1))       ! emissivity of solar panels               (-)
ALLOCATE(TPN%XALB_PANEL(1))        ! albedo of soolar panels                  (-)
ALLOCATE(TPN%XEFF_PANEL(1))        ! Efficiency coefficient of solar panels   (-)
ALLOCATE(TPN%XFRAC_PANEL(1))       ! Fraction of SOLAR panels on roofs        (-)
ALLOCATE(TPN%XTHER_PRODC_DAY(1))   ! Present day integrated thermal production of energy    (J/m2 panel)


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
