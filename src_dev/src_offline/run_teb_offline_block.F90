!SFX_LIC Diagnostic consumer of TEB/SURFEX, governed by the CeCILL-C licence.
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      11/2026 -- Mikhail Varentsov (MV)
!!        Create the runtime-sized diagnostic block-driver entry point linked
!!        against the common TEB library.
!!        Use the shared scalar/block offline driver and namelist contract.
!!------------------------------------------------------------------------------
PROGRAM run_teb_offline_block
USE TEB_OFFLINE_DRIVER, ONLY: OFFLINE_MAIN
IMPLICIT NONE
CALL OFFLINE_MAIN
END PROGRAM run_teb_offline_block
