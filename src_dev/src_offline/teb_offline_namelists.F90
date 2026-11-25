!SFX_LIC TEB/SURFEX interfaces are distributed under the CeCILL-C licence.
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      Pre-repository -- Maria Tarasova (MT)
!!        Configure the standalone host through model/forcing namelists.
!!      09/2026 -- Mikhail Varentsov (MV)
!!        Validate namelist input and configurable diagnostic surface properties.
!!      11/2026 -- Mikhail Varentsov (MV)
!!        Share strict options/parameters and scalar-or-nvec expansion.
!!        Read timestep and named scheme selectors from common options,
!!        translating them to the unchanged API and retaining legacy input.
!!      11/2026 -- OpenAI Codex
!!        Read independent road, roof and canyon exchange algorithms.
!!      11/2026 -- OpenAI Codex
!!        Read the scalar road, roof and snow momentum roughness lengths.
!!      11/2026 -- OpenAI Codex
!!        Configure the town roughness rule in tebopts.
!!      11/2026 -- OpenAI Codex
!!        Read thermal roughness rules and per-column vegetation ratios.
!!        Keep scalar CBS settings together in tebopts for split namelists.
!!        Read layer counts and one positive depth profile per surface.
!!      11/2026 -- OpenAI Codex
!!        Read the named canyon wind scheme in both model namelist formats.
!!      11/2026 -- OpenAI Codex
!!        Read the dynamic town roughness and displacement rules in tebopts.
!!      11/2026 -- OpenAI Codex
!!        Derive omitted frontal area indices from each cell's wall area.
!-------------------------------------------------------------------------------
MODULE TEB_OFFLINE_NAMELISTS
USE TEB_OFFLINE_HOST, ONLY: BLOCK_CONFIG, TEB_BLOCK, allocate_block
USE TEB_HOST, ONLY: TEB_DEFAULT_D_RF, TEB_DEFAULT_D_RD, TEB_DEFAULT_D_WL, TEB_WALL_AREA_INDEX
USE MODD_CSTS, ONLY: XPI
USE MODD_SURF_PAR, ONLY: XUNDEF, teb_snow_check
USE MODD_SNOW_PAR, ONLY: XZ0SN
USE MODD_TEB_OPTION_n, ONLY: CTEB_EXCH_DEFAULT, TEB_EXCH_VALID, TEB_Z0H_t, &
                             TEB_Z0H_RULE_t, TEB_PARSE_Z0H, TEB_Z0_RATIO_VALID, &
                             CTEB_TOWN_DYNCORR_DEFAULT, TEB_PARSE_TOWN_DYNCORR
USE MODD_PROXI_SVAT_PAR, ONLY: XZ0_GD, XZ0_GR, XZ0_O_Z0H_GD, XZ0_O_Z0H_GR, proxy_phu_gdn, proxy_phu_grf
USE MODE_THERMOS, ONLY: QSAT
USE, INTRINSIC :: IEEE_ARITHMETIC, ONLY: IEEE_IS_FINITE
USE, INTRINSIC :: ISO_FORTRAN_ENV, ONLY: INT32
IMPLICIT NONE
PRIVATE
PUBLIC :: READ_OFFLINE_PARAMETERS
TYPE NML_ASSIGNMENT
  CHARACTER(LEN=64) :: name=''
  CHARACTER(LEN=:), ALLOCATABLE :: value
  INTEGER :: line=0
  INTEGER :: count=0
END TYPE
CONTAINS
SUBROUTINE READ_OFFLINE_PARAMETERS(path,c,cfg)
CHARACTER(LEN=*), INTENT(IN) :: path
TYPE(TEB_BLOCK), INTENT(OUT) :: c
TYPE(BLOCK_CONFIG), INTENT(INOUT) :: cfg
TYPE(NML_ASSIGNMENT), ALLOCATABLE :: a(:),o(:)
CHARACTER(LEN=:), ALLOCATABLE :: text,body,opts
CHARACTER(LEN=1024) :: message
INTEGER :: nvec,rc,j,k,unit
INTEGER :: teb_nroof_layer, teb_nroad_layer, teb_nwall_layer
REAL, ALLOCATABLE :: urb_d_rf(:), urb_d_rd(:), urb_d_wl(:)
LOGICAL :: legacy,found,teb_lwrite_output,teb_lwrite_emu,teb_lwrite_runoff,teb_lwrite_test_dump
LOGICAL :: valid_town_dyncorr, has_fai
REAL :: dt
CHARACTER(LEN=3) :: teb_ctype_bem
CHARACTER(LEN=4) :: teb_ctype_natvent
CHARACTER(LEN=6) :: teb_ctype_bem_cool
CHARACTER(LEN=6) :: teb_ctype_bem_heat
CHARACTER(LEN=4) :: teb_ctype_wind
CHARACTER(LEN=6) :: teb_ctype_exch_rd, teb_ctype_exch_rf, teb_ctype_exch_canyon
CHARACTER(LEN=9) :: teb_ctype_garden
CHARACTER(LEN=9) :: teb_ctype_greenroof
CHARACTER(LEN=16) :: teb_ctype_z0_town
CHARACTER(LEN=16) :: teb_ctype_z0_town_dyncorr, teb_ctype_zd_town_dyncorr
CHARACTER(LEN=LEN(CTEB_TOWN_DYNCORR_DEFAULT)) :: z0_town_dyncorr, zd_town_dyncorr
CHARACTER(LEN=16) :: teb_ctype_z0_o_z0h_rd, teb_ctype_z0_o_z0h_rf, teb_ctype_z0_o_z0h_town
TYPE(TEB_Z0H_t) :: z0h
REAL, ALLOCATABLE :: urb_h_bld(:)
REAL, ALLOCATABLE :: urb_fr_bld(:)
REAL, ALLOCATABLE :: fr_garden(:)
REAL, ALLOCATABLE :: urb_h2w(:)
REAL, ALLOCATABLE :: teb_road_dir(:)
CHARACTER(LEN=4) :: teb_hroad_dir
CHARACTER(LEN=4) :: teb_wall_opt
REAL, ALLOCATABLE :: teb_ti_bld_init(:)
REAL, ALLOCATABLE :: teb_qi_bld_init(:)
REAL, ALLOCATABLE :: urb_alb_rf_so(:)
REAL, ALLOCATABLE :: urb_alb_rf_th(:)
REAL, ALLOCATABLE :: urb_emis_rf(:)
REAL, ALLOCATABLE :: urb_hcap_rf(:)
REAL, ALLOCATABLE :: urb_hcon_rf(:)
REAL, ALLOCATABLE :: urb_alb_rd_so(:)
REAL, ALLOCATABLE :: urb_alb_rd_th(:)
REAL, ALLOCATABLE :: urb_emis_rd(:)
REAL, ALLOCATABLE :: urb_hcap_rd(:)
REAL, ALLOCATABLE :: urb_hcon_rd(:)
REAL, ALLOCATABLE :: urb_alb_wl_so(:)
REAL, ALLOCATABLE :: urb_alb_wl_th(:)
REAL, ALLOCATABLE :: urb_emis_wl(:)
REAL, ALLOCATABLE :: urb_hcap_wl(:)
REAL, ALLOCATABLE :: urb_hcon_wl(:)
CHARACTER(LEN=3) :: teb_itype_bem
LOGICAL :: teb_lbem_ac
CHARACTER(LEN=4) :: teb_itype_natvent
CHARACTER(LEN=6) :: teb_itype_bem_cool
CHARACTER(LEN=6) :: teb_itype_bem_heat
REAL, ALLOCATABLE :: teb_frac_gz(:)
REAL, ALLOCATABLE :: teb_tcool_target(:)
REAL, ALLOCATABLE :: teb_theat_target(:)
REAL, ALLOCATABLE :: teb_zresidential(:)
REAL, ALLOCATABLE :: teb_dt_res(:)
REAL, ALLOCATABLE :: teb_dt_off(:)
REAL, ALLOCATABLE :: teb_bem_inf(:)
REAL, ALLOCATABLE :: teb_bem_vent(:)
REAL, ALLOCATABLE :: teb_bem_cop(:)
REAL, ALLOCATABLE :: teb_cap_sys_rat(:)
REAL, ALLOCATABLE :: teb_m_sys_rat(:)
REAL, ALLOCATABLE :: teb_cap_sys_heat(:)
REAL, ALLOCATABLE :: ahf_traffic(:)
REAL, ALLOCATABLE :: ahf_industry(:)
REAL :: teb_fai(8)
LOGICAL :: teb_lgarden
CHARACTER(LEN=9) :: teb_type_garden
REAL, ALLOCATABLE :: urb_z0_gdn(:)
REAL, ALLOCATABLE :: urb_z0_o_z0h_gdn(:)
REAL, ALLOCATABLE :: urb_alb_gdn(:)
REAL, ALLOCATABLE :: urb_emis_gdn(:)
LOGICAL :: teb_lgreenroof
CHARACTER(LEN=9) :: teb_type_greenroof
REAL, ALLOCATABLE :: teb_frac_gr(:)
REAL, ALLOCATABLE :: urb_z0_grf(:)
REAL, ALLOCATABLE :: urb_z0_o_z0h_grf(:)
REAL, ALLOCATABLE :: urb_alb_grf(:)
REAL, ALLOCATABLE :: urb_emis_grf(:)
LOGICAL :: teb_lsolar_panel
REAL, ALLOCATABLE :: teb_fr_panel(:)
LOGICAL :: teb_lroad_irrig
REAL, ALLOCATABLE :: teb_rd_irrig_start_m(:)
REAL, ALLOCATABLE :: teb_rd_irrig_end_m(:)
REAL, ALLOCATABLE :: teb_rd_irrig_start_h(:)
REAL, ALLOCATABLE :: teb_rd_irrig_end_h(:)
REAL, ALLOCATABLE :: teb_rd_irrig_sum(:)
INTEGER :: teb_utc_hour
LOGICAL :: teb_lshade
CHARACTER(LEN=16) :: urb_zd_town
REAL :: urb_z0_rd, urb_z0_rf, urb_z0_snow
LOGICAL :: teb_lcbs_scheme
REAL :: teb_tau_hw_thresh, teb_tau_hw_width  ! Legacy &tebparam and host values.
REAL :: teb_cbs_hw_thresh, teb_cbs_hw_width
NAMELIST /tebopts/ &
  dt, &
  nvec, teb_nroof_layer, teb_nroad_layer, teb_nwall_layer, &
  teb_lbem_ac, teb_lgarden, &
  teb_lgreenroof, teb_lsolar_panel, teb_lroad_irrig, &
  teb_lshade, teb_snow_check, &
  teb_lcbs_scheme, teb_cbs_hw_thresh, teb_cbs_hw_width, &
  teb_ctype_bem, teb_ctype_natvent, teb_ctype_bem_cool, &
  teb_ctype_bem_heat, teb_ctype_wind, teb_ctype_garden, &
  teb_ctype_greenroof, teb_hroad_dir, teb_wall_opt, &
  teb_ctype_exch_rd, teb_ctype_exch_rf, teb_ctype_exch_canyon, &
  teb_ctype_z0_town, teb_ctype_z0_town_dyncorr, teb_ctype_zd_town_dyncorr, &
  teb_ctype_z0_o_z0h_rd, teb_ctype_z0_o_z0h_rf, teb_ctype_z0_o_z0h_town, &
  teb_lwrite_output, teb_lwrite_emu, teb_lwrite_runoff, &
  teb_lwrite_test_dump
NAMELIST /tebparams/ &
  urb_d_rf, urb_d_rd, urb_d_wl, &
  urb_h_bld, urb_fr_bld, &
  fr_garden, urb_h2w, teb_road_dir, &
  teb_ti_bld_init, teb_qi_bld_init, urb_alb_rf_so, &
  urb_alb_rf_th, urb_emis_rf, urb_hcap_rf, &
  urb_hcon_rf, urb_alb_rd_so, urb_alb_rd_th, &
  urb_emis_rd, urb_hcap_rd, urb_hcon_rd, &
  urb_alb_wl_so, urb_alb_wl_th, urb_emis_wl, &
  urb_hcap_wl, urb_hcon_wl, teb_frac_gz, &
  teb_tcool_target, teb_theat_target, teb_zresidential, &
  teb_dt_res, teb_dt_off, teb_bem_inf, &
  teb_bem_vent, teb_bem_cop, teb_cap_sys_rat, &
  teb_m_sys_rat, teb_cap_sys_heat, ahf_traffic, &
  ahf_industry, teb_fai, urb_z0_gdn, &
  urb_z0_o_z0h_gdn, urb_alb_gdn, urb_emis_gdn, &
  teb_frac_gr, urb_z0_grf, urb_z0_o_z0h_grf, &
  urb_alb_grf, urb_emis_grf, proxy_phu_gdn, &
  proxy_phu_grf, teb_fr_panel, teb_rd_irrig_start_m, &
  teb_rd_irrig_end_m, teb_rd_irrig_start_h, teb_rd_irrig_end_h, &
  teb_rd_irrig_sum, teb_utc_hour, urb_zd_town, &
  urb_z0_rd, urb_z0_rf, urb_z0_snow
NAMELIST /tebparam/ &
  dt, urb_h_bld, urb_fr_bld, &
  fr_garden, urb_h2w, teb_road_dir, &
  teb_hroad_dir, teb_wall_opt, teb_ti_bld_init, &
  teb_qi_bld_init, urb_alb_rf_so, urb_alb_rf_th, &
  urb_emis_rf, urb_hcap_rf, urb_hcon_rf, &
  urb_alb_rd_so, urb_alb_rd_th, urb_emis_rd, &
  urb_hcap_rd, urb_hcon_rd, urb_alb_wl_so, &
  urb_alb_wl_th, urb_emis_wl, urb_hcap_wl, &
  urb_hcon_wl, teb_itype_bem, teb_lbem_ac, &
  teb_itype_natvent, teb_itype_bem_cool, teb_itype_bem_heat, &
  teb_frac_gz, teb_tcool_target, teb_theat_target, &
  teb_zresidential, teb_dt_res, teb_dt_off, &
  teb_bem_inf, teb_bem_vent, teb_bem_cop, &
  teb_cap_sys_rat, teb_m_sys_rat, teb_cap_sys_heat, &
  ahf_traffic, ahf_industry, teb_ctype_wind, &
  teb_fai, teb_lgarden, teb_type_garden, &
  urb_z0_gdn, urb_z0_o_z0h_gdn, urb_alb_gdn, &
  urb_emis_gdn, teb_lgreenroof, teb_type_greenroof, &
  teb_frac_gr, urb_z0_grf, urb_z0_o_z0h_grf, &
  urb_alb_grf, urb_emis_grf, proxy_phu_gdn, &
  proxy_phu_grf, teb_lsolar_panel, teb_fr_panel, &
  teb_lroad_irrig, teb_rd_irrig_start_m, teb_rd_irrig_end_m, &
  teb_rd_irrig_start_h, teb_rd_irrig_end_h, teb_rd_irrig_sum, &
  teb_utc_hour, teb_lshade, urb_zd_town, &
  teb_lcbs_scheme, teb_tau_hw_thresh, &
  teb_tau_hw_width, teb_snow_check
teb_nroof_layer=5
teb_nroad_layer=5
teb_nwall_layer=5
CALL read_text(path,text)
CALL scan_group(text,'tebparam',a,found,path)
legacy=found
IF (legacy) THEN
  CALL scan_group(text,'tebopts',o,found,path)
  IF(found) CALL fail(path,'tebopts',0,'cannot mix legacy tebparam and tebopts')
  CALL scan_group(text,'tebparams',o,found,path)
  IF(found) CALL fail(path,'tebparams',0,'cannot mix legacy tebparam and tebparams')
  nvec=1
ELSE
  CALL scan_group(text,'tebopts',o,found,path)
  nvec=1
  IF(found) THEN
    DO j=1,SIZE(o)
      SELECT CASE(o(j)%name)
      CASE('nvec','teb_nroof_layer','teb_nroad_layer','teb_nwall_layer')
        CALL require_count(o(j),1,1,path)
        SELECT CASE(o(j)%name)
        CASE('nvec')
          READ(o(j)%value,*,IOSTAT=rc) nvec
        CASE('teb_nroof_layer')
          READ(o(j)%value,*,IOSTAT=rc) teb_nroof_layer
        CASE('teb_nroad_layer')
          READ(o(j)%value,*,IOSTAT=rc) teb_nroad_layer
        CASE('teb_nwall_layer')
          READ(o(j)%value,*,IOSTAT=rc) teb_nwall_layer
        END SELECT
        IF(rc/=0) CALL fail(path,o(j)%name,o(j)%line,'expected an integer')
      END SELECT
    END DO
  END IF
  CALL scan_group(text,'tebparams',a,found,path)
  IF(.NOT.found) CALL fail(path,'tebparams',0,'missing namelist group')
END IF
IF(nvec<1) CALL fail(path,'nvec',0,'must be positive')
IF(teb_nroof_layer<1) CALL fail(path,'teb_nroof_layer',0,'must be positive')
IF(teb_nroad_layer<1) CALL fail(path,'teb_nroad_layer',0,'must be positive')
IF(teb_nwall_layer<1) CALL fail(path,'teb_nwall_layer',0,'must be positive')
IF(cfg%test_mode .AND. cfg%nvec>0 .AND. cfg%nvec/=nvec) CALL fail(path,'nvec',0, &
  'differs from block_test nvec')
cfg%nvec=nvec
ALLOCATE(urb_d_rf(teb_nroof_layer),urb_d_rd(teb_nroad_layer),urb_d_wl(teb_nwall_layer))
urb_d_rf=XUNDEF
urb_d_rd=XUNDEF
urb_d_wl=XUNDEF
IF(teb_nroof_layer==5) urb_d_rf=TEB_DEFAULT_D_RF
IF(teb_nroad_layer==5) urb_d_rd=TEB_DEFAULT_D_RD
IF(teb_nwall_layer==5) urb_d_wl=TEB_DEFAULT_D_WL
ALLOCATE(urb_h_bld(nvec))
ALLOCATE(urb_fr_bld(nvec))
ALLOCATE(fr_garden(nvec))
ALLOCATE(urb_h2w(nvec))
ALLOCATE(teb_road_dir(nvec))
ALLOCATE(teb_ti_bld_init(nvec))
ALLOCATE(teb_qi_bld_init(nvec))
ALLOCATE(urb_alb_rf_so(nvec))
ALLOCATE(urb_alb_rf_th(nvec))
ALLOCATE(urb_hcap_rf(nvec))
ALLOCATE(urb_hcon_rf(nvec))
ALLOCATE(urb_alb_rd_so(nvec))
ALLOCATE(urb_alb_rd_th(nvec))
ALLOCATE(urb_hcap_rd(nvec))
ALLOCATE(urb_hcon_rd(nvec))
ALLOCATE(urb_alb_wl_so(nvec))
ALLOCATE(urb_alb_wl_th(nvec))
ALLOCATE(urb_hcap_wl(nvec))
ALLOCATE(urb_hcon_wl(nvec))
ALLOCATE(teb_frac_gz(nvec))
ALLOCATE(teb_tcool_target(nvec))
ALLOCATE(teb_theat_target(nvec))
ALLOCATE(teb_zresidential(nvec))
ALLOCATE(teb_dt_res(nvec))
ALLOCATE(teb_dt_off(nvec))
ALLOCATE(teb_bem_inf(nvec))
ALLOCATE(teb_bem_vent(nvec))
ALLOCATE(teb_bem_cop(nvec))
ALLOCATE(teb_cap_sys_rat(nvec))
ALLOCATE(teb_m_sys_rat(nvec))
ALLOCATE(teb_cap_sys_heat(nvec))
ALLOCATE(ahf_traffic(nvec))
ALLOCATE(ahf_industry(nvec))
ALLOCATE(urb_z0_gdn(nvec),urb_z0_o_z0h_gdn(nvec))
ALLOCATE(urb_alb_gdn(nvec))
ALLOCATE(urb_emis_gdn(nvec))
ALLOCATE(teb_frac_gr(nvec))
ALLOCATE(urb_z0_grf(nvec),urb_z0_o_z0h_grf(nvec))
ALLOCATE(urb_alb_grf(nvec))
ALLOCATE(urb_emis_grf(nvec))
ALLOCATE(teb_fr_panel(nvec))
ALLOCATE(teb_rd_irrig_start_m(nvec))
ALLOCATE(teb_rd_irrig_end_m(nvec))
ALLOCATE(teb_rd_irrig_start_h(nvec))
ALLOCATE(teb_rd_irrig_end_h(nvec))
ALLOCATE(teb_rd_irrig_sum(nvec))
ALLOCATE(urb_emis_rf(nvec))
ALLOCATE(urb_emis_rd(nvec))
ALLOCATE(urb_emis_wl(nvec))
dt=300.
urb_h_bld=20.
urb_fr_bld=0.62
fr_garden=0.2
urb_h2w=1.38158
teb_road_dir=0.0
teb_hroad_dir='UNIF'
teb_wall_opt='UNIF'
teb_ti_bld_init=XUNDEF
teb_qi_bld_init=XUNDEF
urb_alb_rf_so=0.40
urb_alb_rf_th=XUNDEF
urb_emis_rf=XUNDEF
urb_hcap_rf=1580000.
urb_hcon_rf=1.15
urb_alb_rd_so=0.08
urb_alb_rd_th=XUNDEF
urb_emis_rd=XUNDEF
urb_hcap_rd=1740000.
urb_hcon_rd=0.82
urb_alb_wl_so=0.32
urb_alb_wl_th=XUNDEF
urb_emis_wl=XUNDEF
urb_hcap_wl=1580000.
urb_hcon_wl=1.15
teb_itype_bem='BEM'
teb_lbem_ac=.TRUE.
teb_itype_natvent='NONE'
teb_itype_bem_cool='IDEAL '
teb_itype_bem_heat='IDEAL '
teb_frac_gz=0.1
teb_tcool_target=297.16
teb_theat_target=292.16
teb_zresidential=1.
teb_dt_res=3.
teb_dt_off=3.
teb_bem_inf=0.5
teb_bem_vent=0.0
teb_bem_cop=2.5
teb_cap_sys_rat=100.
teb_m_sys_rat=0.0067
teb_cap_sys_heat=90.
ahf_traffic=0.0
ahf_industry=0.0
teb_ctype_wind='DEF'
teb_lgarden=.TRUE.
teb_type_garden='PROXY_NEW'
urb_z0_gdn=XZ0_GD
urb_z0_o_z0h_gdn=XZ0_O_Z0H_GD
urb_alb_gdn=0.15
urb_emis_gdn=0.98
teb_lgreenroof=.FALSE.
teb_type_greenroof='PROXY_NEW'
teb_frac_gr=0.0
urb_z0_grf=XZ0_GR
urb_z0_o_z0h_grf=XZ0_O_Z0H_GR
urb_alb_grf=0.15
urb_emis_grf=0.98
proxy_phu_gdn=0.7
proxy_phu_grf=0.7
teb_lsolar_panel=.FALSE.
teb_fr_panel=0.
teb_lroad_irrig=.FALSE.
teb_rd_irrig_start_m=6.
teb_rd_irrig_end_m=8.
teb_rd_irrig_start_h=6.
teb_rd_irrig_end_h=9.
teb_rd_irrig_sum=1.
teb_utc_hour=3
teb_lshade=.TRUE.
teb_ctype_z0_town='0.1H'
teb_ctype_z0_town_dyncorr=CTEB_TOWN_DYNCORR_DEFAULT
teb_ctype_zd_town_dyncorr=CTEB_TOWN_DYNCORR_DEFAULT
urb_z0_rd=c%tz0%XROAD
urb_z0_rf=c%tz0%XROOF
urb_z0_snow=XZ0SN
urb_zd_town='H/3'
teb_lcbs_scheme=.FALSE.
teb_tau_hw_thresh=0.5
teb_tau_hw_width=0.25
teb_snow_check=.FALSE.
teb_ctype_exch_rd=CTEB_EXCH_DEFAULT
teb_ctype_exch_rf=CTEB_EXCH_DEFAULT
teb_ctype_exch_canyon=CTEB_EXCH_DEFAULT
teb_ctype_z0_o_z0h_rd='200'
teb_ctype_z0_o_z0h_rf='200'
teb_ctype_z0_o_z0h_town='200'
teb_lwrite_output=.TRUE.
teb_lwrite_emu=.TRUE.
teb_lwrite_runoff=.TRUE.
teb_lwrite_test_dump=.FALSE.
IF(legacy) THEN
  teb_lwrite_output=cfg%model_log
  teb_lwrite_test_dump=cfg%test_dump
END IF
IF(.NOT.legacy) THEN
  teb_ctype_bem=teb_itype_bem
  teb_ctype_natvent=teb_itype_natvent
  teb_ctype_bem_cool=teb_itype_bem_cool
  teb_ctype_bem_heat=teb_itype_bem_heat
  teb_ctype_garden=teb_type_garden
  teb_ctype_greenroof=teb_type_greenroof
  teb_cbs_hw_thresh=teb_tau_hw_thresh
  teb_cbs_hw_width=teb_tau_hw_width
  DO j=1,SIZE(o)
    CALL require_count(o(j),1,1,path)
    CALL check_string(o(j),path)
  END DO
  opts=build_text('tebopts',o)
  READ(opts,NML=tebopts,IOSTAT=rc,IOMSG=message)
  IF(rc/=0) CALL fail(path,'tebopts',0,TRIM(message))
  IF (.NOT. TEB_EXCH_VALID(teb_ctype_exch_rd)) &
    CALL fail(path,'teb_ctype_exch_rd',0,'expected MASC95 or DELAGE')
  IF (.NOT. TEB_EXCH_VALID(teb_ctype_exch_rf)) &
    CALL fail(path,'teb_ctype_exch_rf',0,'expected MASC95 or DELAGE')
  IF (.NOT. TEB_EXCH_VALID(teb_ctype_exch_canyon)) &
    CALL fail(path,'teb_ctype_exch_canyon',0,'expected MASC95 or DELAGE')
  CALL read_z0h_rule(path,'teb_ctype_z0_o_z0h_rd',teb_ctype_z0_o_z0h_rd,z0h%RD)
  CALL read_z0h_rule(path,'teb_ctype_z0_o_z0h_rf',teb_ctype_z0_o_z0h_rf,z0h%RF)
  CALL read_z0h_rule(path,'teb_ctype_z0_o_z0h_town',teb_ctype_z0_o_z0h_town,z0h%TOWN)
  teb_itype_bem=teb_ctype_bem
  teb_itype_natvent=teb_ctype_natvent
  teb_itype_bem_cool=teb_ctype_bem_cool
  teb_itype_bem_heat=teb_ctype_bem_heat
  teb_type_garden=teb_ctype_garden
  teb_type_greenroof=teb_ctype_greenroof
  teb_tau_hw_thresh=teb_cbs_hw_thresh
  teb_tau_hw_width=teb_cbs_hw_width
END IF
CALL TEB_PARSE_TOWN_DYNCORR(teb_ctype_z0_town_dyncorr,z0_town_dyncorr,valid_town_dyncorr)
IF (.NOT. valid_town_dyncorr) &
  CALL fail(path,'teb_ctype_z0_town_dyncorr',0,'expected OFF or ZIL2008')
CALL TEB_PARSE_TOWN_DYNCORR(teb_ctype_zd_town_dyncorr,zd_town_dyncorr,valid_town_dyncorr)
IF (.NOT. valid_town_dyncorr) &
  CALL fail(path,'teb_ctype_zd_town_dyncorr',0,'expected OFF or ZIL2008')
DO j=1,SIZE(a)
  CALL check_string(a(j),path)
  SELECT CASE(a(j)%name)
  CASE('urb_h_bld','urb_fr_bld','fr_garden','urb_h2w','teb_road_dir','teb_ti_bld_init','teb_qi_bld_init', &
       'urb_alb_rf_so','urb_alb_rf_th','urb_hcap_rf','urb_hcon_rf','urb_alb_rd_so','urb_alb_rd_th', &
       'urb_hcap_rd','urb_hcon_rd','urb_alb_wl_so','urb_alb_wl_th','urb_hcap_wl','urb_hcon_wl', &
       'teb_frac_gz','teb_tcool_target','teb_theat_target','teb_zresidential','teb_dt_res','teb_dt_off', &
       'teb_bem_inf','teb_bem_vent','teb_bem_cop','teb_cap_sys_rat','teb_m_sys_rat','teb_cap_sys_heat', &
       'ahf_traffic','ahf_industry','urb_z0_gdn','urb_alb_gdn','urb_emis_gdn','teb_frac_gr','urb_z0_grf', &
       'urb_z0_o_z0h_gdn','urb_z0_o_z0h_grf', &
       'urb_alb_grf','urb_emis_grf','teb_fr_panel','teb_rd_irrig_start_m','teb_rd_irrig_end_m', &
       'teb_rd_irrig_start_h','teb_rd_irrig_end_h','teb_rd_irrig_sum','urb_emis_rf','urb_emis_rd', &
       'urb_emis_wl')
    CALL require_count(a(j),1,nvec,path)
  CASE('teb_fai')
    CALL require_count(a(j),8,8,path)
  CASE('urb_d_rf')
    CALL require_count(a(j),teb_nroof_layer,teb_nroof_layer,path)
  CASE('urb_d_rd')
    CALL require_count(a(j),teb_nroad_layer,teb_nroad_layer,path)
  CASE('urb_d_wl')
    CALL require_count(a(j),teb_nwall_layer,teb_nwall_layer,path)
  CASE DEFAULT
    CALL require_count(a(j),1,1,path)
  END SELECT
END DO
IF(legacy) THEN
  body=build_text('tebparam',a)
  READ(body,NML=tebparam,IOSTAT=rc,IOMSG=message)
ELSE
  body=build_text('tebparams',a)
  READ(body,NML=tebparams,IOSTAT=rc,IOMSG=message)
END IF
IF(rc/=0) CALL fail(path,'parameters',0,TRIM(message))
CALL check_layer_depths(path,'urb_d_rf',urb_d_rf)
CALL check_layer_depths(path,'urb_d_rd',urb_d_rd)
CALL check_layer_depths(path,'urb_d_wl',urb_d_wl)
CALL check_z0_input(path,'urb_z0_rd',urb_z0_rd)
CALL check_z0_input(path,'urb_z0_rf',urb_z0_rf)
CALL check_z0_input(path,'urb_z0_snow',urb_z0_snow)
DO j=1,SIZE(a)
  IF(a(j)%count/=1) CYCLE
  SELECT CASE(a(j)%name)
  CASE('urb_h_bld')
    urb_h_bld=urb_h_bld(1)
  CASE('urb_fr_bld')
    urb_fr_bld=urb_fr_bld(1)
  CASE('fr_garden')
    fr_garden=fr_garden(1)
  CASE('urb_h2w')
    urb_h2w=urb_h2w(1)
  CASE('teb_road_dir')
    teb_road_dir=teb_road_dir(1)
  CASE('teb_ti_bld_init')
    teb_ti_bld_init=teb_ti_bld_init(1)
  CASE('teb_qi_bld_init')
    teb_qi_bld_init=teb_qi_bld_init(1)
  CASE('urb_alb_rf_so')
    urb_alb_rf_so=urb_alb_rf_so(1)
  CASE('urb_alb_rf_th')
    urb_alb_rf_th=urb_alb_rf_th(1)
  CASE('urb_hcap_rf')
    urb_hcap_rf=urb_hcap_rf(1)
  CASE('urb_hcon_rf')
    urb_hcon_rf=urb_hcon_rf(1)
  CASE('urb_alb_rd_so')
    urb_alb_rd_so=urb_alb_rd_so(1)
  CASE('urb_alb_rd_th')
    urb_alb_rd_th=urb_alb_rd_th(1)
  CASE('urb_hcap_rd')
    urb_hcap_rd=urb_hcap_rd(1)
  CASE('urb_hcon_rd')
    urb_hcon_rd=urb_hcon_rd(1)
  CASE('urb_alb_wl_so')
    urb_alb_wl_so=urb_alb_wl_so(1)
  CASE('urb_alb_wl_th')
    urb_alb_wl_th=urb_alb_wl_th(1)
  CASE('urb_hcap_wl')
    urb_hcap_wl=urb_hcap_wl(1)
  CASE('urb_hcon_wl')
    urb_hcon_wl=urb_hcon_wl(1)
  CASE('teb_frac_gz')
    teb_frac_gz=teb_frac_gz(1)
  CASE('teb_tcool_target')
    teb_tcool_target=teb_tcool_target(1)
  CASE('teb_theat_target')
    teb_theat_target=teb_theat_target(1)
  CASE('teb_zresidential')
    teb_zresidential=teb_zresidential(1)
  CASE('teb_dt_res')
    teb_dt_res=teb_dt_res(1)
  CASE('teb_dt_off')
    teb_dt_off=teb_dt_off(1)
  CASE('teb_bem_inf')
    teb_bem_inf=teb_bem_inf(1)
  CASE('teb_bem_vent')
    teb_bem_vent=teb_bem_vent(1)
  CASE('teb_bem_cop')
    teb_bem_cop=teb_bem_cop(1)
  CASE('teb_cap_sys_rat')
    teb_cap_sys_rat=teb_cap_sys_rat(1)
  CASE('teb_m_sys_rat')
    teb_m_sys_rat=teb_m_sys_rat(1)
  CASE('teb_cap_sys_heat')
    teb_cap_sys_heat=teb_cap_sys_heat(1)
  CASE('ahf_traffic')
    ahf_traffic=ahf_traffic(1)
  CASE('ahf_industry')
    ahf_industry=ahf_industry(1)
  CASE('urb_z0_gdn')
    urb_z0_gdn=urb_z0_gdn(1)
  CASE('urb_z0_o_z0h_gdn')
    urb_z0_o_z0h_gdn=urb_z0_o_z0h_gdn(1)
  CASE('urb_alb_gdn')
    urb_alb_gdn=urb_alb_gdn(1)
  CASE('urb_emis_gdn')
    urb_emis_gdn=urb_emis_gdn(1)
  CASE('teb_frac_gr')
    teb_frac_gr=teb_frac_gr(1)
  CASE('urb_z0_grf')
    urb_z0_grf=urb_z0_grf(1)
  CASE('urb_z0_o_z0h_grf')
    urb_z0_o_z0h_grf=urb_z0_o_z0h_grf(1)
  CASE('urb_alb_grf')
    urb_alb_grf=urb_alb_grf(1)
  CASE('urb_emis_grf')
    urb_emis_grf=urb_emis_grf(1)
  CASE('teb_fr_panel')
    teb_fr_panel=teb_fr_panel(1)
  CASE('teb_rd_irrig_start_m')
    teb_rd_irrig_start_m=teb_rd_irrig_start_m(1)
  CASE('teb_rd_irrig_end_m')
    teb_rd_irrig_end_m=teb_rd_irrig_end_m(1)
  CASE('teb_rd_irrig_start_h')
    teb_rd_irrig_start_h=teb_rd_irrig_start_h(1)
  CASE('teb_rd_irrig_end_h')
    teb_rd_irrig_end_h=teb_rd_irrig_end_h(1)
  CASE('teb_rd_irrig_sum')
    teb_rd_irrig_sum=teb_rd_irrig_sum(1)
  CASE('urb_emis_rf')
    urb_emis_rf=urb_emis_rf(1)
  CASE('urb_emis_rd')
    urb_emis_rd=urb_emis_rd(1)
  CASE('urb_emis_wl')
    urb_emis_wl=urb_emis_wl(1)
  END SELECT
END DO
IF(.NOT.ALL(IEEE_IS_FINITE(urb_h_bld))) CALL fail(path,'urb_h_bld',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_fr_bld))) CALL fail(path,'urb_fr_bld',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(fr_garden))) CALL fail(path,'fr_garden',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_h2w))) CALL fail(path,'urb_h2w',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_road_dir))) CALL fail(path,'teb_road_dir',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_ti_bld_init))) CALL fail(path,'teb_ti_bld_init',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_qi_bld_init))) CALL fail(path,'teb_qi_bld_init',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_alb_rf_so))) CALL fail(path,'urb_alb_rf_so',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_alb_rf_th))) CALL fail(path,'urb_alb_rf_th',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_hcap_rf))) CALL fail(path,'urb_hcap_rf',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_hcon_rf))) CALL fail(path,'urb_hcon_rf',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_alb_rd_so))) CALL fail(path,'urb_alb_rd_so',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_alb_rd_th))) CALL fail(path,'urb_alb_rd_th',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_hcap_rd))) CALL fail(path,'urb_hcap_rd',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_hcon_rd))) CALL fail(path,'urb_hcon_rd',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_alb_wl_so))) CALL fail(path,'urb_alb_wl_so',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_alb_wl_th))) CALL fail(path,'urb_alb_wl_th',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_hcap_wl))) CALL fail(path,'urb_hcap_wl',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_hcon_wl))) CALL fail(path,'urb_hcon_wl',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_frac_gz))) CALL fail(path,'teb_frac_gz',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_tcool_target))) CALL fail(path,'teb_tcool_target',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_theat_target))) CALL fail(path,'teb_theat_target',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_zresidential))) CALL fail(path,'teb_zresidential',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_dt_res))) CALL fail(path,'teb_dt_res',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_dt_off))) CALL fail(path,'teb_dt_off',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_bem_inf))) CALL fail(path,'teb_bem_inf',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_bem_vent))) CALL fail(path,'teb_bem_vent',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_bem_cop))) CALL fail(path,'teb_bem_cop',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_cap_sys_rat))) CALL fail(path,'teb_cap_sys_rat',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_m_sys_rat))) CALL fail(path,'teb_m_sys_rat',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_cap_sys_heat))) CALL fail(path,'teb_cap_sys_heat',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(ahf_traffic))) CALL fail(path,'ahf_traffic',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(ahf_industry))) CALL fail(path,'ahf_industry',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_z0_gdn))) CALL fail(path,'urb_z0_gdn',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_alb_gdn))) CALL fail(path,'urb_alb_gdn',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_emis_gdn))) CALL fail(path,'urb_emis_gdn',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_frac_gr))) CALL fail(path,'teb_frac_gr',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_z0_grf))) CALL fail(path,'urb_z0_grf',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_alb_grf))) CALL fail(path,'urb_alb_grf',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_emis_grf))) CALL fail(path,'urb_emis_grf',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_fr_panel))) CALL fail(path,'teb_fr_panel',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_rd_irrig_start_m))) CALL fail(path,'teb_rd_irrig_start_m',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_rd_irrig_end_m))) CALL fail(path,'teb_rd_irrig_end_m',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_rd_irrig_start_h))) CALL fail(path,'teb_rd_irrig_start_h',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_rd_irrig_end_h))) CALL fail(path,'teb_rd_irrig_end_h',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(teb_rd_irrig_sum))) CALL fail(path,'teb_rd_irrig_sum',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_emis_rf))) CALL fail(path,'urb_emis_rf',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_emis_rd))) CALL fail(path,'urb_emis_rd',0,'non-finite value')
IF(.NOT.ALL(IEEE_IS_FINITE(urb_emis_wl))) CALL fail(path,'urb_emis_wl',0,'non-finite value')
CALL resolve_emis('roof',urb_emis_rf,urb_alb_rf_th,0.03,supplied(a,'urb_emis_rf'),supplied(a,'urb_alb_rf_th'))
CALL resolve_emis('road',urb_emis_rd,urb_alb_rd_th,0.04,supplied(a,'urb_emis_rd'),supplied(a,'urb_alb_rd_th'))
CALL resolve_emis('wall',urb_emis_wl,urb_alb_wl_th,0.03,supplied(a,'urb_emis_wl'),supplied(a,'urb_alb_wl_th'))
WHERE(teb_ti_bld_init==XUNDEF) teb_ti_bld_init=teb_tcool_target
IF(ANY(teb_ti_bld_init<150. .OR. teb_ti_bld_init>350.)) CALL fail(path,'teb_ti_bld_init',0, &
  'expected 150..350 K')
IF(ANY(teb_qi_bld_init/=XUNDEF .AND. (teb_qi_bld_init<0. .OR. teb_qi_bld_init>0.2))) &
  CALL fail(path,'teb_qi_bld_init',0,'expected 0..0.2 kg/kg')
IF(dt<=0. .OR. .NOT.IEEE_IS_FINITE(dt)) CALL fail(path,'dt',0,'must be finite and positive')
IF(ANY(urb_h_bld<=0.) .OR. ANY(urb_h2w<=0.)) CALL fail(path,'urban geometry',0, &
  'height and H/W must be positive')
IF(ANY(urb_fr_bld<=0. .OR. urb_fr_bld>=1.)) CALL fail(path,'urb_fr_bld',0,'expected 0 < fraction < 1')
IF(ANY(fr_garden<0. .OR. fr_garden>1.)) CALL fail(path,'fr_garden',0,'expected 0..1')
IF(ANY(teb_frac_gr<0. .OR. teb_frac_gr>1.)) CALL fail(path,'teb_frac_gr',0,'expected 0..1')
IF(ANY(urb_z0_gdn<=0. .OR. urb_z0_gdn>=XUNDEF)) CALL fail(path,'urb_z0_gdn',0,'invalid roughness')
IF(ANY(urb_alb_gdn<0. .OR. urb_alb_gdn>=1.)) CALL fail(path,'urb_alb_gdn',0,'expected 0 <= albedo < 1')
IF(ANY(urb_emis_gdn<=0. .OR. urb_emis_gdn>1.)) CALL fail(path,'urb_emis_gdn',0,'expected 0 < emissivity <= 1')
CALL check_vegetation_ratio(path,'urb_z0_o_z0h_gdn',urb_z0_o_z0h_gdn)
IF(.NOT.IEEE_IS_FINITE(proxy_phu_gdn) .OR. proxy_phu_gdn<=0. .OR. proxy_phu_gdn>1.) &
  CALL fail(path,'proxy_phu_gdn',0,'expected finite humidity > 0 and <= 1')
IF(ANY(urb_z0_grf<=0. .OR. urb_z0_grf>=XUNDEF)) CALL fail(path,'urb_z0_grf',0,'invalid roughness')
IF(ANY(urb_alb_grf<0. .OR. urb_alb_grf>=1.)) CALL fail(path,'urb_alb_grf',0,'expected 0 <= albedo < 1')
IF(ANY(urb_emis_grf<=0. .OR. urb_emis_grf>1.)) CALL fail(path,'urb_emis_grf',0,'expected 0 < emissivity <= 1')
CALL check_vegetation_ratio(path,'urb_z0_o_z0h_grf',urb_z0_o_z0h_grf)
IF(.NOT.IEEE_IS_FINITE(proxy_phu_grf) .OR. proxy_phu_grf<=0. .OR. proxy_phu_grf>1.) &
  CALL fail(path,'proxy_phu_grf',0,'expected finite humidity > 0 and <= 1')
SELECT CASE(TRIM(teb_type_garden))
CASE('PROXY_OLD','PROXY_NEW','EXT','EXT_NEU')
CASE DEFAULT
  CALL fail(path,selector_name('teb_type_garden',legacy),0,'unknown surface scheme')
END SELECT
SELECT CASE(TRIM(teb_type_greenroof))
CASE('PROXY_OLD','PROXY_NEW','EXT','EXT_NEU')
CASE DEFAULT
  CALL fail(path,selector_name('teb_type_greenroof',legacy),0,'unknown surface scheme')
END SELECT
IF(teb_itype_bem/='BEM' .AND. teb_itype_bem/='DEF') CALL fail(path,selector_name('teb_itype_bem',legacy),0,'expected BEM or DEF')
IF(teb_ctype_wind/='DEF' .AND. teb_ctype_wind/='WANG') &
  CALL fail(path,'teb_ctype_wind',0,'expected DEF or WANG')
has_fai=supplied(a,'teb_fai')
IF(has_fai) THEN
  IF(.NOT.ALL(IEEE_IS_FINITE(teb_fai)) .OR. ANY(teb_fai<0.)) CALL fail(path,'teb_fai',0, &
    'expected finite nonnegative indices')
END IF
IF(.NOT.IEEE_IS_FINITE(teb_tau_hw_thresh) .OR. .NOT.IEEE_IS_FINITE(teb_tau_hw_width)) &
  CALL fail(path,'CBS thresholds',0,'expected finite values')
SELECT CASE(TRIM(teb_itype_natvent))
CASE('NONE','AUTO','MECH','MANU')
CASE DEFAULT
  CALL fail(path,selector_name('teb_itype_natvent',legacy),0,'unknown natural ventilation option')
END SELECT
IF(teb_itype_bem_cool/='IDEAL' .AND. teb_itype_bem_cool/='DXCOIL') &
  CALL fail(path,selector_name('teb_itype_bem_cool',legacy),0,'unknown cooling option')
IF(teb_itype_bem_heat/='IDEAL' .AND. teb_itype_bem_heat/='FINCAP') &
  CALL fail(path,selector_name('teb_itype_bem_heat',legacy),0,'unknown heating option')
cfg%dt=dt
cfg%model_log=teb_lwrite_output
cfg%write_emu=teb_lwrite_emu
cfg%write_runoff=teb_lwrite_runoff
cfg%test_dump=teb_lwrite_test_dump
! CRC32 guards restart against changed physical input, independent of its path.
cfg%parameter_signature=NOT(0_INT32)
DO j=1,LEN(text)
  cfg%parameter_signature=IEOR(cfg%parameter_signature,INT(IACHAR(text(j:j)),INT32))
  DO k=1,8
    IF(BTEST(cfg%parameter_signature,0)) THEN
      cfg%parameter_signature=IEOR(SHIFTR(cfg%parameter_signature,1),INT(Z'EDB88320',INT32))
    ELSE
      cfg%parameter_signature=SHIFTR(cfg%parameter_signature,1)
    END IF
  END DO
END DO
cfg%parameter_signature=NOT(cfg%parameter_signature)
CALL allocate_block(c,nvec,teb_nroof_layer,teb_nroad_layer,teb_nwall_layer)
c%dt=dt
c%iblock=1
c%ivstart=1
c%ivend=nvec
c%sa_uc=1.
c%teb_nroof_layer=teb_nroof_layer
c%teb_nroad_layer=teb_nroad_layer
c%teb_nwall_layer=teb_nwall_layer
c%urb_d_rf=urb_d_rf
c%urb_d_rd=urb_d_rd
c%urb_d_wl=urb_d_wl
c%teb_nfloor_layer=5
c%dt=dt
c%urb_h_bld=urb_h_bld
c%urb_fr_bld=urb_fr_bld
c%fr_garden=fr_garden
c%urb_h2w=urb_h2w
c%teb_road_dir=teb_road_dir
c%teb_hroad_dir=teb_hroad_dir
c%teb_wall_opt=teb_wall_opt
c%teb_ti_bld=teb_ti_bld_init
c%teb_qi_bld=teb_qi_bld_init
c%urb_alb_rf_so=urb_alb_rf_so
c%urb_alb_rf_th=urb_alb_rf_th
c%urb_hcap_rf=urb_hcap_rf
c%urb_hcon_rf=urb_hcon_rf
c%urb_alb_rd_so=urb_alb_rd_so
c%urb_alb_rd_th=urb_alb_rd_th
c%urb_hcap_rd=urb_hcap_rd
c%urb_hcon_rd=urb_hcon_rd
c%urb_alb_wl_so=urb_alb_wl_so
c%urb_alb_wl_th=urb_alb_wl_th
c%urb_hcap_wl=urb_hcap_wl
c%urb_hcon_wl=urb_hcon_wl
c%teb_itype_bem=teb_itype_bem
c%teb_lbem_ac=teb_lbem_ac
c%teb_itype_natvent=teb_itype_natvent
c%teb_itype_bem_cool=teb_itype_bem_cool
c%teb_itype_bem_heat=teb_itype_bem_heat
c%teb_frac_gz=teb_frac_gz
c%teb_tcool_target=teb_tcool_target
c%teb_theat_target=teb_theat_target
c%teb_zresidential=teb_zresidential
c%teb_dt_res=teb_dt_res
c%teb_dt_off=teb_dt_off
c%teb_bem_inf=teb_bem_inf
c%teb_bem_vent=teb_bem_vent
c%teb_bem_cop=teb_bem_cop
c%teb_cap_sys_rat=teb_cap_sys_rat
c%teb_m_sys_rat=teb_m_sys_rat
c%teb_cap_sys_heat=teb_cap_sys_heat
c%ahf_traffic=ahf_traffic
c%ahf_industry=ahf_industry
c%teb_ctype_wind=teb_ctype_wind
c%teb_ctype_exch_road=teb_ctype_exch_rd
c%teb_ctype_exch_roof=teb_ctype_exch_rf
c%teb_ctype_exch_canyon=teb_ctype_exch_canyon
c%teb_ctype_z0_town_dyncorr=z0_town_dyncorr
c%teb_ctype_zd_town_dyncorr=zd_town_dyncorr
c%teb_lgarden=teb_lgarden
c%teb_type_garden=teb_type_garden
c%teb_z0_gd=urb_z0_gdn
c%urb_z0_o_z0h_gdn=urb_z0_o_z0h_gdn
c%teb_alb_gd=urb_alb_gdn
c%teb_emis_gd=urb_emis_gdn
c%teb_lgreenroof=teb_lgreenroof
c%teb_type_greenroof=teb_type_greenroof
c%teb_frac_gr=teb_frac_gr
c%teb_z0_gr=urb_z0_grf
c%urb_z0_o_z0h_grf=urb_z0_o_z0h_grf
c%teb_alb_gr=urb_alb_grf
c%teb_emis_gr=urb_emis_grf
c%teb_lsolar_panel=teb_lsolar_panel
c%teb_fr_panel=teb_fr_panel
c%teb_lroad_irrig=teb_lroad_irrig
c%teb_rd_irrig_start_m=teb_rd_irrig_start_m
c%teb_rd_irrig_end_m=teb_rd_irrig_end_m
c%teb_rd_irrig_start_h=teb_rd_irrig_start_h
c%teb_rd_irrig_end_h=teb_rd_irrig_end_h
c%teb_rd_irrig_sum=teb_rd_irrig_sum
c%teb_utc_hour=teb_utc_hour
c%teb_lshade=teb_lshade
c%urb_z0_town=teb_ctype_z0_town
c%tz0h=z0h
c%tz0%XROAD=urb_z0_rd
c%tz0%XROOF=urb_z0_rf
c%tz0%XSNOW=urb_z0_snow
c%urb_zd_town=urb_zd_town
c%teb_lcbs_scheme=teb_lcbs_scheme
c%teb_tau_hw_thresh=teb_tau_hw_thresh
c%teb_tau_hw_width=teb_tau_hw_width
IF(has_fai) THEN
  DO k=1,8
    c%teb_fai(:,k)=teb_fai(k)
  END DO
ELSE
  ! Uniform canyon orientations give a mean windward projection of WAI/pi.
  DO k=1,nvec
    c%teb_fai(k,:)=TEB_WALL_AREA_INDEX(urb_h2w(k),urb_fr_bld(k))/XPI
  END DO
END IF
c%teb_lgreenroof_ext=teb_type_greenroof=='EXT' .OR. teb_type_greenroof=='EXT_NEU'
c%teb_tch_gd=XUNDEF
c%teb_tcm_gd=XUNDEF
c%teb_ustar_town=0.2
c%teb_cd_greenroof_atm=XUNDEF
! Preserve ordinary-offline external-surface initialization and its call order.
c%t=290.3
c%ps=98872.90000
c%teb_ts_gd=275.
c%teb_ts_gr=275.
c%teb_qs_gd=0.00380
c%teb_qs_gr=0.00380
IF(teb_type_garden=='EXT' .OR. teb_type_garden=='EXT_NEU') THEN
  c%teb_ts_gd=c%t
  c%teb_qs_gd=proxy_phu_gdn*QSAT(c%teb_ts_gd,c%ps)
END IF
IF(c%teb_lgreenroof_ext) THEN
  c%teb_ts_gr=c%t
  c%teb_qs_gr=proxy_phu_grf*QSAT(c%teb_ts_gr,c%ps)
END IF
END SUBROUTINE READ_OFFLINE_PARAMETERS

SUBROUTINE check_layer_depths(path,key,depths)
CHARACTER(LEN=*), INTENT(IN) :: path,key
REAL, INTENT(IN) :: depths(:)
IF(ANY(.NOT. IEEE_IS_FINITE(depths))) CALL fail(path,key,0,'layer depths must be finite')
IF(ANY(depths==XUNDEF)) CALL fail(path,key,0,'explicit profile required for this layer count')
IF(ANY(depths<=0.)) CALL fail(path,key,0,'layer depths must be positive')
END SUBROUTINE check_layer_depths

SUBROUTINE resolve_emis(label,emis,alb,default_alb,has_emis,has_alb)
CHARACTER(LEN=*),INTENT(IN)::label
REAL,INTENT(INOUT)::emis(:),alb(:)
REAL,INTENT(IN)::default_alb
LOGICAL,INTENT(IN)::has_emis,has_alb
IF(has_emis .AND. has_alb) CALL fail('parameters',label,0,'both emissivity and thermal albedo supplied')
IF(has_emis) THEN
  IF(ANY(emis<=0. .OR. emis>1.)) CALL fail('parameters',label,0,'invalid emissivity')
  alb=1.-emis
ELSE IF(has_alb) THEN
  IF(ANY(alb<0. .OR. alb>=1.)) CALL fail('parameters',label,0,'invalid thermal albedo')
  emis=1.-alb
ELSE
  alb=default_alb
  emis=1.-default_alb
END IF
END SUBROUTINE

LOGICAL FUNCTION supplied(a,name)
TYPE(NML_ASSIGNMENT),INTENT(IN)::a(:)
CHARACTER(LEN=*),INTENT(IN)::name
supplied=ANY(a%name==name)
END FUNCTION

FUNCTION selector_name(name,legacy) RESULT(key)
CHARACTER(LEN=*),INTENT(IN)::name
LOGICAL,INTENT(IN)::legacy
CHARACTER(LEN=32)::key
key=name
IF(legacy) RETURN
SELECT CASE(name)
CASE('teb_itype_bem')
  key='teb_ctype_bem'
CASE('teb_itype_natvent')
  key='teb_ctype_natvent'
CASE('teb_itype_bem_cool')
  key='teb_ctype_bem_cool'
CASE('teb_itype_bem_heat')
  key='teb_ctype_bem_heat'
CASE('teb_type_garden')
  key='teb_ctype_garden'
CASE('teb_type_greenroof')
  key='teb_ctype_greenroof'
END SELECT
END FUNCTION

SUBROUTINE check_string(a,path)
TYPE(NML_ASSIGNMENT),INTENT(IN)::a
CHARACTER(LEN=*),INTENT(IN)::path
INTEGER::limit,n,p
CHARACTER::quote
SELECT CASE(a%name)
CASE('teb_itype_bem','teb_ctype_bem')
  limit=3
CASE('teb_itype_natvent','teb_ctype_natvent','teb_ctype_wind','teb_hroad_dir','teb_wall_opt')
  limit=4
CASE('teb_itype_bem_cool','teb_itype_bem_heat','teb_ctype_bem_cool','teb_ctype_bem_heat')
  limit=6
CASE('teb_ctype_exch_rd','teb_ctype_exch_rf','teb_ctype_exch_canyon')
  limit=6
CASE('teb_type_garden','teb_type_greenroof','teb_ctype_garden','teb_ctype_greenroof')
  limit=9
CASE('teb_ctype_z0_town','teb_ctype_z0_town_dyncorr','teb_ctype_zd_town_dyncorr','urb_zd_town', &
     'teb_ctype_z0_o_z0h_rd','teb_ctype_z0_o_z0h_rf','teb_ctype_z0_o_z0h_town')
  limit=16
CASE DEFAULT
  RETURN
END SELECT
CALL require_count(a,1,1,path)
n=LEN(a%value)
quote=a%value(1:1)
IF(quote=="'" .OR. quote=='"') THEN
  n=n-2
  p=2
  DO WHILE(p<LEN(a%value))
    IF(a%value(p:p)==quote) THEN
      n=n-1
      p=p+1
    END IF
    p=p+1
  END DO
END IF
IF(n>limit) CALL fail(path,a%name,a%line,'character value exceeds supported length')
END SUBROUTINE

SUBROUTINE read_text(path,text)
USE, INTRINSIC :: ISO_FORTRAN_ENV, ONLY: IOSTAT_EOR, IOSTAT_END
CHARACTER(LEN=*),INTENT(IN)::path
CHARACTER(LEN=:),ALLOCATABLE,INTENT(OUT)::text
CHARACTER(LEN=256)::chunk
INTEGER::unit,rc,n
text=''
OPEN(NEWUNIT=unit,FILE=path,STATUS='OLD',ACTION='READ',IOSTAT=rc)
IF(rc/=0) CALL fail(path,'file',0,'cannot open namelist')
DO
  READ(unit,'(A)',ADVANCE='NO',SIZE=n,IOSTAT=rc) chunk
  IF(n>0) text=text//chunk(:n)
  IF(rc==IOSTAT_EOR) text=text//ACHAR(10)
  IF(rc==IOSTAT_END) EXIT
  IF(rc/=0 .AND. rc/=IOSTAT_EOR) CALL fail(path,'file',0,'cannot read namelist')
END DO
CLOSE(unit)
END SUBROUTINE

SUBROUTINE skip_space(text,p,line)
CHARACTER(LEN=*),INTENT(IN)::text
INTEGER,INTENT(INOUT)::p,line
DO WHILE(p<=LEN(text))
  SELECT CASE(text(p:p))
  CASE(' ',ACHAR(9),ACHAR(13))
    p=p+1
  CASE(ACHAR(10))
    p=p+1
    line=line+1
  CASE('!')
    DO WHILE(p<=LEN(text))
      IF(text(p:p)==ACHAR(10)) EXIT
      p=p+1
    END DO
  CASE DEFAULT
    EXIT
  END SELECT
END DO
END SUBROUTINE

FUNCTION lower(s) RESULT(out)
CHARACTER(LEN=*),INTENT(IN)::s
CHARACTER(LEN=LEN(s))::out
INTEGER::j,k
out=s
DO j=1,LEN(s)
  k=IACHAR(s(j:j))
  IF(k>=65 .AND. k<=90) out(j:j)=ACHAR(k+32)
END DO
END FUNCTION

LOGICAL FUNCTION name_char(c)
CHARACTER,INTENT(IN)::c
INTEGER::k
k=IACHAR(c)
name_char=(k>=65 .AND. k<=90) .OR. (k>=97 .AND. k<=122) .OR. (k>=48 .AND. k<=57) .OR. c=='_'
END FUNCTION

FUNCTION get_name(text,p) RESULT(name)
CHARACTER(LEN=*),INTENT(IN)::text
INTEGER,INTENT(INOUT)::p
CHARACTER(LEN=:),ALLOCATABLE::name
INTEGER::start
start=p
DO WHILE(p<=LEN(text))
  IF(.NOT.name_char(text(p:p))) EXIT
  p=p+1
END DO
name=lower(text(start:p-1))
END FUNCTION

FUNCTION get_value(text,p,line,path,item) RESULT(value)
CHARACTER(LEN=*),INTENT(IN)::text,path,item
INTEGER,INTENT(INOUT)::p,line
CHARACTER(LEN=:),ALLOCATABLE::value
CHARACTER::quote,c
INTEGER::start
start=p
quote=text(p:p)
IF(quote=="'" .OR. quote=='"') THEN
  p=p+1
  DO WHILE(p<=LEN(text))
    c=text(p:p)
    IF(c==ACHAR(10)) line=line+1
    IF(c==quote) THEN
      IF(p<LEN(text)) THEN
        IF(text(p+1:p+1)==quote) THEN
          p=p+2
          CYCLE
        END IF
      END IF
      p=p+1
      value=text(start:p-1)
      RETURN
    END IF
    p=p+1
  END DO
  CALL fail(path,item,line,'unterminated quoted value')
ELSE
  DO WHILE(p<=LEN(text))
    c=text(p:p)
    IF(INDEX(' ,/=*&()!'//ACHAR(9)//ACHAR(10)//ACHAR(13),c)>0) EXIT
    p=p+1
  END DO
  IF(p==start) CALL fail(path,item,line,'repetitions, indexed assignments and null values are unsupported')
  value=text(start:p-1)
END IF
END FUNCTION

SUBROUTINE scan_group(text,group,a,found,path)
CHARACTER(LEN=*),INTENT(IN)::text,group,path
TYPE(NML_ASSIGNMENT),ALLOCATABLE,INTENT(OUT)::a(:)
LOGICAL,INTENT(OUT)::found
TYPE(NML_ASSIGNMENT)::entry
CHARACTER(LEN=:),ALLOCATABLE::name,value,probe
INTEGER::p,line,q,ql,j
LOGICAL::comma,match
ALLOCATE(a(0))
found=.FALSE.
p=1
line=1
DO
  CALL skip_space(text,p,line)
  IF(p>LEN(text)) EXIT
  IF(text(p:p)/='&') CALL fail(path,group,line,'expected a namelist group')
  p=p+1
  name=get_name(text,p)
  SELECT CASE(name)
  CASE('tebopts','tebparams','tebparam','tebforcing','block_test')
  CASE DEFAULT
    CALL fail(path,name,line,'unknown namelist group')
  END SELECT
  match=name==group
  IF(match .AND. found) CALL fail(path,group,line,'duplicate namelist group')
  IF(match) found=.TRUE.
  DO
    CALL skip_space(text,p,line)
    IF(p>LEN(text)) CALL fail(path,name,line,'missing terminating slash')
    IF(text(p:p)=='/') THEN
      p=p+1
      EXIT
    END IF
    IF(.NOT.match) THEN
      ! Skip other groups with quote-aware handling of paths and H/3.
      IF(text(p:p)=="'" .OR. text(p:p)=='"') THEN
        value=get_value(text,p,line,path,name)
      ELSE
        p=p+1
      END IF
      CYCLE
    END IF
    entry%line=line
    probe=get_name(text,p)
    IF(LEN(probe)>LEN(entry%name)) CALL fail(path,group,line,'parameter name is too long')
    entry%name=probe
    IF(LEN_TRIM(entry%name)==0) CALL fail(path,group,line,'expected parameter name')
    SELECT CASE(entry%name)
    CASE('urb_z0_town')
      CALL fail(path,group,line,'urb_z0_town is deprecated. Use teb_ctype_z0_town in &tebopts.')
    CASE('teb_ctype_exch_road')
      CALL fail(path,group,line,'teb_ctype_exch_road is deprecated. Use teb_ctype_exch_rd in &tebopts.')
    CASE('teb_ctype_exch_roof')
      CALL fail(path,group,line,'teb_ctype_exch_roof is deprecated. Use teb_ctype_exch_rf in &tebopts.')
    CASE('teb_tau_hw_thresh')
      IF(group/='tebparam') &
        CALL fail(path,group,line,'teb_tau_hw_thresh is deprecated. Use teb_cbs_hw_thresh in &tebopts.')
    CASE('teb_tau_hw_width')
      IF(group/='tebparam') &
        CALL fail(path,group,line,'teb_tau_hw_width is deprecated. Use teb_cbs_hw_width in &tebopts.')
    CASE('teb_cbs_hw_thresh','teb_cbs_hw_width','teb_ctype_z0_town_dyncorr','teb_ctype_zd_town_dyncorr')
      IF(group/='tebopts') CALL fail(path,group,line,TRIM(entry%name)//' belongs in &tebopts.')
    END SELECT
    CALL skip_space(text,p,line)
    IF(p>LEN(text)) CALL fail(path,entry%name,line,'missing equals sign')
    IF(text(p:p)/='=') CALL fail(path,entry%name,line,'expected =; indexed assignments are unsupported')
    DO j=1,SIZE(a)
      IF(a(j)%name==entry%name) CALL fail(path,entry%name,line,'duplicate parameter')
    END DO
    p=p+1
    entry%value=''
    entry%count=0
    comma=.FALSE.
    DO
      CALL skip_space(text,p,line)
      IF(p>LEN(text)) CALL fail(path,entry%name,line,'missing terminating slash')
      IF(text(p:p)=='/') EXIT
      IF(text(p:p)==',') THEN
        IF(comma .OR. entry%count==0) CALL fail(path,entry%name,line,'null values are unsupported')
        comma=.TRUE.
        p=p+1
        CYCLE
      END IF
      q=p
      ql=line
      probe=get_name(text,q)
      IF(LEN(probe)>0) THEN
        CALL skip_space(text,q,ql)
        IF(q<=LEN(text)) THEN
          IF(text(q:q)=='=') EXIT
        END IF
      END IF
      value=get_value(text,p,line,path,entry%name)
      IF(entry%count>0) entry%value=entry%value//', '
      entry%value=entry%value//value
      entry%count=entry%count+1
      comma=.FALSE.
    END DO
    IF(entry%count==0) CALL fail(path,entry%name,entry%line,'missing value')
    a=[a,entry]
  END DO
END DO
END SUBROUTINE

SUBROUTINE require_count(a,one,n,path)
TYPE(NML_ASSIGNMENT),INTENT(IN)::a
INTEGER,INTENT(IN)::one,n
CHARACTER(LEN=*),INTENT(IN)::path
CHARACTER(LEN=160)::message
IF(a%count==one .OR. a%count==n) RETURN
WRITE(message,'(A,I0,A,I0,A,I0)') 'received ',a%count,' values; expected ',one,' or ',n
CALL fail(path,a%name,a%line,TRIM(message))
END SUBROUTINE

FUNCTION build_text(group,a) RESULT(text)
CHARACTER(LEN=*),INTENT(IN)::group
TYPE(NML_ASSIGNMENT),INTENT(IN)::a(:)
CHARACTER(LEN=:),ALLOCATABLE::text
INTEGER::j
text='&'//group//ACHAR(10)
DO j=1,SIZE(a)
  text=text//TRIM(a(j)%name)//'='//a(j)%value//','//ACHAR(10)
END DO
text=text//'/'//ACHAR(10)
END FUNCTION

SUBROUTINE read_z0h_rule(path,key,spec,rule)
CHARACTER(LEN=*),INTENT(IN)::path,key,spec
TYPE(TEB_Z0H_RULE_t),INTENT(OUT)::rule
LOGICAL::valid

CALL TEB_PARSE_Z0H(spec,rule,valid)
IF (.NOT.valid) CALL fail(path,key,0,'expected a finite ratio >= 1, KANDA07 or BRUT82')
END SUBROUTINE read_z0h_rule

SUBROUTINE check_vegetation_ratio(path,key,ratio)
CHARACTER(LEN=*),INTENT(IN)::path,key
REAL,INTENT(IN)::ratio(:)

IF (ALL(TEB_Z0_RATIO_VALID(ratio))) THEN
  IF (ALL(ratio < XUNDEF)) RETURN
END IF
CALL fail(path,key,0,'expected finite ratio >= 1')
END SUBROUTINE check_vegetation_ratio

SUBROUTINE check_z0_input(path,key,z0)
CHARACTER(LEN=*),INTENT(IN)::path,key
REAL,INTENT(IN)::z0
IF (IEEE_IS_FINITE(z0)) THEN
  IF (z0 > 0.) RETURN
END IF
CALL fail(path,key,0,'expected a finite positive roughness in m')
END SUBROUTINE check_z0_input

SUBROUTINE fail(path,item,line,message)
CHARACTER(LEN=*),INTENT(IN)::path,item,message
INTEGER,INTENT(IN)::line
WRITE(*,'(A,A,A,I0,A,A,A,A)') 'ERROR namelist ',TRIM(path),':',line,': ',TRIM(item),': ',TRIM(message)
ERROR STOP 1
END SUBROUTINE
END MODULE TEB_OFFLINE_NAMELISTS
