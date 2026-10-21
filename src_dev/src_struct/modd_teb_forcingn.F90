!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt
!SFX_LIC for details. version 1.
!     #######################
      MODULE MODD_TEB_FORCING_n
!     #######################
!
!!****  *MODD_TEB_FORCING_n - atmospheric forcing of one sub-step
!!
!!    PURPOSE
!!    -------
!!    The forcing that TEB receives from the host, as an explicit container: it
!!    used to be the global workspace of the SURFEX module MODD_FORC_ATM, which
!!    both CALL_DRIVER and the CSV writer read behind the argument lists.
!!
!!      * raw forcing, as received from the host: wind, temperature, humidity,
!!        pressure, precipitation, radiation, the heights of the forcing levels
!!        and the CO2 concentration;
!!      * derived quantities, computed once per sub-step by TEB_FILL_FORCING of
!!        TEB_HOST: the pressure and the Exner functions at the forcing level,
!!        the air density, the wind speed, the solar time and the sun position,
!!        and the direct/diffuse partition of the circumsolar model.
!!
!!    The container is filled for the window KSTART:KEND before the per-cell
!!    loop of TEB_INTERFACE (TEB_FILL_FORCING) and reached as FORC%XTA(icell)
!!    all the way down to TEB_GARDEN. It is NOT the forcing state of the host:
!!    the SURFEX reader (OL_TIME_INTERP_ATM of the offline driver) keeps
!!    MODD_FORC_ATM for its own interpolation.
!!
!!    REFERENCE
!!    ---------
!!    TEB-MSU: TEB_MSU_containers.md, section 5.10
!!
 IMPLICIT NONE
!---------------------------------------------------------------------------
!
!* Raw forcing: one value per cell, as the host provides it. XDIR_SW/XSCA_SW are
!* the direct/diffuse components AFTER the circumsolar partition (the values TEB
!* consumes), not the raw swdir_s/swdifd_s of the host.
!* Derived forcing: computed by TEB_FILL_FORCING, never by the physics.
!* XQA is the SPECIFIC humidity in kg/kg (the qv of the host, the PQA of the
!* physics); it must not be confused with MODD_FORC_ATM%XQA, the absolute
!* humidity in kg/m3 used by the reader of the offline driver.
!
TYPE TEB_FORCING_t
  !* ---- raw forcing ----
  REAL, POINTER, DIMENSION(:)   :: XU        ! zonal wind                                 (m/s)
  REAL, POINTER, DIMENSION(:)   :: XV        ! meridional wind                            (m/s)
  REAL, POINTER, DIMENSION(:)   :: XTA       ! air temperature                            (K)
  REAL, POINTER, DIMENSION(:)   :: XQA       ! specific humidity                          (kg/kg)
  REAL, POINTER, DIMENSION(:)   :: XPS       ! surface pressure                           (Pa)
  REAL, POINTER, DIMENSION(:)   :: XZS       ! orography (fallback of XPS; 0 in offline)  (m)
  REAL, POINTER, DIMENSION(:)   :: XRAIN     ! liquid precipitation                       (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XSNOW     ! solid precipitation, graupel included      (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XLW       ! downward longwave radiation                (W/m2)
  REAL, POINTER, DIMENSION(:,:) :: XDIR_SW   ! direct shortwave, circumsolar partition    (W/m2)
  REAL, POINTER, DIMENSION(:,:) :: XSCA_SW   ! diffuse shortwave, circumsolar partition   (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XZREF     ! height of the temperature/humidity forcing (m)
  REAL, POINTER, DIMENSION(:)   :: XUREF     ! height of the wind forcing                 (m)
  REAL, POINTER, DIMENSION(:)   :: XCO2      ! CO2 concentration                          (kg/kg)
  !* ---- derived once per sub-step ----
  REAL, POINTER, DIMENSION(:)   :: XPA       ! pressure at the forcing level              (Pa)
  REAL, POINTER, DIMENSION(:)   :: XEXNS     ! Exner function at the surface              (-)
  REAL, POINTER, DIMENSION(:)   :: XEXNA     ! Exner function at the forcing level        (-)
  REAL, POINTER, DIMENSION(:)   :: XRHOA     ! air density at the forcing level           (kg/m3)
  REAL, POINTER, DIMENSION(:)   :: XVMOD     ! wind speed at the forcing level            (m/s)
  REAL, POINTER, DIMENSION(:)   :: XTSUN     ! solar time                                 (s)
  REAL, POINTER, DIMENSION(:)   :: XZENITH   ! solar zenithal angle                       (rad)
  REAL, POINTER, DIMENSION(:)   :: XAZIM     ! solar azimuthal angle                      (rad)
END TYPE TEB_FORCING_t
!
!---------------------------------------------------------------------------
!
CONTAINS
!
!===========================================================================
!*       1.   Lifecycle of the container
!===========================================================================
!
SUBROUTINE TEB_FORCING_INIT (YTEB_FORCING)
!!****  *TEB_FORCING_INIT* - NULLIFY every field of the forcing container
TYPE(TEB_FORCING_t), INTENT(INOUT) :: YTEB_FORCING
!
NULLIFY(YTEB_FORCING%XU)
NULLIFY(YTEB_FORCING%XV)
NULLIFY(YTEB_FORCING%XTA)
NULLIFY(YTEB_FORCING%XQA)
NULLIFY(YTEB_FORCING%XPS)
NULLIFY(YTEB_FORCING%XZS)
NULLIFY(YTEB_FORCING%XRAIN)
NULLIFY(YTEB_FORCING%XSNOW)
NULLIFY(YTEB_FORCING%XLW)
NULLIFY(YTEB_FORCING%XDIR_SW)
NULLIFY(YTEB_FORCING%XSCA_SW)
NULLIFY(YTEB_FORCING%XZREF)
NULLIFY(YTEB_FORCING%XUREF)
NULLIFY(YTEB_FORCING%XCO2)
NULLIFY(YTEB_FORCING%XPA)
NULLIFY(YTEB_FORCING%XEXNS)
NULLIFY(YTEB_FORCING%XEXNA)
NULLIFY(YTEB_FORCING%XRHOA)
NULLIFY(YTEB_FORCING%XVMOD)
NULLIFY(YTEB_FORCING%XTSUN)
NULLIFY(YTEB_FORCING%XZENITH)
NULLIFY(YTEB_FORCING%XAZIM)
!
END SUBROUTINE TEB_FORCING_INIT
!
!===========================================================================
SUBROUTINE ALLOC_TEB_FORCING (YTEB_FORCING, KB)
!!****  *ALLOC_TEB_FORCING* - allocate every field of the forcing container
!!    KB is the number of points; the second dimension of the shortwave fields
!!    is the single spectral band of TEB (KSW = 1).
!
TYPE(TEB_FORCING_t), INTENT(INOUT) :: YTEB_FORCING
INTEGER,             INTENT(IN)    :: KB
!
CALL TEB_FORCING_INIT(YTEB_FORCING)
!
ALLOCATE(YTEB_FORCING%XU(KB))
ALLOCATE(YTEB_FORCING%XV(KB))
ALLOCATE(YTEB_FORCING%XTA(KB))
ALLOCATE(YTEB_FORCING%XQA(KB))
ALLOCATE(YTEB_FORCING%XPS(KB))
ALLOCATE(YTEB_FORCING%XZS(KB))
ALLOCATE(YTEB_FORCING%XRAIN(KB))
ALLOCATE(YTEB_FORCING%XSNOW(KB))
ALLOCATE(YTEB_FORCING%XLW(KB))
ALLOCATE(YTEB_FORCING%XDIR_SW(KB,1))
ALLOCATE(YTEB_FORCING%XSCA_SW(KB,1))
ALLOCATE(YTEB_FORCING%XZREF(KB))
ALLOCATE(YTEB_FORCING%XUREF(KB))
ALLOCATE(YTEB_FORCING%XCO2(KB))
ALLOCATE(YTEB_FORCING%XPA(KB))
ALLOCATE(YTEB_FORCING%XEXNS(KB))
ALLOCATE(YTEB_FORCING%XEXNA(KB))
ALLOCATE(YTEB_FORCING%XRHOA(KB))
ALLOCATE(YTEB_FORCING%XVMOD(KB))
ALLOCATE(YTEB_FORCING%XTSUN(KB))
ALLOCATE(YTEB_FORCING%XZENITH(KB))
ALLOCATE(YTEB_FORCING%XAZIM(KB))
!
END SUBROUTINE ALLOC_TEB_FORCING
!
!===========================================================================
SUBROUTINE DEALLOC_TEB_FORCING (YTEB_FORCING)
!!****  *DEALLOC_TEB_FORCING* - release every field of the forcing container
TYPE(TEB_FORCING_t), INTENT(INOUT) :: YTEB_FORCING
!
DEALLOCATE(YTEB_FORCING%XU)
DEALLOCATE(YTEB_FORCING%XV)
DEALLOCATE(YTEB_FORCING%XTA)
DEALLOCATE(YTEB_FORCING%XQA)
DEALLOCATE(YTEB_FORCING%XPS)
DEALLOCATE(YTEB_FORCING%XZS)
DEALLOCATE(YTEB_FORCING%XRAIN)
DEALLOCATE(YTEB_FORCING%XSNOW)
DEALLOCATE(YTEB_FORCING%XLW)
DEALLOCATE(YTEB_FORCING%XDIR_SW)
DEALLOCATE(YTEB_FORCING%XSCA_SW)
DEALLOCATE(YTEB_FORCING%XZREF)
DEALLOCATE(YTEB_FORCING%XUREF)
DEALLOCATE(YTEB_FORCING%XCO2)
DEALLOCATE(YTEB_FORCING%XPA)
DEALLOCATE(YTEB_FORCING%XEXNS)
DEALLOCATE(YTEB_FORCING%XEXNA)
DEALLOCATE(YTEB_FORCING%XRHOA)
DEALLOCATE(YTEB_FORCING%XVMOD)
DEALLOCATE(YTEB_FORCING%XTSUN)
DEALLOCATE(YTEB_FORCING%XZENITH)
DEALLOCATE(YTEB_FORCING%XAZIM)
!
END SUBROUTINE DEALLOC_TEB_FORCING
!
END MODULE MODD_TEB_FORCING_n
