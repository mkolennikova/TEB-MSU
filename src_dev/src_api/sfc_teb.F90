

MODULE sfc_teb



!------------------------------------------------------------------------------
! Public subroutines
!------------------------------------------------------------------------------

!MV202609 explicit interface of the host-model adapter
!* CALL_DRIVER is a module procedure now (see the wrapper in call_driver.F90), so
!* the compiler checks the arguments of the call below instead of accepting an
!* implicit interface; IMPLICIT NONE closes the door to a silently created
!* variable when an identifier is misspelled.
USE MODI_CALL_DRIVER, ONLY : CALL_DRIVER
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE TEB_HOST, ONLY : TEB_FILL_PARAMS, TEB_FILL_DERIVED, TEB_HOST_ENSURE, TOP, TP, BOP, BP, TSTATE, BSTATE, TPN, TIR, DMT, TEB_BIND_STATE, TEB_UNBIND_STATE
USE TEB_LOG,  ONLY : TEB_LOG_SET_FILTER, TEB_LOG_AT_CADENCE, TEB_LOG_EMIT
IMPLICIT NONE

PUBLIC :: teb_interface

!------------------------------------------------------------------------------
! Parameters and variables which are global in this module
!------------------------------------------------------------------------------

CONTAINS

!==============================================================================
!! Computation of the first part of the soil parameterization scheme
!------------------------------------------------------------------------------

SUBROUTINE teb_interface (ntstep, nvec, iblock, dt, teb_year, teb_month, teb_day, teb_hour, teb_min, &
                 teb_sec, teb_hour_seconds, sa_uc, lon_teb, lat_teb, &
                 hlev_teb, ivstart, ivend, u, v, t, qv, ps, rho, prr_con, &
                 prs_con, prr_gsp, prs_gsp, prg_gsp, lwd_s, swdir_s, &
                 swdifd_s, teb_nroof_layer, teb_nroad_layer, teb_nwall_layer, &
                 teb_nfloor_layer, urb_fr_bld, fr_garden, urb_h2w, urb_h_bld, &
                 urb_hcap_rd, urb_hcap_rf, urb_hcap_wl, urb_hcon_rd, &
                 urb_hcon_rf, urb_hcon_wl, urb_alb_rd_so, urb_alb_rf_so, &
                 urb_alb_wl_so, urb_alb_rd_th, urb_alb_rf_th, urb_alb_wl_th, &
                 ahf_traffic, ahf_industry, teb_ti_bld, teb_troof, &
                 teb_troad, teb_twalla, teb_twallb, &
                 teb_tfloor, teb_tmass, teb_qi_bld, teb_tcanyon, teb_qcanyon, &
                 teb_ws_roof, teb_ws_road, teb_wsnow_roof, teb_wsnow_road, &
                 teb_tsnow_roof, teb_tsnow_road, teb_rsnow_roof, &
                 teb_rsnow_road, teb_tssnow_roof, teb_tssnow_road, &
                 teb_asnow_roof, teb_asnow_road, teb_esnow_roof, &
                 teb_esnow_road, teb_twin1, teb_twin2, teb_albwin, &
                 teb_itype_bem, teb_lbem_ac, teb_itype_natvent, &
                 teb_itype_bem_cool, teb_itype_bem_heat, teb_frac_gz, &
                 teb_tcool_target, teb_theat_target, teb_bem_vent, &
                 teb_bem_inf, teb_bem_cop, teb_cap_sys_rat, teb_m_sys_rat, &
                 teb_shad_day, teb_natvent_night, teb_lgreenroof, &
                 teb_frac_gr, teb_z0_gr, teb_alb_gr, teb_emis_gr, teb_ts_gr, &
                 teb_qs_gr, teb_shfl_gr, teb_lhfl_gr, teb_qvfl_gr, &
                 teb_runoff_gr, teb_lgarden, teb_z0_gd, teb_alb_gd, &
                 teb_emis_gd, teb_ts_gd, teb_qs_gd, teb_shfl_gd, teb_lhfl_gd, &
                 teb_qvfl_gd, teb_tch_gd, teb_tcm_gd, teb_runoff_gd, &
                 teb_itype_wind, teb_fai, teb_type_garden, &
                 teb_type_greenroof, teb_lgreenroof_ext, teb_hroad_dir, &
                 teb_wall_opt, teb_road_dir, teb_zresidential, teb_dt_res, &
                 teb_dt_off, teb_cap_sys_heat, teb_lsolar_panel, &
                 teb_fr_panel, teb_lroad_irrig, teb_rd_irrig_start_m, &
                 teb_rd_irrig_end_m, teb_rd_irrig_start_h, &
                 teb_rd_irrig_end_h, teb_rd_irrig_sum, teb_utc_hour, &
                 teb_lshade, urb_z0_town, urb_zd_town, urb_z0_o_z0h_gdn, &
                 urb_z0_o_z0h_grf, teb_lcbs_scheme, teb_tau_hw_thresh, &
                 teb_tau_hw_width, teb_wind_canyon, teb_sobs, teb_thbs, teb_runoff_road, teb_runoff_roof, kteb_log_block, &
                 kteb_log_point)
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_PARAMS_n, ONLY : TEB_PARAMS_t
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t

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
		REAL ,DIMENSION(nvec, 1:teb_nroad_layer) :: teb_troad
	REAL ,DIMENSION(nvec, 1:teb_nwall_layer) :: teb_twalla  
	REAL ,DIMENSION(nvec, 1:teb_nwall_layer) :: teb_twallb  
	REAL ,DIMENSION(nvec, 1:teb_nfloor_layer) :: teb_tfloor  
	REAL ,DIMENSION(nvec, 1:teb_nfloor_layer) :: teb_tmass  
	REAL,DIMENSION(nvec) :: teb_qi_bld
	REAL,DIMENSION(nvec) :: teb_tcanyon
	REAL,DIMENSION(nvec) :: teb_qcanyon
	
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
!MV202609 fixes of the snow melt / roof puddle water path (runoff diagnostics)
	
	
	REAL ,DIMENSION(nvec) :: teb_tcool_target
	REAL ,DIMENSION(nvec) :: teb_theat_target
	REAL ,DIMENSION(nvec) :: teb_bem_vent
	REAL ,DIMENSION(nvec) :: teb_bem_inf
	REAL ,DIMENSION(nvec) :: teb_bem_cop
	
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!MV202609 CBS scheme of the road (revision: three-temperature construction)
!MV202609 CBS scheme of the road
!MV202609 anthropogenic heat diagnostics
!MV202609 CBS scheme of the road (revision: puddle diagnostics)
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
!MV202609 garden diagnostics
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
!MV202609 greenroof diagnostics
!MV202609 greenroof-to-atm exchange diagnostics (from URBAN_DRAG)
LOGICAL,              INTENT(IN)  :: teb_lcbs_scheme  ! flag to use the CBS scheme for the road
REAL,                 INTENT(IN)  :: teb_tau_hw_thresh! H/W giving tau = 0.5 (CBS scheme)
REAL,                 INTENT(IN)  :: teb_tau_hw_width ! width of the tanh relaxation (CBS scheme)
!MV202610 emulator inputs as individual fields (no structures across the boundary)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_wind_canyon   ! canyon wind (m/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_sobs         ! solar radiation absorbed by the ground (W/m2)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_thbs         ! thermal radiation absorbed by the ground (W/m2)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_runoff_road  ! road runoff of this sub-step (kg/m2/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_runoff_roof  ! roof runoff of this sub-step (kg/m2/s)
!* MV202610 blocks and points for which the text output is written;
!* in the coupled model both lists are empty by default (no filter).
INTEGER, DIMENSION(:), INTENT(IN) :: KTEB_LOG_BLOCK   ! blocks to write
INTEGER, DIMENSION(:), INTENT(IN) :: KTEB_LOG_POINT   ! points to write


!------------------------------------------------------------------------------
! Begin Subroutine teb_interface
!------------------------------------------------------------------------------
    
    !MV202610 selection of the blocks/points of the text output (empty: no filter)
    CALL TEB_LOG_SET_FILTER(KTEB_LOG_BLOCK, KTEB_LOG_POINT)
    !MV202610 the containers are declared and allocated here (one set per thread)
    CALL TEB_HOST_ENSURE(nvec, teb_nroof_layer, teb_nroad_layer, teb_nwall_layer, teb_nfloor_layer)
    !MV202610 parameter containers are filled here, where the configuration is known
    CALL TEB_FILL_PARAMS (ivstart, &
                 ivend, teb_itype_bem_cool, teb_itype_bem_heat, teb_tcool_target, teb_theat_target, &
                 teb_frac_gz, teb_bem_inf, teb_bem_vent, teb_cap_sys_heat, teb_bem_cop, &
                 teb_itype_natvent, teb_lgarden, teb_hroad_dir, teb_wall_opt, teb_itype_bem, &
                 teb_lgreenroof, teb_type_garden, teb_type_greenroof, teb_lsolar_panel, teb_lcbs_scheme, &
                 teb_tau_hw_thresh, teb_tau_hw_width, urb_z0_o_z0h_gdn, urb_z0_o_z0h_grf, teb_road_dir, &
                 fr_garden, teb_frac_gr, urb_fr_bld, urb_h2w, urb_h_bld, &
                 urb_alb_rf_so, urb_alb_rd_so, urb_alb_wl_so, urb_alb_rd_th, urb_alb_rf_th, &
                 urb_alb_wl_th, teb_zresidential, teb_dt_res, teb_dt_off, ahf_industry, &
                  teb_itype_wind, teb_utc_hour, teb_lgreenroof_ext, teb_lbem_ac)
    !MV202610 derived statics: layer profiles, geometry, SVF, z0/zd, BEM constants
    CALL TEB_FILL_DERIVED (ivstart, ivend, urb_z0_town, urb_zd_town, &
                  urb_hcap_rd, urb_hcap_rf, urb_hcap_wl, &
                  urb_hcon_rd, urb_hcon_rf, urb_hcon_wl, &
                  ahf_traffic, teb_fai)
    CALL TEB_BIND_STATE (ivstart, ivend, &
                 teb_ti_bld, &
                 teb_twin2, &
                 teb_qi_bld, &
                 teb_cap_sys_rat, &
                 teb_m_sys_rat, &
                 teb_twin1, &
                                  teb_lshade, &
                 teb_shad_day, &
                 teb_natvent_night, &
                 teb_ws_roof, &
                 teb_troof, &
                 teb_troad, &
                 teb_twalla, &
                 teb_twallb, &
                 teb_wsnow_roof, &
                 teb_tsnow_roof, &
                 teb_rsnow_roof, &
                 teb_asnow_roof, &
                 teb_esnow_roof, &
                 teb_tssnow_roof, &
                 teb_wsnow_road, &
                 teb_tsnow_road, &
                 teb_rsnow_road, &
                 teb_asnow_road, &
                 teb_esnow_road, &
                 teb_tssnow_road, &
                  teb_tcanyon, &
                  teb_qcanyon, &
                  teb_ws_road, &
                  teb_tfloor, &
                  teb_tmass)
	DO i = ivstart, ivend
		CALL CALL_DRIVER (ntstep, i, iblock, dt, teb_year, teb_month, teb_day, teb_hour, teb_min, &
                 teb_sec, teb_hour_seconds(1), sa_uc(i), lon_teb(i), lat_teb(i), hlev_teb(i), &
                 u(i), v(i), t(i), qv(i), ps(i), prr_con(i), prs_con(i), prr_gsp(i), &
                 prs_gsp(i), prg_gsp(i), lwd_s(i), swdir_s(i), swdifd_s(i), teb_z0_gr(i), &
                 teb_alb_gr(i), teb_emis_gr(i), teb_ts_gr(i), teb_qs_gr(i), teb_shfl_gr(i), &
                 teb_lhfl_gr(i), teb_qvfl_gr(i), teb_runoff_gr(i), teb_z0_gd(i), &
                 teb_alb_gd(i), teb_emis_gd(i), teb_ts_gd(i), teb_qs_gd(i), teb_shfl_gd(i), &
                 teb_lhfl_gd(i), teb_qvfl_gd(i), teb_tch_gd(i), teb_tcm_gd(i), &
                 teb_runoff_gd(i), teb_fr_panel(i), teb_lroad_irrig, teb_rd_irrig_start_m(i), &
                 teb_rd_irrig_end_m(i), teb_rd_irrig_start_h(i), teb_rd_irrig_end_h(i), &
                 teb_rd_irrig_sum(i), DMT, TOP, TP, BOP, BP, TSTATE, BSTATE, TPN, TIR)
	END DO
	
    CALL TEB_UNBIND_STATE (ivstart, ivend, &
                 teb_ti_bld, &
                 teb_twin2, &
                 teb_qi_bld, &
                 teb_cap_sys_rat, &
                 teb_m_sys_rat, &
                 teb_twin1, &
                                  teb_lshade, &
                 teb_shad_day, &
                 teb_natvent_night, &
                 teb_ws_roof, &
                 teb_troof, &
                 teb_troad, &
                 teb_twalla, &
                 teb_twallb, &
                 teb_wsnow_roof, &
                 teb_tsnow_roof, &
                 teb_rsnow_roof, &
                 teb_asnow_roof, &
                 teb_esnow_roof, &
                 teb_tssnow_roof, &
                 teb_wsnow_road, &
                 teb_tsnow_road, &
                 teb_rsnow_road, &
                 teb_asnow_road, &
                 teb_esnow_road, &
                 teb_tssnow_road, &
                  teb_tcanyon, &
                  teb_qcanyon, &
                  teb_ws_road, &
                  teb_tfloor, &
                  teb_tmass, &
                  teb_albwin)
    !MV202610 the emulator of the host reads these as individual fields
    teb_wind_canyon(1:nvec) = DMT%XWIND_CANYON(1:nvec)
    teb_sobs(1:nvec)        = DMT%XSOBS(1:nvec)
    teb_thbs(1:nvec)        = DMT%XTHBS(1:nvec)
    teb_runoff_road(1:nvec) = DMT%XRUNOFF_ROAD(1:nvec)
    teb_runoff_roof(1:nvec) = DMT%XRUNOFF_ROOF(1:nvec)
    !MV202610 universal output: one row per selected cell, at the output cadence
    IF (TEB_LOG_AT_CADENCE()) THEN
       CALL TEB_LOG_EMIT(iblock, DMT, TOP, TSTATE, BSTATE, teb_year, teb_month, teb_day, teb_hour_seconds, &
            teb_tch_gd, &
            teb_tcm_gd, &
            t, &
            qv, &
            ps, &
            rho, &
            u, &
            v, &
            prr_con, &
            prs_con, &
            prr_gsp, &
            prs_gsp, &
            prg_gsp, &
            lwd_s, &
            swdir_s, &
            swdifd_s)
    END IF
END SUBROUTINE teb_interface

END MODULE sfc_teb
