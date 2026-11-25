!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 1998-2013 Meteo-France
! This is part of the TEB software governed by the CeCILL-C licence version 1.
! See LICENCE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt for details.
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-fr.txt
! The CeCILL-C licence is compatible with L-GPL
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! ======================================================================, 
!* The module interface checks CALL_DRIVER arguments at compile time.
!* The host supplies configuration, forcing, external surfaces and containers;
!* this routine advances the currently loaded physical column.
MODULE MODI_CALL_DRIVER
USE MODD_TEB_n,           ONLY : TEB_t
USE MODD_BEM_n,           ONLY : BEM_t
USE MODD_TEB_PANEL_n,     ONLY : TEB_PANEL_t
USE MODD_TEB_IRRIG_n,     ONLY : TEB_IRRIG_t
USE MODI_URB_AERO_PARAMS, ONLY : URB_AERO_PARAMS
IMPLICIT NONE
CONTAINS
SUBROUTINE CALL_DRIVER (ntstep, icell, iblock, dt, IYEAR, IMONTH, IDAY, IHOUR, IMIN, ISEC, &
                        ZTIME, FR_URB, ZLON, ZLAT, FORC, EXT, ZCH_GD, ZCD_GD, &
                        DMT, TOPTS, TPARAMS, BOPTS, BPARAMS, TSTATE, &
                        BSTATE, TPN, TIR, PINV_L_TOWN_PREV)
							
! ======================================================================
! 
! ......................................................................     
!  METHOD
! ......................................................................
!
! Program designed to create, modify, and test TEB routines before being 
! actually implemented into another driver or model (e.g. SURFEX or in an
! atmospheric model)
!
! Using just TEB physical routines, new arguments can be created or
! eliminated as local variables in Driver.
!
!
! Notes:
! The current version of Driver does not include the option TEB_CANOPY.
! Outputs have to be declared in Driver.
!
!    AUTHOR
!
!	B. Bueno, Meteo-France
!
!    MODIFICATIONS
!
!      Original    08/12/10 
!      Modification   04/13 (V. Masson) adds garden     (with a proxi SVAT)
!                                            greenroofs (with a proxi SVAT)
!                                            road orientation option
!                                            separated walls option
!      Modification   10/13 (V. Masson) adds irrigation and solar panels
!      TEB-MSU development
!      Pre-repository -- Maria Tarasova (MT)
!        Adapt the standalone driver for COSMO coupling and external
!        garden/greenroof models; integrate the Wang (2012) wind profile.
!      09/2026 -- Mikhail Varentsov (MV)
!        Support configurable urban aerodynamics, CBS and diagnostic
!        garden/greenroof schemes.
!      10/2026 -- Mikhail Varentsov (MV)
!        Integrate pedestrian mean radiant temperature calculations for the road
!        canyon and roof.
!      10-11/2026 -- Mikhail Varentsov (MV)
!        Reorganize the model entry around explicit containers and separate
!        physics calls from offline forcing and output.
!      11/2026 -- OpenAI Codex
!        Select the canyon wind calculation by its scheme name.
!        Diagnose stability-dependent town roughness from the previous step
!        and pass it to the wind profile and both town exchange calculations.
!        Diagnose town displacement from the same stability history.
! ---------------------------------------------------------------
! Modules
! ---------------------------------------------------------------
!
USE, INTRINSIC :: IEEE_ARITHMETIC, ONLY : IEEE_IS_FINITE
USE MODD_CSTS,     ONLY : XCPD, XSTEFAN, XPI, XDAY,   &
                          XLVTT, XLSTT, XLMTT, XRV, XRD, XG, XP00
USE MODD_SURF_ATM, ONLY: XCISMIN, XVMODMIN, LALDTHRES, XRIMAX
USE MODD_SURF_PAR, ONLY: XUNDEF
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE MODD_TEB_FORCING_n,  ONLY : TEB_FORCING_t
USE MODD_TEB_EXT_SURF_n, ONLY : TEB_EXT_SURF_t
USE MODD_TYPE_DATE_SURF
USE MODE_THERMOS
USE MODD_REPROD_OPER, ONLY : CQSAT
!
USE MODI_INIT_SURFCONSPHY
USE MODI_SUNPOS
USE MODI_TEB_GARDEN
USE MODI_URBAN_MRT
USE MODI_WINDOW_DATA_STRUCT
USE MODI_BEM_MORPHO_STRUCT
USE MODI_CIRCUMSOLAR_RAD
USE WIND_PROFILE_WANG
USE MODI_WIND_THRESHOLD
USE AHF_TRAFFIC_NOW
!
!
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_PARAMS_n, ONLY : TEB_PARAMS_t
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t
!* Console: the model prints nothing on its own, except errors and the dump of
!* the configuration that the host asks for with TEB_LOG_SET_VERBOSE
USE TEB_LOG, ONLY : TEB_LOG_VERBOSE_FIRST
IMPLICIT NONE
TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: TOPTS
TYPE(TEB_PARAMS_t),  INTENT(INOUT) :: TPARAMS
TYPE(BEM_OPTIONS_t), INTENT(INOUT) :: BOPTS
TYPE(BEM_PARAMS_t),  INTENT(INOUT) :: BPARAMS
! ---------------------------------------------------------------
! Declaration of variables 
! ---------------------------------------------------------------
! Input variables from the host
INTEGER, INTENT(IN) :: ntstep              !IN timestep
INTEGER, INTENT(IN) :: icell               !IN number of cell in the block
INTEGER, INTENT(IN) :: iblock              !IN number of block
REAL, INTENT(IN) :: dt                     !IN integration timestep
INTEGER, INTENT(IN) :: IYEAR               !IN Current year (UTC)
INTEGER, INTENT(IN) :: IMONTH              !IN Current month (UTC)
INTEGER, INTENT(IN) :: IDAY                !IN Current day (UTC)
INTEGER, INTENT(IN) :: IHOUR               !IN Current hour (UTC)
INTEGER, INTENT(IN) :: IMIN                !IN Current minute (UTC)
INTEGER, INTENT(IN) :: ISEC                !IN Current seconds (UTC)
REAL, INTENT(IN) :: ZTIME                  !IN Current duration since start of the run(s)
REAL,DIMENSION(1), INTENT(IN) :: FR_URB    !IN fraction of urban area (need for AHF_TRAFFIC calculation)
REAL,DIMENSION(1), INTENT(IN) :: ZLON      !IN Longitude (deg)
REAL,DIMENSION(1), INTENT(IN) :: ZLAT      !IN Latitude (deg)
TYPE(TEB_FORCING_t), INTENT(IN)   :: FORC  !IN atmospheric forcing of the sub-step

! Input urban parameters
! 'UNIF' : uniform roads                       
! 'ORIE' : specified road orientation          
! 'UNIF' : uniform walls                       
! 'TWO ' : 2 opposite  walls
										
! Input parameters for BEM                                                                                                                                       ! ||   ||

! Wind calculation
! 0 - default; 1 - Wang scheme

! external garden / greenroof surface state and fluxes of the host (TEB_EXT_SURF_t);
!* the garden conductances ZCH_GD/ZCD_GD flow the other way (TEB -> host) and stay flat
TYPE(TEB_EXT_SURF_t), INTENT(IN) :: EXT
REAL,DIMENSION(1), INTENT(OUT) :: ZCH_GD    !OUT garden transfer coefficient for heat (external model)
REAL,DIMENSION(1), INTENT(INOUT) :: ZCD_GD  !INOUT previous/new garden momentum coefficient (external model)

! (P-C4) solar-panel and road-irrigation inputs moved into TPN/TIR by TEB_FILL_PARAMS

! Input/Output prognostic variables
! Input/Output semi-prognostic variables 
! Input/Output prognostic variables

! Output diagnostic variables
REAL,DIMENSION(1)                 :: ZTS_TOWN_S      !OUT town surface temperature from flux calculation  
REAL,DIMENSION(1)                 :: ZABS_SW_GRND    !OUT Shortwave radiation absorbed by ground
REAL,DIMENSION(1)                 :: ZABS_LW_GRND    !OUT Longwave radiation absorbed by ground
REAL,DIMENSION(1)                 :: ZLMO_TOP        !OUT 1/length of Monin-Obukov 
 
! ---------------------------------------------------------------
! TEB Declarations
! ---------------------------------------------------------------
! Local parameters:
! ---------------------------------------------------------------
INTEGER            :: KSW         = 1        ! number of spectral bands in SW forcing
REAL               :: ZTIME_BEG              ! Time at beginning of time step   
REAL               :: XTSTEP_SURF       
INTEGER            :: JLOOP                  ! loop counter 
TYPE(DATE_TIME)    :: TPTIME
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT  ! diagnostics container (owned by the driver)
TYPE(TEB_t),         INTENT(INOUT) :: TSTATE
TYPE(BEM_t),         INTENT(INOUT) :: BSTATE
TYPE(TEB_PANEL_t),   INTENT(INOUT) :: TPN
TYPE(TEB_IRRIG_t),   INTENT(INOUT) :: TIR
REAL, DIMENSION(1), OPTIONAL, INTENT(INOUT) :: PINV_L_TOWN_PREV ! 1/L in Zilitinkevich et al. (2008), m-1
REAL, PARAMETER :: ZUSTAR_MIN_DYNCORR = 0.1 ! m/s
REAL :: ZBLD_H, ZROOF_DIST, ZLOG_HEIGHT, ZZ0_MIN, ZZ0_MAX, ZZ0_RAW, ZS
REAL :: ZZD_RAW, ZZD_MAX, ZZ0_RESERVE, ZCONVECTIVE
LOGICAL :: LZ0_DYNCORR, LZD_DYNCORR, LTOWN_DYNCORR

! Canyon geometry                                                                     

! Urban options                                                                                                                   
CHARACTER(LEN=3)   :: HIMPLICIT_WIND='NEW'  ! Implicitation option for wind fluxes
CHARACTER(LEN=3)   :: HSNOW_ROOF = "1-L"    ! Option for roof snow                        
CHARACTER(LEN=3)   :: HSNOW_ROAD = "1-L"    ! Option for road snow 

! Canyon thermal properties
INTEGER            :: NWALL_LAYER     ! number of wall layers                           
INTEGER            :: NROOF_LAYER     ! number of roof layers                          
INTEGER            :: NROAD_LAYER     ! number of road layers                           
INTEGER            :: NFLOOR_LAYER    ! number of floor layers
REAL,DIMENSION(1)  :: ZD_WALL_LAYERS  ! Thickness            of 1-4 wall layers                                                        
REAL,DIMENSION(1)  :: ZD_ROOF_LAYERS  ! Thickness            of 1-4 roof layers                                                        

! Wind calculation
REAL,DIMENSION(1)  :: ZDIR            ! Wind direction (degrees)
REAL               :: XPII
REAL,DIMENSION(1:9):: ZU_CANYON_WANG  ! hor. wind in canyon due to Wang
REAL,DIMENSION(1)  :: ZU_CAN_PED      ! hor. wind at pedestrian height (1.1 m) due to Wang
REAL,DIMENSION(1)  :: ZU_CAN_10M      ! hor. wind at 10 m height due to Wang

REAL,DIMENSION(1)  :: ZVMOD_TS  ! Wind speed at forcing level limited with wind_threshold (m/s)
! Urban variables    
REAL,DIMENSION(1)  :: ZPEW_A_COEF         ! implicit coefficients                        
REAL,DIMENSION(1)  :: ZPEW_B_COEF         ! for wind coupling                            
REAL,DIMENSION(1)  :: ZPEW_A_COEF_LOWCAN  !                                             
REAL,DIMENSION(1)  :: ZPEW_B_COEF_LOWCAN  !                                             

! Urban fluxes variables                                                              
REAL,DIMENSION(1)  :: DELTA_TROOF         ! temperature difference between roof and air in sensible heat flux 
REAL,DIMENSION(1)  :: DELTA_TROAD         ! temperature difference between road and air in sensible heat flux
REAL,DIMENSION(1)  :: DELTA_TWALL         ! temperature difference between wall and air in sensible heat flux               
REAL,DIMENSION(1)  :: ZH_TRAFFIC_NOW_CAN  ! heat fluxes due to traffic at current time-step to the canyon

! Radiative variables                                                                
                       
REAL,DIMENSION(1)  :: ZALB_TH_RED  ! thermal albedo reduction factor for the urban fabric 
                
REAL :: ZPDN_RF_DIAG, ZPDN_RD_DIAG  ! snow fractions for end-of-step state diagnostics
REAL :: ZTSSNOW_RF_TERM, ZTSSNOW_RD_TERM
REAL :: ZRSNOW_RF_TERM, ZRSNOW_RD_TERM

REAL,DIMENSION(1)  :: ZWAKE  ! reduction of average wind speed                

! Anthropogenic heat fluxes                                                                           

! New arguments created after BEM                                                                                                                                       ! ||   ||            
REAL, DIMENSION(1) :: PFLOOR_HEIGHT  ! Floor height (m)                           
!* latent waste heat of the buildings, per horizontal surface area (as the
!* sensible one DMT%XH_WASTE(1)): it is added to the wall/roof latent fluxes and to the
!* canyon humidity by URBAN_FLUXES/AVG_URBAN_FLUXES
 

! New argument for the UTCI calculation                                               
                                                                                    
! Solar panels                                                                        

! Road watering                                                                       
                                                                                
! New arguments for shading, schedule or natural ventilation                          
REAL, DIMENSION(1)  :: ZN_FLOOR  ! Number of floors                           

!                                                                                    
!                                                                                     
!============================================================                        
!============================================================                         
!============================================================            
!============================================================           
!             PARAMETERS SETUP : CAPITOUL CASE                        
!============================================================         
!============================================================          
!============================================================           
!============================================================
!
! Main TEB options
!
!============================================================
!============================================================
! TEB option for z0h roof & road: 'MASC95' : Mascart et al,1995; 
!                                 'BRUT82' : Brustaert,1982; 
!                                 'KAND07' : Kanda,2007
!
!
!============================================================
!============================================================
! Urban geometry
!============================================================
!============================================================
!ZZ0         = TPARAMS%XBLD_HEIGHT(icell:icell) * 0.075   ! Roughness length (m)
! TEB_FILL_DERIVED resolves the town roughness and displacement height.
! The offline namelist supplies teb_ctype_z0_town and urb_zd_town.

!
!============================================================
!============================================================

! 
!============================================================
!============================================================
! 
!============================================================
!============================================================
! solar panels
!============================================================
!============================================================
!============================================================
!============================================================
! Parameters for Building Energy Module (BEM)
!============================================================
!============================================================
!
!=============================================================
! Building configuration
!=============================================================
!
PFLOOR_HEIGHT = 3.0     ! Floor height (m)
!
!=============================================================
! windows
!=============================================================
!
!
!=============================================================
! Shading devices
!=============================================================
!
!
!=============================================================
! HVAC system
!=============================================================
!
!
!=============================================================
! Internal target temperatures
!=============================================================
!
!=============================================================
! Heating system
!=============================================================
!
!
!=============================================================
! Cooling system
!=============================================================
!
BSTATE%XT_ADP = 285.66  ! Apparatus dewpoint temperature of the
!=============================================================
! convection coefficients option
!=============================================================
!
!
!===========================================================================
!===========================================================================
!===========================================================================
!===========================================================================
! END OF PARAMETERS SETUP
!===========================================================================
!===========================================================================
!===========================================================================
!===========================================================================
!
!                  Check First time-step values below
!
!                               ||   ||
!                               ||   ||
!                              \\     //
!                               \\   //
!                                \\ //
!                                 \\/
!
!===========================================================================
!===========================================================================
!===========================================================================
!===========================================================================
! Inizialization for first time-step
!===========================================================================
!===========================================================================
!===========================================================================
!===========================================================================

IF (TEB_LOG_VERBOSE_FIRST()) THEN
  !-------------------------------------------------------------------
  ! Print configuration parameters: once per run and only when the host
  ! asked for it (TEB_LOG_SET_VERBOSE) - the loop is per cell and per call
  !-------------------------------------------------------------------
  PRINT*, '=================================================='
  PRINT*, 'TEB-MSU Configuration Parameters (from namelists):'
  PRINT*, '  Geometry:'
  PRINT*, '    TPARAMS%XBLD(icell:icell)          = ', TPARAMS%XBLD(icell)
  PRINT*, '    TPARAMS%XGARDEN(icell:icell)       = ', TPARAMS%XGARDEN(icell)
  PRINT*, '    TPARAMS%XCAN_HW_RATIO(icell:icell) = ', TPARAMS%XCAN_HW_RATIO(icell)
  PRINT*, '    TPARAMS%XBLD_HEIGHT(icell:icell)   = ', TPARAMS%XBLD_HEIGHT(icell)
  PRINT*, '    TPARAMS%XROAD_DIR(icell:icell)     = ', TPARAMS%XROAD_DIR(icell)
  PRINT*, '    TOPTS%CROAD_DIR     = ', TOPTS%CROAD_DIR
  PRINT*, '    TOPTS%CWALL_OPT     = ', TOPTS%CWALL_OPT
  PRINT*, '  Thermal properties:'
  PRINT*, '    ZHC_ROAD_S    = ', TPARAMS%XHC_ROAD(icell,1)
  PRINT*, '    ZHC_ROOF_S    = ', TPARAMS%XHC_ROOF(icell,1)
  PRINT*, '    ZHC_WALL_S    = ', TPARAMS%XHC_WALL(icell,1)
  PRINT*, '    ZTC_ROAD_S    = ', TPARAMS%XTC_ROAD(icell,1)
  PRINT*, '    ZTC_ROOF_S    = ', TPARAMS%XTC_ROOF(icell,1)
  PRINT*, '    ZTC_WALL_S    = ', TPARAMS%XTC_WALL(icell,1)
  PRINT*, '    TPARAMS%XALB_ROAD(icell:icell)     = ', TPARAMS%XALB_ROAD(icell)
  PRINT*, '    TPARAMS%XALB_ROOF(icell:icell)     = ', TPARAMS%XALB_ROOF(icell)
  PRINT*, '    TPARAMS%XALB_WALL(icell:icell)     = ', TPARAMS%XALB_WALL(icell)
  PRINT*, '    TPARAMS%XEMIS_ROAD(icell:icell)    = ', TPARAMS%XEMIS_ROAD(icell)
  PRINT*, '    TPARAMS%XEMIS_ROOF(icell:icell)    = ', TPARAMS%XEMIS_ROOF(icell)
  PRINT*, '    TPARAMS%XEMIS_WALL(icell:icell)    = ', TPARAMS%XEMIS_WALL(icell)
  PRINT*, '  BEM parameters:'
  PRINT*, '    TOPTS%CBEM          = ', TOPTS%CBEM
  PRINT*, '    BOPTS%LBEM_AC       = ', BOPTS%LBEM_AC
  PRINT*, '    BPARAMS%XTCOOL_TARGET(icell:icell) = ', BPARAMS%XTCOOL_TARGET(icell)
  PRINT*, '    BPARAMS%XTHEAT_TARGET(icell:icell) = ', BPARAMS%XTHEAT_TARGET(icell)
  PRINT*, '    BPARAMS%XV_VENT(icell:icell)       = ', BPARAMS%XV_VENT(icell)
  PRINT*, '    BPARAMS%XINF(icell:icell)          = ', BPARAMS%XINF(icell)
  PRINT*, '    BPARAMS%XCOP_RAT(icell:icell)      = ', BPARAMS%XCOP_RAT(icell)
  PRINT*, '    BPARAMS%XGR(icell:icell)           = ', BPARAMS%XGR(icell)
  PRINT*, '    TPARAMS%XRESIDENTIAL(icell:icell)  = ', TPARAMS%XRESIDENTIAL(icell)
  PRINT*, '    TPARAMS%XDT_RES       = ', TPARAMS%XDT_RES
  PRINT*, '    TPARAMS%XDT_OFF       = ', TPARAMS%XDT_OFF
  PRINT*, '    BPARAMS%XCAP_SYS_HEAT(icell:icell) = ', BPARAMS%XCAP_SYS_HEAT(icell)
  PRINT*, '    BPARAMS%CNATVENT(icell:icell)      = ', BPARAMS%CNATVENT(icell:icell)
  PRINT*, '    BOPTS%CCOOL_COIL    = ', BOPTS%CCOOL_COIL
  PRINT*, '    BOPTS%CHEAT_COIL    = ', BOPTS%CHEAT_COIL
  PRINT*, '  Green roofs:'
  PRINT*, '    TOPTS%LGREENROOF    = ', TOPTS%LGREENROOF
  PRINT*, '    TPARAMS%XGREENROOF(icell:icell)      = ', TPARAMS%XGREENROOF(icell)
  PRINT*, '    TOPTS%LGREENROOF_EXT= ', TOPTS%LGREENROOF_EXT
  PRINT*, '  Gardens:'
  PRINT*, '    TOPTS%LGARDEN       = ', TOPTS%LGARDEN
  PRINT*, '    TOPTS%CTYPE_GARDEN   = ', TOPTS%CTYPE_GARDEN
  PRINT*, '  Solar panels:'
  PRINT*, '    TOPTS%LSOLAR_PANEL  = ', TOPTS%LSOLAR_PANEL
  PRINT*, '    TPN%XFRAC_PANEL = ', TPN%XFRAC_PANEL(1)
  PRINT*, '  Irrigation:'
  PRINT*, '    TIR%LPAR_RD_IRRIG = ', TIR%LPAR_RD_IRRIG
  PRINT*, '    TIR%XRD_START_MONTH = ', TIR%XRD_START_MONTH(1)
  PRINT*, '    TIR%XRD_END_MONTH   = ', TIR%XRD_END_MONTH(1)
  PRINT*, '    TIR%XRD_START_HOUR  = ', TIR%XRD_START_HOUR(1)
  PRINT*, '    TIR%XRD_END_HOUR    = ', TIR%XRD_END_HOUR(1)
  PRINT*, '    TIR%XRD_24H_IRRIG   = ', TIR%XRD_24H_IRRIG(1)
  PRINT*, '  Wind:'
  PRINT*, '    TOPTS%CTYPE_WIND    = ', TOPTS%CTYPE_WIND
  PRINT*, '    TPARAMS%XFAI(icell:icell,:)          = ', TPARAMS%XFAI(icell,:)
  PRINT*, '  Aerodynamics of the urban surface:'
  PRINT*, '    urb_z0_town   = ', ' -> z0   = ', TPARAMS%XZ0_TOWN(icell), ' m'
  PRINT*, '    urb_zd_town   = ', ' -> zd   = ', TPARAMS%XZD_TOWN(icell), ' m'
  PRINT*, '  Anthropogenic heat:'
  PRINT*, '    TPARAMS%XH_TRAFFIC_MEAN(icell:icell)    = ', TPARAMS%XH_TRAFFIC_MEAN(icell)
  PRINT*, '    ZH_INDUSTRY   = ', TPARAMS%XH_INDUSTRY(icell)
  PRINT*, '    TOPTS%NUTC_HOUR     = ', TOPTS%NUTC_HOUR
  PRINT*, '  Shading flag:'
  PRINT*, '    BSTATE%LSHADE(icell:icell)        = ', BSTATE%LSHADE(icell:icell)
  PRINT*, '=================================================='
END IF

!===========================================================================
!===========================================================================
!===========================================================================
!===========================================================================
!===========================================================================
!===========================================================================
!                     *** DO NOT CHANGE VALUES BELOW ***
!===========================================================================
!===========================================================================
!===========================================================================
!===========================================================================
!===========================================================================
!===========================================================================
! -----------------------------------------------------------
! Inizializations (SYSTEM)
! -----------------------------------------------------------
!
!GSHAD_DAY = .FALSE. ! has shading been necessary this day ?
!GNATVENT_NIGHT =.FALSE. ! has natural ventilation been necessary/possible this night ?
!
! coherence check
IF ( (.NOT. TOPTS%LGREENROOF) .AND. TPARAMS%XGREENROOF(icell)>0.) THEN
  print*, 'Greenroofs option   is not activated but a non-zero greenroof fraction is given'
  STOP
END IF
IF ( (.NOT. TOPTS%LGARDEN) .AND. TPARAMS%XGARDEN(icell)>0.) THEN
  print*, 'Garden     option   is not activated but a non-zero garden    fraction is given'
  STOP
END IF
IF ( TPARAMS%XBLD(icell)+TPARAMS%XGARDEN(icell)>=1.) THEN
  print*, 'The sum of garden and building fraction is larger than one, so road fraction is negative. Please check their values.'
  print*, 'TPARAMS%XGARDEN(icell:icell) = ', TPARAMS%XGARDEN(icell)
  print*, 'TPARAMS%XBLD(icell:icell) = ', TPARAMS%XBLD(icell)
  print*, 'iblock = ', iblock
  print*, 'icell = ', icell
  STOP
END IF
IF ( (.NOT. TOPTS%LSOLAR_PANEL) .AND. TPN%XFRAC_PANEL(1)>0.) THEN
  print*, 'Solar panels option is not activated but a non-zero solar panels fraction is given'
  STOP
END IF
IF ( (.NOT. TOPTS%CBEM=='BEM') .AND. BPARAMS%XGR(icell)>0.) THEN
  print*, 'Building Energy Module (BEM) is not activated but a non-zero glazing ratio is given'
  STOP
END IF
!
!
! multi layer option
! is canopy active ?  ** DO NOT CHANGE **
!
! initialization of physical constants
!
CALL INI_CSTS
!
CALL INIT_SURFCONSPHY
!
CQSAT='OLD'  ! saturation is computed relative to water above 0°C, and relative to ice below 0°C
!
!* various thresholds
!
XCISMIN = 0.5     ! minimum wind shear
XVMODMIN = 0.5    ! minimum wind speed
LALDTHRES = .FALSE.    ! activate aladin threshold for wind
XRIMAX = 0.2  ! Maximum richardson number for exchange coefficients computations
!

!
! -----------------------------------------------------------
! Geometric parameters
! -----------------------------------------------------------
!


!* for the external garden the coefficients of URBAN_DRAG are computed with the
!* roughness of the host (teb_z0_gd, container EXT%XZ0_GD); a non-physical value
!* would silently give wrong coefficients and a wrong teb_tch_gd/teb_tcm_gd to
!* the host (see the garden diagnostic scheme, section 9)
IF (TOPTS%LGARDEN .AND. (TOPTS%CTYPE_GARDEN == 'EXT' .OR. TOPTS%CTYPE_GARDEN == 'EXT_NEU')) THEN
  IF (EXT%XZ0_GD(icell) <= 0. .OR. EXT%XZ0_GD(icell) >= XUNDEF) THEN
    WRITE(*,*) 'ERROR in CALL_DRIVER: garden type ', TRIM(TOPTS%CTYPE_GARDEN), ' but ZZ0_GD_EXT = ', EXT%XZ0_GD(icell), ' m'
    WRITE(*,*) '   an external garden needs the garden roughness of the host (teb_z0_gd)'
    STOP 1
  ENDIF
ENDIF
! -----------------------------------------------------------

! -----------------------------------------------------------
! -----------------------------------------------------------
! Forcing of the sub-step
! -----------------------------------------------------------
!* the atmospheric forcing (raw values, pressure/Exner/density at the forcing
!* level, wind speed, solar time and sun position, circumsolar partition of the
!* shortwave) is filled once per sub-step by TEB_FILL_FORCING of TEB_HOST;
!* only the previous-step copies and the clock are set here
DMT%XTS_ROOF(1:1)         = 0.
DMT%XTS_ROAD(1:1)         = 0.
DMT%XTS_WALL_A(1:1)       = 0.
DMT%XTS_WALL_B(1:1)       = 0.
DMT%XTSTOWN_S_NOW(1:1)    = DMT%XTSTOWN_S(1:1)
DMT%XWSTOWN_NOW(1:1)      = DMT%XWSTOWN(1:1)
DMT%XTSSNOW_TOWN_NOW(1:1) = DMT%XTSSNOW_TOWN(1:1)
DMT%XWSNOW_TOWN_NOW(1:1)  = DMT%XWSNOW_TOWN(1:1)
DMT%XRSNOW_TOWN_NOW(1:1)  = DMT%XRSNOW_TOWN(1:1)
DMT%XHSNOW_TOWN_NOW(1:1)  = DMT%XHSNOW_TOWN(1:1)
ZTIME_BEG                 = ZTIME  ! time at beginning of time step
XTSTEP_SURF               = dt
TPTIME%TIME               = ZTIME
TPTIME%TDATE%YEAR         = IYEAR
TPTIME%TDATE%MONTH        = IMONTH
TPTIME%TDATE%DAY          = IDAY
! Calculation of Wind Speed inside the canyon
! -----------------------------------------------------------
DMT%XZ0_TOWN_NEUTRAL(1) = TPARAMS%XZ0_TOWN(icell)
DMT%XZ0_TOWN(1) = DMT%XZ0_TOWN_NEUTRAL(1)
DMT%XZD_TOWN_NEUTRAL(1) = TPARAMS%XZD_TOWN(icell)
DMT%XZD_TOWN(1) = DMT%XZD_TOWN_NEUTRAL(1)
DMT%XZ0_TOWN_S(1) = 0.
DMT%XZ0_TOWN_NEUTRAL_FALLBACK(1) = 0.
LZ0_DYNCORR = (TOPTS%CTYPE_Z0_TOWN_DYNCORR == 'ZIL2008')
LZD_DYNCORR = (TOPTS%CTYPE_ZD_TOWN_DYNCORR == 'ZIL2008')
LTOWN_DYNCORR = LZ0_DYNCORR .OR. LZD_DYNCORR
IF (LTOWN_DYNCORR) THEN
  IF (.NOT. PRESENT(PINV_L_TOWN_PREV)) ERROR STOP 'CALL_DRIVER: missing town stability history'
  IF (ntstep == 0) PINV_L_TOWN_PREV(1) = 0.

  ZBLD_H = TPARAMS%XBLD_HEIGHT(icell)
  IF (IEEE_IS_FINITE(PINV_L_TOWN_PREV(1))) THEN
    IF (ABS(PINV_L_TOWN_PREV(1)) < XUNDEF) THEN
      DMT%XZ0_TOWN_S(1) = ZBLD_H * PINV_L_TOWN_PREV(1)
    ELSE
      DMT%XZ0_TOWN_NEUTRAL_FALLBACK(1) = 1.
    ENDIF
  ELSE
    DMT%XZ0_TOWN_NEUTRAL_FALLBACK(1) = 1.
  ENDIF
  ZS = DMT%XZ0_TOWN_S(1)

  IF (ZS /= 0.) THEN
    ! Zilitinkevich et al. (2008), equations (12), (15), (16) and (17).
    ZZ0_RAW = DMT%XZ0_TOWN_NEUTRAL(1)
    ZZD_RAW = DMT%XZD_TOWN_NEUTRAL(1)
    IF (ZS > 0.) THEN
      IF (LZ0_DYNCORR) ZZ0_RAW = ZZ0_RAW / (1. + 8.13 * ZS)
      IF (LZD_DYNCORR) ZZD_RAW = ZZD_RAW + (ZBLD_H - ZZD_RAW) * (ZS / (1.05 + ZS))
    ELSE
      ZCONVECTIVE = (-ZS)**(1./3.)
      IF (LZ0_DYNCORR) ZZ0_RAW = ZZ0_RAW * (1. + 1.15 * ZCONVECTIVE)
      IF (LZD_DYNCORR) ZZD_RAW = ZZD_RAW / (1. + 0.56 * ZCONVECTIVE)
    ENDIF
    ZZ0_MIN = EPSILON(1.) * DMT%XZ0_TOWN_NEUTRAL(1)
    IF (LZD_DYNCORR) THEN
      ! In stable air use the reduced roughness to constrain displacement.
      ! In unstable air displacement decreases, so reserve the neutral z0
      ! here and constrain its growth below using the corrected displacement.
      ZZ0_RESERVE = MIN(DMT%XZ0_TOWN_NEUTRAL(1), MAX(ZZ0_RAW, ZZ0_MIN))
      ZZD_MAX = MAX(DMT%XZD_TOWN_NEUTRAL(1), &
                    ZBLD_H - ZZ0_RESERVE - MAX(0.001 * ZZ0_RESERVE, 2. * SPACING(ZBLD_H)))
      DMT%XZD_TOWN(1) = MIN(ZZD_RAW, ZZD_MAX)
    ENDIF
    IF (LZ0_DYNCORR) THEN
      ! The roof profile and Delage canyon neutral drag use logarithms.
      ZROOF_DIST = ZBLD_H - DMT%XZD_TOWN(1)
      ZLOG_HEIGHT = MIN(ZROOF_DIST, FORC%XUREF(1) + 0.5 * ZBLD_H)
      ZZ0_MAX = MAX(DMT%XZ0_TOWN_NEUTRAL(1), ZLOG_HEIGHT - MAX(0.001 * ZLOG_HEIGHT, SPACING(ZBLD_H)))
      DMT%XZ0_TOWN(1) = MIN(MAX(ZZ0_RAW, ZZ0_MIN), ZZ0_MAX)
    ENDIF
  ENDIF
ENDIF

! Wind speed at the top of the canyon (roof level), from the logarithmic
! profile referenced to the displacement height used in this step.
DMT%XWIND_TOP(1:1) = FORC%XVMOD(1:1) * LOG( (        TPARAMS%XBLD_HEIGHT(icell:icell) - DMT%XZD_TOWN(1:1)) / DMT%XZ0_TOWN(1:1))   &
  / LOG( (FORC%XZREF(1:1) + TPARAMS%XBLD_HEIGHT(icell:icell) - DMT%XZD_TOWN(1:1)) / DMT%XZ0_TOWN(1:1))
IF (TOPTS%CTYPE_WIND == 'DEF') THEN
  ZWAKE                 = 1. + (2./XPI-1.) * 2. * (TPARAMS%XCAN_HW_RATIO(icell:icell)-0.5)
  ZWAKE                 = MAX(MIN(ZWAKE,1.),2./XPI)
  DMT%XWIND_CANYON(1:1) = ZWAKE * EXP(-TPARAMS%XCAN_HW_RATIO(icell:icell)/4.) * DMT%XWIND_TOP(1)
  DMT%XU_CAN_PED(1:1)   = DMT%XWIND_CANYON(1:1)
  DMT%XU_CAN_10M(1:1)   = DMT%XWIND_CANYON(1:1)
ELSEIF (TOPTS%CTYPE_WIND == 'WANG') THEN
  CALL WIND_CALCULATION_WANG(icell, iblock, TPARAMS%XBLD_HEIGHT(icell:icell), DMT%XUSTAR_TOWN(1:1), DMT%XWIND_TOP(1:1), FORC%XU(1:1), FORC%XV(1:1), TPARAMS%XFAI(icell:icell,:), ZU_CANYON_WANG, ZU_CAN_PED, ZU_CAN_10M)
  DMT%XWIND_CANYON(1:1) = ZU_CANYON_WANG(5)
  DMT%XU_CAN_PED(1:1)   = ZU_CAN_PED(1:1)
  DMT%XU_CAN_10M(1:1)   = ZU_CAN_10M(1:1)
ENDIF

! Calculate Wind Direction from U and V components
! Forcing for TERRA to use Garden
XPII = 2.*ASIN(1.)
ZDIR = MOD(180. + 180. / XPII * atan2(FORC%XU(1),FORC%XV(1)),360.) 
DMT%XUCANYON(1:1) = -DMT%XWIND_CANYON(1)*SIN(ZDIR*XPII/180)
DMT%XVCANYON(1:1) = -DMT%XWIND_CANYON(1)*COS(ZDIR*XPII/180)	


ZPEW_A_COEF        = 0.
ZPEW_A_COEF_LOWCAN = 0.
ZPEW_B_COEF        = FORC%XVMOD(1:1)
ZPEW_B_COEF_LOWCAN = DMT%XWIND_CANYON(1:1)
	
! -----------------------------------------------------------
! Calculation of Daily Cycle of AHF TRAFFIC
! -----------------------------------------------------------	
CALL H_TRAFFIC_NOW(icell, iblock, TPARAMS%XH_TRAFFIC_MEAN(icell:icell), IHOUR, IMIN, ISEC, TOPTS%NUTC_HOUR, DMT%XAHF_TRAFFIC_NOW(1:1)) 
ZH_TRAFFIC_NOW_CAN = DMT%XAHF_TRAFFIC_NOW(1:1)
IF (FR_URB(1) >= 0.25) THEN
  ZH_TRAFFIC_NOW_CAN = ZH_TRAFFIC_NOW_CAN / FR_URB
ELSE
  ZH_TRAFFIC_NOW_CAN = 0.
ENDIF	


!*****************************************************************************
!*****************************************************************************
!                  Call of physical routines of TEB is here                  !
!*****************************************************************************
!*****************************************************************************


!
!
BOPTS%NFLOOR_LAYER = SIZE(BSTATE%XT_FLOOR,2)
TOPTS%NROOF_LAYER = SIZE(TSTATE%XT_ROOF,2)
TOPTS%NROAD_LAYER = SIZE(TSTATE%XT_ROAD,2)
TOPTS%NWALL_LAYER = SIZE(TSTATE%XT_WALL_A,2)
TOPTS%TTIME = TPTIME
TOPTS%XTSTEP = XTSTEP_SURF

CALL TEB_GARDEN (icell, iblock, TOPTS, TSTATE, BOPTS, BSTATE, TPN, TIR, DMT, &
                 TOPTS%LGREENROOF_EXT, HIMPLICIT_WIND, BOPTS%LBEM_AC, FORC, EXT, HSNOW_ROOF, &
                 HSNOW_ROAD, ZPEW_A_COEF, ZPEW_B_COEF, ZPEW_A_COEF_LOWCAN, ZPEW_B_COEF_LOWCAN, &
                 KSW, ZH_TRAFFIC_NOW_CAN, XTSTEP_SURF, IDAY, ZTIME_BEG, &
                 ZCH_GD, ZCD_GD, TPARAMS, BPARAMS)
BSTATE%XTI_BLD(icell)            = BSTATE%XTI_BLD(icell)
BSTATE%XQI_BLD(icell)            = BSTATE%XQI_BLD(icell)
BSTATE%XT_WIN1(icell)            = BSTATE%XT_WIN1(icell)
BSTATE%XT_WIN2(icell)            = BSTATE%XT_WIN2(icell)
BSTATE%XCAP_SYS_RAT(icell)       = BSTATE%XCAP_SYS_RAT(icell)
BSTATE%XM_SYS_RAT(icell)         = BSTATE%XM_SYS_RAT(icell)
BSTATE%LSHAD_DAY(icell)          = BSTATE%LSHAD_DAY(icell)
BSTATE%LNATVENT_NIGHT(icell)     = BSTATE%LNATVENT_NIGHT(icell)
TSTATE%XT_ROOF(icell,:)          = TSTATE%XT_ROOF(icell,:)
TSTATE%XT_ROAD(icell,:)          = TSTATE%XT_ROAD(icell,:)
TSTATE%XT_WALL_A(icell,:)        = TSTATE%XT_WALL_A(icell,:)
TSTATE%XT_WALL_B(icell,:)        = TSTATE%XT_WALL_B(icell,:)
TSTATE%XWS_ROOF(icell)           = TSTATE%XWS_ROOF(icell)
TSTATE%TSNOW_ROOF%WSNOW(icell,:) = TSTATE%TSNOW_ROOF%WSNOW(icell,:)
TSTATE%TSNOW_ROOF%T(icell,:)     = TSTATE%TSNOW_ROOF%T(icell,:)
TSTATE%TSNOW_ROOF%RHO(icell,:)   = TSTATE%TSNOW_ROOF%RHO(icell,:)
TSTATE%TSNOW_ROOF%ALB(icell)     = TSTATE%TSNOW_ROOF%ALB(icell)
TSTATE%TSNOW_ROOF%EMIS(icell)    = TSTATE%TSNOW_ROOF%EMIS(icell)
TSTATE%TSNOW_ROOF%TS(icell)      = TSTATE%TSNOW_ROOF%TS(icell)
TSTATE%TSNOW_ROAD%WSNOW(icell,:) = TSTATE%TSNOW_ROAD%WSNOW(icell,:)
TSTATE%TSNOW_ROAD%T(icell,:)     = TSTATE%TSNOW_ROAD%T(icell,:)
TSTATE%TSNOW_ROAD%RHO(icell,:)   = TSTATE%TSNOW_ROAD%RHO(icell,:)
TSTATE%TSNOW_ROAD%ALB(icell)     = TSTATE%TSNOW_ROAD%ALB(icell)
TSTATE%TSNOW_ROAD%EMIS(icell)    = TSTATE%TSNOW_ROAD%EMIS(icell)
TSTATE%TSNOW_ROAD%TS(icell)      = TSTATE%TSNOW_ROAD%TS(icell)
!*****************************************************************************
!*****************************************************************************
!*****************************************************************************
!*****************************************************************************
!

!* XTSTOWN_S_NOW is initialized after TEB_GARDEN by teb_interface at ntstep == 0

DMT%XQSTOWN_S(1:1)    = FORC%XQA(1:1) * FORC%XEXNS(1:1) / FORC%XEXNA(1:1) + DMT%XLE_TOWN(1) / (FORC%XRHOA(1:1) * XLVTT * DMT%XTCH_TOWN(1) * FORC%XVMOD(1:1))

DMT%XWSTOWN(1:1)      = (TSTATE%XWS_ROOF(icell) * TPARAMS%XBLD(icell:icell) + TSTATE%XWS_ROAD(icell:icell) * TPARAMS%XROAD(icell:icell)) * 0.001
!DMT%XRUNOFF_TOWN(1:1)  = DMT%XRUNOFF_TOWN(1) * dt

!* Diagnose remaining snow after evolution using local fractions.
ZPDN_RF_DIAG = 0.
IF (TSTATE%TSNOW_ROOF%WSNOW(icell,1) > 0.) ZPDN_RF_DIAG = DMT%XPDN_RF(1)
ZTSSNOW_RF_TERM = 0.
ZRSNOW_RF_TERM = 0.
IF (ZPDN_RF_DIAG > 0.) THEN
  ZTSSNOW_RF_TERM = TSTATE%TSNOW_ROOF%TS(icell)
  IF (ZTSSNOW_RF_TERM /= XUNDEF) ZTSSNOW_RF_TERM = ZTSSNOW_RF_TERM * TPARAMS%XBLD(icell) * ZPDN_RF_DIAG
  ZRSNOW_RF_TERM = TSTATE%TSNOW_ROOF%RHO(icell,1)
  IF (ZRSNOW_RF_TERM /= XUNDEF) ZRSNOW_RF_TERM = ZRSNOW_RF_TERM * TPARAMS%XBLD(icell) * ZPDN_RF_DIAG
ENDIF

ZPDN_RD_DIAG = 0.
IF (TSTATE%TSNOW_ROAD%WSNOW(icell,1) > 0.) ZPDN_RD_DIAG = DMT%XPDN_RD(1)
ZTSSNOW_RD_TERM = 0.
ZRSNOW_RD_TERM = 0.
IF (ZPDN_RD_DIAG > 0.) THEN
  ZTSSNOW_RD_TERM = TSTATE%TSNOW_ROAD%TS(icell)
  IF (ZTSSNOW_RD_TERM /= XUNDEF) ZTSSNOW_RD_TERM = ZTSSNOW_RD_TERM * TPARAMS%XROAD(icell) * ZPDN_RD_DIAG
  ZRSNOW_RD_TERM = TSTATE%TSNOW_ROAD%RHO(icell,1)
  IF (ZRSNOW_RD_TERM /= XUNDEF) ZRSNOW_RD_TERM = ZRSNOW_RD_TERM * TPARAMS%XROAD(icell) * ZPDN_RD_DIAG
ENDIF
!
DMT%XFRSNOW(1:1) = (ZPDN_RF_DIAG * TPARAMS%XBLD(icell) + ZPDN_RD_DIAG * TPARAMS%XROAD(icell)) / (TPARAMS%XBLD(icell) + TPARAMS%XROAD(icell))
! Snow temperature and density are intensive properties of the snow-covered area.
IF (ZTSSNOW_RF_TERM == XUNDEF .OR. ZTSSNOW_RD_TERM == XUNDEF .OR. DMT%XFRSNOW(1) <= 0.) THEN
  DMT%XTSSNOW_TOWN(1:1) = XUNDEF
ELSE
  DMT%XTSSNOW_TOWN(1:1) = (ZTSSNOW_RF_TERM + ZTSSNOW_RD_TERM) / ((TPARAMS%XBLD(icell) + TPARAMS%XROAD(icell)) * DMT%XFRSNOW(1))
ENDIF
IF (ZRSNOW_RF_TERM == XUNDEF .OR. ZRSNOW_RD_TERM == XUNDEF .OR. DMT%XFRSNOW(1) <= 0.) THEN
  DMT%XRSNOW_TOWN(1:1) = XUNDEF
ELSE
  DMT%XRSNOW_TOWN(1:1) = (ZRSNOW_RF_TERM + ZRSNOW_RD_TERM) / ((TPARAMS%XBLD(icell) + TPARAMS%XROAD(icell)) * DMT%XFRSNOW(1))
ENDIF
! Snow amounts already include their covered fractions after URBAN_SNOW_EVOL.
DMT%XWSNOW_TOWN(1:1) = (TSTATE%TSNOW_ROOF%WSNOW(icell,1) * TPARAMS%XBLD(icell:icell) + TSTATE%TSNOW_ROAD%WSNOW(icell,1) * TPARAMS%XROAD(icell:icell)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell)) * 0.001
DMT%XSHFL_SNOW(1:1)  = (DMT%XH_SNOW_ROOF(1) * TPARAMS%XBLD(icell:icell) * DMT%XPDN_RF(1) + DMT%XH_SNOW_ROAD(1) * TPARAMS%XROAD(icell:icell) * DMT%XPDN_RD(1)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell))
DMT%XLHFL_SNOW(1:1)  = (DMT%XLE_SNOW_ROOF(1) * TPARAMS%XBLD(icell:icell) * DMT%XPDN_RF(1) + DMT%XLE_SNOW_ROAD(1) * TPARAMS%XROAD(icell:icell) * DMT%XPDN_RD(1)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell))
DMT%XHSNOW_TOWN(1:1) = (DMT%XSNOWD_ROOF(1) * TPARAMS%XBLD(icell:icell) * DMT%XPDN_RF(1) + DMT%XSNOWD_ROAD(1) * TPARAMS%XROAD(icell:icell) * DMT%XPDN_RD(1)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell))

!  Instantaneous diagnostics
DMT%XTS_ROOF(1:1) = TSTATE%XT_ROOF(icell,1)
DMT%XTS_ROAD(1:1) = TSTATE%XT_ROAD(icell,1)
DMT%XTS_WALL_A(1:1) = TSTATE%XT_WALL_A(icell,1)
DMT%XTS_WALL_B(1:1) = TSTATE%XT_WALL_B(icell,1)

!* pure diagnostic: it needs the surface temperatures of this sub-step (set just
!* above), the incident shortwave components of URBAN_SOLAR_ABS (DMT%XSW_*) and
!* the canyon geometry of TPARAMS; no feedback on the physics. The projection
!* factor of a STANDING person is used here ('PERSON': the beam factor depends on
!* the solar elevation); 'SPHERE' - the default of URBAN_MRT, the globe-like
!* definition - remains available as an alternative
CALL URBAN_MRT(icell, iblock, FORC, TPARAMS, TSTATE, DMT, EXT, 'PERSON')
CALL URBAN_MRT_ROOF(icell, iblock, FORC, TPARAMS, TSTATE, DMT, EXT, 'PERSON')

DMT%XH_ROOF_FR(1:1) = DMT%XH_ROOF(1)*TPARAMS%XBLD(icell:icell)
!* road fluxes (per m2 of road) as computed by the road energy budget, i.e. the
!* tau-aggregated fluxes when the CBS scheme is activated (see TEB_GARDEN/TEB)
!* road water diagnostics: effective (water-limited) conductances of both branches,
!* snow fraction and liquid/snow components of the road latent heat flux
!* per-m2-of-garden surface diagnostics (net radiation, fluxes, surface
!* temperature, conductance and saturation humidity)
!
!* roof water diagnostics: snow fraction and liquid/snow components of the roof
!* latent heat flux (tile-mean, as computed by TEB for the roof reservoir drain)
!
!* water runoff of the road and of the roof reservoirs (per m2 of road / roof),
!* needed to close the water budget of the two reservoirs on every hour (the
!* runoff is the (only) term that leaves the reservoir without evaporating)
!
DMT%XH_ROAD_FR(1:1) = DMT%XPH_ROAD(1)*TPARAMS%XROAD(icell:icell)
DMT%XH_WALL_FR(1:1) = DMT%XH_WALL_A(1)*TPARAMS%XWALL_O_HOR(icell:icell)

DELTA_TROOF = DMT%XTS_ROOF(1)/FORC%XEXNS(1) - FORC%XTA(1)/FORC%XEXNA(1)
DELTA_TROAD = DMT%XTS_ROAD(1) - TSTATE%XT_CANYON(icell:icell)
DELTA_TWALL = DMT%XTS_WALL_A(1) - TSTATE%XT_CANYON(icell:icell)

! Calculate Shortwave and Longwave Surface Balance
! Forcing for TERRA to use Garden
ZABS_SW_GRND = TPARAMS%XROAD(icell:icell) /(TPARAMS%XROAD(icell:icell) + TPARAMS%XGARDEN(icell:icell)) * DMT%XABS_SW_ROAD(1) + TPARAMS%XGARDEN(icell:icell) /(TPARAMS%XROAD(icell:icell) + TPARAMS%XGARDEN(icell:icell)) * DMT%XABS_SW_GARDEN(1)
ZABS_LW_GRND = TPARAMS%XROAD(icell:icell) /(TPARAMS%XROAD(icell:icell) + TPARAMS%XGARDEN(icell:icell)) * DMT%XABS_LW_ROAD(1) + TPARAMS%XGARDEN(icell:icell) /(TPARAMS%XROAD(icell:icell) + TPARAMS%XGARDEN(icell:icell)) * DMT%XABS_LW_GARDEN(1)

IF (LTOWN_DYNCORR) THEN
  ! Dry buoyancy flux and final city-tile friction velocity for the next
  ! step. Equation (4) uses L = -u*^3/Fb, with no von Karman factor.
  PINV_L_TOWN_PREV(1) = XUNDEF
  IF (IEEE_IS_FINITE(DMT%XH_TOWN(1)) .AND. IEEE_IS_FINITE(DMT%XUSTAR_TOWN(1)) .AND. &
      IEEE_IS_FINITE(FORC%XTA(1)) .AND. IEEE_IS_FINITE(FORC%XRHOA(1))) THEN
    IF (ABS(DMT%XH_TOWN(1)) < XUNDEF .AND. DMT%XUSTAR_TOWN(1) >= ZUSTAR_MIN_DYNCORR .AND. &
        DMT%XUSTAR_TOWN(1) < XUNDEF .AND. FORC%XTA(1) > 0. .AND. FORC%XTA(1) < XUNDEF .AND. &
        FORC%XRHOA(1) > 0. .AND. FORC%XRHOA(1) < XUNDEF) THEN
      PINV_L_TOWN_PREV(1) = -(XG / FORC%XTA(1)) * (DMT%XH_TOWN(1) / (FORC%XRHOA(1) * XCPD)) &
                           / DMT%XUSTAR_TOWN(1)**3
    ENDIF
  ENDIF
ENDIF

! --------------------------------------------------------------------------------------

!DEALLOCATE(TSTATE%XT_WALL_A(icell:icell,:)) 
!DEALLOCATE(TSTATE%XT_WALL_B(icell:icell,:)) 
!DEALLOCATE(TSTATE%XT_ROOF(icell:icell,:)) 
!DEALLOCATE(TSTATE%XT_ROAD(icell:icell,:)) 

! --------------------------------------------------------------------------------------
!
END SUBROUTINE CALL_DRIVER

END MODULE MODI_CALL_DRIVER
