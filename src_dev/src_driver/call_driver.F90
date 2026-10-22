!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 1998-2013 Meteo-France
! This is part of the TEB software governed by the CeCILL-C licence version 1.
! See LICENCE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt for details.
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-fr.txt
! The CeCILL-C licence is compatible with L-GPL
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! ======================================================================, 
!MV202609 explicit interface of the host-model adapter
!* CALL_DRIVER is the entry point of the physics (the offline driver goes through
!* RUN_TEB_OFFLINE -> teb_interface -> CALL_DRIVER). Wrapping the implementation in
!* a module gives every call site a COMPILE-TIME CHECKED interface: while it was an
!* external procedure the compiler could not see the argument list, so a wrong
!* order, type or rank of one of the ~265 arguments was silently accepted (see
!* docs/TEB_MSU_coupling_checklist.md). Wrapping (instead of an mkmf-style
!* MODI_CALL_DRIVER interface file) also avoids a second copy of the list that
!* would have to be kept in sync by hand.
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
                 BSTATE, TPN, TIR)
							
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
! ---------------------------------------------------------------
! Modules
! ---------------------------------------------------------------
!
USE MODD_CSTS,     ONLY : XCPD, XSTEFAN, XPI, XDAY, XKARMAN,   &
                          XLVTT, XLSTT, XLMTT, XRV, XRD, XG, XP00
USE MODD_SURF_ATM, ONLY: XCISMIN, XVMODMIN, LALDTHRES, XRIMAX
USE MODD_SURF_PAR, ONLY: XUNDEF
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE MODD_TEB_FORCING_n,  ONLY : TEB_FORCING_t
USE MODD_TEB_EXT_SURF_n, ONLY : TEB_EXT_SURF_t
USE MODD_FORC_ATM,       ONLY : XZREF, XUREF
USE MODD_TYPE_DATE_SURF
USE MODE_THERMOS
USE MODD_REPROD_OPER, ONLY : CQSAT
!
USE MODI_INIT_SURFCONSPHY
USE MODI_SUNPOS
USE MODI_OL_READ_ATM
USE MODI_OL_ALLOC_ATM
USE MODI_OL_TIME_INTERP_ATM
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
! Input variables from COSMO
INTEGER                           :: ntstep            !IN timestep
INTEGER                           :: icell             !IN number of cell in the block
INTEGER                           :: iblock            !IN number of block
REAL                              :: dt                !IN integration timestep
INTEGER                           :: IYEAR             !IN Current year (UTC)
INTEGER                           :: IMONTH            !IN Current month (UTC)
INTEGER                           :: IDAY              !IN Current day (UTC)
INTEGER                           :: IHOUR             !IN Current hour (UTC)
INTEGER                           :: IMIN              !IN Current minute (UTC)
INTEGER                           :: ISEC              !IN Current seconds (UTC)
REAL                              :: ZTIME             !IN Current duration since start of the run(s)
REAL,DIMENSION(1)                 :: FR_URB            !IN fraction of urban area (need for AHF_TRAFFIC calculation)   
REAL,DIMENSION(1)                 :: ZLON              !IN Longitude (deg)
REAL,DIMENSION(1)                 :: ZLAT              !IN Latitude (deg)
TYPE(TEB_FORCING_t), INTENT(IN)   :: FORC              !IN atmospheric forcing of the sub-step

! Input urban parameters
                                                       ! 'UNIF' : uniform roads                       
                                                       ! 'ORIE' : specified road orientation          
                                                       ! 'UNIF' : uniform walls                       
									                   ! 'TWO ' : 2 opposite  walls
!MV202609 z0 and zd to namelist
!MV202609 garden thermal roughness (z0h)
!MV202609 greenroof model type, thermal roughness and surface humidity
										
! Input parameters for BEM                                                                                                                                       ! ||   ||

! Wind calculation
													   ! 0 - default; 1 - Wang scheme

! external garden / greenroof surface state and fluxes of the host (TEB_EXT_SURF_t);
!* the garden conductances ZCH_GD/ZCD_GD flow the other way (TEB -> host) and stay flat
TYPE(TEB_EXT_SURF_t), INTENT(IN) :: EXT
REAL,DIMENSION(1)                 :: ZCH_GD            !OUT garden transfer coefficient for heat (external model)
REAL,DIMENSION(1)                 :: ZCD_GD            !OUT garden  surf. exchange coefficient (external model)

! (P-C4) solar-panel and road-irrigation inputs moved into TPN/TIR by TEB_FILL_PARAMS

! Input/Output prognostic variables
! Input/Output semi-prognostic variables 
! Input/Output prognostic variables

! Output diagnostic variables
REAL,DIMENSION(1)                 :: ZTS_TOWN_S        !OUT town surface temperature from flux calculation  
REAL,DIMENSION(1)                 :: ZABS_SW_GRND      !OUT Shortwave radiation absorbed by ground
REAL,DIMENSION(1)                 :: ZABS_LW_GRND      !OUT Longwave radiation absorbed by ground
REAL,DIMENSION(1)                 :: ZILMO_TOP_FLUX         ! 1/length of Monin-Obukov (from fluxes)
REAL,DIMENSION(1)                 :: ZLMO_TOP          !OUT 1/length of Monin-Obukov 
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!MV202609 CBS scheme of the road (revision: three-temperature construction)
!MV202609 CBS scheme of the road
!MV202609 CBS scheme of the road (revision: puddle diagnostics)
!MV202609 garden diagnostics
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
!MV202609 greenroof diagnostics
!MV202609 greenroof-to-atm exchange diagnostics (from URBAN_DRAG)
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
 
! ---------------------------------------------------------------
! TEB Declarations
! ---------------------------------------------------------------
! Local parameters:
! ---------------------------------------------------------------
INTEGER            :: KSW         = 1   ! number of spectral bands in SW forcing
REAL               :: ZTIME_BEG         ! Time at beginning of time step   
REAL               :: XTSTEP_SURF       
INTEGER            :: JLOOP             ! loop counter 
TYPE(DATE_TIME)    :: TPTIME
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT   ! diagnostics container (owned by the driver)
TYPE(TEB_t),         INTENT(INOUT) :: TSTATE
TYPE(BEM_t),         INTENT(INOUT) :: BSTATE
TYPE(TEB_PANEL_t),   INTENT(INOUT) :: TPN
TYPE(TEB_IRRIG_t),   INTENT(INOUT) :: TIR

! Canyon geometry                                                                     

! Urban options                                                                                                                   
CHARACTER(LEN=3)   :: HIMPLICIT_WIND='NEW' ! Implicitation option for wind fluxes
CHARACTER(LEN=3)   :: HSNOW_ROOF = "1-L"! Option for roof snow                        
CHARACTER(LEN=3)   :: HSNOW_ROAD = "1-L"! Option for road snow 

! Canyon thermal properties
INTEGER            :: NWALL_LAYER       ! number of wall layers                           
INTEGER            :: NROOF_LAYER       ! number of roof layers                          
INTEGER            :: NROAD_LAYER       ! number of road layers                           
INTEGER            :: NFLOOR_LAYER      ! number of floor layers
REAL,DIMENSION(1)  :: ZD_WALL_LAYERS         ! Thickness            of 1-4 wall layers                                                        
REAL,DIMENSION(1)  :: ZD_ROOF_LAYERS         ! Thickness            of 1-4 roof layers                                                        

! Wind calculation
REAL,DIMENSION(1)  :: ZDIR             ! Wind direction (degrees)
REAL               :: XPII
REAL,DIMENSION(1:9):: ZU_CANYON_WANG   ! hor. wind in canyon due to Wang

REAL,DIMENSION(1)  :: ZVMOD_TS         ! Wind speed at forcing level limited with wind_threshold (m/s)
! Urban variables    
REAL,DIMENSION(1)  :: ZPEW_A_COEF       ! implicit coefficients                        
REAL,DIMENSION(1)  :: ZPEW_B_COEF       ! for wind coupling                            
REAL,DIMENSION(1)  :: ZPEW_A_COEF_LOWCAN!                                             
REAL,DIMENSION(1)  :: ZPEW_B_COEF_LOWCAN!                                             
!MV202609 CBS scheme of the road (revision: puddle diagnostics)
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
!MV202609 garden diagnostics
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
!MV202609 greenroof diagnostics
!MV202609 greenroof-to-atm exchange diagnostics (from URBAN_DRAG)
!MV202609 fixes of the snow melt / roof puddle water path (runoff diagnostics)

! Urban fluxes variables                                                              
REAL,DIMENSION(1)  :: DELTA_TROOF       ! temperature difference between roof and air in sensible heat flux 
REAL,DIMENSION(1)  :: DELTA_TROAD       ! temperature difference between road and air in sensible heat flux
REAL,DIMENSION(1)  :: DELTA_TWALL       ! temperature difference between wall and air in sensible heat flux               
REAL,DIMENSION(1)  :: ZH_TRAFFIC_NOW_CAN! heat fluxes due to traffic at current time-step to the canyon

! Radiative variables                                                                
                       
REAL,DIMENSION(1)  :: ZALB_TH_RED       ! thermal albedo reduction factor for the urban fabric 
                
REAL,DIMENSION(1)  :: ZALB_AVE_TWN      ! town area-averaged albedo                

REAL,DIMENSION(1)  :: ZWAKE             ! reduction of average wind speed                

! Anthropogenic heat fluxes                                                                           

! New arguments created after BEM                                                                                                                                       ! ||   ||            
REAL, DIMENSION(1) :: PFLOOR_HEIGHT      ! Floor height (m)                           
!MV202609 anthropogenic heat diagnostics
!* latent waste heat of the buildings, per horizontal surface area (as the
!* sensible one DMT%XH_WASTE(1)): it is added to the wall/roof latent fluxes and to the
!* canyon humidity by URBAN_FLUXES/AVG_URBAN_FLUXES
 

! New argument for the UTCI calculation                                               
                                                                                    
! Solar panels                                                                        

! Road watering                                                                       
                                                                                
! New arguments for shading, schedule or natural ventilation                          
REAL, DIMENSION(1)  :: ZN_FLOOR          ! Number of floors                           

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
!MV202609 z0 and zd to namelist
! z0 of the urban surface and the displacement height come from the namelist
! entries urb_z0_town and urb_zd_town: a value in metres, a fraction of the
! building height ('<value>H') or 'H/<n>'; a parameterization name is
! accepted but not implemented yet

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

IF (ntstep == 1) THEN

	! Input/Output semi-prognostic variables
	TSTATE%XT_CANYON(icell:icell)      = FORC%XTA(1:1)                 ! Canyon air temperature
	TSTATE%XQ_CANYON(icell:icell)      = FORC%XQA(1:1)                ! Outdoor specific humidity    [kg kg-1]
	
	! Input/Output prognostic variables
	BSTATE%XTI_BLD(icell) = BPARAMS%XTCOOL_TARGET(icell)     ! indoor air temperature
	BSTATE%XTI_BLD = BPARAMS%XTCOOL_TARGET(icell:icell)     ! indoor air temperature
    BSTATE%XQI_BLD(icell) = 0.0068794074      ! Indoor air specific humidity [kg kg-1]
    BSTATE%XQI_BLD = 0.0068794074      ! Indoor air specific humidity [kg kg-1]
	DMT%XWIND_CANYON(1:1)      = 1.                ! Wind speed in canyon
	ZTS_TOWN_S     = FORC%XTA(1:1)
    DMT%XTSTOWN_S(1:1)       = FORC%XTA(1:1)	
	DMT%XQSTOWN_S(1:1)     = FORC%XQA(1:1)
	
	! Roof properties
	ZD_ROOF_LAYERS = TPARAMS%XD_ROOF(icell,4) + TPARAMS%XD_ROOF(icell,3) + TPARAMS%XD_ROOF(icell,2) + TPARAMS%XD_ROOF(icell,1)
	TSTATE%XT_ROOF(icell:icell,1) = FORC%XTA(1)  ! roof layers temperatures
	TSTATE%XT_ROOF(icell:,1) = FORC%XTA(1:1)  ! roof layers temperatures
	TSTATE%XT_ROOF(icell:icell,2) = BPARAMS%XTCOOL_TARGET(icell) - ((BPARAMS%XTCOOL_TARGET(icell) - FORC%XTA(1)) * (TPARAMS%XD_ROOF(icell,4) + TPARAMS%XD_ROOF(icell,3) + TPARAMS%XD_ROOF(icell,2)) / ZD_ROOF_LAYERS(1))  ! roof layers temperatures
	TSTATE%XT_ROOF(icell:,2) = BPARAMS%XTCOOL_TARGET(icell:icell) - ((BPARAMS%XTCOOL_TARGET(icell:icell) - FORC%XTA(1:1)) * (TPARAMS%XD_ROOF(icell,4) + TPARAMS%XD_ROOF(icell,3) + TPARAMS%XD_ROOF(icell,2)) / ZD_ROOF_LAYERS)  ! roof layers temperatures
	TSTATE%XT_ROOF(icell:icell,3) = BPARAMS%XTCOOL_TARGET(icell) - ((BPARAMS%XTCOOL_TARGET(icell) - FORC%XTA(1)) * (TPARAMS%XD_ROOF(icell,4) + TPARAMS%XD_ROOF(icell,3))  / ZD_ROOF_LAYERS(1))  ! roof layers temperatures
	TSTATE%XT_ROOF(icell:,3) = BPARAMS%XTCOOL_TARGET(icell:icell) - ((BPARAMS%XTCOOL_TARGET(icell:icell) - FORC%XTA(1:1)) * (TPARAMS%XD_ROOF(icell,4) + TPARAMS%XD_ROOF(icell,3))  / ZD_ROOF_LAYERS)  ! roof layers temperatures
	TSTATE%XT_ROOF(icell:icell,4) = BPARAMS%XTCOOL_TARGET(icell) - ((BPARAMS%XTCOOL_TARGET(icell) - FORC%XTA(1)) * TPARAMS%XD_ROOF(icell,4)  / ZD_ROOF_LAYERS(1))  ! roof layers temperatures
	TSTATE%XT_ROOF(icell:,4) = BPARAMS%XTCOOL_TARGET(icell:icell) - ((BPARAMS%XTCOOL_TARGET(icell:icell) - FORC%XTA(1:1)) * TPARAMS%XD_ROOF(icell,4)  / ZD_ROOF_LAYERS)  ! roof layers temperatures
	TSTATE%XT_ROOF(icell:icell,5) = BPARAMS%XTCOOL_TARGET(icell)  ! roof layers temperatures
	TSTATE%XT_ROOF(icell:,5) = BPARAMS%XTCOOL_TARGET(icell:icell)  ! roof layers temperatures
	
	! Road properties
	TSTATE%XT_ROAD(icell:icell,1) = FORC%XTA(1)  ! road layers temperatures
	TSTATE%XT_ROAD(icell:,1) = FORC%XTA(1:1)  ! road layers temperatures
	TSTATE%XT_ROAD(icell:icell,2) = FORC%XTA(1)  ! road layers temperatures
	TSTATE%XT_ROAD(icell:,2) = FORC%XTA(1:1)  ! road layers temperatures
	TSTATE%XT_ROAD(icell:icell,3) = FORC%XTA(1)  ! road layers temperatures
	TSTATE%XT_ROAD(icell:,3) = FORC%XTA(1:1)  ! road layers temperatures
	TSTATE%XT_ROAD(icell:icell,4) = FORC%XTA(1)  ! road layers temperatures
	TSTATE%XT_ROAD(icell:,4) = FORC%XTA(1:1)  ! road layers temperatures
	TSTATE%XT_ROAD(icell:icell,5) = FORC%XTA(1)  ! road layers temperatures
	TSTATE%XT_ROAD(icell:,5) = FORC%XTA(1:1)  ! road layers temperatures
	
	! Wall properties
	ZD_WALL_LAYERS = TPARAMS%XD_WALL(icell,1) + TPARAMS%XD_WALL(icell,2) + TPARAMS%XD_WALL(icell,3) + TPARAMS%XD_WALL(icell,4)
	TSTATE%XT_WALL_A(icell:icell,1) = FORC%XTA(1)  ! wall layers temperatures
	TSTATE%XT_WALL_A(icell:,1) = FORC%XTA(1:1)  ! wall layers temperatures
	TSTATE%XT_WALL_A(icell:icell,2) = BPARAMS%XTCOOL_TARGET(icell) - ((BPARAMS%XTCOOL_TARGET(icell) - FORC%XTA(1)) * (TPARAMS%XD_WALL(icell,4) + TPARAMS%XD_WALL(icell,3) + TPARAMS%XD_WALL(icell,2)) / ZD_WALL_LAYERS(1))  ! wall layers temperatures
	TSTATE%XT_WALL_A(icell:,2) = BPARAMS%XTCOOL_TARGET(icell:icell) - ((BPARAMS%XTCOOL_TARGET(icell:icell) - FORC%XTA(1:1)) * (TPARAMS%XD_WALL(icell,4) + TPARAMS%XD_WALL(icell,3) + TPARAMS%XD_WALL(icell,2)) / ZD_WALL_LAYERS)  ! wall layers temperatures
	TSTATE%XT_WALL_A(icell:icell,3) = BPARAMS%XTCOOL_TARGET(icell) - ((BPARAMS%XTCOOL_TARGET(icell) - FORC%XTA(1)) * (TPARAMS%XD_WALL(icell,4) + TPARAMS%XD_WALL(icell,3))  / ZD_WALL_LAYERS(1))  ! wall layers temperatures
	TSTATE%XT_WALL_A(icell:,3) = BPARAMS%XTCOOL_TARGET(icell:icell) - ((BPARAMS%XTCOOL_TARGET(icell:icell) - FORC%XTA(1:1)) * (TPARAMS%XD_WALL(icell,4) + TPARAMS%XD_WALL(icell,3))  / ZD_WALL_LAYERS)  ! wall layers temperatures
	TSTATE%XT_WALL_A(icell:icell,4) = BPARAMS%XTCOOL_TARGET(icell) - ((BPARAMS%XTCOOL_TARGET(icell) - FORC%XTA(1)) * TPARAMS%XD_WALL(icell,4)  / ZD_WALL_LAYERS(1))  ! wall layers temperatures
	TSTATE%XT_WALL_A(icell:,4) = BPARAMS%XTCOOL_TARGET(icell:icell) - ((BPARAMS%XTCOOL_TARGET(icell:icell) - FORC%XTA(1:1)) * TPARAMS%XD_WALL(icell,4)  / ZD_WALL_LAYERS)  ! wall layers temperatures
	TSTATE%XT_WALL_A(icell:icell,5) = BPARAMS%XTCOOL_TARGET(icell)  ! wall layers temperatures
	TSTATE%XT_WALL_A(icell:,5) = BPARAMS%XTCOOL_TARGET(icell:icell)  ! wall layers temperatures
	TSTATE%XT_WALL_B(icell:icell,:) = TSTATE%XT_WALL_A(icell:icell,:)      ! wall layers temperatures
	TSTATE%XT_WALL_B = TSTATE%XT_WALL_A(icell:icell,:)      ! wall layers temperatures

	! Floor properties
	BSTATE%XT_FLOOR(icell:icell,1) = 292.12         ! building floor temperature
	BSTATE%XT_FLOOR(icell:icell,2) = 291.89778      ! building floor temperature
	BSTATE%XT_FLOOR(icell:icell,3) = 291.26111      ! building floor temperature
	BSTATE%XT_FLOOR(icell:icell,4) = 289.48333      ! building floor temperature
	BSTATE%XT_FLOOR(icell:icell,5) = 283.84017      ! building floor temperature
	
	! Mass properties
	BSTATE%XT_MASS(icell:icell,1) = 292.15         ! building mass temperature
	BSTATE%XT_MASS(icell:icell,2) = 292.15         ! building mass temperature
	BSTATE%XT_MASS(icell:icell,3) = 292.15         ! building mass temperature
	BSTATE%XT_MASS(icell:icell,4) = 292.15         ! building mass temperature
	BSTATE%XT_MASS(icell:icell,5) = 291.84017      ! building mass temperature
	
	! Water content at first time-step
	TSTATE%XWS_ROOF(icell) = 0.             ! roof water content (kg/m2) 
	TSTATE%XWS_ROOF = 0.             ! roof water content (kg/m2) 
	TSTATE%XWS_ROAD(icell:icell)       = 0.             ! road water content (kg/m2)
	! -----------------------------------------------------------
	! Default at first time-step : no snow
	! ----------------------------------------------------------- 
	TSTATE%TSNOW_ROOF%WSNOW(icell:icell,:) = 0.             ! Initial Amount of roof snow reservoir
	TSTATE%TSNOW_ROOF%WSNOW = 0.             ! Initial Amount of roof snow reservoir
	TSTATE%TSNOW_ROAD%WSNOW(icell:icell,:) = 0.             ! Initial Amount of road snow reservoir
	TSTATE%TSNOW_ROAD%WSNOW = 0.             ! Initial Amount of road snow reservoir
	TSTATE%TSNOW_ROOF%T(icell:icell,:) = XUNDEF         ! layer temperature   of roof snow
	TSTATE%TSNOW_ROOF%T = XUNDEF         ! layer temperature   of roof snow
	TSTATE%TSNOW_ROAD%T(icell:icell,:) = XUNDEF         ! layer temperature   of road snow
	TSTATE%TSNOW_ROAD%T = XUNDEF         ! layer temperature   of road snow
	TSTATE%TSNOW_ROOF%RHO(icell:icell,:) = XUNDEF         ! density             of roof snow
	TSTATE%TSNOW_ROOF%RHO = XUNDEF         ! density             of roof snow
	TSTATE%TSNOW_ROAD%RHO(icell:icell,:) = XUNDEF         ! density             of road snow
	TSTATE%TSNOW_ROAD%RHO = XUNDEF         ! density             of road snow
	TSTATE%TSNOW_ROOF%TS(icell) = XUNDEF         ! surface temperature of roof snow
	TSTATE%TSNOW_ROOF%TS = XUNDEF         ! surface temperature of roof snow
	TSTATE%TSNOW_ROAD%TS(icell) = XUNDEF         ! surface temperature of road snow
	TSTATE%TSNOW_ROAD%TS = XUNDEF         ! surface temperature of road snow
	TSTATE%TSNOW_ROOF%ALB(icell) = XUNDEF
	TSTATE%TSNOW_ROOF%ALB = XUNDEF
	TSTATE%TSNOW_ROAD%ALB(icell) = XUNDEF
	TSTATE%TSNOW_ROAD%ALB = XUNDEF
	TSTATE%TSNOW_ROOF%EMIS(icell) = XUNDEF
	TSTATE%TSNOW_ROOF%EMIS = XUNDEF
	TSTATE%TSNOW_ROAD%EMIS(icell) = XUNDEF
	TSTATE%TSNOW_ROAD%EMIS = XUNDEF
	! -----------------------------------------------------------
	! Default at first time-step for BEM Model
	! -----------------------------------------------------------
	BSTATE%XM_SYS_RAT(icell) = 0.0067         ! Rated HVAC mass flow rate [kg s-1 m-2(bld)]	
	BSTATE%XM_SYS_RAT = 0.0067         ! Rated HVAC mass flow rate [kg s-1 m-2(bld)]	
	BSTATE%XT_WIN1(icell) = FORC%XTA(1)              ! External window temperature
	BSTATE%XT_WIN1 = FORC%XTA(1:1)              ! External window temperature
	BSTATE%XT_WIN2(icell) = BPARAMS%XTCOOL_TARGET(icell)  ! Internal window temperature
	BSTATE%XT_WIN2 = BPARAMS%XTCOOL_TARGET(icell:icell)  ! Internal window temperature
	BSTATE%XNATVENT = 0.           ! flag to describe surventilation system for i/o 
                                       ! 0 for NONE, 1 for MANU and 2 for AUTO
	!BSTATE%LSHADE(icell:icell)         = .FALSE.      ! Are shading devices being used ?
	BSTATE%XSHADE = 0.
    BSTATE%XAUX_MAX = 5.           ! flag to activate shading devices -> REAL for i/o 0. or 1	
    BSTATE%LSHAD_DAY(icell) = .FALSE.      ! has shading been necessary this day ?
    BSTATE%LSHAD_DAY = .FALSE.      ! has shading been necessary this day ?
    BSTATE%LNATVENT_NIGHT(icell) = .FALSE.      ! has natural ventilation been necessary/possible this night ?	
    BSTATE%LNATVENT_NIGHT = .FALSE.      ! has natural ventilation been necessary/possible this night ?	
	! For REAL Cooling System
	IF (PFLOOR_HEIGHT(1) > TPARAMS%XBLD_HEIGHT(icell)) THEN
      PFLOOR_HEIGHT = TPARAMS%XBLD_HEIGHT(icell:icell)
    ENDIF
    ZN_FLOOR = FLOAT(NINT(TPARAMS%XBLD_HEIGHT(icell:icell) / PFLOOR_HEIGHT ))
    BSTATE%XCAP_SYS_RAT(icell:icell)        = BSTATE%XCAP_SYS_RAT(icell:icell) * ZN_FLOOR   ! Rated capacity of the cooling system [W m-2(bld)]

	! For (Wang, 2012) Wind Calculation
	DMT%XUSTAR_TOWN(1:1)         = 0.2 
	
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
		PRINT*, '    TOPTS%ITYPE_WIND    = ', TOPTS%ITYPE_WIND
		PRINT*, '    TPARAMS%XFAI(icell:icell,:)          = ', TPARAMS%XFAI(icell,:)
!MV202609 z0 and zd to namelist
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
ENDIF

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
CQSAT='OLD' ! saturation is computed relative to water above 0°C, and relative to ice below 0°C
!
!* various thresholds
!
XCISMIN = 0.5     ! minimum wind shear
XVMODMIN = 0.5    ! minimum wind speed
LALDTHRES = .FALSE.    ! activate aladin threshold for wind
XRIMAX = 0.2 ! Maximum richardson number for exchange coefficients computations
!

!
! -----------------------------------------------------------
! Geometric parameters
! -----------------------------------------------------------
!


!MV202609 garden roughness of an EXTERNAL garden
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
!* bridge to the forcing module of the offline host (MODD_FORC_ATM):
!* OL_TIME_INTERP_ATM builds the density and the pressure of its atmosphere with
!* the forcing height XZREF/XUREF of that module and the host converts the
!* absolute humidity with them (qv = XQA/XRHOA, rho = XRHOA); the CSV writer
!* reads the solar time and the sun position there. CALL_DRIVER refreshed these
!* five fields at every sub-step; they are now copied from the container at the
!* same point of the step, so the host keeps seeing the same values
XZREF  (1:1) = FORC%XZREF(icell:icell)
XUREF  (1:1) = FORC%XUREF(icell:icell)
DMT%XTS_ROOF(1:1)    = 0.
DMT%XTS_ROAD(1:1)    = 0.
DMT%XTS_WALL_A(1:1)  = 0.
DMT%XTS_WALL_B(1:1)  = 0.
DMT%XTSTOWN_S_NOW(1:1)   = DMT%XTSTOWN_S(1:1)
DMT%XWSTOWN_NOW(1:1)     = DMT%XWSTOWN(1:1)
DMT%XTSSNOW_TOWN_NOW(1:1) = DMT%XTSSNOW_TOWN(1:1)
DMT%XWSNOW_TOWN_NOW(1:1)  = DMT%XWSNOW_TOWN(1:1)
DMT%XRSNOW_TOWN_NOW(1:1)  = DMT%XRSNOW_TOWN(1:1)
DMT%XHSNOW_TOWN_NOW(1:1)  = DMT%XHSNOW_TOWN(1:1)
ZTIME_BEG = ZTIME           ! time at beginning of time step
XTSTEP_SURF = dt
TPTIME%TIME= ZTIME
TPTIME%TDATE%YEAR =IYEAR
TPTIME%TDATE%MONTH=IMONTH
TPTIME%TDATE%DAY  =IDAY
! Calculation of Wind Speed inside the canyon
! -----------------------------------------------------------
! Wind speed at the top of the canyon (roof level), from the logarithmic
! profile referenced to the displacement height TPARAMS%XZD_TOWN(icell:icell)
DMT%XWIND_TOP(1:1) = FORC%XVMOD(1:1) * LOG( (        TPARAMS%XBLD_HEIGHT(icell:icell) - TPARAMS%XZD_TOWN(icell:icell)) / TPARAMS%XZ0_TOWN(icell:icell))   &
	/ LOG( (FORC%XZREF(1:1) + TPARAMS%XBLD_HEIGHT(icell:icell) - TPARAMS%XZD_TOWN(icell:icell)) / TPARAMS%XZ0_TOWN(icell:icell))
IF (TOPTS%ITYPE_WIND == 0) THEN
	ZWAKE = 1. + (2./XPI-1.) * 2. * (TPARAMS%XCAN_HW_RATIO(icell:icell)-0.5)
	ZWAKE = MAX(MIN(ZWAKE,1.),2./XPI)
	DMT%XWIND_CANYON(1:1) = ZWAKE * EXP(-TPARAMS%XCAN_HW_RATIO(icell:icell)/4.) * DMT%XWIND_TOP(1)
ELSEIF (TOPTS%ITYPE_WIND == 1) THEN
	CALL WIND_CALCULATION_WANG(icell, iblock, TPARAMS%XBLD_HEIGHT(icell:icell), DMT%XUSTAR_TOWN(1:1), DMT%XWIND_TOP(1:1), FORC%XU(1:1), FORC%XV(1:1), TPARAMS%XFAI(icell:icell,:), ZU_CANYON_WANG)  
	DMT%XWIND_CANYON(1:1) = ZU_CANYON_WANG(5)
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

DMT%XZ0_TOWN = TPARAMS%XZ0_TOWN(icell:icell)   ! town roughness length
CALL TEB_GARDEN (icell, iblock, TOPTS, TSTATE, BOPTS, BSTATE, TPN, TIR, DMT, &
                 TOPTS%LGREENROOF_EXT, HIMPLICIT_WIND, BOPTS%LBEM_AC, FORC, EXT, HSNOW_ROOF, &
                 HSNOW_ROAD, ZPEW_A_COEF, ZPEW_B_COEF, ZPEW_A_COEF_LOWCAN, ZPEW_B_COEF_LOWCAN, &
                 KSW, ZH_TRAFFIC_NOW_CAN, XTSTEP_SURF, IDAY, ZTIME_BEG, &
                 ZCH_GD, ZCD_GD, TPARAMS, BPARAMS)
    BSTATE%XTI_BLD(icell)               = BSTATE%XTI_BLD(icell)
    BSTATE%XQI_BLD(icell)               = BSTATE%XQI_BLD(icell)
    BSTATE%XT_WIN1(icell)               = BSTATE%XT_WIN1(icell)
    BSTATE%XT_WIN2(icell)               = BSTATE%XT_WIN2(icell)
    BSTATE%XCAP_SYS_RAT(icell)          = BSTATE%XCAP_SYS_RAT(icell)
    BSTATE%XM_SYS_RAT(icell)            = BSTATE%XM_SYS_RAT(icell)
    BSTATE%LSHAD_DAY(icell)             = BSTATE%LSHAD_DAY(icell)
    BSTATE%LNATVENT_NIGHT(icell)        = BSTATE%LNATVENT_NIGHT(icell)
    TSTATE%XT_ROOF(icell,:)             = TSTATE%XT_ROOF(icell,:)
    TSTATE%XT_ROAD(icell,:)             = TSTATE%XT_ROAD(icell,:)
    TSTATE%XT_WALL_A(icell,:)           = TSTATE%XT_WALL_A(icell,:)
    TSTATE%XT_WALL_B(icell,:)           = TSTATE%XT_WALL_B(icell,:)
    TSTATE%XWS_ROOF(icell)              = TSTATE%XWS_ROOF(icell)
    TSTATE%TSNOW_ROOF%WSNOW(icell,:)         = TSTATE%TSNOW_ROOF%WSNOW(icell,:)
    TSTATE%TSNOW_ROOF%T(icell,:)         = TSTATE%TSNOW_ROOF%T(icell,:)
    TSTATE%TSNOW_ROOF%RHO(icell,:)         = TSTATE%TSNOW_ROOF%RHO(icell,:)
    TSTATE%TSNOW_ROOF%ALB(icell)           = TSTATE%TSNOW_ROOF%ALB(icell)
    TSTATE%TSNOW_ROOF%EMIS(icell)           = TSTATE%TSNOW_ROOF%EMIS(icell)
    TSTATE%TSNOW_ROOF%TS(icell)          = TSTATE%TSNOW_ROOF%TS(icell)
    TSTATE%TSNOW_ROAD%WSNOW(icell,:)         = TSTATE%TSNOW_ROAD%WSNOW(icell,:)
    TSTATE%TSNOW_ROAD%T(icell,:)         = TSTATE%TSNOW_ROAD%T(icell,:)
    TSTATE%TSNOW_ROAD%RHO(icell,:)         = TSTATE%TSNOW_ROAD%RHO(icell,:)
    TSTATE%TSNOW_ROAD%ALB(icell)           = TSTATE%TSNOW_ROAD%ALB(icell)
    TSTATE%TSNOW_ROAD%EMIS(icell)           = TSTATE%TSNOW_ROAD%EMIS(icell)
    TSTATE%TSNOW_ROAD%TS(icell)          = TSTATE%TSNOW_ROAD%TS(icell)
!*****************************************************************************
!*****************************************************************************
!*****************************************************************************
!*****************************************************************************
!

IF (ntstep == 1) THEN
	DMT%XTSTOWN_S_NOW(1:1) = DMT%XTSTOWN_S(1:1)
END IF

DMT%XQSTOWN_S(1:1)    = FORC%XQA(1:1) * FORC%XEXNS(1:1) / FORC%XEXNA(1:1) + DMT%XLE_TOWN(1) / (FORC%XRHOA(1:1) * XLVTT * DMT%XTCH_TOWN(1) * FORC%XVMOD(1:1))

DMT%XWSTOWN(1:1)      = (TSTATE%XWS_ROOF(icell) * TPARAMS%XBLD(icell:icell) + TSTATE%XWS_ROAD(icell:icell) * TPARAMS%XROAD(icell:icell)) * 0.001
!DMT%XRUNOFF_TOWN(1:1)  = DMT%XRUNOFF_TOWN(1) * dt

DMT%XTSSNOW_TOWN(1:1)  = (TSTATE%TSNOW_ROOF%TS(icell) * TPARAMS%XBLD(icell:icell) * DMT%XPDN_RF(1) + TSTATE%TSNOW_ROAD%TS(icell) * TPARAMS%XROAD(icell:icell) * DMT%XPDN_RD(1)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell))
DMT%XWSNOW_TOWN(1:1)   = (TSTATE%TSNOW_ROOF%WSNOW(icell,1) * TPARAMS%XBLD(icell:icell) * DMT%XPDN_RF(1) + TSTATE%TSNOW_ROAD%WSNOW(icell,1) * TPARAMS%XROAD(icell:icell) * DMT%XPDN_RD(1)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell)) * 0.001
DMT%XRSNOW_TOWN(1:1)   = (TSTATE%TSNOW_ROOF%RHO(icell,1) * TPARAMS%XBLD(icell:icell) * DMT%XPDN_RF(1) + TSTATE%TSNOW_ROAD%RHO(icell,1) * TPARAMS%XROAD(icell:icell) * DMT%XPDN_RD(1)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell))
DMT%XSHFL_SNOW(1:1)   = (DMT%XH_SNOW_ROOF(1) * TPARAMS%XBLD(icell:icell) * DMT%XPDN_RF(1) + DMT%XH_SNOW_ROAD(1) * TPARAMS%XROAD(icell:icell) * DMT%XPDN_RD(1)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell))
DMT%XLHFL_SNOW(1:1)  = (DMT%XLE_SNOW_ROOF(1) * TPARAMS%XBLD(icell:icell) * DMT%XPDN_RF(1) + DMT%XLE_SNOW_ROAD(1) * TPARAMS%XROAD(icell:icell) * DMT%XPDN_RD(1)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell))
DMT%XFRSNOW(1:1)      = (DMT%XPDN_RF(1) * TPARAMS%XBLD(icell:icell) + DMT%XPDN_RD(1) * TPARAMS%XROAD(icell:icell)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell))
DMT%XHSNOW_TOWN(1:1)   = (DMT%XSNOWD_ROOF(1) * TPARAMS%XBLD(icell:icell) * DMT%XPDN_RF(1) + DMT%XSNOWD_ROAD(1) * TPARAMS%XROAD(icell:icell) * DMT%XPDN_RD(1)) / (TPARAMS%XBLD(icell:icell) + TPARAMS%XROAD(icell:icell))


!Town area-averaged albedo 
!Albedo of Green garden and Green roofs is manualy added: 0.15. Fix later!
ZALB_AVE_TWN = TPARAMS%XBLD(icell:icell) * (1.- TPARAMS%XGREENROOF(icell:icell)) * (1-DMT%XPDN_RF(1)) * TPARAMS%XALB_ROOF(icell:icell) * (1.-TPN%XFRAC_PANEL(1))                    &
                  + TPARAMS%XBLD(icell:icell) * (1.-TPARAMS%XGREENROOF(icell:icell)) * DMT%XPDN_RF(1) * TSTATE%TSNOW_ROOF%ALB(icell) * (1.-TPN%XFRAC_PANEL(1))                  &
                  + TPARAMS%XBLD(icell:icell) *     TPARAMS%XGREENROOF(icell:icell)               * EXT%XALB_GR(icell) * (1.-TPN%XFRAC_PANEL(1))                     &
                  + TPARAMS%XBLD(icell:icell) * TPN%XALB_PANEL(1) * TPN%XFRAC_PANEL(1)                                            &
                  + TPARAMS%XROAD(icell:icell) * ( TPARAMS%XSVF_ROAD(icell:icell) * (1-DMT%XPDN_RD(1)) * TPARAMS%XALB_ROAD(icell:icell)                                    &
                  + TPARAMS%XSVF_ROAD(icell:icell) * DMT%XPDN_RD(1) * TSTATE%TSNOW_ROAD%ALB(icell))                                               &
                  + TPARAMS%XGARDEN(icell:icell) *    TPARAMS%XSVF_GARDEN(icell:icell) * 0.15                                                 &
                  + TPARAMS%XWALL_O_HOR(icell:icell) *    TPARAMS%XSVF_WALL(icell:icell)         * TPARAMS%XALB_WALL(icell:icell)


!  Instantaneous diagnostics
DMT%XTS_ROOF(1:1) = TSTATE%XT_ROOF(icell,1)
DMT%XTS_ROAD(1:1) = TSTATE%XT_ROAD(icell,1)
DMT%XTS_WALL_A(1:1) = TSTATE%XT_WALL_A(icell,1)
DMT%XTS_WALL_B(1:1) = TSTATE%XT_WALL_B(icell,1)

!MV202610 mean radiant temperature of a pedestrian standing on the road
!* pure diagnostic: it needs the surface temperatures of this sub-step (set just
!* above), the incident shortwave components of URBAN_SOLAR_ABS (DMT%XSW_*) and
!* the canyon geometry of TPARAMS; no feedback on the physics. The projection
!* factor of a STANDING person is used here ('PERSON': the beam factor depends on
!* the solar elevation); 'SPHERE' - the default of URBAN_MRT, the globe-like
!* definition - remains available as an alternative
CALL URBAN_MRT(icell, iblock, FORC, TPARAMS, TSTATE, DMT, EXT, 'PERSON')
!MV202610 the same pedestrian on the roof: only the sky and the roof itself
CALL URBAN_MRT_ROOF(icell, iblock, FORC, TPARAMS, TSTATE, DMT, EXT, 'PERSON')

DMT%XH_ROOF_FR(1:1) = DMT%XH_ROOF(1)*TPARAMS%XBLD(icell:icell)
!MV202609 CBS scheme of the road
!* road fluxes (per m2 of road) as computed by the road energy budget, i.e. the
!* tau-aggregated fluxes when the CBS scheme is activated (see TEB_GARDEN/TEB)
!MV202609 CBS scheme of the road (revision: puddle diagnostics)
!* road water diagnostics: effective (water-limited) conductances of both branches,
!* snow fraction and liquid/snow components of the road latent heat flux
!MV202609 garden diagnostics
!* per-m2-of-garden surface diagnostics (net radiation, fluxes, surface
!* temperature, conductance and saturation humidity)
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
!MV202609 greenroof diagnostics
!MV202609 greenroof-to-atm exchange diagnostics (from URBAN_DRAG)
!
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
!* roof water diagnostics: snow fraction and liquid/snow components of the roof
!* latent heat flux (tile-mean, as computed by TEB for the roof reservoir drain)
!
!MV202609 fixes of the snow melt / roof puddle water path (runoff diagnostics)
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

!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!* 1/L of the town computed from the fluxes (not exported; distinct from ZILMO_TOP_EXCH
!* which receives the 1/L from TEB, empty under MASC95)
ZILMO_TOP_FLUX = -(DMT%XUSTAR_TOWN(1)**3 * FORC%XTA(1:1)) / (XKARMAN * XG * DMT%XH_TOWN(1) / (XCPD * FORC%XRHOA(1:1)))

IF (ZILMO_TOP_FLUX(1) < 0.) THEN
	ZILMO_TOP_FLUX = MIN(-TPARAMS%XBLD_HEIGHT(icell:icell) / 150., ZILMO_TOP_FLUX)
ELSE
	ZILMO_TOP_FLUX = MAX(TPARAMS%XBLD_HEIGHT(icell:icell) / 150., ZILMO_TOP_FLUX)
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