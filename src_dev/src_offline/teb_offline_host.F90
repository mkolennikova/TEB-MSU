!SFX_LIC This diagnostic host uses the TEB/SURFEX interfaces under the CeCILL-C licence.
! The typed packet mirrors the public API; every OUT, including OPTIONAL, is requested.
! Keep packet, copies, schema and checkpoint serialization synchronized with sfc_teb.
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      11/2026 -- Mikhail Varentsov (MV)
!!        Create a host-owned block/state packet with uniform and perturbed
!!        columns, masks, permutations, restart and external-surface emulation.
!!        Share the complete packet with the ordinary offline driver and retain
!!        per-cell diagnostic/interval state in checkpoints.
!!        Forward the shared snow-filter option through the public API.
!!      11/2026 -- OpenAI Codex
!!        Pass run-level exchange configuration through block and serial steps.
!!      11/2026 -- OpenAI Codex
!!        Bind offline road, roof and snow lengths for block and serial calls.
!!      11/2026 -- OpenAI Codex
!!        Track vegetation roughness ratios with cell identity across restart.
!!        Carry variable layer counts/depths through serial/block calls,
!!        diagnostic packets and versioned checkpoints.
!!------------------------------------------------------------------------------
MODULE TEB_OFFLINE_HOST
USE sfc_teb, ONLY: teb_interface, teb_real_kind, XUNDEF => teb_undef
USE TEB_HOST, ONLY: TEB_HOST_FINAL, TEB_BIND_Z0, TEB_BIND_Z0H, TEB_Z0H_BINDING_t, &
                   TEB_DEFAULT_D_RF, TEB_DEFAULT_D_RD, TEB_DEFAULT_D_WL
USE MODD_TEB_PARAMS_n, ONLY: TEB_Z0_t
USE TEB_LOG, ONLY: TEB_LOG_INIT, TEB_LOG_FINAL
USE MODD_SURF_PAR, ONLY: teb_snow_check
USE MODD_TEB_OPTION_n, ONLY: CTEB_EXCH_DEFAULT, TEB_Z0H_t
USE MODD_CSTS, ONLY: XRD,XRV,XG,XSTEFAN
USE MODI_INI_CSTS, ONLY: INI_CSTS
USE MODE_THERMOS, ONLY: QSAT
USE MODI_GARDEN, ONLY: GARDEN_PCD
USE MODE_GARDEN_BALANCE, ONLY: GARDEN_PCD_NEUTRAL,GARDEN_PCH_NEUTRAL,XVMIN_GD
USE MODD_PROXI_SVAT_PAR, ONLY: proxy_phu_gdn,proxy_phu_grf
USE MODI_OL_ALLOC_ATM, ONLY: OL_ALLOC_ATM
USE MODI_OL_READ_ATM, ONLY: OL_READ_ATM
USE MODI_OL_TIME_INTERP_ATM, ONLY: OL_TIME_INTERP_ATM
USE MODI_ADD_FORECAST_TO_DATE_SURF, ONLY: ADD_FORECAST_TO_DATE_SURF
USE MODD_FORC_ATM, ONLY: XZREF,XUREF,XTA,XQA,XRHOA,XPS,XU,XV,XLW,XDIR_SW,XSCA_SW,XRAIN,XSNOW
USE, INTRINSIC :: ISO_FORTRAN_ENV, ONLY: INT32
USE, INTRINSIC :: IEEE_ARITHMETIC, ONLY: IEEE_IS_FINITE
IMPLICIT NONE
PRIVATE
PUBLIC :: BLOCK_CONFIG, TEB_BLOCK, field_count, READ_BLOCK_CONFIG
PUBLIC :: allocate_block, copy_column, copy_result, api_step, active, validate
PUBLIC :: pack, write_schema, sanitize_outputs, dump, permute
PUBLIC :: config_echo, save_checkpoint, load_checkpoint
PUBLIC :: load_file, forcing, modify
TYPE BLOCK_CONFIG
  INTEGER :: nvec=1
  INTEGER :: nblocks=1
  INTEGER :: nsteps=48
  INTEGER :: source_nvec=0
  INTEGER :: sample_column=0
  INTEGER :: ivstart=1
  INTEGER :: ivend=-1
  INTEGER :: mask_stride=0
  INTEGER :: perturb_column=1
  INTEGER :: from_step=0
  INTEGER :: permute_step=-1
  INTEGER :: stop_after=0
  REAL(teb_real_kind) :: dt=300.
  REAL(teb_real_kind) :: factor=1.
  REAL(teb_real_kind) :: delta=0.
  INTEGER :: year=2026
  INTEGER :: month=7
  INTEGER :: day=10
  INTEGER :: hour=12
  INTEGER :: minute=0
  REAL(teb_real_kind) :: lon=37.6
  REAL(teb_real_kind) :: lat=55.7
  REAL(teb_real_kind) :: height=28.
  CHARACTER(LEN=24) :: profile='DEF'
  CHARACTER(LEN=16) :: scenario='UNIFORM'
  CHARACTER(LEN=16) :: layout='BLOCK'
  CHARACTER(LEN=40) :: parameter='none'
  CHARACTER(LEN=16) :: forcing_source='SYNTHETIC'
  CHARACTER(LEN=512) :: forcing_nml=''
  CHARACTER(LEN=512) :: checkpoint_file=''
  CHARACTER(LEN=512) :: restart_file=''
  CHARACTER(LEN=24) :: test_fault='NONE'
  LOGICAL :: reverse=.FALSE.
  LOGICAL :: fresh_work=.FALSE.
  LOGICAL :: model_log=.FALSE.
  LOGICAL :: test_mode=.FALSE.
  LOGICAL :: write_emu=.TRUE.
  LOGICAL :: write_runoff=.TRUE.
  LOGICAL :: test_dump=.FALSE.
  LOGICAL :: verbose=.FALSE.
  CHARACTER(LEN=1024) :: param_nml=''
  INTEGER(INT32) :: parameter_signature=0
END TYPE
TYPE TEB_BLOCK
  INTEGER :: ntstep
  INTEGER :: nvec
  INTEGER :: iblock
  REAL(teb_real_kind) :: dt
  INTEGER :: teb_year
  INTEGER :: teb_month
  INTEGER :: teb_day
  INTEGER :: teb_hour
  INTEGER :: teb_min
  INTEGER :: teb_sec
  REAL(teb_real_kind),DIMENSION(1) :: teb_hour_seconds
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: sa_uc
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: lon_teb
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: lat_teb
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: hlev_teb
  INTEGER :: ivstart
  INTEGER :: ivend
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: u
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: v
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: t
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: qv
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: ps
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: rho
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: prr_con
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: prs_con
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: prr_gsp
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: prs_gsp
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: prg_gsp
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: lwd_s
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: swdir_s
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: swdifd_s
  INTEGER :: teb_nroof_layer
  INTEGER :: teb_nroad_layer
  INTEGER :: teb_nwall_layer
  INTEGER :: teb_nfloor_layer
  REAL(teb_real_kind), ALLOCATABLE :: urb_d_rf(:), urb_d_rd(:), urb_d_wl(:)
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_fr_bld
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: fr_garden
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_h2w
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_h_bld
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_hcap_rd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_hcap_rf
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_hcap_wl
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_hcon_rd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_hcon_rf
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_hcon_wl
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_alb_rd_so
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_alb_rf_so
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_alb_wl_so
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_alb_rd_th
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_alb_rf_th
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: urb_alb_wl_th
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: ahf_traffic
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: ahf_industry
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_ti_bld
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_troof
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_troad
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_twalla
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_twallb
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_tfloor
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_tmass
  REAL(teb_real_kind),ALLOCATABLE, DIMENSION(:) :: teb_qi_bld
  REAL(teb_real_kind),ALLOCATABLE, DIMENSION(:) :: teb_tcanyon
  REAL(teb_real_kind),ALLOCATABLE, DIMENSION(:) :: teb_qcanyon
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_ws_roof
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_ws_road
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_wsnow_roof
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_wsnow_road
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_tsnow_roof
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_tsnow_road
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_rsnow_roof
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_rsnow_road
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_tssnow_roof
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_tssnow_road
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_asnow_roof
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_asnow_road
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_esnow_roof
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_esnow_road
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_twin1
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_twin2
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_albwin
  CHARACTER(LEN=3) :: teb_itype_bem
  LOGICAL :: teb_lbem_ac
  CHARACTER(LEN=4) :: teb_itype_natvent
  CHARACTER(LEN=6) :: teb_itype_bem_cool
  CHARACTER(LEN=6) :: teb_itype_bem_heat
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_frac_gz
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_tcool_target
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_theat_target
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_bem_vent
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_bem_inf
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_bem_cop
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_cap_sys_rat
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_m_sys_rat
  LOGICAL ,ALLOCATABLE, DIMENSION(:) :: teb_shad_day
  LOGICAL ,ALLOCATABLE, DIMENSION(:) :: teb_natvent_night
  LOGICAL :: teb_lgreenroof
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_frac_gr
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_z0_gr
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_alb_gr
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_emis_gr
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_ts_gr
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_qs_gr
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_shfl_gr
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_lhfl_gr
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_qvfl_gr
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_runoff_gr
  LOGICAL :: teb_lgarden
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_z0_gd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_alb_gd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_emis_gd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_ts_gd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_qs_gd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_shfl_gd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_lhfl_gd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_qvfl_gd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_tch_gd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_tcm_gd
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_runoff_gd
  INTEGER :: teb_itype_wind
  ! Run options are reread from the parameter namelist on restart.
  CHARACTER(LEN=6) :: teb_ctype_exch_road=CTEB_EXCH_DEFAULT
  CHARACTER(LEN=6) :: teb_ctype_exch_roof=CTEB_EXCH_DEFAULT
  CHARACTER(LEN=6) :: teb_ctype_exch_canyon=CTEB_EXCH_DEFAULT
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:,:) :: teb_fai
  CHARACTER(LEN=9) :: teb_type_garden
  CHARACTER(LEN=9) :: teb_type_greenroof
  LOGICAL :: teb_lgreenroof_ext
  CHARACTER(LEN=4) :: teb_hroad_dir
  CHARACTER(LEN=4) :: teb_wall_opt
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_road_dir
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_zresidential
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_dt_res
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_dt_off
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_cap_sys_heat
  LOGICAL :: teb_lsolar_panel
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_fr_panel
  LOGICAL :: teb_lroad_irrig
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_rd_irrig_start_m
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_rd_irrig_end_m
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_rd_irrig_start_h
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_rd_irrig_end_h
  REAL(teb_real_kind) ,ALLOCATABLE, DIMENSION(:) :: teb_rd_irrig_sum
  INTEGER :: teb_utc_hour
  LOGICAL :: teb_lshade
  CHARACTER(LEN=16) :: urb_z0_town
  CHARACTER(LEN=16) :: urb_zd_town
  TYPE(TEB_Z0_t) :: tz0   ! Restored from the parameter file on restart.
  TYPE(TEB_Z0H_t) :: tz0h
  REAL(teb_real_kind), ALLOCATABLE :: urb_z0_o_z0h_gdn(:)
  REAL(teb_real_kind), ALLOCATABLE :: urb_z0_o_z0h_grf(:)
  LOGICAL :: teb_lcbs_scheme
  REAL(teb_real_kind) :: teb_tau_hw_thresh
  REAL(teb_real_kind) :: teb_tau_hw_width
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_wind_canyon
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_u_can_ped
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_u_can_10m
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_sobs
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_thbs
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_runoff_road
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_runoff_roof
  INTEGER, ALLOCATABLE, DIMENSION(:) :: kteb_log_block
  INTEGER, ALLOCATABLE, DIMENSION(:) :: kteb_log_point
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_ustar_town
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_cd_greenroof_atm
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:,:) :: teb_troad_before
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_ucanyon
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_vcanyon
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_tsroof
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_tswalla
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_tswallb
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_shfl
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_lhfl
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_qvfl
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_tstown_s
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_qstown_s
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_wstown
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_runoff_town
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_tssnow_town
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_wsnow_town
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_rsnow_town
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_frsnow
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_hsnow_town
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_tch_town
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_shfl_snow
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_lhfl_snow
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_snow_melt
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_alb_so
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_emis_town
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_hwaste
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_hvac_cool
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_hvac_heat
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_dqs_town
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_gflux
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_shfl_rf
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_shfl_rd
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_shfl_wl
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_ac_rf
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_ac_rd
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_ac_wl
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_ac_top
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_tch_rf
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_tch_rd
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_tch_wl
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_tch_top
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_wind_top
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_cd_garden_atm
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: teb_ch_garden_atm
  REAL(teb_real_kind), ALLOCATABLE, DIMENSION(:) :: ahf_traffic_now
  REAL(teb_real_kind), ALLOCATABLE :: emu_tau(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_pcd_can(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_pcd_atm(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_pch_can(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_pch_atm(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_v_can(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_v_atm(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_ca_can(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_ca_atm(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_ca_eff(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_v_star(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_t_star(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_q_star(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_ch_eff(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_cd_eff(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_ch_naive(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_psw(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_plw(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_ts(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_rn(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_h(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_le(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_evap(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_qsat(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_pac(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_puw(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gflux(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_sfco2(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_runoff(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_drain(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_irrig(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_pcd(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_pch(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_v(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_t(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_q(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_ca(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_cd(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_ch(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_psw(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_plw(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_ts(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_rn(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_h(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_le(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_evap(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_qsat(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_pac(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_puw(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_gflux(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_sfco2(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_runoff(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_drain(:)
  REAL(teb_real_kind), ALLOCATABLE :: emu_gr_irrig(:)
  REAL(teb_real_kind), ALLOCATABLE :: runoff_road_acc(:)
  REAL(teb_real_kind), ALLOCATABLE :: runoff_roof_acc(:)
  INTEGER :: output_count=0
END TYPE

CONTAINS
SUBROUTINE READ_BLOCK_CONFIG(path,c)
CHARACTER(LEN=*),INTENT(IN)::path
TYPE(BLOCK_CONFIG),INTENT(OUT)::c
INTEGER::unit,rc
CHARACTER(LEN=512)::message
INTEGER :: nvec
INTEGER :: nblocks
INTEGER :: nsteps
INTEGER :: source_nvec
INTEGER :: sample_column
INTEGER :: ivstart
INTEGER :: ivend
INTEGER :: mask_stride
INTEGER :: perturb_column
INTEGER :: from_step
INTEGER :: permute_step
INTEGER :: stop_after
REAL(teb_real_kind) :: dt
REAL(teb_real_kind) :: factor
REAL(teb_real_kind) :: delta
INTEGER :: year
INTEGER :: month
INTEGER :: day
INTEGER :: hour
INTEGER :: minute
REAL(teb_real_kind) :: lon
REAL(teb_real_kind) :: lat
REAL(teb_real_kind) :: height
CHARACTER(LEN=24) :: profile
CHARACTER(LEN=16) :: scenario
CHARACTER(LEN=16) :: layout
CHARACTER(LEN=40) :: parameter
CHARACTER(LEN=16) :: forcing_source
CHARACTER(LEN=512) :: forcing_nml
CHARACTER(LEN=512) :: checkpoint_file
CHARACTER(LEN=512) :: restart_file
CHARACTER(LEN=24) :: test_fault
LOGICAL :: reverse
LOGICAL :: fresh_work
LOGICAL :: model_log
CHARACTER(LEN=1024) :: param_nml
NAMELIST /block_test/ param_nml, nvec, &
  nblocks, &
  nsteps, &
  source_nvec, &
  sample_column, &
  ivstart, &
  ivend, &
  mask_stride, &
  perturb_column, &
  from_step, &
  permute_step, &
  stop_after, &
  dt, &
  factor, &
  delta, &
  year, &
  month, &
  day, &
  hour, &
  minute, &
  lon, &
  lat, &
  height, &
  profile, &
  scenario, &
  layout, &
  parameter, &
  forcing_source, &
  forcing_nml, &
  checkpoint_file, &
  restart_file, &
  test_fault, &
  reverse, &
  fresh_work, &
  model_log
param_nml=c%param_nml
nvec=-1
nblocks=c%nblocks
nsteps=c%nsteps
source_nvec=c%source_nvec
sample_column=c%sample_column
ivstart=c%ivstart
ivend=c%ivend
mask_stride=c%mask_stride
perturb_column=c%perturb_column
from_step=c%from_step
permute_step=c%permute_step
stop_after=c%stop_after
dt=c%dt
factor=c%factor
delta=c%delta
year=c%year
month=c%month
day=c%day
hour=c%hour
minute=c%minute
lon=c%lon
lat=c%lat
height=c%height
profile=c%profile
scenario=c%scenario
layout=c%layout
parameter=c%parameter
forcing_source=c%forcing_source
forcing_nml=c%forcing_nml
checkpoint_file=c%checkpoint_file
restart_file=c%restart_file
test_fault=c%test_fault
reverse=c%reverse
fresh_work=c%fresh_work
model_log=c%model_log
OPEN(NEWUNIT=unit,FILE=TRIM(path),STATUS='OLD',ACTION='READ',IOSTAT=rc)
IF(rc/=0) ERROR STOP 'Cannot open block configuration'
READ(unit,NML=block_test,IOSTAT=rc,IOMSG=message)
CLOSE(unit)
IF(rc/=0) THEN
  WRITE(*,*) TRIM(message)
  ERROR STOP 'Invalid block_test namelist'
END IF
c%param_nml=param_nml
c%nvec=nvec
c%nblocks=nblocks
c%nsteps=nsteps
c%source_nvec=source_nvec
c%sample_column=sample_column
c%ivstart=ivstart
c%ivend=ivend
c%mask_stride=mask_stride
c%perturb_column=perturb_column
c%from_step=from_step
c%permute_step=permute_step
c%stop_after=stop_after
c%dt=dt
c%factor=factor
c%delta=delta
c%year=year
c%month=month
c%day=day
c%hour=hour
c%minute=minute
c%lon=lon
c%lat=lat
c%height=height
c%profile=profile
c%scenario=scenario
c%layout=layout
c%parameter=parameter
c%forcing_source=forcing_source
c%forcing_nml=forcing_nml
c%checkpoint_file=checkpoint_file
c%restart_file=restart_file
c%test_fault=test_fault
c%reverse=reverse
c%fresh_work=fresh_work
c%model_log=model_log
END SUBROUTINE
SUBROUTINE allocate_block(c,knvec,kroof,kroad,kwall)
TYPE(TEB_BLOCK),INTENT(OUT)::c
INTEGER,INTENT(IN)::knvec
INTEGER,OPTIONAL,INTENT(IN)::kroof,kroad,kwall
INTEGER::nr,nd,nw
nr=5
nd=5
nw=5
IF(PRESENT(kroof)) nr=kroof
IF(PRESENT(kroad)) nd=kroad
IF(PRESENT(kwall)) nw=kwall
IF(MIN(knvec,nr,nd,nw)<1) ERROR STOP 'Invalid offline block or layer dimensions'
ALLOCATE(c%urb_d_rf(nr),c%urb_d_rd(nd),c%urb_d_wl(nw))
c%urb_d_rf=XUNDEF
c%urb_d_rd=XUNDEF
c%urb_d_wl=XUNDEF
IF(nr==5) c%urb_d_rf=TEB_DEFAULT_D_RF
IF(nd==5) c%urb_d_rd=TEB_DEFAULT_D_RD
IF(nw==5) c%urb_d_wl=TEB_DEFAULT_D_WL
ALLOCATE(c%sa_uc(knvec))
ALLOCATE(c%lon_teb(knvec))
ALLOCATE(c%lat_teb(knvec))
ALLOCATE(c%hlev_teb(knvec))
ALLOCATE(c%u(knvec))
ALLOCATE(c%v(knvec))
ALLOCATE(c%t(knvec))
ALLOCATE(c%qv(knvec))
ALLOCATE(c%ps(knvec))
ALLOCATE(c%rho(knvec))
ALLOCATE(c%prr_con(knvec))
ALLOCATE(c%prs_con(knvec))
ALLOCATE(c%prr_gsp(knvec))
ALLOCATE(c%prs_gsp(knvec))
ALLOCATE(c%prg_gsp(knvec))
ALLOCATE(c%lwd_s(knvec))
ALLOCATE(c%swdir_s(knvec))
ALLOCATE(c%swdifd_s(knvec))
ALLOCATE(c%urb_fr_bld(knvec))
ALLOCATE(c%fr_garden(knvec))
ALLOCATE(c%urb_z0_o_z0h_gdn(knvec),c%urb_z0_o_z0h_grf(knvec))
ALLOCATE(c%urb_h2w(knvec))
ALLOCATE(c%urb_h_bld(knvec))
ALLOCATE(c%urb_hcap_rd(knvec))
ALLOCATE(c%urb_hcap_rf(knvec))
ALLOCATE(c%urb_hcap_wl(knvec))
ALLOCATE(c%urb_hcon_rd(knvec))
ALLOCATE(c%urb_hcon_rf(knvec))
ALLOCATE(c%urb_hcon_wl(knvec))
ALLOCATE(c%urb_alb_rd_so(knvec))
ALLOCATE(c%urb_alb_rf_so(knvec))
ALLOCATE(c%urb_alb_wl_so(knvec))
ALLOCATE(c%urb_alb_rd_th(knvec))
ALLOCATE(c%urb_alb_rf_th(knvec))
ALLOCATE(c%urb_alb_wl_th(knvec))
ALLOCATE(c%ahf_traffic(knvec))
ALLOCATE(c%ahf_industry(knvec))
ALLOCATE(c%teb_ti_bld(knvec))
ALLOCATE(c%teb_troof(knvec,nr))
ALLOCATE(c%teb_troad(knvec,nd))
ALLOCATE(c%teb_twalla(knvec,nw))
ALLOCATE(c%teb_twallb(knvec,nw))
ALLOCATE(c%teb_tfloor(knvec,1:5))
ALLOCATE(c%teb_tmass(knvec,1:5))
ALLOCATE(c%teb_qi_bld(knvec))
ALLOCATE(c%teb_tcanyon(knvec))
ALLOCATE(c%teb_qcanyon(knvec))
ALLOCATE(c%teb_ws_roof(knvec))
ALLOCATE(c%teb_ws_road(knvec))
ALLOCATE(c%teb_wsnow_roof(knvec,1))
ALLOCATE(c%teb_wsnow_road(knvec,1))
ALLOCATE(c%teb_tsnow_roof(knvec,1))
ALLOCATE(c%teb_tsnow_road(knvec,1))
ALLOCATE(c%teb_rsnow_roof(knvec,1))
ALLOCATE(c%teb_rsnow_road(knvec,1))
ALLOCATE(c%teb_tssnow_roof(knvec))
ALLOCATE(c%teb_tssnow_road(knvec))
ALLOCATE(c%teb_asnow_roof(knvec))
ALLOCATE(c%teb_asnow_road(knvec))
ALLOCATE(c%teb_esnow_roof(knvec))
ALLOCATE(c%teb_esnow_road(knvec))
ALLOCATE(c%teb_twin1(knvec))
ALLOCATE(c%teb_twin2(knvec))
ALLOCATE(c%teb_albwin(knvec))
ALLOCATE(c%teb_frac_gz(knvec))
ALLOCATE(c%teb_tcool_target(knvec))
ALLOCATE(c%teb_theat_target(knvec))
ALLOCATE(c%teb_bem_vent(knvec))
ALLOCATE(c%teb_bem_inf(knvec))
ALLOCATE(c%teb_bem_cop(knvec))
ALLOCATE(c%teb_cap_sys_rat(knvec))
ALLOCATE(c%teb_m_sys_rat(knvec))
ALLOCATE(c%teb_shad_day(knvec))
ALLOCATE(c%teb_natvent_night(knvec))
ALLOCATE(c%teb_frac_gr(knvec))
ALLOCATE(c%teb_z0_gr(knvec))
ALLOCATE(c%teb_alb_gr(knvec))
ALLOCATE(c%teb_emis_gr(knvec))
ALLOCATE(c%teb_ts_gr(knvec))
ALLOCATE(c%teb_qs_gr(knvec))
ALLOCATE(c%teb_shfl_gr(knvec))
ALLOCATE(c%teb_lhfl_gr(knvec))
ALLOCATE(c%teb_qvfl_gr(knvec))
ALLOCATE(c%teb_runoff_gr(knvec))
ALLOCATE(c%teb_z0_gd(knvec))
ALLOCATE(c%teb_alb_gd(knvec))
ALLOCATE(c%teb_emis_gd(knvec))
ALLOCATE(c%teb_ts_gd(knvec))
ALLOCATE(c%teb_qs_gd(knvec))
ALLOCATE(c%teb_shfl_gd(knvec))
ALLOCATE(c%teb_lhfl_gd(knvec))
ALLOCATE(c%teb_qvfl_gd(knvec))
ALLOCATE(c%teb_tch_gd(knvec))
ALLOCATE(c%teb_tcm_gd(knvec))
ALLOCATE(c%teb_runoff_gd(knvec))
ALLOCATE(c%teb_fai(knvec,1:8))
ALLOCATE(c%teb_road_dir(knvec))
ALLOCATE(c%teb_zresidential(knvec))
ALLOCATE(c%teb_dt_res(knvec))
ALLOCATE(c%teb_dt_off(knvec))
ALLOCATE(c%teb_cap_sys_heat(knvec))
ALLOCATE(c%teb_fr_panel(knvec))
ALLOCATE(c%teb_rd_irrig_start_m(knvec))
ALLOCATE(c%teb_rd_irrig_end_m(knvec))
ALLOCATE(c%teb_rd_irrig_start_h(knvec))
ALLOCATE(c%teb_rd_irrig_end_h(knvec))
ALLOCATE(c%teb_rd_irrig_sum(knvec))
ALLOCATE(c%teb_wind_canyon(knvec))
ALLOCATE(c%teb_u_can_ped(knvec))
ALLOCATE(c%teb_u_can_10m(knvec))
ALLOCATE(c%teb_sobs(knvec))
ALLOCATE(c%teb_thbs(knvec))
ALLOCATE(c%teb_runoff_road(knvec))
ALLOCATE(c%teb_runoff_roof(knvec))
ALLOCATE(c%kteb_log_block(0))
ALLOCATE(c%kteb_log_point(0))
ALLOCATE(c%teb_ustar_town(knvec))
ALLOCATE(c%teb_cd_greenroof_atm(knvec))
ALLOCATE(c%teb_troad_before(knvec,nd))
ALLOCATE(c%teb_ucanyon(knvec))
ALLOCATE(c%teb_vcanyon(knvec))
ALLOCATE(c%teb_tsroof(knvec))
ALLOCATE(c%teb_tswalla(knvec))
ALLOCATE(c%teb_tswallb(knvec))
ALLOCATE(c%teb_shfl(knvec))
ALLOCATE(c%teb_lhfl(knvec))
ALLOCATE(c%teb_qvfl(knvec))
ALLOCATE(c%teb_tstown_s(knvec))
ALLOCATE(c%teb_qstown_s(knvec))
ALLOCATE(c%teb_wstown(knvec))
ALLOCATE(c%teb_runoff_town(knvec))
ALLOCATE(c%teb_tssnow_town(knvec))
ALLOCATE(c%teb_wsnow_town(knvec))
ALLOCATE(c%teb_rsnow_town(knvec))
ALLOCATE(c%teb_frsnow(knvec))
ALLOCATE(c%teb_hsnow_town(knvec))
ALLOCATE(c%teb_tch_town(knvec))
ALLOCATE(c%teb_shfl_snow(knvec))
ALLOCATE(c%teb_lhfl_snow(knvec))
ALLOCATE(c%teb_snow_melt(knvec))
ALLOCATE(c%teb_alb_so(knvec))
ALLOCATE(c%teb_emis_town(knvec))
ALLOCATE(c%teb_hwaste(knvec))
ALLOCATE(c%teb_hvac_cool(knvec))
ALLOCATE(c%teb_hvac_heat(knvec))
ALLOCATE(c%teb_dqs_town(knvec))
ALLOCATE(c%teb_gflux(knvec))
ALLOCATE(c%teb_shfl_rf(knvec))
ALLOCATE(c%teb_shfl_rd(knvec))
ALLOCATE(c%teb_shfl_wl(knvec))
ALLOCATE(c%teb_ac_rf(knvec))
ALLOCATE(c%teb_ac_rd(knvec))
ALLOCATE(c%teb_ac_wl(knvec))
ALLOCATE(c%teb_ac_top(knvec))
ALLOCATE(c%teb_tch_rf(knvec))
ALLOCATE(c%teb_tch_rd(knvec))
ALLOCATE(c%teb_tch_wl(knvec))
ALLOCATE(c%teb_tch_top(knvec))
ALLOCATE(c%teb_wind_top(knvec))
ALLOCATE(c%teb_cd_garden_atm(knvec))
ALLOCATE(c%teb_ch_garden_atm(knvec))
ALLOCATE(c%ahf_traffic_now(knvec))
c%ntstep=0
c%nvec=0
c%iblock=0
c%dt=0.
c%teb_year=0
c%teb_month=0
c%teb_day=0
c%teb_hour=0
c%teb_min=0
c%teb_sec=0
c%teb_hour_seconds=0.
c%sa_uc=0.
c%lon_teb=0.
c%lat_teb=0.
c%hlev_teb=0.
c%ivstart=0
c%ivend=0
c%u=0.
c%v=0.
c%t=0.
c%qv=0.
c%ps=0.
c%rho=0.
c%prr_con=0.
c%prs_con=0.
c%prr_gsp=0.
c%prs_gsp=0.
c%prg_gsp=0.
c%lwd_s=0.
c%swdir_s=0.
c%swdifd_s=0.
c%teb_nroof_layer=nr
c%teb_nroad_layer=nd
c%teb_nwall_layer=nw
c%teb_nfloor_layer=5
c%urb_fr_bld=0.
c%fr_garden=0.
c%urb_h2w=0.
c%urb_h_bld=0.
c%urb_hcap_rd=0.
c%urb_hcap_rf=0.
c%urb_hcap_wl=0.
c%urb_hcon_rd=0.
c%urb_hcon_rf=0.
c%urb_hcon_wl=0.
c%urb_alb_rd_so=0.
c%urb_alb_rf_so=0.
c%urb_alb_wl_so=0.
c%urb_alb_rd_th=0.
c%urb_alb_rf_th=0.
c%urb_alb_wl_th=0.
c%ahf_traffic=0.
c%ahf_industry=0.
c%teb_ti_bld=0.
c%teb_troof=0.
c%teb_troad=0.
c%teb_twalla=0.
c%teb_twallb=0.
c%teb_tfloor=0.
c%teb_tmass=0.
c%teb_qi_bld=0.
c%teb_tcanyon=0.
c%teb_qcanyon=0.
c%teb_ws_roof=0.
c%teb_ws_road=0.
c%teb_wsnow_roof=0.
c%teb_wsnow_road=0.
c%teb_tsnow_roof=0.
c%teb_tsnow_road=0.
c%teb_rsnow_roof=0.
c%teb_rsnow_road=0.
c%teb_tssnow_roof=0.
c%teb_tssnow_road=0.
c%teb_asnow_roof=0.
c%teb_asnow_road=0.
c%teb_esnow_roof=0.
c%teb_esnow_road=0.
c%teb_twin1=0.
c%teb_twin2=0.
c%teb_albwin=XUNDEF
c%teb_itype_bem=' '
c%teb_lbem_ac=.FALSE.
c%teb_itype_natvent=' '
c%teb_itype_bem_cool=' '
c%teb_itype_bem_heat=' '
c%teb_frac_gz=0.
c%teb_tcool_target=0.
c%teb_theat_target=0.
c%teb_bem_vent=0.
c%teb_bem_inf=0.
c%teb_bem_cop=0.
c%teb_cap_sys_rat=0.
c%teb_m_sys_rat=0.
c%teb_shad_day=.FALSE.
c%teb_natvent_night=.FALSE.
c%teb_lgreenroof=.FALSE.
c%teb_frac_gr=0.
c%teb_z0_gr=0.
c%teb_alb_gr=0.
c%teb_emis_gr=0.
c%teb_ts_gr=0.
c%teb_qs_gr=0.
c%teb_shfl_gr=0.
c%teb_lhfl_gr=0.
c%teb_qvfl_gr=0.
c%teb_runoff_gr=0.
c%teb_lgarden=.FALSE.
c%teb_z0_gd=0.
c%teb_alb_gd=0.
c%teb_emis_gd=0.
c%teb_ts_gd=0.
c%teb_qs_gd=0.
c%teb_shfl_gd=0.
c%teb_lhfl_gd=0.
c%teb_qvfl_gd=0.
c%teb_tch_gd=XUNDEF
c%teb_tcm_gd=0.
c%teb_runoff_gd=0.
c%teb_itype_wind=0
c%teb_fai=0.
c%teb_type_garden=' '
c%teb_type_greenroof=' '
c%teb_lgreenroof_ext=.FALSE.
c%teb_hroad_dir=' '
c%teb_wall_opt=' '
c%teb_road_dir=0.
c%teb_zresidential=0.
c%teb_dt_res=0.
c%teb_dt_off=0.
c%teb_cap_sys_heat=0.
c%teb_lsolar_panel=.FALSE.
c%teb_fr_panel=0.
c%teb_lroad_irrig=.FALSE.
c%teb_rd_irrig_start_m=0.
c%teb_rd_irrig_end_m=0.
c%teb_rd_irrig_start_h=0.
c%teb_rd_irrig_end_h=0.
c%teb_rd_irrig_sum=0.
c%teb_utc_hour=0
c%teb_lshade=.FALSE.
c%urb_z0_town=' '
c%urb_zd_town=' '
c%urb_z0_o_z0h_gdn=0.
c%urb_z0_o_z0h_grf=0.
c%teb_lcbs_scheme=.FALSE.
c%teb_tau_hw_thresh=0.
c%teb_tau_hw_width=0.
c%teb_wind_canyon=XUNDEF
c%teb_u_can_ped=XUNDEF
c%teb_u_can_10m=XUNDEF
c%teb_sobs=XUNDEF
c%teb_thbs=XUNDEF
c%teb_runoff_road=XUNDEF
c%teb_runoff_roof=XUNDEF
c%kteb_log_block=0
c%kteb_log_point=0
c%teb_ustar_town=0.
c%teb_cd_greenroof_atm=0.
c%teb_troad_before=XUNDEF
c%teb_ucanyon=XUNDEF
c%teb_vcanyon=XUNDEF
c%teb_tsroof=XUNDEF
c%teb_tswalla=XUNDEF
c%teb_tswallb=XUNDEF
c%teb_shfl=XUNDEF
c%teb_lhfl=XUNDEF
c%teb_qvfl=XUNDEF
c%teb_tstown_s=XUNDEF
c%teb_qstown_s=XUNDEF
c%teb_wstown=XUNDEF
c%teb_runoff_town=XUNDEF
c%teb_tssnow_town=XUNDEF
c%teb_wsnow_town=XUNDEF
c%teb_rsnow_town=XUNDEF
c%teb_frsnow=XUNDEF
c%teb_hsnow_town=XUNDEF
c%teb_tch_town=XUNDEF
c%teb_shfl_snow=XUNDEF
c%teb_lhfl_snow=XUNDEF
c%teb_snow_melt=XUNDEF
c%teb_alb_so=XUNDEF
c%teb_emis_town=XUNDEF
c%teb_hwaste=XUNDEF
c%teb_hvac_cool=XUNDEF
c%teb_hvac_heat=XUNDEF
c%teb_dqs_town=XUNDEF
c%teb_gflux=XUNDEF
c%teb_shfl_rf=XUNDEF
c%teb_shfl_rd=XUNDEF
c%teb_shfl_wl=XUNDEF
c%teb_ac_rf=XUNDEF
c%teb_ac_rd=XUNDEF
c%teb_ac_wl=XUNDEF
c%teb_ac_top=XUNDEF
c%teb_tch_rf=XUNDEF
c%teb_tch_rd=XUNDEF
c%teb_tch_wl=XUNDEF
c%teb_tch_top=XUNDEF
c%teb_wind_top=XUNDEF
c%teb_cd_garden_atm=XUNDEF
c%teb_ch_garden_atm=XUNDEF
c%ahf_traffic_now=XUNDEF
c%nvec=knvec
c%output_count=0
ALLOCATE(c%emu_tau(knvec))
c%emu_tau=0.
ALLOCATE(c%emu_pcd_can(knvec))
c%emu_pcd_can=0.
ALLOCATE(c%emu_pcd_atm(knvec))
c%emu_pcd_atm=0.
ALLOCATE(c%emu_pch_can(knvec))
c%emu_pch_can=0.
ALLOCATE(c%emu_pch_atm(knvec))
c%emu_pch_atm=0.
ALLOCATE(c%emu_v_can(knvec))
c%emu_v_can=0.
ALLOCATE(c%emu_v_atm(knvec))
c%emu_v_atm=0.
ALLOCATE(c%emu_ca_can(knvec))
c%emu_ca_can=0.
ALLOCATE(c%emu_ca_atm(knvec))
c%emu_ca_atm=0.
ALLOCATE(c%emu_ca_eff(knvec))
c%emu_ca_eff=0.
ALLOCATE(c%emu_v_star(knvec))
c%emu_v_star=0.
ALLOCATE(c%emu_t_star(knvec))
c%emu_t_star=0.
ALLOCATE(c%emu_q_star(knvec))
c%emu_q_star=0.
ALLOCATE(c%emu_ch_eff(knvec))
c%emu_ch_eff=0.
ALLOCATE(c%emu_cd_eff(knvec))
c%emu_cd_eff=0.
ALLOCATE(c%emu_ch_naive(knvec))
c%emu_ch_naive=0.
ALLOCATE(c%emu_psw(knvec))
c%emu_psw=0.
ALLOCATE(c%emu_plw(knvec))
c%emu_plw=0.
ALLOCATE(c%emu_ts(knvec))
c%emu_ts=0.
ALLOCATE(c%emu_rn(knvec))
c%emu_rn=0.
ALLOCATE(c%emu_h(knvec))
c%emu_h=0.
ALLOCATE(c%emu_le(knvec))
c%emu_le=0.
ALLOCATE(c%emu_evap(knvec))
c%emu_evap=0.
ALLOCATE(c%emu_qsat(knvec))
c%emu_qsat=0.
ALLOCATE(c%emu_pac(knvec))
c%emu_pac=0.
ALLOCATE(c%emu_puw(knvec))
c%emu_puw=0.
ALLOCATE(c%emu_gflux(knvec))
c%emu_gflux=0.
ALLOCATE(c%emu_sfco2(knvec))
c%emu_sfco2=0.
ALLOCATE(c%emu_runoff(knvec))
c%emu_runoff=0.
ALLOCATE(c%emu_drain(knvec))
c%emu_drain=0.
ALLOCATE(c%emu_irrig(knvec))
c%emu_irrig=0.
ALLOCATE(c%emu_gr_pcd(knvec))
c%emu_gr_pcd=0.
ALLOCATE(c%emu_gr_pch(knvec))
c%emu_gr_pch=0.
ALLOCATE(c%emu_gr_v(knvec))
c%emu_gr_v=0.
ALLOCATE(c%emu_gr_t(knvec))
c%emu_gr_t=0.
ALLOCATE(c%emu_gr_q(knvec))
c%emu_gr_q=0.
ALLOCATE(c%emu_gr_ca(knvec))
c%emu_gr_ca=0.
ALLOCATE(c%emu_gr_cd(knvec))
c%emu_gr_cd=0.
ALLOCATE(c%emu_gr_ch(knvec))
c%emu_gr_ch=0.
ALLOCATE(c%emu_gr_psw(knvec))
c%emu_gr_psw=0.
ALLOCATE(c%emu_gr_plw(knvec))
c%emu_gr_plw=0.
ALLOCATE(c%emu_gr_ts(knvec))
c%emu_gr_ts=0.
ALLOCATE(c%emu_gr_rn(knvec))
c%emu_gr_rn=0.
ALLOCATE(c%emu_gr_h(knvec))
c%emu_gr_h=0.
ALLOCATE(c%emu_gr_le(knvec))
c%emu_gr_le=0.
ALLOCATE(c%emu_gr_evap(knvec))
c%emu_gr_evap=0.
ALLOCATE(c%emu_gr_qsat(knvec))
c%emu_gr_qsat=0.
ALLOCATE(c%emu_gr_pac(knvec))
c%emu_gr_pac=0.
ALLOCATE(c%emu_gr_puw(knvec))
c%emu_gr_puw=0.
ALLOCATE(c%emu_gr_gflux(knvec))
c%emu_gr_gflux=0.
ALLOCATE(c%emu_gr_sfco2(knvec))
c%emu_gr_sfco2=0.
ALLOCATE(c%emu_gr_runoff(knvec))
c%emu_gr_runoff=0.
ALLOCATE(c%emu_gr_drain(knvec))
c%emu_gr_drain=0.
ALLOCATE(c%emu_gr_irrig(knvec))
c%emu_gr_irrig=0.
ALLOCATE(c%runoff_road_acc(knvec))
c%runoff_road_acc=0.
ALLOCATE(c%runoff_roof_acc(knvec))
c%runoff_roof_acc=0.
END SUBROUTINE
SUBROUTINE copy_column(d,k,s,j)
TYPE(TEB_BLOCK),INTENT(INOUT)::d
TYPE(TEB_BLOCK),INTENT(IN)::s
INTEGER,INTENT(IN)::k,j
d%ntstep=s%ntstep
d%iblock=s%iblock
d%dt=s%dt
d%teb_year=s%teb_year
d%teb_month=s%teb_month
d%teb_day=s%teb_day
d%teb_hour=s%teb_hour
d%teb_min=s%teb_min
d%teb_sec=s%teb_sec
d%teb_hour_seconds=s%teb_hour_seconds
d%sa_uc(k:k)=s%sa_uc(j:j)
d%lon_teb(k:k)=s%lon_teb(j:j)
d%lat_teb(k:k)=s%lat_teb(j:j)
d%hlev_teb(k:k)=s%hlev_teb(j:j)
d%u(k:k)=s%u(j:j)
d%v(k:k)=s%v(j:j)
d%t(k:k)=s%t(j:j)
d%qv(k:k)=s%qv(j:j)
d%ps(k:k)=s%ps(j:j)
d%rho(k:k)=s%rho(j:j)
d%prr_con(k:k)=s%prr_con(j:j)
d%prs_con(k:k)=s%prs_con(j:j)
d%prr_gsp(k:k)=s%prr_gsp(j:j)
d%prs_gsp(k:k)=s%prs_gsp(j:j)
d%prg_gsp(k:k)=s%prg_gsp(j:j)
d%lwd_s(k:k)=s%lwd_s(j:j)
d%swdir_s(k:k)=s%swdir_s(j:j)
d%swdifd_s(k:k)=s%swdifd_s(j:j)
d%teb_nroof_layer=s%teb_nroof_layer
d%teb_nroad_layer=s%teb_nroad_layer
d%teb_nwall_layer=s%teb_nwall_layer
d%teb_nfloor_layer=s%teb_nfloor_layer
d%urb_d_rf=s%urb_d_rf
d%urb_d_rd=s%urb_d_rd
d%urb_d_wl=s%urb_d_wl
d%urb_fr_bld(k:k)=s%urb_fr_bld(j:j)
d%fr_garden(k:k)=s%fr_garden(j:j)
d%urb_h2w(k:k)=s%urb_h2w(j:j)
d%urb_h_bld(k:k)=s%urb_h_bld(j:j)
d%urb_hcap_rd(k:k)=s%urb_hcap_rd(j:j)
d%urb_hcap_rf(k:k)=s%urb_hcap_rf(j:j)
d%urb_hcap_wl(k:k)=s%urb_hcap_wl(j:j)
d%urb_hcon_rd(k:k)=s%urb_hcon_rd(j:j)
d%urb_hcon_rf(k:k)=s%urb_hcon_rf(j:j)
d%urb_hcon_wl(k:k)=s%urb_hcon_wl(j:j)
d%urb_alb_rd_so(k:k)=s%urb_alb_rd_so(j:j)
d%urb_alb_rf_so(k:k)=s%urb_alb_rf_so(j:j)
d%urb_alb_wl_so(k:k)=s%urb_alb_wl_so(j:j)
d%urb_alb_rd_th(k:k)=s%urb_alb_rd_th(j:j)
d%urb_alb_rf_th(k:k)=s%urb_alb_rf_th(j:j)
d%urb_alb_wl_th(k:k)=s%urb_alb_wl_th(j:j)
d%ahf_traffic(k:k)=s%ahf_traffic(j:j)
d%ahf_industry(k:k)=s%ahf_industry(j:j)
d%teb_ti_bld(k:k)=s%teb_ti_bld(j:j)
d%teb_troof(k:k,:)=s%teb_troof(j:j,:)
d%teb_troad(k:k,:)=s%teb_troad(j:j,:)
d%teb_twalla(k:k,:)=s%teb_twalla(j:j,:)
d%teb_twallb(k:k,:)=s%teb_twallb(j:j,:)
d%teb_tfloor(k:k,:)=s%teb_tfloor(j:j,:)
d%teb_tmass(k:k,:)=s%teb_tmass(j:j,:)
d%teb_qi_bld(k:k)=s%teb_qi_bld(j:j)
d%teb_tcanyon(k:k)=s%teb_tcanyon(j:j)
d%teb_qcanyon(k:k)=s%teb_qcanyon(j:j)
d%teb_ws_roof(k:k)=s%teb_ws_roof(j:j)
d%teb_ws_road(k:k)=s%teb_ws_road(j:j)
d%teb_wsnow_roof(k:k,:)=s%teb_wsnow_roof(j:j,:)
d%teb_wsnow_road(k:k,:)=s%teb_wsnow_road(j:j,:)
d%teb_tsnow_roof(k:k,:)=s%teb_tsnow_roof(j:j,:)
d%teb_tsnow_road(k:k,:)=s%teb_tsnow_road(j:j,:)
d%teb_rsnow_roof(k:k,:)=s%teb_rsnow_roof(j:j,:)
d%teb_rsnow_road(k:k,:)=s%teb_rsnow_road(j:j,:)
d%teb_tssnow_roof(k:k)=s%teb_tssnow_roof(j:j)
d%teb_tssnow_road(k:k)=s%teb_tssnow_road(j:j)
d%teb_asnow_roof(k:k)=s%teb_asnow_roof(j:j)
d%teb_asnow_road(k:k)=s%teb_asnow_road(j:j)
d%teb_esnow_roof(k:k)=s%teb_esnow_roof(j:j)
d%teb_esnow_road(k:k)=s%teb_esnow_road(j:j)
d%teb_twin1(k:k)=s%teb_twin1(j:j)
d%teb_twin2(k:k)=s%teb_twin2(j:j)
d%teb_albwin(k:k)=s%teb_albwin(j:j)
d%teb_itype_bem=s%teb_itype_bem
d%teb_lbem_ac=s%teb_lbem_ac
d%teb_itype_natvent=s%teb_itype_natvent
d%teb_itype_bem_cool=s%teb_itype_bem_cool
d%teb_itype_bem_heat=s%teb_itype_bem_heat
d%teb_frac_gz(k:k)=s%teb_frac_gz(j:j)
d%teb_tcool_target(k:k)=s%teb_tcool_target(j:j)
d%teb_theat_target(k:k)=s%teb_theat_target(j:j)
d%teb_bem_vent(k:k)=s%teb_bem_vent(j:j)
d%teb_bem_inf(k:k)=s%teb_bem_inf(j:j)
d%teb_bem_cop(k:k)=s%teb_bem_cop(j:j)
d%teb_cap_sys_rat(k:k)=s%teb_cap_sys_rat(j:j)
d%teb_m_sys_rat(k:k)=s%teb_m_sys_rat(j:j)
d%teb_shad_day(k:k)=s%teb_shad_day(j:j)
d%teb_natvent_night(k:k)=s%teb_natvent_night(j:j)
d%teb_lgreenroof=s%teb_lgreenroof
d%teb_frac_gr(k:k)=s%teb_frac_gr(j:j)
d%teb_z0_gr(k:k)=s%teb_z0_gr(j:j)
d%teb_alb_gr(k:k)=s%teb_alb_gr(j:j)
d%teb_emis_gr(k:k)=s%teb_emis_gr(j:j)
d%teb_ts_gr(k:k)=s%teb_ts_gr(j:j)
d%teb_qs_gr(k:k)=s%teb_qs_gr(j:j)
d%teb_shfl_gr(k:k)=s%teb_shfl_gr(j:j)
d%teb_lhfl_gr(k:k)=s%teb_lhfl_gr(j:j)
d%teb_qvfl_gr(k:k)=s%teb_qvfl_gr(j:j)
d%teb_runoff_gr(k:k)=s%teb_runoff_gr(j:j)
d%teb_lgarden=s%teb_lgarden
d%teb_z0_gd(k:k)=s%teb_z0_gd(j:j)
d%teb_alb_gd(k:k)=s%teb_alb_gd(j:j)
d%teb_emis_gd(k:k)=s%teb_emis_gd(j:j)
d%teb_ts_gd(k:k)=s%teb_ts_gd(j:j)
d%teb_qs_gd(k:k)=s%teb_qs_gd(j:j)
d%teb_shfl_gd(k:k)=s%teb_shfl_gd(j:j)
d%teb_lhfl_gd(k:k)=s%teb_lhfl_gd(j:j)
d%teb_qvfl_gd(k:k)=s%teb_qvfl_gd(j:j)
d%teb_tch_gd(k:k)=s%teb_tch_gd(j:j)
d%teb_tcm_gd(k:k)=s%teb_tcm_gd(j:j)
d%teb_runoff_gd(k:k)=s%teb_runoff_gd(j:j)
d%teb_itype_wind=s%teb_itype_wind
d%teb_ctype_exch_road=s%teb_ctype_exch_road
d%teb_ctype_exch_roof=s%teb_ctype_exch_roof
d%teb_ctype_exch_canyon=s%teb_ctype_exch_canyon
d%teb_fai(k:k,:)=s%teb_fai(j:j,:)
d%teb_type_garden=s%teb_type_garden
d%teb_type_greenroof=s%teb_type_greenroof
d%teb_lgreenroof_ext=s%teb_lgreenroof_ext
d%teb_hroad_dir=s%teb_hroad_dir
d%teb_wall_opt=s%teb_wall_opt
d%teb_road_dir(k:k)=s%teb_road_dir(j:j)
d%teb_zresidential(k:k)=s%teb_zresidential(j:j)
d%teb_dt_res(k:k)=s%teb_dt_res(j:j)
d%teb_dt_off(k:k)=s%teb_dt_off(j:j)
d%teb_cap_sys_heat(k:k)=s%teb_cap_sys_heat(j:j)
d%teb_lsolar_panel=s%teb_lsolar_panel
d%teb_fr_panel(k:k)=s%teb_fr_panel(j:j)
d%teb_lroad_irrig=s%teb_lroad_irrig
d%teb_rd_irrig_start_m(k:k)=s%teb_rd_irrig_start_m(j:j)
d%teb_rd_irrig_end_m(k:k)=s%teb_rd_irrig_end_m(j:j)
d%teb_rd_irrig_start_h(k:k)=s%teb_rd_irrig_start_h(j:j)
d%teb_rd_irrig_end_h(k:k)=s%teb_rd_irrig_end_h(j:j)
d%teb_rd_irrig_sum(k:k)=s%teb_rd_irrig_sum(j:j)
d%teb_utc_hour=s%teb_utc_hour
d%teb_lshade=s%teb_lshade
d%urb_z0_town=s%urb_z0_town
d%urb_zd_town=s%urb_zd_town
d%tz0=s%tz0
d%tz0h=s%tz0h
d%urb_z0_o_z0h_gdn(k)=s%urb_z0_o_z0h_gdn(j)
d%urb_z0_o_z0h_grf(k)=s%urb_z0_o_z0h_grf(j)
d%teb_lcbs_scheme=s%teb_lcbs_scheme
d%teb_tau_hw_thresh=s%teb_tau_hw_thresh
d%teb_tau_hw_width=s%teb_tau_hw_width
d%teb_wind_canyon(k:k)=s%teb_wind_canyon(j:j)
d%teb_u_can_ped(k:k)=s%teb_u_can_ped(j:j)
d%teb_u_can_10m(k:k)=s%teb_u_can_10m(j:j)
d%teb_sobs(k:k)=s%teb_sobs(j:j)
d%teb_thbs(k:k)=s%teb_thbs(j:j)
d%teb_runoff_road(k:k)=s%teb_runoff_road(j:j)
d%teb_runoff_roof(k:k)=s%teb_runoff_roof(j:j)
d%teb_ustar_town(k:k)=s%teb_ustar_town(j:j)
d%teb_cd_greenroof_atm(k:k)=s%teb_cd_greenroof_atm(j:j)
d%teb_troad_before(k:k,:)=s%teb_troad_before(j:j,:)
d%teb_ucanyon(k:k)=s%teb_ucanyon(j:j)
d%teb_vcanyon(k:k)=s%teb_vcanyon(j:j)
d%teb_tsroof(k:k)=s%teb_tsroof(j:j)
d%teb_tswalla(k:k)=s%teb_tswalla(j:j)
d%teb_tswallb(k:k)=s%teb_tswallb(j:j)
d%teb_shfl(k:k)=s%teb_shfl(j:j)
d%teb_lhfl(k:k)=s%teb_lhfl(j:j)
d%teb_qvfl(k:k)=s%teb_qvfl(j:j)
d%teb_tstown_s(k:k)=s%teb_tstown_s(j:j)
d%teb_qstown_s(k:k)=s%teb_qstown_s(j:j)
d%teb_wstown(k:k)=s%teb_wstown(j:j)
d%teb_runoff_town(k:k)=s%teb_runoff_town(j:j)
d%teb_tssnow_town(k:k)=s%teb_tssnow_town(j:j)
d%teb_wsnow_town(k:k)=s%teb_wsnow_town(j:j)
d%teb_rsnow_town(k:k)=s%teb_rsnow_town(j:j)
d%teb_frsnow(k:k)=s%teb_frsnow(j:j)
d%teb_hsnow_town(k:k)=s%teb_hsnow_town(j:j)
d%teb_tch_town(k:k)=s%teb_tch_town(j:j)
d%teb_shfl_snow(k:k)=s%teb_shfl_snow(j:j)
d%teb_lhfl_snow(k:k)=s%teb_lhfl_snow(j:j)
d%teb_snow_melt(k:k)=s%teb_snow_melt(j:j)
d%teb_alb_so(k:k)=s%teb_alb_so(j:j)
d%teb_emis_town(k:k)=s%teb_emis_town(j:j)
d%teb_hwaste(k:k)=s%teb_hwaste(j:j)
d%teb_hvac_cool(k:k)=s%teb_hvac_cool(j:j)
d%teb_hvac_heat(k:k)=s%teb_hvac_heat(j:j)
d%teb_dqs_town(k:k)=s%teb_dqs_town(j:j)
d%teb_gflux(k:k)=s%teb_gflux(j:j)
d%teb_shfl_rf(k:k)=s%teb_shfl_rf(j:j)
d%teb_shfl_rd(k:k)=s%teb_shfl_rd(j:j)
d%teb_shfl_wl(k:k)=s%teb_shfl_wl(j:j)
d%teb_ac_rf(k:k)=s%teb_ac_rf(j:j)
d%teb_ac_rd(k:k)=s%teb_ac_rd(j:j)
d%teb_ac_wl(k:k)=s%teb_ac_wl(j:j)
d%teb_ac_top(k:k)=s%teb_ac_top(j:j)
d%teb_tch_rf(k:k)=s%teb_tch_rf(j:j)
d%teb_tch_rd(k:k)=s%teb_tch_rd(j:j)
d%teb_tch_wl(k:k)=s%teb_tch_wl(j:j)
d%teb_tch_top(k:k)=s%teb_tch_top(j:j)
d%teb_wind_top(k:k)=s%teb_wind_top(j:j)
d%teb_cd_garden_atm(k:k)=s%teb_cd_garden_atm(j:j)
d%teb_ch_garden_atm(k:k)=s%teb_ch_garden_atm(j:j)
d%ahf_traffic_now(k:k)=s%ahf_traffic_now(j:j)
d%emu_tau(k)=s%emu_tau(j)
d%emu_pcd_can(k)=s%emu_pcd_can(j)
d%emu_pcd_atm(k)=s%emu_pcd_atm(j)
d%emu_pch_can(k)=s%emu_pch_can(j)
d%emu_pch_atm(k)=s%emu_pch_atm(j)
d%emu_v_can(k)=s%emu_v_can(j)
d%emu_v_atm(k)=s%emu_v_atm(j)
d%emu_ca_can(k)=s%emu_ca_can(j)
d%emu_ca_atm(k)=s%emu_ca_atm(j)
d%emu_ca_eff(k)=s%emu_ca_eff(j)
d%emu_v_star(k)=s%emu_v_star(j)
d%emu_t_star(k)=s%emu_t_star(j)
d%emu_q_star(k)=s%emu_q_star(j)
d%emu_ch_eff(k)=s%emu_ch_eff(j)
d%emu_cd_eff(k)=s%emu_cd_eff(j)
d%emu_ch_naive(k)=s%emu_ch_naive(j)
d%emu_psw(k)=s%emu_psw(j)
d%emu_plw(k)=s%emu_plw(j)
d%emu_ts(k)=s%emu_ts(j)
d%emu_rn(k)=s%emu_rn(j)
d%emu_h(k)=s%emu_h(j)
d%emu_le(k)=s%emu_le(j)
d%emu_evap(k)=s%emu_evap(j)
d%emu_qsat(k)=s%emu_qsat(j)
d%emu_pac(k)=s%emu_pac(j)
d%emu_puw(k)=s%emu_puw(j)
d%emu_gflux(k)=s%emu_gflux(j)
d%emu_sfco2(k)=s%emu_sfco2(j)
d%emu_runoff(k)=s%emu_runoff(j)
d%emu_drain(k)=s%emu_drain(j)
d%emu_irrig(k)=s%emu_irrig(j)
d%emu_gr_pcd(k)=s%emu_gr_pcd(j)
d%emu_gr_pch(k)=s%emu_gr_pch(j)
d%emu_gr_v(k)=s%emu_gr_v(j)
d%emu_gr_t(k)=s%emu_gr_t(j)
d%emu_gr_q(k)=s%emu_gr_q(j)
d%emu_gr_ca(k)=s%emu_gr_ca(j)
d%emu_gr_cd(k)=s%emu_gr_cd(j)
d%emu_gr_ch(k)=s%emu_gr_ch(j)
d%emu_gr_psw(k)=s%emu_gr_psw(j)
d%emu_gr_plw(k)=s%emu_gr_plw(j)
d%emu_gr_ts(k)=s%emu_gr_ts(j)
d%emu_gr_rn(k)=s%emu_gr_rn(j)
d%emu_gr_h(k)=s%emu_gr_h(j)
d%emu_gr_le(k)=s%emu_gr_le(j)
d%emu_gr_evap(k)=s%emu_gr_evap(j)
d%emu_gr_qsat(k)=s%emu_gr_qsat(j)
d%emu_gr_pac(k)=s%emu_gr_pac(j)
d%emu_gr_puw(k)=s%emu_gr_puw(j)
d%emu_gr_gflux(k)=s%emu_gr_gflux(j)
d%emu_gr_sfco2(k)=s%emu_gr_sfco2(j)
d%emu_gr_runoff(k)=s%emu_gr_runoff(j)
d%emu_gr_drain(k)=s%emu_gr_drain(j)
d%emu_gr_irrig(k)=s%emu_gr_irrig(j)
d%runoff_road_acc(k)=s%runoff_road_acc(j)
d%runoff_roof_acc(k)=s%runoff_roof_acc(j)
END SUBROUTINE
SUBROUTINE copy_result(d,k,s,j)
TYPE(TEB_BLOCK),INTENT(INOUT)::d
TYPE(TEB_BLOCK),INTENT(IN)::s
INTEGER,INTENT(IN)::k,j
d%teb_ti_bld(k:k)=s%teb_ti_bld(j:j)
d%teb_troof(k:k,:)=s%teb_troof(j:j,:)
d%teb_troad(k:k,:)=s%teb_troad(j:j,:)
d%teb_twalla(k:k,:)=s%teb_twalla(j:j,:)
d%teb_twallb(k:k,:)=s%teb_twallb(j:j,:)
d%teb_tfloor(k:k,:)=s%teb_tfloor(j:j,:)
d%teb_tmass(k:k,:)=s%teb_tmass(j:j,:)
d%teb_qi_bld(k:k)=s%teb_qi_bld(j:j)
d%teb_tcanyon(k:k)=s%teb_tcanyon(j:j)
d%teb_qcanyon(k:k)=s%teb_qcanyon(j:j)
d%teb_ws_roof(k:k)=s%teb_ws_roof(j:j)
d%teb_ws_road(k:k)=s%teb_ws_road(j:j)
d%teb_wsnow_roof(k:k,:)=s%teb_wsnow_roof(j:j,:)
d%teb_wsnow_road(k:k,:)=s%teb_wsnow_road(j:j,:)
d%teb_tsnow_roof(k:k,:)=s%teb_tsnow_roof(j:j,:)
d%teb_tsnow_road(k:k,:)=s%teb_tsnow_road(j:j,:)
d%teb_rsnow_roof(k:k,:)=s%teb_rsnow_roof(j:j,:)
d%teb_rsnow_road(k:k,:)=s%teb_rsnow_road(j:j,:)
d%teb_tssnow_roof(k:k)=s%teb_tssnow_roof(j:j)
d%teb_tssnow_road(k:k)=s%teb_tssnow_road(j:j)
d%teb_asnow_roof(k:k)=s%teb_asnow_roof(j:j)
d%teb_asnow_road(k:k)=s%teb_asnow_road(j:j)
d%teb_esnow_roof(k:k)=s%teb_esnow_roof(j:j)
d%teb_esnow_road(k:k)=s%teb_esnow_road(j:j)
d%teb_twin1(k:k)=s%teb_twin1(j:j)
d%teb_twin2(k:k)=s%teb_twin2(j:j)
d%teb_albwin(k:k)=s%teb_albwin(j:j)
d%teb_cap_sys_rat(k:k)=s%teb_cap_sys_rat(j:j)
d%teb_m_sys_rat(k:k)=s%teb_m_sys_rat(j:j)
d%teb_shad_day(k:k)=s%teb_shad_day(j:j)
d%teb_natvent_night(k:k)=s%teb_natvent_night(j:j)
d%teb_tch_gd(k:k)=s%teb_tch_gd(j:j)
d%teb_tcm_gd(k:k)=s%teb_tcm_gd(j:j)
d%teb_wind_canyon(k:k)=s%teb_wind_canyon(j:j)
d%teb_u_can_ped(k:k)=s%teb_u_can_ped(j:j)
d%teb_u_can_10m(k:k)=s%teb_u_can_10m(j:j)
d%teb_sobs(k:k)=s%teb_sobs(j:j)
d%teb_thbs(k:k)=s%teb_thbs(j:j)
d%teb_runoff_road(k:k)=s%teb_runoff_road(j:j)
d%teb_runoff_roof(k:k)=s%teb_runoff_roof(j:j)
d%teb_ustar_town(k:k)=s%teb_ustar_town(j:j)
d%teb_cd_greenroof_atm(k:k)=s%teb_cd_greenroof_atm(j:j)
d%teb_troad_before(k:k,:)=s%teb_troad_before(j:j,:)
d%teb_ucanyon(k:k)=s%teb_ucanyon(j:j)
d%teb_vcanyon(k:k)=s%teb_vcanyon(j:j)
d%teb_tsroof(k:k)=s%teb_tsroof(j:j)
d%teb_tswalla(k:k)=s%teb_tswalla(j:j)
d%teb_tswallb(k:k)=s%teb_tswallb(j:j)
d%teb_shfl(k:k)=s%teb_shfl(j:j)
d%teb_lhfl(k:k)=s%teb_lhfl(j:j)
d%teb_qvfl(k:k)=s%teb_qvfl(j:j)
d%teb_tstown_s(k:k)=s%teb_tstown_s(j:j)
d%teb_qstown_s(k:k)=s%teb_qstown_s(j:j)
d%teb_wstown(k:k)=s%teb_wstown(j:j)
d%teb_runoff_town(k:k)=s%teb_runoff_town(j:j)
d%teb_tssnow_town(k:k)=s%teb_tssnow_town(j:j)
d%teb_wsnow_town(k:k)=s%teb_wsnow_town(j:j)
d%teb_rsnow_town(k:k)=s%teb_rsnow_town(j:j)
d%teb_frsnow(k:k)=s%teb_frsnow(j:j)
d%teb_hsnow_town(k:k)=s%teb_hsnow_town(j:j)
d%teb_tch_town(k:k)=s%teb_tch_town(j:j)
d%teb_shfl_snow(k:k)=s%teb_shfl_snow(j:j)
d%teb_lhfl_snow(k:k)=s%teb_lhfl_snow(j:j)
d%teb_snow_melt(k:k)=s%teb_snow_melt(j:j)
d%teb_alb_so(k:k)=s%teb_alb_so(j:j)
d%teb_emis_town(k:k)=s%teb_emis_town(j:j)
d%teb_hwaste(k:k)=s%teb_hwaste(j:j)
d%teb_hvac_cool(k:k)=s%teb_hvac_cool(j:j)
d%teb_hvac_heat(k:k)=s%teb_hvac_heat(j:j)
d%teb_dqs_town(k:k)=s%teb_dqs_town(j:j)
d%teb_gflux(k:k)=s%teb_gflux(j:j)
d%teb_shfl_rf(k:k)=s%teb_shfl_rf(j:j)
d%teb_shfl_rd(k:k)=s%teb_shfl_rd(j:j)
d%teb_shfl_wl(k:k)=s%teb_shfl_wl(j:j)
d%teb_ac_rf(k:k)=s%teb_ac_rf(j:j)
d%teb_ac_rd(k:k)=s%teb_ac_rd(j:j)
d%teb_ac_wl(k:k)=s%teb_ac_wl(j:j)
d%teb_ac_top(k:k)=s%teb_ac_top(j:j)
d%teb_tch_rf(k:k)=s%teb_tch_rf(j:j)
d%teb_tch_rd(k:k)=s%teb_tch_rd(j:j)
d%teb_tch_wl(k:k)=s%teb_tch_wl(j:j)
d%teb_tch_top(k:k)=s%teb_tch_top(j:j)
d%teb_wind_top(k:k)=s%teb_wind_top(j:j)
d%teb_cd_garden_atm(k:k)=s%teb_cd_garden_atm(j:j)
d%teb_ch_garden_atm(k:k)=s%teb_ch_garden_atm(j:j)
d%ahf_traffic_now(k:k)=s%ahf_traffic_now(j:j)
END SUBROUTINE
SUBROUTINE api_step(c,snow_check)
TYPE(TEB_BLOCK),INTENT(INOUT),TARGET::c
LOGICAL,OPTIONAL,INTENT(IN)::snow_check
LOGICAL::selected_snow_check
TYPE(TEB_Z0_t)::previous_z0
TYPE(TEB_Z0H_BINDING_t)::z0h,previous_z0h
selected_snow_check=teb_snow_check
IF(PRESENT(snow_check)) selected_snow_check=snow_check
CALL TEB_BIND_Z0(c%tz0,previous_z0)
z0h%RULES=c%tz0h
z0h%GARDEN=>c%urb_z0_o_z0h_gdn
z0h%GREENROOF=>c%urb_z0_o_z0h_grf
CALL TEB_BIND_Z0H(z0h,previous_z0h)
CALL teb_interface(ntstep=c%ntstep, nvec=c%nvec, iblock=c%iblock, dt=c%dt, teb_year=c%teb_year, &
                   teb_month=c%teb_month, teb_day=c%teb_day, teb_hour=c%teb_hour, teb_min=c%teb_min, &
                   teb_sec=c%teb_sec, &
                   teb_hour_seconds=c%teb_hour_seconds, sa_uc=c%sa_uc, lon_teb=c%lon_teb, lat_teb=c%lat_teb, &
                   hlev_teb=c%hlev_teb, ivstart=c%ivstart, ivend=c%ivend, u=c%u, v=c%v, t=c%t, qv=c%qv, &
                   ps=c%ps, rho=c%rho, &
                   prr_con=c%prr_con, prs_con=c%prs_con, prr_gsp=c%prr_gsp, prs_gsp=c%prs_gsp, &
                   prg_gsp=c%prg_gsp, &
                   lwd_s=c%lwd_s, swdir_s=c%swdir_s, swdifd_s=c%swdifd_s, teb_nroof_layer=c%teb_nroof_layer, &
                   teb_nroad_layer=c%teb_nroad_layer, teb_nwall_layer=c%teb_nwall_layer, &
                   teb_nfloor_layer=c%teb_nfloor_layer, urb_fr_bld=c%urb_fr_bld, fr_garden=c%fr_garden, &
                   urb_h2w=c%urb_h2w, &
                   urb_h_bld=c%urb_h_bld, urb_hcap_rd=c%urb_hcap_rd, urb_hcap_rf=c%urb_hcap_rf, &
                   urb_hcap_wl=c%urb_hcap_wl, &
                   urb_hcon_rd=c%urb_hcon_rd, urb_hcon_rf=c%urb_hcon_rf, urb_hcon_wl=c%urb_hcon_wl, &
                   urb_alb_rd_so=c%urb_alb_rd_so, urb_alb_rf_so=c%urb_alb_rf_so, &
                   urb_alb_wl_so=c%urb_alb_wl_so, &
                   urb_alb_rd_th=c%urb_alb_rd_th, urb_alb_rf_th=c%urb_alb_rf_th, &
                   urb_alb_wl_th=c%urb_alb_wl_th, &
                   ahf_traffic=c%ahf_traffic, ahf_industry=c%ahf_industry, teb_ti_bld=c%teb_ti_bld, &
                   teb_troof=c%teb_troof, &
                   teb_troad=c%teb_troad, teb_twalla=c%teb_twalla, teb_twallb=c%teb_twallb, &
                   teb_tfloor=c%teb_tfloor, &
                   teb_tmass=c%teb_tmass, teb_qi_bld=c%teb_qi_bld, teb_tcanyon=c%teb_tcanyon, &
                   teb_qcanyon=c%teb_qcanyon, &
                   teb_ws_roof=c%teb_ws_roof, teb_ws_road=c%teb_ws_road, teb_wsnow_roof=c%teb_wsnow_roof, &
                   teb_wsnow_road=c%teb_wsnow_road, teb_tsnow_roof=c%teb_tsnow_roof, &
                   teb_tsnow_road=c%teb_tsnow_road, &
                   teb_rsnow_roof=c%teb_rsnow_roof, teb_rsnow_road=c%teb_rsnow_road, &
                   teb_tssnow_roof=c%teb_tssnow_roof, &
                   teb_tssnow_road=c%teb_tssnow_road, teb_asnow_roof=c%teb_asnow_roof, &
                   teb_asnow_road=c%teb_asnow_road, &
                   teb_esnow_roof=c%teb_esnow_roof, teb_esnow_road=c%teb_esnow_road, teb_twin1=c%teb_twin1, &
                   teb_twin2=c%teb_twin2, teb_albwin=c%teb_albwin, teb_itype_bem=c%teb_itype_bem, &
                   teb_lbem_ac=c%teb_lbem_ac, &
                   teb_itype_natvent=c%teb_itype_natvent, teb_itype_bem_cool=c%teb_itype_bem_cool, &
                   teb_itype_bem_heat=c%teb_itype_bem_heat, teb_frac_gz=c%teb_frac_gz, &
                   teb_tcool_target=c%teb_tcool_target, &
                   teb_theat_target=c%teb_theat_target, teb_bem_vent=c%teb_bem_vent, &
                   teb_bem_inf=c%teb_bem_inf, &
                   teb_bem_cop=c%teb_bem_cop, teb_cap_sys_rat=c%teb_cap_sys_rat, &
                   teb_m_sys_rat=c%teb_m_sys_rat, &
                   teb_shad_day=c%teb_shad_day, teb_natvent_night=c%teb_natvent_night, &
                   teb_lgreenroof=c%teb_lgreenroof, &
                   teb_frac_gr=c%teb_frac_gr, teb_z0_gr=c%teb_z0_gr, teb_alb_gr=c%teb_alb_gr, &
                   teb_emis_gr=c%teb_emis_gr, &
                   teb_ts_gr=c%teb_ts_gr, teb_qs_gr=c%teb_qs_gr, teb_shfl_gr=c%teb_shfl_gr, &
                   teb_lhfl_gr=c%teb_lhfl_gr, &
                   teb_qvfl_gr=c%teb_qvfl_gr, teb_runoff_gr=c%teb_runoff_gr, teb_lgarden=c%teb_lgarden, &
                   teb_z0_gd=c%teb_z0_gd, teb_alb_gd=c%teb_alb_gd, teb_emis_gd=c%teb_emis_gd, &
                   teb_ts_gd=c%teb_ts_gd, &
                   teb_qs_gd=c%teb_qs_gd, teb_shfl_gd=c%teb_shfl_gd, teb_lhfl_gd=c%teb_lhfl_gd, &
                   teb_qvfl_gd=c%teb_qvfl_gd, &
                   teb_tch_gd=c%teb_tch_gd, teb_tcm_gd=c%teb_tcm_gd, teb_runoff_gd=c%teb_runoff_gd, &
                   teb_itype_wind=c%teb_itype_wind, teb_fai=c%teb_fai, teb_type_garden=c%teb_type_garden, &
                   teb_type_greenroof=c%teb_type_greenroof, teb_lgreenroof_ext=c%teb_lgreenroof_ext, &
                   teb_hroad_dir=c%teb_hroad_dir, teb_wall_opt=c%teb_wall_opt, teb_road_dir=c%teb_road_dir, &
                   teb_zresidential=c%teb_zresidential, teb_dt_res=c%teb_dt_res, teb_dt_off=c%teb_dt_off, &
                   teb_cap_sys_heat=c%teb_cap_sys_heat, teb_lsolar_panel=c%teb_lsolar_panel, &
                   teb_fr_panel=c%teb_fr_panel, &
                   teb_lroad_irrig=c%teb_lroad_irrig, teb_rd_irrig_start_m=c%teb_rd_irrig_start_m, &
                   teb_rd_irrig_end_m=c%teb_rd_irrig_end_m, teb_rd_irrig_start_h=c%teb_rd_irrig_start_h, &
                   teb_rd_irrig_end_h=c%teb_rd_irrig_end_h, teb_rd_irrig_sum=c%teb_rd_irrig_sum, &
                   teb_utc_hour=c%teb_utc_hour, teb_lshade=c%teb_lshade, urb_z0_town=c%urb_z0_town, &
                   urb_zd_town=c%urb_zd_town, urb_z0_o_z0h_gdn=c%urb_z0_o_z0h_gdn(1), &
                   urb_z0_o_z0h_grf=c%urb_z0_o_z0h_grf(1), &
                   teb_lcbs_scheme=c%teb_lcbs_scheme, teb_tau_hw_thresh=c%teb_tau_hw_thresh, &
                   teb_tau_hw_width=c%teb_tau_hw_width, teb_wind_canyon=c%teb_wind_canyon, &
                   teb_u_can_ped=c%teb_u_can_ped, &
                   teb_u_can_10m=c%teb_u_can_10m, teb_sobs=c%teb_sobs, teb_thbs=c%teb_thbs, &
                   teb_runoff_road=c%teb_runoff_road, teb_runoff_roof=c%teb_runoff_roof, &
                   kteb_log_block=c%kteb_log_block, &
                   kteb_log_point=c%kteb_log_point, teb_ustar_town=c%teb_ustar_town, &
                   teb_cd_greenroof_atm=c%teb_cd_greenroof_atm, teb_troad_before=c%teb_troad_before, &
                   teb_ucanyon=c%teb_ucanyon, teb_vcanyon=c%teb_vcanyon, teb_tsroof=c%teb_tsroof, &
                   teb_tswalla=c%teb_tswalla, &
                   teb_tswallb=c%teb_tswallb, teb_shfl=c%teb_shfl, teb_lhfl=c%teb_lhfl, teb_qvfl=c%teb_qvfl, &
                   teb_tstown_s=c%teb_tstown_s, teb_qstown_s=c%teb_qstown_s, teb_wstown=c%teb_wstown, &
                   teb_runoff_town=c%teb_runoff_town, teb_tssnow_town=c%teb_tssnow_town, &
                   teb_wsnow_town=c%teb_wsnow_town, &
                   teb_rsnow_town=c%teb_rsnow_town, teb_frsnow=c%teb_frsnow, &
                   teb_hsnow_town=c%teb_hsnow_town, &
                   teb_tch_town=c%teb_tch_town, teb_shfl_snow=c%teb_shfl_snow, &
                   teb_lhfl_snow=c%teb_lhfl_snow, &
                   teb_snow_melt=c%teb_snow_melt, teb_alb_so=c%teb_alb_so, teb_emis_town=c%teb_emis_town, &
                   teb_hwaste=c%teb_hwaste, teb_hvac_cool=c%teb_hvac_cool, teb_hvac_heat=c%teb_hvac_heat, &
                   teb_dqs_town=c%teb_dqs_town, teb_gflux=c%teb_gflux, teb_shfl_rf=c%teb_shfl_rf, &
                   teb_shfl_rd=c%teb_shfl_rd, &
                   teb_shfl_wl=c%teb_shfl_wl, teb_ac_rf=c%teb_ac_rf, teb_ac_rd=c%teb_ac_rd, &
                   teb_ac_wl=c%teb_ac_wl, &
                   teb_ac_top=c%teb_ac_top, teb_tch_rf=c%teb_tch_rf, teb_tch_rd=c%teb_tch_rd, &
                   teb_tch_wl=c%teb_tch_wl, &
                   teb_tch_top=c%teb_tch_top, teb_wind_top=c%teb_wind_top, &
                   teb_cd_garden_atm=c%teb_cd_garden_atm, &
                   teb_ch_garden_atm=c%teb_ch_garden_atm, ahf_traffic_now=c%ahf_traffic_now, &
                   teb_snow_check=selected_snow_check, &
                   teb_ctype_exch_road=c%teb_ctype_exch_road, teb_ctype_exch_roof=c%teb_ctype_exch_roof, &
                   teb_ctype_exch_canyon=c%teb_ctype_exch_canyon, &
                   urb_d_rf=c%urb_d_rf, urb_d_rd=c%urb_d_rd, urb_d_wl=c%urb_d_wl)
CALL TEB_BIND_Z0H(previous_z0h)
CALL TEB_BIND_Z0(previous_z0)
END SUBROUTINE
PURE INTEGER FUNCTION field_count(c) RESULT(n)
TYPE(TEB_BLOCK),INTENT(IN)::c
! Scalar/fixed-size fields plus temperatures, saved road state and depths.
n=200+2*c%teb_nroof_layer+3*c%teb_nroad_layer+3*c%teb_nwall_layer
END FUNCTION field_count

SUBROUTINE pack(c,j,values)
TYPE(TEB_BLOCK),INTENT(IN)::c
INTEGER,INTENT(IN)::j
REAL(teb_real_kind),INTENT(OUT)::values(:)
INTEGER::k,l
IF(SIZE(values)/=field_count(c)) ERROR STOP 'Invalid diagnostic packet size'
k=0
CALL add_value(REAL(c%ntstep,teb_real_kind))
CALL add_value(REAL(c%nvec,teb_real_kind))
CALL add_value(REAL(c%iblock,teb_real_kind))
CALL add_value(c%dt)
CALL add_value(REAL(c%teb_year,teb_real_kind))
CALL add_value(REAL(c%teb_month,teb_real_kind))
CALL add_value(REAL(c%teb_day,teb_real_kind))
CALL add_value(REAL(c%teb_hour,teb_real_kind))
CALL add_value(REAL(c%teb_min,teb_real_kind))
CALL add_value(REAL(c%teb_sec,teb_real_kind))
CALL add_value(c%teb_hour_seconds(1))
CALL add_value(c%sa_uc(j))
CALL add_value(c%lon_teb(j))
CALL add_value(c%lat_teb(j))
CALL add_value(c%hlev_teb(j))
CALL add_value(REAL(c%ivstart,teb_real_kind))
CALL add_value(REAL(c%ivend,teb_real_kind))
CALL add_value(c%u(j))
CALL add_value(c%v(j))
CALL add_value(c%t(j))
CALL add_value(c%qv(j))
CALL add_value(c%ps(j))
CALL add_value(c%rho(j))
CALL add_value(c%prr_con(j))
CALL add_value(c%prs_con(j))
CALL add_value(c%prr_gsp(j))
CALL add_value(c%prs_gsp(j))
CALL add_value(c%prg_gsp(j))
CALL add_value(c%lwd_s(j))
CALL add_value(c%swdir_s(j))
CALL add_value(c%swdifd_s(j))
CALL add_value(REAL(c%teb_nroof_layer,teb_real_kind))
CALL add_value(REAL(c%teb_nroad_layer,teb_real_kind))
CALL add_value(REAL(c%teb_nwall_layer,teb_real_kind))
CALL add_value(REAL(c%teb_nfloor_layer,teb_real_kind))
CALL add_value(c%urb_fr_bld(j))
CALL add_value(c%fr_garden(j))
CALL add_value(c%urb_h2w(j))
CALL add_value(c%urb_h_bld(j))
CALL add_value(c%urb_hcap_rd(j))
CALL add_value(c%urb_hcap_rf(j))
CALL add_value(c%urb_hcap_wl(j))
CALL add_value(c%urb_hcon_rd(j))
CALL add_value(c%urb_hcon_rf(j))
CALL add_value(c%urb_hcon_wl(j))
CALL add_value(c%urb_alb_rd_so(j))
CALL add_value(c%urb_alb_rf_so(j))
CALL add_value(c%urb_alb_wl_so(j))
CALL add_value(c%urb_alb_rd_th(j))
CALL add_value(c%urb_alb_rf_th(j))
CALL add_value(c%urb_alb_wl_th(j))
CALL add_value(c%ahf_traffic(j))
CALL add_value(c%ahf_industry(j))
CALL add_value(c%teb_ti_bld(j))
DO l=1,c%teb_nroof_layer
  CALL add_value(c%teb_troof(j,l))
END DO
DO l=1,c%teb_nroad_layer
  CALL add_value(c%teb_troad(j,l))
END DO
DO l=1,c%teb_nwall_layer
  CALL add_value(c%teb_twalla(j,l))
END DO
DO l=1,c%teb_nwall_layer
  CALL add_value(c%teb_twallb(j,l))
END DO
CALL add_value(c%teb_tfloor(j,1))
CALL add_value(c%teb_tfloor(j,2))
CALL add_value(c%teb_tfloor(j,3))
CALL add_value(c%teb_tfloor(j,4))
CALL add_value(c%teb_tfloor(j,5))
CALL add_value(c%teb_tmass(j,1))
CALL add_value(c%teb_tmass(j,2))
CALL add_value(c%teb_tmass(j,3))
CALL add_value(c%teb_tmass(j,4))
CALL add_value(c%teb_tmass(j,5))
CALL add_value(c%teb_qi_bld(j))
CALL add_value(c%teb_tcanyon(j))
CALL add_value(c%teb_qcanyon(j))
CALL add_value(c%teb_ws_roof(j))
CALL add_value(c%teb_ws_road(j))
CALL add_value(c%teb_wsnow_roof(j,1))
CALL add_value(c%teb_wsnow_road(j,1))
CALL add_value(c%teb_tsnow_roof(j,1))
CALL add_value(c%teb_tsnow_road(j,1))
CALL add_value(c%teb_rsnow_roof(j,1))
CALL add_value(c%teb_rsnow_road(j,1))
CALL add_value(c%teb_tssnow_roof(j))
CALL add_value(c%teb_tssnow_road(j))
CALL add_value(c%teb_asnow_roof(j))
CALL add_value(c%teb_asnow_road(j))
CALL add_value(c%teb_esnow_roof(j))
CALL add_value(c%teb_esnow_road(j))
CALL add_value(c%teb_twin1(j))
CALL add_value(c%teb_twin2(j))
CALL add_value(c%teb_albwin(j))
CALL add_value(MERGE(1.,0.,c%teb_lbem_ac))
CALL add_value(c%teb_frac_gz(j))
CALL add_value(c%teb_tcool_target(j))
CALL add_value(c%teb_theat_target(j))
CALL add_value(c%teb_bem_vent(j))
CALL add_value(c%teb_bem_inf(j))
CALL add_value(c%teb_bem_cop(j))
CALL add_value(c%teb_cap_sys_rat(j))
CALL add_value(c%teb_m_sys_rat(j))
CALL add_value(MERGE(1.,0.,c%teb_shad_day(j)))
CALL add_value(MERGE(1.,0.,c%teb_natvent_night(j)))
CALL add_value(MERGE(1.,0.,c%teb_lgreenroof))
CALL add_value(c%teb_frac_gr(j))
CALL add_value(c%teb_z0_gr(j))
CALL add_value(c%teb_alb_gr(j))
CALL add_value(c%teb_emis_gr(j))
CALL add_value(c%teb_ts_gr(j))
CALL add_value(c%teb_qs_gr(j))
CALL add_value(c%teb_shfl_gr(j))
CALL add_value(c%teb_lhfl_gr(j))
CALL add_value(c%teb_qvfl_gr(j))
CALL add_value(c%teb_runoff_gr(j))
CALL add_value(MERGE(1.,0.,c%teb_lgarden))
CALL add_value(c%teb_z0_gd(j))
CALL add_value(c%teb_alb_gd(j))
CALL add_value(c%teb_emis_gd(j))
CALL add_value(c%teb_ts_gd(j))
CALL add_value(c%teb_qs_gd(j))
CALL add_value(c%teb_shfl_gd(j))
CALL add_value(c%teb_lhfl_gd(j))
CALL add_value(c%teb_qvfl_gd(j))
CALL add_value(c%teb_tch_gd(j))
CALL add_value(c%teb_tcm_gd(j))
CALL add_value(c%teb_runoff_gd(j))
CALL add_value(REAL(c%teb_itype_wind,teb_real_kind))
CALL add_value(c%teb_fai(j,1))
CALL add_value(c%teb_fai(j,2))
CALL add_value(c%teb_fai(j,3))
CALL add_value(c%teb_fai(j,4))
CALL add_value(c%teb_fai(j,5))
CALL add_value(c%teb_fai(j,6))
CALL add_value(c%teb_fai(j,7))
CALL add_value(c%teb_fai(j,8))
CALL add_value(MERGE(1.,0.,c%teb_lgreenroof_ext))
CALL add_value(c%teb_road_dir(j))
CALL add_value(c%teb_zresidential(j))
CALL add_value(c%teb_dt_res(j))
CALL add_value(c%teb_dt_off(j))
CALL add_value(c%teb_cap_sys_heat(j))
CALL add_value(MERGE(1.,0.,c%teb_lsolar_panel))
CALL add_value(c%teb_fr_panel(j))
CALL add_value(MERGE(1.,0.,c%teb_lroad_irrig))
CALL add_value(c%teb_rd_irrig_start_m(j))
CALL add_value(c%teb_rd_irrig_end_m(j))
CALL add_value(c%teb_rd_irrig_start_h(j))
CALL add_value(c%teb_rd_irrig_end_h(j))
CALL add_value(c%teb_rd_irrig_sum(j))
CALL add_value(REAL(c%teb_utc_hour,teb_real_kind))
CALL add_value(MERGE(1.,0.,c%teb_lshade))
CALL add_value(c%urb_z0_o_z0h_gdn(j))
CALL add_value(c%urb_z0_o_z0h_grf(j))
CALL add_value(MERGE(1.,0.,c%teb_lcbs_scheme))
CALL add_value(c%teb_tau_hw_thresh)
CALL add_value(c%teb_tau_hw_width)
CALL add_value(c%teb_wind_canyon(j))
CALL add_value(c%teb_u_can_ped(j))
CALL add_value(c%teb_u_can_10m(j))
CALL add_value(c%teb_sobs(j))
CALL add_value(c%teb_thbs(j))
CALL add_value(c%teb_runoff_road(j))
CALL add_value(c%teb_runoff_roof(j))
CALL add_value(c%teb_ustar_town(j))
CALL add_value(c%teb_cd_greenroof_atm(j))
DO l=1,c%teb_nroad_layer
  CALL add_value(c%teb_troad_before(j,l))
END DO
CALL add_value(c%teb_ucanyon(j))
CALL add_value(c%teb_vcanyon(j))
CALL add_value(c%teb_tsroof(j))
CALL add_value(c%teb_tswalla(j))
CALL add_value(c%teb_tswallb(j))
CALL add_value(c%teb_shfl(j))
CALL add_value(c%teb_lhfl(j))
CALL add_value(c%teb_qvfl(j))
CALL add_value(c%teb_tstown_s(j))
CALL add_value(c%teb_qstown_s(j))
CALL add_value(c%teb_wstown(j))
CALL add_value(c%teb_runoff_town(j))
CALL add_value(c%teb_tssnow_town(j))
CALL add_value(c%teb_wsnow_town(j))
CALL add_value(c%teb_rsnow_town(j))
CALL add_value(c%teb_frsnow(j))
CALL add_value(c%teb_hsnow_town(j))
CALL add_value(c%teb_tch_town(j))
CALL add_value(c%teb_shfl_snow(j))
CALL add_value(c%teb_lhfl_snow(j))
CALL add_value(c%teb_snow_melt(j))
CALL add_value(c%teb_alb_so(j))
CALL add_value(c%teb_emis_town(j))
CALL add_value(c%teb_hwaste(j))
CALL add_value(c%teb_hvac_cool(j))
CALL add_value(c%teb_hvac_heat(j))
CALL add_value(c%teb_dqs_town(j))
CALL add_value(c%teb_gflux(j))
CALL add_value(c%teb_shfl_rf(j))
CALL add_value(c%teb_shfl_rd(j))
CALL add_value(c%teb_shfl_wl(j))
CALL add_value(c%teb_ac_rf(j))
CALL add_value(c%teb_ac_rd(j))
CALL add_value(c%teb_ac_wl(j))
CALL add_value(c%teb_ac_top(j))
CALL add_value(c%teb_tch_rf(j))
CALL add_value(c%teb_tch_rd(j))
CALL add_value(c%teb_tch_wl(j))
CALL add_value(c%teb_tch_top(j))
CALL add_value(c%teb_wind_top(j))
CALL add_value(c%teb_cd_garden_atm(j))
CALL add_value(c%teb_ch_garden_atm(j))
CALL add_value(c%ahf_traffic_now(j))
DO l=1,c%teb_nroof_layer
  CALL add_value(c%urb_d_rf(l))
END DO
DO l=1,c%teb_nroad_layer
  CALL add_value(c%urb_d_rd(l))
END DO
DO l=1,c%teb_nwall_layer
  CALL add_value(c%urb_d_wl(l))
END DO
IF(k/=SIZE(values)) ERROR STOP 'Incomplete diagnostic packet'
CONTAINS
SUBROUTINE add_value(value)
REAL(teb_real_kind),INTENT(IN)::value
k=k+1
values(k)=value
END SUBROUTINE add_value
END SUBROUTINE pack

SUBROUTINE write_schema(path,c)
CHARACTER(LEN=*),INTENT(IN)::path
TYPE(TEB_BLOCK),INTENT(IN)::c
INTEGER::unit,rc,l
OPEN(NEWUNIT=unit,FILE=TRIM(path),STATUS='REPLACE',ACTION='WRITE',IOSTAT=rc)
IF(rc/=0) ERROR STOP 'Cannot create fields.csv'
WRITE(unit,'(A)') 'name;intent;type'
WRITE(unit,'(A)') 'ntstep;IN;INTEGER'
WRITE(unit,'(A)') 'nvec;IN;INTEGER'
WRITE(unit,'(A)') 'iblock;IN;INTEGER'
WRITE(unit,'(A)') 'dt;IN;REAL'
WRITE(unit,'(A)') 'teb_year;IN;INTEGER'
WRITE(unit,'(A)') 'teb_month;IN;INTEGER'
WRITE(unit,'(A)') 'teb_day;IN;INTEGER'
WRITE(unit,'(A)') 'teb_hour;IN;INTEGER'
WRITE(unit,'(A)') 'teb_min;IN;INTEGER'
WRITE(unit,'(A)') 'teb_sec;IN;INTEGER'
WRITE(unit,'(A)') 'teb_hour_seconds;IN;REAL'
WRITE(unit,'(A)') 'sa_uc;IN;REAL'
WRITE(unit,'(A)') 'lon_teb;IN;REAL'
WRITE(unit,'(A)') 'lat_teb;IN;REAL'
WRITE(unit,'(A)') 'hlev_teb;IN;REAL'
WRITE(unit,'(A)') 'ivstart;IN;INTEGER'
WRITE(unit,'(A)') 'ivend;IN;INTEGER'
WRITE(unit,'(A)') 'u;IN;REAL'
WRITE(unit,'(A)') 'v;IN;REAL'
WRITE(unit,'(A)') 't;IN;REAL'
WRITE(unit,'(A)') 'qv;IN;REAL'
WRITE(unit,'(A)') 'ps;IN;REAL'
WRITE(unit,'(A)') 'rho;IN;REAL'
WRITE(unit,'(A)') 'prr_con;IN;REAL'
WRITE(unit,'(A)') 'prs_con;IN;REAL'
WRITE(unit,'(A)') 'prr_gsp;IN;REAL'
WRITE(unit,'(A)') 'prs_gsp;IN;REAL'
WRITE(unit,'(A)') 'prg_gsp;IN;REAL'
WRITE(unit,'(A)') 'lwd_s;IN;REAL'
WRITE(unit,'(A)') 'swdir_s;IN;REAL'
WRITE(unit,'(A)') 'swdifd_s;IN;REAL'
WRITE(unit,'(A)') 'teb_nroof_layer;IN;INTEGER'
WRITE(unit,'(A)') 'teb_nroad_layer;IN;INTEGER'
WRITE(unit,'(A)') 'teb_nwall_layer;IN;INTEGER'
WRITE(unit,'(A)') 'teb_nfloor_layer;IN;INTEGER'
WRITE(unit,'(A)') 'urb_fr_bld;IN;REAL'
WRITE(unit,'(A)') 'fr_garden;IN;REAL'
WRITE(unit,'(A)') 'urb_h2w;IN;REAL'
WRITE(unit,'(A)') 'urb_h_bld;IN;REAL'
WRITE(unit,'(A)') 'urb_hcap_rd;IN;REAL'
WRITE(unit,'(A)') 'urb_hcap_rf;IN;REAL'
WRITE(unit,'(A)') 'urb_hcap_wl;IN;REAL'
WRITE(unit,'(A)') 'urb_hcon_rd;IN;REAL'
WRITE(unit,'(A)') 'urb_hcon_rf;IN;REAL'
WRITE(unit,'(A)') 'urb_hcon_wl;IN;REAL'
WRITE(unit,'(A)') 'urb_alb_rd_so;IN;REAL'
WRITE(unit,'(A)') 'urb_alb_rf_so;IN;REAL'
WRITE(unit,'(A)') 'urb_alb_wl_so;IN;REAL'
WRITE(unit,'(A)') 'urb_alb_rd_th;IN;REAL'
WRITE(unit,'(A)') 'urb_alb_rf_th;IN;REAL'
WRITE(unit,'(A)') 'urb_alb_wl_th;IN;REAL'
WRITE(unit,'(A)') 'ahf_traffic;IN;REAL'
WRITE(unit,'(A)') 'ahf_industry;IN;REAL'
WRITE(unit,'(A)') 'teb_ti_bld;INOUT;REAL'
DO l=1,c%teb_nroof_layer
  WRITE(unit,'(A,I0,A)') 'teb_troof[',l,'];INOUT;REAL'
END DO
DO l=1,c%teb_nroad_layer
  WRITE(unit,'(A,I0,A)') 'teb_troad[',l,'];INOUT;REAL'
END DO
DO l=1,c%teb_nwall_layer
  WRITE(unit,'(A,I0,A)') 'teb_twalla[',l,'];INOUT;REAL'
END DO
DO l=1,c%teb_nwall_layer
  WRITE(unit,'(A,I0,A)') 'teb_twallb[',l,'];INOUT;REAL'
END DO
WRITE(unit,'(A)') 'teb_tfloor[1];INOUT;REAL'
WRITE(unit,'(A)') 'teb_tfloor[2];INOUT;REAL'
WRITE(unit,'(A)') 'teb_tfloor[3];INOUT;REAL'
WRITE(unit,'(A)') 'teb_tfloor[4];INOUT;REAL'
WRITE(unit,'(A)') 'teb_tfloor[5];INOUT;REAL'
WRITE(unit,'(A)') 'teb_tmass[1];INOUT;REAL'
WRITE(unit,'(A)') 'teb_tmass[2];INOUT;REAL'
WRITE(unit,'(A)') 'teb_tmass[3];INOUT;REAL'
WRITE(unit,'(A)') 'teb_tmass[4];INOUT;REAL'
WRITE(unit,'(A)') 'teb_tmass[5];INOUT;REAL'
WRITE(unit,'(A)') 'teb_qi_bld;INOUT;REAL'
WRITE(unit,'(A)') 'teb_tcanyon;INOUT;REAL'
WRITE(unit,'(A)') 'teb_qcanyon;INOUT;REAL'
WRITE(unit,'(A)') 'teb_ws_roof;INOUT;REAL'
WRITE(unit,'(A)') 'teb_ws_road;INOUT;REAL'
WRITE(unit,'(A)') 'teb_wsnow_roof;INOUT;REAL'
WRITE(unit,'(A)') 'teb_wsnow_road;INOUT;REAL'
WRITE(unit,'(A)') 'teb_tsnow_roof;INOUT;REAL'
WRITE(unit,'(A)') 'teb_tsnow_road;INOUT;REAL'
WRITE(unit,'(A)') 'teb_rsnow_roof;INOUT;REAL'
WRITE(unit,'(A)') 'teb_rsnow_road;INOUT;REAL'
WRITE(unit,'(A)') 'teb_tssnow_roof;INOUT;REAL'
WRITE(unit,'(A)') 'teb_tssnow_road;INOUT;REAL'
WRITE(unit,'(A)') 'teb_asnow_roof;INOUT;REAL'
WRITE(unit,'(A)') 'teb_asnow_road;INOUT;REAL'
WRITE(unit,'(A)') 'teb_esnow_roof;INOUT;REAL'
WRITE(unit,'(A)') 'teb_esnow_road;INOUT;REAL'
WRITE(unit,'(A)') 'teb_twin1;INOUT;REAL'
WRITE(unit,'(A)') 'teb_twin2;INOUT;REAL'
WRITE(unit,'(A)') 'teb_albwin;OUT;REAL'
WRITE(unit,'(A)') 'teb_lbem_ac;IN;LOGICAL'
WRITE(unit,'(A)') 'teb_frac_gz;IN;REAL'
WRITE(unit,'(A)') 'teb_tcool_target;IN;REAL'
WRITE(unit,'(A)') 'teb_theat_target;IN;REAL'
WRITE(unit,'(A)') 'teb_bem_vent;IN;REAL'
WRITE(unit,'(A)') 'teb_bem_inf;IN;REAL'
WRITE(unit,'(A)') 'teb_bem_cop;IN;REAL'
WRITE(unit,'(A)') 'teb_cap_sys_rat;INOUT;REAL'
WRITE(unit,'(A)') 'teb_m_sys_rat;INOUT;REAL'
WRITE(unit,'(A)') 'teb_shad_day;INOUT;LOGICAL'
WRITE(unit,'(A)') 'teb_natvent_night;INOUT;LOGICAL'
WRITE(unit,'(A)') 'teb_lgreenroof;IN;LOGICAL'
WRITE(unit,'(A)') 'teb_frac_gr;IN;REAL'
WRITE(unit,'(A)') 'teb_z0_gr;IN;REAL'
WRITE(unit,'(A)') 'teb_alb_gr;IN;REAL'
WRITE(unit,'(A)') 'teb_emis_gr;IN;REAL'
WRITE(unit,'(A)') 'teb_ts_gr;IN;REAL'
WRITE(unit,'(A)') 'teb_qs_gr;IN;REAL'
WRITE(unit,'(A)') 'teb_shfl_gr;IN;REAL'
WRITE(unit,'(A)') 'teb_lhfl_gr;IN;REAL'
WRITE(unit,'(A)') 'teb_qvfl_gr;IN;REAL'
WRITE(unit,'(A)') 'teb_runoff_gr;IN;REAL'
WRITE(unit,'(A)') 'teb_lgarden;IN;LOGICAL'
WRITE(unit,'(A)') 'teb_z0_gd;IN;REAL'
WRITE(unit,'(A)') 'teb_alb_gd;IN;REAL'
WRITE(unit,'(A)') 'teb_emis_gd;IN;REAL'
WRITE(unit,'(A)') 'teb_ts_gd;IN;REAL'
WRITE(unit,'(A)') 'teb_qs_gd;IN;REAL'
WRITE(unit,'(A)') 'teb_shfl_gd;IN;REAL'
WRITE(unit,'(A)') 'teb_lhfl_gd;IN;REAL'
WRITE(unit,'(A)') 'teb_qvfl_gd;IN;REAL'
WRITE(unit,'(A)') 'teb_tch_gd;OUT;REAL'
WRITE(unit,'(A)') 'teb_tcm_gd;INOUT;REAL'
WRITE(unit,'(A)') 'teb_runoff_gd;IN;REAL'
WRITE(unit,'(A)') 'teb_itype_wind;IN;INTEGER'
WRITE(unit,'(A)') 'teb_fai[1];IN;REAL'
WRITE(unit,'(A)') 'teb_fai[2];IN;REAL'
WRITE(unit,'(A)') 'teb_fai[3];IN;REAL'
WRITE(unit,'(A)') 'teb_fai[4];IN;REAL'
WRITE(unit,'(A)') 'teb_fai[5];IN;REAL'
WRITE(unit,'(A)') 'teb_fai[6];IN;REAL'
WRITE(unit,'(A)') 'teb_fai[7];IN;REAL'
WRITE(unit,'(A)') 'teb_fai[8];IN;REAL'
WRITE(unit,'(A)') 'teb_lgreenroof_ext;IN;LOGICAL'
WRITE(unit,'(A)') 'teb_road_dir;IN;REAL'
WRITE(unit,'(A)') 'teb_zresidential;IN;REAL'
WRITE(unit,'(A)') 'teb_dt_res;IN;REAL'
WRITE(unit,'(A)') 'teb_dt_off;IN;REAL'
WRITE(unit,'(A)') 'teb_cap_sys_heat;IN;REAL'
WRITE(unit,'(A)') 'teb_lsolar_panel;IN;LOGICAL'
WRITE(unit,'(A)') 'teb_fr_panel;IN;REAL'
WRITE(unit,'(A)') 'teb_lroad_irrig;IN;LOGICAL'
WRITE(unit,'(A)') 'teb_rd_irrig_start_m;IN;REAL'
WRITE(unit,'(A)') 'teb_rd_irrig_end_m;IN;REAL'
WRITE(unit,'(A)') 'teb_rd_irrig_start_h;IN;REAL'
WRITE(unit,'(A)') 'teb_rd_irrig_end_h;IN;REAL'
WRITE(unit,'(A)') 'teb_rd_irrig_sum;IN;REAL'
WRITE(unit,'(A)') 'teb_utc_hour;IN;INTEGER'
WRITE(unit,'(A)') 'teb_lshade;IN;LOGICAL'
WRITE(unit,'(A)') 'urb_z0_o_z0h_gdn;IN;REAL'
WRITE(unit,'(A)') 'urb_z0_o_z0h_grf;IN;REAL'
WRITE(unit,'(A)') 'teb_lcbs_scheme;IN;LOGICAL'
WRITE(unit,'(A)') 'teb_tau_hw_thresh;IN;REAL'
WRITE(unit,'(A)') 'teb_tau_hw_width;IN;REAL'
WRITE(unit,'(A)') 'teb_wind_canyon;OUT;REAL'
WRITE(unit,'(A)') 'teb_u_can_ped;OUT;REAL'
WRITE(unit,'(A)') 'teb_u_can_10m;OUT;REAL'
WRITE(unit,'(A)') 'teb_sobs;OUT;REAL'
WRITE(unit,'(A)') 'teb_thbs;OUT;REAL'
WRITE(unit,'(A)') 'teb_runoff_road;OUT;REAL'
WRITE(unit,'(A)') 'teb_runoff_roof;OUT;REAL'
WRITE(unit,'(A)') 'teb_ustar_town;INOUT;REAL'
WRITE(unit,'(A)') 'teb_cd_greenroof_atm;INOUT;REAL'
DO l=1,c%teb_nroad_layer
  WRITE(unit,'(A,I0,A)') 'teb_troad_before[',l,'];OUT;REAL'
END DO
WRITE(unit,'(A)') 'teb_ucanyon;OUT;REAL'
WRITE(unit,'(A)') 'teb_vcanyon;OUT;REAL'
WRITE(unit,'(A)') 'teb_tsroof;OUT;REAL'
WRITE(unit,'(A)') 'teb_tswalla;OUT;REAL'
WRITE(unit,'(A)') 'teb_tswallb;OUT;REAL'
WRITE(unit,'(A)') 'teb_shfl;OUT;REAL'
WRITE(unit,'(A)') 'teb_lhfl;OUT;REAL'
WRITE(unit,'(A)') 'teb_qvfl;OUT;REAL'
WRITE(unit,'(A)') 'teb_tstown_s;OUT;REAL'
WRITE(unit,'(A)') 'teb_qstown_s;OUT;REAL'
WRITE(unit,'(A)') 'teb_wstown;OUT;REAL'
WRITE(unit,'(A)') 'teb_runoff_town;OUT;REAL'
WRITE(unit,'(A)') 'teb_tssnow_town;OUT;REAL'
WRITE(unit,'(A)') 'teb_wsnow_town;OUT;REAL'
WRITE(unit,'(A)') 'teb_rsnow_town;OUT;REAL'
WRITE(unit,'(A)') 'teb_frsnow;OUT;REAL'
WRITE(unit,'(A)') 'teb_hsnow_town;OUT;REAL'
WRITE(unit,'(A)') 'teb_tch_town;OUT;REAL'
WRITE(unit,'(A)') 'teb_shfl_snow;OUT;REAL'
WRITE(unit,'(A)') 'teb_lhfl_snow;OUT;REAL'
WRITE(unit,'(A)') 'teb_snow_melt;OUT;REAL'
WRITE(unit,'(A)') 'teb_alb_so;OUT;REAL'
WRITE(unit,'(A)') 'teb_emis_town;OUT;REAL'
WRITE(unit,'(A)') 'teb_hwaste;OUT;REAL'
WRITE(unit,'(A)') 'teb_hvac_cool;OUT;REAL'
WRITE(unit,'(A)') 'teb_hvac_heat;OUT;REAL'
WRITE(unit,'(A)') 'teb_dqs_town;OUT;REAL'
WRITE(unit,'(A)') 'teb_gflux;OUT;REAL'
WRITE(unit,'(A)') 'teb_shfl_rf;OUT;REAL'
WRITE(unit,'(A)') 'teb_shfl_rd;OUT;REAL'
WRITE(unit,'(A)') 'teb_shfl_wl;OUT;REAL'
WRITE(unit,'(A)') 'teb_ac_rf;OUT;REAL'
WRITE(unit,'(A)') 'teb_ac_rd;OUT;REAL'
WRITE(unit,'(A)') 'teb_ac_wl;OUT;REAL'
WRITE(unit,'(A)') 'teb_ac_top;OUT;REAL'
WRITE(unit,'(A)') 'teb_tch_rf;OUT;REAL'
WRITE(unit,'(A)') 'teb_tch_rd;OUT;REAL'
WRITE(unit,'(A)') 'teb_tch_wl;OUT;REAL'
WRITE(unit,'(A)') 'teb_tch_top;OUT;REAL'
WRITE(unit,'(A)') 'teb_wind_top;OUT;REAL'
WRITE(unit,'(A)') 'teb_cd_garden_atm;OUT;REAL'
WRITE(unit,'(A)') 'teb_ch_garden_atm;OUT;REAL'
WRITE(unit,'(A)') 'ahf_traffic_now;OUT;REAL'
DO l=1,c%teb_nroof_layer
  WRITE(unit,'(A,I0,A)') 'urb_d_rf[',l,'];IN;REAL'
END DO
DO l=1,c%teb_nroad_layer
  WRITE(unit,'(A,I0,A)') 'urb_d_rd[',l,'];IN;REAL'
END DO
DO l=1,c%teb_nwall_layer
  WRITE(unit,'(A,I0,A)') 'urb_d_wl[',l,'];IN;REAL'
END DO
CLOSE(unit)
END SUBROUTINE
SUBROUTINE sanitize_outputs(c,ids,cfg)
TYPE(TEB_BLOCK),INTENT(INOUT)::c
INTEGER,INTENT(IN)::ids(:)
TYPE(BLOCK_CONFIG),INTENT(IN)::cfg
INTEGER::j
DO j=1,c%nvec
  IF(active(c,j)) CYCLE
  c%teb_albwin(j)=XUNDEF
  c%teb_tch_gd(j)=XUNDEF
  c%teb_wind_canyon(j)=XUNDEF
  c%teb_u_can_ped(j)=XUNDEF
  c%teb_u_can_10m(j)=XUNDEF
  c%teb_sobs(j)=XUNDEF
  c%teb_thbs(j)=XUNDEF
  c%teb_runoff_road(j)=XUNDEF
  c%teb_runoff_roof(j)=XUNDEF
  c%teb_troad_before(j,:)=XUNDEF
  c%teb_ucanyon(j)=XUNDEF
  c%teb_vcanyon(j)=XUNDEF
  c%teb_tsroof(j)=XUNDEF
  c%teb_tswalla(j)=XUNDEF
  c%teb_tswallb(j)=XUNDEF
  c%teb_shfl(j)=XUNDEF
  c%teb_lhfl(j)=XUNDEF
  c%teb_qvfl(j)=XUNDEF
  c%teb_tstown_s(j)=XUNDEF
  c%teb_qstown_s(j)=XUNDEF
  c%teb_wstown(j)=XUNDEF
  c%teb_runoff_town(j)=XUNDEF
  c%teb_tssnow_town(j)=XUNDEF
  c%teb_wsnow_town(j)=XUNDEF
  c%teb_rsnow_town(j)=XUNDEF
  c%teb_frsnow(j)=XUNDEF
  c%teb_hsnow_town(j)=XUNDEF
  c%teb_tch_town(j)=XUNDEF
  c%teb_shfl_snow(j)=XUNDEF
  c%teb_lhfl_snow(j)=XUNDEF
  c%teb_snow_melt(j)=XUNDEF
  c%teb_alb_so(j)=XUNDEF
  c%teb_emis_town(j)=XUNDEF
  c%teb_hwaste(j)=XUNDEF
  c%teb_hvac_cool(j)=XUNDEF
  c%teb_hvac_heat(j)=XUNDEF
  c%teb_dqs_town(j)=XUNDEF
  c%teb_gflux(j)=XUNDEF
  c%teb_shfl_rf(j)=XUNDEF
  c%teb_shfl_rd(j)=XUNDEF
  c%teb_shfl_wl(j)=XUNDEF
  c%teb_ac_rf(j)=XUNDEF
  c%teb_ac_rd(j)=XUNDEF
  c%teb_ac_wl(j)=XUNDEF
  c%teb_ac_top(j)=XUNDEF
  c%teb_tch_rf(j)=XUNDEF
  c%teb_tch_rd(j)=XUNDEF
  c%teb_tch_wl(j)=XUNDEF
  c%teb_tch_top(j)=XUNDEF
  c%teb_wind_top(j)=XUNDEF
  c%teb_cd_garden_atm(j)=XUNDEF
  c%teb_ch_garden_atm(j)=XUNDEF
  c%ahf_traffic_now(j)=XUNDEF
END DO
END SUBROUTINE
SUBROUTINE write_packet(unit,c)
INTEGER,INTENT(IN)::unit
TYPE(TEB_BLOCK),INTENT(IN)::c
WRITE(unit) c%ntstep
WRITE(unit) c%nvec
WRITE(unit) c%iblock
WRITE(unit) c%dt
WRITE(unit) c%teb_year
WRITE(unit) c%teb_month
WRITE(unit) c%teb_day
WRITE(unit) c%teb_hour
WRITE(unit) c%teb_min
WRITE(unit) c%teb_sec
WRITE(unit) c%teb_hour_seconds
WRITE(unit) c%sa_uc
WRITE(unit) c%lon_teb
WRITE(unit) c%lat_teb
WRITE(unit) c%hlev_teb
WRITE(unit) c%ivstart
WRITE(unit) c%ivend
WRITE(unit) c%u
WRITE(unit) c%v
WRITE(unit) c%t
WRITE(unit) c%qv
WRITE(unit) c%ps
WRITE(unit) c%rho
WRITE(unit) c%prr_con
WRITE(unit) c%prs_con
WRITE(unit) c%prr_gsp
WRITE(unit) c%prs_gsp
WRITE(unit) c%prg_gsp
WRITE(unit) c%lwd_s
WRITE(unit) c%swdir_s
WRITE(unit) c%swdifd_s
WRITE(unit) c%teb_nroof_layer
WRITE(unit) c%teb_nroad_layer
WRITE(unit) c%teb_nwall_layer
WRITE(unit) c%teb_nfloor_layer
WRITE(unit) c%urb_d_rf
WRITE(unit) c%urb_d_rd
WRITE(unit) c%urb_d_wl
WRITE(unit) c%urb_fr_bld
WRITE(unit) c%fr_garden
WRITE(unit) c%urb_h2w
WRITE(unit) c%urb_h_bld
WRITE(unit) c%urb_hcap_rd
WRITE(unit) c%urb_hcap_rf
WRITE(unit) c%urb_hcap_wl
WRITE(unit) c%urb_hcon_rd
WRITE(unit) c%urb_hcon_rf
WRITE(unit) c%urb_hcon_wl
WRITE(unit) c%urb_alb_rd_so
WRITE(unit) c%urb_alb_rf_so
WRITE(unit) c%urb_alb_wl_so
WRITE(unit) c%urb_alb_rd_th
WRITE(unit) c%urb_alb_rf_th
WRITE(unit) c%urb_alb_wl_th
WRITE(unit) c%ahf_traffic
WRITE(unit) c%ahf_industry
WRITE(unit) c%teb_ti_bld
WRITE(unit) c%teb_troof
WRITE(unit) c%teb_troad
WRITE(unit) c%teb_twalla
WRITE(unit) c%teb_twallb
WRITE(unit) c%teb_tfloor
WRITE(unit) c%teb_tmass
WRITE(unit) c%teb_qi_bld
WRITE(unit) c%teb_tcanyon
WRITE(unit) c%teb_qcanyon
WRITE(unit) c%teb_ws_roof
WRITE(unit) c%teb_ws_road
WRITE(unit) c%teb_wsnow_roof
WRITE(unit) c%teb_wsnow_road
WRITE(unit) c%teb_tsnow_roof
WRITE(unit) c%teb_tsnow_road
WRITE(unit) c%teb_rsnow_roof
WRITE(unit) c%teb_rsnow_road
WRITE(unit) c%teb_tssnow_roof
WRITE(unit) c%teb_tssnow_road
WRITE(unit) c%teb_asnow_roof
WRITE(unit) c%teb_asnow_road
WRITE(unit) c%teb_esnow_roof
WRITE(unit) c%teb_esnow_road
WRITE(unit) c%teb_twin1
WRITE(unit) c%teb_twin2
WRITE(unit) c%teb_albwin
WRITE(unit) c%teb_itype_bem
WRITE(unit) c%teb_lbem_ac
WRITE(unit) c%teb_itype_natvent
WRITE(unit) c%teb_itype_bem_cool
WRITE(unit) c%teb_itype_bem_heat
WRITE(unit) c%teb_frac_gz
WRITE(unit) c%teb_tcool_target
WRITE(unit) c%teb_theat_target
WRITE(unit) c%teb_bem_vent
WRITE(unit) c%teb_bem_inf
WRITE(unit) c%teb_bem_cop
WRITE(unit) c%teb_cap_sys_rat
WRITE(unit) c%teb_m_sys_rat
WRITE(unit) c%teb_shad_day
WRITE(unit) c%teb_natvent_night
WRITE(unit) c%teb_lgreenroof
WRITE(unit) c%teb_frac_gr
WRITE(unit) c%teb_z0_gr
WRITE(unit) c%teb_alb_gr
WRITE(unit) c%teb_emis_gr
WRITE(unit) c%teb_ts_gr
WRITE(unit) c%teb_qs_gr
WRITE(unit) c%teb_shfl_gr
WRITE(unit) c%teb_lhfl_gr
WRITE(unit) c%teb_qvfl_gr
WRITE(unit) c%teb_runoff_gr
WRITE(unit) c%teb_lgarden
WRITE(unit) c%teb_z0_gd
WRITE(unit) c%teb_alb_gd
WRITE(unit) c%teb_emis_gd
WRITE(unit) c%teb_ts_gd
WRITE(unit) c%teb_qs_gd
WRITE(unit) c%teb_shfl_gd
WRITE(unit) c%teb_lhfl_gd
WRITE(unit) c%teb_qvfl_gd
WRITE(unit) c%teb_tch_gd
WRITE(unit) c%teb_tcm_gd
WRITE(unit) c%teb_runoff_gd
WRITE(unit) c%teb_itype_wind
WRITE(unit) c%teb_fai
WRITE(unit) c%teb_type_garden
WRITE(unit) c%teb_type_greenroof
WRITE(unit) c%teb_lgreenroof_ext
WRITE(unit) c%teb_hroad_dir
WRITE(unit) c%teb_wall_opt
WRITE(unit) c%teb_road_dir
WRITE(unit) c%teb_zresidential
WRITE(unit) c%teb_dt_res
WRITE(unit) c%teb_dt_off
WRITE(unit) c%teb_cap_sys_heat
WRITE(unit) c%teb_lsolar_panel
WRITE(unit) c%teb_fr_panel
WRITE(unit) c%teb_lroad_irrig
WRITE(unit) c%teb_rd_irrig_start_m
WRITE(unit) c%teb_rd_irrig_end_m
WRITE(unit) c%teb_rd_irrig_start_h
WRITE(unit) c%teb_rd_irrig_end_h
WRITE(unit) c%teb_rd_irrig_sum
WRITE(unit) c%teb_utc_hour
WRITE(unit) c%teb_lshade
WRITE(unit) c%urb_z0_town
WRITE(unit) c%urb_zd_town
! Retain the scalar slots in checkpoint v2. The lists come from the namelist.
WRITE(unit) c%urb_z0_o_z0h_gdn(1)
WRITE(unit) c%urb_z0_o_z0h_grf(1)
WRITE(unit) c%teb_lcbs_scheme
WRITE(unit) c%teb_tau_hw_thresh
WRITE(unit) c%teb_tau_hw_width
WRITE(unit) c%teb_wind_canyon
WRITE(unit) c%teb_u_can_ped
WRITE(unit) c%teb_u_can_10m
WRITE(unit) c%teb_sobs
WRITE(unit) c%teb_thbs
WRITE(unit) c%teb_runoff_road
WRITE(unit) c%teb_runoff_roof
WRITE(unit) c%teb_ustar_town
WRITE(unit) c%teb_cd_greenroof_atm
WRITE(unit) c%teb_troad_before
WRITE(unit) c%teb_ucanyon
WRITE(unit) c%teb_vcanyon
WRITE(unit) c%teb_tsroof
WRITE(unit) c%teb_tswalla
WRITE(unit) c%teb_tswallb
WRITE(unit) c%teb_shfl
WRITE(unit) c%teb_lhfl
WRITE(unit) c%teb_qvfl
WRITE(unit) c%teb_tstown_s
WRITE(unit) c%teb_qstown_s
WRITE(unit) c%teb_wstown
WRITE(unit) c%teb_runoff_town
WRITE(unit) c%teb_tssnow_town
WRITE(unit) c%teb_wsnow_town
WRITE(unit) c%teb_rsnow_town
WRITE(unit) c%teb_frsnow
WRITE(unit) c%teb_hsnow_town
WRITE(unit) c%teb_tch_town
WRITE(unit) c%teb_shfl_snow
WRITE(unit) c%teb_lhfl_snow
WRITE(unit) c%teb_snow_melt
WRITE(unit) c%teb_alb_so
WRITE(unit) c%teb_emis_town
WRITE(unit) c%teb_hwaste
WRITE(unit) c%teb_hvac_cool
WRITE(unit) c%teb_hvac_heat
WRITE(unit) c%teb_dqs_town
WRITE(unit) c%teb_gflux
WRITE(unit) c%teb_shfl_rf
WRITE(unit) c%teb_shfl_rd
WRITE(unit) c%teb_shfl_wl
WRITE(unit) c%teb_ac_rf
WRITE(unit) c%teb_ac_rd
WRITE(unit) c%teb_ac_wl
WRITE(unit) c%teb_ac_top
WRITE(unit) c%teb_tch_rf
WRITE(unit) c%teb_tch_rd
WRITE(unit) c%teb_tch_wl
WRITE(unit) c%teb_tch_top
WRITE(unit) c%teb_wind_top
WRITE(unit) c%teb_cd_garden_atm
WRITE(unit) c%teb_ch_garden_atm
WRITE(unit) c%ahf_traffic_now
WRITE(unit) c%emu_tau
WRITE(unit) c%emu_pcd_can
WRITE(unit) c%emu_pcd_atm
WRITE(unit) c%emu_pch_can
WRITE(unit) c%emu_pch_atm
WRITE(unit) c%emu_v_can
WRITE(unit) c%emu_v_atm
WRITE(unit) c%emu_ca_can
WRITE(unit) c%emu_ca_atm
WRITE(unit) c%emu_ca_eff
WRITE(unit) c%emu_v_star
WRITE(unit) c%emu_t_star
WRITE(unit) c%emu_q_star
WRITE(unit) c%emu_ch_eff
WRITE(unit) c%emu_cd_eff
WRITE(unit) c%emu_ch_naive
WRITE(unit) c%emu_psw
WRITE(unit) c%emu_plw
WRITE(unit) c%emu_ts
WRITE(unit) c%emu_rn
WRITE(unit) c%emu_h
WRITE(unit) c%emu_le
WRITE(unit) c%emu_evap
WRITE(unit) c%emu_qsat
WRITE(unit) c%emu_pac
WRITE(unit) c%emu_puw
WRITE(unit) c%emu_gflux
WRITE(unit) c%emu_sfco2
WRITE(unit) c%emu_runoff
WRITE(unit) c%emu_drain
WRITE(unit) c%emu_irrig
WRITE(unit) c%emu_gr_pcd
WRITE(unit) c%emu_gr_pch
WRITE(unit) c%emu_gr_v
WRITE(unit) c%emu_gr_t
WRITE(unit) c%emu_gr_q
WRITE(unit) c%emu_gr_ca
WRITE(unit) c%emu_gr_cd
WRITE(unit) c%emu_gr_ch
WRITE(unit) c%emu_gr_psw
WRITE(unit) c%emu_gr_plw
WRITE(unit) c%emu_gr_ts
WRITE(unit) c%emu_gr_rn
WRITE(unit) c%emu_gr_h
WRITE(unit) c%emu_gr_le
WRITE(unit) c%emu_gr_evap
WRITE(unit) c%emu_gr_qsat
WRITE(unit) c%emu_gr_pac
WRITE(unit) c%emu_gr_puw
WRITE(unit) c%emu_gr_gflux
WRITE(unit) c%emu_gr_sfco2
WRITE(unit) c%emu_gr_runoff
WRITE(unit) c%emu_gr_drain
WRITE(unit) c%emu_gr_irrig
WRITE(unit) c%runoff_road_acc
WRITE(unit) c%runoff_roof_acc
WRITE(unit) c%output_count
END SUBROUTINE
SUBROUTINE read_packet(unit,c)
INTEGER,INTENT(IN)::unit
TYPE(TEB_BLOCK),INTENT(INOUT)::c
INTEGER::rc
READ(unit,IOSTAT=rc) c%ntstep
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%nvec
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%iblock
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%dt
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_year
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_month
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_day
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_hour
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_min
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_sec
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_hour_seconds
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%sa_uc
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%lon_teb
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%lat_teb
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%hlev_teb
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%ivstart
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%ivend
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%u
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%v
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%t
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%qv
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%ps
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%rho
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%prr_con
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%prs_con
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%prr_gsp
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%prs_gsp
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%prg_gsp
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%lwd_s
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%swdir_s
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%swdifd_s
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_nroof_layer
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_nroad_layer
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_nwall_layer
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_nfloor_layer
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
IF(SIZE(c%teb_troof,2)/=c%teb_nroof_layer .OR. &
   SIZE(c%teb_troad,2)/=c%teb_nroad_layer .OR. &
   SIZE(c%teb_twalla,2)/=c%teb_nwall_layer) ERROR STOP 'Checkpoint layer mismatch'
READ(unit,IOSTAT=rc) c%urb_d_rf
IF(rc/=0) ERROR STOP "Incomplete layer depths"
READ(unit,IOSTAT=rc) c%urb_d_rd
IF(rc/=0) ERROR STOP "Incomplete layer depths"
READ(unit,IOSTAT=rc) c%urb_d_wl
IF(rc/=0) ERROR STOP "Incomplete layer depths"
READ(unit,IOSTAT=rc) c%urb_fr_bld
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%fr_garden
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_h2w
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_h_bld
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_hcap_rd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_hcap_rf
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_hcap_wl
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_hcon_rd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_hcon_rf
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_hcon_wl
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_alb_rd_so
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_alb_rf_so
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_alb_wl_so
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_alb_rd_th
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_alb_rf_th
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_alb_wl_th
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%ahf_traffic
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%ahf_industry
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ti_bld
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_troof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_troad
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_twalla
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_twallb
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tfloor
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tmass
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_qi_bld
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tcanyon
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_qcanyon
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ws_roof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ws_road
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_wsnow_roof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_wsnow_road
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tsnow_roof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tsnow_road
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_rsnow_roof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_rsnow_road
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tssnow_roof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tssnow_road
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_asnow_roof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_asnow_road
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_esnow_roof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_esnow_road
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_twin1
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_twin2
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_albwin
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_itype_bem
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lbem_ac
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_itype_natvent
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_itype_bem_cool
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_itype_bem_heat
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_frac_gz
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tcool_target
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_theat_target
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_bem_vent
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_bem_inf
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_bem_cop
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_cap_sys_rat
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_m_sys_rat
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_shad_day
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_natvent_night
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lgreenroof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_frac_gr
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_z0_gr
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_alb_gr
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_emis_gr
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ts_gr
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_qs_gr
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_shfl_gr
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lhfl_gr
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_qvfl_gr
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_runoff_gr
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lgarden
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_z0_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_alb_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_emis_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ts_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_qs_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_shfl_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lhfl_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_qvfl_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tch_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tcm_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_runoff_gd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_itype_wind
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_fai
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_type_garden
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_type_greenroof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lgreenroof_ext
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_hroad_dir
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_wall_opt
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_road_dir
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_zresidential
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_dt_res
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_dt_off
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_cap_sys_heat
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lsolar_panel
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_fr_panel
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lroad_irrig
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_rd_irrig_start_m
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_rd_irrig_end_m
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_rd_irrig_start_h
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_rd_irrig_end_h
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_rd_irrig_sum
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_utc_hour
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lshade
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_z0_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_zd_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_z0_o_z0h_gdn(1)
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%urb_z0_o_z0h_grf(1)
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lcbs_scheme
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tau_hw_thresh
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tau_hw_width
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_wind_canyon
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_u_can_ped
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_u_can_10m
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_sobs
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_thbs
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_runoff_road
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_runoff_roof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ustar_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_cd_greenroof_atm
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_troad_before
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ucanyon
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_vcanyon
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tsroof
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tswalla
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tswallb
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_shfl
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lhfl
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_qvfl
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tstown_s
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_qstown_s
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_wstown
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_runoff_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tssnow_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_wsnow_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_rsnow_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_frsnow
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_hsnow_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tch_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_shfl_snow
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_lhfl_snow
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_snow_melt
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_alb_so
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_emis_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_hwaste
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_hvac_cool
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_hvac_heat
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_dqs_town
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_gflux
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_shfl_rf
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_shfl_rd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_shfl_wl
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ac_rf
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ac_rd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ac_wl
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ac_top
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tch_rf
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tch_rd
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tch_wl
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_tch_top
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_wind_top
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_cd_garden_atm
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%teb_ch_garden_atm
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%ahf_traffic_now
IF(rc/=0) ERROR STOP "Incomplete checkpoint"
READ(unit,IOSTAT=rc) c%emu_tau
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_pcd_can
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_pcd_atm
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_pch_can
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_pch_atm
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_v_can
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_v_atm
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_ca_can
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_ca_atm
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_ca_eff
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_v_star
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_t_star
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_q_star
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_ch_eff
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_cd_eff
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_ch_naive
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_psw
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_plw
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_ts
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_rn
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_h
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_le
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_evap
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_qsat
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_pac
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_puw
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gflux
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_sfco2
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_runoff
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_drain
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_irrig
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_pcd
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_pch
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_v
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_t
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_q
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_ca
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_cd
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_ch
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_psw
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_plw
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_ts
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_rn
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_h
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_le
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_evap
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_qsat
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_pac
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_puw
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_gflux
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_sfco2
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_runoff
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_drain
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%emu_gr_irrig
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%runoff_road_acc
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%runoff_roof_acc
IF(rc/=0) ERROR STOP 'Truncated output state'
READ(unit,IOSTAT=rc) c%output_count
IF(rc/=0) ERROR STOP 'Truncated output count'
END SUBROUTINE
LOGICAL FUNCTION same_config(a,b)
TYPE(BLOCK_CONFIG),INTENT(IN)::a,b
same_config=( (a%nvec==b%nvec) &
  .AND. (a%nblocks==b%nblocks) &
  .AND. (a%nsteps==b%nsteps) &
  .AND. (a%source_nvec==b%source_nvec) &
  .AND. (a%sample_column==b%sample_column) &
  .AND. (a%ivstart==b%ivstart) &
  .AND. (a%ivend==b%ivend) &
  .AND. (a%mask_stride==b%mask_stride) &
  .AND. (a%perturb_column==b%perturb_column) &
  .AND. (a%from_step==b%from_step) &
  .AND. (a%permute_step==b%permute_step) &
  .AND. (a%dt==b%dt) &
  .AND. (a%factor==b%factor) &
  .AND. (a%delta==b%delta) &
  .AND. (a%year==b%year) &
  .AND. (a%month==b%month) &
  .AND. (a%day==b%day) &
  .AND. (a%hour==b%hour) &
  .AND. (a%minute==b%minute) &
  .AND. (a%lon==b%lon) &
  .AND. (a%lat==b%lat) &
  .AND. (a%height==b%height) &
  .AND. (a%profile==b%profile) &
  .AND. (a%scenario==b%scenario) &
  .AND. (a%layout==b%layout) &
  .AND. (a%parameter==b%parameter) &
  .AND. (a%forcing_source==b%forcing_source) &
  .AND. (a%forcing_nml==b%forcing_nml) &
  .AND. (a%test_fault==b%test_fault) &
  .AND. (a%reverse .EQV. b%reverse) &
  .AND. (a%fresh_work .EQV. b%fresh_work) &
  .AND. a%parameter_signature==b%parameter_signature &
  .AND. (a%write_emu .EQV. b%write_emu) &
  .AND. (a%write_runoff .EQV. b%write_runoff) &
  .AND. (a%model_log .EQV. b%model_log) )
END FUNCTION
SUBROUTINE config_echo(path,c)
CHARACTER(LEN=*),INTENT(IN)::path
TYPE(BLOCK_CONFIG),INTENT(IN)::c
INTEGER::unit,rc
OPEN(NEWUNIT=unit,FILE=TRIM(path),STATUS='REPLACE',ACTION='WRITE',IOSTAT=rc)
IF(rc/=0) ERROR STOP 'Cannot create configuration echo'
WRITE(unit,'(A,I0)') 'nvec=',c%nvec
WRITE(unit,'(A,I0)') 'nblocks=',c%nblocks
WRITE(unit,'(A,I0)') 'nsteps=',c%nsteps
WRITE(unit,'(A,I0)') 'source_nvec=',c%source_nvec
WRITE(unit,'(A,I0)') 'sample_column=',c%sample_column
WRITE(unit,'(A,I0)') 'ivstart=',c%ivstart
WRITE(unit,'(A,I0)') 'ivend=',c%ivend
WRITE(unit,'(A,I0)') 'mask_stride=',c%mask_stride
WRITE(unit,'(A,I0)') 'perturb_column=',c%perturb_column
WRITE(unit,'(A,I0)') 'from_step=',c%from_step
WRITE(unit,'(A,I0)') 'permute_step=',c%permute_step
WRITE(unit,'(A,I0)') 'stop_after=',c%stop_after
WRITE(unit,'(A,ES26.17E3)') 'dt=',c%dt
WRITE(unit,'(A,ES26.17E3)') 'factor=',c%factor
WRITE(unit,'(A,ES26.17E3)') 'delta=',c%delta
WRITE(unit,'(A,I0)') 'year=',c%year
WRITE(unit,'(A,I0)') 'month=',c%month
WRITE(unit,'(A,I0)') 'day=',c%day
WRITE(unit,'(A,I0)') 'hour=',c%hour
WRITE(unit,'(A,I0)') 'minute=',c%minute
WRITE(unit,'(A,ES26.17E3)') 'lon=',c%lon
WRITE(unit,'(A,ES26.17E3)') 'lat=',c%lat
WRITE(unit,'(A,ES26.17E3)') 'height=',c%height
WRITE(unit,'(A,A)') 'profile=',c%profile
WRITE(unit,'(A,A)') 'scenario=',c%scenario
WRITE(unit,'(A,A)') 'layout=',c%layout
WRITE(unit,'(A,A)') 'parameter=',c%parameter
WRITE(unit,'(A,A)') 'forcing_source=',c%forcing_source
WRITE(unit,'(A,A)') 'forcing_nml=',c%forcing_nml
WRITE(unit,'(A,A)') 'checkpoint_file=',c%checkpoint_file
WRITE(unit,'(A,A)') 'restart_file=',c%restart_file
WRITE(unit,'(A,A)') 'test_fault=',c%test_fault
WRITE(unit,'(A,L1)') 'reverse=',c%reverse
WRITE(unit,'(A,L1)') 'fresh_work=',c%fresh_work
WRITE(unit,'(A,L1)') 'model_log=',c%model_log
WRITE(unit,'(A,A)') 'param_nml=',TRIM(c%param_nml)
WRITE(unit,'(A,L1)') 'write_emu=',c%write_emu
WRITE(unit,'(A,L1)') 'write_runoff=',c%write_runoff
WRITE(unit,'(A,L1)') 'test_dump=',c%test_dump
WRITE(unit,'(A,I0)') 'parameter_signature=',c%parameter_signature
CLOSE(unit)
END SUBROUTINE

! All state below belongs to the host. The physics still receives one complete
! runtime-sized packet per block through the public interface.
LOGICAL FUNCTION active(c,j)
TYPE(TEB_BLOCK),INTENT(IN)::c
INTEGER,INTENT(IN)::j
active=j>=c%ivstart .AND. j<=c%ivend .AND. c%sa_uc(j)>0.
END FUNCTION

SUBROUTINE validate(cfg)
TYPE(BLOCK_CONFIG),INTENT(INOUT)::cfg
IF(cfg%nvec<1 .OR. cfg%nblocks<1 .OR. cfg%nsteps<0 .OR. cfg%dt<=0.) ERROR STOP &
  'Invalid dimensions or time step'
IF(cfg%source_nvec==0) cfg%source_nvec=cfg%nvec
IF(cfg%source_nvec<cfg%nvec) ERROR STOP 'source_nvec is smaller than nvec'
IF(cfg%sample_column<0 .OR. cfg%sample_column>cfg%source_nvec) ERROR STOP 'Invalid scalar sample'
IF(cfg%sample_column>0 .AND. cfg%nvec/=1) ERROR STOP 'A scalar sample requires nvec=1'
IF(cfg%ivend==-1) cfg%ivend=cfg%nvec
IF(cfg%ivstart<1 .OR. cfg%ivstart>cfg%nvec+1 .OR. cfg%ivend>cfg%nvec &
  .OR. cfg%ivend<cfg%ivstart-1) ERROR STOP 'Invalid block window'
IF(cfg%mask_stride<0 .OR. cfg%from_step<0) ERROR STOP 'Invalid mask or modification step'
IF(cfg%perturb_column<1 .OR. cfg%perturb_column>cfg%source_nvec) ERROR STOP 'Invalid perturbation column'
SELECT CASE(TRIM(cfg%scenario))
CASE('UNIFORM','SINGLE','RAMP')
CASE DEFAULT
  ERROR STOP 'Unknown scenario'
END SELECT
SELECT CASE(TRIM(cfg%layout))
CASE('BLOCK','SERIAL')
CASE DEFAULT
  ERROR STOP 'Unknown call layout'
END SELECT
SELECT CASE(TRIM(cfg%forcing_source))
CASE('SYNTHETIC','FILE')
CASE DEFAULT
  ERROR STOP 'Unknown forcing source'
END SELECT
IF(cfg%nsteps==0 .AND. cfg%forcing_source/='FILE') ERROR STOP 'Synthetic forcing needs nsteps>0'
SELECT CASE(TRIM(cfg%test_fault))
CASE('NONE','BROADCAST_FIRST')
CASE DEFAULT
  ERROR STOP 'Unknown checker fault injection'
END SELECT
IF(cfg%model_log .AND. cfg%layout=='SERIAL' .AND. cfg%nvec>1) ERROR STOP &
  'Use BLOCK layout for per-cell model CSV'
END SUBROUTINE



SUBROUTINE load_file(cfg,table,cadence)
TYPE(BLOCK_CONFIG),INTENT(INOUT)::cfg
REAL(teb_real_kind),ALLOCATABLE,INTENT(OUT)::table(:,:)
INTEGER,INTENT(OUT)::cadence
CHARACTER(LEN=512)::forcing_path,message
CHARACTER(LEN=4096)::input_line
CHARACTER(LEN=:),ALLOCATABLE::input_text
REAL(teb_real_kind)::lon_teb(1),lat_teb(1),hlev_teb(1),forc_step
REAL(teb_real_kind)::zta(2,1),zqa(2,1),zwind(2,1),zdir_sw(2,1),zsca_sw(2,1),zlw(2,1)
REAL(teb_real_kind)::zsnow(2,1),zrain(2,1),zps(2,1),zdir(2,1)
INTEGER::teb_year,teb_month,teb_day,teb_hour,teb_min,nsteps,unit,rc,k,sub,step,total
INTEGER::month_days(12)
NAMELIST /tebforcing/ forcing_path,lon_teb,lat_teb,hlev_teb,teb_year,teb_month,teb_day,teb_hour,teb_min, &
  nsteps,forc_step
forcing_path=''
lon_teb=1.3
lat_teb=43.484
hlev_teb=28.
teb_year=-9999
teb_month=-9999
teb_day=-9999
teb_hour=-9999
teb_min=-9999
nsteps=0
forc_step=1800.
OPEN(NEWUNIT=unit,FILE=TRIM(cfg%forcing_nml),STATUS='OLD',ACTION='READ',IOSTAT=rc)
IF(rc/=0) ERROR STOP 'Cannot open forcing namelist'
! Normalize the final record: GNU namelist input can return EOF for a valid
! terminating slash without a final newline.
input_text=''
DO
  READ(unit,'(A)',IOSTAT=rc) input_line
  IF(rc/=0) EXIT
  input_text=input_text//TRIM(input_line)//ACHAR(10)
END DO
CLOSE(unit)
READ(input_text,NML=tebforcing,IOSTAT=rc,IOMSG=message)
IF(rc>0) THEN
  WRITE(*,*) TRIM(message)
  ERROR STOP 'Invalid forcing namelist'
END IF
IF(LEN_TRIM(forcing_path)==0) ERROR STOP 'Missing forcing_path'
IF(teb_year<1 .OR. teb_month<1 .OR. teb_month>12 .OR. teb_day<1 .OR. teb_day>31 .OR. &
  teb_hour<0 .OR. teb_hour>23 .OR. teb_min<0 .OR. teb_min>59) ERROR STOP 'Invalid or missing forcing date'
month_days=[31,28,31,30,31,30,31,31,30,31,30,31]
IF(MOD(teb_year,4)==0 .AND. (MOD(teb_year,100)/=0 .OR. MOD(teb_year,400)==0)) month_days(2)=29
IF(teb_day>month_days(teb_month)) ERROR STOP 'Invalid day of forcing month'
IF(.NOT.IEEE_IS_FINITE(forc_step) .OR. forc_step<=0.) ERROR STOP 'Invalid forcing step'
IF(.NOT.ALL(IEEE_IS_FINITE(hlev_teb)) .OR. ANY(hlev_teb<=0.)) ERROR STOP 'Invalid forcing height'
IF(.NOT.ALL(IEEE_IS_FINITE(lon_teb)) .OR. .NOT.ALL(IEEE_IS_FINITE(lat_teb))) ERROR STOP &
  'Invalid forcing coordinates'
IF(ANY(ABS(lat_teb)>90.) .OR. ANY(ABS(lon_teb)>360.)) ERROR STOP 'Forcing coordinates out of range'
IF(forc_step/cfg%dt>REAL(HUGE(cadence)-1)) ERROR STOP 'Forcing cadence exceeds integer range'
IF(MOD(forc_step,cfg%dt)/=0.) ERROR STOP 'Forcing step must be divisible by dt'
cadence=NINT(forc_step/cfg%dt)
IF(nsteps<2 .OR. cadence<1) ERROR STOP 'Invalid file forcing length or cadence'
IF(ABS(cadence*cfg%dt-forc_step)>1.E-8) ERROR STOP 'Forcing step must be divisible by dt'
total=(nsteps-1)*cadence
IF(cfg%nsteps==0) cfg%nsteps=total
IF(cfg%nsteps>total) ERROR STOP 'Requested more steps than file forcing supplies'
cfg%lon=lon_teb(1)
cfg%lat=lat_teb(1)
cfg%height=hlev_teb(1)
cfg%year=teb_year
cfg%month=teb_month
cfg%day=teb_day
cfg%hour=teb_hour
cfg%minute=teb_min
ALLOCATE(table(11,cfg%nsteps))
CALL OPEN_CLOSE_BIN_ASC_FORC('OPEN ','ASCII ',1,'R',TRIM(forcing_path))
CALL OL_ALLOC_ATM(1,1,1)
! Set the host-owned heights before the first interpolation, as in ordinary offline.
XZREF=hlev_teb
XUREF=hlev_teb
CALL OL_READ_ATM('ASCII ','ASCII ',1,TRIM(forcing_path),zta,zqa,zwind,zdir_sw,zsca_sw,zlw,zsnow,zrain, &
                 zps,zdir)
XRHOA=zps(1,:)/(zta(1,:)*XRD*(1.+(XRV/XRD-1.)*zqa(1,:))+hlev_teb*XG)
step=0
outer: DO k=1,nsteps-1
  CALL OL_READ_ATM('ASCII ','ASCII ',k,TRIM(forcing_path),zta,zqa,zwind,zdir_sw,zsca_sw,zlw,zsnow,zrain, &
                   zps,zdir)
  DO sub=1,cadence
    CALL OL_TIME_INTERP_ATM(sub,cadence,zta,zqa,zwind,zdir_sw,zsca_sw,zlw,zsnow,zrain,zps,zdir)
    step=step+1
    table(:,step)=[XTA(1),XQA(1)/XRHOA(1),XU(1),XV(1),XPS(1),XRHOA(1), &
      XRAIN(1),XSNOW(1),XLW(1),XDIR_SW(1,1),XSCA_SW(1,1)]
    IF(step==cfg%nsteps) EXIT outer
  END DO
END DO outer
CALL OPEN_CLOSE_BIN_ASC_FORC('CLOSE ','ASCII ',1,'R',TRIM(forcing_path))
END SUBROUTINE

SUBROUTINE forcing(c,cfg,step,table)
TYPE(TEB_BLOCK),INTENT(INOUT)::c
TYPE(BLOCK_CONFIG),INTENT(IN)::cfg
INTEGER,INTENT(IN)::step
REAL(teb_real_kind),INTENT(IN)::table(:,:)
REAL(teb_real_kind)::wave
c%ntstep=step
IF(step==0) THEN
  c%teb_year=cfg%year
  c%teb_month=cfg%month
  c%teb_day=cfg%day
  c%teb_hour_seconds=cfg%hour*3600.+cfg%minute*60.
END IF
c%teb_hour_seconds=c%teb_hour_seconds+cfg%dt
CALL ADD_FORECAST_TO_DATE_SURF(c%teb_year,c%teb_month,c%teb_day,c%teb_hour_seconds(1))
c%teb_hour=INT(c%teb_hour_seconds(1)/3600.)
c%teb_min=INT(MOD(c%teb_hour_seconds(1),3600.)/60.)
c%teb_sec=INT(MOD(c%teb_hour_seconds(1),60.))
c%prr_con=0.
c%prs_con=0.
c%prr_gsp=0.
c%prs_gsp=0.
c%prg_gsp=0.
IF(cfg%forcing_source=='FILE') THEN
  c%t=table(1,step+1)
  c%qv=table(2,step+1)
  c%u=table(3,step+1)
  c%v=table(4,step+1)
  c%ps=table(5,step+1)
  c%rho=table(6,step+1)
  c%prr_con=table(7,step+1)
  c%prs_con=table(8,step+1)
  c%lwd_s=table(9,step+1)
  c%swdir_s=table(10,step+1)
  c%swdifd_s=table(11,step+1)
ELSE
  wave=SIN(0.17*step)
  c%t=295.+wave
  c%qv=0.007
  c%u=3.+0.3*wave
  c%v=1.2
  c%ps=100900.
  c%lwd_s=330.
  c%swdir_s=MAX(100.,500.-2.*step)
  c%swdifd_s=80.
  IF(cfg%profile=='SNOW') THEN
    c%t=268.
    c%lwd_s=240.
    c%swdir_s=0.
    c%swdifd_s=0.
    IF(step<12) c%prs_con=0.0001
    IF(step>=12) THEN
      c%t=282.
      c%swdir_s=500.
      c%swdifd_s=80.
      c%lwd_s=330.
    END IF
    IF(step>=24 .AND. step<30) c%prr_con=0.0002
  END IF
  c%rho=c%ps/(XRD*c%t*(1.+(XRV/XRD-1.)*c%qv)+c%hlev_teb*XG)
END IF
IF(cfg%profile=='SNOW' .AND. step==1) THEN
  c%teb_wsnow_roof=20.
  c%teb_wsnow_road=30.
  c%teb_tsnow_roof=265.
  c%teb_tsnow_road=265.
  c%teb_tssnow_roof=265.
  c%teb_tssnow_road=265.
  c%teb_rsnow_roof=200.
  c%teb_rsnow_road=200.
  c%teb_asnow_roof=0.7
  c%teb_asnow_road=0.7
  c%teb_esnow_roof=1.
  c%teb_esnow_road=1.
END IF
END SUBROUTINE

SUBROUTINE modify(c,cfg,ids,step)
TYPE(TEB_BLOCK),INTENT(INOUT)::c
TYPE(BLOCK_CONFIG),INTENT(IN)::cfg
INTEGER,INTENT(IN)::ids(:),step
REAL(teb_real_kind)::weight,mult,offset
INTEGER::j
LOGICAL::each_step
IF(cfg%scenario=='UNIFORM' .OR. step<cfg%from_step) RETURN
each_step=cfg%parameter=='t' .OR. cfg%parameter=='u'
IF(.NOT.each_step .AND. step/=cfg%from_step) RETURN
DO j=1,c%nvec
  weight=1.
  IF(cfg%scenario=='SINGLE' .AND. ids(j)/=cfg%perturb_column) CYCLE
  IF(cfg%scenario=='RAMP') weight=REAL(ids(j)-1+(c%iblock-1)*cfg%source_nvec,teb_real_kind)
  mult=1.+weight*(cfg%factor-1.)
  offset=weight*cfg%delta
  SELECT CASE(TRIM(cfg%parameter))
  CASE('ahf_traffic')
    c%ahf_traffic(j)=c%ahf_traffic(j)*mult+offset
  CASE('urb_alb_rf_so')
    c%urb_alb_rf_so(j)=c%urb_alb_rf_so(j)*mult+offset
    IF(c%urb_alb_rf_so(j)<0. .OR. c%urb_alb_rf_so(j)>1.) ERROR STOP 'Albedo outside 0:1'
  CASE('urb_hcap_rd')
    c%urb_hcap_rd(j)=c%urb_hcap_rd(j)*mult+offset
    IF(c%urb_hcap_rd(j)<=0.) ERROR STOP 'Nonpositive heat capacity'
  CASE('urb_h2w')
    c%urb_h2w(j)=c%urb_h2w(j)*mult+offset
    IF(c%urb_h2w(j)<=0.) ERROR STOP 'Nonpositive aspect ratio'
  CASE('teb_z0_gr')
    c%teb_z0_gr(j)=c%teb_z0_gr(j)*mult+offset
    IF(c%teb_z0_gr(j)<=0. .OR. c%teb_z0_gr(j)>=c%hlev_teb(j)) ERROR STOP 'Invalid roof roughness'
  CASE('u')
    c%u(j)=c%u(j)*mult+offset
  CASE('t')
    c%t(j)=c%t(j)*mult+offset
    IF(c%t(j)<150. .OR. c%t(j)>350.) ERROR STOP 'Implausible air temperature'
    c%rho(j)=c%ps(j)/(XRD*c%t(j)*(1.+(XRV/XRD-1.)*c%qv(j))+c%hlev_teb(j)*XG)
  CASE('teb_troad_top')
    IF(step==0) ERROR STOP 'Road state perturbation requires a warm step'
    c%teb_troad(j,1)=c%teb_troad(j,1)*mult+offset
  CASE('teb_ustar_town')
    IF(step==0) ERROR STOP 'Friction memory perturbation requires a warm step'
    c%teb_ustar_town(j)=c%teb_ustar_town(j)*mult+offset
  CASE('teb_cd_greenroof_atm')
    IF(step==0) ERROR STOP 'Roof CD memory perturbation requires a warm step'
    c%teb_cd_greenroof_atm(j)=c%teb_cd_greenroof_atm(j)*mult+offset
  CASE DEFAULT
    ERROR STOP 'Unknown array modification'
  END SELECT
END DO
END SUBROUTINE



SUBROUTINE dump(unit,c,ids,phase)
! Stream format v1: four INT32 header words, then six INT32 metadata words and
! field_count(c) REAL64 values per record. fields.csv describes their order and intent.
! Phase 0 is immediately before the API; phase 1 precedes host emulator updates.
INTEGER,INTENT(IN)::unit,ids(:),phase
TYPE(TEB_BLOCK),INTENT(IN)::c
REAL(teb_real_kind)::values(field_count(c))
INTEGER::j
DO j=1,c%nvec
  CALL pack(c,j,values)
  IF(ANY(.NOT.IEEE_IS_FINITE(values))) ERROR STOP 'Nonfinite value in diagnostic packet'
  WRITE(unit) INT([c%ntstep,c%iblock,ids(j),j,MERGE(1,0,active(c,j)),phase],INT32),values
END DO
END SUBROUTINE

SUBROUTINE permute(c,ids)
TYPE(TEB_BLOCK),INTENT(INOUT)::c
INTEGER,INTENT(INOUT)::ids(:)
TYPE(TEB_BLOCK)::saved
INTEGER::j
saved=c
DO j=1,c%nvec
  CALL copy_column(c,j,saved,c%nvec+1-j)
END DO
ids=ids(SIZE(ids):1:-1)
END SUBROUTINE

SUBROUTINE save_checkpoint(path,cfg,next_step,blocks,ids)
! Diagnostic checkpoint only: same executable/platform/configuration on restart.
! Store full external-surface packets after emulator updates, not just TEB INOUT.
CHARACTER(LEN=*),INTENT(IN)::path
TYPE(BLOCK_CONFIG),INTENT(IN)::cfg
INTEGER,INTENT(IN)::next_step,ids(:,:)
TYPE(TEB_BLOCK),INTENT(IN)::blocks(:)
INTEGER::unit,b,rc
OPEN(NEWUNIT=unit,FILE=TRIM(path),ACCESS='STREAM',FORM='UNFORMATTED',STATUS='REPLACE',IOSTAT=rc)
IF(rc/=0) ERROR STOP 'Cannot create checkpoint'
WRITE(unit) INT([1413825074,3,field_count(blocks(1)),STORAGE_SIZE(blocks(1)%t)],INT32)
WRITE(unit) cfg,next_step,ids
DO b=1,SIZE(blocks)
  CALL write_packet(unit,blocks(b))
END DO
CLOSE(unit)
END SUBROUTINE

SUBROUTINE load_checkpoint(path,cfg,next_step,blocks,ids,base)
CHARACTER(LEN=*),INTENT(IN)::path
TYPE(BLOCK_CONFIG),INTENT(IN)::cfg
TYPE(TEB_BLOCK),INTENT(IN)::base
INTEGER,INTENT(OUT)::next_step,ids(:,:)
TYPE(TEB_BLOCK),INTENT(INOUT)::blocks(:)
TYPE(BLOCK_CONFIG)::saved_cfg
INTEGER(INT32)::header(4)
INTEGER::unit,b,rc,columns(SIZE(ids,1))
OPEN(NEWUNIT=unit,FILE=TRIM(path),ACCESS='STREAM',FORM='UNFORMATTED',STATUS='OLD',IOSTAT=rc)
IF(rc/=0) ERROR STOP 'Cannot open checkpoint'
READ(unit,IOSTAT=rc) header
IF(rc/=0) ERROR STOP 'Invalid checkpoint header'
IF(ANY(header/=INT([1413825074,3,field_count(blocks(1)),STORAGE_SIZE(blocks(1)%t)],INT32))) ERROR STOP &
  'Checkpoint format mismatch'
READ(unit,IOSTAT=rc) saved_cfg,next_step
IF(rc/=0) ERROR STOP 'Incomplete checkpoint configuration'
IF(.NOT.same_config(cfg,saved_cfg)) ERROR STOP 'Checkpoint configuration mismatch'
IF(next_step<1 .OR. next_step>=cfg%nsteps) ERROR STOP 'Invalid checkpoint time'
READ(unit,IOSTAT=rc) ids
IF(rc/=0) ERROR STOP 'Incomplete checkpoint indices'
DO b=1,SIZE(blocks)
  CALL read_packet(unit,blocks(b))
  columns=ids(:,b)
  ! A scalar sample has its original diagnostic ID and one namelist slot.
  IF (cfg%sample_column>0) columns=1
  IF (ANY(columns<1) .OR. ANY(columns>base%nvec)) ERROR STOP 'Invalid checkpoint column IDs'
  blocks(b)%urb_z0_o_z0h_gdn=base%urb_z0_o_z0h_gdn(columns)
  blocks(b)%urb_z0_o_z0h_grf=base%urb_z0_o_z0h_grf(columns)
END DO
CLOSE(unit)
END SUBROUTINE


END MODULE TEB_OFFLINE_HOST
