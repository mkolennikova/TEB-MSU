!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 1998-2013 Meteo-France
! This is part of the TEB software governed by the CeCILL-C licence version 1.
! See LICENCE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt for details.
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-fr.txt
! The CeCILL-C licence is compatible with L-GPL
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! ======================================================================, 
SUBROUTINE CALL_DRIVER (ntstep, icell, iblock, dt, IYEAR, IMONTH, IDAY, IHOUR, IMIN, ISEC, ZTIME, FR_URB, ZLON, ZLAT, ZZREF,      &
				u, v, t, qv, ps, rho, prr_con, prs_con, prr_gsp, prs_gsp, prg_gsp, lwd_s, swdir_s, swdifd_s,  &
				NROOF_LAYER1, NROAD_LAYER1, NWALL_LAYER1, NFLOOR_LAYER1, ZBLD, ZGARDEN, ZCAN_HW_RATIO,        &
				ZBLD_HEIGHT, ZHC_ROAD_S, ZHC_ROOF_S, ZHC_WALL_S, ZTC_ROAD_S, ZTC_ROOF_S, ZTC_WALL_S,          &
				ZALB_ROAD, ZALB_ROOF, ZALB_WALL, ZEMIS_ROAD, ZEMIS_ROOF, ZEMIS_WALL, ZH_TRAFFIC, ZH_INDUSTRY, &
				ZTI_BLD, ZT_ROOF, ZT_ROAD_NOW, ZT_ROAD, ZT_WALL_A, ZT_WALL_B, ZT_FLOOR, ZT_MASS, ZQI_BLD,     &
				ZT_CANYON, ZQ_CANYON, XU_CANYON, XV_CANYON, ZABS_SW_GARDEN, ZABS_LW_GARDEN, ZWS_ROOF, ZWS_ROAD,&
				ZWSNOW_ROOF, ZWSNOW_ROAD, ZTSNOW_ROOF, ZTSNOW_ROAD, ZRSNOW_ROOF, ZRSNOW_ROAD, ZTSSNOW_ROOF,   &
				ZTSSNOW_ROAD, ZASNOW_ROOF, ZASNOW_ROAD, ZESNOW_ROOF, ZESNOW_ROAD, ZT_WIN1, ZT_WIN2, ZALB_WIN, &
				ZTS_ROOF, ZTS_WALL_A, ZTS_WALL_B, ZH_TOWN, ZLE_TOWN, ZTS_TOWN_S_NOW, ZTS_TOWN, ZQS_TOWN_S,    &
				ZWS_TOWN_NOW, ZWS_TOWN, ZRUNOFF_TOWN, ZTSSNOW_TOWN_NOW, ZTSSNOW_TOWN, ZWSNOW_TOWN_NOW,        &
				ZWSNOW_TOWN, ZRSNOW_TOWN_NOW, ZRSNOW_TOWN, ZCH_TOWN, ZEVAP_TOWN, ZHSNOW_TOWN, ZLESNOW_TOWN,   &
				ZDN_TOWN, ZMELT_BLT_SUM, ZSNOWD_TOWN_NOW, ZSNOWD_TOWN, ZSO_ALB_TOWN, ZTH_ALB_TOWN,            &
				CBEM, LBEM_AC, HNATVENT, CCOOL_COIL, CHEAT_COIL, ZGR, ZTCOOL_TARGET, ZTHEAT_TARGET, ZV_VENT,  &
				ZINF, ZCOP_RAT, ZCAP_SYS_RAT, ZM_SYS_RAT, GSHAD_DAY, GNATVENT_NIGHT,                          &
				ZH_WASTE, ZHVAC_COOL, ZHVAC_HEAT, LGREENROOF, ZFRAC_GR, ZALB_GR_EXT, ZEMIS_GR_EXT, ZTSRAD_GR_EXT, ZH_GR_EXT,  &
				ZLE_GR_EXT, ZEVAP_GR_EXT,        &
				ZRUNOFF_GR_EXT, LGARDEN, ZZ0_GD_EXT, ZALB_GD_EXT, ZEMIS_GD_EXT, ZTSRAD_GD_EXT, ZQV_GD_EXT, ZH_GD_EXT, ZLE_GD_EXT, ZEVAP_GD_EXT, ZCH_GD,   &
				ZCD_GD, ZRUNOFF_GD_EXT, ITYPE_WIND, ZFAI, ZDQS_TOWN, ZGFLUX_TOWN, ZH_ROOF_FR, ZH_ROAD_FR,         &
				ZH_WALL_FR, ZAC_ROOF, ZAC_ROAD, ZAC_WALL, ZAC_TOP, ZCH_RF, ZCH_RD, ZCH_WL, ZCH_TOP, ZU_TOP,   &
                ZUSTAR_TOWN, ZCD_TERRA, ZCH_TERRA, ZH_TRAFFIC_NOW, ZRN_TOWN, ZU_CANYON, ZTS_ROAD, LGARDEN_EXT, &
				LGREENROOF_EXT, HROAD_DIR, HWALL_OPT, ZROAD_DIR, ZRESIDENTIAL, ZDT_RES, ZDT_OFF, ZCAP_SYS_HEAT, &
				LSOLAR_PANEL, ZFRAC_PANEL, LPAR_RD_IRRIG, ZRD_START_MONTH, ZRD_END_MONTH, ZRD_START_HOUR,        &
				ZRD_END_HOUR, ZRD_24H_IRRIG, ZPROD_BLD, ZUTC_HOUR, LSHADE,                                     &
!MV202609 z0 and zd to namelist
				HZ0_TOWN, HZD_TOWN)
							
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
USE MODD_TYPE_DATE_SURF
USE MODE_THERMOS
USE MODD_REPROD_OPER, ONLY : CQSAT
!
USE MODI_INIT_SURFCONSPHY
USE MODI_SUNPOS
USE MODI_OL_READ_ATM
USE MODI_OL_ALLOC_ATM
USE MODI_OL_TIME_INTERP_ATM
USE MODI_TEB_GARDEN_STRUCT
USE MODI_WINDOW_DATA_STRUCT
USE MODI_BEM_MORPHO_STRUCT
USE MODI_CIRCUMSOLAR_RAD
USE WIND_PROFILE_WANG
USE MODI_WIND_THRESHOLD
USE AHF_TRAFFIC_NOW
!
USE MODD_FORC_ATM, ONLY: CSV         ,&! name of all scalar variables
                         XDIR_ALB    ,&! direct albedo for each band
                         XSCA_ALB    ,&! diffuse albedo for each band
                         XEMIS       ,&! emissivity
                         XTSRAD      ,&! radiative temperature
                         XTSUN       ,&! solar time (s from midnight)
                         XZS         ,&! orography               (m)
                         XZREF       ,&! height of T,q forcing   (m)
                         XUREF       ,&! height of wind forcing  (m)
                         XTA         ,&! air temperature forcing (K)
                         XQA         ,&! air humidity forcing    (kg/m3)
                         XSV         ,&! scalar variables
                         XU          ,&! zonal wind              (m/s)
                         XV          ,&! meridian wind           (m/s)
                         XDIR_SW     ,&! direct  solar radiation (on horizontal surf.)
                         XSCA_SW     ,&! diffuse solar radiation (on horizontal surf.)
                         XSW_BANDS   ,&! mean wavelength of each shortwave band (m)
                         XZENITH     ,&! zenithal angle  (radian from the vertical)
                         XZENITH2    ,&! zenithal angle  (radian from the vertical)
                         XAZIM       ,&! azimuthal angle (radian from North, clockwise)
                         XLW         ,&! longwave radiation (on horizontal surf.)
                         XPS         ,&! pressure at atmospheric model surface (Pa)
                         XPA         ,&! pressure at forcing level      (Pa)
                         XRHOA       ,&! density at forcing level       (kg/m3)
                         XCO2        ,&! CO2 concentration in the air   (kg/m3)
                         XSNOW       ,&! snow precipitation             (kg/m2/s)
                         XRAIN       ,&! liquid precipitation           (kg/m2/s)
                         XSFTH       ,&! flux of heat                   (W/m2)
                         XSFTQ       ,&! flux of water vapor            (kg/m2/s)
                         XSFU        ,&! zonal momentum flux            (m/s)
                         XSFV        ,&! meridian momentum flux         (m/s)
                         XSFCO2      ,&! flux of CO2                    (kg/m2/s)
                         XSFTS       ,&! flux of scalar var.            (kg/m2/s)
                         XPEW_A_COEF ,&! implicit coefficients
                         XPEW_B_COEF ,&!
                         XPET_A_COEF ,&
                         XPEQ_A_COEF ,&
                         XPET_B_COEF ,&
                         XPEQ_B_COEF
!
IMPLICIT NONE
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
REAL,DIMENSION(1)                 :: ZZREF             !IN Atm. Forcing height above roof level

! Input forcing from COSMO
REAL,DIMENSION(1)                 :: u                 !IN zonal wind speed
REAL,DIMENSION(1)                 :: v                 !IN meridional wind speed 
REAL,DIMENSION(1)                 :: t            	   !IN temperature                            (  K  )
REAL,DIMENSION(1)                 :: qv                !IN specific water vapor content           (kg/kg)
REAL,DIMENSION(1)                 :: ps                !IN surface pressure                       ( Pa  )
REAL,DIMENSION(1)                 :: rho               !IN air density                            ( kg/m3  )
REAL,DIMENSION(1)                 :: prr_con           !IN precipitation rate of rain, convective       (kg/m2*s)
REAL,DIMENSION(1)                 :: prs_con           !IN precipitation rate of snow, convective       (kg/m2*s)
REAL,DIMENSION(1)                 :: prr_gsp           !IN precipitation rate of rain, grid-scale       (kg/m2*s)
REAL,DIMENSION(1)                 :: prs_gsp           !IN precipitation rate of snow, grid-scale       (kg/m2*s)
REAL,DIMENSION(1)                 :: prg_gsp           !IN precipitation rate of graupel, grid-scale    (kg/m2*s)
REAL,DIMENSION(1)                 :: lwd_s             !IN downward comp. of long  wave rad. flux
REAL,DIMENSION(1)                 :: swdir_s           !IN direct comp. of solar radiative flux at surface 
REAL,DIMENSION(1)                 :: swdifd_s          !IN diffuse downward comp. of short wave rad. flux

! Input urban parameters
INTEGER                           :: NWALL_LAYER1      !IN number of wall layers                           
INTEGER                           :: NROOF_LAYER1      !IN number of roof layers                           
INTEGER                           :: NROAD_LAYER1      !IN number of road layers                           
INTEGER                           :: NFLOOR_LAYER1     !IN number of floor layers
REAL,DIMENSION(1)                 :: ZBLD              !IN Horizontal building area density 
REAL,DIMENSION(1)                 :: ZGARDEN           !IN fraction of GARDEN areas   
REAL,DIMENSION(1)                 :: ZCAN_HW_RATIO     !IN Canyon H/W
REAL,DIMENSION(1)                 :: ZBLD_HEIGHT       !IN Canyon height (m)    
REAL,DIMENSION(1)                 :: ZHC_ROAD_S        !IN Heat capacity of road surface  
REAL,DIMENSION(1)                 :: ZHC_ROOF_S        !IN Heat capacity of roof surface
REAL,DIMENSION(1)                 :: ZHC_WALL_S        !IN Heat capacity of wall surface  
REAL,DIMENSION(1)                 :: ZTC_ROAD_S        !IN Thermal conductivity of road surface
REAL,DIMENSION(1)                 :: ZTC_ROOF_S        !IN Thermal conductivity of roof surface
REAL,DIMENSION(1)                 :: ZTC_WALL_S        !IN Thermal conductivity of wall surface
REAL,DIMENSION(1)                 :: ZALB_WALL         !IN albedo of walls                             
REAL,DIMENSION(1)                 :: ZEMIS_WALL        !IN emissivity of walls                         
REAL,DIMENSION(1)                 :: ZALB_ROOF         !IN albedo of roofs                             
REAL,DIMENSION(1)                 :: ZEMIS_ROOF        !IN emissivity of roofs                         
REAL,DIMENSION(1)                 :: ZALB_ROAD         !IN albedo of roads                             
REAL,DIMENSION(1)                 :: ZEMIS_ROAD        !IN emissivity of roads 
REAL,DIMENSION(1)                 :: ZH_TRAFFIC        !IN heat fluxes due to traffic (mean value) 
INTEGER                           :: ZUTC_HOUR         !IN Time zone for traffic daily cycle calculation                  
REAL,DIMENSION(1)                 :: ZH_INDUSTRY       !IN heat fluxes due to factories                 
CHARACTER(LEN=4)                  :: HROAD_DIR         !IN road direction option :                      
                                                       ! 'UNIF' : uniform roads                       
                                                       ! 'ORIE' : specified road orientation          
CHARACTER(LEN=4)                  :: HWALL_OPT         !IN Wall option                                  
                                                       ! 'UNIF' : uniform walls                       
									                   ! 'TWO ' : 2 opposite  walls
!MV202609 z0 and zd to namelist
CHARACTER(LEN=16)                 :: HZ0_TOWN          !IN z0 of the urban surface (0.5 | 0.5m | 0.1H | H/3 | <name>)
CHARACTER(LEN=16)                 :: HZD_TOWN          !IN displacement height    (same forms as HZ0_TOWN)
REAL,DIMENSION(1)                 :: ZROAD_DIR         !IN road direction (° from North, clockwise)													   
										
! Input parameters for BEM                                                                                                                                       ! ||   ||
CHARACTER(LEN=3)                  :: CBEM              !IN Building Energy model 'DEF' or 'BEM'       
CHARACTER(LEN=6)                  :: CCOOL_COIL        !IN option for cooling device type 'DXCOIL','IDEAL '            
CHARACTER(LEN=6)                  :: CHEAT_COIL        !IN option for heating device type 'FINCAP','IDEAL '
REAL, DIMENSION(1)                :: ZGR               !IN Glazing ratio   
LOGICAL                           :: LBEM_AC           !IN Flag to use air conditioners
REAL, DIMENSION(1)                :: ZTCOOL_TARGET     !IN Cooling setpoint of HVAC system [K]        
REAL, DIMENSION(1)                :: ZTHEAT_TARGET     !IN Heating setpoint of HVAC system [K]
REAL, DIMENSION(1)                :: ZV_VENT           !IN Ventilation flow rate [AC/H]
REAL, DIMENSION(1)                :: ZINF              !IN Infiltration flow rate [AC/H]
REAL, DIMENSION(1)                :: ZCOP_RAT          !IN Rated COP of the cooling system
CHARACTER(LEN=4), DIMENSION(1)    :: HNATVENT          !IN Natural ventilation 'NONE', 'AUTO', 'MECH', 'MANU'
REAL, DIMENSION(1)                :: ZRESIDENTIAL      !IN Fraction of residential use in buildings(-)
REAL                              :: ZDT_RES           !IN target temperature change when unoccupied (K) (residential buildings)                
REAL                              :: ZDT_OFF           !IN target temperature change when unoccupied (K) (office buildings)                     
REAL, DIMENSION(1)                :: ZCAP_SYS_HEAT     !IN Capacity of the heating system [W m-2(bld)]

! Wind calculation
INTEGER,DIMENSION(1)              :: ITYPE_WIND        !IN TEB option for camyon wond calculation:
													   ! 0 - default; 1 - Wang scheme
REAL,DIMENSION(1,1:8)             :: ZFAI              !IN Frontal area index 

! Input parameters for Greenroof from TERRA
REAL,DIMENSION(1)                 :: ZFRAC_GR          !IN fraction of greenroofs on roofs             
LOGICAL                           :: LGREENROOF        !IN Flag to use a green roofs scheme  
LOGICAL                           :: LGREENROOF_EXT    !IN Flag to use a green roofs scheme (external)
REAL,DIMENSION(1)                 :: ZALB_GR_EXT       !IN green roof albedo
REAL,DIMENSION(1)                 :: ZEMIS_GR_EXT      !IN green roof emissivity 
REAL,DIMENSION(1)                 :: ZTSRAD_GR_EXT     !IN greenroof radiative surface temp. (snow free) 
REAL,DIMENSION(1)                 :: ZH_GR_EXT         !IN sensible heat flux over greenroofs 
REAL,DIMENSION(1)                 :: ZLE_GR_EXT        !IN latent heat flux over greenroofs 
REAL,DIMENSION(1)                 :: ZEVAP_GR_EXT      !IN total evaporation over greenroofs (kg/m2/s)
REAL,DIMENSION(1)                 :: ZRUNOFF_GR_EXT    !IN greenroof surface runoff

! Input parameters for Garden from TERRA           
LOGICAL                           :: LGARDEN           !IN Flag to use a garden scheme
LOGICAL                           :: LGARDEN_EXT       !IN Flag to use a garden scheme (external)    
REAL,DIMENSION(1)                 :: ZZ0_GD_EXT        !IN garden roughness length (external model)
REAL,DIMENSION(1)                 :: ZALB_GD_EXT       !IN garden albedo (external model)
REAL,DIMENSION(1)                 :: ZEMIS_GD_EXT      !IN garden emissivity (external model)
REAL,DIMENSION(1)                 :: ZTSRAD_GD_EXT     !IN garden radiative surface temp. (snow free) (external model)
REAL,DIMENSION(1)                 :: ZQV_GD_EXT        !IN garden specific humidity (external model)
REAL,DIMENSION(1)                 :: ZH_GD_EXT         !IN sensible heat flux over garden (external model)
REAL,DIMENSION(1)                 :: ZLE_GD_EXT        !IN latent heat flux over garden (external model)
REAL,DIMENSION(1)                 :: ZEVAP_GD_EXT      !IN total evaporation over garden (kg/m2/s) (external model)
REAL,DIMENSION(1)                 :: ZCH_GD            !OUT garden transfer coefficient for heat (external model)
REAL,DIMENSION(1)                 :: ZCD_GD            !OUT garden  surf. exchange coefficient (external model)
REAL,DIMENSION(1)                 :: ZRUNOFF_GD_EXT    !IN garden surface runoff (external model)

! Input parameters for Solar Panels
LOGICAL                           :: LSOLAR_PANEL      !IN Flag to use a solar panels on roofs
REAL,DIMENSION(1)                 :: ZFRAC_PANEL       !IN fraction of solar panels on roofs

! Input parameters for Irrigation
LOGICAL                           :: LPAR_RD_IRRIG     !IN Flag for road watering
REAL, DIMENSION(1)                :: ZRD_START_MONTH   !IN start month for watering of roads(included)
REAL, DIMENSION(1)                :: ZRD_END_MONTH     !IN end   month for watering of roads(included)
REAL, DIMENSION(1)                :: ZRD_START_HOUR    !IN start hour  for watering of roads(included)
REAL, DIMENSION(1)                :: ZRD_END_HOUR      !IN end   hour  for watering of roads(excluded)
REAL, DIMENSION(1)                :: ZRD_24H_IRRIG     !IN 24h quantity of water used for road watering (liter/m2)               

! Input/Output prognostic variables
REAL,DIMENSION(1)                 :: ZTI_BLD           !INOUT indoor air temperature
REAL,DIMENSION(1,1:NROOF_LAYER1)  :: ZT_ROOF  	       !INOUT roof layers temperatures
REAL,DIMENSION(1,1:NROAD_LAYER1)  :: ZT_ROAD_NOW       !INOUT road layers temperatures at previous time-step 
REAL,DIMENSION(1,1:NROAD_LAYER1)  :: ZT_ROAD  	       !INOUT road layers temperatures          
REAL,DIMENSION(1,1:NWALL_LAYER1)  :: ZT_WALL_A	       !INOUT wall layers temperatures (wall 'A') 
REAL,DIMENSION(1,1:NWALL_LAYER1)  :: ZT_WALL_B	       !INOUT wall layers temperatures (wall 'B') 
REAL,DIMENSION(1,1:NFLOOR_LAYER1) :: ZT_FLOOR 	       !INOUT Floor layers temperatures [K]
REAL,DIMENSION(1,1:NFLOOR_LAYER1) :: ZT_MASS  	       !INOUT Internal mass layers temperatures [K]      
REAL,DIMENSION(1)                 :: ZQI_BLD   		   !INOUT Indoor air specific humidity [kg kg-1]
! Input/Output semi-prognostic variables 
REAL,DIMENSION(1)                 :: ZT_CANYON   	   !INOUT air canyon temperature 
REAL,DIMENSION(1)                 :: ZQ_CANYON     	   !INOUT canyon air humidity ratio
! Input/Output prognostic variables
REAL,DIMENSION(1)                 :: ZWS_ROOF          !INOUT roof water content (kg/m2)                   
REAL,DIMENSION(1)                 :: ZWS_ROAD          !INOUT road water content (kg/m2)
REAL,DIMENSION(1,1)               :: ZWSNOW_ROOF       !INOUT Initial Amount      of roof snow reservoir  
REAL,DIMENSION(1,1)               :: ZWSNOW_ROAD       !INOUT Initial amount      of road snow reservoir
REAL,DIMENSION(1,1)               :: ZTSNOW_ROOF       !INOUT layer temperature   of roof snow 
REAL,DIMENSION(1,1)               :: ZTSNOW_ROAD       !INOUT layer temperature   of road snow          
REAL,DIMENSION(1,1)               :: ZRSNOW_ROOF       !INOUT density             of roof snow  
REAL,DIMENSION(1,1)               :: ZRSNOW_ROAD       !INOUT density             of road snow          
REAL,DIMENSION(1)                 :: ZTSSNOW_ROOF      !INOUT surface temperature of roof snow           
REAL,DIMENSION(1)                 :: ZTSSNOW_ROAD      !INOUT surface temperature of road snow
REAL,DIMENSION(1)                 :: ZASNOW_ROOF       !INOUT roof snow albedo                            
REAL,DIMENSION(1)                 :: ZASNOW_ROAD       !INOUT road snow albedo
REAL,DIMENSION(1)                 :: ZESNOW_ROOF       !INOUT snow roof emissivity
REAL,DIMENSION(1)                 :: ZESNOW_ROAD       !INOUT road snow emissivity                          
REAL,DIMENSION(1)                 :: ZT_WIN1           !INOUT outdoor window temperature [K] 
REAL,DIMENSION(1)                 :: ZT_WIN2           !INOUT Indoor window temperature [K] 
REAL,DIMENSION(1)                 :: ZALB_WIN          !INOUT window albedo
REAL,DIMENSION(1)                 :: ZCAP_SYS_RAT      !INOUT Rated capacity of the cooling system [W m-2(floor)]                                                   
REAL,DIMENSION(1)                 :: ZM_SYS_RAT        !INOUT Rated HVAC mass flow rate [kg s-1 m-2(bld)] 
LOGICAL,DIMENSION(1)              :: GSHAD_DAY         !INOUT has shading been necessary this day ?     
LOGICAL,DIMENSION(1)              :: GNATVENT_NIGHT    !INOUT has natural ventilation been

! Output diagnostic variables
REAL,DIMENSION(1)                 :: ZTS_ROOF          !OUT roof surface temperature   [K]                                       
REAL,DIMENSION(1)                 :: ZTS_WALL_A        !OUT wall 'A' surface temperature [K]               
REAL,DIMENSION(1)                 :: ZTS_WALL_B        !OUT wall 'B' surface temperature [K]                   
REAL,DIMENSION(1)                 :: ZH_TOWN           !OUT sensible heat flux over town             
REAL,DIMENSION(1)                 :: ZLE_TOWN          !OUT latent heat flux over town     
REAL,DIMENSION(1)                 :: ZTS_TOWN_S_NOW    !OUT town surface temperature from flux calculation at previous time-step          
REAL,DIMENSION(1)                 :: ZTS_TOWN_S        !OUT town surface temperature from flux calculation  
REAL,DIMENSION(1)                 :: ZQS_TOWN_S        !OUT town surface specific humidity from flux calculation (kg/kg)                
REAL,DIMENSION(1)                 :: ZWS_TOWN_NOW      !OUT town water content (m H2O) at previous time-step     
REAL,DIMENSION(1)                 :: ZWS_TOWN          !OUT town water content (m H2O)
REAL,DIMENSION(1)                 :: ZRUNOFF_TOWN      !OUT runoff for town
REAL,DIMENSION(1)                 :: ZTSSNOW_TOWN_NOW  !OUT town snow surface temperature (K) at previous time-step
REAL,DIMENSION(1)                 :: ZTSSNOW_TOWN      !OUT town snow surface temperature (K)
REAL,DIMENSION(1)                 :: ZWSNOW_TOWN_NOW   !OUT town snow (& liq. water) content (m H2O) at previous time-step
REAL,DIMENSION(1)                 :: ZWSNOW_TOWN       !OUT town snow (& liq. water) content (m H2O)
REAL,DIMENSION(1)                 :: ZRSNOW_TOWN_NOW   !OUT town snow layers density (kg/m3) at previous time-step   
REAL,DIMENSION(1)                 :: ZRSNOW_TOWN       !OUT town snow layers density (kg/m3)
REAL,DIMENSION(1)                 :: ZCH_TOWN          !OUT Heat exchange coefficient  
REAL,DIMENSION(1)                 :: ZEVAP_TOWN        !OUT evaporation (kg/m2/s)                     
REAL,DIMENSION(1)                 :: ZHSNOW_TOWN       !OUT sensible heat flux over snow
REAL,DIMENSION(1)                 :: ZLESNOW_TOWN      !OUT latent heat flux over snow
REAL,DIMENSION(1)                 :: ZDN_TOWN          !OUT snow fraction over town
REAL,DIMENSION(1)                 :: ZMELT_BLT_SUM     !OUT Snow melt for built & impervious part (kg/m2)
REAL,DIMENSION(1)                 :: ZSNOWD_TOWN_NOW   !OUT town snow depth at previous time-step
REAL,DIMENSION(1)                 :: ZSNOWD_TOWN       !OUT town snow depth
REAL,DIMENSION(1)                 :: ZSO_ALB_TOWN      !OUT town solar albedo  
REAL,DIMENSION(1)                 :: ZTH_ALB_TOWN      !OUT town thermal albedo
REAL,DIMENSION(1)                 :: XU_CANYON         !OUT u-wind component of wind inside the canyon                            
REAL,DIMENSION(1)                 :: XV_CANYON         !OUT v-wind component of wind inside the canyon
REAL,DIMENSION(1)                 :: ZABS_SW_GRND      !OUT Shortwave radiation absorbed by ground
REAL,DIMENSION(1)                 :: ZABS_LW_GRND      !OUT Longwave radiation absorbed by ground
REAL,DIMENSION(1)                 :: ZH_WASTE          !OUT Sensible waste heat from HVAC system [W m-2(tot)]
REAL,DIMENSION(1)                 :: ZHVAC_COOL        !OUT Energy consumption of the cooling system [W m-2(bld)]                               
REAL,DIMENSION(1)                 :: ZHVAC_HEAT        !OUT Energy consumption of the heating system [W m-2(bld)]
REAL,DIMENSION(1)                 :: ZCH_RD            !OUT road transfer coefficient for heat
REAL,DIMENSION(1)                 :: ZCH_RF            !OUT roof transfer coefficient for heat
REAL,DIMENSION(1)                 :: ZCH_WL            !OUT wall transfer coefficient for heat
REAL,DIMENSION(1)                 :: ZCH_TOP           !OUT between canyon top and atm. transfer coefficient for heat
REAL,DIMENSION(1)                 :: ZILMO_ROAD        !OUT 1/length of Monin-Obukov
REAL,DIMENSION(1)                 :: ZILMO_ROOF        !OUT 1/length of Monin-Obukov
REAL,DIMENSION(1)                 :: ZILMO_TOP         !OUT 1/length of Monin-Obukov
REAL,DIMENSION(1)                 :: ZLMO_TOP          !OUT 1/length of Monin-Obukov 
REAL,DIMENSION(1)                 :: ZZ0U              !OUT Roughness length (m)
REAL,DIMENSION(1)                 :: ZCD_TERRA         !OUT 
REAL,DIMENSION(1)                 :: ZCH_TERRA         !OUT 
REAL,DIMENSION(1)                 :: ZH_TRAFFIC_NOW    !OUT heat fluxes due to traffic at current time-step      
REAL,DIMENSION(1)                 :: ZPROD_BLD         !OUT Averaged Energy production of solar panel on roofs (W/m2 bld  )   
 
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

! Canyon geometry                                                                     
REAL,DIMENSION(1)  :: ZZ0               ! Roughness length (m) for neutral stratification                                                           
REAL,DIMENSION(1)  :: ZZDU              ! Displacement height (m)                                                          
REAL,DIMENSION(1)  :: ZWALL_O_HOR       ! Vertical to horizonal surf ratio                 
REAL,DIMENSION(1)  :: ZROAD             ! fraction of roads                            
REAL,DIMENSION(1)  :: ZROOF_FRAC        ! roof, wall,                                  
REAL,DIMENSION(1)  :: ZWALL_FRAC        ! road, and green area                         
REAL,DIMENSION(1)  :: ZROAD_FRAC        ! fractions                                    
REAL,DIMENSION(1)  :: ZGARDEN_FRAC      ! fractions 
REAL,DIMENSION(1)  :: ZWALL_O_GRND      ! Wall to ground surface ratio                 
REAL,DIMENSION(1)  :: ZROAD_O_GRND      ! Road to ground surface ratio                 
REAL,DIMENSION(1)  :: ZGARDEN_O_GRND    ! Garden to ground surface ratio

! Urban options                                                                                                                   
CHARACTER(LEN=6)   :: HZ0H              ! TEB option for z0h roof & road                  
CHARACTER(LEN=3)   :: HIMPLICIT_WIND='NEW' ! Implicitation option for wind fluxes
CHARACTER(LEN=3)   :: HSNOW_ROOF = "1-L"! Option for roof snow                        
CHARACTER(LEN=3)   :: HSNOW_ROAD = "1-L"! Option for road snow 

! Canyon thermal properties
INTEGER            :: NWALL_LAYER       ! number of wall layers                           
INTEGER            :: NROOF_LAYER       ! number of roof layers                          
INTEGER            :: NROAD_LAYER       ! number of road layers                           
INTEGER            :: NFLOOR_LAYER      ! number of floor layers
REAL,DIMENSION(:,:), ALLOCATABLE :: ZHC_WALL ! Heat capacity        of wall layers    
REAL,DIMENSION(:,:), ALLOCATABLE :: ZTC_WALL ! Thermal conductivity of wall layers    
REAL,DIMENSION(:,:), ALLOCATABLE :: ZD_WALL  ! Thickness            of wall layers    
REAL,DIMENSION(:,:), ALLOCATABLE :: ZHC_ROOF ! Heat capacity        of roof layers    
REAL,DIMENSION(:,:), ALLOCATABLE :: ZTC_ROOF ! Thermal conductivity of roof layers    
REAL,DIMENSION(:,:), ALLOCATABLE :: ZD_ROOF  ! Thickness            of roof layers    
REAL,DIMENSION(:,:), ALLOCATABLE :: ZHC_ROAD ! Heat capacity        of road layers            
REAL,DIMENSION(:,:), ALLOCATABLE :: ZTC_ROAD ! Thermal conductivity of road layers    
REAL,DIMENSION(:,:), ALLOCATABLE :: ZD_ROAD  ! Thickness            of road layers    
REAL,DIMENSION(1)  :: ZD_WALL_LAYERS         ! Thickness            of 1-4 wall layers                                                        
REAL,DIMENSION(1)  :: ZD_ROOF_LAYERS         ! Thickness            of 1-4 roof layers                                                        

! Wind calculation
REAL,DIMENSION(1)  :: ZU_TOP           ! Wind speed at canyon top (m/s)
REAL,DIMENSION(1)  :: ZDIR             ! Wind direction (degrees)
REAL               :: XPII
REAL,DIMENSION(1:9):: ZU_CANYON_WANG   ! hor. wind in canyon due to Wang

REAL,DIMENSION(1)  :: ZVMOD_TS         ! Wind speed at forcing level limited with wind_threshold (m/s)
! Urban variables    
REAL,DIMENSION(1)  :: ZQA_KGKG          ! air humidity at forcing level (kg/kg)                                                                 
REAL,DIMENSION(1)  :: ZU_CANYON         ! hor. wind in canyon                                          
REAL,DIMENSION(1)  :: ZTS_ROAD          ! road surface temperature   [K]                                                                    
REAL,DIMENSION(1)  :: ZZ_LOWCAN         ! altitude of air layer above road             
REAL,DIMENSION(1)  :: ZT_LOWCAN         ! temperature of air above road                
REAL,DIMENSION(1)  :: ZU_LOWCAN         ! wind above road                              
REAL,DIMENSION(1)  :: ZQ_LOWCAN         ! humidity above road                          
REAL,DIMENSION(1)  :: ZEXNS             ! surface exner function                       
REAL,DIMENSION(1)  :: ZEXNA             ! exner function                               
REAL,DIMENSION(1)  :: ZPEW_A_COEF       ! implicit coefficients                        
REAL,DIMENSION(1)  :: ZPEW_B_COEF       ! for wind coupling                            
REAL,DIMENSION(1)  :: ZPEW_A_COEF_LOWCAN!                                             
REAL,DIMENSION(1)  :: ZPEW_B_COEF_LOWCAN!                                             
REAL,DIMENSION(1)  :: ZVMOD             ! Module of wind speed at the top of the canyon
REAL,DIMENSION(1)  :: ZCD               ! drag coefficient                             
REAL,DIMENSION(1)  :: ZCDN              ! neutral drag coefficient    
REAL,DIMENSION(1)  :: ZAC_ROOF          ! roof aerodynamical conductance        
REAL,DIMENSION(1)  :: ZAC_ROAD          ! road aerodynamical conductance                         
REAL,DIMENSION(1)  :: ZAC_WALL          ! wall aerodynamical conductance   
REAL,DIMENSION(1)  :: ZAC_TOP           ! aerodynamical conductance between canyon top and atm.     
REAL,DIMENSION(1)  :: ZAC_ROAD_WAT      ! road aerodynamical conductance (for water)   
REAL,DIMENSION(1)  :: ZAC_GARDEN        ! garden aerodynamical conductance             
REAL,DIMENSION(1)  :: ZAC_GARDEN_WAT    ! garden aerodynamical conductance for vapor   
REAL,DIMENSION(1)  :: ZAC_GREENROOF     ! green roofs aerodynamical conductance        
REAL,DIMENSION(1)  :: ZAC_GREENROOF_WAT ! green roofs aerodynamical conductance for vapor                                    
REAL,DIMENSION(1)  :: ZUW_ROOF          ! Momentum flux for roofs                      
REAL,DIMENSION(1)  :: ZDUWDU_GRND       ! d(u'w')/du for ground                        
REAL,DIMENSION(1)  :: ZDUWDU_ROOF       ! d(u'w')/du for roof                          
REAL,DIMENSION(1)  :: ZUSTAR_TOWN       ! Fraction velocity for town                   
REAL,DIMENSION(1)  :: ZRESA_TOWN        ! Aerodynamical resistance                     
REAL,DIMENSION(1)  :: ZRI_TOWN          ! Richardson number                            
REAL,DIMENSION(1)  :: ZRUNOFF_ROOF      ! runoff for roof                              
REAL,DIMENSION(1)  :: ZRUNOFF_ROAD      ! runoff for road                                                                                    
REAL,DIMENSION(1)  :: ZGSNOW_ROAD = 0.0 ! road snow conduction                         

! Urban fluxes variables                                                              
REAL,DIMENSION(1)  :: ZTOTS_O_HORS      ! total canyon+roof surf over horizontal surf  
REAL,DIMENSION(1)  :: ZUW_GRND          ! friction flux over ground                    
REAL,DIMENSION(1)  :: ZRN_ROOF          ! net radiation over roof                      
REAL,DIMENSION(1)  :: ZH_ROOF           ! sensible heat flux over roof    
REAL,DIMENSION(1)  :: ZH_ROOF_FR        ! sensible heat flux over roof (fraction)    
REAL,DIMENSION(1)  :: DELTA_TROOF       ! temperature difference between roof and air in sensible heat flux 
REAL,DIMENSION(1)  :: DELTA_TROAD       ! temperature difference between road and air in sensible heat flux
REAL,DIMENSION(1)  :: DELTA_TWALL       ! temperature difference between wall and air in sensible heat flux               
REAL,DIMENSION(1)  :: ZLE_ROOF          ! latent heat flux over roof                   
REAL,DIMENSION(1)  :: ZGFLUX_ROOF       ! flux through the roof                        
REAL,DIMENSION(1)  :: ZRN_ROAD          ! net radiation over road                      
REAL,DIMENSION(1)  :: ZH_ROAD           ! sensible heat flux over road 
REAL,DIMENSION(1)  :: ZH_ROAD_FR        ! sensible heat flux over road (fraction)                
REAL,DIMENSION(1)  :: ZLE_ROAD          ! latent heat flux over road                   
REAL,DIMENSION(1)  :: ZGFLUX_ROAD       ! flux through the road                        
REAL,DIMENSION(1)  :: ZRN_WALL_A        ! net radiation over wall                      
REAL,DIMENSION(1)  :: ZRN_WALL_B        ! net radiation over wall                      
REAL,DIMENSION(1)  :: ZH_WALL_A = 0.0   ! sensible heat flux over wall 
REAL,DIMENSION(1)  :: ZH_WALL_FR        ! sensible heat flux over wall (fraction)                
REAL,DIMENSION(1)  :: ZH_WALL_B = 0.0   ! sensible heat flux over wall                 
REAL,DIMENSION(1)  :: ZLE_WALL_A        ! latent heat flux over wall                   
REAL,DIMENSION(1)  :: ZLE_WALL_B        ! latent heat flux over wall                   
REAL,DIMENSION(1)  :: ZGFLUX_WALL_A     ! flux through the wall                        
REAL,DIMENSION(1)  :: ZGFLUX_WALL_B     ! flux through the wall                        
REAL,DIMENSION(1)  :: ZG_GREENROOF_ROOF ! heat flux between base of greenroof and structural roof         
REAL,DIMENSION(1)  :: ZRNSNOW_ROOF = 0.0! net radiation over snow                    
REAL,DIMENSION(1)  :: ZRNSNOW_ROAD = 0.0! net radiation over snow                    
REAL,DIMENSION(1)  :: ZHSNOW_ROAD  = 0.0! sensible heat flux over snow               
REAL,DIMENSION(1)  :: ZLESNOW_ROAD = 0.0! latent heat flux over snow                 
REAL,DIMENSION(1)  :: ZRN_BLT           ! net radiation over built covers            
REAL,DIMENSION(1)  :: ZH_BLT            ! sensible heat flux over built covers       
REAL,DIMENSION(1)  :: ZLE_BLT           ! latent heat flux over built covers         
REAL,DIMENSION(1)  :: ZGFLUX_BLT        ! flux through the built covers              
REAL,DIMENSION(1)  :: ZFLX_BLD          ! heat flx from bld to its structure         
REAL,DIMENSION(1)  :: ZDQS_TOWN         ! storage inside town materials              
REAL,DIMENSION(1)  :: ZQF_TOWN          ! total anthropogenic heat                   
REAL,DIMENSION(1)  :: ZMELT_ROOF = 0.0  ! snow melting on roof                       
REAL,DIMENSION(1)  :: ZMELT_ROAD  = 0.0 ! snow melting on road                       
REAL,DIMENSION(1)  :: ZQF_BLD                                                         
REAL,DIMENSION(1)  :: ZSFCO2            ! Surface Flux of CO2                        
REAL,DIMENSION(1)  :: ZDN_RF            ! snow fraction on roofs
REAL,DIMENSION(1)  :: ZDN_RD            ! snow fraction on roads
REAL,DIMENSION(1)  :: ZMELT_BLT         ! Snow melt for built & impervious part (kg/m2/s) 
REAL,DIMENSION(1)  :: ZSNOWD_RF         ! snow depth on roofs
REAL,DIMENSION(1)  :: ZSNOWD_RD         ! snow depth on roads              
REAL,DIMENSION(1)  :: ZABS_LW_SNOW_ROOF ! abs. LW rad. by snow                        
REAL,DIMENSION(1)  :: ZABS_LW_SNOW_ROAD ! abs. LW rad. by snow                        
REAL,DIMENSION(1)  :: ZRN_STRLROOF      ! net radiation over structural roof          
REAL,DIMENSION(1)  :: ZH_STRLROOF       ! sensible heat flux over structural roof     
REAL,DIMENSION(1)  :: ZLE_STRLROOF      ! latent heat flux over structural roof       
REAL,DIMENSION(1)  :: ZGFLUX_STRLROOF   ! flux through the structural roof            
REAL,DIMENSION(1)  :: ZRUNOFF_STRLROOF  ! water runoff on the structural roof         
REAL,DIMENSION(1)  :: ZLEW_ROOF         ! latent heat flux of snowfree roof           
REAL,DIMENSION(1)  :: ZLESNOW_ROOF      ! latent heat flux over snow                  
REAL,DIMENSION(1)  :: ZLEW_ROAD         ! latent heat flux of snowfree road           
REAL,DIMENSION(1)  :: ZRN_GRND          ! net radiation over ground                   
REAL,DIMENSION(1)  :: ZH_GRND           ! sensible heat flux over ground              
REAL,DIMENSION(1)  :: ZLE_GRND          ! latent heat flux over ground                
REAL,DIMENSION(1)  :: ZGFLUX_GRND       ! flux through the ground                     
REAL,DIMENSION(1)  :: ZRN_TOWN          ! net radiation over town                     
REAL,DIMENSION(1)  :: ZGFLUX_TOWN       ! flux through the ground for town            
REAL,DIMENSION(1)  :: ZH_TRAFFIC_NOW_CAN! heat fluxes due to traffic at current time-step to the canyon

! Radiative variables                                                                
                       
REAL,DIMENSION(1)  :: ZABS_SW_ROOF      ! Shortwave radiation absorbed by roofs       
REAL,DIMENSION(1)  :: ZABS_SW_ROAD      ! Shortwave radiation absorbed by roads       
REAL,DIMENSION(1)  :: ZABS_SW_WALL_A    ! Shortwave radiation absorbed by wall A      
REAL,DIMENSION(1)  :: ZABS_SW_WALL_B    ! Shortwave radiation absorbed by wall B      
REAL,DIMENSION(1)  :: ZABS_SW_GARDEN    ! Shortwave radiation absorbed by gardens     
REAL,DIMENSION(1)  :: ZABS_SW_GREENROOF ! Shortwave radiation absorbed by greenroofs  
REAL,DIMENSION(1)  :: ZABS_LW_ROOF      ! Longwave  radiation absorbed by roofs       
REAL,DIMENSION(1)  :: ZABS_LW_ROAD      ! Longwave  radiation absorbed by roads       
REAL,DIMENSION(1)  :: ZABS_LW_WALL_A    ! Longwave  radiation absorbed by wall A      
REAL,DIMENSION(1)  :: ZABS_LW_WALL_B    ! Longwave  radiation absorbed by wall B      
REAL,DIMENSION(1)  :: ZABS_LW_GARDEN    ! Longwave  radiation absorbed by gardens     
REAL,DIMENSION(1)  :: ZABS_LW_GREENROOF ! Longwave  radiation absorbed by greenroofs  
REAL,DIMENSION(1)  :: ZABS_SW_SNOW_ROOF ! Shortwave radiation absorbed by roof snow   
REAL,DIMENSION(1)  :: ZABS_SW_SNOW_ROAD ! Shortwave radiation absorbed by road snow   
REAL,DIMENSION(1)  :: ZABS_SW_PANEL     ! Shortwave radiation absorbed by solar panels   
REAL,DIMENSION(1)  :: ZABS_LW_PANEL     ! Longwave  radiation absorbed by solar panels   
REAL,DIMENSION(1)  :: ZDIR_ALB_TOWN     ! town direct albedo                             
REAL,DIMENSION(1)  :: ZSCA_ALB_TOWN     ! town scaterred albedo     
REAL,DIMENSION(1)  :: ZALB_TH_RED       ! thermal albedo reduction factor for the urban fabric 
                
REAL,DIMENSION(1)  :: ZALB_AVE_TWN      ! town area-averaged albedo                
REAL,DIMENSION(1)  :: ZSW_UP_SO         ! outgoing solar radiation 
REAL,DIMENSION(1)  :: ZLW_UP            ! outgoing longwave radiation                      
REAL,DIMENSION(1,1):: ZTDIR_SW          ! total direct SW                         
REAL,DIMENSION(1,1):: ZTSCA_SW          ! total diffuse SW                        
REAL,DIMENSION(1)  :: ZTS_TOWN          ! town surface temperature                    
REAL,DIMENSION(1)  :: ZEMIS_TOWN        ! town equivalent emissivity
REAL,DIMENSION(1)  :: ZCOEF             ! work array                              
REAL,DIMENSION(1)  :: ZF1_o_B           ! Coefficient for sky model

REAL,DIMENSION(1)  :: ZSVF_ROAD         ! road sky view factor                           
REAL,DIMENSION(1)  :: ZSVF_GARDEN       ! garden sky view factor                         
REAL,DIMENSION(1)  :: ZSVF_WALL         ! wall sky view factor                           
REAL,DIMENSION(1)  :: ZWAKE             ! reduction of average wind speed                
REAL,DIMENSION(1)  :: ZGSNOW_ROOF  = 0.0! roof snow conduction                       
REAL,DIMENSION(1)  :: ZHSNOW_ROOF       

! Anthropogenic heat fluxes                                                                           
REAL,DIMENSION(1)  :: ZLE_TRAFFIC       ! heat fluxes due to traffic                                   
REAL,DIMENSION(1)  :: ZLE_INDUSTRY      ! heat fluxes due to factories

! New arguments created after BEM                                                                                                                                       ! ||   ||            
REAL, DIMENSION(1)  :: ZF_WATER_COND     ! fraction of evaporation for the condensers                                             
REAL, DIMENSION(1)  :: ZNATVENT          ! flag to describe surventilation system for 
                                         ! i/o 0 for NONE, 1 for MANU and 2 for AUTO  
REAL, DIMENSION(1) :: ZAUX_MAX = 5.      ! Auxiliar variable for autosize calcs (not used)
REAL, DIMENSION(1) :: PFLOOR_HEIGHT      ! Floor height (m)                           
REAL, DIMENSION(1) :: ZH_BLD_COOL        ! Sensible cooling energy demand of the building [W m-2(bld)]               
REAL, DIMENSION(1) :: ZT_BLD_COOL        ! Total cooling energy demand of the building [W m-2(bld)]               
REAL, DIMENSION(1) :: ZH_BLD_HEAT        ! Heating energy demand of the building [W m-2(bld)]               
REAL, DIMENSION(1) :: ZLE_BLD_COOL       ! Latent cooling energy demand of the building [W m-2(bld)]               
REAL, DIMENSION(1) :: ZLE_BLD_HEAT       ! Latent heating energy demand of the building [W m-2(bld)]                                             
REAL, DIMENSION(1) :: ZLE_WASTE          ! Latent waste heat from HVAC system [W m-2(tot)]                               
REAL, DIMENSION(1) :: ZF_WASTE_CAN       ! fraction of waste heat released into the canyon                                                           
REAL, DIMENSION(1) :: ZQIN               ! Internal heat gains [W m-2(floor)]         
REAL, DIMENSION(1) :: ZQIN_FRAD          ! Radiant fraction of internal heat gains    
REAL, DIMENSION(1) :: ZQIN_FLAT          ! Latent franction of internal heat gains                               
REAL, DIMENSION(1) :: ZEFF_HEAT          ! Efficiency of the heating system                             
REAL, DIMENSION(1) :: ZCUR_QIN           ! Internal heat gains [W m-2(floor)]         
REAL, DIMENSION(1) :: ZCUR_TCOOL_TARGET  ! Cooling setpoint of HVAC system [K]        
REAL, DIMENSION(1) :: ZCUR_THEAT_TARGET  ! Heating setpoint of HVAC system [K]        
REAL, DIMENSION(1) :: ZHR_TARGET         ! Relative humidity setpoint                                
REAL, DIMENSION(1) :: ZCAP_SYS           ! Actual capacity of the cooling system [W m-2(bld)]                                                            
REAL, DIMENSION(1) :: ZT_ADP             ! Apparatus dewpoint temperature of the cooling coil [K]                                                                                            
REAL, DIMENSION(1) :: ZM_SYS             ! Actual HVAC mass flow rate [kg s-1 m-2(bld)]                          
REAL, DIMENSION(1) :: ZCOP               ! COP of the cooling system                  
REAL, DIMENSION(1) :: ZQ_SYS             ! Supply air specific humidity [kg kg-1]     
REAL, DIMENSION(1) :: ZT_SYS             ! Supply air temperature [K]                 
REAL, DIMENSION(1) :: ZTR_SW_WIN         ! Solar radiation transmitted throught windows [W m-2(bld)]                       
REAL, DIMENSION(1) :: ZFAN_POWER         ! HVAC fan power                             
REAL, DIMENSION(:,:), ALLOCATABLE :: ZHC_FLOOR ! heat capacity for floor layers       
REAL, DIMENSION(:,:), ALLOCATABLE :: ZTC_FLOOR ! thermal conductivity for floor layers                         
REAL, DIMENSION(:,:), ALLOCATABLE :: ZD_FLOOR  ! depth of floor layers                
 
REAL, DIMENSION(1) :: ZABS_SW_WIN        ! window absorbed shortwave radiation [W m-2]
REAL, DIMENSION(1) :: ZABS_LW_WIN        ! absorbed infrared rad. [W m-2]             
REAL, DIMENSION(1) :: ZSHGC              ! window solar transmittance                 
REAL, DIMENSION(1) :: ZSHGC_SH           ! window + shading solar heat gain coef.      
REAL, DIMENSION(1) :: ZUGG_WIN           ! window glass-to-glass U-factro [W m-2 K-1] 
REAL, DIMENSION(1) :: PU_WIN             ! window U-factor [K m W-2]                  
REAL, DIMENSION(1) :: ZABS_WIN           ! window absortance                          
REAL, DIMENSION(1) :: ZTRAN_WIN          ! window transmittance                       

! New argument for the UTCI calculation                                               
REAL, DIMENSION(1)  :: ZEMIT_LW_GRND     ! LW flux emitted by the ground (W/m² ground)
REAL, DIMENSION(1)  :: ZEMIT_LW_FAC      ! LW flux emitted by the facade (W/m² ground)
REAL, DIMENSION(1)  :: ZT_RAD_IND        ! Indoor mean radiant temperature [K]        
REAL, DIMENSION(1)  :: ZREF_SW_GRND      ! total solar rad reflected from ground      
REAL, DIMENSION(1)  :: ZREF_SW_FAC       ! total solar rad reflected from facade      
REAL, DIMENSION(1)  :: ZHU_BLD           ! Indoor relative humidity 0 < (-) < 1       
                                                                                    
! Solar panels                                                                        
REAL, DIMENSION(1)  :: ZEMIS_PANEL       ! Emissivity of solar panel [-]              
REAL, DIMENSION(1)  :: ZALB_PANEL        ! albedo of solar panel  [-]                 
REAL, DIMENSION(1)  :: ZEFF_PANEL        ! Efficiency of solar panel [-]              
REAL, DIMENSION(1)  :: ZTHER_PROD_PANEL  ! Thermal Energy production of solar panel on roofs (W/m2 panel)   
REAL, DIMENSION(1)  :: ZPHOT_PROD_PANEL  ! Photovoltaic Energy production of solar panel on roofs (W/m2 panel)   
REAL, DIMENSION(1)  :: ZPROD_PANEL       ! Averaged Energy production of solar panel on roofs (W/m2 panel)   
REAL, DIMENSION(1)  :: ZTHER_PROD_BLD    ! Thermal Energy production of solar panel on roofs (W/m2 bld  )   
REAL, DIMENSION(1)  :: ZPHOT_PROD_BLD    ! Photovoltaic Energy production of solar panel on roofs (W/m2 bld  )   
REAL, DIMENSION(1)  :: ZTHER_PRODC_DAY=0.! Present day integrated thermal production of energy (J/m2 panel). zero value at start
REAL, DIMENSION(1)  :: ZH_PANEL          ! Sensible heat flux from solar panels (W/m2 panel)                           
REAL, DIMENSION(1)  :: ZRN_PANEL         ! Net radiation of solar panel (W/m2 panel)                                                                                                              

! Road watering                                                                       
REAL, DIMENSION(1)  :: ZIRRIG_ROAD       ! road irrigation during current time-step   
                                                                                
! New arguments for shading, schedule or natural ventilation                          
LOGICAL,DIMENSION(1) :: LSHADE            ! Flag to use shading devices              
REAL,   DIMENSION(1) :: ZSHADE            ! flag to activate shading devices -> REAL for i/o 0. or 1                                                                                                      ! ||   ||
REAL, DIMENSION(1)  :: ZN_FLOOR          ! Number of floors                           
REAL, DIMENSION(1)  :: ZWALL_O_BLD       ! Wall area [m2_wall/m2_bld]                 
REAL, DIMENSION(1)  :: ZGLAZ_O_BLD       ! Window area [m2_win/m2_bld]                
REAL, DIMENSION(1)  :: ZMASS_O_BLD       ! Mass area [m2_mass/m2_bld]                 
REAL, DIMENSION(1)  :: ZFLOOR_HW_RATIO   ! H/W ratio of 1 floor level                 
REAL, DIMENSION(1)  :: ZF_FLOOR_MASS     ! View factor floor-mass                     
REAL, DIMENSION(1)  :: ZF_FLOOR_WALL     ! View factor floor-wall                     
REAL, DIMENSION(1)  :: ZF_FLOOR_WIN      ! View factor floor-window                   
REAL, DIMENSION(1)  :: ZF_FLOOR_ROOF     ! View factor floor-roof                     
REAL, DIMENSION(1)  :: ZF_WALL_FLOOR     ! View factor wall-floor                     
REAL, DIMENSION(1)  :: ZF_WALL_MASS      ! View factor wall-mass                      
REAL, DIMENSION(1)  :: ZF_WALL_WIN       ! View factor wall-win                       
REAL, DIMENSION(1)  :: ZF_WIN_FLOOR      ! View factor win-floor                      
REAL, DIMENSION(1)  :: ZF_WIN_MASS       ! View factor win-mass                       
REAL, DIMENSION(1)  :: ZF_WIN_WALL       ! View factor win-wall                       
REAL, DIMENSION(1)  :: ZF_MASS_FLOOR     ! View factor mass-floor                     
REAL, DIMENSION(1)  :: ZF_MASS_WALL      ! View factor mass-wall                      
REAL, DIMENSION(1)  :: ZF_MASS_WIN       ! View factor mass-window                    
LOGICAL             :: LCANOPY           ! is canopy active ?                         
CHARACTER(LEN=5)    :: CCH_BEM           ! TEB option for building outside conv. coef 
REAL, DIMENSION(1)  :: ZROUGH_ROOF       ! roof roughness coef.                       
REAL, DIMENSION(1)  :: ZROUGH_WALL       ! wall roughness coef.                       
REAL, DIMENSION(1)  :: ZF_WIN_WIN        ! indoor win to win view factor             

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
HZ0H = 'MASC95'
!
!
!============================================================
!============================================================
! Urban geometry
!============================================================
!============================================================
!ZZ0         = ZBLD_HEIGHT * 0.075   ! Roughness length (m)
!MV202609 z0 and zd to namelist
! z0 of the urban surface and the displacement height come from the namelist
! entries urb_z0_town and urb_zd_town: a value in metres, a fraction of the
! building height ('<value>H') or 'H/<n>'; a parameterization name is
! accepted but not implemented yet
CALL URB_AERO_PARAMS(HZ0_TOWN, HZD_TOWN, ZBLD_HEIGHT, ZBLD, ZFAI, ZZ0, ZZDU)
!MV202609 z0 and zd to namelist
! sanity checks of the resulting values
IF (ZZ0(1) <= 0. .OR. ZZ0(1) > 0.5*ZBLD_HEIGHT(1)) THEN
  WRITE(*,*) 'ERROR in CALL_DRIVER: urb_z0_town = ', TRIM(HZ0_TOWN), ' -> z0 = ', ZZ0(1), ' m'
  WRITE(*,*) '   z0 must be in (0, 0.5*urb_h_bld], urb_h_bld = ', ZBLD_HEIGHT(1), ' m'
  STOP
ENDIF
!MV202609 z0 and zd to namelist
IF (ZZDU(1) < 0. .OR. ZZDU(1) >= ZBLD_HEIGHT(1)) THEN
  WRITE(*,*) 'ERROR in CALL_DRIVER: urb_zd_town = ', TRIM(HZD_TOWN), ' -> zd = ', ZZDU(1), ' m'
  WRITE(*,*) '   zd must be in [0, urb_h_bld), urb_h_bld = ', ZBLD_HEIGHT(1), ' m'
  STOP
ENDIF

!
!============================================================
!============================================================
! Roof
!============================================================
!============================================================
NROOF_LAYER = 5          ! number of roof layers
ALLOCATE(ZHC_ROOF    (1,NROOF_LAYER)) 
ALLOCATE(ZTC_ROOF    (1,NROOF_LAYER)) 
ALLOCATE(ZD_ROOF     (1,NROOF_LAYER)) 
ZHC_ROOF(1,1) = ZHC_ROOF_S(1)   ! volumetric heat capacity (J m-3 K-1) (external layer)
ZHC_ROOF(1,2) = ZHC_ROOF_S(1)   ! volumetric heat capacity (J m-3 K-1)
ZHC_ROOF(1,3) = ZHC_ROOF_S(1)   ! volumetric heat capacity (J m-3 K-1)
ZHC_ROOF(1,4) = 1127845.62      ! volumetric heat capacity (J m-3 K-1) 
ZHC_ROOF(1,5) =   52030.        ! volumetric heat capacity (J m-3 K-1) (inner layer)
ZTC_ROOF(1,1) = ZTC_ROOF_S(1)   ! thermal conductivity (W/m K) (external layer)
ZTC_ROOF(1,2) = ZTC_ROOF_S(1)   ! thermal conductivity (W/m K)
ZTC_ROOF(1,3) = ZTC_ROOF_S(1)   ! thermal conductivity (W/m K)
ZTC_ROOF(1,4) = 0.095454545 ! thermal conductivity (W/m K)
ZTC_ROOF(1,5) = 0.03        ! thermal conductivity (W/m K) (inner layer)
ZD_ROOF(1,1)  = 0.001      ! thickcness (m) (external layer)
ZD_ROOF(1,2)  = 0.098      ! thickcness (m)
ZD_ROOF(1,3)  = 0.132      ! thickcness (m)
ZD_ROOF(1,4)  = 0.098      ! thickcness (m)
ZD_ROOF(1,5)  = 0.001      ! thickcness (m) (inner layer)

!============================================================
!============================================================
! Road
!============================================================
!============================================================
NROAD_LAYER = 5          ! number of road layers
ALLOCATE(ZHC_ROAD    (1,NROAD_LAYER)) 
ALLOCATE(ZTC_ROAD    (1,NROAD_LAYER)) 
ALLOCATE(ZD_ROAD     (1,NROAD_LAYER)) 
ZHC_ROAD(1,1) = ZHC_ROAD_S(1)  ! volumetric heat capacity (J m-3 K-1) (surface layer)
ZHC_ROAD(1,2) = ZHC_ROAD_S(1)  ! volumetric heat capacity (J m-3 K-1)
ZHC_ROAD(1,3) = 1989600. ! volumetric heat capacity (J m-3 K-1)
ZHC_ROAD(1,4) = 1640000. ! volumetric heat capacity (J m-3 K-1)
ZHC_ROAD(1,5) = 1400000. ! volumetric heat capacity (J m-3 K-1) (deep soil layer)
ZTC_ROAD(1,1) = ZTC_ROAD_S(1)  ! thermal conductivity (W/m K) (surface layer)
ZTC_ROAD(1,2) = ZTC_ROAD_S(1)  ! thermal conductivity (W/m K)
ZTC_ROAD(1,3) = 1.976584 ! thermal conductivity (W/m K)
ZTC_ROAD(1,4) = 0.5915493! thermal conductivity (W/m K)
ZTC_ROAD(1,5) = 0.4000   ! thermal conductivity (W/m K) (deep soil layer)
ZD_ROAD(1,1)  = 0.001       ! thickcness (m) (surface layer)
ZD_ROAD(1,2)  = 0.045296296 ! thickcness (m)
ZD_ROAD(1,3)  = 0.092592593 ! thickcness (m)
ZD_ROAD(1,4)  = 0.27777778  ! thickcness (m)
ZD_ROAD(1,5)  = 0.83333333  ! thickcness (m) (deep soil layer)
!============================================================
!============================================================
! Wall
!============================================================
!============================================================
NWALL_LAYER = 5         ! number of wall layers
ALLOCATE(ZHC_WALL    (1,NWALL_LAYER)) 
ALLOCATE(ZTC_WALL    (1,NWALL_LAYER)) 
ALLOCATE(ZD_WALL     (1,NWALL_LAYER)) 
ZHC_WALL(1,1) = ZHC_WALL_S(1)    ! volumetric heat capacity (J m-3 K-1) (external layer)
ZHC_WALL(1,2) = ZHC_WALL_S(1)    ! volumetric heat capacity (J m-3 K-1) 
ZHC_WALL(1,3) = ZHC_WALL_S(1)    ! volumetric heat capacity (J m-3 K-1) 
ZHC_WALL(1,4) = 1127845.6   ! volumetric heat capacity (J m-3 K-1) 
ZHC_WALL(1,5) =   52030.    ! volumetric heat capacity (J m-3 K-1) (inner layer)
ZTC_WALL(1,1) = ZTC_WALL_S(1)    ! thermal conductivity (W/m K) (external layer)
ZTC_WALL(1,2) = ZTC_WALL_S(1)    ! thermal conductivity (W/m K)
ZTC_WALL(1,3) = ZTC_WALL_S(1)    ! thermal conductivity (W/m K)
ZTC_WALL(1,4) = 0.095454545 ! thermal conductivity (W/m K)
ZTC_WALL(1,5) = 0.03        ! thermal conductivity (W/m K) (inner layer)
ZD_WALL(1,1)  = 0.001       ! thickcness (m) (external layer)
ZD_WALL(1,2)  = 0.098       ! thickcness (m)
ZD_WALL(1,3)  = 0.132       ! thickcness (m)
ZD_WALL(1,4)  = 0.098       ! thickcness (m)
ZD_WALL(1,5)  = 0.001       ! thickcness (m) (inner layer)
!============================================================
!============================================================
! Floor and internal mass
!============================================================
!============================================================
NFLOOR_LAYER = 5         ! number of floor layers
ALLOCATE(ZHC_FLOOR   (1,NFLOOR_LAYER)) 
ALLOCATE(ZTC_FLOOR   (1,NFLOOR_LAYER)) 
ALLOCATE(ZD_FLOOR    (1,NFLOOR_LAYER))  
ZHC_FLOOR(1,1) = 2016000. ! volumetric heat capacity (J m-3 K-1) (upper layer)
ZHC_FLOOR(1,2) = 2016000. ! volumetric heat capacity (J m-3 K-1)
ZHC_FLOOR(1,3) = 2016000. ! volumetric heat capacity (J m-3 K-1)
ZHC_FLOOR(1,4) = 2016000. ! volumetric heat capacity (J m-3 K-1)
ZHC_FLOOR(1,5) = 2016000. ! volumetric heat capacity (J m-3 K-1) (lower layer)
ZTC_FLOOR(1,1) = 1.95     ! thermal conductivity (W/m K) (upper layer)
ZTC_FLOOR(1,2) = 1.95     ! thermal conductivity (W/m K)
ZTC_FLOOR(1,3) = 1.95     ! thermal conductivity (W/m K)
ZTC_FLOOR(1,4) = 1.95     ! thermal conductivity (W/m K)
ZTC_FLOOR(1,5) = 1.95     ! thermal conductivity (W/m K) (lower layer)
ZD_FLOOR(1,1)  = 0.001        ! thickcness (m) (upper layer)
ZD_FLOOR(1,2)  = 0.0064074074 ! thickcness (m)
ZD_FLOOR(1,3)  = 0.014814815  ! thickcness (m)
ZD_FLOOR(1,4)  = 0.044444444  ! thickcness (m)
ZD_FLOOR(1,5)  = 0.13333333   ! thickcness (m) (lower layer)

! 
!============================================================
!============================================================
!* anthropogenic heat fluxes
!============================================================
!============================================================
ZLE_TRAFFIC  = 0.0  ! heat fluxes due to traffic
ZLE_INDUSTRY = 0.0  ! heat fluxes due to factories
! 
!============================================================
!============================================================
! solar panels
!============================================================
!============================================================
ZEMIS_PANEL = 0.9      ! Emissivity of solar panel [-]
ZALB_PANEL  = 0.1      ! albedo of solar panel  [-]
ZEFF_PANEL  = 0.14     ! Efficiency of solar panel [-]
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
ZQIN          = 5.8     ! Internal heat gains [W m-2(floor)]
ZQIN_FRAD     = 0.2     ! Radiant fraction of internal heat gains
ZQIN_FLAT     = 0.2     ! Latent franction of internal heat gains
!
!=============================================================
! windows
!=============================================================
!
ZSHGC         = 0.763   ! window solar transmittance
PU_WIN        = 2.716   ! window glass-to-glass U-factor [W m-2 K-1]
!
!=============================================================
! Shading devices
!=============================================================
!
ZSHGC_SH      = 0.025   ! window + shading solar heat gain coef.
!
!=============================================================
! HVAC system
!=============================================================
!
ZF_WATER_COND = 0.      ! fraction of evaporation for the condensers
ZF_WASTE_CAN  = 1.0     ! fraction of waste heat released into the canyon
!
!=============================================================
! Internal target temperatures
!=============================================================
ZHR_TARGET    = 0.5     ! Relative humidity setpoint
!
!=============================================================
! Heating system
!=============================================================
!
ZEFF_HEAT     = 0.9     ! Efficiency of the heating system
!
!=============================================================
! Cooling system
!=============================================================
!
ZT_ADP        = 285.66  ! Apparatus dewpoint temperature of the
!=============================================================
! convection coefficients option
!=============================================================
!
CCH_BEM       = ' ' ! TEB option for building outside conv. coef : '   ', 'DOE-2'
ZROUGH_ROOF   = 1.52    ! roof roughness coef. in case DOE-2
ZROUGH_WALL   = 1.52    ! wall roughness coef. in case DOE-2
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
	ZZ0U = ZZ0
ELSE
    ZZ0U = ZZ0
	!IF (ZILMO_TOP(1) < 0.) THEN
	!	ZZ0U = ZZ0 * (1 + 1.15 * ((ZBLD_HEIGHT / -ZILMO_TOP)**(1./3.)))
	!ELSE
	!	ZZ0U = ZZ0 / (1 + 8.13 * (ZBLD_HEIGHT / ZILMO_TOP))
	!ENDIF	
ENDIF
!ZZ0U = MIN(ZZ0U,ZZ0 * 5.)
!ZZ0U = MAX(ZZ0U,ZZ0 * 0.2)

IF (ntstep == 1) THEN

	! Input/Output semi-prognostic variables
	ZT_CANYON      = t                 ! Canyon air temperature
	ZQ_CANYON      = qv                ! Outdoor specific humidity    [kg kg-1]
	
	! Input/Output prognostic variables
	ZTI_BLD        = ZTCOOL_TARGET     ! indoor air temperature
    ZQI_BLD        = 0.0068794074      ! Indoor air specific humidity [kg kg-1]
	ZU_CANYON      = 1.                ! Wind speed in canyon
	ZTS_TOWN_S     = t
    ZTS_TOWN       = t	
	ZQS_TOWN_S     = qv
	
	! Roof properties
	ZD_ROOF_LAYERS = ZD_ROOF(1,4) + ZD_ROOF(1,3) + ZD_ROOF(1,2) + ZD_ROOF(1,1)
	ZT_ROOF(:,1)   = t  ! roof layers temperatures
	ZT_ROOF(:,2)   = ZTCOOL_TARGET - ((ZTCOOL_TARGET - t) * (ZD_ROOF(1,4) + ZD_ROOF(1,3) + ZD_ROOF(1,2)) / ZD_ROOF_LAYERS)  ! roof layers temperatures
	ZT_ROOF(:,3)   = ZTCOOL_TARGET - ((ZTCOOL_TARGET - t) * (ZD_ROOF(1,4) + ZD_ROOF(1,3))  / ZD_ROOF_LAYERS)  ! roof layers temperatures
	ZT_ROOF(:,4)   = ZTCOOL_TARGET - ((ZTCOOL_TARGET - t) * ZD_ROOF(1,4)  / ZD_ROOF_LAYERS)  ! roof layers temperatures
	ZT_ROOF(:,5)   = ZTCOOL_TARGET  ! roof layers temperatures
	
	! Road properties
	ZT_ROAD  (:,1) = t  ! road layers temperatures
	ZT_ROAD  (:,2) = t  ! road layers temperatures
	ZT_ROAD  (:,3) = t  ! road layers temperatures
	ZT_ROAD  (:,4) = t  ! road layers temperatures
	ZT_ROAD  (:,5) = t  ! road layers temperatures
	ZT_ROAD_NOW(:,:) = ZT_ROAD(:,:)
	
	! Wall properties
	ZD_WALL_LAYERS = ZD_WALL(1,1) + ZD_WALL(1,2) + ZD_WALL(1,3) + ZD_WALL(1,4)
	ZT_WALL_A(:,1) = t  ! wall layers temperatures
	ZT_WALL_A(:,2) = ZTCOOL_TARGET - ((ZTCOOL_TARGET - t) * (ZD_WALL(1,4) + ZD_WALL(1,3) + ZD_WALL(1,2)) / ZD_WALL_LAYERS)  ! wall layers temperatures
	ZT_WALL_A(:,3) = ZTCOOL_TARGET - ((ZTCOOL_TARGET - t) * (ZD_WALL(1,4) + ZD_WALL(1,3))  / ZD_WALL_LAYERS)  ! wall layers temperatures
	ZT_WALL_A(:,4) = ZTCOOL_TARGET - ((ZTCOOL_TARGET - t) * ZD_WALL(1,4)  / ZD_WALL_LAYERS)  ! wall layers temperatures
	ZT_WALL_A(:,5) = ZTCOOL_TARGET  ! wall layers temperatures
	ZT_WALL_B      = ZT_WALL_A      ! wall layers temperatures

	! Floor properties
	ZT_FLOOR (:,1) = 292.12         ! building floor temperature
	ZT_FLOOR (:,2) = 291.89778      ! building floor temperature
	ZT_FLOOR (:,3) = 291.26111      ! building floor temperature
	ZT_FLOOR (:,4) = 289.48333      ! building floor temperature
	ZT_FLOOR (:,5) = 283.84017      ! building floor temperature
	
	! Mass properties
	ZT_MASS  (:,1) = 292.15         ! building mass temperature
	ZT_MASS  (:,2) = 292.15         ! building mass temperature
	ZT_MASS  (:,3) = 292.15         ! building mass temperature
	ZT_MASS  (:,4) = 292.15         ! building mass temperature
	ZT_MASS  (:,5) = 291.84017      ! building mass temperature
	
	! Water content at first time-step
	ZWS_ROOF       = 0.             ! roof water content (kg/m2) 
	ZWS_ROAD       = 0.             ! road water content (kg/m2)
	! -----------------------------------------------------------
	! Default at first time-step : no snow
	! ----------------------------------------------------------- 
	ZWSNOW_ROOF    = 0.             ! Initial Amount of roof snow reservoir
	ZWSNOW_ROAD    = 0.             ! Initial Amount of road snow reservoir
	ZTSNOW_ROOF    = XUNDEF         ! layer temperature   of roof snow
	ZTSNOW_ROAD    = XUNDEF         ! layer temperature   of road snow
	ZRSNOW_ROOF    = XUNDEF         ! density             of roof snow
	ZRSNOW_ROAD    = XUNDEF         ! density             of road snow
	ZTSSNOW_ROOF   = XUNDEF         ! surface temperature of roof snow
	ZTSSNOW_ROAD   = XUNDEF         ! surface temperature of road snow
	ZASNOW_ROOF    = XUNDEF
	ZASNOW_ROAD    = XUNDEF
	ZESNOW_ROOF    = XUNDEF
	ZESNOW_ROAD    = XUNDEF
	! -----------------------------------------------------------
	! Default at first time-step for BEM Model
	! -----------------------------------------------------------
	ZM_SYS_RAT     = 0.0067         ! Rated HVAC mass flow rate [kg s-1 m-2(bld)]	
	ZT_WIN1        = t              ! External window temperature
	ZT_WIN2        = ZTCOOL_TARGET  ! Internal window temperature
	ZALB_WIN       = XUNDEF
	ZNATVENT       = 0.           ! flag to describe surventilation system for i/o 
                                       ! 0 for NONE, 1 for MANU and 2 for AUTO
	!LSHADE         = .FALSE.      ! Are shading devices being used ?
	ZSHADE         = 0.           ! flag to activate shading devices -> REAL for i/o 0. or 1	
    GSHAD_DAY      = .FALSE.      ! has shading been necessary this day ?
    GNATVENT_NIGHT = .FALSE.      ! has natural ventilation been necessary/possible this night ?	
	! For REAL Cooling System
	IF (PFLOOR_HEIGHT(1) > ZBLD_HEIGHT(1)) THEN
      PFLOOR_HEIGHT = ZBLD_HEIGHT
    ENDIF
    ZN_FLOOR = FLOAT(NINT(ZBLD_HEIGHT / PFLOOR_HEIGHT ))
    ZCAP_SYS_RAT        = ZCAP_SYS_RAT * ZN_FLOOR   ! Rated capacity of the cooling system [W m-2(bld)]

	! For (Wang, 2012) Wind Calculation
	ZUSTAR_TOWN         = 0.2 
	
	IF (icell .EQ. 1 .AND. iblock .EQ. 1) THEN
		!-------------------------------------------------------------------
		! Print configuration parameters (only on first time step)
		!-------------------------------------------------------------------
		PRINT*, '=================================================='
		PRINT*, 'TEB-Ru Configuration Parameters (from namelists):'
		PRINT*, '  Geometry:'
		PRINT*, '    ZBLD          = ', ZBLD(1)
		PRINT*, '    ZGARDEN       = ', ZGARDEN(1)
		PRINT*, '    ZCAN_HW_RATIO = ', ZCAN_HW_RATIO(1)
		PRINT*, '    ZBLD_HEIGHT   = ', ZBLD_HEIGHT(1)
		PRINT*, '    ZROAD_DIR     = ', ZROAD_DIR(1)
		PRINT*, '    HROAD_DIR     = ', HROAD_DIR
		PRINT*, '    HWALL_OPT     = ', HWALL_OPT
		PRINT*, '  Thermal properties:'
		PRINT*, '    ZHC_ROAD_S    = ', ZHC_ROAD_S(1)
		PRINT*, '    ZHC_ROOF_S    = ', ZHC_ROOF_S(1)
		PRINT*, '    ZHC_WALL_S    = ', ZHC_WALL_S(1)
		PRINT*, '    ZTC_ROAD_S    = ', ZTC_ROAD_S(1)
		PRINT*, '    ZTC_ROOF_S    = ', ZTC_ROOF_S(1)
		PRINT*, '    ZTC_WALL_S    = ', ZTC_WALL_S(1)
		PRINT*, '    ZALB_ROAD     = ', ZALB_ROAD(1)
		PRINT*, '    ZALB_ROOF     = ', ZALB_ROOF(1)
		PRINT*, '    ZALB_WALL     = ', ZALB_WALL(1)
		PRINT*, '    ZEMIS_ROAD    = ', ZEMIS_ROAD(1)
		PRINT*, '    ZEMIS_ROOF    = ', ZEMIS_ROOF(1)
		PRINT*, '    ZEMIS_WALL    = ', ZEMIS_WALL(1)
		PRINT*, '  BEM parameters:'
		PRINT*, '    CBEM          = ', CBEM
		PRINT*, '    LBEM_AC       = ', LBEM_AC
		PRINT*, '    ZTCOOL_TARGET = ', ZTCOOL_TARGET(1)
		PRINT*, '    ZTHEAT_TARGET = ', ZTHEAT_TARGET(1)
		PRINT*, '    ZV_VENT       = ', ZV_VENT(1)
		PRINT*, '    ZINF          = ', ZINF(1)
		PRINT*, '    ZCOP_RAT      = ', ZCOP_RAT(1)
		PRINT*, '    ZGR           = ', ZGR(1)
		PRINT*, '    ZRESIDENTIAL  = ', ZRESIDENTIAL(1)
		PRINT*, '    ZDT_RES       = ', ZDT_RES
		PRINT*, '    ZDT_OFF       = ', ZDT_OFF
		PRINT*, '    ZCAP_SYS_HEAT = ', ZCAP_SYS_HEAT(1)
		PRINT*, '    HNATVENT      = ', HNATVENT
		PRINT*, '    CCOOL_COIL    = ', CCOOL_COIL
		PRINT*, '    CHEAT_COIL    = ', CHEAT_COIL
		PRINT*, '  Green roofs:'
		PRINT*, '    LGREENROOF    = ', LGREENROOF
		PRINT*, '    ZFRAC_GR      = ', ZFRAC_GR(1)
		PRINT*, '    LGREENROOF_EXT= ', LGREENROOF_EXT
		PRINT*, '  Gardens:'
		PRINT*, '    LGARDEN       = ', LGARDEN
		PRINT*, '    LGARDEN_EXT   = ', LGARDEN_EXT
		PRINT*, '  Solar panels:'
		PRINT*, '    LSOLAR_PANEL  = ', LSOLAR_PANEL
		PRINT*, '    ZFRAC_PANEL   = ', ZFRAC_PANEL(1)
		PRINT*, '  Irrigation:'
		PRINT*, '    LPAR_RD_IRRIG = ', LPAR_RD_IRRIG
		PRINT*, '    ZRD_START_MONTH = ', ZRD_START_MONTH(1)
		PRINT*, '    ZRD_END_MONTH   = ', ZRD_END_MONTH(1)
		PRINT*, '    ZRD_START_HOUR  = ', ZRD_START_HOUR(1)
		PRINT*, '    ZRD_END_HOUR    = ', ZRD_END_HOUR(1)
		PRINT*, '    ZRD_24H_IRRIG   = ', ZRD_24H_IRRIG(1)
		PRINT*, '  Wind:'
		PRINT*, '    ITYPE_WIND    = ', ITYPE_WIND(1)
		PRINT*, '    ZFAI          = ', ZFAI(1,:)
!MV202609 z0 and zd to namelist
		PRINT*, '  Aerodynamics of the urban surface:'
		PRINT*, '    urb_z0_town   = ', HZ0_TOWN, ' -> z0   = ', ZZ0(1), ' m'
		PRINT*, '    urb_zd_town   = ', HZD_TOWN, ' -> zd   = ', ZZDU(1), ' m'
		PRINT*, '  Anthropogenic heat:'
		PRINT*, '    ZH_TRAFFIC    = ', ZH_TRAFFIC(1)
		PRINT*, '    ZH_INDUSTRY   = ', ZH_INDUSTRY(1)
		PRINT*, '    ZUTC_HOUR     = ', ZUTC_HOUR
		PRINT*, '  Shading flag:'
		PRINT*, '    LSHADE        = ', LSHADE
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
IF ( (.NOT. LGREENROOF) .AND. ZFRAC_GR(1)>0.) THEN
  print*, 'Greenroofs option   is not activated but a non-zero greenroof fraction is given'
  STOP
END IF
IF ( (.NOT. LGARDEN) .AND. ZGARDEN(1)>0.) THEN
  print*, 'Garden     option   is not activated but a non-zero garden    fraction is given'
  STOP
END IF
IF ( ZBLD(1)+ZGARDEN(1)>=1.) THEN
  print*, 'The sum of garden and building fraction is larger than one, so road fraction is negative. Please check their values.'
  print*, 'ZGARDEN = ', ZGARDEN(1)
  print*, 'ZBLD = ', ZBLD(1)
  print*, 'iblock = ', iblock
  print*, 'icell = ', icell
  STOP
END IF
IF ( (.NOT. LSOLAR_PANEL) .AND. ZFRAC_PANEL(1)>0.) THEN
  print*, 'Solar panels option is not activated but a non-zero solar panels fraction is given'
  STOP
END IF
IF ( (.NOT. CBEM=='BEM') .AND. ZGR(1)>0.) THEN
  print*, 'Building Energy Module (BEM) is not activated but a non-zero glazing ratio is given'
  STOP
END IF
!
!
! multi layer option
LCANOPY= .FALSE.  ! is canopy active ?  ** DO NOT CHANGE **
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
! sun position at run start
!
CALL SUNPOS(IYEAR, IMONTH, IDAY, ZTIME, ZLON, ZLAT, XTSUN, XZENITH, XAZIM)


!
! -----------------------------------------------------------
! Geometric parameters
! -----------------------------------------------------------
!
ZROAD         = (1. - ZBLD - ZGARDEN)
XZREF         = ZZREF
XUREF         = ZZREF
ZWALL_O_HOR   = 2. * ZCAN_HW_RATIO * (1. - ZBLD)

ZSVF_ROAD     = (SQRT(ZCAN_HW_RATIO**2+1.) - ZCAN_HW_RATIO)
ZSVF_GARDEN   = ZSVF_ROAD
ZSVF_WALL     =  0.5*(ZCAN_HW_RATIO+1.-SQRT(ZCAN_HW_RATIO**2+1.))/ZCAN_HW_RATIO
ZZ_LOWCAN     = ZBLD_HEIGHT / 2
ZTOTS_O_HORS  = 1. + ZWALL_O_HOR
ZROOF_FRAC    = ZBLD        / ZTOTS_O_HORS
ZWALL_FRAC    = ZWALL_O_HOR / ZTOTS_O_HORS
ZROAD_FRAC    = ZROAD       / ZTOTS_O_HORS
ZGARDEN_FRAC  = ZGARDEN     / ZTOTS_O_HORS
ZWALL_O_GRND  = ZWALL_FRAC  / (ZROAD_FRAC+ZGARDEN_FRAC)
ZROAD_O_GRND   = ZROAD / (ZROAD + ZGARDEN)
ZGARDEN_O_GRND = ZGARDEN / (ZROAD + ZGARDEN)

IF (LGREENROOF_EXT) THEN
  ZRUNOFF_GR_EXT  = ZRUNOFF_GR_EXT / dt
ENDIF
IF (LGARDEN_EXT) THEN
  ZRUNOFF_GD_EXT    = ZRUNOFF_GD_EXT / dt
ENDIF	
!
! -----------------------------------------------------------
! BEM characteristics
! -----------------------------------------------------------

CALL BEM_MORPHO_STRUCT(ZBLD, ZWALL_O_HOR, ZBLD_HEIGHT, PFLOOR_HEIGHT,                  &
                      ZGR, ZN_FLOOR, ZWALL_O_BLD, ZGLAZ_O_BLD, ZMASS_O_BLD,     &
                      ZFLOOR_HW_RATIO,                                          &
                      ZF_FLOOR_MASS, ZF_FLOOR_WALL, ZF_FLOOR_WIN,               &
                      ZF_FLOOR_ROOF, ZF_WALL_FLOOR, ZF_WALL_MASS,               &
                      ZF_WALL_WIN, ZF_WIN_FLOOR, ZF_WIN_MASS, ZF_WIN_WALL,      &
                      ZF_MASS_FLOOR, ZF_MASS_WALL, ZF_MASS_WIN, ZF_WASTE_CAN,   &
                      ZF_WIN_WIN)
!
! -----------------------------------------------------------
! Window characteristics
! -----------------------------------------------------------
!
CALL WINDOW_DATA_STRUCT(1, ZSHGC, PU_WIN, ZALB_WIN, ZABS_WIN, ZUGG_WIN, ZTRAN_WIN)

! -----------------------------------------------------------
! Define Forcing variables
! -----------------------------------------------------------
ZTS_ROOF    = 0.
ZTS_ROAD    = 0.
ZTS_WALL_A  = 0.
ZTS_WALL_B  = 0.
XTA(:)      = t
XPS(:)      = ps
!XRHOA (:)   = XPS (:) / XRD /  ZTS_TOWN (:) / ( 1.+((XRV/XRD)-1.)*ZQS_TOWN_S (:) )
XRHOA(:)    = XPS(:) / ( XTA(:)*XRD * ( 1.+((XRV/XRD)-1.)*qv(:) ) + XZREF(:)*XG )
ZQA_KGKG(:) = qv
XSNOW(:)    = prs_con + prs_gsp + prg_gsp
XRAIN(:)    = prr_con + prr_gsp
XPA(:)      = XPS(:) - XRHOA(:) * XG * XZREF
XCO2(:)     = 0.0
XU(:)       = u
XV(:)       = v   
XLW(:)      = lwd_s
XDIR_SW(:,1)  =  swdir_s            
XSCA_SW(:,1)  =  swdifd_s
ZTS_TOWN_S_NOW   = ZTS_TOWN
ZT_ROAD_NOW(:,:) = ZT_ROAD(:,:)
ZWS_TOWN_NOW     = ZWS_TOWN
ZTSSNOW_TOWN_NOW = ZTSSNOW_TOWN
ZWSNOW_TOWN_NOW  = ZWSNOW_TOWN
ZRSNOW_TOWN_NOW  = ZRSNOW_TOWN
ZSNOWD_TOWN_NOW  = ZSNOWD_TOWN

! Check No value data
!---------------------
! Error cases
! From OL_TIME_INTERP_ATM.F90
IF (MINVAL(XPS)    .EQ.XUNDEF) THEN            ! No surface Pressure 
	XPS(:)  = 101325*(1-0.0065 * XZS(:)/288.15)**5.31
ENDIF
IF (MINVAL(XDIR_SW).EQ.XUNDEF) XDIR_SW(:,:)=0. ! No direct solar radiation
IF (MINVAL(XSCA_SW).EQ.XUNDEF) XSCA_SW(:,:)=0. ! No diffuse solar radiation

! Update time
ZTIME_BEG = ZTIME           ! time at beginning of time step
XTSTEP_SURF = dt
      
TPTIME%TIME= ZTIME
TPTIME%TDATE%YEAR =IYEAR
TPTIME%TDATE%MONTH=IMONTH
TPTIME%TDATE%DAY  =IDAY
!
! Exner functions
!
ZEXNS = (XPS/XP00)**(XRD/XCPD)
ZEXNA = (XPA/XP00)**(XRD/XCPD)

! -----------------------------------------------------------
! Solar Corrections
! -----------------------------------------------------------
! coherence between solar zenithal angle and radiation
! when solar beam close to horizontal -> reduction of direct radiation to
! the benefit of scattered radiation
! when pi/2 - 0.1 < ZENITH < pi/2 - 0.05 => weight of direct to scattered radiation decreases linearly with zenith 
! when pi/2 - 0.05 < ZENITH => all the direct radiation is converted to scattered radiation
! coherence between solar zenithal angle and radiation
!
ZCOEF(:) = (XPI/2. - XZENITH(:) - 0.05) / 0.05
ZCOEF(:) = MAX(MIN(ZCOEF,1.),0.)
DO JLOOP=1,SIZE(XDIR_SW,2)
  XSCA_SW(:,JLOOP) = XSCA_SW(:,JLOOP) + XDIR_SW(:,JLOOP) * (1 - ZCOEF)
  XDIR_SW(:,JLOOP) = XDIR_SW(:,JLOOP) * ZCOEF(:)
ENDDO
!
ZTDIR_SW = XDIR_SW(1,1)
ZTSCA_SW = XSCA_SW(1,1)
KSW = 1  ! only one spectral band here
!
! Sky model for diffuse radiation
!
!add directionnal contrib from scattered radiation
CALL CIRCUMSOLAR_RAD(XDIR_SW(:,1), XSCA_SW(:,1), XZENITH, ZF1_o_B)
ZTDIR_SW(:,1) = XDIR_SW(:,1) + XSCA_SW(:,1) * ZF1_o_B
ZTSCA_SW(:,1) = XSCA_SW(:,1) * (1. - ZF1_o_B)
!
!
! -----------------------------------------------------------
! Calculation of Wind Speed inside the canyon
! -----------------------------------------------------------
ZVMOD = SQRT(XU**2+XV**2)
! Wind speed at the top of the canyon (roof level), from the logarithmic
! profile referenced to the displacement height ZZDU
ZU_TOP = ZVMOD * LOG( (        ZBLD_HEIGHT - ZZDU) / ZZ0U)   &
	/ LOG( (ZZREF + ZBLD_HEIGHT - ZZDU) / ZZ0U)
IF (ITYPE_WIND(1) == 0) THEN
	ZWAKE = 1. + (2./XPI-1.) * 2. * (ZCAN_HW_RATIO-0.5)
	ZWAKE = MAX(MIN(ZWAKE,1.),2./XPI)
	ZU_CANYON = ZWAKE * EXP(-ZCAN_HW_RATIO/4.) * ZU_TOP
ELSEIF (ITYPE_WIND(1) == 1) THEN
	CALL WIND_CALCULATION_WANG(icell, iblock, ZBLD_HEIGHT, ZUSTAR_TOWN, ZU_TOP, XU, XV, ZFAI, ZU_CANYON_WANG)  
	ZU_CANYON = ZU_CANYON_WANG(5)
ENDIF

! Calculate Wind Direction from U and V components
! Forcing for TERRA to use Garden
XPII = 2.*ASIN(1.)
ZDIR = MOD(180. + 180. / XPII * atan2(XU,XV),360.) 
XU_CANYON = -ZU_CANYON*SIN(ZDIR*XPII/180)
XV_CANYON = -ZU_CANYON*COS(ZDIR*XPII/180)	

ZU_LOWCAN = ZU_CANYON 
ZT_LOWCAN = ZT_CANYON 
ZQ_LOWCAN = ZQ_CANYON 

ZPEW_A_COEF        = 0.
ZPEW_A_COEF_LOWCAN = 0.
ZPEW_B_COEF        = ZVMOD
ZPEW_B_COEF_LOWCAN = ZU_LOWCAN
	
! -----------------------------------------------------------
! Calculation of Daily Cycle of AHF TRAFFIC
! -----------------------------------------------------------	
CALL H_TRAFFIC_NOW(icell, iblock, ZH_TRAFFIC, IHOUR, IMIN, ISEC, ZUTC_HOUR, ZH_TRAFFIC_NOW) 
ZH_TRAFFIC_NOW_CAN = ZH_TRAFFIC_NOW
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


CALL TEB_GARDEN_STRUCT (icell, iblock, LGARDEN, LGARDEN_EXT, LGREENROOF, LGREENROOF_EXT, LSOLAR_PANEL,                &
                     HZ0H, HIMPLICIT_WIND, HROAD_DIR, HWALL_OPT, TPTIME,      &
                     LBEM_AC, XTSUN, ZT_CANYON, ZQ_CANYON, ZU_CANYON,                  &
                     ZT_LOWCAN, ZQ_LOWCAN, ZU_LOWCAN, ZZ_LOWCAN,              &
                     ZTI_BLD,                                                 &
                     ZT_ROOF, ZT_ROAD, ZT_WALL_A, ZT_WALL_B,                  &
                     ZWS_ROOF,ZWS_ROAD,                                       &
                     HSNOW_ROOF,                                              &
                     ZWSNOW_ROOF, ZTSNOW_ROOF, ZRSNOW_ROOF, ZASNOW_ROOF,      &
                     ZTSSNOW_ROOF, ZESNOW_ROOF,                               &
                     HSNOW_ROAD,                                              &
                     ZWSNOW_ROAD, ZTSNOW_ROAD, ZRSNOW_ROAD, ZASNOW_ROAD,      &
                     ZTSSNOW_ROAD, ZESNOW_ROAD,                               &
                     ZPEW_A_COEF, ZPEW_B_COEF,                                &
                     ZPEW_A_COEF_LOWCAN, ZPEW_B_COEF_LOWCAN, ZZ0_GD_EXT,      &
                     XPS, XPA, ZEXNS, ZEXNA,                                  &
                     XTA, ZQA_KGKG, XRHOA, XCO2,                              &
                     XLW, ZTDIR_SW, ZTSCA_SW, XSW_BANDS, KSW,                 &
                     XZENITH, XAZIM,                                          &
                     XRAIN, XSNOW,                                            &
                     ZZREF, ZZREF, ZVMOD,                                     &
                     ZH_TRAFFIC_NOW_CAN, ZLE_TRAFFIC, ZH_INDUSTRY, ZLE_INDUSTRY,      &
                     XTSTEP_SURF,                                             &
                     ZZ0U,                                                     &
                     ZBLD,ZGARDEN,ZROAD_DIR,ZROAD,ZFRAC_GR,                   &
                     ZBLD_HEIGHT,ZWALL_O_HOR,ZCAN_HW_RATIO,                   &
                     ZROAD_O_GRND, ZGARDEN_O_GRND, ZWALL_O_GRND,              &
                     ZALB_ROOF, ZEMIS_ROOF,                                   &
                     ZHC_ROOF,ZTC_ROOF,ZD_ROOF,                               &
                     ZALB_ROAD, ZEMIS_ROAD, ZSVF_ROAD,                        &
                     ZHC_ROAD,ZTC_ROAD,ZD_ROAD,                               &
                     ZALB_WALL, ZEMIS_WALL, ZSVF_WALL,                        &
                     ZSVF_GARDEN,                                             &
                     ZHC_WALL,ZTC_WALL,ZD_WALL,                               &
                     ZRN_ROOF, ZH_ROOF, ZLE_ROOF, ZLEW_ROOF, ZGFLUX_ROOF,     &
                     ZRUNOFF_ROOF,                                            &
                     ZRN_ROAD, ZH_ROAD, ZLE_ROAD, ZLEW_ROAD, ZGFLUX_ROAD,     &
                     ZRUNOFF_ROAD,                                            &
                     ZRN_WALL_A, ZH_WALL_A, ZLE_WALL_A, ZGFLUX_WALL_A,        &
                     ZRN_WALL_B, ZH_WALL_B, ZLE_WALL_B, ZGFLUX_WALL_B,        &
                     ZRN_STRLROOF,ZH_STRLROOF,ZLE_STRLROOF, ZGFLUX_STRLROOF,  &
                     ZRUNOFF_STRLROOF,                                        &
                     ZRN_BLT,ZH_BLT,ZLE_BLT, ZGFLUX_BLT,                      &
                     ZRNSNOW_ROOF, ZHSNOW_ROOF, ZLESNOW_ROOF, ZGSNOW_ROOF,    &
                     ZMELT_ROOF,                                              &
                     ZRNSNOW_ROAD, ZHSNOW_ROAD, ZLESNOW_ROAD, ZGSNOW_ROAD,    &
                     ZMELT_ROAD,                                              &
                     ZRN_GRND, ZH_GRND, ZLE_GRND, ZGFLUX_GRND,                &
                     ZRN_TOWN, ZH_TOWN, ZLE_TOWN, ZGFLUX_TOWN, ZEVAP_TOWN,    &
                     ZRUNOFF_TOWN, ZSFCO2,                                    &
                     ZUW_GRND, ZUW_ROOF, ZDUWDU_GRND, ZDUWDU_ROOF,            & 
                     ZUSTAR_TOWN, ZCD, ZCDN, ZCH_TOWN, ZRI_TOWN,              &
                     ZTS_TOWN, ZEMIS_TOWN, ZDIR_ALB_TOWN, ZSCA_ALB_TOWN,      &
                     ZSO_ALB_TOWN, ZSW_UP_SO, ZRESA_TOWN, ZDQS_TOWN, ZQF_TOWN, ZQF_BLD,  &
                     ZFLX_BLD, ZAC_ROOF, ZAC_ROAD, ZAC_WALL, ZAC_GARDEN, ZAC_GREENROOF,           &
                     ZAC_ROAD_WAT, ZAC_GARDEN_WAT, ZAC_GREENROOF_WAT,         &
                     ZABS_SW_ROOF,ZABS_LW_ROOF,                               &
                     ZABS_SW_SNOW_ROOF,ZABS_LW_SNOW_ROOF,                     &
                     ZABS_SW_ROAD,ZABS_LW_ROAD,                               &
                     ZABS_SW_SNOW_ROAD,ZABS_LW_SNOW_ROAD,                     &
                     ZABS_SW_WALL_A,ZABS_LW_WALL_A,                           &
                     ZABS_SW_WALL_B,ZABS_LW_WALL_B,                           &
                     ZABS_SW_PANEL,ZABS_LW_PANEL,                             &
                     ZABS_SW_GARDEN,ZABS_LW_GARDEN,                           &
                     ZABS_SW_GREENROOF,ZABS_LW_GREENROOF,                     &
                     ZG_GREENROOF_ROOF,    &
                     CCOOL_COIL, ZF_WATER_COND, CHEAT_COIL,  &
                     HNATVENT, ZNATVENT, IDAY, ZAUX_MAX, ZT_FLOOR,            &
                     ZT_MASS, ZH_BLD_COOL, ZT_BLD_COOL, ZH_BLD_HEAT,          &
                     ZLE_BLD_COOL, ZLE_BLD_HEAT, ZH_WASTE, ZLE_WASTE,         &
                     ZF_WASTE_CAN, ZHVAC_COOL, ZHVAC_HEAT, ZQIN, ZQIN_FRAD,   &
                     ZQIN_FLAT, ZGR, ZEFF_HEAT, ZINF,                         &
                     ZTCOOL_TARGET, ZTHEAT_TARGET, ZHR_TARGET, ZT_WIN2,       &
                     ZQI_BLD, ZV_VENT, ZCAP_SYS_HEAT, ZCAP_SYS_RAT, ZT_ADP,   &
                     ZM_SYS_RAT, ZCOP_RAT, ZCAP_SYS, ZM_SYS, ZCOP, ZQ_SYS,    &
                     ZT_SYS, ZTR_SW_WIN, ZFAN_POWER, ZHC_FLOOR, ZTC_FLOOR,    &
                     ZD_FLOOR, ZT_WIN1, ZABS_SW_WIN, ZABS_LW_WIN, ZSHGC,      &
                     ZSHGC_SH, ZUGG_WIN, ZALB_WIN, ZABS_WIN, ZEMIT_LW_FAC,    &
                     ZEMIT_LW_GRND, ZT_RAD_IND, ZREF_SW_GRND, ZREF_SW_FAC,    &
                     ZHU_BLD, ZTIME_BEG, LSHADE, ZSHADE, GSHAD_DAY,           &
                     GNATVENT_NIGHT,                                          &
                     CBEM,                                                    &
                     ZN_FLOOR, ZWALL_O_BLD, ZGLAZ_O_BLD, ZMASS_O_BLD,         &
                     ZFLOOR_HW_RATIO, ZF_FLOOR_MASS, ZF_FLOOR_WALL,           &
                     ZF_FLOOR_WIN, ZF_FLOOR_ROOF, ZF_WALL_FLOOR, ZF_WALL_MASS,&
                     ZF_WALL_WIN, ZF_WIN_FLOOR, ZF_WIN_MASS, ZF_WIN_WALL,     &
                     ZF_MASS_FLOOR, ZF_MASS_WALL, ZF_MASS_WIN, LCANOPY,       &
                     ZTRAN_WIN, CCH_BEM, ZROUGH_ROOF, ZROUGH_WALL, ZF_WIN_WIN,&
                     LPAR_RD_IRRIG, ZRD_START_MONTH, ZRD_END_MONTH,           &
                     ZRD_START_HOUR, ZRD_END_HOUR, ZRD_24H_IRRIG, ZIRRIG_ROAD,&
                     ZEMIS_PANEL, ZALB_PANEL, ZEFF_PANEL, ZFRAC_PANEL,        &
                     ZRESIDENTIAL,                                            &
                     ZTHER_PROD_PANEL, ZPHOT_PROD_PANEL, ZPROD_PANEL,         &
                     ZTHER_PROD_BLD  , ZPHOT_PROD_BLD  , ZPROD_BLD  ,         &
                     ZTHER_PRODC_DAY, ZH_PANEL, ZRN_PANEL,                    &
                     ZDT_RES, ZDT_OFF,                                        &
                     ZCUR_TCOOL_TARGET, ZCUR_THEAT_TARGET, ZCUR_QIN ,         &
					 ZDN_RF, ZDN_RD, ZMELT_BLT, ZSNOWD_RF, ZSNOWD_RD, ZLW_UP, &
					 ZALB_GR_EXT, ZEMIS_GR_EXT, ZTSRAD_GR_EXT, ZH_GR_EXT, ZLE_GR_EXT, ZEVAP_GR_EXT,   &
					 ZRUNOFF_GR_EXT, ZALB_GD_EXT, ZEMIS_GD_EXT, ZTSRAD_GD_EXT, ZQV_GD_EXT, ZH_GD_EXT, &
					 ZLE_GD_EXT, ZEVAP_GD_EXT, ZCH_GD, ZCD_GD, ZRUNOFF_GD_EXT, ZCH_RD,    &
					 ZCH_RF, ZCH_WL, ZCH_TOP, ZAC_TOP, ZILMO_ROAD, ZILMO_ROOF,&
                     ZILMO_TOP, ZCD_TERRA, ZCH_TERRA, ZZDU			 )
!*****************************************************************************
!*****************************************************************************
!*****************************************************************************
!*****************************************************************************
!

IF (ntstep == 1) THEN
	ZTS_TOWN_S_NOW = ZTS_TOWN
END IF

ZQS_TOWN_S    = ZQA_KGKG * ZEXNS / ZEXNA + ZLE_TOWN / (XRHOA * XLVTT * ZCH_TOWN * ZVMOD)

ZWS_TOWN      = (ZWS_ROOF * ZBLD + ZWS_ROAD * ZROAD) * 0.001
!ZRUNOFF_TOWN  = ZRUNOFF_TOWN * dt

ZTSSNOW_TOWN  = (ZTSSNOW_ROOF * ZBLD * ZDN_RF + ZTSSNOW_ROAD * ZROAD * ZDN_RD) / (ZBLD + ZROAD)
ZWSNOW_TOWN   = (ZWSNOW_ROOF(1,1) * ZBLD * ZDN_RF + ZWSNOW_ROAD(1,1) * ZROAD * ZDN_RD) / (ZBLD + ZROAD) * 0.001
ZRSNOW_TOWN   = (ZRSNOW_ROOF(1,1) * ZBLD * ZDN_RF + ZRSNOW_ROAD(1,1) * ZROAD * ZDN_RD) / (ZBLD + ZROAD)
ZHSNOW_TOWN   = (ZHSNOW_ROOF * ZBLD * ZDN_RF + ZHSNOW_ROAD * ZROAD * ZDN_RD) / (ZBLD + ZROAD)
ZLESNOW_TOWN  = (ZLESNOW_ROOF * ZBLD * ZDN_RF + ZLESNOW_ROAD * ZROAD * ZDN_RD) / (ZBLD + ZROAD)
ZDN_TOWN      = (ZDN_RF * ZBLD + ZDN_RD * ZROAD) / (ZBLD + ZROAD)
ZMELT_BLT_SUM = ZMELT_BLT * dt
ZSNOWD_TOWN   = (ZSNOWD_RF * ZBLD * ZDN_RF + ZSNOWD_RD * ZROAD * ZDN_RD) / (ZBLD + ZROAD)


!Town area-averaged albedo 
!Albedo of Green garden and Green roofs is manualy added: 0.15. Fix later!
ZALB_AVE_TWN = ZBLD * (1.- ZFRAC_GR) * (1-ZDN_RF) * ZALB_ROOF * (1.-ZFRAC_PANEL)                    &
                  + ZBLD * (1.-ZFRAC_GR) * ZDN_RF * ZASNOW_ROOF * (1.-ZFRAC_PANEL)                  &
                  + ZBLD *     ZFRAC_GR               * ZALB_GR_EXT * (1.-ZFRAC_PANEL)                     &
                  + ZBLD * ZALB_PANEL *      ZFRAC_PANEL                                            &
                  + ZROAD * ( ZSVF_ROAD * (1-ZDN_RD) * ZALB_ROAD                                    &
                  + ZSVF_ROAD * ZDN_RD * ZASNOW_ROAD)                                               &
                  + ZGARDEN *    ZSVF_GARDEN * 0.15                                                 &
                  + ZWALL_O_HOR *    ZSVF_WALL         * ZALB_WALL


ZTH_ALB_TOWN = 1 - ZEMIS_TOWN
!  Instantaneous diagnostics
ZTS_ROOF = ZT_ROOF(1,1)
ZTS_ROAD = ZT_ROAD(1,1)
ZTS_WALL_A = ZT_WALL_A(1,1)
ZTS_WALL_B = ZT_WALL_B(1,1)

ZH_ROOF_FR = ZH_ROOF*ZBLD
ZH_ROAD_FR = ZH_ROAD*ZROAD
ZH_WALL_FR = ZH_WALL_A*ZWALL_O_HOR

DELTA_TROOF = ZTS_ROOF/ZEXNS - XTA/ZEXNA
DELTA_TROAD = ZTS_ROAD - ZT_CANYON
DELTA_TWALL = ZTS_WALL_A - ZT_CANYON

! Calculate Shortwave and Longwave Surface Balance
! Forcing for TERRA to use Garden
ZABS_SW_GRND = ZROAD /(ZROAD + ZGARDEN) * ZABS_SW_ROAD + ZGARDEN /(ZROAD + ZGARDEN) * ZABS_SW_GARDEN
ZABS_LW_GRND = ZROAD /(ZROAD + ZGARDEN) * ZABS_LW_ROAD + ZGARDEN /(ZROAD + ZGARDEN) * ZABS_LW_GARDEN

ZILMO_TOP = -(ZUSTAR_TOWN**3 * XTA) / (XKARMAN * XG * ZH_TOWN / (XCPD * XRHOA))

IF (ZILMO_TOP(1) < 0.) THEN
	ZILMO_TOP = MIN(-ZBLD_HEIGHT / 150., ZILMO_TOP)
ELSE
	ZILMO_TOP = MAX(ZBLD_HEIGHT / 150., ZILMO_TOP)
ENDIF

! --------------------------------------------------------------------------------------

DEALLOCATE(ZHC_WALL) 
DEALLOCATE(ZTC_WALL) 
DEALLOCATE(ZD_WALL)
!DEALLOCATE(ZT_WALL_A) 
!DEALLOCATE(ZT_WALL_B) 
DEALLOCATE(ZHC_ROOF) 
DEALLOCATE(ZTC_ROOF) 
DEALLOCATE(ZD_ROOF)
!DEALLOCATE(ZT_ROOF) 
DEALLOCATE(ZHC_ROAD) 
DEALLOCATE(ZTC_ROAD) 
DEALLOCATE(ZD_ROAD) 
!DEALLOCATE(ZT_ROAD) 
DEALLOCATE(ZHC_FLOOR) 
DEALLOCATE(ZTC_FLOOR) 
DEALLOCATE(ZD_FLOOR)

! --------------------------------------------------------------------------------------
!
!MV202609 z0 and zd to namelist
CONTAINS

!MV202609 z0 and zd to namelist
SUBROUTINE URB_AERO_PARAMS(CZ0, CZD, PBLD_HEIGHT, PBLD_FRAC, PFAI, PZ0, PZD)
! Aerodynamic parameters of the urban surface: z0 of the town and the
! displacement height zd. Both are defined by the namelist entries
! (urb_z0_town, urb_zd_town), each of them accepting (case insensitive):
!   0.5 | 0.5m  - value in metres
!   0.1H        - fraction of the building height
!   H/3         - building height divided by n
!   <name>      - a named parameterization (see URB_AERO_SCHEME_Z0 and
!                 URB_AERO_SCHEME_ZD: MACDONALD1998, MACDONALD1998SQ)
! The two entries are resolved independently, so that zd can be taken from a
! parameterization ('MACDONALD1998') while z0 is given explicitly ('0.1H'),
! and vice versa.
CHARACTER(LEN=*),    INTENT(IN)  :: CZ0, CZD      ! namelist entries
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_HEIGHT   ! building height (m)
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_FRAC    ! plan area index (-)
REAL, DIMENSION(:,:),INTENT(IN)  :: PFAI          ! frontal area index (8 dir.)
REAL, DIMENSION(:),  INTENT(OUT) :: PZ0, PZD      ! resulting z0 and zd (m)

!MV202609 z0 and zd to namelist
LOGICAL           :: LSCHEME_Z0, LSCHEME_ZD
INTEGER           :: KERR
CHARACTER(LEN=16) :: CSCHEME_Z0, CSCHEME_ZD

!MV202609 z0 and zd to namelist
! z0: explicit value or a parameterization name
CALL URB_AERO_ONE(CZ0, PBLD_HEIGHT, PZ0, LSCHEME_Z0, CSCHEME_Z0)
IF (LSCHEME_Z0) THEN
  CALL URB_AERO_SCHEME_Z0(CSCHEME_Z0, PBLD_HEIGHT, PBLD_FRAC, PFAI, PZ0, KERR)
  IF (KERR /= 0) CALL URB_AERO_STOP('urb_z0_town', CZ0, CZD)
ENDIF

!MV202609 z0 and zd to namelist
! zd: explicit value or a parameterization name
CALL URB_AERO_ONE(CZD, PBLD_HEIGHT, PZD, LSCHEME_ZD, CSCHEME_ZD)
IF (LSCHEME_ZD) THEN
  CALL URB_AERO_SCHEME_ZD(CSCHEME_ZD, PBLD_HEIGHT, PBLD_FRAC, PZD, KERR)
  IF (KERR /= 0) CALL URB_AERO_STOP('urb_zd_town', CZ0, CZD)
ENDIF
END SUBROUTINE URB_AERO_PARAMS

!MV202609 z0 and zd to namelist
SUBROUTINE URB_AERO_STOP(CNAME, CZ0, CZD)
! Stops the run with a message about an unknown value or parameterization name
CHARACTER(LEN=*), INTENT(IN) :: CNAME             ! offending namelist entry
CHARACTER(LEN=*), INTENT(IN) :: CZ0, CZD          ! both namelist entries

WRITE(*,*) 'ERROR in CALL_DRIVER: cannot interpret the namelist entry '//TRIM(CNAME)
WRITE(*,*) '   urb_z0_town = ', TRIM(CZ0)
WRITE(*,*) '   urb_zd_town = ', TRIM(CZD)
WRITE(*,*) '   accepted forms: <value> (m), <value>m, <value>H, H/<n>'
WRITE(*,*) '   named parameterizations: MACDONALD1998, MACDONALD1998SQ'
STOP
END SUBROUTINE URB_AERO_STOP

!MV202609 z0 and zd to namelist
SUBROUTINE URB_AERO_ONE(CVALUE, PBLD_HEIGHT, PVALUE, LSCHEME, CSCHEME)
! Parses one namelist entry of an urban aerodynamic length (see URB_AERO_PARAMS).
! If the entry is not a number, it is returned as a parameterization name.
CHARACTER(LEN=*),    INTENT(IN)  :: CVALUE       ! namelist entry
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_HEIGHT  ! building height (m)
REAL, DIMENSION(:),  INTENT(OUT) :: PVALUE       ! resulting length (m)
LOGICAL,             INTENT(OUT) :: LSCHEME      ! true if CVALUE is a scheme name
CHARACTER(LEN=16),   INTENT(OUT) :: CSCHEME      ! scheme name (upper case)

INTEGER           :: IJ, ILEN, IOS, ICHR
REAL              :: ZPVAL
CHARACTER(LEN=16) :: YSTR, YNUM

YSTR = ADJUSTL(CVALUE)
ILEN = LEN_TRIM(YSTR)
DO IJ = 1, ILEN
  ICHR = ICHAR(YSTR(IJ:IJ))
  IF (ICHR >= ICHAR('a') .AND. ICHR <= ICHAR('z')) YSTR(IJ:IJ) = CHAR(ICHR - 32)
ENDDO

LSCHEME = .FALSE.
CSCHEME = ' '
IF (ILEN == 0) THEN
  LSCHEME = .TRUE.
  RETURN
ENDIF

! 'H/<n>' - building height divided by n
IF (ILEN > 2) THEN
  IF (YSTR(1:2) == 'H/') THEN
    YNUM = YSTR(3:ILEN)
    READ(YNUM,*,IOSTAT=IOS) ZPVAL
    IF (IOS == 0 .AND. ZPVAL /= 0.) THEN
      PVALUE = PBLD_HEIGHT / ZPVAL
      RETURN
    ENDIF
  ENDIF
ENDIF

! '<value>H' - fraction of the building height
IF (ILEN > 1) THEN
  IF (YSTR(ILEN:ILEN) == 'H') THEN
    YNUM = YSTR(1:ILEN-1)
    READ(YNUM,*,IOSTAT=IOS) ZPVAL
    IF (IOS == 0) THEN
      PVALUE = ZPVAL * PBLD_HEIGHT
      RETURN
    ENDIF
  ENDIF
ENDIF

! '<value>m' - value in metres
IF (ILEN > 1) THEN
  IF (YSTR(ILEN:ILEN) == 'M') THEN
    YNUM = YSTR(1:ILEN-1)
    READ(YNUM,*,IOSTAT=IOS) ZPVAL
    IF (IOS == 0) THEN
      PVALUE = ZPVAL
      RETURN
    ENDIF
  ENDIF
ENDIF

! '<value>' - value in metres
YNUM = YSTR(1:ILEN)
READ(YNUM,*,IOSTAT=IOS) ZPVAL
IF (IOS == 0) THEN
  PVALUE = ZPVAL
  RETURN
ENDIF

! otherwise: a parameterization name
LSCHEME = .TRUE.
CSCHEME = YSTR
END SUBROUTINE URB_AERO_ONE

!MV202609 z0 and zd to namelist
SUBROUTINE URB_AERO_SCHEME_Z0(CSCHEME, PBLD_HEIGHT, PBLD_FRAC, PFAI, PZ0, KERR)
! Roughness length z0 from a named parameterization. It uses the building
! height, the plan area index and the frontal area index. Available schemes:
!   'MACDONALD1998'   - Macdonald et al. (1998), staggered arrays
!   'MACDONALD1998SQ' - Macdonald et al. (1998), square arrays
CHARACTER(LEN=*),    INTENT(IN)  :: CSCHEME
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_HEIGHT
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_FRAC
REAL, DIMENSION(:,:),INTENT(IN)  :: PFAI
REAL, DIMENSION(:),  INTENT(OUT) :: PZ0
INTEGER,             INTENT(OUT) :: KERR

!MV202609 z0 and zd to namelist
REAL              :: ZLAMBDA_P, ZLAMBDA_F
CHARACTER(LEN=16) :: CWHERE

KERR = 1
PZ0(:) = 0.

!MV202609 z0 and zd to namelist
! plan area index (building fraction) and frontal area index (mean over the
! 8 wind directions, i.e. the isotropic variant)
ZLAMBDA_P = SUM(PBLD_FRAC) / REAL(SIZE(PBLD_FRAC))
ZLAMBDA_F = SUM(PFAI)      / REAL(SIZE(PFAI))

!MV202609 z0 and zd to namelist
SELECT CASE (TRIM(CSCHEME))
CASE ('MACDONALD1998', 'MACDONALD', 'MACDONALD98')
  CWHERE = 'STAG'
CASE ('MACDONALD1998SQ', 'MACDONALD98SQ')
  CWHERE = 'SQUARE'
CASE DEFAULT
  CWHERE = ' '
END SELECT

!MV202609 z0 and zd to namelist
IF (CWHERE /= ' ') THEN
  PZ0 = URB_Z0_MACDONALD(PBLD_HEIGHT, ZLAMBDA_P, ZLAMBDA_F, CWHERE)
  KERR = 0
ENDIF
END SUBROUTINE URB_AERO_SCHEME_Z0

!MV202609 z0 and zd to namelist
SUBROUTINE URB_AERO_SCHEME_ZD(CSCHEME, PBLD_HEIGHT, PBLD_FRAC, PZD, KERR)
! Displacement height zd from a named parameterization. It uses the building
! height and the plan area index. Available schemes:
!   'MACDONALD1998'   - Macdonald et al. (1998), staggered arrays
!   'MACDONALD1998SQ' - Macdonald et al. (1998), square arrays
CHARACTER(LEN=*),    INTENT(IN)  :: CSCHEME
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_HEIGHT
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_FRAC
REAL, DIMENSION(:),  INTENT(OUT) :: PZD
INTEGER,             INTENT(OUT) :: KERR

!MV202609 z0 and zd to namelist
REAL              :: ZLAMBDA_P
CHARACTER(LEN=16) :: CWHERE

KERR = 1
PZD(:) = 0.

!MV202609 z0 and zd to namelist
! plan area index (building fraction)
ZLAMBDA_P = SUM(PBLD_FRAC) / REAL(SIZE(PBLD_FRAC))

!MV202609 z0 and zd to namelist
SELECT CASE (TRIM(CSCHEME))
CASE ('MACDONALD1998', 'MACDONALD', 'MACDONALD98')
  CWHERE = 'STAG'
CASE ('MACDONALD1998SQ', 'MACDONALD98SQ')
  CWHERE = 'SQUARE'
CASE DEFAULT
  CWHERE = ' '
END SELECT

!MV202609 z0 and zd to namelist
IF (CWHERE /= ' ') THEN
  PZD = URB_ZD_MACDONALD(PBLD_HEIGHT, ZLAMBDA_P, CWHERE)
  KERR = 0
ENDIF
END SUBROUTINE URB_AERO_SCHEME_ZD

!MV202609 z0 and zd to namelist
FUNCTION URB_ZD_MACDONALD(PBLD_HEIGHT, PLAMBDA_P, CWHERE) RESULT(PZD)
! Displacement height after Macdonald et al. (1998), eq. (23):
!   d/H = 1 + A^(-lambda_p) * (lambda_p - 1)
! with A = 4.43 for staggered arrays and A = 3.59 for square arrays.
! DOI 10.1016/S1352-2310(97)00403-2
REAL, DIMENSION(:), INTENT(IN) :: PBLD_HEIGHT     ! building height (m)
REAL,             INTENT(IN)   :: PLAMBDA_P       ! plan area index (-)
CHARACTER(LEN=*), INTENT(IN)   :: CWHERE          ! 'STAG' or 'SQUARE'
REAL, DIMENSION(SIZE(PBLD_HEIGHT)) :: PZD

!MV202609 z0 and zd to namelist
REAL :: ZA

ZA = 4.43
IF (TRIM(CWHERE) == 'SQUARE') ZA = 3.59

!MV202609 z0 and zd to namelist
! degenerate cases: no buildings, or a fully built-up surface
IF (PLAMBDA_P <= 0.) THEN
  PZD(:) = 0.
  RETURN
ENDIF
IF (PLAMBDA_P >= 1.) THEN
  PZD(:) = PBLD_HEIGHT
  RETURN
ENDIF

!MV202609 z0 and zd to namelist
PZD = PBLD_HEIGHT * (1. + ZA**(-PLAMBDA_P) * (PLAMBDA_P - 1.))
END FUNCTION URB_ZD_MACDONALD

!MV202609 z0 and zd to namelist
FUNCTION URB_Z0_MACDONALD(PBLD_HEIGHT, PLAMBDA_P, PLAMBDA_F, CWHERE) RESULT(PZ0)
! Roughness length after Macdonald et al. (1998), eq. (22):
!   z0/H = (1 - d/H) * exp( -( 0.5*beta*(Cd/kappa**2)*(1 - d/H)*lambda_f )**(-0.5) )
! with Cd = 1.2, kappa = 0.4 (von Karman) and beta = 1.0 for staggered arrays
! or beta = 0.55 for square arrays.
! DOI 10.1016/S1352-2310(97)00403-2
REAL, DIMENSION(:), INTENT(IN) :: PBLD_HEIGHT     ! building height (m)
REAL,             INTENT(IN)   :: PLAMBDA_P       ! plan area index (-)
REAL,             INTENT(IN)   :: PLAMBDA_F       ! frontal area index (-)
CHARACTER(LEN=*), INTENT(IN)   :: CWHERE          ! 'STAG' or 'SQUARE'
REAL, DIMENSION(SIZE(PBLD_HEIGHT)) :: PZ0

!MV202609 z0 and zd to namelist
REAL :: ZBETA, ZCD, ZKAPPA, ZLAMBDA
REAL, DIMENSION(SIZE(PBLD_HEIGHT)) :: ZD, ZONE_MINUS_D, ZINNER

ZBETA  = 1.0
IF (TRIM(CWHERE) == 'SQUARE') ZBETA = 0.55
ZCD    = 1.2
ZKAPPA = XKARMAN

!MV202609 z0 and zd to namelist
! degenerate cases: no buildings or no frontal area -> smooth surface
IF (PLAMBDA_P <= 0. .OR. PLAMBDA_F <= 0.) THEN
  PZ0(:) = 1.E-3
  RETURN
ENDIF
ZLAMBDA = MIN(PLAMBDA_P, 0.999)

!MV202609 z0 and zd to namelist
! displacement height and the factor (1 - d/H)
ZD           = URB_ZD_MACDONALD(PBLD_HEIGHT, ZLAMBDA, CWHERE)
ZONE_MINUS_D = 1. - ZD / PBLD_HEIGHT
IF (MINVAL(ZONE_MINUS_D) <= 0.) THEN
  PZ0(:) = 1.E-3
  RETURN
ENDIF

!MV202609 z0 and zd to namelist
! inner expression of eq. (22)
ZINNER = 0.5 * ZBETA * (ZCD / ZKAPPA**2) * ZONE_MINUS_D * PLAMBDA_F
IF (MINVAL(ZINNER) <= 0.) THEN
  PZ0(:) = 1.E-3
  RETURN
ENDIF

!MV202609 z0 and zd to namelist
PZ0 = PBLD_HEIGHT * ZONE_MINUS_D * EXP(-(ZINNER**(-0.5)))
END FUNCTION URB_Z0_MACDONALD

! --------------------------------------------------------------------------------------
!
END SUBROUTINE CALL_DRIVER
