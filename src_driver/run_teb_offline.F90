PROGRAM run_teb_offline

USE sfc_teb,        ONLY : teb_interface
USE MODI_OL_READ_ATM
USE MODI_OL_TIME_INTERP_ATM
USE MODD_SURF_PAR, ONLY: XUNDEF
USE MODD_CSTS,     ONLY : XCPD, XSTEFAN, XPI, XDAY, XKARMAN,   &
                          XLVTT, XLSTT, XLMTT, XRV, XRD, XG, XP00
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

IMPLICIT NONE

! Program arguments
INTEGER :: num_args
CHARACTER(LEN=100) :: arg1, arg2
LOGICAL :: arg1_exists, arg2_exists

INTEGER :: nsteps                            !IN Number of timesteps
INTEGER :: JSURF_STEP                        ! Driver loop index
INTEGER :: INB_ATM                           ! number time the driver calls the TEB
!                                            ! routines during a forcing time-step
!                                            ! --> it defines the time-step for TEB
INTEGER :: nstep                             !IN timestep 
INTEGER, PARAMETER :: nvec = 1               !IN array dimensions
INTEGER :: ivstart                           !IN optional start index                  
INTEGER :: ivend                             !IN optional end   index                  
INTEGER :: iblock                            !IN number of block             

INTEGER :: teb_year                          !IN Current year (UTC)
INTEGER :: teb_month                         !IN Current month (UTC)
INTEGER :: teb_day                           !IN Current day (UTC)
INTEGER :: teb_hour                          !IN Current hour (UTC)
INTEGER :: teb_min                           !IN Current minute (UTC)
INTEGER :: teb_sec                           !IN Current seconds (UTC)
REAL,DIMENSION(1) :: teb_hour_seconds        !IN Current duration since start of the run(s)

REAL ,DIMENSION(nvec) :: lon_teb             !IN Longitude (deg)				
REAL ,DIMENSION(nvec) :: lat_teb             !IN Latitude (deg)
REAL ,DIMENSION(nvec) :: hlev_teb            !IN Atm. Forcing height above roof level
REAL ,DIMENSION(nvec) :: sa_uc               !IN fraction of urban area (need for AHF_TRAFFIC calculation)   
REAL                  :: dt                  !IN integration timestep (model)
REAL                  :: forc_step           !IN Forcing time-step (s)

! Input forcing
REAL,DIMENSION(nvec) :: u              !IN zonal wind speed
REAL,DIMENSION(nvec) :: v              !IN meridional wind speed 
REAL,DIMENSION(nvec) :: t              !IN temperature                            (  K  )
REAL,DIMENSION(nvec) :: qv             !IN specific water vapor content           (kg/kg)
REAL,DIMENSION(nvec) :: ps             !IN surface pressure                       ( Pa  )
REAL,DIMENSION(nvec) :: rho            !IN air density                            ( kg/m3  )
REAL,DIMENSION(nvec) :: prr_con        !IN precipitation rate of rain, convective       (kg/m2*s)
REAL,DIMENSION(nvec) :: prs_con        !IN precipitation rate of snow, convective       (kg/m2*s)
REAL,DIMENSION(nvec) :: prr_gsp        !IN precipitation rate of rain, grid-scale       (kg/m2*s)
REAL,DIMENSION(nvec) :: prs_gsp        !IN precipitation rate of snow, grid-scale       (kg/m2*s)
REAL,DIMENSION(nvec) :: prg_gsp        !IN precipitation rate of graupel, grid-scale    (kg/m2*s)
REAL,DIMENSION(nvec) :: lwd_s          !IN downward comp. of long  wave rad. flux
REAL,DIMENSION(nvec) :: swdir_s        !IN direct comp. of solar radiative flux at surface 
REAL,DIMENSION(nvec) :: swdifd_s       !IN diffuse downward comp. of short wave rad. flux

! Input urban parameters
INTEGER, PARAMETER :: teb_nwall_layer                = 5 !IN number of wall layers      
INTEGER, PARAMETER :: teb_nroof_layer                = 5 !IN number of roof layers                           
INTEGER, PARAMETER :: teb_nroad_layer                = 5 !IN number of road layers                   
INTEGER, PARAMETER :: teb_nfloor_layer               = 5 !IN number of floor layers      
REAL ,DIMENSION(nvec) :: urb_fr_bld                     !IN Building area fraction with respect to urban tile    (  -  )
REAL ,DIMENSION(nvec) :: fr_garden                      !IN Garden area fraction with respect to urban tile    (  -  )
REAL ,DIMENSION(nvec) :: urb_h2w                        !IN Street canyon H/W ratio   ( m/m )
REAL ,DIMENSION(nvec) :: urb_h_bld                      !IN Building height  (  m  )
!MV202609 z0 and zd to namelist
CHARACTER(LEN=16)     :: urb_z0_town                    !IN z0 of the urban surface (0.5 | 0.5m | 0.1H | H/3 | <name>)
CHARACTER(LEN=16)     :: urb_zd_town                    !IN displacement height    (same forms as urb_z0_town)
CHARACTER(LEN=4)      :: teb_hroad_dir                  !IN road direction option :                      
                                                        ! 'UNIF' : uniform roads                       
                                                        ! 'ORIE' : specified road orientation          
CHARACTER(LEN=4)      :: teb_wall_opt                   !IN Wall option                                  
                                                        ! 'UNIF' : uniform walls                       
									                    ! 'TWO ' : 2 opposite  walls
REAL,DIMENSION(nvec)  :: teb_road_dir                   !IN road direction (° from North, clockwise)													   
REAL ,DIMENSION(nvec) :: urb_hcap_rd                    !IN Volumetric heat capacity of road material (Jm-3K-1)
REAL ,DIMENSION(nvec) :: urb_hcap_rf                    !IN Volumetric heat capacity of roof material (Jm-3K-1)
REAL ,DIMENSION(nvec) :: urb_hcap_wl                    !IN Volumetric heat capacity of wall material (Jm-3K-1)
REAL ,DIMENSION(nvec) :: urb_hcon_rd                    !IN heat conductivity of road material
REAL ,DIMENSION(nvec) :: urb_hcon_rf                    !IN heat conductivity of roof material
REAL ,DIMENSION(nvec) :: urb_hcon_wl                    !IN heat conductivity of wall material
REAL ,DIMENSION(nvec) :: urb_alb_rd_so                  !IN road material solar albedo
REAL ,DIMENSION(nvec) :: urb_alb_rf_so                  !IN roof material solar albedo
REAL ,DIMENSION(nvec) :: urb_alb_wl_so                  !IN wall material solar albedo
REAL ,DIMENSION(nvec) :: urb_alb_rd_th                  !IN road material thermal albedo
REAL ,DIMENSION(nvec) :: urb_alb_rf_th                  !IN roof material thermal albedo
REAL ,DIMENSION(nvec) :: urb_alb_wl_th                  !IN wall material thermal albedo
REAL ,DIMENSION(nvec) :: ahf_traffic                    !IN Anthropogenic heat flux by traffic (annual mean)
REAL ,DIMENSION(nvec) :: ahf_industry                   !IN Anthropogenic heat flux by industry (annual mean)
INTEGER               :: teb_utc_hour                   !IN Time zone for traffic daily cycle calculation                  
	
! Input parameters for BEM 
CHARACTER(LEN=3)  :: teb_itype_bem                      !IN Building Energy model 'DEF' or 'BEM'       
LOGICAL           :: teb_lbem_ac                        !IN Flag to use air conditioners
LOGICAL           :: teb_lshade                         !IN Flag to use window shading

CHARACTER(LEN=4)  :: teb_itype_natvent                  !IN Natural ventilation 'NONE', 'AUTO', 'MECH', 'MANU'
CHARACTER(LEN=6)  :: teb_itype_bem_cool                 !IN option for cooling device type 'DXCOIL','IDEAL '
CHARACTER(LEN=6)  :: teb_itype_bem_heat                 !IN option for heating device type 'FINCAP','IDEAL '
REAL ,DIMENSION(nvec) :: teb_frac_gz                    !IN Glazing ratio   
REAL ,DIMENSION(nvec) :: teb_tcool_target               !IN Cooling setpoint of HVAC system [K]        
REAL ,DIMENSION(nvec) :: teb_theat_target               !IN Heating setpoint of HVAC system [K]
REAL ,DIMENSION(nvec) :: teb_bem_vent                   !IN Ventilation flow rate [AC/H]
REAL ,DIMENSION(nvec) :: teb_bem_inf                    !IN Infiltration flow rate [AC/H]
REAL ,DIMENSION(nvec) :: teb_bem_cop                    !IN Rated COP of the cooling system
REAL, DIMENSION(nvec) :: teb_zresidential               !IN Fraction of residential use in buildings(-)
REAL, DIMENSION(nvec) :: teb_dt_res                     !IN target temperature change when unoccupied (K) (residential buildings)                
REAL, DIMENSION(nvec) :: teb_dt_off                     !IN target temperature change when unoccupied (K) (office buildings)                     
REAL, DIMENSION(nvec) :: teb_cap_sys_heat               !IN Capacity of the heating system [W m-2(bld)]

! Input parameters for Wind calculation
INTEGER  :: teb_itype_wind                              !IN TEB option for camyon wond calculation:
													    ! 0 - default; 1 - Wang scheme
REAL ,DIMENSION(nvec, 1:8) :: teb_fai                   !IN Frontal area index                 
!
!MV202609 tau scheme of the road
! Input parameters for the tau scheme of the road
LOGICAL  :: teb_ltau_scheme                             !IN Flag to use the tau scheme
REAL     :: teb_tau_hw_thresh                           !IN H/W giving tau = 0.5
REAL     :: teb_tau_hw_width                            !IN width of the tanh relaxation

! Input parameters for Greenroof from TERRA
LOGICAL  :: teb_lgreenroof                              !IN Flag to use a green roofs scheme
LOGICAL  :: teb_lgreenroof_ext                          !IN Flag to use external green roofs scheme
REAL ,DIMENSION(nvec) :: teb_frac_gr                    !IN fraction of greenroofs on roofs             
REAL ,DIMENSION(nvec) :: teb_alb_gr                     !IN green roof albedo
REAL ,DIMENSION(nvec) :: teb_emis_gr                    !IN green roof emissivity 
REAL ,DIMENSION(nvec) :: teb_ts_gr                      !IN greenroof radiative surface temp. (snow free)
REAL ,DIMENSION(nvec) :: teb_shfl_gr                    !IN sensible heat flux over greenroofs 
REAL ,DIMENSION(nvec) :: teb_lhfl_gr                    !IN latent heat flux over greenroofs 
REAL ,DIMENSION(nvec) :: teb_qvfl_gr                    !IN total evaporation over greenroofs (kg/m2/s)
REAL ,DIMENSION(nvec) :: teb_runoff_gr                  !IN greenroof surface runoff

! Input parameters for Garden from TERRA           
LOGICAL  :: teb_lgarden                                 !IN Flag to use a garden scheme
LOGICAL  :: teb_lgarden_ext                             !IN Flag to use external garden scheme
REAL ,DIMENSION(nvec) :: teb_z0_gd                      !IN garden roughness length
REAL ,DIMENSION(nvec) :: teb_alb_gd                     !IN garden albedo
REAL ,DIMENSION(nvec) :: teb_emis_gd                    !IN garden emissivity 
REAL ,DIMENSION(nvec) :: teb_ts_gd                      !IN garden radiative surface temp. (snow free)
REAL ,DIMENSION(nvec) :: teb_qs_gd                      !IN garden specific humidity
REAL ,DIMENSION(nvec) :: teb_shfl_gd                    !IN sensible heat flux over garden 
REAL ,DIMENSION(nvec) :: teb_lhfl_gd                    !IN latent heat flux over garden 
REAL ,DIMENSION(nvec) :: teb_qvfl_gd                    !IN total evaporation over garden (kg/m2/s)
REAL ,DIMENSION(nvec) :: teb_runoff_gd                  !IN garden surface runoff

! Input parameters for Solar Panels module           
LOGICAL  :: teb_lsolar_panel                            !IN Flag to use a solar panels on roofs
REAL ,DIMENSION(nvec) :: teb_fr_panel                   !IN fraction of solar panels on roofs

! Input parameters for Irrigation
LOGICAL               :: teb_lroad_irrig                !IN Flag for road watering
REAL, DIMENSION(nvec) :: teb_rd_irrig_start_m           !IN start month for watering of roads(included)
REAL, DIMENSION(nvec) :: teb_rd_irrig_end_m             !IN end   month for watering of roads(included)
REAL, DIMENSION(nvec) :: teb_rd_irrig_start_h           !IN start hour  for watering of roads(included)
REAL, DIMENSION(nvec) :: teb_rd_irrig_end_h             !IN end   hour  for watering of roads(excluded)
REAL, DIMENSION(nvec) :: teb_rd_irrig_sum               !IN 24h quantity of water used for road watering (liter/m2)               

! Input/Output semi-prognostic variables 
REAL ,DIMENSION(nvec) :: teb_tcanyon                    !INOUT air canyon temperature 
REAL ,DIMENSION(nvec) :: teb_qcanyon                    !INOUT canyon air humidity ratio

! Input/Output prognostic variables
REAL ,DIMENSION(nvec) :: teb_ti_bld                     !INOUT indoor air temperature   
REAL ,DIMENSION(nvec) :: teb_qi_bld                     !INOUT Indoor air specific humidity [kg kg-1]     
REAL ,DIMENSION(nvec, teb_nroof_layer)  :: teb_troof    !INOUT roof layers temperatures
REAL ,DIMENSION(nvec, teb_nroad_layer)  :: teb_troad_now!INOUT road layers temperatures at previous time-step       
REAL ,DIMENSION(nvec, teb_nroad_layer)  :: teb_troad    !INOUT road layers temperatures     
REAL ,DIMENSION(nvec, teb_nwall_layer)  :: teb_twalla   !INOUT wall layers temperatures (wall 'A') 
REAL ,DIMENSION(nvec, teb_nwall_layer)  :: teb_twallb   !INOUT wall layers temperatures (wall 'B') 
REAL ,DIMENSION(nvec, teb_nfloor_layer) :: teb_tfloor   !INOUT Floor layers temperatures [K] 
REAL ,DIMENSION(nvec, teb_nfloor_layer) :: teb_tmass    !INOUT Internal mass layers temperatures [K]  
REAL ,DIMENSION(nvec) :: teb_ws_roof                    !INOUT roof water content (kg/m2)    
REAL ,DIMENSION(nvec) :: teb_ws_road                    !INOUT road water content (kg/m2)    
REAL ,DIMENSION(nvec, 1) :: teb_wsnow_roof              !INOUT Initial Amount      of roof snow reservoir 
REAL ,DIMENSION(nvec, 1) :: teb_wsnow_road              !INOUT Initial amount      of road snow reservoir
REAL ,DIMENSION(nvec, 1) :: teb_tsnow_roof              !INOUT layer temperature   of roof snow
REAL ,DIMENSION(nvec, 1) :: teb_tsnow_road              !INOUT layer temperature   of road snow  
REAL ,DIMENSION(nvec, 1) :: teb_rsnow_roof              !INOUT density             of roof snow
REAL ,DIMENSION(nvec, 1) :: teb_rsnow_road              !INOUT density             of road snow
REAL ,DIMENSION(nvec) :: teb_tssnow_roof                !INOUT surface temperature of roof snow
REAL ,DIMENSION(nvec) :: teb_tssnow_road                !INOUT surface temperature of road snow
REAL ,DIMENSION(nvec) :: teb_asnow_roof                 !INOUT roof snow albedo 
REAL ,DIMENSION(nvec) :: teb_asnow_road                 !INOUT road snow albedo 
REAL ,DIMENSION(nvec) :: teb_esnow_roof                 !INOUT snow roof emissivity
REAL ,DIMENSION(nvec) :: teb_esnow_road                 !INOUT snow road emissivity
REAL ,DIMENSION(nvec) :: teb_twin1                      !INOUT outdoor window temperature [K] 
REAL ,DIMENSION(nvec) :: teb_twin2                      !INOUT Indoor window temperature [K] 
REAL ,DIMENSION(nvec) :: teb_albwin                     !INOUT window albedo
REAL ,DIMENSION(nvec) :: teb_cap_sys_rat                !INOUT Rated capacity of the cooling system [W m-2(floor)]                      
REAL ,DIMENSION(nvec) :: teb_m_sys_rat                  !INOUT Rated HVAC mass flow rate [kg s-1 m-2(bld)]
LOGICAL ,DIMENSION(nvec) :: teb_shad_day                !INOUT has shading been necessary this day ? 
LOGICAL ,DIMENSION(nvec) :: teb_natvent_night           !INOUT has natural ventilation been

! Output diagnostic variables
! For town
REAL ,DIMENSION(nvec) :: teb_shfl  		                !OUT sensible heat flux over town
REAL ,DIMENSION(nvec) :: teb_lhfl   	                !OUT latent heat flux over town   
REAL ,DIMENSION(nvec) :: teb_qvfl   	                !OUT evaporation (kg/m2/s)    
REAL ,DIMENSION(nvec) :: teb_gflux                      !OUT Flux through the ground for town  
REAL ,DIMENSION(nvec) :: teb_dqs_town                   !OUT Storage inside town materials  
REAL ,DIMENSION(nvec) :: teb_tch_town                   !OUT Heat exchange coefficient  
REAL ,DIMENSION(nvec) :: teb_tstown_s_now               !OUT town surface temperature from flux calculation at previous time-step 
REAL ,DIMENSION(nvec) :: teb_tstown_s                   !OUT town surface temperature from flux calculation
REAL ,DIMENSION(nvec) :: teb_qstown_s                   !OUT town surface specific humidity from flux calculation (kg/kg)
REAL ,DIMENSION(nvec) :: teb_wstown_now                 !OUT town water content (m H2O) at previous time-step    
REAL ,DIMENSION(nvec) :: teb_wstown                     !OUT town water content (m H2O)
REAL ,DIMENSION(nvec) :: teb_runoff_town                !OUT runoff for town
REAL ,DIMENSION(nvec) :: teb_alb_so                     !OUT town solar albedo  
REAL ,DIMENSION(nvec) :: teb_alb_th                     !OUT town thermal albedo
REAL ,DIMENSION(nvec) :: teb_wind_top                   !OUT Wind speed at canyon top (m/s)
REAL ,DIMENSION(nvec) :: teb_ucanyon                    !OUT u-wind component of wind inside the canyon    
REAL ,DIMENSION(nvec) :: teb_vcanyon                    !OUT v-wind component of wind inside the canyon   
REAL ,DIMENSION(nvec) :: teb_wind_canyon                !OUT Wind speed in canyon   
REAL ,DIMENSION(nvec) :: teb_rn_town                    !OUT Net radiation over town    

! For individual surfaces
REAL ,DIMENSION(nvec) :: teb_tsroof                     !OUT roof surface temperature   [K] 
REAL ,DIMENSION(nvec) :: teb_tsroad                     !OUT road surface temperature   [K] 
REAL ,DIMENSION(nvec) :: teb_tswalla                    !OUT wall 'A' surface temperature [K] 
REAL ,DIMENSION(nvec) :: teb_tswallb                    !OUT wall 'B' surface temperature [K]  
REAL ,DIMENSION(nvec) :: teb_shfl_rf                    !OUT Sensible heat flux over roof
REAL ,DIMENSION(nvec) :: teb_shfl_rd                    !OUT Sensible heat flux over road
REAL ,DIMENSION(nvec) :: teb_shfl_wl                    !OUT Sensible heat flux over wall
REAL ,DIMENSION(nvec) :: teb_tch_rd                     !OUT road transfer coefficient for heat
REAL ,DIMENSION(nvec) :: teb_tch_rf                     !OUT roof transfer coefficient for heat
REAL ,DIMENSION(nvec) :: teb_tch_wl                     !OUT wall transfer coefficient for heat
REAL ,DIMENSION(nvec) :: teb_tch_top                    !OUT between canyon top and atm. transfer coefficient for hea
REAL ,DIMENSION(nvec) :: teb_ac_rf                      !OUT Roof aerodynamical conductance
REAL ,DIMENSION(nvec) :: teb_ac_rd                      !OUT Road aerodynamical conductance
REAL ,DIMENSION(nvec) :: teb_ac_wl                      !OUT Wall aerodynamical conductance
REAL ,DIMENSION(nvec) :: teb_ac_top                     !OUT Canyon-atm. aerodynamical conductance

! Snow variables
REAL ,DIMENSION(nvec) :: teb_tssnow_town_now            !OUT town snow surface temperature (K) at previous time-step
REAL ,DIMENSION(nvec) :: teb_tssnow_town                !OUT town snow surface temperature (K)
REAL ,DIMENSION(nvec) :: teb_wsnow_town_now             !OUT town snow (& liq. water) content (m H2O) at previous time-step
REAL ,DIMENSION(nvec) :: teb_wsnow_town                 !OUT town snow (& liq. water) content (m H2O)
REAL ,DIMENSION(nvec) :: teb_rsnow_town_now             !OUT town snow layers density (kg/m3) at previous time-step
REAL ,DIMENSION(nvec) :: teb_rsnow_town                 !OUT town snow layers density (kg/m3)
REAL ,DIMENSION(nvec) :: teb_shfl_snow                  !OUT sensible heat flux over snow
REAL ,DIMENSION(nvec) :: teb_lhfl_snow                  !OUT latent heat flux over snow	
REAL ,DIMENSION(nvec) :: teb_frsnow                     !OUT snow fraction over town
REAL ,DIMENSION(nvec) :: teb_snow_melt                  !OUT Snow melt for built & impervious part (kg/m2)
REAL ,DIMENSION(nvec) :: teb_hsnow_town_now             !OUT town snow depth at previous time-step
REAL ,DIMENSION(nvec) :: teb_hsnow_town                 !OUT town snow depth

! BEM variables
REAL ,DIMENSION(nvec) :: teb_hwaste                     !OUT Sensible waste heat from HVAC system [W m-2(tot)]
!MV202609 anthropogenic heat diagnostics
REAL ,DIMENSION(nvec) :: teb_lewaste                    !OUT Latent waste heat of the buildings [W m-2(tot)] 
REAL ,DIMENSION(nvec) :: teb_hvac_cool                  !OUT Energy consumption of the cooling system [W m-2(bld)]  
REAL ,DIMENSION(nvec) :: teb_hvac_heat                  !OUT Energy consumption of the heating system [W m-2(bld)]  

!Variables for garden (COSMO)
REAL ,DIMENSION(nvec) :: teb_sobs                       !OUT Shortwave radiation absorbed by garden
REAL ,DIMENSION(nvec) :: teb_thbs                       !OUT Longwave radiation absorbed by garden
REAL ,DIMENSION(nvec) :: teb_tch_gd                     !OUT garden transfer coefficient for heat
REAL ,DIMENSION(nvec) :: teb_tcm_gd                     !OUT garden  surf. exchange coefficient

!Other variables
REAL ,DIMENSION(nvec) :: teb_ustar_town
REAL ,DIMENSION(nvec) :: teb_cd_garden_atm
REAL ,DIMENSION(nvec) :: teb_ch_garden_atm
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
REAL ,DIMENSION(nvec) :: PCD_ROAD_CAN     ! road   drag coefficient (canyon)
REAL ,DIMENSION(nvec) :: PCDN_ROAD_CAN    ! road   neutral drag coefficient (canyon)
REAL ,DIMENSION(nvec) :: PRI_ROAD_CAN     ! road   Richardson number (canyon)
REAL ,DIMENSION(nvec) :: ZZ0H_ROAD_CAN    ! road   roughness length for heat (canyon)
REAL ,DIMENSION(nvec) :: PAC_ROAD_ATM     ! road   aerodynamical conductance (atm.)
REAL ,DIMENSION(nvec) :: PCH_ROAD_ATM     ! road   drag coefficient for heat (atm.)
REAL ,DIMENSION(nvec) :: PCD_ROAD_ATM     ! road   drag coefficient (atm.)
REAL ,DIMENSION(nvec) :: PCDN_ROAD_ATM    ! road   neutral drag coefficient (atm.)
REAL ,DIMENSION(nvec) :: PRI_ROAD_ATM     ! road   Richardson number (atm.)
REAL ,DIMENSION(nvec) :: ZZ0H_ROAD_ATM    ! road   roughness length for heat (atm.)
REAL ,DIMENSION(nvec) :: PCDN_GARDEN_CAN  ! garden neutral drag coefficient (canyon)
REAL ,DIMENSION(nvec) :: PRI_GARDEN_CAN   ! garden Richardson number (canyon)
REAL ,DIMENSION(nvec) :: ZZ0H_GARDEN_CAN  ! garden roughness length for heat (canyon)
REAL ,DIMENSION(nvec) :: PAC_GARDEN_ATM   ! garden aerodynamical conductance (atm.)
REAL ,DIMENSION(nvec) :: PCDN_GARDEN_ATM  ! garden neutral drag coefficient (atm.)
REAL ,DIMENSION(nvec) :: PRI_GARDEN_ATM   ! garden Richardson number (atm.)
REAL ,DIMENSION(nvec) :: ZZ0H_GARDEN_ATM  ! garden roughness length for heat (atm.)
REAL ,DIMENSION(nvec) :: PH_ROAD_CAN      ! road sensible heat flux, road -> canyon air [W m-2]
REAL ,DIMENSION(nvec) :: PLE_ROAD_CAN     ! road latent heat flux, road -> canyon air [W m-2]
REAL ,DIMENSION(nvec) :: PH_ROAD_ATM      ! road sensible heat flux, road -> forcing level [W m-2]
REAL ,DIMENSION(nvec) :: PLE_ROAD_ATM      ! road latent heat flux, road -> forcing level [W m-2]
!MV202609 tau scheme of the road (revision: three-temperature construction)
REAL ,DIMENSION(nvec) :: PT_CAN0           ! canyon air temperature without tau [K]
REAL ,DIMENSION(nvec) :: PT_CAN1           ! free layer (second canopy) air temperature [K]
REAL ,DIMENSION(nvec) :: PPHI_CAN1         ! free layer air temperature / theta* ratio of the MOST profile [-]
!MV202609 tau scheme of the road
REAL ,DIMENSION(nvec) :: PH_ROAD          ! road sensible heat flux, tau scheme [W m-2]
REAL ,DIMENSION(nvec) :: PLE_ROAD         ! road latent heat flux, tau scheme [W m-2]
REAL ,DIMENSION(nvec) :: ahf_traffic_now                !OUT Anthropogenic heat flux by traffic (current value)
REAL ,DIMENSION(nvec) :: teb_solar_prod                 !OUT Averaged Energy production of solar panel on roofs (W/m2 bld  )
	

! Atmospheric Forcing variables                                                       
REAL, DIMENSION(:,:), ALLOCATABLE :: ZTA    ! air temperature forcing (K)             
REAL, DIMENSION(:,:), ALLOCATABLE :: ZQA    ! air humidity forcing (kg/m3)            
REAL, DIMENSION(:,:), ALLOCATABLE :: ZWIND  ! wind speed (m/s)                        
REAL, DIMENSION(:,:), ALLOCATABLE :: ZSCA_SW! diffuse solar radiation (on hor surf)   
REAL, DIMENSION(:,:), ALLOCATABLE :: ZDIR_SW! direct  solar radiation (on hor surf)   
REAL, DIMENSION(:,:), ALLOCATABLE :: ZLW    ! longwave radiation (on horizontal surf) 
REAL, DIMENSION(:,:), ALLOCATABLE :: ZSNOW  ! snow precipitation  (kg/m2/s)           
REAL, DIMENSION(:,:), ALLOCATABLE :: ZRAIN  ! liquid precipitation  (kg/m2/s)         
REAL, DIMENSION(:,:), ALLOCATABLE :: ZPS    ! pressure at forcing level  (Pa)         
!REAL, DIMENSION(:,:), ALLOCATABLE :: ZCO2   ! CO2 concentration in the air  (kg/m3)   
REAL, DIMENSION(:,:), ALLOCATABLE :: ZDIR   ! wind direction                          

! -----------------------------------------------------------                        
! Outputs                                                                            
! -----------------------------------------------------------                        
!    
CHARACTER(LEN=100) :: output_dir
! the output is written to a single CSV file with ';' separators
INTEGER, PARAMETER :: fu_out  = 13             ! unit of the output CSV file
INTEGER, PARAMETER :: nout_max = 128           ! max number of output columns (array bound of out_names)
INTEGER :: nout                                ! actual number of output columns
INTEGER :: jout                                ! column loop counter
INTEGER :: lout                                ! length of the current output line
CHARACTER(LEN=1),  PARAMETER :: out_sep = ';'  ! CSV field separator
CHARACTER(LEN=16), DIMENSION(nout_max) :: out_names  ! column headers (1:nout)
CHARACTER(LEN=100) :: output_csv               ! full path of the output CSV file
CHARACTER(LEN=4096) :: out_line                ! one CSV line (header or data row)
CHARACTER(LEN=32) :: time_buf                  ! timestamp buffer (ISO 8601)
REAL :: forc_wind                              ! forcing wind speed       (m/s)
REAL :: forc_dir                               ! forcing wind direction   (deg from North)
! -----------------------------------------------------------                        
! Namelist paths                                                                            
! -----------------------------------------------------------                                      
INTEGER                           :: fu, rc
CHARACTER(LEN=*), PARAMETER       :: namelist_path_default = 'namelist/namelist.nml'
CHARACTER(LEN=*), PARAMETER       :: namelist_forcing_path_default = 'namelist/namelist_forcing.nml'
CHARACTER(LEN=100)                :: namelist_path_local
CHARACTER(LEN=100)                :: namelist_forcing_path_local


CHARACTER(LEN=100)                :: forcing_path   ! Forcing filepath that we read from namelist
CHARACTER(:), allocatable         :: forcing_path2  ! Forcing filepath with adjusted length

INTEGER :: i  ! Loop counter for command line arguments

!===========================================================================
! NAMELIST declarations
!===========================================================================

NAMELIST /tebforcing/ forcing_path, lon_teb, lat_teb, hlev_teb, teb_year,          &
                      teb_month, teb_day, teb_hour, teb_min, nsteps, forc_step

NAMELIST /tebparam/ dt, urb_h_bld, urb_fr_bld, fr_garden, urb_h2w, teb_road_dir,           &
                    teb_hroad_dir, teb_wall_opt, teb_ti_bld, teb_qi_bld,               &
					urb_alb_rf_so, urb_alb_rf_th, urb_hcap_rf, urb_hcon_rf,            &
					urb_alb_rd_so, urb_alb_rd_th, urb_hcap_rd, urb_hcon_rd,            &
					urb_alb_wl_so, urb_alb_wl_th, urb_hcap_wl, urb_hcon_wl,            &
					teb_itype_bem, teb_lbem_ac, teb_itype_natvent, teb_itype_bem_cool, &
					teb_itype_bem_heat, teb_frac_gz, teb_tcool_target,                 &
					teb_theat_target, teb_zresidential, teb_dt_res, teb_dt_off,        &
                    teb_bem_inf, teb_bem_vent, teb_bem_cop, teb_cap_sys_rat,           &
                    teb_m_sys_rat, teb_cap_sys_heat, ahf_traffic, ahf_industry,        &
                    teb_itype_wind, teb_fai, teb_lgarden, teb_lgreenroof, teb_frac_gr, &
                    teb_lsolar_panel, teb_fr_panel, teb_lroad_irrig,                   &
                    teb_rd_irrig_start_m, teb_rd_irrig_end_m, teb_rd_irrig_start_h,    &
                    teb_rd_irrig_end_h, teb_rd_irrig_sum, teb_utc_hour, teb_lshade, &
!MV202609 z0 and zd to namelist
                    urb_z0_town, urb_zd_town,                                       &
!MV202609 tau scheme of the road
                    teb_ltau_scheme, teb_tau_hw_thresh, teb_tau_hw_width

!============================================================
!============================================================
!             PARAMETERS SETUP            
!============================================================
!============================================================
!============================================================
!============================================================


!===========================================================================
! Process command line arguments with keys
!===========================================================================
num_args = COMMAND_ARGUMENT_COUNT()

! Initialize variables
namelist_forcing_path_local = TRIM(namelist_forcing_path_default)
namelist_path_local = TRIM(namelist_path_default)
output_dir = 'output/'

! Parse arguments
IF (num_args > 0) THEN
    i = 1
    DO WHILE (i <= num_args)
        CALL GET_COMMAND_ARGUMENT(i, arg1)
        
        SELECT CASE (TRIM(arg1))
        CASE ('-forcing_nml')
            IF (i+1 <= num_args) THEN
                CALL GET_COMMAND_ARGUMENT(i+1, arg2)
                namelist_forcing_path_local = TRIM(arg2)
                i = i + 1
            ELSE
                WRITE(*,*) 'ERROR: Missing value for -forcing_nml'
                CALL PRINT_USAGE()
                STOP 1
            END IF
            
        CASE ('-param_nml')
            IF (i+1 <= num_args) THEN
                CALL GET_COMMAND_ARGUMENT(i+1, arg2)
                namelist_path_local = TRIM(arg2)
                i = i + 1
            ELSE
                WRITE(*,*) 'ERROR: Missing value for -param_nml'
                CALL PRINT_USAGE()
                STOP 1
            END IF
            
        CASE ('-output')
            IF (i+1 <= num_args) THEN
                CALL GET_COMMAND_ARGUMENT(i+1, arg2)
                output_dir = TRIM(arg2)
                ! Ensure trailing slash
                IF (output_dir(LEN_TRIM(output_dir):LEN_TRIM(output_dir)) /= '/') THEN
                    output_dir = TRIM(output_dir) // '/'
                END IF
                i = i + 1
            ELSE
                WRITE(*,*) 'ERROR: Missing value for -output'
                CALL PRINT_USAGE()
                STOP 1
            END IF
            
        CASE ('-h', '-help', '--help')
            CALL PRINT_USAGE()
            STOP 0
            
        CASE DEFAULT
            WRITE(*,*) 'ERROR: Unknown option: ', TRIM(arg1)
            CALL PRINT_USAGE()
            STOP 1
        END SELECT
        
        i = i + 1
    END DO
END IF

! Print information about which files are being used
WRITE(*,*) '----------------------------------------------------'
WRITE(*,*) 'TEB-Ru Offline Model'
WRITE(*,*) '  Forcing namelist: ', TRIM(namelist_forcing_path_local)
WRITE(*,*) '  Parameter namelist: ', TRIM(namelist_path_local)
WRITE(*,*) '  Output directory: ', TRIM(output_dir)
WRITE(*,*) '----------------------------------------------------'

                    ! Basic Settings of Location and Forcing
!============================================================
!============================================================
lon_teb(:)        = 1.3              ! Longitude (deg)
lat_teb(:)        = 43.484           ! Latitude (deg)
hlev_teb(:)       = 28.0             ! Atm. Forcing height above roof level
teb_year          = 2004             ! Current year (UTC)
teb_month         = 2                ! Current month (UTC)
teb_day           = 20               ! Current day (UTC)
teb_hour          = 0                ! Current hour (UTC)
teb_min           = 0                ! Current minute (UTC)
teb_sec           = 0                ! Current seconds (UTC)
dt                = 300.             ! Model time-steps
nsteps            = 18000            ! Number of Forcing time-steps
forc_step         = 1800             ! Forcing time-step

!============================================================
! Settings for Coupled Model (do not change in offline mode) 
!============================================================
sa_uc(:)          = 1.               ! Urban fraction
ivstart           = 1                ! optional start index                  
ivend             = 1                ! optional end index                  
iblock            = 1                ! number of block  

! Input forcing
u(:) = 5.
v(:) = -1.
t(:) = 290.3
qv(:) = 0.00380
ps(:) = 98872.90000
rho(:) = 1.26
prr_con(:) = 0.
prs_con(:) = 0.
prr_gsp(:) = 0.
prs_gsp(:) = 0.
prg_gsp(:) = 0.
lwd_s(:)   = 286.14000
swdir_s(:) = 0.
swdifd_s(:) = 0.

!============================================================
!============================================================
! Urban geometry
!============================================================
!============================================================
urb_fr_bld(:)    = 0.62             ! Horizontal building area density
fr_garden(:)     = 0.2              ! Fraction of GARDEN areas
urb_h2w(:)       = 1.38158          ! Canyon H/W
urb_h_bld(:)     = 20.              ! Canyon height (m)
!MV202609 z0 and zd to namelist
urb_z0_town      = '0.1H'           ! z0 of the urban surface (0.1*H - as before)
urb_zd_town      = 'H/3'            ! displacement height (H/3 - as before)
teb_road_dir(:)  = 0.0              ! Road direction (° from North, clockwise)
teb_hroad_dir    = 'UNIF'           ! Road direction
                                    ! 'UNIF' : uniform roads
                                    ! 'ORIE' : specified road orientation
teb_wall_opt     = 'UNIF'           ! Wall option
                                    ! 'UNIF' : uniform walls
                                    ! 'TWO ' : 2 opposite  wall
!============================================================
!============================================================
! Roof
!============================================================
!============================================================
urb_hcap_rf(:)   = 1580000.         ! Volumetric heat capacity (J m-3 K-1)
urb_hcon_rf(:)   = 1.15             ! Thermal conductivity (W/m K)
urb_alb_rf_so(:) = 0.40             ! Solar albedo of roofs
urb_alb_rf_th(:) = 0.03             ! Thermal albedo of roofs
!============================================================
!============================================================
! Road
!============================================================
!============================================================
urb_hcap_rd(:)   = 1740000.         ! Volumetric heat capacity (J m-3 K-1)
urb_hcon_rd(:)   = 0.82             ! Thermal conductivity (W/m K)
urb_alb_rd_so(:) = 0.08             ! Solar albedo of roads
urb_alb_rd_th(:) = 0.04             ! Thermal albedo of roads
!============================================================
!============================================================
! Wall
!============================================================
!============================================================
urb_hcap_wl(:)   = 1580000.         ! Volumetric heat capacity (J m-3 K-1)
urb_hcon_wl(:)   = 1.15             ! Thermal conductivity (W/m K)
urb_alb_wl_so(:) = 0.32             ! Solar albedo of walls
urb_alb_wl_th(:) = 0.03             ! Thermal albedo of walls
!============================================================
!============================================================
!* anthropogenic heat fluxes
!============================================================
!============================================================
ahf_traffic(:)   = 0.0              ! heat fluxes due to traffic
teb_utc_hour     = 3                ! Time zone for traffic daily cycle calculation                          
ahf_industry(:)  = 0.0              ! heat fluxes due to factories
!============================================================
!============================================================
! Parameters for Building Energy Module (BEM)
!============================================================
!============================================================ 
teb_itype_bem        = 'BEM'        ! Building energy Model
                                    ! 'DEF'  : no Building Energy Model
                                    ! 'BEM'  :    Building Energy Model
teb_lbem_ac          = .TRUE.       ! Flag to use air conditioners
teb_lshade           = .TRUE.       ! Flag for window shading
teb_itype_natvent    = 'NONE'       ! Natural Ventilation ! 'NONE', 'MANU', 'AUTO', 'MECH'
teb_itype_bem_cool   = 'IDEAL '     ! Cooling system    ! 'DXCOIL','IDEAL '    
teb_itype_bem_heat   = 'IDEAL '     ! Heating system    ! 'FINCAP','IDEAL '
teb_frac_gz    (:)   = 0.1          ! Glazing ratio 
teb_tcool_target(:)  = 297.16       ! Cooling setpoint of HVAC system [K]
teb_theat_target(:)  = 292.16       ! Heating setpoint of HVAC system [K]
teb_bem_vent   (:)   = 0.0          ! Ventilation flow rate [AC/H]
teb_bem_inf    (:)   = 0.5          ! Infiltration flow rate [AC/H]
teb_bem_cop    (:)   = 2.5	        ! Rated COP of the cooling system
teb_zresidential(:)  = 1.           ! Fraction of residential use in buildings (-)
teb_dt_res(:)        = 3.           ! Target temperature change when unoccupied (K) (residential buildings)
teb_dt_off(:)        = 3.           ! Target temperature change when unoccupied (K) (office buildings)
teb_cap_sys_heat(:)  =  90.         ! Capacity of the heating system [W m-2(bld)]

!============================================================
!============================================================
! Wind calculation	
!============================================================
!============================================================
teb_itype_wind       = 0            !IN TEB option for camyon wond calculation:
									! 0 - default; 1 - Wang scheme 
teb_fai(:,1:8)       = 0.5          ! Frontal area index
!MV202609 tau scheme of the road
teb_ltau_scheme      = .FALSE.      ! Flag to use the tau scheme for the road
teb_tau_hw_thresh    = 0.5          ! H/W giving tau = 0.5 (tau scheme)
teb_tau_hw_width     = 0.25         ! width of the tanh relaxation (tau scheme)
!============================================================
!============================================================
! Parameters for GREENROOF module 
!============================================================
!============================================================
teb_lgreenroof       = .FALSE.      ! Greenroof activation
teb_lgreenroof_ext   = .FALSE.      ! Greenroof activation (external scheme)
teb_frac_gr     (:)  = 0.0          ! Fraction of greenroofs on roofs  
teb_alb_gr      (:)  = 0.15         ! Greenroof albedo
teb_emis_gr     (:)  = 0.9          ! Greenroof emissivity 
teb_ts_gr       (:)  = 275.         ! Greenroof radiative surface temp. (snow free)
teb_shfl_gr     (:)  = 0.           ! Sensible heat flux over greenroofs 
teb_lhfl_gr     (:)  = 0.           ! Latent heat flux over greenroofs 
teb_qvfl_gr     (:)  = 0.           ! Total evaporation over greenroofs (kg/m2/s)
teb_runoff_gr   (:)  = 0.	        ! Greenroof surface runoff
!============================================================
!============================================================
! Parameters for GARDEN module 
!============================================================
!============================================================	
teb_lgarden          = .TRUE.       ! Garden activation
teb_lgarden_ext      = .FALSE.      ! Garden activation (external scheme)
teb_z0_gd       (:)  = 0.8          ! Garden roughness length
teb_alb_gd      (:)  = 0.15         ! Garden albedo
teb_emis_gd     (:)  = 0.9          ! Garden emissivity 
teb_ts_gd       (:)  = 275.         ! Garden radiative surface temp. (snow free)
teb_qs_gd       (:)  = 0.00380      ! Garden specific humidity
teb_shfl_gd     (:)  = 0.           ! Sensible heat flux over garden 
teb_lhfl_gd     (:)  = 0.           ! Latent heat flux over garden 
teb_qvfl_gd     (:)  = 0.           ! Total evaporation over garden (kg/m2/s)
teb_runoff_gd   (:)  = 0.           ! Garden surface runoff

!============================================================
!============================================================
! Parameters for Solar Panels module 
!============================================================
!============================================================	
teb_lsolar_panel     = .FALSE.       ! Garden activation
teb_fr_panel(:)      = 0.            ! Garden roughness length
!============================================================
!============================================================
! Parameters for Road Watering
!============================================================
!============================================================
teb_lroad_irrig         = .FALSE.    ! Road watering activation
teb_rd_irrig_start_m(:) = 6.         ! start month for watering of roads (included)
teb_rd_irrig_end_m(:)   = 8.         ! end   month for watering of roads (included)
teb_rd_irrig_start_h(:) = 6.         ! start hour  for watering of roads (included)
teb_rd_irrig_end_h(:)   = 9.         ! end   hour  for watering of roads (excluded)
teb_rd_irrig_sum(:)     = 1.         ! 24h quantity of water used for road watering (liter/m2)

!===========================================================================
!===========================================================================
! READ NAMELIST FORCING PARAMETERS
!===========================================================================
!===========================================================================
! Read from file.
OPEN(action='read', file=namelist_forcing_path_local, iostat=rc, newunit=fu)
IF (rc /= 0) THEN
    WRITE(*,*) 'ERROR: Cannot open forcing namelist file: ', TRIM(namelist_forcing_path_local)
    WRITE(*,*) 'IOSTAT = ', rc
    STOP 1
END IF

READ(nml=tebforcing, iostat=rc, unit=fu)
IF (rc > 0) THEN
    WRITE(*,*) 'WARNING: Issues reading forcing namelist from: ', TRIM(namelist_forcing_path_local)
    WRITE(*,*) 'IOSTAT = ', rc
    WRITE(*,*) 'Attempting to continue...'
    CALL SLEEP(2)  ! Pause for 2 second
END IF
CLOSE(fu)
forcing_path2=trim(forcing_path)

!===========================================================================
!===========================================================================
! READ NAMELIST PARAMETERS
!===========================================================================
!===========================================================================
				
!===========================================================================
! READ NAMELIST PARAMETERS
!===========================================================================
! Read from file.
OPEN(action='read', file=namelist_path_local, iostat=rc, newunit=fu)
IF (rc /= 0) THEN
    WRITE(*,*) 'ERROR: Cannot open parameter namelist file: ', TRIM(namelist_path_local)
    WRITE(*,*) 'IOSTAT = ', rc
    STOP 1
END IF

READ(nml=tebparam, iostat=rc, unit=fu)
IF (rc > 0) THEN
    WRITE(*,*) 'WARNING: Issues reading parameter namelist from: ', TRIM(namelist_path_local)
    WRITE(*,*) 'IOSTAT = ', rc
    WRITE(*,*) 'Attempting to continue...'
    CALL SLEEP(2)  ! Pause for 2 second
END IF
CLOSE(fu)

!===========================================================================
!===========================================================================
! READ ATMOSPHERIC FORCING FROM FILES
!===========================================================================
!===========================================================================
!* Open atmospheric forcing files
!
CALL OPEN_CLOSE_BIN_ASC_FORC('OPEN ','ASCII ',1,'R', forcing_path2)
!
! allocation of variables
!
CALL OL_ALLOC_ATM(1,1,1) ! INI, IBANDS, ISCAL
! allocate local atmospheric variables
ALLOCATE(ZTA    (2,1)) 
ALLOCATE(ZQA    (2,1))
ALLOCATE(ZWIND  (2,1))
ALLOCATE(ZDIR_SW(2,1))
ALLOCATE(ZSCA_SW(2,1))
ALLOCATE(ZLW    (2,1))
ALLOCATE(ZSNOW  (2,1))
ALLOCATE(ZRAIN  (2,1))
ALLOCATE(ZPS    (2,1))
!ALLOCATE(ZCO2   (2,1))
ALLOCATE(ZDIR   (2,1))
!* reads atmospheric forcing for first time-step
!
CALL OL_READ_ATM('ASCII ', 'ASCII ', 1, forcing_path2,   &
                    ZTA,ZQA,ZWIND,ZDIR_SW,ZSCA_SW,ZLW,ZSNOW,ZRAIN,ZPS,&
                    ZDIR )

! initialization of physical constants
CALL INI_CSTS

!XCO2(:)  = ZCO2(1,:)
XCO2(:)  = 0.
XRHOA(:) = ZPS(1,:) / ( ZTA(1,:)*XRD * ( 1.+((XRV/XRD)-1.)*ZQA(1,:) ) + hlev_teb(:)*XG )
teb_hour_seconds = teb_hour * 3600. + teb_min * 60. + teb_sec

! -----------------------------------------------------------
! Outputs
! -----------------------------------------------------------
!

! Set the list of the output columns.
! The number of columns depends on the activated model options:
!   HVAC_COOL/HVAC_HEAT - only with the Building Energy Model (teb_itype_bem='BEM')
!   SOLAR_PROD          - only with the solar panels module
! The atmospheric forcing used at the current step is appended at the end
! (columns Forc_*).
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
! The exchange coefficients between the road/garden surfaces and the air of the
! canyon (*_ROAD_CAN, *_GARDEN_CAN) or of the forcing level (*_ROAD_ATM,
! *_GARDEN_ATM) are appended after WIND_TOP (see URBAN_DRAG section 8.3):
! PCD/PCDN = drag coefficients, PRI = Richardson number, ZZ0H = roughness length
! for heat, PAC/PCH = conductance and heat transfer coefficient.
! The garden canyon/atmosphere coefficients are computed only with the external
! garden model (teb_lgarden_ext = .TRUE.); with the internal garden
! PCH_GARDEN_CAN is set to 0 in TEB_GARDEN and the *_GARDEN_ATM stay XUNDEF.
! The diagnostic turbulent heat fluxes of the road with the canyon air
! (H_ROAD_CAN, LE_ROAD_CAN) and directly with the air of the forcing level
! (H_ROAD_ATM, LE_ROAD_ATM) are appended at the very end: they are derived from
! the road surface temperature of the energy-budget solve (ROAD_LAYER_E_BUDGET)
! and from the road/canyon and road/atmosphere conductances, and are diagnostics
! only.
! The coefficients of the canyon exchange already available in the driver
! (teb_ac_rd, teb_tch_rd, teb_tcm_gd, teb_tch_gd, teb_cd_garden_atm,
! teb_ch_garden_atm) complete the set with PAC_ROAD_CAN, PCH_ROAD_CAN,
! PCD_GARDEN_CAN, PCH_GARDEN_CAN, PCD_GARDEN_ATM and PCH_GARDEN_ATM.
! anthropogenic heat diagnostics appended after LE_ROAD: AHF_TRAFFIC = sensible
! anthropogenic heat flux due to traffic at the current time-step and H_WASTE =
! sensible waste heat of the buildings (HVAC systems and infiltration/
! ventilation), both in W m-2(ground). They are already included in H_TOWN with
! their full weight (the tau scheme weights the road exchange only), so
! H_TOWN - AHF_TRAFFIC - H_WASTE is the flux of the urban surfaces alone.
nout = 0
nout = nout + 1; out_names(nout) = 'T_ROOF1'
nout = nout + 1; out_names(nout) = 'T_CANYON'
nout = nout + 1; out_names(nout) = 'T_ROAD1'
nout = nout + 1; out_names(nout) = 'T_WALLA1'
nout = nout + 1; out_names(nout) = 'T_WALLB1'
nout = nout + 1; out_names(nout) = 'TI_BLD'
nout = nout + 1; out_names(nout) = 'Q_CANYON'
nout = nout + 1; out_names(nout) = 'P_CANYON'
nout = nout + 1; out_names(nout) = 'U_CANYON'
nout = nout + 1; out_names(nout) = 'H_TOWN'
nout = nout + 1; out_names(nout) = 'LE_TOWN'
nout = nout + 1; out_names(nout) = 'RN_TOWN'
IF (teb_itype_bem == 'BEM') THEN
   nout = nout + 1; out_names(nout) = 'HVAC_COOL'
   nout = nout + 1; out_names(nout) = 'HVAC_HEAT'
END IF
IF (teb_lsolar_panel) THEN
   nout = nout + 1; out_names(nout) = 'SOLAR_PROD'
END IF
nout = nout + 1; out_names(nout) = 'WIND_TOP'
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
nout = nout + 1; out_names(nout) = 'PCD_ROAD_CAN'
nout = nout + 1; out_names(nout) = 'PCDN_ROAD_CAN'
nout = nout + 1; out_names(nout) = 'PRI_ROAD_CAN'
nout = nout + 1; out_names(nout) = 'ZZ0H_ROAD_CAN'
nout = nout + 1; out_names(nout) = 'PAC_ROAD_ATM'
nout = nout + 1; out_names(nout) = 'PCH_ROAD_ATM'
nout = nout + 1; out_names(nout) = 'PCD_ROAD_ATM'
nout = nout + 1; out_names(nout) = 'PCDN_ROAD_ATM'
nout = nout + 1; out_names(nout) = 'PRI_ROAD_ATM'
nout = nout + 1; out_names(nout) = 'ZZ0H_ROAD_ATM'
nout = nout + 1; out_names(nout) = 'PCDN_GARDEN_CAN'
nout = nout + 1; out_names(nout) = 'PRI_GARDEN_CAN'
nout = nout + 1; out_names(nout) = 'ZZ0H_GARDEN_CAN'
nout = nout + 1; out_names(nout) = 'PAC_GARDEN_ATM'
nout = nout + 1; out_names(nout) = 'PCDN_GARDEN_ATM'
nout = nout + 1; out_names(nout) = 'PRI_GARDEN_ATM'
nout = nout + 1; out_names(nout) = 'ZZ0H_GARDEN_ATM'
nout = nout + 1; out_names(nout) = 'PAC_ROAD_CAN'
nout = nout + 1; out_names(nout) = 'PCH_ROAD_CAN'
nout = nout + 1; out_names(nout) = 'PCD_GARDEN_CAN'
nout = nout + 1; out_names(nout) = 'PCH_GARDEN_CAN'
nout = nout + 1; out_names(nout) = 'PCD_GARDEN_ATM'
nout = nout + 1; out_names(nout) = 'PCH_GARDEN_ATM'
nout = nout + 1; out_names(nout) = 'H_ROAD_CAN'
nout = nout + 1; out_names(nout) = 'LE_ROAD_CAN'
nout = nout + 1; out_names(nout) = 'H_ROAD_ATM'
nout = nout + 1; out_names(nout) = 'LE_ROAD_ATM'
!MV202609 tau scheme of the road
nout = nout + 1; out_names(nout) = 'H_ROAD'
nout = nout + 1; out_names(nout) = 'LE_ROAD'
!MV202609 anthropogenic heat diagnostics (traffic and building waste heat)
nout = nout + 1; out_names(nout) = 'AHF_TRAFFIC'
nout = nout + 1; out_names(nout) = 'H_WASTE'
nout = nout + 1; out_names(nout) = 'LE_WASTE'
nout = nout + 1; out_names(nout) = 'GFLUX_TOWN'
!MV202609 tau scheme of the road (revision: three-temperature construction)
nout = nout + 1; out_names(nout) = 'T_CAN0'
nout = nout + 1; out_names(nout) = 'T_CAN1'
nout = nout + 1; out_names(nout) = 'PHI_CAN1'
! atmospheric forcing used by the model at the current time-step
nout = nout + 1; out_names(nout) = 'Forc_TA'
nout = nout + 1; out_names(nout) = 'Forc_QA'
nout = nout + 1; out_names(nout) = 'Forc_QV'
nout = nout + 1; out_names(nout) = 'Forc_U'
nout = nout + 1; out_names(nout) = 'Forc_V'
nout = nout + 1; out_names(nout) = 'Forc_WIND'
nout = nout + 1; out_names(nout) = 'Forc_DIR'
nout = nout + 1; out_names(nout) = 'Forc_PS'
nout = nout + 1; out_names(nout) = 'Forc_RHOA'
nout = nout + 1; out_names(nout) = 'Forc_RAIN'
nout = nout + 1; out_names(nout) = 'Forc_SNOW'
nout = nout + 1; out_names(nout) = 'Forc_LW'
nout = nout + 1; out_names(nout) = 'Forc_DIR_SW'
nout = nout + 1; out_names(nout) = 'Forc_SCA_SW'

! Open the output CSV file (the header is written once, the file is replaced)
output_csv = TRIM(output_dir)//'TEB_output.csv'
OPEN(UNIT=fu_out, FILE = output_csv, STATUS = 'REPLACE', ACTION = 'WRITE', IOSTAT=rc)
IF (rc /= 0) THEN
   WRITE(*,*) 'ERROR: Cannot open output CSV file: ', TRIM(output_csv)
   WRITE(*,*) 'IOSTAT = ', rc
   STOP 1
END IF

! The column names are stored in a fixed size array: stop explicitly instead of
! overwriting memory when the list of columns grows beyond nout_max
IF (nout > nout_max) THEN
   WRITE(*,*) 'ERROR RUN_TEB_OFFLINE: too many output columns: ', nout, &
              ' > nout_max = ', nout_max
   WRITE(*,*) 'Increase nout_max in RUN_TEB_OFFLINE.'
   STOP 1
END IF

! Build and write the header line: time;name1;name2;...
! (the line is filled in place: an assignment of a concatenation longer than
!  out_line would be silently truncated, so the position is tracked explicitly)
out_line = 'time'
lout = LEN_TRIM(out_line)
DO jout = 1, nout
   out_line(lout+1:lout+1) = out_sep
   out_line(lout+2:) = TRIM(out_names(jout))
   lout = lout + 1 + LEN_TRIM(out_names(jout))
END DO
WRITE(*,*) '  Output file: ', TRIM(output_csv)
WRITE(*,*) '  Output columns: ', TRIM(out_line)
WRITE(fu_out,'(A)') TRIM(out_line)

! -----------------------------------------------------------
! Temporal loops
! -----------------------------------------------------------
!
INB_ATM = forc_step / dt

DO nstep= 1,nsteps - 1
   WRITE(*,FMT='(I5,A1,I5)') nstep,'/',nsteps - 1
	! read Forcing
    CALL OL_READ_ATM('ASCII ', 'ASCII ', nstep, forcing_path2,   &
                    ZTA,ZQA,ZWIND,ZDIR_SW,ZSCA_SW,ZLW,ZSNOW,ZRAIN,ZPS,&
                    ZDIR )
    
	DO JSURF_STEP=1,INB_ATM  
	
       ! time interpolation of the forcing
       CALL OL_TIME_INTERP_ATM(JSURF_STEP,INB_ATM,                               &
                               ZTA,ZQA,ZWIND,ZDIR_SW,ZSCA_SW,ZLW,ZSNOW,ZRAIN,ZPS,&
                               ZDIR  )
  
       ! define forcing variables
	   t(:) = XTA(:)
	   ! specific humidity (conversion from kg/m3 to kg/kg)
	   qv(:) = XQA(:) / XRHOA(:)
	   u(:) = XU(:)
	   v(:) = XV(:)
	   ps(:) = XPS(:)
	   rho(:) = XRHOA(:)
	   prr_con(:) = XRAIN(:)
	   prs_con(:) = XSNOW(:)
	   prr_gsp(:) = 0.
	   prs_gsp(:) = 0.
	   prg_gsp(:) = 0.
	   lwd_s(:) = XLW(:)
	   swdir_s(:) = XDIR_SW(:,1)
	   swdifd_s(:) = XSCA_SW(:,1)
	   
	   ! Update time
	   teb_hour_seconds = teb_hour_seconds + dt
       teb_hour = INT(teb_hour_seconds(1) / 3600.)
       teb_min  = INT(MOD(teb_hour_seconds(1), 3600.) / 60.)
       teb_sec  = INT(MOD(teb_hour_seconds(1), 60.))
	   
	   CALL ADD_FORECAST_TO_DATE_SURF(teb_year, teb_month, teb_day, teb_hour_seconds)

!*****************************************************************************
!                  Call of physical routines of TEB is here                  !
!*****************************************************************************	   
	   CALL teb_interface (nstep, nvec, iblock, dt, teb_year, teb_month, teb_day, teb_hour,         &
                teb_min, teb_sec, teb_hour_seconds, sa_uc, lon_teb, lat_teb, hlev_teb,              &
				ivstart, ivend, u, v, t, qv, ps, rho, prr_con, prs_con, prr_gsp, prs_gsp, prg_gsp,  &
				lwd_s, swdir_s, swdifd_s, teb_nroof_layer, teb_nroad_layer, teb_nwall_layer,        &
				teb_nfloor_layer, urb_fr_bld, fr_garden, urb_h2w, urb_h_bld, urb_hcap_rd,           &
				urb_hcap_rf, urb_hcap_wl, urb_hcon_rd, urb_hcon_rf, urb_hcon_wl, urb_alb_rd_so,     &
				urb_alb_rf_so, urb_alb_wl_so, urb_alb_rd_th, urb_alb_rf_th, urb_alb_wl_th,          &
				ahf_traffic, ahf_industry, teb_ti_bld, teb_troof, teb_troad_now, teb_troad,         &
				teb_twalla, teb_twallb, teb_tfloor, teb_tmass, teb_qi_bld, teb_tcanyon,             &
				teb_qcanyon, teb_ucanyon, teb_vcanyon, teb_sobs, teb_thbs, teb_ws_roof,             &
				teb_ws_road, teb_wsnow_roof, teb_wsnow_road, teb_tsnow_roof, teb_tsnow_road,        &
				teb_rsnow_roof, teb_rsnow_road, teb_tssnow_roof, teb_tssnow_road, teb_asnow_roof,   &
				teb_asnow_road, teb_esnow_roof, teb_esnow_road, teb_twin1, teb_twin2, teb_albwin,   &
				teb_tsroof, teb_tswalla, teb_tswallb, teb_shfl, teb_lhfl, teb_tstown_s_now,         &
				teb_tstown_s, teb_qstown_s, teb_wstown_now, teb_wstown, teb_runoff_town,            &
				teb_tssnow_town_now, teb_tssnow_town, teb_wsnow_town_now, teb_wsnow_town,           &
				teb_rsnow_town_now, teb_rsnow_town, teb_tch_town, teb_qvfl, teb_shfl_snow,          &
				teb_lhfl_snow, teb_frsnow, teb_snow_melt, teb_hsnow_town_now, teb_hsnow_town,       &
				teb_alb_so, teb_alb_th, teb_itype_bem, teb_lbem_ac, teb_itype_natvent,              &
				teb_itype_bem_cool, teb_itype_bem_heat, teb_frac_gz, teb_tcool_target,              &
				teb_theat_target, teb_bem_vent, teb_bem_inf, teb_bem_cop, teb_cap_sys_rat,          &
				teb_m_sys_rat, teb_shad_day, teb_natvent_night, teb_hwaste, teb_hvac_cool,          &
				teb_hvac_heat, teb_lgreenroof,  teb_frac_gr, teb_alb_gr, teb_emis_gr, teb_ts_gr,    &
				teb_shfl_gr, teb_lhfl_gr, teb_qvfl_gr, teb_runoff_gr, teb_lgarden, teb_z0_gd,       &
				teb_alb_gd, teb_emis_gd, teb_ts_gd, teb_qs_gd, teb_shfl_gd, teb_lhfl_gd,            &
				teb_qvfl_gd, teb_tch_gd, teb_tcm_gd, teb_runoff_gd, teb_itype_wind, teb_fai,        &
				teb_dqs_town, teb_gflux, teb_shfl_rf, teb_shfl_rd, teb_shfl_wl, teb_ac_rf,          &
				teb_ac_rd, teb_ac_wl, teb_ac_top, teb_tch_rf, teb_tch_rd, teb_tch_wl, teb_tch_top,  &
				teb_wind_top, teb_ustar_town, teb_cd_garden_atm, teb_ch_garden_atm, ahf_traffic_now,          &
				teb_rn_town, teb_wind_canyon, teb_tsroad, teb_lgarden_ext, teb_lgreenroof_ext,      &
				teb_hroad_dir, teb_wall_opt, teb_road_dir, teb_zresidential, teb_dt_res, teb_dt_off,&
				teb_cap_sys_heat, teb_lsolar_panel, teb_fr_panel, teb_lroad_irrig,                  &
				teb_rd_irrig_start_m, teb_rd_irrig_end_m, teb_rd_irrig_start_h, teb_rd_irrig_end_h, &
				teb_rd_irrig_sum, teb_solar_prod, teb_utc_hour, teb_lshade,                          &
!MV202609 z0 and zd to namelist
				urb_z0_town, urb_zd_town,                         &
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
                          PCD_ROAD_CAN, PCDN_ROAD_CAN, PRI_ROAD_CAN, ZZ0H_ROAD_CAN, &
                          PAC_ROAD_ATM, PCH_ROAD_ATM, PCD_ROAD_ATM, PCDN_ROAD_ATM, &
                          PRI_ROAD_ATM, ZZ0H_ROAD_ATM, PCDN_GARDEN_CAN, PRI_GARDEN_CAN, &
                          ZZ0H_GARDEN_CAN, PAC_GARDEN_ATM, PCDN_GARDEN_ATM, PRI_GARDEN_ATM, ZZ0H_GARDEN_ATM, &
                          PH_ROAD_CAN, PLE_ROAD_CAN, PH_ROAD_ATM, PLE_ROAD_ATM, &
!MV202609 tau scheme of the road (revision: three-temperature construction)
                          PT_CAN0, PT_CAN1, PPHI_CAN1,                        &
!MV202609 tau scheme of the road
                          PH_ROAD, PLE_ROAD, teb_ltau_scheme,                   &
                          teb_tau_hw_thresh, teb_tau_hw_width,                  &
!MV202609 anthropogenic heat diagnostics
                          teb_lewaste)
						
    END DO
	   !
    ! --- one line of the output file: timestamp, model variables, forcing
    ! note: teb_hour is computed before the date is updated (ADD_FORECAST_TO_DATE_SURF),
    !       so just after the date change it may be 24; the time of the current state is
    !       therefore recomputed from teb_hour_seconds (seconds since midnight of the date)
    WRITE(time_buf,'(I4.4,"-",I2.2,"-",I2.2," ",I2.2,":",I2.2,":",I2.2)')              &
         teb_year, teb_month, teb_day,                                                &
         INT(teb_hour_seconds(1)/3600.),                                              &
         INT(MOD(teb_hour_seconds(1), 3600.)/60.),                                    &
         INT(MOD(teb_hour_seconds(1), 60.))
    out_line = TRIM(time_buf)
    CALL CSV_APPEND(out_line, teb_tsroof(1))
    CALL CSV_APPEND(out_line, teb_tcanyon(1))
    CALL CSV_APPEND(out_line, teb_tsroad(1))
    CALL CSV_APPEND(out_line, teb_tswalla(1))
    CALL CSV_APPEND(out_line, teb_tswallb(1))
    CALL CSV_APPEND(out_line, teb_ti_bld(1))
    CALL CSV_APPEND(out_line, teb_qcanyon(1))
    CALL CSV_APPEND(out_line, XPS(1))
    CALL CSV_APPEND(out_line, teb_wind_canyon(1))
    CALL CSV_APPEND(out_line, teb_shfl(1))
    CALL CSV_APPEND(out_line, teb_lhfl(1))
    CALL CSV_APPEND(out_line, teb_rn_town(1))
    IF (teb_itype_bem == 'BEM') THEN
       CALL CSV_APPEND(out_line, teb_hvac_cool(1))
       CALL CSV_APPEND(out_line, teb_hvac_heat(1))
    END IF
    IF (teb_lsolar_panel) THEN
       CALL CSV_APPEND(out_line, teb_solar_prod(1))
    END IF
    CALL CSV_APPEND(out_line, teb_wind_top(1))
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
CALL CSV_APPEND(out_line, PCD_ROAD_CAN(1))
CALL CSV_APPEND(out_line, PCDN_ROAD_CAN(1))
CALL CSV_APPEND(out_line, PRI_ROAD_CAN(1))
CALL CSV_APPEND(out_line, ZZ0H_ROAD_CAN(1))
CALL CSV_APPEND(out_line, PAC_ROAD_ATM(1))
CALL CSV_APPEND(out_line, PCH_ROAD_ATM(1))
CALL CSV_APPEND(out_line, PCD_ROAD_ATM(1))
CALL CSV_APPEND(out_line, PCDN_ROAD_ATM(1))
CALL CSV_APPEND(out_line, PRI_ROAD_ATM(1))
CALL CSV_APPEND(out_line, ZZ0H_ROAD_ATM(1))
CALL CSV_APPEND(out_line, PCDN_GARDEN_CAN(1))
CALL CSV_APPEND(out_line, PRI_GARDEN_CAN(1))
CALL CSV_APPEND(out_line, ZZ0H_GARDEN_CAN(1))
CALL CSV_APPEND(out_line, PAC_GARDEN_ATM(1))
CALL CSV_APPEND(out_line, PCDN_GARDEN_ATM(1))
CALL CSV_APPEND(out_line, PRI_GARDEN_ATM(1))
CALL CSV_APPEND(out_line, ZZ0H_GARDEN_ATM(1))
CALL CSV_APPEND(out_line, teb_ac_rd(1))
CALL CSV_APPEND(out_line, teb_tch_rd(1))
CALL CSV_APPEND(out_line, teb_tcm_gd(1))
CALL CSV_APPEND(out_line, teb_tch_gd(1))
CALL CSV_APPEND(out_line, teb_cd_garden_atm(1))
CALL CSV_APPEND(out_line, teb_ch_garden_atm(1))
CALL CSV_APPEND(out_line, PH_ROAD_CAN(1))
CALL CSV_APPEND(out_line, PLE_ROAD_CAN(1))
CALL CSV_APPEND(out_line, PH_ROAD_ATM(1))
CALL CSV_APPEND(out_line, PLE_ROAD_ATM(1))
!MV202609 tau scheme of the road
CALL CSV_APPEND(out_line, PH_ROAD(1))
CALL CSV_APPEND(out_line, PLE_ROAD(1))
!MV202609 anthropogenic heat diagnostics (traffic and building waste heat)
CALL CSV_APPEND(out_line, ahf_traffic_now(1))
CALL CSV_APPEND(out_line, teb_hwaste(1))
CALL CSV_APPEND(out_line, teb_lewaste(1))
CALL CSV_APPEND(out_line, teb_gflux(1))
!MV202609 tau scheme of the road (revision: three-temperature construction)
CALL CSV_APPEND(out_line, PT_CAN0(1))
CALL CSV_APPEND(out_line, PT_CAN1(1))
CALL CSV_APPEND(out_line, PPHI_CAN1(1))
    ! --- atmospheric forcing used by the model at the current time-step
    forc_wind = SQRT(u(1)**2 + v(1)**2)
    forc_dir  = MOD(ATAN2(u(1), v(1))*180./XPI + 360., 360.)
    CALL CSV_APPEND(out_line, t(1))
    CALL CSV_APPEND(out_line, qv(1)*rho(1))
    CALL CSV_APPEND(out_line, qv(1))
    CALL CSV_APPEND(out_line, u(1))
    CALL CSV_APPEND(out_line, v(1))
    CALL CSV_APPEND(out_line, forc_wind)
    CALL CSV_APPEND(out_line, forc_dir)
    CALL CSV_APPEND(out_line, ps(1))
    CALL CSV_APPEND(out_line, rho(1))
    CALL CSV_APPEND(out_line, prr_con(1))
    CALL CSV_APPEND(out_line, prs_con(1))
    CALL CSV_APPEND(out_line, lwd_s(1))
    CALL CSV_APPEND(out_line, swdir_s(1))
    CALL CSV_APPEND(out_line, swdifd_s(1))
    WRITE(fu_out,'(A)') TRIM(out_line)
END DO

!  DEALLOCATE variables
DEALLOCATE(ZTA) 
DEALLOCATE(ZQA)
DEALLOCATE(ZWIND)
DEALLOCATE(ZDIR_SW)
DEALLOCATE(ZSCA_SW)
DEALLOCATE(ZLW)
DEALLOCATE(ZSNOW)
DEALLOCATE(ZRAIN)
DEALLOCATE(ZPS)
!DEALLOCATE(ZCO2)
DEALLOCATE(ZDIR)

CALL OPEN_CLOSE_BIN_ASC_FORC('CLOSE ','ASCII ',1,'R', forcing_path2)
CLOSE(fu_out)

!
    WRITE(*,*) ' '
    WRITE(*,*) '    --------------------------'
    WRITE(*,*) '    |  TEB-Ru OFFLINE SIMULATION ENDS CORRECTLY |'
    WRITE(*,*) '    --------------------------'
    WRITE(*,*) ' '
!
! --------------------------------------------------------------------------------------
!
CONTAINS

SUBROUTINE PRINT_USAGE()
    WRITE(*,*) ''
    WRITE(*,*) 'Usage: ./TEB_offline.exe [options]'
    WRITE(*,*) ''
    WRITE(*,*) 'Options:'
    WRITE(*,*) '  -forcing_nml <path>    Path to forcing namelist file'
    WRITE(*,*) '                          (default: namelist/namelist_forcing.nml)'
    WRITE(*,*) '  -param_nml <path>      Path to parameter namelist file'
    WRITE(*,*) '                          (default: namelist/namelist.nml)'
    WRITE(*,*) '  -output <dir>          Output directory for model results'
    WRITE(*,*) '                          (default: output/)'
    WRITE(*,*) '  -h, -help, --help      Show this help message'
    WRITE(*,*) ''
    WRITE(*,*) 'Examples:'
    WRITE(*,*) '  ./TEB_offline.exe'
    WRITE(*,*) '  ./TEB_offline.exe -forcing_nml my_forcing.nml -param_nml my_params.nml'
    WRITE(*,*) '  ./TEB_offline.exe -forcing_nml my_forcing.nml -output my_results/'
    WRITE(*,*) '  ./TEB_offline.exe -help'
    WRITE(*,*) ''
END SUBROUTINE PRINT_USAGE

!> Append one real value to a CSV line: 'line = line//sep//value'
!! List-directed output is used, so that the CSV file contains exactly the same digits
!! as the previous per-variable txt files (bit-identical values).
SUBROUTINE CSV_APPEND(line, value)
    CHARACTER(LEN=*), INTENT(INOUT) :: line
    REAL, INTENT(IN) :: value
    CHARACTER(LEN=64) :: buf
    INTEGER :: l
    WRITE(buf,*) value
    l = LEN_TRIM(line)
    IF (l + 1 + LEN_TRIM(ADJUSTL(buf)) > LEN(line)) THEN
       WRITE(*,*) 'ERROR: output line is too long, increase the size of out_line'
       STOP 1
    END IF
    line(l+1:l+1) = out_sep
    line(l+2:) = TRIM(ADJUSTL(buf))
END SUBROUTINE CSV_APPEND

END PROGRAM run_teb_offline

