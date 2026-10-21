!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!     ################
      MODULE MODD_TEB_n
!     ################
!
!!****  *MODD_TEB_n - declaration of surface parameters for urban surface
!!
!!    PURPOSE
!!    -------
!     Declaration of surface parameters
!
!!
!!**  IMPLICIT ARGUMENTS
!!    ------------------
!!      None 
!!
!!    REFERENCE
!!    ---------
!!
!!    AUTHOR
!!    ------
!!      V. Masson   *Meteo France*
!!
!!    MODIFICATIONS
!!    -------------
!!      Original       01/2004
!!      A. Lemonsu      07/2012         Key for urban hydrology
!!      V. Masson       06/2013         splits module in two
!
!*       0.   DECLARATIONS
!             ------------
!
USE MODD_TYPE_SNOW
USE MODD_TYPE_DATE_SURF
!
!
USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
USE PARKIND1  ,ONLY : JPRB
!
IMPLICIT NONE
!--------------------------------------------------------------------------

TYPE TEB_t
!* CONTRACT (checked by python_tests/container_fields_inventory.py):
!*   state    - prognostic state carried across sub-steps (XWS_*, XT_ROOF/ROAD/WALL_*,
!*              TSNOW_ROOF/ROAD, XT_CANYON, XQ_CANYON)
!*   reserved - TSNOW_GARDEN (garden snow is not used in TEB-MSU)
!*   param, flux - passed as the TPARAMS argument (MODD_TEB_PARAMS_n)
! TEB scheme option
!
! Prognostic variables:
!
  REAL, POINTER, DIMENSION(:)   :: XWS_ROOF      ! roof water reservoir             (kg/m2)
  REAL, POINTER, DIMENSION(:)   :: XWS_ROAD      ! road water reservoir             (kg/m2)
  REAL, POINTER, DIMENSION(:,:) :: XT_ROOF       ! roof layer temperatures          (K)
  REAL, POINTER, DIMENSION(:,:) :: XT_ROAD       ! road layer temperatures          (K)
  REAL, POINTER, DIMENSION(:,:) :: XT_WALL_A     ! wall layer temperatures          (K)
  REAL, POINTER, DIMENSION(:,:) :: XT_WALL_B     ! wall layer temperatures          (K)
!
! Semi-prognostic variables:
!
  REAL, POINTER, DIMENSION(:)   :: XT_CANYON     ! canyon air temperature           (K)
  REAL, POINTER, DIMENSION(:)   :: XQ_CANYON     ! canyon air specific humidity     (kg/kg)
!
!
! Prognostic snow:
!
  TYPE(SURF_SNOW)                 :: TSNOW_ROOF      ! snow state on roofs: 
!                                                  ! scheme type/option               (-)
!                                                  ! number of layers                 (-)
!                                                  ! snow (& liq. water) content      (kg/m2)
!                                                  ! heat content                     (J/m2)
!                                                  ! temperature                      (K)
!                                                  ! density                          (kg m-3)
  TYPE(SURF_SNOW)                 :: TSNOW_ROAD      ! snow state on roads: 
!                                                  ! scheme type/option               (-)
!                                                  ! number of layers                 (-)
!                                                  ! snow (& liq. water) content      (kg/m2)
!                                                  ! heat content                     (J/m2)
!                                                  ! temperature                      (K)
!                                                  ! density                          (kg m-3)
!                                                  ! density                          (kg m-3)
  TYPE(SURF_SNOW)                 :: TSNOW_GARDEN    ! snow state on green areas:
!                                                  ! scheme type/option               (-)
!                                                  ! number of layers                 (-)
!                                                  ! snow (& liq. water) content      (kg/m2)
!                                                  ! heat content                     (J/m2)
!                                                  ! temperature                      (K)
!                                                  ! density                          (kg m-3)
!
END TYPE TEB_t

TYPE TEB_NP_t
  !
  TYPE(TEB_t), POINTER :: AL(:) => NULL()
  !
END TYPE TEB_NP_t
!
CONTAINS
!----------------------------------------------------------------------------
!
SUBROUTINE TEB_INIT(YTEB)
TYPE(TEB_t), INTENT(INOUT) :: YTEB
REAL(KIND=JPRB) :: ZHOOK_HANDLE
IF (LHOOK) CALL DR_HOOK("MODD_TEB_N:TEB_INIT",0,ZHOOK_HANDLE)
  NULLIFY(YTEB%XWS_ROOF)
  NULLIFY(YTEB%XWS_ROAD)
  NULLIFY(YTEB%XT_ROOF)
  NULLIFY(YTEB%XT_ROAD)
  NULLIFY(YTEB%XT_WALL_A)
  NULLIFY(YTEB%XT_WALL_B)
  NULLIFY(YTEB%XT_CANYON)
  NULLIFY(YTEB%XQ_CANYON)
IF (LHOOK) CALL DR_HOOK("MODD_TEB_N:TEB_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE TEB_INIT
!
SUBROUTINE TEB_NP_INIT(YNTEB,KPATCH)
TYPE(TEB_NP_t), INTENT(INOUT) :: YNTEB
INTEGER, INTENT(IN) :: KPATCH
INTEGER :: JP
REAL(KIND=JPRB) :: ZHOOK_HANDLE
IF (LHOOK) CALL DR_HOOK("MODD_TEB_N:TEB_NP_INIT",0,ZHOOK_HANDLE)
IF (.NOT.ASSOCIATED(YNTEB%AL)) THEN
  ALLOCATE(YNTEB%AL(KPATCH))
  DO JP=1,KPATCH
    CALL TEB_INIT(YNTEB%AL(JP))
  ENDDO
ELSE
  DO JP=1,KPATCH
    CALL TEB_INIT(YNTEB%AL(JP))
  ENDDO
  DEALLOCATE(YNTEB%AL)        
ENDIF
IF (LHOOK) CALL DR_HOOK("MODD_TEB_N:TEB_NP_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE TEB_NP_INIT


END MODULE MODD_TEB_n
