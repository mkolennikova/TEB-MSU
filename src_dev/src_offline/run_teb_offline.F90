!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      Pre-repository -- Maria Tarasova (MT)
!!        Extract a standalone host for the COSMO-style TEB interface, with
!!        namelist configuration and atmospheric forcing.
!!      09/2026 -- Mikhail Varentsov (MV)
!!        Add forcing-aware CSV output, strict namelist input and emulators of
!!        external diagnostic garden/greenroof surfaces.
!!      10/2026 -- Mikhail Varentsov (MV)
!!        Support explicit cold-start inputs and host-managed state transfer
!!        through the container-based API.
!!      11/2026 -- Mikhail Varentsov (MV)
!!        Separate the offline host from the common TEB library and link it
!!        against libteb.a.
!!        Use the shared scalar/block offline driver and namelist contract.
!!------------------------------------------------------------------------------
PROGRAM run_teb_offline
USE TEB_OFFLINE_DRIVER, ONLY: OFFLINE_MAIN
IMPLICIT NONE
CALL OFFLINE_MAIN
END PROGRAM run_teb_offline
