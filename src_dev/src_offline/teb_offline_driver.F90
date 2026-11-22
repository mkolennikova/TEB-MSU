!SFX_LIC TEB/SURFEX interfaces are distributed under the CeCILL-C licence.
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      11/2026 -- Mikhail Varentsov (MV)
!!        Share namelists, initialization, forcing, model calls and per-cell
!!        output between ordinary and diagnostic block offline executables.
!!        Pass the run's snow-filter option on each API call and release
!!        library resources through the public finalization procedure.
!!      11/2026 -- OpenAI Codex
!!        Size serial workspaces and diagnostic records from layer options.
!-------------------------------------------------------------------------------
MODULE TEB_OFFLINE_DRIVER
USE sfc_teb, ONLY: teb_real_kind, teb_finalize, XUNDEF => teb_undef
USE TEB_OFFLINE_HOST
USE TEB_OFFLINE_NAMELISTS, ONLY: READ_OFFLINE_PARAMETERS
USE TEB_OFFLINE_OUTPUT
USE TEB_OFFLINE_SURFACES, ONLY: EXTERNAL_SURFACES
USE TEB_LOG, ONLY: TEB_LOG_INIT, TEB_LOG_SET_VERBOSE, TEB_LOG_SET_POINT_IDS
USE TEB_HOST, ONLY: TEB_HOST_FINAL
USE MODI_INI_CSTS, ONLY: INI_CSTS
USE MODD_SURF_PAR, ONLY: teb_snow_check
USE MODE_THERMOS, ONLY: QSAT
USE, INTRINSIC :: ISO_FORTRAN_ENV, ONLY: INT32
IMPLICIT NONE
PRIVATE
PUBLIC :: OFFLINE_MAIN
CONTAINS
SUBROUTINE OFFLINE_MAIN
TYPE(BLOCK_CONFIG)::cfg
CHARACTER(LEN=2048)::arg,value,param_path,forcing_path,config_path,output_path
INTEGER::j
LOGICAL::verbose
param_path=''
forcing_path=''
config_path=''
output_path=''
verbose=.FALSE.
j=1
DO WHILE(j<=COMMAND_ARGUMENT_COUNT())
  CALL GET_COMMAND_ARGUMENT(j,arg)
  SELECT CASE(TRIM(arg))
  CASE('-param_nml','-forcing_nml','-config','-output')
    IF(j==COMMAND_ARGUMENT_COUNT()) ERROR STOP 'Missing command argument value'
    CALL GET_COMMAND_ARGUMENT(j+1,value)
    SELECT CASE(TRIM(arg))
    CASE('-param_nml')
      param_path=value
    CASE('-forcing_nml')
      forcing_path=value
    CASE('-config')
      config_path=value
    CASE('-output')
      output_path=value
    END SELECT
    j=j+2
  CASE('-verbose','--verbose')
    verbose=.TRUE.
    j=j+1
  CASE('-help','--help')
    WRITE(*,'(A)') &
      'TEB offline: -param_nml <parameters.nml> -forcing_nml <forcing.nml> -output <external directory>'
    WRITE(*,'(A)') 'Optional: -config <block_test.nml> -verbose; both executables use the same driver.'
    RETURN
  CASE DEFAULT
    WRITE(*,*) 'Unknown argument: ',TRIM(arg)
    ERROR STOP 'Invalid offline command'
  END SELECT
END DO
IF(LEN_TRIM(output_path)==0) ERROR STOP 'Specify -output with an external directory'
IF(LEN_TRIM(config_path)>0) THEN
  CALL READ_BLOCK_CONFIG(TRIM(config_path),cfg)
  cfg%test_mode=.TRUE.
  cfg%test_dump=.TRUE.
ELSE
  cfg%forcing_source='FILE'
  cfg%nsteps=0
  cfg%model_log=.TRUE.
END IF
IF(LEN_TRIM(param_path)>LEN(cfg%param_nml)) ERROR STOP 'Parameter namelist path is too long'
IF(LEN_TRIM(param_path)>0) cfg%param_nml=TRIM(param_path)
IF(LEN_TRIM(cfg%param_nml)==0) THEN
  IF(cfg%test_mode) ERROR STOP 'Block tests must supply -param_nml or block_test param_nml'
  cfg%param_nml='namelist/namelist.nml'
END IF
IF(LEN_TRIM(forcing_path)>0) THEN
  IF(LEN_TRIM(forcing_path)>LEN(cfg%forcing_nml)) ERROR STOP 'Forcing namelist path is too long'
  cfg%forcing_nml=TRIM(forcing_path)
  cfg%forcing_source='FILE'
END IF
IF(cfg%forcing_source=='FILE' .AND. LEN_TRIM(cfg%forcing_nml)==0) &
  cfg%forcing_nml='namelist/namelist_forcing.nml'
cfg%verbose=verbose
CALL RUN_OFFLINE(cfg,TRIM(output_path))
END SUBROUTINE

SUBROUTINE RUN_OFFLINE(cfg,output_dir)
TYPE(BLOCK_CONFIG),INTENT(INOUT)::cfg
CHARACTER(LEN=*),INTENT(IN)::output_dir
TYPE(TEB_BLOCK)::base,single,saved
TYPE(TEB_BLOCK),ALLOCATABLE::blocks(:)
TYPE(OUTPUT_FILES)::files
REAL(teb_real_kind),ALLOCATABLE::table(:,:)
INTEGER,ALLOCATABLE::ids(:,:),log_blocks(:),log_points(:)
CHARACTER(LEN=:),ALLOCATABLE::prefix
INTEGER::b,j,k,m,nselected,cadence,rc,unit,meta_unit,step,first_step,last_step
LOGICAL::run_snow_check
CALL INI_CSTS
CALL READ_OFFLINE_PARAMETERS(TRIM(cfg%param_nml),base,cfg)
run_snow_check=teb_snow_check
IF(cfg%test_dump .AND. STORAGE_SIZE(base%t)/=64) ERROR STOP 'Block dump requires REAL64'
CALL validate(cfg)
cadence=1
IF(cfg%forcing_source=='FILE') THEN
  CALL load_file(cfg,table,cadence)
ELSE
  ALLOCATE(table(0,0))
END IF
IF(cfg%nsteps<1) ERROR STOP 'No model steps requested'
prefix=TRIM(output_dir)//'/'
CALL config_echo(prefix//'config.txt',cfg)
ALLOCATE(blocks(cfg%nblocks),ids(cfg%nvec,cfg%nblocks))
DO b=1,cfg%nblocks
  blocks(b)=base
  blocks(b)%iblock=b
  blocks(b)%ivstart=cfg%ivstart
  blocks(b)%ivend=cfg%ivend
  blocks(b)%lon_teb=cfg%lon
  blocks(b)%lat_teb=cfg%lat
  blocks(b)%hlev_teb=cfg%height
  DO j=1,cfg%nvec
    ids(j,b)=j
    IF(cfg%sample_column>0) ids(j,b)=cfg%sample_column
    IF(cfg%mask_stride>0) THEN
      IF(MOD(ids(j,b),cfg%mask_stride)==0) blocks(b)%sa_uc(j)=0.
    END IF
  END DO
  IF(cfg%reverse) CALL permute(blocks(b),ids(:,b))
END DO
IF(cfg%layout=='SERIAL') CALL allocate_block(single,1, &
  base%teb_nroof_layer,base%teb_nroad_layer,base%teb_nwall_layer)
first_step=0
IF(LEN_TRIM(cfg%restart_file)>0) CALL load_checkpoint(cfg%restart_file,cfg,first_step,blocks,ids,base)
last_step=cfg%nsteps-1
IF(cfg%stop_after>0) THEN
  IF(cfg%stop_after<=first_step .OR. cfg%stop_after>=cfg%nsteps) ERROR STOP 'Invalid stop_after'
  IF(LEN_TRIM(cfg%checkpoint_file)==0) ERROR STOP 'stop_after requires checkpoint_file'
  last_step=cfg%stop_after-1
END IF
CALL WRITE_METADATA(prefix,cfg,blocks,ids)
CALL OPEN_OFFLINE_OUTPUT(prefix,cfg,blocks,ids,files)
nselected=0
IF(cfg%model_log) THEN
  DO b=1,cfg%nblocks
    DO j=1,cfg%nvec
      IF(blocks(b)%sa_uc(j)>0.) nselected=nselected+1
    END DO
  END DO
END IF
ALLOCATE(log_blocks(nselected),log_points(nselected))
k=0
IF(cfg%model_log) THEN
  DO b=1,cfg%nblocks
    DO j=1,cfg%nvec
      IF(.NOT.(blocks(b)%sa_uc(j)>0.)) CYCLE
      k=k+1
      log_blocks(k)=b
      log_points(k)=ids(j,b)
    END DO
  END DO
END IF
DO b=1,cfg%nblocks
  blocks(b)%kteb_log_block=log_blocks
  blocks(b)%kteb_log_point=log_points
END DO
CALL TEB_LOG_INIT(prefix//'TEB_output',cadence,rc)
IF(rc/=0) ERROR STOP 'Cannot initialize model CSV output'
CALL TEB_LOG_SET_VERBOSE(cfg%verbose)
IF(cfg%test_dump) THEN
  CALL write_schema(prefix//'fields.csv',base)
  OPEN(NEWUNIT=unit,FILE=prefix//'records.bin',ACCESS='STREAM',FORM='UNFORMATTED',STATUS='REPLACE',IOSTAT=rc)
  IF(rc/=0) ERROR STOP 'Cannot create block dump'
  WRITE(unit) INT([1413825073,1,field_count(base),8],INT32)
END IF
WRITE(*,*) 'TEB offline: nvec=',cfg%nvec,' blocks=',cfg%nblocks,' model steps=',cfg%nsteps
WRITE(*,*) 'Parameter namelist: ',TRIM(cfg%param_nml)
WRITE(*,*) 'Forcing namelist: ',TRIM(cfg%forcing_nml)
WRITE(*,'(A,I4.4,A,I2.2,A,I2.2,A,I2.2,A,I2.2,A)') 'Start: ', &
  cfg%year,'-',cfg%month,'-',cfg%day,' ',cfg%hour,':',cfg%minute,' UTC'
WRITE(*,*) 'dt=',cfg%dt,' seconds; CSV cadence=',cadence,' model steps'
DO step=first_step,last_step
  DO b=1,cfg%nblocks
    IF(step==cfg%permute_step) CALL permute(blocks(b),ids(:,b))
    CALL forcing(blocks(b),cfg,step,table)
    IF(step==0) THEN
      WHERE(blocks(b)%teb_qi_bld==XUNDEF) &
        blocks(b)%teb_qi_bld=0.5*QSAT(blocks(b)%teb_ti_bld,blocks(b)%ps)
    END IF
    IF(cfg%test_mode) CALL modify(blocks(b),cfg,ids(:,b),step)
    IF(cfg%test_fault=='BROADCAST_FIRST') THEN
      saved=blocks(b)
      DO j=2,cfg%nvec
        CALL copy_column(blocks(b),j,saved,1)
      END DO
    END IF
    IF(cfg%test_dump) CALL dump(unit,blocks(b),ids(:,b),0)
    IF(cfg%fresh_work) CALL TEB_HOST_FINAL
    CALL TEB_LOG_SET_POINT_IDS(b,ids(:,b))
    IF(cfg%layout=='BLOCK') THEN
      CALL api_step(blocks(b),run_snow_check)
    ELSE
      DO j=1,cfg%nvec
        IF(.NOT.active(blocks(b),j)) CYCLE
        CALL copy_column(single,1,blocks(b),j)
        single%ivstart=1
        single%ivend=1
        CALL api_step(single,run_snow_check)
        CALL copy_result(blocks(b),j,single,1)
      END DO
    END IF
    CALL sanitize_outputs(blocks(b),ids(:,b),cfg)
    IF(cfg%test_dump) CALL dump(unit,blocks(b),ids(:,b),1)
    CALL EXTERNAL_SURFACES(blocks(b))
    CALL WRITE_OFFLINE_OUTPUT(blocks(b),ids(:,b),cadence,files)
  END DO
  IF(MOD(step+1,cadence)==0) WRITE(*,'(A,I0,A,I0)') 'Output interval ',(step+1)/cadence,' / ', &
    cfg%nsteps/cadence
END DO
IF(cfg%test_dump) CLOSE(unit)
IF(LEN_TRIM(cfg%checkpoint_file)>0) CALL save_checkpoint(cfg%checkpoint_file,cfg,last_step+1,blocks,ids)
CALL CLOSE_OFFLINE_OUTPUT(files)
CALL teb_finalize
OPEN(NEWUNIT=meta_unit,FILE=prefix//'completed.txt',STATUS='REPLACE',ACTION='WRITE',IOSTAT=rc)
IF(rc/=0) ERROR STOP 'Cannot create completion marker'
WRITE(meta_unit,*) 'BLOCK_COMPLETED',first_step,last_step,cfg%nvec,cfg%nblocks,field_count(base)
CLOSE(meta_unit)
WRITE(*,*) 'BLOCK_COMPLETED',first_step,last_step,cfg%nvec,cfg%nblocks,field_count(base)
WRITE(*,'(A,I4.4,A,I2.2,A,I2.2,A,F12.3,A)') 'End: ',blocks(1)%teb_year,'-', &
  blocks(1)%teb_month,'-',blocks(1)%teb_day,' +',blocks(1)%teb_hour_seconds(1),' seconds UTC'
WRITE(*,*) 'TEB PROGRAM ENDS CORRECTLY'
END SUBROUTINE
END MODULE TEB_OFFLINE_DRIVER
