!SFX_LIC Diagnostic consumer of TEB/SURFEX, governed by the CeCILL-C licence.
!MV202611 Separate executable: the ordinary single-column offline is unchanged.
PROGRAM RUN_TEB_OFFLINE_BLOCK
USE TEB_OFFLINE_BLOCK_HOST, ONLY: BLOCK_CONFIG,READ_BLOCK_CONFIG,RUN_BLOCK_CASE
IMPLICIT NONE
TYPE(BLOCK_CONFIG)::cfg
CHARACTER(LEN=1024)::arg,config_path,output_dir
INTEGER::j
config_path=''
output_dir=''
j=1
DO WHILE(j<=COMMAND_ARGUMENT_COUNT())
  CALL GET_COMMAND_ARGUMENT(j,arg)
  SELECT CASE(TRIM(arg))
  CASE('-config','-output')
    IF(j==COMMAND_ARGUMENT_COUNT()) ERROR STOP 'Missing argument value'
    IF(arg=='-config') CALL GET_COMMAND_ARGUMENT(j+1,config_path)
    IF(arg=='-output') CALL GET_COMMAND_ARGUMENT(j+1,output_dir)
    j=j+2
  CASE('-help','--help')
    WRITE(*,'(A)') 'TEB_offline_block_dev -config <block_test.nml> -output <existing external directory>'
    STOP
  CASE DEFAULT
    ERROR STOP 'Unknown command argument'
  END SELECT
END DO
IF(LEN_TRIM(config_path)==0 .OR. LEN_TRIM(output_dir)==0) ERROR STOP 'Both -config and -output are required'
CALL READ_BLOCK_CONFIG(TRIM(config_path),cfg)
CALL RUN_BLOCK_CASE(cfg,TRIM(output_dir))
END PROGRAM RUN_TEB_OFFLINE_BLOCK
