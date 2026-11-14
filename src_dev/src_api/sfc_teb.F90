

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
USE MODI_INI_CSTS,   ONLY : INI_CSTS
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE TEB_HOST, ONLY : TEB_FILL_PARAMS, TEB_FILL_DERIVED, TEB_FILL_FORCING, TEB_FILL_EXT, TEB_HOST_ENSURE, TOPTS, TPARAMS, BOPTS, BPARAMS, TSTATE, BSTATE, TPN, TIR, DMT, FORC, EXT, TEB_BIND_STATE, TEB_UNBIND_STATE, TEB_INIT_STATE
USE TEB_LOG,  ONLY : TEB_LOG_SET_FILTER, TEB_LOG_AT_CADENCE, TEB_LOG_EMIT
!MV202611 explicit public host contract; numerical kind follows the build profile
IMPLICIT NONE
PRIVATE
INTEGER, PARAMETER :: teb_real_kind = KIND(0.0)

PUBLIC :: teb_interface, teb_real_kind

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
                          teb_tau_hw_width, teb_wind_canyon, teb_u_can_ped, teb_u_can_10m, teb_sobs, teb_thbs, teb_runoff_road, teb_runoff_roof, kteb_log_block, &
                          kteb_log_point, teb_ustar_town, teb_cd_greenroof_atm, &
                          teb_troad_before, teb_ucanyon, teb_vcanyon, &
                          teb_tsroof, teb_tswalla, teb_tswallb, &
                          teb_shfl, teb_lhfl, teb_qvfl, &
                          teb_tstown_s, teb_qstown_s, teb_wstown, &
                          teb_runoff_town, teb_tssnow_town, teb_wsnow_town, &
                          teb_rsnow_town, teb_frsnow, teb_hsnow_town, &
                          teb_tch_town, teb_shfl_snow, teb_lhfl_snow, &
                          teb_snow_melt, teb_alb_so, teb_emis_town, &
                          teb_hwaste, teb_hvac_cool, teb_hvac_heat, &
                          teb_dqs_town, teb_gflux, teb_shfl_rf, &
                          teb_shfl_rd, teb_shfl_wl, teb_ac_rf, &
                          teb_ac_rd, teb_ac_wl, teb_ac_top, &
                          teb_tch_rf, teb_tch_rd, teb_tch_wl, &
                          teb_tch_top, teb_wind_top, teb_cd_garden_atm, &
                          teb_ch_garden_atm, ahf_traffic_now)
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_PARAMS_n, ONLY : TEB_PARAMS_t
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t

!-------------------------------------------------------------------------------
! Declarations
!-------------------------------------------------------------------------------
INTEGER, INTENT(IN) :: ntstep
INTEGER, INTENT(IN) :: nvec     ! array dimensions
INTEGER, INTENT(IN) :: ivstart  !IN optional start index                   ! ivstart
INTEGER, INTENT(IN) :: ivend    !IN optional end   index                   ! ivend
INTEGER, INTENT(IN) :: iblock   !IN number of block
INTEGER :: i
LOGICAL :: LWRITE_LOG
REAL, INTENT(IN) :: dt          !IN integration timestep
	
INTEGER, INTENT(IN) :: &
  teb_year           , &                                                                                   ! current year
  teb_month          , &                                                                                   ! current month
  teb_day            , &                                                                                   ! current day
  teb_hour           , &                                                                                   ! current hour
  teb_min            , &                                                                                   ! current minutes
  teb_sec
									 
REAL,DIMENSION(1), INTENT(IN) :: teb_hour_seconds
REAL ,DIMENSION(nvec), INTENT(IN) :: lon_teb
REAL ,DIMENSION(nvec), INTENT(IN) :: lat_teb
REAL ,DIMENSION(nvec), INTENT(IN) :: hlev_teb
REAL ,DIMENSION(nvec), INTENT(IN) :: sa_uc  !IN total impervious surface-area index
									 
									 
										 
REAL ,DIMENSION(nvec), INTENT(IN) :: u         !IN zonal wind speed
REAL ,DIMENSION(nvec), INTENT(IN) :: v         !IN meridional wind speed
REAL ,DIMENSION(nvec), INTENT(IN) :: t         !IN temperature                            (  K  )
REAL ,DIMENSION(nvec), INTENT(IN) :: qv        !IN specific water vapor content           (kg/kg)
REAL ,DIMENSION(nvec), INTENT(IN) :: ps        !IN surface pressure                       ( Pa  )
REAL ,DIMENSION(nvec), INTENT(IN) :: rho       !IN air density                            ( kg/m3  )
REAL ,DIMENSION(nvec), INTENT(IN) :: prr_con   !IN precipitation rate of rain, convective       (kg/m2*s)
REAL ,DIMENSION(nvec), INTENT(IN) :: prs_con   !IN precipitation rate of snow, convective       (kg/m2*s)
REAL ,DIMENSION(nvec) :: conv_frac             !IN convective area fraction
REAL ,DIMENSION(nvec), INTENT(IN) :: prr_gsp   !IN precipitation rate of rain, grid-scale       (kg/m2*s)
REAL ,DIMENSION(nvec), INTENT(IN) :: prs_gsp   !IN precipitation rate of snow, grid-scale       (kg/m2*s)
REAL ,DIMENSION(nvec), INTENT(IN) :: prg_gsp   !IN precipitation rate of graupel, grid-scale    (kg/m2*s)
REAL ,DIMENSION(nvec) :: prh_gsp               !IN precipitation rate of hail, grid-scale       (kg/m2*s)
REAL ,DIMENSION(nvec), INTENT(IN) :: lwd_s     !IN downward comp. of long  wave rad. flux
REAL ,DIMENSION(nvec), INTENT(IN) :: swdir_s   !IN direct comp. of solar radiative flux at surface
REAL ,DIMENSION(nvec), INTENT(IN) :: swdifd_s  !IN diffuse downward comp. of short wave rad. flux
	
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_ti_bld  !INOUT indoor air temperature (K)
	
INTEGER, INTENT(IN) :: teb_nwall_layer   !IN optional end   index                   ! ivend
INTEGER, INTENT(IN) :: teb_nroof_layer   !IN optional end   index                   ! ivend
INTEGER, INTENT(IN) :: teb_nroad_layer   !IN optional end   index                   ! ivend
INTEGER, INTENT(IN) :: teb_nfloor_layer  !IN optional end   index                   ! ivend
	
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_fr_bld  !IN Building area fraction with respect to urban tile    (  -  )
REAL ,DIMENSION(nvec), INTENT(IN) :: fr_garden   !IN Garden area fraction with respect to urban tile    (  -  )
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_h2w     !IN Street canyon H/W ratio   ( m/m )
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_h_bld   !IN Building height  (  m  )
!MV202609 z0 and zd to namelist
CHARACTER(LEN=16), INTENT(IN) :: urb_z0_town  !IN z0 of the urban surface (0.5 | 0.5m | 0.1H | H/3 | <name>)
CHARACTER(LEN=16), INTENT(IN) :: urb_zd_town  !IN displacement height    (same forms as urb_z0_town)
!MV202609 garden thermal roughness (z0h)
REAL, INTENT(IN) :: urb_z0_o_z0h_gdn  !IN garden z0/z0h ratio (-)         ( >= 1 )
!MV202609 greenroof model type, thermal roughness and surface humidity
REAL, INTENT(IN) :: urb_z0_o_z0h_grf               !IN greenroof z0/z0h ratio (-)      ( >= 1 )
CHARACTER(LEN=4), INTENT(IN) :: teb_hroad_dir      !IN road direction option :
                                                   ! 'UNIF' : uniform roads                       
                                                   ! 'ORIE' : specified road orientation          
CHARACTER(LEN=4), INTENT(IN) :: teb_wall_opt       !IN Wall option
                                                   ! 'UNIF' : uniform walls                       
                                                   ! 'TWO ' : 2 opposite  walls
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_road_dir  !IN road direction (° from North, clockwise)
    

REAL ,DIMENSION(nvec), INTENT(IN) :: urb_hcap_rd    !IN Volumetric heat capacity of road material (Jm-3K-1)
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_hcap_rf    !IN Volumetric heat capacity of roof material (Jm-3K-1)
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_hcap_wl    !IN Volumetric heat capacity of wall material (Jm-3K-1)
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_hcon_rd    !IN heat conductivity of road material
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_hcon_rf    !IN heat conductivity of roof material
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_hcon_wl    !IN heat conductivity of wall material
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_alb_rd_so  !IN road material solar albedo
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_alb_rf_so  !IN roof material solar albedo
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_alb_wl_so  !IN wall material solar albedo
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_alb_rd_th  !IN road material thermal albedo
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_alb_rf_th  !IN roof material thermal albedo
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_alb_wl_th  !IN wall material thermal albedo
REAL ,DIMENSION(nvec), INTENT(IN) :: ahf_traffic    !IN Anthropogenic heat flux by traffic (annual mean)
REAL ,DIMENSION(nvec), INTENT(IN) :: ahf_industry   !IN Anthropogenic heat flux by industry (annual mean)
INTEGER, INTENT(IN) :: teb_utc_hour                 !IN Time zone for traffic daily cycle calculation
	
CHARACTER(LEN=3), INTENT(IN) :: teb_itype_bem
LOGICAL, INTENT(IN) :: teb_lbem_ac
CHARACTER(LEN=4), INTENT(IN) :: teb_itype_natvent
CHARACTER(LEN=6), INTENT(IN) :: teb_itype_bem_cool
CHARACTER(LEN=6), INTENT(IN) :: teb_itype_bem_heat
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_frac_gz
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_zresidential  !IN Fraction of residential use in buildings(-)
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_dt_res        !IN target temperature change when unoccupied (K) (residential buildings)
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_dt_off        !IN target temperature change when unoccupied (K) (office buildings)
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_cap_sys_heat  !IN Capacity of the heating system [W m-2(bld)]
	
LOGICAL, INTENT(IN) :: teb_lgreenroof
LOGICAL, INTENT(IN) :: teb_lgreenroof_ext
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_frac_gr
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_z0_gr
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_alb_gr
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_emis_gr
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_ts_gr
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_qs_gr
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_shfl_gr
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_lhfl_gr
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_qvfl_gr
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_runoff_gr

LOGICAL, INTENT(IN) :: teb_lgarden
CHARACTER(LEN=9), INTENT(IN) :: teb_type_garden
CHARACTER(LEN=9), INTENT(IN) :: teb_type_greenroof
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_z0_gd
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_alb_gd
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_emis_gd
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_ts_gd
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_qs_gd
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_shfl_gd
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_lhfl_gd
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_qvfl_gd
REAL ,DIMENSION(nvec), INTENT(OUT) :: teb_tch_gd
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_tcm_gd
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_runoff_gd
	
LOGICAL, INTENT(IN) :: teb_lshade
	
INTEGER, INTENT(IN) :: teb_itype_wind
REAL ,DIMENSION(nvec, 1:8), INTENT(IN) :: teb_fai
	
LOGICAL, INTENT(IN) :: teb_lsolar_panel
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_fr_panel

LOGICAL, INTENT(IN) :: teb_lroad_irrig
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_rd_irrig_start_m
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_rd_irrig_end_m
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_rd_irrig_start_h
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_rd_irrig_end_h
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_rd_irrig_sum

REAL ,DIMENSION(nvec, 1:teb_nroof_layer), INTENT(INOUT) :: teb_troof
REAL ,DIMENSION(nvec, 1:teb_nroad_layer), INTENT(INOUT) :: teb_troad
REAL ,DIMENSION(nvec, 1:teb_nwall_layer), INTENT(INOUT) :: teb_twalla
REAL ,DIMENSION(nvec, 1:teb_nwall_layer), INTENT(INOUT) :: teb_twallb
REAL ,DIMENSION(nvec, 1:teb_nfloor_layer), INTENT(INOUT) :: teb_tfloor
REAL ,DIMENSION(nvec, 1:teb_nfloor_layer), INTENT(INOUT) :: teb_tmass
REAL,DIMENSION(nvec), INTENT(INOUT) :: teb_qi_bld
REAL,DIMENSION(nvec), INTENT(INOUT) :: teb_tcanyon
REAL,DIMENSION(nvec), INTENT(INOUT) :: teb_qcanyon
	
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_ws_roof  ! roof water content (kg/m2)
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_ws_road  ! road water content (kg/m2)
REAL ,DIMENSION(nvec, 1), INTENT(INOUT) :: teb_wsnow_roof
REAL ,DIMENSION(nvec, 1), INTENT(INOUT) :: teb_wsnow_road
REAL ,DIMENSION(nvec, 1), INTENT(INOUT) :: teb_tsnow_roof
REAL ,DIMENSION(nvec, 1), INTENT(INOUT) :: teb_tsnow_road
REAL ,DIMENSION(nvec, 1), INTENT(INOUT) :: teb_rsnow_roof
REAL ,DIMENSION(nvec, 1), INTENT(INOUT) :: teb_rsnow_road
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_tssnow_roof
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_tssnow_road
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_asnow_roof
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_asnow_road
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_esnow_roof
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_esnow_road
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_twin1
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_twin2
REAL ,DIMENSION(nvec), INTENT(OUT) :: teb_albwin
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_cap_sys_rat
REAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_m_sys_rat
LOGICAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_shad_day
LOGICAL ,DIMENSION(nvec), INTENT(INOUT) :: teb_natvent_night
!MV202609 fixes of the snow melt / roof puddle water path (runoff diagnostics)
	
	
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_tcool_target
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_theat_target
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_bem_vent
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_bem_inf
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_bem_cop
	
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
LOGICAL,              INTENT(IN)  :: teb_lcbs_scheme    ! flag to use the CBS scheme for the road
REAL,                 INTENT(IN)  :: teb_tau_hw_thresh  ! H/W giving tau = 0.5 (CBS scheme)
REAL,                 INTENT(IN)  :: teb_tau_hw_width   ! width of the tanh relaxation (CBS scheme)
!MV202610 emulator inputs as individual fields (no structures across the boundary)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_wind_canyon  ! canyon wind (m/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_u_can_ped    ! wind speed at pedestrian height (1.1 m) (m/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_u_can_10m    ! wind speed at 10 m height (m/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_sobs         ! solar radiation absorbed by the ground (W/m2)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_thbs         ! thermal radiation absorbed by the ground (W/m2)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_runoff_road  ! road runoff of this sub-step (kg/m2/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_runoff_roof  ! roof runoff of this sub-step (kg/m2/s)
!MV202611 host-owned lagged momentum inputs (one value per column)
!* Cold start uses u*=0.2 m/s and an unavailable roof CD (neutral fallback).
!* Later calls, including restart, restore both values from the host.
REAL, DIMENSION(nvec), INTENT(INOUT) :: teb_ustar_town        ! town friction velocity (m/s)
REAL, DIMENSION(nvec), INTENT(INOUT) :: teb_cd_greenroof_atm  ! external greenroof momentum coefficient (-)
!MV202611 optional host diagnostics: native TEB units and normalization
!* Only ivstart:ivend is valid. The host owns history and unit conversions.
!* teb_troad_before is sampled after cold-start, before CALL_DRIVER.
!* HVAC power is zero with DEF; unavailable diagnostics retain XUNDEF.
REAL, DIMENSION(nvec,teb_nroad_layer), OPTIONAL, INTENT(OUT) :: teb_troad_before  ! K; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_ucanyon                       ! m/s; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_vcanyon                       ! m/s; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_tsroof                        ! K; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_tswalla                       ! K; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_tswallb                       ! K; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_shfl                          ! W/m2; town
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_lhfl                          ! W/m2; town
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_qvfl                          ! kg/m2/s; town
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_tstown_s                      ! K; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_qstown_s                      ! kg/kg; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_wstown                        ! m H2O; town
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_runoff_town                   ! kg/m2/s; town
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_tssnow_town                   ! K; snow
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_wsnow_town                    ! m H2O; impervious
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_rsnow_town                    ! kg/m3; snow
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_frsnow                        ! -; impervious
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_hsnow_town                    ! m; impervious
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_tch_town                      ! -; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_shfl_snow                     ! W/m2; impervious
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_lhfl_snow                     ! W/m2; impervious
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_snow_melt                     ! kg/m2/s; impervious
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_alb_so                        ! -; town
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_emis_town                     ! -; town
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_hwaste                        ! W/m2; town
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_hvac_cool                     ! W/m2; building
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_hvac_heat                     ! W/m2; building
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_dqs_town                      ! W/m2; impervious
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_gflux                         ! W/m2; town
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_shfl_rf                       ! W/m2; weighted
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_shfl_rd                       ! W/m2; weighted
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_shfl_wl                       ! W/m2; weighted
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_ac_rf                         ! m/s; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_ac_rd                         ! m/s; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_ac_wl                         ! m/s; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_ac_top                        ! m/s; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_tch_rf                        ! -; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_tch_rd                        ! -; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_tch_wl                        ! -; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_tch_top                       ! -; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_wind_top                      ! m/s; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_cd_garden_atm                 ! -; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: teb_ch_garden_atm                 ! -; none
REAL, DIMENSION(nvec), OPTIONAL, INTENT(OUT) :: ahf_traffic_now                   ! W/m2; town
!* MV202610 blocks and points for which the text output is written;
!* in the coupled model both lists are empty by default (no filter).
INTEGER, DIMENSION(:), INTENT(IN) :: KTEB_LOG_BLOCK  ! blocks to write
INTEGER, DIMENSION(:), INTENT(IN) :: KTEB_LOG_POINT  ! points to write


!------------------------------------------------------------------------------
! Begin Subroutine teb_interface
!------------------------------------------------------------------------------
    
!MV202611 block host contract; the physical workspace remains one column.
IF (nvec < 1) ERROR STOP 'TEB_INTERFACE: nvec must be positive'
IF (ivstart < 1 .OR. ivstart > nvec+1 .OR. ivend < 0 .OR. ivend > nvec .OR. &
    ivend < ivstart-1) ERROR STOP 'TEB_INTERFACE: invalid window bounds'
IF (ANY([teb_nroof_layer, teb_nroad_layer, teb_nwall_layer, teb_nfloor_layer] /= 5)) &
  ERROR STOP 'TEB_INTERFACE: roof/road/wall/floor require five layers'
CALL TEB_LOG_SET_FILTER(KTEB_LOG_BLOCK, KTEB_LOG_POINT)
! All blocks of the same model step share the output decision.
LWRITE_LOG = TEB_LOG_AT_CADENCE(ntstep)
IF (ivend < ivstart) RETURN
IF (.NOT. ANY(sa_uc(ivstart:ivend) > 0.)) RETURN
CALL INI_CSTS
CALL TEB_HOST_ENSURE(1, teb_nroof_layer, teb_nroad_layer, teb_nwall_layer, teb_nfloor_layer)
DO i = ivstart, ivend
  IF (.NOT. (sa_uc(i) > 0.)) CYCLE
  !MV202610 parameter containers are filled here, where the configuration is known
  CALL TEB_FILL_PARAMS (1, 1, teb_itype_bem_cool, teb_itype_bem_heat, teb_tcool_target(i:i), &
                        teb_theat_target(i:i), teb_frac_gz(i:i), teb_bem_inf(i:i), teb_bem_vent(i:i), teb_cap_sys_heat(i:i), &
                        teb_bem_cop(i:i), teb_itype_natvent, teb_lgarden, teb_hroad_dir, teb_wall_opt, teb_itype_bem, &
                        teb_lgreenroof, teb_type_garden, teb_type_greenroof, teb_lsolar_panel, teb_lcbs_scheme, &
                        teb_tau_hw_thresh, teb_tau_hw_width, urb_z0_o_z0h_gdn, urb_z0_o_z0h_grf, teb_road_dir(i:i), &
                        fr_garden(i:i), teb_frac_gr(i:i), urb_fr_bld(i:i), urb_h2w(i:i), urb_h_bld(i:i), urb_alb_rf_so(i:i), &
                        urb_alb_rd_so(i:i), urb_alb_wl_so(i:i), urb_alb_rd_th(i:i), urb_alb_rf_th(i:i), urb_alb_wl_th(i:i), &
                        teb_zresidential(i:i), teb_dt_res(i:i), teb_dt_off(i:i), ahf_industry(i:i), teb_itype_wind, &
                        teb_utc_hour, teb_lgreenroof_ext, teb_lbem_ac, teb_fr_panel(i:i), teb_lroad_irrig, &
                        teb_rd_irrig_start_m(i:i), teb_rd_irrig_end_m(i:i), teb_rd_irrig_start_h(i:i), &
                        teb_rd_irrig_end_h(i:i), teb_rd_irrig_sum(i:i))
  !MV202610 derived statics: layer profiles, geometry, SVF, z0/zd, BEM constants
  CALL TEB_FILL_DERIVED (1, 1, urb_z0_town, urb_zd_town, urb_hcap_rd(i:i), urb_hcap_rf(i:i), &
                         urb_hcap_wl(i:i), urb_hcon_rd(i:i), urb_hcon_rf(i:i), urb_hcon_wl(i:i), ahf_traffic(i:i), &
                         teb_fai(i:i,:))
  !MV202610 forcing of the sub-step: raw values and the derived quantities
  !* (pressure/Exner, density, wind, solar geometry and shortwave partition)
  !* are recomputed for this host column in the single-column workspace
  CALL TEB_FILL_FORCING (1, 1, teb_year, teb_month, teb_day, teb_hour_seconds(1), lon_teb(i:i), lat_teb(i:i), &
                         u(i:i), v(i:i), t(i:i), qv(i:i), ps(i:i), prr_con(i:i), prs_con(i:i), prr_gsp(i:i), prs_gsp(i:i), &
                         prg_gsp(i:i), lwd_s(i:i), swdir_s(i:i), swdifd_s(i:i), hlev_teb(i:i), hlev_teb(i:i))
  !MV202611 external garden / greenroof: the host-provided surface state and
  !* fluxes are copied for this column (the two runoffs
  !* are converted here from kg/m2 to kg/m2/s with the same /dt as before)
  CALL TEB_FILL_EXT (1, 1, dt, teb_z0_gr(i:i), teb_alb_gr(i:i), teb_emis_gr(i:i), teb_ts_gr(i:i), &
                     teb_qs_gr(i:i), teb_shfl_gr(i:i), teb_lhfl_gr(i:i), teb_qvfl_gr(i:i), teb_runoff_gr(i:i), &
                     teb_z0_gd(i:i), teb_alb_gd(i:i), teb_emis_gd(i:i), teb_ts_gd(i:i), teb_qs_gd(i:i), teb_shfl_gd(i:i), &
                     teb_lhfl_gd(i:i), teb_qvfl_gd(i:i), teb_runoff_gd(i:i))
  CALL TEB_BIND_STATE (1, 1, teb_ti_bld(i:i), teb_twin2(i:i), teb_qi_bld(i:i), teb_cap_sys_rat(i:i), &
                       teb_m_sys_rat(i:i), teb_twin1(i:i), teb_lshade, teb_shad_day(i:i), teb_natvent_night(i:i), &
                       teb_ws_roof(i:i), teb_troof(i:i,:), teb_troad(i:i,:), teb_twalla(i:i,:), teb_twallb(i:i,:), &
                       teb_wsnow_roof(i:i,:), teb_tsnow_roof(i:i,:), teb_rsnow_roof(i:i,:), teb_asnow_roof(i:i), &
                       teb_esnow_roof(i:i), teb_tssnow_roof(i:i), teb_wsnow_road(i:i,:), teb_tsnow_road(i:i,:), &
                       teb_rsnow_road(i:i,:), teb_asnow_road(i:i), teb_esnow_road(i:i), teb_tssnow_road(i:i), &
                       teb_tcanyon(i:i), teb_qcanyon(i:i), teb_ws_road(i:i), teb_tfloor(i:i,:), teb_tmass(i:i,:))
  !MV202610 cold start of the first model step: ntstep is 0-based
  IF (ntstep == 0) THEN
    CALL TEB_INIT_STATE (1, 1)
  ELSE
    !MV202611 restore the lagged inputs of THIS column before physics.
    DMT%XUSTAR_TOWN(1:1) = teb_ustar_town(i:i)
    DMT%XPCD_GREENROOF_ATM(1:1) = teb_cd_greenroof_atm(i:i)
  END IF
  !MV202611 expose the actual pre-physics road profile, including cold-start
  IF (PRESENT(teb_troad_before)) &
    teb_troad_before(i:i,:) = TSTATE%XT_ROAD(1:1,:)
  CALL CALL_DRIVER (ntstep, 1, iblock, dt, teb_year, teb_month, teb_day, teb_hour, teb_min, &
                    teb_sec, teb_hour_seconds(1), sa_uc(i), lon_teb(i), lat_teb(i), FORC, EXT, &
                    teb_tch_gd(i), teb_tcm_gd(i), &
                    DMT, TOPTS, TPARAMS, BOPTS, BPARAMS, TSTATE, BSTATE, TPN, TIR)
  !MV202611 return the updated momentum inputs for the next host step.
  teb_ustar_town(i:i) = DMT%XUSTAR_TOWN(1:1)
  teb_cd_greenroof_atm(i:i) = DMT%XPCD_GREENROOF_ATM(1:1)
  !MV202610 keep the post-TEB_GARDEN value on the first model step
  IF (ntstep == 0) DMT%XTSTOWN_S_NOW(1:1) = DMT%XTSTOWN_S(1:1)
  CALL TEB_UNBIND_STATE (1, 1, teb_ti_bld(i:i), teb_twin2(i:i), teb_qi_bld(i:i), teb_cap_sys_rat(i:i), &
                         teb_m_sys_rat(i:i), teb_twin1(i:i), teb_lshade, teb_shad_day(i:i), teb_natvent_night(i:i), &
                         teb_ws_roof(i:i), teb_troof(i:i,:), teb_troad(i:i,:), teb_twalla(i:i,:), teb_twallb(i:i,:), &
                         teb_wsnow_roof(i:i,:), teb_tsnow_roof(i:i,:), teb_rsnow_roof(i:i,:), teb_asnow_roof(i:i), &
                         teb_esnow_roof(i:i), teb_tssnow_roof(i:i), teb_wsnow_road(i:i,:), teb_tsnow_road(i:i,:), &
                         teb_rsnow_road(i:i,:), teb_asnow_road(i:i), teb_esnow_road(i:i), teb_tssnow_road(i:i), &
                         teb_tcanyon(i:i), teb_qcanyon(i:i), teb_ws_road(i:i), teb_tfloor(i:i,:), teb_tmass(i:i,:), &
                         teb_albwin(i:i))
  !MV202610 the emulator of the host reads these as individual fields
  !* sobs/thbs are the solar/thermal radiation absorbed by the garden, i.e. the
  !* XABS_SW_GARDEN/XABS_LW_GARDEN that TEB_GARDEN computes for the sub-step
  !* (the dedicated XSOBS/XTHBS fields of the container were never filled and
  !* have been removed; check_diag_producers.py guards against a recurrence)
  teb_wind_canyon(i:i) = DMT%XWIND_CANYON(1:1)
  teb_u_can_ped(i:i)   = DMT%XU_CAN_PED(1:1)
  teb_u_can_10m(i:i)   = DMT%XU_CAN_10M(1:1)
  teb_sobs(i:i)        = DMT%XABS_SW_GARDEN(1:1)
  teb_thbs(i:i)        = DMT%XABS_LW_GARDEN(1:1)
  teb_runoff_road(i:i) = DMT%XRUNOFF_ROAD(1:1)
  teb_runoff_roof(i:i) = DMT%XRUNOFF_ROOF(1:1)
  !MV202611 optional results are copied out; the physical containers are unchanged
  IF (PRESENT(teb_ucanyon)) &
    teb_ucanyon(i:i) = DMT%XUCANYON(1:1)
  IF (PRESENT(teb_vcanyon)) &
    teb_vcanyon(i:i) = DMT%XVCANYON(1:1)
  IF (PRESENT(teb_tsroof)) &
    teb_tsroof(i:i) = DMT%XTS_ROOF(1:1)
  IF (PRESENT(teb_tswalla)) &
    teb_tswalla(i:i) = DMT%XTS_WALL_A(1:1)
  IF (PRESENT(teb_tswallb)) &
    teb_tswallb(i:i) = DMT%XTS_WALL_B(1:1)
  IF (PRESENT(teb_shfl)) &
    teb_shfl(i:i) = DMT%XH_TOWN(1:1)
  IF (PRESENT(teb_lhfl)) &
    teb_lhfl(i:i) = DMT%XLE_TOWN(1:1)
  IF (PRESENT(teb_qvfl)) &
    teb_qvfl(i:i) = DMT%XQVFL(1:1)
  IF (PRESENT(teb_tstown_s)) &
    teb_tstown_s(i:i) = DMT%XTSTOWN_S(1:1)
  IF (PRESENT(teb_qstown_s)) &
    teb_qstown_s(i:i) = DMT%XQSTOWN_S(1:1)
  IF (PRESENT(teb_wstown)) &
    teb_wstown(i:i) = DMT%XWSTOWN(1:1)
  IF (PRESENT(teb_runoff_town)) &
    teb_runoff_town(i:i) = DMT%XRUNOFF_TOWN(1:1)
  IF (PRESENT(teb_tssnow_town)) &
    teb_tssnow_town(i:i) = DMT%XTSSNOW_TOWN(1:1)
  IF (PRESENT(teb_wsnow_town)) &
    teb_wsnow_town(i:i) = DMT%XWSNOW_TOWN(1:1)
  IF (PRESENT(teb_rsnow_town)) &
    teb_rsnow_town(i:i) = DMT%XRSNOW_TOWN(1:1)
  IF (PRESENT(teb_frsnow)) &
    teb_frsnow(i:i) = DMT%XFRSNOW(1:1)
  IF (PRESENT(teb_hsnow_town)) &
    teb_hsnow_town(i:i) = DMT%XHSNOW_TOWN(1:1)
  IF (PRESENT(teb_tch_town)) &
    teb_tch_town(i:i) = DMT%XTCH_TOWN(1:1)
  IF (PRESENT(teb_shfl_snow)) &
    teb_shfl_snow(i:i) = DMT%XSHFL_SNOW(1:1)
  IF (PRESENT(teb_lhfl_snow)) &
    teb_lhfl_snow(i:i) = DMT%XLHFL_SNOW(1:1)
  IF (PRESENT(teb_snow_melt)) &
    teb_snow_melt(i:i) = DMT%XSNOW_MELT(1:1)
  IF (PRESENT(teb_alb_so)) &
    teb_alb_so(i:i) = DMT%XALB_SO(1:1)
  IF (PRESENT(teb_emis_town)) &
    teb_emis_town(i:i) = DMT%XEMIS_TOWN(1:1)
  IF (PRESENT(teb_hwaste)) &
    teb_hwaste(i:i) = DMT%XH_WASTE(1:1)
  IF (PRESENT(teb_hvac_cool)) THEN
    teb_hvac_cool(i:i) = 0.
    IF (teb_itype_bem == 'BEM') &
      teb_hvac_cool(i:i) = DMT%XHVAC_COOL(1:1)
  END IF
  IF (PRESENT(teb_hvac_heat)) THEN
    teb_hvac_heat(i:i) = 0.
    IF (teb_itype_bem == 'BEM') &
      teb_hvac_heat(i:i) = DMT%XHVAC_HEAT(1:1)
  END IF
  IF (PRESENT(teb_dqs_town)) &
    teb_dqs_town(i:i) = DMT%XDQS_TOWN(1:1)
  IF (PRESENT(teb_gflux)) &
    teb_gflux(i:i) = DMT%XGFLUX_TOWN(1:1)
  IF (PRESENT(teb_shfl_rf)) &
    teb_shfl_rf(i:i) = DMT%XH_ROOF_FR(1:1)
  IF (PRESENT(teb_shfl_rd)) &
    teb_shfl_rd(i:i) = DMT%XH_ROAD_FR(1:1)
  IF (PRESENT(teb_shfl_wl)) &
    teb_shfl_wl(i:i) = DMT%XH_WALL_FR(1:1)
  IF (PRESENT(teb_ac_rf)) &
    teb_ac_rf(i:i) = DMT%XAC_RF(1:1)
  IF (PRESENT(teb_ac_rd)) &
    teb_ac_rd(i:i) = DMT%CAN%PAC_ROAD(1:1)
  IF (PRESENT(teb_ac_wl)) &
    teb_ac_wl(i:i) = DMT%XAC_WL(1:1)
  IF (PRESENT(teb_ac_top)) &
    teb_ac_top(i:i) = DMT%XAC_TOP(1:1)
  IF (PRESENT(teb_tch_rf)) &
    teb_tch_rf(i:i) = DMT%XTCH_RF(1:1)
  IF (PRESENT(teb_tch_rd)) &
    teb_tch_rd(i:i) = DMT%CAN%PCH_ROAD(1:1)
  IF (PRESENT(teb_tch_wl)) &
    teb_tch_wl(i:i) = DMT%XTCH_WL(1:1)
  IF (PRESENT(teb_tch_top)) &
    teb_tch_top(i:i) = DMT%XTCH_TOP(1:1)
  IF (PRESENT(teb_wind_top)) &
    teb_wind_top(i:i) = DMT%XWIND_TOP(1:1)
  IF (PRESENT(teb_cd_garden_atm)) &
    teb_cd_garden_atm(i:i) = DMT%ATM%PCD_GARDEN(1:1)
  IF (PRESENT(teb_ch_garden_atm)) &
    teb_ch_garden_atm(i:i) = DMT%ATM%PCH_GARDEN(1:1)
  IF (PRESENT(ahf_traffic_now)) &
    ahf_traffic_now(i:i) = DMT%XAHF_TRAFFIC_NOW(1:1)

  !MV202611 emit only this host cell while its workspace is still loaded.
  IF (LWRITE_LOG) THEN
    CALL TEB_LOG_EMIT (iblock, DMT, TOPTS, TSTATE, BSTATE, FORC, teb_year, teb_month, teb_day, &
                       teb_hour_seconds, t(i:i), qv(i:i), ps(i:i), rho(i:i), u(i:i), v(i:i), prr_con(i:i), &
                       prs_con(i:i), prr_gsp(i:i), prs_gsp(i:i), prg_gsp(i:i), lwd_s(i:i), swdir_s(i:i), swdifd_s(i:i), &
                       KHOST_CELL=i)
  END IF
END DO
END SUBROUTINE teb_interface

END MODULE sfc_teb
