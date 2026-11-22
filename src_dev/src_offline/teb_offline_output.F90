!SFX_LIC TEB/SURFEX interfaces are distributed under the CeCILL-C licence.
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      09/2026 -- Mikhail Varentsov (MV)
!!        Write external-emulator and interval-mean runoff diagnostics.
!!      11/2026 -- Mikhail Varentsov (MV)
!!        Share per-cell CSV and metadata, retaining interval state on restart.
!!      11/2026 -- OpenAI Codex
!!        Include configured layer counts and depths in parameter metadata.
!-------------------------------------------------------------------------------
MODULE TEB_OFFLINE_OUTPUT
USE TEB_OFFLINE_HOST, ONLY: TEB_BLOCK, BLOCK_CONFIG, active
USE MODD_PROXI_SVAT_PAR, ONLY: proxy_phu_gdn, proxy_phu_grf
USE MODD_SURF_PAR, ONLY: teb_snow_check
IMPLICIT NONE
PRIVATE
PUBLIC :: OUTPUT_FILES, OPEN_OFFLINE_OUTPUT, WRITE_OFFLINE_OUTPUT, CLOSE_OFFLINE_OUTPUT, WRITE_METADATA
CHARACTER,PARAMETER::out_sep=';'
TYPE OUTPUT_FILES
  INTEGER,ALLOCATABLE::emu(:,:),runoff(:,:)
  LOGICAL,ALLOCATABLE::emu_header(:,:),runoff_header(:,:)
END TYPE
CONTAINS
FUNCTION point_path(prefix,kind,b,id,single) RESULT(path)
CHARACTER(LEN=*),INTENT(IN)::prefix,kind
INTEGER,INTENT(IN)::b,id
LOGICAL,INTENT(IN)::single
CHARACTER(LEN=:),ALLOCATABLE::path
CHARACTER(LEN=32)::cb,ci
WRITE(cb,'(I0)') b
WRITE(ci,'(I0)') id
path=prefix//'TEB_'//kind
IF(.NOT.single) path=path//'_b'//TRIM(cb)//'_c'//TRIM(ci)
path=path//'.csv'
END FUNCTION

SUBROUTINE OPEN_OFFLINE_OUTPUT(prefix,cfg,blocks,ids,files)
CHARACTER(LEN=*),INTENT(IN)::prefix
TYPE(BLOCK_CONFIG),INTENT(IN)::cfg
TYPE(TEB_BLOCK),INTENT(IN)::blocks(:)
INTEGER,INTENT(IN)::ids(:,:)
TYPE(OUTPUT_FILES),INTENT(OUT)::files
INTEGER::b,j,id,n,rc
CHARACTER(LEN=:),ALLOCATABLE::path
LOGICAL::single
n=MAXVAL(ids)
ALLOCATE(files%emu(n,SIZE(blocks)),files%runoff(n,SIZE(blocks)))
ALLOCATE(files%emu_header(n,SIZE(blocks)),files%runoff_header(n,SIZE(blocks)))
files%emu=0
files%runoff=0
files%emu_header=.FALSE.
files%runoff_header=.FALSE.
single=cfg%nvec==1 .AND. cfg%nblocks==1
DO b=1,SIZE(blocks)
  DO j=1,blocks(b)%nvec
    IF(.NOT.(blocks(b)%sa_uc(j)>0.)) CYCLE
    id=ids(j,b)
    IF(cfg%write_emu) THEN
      path=point_path(prefix,'emu',b,id,single)
      OPEN(NEWUNIT=files%emu(id,b),FILE=path,STATUS='REPLACE',ACTION='WRITE',IOSTAT=rc)
      IF(rc/=0) THEN
        WRITE(*,*) 'Cannot create ',path
        ERROR STOP 'Offline emulator output failed'
      END IF
    END IF
    IF(cfg%write_runoff) THEN
      path=point_path(prefix,'runoff',b,id,single)
      OPEN(NEWUNIT=files%runoff(id,b),FILE=path,STATUS='REPLACE',ACTION='WRITE',IOSTAT=rc)
      IF(rc/=0) THEN
        WRITE(*,*) 'Cannot create ',path
        ERROR STOP 'Offline runoff output failed'
      END IF
    END IF
  END DO
END DO
END SUBROUTINE

SUBROUTINE WRITE_OFFLINE_OUTPUT(c,ids,cadence,files)
TYPE(TEB_BLOCK),INTENT(INOUT)::c
INTEGER,INTENT(IN)::ids(:),cadence
TYPE(OUTPUT_FILES),INTENT(INOUT)::files
CHARACTER(LEN=4096)::emu_hdr,emu_line,runoff_hdr,runoff_line
CHARACTER(LEN=32)::time_buf
CHARACTER(LEN=24)::emu_names(64),runoff_names(8)
INTEGER::j,b,id,emu_ncol,runoff_ncol,rc
DO j=1,c%nvec
  IF(.NOT.active(c,j)) CYCLE
  c%runoff_road_acc(j)=c%runoff_road_acc(j)+c%teb_runoff_road(j)
  c%runoff_roof_acc(j)=c%runoff_roof_acc(j)+c%teb_runoff_roof(j)
END DO
c%output_count=c%output_count+1
IF(MOD(c%ntstep+1,cadence)/=0) RETURN
WRITE(time_buf,'(I4.4,"-",I2.2,"-",I2.2," ",I2.2,":",I2.2,":",I2.2)') &
  c%teb_year,c%teb_month,c%teb_day,INT(c%teb_hour_seconds(1)/3600.), &
  INT(MOD(c%teb_hour_seconds(1),3600.)/60.),INT(MOD(c%teb_hour_seconds(1),60.))
b=c%iblock
DO j=1,c%nvec
  IF(.NOT.active(c,j)) CYCLE
  id=ids(j)
  emu_ncol=0
  emu_hdr='time'
  emu_line=TRIM(time_buf)
  IF(c%teb_type_garden=='EXT' .OR. c%teb_type_garden=='EXT_NEU') THEN
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_TAU',c%emu_tau(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_CD_EFF',c%emu_cd_eff(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_CH_EFF',c%emu_ch_eff(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_CH_NAIVE',c%emu_ch_naive(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_V',c%emu_v_star(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_T',c%emu_t_star(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_Q',c%emu_q_star(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_CA_CAN',c%emu_ca_can(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_CA_EFF',c%emu_ca_eff(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_TS',c%emu_ts(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_H',c%emu_h(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_LE',c%emu_le(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_EVAP',c%emu_evap(j))
  END IF
  IF(c%teb_lgreenroof_ext) THEN
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_CD',c%emu_gr_cd(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_CH',c%emu_gr_ch(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_CA',c%emu_gr_ca(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_V',c%emu_gr_v(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_T',c%emu_gr_t(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_Q',c%emu_gr_q(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_PSW',c%emu_gr_psw(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_PLW',c%emu_gr_plw(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_TS',c%emu_gr_ts(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_RN',c%emu_gr_rn(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_H',c%emu_gr_h(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_LE',c%emu_gr_le(j))
    CALL CSV_ADD(emu_hdr,emu_line,emu_ncol,emu_names,'EMU_GR_EVAP',c%emu_gr_evap(j))
  END IF
  IF(files%emu(id,b)/=0 .AND. emu_ncol>0) THEN
    IF(.NOT.files%emu_header(id,b)) THEN
      WRITE(files%emu(id,b),'(A)',IOSTAT=rc) TRIM(emu_hdr)
      CALL check_write(rc)
      files%emu_header(id,b)=.TRUE.
    END IF
    WRITE(files%emu(id,b),'(A)',IOSTAT=rc) TRIM(emu_line)
    CALL check_write(rc)
  END IF
  IF(files%runoff(id,b)/=0) THEN
    runoff_ncol=0
    runoff_hdr='time'
    runoff_line=TRIM(time_buf)
    CALL CSV_ADD(runoff_hdr,runoff_line,runoff_ncol,runoff_names,'RUNOFF_ROAD', &
                 c%runoff_road_acc(j)/c%output_count)
    CALL CSV_ADD(runoff_hdr,runoff_line,runoff_ncol,runoff_names,'RUNOFF_ROOF', &
                 c%runoff_roof_acc(j)/c%output_count)
    IF(.NOT.files%runoff_header(id,b)) THEN
      WRITE(files%runoff(id,b),'(A)',IOSTAT=rc) TRIM(runoff_hdr)
      CALL check_write(rc)
      files%runoff_header(id,b)=.TRUE.
    END IF
    WRITE(files%runoff(id,b),'(A)',IOSTAT=rc) TRIM(runoff_line)
    CALL check_write(rc)
  END IF
END DO
c%runoff_road_acc=0.
c%runoff_roof_acc=0.
c%output_count=0
END SUBROUTINE

SUBROUTINE check_write(rc)
INTEGER,INTENT(IN)::rc
IF(rc/=0) ERROR STOP 'Offline CSV write failed'
END SUBROUTINE

SUBROUTINE CLOSE_OFFLINE_OUTPUT(files)
TYPE(OUTPUT_FILES),INTENT(INOUT)::files
INTEGER::b,j,rc
DO b=1,SIZE(files%emu,2)
  DO j=1,SIZE(files%emu,1)
    IF(files%emu(j,b)/=0) THEN
      CLOSE(files%emu(j,b),IOSTAT=rc)
      CALL check_write(rc)
    END IF
    IF(files%runoff(j,b)/=0) THEN
      CLOSE(files%runoff(j,b),IOSTAT=rc)
      CALL check_write(rc)
    END IF
  END DO
END DO
END SUBROUTINE

SUBROUTINE WRITE_METADATA(prefix,cfg,blocks,ids)
CHARACTER(LEN=*),INTENT(IN)::prefix
TYPE(BLOCK_CONFIG),INTENT(IN)::cfg
TYPE(TEB_BLOCK),INTENT(IN)::blocks(:)
INTEGER,INTENT(IN)::ids(:,:)
INTEGER::unit,rc,b,j,k
OPEN(NEWUNIT=unit,FILE=prefix//'cells.csv',STATUS='REPLACE',ACTION='WRITE',IOSTAT=rc)
CALL check_write(rc)
WRITE(unit,'(A)') 'block;cell;position;active'
DO b=1,SIZE(blocks)
  DO j=1,blocks(b)%nvec
    WRITE(unit,'(I0,A,I0,A,I0,A,L1)') b,';',ids(j,b),';',j,';',active(blocks(b),j)
  END DO
END DO
CLOSE(unit)
OPEN(NEWUNIT=unit,FILE=prefix//'parameters.csv',STATUS='REPLACE',ACTION='WRITE',IOSTAT=rc)
CALL check_write(rc)
WRITE(unit,'(A)') 'block;cell;parameter;value'
DO b=1,SIZE(blocks)
  DO j=1,blocks(b)%nvec
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';dt;',blocks(b)%dt
    WRITE(unit,'(I0,A,I0,A,I0)') b,';',ids(j,b),';teb_nroof_layer;',blocks(b)%teb_nroof_layer
    WRITE(unit,'(I0,A,I0,A,I0)') b,';',ids(j,b),';teb_nroad_layer;',blocks(b)%teb_nroad_layer
    WRITE(unit,'(I0,A,I0,A,I0)') b,';',ids(j,b),';teb_nwall_layer;',blocks(b)%teb_nwall_layer
    DO k=1,blocks(b)%teb_nroof_layer
      WRITE(unit,'(I0,A,I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_d_rf[',k,'];',blocks(b)%urb_d_rf(k)
    END DO
    DO k=1,blocks(b)%teb_nroad_layer
      WRITE(unit,'(I0,A,I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_d_rd[',k,'];',blocks(b)%urb_d_rd(k)
    END DO
    DO k=1,blocks(b)%teb_nwall_layer
      WRITE(unit,'(I0,A,I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_d_wl[',k,'];',blocks(b)%urb_d_wl(k)
    END DO
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_h_bld;',blocks(b)%urb_h_bld(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_fr_bld;',blocks(b)%urb_fr_bld(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';fr_garden;',blocks(b)%fr_garden(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_h2w;',blocks(b)%urb_h2w(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_road_dir;',blocks(b)%teb_road_dir(j)
    WRITE(unit,'(I0,A,I0,A,A)') b,';',ids(j,b),';teb_hroad_dir;',blocks(b)%teb_hroad_dir
    WRITE(unit,'(I0,A,I0,A,A)') b,';',ids(j,b),';teb_wall_opt;',blocks(b)%teb_wall_opt
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_ti_bld_init;',blocks(b)%teb_ti_bld(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_qi_bld_init;',blocks(b)%teb_qi_bld(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_alb_rf_so;',blocks(b)%urb_alb_rf_so(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_alb_rf_th;',blocks(b)%urb_alb_rf_th(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_emis_rf;',1.-blocks(b)%urb_alb_rf_th(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_hcap_rf;',blocks(b)%urb_hcap_rf(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_hcon_rf;',blocks(b)%urb_hcon_rf(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_alb_rd_so;',blocks(b)%urb_alb_rd_so(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_alb_rd_th;',blocks(b)%urb_alb_rd_th(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_emis_rd;',1.-blocks(b)%urb_alb_rd_th(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_hcap_rd;',blocks(b)%urb_hcap_rd(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_hcon_rd;',blocks(b)%urb_hcon_rd(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_alb_wl_so;',blocks(b)%urb_alb_wl_so(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_alb_wl_th;',blocks(b)%urb_alb_wl_th(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_emis_wl;',1.-blocks(b)%urb_alb_wl_th(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_hcap_wl;',blocks(b)%urb_hcap_wl(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_hcon_wl;',blocks(b)%urb_hcon_wl(j)
    WRITE(unit,'(I0,A,I0,A,A)') b,';',ids(j,b),';teb_itype_bem;',blocks(b)%teb_itype_bem
    WRITE(unit,'(I0,A,I0,A,L1)') b,';',ids(j,b),';teb_lbem_ac;',blocks(b)%teb_lbem_ac
    WRITE(unit,'(I0,A,I0,A,A)') b,';',ids(j,b),';teb_itype_natvent;',blocks(b)%teb_itype_natvent
    WRITE(unit,'(I0,A,I0,A,A)') b,';',ids(j,b),';teb_itype_bem_cool;',blocks(b)%teb_itype_bem_cool
    WRITE(unit,'(I0,A,I0,A,A)') b,';',ids(j,b),';teb_itype_bem_heat;',blocks(b)%teb_itype_bem_heat
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_frac_gz;',blocks(b)%teb_frac_gz(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_tcool_target;',blocks(b)%teb_tcool_target(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_theat_target;',blocks(b)%teb_theat_target(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_zresidential;',blocks(b)%teb_zresidential(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_dt_res;',blocks(b)%teb_dt_res(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_dt_off;',blocks(b)%teb_dt_off(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_bem_inf;',blocks(b)%teb_bem_inf(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_bem_vent;',blocks(b)%teb_bem_vent(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_bem_cop;',blocks(b)%teb_bem_cop(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_cap_sys_rat;',blocks(b)%teb_cap_sys_rat(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_m_sys_rat;',blocks(b)%teb_m_sys_rat(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_cap_sys_heat;',blocks(b)%teb_cap_sys_heat(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';ahf_traffic;',blocks(b)%ahf_traffic(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';ahf_industry;',blocks(b)%ahf_industry(j)
    WRITE(unit,'(I0,A,I0,A,I0)') b,';',ids(j,b),';teb_itype_wind;',blocks(b)%teb_itype_wind
    DO k=1,8
      WRITE(unit,'(I0,A,I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_fai_',k,';',blocks(b)%teb_fai(j,k)
    END DO
    WRITE(unit,'(I0,A,I0,A,L1)') b,';',ids(j,b),';teb_lgarden;',blocks(b)%teb_lgarden
    WRITE(unit,'(I0,A,I0,A,A)') b,';',ids(j,b),';teb_type_garden;',blocks(b)%teb_type_garden
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_z0_gdn;',blocks(b)%teb_z0_gd(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_z0_o_z0h_gdn;',blocks(b)%urb_z0_o_z0h_gdn(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_alb_gdn;',blocks(b)%teb_alb_gd(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_emis_gdn;',blocks(b)%teb_emis_gd(j)
    WRITE(unit,'(I0,A,I0,A,L1)') b,';',ids(j,b),';teb_lgreenroof;',blocks(b)%teb_lgreenroof
    WRITE(unit,'(I0,A,I0,A,A)') b,';',ids(j,b),';teb_type_greenroof;',blocks(b)%teb_type_greenroof
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_frac_gr;',blocks(b)%teb_frac_gr(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_z0_grf;',blocks(b)%teb_z0_gr(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_z0_o_z0h_grf;',blocks(b)%urb_z0_o_z0h_grf(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_alb_grf;',blocks(b)%teb_alb_gr(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';urb_emis_grf;',blocks(b)%teb_emis_gr(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';proxy_phu_gdn;',proxy_phu_gdn
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';proxy_phu_grf;',proxy_phu_grf
    WRITE(unit,'(I0,A,I0,A,L1)') b,';',ids(j,b),';teb_lsolar_panel;',blocks(b)%teb_lsolar_panel
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_fr_panel;',blocks(b)%teb_fr_panel(j)
    WRITE(unit,'(I0,A,I0,A,L1)') b,';',ids(j,b),';teb_lroad_irrig;',blocks(b)%teb_lroad_irrig
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_rd_irrig_start_m;', &
      blocks(b)%teb_rd_irrig_start_m(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_rd_irrig_end_m;',blocks(b)%teb_rd_irrig_end_m(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_rd_irrig_start_h;', &
      blocks(b)%teb_rd_irrig_start_h(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_rd_irrig_end_h;',blocks(b)%teb_rd_irrig_end_h(j)
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_rd_irrig_sum;',blocks(b)%teb_rd_irrig_sum(j)
    WRITE(unit,'(I0,A,I0,A,I0)') b,';',ids(j,b),';teb_utc_hour;',blocks(b)%teb_utc_hour
    WRITE(unit,'(I0,A,I0,A,L1)') b,';',ids(j,b),';teb_lshade;',blocks(b)%teb_lshade
    WRITE(unit,'(I0,A,I0,A,A)') b,';',ids(j,b),';urb_z0_town;',blocks(b)%urb_z0_town
    WRITE(unit,'(I0,A,I0,A,A)') b,';',ids(j,b),';urb_zd_town;',blocks(b)%urb_zd_town
    WRITE(unit,'(I0,A,I0,A,L1)') b,';',ids(j,b),';teb_lcbs_scheme;',blocks(b)%teb_lcbs_scheme
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_tau_hw_thresh;',blocks(b)%teb_tau_hw_thresh
    WRITE(unit,'(I0,A,I0,A,ES26.17E3)') b,';',ids(j,b),';teb_tau_hw_width;',blocks(b)%teb_tau_hw_width
    WRITE(unit,'(I0,A,I0,A,L1)') b,';',ids(j,b),';teb_snow_check;',teb_snow_check
  END DO
END DO
CLOSE(unit)
END SUBROUTINE
SUBROUTINE CSV_ADD(header, line, ncol, names, name, value)
!* One call defines a column completely - the name goes to the header line, the
!* value goes to the data row - so the two cannot drift apart (the earlier code
!* kept two parallel lists, the names and the CALL CSV_APPEND sequence, that had
!* to be kept in the same order by hand). The header line is written once, just
!* before the first data row, from the same calls.
!* HOST COPY: it serves only the files the host owns (TEB_emu.csv and
!* TEB_runoff.csv). The per-cell TEB_output_b*.csv files are written by TEB
!* itself through the separate copy of the writer in TEB_LOG:CSV_ADD.
CHARACTER(LEN=*), INTENT(INOUT) :: header               ! header line being built
CHARACTER(LEN=*), INTENT(INOUT) :: line                 ! data row being built
INTEGER, INTENT(INOUT) :: ncol                          ! number of columns registered so far
CHARACTER(LEN=*), DIMENSION(:), INTENT(INOUT) :: names  ! column names (1:ncol)
CHARACTER(LEN=*), INTENT(IN) :: name                    ! name of this column
REAL, INTENT(IN) :: value                               ! value of this column
INTEGER :: l
ncol = ncol + 1
IF (ncol > SIZE(names)) THEN
  WRITE(*,*) 'ERROR RUN_TEB_OFFLINE: too many output columns: ', ncol, &
    ' > nout_max = ', SIZE(names)
  WRITE(*,*) 'Increase nout_max in RUN_TEB_OFFLINE.'
  STOP 1
END IF
names(ncol) = name
l = LEN_TRIM(header)
IF (l + 1 + LEN_TRIM(name) > LEN(header)) THEN
  WRITE(*,*) 'ERROR: header line is too long, increase the size of hdr_line'
  STOP 1
END IF
header(l+1:l+1) = out_sep
header(l+2:) = TRIM(name)
CALL CSV_APPEND(line, value)
END SUBROUTINE CSV_ADD
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
END MODULE TEB_OFFLINE_OUTPUT
