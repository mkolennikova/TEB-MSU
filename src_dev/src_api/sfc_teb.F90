

!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      Pre-repository -- Maria Tarasova (MT)
!!        Create the COSMO-oriented block adapter with host-supplied forcing,
!!        surface parameters and model state.
!!      09/2026 -- Mikhail Varentsov (MV)
!!        Extend the host interface for CBS and diagnostic garden/greenroof
!!        schemes.
!!      10/2026 -- Mikhail Varentsov (MV)
!!        Reorganize the adapter around reusable workspace containers and
!!        explicit host/workspace state transfers.
!!      11/2026 -- Mikhail Varentsov (MV)
!!        Define the public input/output contract and preserve lagged
!!        USTAR/greenroof-CD inputs independently for each host column.
!!        Expose the snow-filter option, undefined sentinel and workspace/log
!!        finalization through the public API.
!!      11/2026 -- OpenAI Codex
!!        Expose independent optional road, roof and canyon exchange algorithms.
!!      11/2026 -- OpenAI Codex
!!        Accept shared layer-depth profiles and runtime roof/road/wall counts.
!!      11/2026 -- OpenAI Codex
!!        Take the named canyon wind scheme through the public interface.
!!      11/2026 -- OpenAI Codex
!!        Expose dynamic town roughness and displacement height, sharing the
!!        per-column stability history.
!!------------------------------------------------------------------------------
MODULE sfc_teb



!------------------------------------------------------------------------------
! Public subroutines
!------------------------------------------------------------------------------

!* CALL_DRIVER has a compiler-checked module interface.
!* Host arrays are loaded into a one-column workspace for each physics call.
USE MODI_CALL_DRIVER, ONLY : CALL_DRIVER
USE MODI_INI_CSTS,   ONLY : INI_CSTS
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE TEB_HOST, ONLY : TEB_FILL_PARAMS, TEB_FILL_DERIVED, TEB_FILL_FORCING, &
                    TEB_FILL_EXT, TEB_HOST_ENSURE, TOPTS, TPARAMS, BOPTS, &
                    BPARAMS, TSTATE, BSTATE, TPN, TIR, DMT, FORC, EXT, &
                    TEB_BIND_STATE, TEB_UNBIND_STATE, TEB_INIT_STATE, &
                    TEB_HOST_FINAL, TEB_CHECK_LAYER_DEPTHS
USE TEB_LOG,  ONLY : TEB_LOG_SET_FILTER, TEB_LOG_AT_CADENCE, TEB_LOG_EMIT, TEB_LOG_FINAL
USE MODD_SURF_PAR, ONLY : teb_undef => XUNDEF, module_snow_check => teb_snow_check
IMPLICIT NONE
PRIVATE
INTEGER, PARAMETER :: teb_real_kind = KIND(0.0)

PUBLIC :: teb_interface, teb_finalize, teb_real_kind, teb_undef

!------------------------------------------------------------------------------
! Parameters and variables which are global in this module
!------------------------------------------------------------------------------

CONTAINS

!> Release library-owned resources; host-owned column state is unchanged.
!! Safe before the first model call and on repeated calls.
SUBROUTINE teb_finalize
CALL TEB_LOG_FINAL
CALL TEB_HOST_FINAL
END SUBROUTINE teb_finalize

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
                          teb_ctype_wind, teb_fai, teb_type_garden, &
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
                          teb_ch_garden_atm, ahf_traffic_now, teb_snow_check, &
                          teb_ctype_exch_road, teb_ctype_exch_roof, teb_ctype_exch_canyon, &
                          urb_d_rf, urb_d_rd, urb_d_wl, &
                          teb_ctype_z0_town_dyncorr, teb_inv_l_town_prev, teb_ctype_zd_town_dyncorr)
USE, INTRINSIC :: IEEE_ARITHMETIC, ONLY: IEEE_IS_FINITE
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t, TEB_EXCH_METHOD, TEB_PARSE_TOWN_DYNCORR
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
! VALUE permits the module flag itself to be passed without input aliasing.
LOGICAL, OPTIONAL, INTENT(IN), VALUE :: teb_snow_check
CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: teb_ctype_exch_road
CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: teb_ctype_exch_roof
CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: teb_ctype_exch_canyon
! Layer depths in metres, shared by all columns; omitted profiles use defaults.
REAL, OPTIONAL, INTENT(IN) :: urb_d_rf(:), urb_d_rd(:), urb_d_wl(:)
CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: teb_ctype_z0_town_dyncorr
CHARACTER(LEN=*), OPTIONAL, INTENT(IN) :: teb_ctype_zd_town_dyncorr
CHARACTER(LEN=6) :: HEXCH_ROAD, HEXCH_ROOF, HEXCH_CANYON
CHARACTER(LEN=7) :: CZ0_TOWN_DYNCORR, CZD_TOWN_DYNCORR
LOGICAL :: LTOWN_DYNCORR_VALID, LTOWN_DYNCORR
REAL :: ZINV_L_TOWN_PREV(1)
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
	
INTEGER, INTENT(IN) :: teb_nwall_layer   ! Number of material layers
INTEGER, INTENT(IN) :: teb_nroof_layer   ! Number of material layers
INTEGER, INTENT(IN) :: teb_nroad_layer   ! Number of material layers
INTEGER, INTENT(IN) :: teb_nfloor_layer  !IN optional end   index                   ! ivend
	
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_fr_bld  !IN Building area fraction with respect to urban tile    (  -  )
REAL ,DIMENSION(nvec), INTENT(IN) :: fr_garden   !IN Garden area fraction with respect to urban tile    (  -  )
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_h2w     !IN Street canyon H/W ratio   ( m/m )
REAL ,DIMENSION(nvec), INTENT(IN) :: urb_h_bld   !IN Building height  (  m  )
CHARACTER(LEN=16), INTENT(IN) :: urb_z0_town  !IN z0 of the urban surface (0.5 | 0.5m | 0.1H | H/3 | <name>)
CHARACTER(LEN=16), INTENT(IN) :: urb_zd_town  !IN displacement height    (same forms as urb_z0_town)
REAL, INTENT(IN) :: urb_z0_o_z0h_gdn  !IN garden z0/z0h ratio (-)         ( >= 1 )
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
	
CHARACTER(LEN=*), INTENT(IN) :: teb_ctype_wind
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
	
	
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_tcool_target
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_theat_target
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_bem_vent
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_bem_inf
REAL ,DIMENSION(nvec), INTENT(IN) :: teb_bem_cop
	
LOGICAL,              INTENT(IN)  :: teb_lcbs_scheme    ! flag to use the CBS scheme for the road
REAL,                 INTENT(IN)  :: teb_tau_hw_thresh  ! H/W giving tau = 0.5 (CBS scheme)
REAL,                 INTENT(IN)  :: teb_tau_hw_width   ! width of the tanh relaxation (CBS scheme)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_wind_canyon  ! canyon wind (m/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_u_can_ped    ! wind speed at pedestrian height (1.1 m) (m/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_u_can_10m    ! wind speed at 10 m height (m/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_sobs         ! solar radiation absorbed by the ground (W/m2)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_thbs         ! thermal radiation absorbed by the ground (W/m2)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_runoff_road  ! road runoff of this sub-step (kg/m2/s)
REAL, DIMENSION(nvec), INTENT(OUT) :: teb_runoff_roof  ! roof runoff of this sub-step (kg/m2/s)
!* Cold start uses u*=0.2 m/s and an unavailable roof CD (neutral fallback).
!* Later calls, including restart, restore both values from the host.
REAL, DIMENSION(nvec), INTENT(INOUT) :: teb_ustar_town        ! town friction velocity (m/s)
REAL, DIMENSION(nvec), INTENT(INOUT) :: teb_cd_greenroof_atm  ! external greenroof momentum coefficient (-)
!* Either ZIL2008 correction requires an inverse Obukhov length (1/m) per
!* column in the convention of Zilitinkevich et al. (2008). The host carries
!* the returned values between steps and across restarts. Cold starts use zero.
REAL, OPTIONAL, INTENT(INOUT) :: teb_inv_l_town_prev(:)
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
!* in the coupled model both lists are empty by default (no filter).
INTEGER, DIMENSION(:), INTENT(IN) :: KTEB_LOG_BLOCK  ! blocks to write
INTEGER, DIMENSION(:), INTENT(IN) :: KTEB_LOG_POINT  ! points to write


!------------------------------------------------------------------------------
! Begin Subroutine teb_interface
!------------------------------------------------------------------------------
    
IF (nvec < 1) ERROR STOP 'TEB_INTERFACE: nvec must be positive'
IF (ivstart < 1 .OR. ivstart > nvec+1 .OR. ivend < 0 .OR. ivend > nvec .OR. &
    ivend < ivstart-1) ERROR STOP 'TEB_INTERFACE: invalid window bounds'
IF (teb_nfloor_layer /= 5) ERROR STOP 'TEB_INTERFACE: floor requires five layers'
IF (teb_ctype_wind /= 'DEF' .AND. teb_ctype_wind /= 'WANG') &
  ERROR STOP 'TEB_INTERFACE: teb_ctype_wind must be DEF or WANG'
CALL TEB_CHECK_LAYER_DEPTHS('urb_d_rf', teb_nroof_layer, urb_d_rf)
CALL TEB_CHECK_LAYER_DEPTHS('urb_d_rd', teb_nroad_layer, urb_d_rd)
CALL TEB_CHECK_LAYER_DEPTHS('urb_d_wl', teb_nwall_layer, urb_d_wl)
HEXCH_ROAD = TEB_EXCH_METHOD(teb_ctype_exch_road, 'teb_ctype_exch_road')
HEXCH_ROOF = TEB_EXCH_METHOD(teb_ctype_exch_roof, 'teb_ctype_exch_roof')
HEXCH_CANYON = TEB_EXCH_METHOD(teb_ctype_exch_canyon, 'teb_ctype_exch_canyon')
CALL TEB_PARSE_TOWN_DYNCORR(teb_ctype_z0_town_dyncorr, CZ0_TOWN_DYNCORR, LTOWN_DYNCORR_VALID)
IF (.NOT. LTOWN_DYNCORR_VALID) &
  ERROR STOP 'TEB_INTERFACE: teb_ctype_z0_town_dyncorr must be OFF or ZIL2008'
CALL TEB_PARSE_TOWN_DYNCORR(teb_ctype_zd_town_dyncorr, CZD_TOWN_DYNCORR, LTOWN_DYNCORR_VALID)
IF (.NOT. LTOWN_DYNCORR_VALID) &
  ERROR STOP 'TEB_INTERFACE: teb_ctype_zd_town_dyncorr must be OFF or ZIL2008'
LTOWN_DYNCORR = CZ0_TOWN_DYNCORR == 'ZIL2008' .OR. CZD_TOWN_DYNCORR == 'ZIL2008'
IF (LTOWN_DYNCORR) THEN
  IF (.NOT. PRESENT(teb_inv_l_town_prev)) &
    ERROR STOP 'TEB_INTERFACE: ZIL2008 requires teb_inv_l_town_prev'
  IF (SIZE(teb_inv_l_town_prev) /= nvec) &
    ERROR STOP 'TEB_INTERFACE: teb_inv_l_town_prev must have nvec elements'
END IF
IF (PRESENT(teb_snow_check)) module_snow_check = teb_snow_check
CALL TEB_LOG_SET_FILTER(KTEB_LOG_BLOCK, KTEB_LOG_POINT)
! All blocks of the same model step share the output decision.
LWRITE_LOG = TEB_LOG_AT_CADENCE(ntstep)
IF (ivend < ivstart) RETURN
IF (.NOT. ANY(sa_uc(ivstart:ivend) > 0.)) RETURN
CALL INI_CSTS
CALL TEB_HOST_ENSURE(1, teb_nroof_layer, teb_nroad_layer, teb_nwall_layer, teb_nfloor_layer)
DO i = ivstart, ivend
  IF (.NOT. (sa_uc(i) > 0.)) CYCLE
  IF (ANY(.NOT. IEEE_IS_FINITE([urb_hcap_rf(i), urb_hcap_rd(i), urb_hcap_wl(i), &
                               urb_hcon_rf(i), urb_hcon_rd(i), urb_hcon_wl(i)]))) &
    ERROR STOP 'TEB_INTERFACE: material properties must be finite'
  IF (MIN(urb_hcap_rf(i), urb_hcap_rd(i), urb_hcap_wl(i), &
          urb_hcon_rf(i), urb_hcon_rd(i), urb_hcon_wl(i)) <= 0.) &
    ERROR STOP 'TEB_INTERFACE: material properties must be positive'
  CALL TEB_FILL_PARAMS (1, 1, teb_itype_bem_cool, teb_itype_bem_heat, teb_tcool_target(i:i), &
                        teb_theat_target(i:i), teb_frac_gz(i:i), teb_bem_inf(i:i), teb_bem_vent(i:i), teb_cap_sys_heat(i:i), &
                        teb_bem_cop(i:i), teb_itype_natvent, teb_lgarden, teb_hroad_dir, teb_wall_opt, teb_itype_bem, &
                        teb_lgreenroof, teb_type_garden, teb_type_greenroof, teb_lsolar_panel, teb_lcbs_scheme, &
                        teb_tau_hw_thresh, teb_tau_hw_width, urb_z0_o_z0h_gdn, urb_z0_o_z0h_grf, teb_road_dir(i:i), &
                        fr_garden(i:i), teb_frac_gr(i:i), urb_fr_bld(i:i), urb_h2w(i:i), urb_h_bld(i:i), urb_alb_rf_so(i:i), &
                        urb_alb_rd_so(i:i), urb_alb_wl_so(i:i), urb_alb_rd_th(i:i), urb_alb_rf_th(i:i), urb_alb_wl_th(i:i), &
                        teb_zresidential(i:i), teb_dt_res(i:i), teb_dt_off(i:i), ahf_industry(i:i), teb_ctype_wind, &
                        teb_utc_hour, teb_lgreenroof_ext, teb_lbem_ac, teb_fr_panel(i:i), teb_lroad_irrig, &
                        teb_rd_irrig_start_m(i:i), teb_rd_irrig_end_m(i:i), teb_rd_irrig_start_h(i:i), &
                        teb_rd_irrig_end_h(i:i), teb_rd_irrig_sum(i:i), &
                        HEXCH_ROAD, HEXCH_ROOF, HEXCH_CANYON, i, CZ0_TOWN_DYNCORR, CZD_TOWN_DYNCORR)
  CALL TEB_FILL_DERIVED (1, 1, urb_z0_town, urb_zd_town, urb_hcap_rd(i:i), urb_hcap_rf(i:i), &
                         urb_hcap_wl(i:i), urb_hcon_rd(i:i), urb_hcon_rf(i:i), urb_hcon_wl(i:i), ahf_traffic(i:i), &
                         teb_fai(i:i,:), urb_d_rf, urb_d_rd, urb_d_wl)
  !* Recompute pressure/Exner, density, wind and solar quantities for this
  !* host column in the single-column workspace.
  CALL TEB_FILL_FORCING (1, 1, teb_year, teb_month, teb_day, teb_hour_seconds(1), lon_teb(i:i), lat_teb(i:i), &
                         u(i:i), v(i:i), t(i:i), qv(i:i), ps(i:i), prr_con(i:i), prs_con(i:i), prr_gsp(i:i), prs_gsp(i:i), &
                         prg_gsp(i:i), lwd_s(i:i), swdir_s(i:i), swdifd_s(i:i), hlev_teb(i:i), hlev_teb(i:i))
  !* Copy external garden/greenroof state and fluxes for this column.
  !* Convert both runoffs from kg/m2 to kg/m2/s by dividing by dt.
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
  IF (ntstep == 0) THEN
    CALL TEB_INIT_STATE (1, 1)
  ELSE
    DMT%XUSTAR_TOWN(1:1) = teb_ustar_town(i:i)
    DMT%XPCD_GREENROOF_ATM(1:1) = teb_cd_greenroof_atm(i:i)
  END IF
  IF (PRESENT(teb_troad_before)) &
    teb_troad_before(i:i,:) = TSTATE%XT_ROAD(1:1,:)
  ZINV_L_TOWN_PREV = 0.
  IF (LTOWN_DYNCORR .AND. ntstep /= 0) ZINV_L_TOWN_PREV(1) = teb_inv_l_town_prev(i)
  CALL CALL_DRIVER (ntstep, 1, iblock, dt, teb_year, teb_month, teb_day, teb_hour, teb_min, &
                    teb_sec, teb_hour_seconds(1), sa_uc(i), lon_teb(i), lat_teb(i), FORC, EXT, &
                    teb_tch_gd(i), teb_tcm_gd(i), &
                    DMT, TOPTS, TPARAMS, BOPTS, BPARAMS, TSTATE, BSTATE, TPN, TIR, &
                    PINV_L_TOWN_PREV=ZINV_L_TOWN_PREV)
  IF (LTOWN_DYNCORR) teb_inv_l_town_prev(i) = ZINV_L_TOWN_PREV(1)
  teb_ustar_town(i:i) = DMT%XUSTAR_TOWN(1:1)
  teb_cd_greenroof_atm(i:i) = DMT%XPCD_GREENROOF_ATM(1:1)
  IF (ntstep == 0) DMT%XTSTOWN_S_NOW(1:1) = DMT%XTSTOWN_S(1:1)
  CALL TEB_UNBIND_STATE (1, 1, teb_ti_bld(i:i), teb_twin2(i:i), teb_qi_bld(i:i), teb_cap_sys_rat(i:i), &
                         teb_m_sys_rat(i:i), teb_twin1(i:i), teb_lshade, teb_shad_day(i:i), teb_natvent_night(i:i), &
                         teb_ws_roof(i:i), teb_troof(i:i,:), teb_troad(i:i,:), teb_twalla(i:i,:), teb_twallb(i:i,:), &
                         teb_wsnow_roof(i:i,:), teb_tsnow_roof(i:i,:), teb_rsnow_roof(i:i,:), teb_asnow_roof(i:i), &
                         teb_esnow_roof(i:i), teb_tssnow_roof(i:i), teb_wsnow_road(i:i,:), teb_tsnow_road(i:i,:), &
                         teb_rsnow_road(i:i,:), teb_asnow_road(i:i), teb_esnow_road(i:i), teb_tssnow_road(i:i), &
                         teb_tcanyon(i:i), teb_qcanyon(i:i), teb_ws_road(i:i), teb_tfloor(i:i,:), teb_tmass(i:i,:), &
                         teb_albwin(i:i))
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

  IF (LWRITE_LOG) THEN
    CALL TEB_LOG_EMIT (iblock, DMT, TOPTS, TSTATE, BSTATE, FORC, teb_year, teb_month, teb_day, &
                       teb_hour_seconds, t(i:i), qv(i:i), ps(i:i), rho(i:i), u(i:i), v(i:i), prr_con(i:i), &
                       prs_con(i:i), prr_gsp(i:i), prs_gsp(i:i), prg_gsp(i:i), lwd_s(i:i), swdir_s(i:i), swdifd_s(i:i), &
                       KHOST_CELL=i)
  END IF
END DO
END SUBROUTINE teb_interface

END MODULE sfc_teb
