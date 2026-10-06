

MODULE sfc_teb



!------------------------------------------------------------------------------
! Public subroutines
!------------------------------------------------------------------------------

PUBLIC :: teb_interface

!------------------------------------------------------------------------------
! Parameters and variables which are global in this module
!------------------------------------------------------------------------------

CONTAINS

!==============================================================================
!! Computation of the first part of the soil parameterization scheme
!------------------------------------------------------------------------------

SUBROUTINE teb_interface (ntstep, nvec, iblock, dt, teb_year, teb_month, teb_day, teb_hour,         &
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
				teb_hvac_heat, teb_lgreenroof,  teb_frac_gr, teb_z0_gr, teb_alb_gr, teb_emis_gr, teb_ts_gr, teb_qs_gr,    &
				teb_shfl_gr, teb_lhfl_gr, teb_qvfl_gr, teb_runoff_gr, teb_lgarden, teb_z0_gd,       &
				teb_alb_gd, teb_emis_gd, teb_ts_gd, teb_qs_gd, teb_shfl_gd, teb_lhfl_gd,            &
				teb_qvfl_gd, teb_tch_gd, teb_tcm_gd, teb_runoff_gd, teb_itype_wind, teb_fai,        &
				teb_dqs_town, teb_gflux, teb_shfl_rf, teb_shfl_rd, teb_shfl_wl, teb_ac_rf,          &
				teb_ac_rd, teb_ac_wl, teb_ac_top, teb_tch_rf, teb_tch_rd, teb_tch_wl, teb_tch_top,  &
				teb_wind_top, teb_ustar_town, teb_cd_garden_atm, teb_ch_garden_atm, ahf_traffic_now,          &
				teb_rn_town, teb_wind_canyon, teb_tsroad, teb_type_garden, teb_type_greenroof, teb_lgreenroof_ext,      &
				teb_hroad_dir, teb_wall_opt, teb_road_dir, teb_zresidential, teb_dt_res, teb_dt_off,&
				teb_cap_sys_heat, teb_lsolar_panel, teb_fr_panel, teb_lroad_irrig,                  &
				teb_rd_irrig_start_m, teb_rd_irrig_end_m, teb_rd_irrig_start_h, teb_rd_irrig_end_h, &
				teb_rd_irrig_sum, teb_solar_prod, teb_utc_hour, teb_lshade,                         &
!MV202609 z0 and zd to namelist
				urb_z0_town, urb_zd_town,                         &
!MV202609 garden thermal roughness (z0h)
                urb_z0_o_z0h_gdn,                                 &
!MV202609 greenroof model type and thermal roughness
                urb_z0_o_z0h_grf,                                 &
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
                          PCD_ROAD_CAN, PCDN_ROAD_CAN, PRI_ROAD_CAN, ZZ0H_ROAD_CAN, &
                          PAC_ROAD_ATM, PCH_ROAD_ATM, PCD_ROAD_ATM, PCDN_ROAD_ATM, &
                          PRI_ROAD_ATM, ZZ0H_ROAD_ATM, PCDN_GARDEN_CAN, PRI_GARDEN_CAN, &
                          ZZ0H_GARDEN_CAN, PAC_GARDEN_ATM, PCDN_GARDEN_ATM, PRI_GARDEN_ATM, ZZ0H_GARDEN_ATM, &
                          PH_ROAD_CAN, PLE_ROAD_CAN, PH_ROAD_ATM, PLE_ROAD_ATM, &
!MV202609 CBS scheme of the road (revision: three-temperature construction)
                          PT_CAN0, PT_CAN1, PPHI_CAN1,                        &
!MV202609 CBS scheme of the road
                          PH_ROAD, PLE_ROAD, PAC_ROAD_WAT, PAC_ROAD_ATM_WAT, PDN_RD, LE_ROAD_WAT, LE_ROAD_SNOW, &
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
                          PDN_RF, LE_ROOF_WAT, LE_ROOF_SNOW, &
                          teb_lcbs_scheme,                   &
                          teb_tau_hw_thresh, teb_tau_hw_width,                  &
!MV202609 anthropogenic heat diagnostics
                          teb_lewaste,                        &
!MV202609 fixes of the snow melt / roof puddle water path (runoff diagnostics)
                          teb_runoff_road, teb_runoff_roof, &
!MV202609 garden diagnostics
                          teb_ts_garden, teb_rn_garden, teb_h_garden, teb_le_garden,       &
                          teb_evap_garden, teb_qsat_garden, teb_phu_garden,               &
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
                          teb_h_garden_can, teb_h_garden_atm,                             &
                          teb_le_garden_can, teb_le_garden_atm,                           &
                          teb_pac_garden,                                                 &
!MV202609 greenroof diagnostics
                          teb_ts_greenroof, teb_rn_greenroof, teb_h_greenroof, teb_le_greenroof, &
                          teb_evap_greenroof, teb_qsat_greenroof, teb_phu_greenroof,     &
                          teb_pac_greenroof, &
!MV202609 greenroof-to-atm exchange diagnostics
                          teb_pac_greenroof_atm, teb_pcd_greenroof_atm, teb_pcdn_greenroof_atm, &
                          teb_pch_greenroof_atm, teb_pri_greenroof_atm, teb_zz0h_greenroof_atm)

!-------------------------------------------------------------------------------
! Declarations
!-------------------------------------------------------------------------------
    INTEGER :: ntstep
	INTEGER :: nvec              ! array dimensions
	INTEGER :: ivstart                                       !IN optional start index                   ! ivstart
	INTEGER :: ivend                             !IN optional end   index                   ! ivend
	INTEGER :: iblock                                     !IN number of block
	INTEGER :: i
	REAL    :: dt             !IN integration timestep
	
	INTEGER                           :: &
									 teb_year           , &            ! current year
									 teb_month          , &            ! current month
									 teb_day            , &            ! current day
									 teb_hour           , &            ! current hour
									 teb_min            , &            ! current minutes
									 teb_sec
									 
	REAL,DIMENSION(1)     :: teb_hour_seconds								 
	REAL ,DIMENSION(nvec) :: lon_teb              				
	REAL ,DIMENSION(nvec) :: lat_teb  
	REAL ,DIMENSION(nvec) :: hlev_teb
    REAL ,DIMENSION(nvec) :: sa_uc       					!IN total impervious surface-area index  	
									 
									 
										 
	REAL ,DIMENSION(nvec) :: u              !IN zonal wind speed
	REAL ,DIMENSION(nvec) :: v              !IN meridional wind speed 
	REAL ,DIMENSION(nvec) :: t              !IN temperature                            (  K  )
	REAL ,DIMENSION(nvec) :: qv             !IN specific water vapor content           (kg/kg)
	REAL ,DIMENSION(nvec) :: ps             !IN surface pressure                       ( Pa  )
	REAL ,DIMENSION(nvec) :: rho            !IN air density                            ( kg/m3  )
	REAL ,DIMENSION(nvec) :: prr_con        !IN precipitation rate of rain, convective       (kg/m2*s)
	REAL ,DIMENSION(nvec) :: prs_con        !IN precipitation rate of snow, convective       (kg/m2*s)
	REAL ,DIMENSION(nvec) :: conv_frac      !IN convective area fraction
	REAL ,DIMENSION(nvec) :: prr_gsp        !IN precipitation rate of rain, grid-scale       (kg/m2*s)
	REAL ,DIMENSION(nvec) :: prs_gsp        !IN precipitation rate of snow, grid-scale       (kg/m2*s)
	REAL ,DIMENSION(nvec) :: prg_gsp        !IN precipitation rate of graupel, grid-scale    (kg/m2*s)
	REAL ,DIMENSION(nvec) :: prh_gsp        !IN precipitation rate of hail, grid-scale       (kg/m2*s)
	REAL ,DIMENSION(nvec) :: lwd_s          !IN downward comp. of long  wave rad. flux
	REAL ,DIMENSION(nvec) :: swdir_s        !IN direct comp. of solar radiative flux at surface 
	REAL ,DIMENSION(nvec) :: swdifd_s       !IN diffuse downward comp. of short wave rad. flux 
	
	REAL ,DIMENSION(nvec) :: teb_ti_bld       !IN diffuse downward comp. of short wave rad. flux 
	
	INTEGER :: teb_nwall_layer                             !IN optional end   index                   ! ivend
	INTEGER :: teb_nroof_layer                             !IN optional end   index                   ! ivend
	INTEGER :: teb_nroad_layer                             !IN optional end   index                   ! ivend
	INTEGER :: teb_nfloor_layer                             !IN optional end   index                   ! ivend
	
	REAL ,DIMENSION(nvec) :: urb_fr_bld                     !IN Building area fraction with respect to urban tile    (  -  )
	REAL ,DIMENSION(nvec) :: fr_garden                      !IN Garden area fraction with respect to urban tile    (  -  )
	REAL ,DIMENSION(nvec) :: urb_h2w                        !IN Street canyon H/W ratio   ( m/m )
	REAL ,DIMENSION(nvec) :: urb_h_bld                      !IN Building height  (  m  )
!MV202609 z0 and zd to namelist
	CHARACTER(LEN=16)     :: urb_z0_town                    !IN z0 of the urban surface (0.5 | 0.5m | 0.1H | H/3 | <name>)
	CHARACTER(LEN=16)     :: urb_zd_town                    !IN displacement height    (same forms as urb_z0_town)
!MV202609 garden thermal roughness (z0h)
	REAL                  :: urb_z0_o_z0h_gdn                !IN garden z0/z0h ratio (-)         ( >= 1 )
!MV202609 greenroof model type, thermal roughness and surface humidity
	REAL                  :: urb_z0_o_z0h_grf                !IN greenroof z0/z0h ratio (-)      ( >= 1 )
    CHARACTER(LEN=4)      :: teb_hroad_dir                  !IN road direction option :                      
                                                            ! 'UNIF' : uniform roads                       
                                                            ! 'ORIE' : specified road orientation          
    CHARACTER(LEN=4)      :: teb_wall_opt                   !IN Wall option                                  
                                                            ! 'UNIF' : uniform walls                       
									                        ! 'TWO ' : 2 opposite  walls
    REAL ,DIMENSION(nvec) :: teb_road_dir                   !IN road direction (° from North, clockwise)				
    

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
    REAL ,DIMENSION(nvec) :: ahf_traffic_now                !OUT Anthropogenic heat flux by traffic (current value)
	INTEGER               :: teb_utc_hour                   !IN Time zone for traffic daily cycle calculation                  
	
    CHARACTER(LEN=3)  :: teb_itype_bem  
    LOGICAL           :: teb_lbem_ac
	CHARACTER(LEN=4)  :: teb_itype_natvent
	CHARACTER(LEN=6)  :: teb_itype_bem_cool
	CHARACTER(LEN=6)  :: teb_itype_bem_heat
    REAL ,DIMENSION(nvec) :: teb_frac_gz
	REAL ,DIMENSION(nvec) :: teb_zresidential     !IN Fraction of residential use in buildings(-)
    REAL ,DIMENSION(nvec) :: teb_dt_res           !IN target temperature change when unoccupied (K) (residential buildings)                
    REAL ,DIMENSION(nvec) :: teb_dt_off           !IN target temperature change when unoccupied (K) (office buildings)                     
    REAL ,DIMENSION(nvec) :: teb_cap_sys_heat     !IN Capacity of the heating system [W m-2(bld)]
	
	LOGICAL  :: teb_lgreenroof
	LOGICAL  :: teb_lgreenroof_ext
	REAL ,DIMENSION(nvec) :: teb_frac_gr
    REAL ,DIMENSION(nvec) :: teb_z0_gr
REAL ,DIMENSION(nvec) :: teb_alb_gr
	REAL ,DIMENSION(nvec) :: teb_emis_gr
	REAL ,DIMENSION(nvec) :: teb_ts_gr
	REAL ,DIMENSION(nvec) :: teb_qs_gr
	REAL ,DIMENSION(nvec) :: teb_shfl_gr
	REAL ,DIMENSION(nvec) :: teb_lhfl_gr
	REAL ,DIMENSION(nvec) :: teb_qvfl_gr
	REAL ,DIMENSION(nvec) :: teb_runoff_gr

    LOGICAL  :: teb_lgarden
	CHARACTER(LEN=9) :: teb_type_garden
	CHARACTER(LEN=9) :: teb_type_greenroof
    REAL ,DIMENSION(nvec) :: teb_z0_gd
    REAL ,DIMENSION(nvec) :: teb_alb_gd
	REAL ,DIMENSION(nvec) :: teb_emis_gd
	REAL ,DIMENSION(nvec) :: teb_ts_gd
	REAL ,DIMENSION(nvec) :: teb_qs_gd
	REAL ,DIMENSION(nvec) :: teb_shfl_gd
	REAL ,DIMENSION(nvec) :: teb_lhfl_gd
	REAL ,DIMENSION(nvec) :: teb_qvfl_gd
	REAL ,DIMENSION(nvec) :: teb_tch_gd
	REAL ,DIMENSION(nvec) :: teb_tcm_gd
	REAL ,DIMENSION(nvec) :: teb_runoff_gd
	
	LOGICAL :: teb_lshade
	
	INTEGER  :: teb_itype_wind
	REAL ,DIMENSION(nvec, 1:8) :: teb_fai 
	
    LOGICAL  :: teb_lsolar_panel
    REAL ,DIMENSION(nvec) :: teb_fr_panel

    LOGICAL  :: teb_lroad_irrig
    REAL ,DIMENSION(nvec) :: teb_rd_irrig_start_m
	REAL ,DIMENSION(nvec) :: teb_rd_irrig_end_m
	REAL ,DIMENSION(nvec) :: teb_rd_irrig_start_h
	REAL ,DIMENSION(nvec) :: teb_rd_irrig_end_h
	REAL ,DIMENSION(nvec) :: teb_rd_irrig_sum

	REAL ,DIMENSION(nvec, 1:teb_nroof_layer) :: teb_troof 
	REAL ,DIMENSION(nvec, 1:teb_nroad_layer) :: teb_troad_now	
	REAL ,DIMENSION(nvec, 1:teb_nroad_layer) :: teb_troad
	REAL ,DIMENSION(nvec, 1:teb_nwall_layer) :: teb_twalla  
	REAL ,DIMENSION(nvec, 1:teb_nwall_layer) :: teb_twallb  
	REAL ,DIMENSION(nvec, 1:teb_nfloor_layer) :: teb_tfloor  
	REAL ,DIMENSION(nvec, 1:teb_nfloor_layer) :: teb_tmass  
	REAL,DIMENSION(nvec) :: teb_qi_bld
	REAL,DIMENSION(nvec) :: teb_tcanyon
	REAL,DIMENSION(nvec) :: teb_qcanyon
	REAL,DIMENSION(nvec) :: teb_ucanyon
	REAL,DIMENSION(nvec) :: teb_vcanyon
	REAL,DIMENSION(nvec) :: teb_sobs
	REAL,DIMENSION(nvec) :: teb_thbs
	
	REAL ,DIMENSION(nvec) :: teb_ws_roof        ! roof water content (kg/m2) 
	REAL ,DIMENSION(nvec) :: teb_ws_road        ! road water content (kg/m2) 
	REAL ,DIMENSION(nvec, 1) :: teb_wsnow_roof
	REAL ,DIMENSION(nvec, 1) :: teb_wsnow_road
	REAL ,DIMENSION(nvec, 1) :: teb_tsnow_roof
	REAL ,DIMENSION(nvec, 1) :: teb_tsnow_road
	REAL ,DIMENSION(nvec, 1) :: teb_rsnow_roof
	REAL ,DIMENSION(nvec, 1) :: teb_rsnow_road
	REAL ,DIMENSION(nvec) :: teb_tssnow_roof
	REAL ,DIMENSION(nvec) :: teb_tssnow_road
	REAL ,DIMENSION(nvec) :: teb_asnow_roof
	REAL ,DIMENSION(nvec) :: teb_asnow_road
	REAL ,DIMENSION(nvec) :: teb_esnow_roof
	REAL ,DIMENSION(nvec) :: teb_esnow_road
	REAL ,DIMENSION(nvec) :: teb_twin1
	REAL ,DIMENSION(nvec) :: teb_twin2
	REAL ,DIMENSION(nvec) :: teb_albwin
	REAL ,DIMENSION(nvec) :: teb_cap_sys_rat
	REAL ,DIMENSION(nvec) :: teb_m_sys_rat
	LOGICAL ,DIMENSION(nvec) :: teb_shad_day
	LOGICAL ,DIMENSION(nvec) :: teb_natvent_night
	REAL ,DIMENSION(nvec) :: teb_tstown_s_now
	REAL ,DIMENSION(nvec) :: teb_tstown_s
	REAL ,DIMENSION(nvec) :: teb_qstown_s
	REAL ,DIMENSION(nvec) :: teb_wstown_now
	REAL ,DIMENSION(nvec) :: teb_wstown
	REAL ,DIMENSION(nvec) :: teb_runoff_town
!MV202609 fixes of the snow melt / roof puddle water path (runoff diagnostics)
REAL ,DIMENSION(nvec) :: teb_runoff_road
REAL ,DIMENSION(nvec) :: teb_runoff_roof
	REAL ,DIMENSION(nvec) :: teb_tssnow_town_now
	REAL ,DIMENSION(nvec) :: teb_tssnow_town
	REAL ,DIMENSION(nvec) :: teb_wsnow_town_now
	REAL ,DIMENSION(nvec) :: teb_wsnow_town
	REAL ,DIMENSION(nvec) :: teb_rsnow_town_now
	REAL ,DIMENSION(nvec) :: teb_rsnow_town
	REAL ,DIMENSION(nvec) :: teb_tch_town
	REAL ,DIMENSION(nvec) :: teb_frsnow
	REAL ,DIMENSION(nvec) :: teb_snow_melt	
	REAL ,DIMENSION(nvec) :: teb_hsnow_town_now
	REAL ,DIMENSION(nvec) :: teb_hsnow_town
	
	
	REAL ,DIMENSION(nvec) :: teb_tsroof       !OUT roof surface temperature [K] 
	REAL ,DIMENSION(nvec) :: teb_tswalla      !OUT walla surface temperature [K] 
	REAL ,DIMENSION(nvec) :: teb_tswallb      !OUT wallb surface temperature [K] 
	REAL ,DIMENSION(nvec) :: teb_shfl  		  !OUT sensible heat flux over town	
	REAL ,DIMENSION(nvec) :: teb_lhfl   	  !OUT latent heat flux over town  
	REAL ,DIMENSION(nvec) :: teb_qvfl   	  !OUT town evaporation (kg/m2/s)
	REAL ,DIMENSION(nvec) :: teb_shfl_snow    !OUT sensible heat flux over snow	
	REAL ,DIMENSION(nvec) :: teb_lhfl_snow    !OUT latent heat flux over snow
	REAL ,DIMENSION(nvec) :: teb_alb_so
	REAL ,DIMENSION(nvec) :: teb_alb_th
	REAL ,DIMENSION(nvec) :: teb_hwaste
	REAL ,DIMENSION(nvec) :: teb_hvac_cool
	REAL ,DIMENSION(nvec) :: teb_hvac_heat
	REAL ,DIMENSION(nvec) :: teb_tcool_target
	REAL ,DIMENSION(nvec) :: teb_theat_target
	REAL ,DIMENSION(nvec) :: teb_bem_vent
	REAL ,DIMENSION(nvec) :: teb_bem_inf
	REAL ,DIMENSION(nvec) :: teb_bem_cop
	
	REAL ,DIMENSION(nvec) :: teb_dqs_town
	REAL ,DIMENSION(nvec) :: teb_gflux
	REAL ,DIMENSION(nvec) :: teb_shfl_rf
	REAL ,DIMENSION(nvec) :: teb_shfl_rd
	REAL ,DIMENSION(nvec) :: teb_shfl_wl
	REAL ,DIMENSION(nvec) :: teb_ac_rf
	REAL ,DIMENSION(nvec) :: teb_ac_rd
	REAL ,DIMENSION(nvec) :: teb_ac_wl
	REAL ,DIMENSION(nvec) :: teb_ac_top
	REAL ,DIMENSION(nvec) :: teb_tch_rd
	REAL ,DIMENSION(nvec) :: teb_tch_rf
	REAL ,DIMENSION(nvec) :: teb_tch_wl
	REAL ,DIMENSION(nvec) :: teb_tch_top
	REAL ,DIMENSION(nvec) :: teb_wind_top
	REAL ,DIMENSION(nvec) :: teb_ustar_town
	REAL ,DIMENSION(nvec) :: teb_cd_garden_atm
	REAL ,DIMENSION(nvec) :: teb_ch_garden_atm
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
REAL, DIMENSION(:), INTENT(OUT)   :: PCD_ROAD_CAN     ! road   drag coefficient (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN_ROAD_CAN    ! road   neutral drag coefficient (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_ROAD_CAN     ! road   Richardson number (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: ZZ0H_ROAD_CAN    ! road   roughness length for heat (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROAD_ATM     ! road   aerodynamical conductance (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_ROAD_ATM     ! road   drag coefficient for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCD_ROAD_ATM     ! road   drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN_ROAD_ATM    ! road   neutral drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_ROAD_ATM     ! road   Richardson number (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: ZZ0H_ROAD_ATM    ! road   roughness length for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN_GARDEN_CAN  ! garden neutral drag coefficient (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_GARDEN_CAN   ! garden Richardson number (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: ZZ0H_GARDEN_CAN  ! garden roughness length for heat (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_GARDEN_ATM   ! garden aerodynamical conductance (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN_GARDEN_ATM  ! garden neutral drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_GARDEN_ATM   ! garden Richardson number (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: ZZ0H_GARDEN_ATM  ! garden roughness length for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PH_ROAD_CAN      ! road sensible heat flux, road -> canyon air [W m-2]
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_ROAD_CAN     ! road latent heat flux, road -> canyon air [W m-2]
REAL, DIMENSION(:), INTENT(OUT)   :: PH_ROAD_ATM      ! road sensible heat flux, road -> forcing level [W m-2]
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_ROAD_ATM     ! road latent heat flux, road -> forcing level [W m-2]
!MV202609 CBS scheme of the road (revision: three-temperature construction)
REAL, DIMENSION(:), INTENT(OUT)   :: PT_CAN0          ! canyon air temperature without tau [K]
REAL, DIMENSION(:), INTENT(OUT)   :: PT_CAN1          ! free layer (second canopy) air temperature [K]
REAL, DIMENSION(:), INTENT(OUT)   :: PPHI_CAN1        ! free layer air temperature / theta* ratio of the MOST profile [-]
!MV202609 CBS scheme of the road
REAL, DIMENSION(:), INTENT(OUT)   :: PH_ROAD          ! road sensible heat flux, CBS scheme [W m-2]
!MV202609 anthropogenic heat diagnostics
REAL, DIMENSION(:), INTENT(OUT)   :: teb_lewaste       ! latent waste heat of the buildings [W m-2]
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_ROAD         ! road latent heat flux, CBS scheme [W m-2]
!MV202609 CBS scheme of the road (revision: puddle diagnostics)
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROAD_WAT     ! road water conductance (canyon, water-limited)
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROAD_ATM_WAT ! road water conductance (forcing level, water-limited)
REAL, DIMENSION(:), INTENT(OUT)   :: PDN_RD           ! road snow fraction (-)
REAL, DIMENSION(:), INTENT(OUT)   :: LE_ROAD_WAT      ! road latent heat flux of the snow-free road (W/m2 road)
REAL, DIMENSION(:), INTENT(OUT)   :: LE_ROAD_SNOW     ! road latent heat flux of the snow-covered road (W/m2 road)
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
REAL, DIMENSION(:), INTENT(OUT)   :: PDN_RF           ! roof snow fraction (-)
REAL, DIMENSION(:), INTENT(OUT)   :: LE_ROOF_WAT      ! roof latent heat flux of the snow-free roof (W/m2 roof)
REAL, DIMENSION(:), INTENT(OUT)   :: LE_ROOF_SNOW     ! roof latent heat flux of the snow-covered roof (W/m2 roof)
!MV202609 garden diagnostics
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_ts_garden    ! garden surface temperature (K)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_rn_garden    ! net radiation over the garden (W/m2 garden)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_h_garden     ! sensible heat flux over the garden (W/m2 garden)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_le_garden    ! latent heat flux over the garden (W/m2 garden)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_evap_garden  ! total evaporation over the garden (kg/m2/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_qsat_garden  ! garden saturation specific humidity (kg/kg)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_phu_garden   ! garden aggregated relative humidity (-)
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_h_garden_can  ! garden sensible heat flux, garden -> canyon air (W/m2 garden)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_h_garden_atm  ! garden sensible heat flux, garden -> forcing level (W/m2 garden)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_le_garden_can ! garden latent  heat flux, garden -> canyon air (W/m2 garden)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_le_garden_atm ! garden latent  heat flux, garden -> forcing level (W/m2 garden)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_pac_garden   ! garden aerodynamic conductance (m/s)
!MV202609 greenroof diagnostics
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_ts_greenroof   ! greenroof surface temperature (K)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_rn_greenroof   ! net radiation over the greenroof (W/m2 greenroof)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_h_greenroof    ! sensible heat flux over the greenroof (W/m2 greenroof)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_le_greenroof   ! latent heat flux over the greenroof (W/m2 greenroof)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_evap_greenroof ! total evaporation over the greenroof (kg/m2/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_qsat_greenroof ! greenroof saturation specific humidity (kg/kg)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_phu_greenroof  ! greenroof aggregated relative humidity (-)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_pac_greenroof    ! green roof conductance (m/s)
!MV202609 greenroof-to-atm exchange diagnostics (from URBAN_DRAG)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_pac_greenroof_atm  ! greenroof aerodynamical conductance (atm.)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_pcd_greenroof_atm  ! greenroof drag coefficient (atm.)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_pcdn_greenroof_atm ! greenroof neutral drag coefficient (atm.)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_pch_greenroof_atm  ! greenroof drag coefficient for heat (atm.)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_pri_greenroof_atm  ! greenroof Richardson number (atm.)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_zz0h_greenroof_atm ! greenroof roughness length for heat (atm.)
LOGICAL,              INTENT(IN)  :: teb_lcbs_scheme  ! flag to use the CBS scheme for the road
REAL,                 INTENT(IN)  :: teb_tau_hw_thresh! H/W giving tau = 0.5 (CBS scheme)
REAL,                 INTENT(IN)  :: teb_tau_hw_width ! width of the tanh relaxation (CBS scheme)
	REAL ,DIMENSION(nvec) :: teb_rn_town
	REAL ,DIMENSION(nvec) :: teb_wind_canyon
	REAL ,DIMENSION(nvec) :: teb_tsroad
	REAL ,DIMENSION(nvec) :: teb_solar_prod


!------------------------------------------------------------------------------
! Begin Subroutine teb_interface
!------------------------------------------------------------------------------
    
	DO i = ivstart, ivend
		CALL CALL_DRIVER (ntstep, i, iblock, dt, teb_year, teb_month, teb_day, teb_hour,                                &
		        teb_min, teb_sec, teb_hour_seconds, sa_uc(i), lon_teb(i), lat_teb(i), hlev_teb(i),                      &
		        u(i), v(i), t(i), qv(i), ps(i), rho(i), prr_con(i), prs_con(i), prr_gsp(i), prs_gsp(i), prg_gsp(i),     &
				lwd_s(i), swdir_s(i), swdifd_s(i), teb_nroof_layer, teb_nroad_layer, teb_nwall_layer,                   &
				teb_nfloor_layer, urb_fr_bld(i), fr_garden(i), urb_h2w(i), urb_h_bld(i), urb_hcap_rd(i),                &
				urb_hcap_rf(i), urb_hcap_wl(i), urb_hcon_rd(i), urb_hcon_rf(i), urb_hcon_wl(i), urb_alb_rd_so(i),       &
				urb_alb_rf_so(i), urb_alb_wl_so(i), 1 - urb_alb_rd_th(i), 1-urb_alb_rf_th(i), 1-urb_alb_wl_th(i),       &
				ahf_traffic(i), ahf_industry(i), teb_ti_bld(i), teb_troof(i,:), teb_troad_now(i,:), teb_troad(i,:),     &
				teb_twalla(i,:), teb_twallb(i,:), teb_tfloor(i,:), teb_tmass(i,:), teb_qi_bld(i), teb_tcanyon(i),       &
				teb_qcanyon(i),  teb_ucanyon(i), teb_vcanyon(i), teb_sobs(i), teb_thbs(i), teb_ws_roof(i),              &
				teb_ws_road(i), teb_wsnow_roof(i,:), teb_wsnow_road(i,:), teb_tsnow_roof(i,:), teb_tsnow_road(i,:),     &
				teb_rsnow_roof(i,:), teb_rsnow_road(i,:), teb_tssnow_roof(i), teb_tssnow_road(i), teb_asnow_roof(i),    &
				teb_asnow_road(i), teb_esnow_roof(i), teb_esnow_road(i), teb_twin1(i), teb_twin2(i), teb_albwin(i),     &
				teb_tsroof(i), teb_tswalla(i), teb_tswallb(i), teb_shfl(i), teb_lhfl(i), teb_tstown_s_now(i),           &
				teb_tstown_s(i), teb_qstown_s(i), teb_wstown_now(i), teb_wstown(i), teb_runoff_town(i),                 &
				teb_tssnow_town_now(i), teb_tssnow_town(i), teb_wsnow_town_now(i), teb_wsnow_town(i),                   &
				teb_rsnow_town_now(i), teb_rsnow_town(i), teb_tch_town(i), teb_qvfl(i), teb_shfl_snow(i),               &
				teb_lhfl_snow(i), teb_frsnow(i), teb_snow_melt(i), teb_hsnow_town_now(i), teb_hsnow_town(i),            &
				teb_alb_so(i), teb_alb_th(i), teb_itype_bem, teb_lbem_ac, teb_itype_natvent,                            &
				teb_itype_bem_cool, teb_itype_bem_heat, teb_frac_gz(i), teb_tcool_target(i),                            &
				teb_theat_target(i), teb_bem_vent(i), teb_bem_inf(i), teb_bem_cop(i), teb_cap_sys_rat(i),               &
				teb_m_sys_rat(i), teb_shad_day(i), teb_natvent_night(i), teb_hwaste(i), teb_hvac_cool(i),               &
				teb_hvac_heat(i), teb_lgreenroof, teb_frac_gr(i), teb_z0_gr(i), teb_alb_gr(i), teb_emis_gr(i), teb_ts_gr(i), teb_qs_gr(i),          &
				teb_shfl_gr(i), teb_lhfl_gr(i), teb_qvfl_gr(i), teb_runoff_gr(i), teb_lgarden, teb_z0_gd(i),            &
				teb_alb_gd(i), teb_emis_gd(i), teb_ts_gd(i), teb_qs_gd(i), teb_shfl_gd(i), teb_lhfl_gd(i),              &
				teb_qvfl_gd(i), teb_tch_gd(i), teb_tcm_gd(i), teb_runoff_gd(i), teb_itype_wind, teb_fai(i,:),           &
				teb_dqs_town(i), teb_gflux(i), teb_shfl_rf(i), teb_shfl_rd(i), teb_shfl_wl(i), teb_ac_rf(i),            &
				teb_ac_rd(i), teb_ac_wl(i), teb_ac_top(i), teb_tch_rf(i), teb_tch_rd(i), teb_tch_wl(i), teb_tch_top(i), &
				teb_wind_top(i), teb_ustar_town(i), teb_cd_garden_atm(i), teb_ch_garden_atm(i), ahf_traffic_now(i),               &
				teb_rn_town(i), teb_wind_canyon(i), teb_tsroad(i), teb_type_garden, teb_type_greenroof, teb_lgreenroof_ext, teb_hroad_dir,  &
				teb_wall_opt, teb_road_dir(i), teb_zresidential(i), teb_dt_res(i), teb_dt_off(i), teb_cap_sys_heat(i),  &
				teb_lsolar_panel, teb_fr_panel(i), teb_lroad_irrig, teb_rd_irrig_start_m(i), teb_rd_irrig_end_m(i),     &
				teb_rd_irrig_start_h(i), teb_rd_irrig_end_h(i), teb_rd_irrig_sum(i), teb_solar_prod(i), teb_utc_hour,   &
				teb_lshade,                                                                       &
!MV202609 z0 and zd to namelist
				urb_z0_town, urb_zd_town,                         &
!MV202609 garden thermal roughness (z0h)
                urb_z0_o_z0h_gdn,                                 &
!MV202609 greenroof model type and thermal roughness
                urb_z0_o_z0h_grf,                                 &
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
                          PCD_ROAD_CAN(i), PCDN_ROAD_CAN(i), PRI_ROAD_CAN(i), ZZ0H_ROAD_CAN(i), &
                          PAC_ROAD_ATM(i), PCH_ROAD_ATM(i), PCD_ROAD_ATM(i), PCDN_ROAD_ATM(i), &
                          PRI_ROAD_ATM(i), ZZ0H_ROAD_ATM(i), PCDN_GARDEN_CAN(i), PRI_GARDEN_CAN(i), &
                          ZZ0H_GARDEN_CAN(i), PAC_GARDEN_ATM(i), PCDN_GARDEN_ATM(i), PRI_GARDEN_ATM(i), ZZ0H_GARDEN_ATM(i), &
                          PH_ROAD_CAN(i), PLE_ROAD_CAN(i), PH_ROAD_ATM(i), PLE_ROAD_ATM(i), &
!MV202609 CBS scheme of the road (revision: three-temperature construction)
                          PT_CAN0(i), PT_CAN1(i), PPHI_CAN1(i),                            &
!MV202609 CBS scheme of the road
                          PH_ROAD(i), PLE_ROAD(i), PAC_ROAD_WAT(i), PAC_ROAD_ATM_WAT(i), PDN_RD(i), LE_ROAD_WAT(i), LE_ROAD_SNOW(i), &
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
                          PDN_RF(i), LE_ROOF_WAT(i), LE_ROOF_SNOW(i), &
                          teb_lcbs_scheme,                        &
                          teb_tau_hw_thresh, teb_tau_hw_width,                             &
!MV202609 anthropogenic heat diagnostics
                          teb_lewaste(i),                        &
!MV202609 fixes of the snow melt / roof puddle water path (runoff diagnostics)
                          teb_runoff_road(i), teb_runoff_roof(i), &
!MV202609 garden diagnostics
                          teb_ts_garden(i), teb_rn_garden(i), teb_h_garden(i), teb_le_garden(i), &
                          teb_evap_garden(i), teb_qsat_garden(i), teb_phu_garden(i),            &
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
                          teb_h_garden_can(i), teb_h_garden_atm(i),                             &
                          teb_le_garden_can(i), teb_le_garden_atm(i),                           &
                          teb_pac_garden(i),                                                   &
!MV202609 greenroof diagnostics
                          teb_ts_greenroof(i), teb_rn_greenroof(i), teb_h_greenroof(i), teb_le_greenroof(i), &
                          teb_evap_greenroof(i), teb_qsat_greenroof(i), teb_phu_greenroof(i),  &
                          teb_pac_greenroof(i), &
!MV202609 greenroof-to-atm exchange diagnostics
                          teb_pac_greenroof_atm(i), teb_pcd_greenroof_atm(i), teb_pcdn_greenroof_atm(i), &
                          teb_pch_greenroof_atm(i), teb_pri_greenroof_atm(i), teb_zz0h_greenroof_atm(i))
	END DO
	
END SUBROUTINE teb_interface

END MODULE sfc_teb