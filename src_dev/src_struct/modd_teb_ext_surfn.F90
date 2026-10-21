!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt
!SFX_LIC for details. version 1.
!     ##########################
      MODULE MODD_TEB_EXT_SURF_n
!     ##########################
!
!!****  *MODD_TEB_EXT_SURF_n - external garden / greenroof surface of one sub-step
!!
!!    PURPOSE
!!    -------
!!    The state and the fluxes that the HOST computes for the external garden and
!!    the external greenroof (its own surface model, emulated by the offline
!!    driver), and that TEB reads through the 'EXT'/'EXT_NEU' interface: one
!!    container instead of the 18 individual arguments that used to run from
!!    teb_interface to TEB_GARDEN.
!!
!!      * greenroof: roughness, albedo, emissivity, radiative temperature,
!!        surface humidity, sensible and latent heat flux, evaporation, runoff;
!!      * garden: the same nine quantities.
!!
!!    The values flow from the host into TEB (the opposite of the garden
!!    conductances CH/CD, which TEB writes and the host reads: they stay outside
!!    this container). The container is filled once per sub-step by
!!    TEB_FILL_EXT of TEB_HOST before the per-cell loop and is reached as
!!    EXT%XALB_GD(icell); it is read-only on the TEB side.
!!
!!    REFERENCE
!!    ---------
!!    TEB-MSU: TEB_MSU_containers.md, section 5.11
!!
 IMPLICIT NONE
!---------------------------------------------------------------------------
!
!* Raw external-surface values, as the host provides them (one value per cell).
!* The runoff is given by the host accumulated over the sub-step and is converted
!* to a flux (kg/m2/s) by TEB_FILL_EXT, so the container carries the ready-to-use
!* flux.
!
TYPE TEB_EXT_SURF_t
  !* ---- external greenroof (host -> TEB) ----
  REAL, POINTER, DIMENSION(:) :: XZ0_GR      ! roughness length                     (m)
  REAL, POINTER, DIMENSION(:) :: XALB_GR     ! albedo                               (-)
  REAL, POINTER, DIMENSION(:) :: XEMIS_GR    ! emissivity                           (-)
  REAL, POINTER, DIMENSION(:) :: XTSRAD_GR   ! radiative surface temperature (snow free) (K)
  REAL, POINTER, DIMENSION(:) :: XQV_GR      ! surface specific humidity            (kg/kg)
  REAL, POINTER, DIMENSION(:) :: XH_GR       ! sensible heat flux                   (W/m2)
  REAL, POINTER, DIMENSION(:) :: XLE_GR      ! latent heat flux                     (W/m2)
  REAL, POINTER, DIMENSION(:) :: XEVAP_GR    ! total evaporation                    (kg/m2/s)
  REAL, POINTER, DIMENSION(:) :: XRUNOFF_GR  ! surface runoff                       (kg/m2/s)
  !* ---- external garden (host -> TEB) ----
  REAL, POINTER, DIMENSION(:) :: XZ0_GD      ! roughness length                     (m)
  REAL, POINTER, DIMENSION(:) :: XALB_GD     ! albedo                               (-)
  REAL, POINTER, DIMENSION(:) :: XEMIS_GD    ! emissivity                           (-)
  REAL, POINTER, DIMENSION(:) :: XTSRAD_GD   ! radiative surface temperature (snow free) (K)
  REAL, POINTER, DIMENSION(:) :: XQV_GD      ! surface specific humidity            (kg/kg)
  REAL, POINTER, DIMENSION(:) :: XH_GD       ! sensible heat flux                   (W/m2)
  REAL, POINTER, DIMENSION(:) :: XLE_GD      ! latent heat flux                     (W/m2)
  REAL, POINTER, DIMENSION(:) :: XEVAP_GD    ! total evaporation                    (kg/m2/s)
  REAL, POINTER, DIMENSION(:) :: XRUNOFF_GD  ! surface runoff                       (kg/m2/s)
END TYPE TEB_EXT_SURF_t
!
!---------------------------------------------------------------------------
!
CONTAINS
!
!===========================================================================
!*       1.   Lifecycle of the container
!===========================================================================
!
SUBROUTINE TEB_EXT_SURF_INIT (YTEB_EXT_SURF)
!!****  *TEB_EXT_SURF_INIT* - NULLIFY every field of the external-surface container
TYPE(TEB_EXT_SURF_t), INTENT(INOUT) :: YTEB_EXT_SURF
!
NULLIFY(YTEB_EXT_SURF%XZ0_GR)
NULLIFY(YTEB_EXT_SURF%XALB_GR)
NULLIFY(YTEB_EXT_SURF%XEMIS_GR)
NULLIFY(YTEB_EXT_SURF%XTSRAD_GR)
NULLIFY(YTEB_EXT_SURF%XQV_GR)
NULLIFY(YTEB_EXT_SURF%XH_GR)
NULLIFY(YTEB_EXT_SURF%XLE_GR)
NULLIFY(YTEB_EXT_SURF%XEVAP_GR)
NULLIFY(YTEB_EXT_SURF%XRUNOFF_GR)
NULLIFY(YTEB_EXT_SURF%XZ0_GD)
NULLIFY(YTEB_EXT_SURF%XALB_GD)
NULLIFY(YTEB_EXT_SURF%XEMIS_GD)
NULLIFY(YTEB_EXT_SURF%XTSRAD_GD)
NULLIFY(YTEB_EXT_SURF%XQV_GD)
NULLIFY(YTEB_EXT_SURF%XH_GD)
NULLIFY(YTEB_EXT_SURF%XLE_GD)
NULLIFY(YTEB_EXT_SURF%XEVAP_GD)
NULLIFY(YTEB_EXT_SURF%XRUNOFF_GD)
!
END SUBROUTINE TEB_EXT_SURF_INIT
!
!===========================================================================
SUBROUTINE ALLOC_TEB_EXT_SURF (YTEB_EXT_SURF, KB)
!!****  *ALLOC_TEB_EXT_SURF* - allocate every field of the external-surface container
TYPE(TEB_EXT_SURF_t), INTENT(INOUT) :: YTEB_EXT_SURF
INTEGER,              INTENT(IN)    :: KB   ! number of points
!
CALL TEB_EXT_SURF_INIT(YTEB_EXT_SURF)
!
ALLOCATE(YTEB_EXT_SURF%XZ0_GR(KB))
ALLOCATE(YTEB_EXT_SURF%XALB_GR(KB))
ALLOCATE(YTEB_EXT_SURF%XEMIS_GR(KB))
ALLOCATE(YTEB_EXT_SURF%XTSRAD_GR(KB))
ALLOCATE(YTEB_EXT_SURF%XQV_GR(KB))
ALLOCATE(YTEB_EXT_SURF%XH_GR(KB))
ALLOCATE(YTEB_EXT_SURF%XLE_GR(KB))
ALLOCATE(YTEB_EXT_SURF%XEVAP_GR(KB))
ALLOCATE(YTEB_EXT_SURF%XRUNOFF_GR(KB))
ALLOCATE(YTEB_EXT_SURF%XZ0_GD(KB))
ALLOCATE(YTEB_EXT_SURF%XALB_GD(KB))
ALLOCATE(YTEB_EXT_SURF%XEMIS_GD(KB))
ALLOCATE(YTEB_EXT_SURF%XTSRAD_GD(KB))
ALLOCATE(YTEB_EXT_SURF%XQV_GD(KB))
ALLOCATE(YTEB_EXT_SURF%XH_GD(KB))
ALLOCATE(YTEB_EXT_SURF%XLE_GD(KB))
ALLOCATE(YTEB_EXT_SURF%XEVAP_GD(KB))
ALLOCATE(YTEB_EXT_SURF%XRUNOFF_GD(KB))
!
END SUBROUTINE ALLOC_TEB_EXT_SURF
!
!===========================================================================
SUBROUTINE DEALLOC_TEB_EXT_SURF (YTEB_EXT_SURF)
!!****  *DEALLOC_TEB_EXT_SURF* - release every field of the external-surface container
TYPE(TEB_EXT_SURF_t), INTENT(INOUT) :: YTEB_EXT_SURF
!
DEALLOCATE(YTEB_EXT_SURF%XZ0_GR)
DEALLOCATE(YTEB_EXT_SURF%XALB_GR)
DEALLOCATE(YTEB_EXT_SURF%XEMIS_GR)
DEALLOCATE(YTEB_EXT_SURF%XTSRAD_GR)
DEALLOCATE(YTEB_EXT_SURF%XQV_GR)
DEALLOCATE(YTEB_EXT_SURF%XH_GR)
DEALLOCATE(YTEB_EXT_SURF%XLE_GR)
DEALLOCATE(YTEB_EXT_SURF%XEVAP_GR)
DEALLOCATE(YTEB_EXT_SURF%XRUNOFF_GR)
DEALLOCATE(YTEB_EXT_SURF%XZ0_GD)
DEALLOCATE(YTEB_EXT_SURF%XALB_GD)
DEALLOCATE(YTEB_EXT_SURF%XEMIS_GD)
DEALLOCATE(YTEB_EXT_SURF%XTSRAD_GD)
DEALLOCATE(YTEB_EXT_SURF%XQV_GD)
DEALLOCATE(YTEB_EXT_SURF%XH_GD)
DEALLOCATE(YTEB_EXT_SURF%XLE_GD)
DEALLOCATE(YTEB_EXT_SURF%XEVAP_GD)
DEALLOCATE(YTEB_EXT_SURF%XRUNOFF_GD)
!
END SUBROUTINE DEALLOC_TEB_EXT_SURF
!
END MODULE MODD_TEB_EXT_SURF_n
