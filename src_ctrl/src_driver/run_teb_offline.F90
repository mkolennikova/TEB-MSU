PROGRAM run_teb_offline

USE sfc_teb,        ONLY : teb_interface
USE MODI_OL_READ_ATM
USE MODI_OL_TIME_INTERP_ATM
USE MODD_SURF_PAR, ONLY: XUNDEF, teb_snow_check
USE MODD_CSTS,     ONLY : XCPD, XSTEFAN, XPI, XDAY, XKARMAN,   &
                          XLVTT, XLSTT, XLMTT, XRV, XRD, XG, XP00
!MV202609 saturation humidity, used by the external garden / greenroof emulator
USE MODE_THERMOS,  ONLY : QSAT
!MV202609 the namelist items of the surface parameters and of the urban
!* aerodynamics of the control tree are carried by MODD_PROXI_SVAT_PAR (a
!* NAMELIST group can reference use-associated variables); the module also
!* holds the resolved displacement height XZD_TOWN used by the physics
USE MODD_PROXI_SVAT_PAR, ONLY : urb_z0_town, urb_zd_town,                        &
                                urb_z0_gdn, urb_alb_gdn, urb_emis_gdn,           &
                                urb_z0_grf, urb_alb_grf, urb_emis_grf,           &
                                teb_type_garden, teb_type_greenroof
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
REAL, DIMENSION(1)    :: dt                  !IN integration timestep

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
LOGICAL, DIMENSION(1) :: teb_lshade                     !IN Flag to use window shading
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
REAL ,DIMENSION(nvec) :: teb_hvac_cool                  !OUT Energy consumption of the cooling system [W m-2(bld)]  
REAL ,DIMENSION(nvec) :: teb_hvac_heat                  !OUT Energy consumption of the heating system [W m-2(bld)]  

!Variables for garden (COSMO)
REAL ,DIMENSION(nvec) :: teb_sobs                       !OUT Shortwave radiation absorbed by garden
REAL ,DIMENSION(nvec) :: teb_thbs                       !OUT Longwave radiation absorbed by garden
REAL ,DIMENSION(nvec) :: teb_tch_gd                     !OUT garden transfer coefficient for heat
REAL ,DIMENSION(nvec) :: teb_tcm_gd                     !OUT garden  surf. exchange coefficient

!Other variables
REAL ,DIMENSION(nvec) :: teb_ilmo_road
REAL ,DIMENSION(nvec) :: teb_ilmo_roof
REAL ,DIMENSION(nvec) :: teb_ilmo_top
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
! Output: the single CSV file is opened after the namelists are read (see below)      
! -----------------------------------------------------------                        
! -----------------------------------------------------------                        
! Namelist paths                                                                            
! -----------------------------------------------------------                                      
INTEGER                           :: fu, rc
CHARACTER(LEN=*), PARAMETER       :: namelist_path = 'namelist/namelist.nml'
CHARACTER(LEN=*), PARAMETER       :: namelist_forcing_path = 'namelist/namelist_forcing.nml'
CHARACTER(LEN=100)                :: forcing_path   ! Forcing filepath that we read from namelist
CHARACTER(:), allocatable         :: forcing_path2  ! Forcing filepath with adjusted length
! -----------------------------------------------------------
! Command line of the executable
! -----------------------------------------------------------
INTEGER                           :: ncmdargs
CHARACTER(LEN=256)                :: cmd_arg1, cmd_arg2
INTEGER                           :: iarg
! -----------------------------------------------------------
! Output: one CSV file <output_dir>/TEB_output.csv
! -----------------------------------------------------------
CHARACTER(LEN=256)                :: output_dir
CHARACTER(LEN=256)                :: output_csv
!* unit of the output CSV file: a fixed unit number, as in src_dev (an
!* uninitialised unit number made OPEN fail intermittently on Windows)
INTEGER, PARAMETER                :: fu_out = 13
CHARACTER(LEN=1), PARAMETER       :: out_sep = ';'
INTEGER, PARAMETER                :: nout_max = 200
INTEGER                           :: nout, lout, jout
CHARACTER(LEN=64), DIMENSION(nout_max) :: out_names
CHARACTER(LEN=8192)               :: out_line
CHARACTER(LEN=32)                 :: time_buf
! -----------------------------------------------------------
! Namelist groups of the run and their paths
! -----------------------------------------------------------
INTEGER, PARAMETER                :: inml_unset = -999999
CHARACTER(LEN=256)                :: namelist_path_local
CHARACTER(LEN=256)                :: namelist_forcing_path_local
REAL                              :: forc_step      ! IN forcing time-step (s), /tebforcing/
!* items of /tebforcing/ (used by the diagnostics of the strict reading; the list is
!* checked against the namelist file by python_tests/check_namelist.py)
CHARACTER(LEN=*), PARAMETER :: nml_forcing_items =                                  &
     'forcing_path,lon_teb,lat_teb,hlev_teb,teb_year,teb_month,teb_day,teb_hour,'// &
     'teb_min,nsteps,forc_step'
!* items of /tebforcing/ that have a sentinel (inml_unset) when they are not read
CHARACTER(LEN=*), PARAMETER :: nml_forcing_value_items =                            &
     'teb_year,teb_month,teb_day,teb_hour,teb_min,nsteps'
CHARACTER(LEN=*), PARAMETER :: nml_param_items =                                    &
     'dt,urb_h_bld,urb_fr_bld,fr_garden,urb_h2w,teb_road_dir,teb_hroad_dir,'//      &
     'teb_wall_opt,teb_ti_bld,teb_qi_bld,urb_alb_rf_so,urb_alb_rf_th,urb_hcap_rf,'//&
     'urb_hcon_rf,urb_alb_rd_so,urb_alb_rd_th,urb_hcap_rd,urb_hcon_rd,'//           &
     'urb_alb_wl_so,urb_alb_wl_th,urb_hcap_wl,urb_hcon_wl,teb_itype_bem,'//         &
     'teb_lbem_ac,teb_itype_natvent,teb_itype_bem_cool,teb_itype_bem_heat,'//       &
     'teb_frac_gz,teb_tcool_target,teb_theat_target,teb_zresidential,teb_dt_res,'//  &
     'teb_dt_off,teb_bem_inf,teb_bem_vent,teb_bem_cop,teb_cap_sys_rat,'//           &
     'teb_m_sys_rat,teb_cap_sys_heat,ahf_traffic,ahf_industry,teb_itype_wind,'//    &
     'teb_fai,teb_lgarden,teb_lgreenroof,teb_frac_gr,teb_lsolar_panel,teb_fr_panel,'//&
     'teb_lroad_irrig,teb_rd_irrig_start_m,teb_rd_irrig_end_m,teb_rd_irrig_start_h,'//&
     'teb_rd_irrig_end_h,teb_rd_irrig_sum,teb_utc_hour,urb_z0_town,urb_zd_town,'//   &
     'teb_type_garden,urb_z0_gdn,urb_alb_gdn,urb_emis_gdn,teb_type_greenroof,'//    &
     'urb_z0_grf,urb_alb_grf,urb_emis_grf,teb_lshade,teb_snow_check'
!* The two groups are declared here (and not next to the READ that uses them): a
!* NAMELIST statement belongs to the specification part of the program, i.e. it must
!* appear before the first executable statement.
NAMELIST /tebforcing/ forcing_path, lon_teb, lat_teb, hlev_teb, teb_year,   &
                      teb_month, teb_day, teb_hour, teb_min, nsteps, forc_step
NAMELIST /tebparam/ dt, urb_h_bld, urb_fr_bld, fr_garden, urb_h2w, teb_road_dir,           &
                    teb_hroad_dir, teb_wall_opt, teb_ti_bld, teb_qi_bld,                   &
                    urb_alb_rf_so, urb_alb_rf_th, urb_hcap_rf, urb_hcon_rf,                &
                    urb_alb_rd_so, urb_alb_rd_th, urb_hcap_rd, urb_hcon_rd,                &
                    urb_alb_wl_so, urb_alb_wl_th, urb_hcap_wl, urb_hcon_wl,                &
                    teb_itype_bem, teb_lbem_ac, teb_itype_natvent, teb_itype_bem_cool,     &
                    teb_itype_bem_heat, teb_frac_gz, teb_tcool_target,                     &
                    teb_theat_target, teb_zresidential, teb_dt_res, teb_dt_off,            &
                    teb_bem_inf, teb_bem_vent, teb_bem_cop, teb_cap_sys_rat,               &
                    teb_m_sys_rat, teb_cap_sys_heat, ahf_traffic, ahf_industry,            &
                    teb_itype_wind, teb_fai, teb_lgarden, teb_lgreenroof, teb_frac_gr,     &
                    teb_lsolar_panel, teb_fr_panel, teb_lroad_irrig,                       &
                    teb_rd_irrig_start_m, teb_rd_irrig_end_m, teb_rd_irrig_start_h,        &
                    teb_rd_irrig_end_h, teb_rd_irrig_sum, teb_utc_hour,                    &
                    !MV202609 keys of the shared namelist honoured by the control tree:
                    !* urban aerodynamics and garden/greenroof surface parameters
                    urb_z0_town, urb_zd_town, teb_type_garden, urb_z0_gdn, urb_alb_gdn,    &
                    urb_emis_gdn, teb_type_greenroof, urb_z0_grf, urb_alb_grf, urb_emis_grf, &
                    teb_lshade, teb_snow_check

!============================================================
!============================================================
!             PARAMETERS SETUP            
!============================================================
!============================================================
!============================================================
!============================================================
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
dt                = 300.             ! Forcing time-steps
nsteps            = 17999            ! Number of Forcing time-steps
INB_ATM           = 6                ! number time the driver calls the TEB
!                                    ! routines during a forcing time-step
!                                    ! --> it defines the time-step for TEB
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
!MV202609 window shading: namelist key teb_lshade, plumbed exactly as in src_dev
!* and main (driver -> TEB_INTERFACE -> CALL_DRIVER, where LSHADE is an
!* argument). The DEFAULT is the first-commit behaviour: the first commit
!* hard-codes LSHADE = .FALSE. inside CALL_DRIVER, so an absent key keeps the
!* base model; set teb_lshade = .TRUE. to activate the shading devices as
!* src_dev/main do by default.
teb_lshade           = .FALSE.      ! Flag for window shading
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
!             COMMAND LINE OF THE EXECUTABLE
!===========================================================================
!===========================================================================
ncmdargs = COMMAND_ARGUMENT_COUNT()
namelist_forcing_path_local = TRIM(namelist_forcing_path)
namelist_path_local = TRIM(namelist_path)
output_dir = 'output/'
IF (ncmdargs > 0) THEN
    iarg = 1
    DO WHILE (iarg <= ncmdargs)
        CALL GET_COMMAND_ARGUMENT(iarg, cmd_arg1)
        SELECT CASE (TRIM(cmd_arg1))
        CASE ('-forcing_nml')
            IF (iarg+1 <= ncmdargs) THEN
                CALL GET_COMMAND_ARGUMENT(iarg+1, cmd_arg2)
                namelist_forcing_path_local = TRIM(cmd_arg2)
                iarg = iarg + 1
            ELSE
                WRITE(*,*) 'ERROR: Missing value for -forcing_nml'
                CALL PRINT_USAGE()
                STOP 1
            END IF
        CASE ('-param_nml')
            IF (iarg+1 <= ncmdargs) THEN
                CALL GET_COMMAND_ARGUMENT(iarg+1, cmd_arg2)
                namelist_path_local = TRIM(cmd_arg2)
                iarg = iarg + 1
            ELSE
                WRITE(*,*) 'ERROR: Missing value for -param_nml'
                CALL PRINT_USAGE()
                STOP 1
            END IF
        CASE ('-output')
            IF (iarg+1 <= ncmdargs) THEN
                CALL GET_COMMAND_ARGUMENT(iarg+1, cmd_arg2)
                output_dir = TRIM(cmd_arg2)
                ! Ensure trailing slash
                IF (output_dir(LEN_TRIM(output_dir):LEN_TRIM(output_dir)) /= '/') THEN
                    output_dir = TRIM(output_dir) // '/'
                END IF
                iarg = iarg + 1
            ELSE
                WRITE(*,*) 'ERROR: Missing value for -output'
                CALL PRINT_USAGE()
                STOP 1
            END IF
        CASE ('-h', '-help', '--help')
            CALL PRINT_USAGE()
            STOP 0
        CASE DEFAULT
            WRITE(*,*) 'ERROR: Unknown option: ', TRIM(cmd_arg1)
            CALL PRINT_USAGE()
            STOP 1
        END SELECT
        iarg = iarg + 1
    END DO
END IF
WRITE(*,*) '----------------------------------------------------'
WRITE(*,*) 'TEB-MSU Offline Model (control tree)'
WRITE(*,*) '  Forcing namelist: ', TRIM(namelist_forcing_path_local)
WRITE(*,*) '  Parameter namelist: ', TRIM(namelist_path_local)
WRITE(*,*) '  Output directory: ', TRIM(output_dir)
!===========================================================================
!===========================================================================
! READ NAMELIST FORCING PARAMETERS
!===========================================================================
!===========================================================================
!* A failed READ is an ERROR (and not a warning followed by a run with a wrong
!* date): the namelist is only read up to the faulty entry, so every item that
!* follows it in the file keeps the value of the program (inml_unset for the
!* date/time items), which is detected by the validation below.
OPEN(action='read', file=namelist_forcing_path_local, iostat=rc, newunit=fu)
IF (rc /= 0) THEN
    WRITE(*,*) 'ERROR: Cannot open forcing namelist file: ', TRIM(namelist_forcing_path_local)
    WRITE(*,*) 'IOSTAT = ', rc
    STOP 1
END IF
READ(nml=tebforcing, iostat=rc, unit=fu)
CLOSE(fu)
!MV202609 strict namelist date/time reading
IF (rc > 0) THEN
    WRITE(*,*) 'ERROR: cannot read the forcing namelist: ', TRIM(namelist_forcing_path_local)
    WRITE(*,*) '       IOSTAT = ', rc
    CALL NML_PRINT_DIAG('tebforcing', namelist_forcing_path_local, nml_forcing_items, &
                        'the namelist could not be read completely', &
                        NML_FORCING_VALUES(), nml_forcing_value_items)
    STOP 1
END IF
IF (.NOT. NML_FORCING_OK()) THEN
    WRITE(*,*) 'ERROR: the forcing namelist does not define a valid configuration'
    WRITE(*,*) '       (IOSTAT of the READ = ', rc, ')'
    CALL NML_PRINT_DIAG('tebforcing', namelist_forcing_path_local, nml_forcing_items, &
                        'a required item is missing, not read, or out of range', &
                        NML_FORCING_VALUES(), nml_forcing_value_items)
    STOP 1
END IF
IF (rc < 0) THEN
    WRITE(*,'(A)') ' TEB-MSU offline: note: the namelist file does not end with an' &
         //' end-of-line (IOSTAT = -1 of the READ); all required items were read'
END IF
CALL NML_REPORT_ABSENT('tebforcing', namelist_forcing_path_local, nml_forcing_items)
WRITE(*,'(A,A)') ' TEB-MSU offline: forcing namelist = ', TRIM(namelist_forcing_path_local)
WRITE(*,'(A,I4,A,I2.2,A,I2.2,A,I2.2,A,I2.2,A)')                                &
     ' TEB-MSU offline: start date ', teb_year, '-', teb_month, '-', teb_day,     &
     ' ', teb_hour, ':', teb_min, ' (teb_year/month/day/hour/min of the namelist)'
WRITE(*,'(A,I10,A,F12.1,A,A)') ' TEB-MSU offline: nsteps = ', nsteps,             &
     '   forc_step = ', forc_step, ' s', ' (forcing window of the run)'
WRITE(*,'(A,A)') ' TEB-MSU offline: forcing_path = ', TRIM(forcing_path)
CALL NML_PRINT_END_DATE()
forcing_path2=trim(forcing_path)
!===========================================================================
!===========================================================================
! READ NAMELIST PARAMETERS
!===========================================================================
!===========================================================================
!* Same policy as for /tebforcing/ above: a failed READ of the parameter namelist
!* stops the run (the namelist is only read up to the faulty entry, so every item
!* that follows it in the file would keep the value of the driver default).
OPEN(action='read', file=namelist_path_local, iostat=rc, newunit=fu)
IF (rc /= 0) THEN
    WRITE(*,*) 'ERROR: Cannot open parameter namelist file: ', TRIM(namelist_path_local)
    WRITE(*,*) 'IOSTAT = ', rc
    STOP 1
END IF
READ(nml=tebparam, iostat=rc, unit=fu)
CLOSE(fu)
IF (rc > 0) THEN
    WRITE(*,*) 'ERROR: cannot read the parameter namelist: ', TRIM(namelist_path_local)
    WRITE(*,*) '       IOSTAT = ', rc
    CALL NML_PRINT_DIAG('tebparam', namelist_path_local, nml_param_items, &
                        'the namelist could not be read completely')
    STOP 1
END IF
CALL NML_REPORT_ABSENT('tebparam', namelist_path_local, nml_param_items)
!* dt is read in this group: INB_ATM = forc_step/dt must be an integer number of
!* model sub-steps per forcing step.
IF (dt(1) <= 0. .OR. MOD(forc_step, dt(1)) /= 0.) THEN
    WRITE(*,*) 'ERROR: inconsistent time steps: dt = ', dt(1), ' s (parameter namelist),'
    WRITE(*,*) '       forc_step = ', forc_step, ' s (forcing namelist):'
    WRITE(*,*) '       dt must be > 0 and forc_step must be a multiple of dt'
    STOP 1
END IF
WRITE(*,'(A,F10.1,A,F12.1,A,I0,A)') ' TEB-MSU offline: dt = ', dt(1), ' s, forc_step = ', &
     forc_step, ' s -> INB_ATM = ', NINT(forc_step / dt(1)), ' model sub-steps per forcing step'

!===========================================================================
!===========================================================================
! SURFACE PARAMETERS AND URBAN AERODYNAMICS FROM THE SHARED NAMELIST
!===========================================================================
!===========================================================================
!MV202609 garden and greenroof surface parameters
!* The control tree has no internal value for these quantities other than the
!* base-model one: it applies the namelist items (urb_z0_gdn / urb_alb_gdn /
!* urb_emis_gdn for the garden, urb_z0_grf / urb_alb_grf / urb_emis_grf for the
!* greenroof), whose defaults are the base-model values of the first commit
!* (0.80/0.15/0.90 and 0.01/0.15/0.90, see MODD_PROXI_SVAT_PAR). An absent item
!* therefore keeps the physics of the first commit.
teb_z0_gd (:) = urb_z0_gdn
teb_alb_gd(:) = urb_alb_gdn
teb_emis_gd(:) = urb_emis_gdn
teb_alb_gr(:) = urb_alb_grf
teb_emis_gr(:) = urb_emis_grf
!* The roughness length of the greenroof is used directly by GREENROOF (friction
!* flux), so it is read there from MODD_PROXI_SVAT_PAR: urb_z0_grf.
WRITE(*,'(A,F8.3,A,F6.3,A,F6.3,A)') ' TEB-MSU offline: garden  z0/alb/emis = ', urb_z0_gdn, &
     ' m / ', urb_alb_gdn, ' / ', urb_emis_gdn
WRITE(*,'(A,F8.3,A,F6.3,A,F6.3,A)') ' TEB-MSU offline: greenroof z0/alb/emis = ', urb_z0_grf, &
     ' m / ', urb_alb_grf, ' / ', urb_emis_grf

!MV202609 garden / greenroof model types (namelist keys of the dev tree)
!* The control tree has a SINGLE internal parameterization for the garden and for
!* the greenroof ('PROXY_OLD' and 'PROXY_NEW' are the same code here). The two
!* external modes of the dev tree are available as well: 'EXT' and 'EXT_NEU' make
!* TEB_GARDEN read the state and the fluxes of the garden / of the greenroof from
!* the coupling interface instead of computing them internally. The driver then
!* has to prescribe them at every sub-step - this is what the BOWEN emulator of
!* this file does (subroutines PCD_GARDEN / PCD_GREENROOF): it evaluates the same
!* fixed Bowen-ratio proxy as the internal scheme of the control tree and feeds
!* the result back through the EXT interface, so that 'EXT' driven by the
!* emulator reproduces the internal 'PROXY_OLD' garden.
!* ('EXT' and 'EXT_NEU' are equivalent in this tree: the dev tree only
!* distinguishes them by the exchange coefficients it exports for diagnostics.)
IF (teb_type_garden /= 'PROXY_OLD' .AND. teb_type_garden /= 'PROXY_NEW' .AND. &
    teb_type_garden /= 'EXT' .AND. teb_type_garden /= 'EXT_NEU') THEN
   WRITE(*,*) 'ERROR: teb_type_garden = ', TRIM(teb_type_garden), &
              ' is not available in the control tree (src_ctrl)'
   WRITE(*,*) '       accepted: PROXY_OLD, PROXY_NEW, EXT, EXT_NEU'
   STOP 1
END IF
IF (teb_type_greenroof /= 'PROXY_OLD' .AND. teb_type_greenroof /= 'PROXY_NEW' .AND. &
    teb_type_greenroof /= 'EXT' .AND. teb_type_greenroof /= 'EXT_NEU') THEN
   WRITE(*,*) 'ERROR: teb_type_greenroof = ', TRIM(teb_type_greenroof), &
              ' is not available in the control tree (src_ctrl)'
   WRITE(*,*) '       accepted: PROXY_OLD, PROXY_NEW, EXT, EXT_NEU'
   STOP 1
END IF
!* external garden / greenroof: the legacy flags teb_lgarden_ext and
!* teb_lgreenroof_ext are the ones TEB_GARDEN tests (OGARDEN_EXT /
!* OGREENROOF_EXT); they are set here from the model type
IF (teb_type_garden == 'EXT' .OR. teb_type_garden == 'EXT_NEU') THEN
   teb_lgarden_ext = .TRUE.
   WRITE(*,'(A,A,A)') ' TEB-MSU offline: external garden (teb_type_garden = ', &
        TRIM(teb_type_garden), '), prescribed by the Bowen emulator'
   IF (.NOT. teb_lgarden) WRITE(*,*) &
        ' TEB-MSU offline: WARNING - teb_lgarden = .FALSE., the garden is OFF: '// &
        'the external garden will not be used'
END IF
IF (teb_type_greenroof == 'EXT' .OR. teb_type_greenroof == 'EXT_NEU') THEN
   teb_lgreenroof_ext = .TRUE.
   WRITE(*,'(A,A,A)') ' TEB-MSU offline: external greenroof (teb_type_greenroof = ', &
        TRIM(teb_type_greenroof), '), prescribed by the Bowen emulator'
   IF (.NOT. teb_lgreenroof) WRITE(*,*) &
        ' TEB-MSU offline: WARNING - teb_lgreenroof = .FALSE., the greenroof is OFF: '// &
        'the external greenroof will not be used'
END IF
WRITE(*,'(A,A,A,A,A)') ' TEB-MSU offline: teb_type_garden = ', TRIM(teb_type_garden), &
     ', teb_type_greenroof = ', TRIM(teb_type_greenroof), &
     ' (internal proxy or external emulator)'

! -----------------------------------------------------------
! Output: one CSV file (<output_dir>/TEB_output.csv)
! -----------------------------------------------------------
! The column names are stored in a fixed size array: stop explicitly instead of
! overwriting memory when the list of columns grows beyond nout_max
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
nout = nout + 1; out_names(nout) = 'HVAC_COOL'
nout = nout + 1; out_names(nout) = 'HVAC_HEAT'
nout = nout + 1; out_names(nout) = 'WIND_TOP'
nout = nout + 1; out_names(nout) = 'SOLAR_PROD'
nout = nout + 1; out_names(nout) = 'AHF_TRAFFIC'
nout = nout + 1; out_names(nout) = 'GFLUX_TOWN'
nout = nout + 1; out_names(nout) = 'H_WASTE'
nout = nout + 1; out_names(nout) = 'SOLAR_ZENITH'
nout = nout + 1; out_names(nout) = 'SOLAR_ELEV'
nout = nout + 1; out_names(nout) = 'SOLAR_AZIM'
! atmospheric forcing used by the model at the current time-step
nout = nout + 1; out_names(nout) = 'Forc_TA'
nout = nout + 1; out_names(nout) = 'Forc_QA'
nout = nout + 1; out_names(nout) = 'Forc_QV'
nout = nout + 1; out_names(nout) = 'Forc_U'
nout = nout + 1; out_names(nout) = 'Forc_V'
nout = nout + 1; out_names(nout) = 'Forc_PS'
nout = nout + 1; out_names(nout) = 'Forc_RHOA'
nout = nout + 1; out_names(nout) = 'Forc_RAIN'
nout = nout + 1; out_names(nout) = 'Forc_SNOW'
nout = nout + 1; out_names(nout) = 'Forc_LW'
nout = nout + 1; out_names(nout) = 'Forc_DIR_SW'
nout = nout + 1; out_names(nout) = 'Forc_SCA_SW'
IF (nout > nout_max) THEN
   WRITE(*,*) 'ERROR RUN_TEB_OFFLINE: too many output columns: ', nout, &
              ' > nout_max = ', nout_max
   STOP 1
END IF
! Open the output CSV file (the header is written once, the file is replaced)
output_csv = TRIM(output_dir)//'TEB_output.csv'
OPEN(UNIT=fu_out, FILE = output_csv, STATUS = 'REPLACE', ACTION = 'WRITE', IOSTAT=rc)
IF (rc /= 0) THEN
   WRITE(*,*) 'ERROR: Cannot open output CSV file: ', TRIM(output_csv)
   WRITE(*,*) 'IOSTAT = ', rc
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
! Temporal loops
! -----------------------------------------------------------
!
!* Number of model sub-steps per forcing step (checked just above: forc_step is a
!* multiple of dt), and the output covers the forcing window [1, nsteps-1]: the
!* forcing file read at step nstep is interpolated over its own window, and the
!* state written at the end of step nstep is stamped start + nstep*forc_step.
INB_ATM = NINT(forc_step / dt(1))
DO ntstep = 1, nsteps - 1
    WRITE(*,FMT='(I5,A1,I5)') ntstep,'/',nsteps - 1
    WRITE(*,FMT='(I5,A1,I5)') ntstep,'/',nsteps
	! read Forcing
    CALL OL_READ_ATM('ASCII ', 'ASCII ', ntstep, forcing_path2,   &
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
	   teb_hour	   = teb_hour_seconds(1) / 3600.
	   teb_min = mod(teb_hour_seconds(1), 3600.) / 60.
	   teb_sec = mod(teb_hour_seconds(1), 60.)
	   
	   CALL ADD_FORECAST_TO_DATE_SURF(teb_year, teb_month, teb_day, teb_hour_seconds)

!*****************************************************************************
!                  Call of physical routines of TEB is here                  !
!*****************************************************************************	   
	   CALL teb_interface (ntstep, nvec, iblock, dt, teb_year, teb_month, teb_day, teb_hour,         &
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
				teb_wind_top, teb_ilmo_road, teb_ilmo_roof, teb_ilmo_top, ahf_traffic_now,          &
				teb_rn_town, teb_wind_canyon, teb_tsroad, teb_lgarden_ext, teb_lgreenroof_ext,      &
				teb_hroad_dir, teb_wall_opt, teb_road_dir, teb_zresidential, teb_dt_res, teb_dt_off,&
				teb_cap_sys_heat, teb_lsolar_panel, teb_fr_panel, teb_lroad_irrig,                  &
				teb_rd_irrig_start_m, teb_rd_irrig_end_m, teb_rd_irrig_start_h, teb_rd_irrig_end_h, &
				teb_rd_irrig_sum, teb_solar_prod, teb_utc_hour, teb_lshade)
       !MV202609 external garden / greenroof: the Bowen emulator prescribes the
       !* state and the fluxes of the garden / of the greenroof, which TEB reads
       !* back at the NEXT sub-step through its EXT interface (one sub-step lag)
       IF (teb_lgarden_ext)     CALL PCD_GARDEN
       IF (teb_lgreenroof_ext)  CALL PCD_GREENROOF
						
    END DO
    !
    ! --- one line of the output file: timestamp, model variables, forcing
    ! note: teb_hour is computed before the date is updated (ADD_FORECAST_TO_DATE_SURF),
    !       so just after the date change it may be 24; the time of the current state is
    !       therefore recomputed from teb_hour_seconds (seconds since midnight of the date)
    WRITE(time_buf,'(I4.4,"-",I2.2,"-",I2.2," ",I2.2,":",I2.2,":",I2.2)')       &
         teb_year, teb_month, teb_day,                                          &
         INT(teb_hour_seconds(1)/3600.),                                        &
         INT(MOD(teb_hour_seconds(1), 3600.)/60.),                              &
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
    CALL CSV_APPEND(out_line, teb_hvac_cool(1))
    CALL CSV_APPEND(out_line, teb_hvac_heat(1))
    CALL CSV_APPEND(out_line, teb_wind_top(1))
    CALL CSV_APPEND(out_line, teb_solar_prod(1))
    CALL CSV_APPEND(out_line, ahf_traffic_now(1))
    CALL CSV_APPEND(out_line, teb_gflux(1))
    CALL CSV_APPEND(out_line, teb_hwaste(1))
    CALL CSV_APPEND(out_line, XZENITH(1) * 180. / XPI)
    CALL CSV_APPEND(out_line, 90. - XZENITH(1) * 180. / XPI)
    CALL CSV_APPEND(out_line, MOD(XAZIM(1) * 180. / XPI + 360., 360.))
    CALL CSV_APPEND(out_line, t(1))
    CALL CSV_APPEND(out_line, qv(1)*rho(1))
    CALL CSV_APPEND(out_line, qv(1))
    CALL CSV_APPEND(out_line, u(1))
    CALL CSV_APPEND(out_line, v(1))
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
    WRITE(*,*) '    |  DRIVER ENDS CORRECTLY |'
    WRITE(*,*) '    --------------------------'
    WRITE(*,*) ' '
!
! --------------------------------------------------------------------------------------
!

!===============================================================================
! Internal procedures: I/O machinery (CSV output and namelist diagnostics)
!  ported from the dev tree (src_dev), identical source
!===============================================================================
CONTAINS
INTEGER FUNCTION NML_DAYS_IN_MONTH(kyear, kmonth)
    INTEGER, INTENT(IN) :: kyear   ! year
    INTEGER, INTENT(IN) :: kmonth  ! month (1-12)
    SELECT CASE (kmonth)
    CASE (4, 6, 9, 11)
        NML_DAYS_IN_MONTH = 30
    CASE (1, 3, 5, 7:8, 10, 12)
        NML_DAYS_IN_MONTH = 31
    CASE (2)
        IF (MOD(kyear, 4) == 0 .AND. (MOD(kyear, 100) /= 0 .OR. MOD(kyear, 400) == 0)) THEN
            NML_DAYS_IN_MONTH = 29
        ELSE
            NML_DAYS_IN_MONTH = 28
        END IF
    CASE DEFAULT
        NML_DAYS_IN_MONTH = 0
    END SELECT
END FUNCTION NML_DAYS_IN_MONTH

!> .TRUE. if the /tebforcing/ group defines a valid configuration: the start
!! date/time of the run was read from the namelist and is a valid date, the forcing
!! window is consistent and the location / forcing path are usable.
!! The items teb_year/teb_month/teb_day/teb_hour/teb_min/nsteps are INTEGER items
!! and have no default value any more: an item that is missing from the file - or
!! that was not read because the READ stopped on an earlier faulty entry (e.g. a
!! real value like 'teb_hour = 0.0' for an INTEGER item) - keeps the sentinel
!! inml_unset and this function returns .FALSE.
LOGICAL FUNCTION NML_FORCING_OK()
    NML_FORCING_OK = .FALSE.
    IF (teb_year  == inml_unset .OR. teb_month == inml_unset .OR. &
        teb_day   == inml_unset .OR. teb_hour  == inml_unset .OR. &
        teb_min   == inml_unset .OR. nsteps    == inml_unset) RETURN
    IF (teb_year  < 1900 .OR. teb_year  > 2200) RETURN
    IF (teb_month < 1    .OR. teb_month > 12)   RETURN
    IF (teb_day   < 1    .OR. teb_day   > NML_DAYS_IN_MONTH(teb_year, teb_month)) RETURN
    IF (teb_hour  < 0    .OR. teb_hour  > 23)   RETURN
    IF (teb_min   < 0    .OR. teb_min   > 59)   RETURN
    IF (nsteps    < 2)                          RETURN
    IF (forc_step <= 0.)                        RETURN
    IF (LEN_TRIM(forcing_path) == 0)            RETURN  ! blank path: not given
    IF (ABS(lat_teb(1)) > 90. .OR. ABS(lon_teb(1)) > 360.) RETURN
    IF (hlev_teb(1) <= 0.)                      RETURN
    NML_FORCING_OK = .TRUE.
END FUNCTION NML_FORCING_OK

!> Diagnostic of a namelist group after a failed READ: for every declared item it
!! prints the line of the file and whether it was read, whether the READ stopped
!! before it (its value is then the driver default) or whether it is not present in
!! the file. The failing entry is located by re-reading prefixes of the group (see
!! NML_FIND_STOP). `vals` (optional, with `valued_items`) holds the values of the
!! items that have a sentinel: an item whose value is inml_unset was not read.
SUBROUTINE NML_PRINT_DIAG(group, path, items, reason, vals, valued_items)
    CHARACTER(LEN=*), INTENT(IN) :: group, path, items, reason
    INTEGER, OPTIONAL, INTENT(IN) :: vals(:)
    CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: valued_items
    CHARACTER(LEN=256), ALLOCATABLE :: body(:)
    INTEGER, ALLOCATABLE :: lineno(:), vcopy(:)
    INTEGER :: nb, nit, i, k, istop, pos, vt, ival, nvals
    LOGICAL :: found, hasval, lnotread
    CHARACTER(LEN=32) :: name, vname, stopname
    CHARACTER(LEN=64) :: state
    !* the values are copied here: the prefix reads of NML_FIND_STOP assign the
    !* variables of the group (vcopy keeps the values at call time)
    nvals = 0
    IF (PRESENT(vals)) nvals = SIZE(vals)
    ALLOCATE(vcopy(MAX(nvals, 1)))
    vcopy = 0
    IF (nvals > 0) vcopy(1:nvals) = vals
    CALL NML_SCAN_GROUP(path, group, body, lineno, nb, found)
    istop = NML_FIRST_FAIL_LINE(group, body, lineno, nb)
    WRITE(*,'(2A)') '       reason: ', TRIM(reason)
    WRITE(*,'(3A)') '       group /', TRIM(group), '/ of the file:'
    WRITE(*,'(2A)') '         ', TRIM(path)
    IF (.NOT. found) THEN
        WRITE(*,'(3A)') '       ERROR: the group /', TRIM(group), &
                        '/ is not present in this file'
        RETURN
    END IF
    nit = NML_ITEM_COUNT(items)
    WRITE(*,'(A,I0,A,I0,A)') '         ', nb, ' lines in the group, ', nit, &
                             ' declared items:'
    DO i = 1, nit
        name = NML_ITEM_PICK(items, i)
        pos = 0
        DO k = 1, nb
            IF (NML_LINE_HAS(body(k), name)) THEN
                pos = lineno(k)
                EXIT
            END IF
        END DO
        hasval = .FALSE.
        ival = 0
        IF (PRESENT(valued_items) .AND. nvals > 0) THEN
            DO vt = 1, NML_ITEM_COUNT(valued_items)
                vname = NML_ITEM_PICK(valued_items, vt)
                IF (vname == name .AND. vt <= nvals) THEN
                    hasval = .TRUE.
                    ival = vcopy(vt)
                    EXIT
                END IF
            END DO
        END IF
        lnotread = hasval .AND. (ival == inml_unset)
        IF (pos == 0) THEN
            state = 'not in the file: driver default used'
        ELSE IF (lnotread) THEN
            state = 'NOT READ: value not set'
        ELSE IF (istop > 0 .AND. pos >= istop) THEN
            state = 'not read: at/after the failing entry'
        ELSE
            state = 'read'
        END IF
        IF (pos > 0) THEN
            WRITE(*,'(3A,I0,2A)') '         - ', TRIM(name), ' (line ', pos, ') : ', &
                                  TRIM(state)
        ELSE
            WRITE(*,'(4A)') '         - ', TRIM(name), ' : ', TRIM(state)
        END IF
    END DO
    IF (istop > 0) THEN
        stopname = ''
        DO k = 1, nb
            IF (lineno(k) == istop) THEN
                stopname = NML_ITEM_NAME_OF(body(k))
                EXIT
            END IF
        END DO
        WRITE(*,'(A,I0,A)') '       -> the READ fails from line ', istop, ' on:'
        WRITE(*,'(2A)') '          first failing entry: "', TRIM(stopname)//'"'
        WRITE(*,'(A)') '          this entry and every entry that follows it in the file' &
             //' keep the value of the program (the driver default)'
    ELSE IF (found) THEN
        WRITE(*,'(A)') '       -> the failing line of the group could not be located'
    END IF
    WRITE(*,'(A)') '       reminder: INTEGER namelist items must be written without a' &
         //' decimal point (teb_hour = 0, not teb_hour = 0.0)'
END SUBROUTINE NML_PRINT_DIAG

!> Name of the item that a body line assigns (empty for a continuation line)
FUNCTION NML_ITEM_NAME_OF(line) RESULT(name)
    CHARACTER(LEN=*), INTENT(IN) :: line
    CHARACTER(LEN=32) :: name
    INTEGER :: j
    name = ''
    IF (.NOT. NML_LINE_ASSIGNS(line)) RETURN
    j = INDEX(line, '=')
    name = NML_LOWER(TRIM(ADJUSTL(line(1:j-1))))
END FUNCTION NML_ITEM_NAME_OF

!> Reports the declared items of a group that are NOT present in the namelist file:
!! their value is the value of the program, i.e. the driver default. Informational
!! only - a namelist file may legitimately give only part of the declared items.
SUBROUTINE NML_REPORT_ABSENT(group, path, items)
    CHARACTER(LEN=*), INTENT(IN) :: group, path, items
    CHARACTER(LEN=256), ALLOCATABLE :: body(:)
    INTEGER, ALLOCATABLE :: lineno(:)
    INTEGER :: nb, nit, i, k, nabs
    LOGICAL :: found, lhere
    CHARACTER(LEN=32) :: name
    CHARACTER(LEN=1024) :: list
    CALL NML_SCAN_GROUP(path, group, body, lineno, nb, found)
    IF (.NOT. found) RETURN
    nit = NML_ITEM_COUNT(items)
    nabs = 0
    list = ''
    DO i = 1, nit
        name = NML_ITEM_PICK(items, i)
        lhere = .FALSE.
        DO k = 1, nb
            IF (NML_LINE_HAS(body(k), name)) THEN
                lhere = .TRUE.
                EXIT
            END IF
        END DO
        IF (.NOT. lhere) THEN
            nabs = nabs + 1
            IF (LEN_TRIM(list) == 0) THEN
                list = TRIM(name)
            ELSE
                list = TRIM(list)//', '//TRIM(name)
            END IF
        END IF
    END DO
    IF (nabs == 0) RETURN
    WRITE(*,'(A,I0,2A)') ' TEB-MSU offline: '//TRIM(group)//' namelist: ', nabs, &
         ' item(s) are not in the file, the driver default is used: ', TRIM(list)
END SUBROUTINE NML_REPORT_ABSENT

!> Lowercase copy of a string (to search the namelist file without case sensitivity)
FUNCTION NML_LOWER(str) RESULT(out)
    CHARACTER(LEN=*), INTENT(IN) :: str
    CHARACTER(LEN=LEN(str))      :: out
    INTEGER :: j, ic
    out = str
    DO j = 1, LEN(str)
        ic = IACHAR(out(j:j))
        IF (ic >= IACHAR('A') .AND. ic <= IACHAR('Z')) out(j:j) = ACHAR(ic + 32)
    END DO
END FUNCTION NML_LOWER

!> .TRUE. if the character can be part of a namelist item name
LOGICAL FUNCTION NML_IS_NAME_CHAR(c)
    CHARACTER, INTENT(IN) :: c
    NML_IS_NAME_CHAR = (c >= 'a' .AND. c <= 'z') .OR. (c >= 'A' .AND. c <= 'Z') &
                       .OR. (c >= '0' .AND. c <= '9') .OR. c == '_'
END FUNCTION NML_IS_NAME_CHAR

!> .TRUE. if the (lowercase) line of a namelist *starts* a new item, i.e. it begins
!! with an item name followed by '=' (a continuation line with the remaining values
!! of the previous item returns .FALSE.)
LOGICAL FUNCTION NML_LINE_ASSIGNS(line)
    CHARACTER(LEN=*), INTENT(IN) :: line
    INTEGER :: j, k
    CHARACTER(LEN=64) :: head
    NML_LINE_ASSIGNS = .FALSE.
    j = INDEX(line, '=')
    IF (j == 0) RETURN
    head = TRIM(ADJUSTL(line(1:j-1)))
    IF (LEN_TRIM(head) == 0) RETURN
    IF (INDEX(TRIM(head), ' ') > 0) RETURN   ! several words: not a single item name
    IF (INDEX(TRIM(head), ',') > 0) RETURN
    IF (INDEX(TRIM(head), '=') > 0) RETURN
    DO k = 1, LEN_TRIM(head)
        IF (.NOT. NML_IS_NAME_CHAR(head(k:k))) RETURN
    END DO
    NML_LINE_ASSIGNS = .TRUE.
END FUNCTION NML_LINE_ASSIGNS

!> Number of items of a comma separated list of namelist item names
INTEGER FUNCTION NML_ITEM_COUNT(items)
    CHARACTER(LEN=*), INTENT(IN) :: items
    INTEGER :: j, k
    NML_ITEM_COUNT = 0
    IF (LEN_TRIM(items) == 0) RETURN
    NML_ITEM_COUNT = 1
    k = 1
    DO
        j = INDEX(items(k:), ',')
        IF (j == 0) EXIT
        NML_ITEM_COUNT = NML_ITEM_COUNT + 1
        k = k + j
    END DO
END FUNCTION NML_ITEM_COUNT

!> i-th item (lowercase, trimmed) of a comma separated list
FUNCTION NML_ITEM_PICK(items, i) RESULT(name)
    CHARACTER(LEN=*), INTENT(IN) :: items
    INTEGER, INTENT(IN) :: i
    CHARACTER(LEN=32) :: name
    INTEGER :: j, k, n
    name = ''
    IF (i < 1) RETURN
    k = 1
    n = 0
    DO
        j = INDEX(items(k:), ',')
        n = n + 1
        IF (n == i) THEN
            IF (j == 0) THEN
                name = items(k:)
            ELSE
                name = items(k:k+j-2)
            END IF
            name = NML_LOWER(TRIM(ADJUSTL(name)))
            RETURN
        END IF
        IF (j == 0) RETURN
        k = k + j
    END DO
END FUNCTION NML_ITEM_PICK

!> .TRUE. if the (lowercase) line of a namelist contains the item "name" assigned,
!! i.e. "name" followed by blanks and '=' - the item must not be part of a longer
!! name ("teb_hour" does not match "teb_hour_seconds")
LOGICAL FUNCTION NML_LINE_HAS(line, name)
    CHARACTER(LEN=*), INTENT(IN) :: line  ! lowercase line
    CHARACTER(LEN=*), INTENT(IN) :: name  ! lowercase item name
    INTEGER :: ip, jp, k, ln, ll
    LOGICAL :: lstart
    NML_LINE_HAS = .FALSE.
    ln = LEN_TRIM(name)
    ll = LEN_TRIM(line)
    jp = 1
    DO WHILE (jp <= ll)
        ip = INDEX(line(jp:ll), name(1:ln))
        IF (ip == 0) RETURN
        ip = jp + ip - 1
!MV202609 strict namelist reading (fix): the character preceding the item must not
!* be a name character, but there is no character at all when the item starts the
!* line (ip = 1). The test must not evaluate LINE(0:0) in that case: Fortran does
!* not guarantee the short-circuit evaluation of .OR. (gfortran evaluates both
!* operands), and reading one byte before the string faults intermittently
!* (SIGSEGV) depending on the memory layout - the string here is a slice of a
!* heap buffer of namelist lines.
        IF (ip == 1) THEN
            lstart = .TRUE.
        ELSE
            lstart = .NOT. NML_IS_NAME_CHAR(line(ip-1:ip-1))
        END IF
        IF (lstart) THEN
            k = ip + ln
            DO WHILE (k <= ll .AND. line(k:k) == ' ')
                k = k + 1
            END DO
            IF (k <= ll) THEN
                IF (line(k:k) == '=') THEN
                    NML_LINE_HAS = .TRUE.
                    RETURN
                END IF
            END IF
        END IF
        jp = ip + 1
    END DO
END FUNCTION NML_LINE_HAS

!> Adds a time interval (idays days, isec seconds) to a date, using the length of
!! the month (leap years included). The date increment of the model itself is
!! ADD_FORECAST_TO_DATE_SURF: the same rule, so the end date printed by the driver
!! is the date the model reaches at the last output line.
SUBROUTINE NML_STEP_DATE(kyr, kmo, kda, khr, kmi, ksec, idays, isec_in)
    INTEGER, INTENT(INOUT) :: kyr, kmo, kda, khr, kmi, ksec
    INTEGER, INTENT(IN)    :: idays    ! number of days to add
    INTEGER, INTENT(IN)    :: isec_in  ! number of seconds to add
    INTEGER :: j, isec
    isec = khr*3600 + kmi*60 + ksec + isec_in
    DO j = 1, idays + isec/86400
        IF (kda < NML_DAYS_IN_MONTH(kyr, kmo)) THEN
            kda = kda + 1
        ELSE IF (kmo < 12) THEN
            kda = 1
            kmo = kmo + 1
        ELSE
            kda = 1
            kmo = 1
            kyr = kyr + 1
        END IF
    END DO
    isec = MOD(isec, 86400)
    khr = isec / 3600
    kmi = MOD(isec, 3600) / 60
    ksec = MOD(isec, 60)
END SUBROUTINE NML_STEP_DATE

!> Echo of the end date of the run: start date of the namelist + the duration of
!! the run ((nsteps-1)*forc_step). The date/time of the first output line is the
!! start date + one forcing step.
SUBROUTINE NML_PRINT_END_DATE()
    INTEGER :: kyr, kmo, kda, khr, kmi, ksec
    INTEGER :: idays, isec
    INTEGER(KIND=8) :: itotal
    itotal = INT(REAL(nsteps - 1, KIND=8)*REAL(forc_step, KIND=8), KIND=8)
    idays  = INT(itotal / 86400_8)
    isec   = INT(MOD(itotal, 86400_8))
    kyr = teb_year; kmo = teb_month; kda = teb_day
    khr = teb_hour; kmi = teb_min  ; ksec = teb_sec
    CALL NML_STEP_DATE(kyr, kmo, kda, khr, kmi, ksec, idays, isec)
    WRITE(*,'(A,I4,A,I2.2,A,I2.2,A,I2.2,A,I2.2,A,I2.2,A)')                        &
         ' TEB-MSU offline: end   date ', kyr, '-', kmo, '-', kda, ' ', khr, ':',  &
         kmi, ':', ksec, ' UTC (= start + (nsteps-1)*forc_step)'
    WRITE(*,'(A)') ' TEB-MSU offline: the first output line is stamped start + forc_step'
END SUBROUTINE NML_PRINT_END_DATE

!> Body of one namelist group of a file: the lines between '&group' and the line
!! whose first non blank character is '/', with the comments removed and the blank
!! lines dropped, together with their line numbers in the file. Restriction of this
!! diagnostic scan: the end of the group is the first line that starts with '/'
!! (the syntax of every namelist file of the project), so that a '/' inside a
!! character value (e.g. a directory path) does not end the group.
SUBROUTINE NML_SCAN_GROUP(path, group, body, lineno, nb, found)
    CHARACTER(LEN=*), INTENT(IN)  :: path, group
    CHARACTER(LEN=256), ALLOCATABLE, INTENT(OUT) :: body(:)
    INTEGER, ALLOCATABLE, INTENT(OUT) :: lineno(:)
    INTEGER, INTENT(OUT) :: nb
    LOGICAL, INTENT(OUT) :: found
    INTEGER, PARAMETER :: nmax = 2048
    CHARACTER(LEN=256) :: line, low, tail
    INTEGER :: fu, rc, i, k, j
    ALLOCATE(body(nmax), lineno(nmax))
    nb = 0
    found = .FALSE.
    OPEN(action='read', file=path, iostat=rc, newunit=fu)
    IF (rc /= 0) THEN
        CLOSE(fu, iostat=rc)
        RETURN
    END IF
    i = 0
    DO
        READ(fu, '(A)', iostat=rc) line
        IF (rc /= 0) EXIT
        i = i + 1
        low = NML_LOWER(line)
        k = INDEX(low, '!')
        IF (k > 0) low = low(1:k-1)
        IF (.NOT. found) THEN
            j = INDEX(low, '&'//TRIM(group))
            IF (j > 0) THEN
                found = .TRUE.
                low = low(j + 1 + LEN_TRIM(group):)   ! drop the '&group' header
            ELSE
                CYCLE
            END IF
        END IF
        tail = ADJUSTL(low)
        IF (tail(1:1) == '/') EXIT                    ! end of the group
        IF (LEN_TRIM(tail) > 0 .AND. nb < nmax) THEN
            nb = nb + 1
            body(nb) = tail
            lineno(nb) = i
        END IF
    END DO
    CLOSE(fu, iostat=rc)
END SUBROUTINE NML_SCAN_GROUP

!> Text of a namelist group built from its first `nbody` body lines: the header
!! '&group', the lines themselves and the terminating '/'.
FUNCTION NML_BUILD_TEXT(group, body, nbody) RESULT(buf)
    CHARACTER(LEN=*), INTENT(IN) :: group
    CHARACTER(LEN=*), INTENT(IN) :: body(:)
    INTEGER, INTENT(IN) :: nbody
    CHARACTER(LEN=:), ALLOCATABLE :: buf
    INTEGER :: j, l, n
    n = MIN(MAX(nbody, 0), SIZE(body))
    l = LEN_TRIM(group) + 8
    DO j = 1, n
        l = l + LEN_TRIM(body(j)) + 1
    END DO
    ALLOCATE(CHARACTER(LEN=l) :: buf)
    buf = '&'//TRIM(group)//ACHAR(10)
    DO j = 1, n
        buf = TRIM(buf)//TRIM(body(j))//ACHAR(10)
    END DO
    buf = TRIM(buf)//ACHAR(10)//'/'
END FUNCTION NML_BUILD_TEXT

!> .TRUE. if the first `nbody` lines of a group can be read as a namelist.
!! NOTE: such a read assigns the variables of the group (it is used by the
!! diagnostics only, on the error path, where the run stops right after).
LOGICAL FUNCTION NML_TEXT_OK(group, body, nbody)
    CHARACTER(LEN=*), INTENT(IN) :: group
    CHARACTER(LEN=*), INTENT(IN) :: body(:)
    INTEGER, INTENT(IN) :: nbody
    CHARACTER(LEN=:), ALLOCATABLE :: buf
    INTEGER :: rc
    buf = NML_BUILD_TEXT(group, body, nbody)
    IF (group == 'tebforcing') THEN
        READ(buf, nml=tebforcing, iostat=rc)
    ELSE
        READ(buf, nml=tebparam, iostat=rc)
    END IF
    DEALLOCATE(buf)
    NML_TEXT_OK = (rc <= 0)
END FUNCTION NML_TEXT_OK

!> First line of the group at which the READ fails (0 = the group reads completely).
!! Simple implementation: the group is read again from an internal file, cutting it
!! after each item (the items start at the lines that begin with an item name); the
!! first cut that cannot be read gives the failing line. The namelist reader reports
!! the error at that record or at the record just before it, so the diagnostic below
!! reports "from line N on" - the exact item is identified by the sentinel check for
!! the items that have one (the date/time items of /tebforcing/).
INTEGER FUNCTION NML_FIRST_FAIL_LINE(group, body, lineno, nb)
    CHARACTER(LEN=*), INTENT(IN) :: group
    CHARACTER(LEN=*), INTENT(IN) :: body(:)
    INTEGER, INTENT(IN) :: lineno(:), nb
    INTEGER, ALLOCATABLE :: ibeg(:)
    INTEGER :: nbeg, j, k
    NML_FIRST_FAIL_LINE = 0
    IF (nb < 1) RETURN
    IF (NML_TEXT_OK(group, body, nb)) RETURN      ! no failure
    ALLOCATE(ibeg(nb + 1))
    nbeg = 0
    DO j = 1, nb
        IF (NML_LINE_ASSIGNS(body(j))) THEN
            nbeg = nbeg + 1
            ibeg(nbeg) = j
        END IF
    END DO
    IF (nbeg == 0) RETURN
    ibeg(nbeg + 1) = nb + 1
    DO k = 1, nbeg
        IF (.NOT. NML_TEXT_OK(group, body, ibeg(k + 1) - 1)) THEN
            NML_FIRST_FAIL_LINE = lineno(ibeg(k))
            RETURN
        END IF
    END DO
END FUNCTION NML_FIRST_FAIL_LINE

!> Values of the items listed in nml_forcing_value_items (the INTEGER ones),
!! used by the diagnostic to detect an item that was not read (sentinel inml_unset)
FUNCTION NML_FORCING_VALUES() RESULT(v)
    INTEGER :: v(6)
    v(1) = teb_year
    v(2) = teb_month
    v(3) = teb_day
    v(4) = teb_hour
    v(5) = teb_min
    v(6) = nsteps
END FUNCTION NML_FORCING_VALUES

SUBROUTINE PRINT_USAGE()
    WRITE(*,*) ''
    WRITE(*,*) 'Usage: build/TEB_offline.exe [options]'
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
    WRITE(*,*) '  build/TEB_offline.exe'
    WRITE(*,*) '  build/TEB_offline.exe -forcing_nml my_forcing.nml -param_nml my_params.nml'
    WRITE(*,*) '  build/TEB_offline.exe -forcing_nml my_forcing.nml -output my_results/'
    WRITE(*,*) '  build/TEB_offline.exe -help'
    WRITE(*,*) ''
END SUBROUTINE PRINT_USAGE

!MV202609 garden emulation (teb_type_garden = 'EXT'/'EXT_NEU')
!> BOWEN emulator of an EXTERNAL garden for the control tree: in the 'EXT' mode
!! TEB_GARDEN reads the state and the fluxes of the garden from the coupling
!! interface (teb_ts_gd / teb_qs_gd / teb_shfl_gd / teb_lhfl_gd / teb_qvfl_gd /
!! teb_runoff_gd) instead of computing them with the internal proxy. Those
!! variables are PROGNOSTIC here: they are initialized once before the time loop
!! and updated by this subroutine at every model sub-step, right after TEB, so
!! that CALL_DRIVER (and the whole physics of TEB) only sees the 'EXT' interface
!! and is unaware of the difference with a real external model.
!!
!! The control tree has a single garden parameterization - the historical fixed
!! Bowen-ratio proxy of src_proxi_SVAT/garden.F90:
!!     Rn = (1 - 0.15)*SW_rec,   H = 0.2*Rn,   LE = 0.8*Rn,
!!     E = LE/XLVTT,   PHU = 0.8,   runoff = 0
!! The emulator applies exactly this proxy to the radiation that TEB has just
!! seen, reconstructed from the part it absorbed (the same reconstruction as in
!! the dev tree):
!!     XABS_SW = (1 - albedo)*SW_rec   ->   SW_rec = XABS_SW/(1 - albedo)
!! with XABS_SW = teb_sobs, the shortwave radiation absorbed by the garden that
!! TEB has computed with the prescribed surface temperature.
!!
!! The surface temperature prescribed to the external garden is the one the
!! internal proxy uses: TEB_VEG_PROPERTIES sets it to the air temperature of the
!! reference level, i.e. to the canyon air temperature (teb_tcanyon). The
!! prescribed surface humidity is the saturation humidity at the fixed 80 %
!! relative humidity of the proxy, so that the aggregation coefficient of the
!! EXT interface (PHU_AGG_GARDEN = qv/qsat) reproduces the 0.8 of the internal
!! proxy exactly. State and fluxes are applied with a one sub-step lag, as in
!! the dev tree.
!!
!! THIS IS A TEST / COUPLING TOOL, not a model: 'EXT' driven by this emulator
!! reproduces the internal 'PROXY_OLD' garden of the control tree, which is what
!! makes the EXT interface verifiable. A real external garden model replaces
!! this subroutine.
SUBROUTINE PCD_GARDEN
    REAL, DIMENSION(nvec) :: ZSW   ! solar radiation received by the garden (W/m2)
    !
    !* reference radiative temperature of the garden (see the header)
    teb_ts_gd(:) = teb_tcanyon(:)
    !* solar radiation received by the garden, from the part TEB absorbed
    ZSW(:) = 0.
    WHERE (1.-teb_alb_gd(:) > 1.E-6) ZSW(:) = teb_sobs(:) / (1.-teb_alb_gd(:))
    !* fixed Bowen-ratio proxy (albedo 0.15, H = 0.2*Rn, LE = 0.8*Rn)
    teb_shfl_gd(:)   = 0.2 * (1.-0.15) * ZSW(:)
    teb_lhfl_gd(:)   = 0.8 * (1.-0.15) * ZSW(:)
    teb_qvfl_gd(:)   = teb_lhfl_gd(:) / XLVTT
    teb_runoff_gd(:) = 0.
    !* surface humidity at the fixed 80 % relative humidity of the proxy
    teb_qs_gd(:) = 0.8 * QSAT(teb_ts_gd(:), ps(:))
END SUBROUTINE PCD_GARDEN

!MV202609 greenroof emulation (teb_type_greenroof = 'EXT'/'EXT_NEU')
!> Same emulator for the greenroof. A greenroof is a ROOF surface: it exchanges
!! with the air of the forcing level (temperature t, humidity qv) and receives
!! the CITY-LEVEL radiation - it is neither shadowed by the canyon nor irradiated
!! by its re-reflections - i.e. (dir + sca)*(1 - frac_panel), as in the dev tree.
!! The proxy of the control tree is
!!     Rn = (1 - 0.15)*SW_rec,   H = LE = 0.5*Rn,   E = LE/XLVTT,   runoff = 0.
SUBROUTINE PCD_GREENROOF
    REAL, DIMENSION(nvec) :: ZSW   ! solar radiation received by the greenroof (W/m2)
    !
    !* reference radiative temperature of the greenroof (air of the forcing level)
    teb_ts_gr(:) = t(:)
    !* city-level solar radiation of the roof (see the header)
    ZSW(:) = (swdir_s(:) + swdifd_s(:)) * (1.-teb_fr_panel(:))
    !* fixed Bowen-ratio proxy of the greenroof (albedo 0.15, H = LE = 0.5*Rn)
    teb_shfl_gr(:)   = 0.5 * (1.-0.15) * ZSW(:)
    teb_lhfl_gr(:)   = 0.5 * (1.-0.15) * ZSW(:)
    teb_qvfl_gr(:)   = teb_lhfl_gr(:) / XLVTT
    teb_runoff_gr(:) = 0.
END SUBROUTINE PCD_GREENROOF

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
