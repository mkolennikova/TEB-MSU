!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!     ################
      MODULE MODD_BEM_n
!     ################
!
!!****  *MODD_BEM_n - declaration of parameters and option for BEM
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
!!      B. Bueno   *Meteo France*
!!
!!    MODIFICATIONS
!!    -------------
!!      Original       10/2010
!!      G. Pigeon      06/2011 add LSHAD_DAY
!!      G. Pigeon      07/2011 add LNATVENT_NIGHT
!!      G. Pigeon      08/2011 change from MODD_BLD -> MODD_BEM
!!      G. Pigeon      10/2011 add indoor relative surf. and view factors
!!      G. Pigeon      09/2012 add TRAN_WIN
!!      G. Pigeon      10/2012 add XF_WIN_WIN
!!      V. Masson      06/2013 splits module in two
!
!*       0.   DECLARATIONS
!             ------------
!
USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
USE PARKIND1  ,ONLY : JPRB
!
IMPLICIT NONE
!
!--------------------------------------------------------------------------
!
TYPE BEM_t
!* CONTRACT (checked by python_tests/container_fields_inventory.py):
!*   state - indoor air and surfaces, shading and natural ventilation flags
!*   work  - XAUX_MAX, XT_ADP (helpers of the autosize / coil calculations)
!*   param - passed as the BP argument (MODD_BEM_PARAMS_n)
! Static parameters of the building: owned by the caller and passed as BP
!
! Indoor state, workspace and ventilation / shading flags
!
  REAL, POINTER, DIMENSION(:)   :: XTI_BLD       ! building interior temperature    (K)
  REAL, POINTER, DIMENSION(:,:) :: XT_FLOOR      ! floor layer temperatures         (K)
  REAL, POINTER, DIMENSION(:,:) :: XT_MASS       ! Air cooled building internal th. mass temperature (K)
  REAL, POINTER, DIMENSION(:)   :: XT_WIN1       ! outdoor window temperature [K]
  REAL, POINTER, DIMENSION(:)   :: XT_WIN2       ! Indoor window temperature [K]
  REAL, POINTER, DIMENSION(:)   :: XQI_BLD       ! Indoor air specific humidity [kg kg-1]
  LOGICAL, POINTER, DIMENSION(:):: LSHADE        ! flag to activate shading devices -> LOGICAL in the code
  LOGICAL, POINTER, DIMENSION(:):: LSHAD_DAY     !Has shading been necessary this day ?
  LOGICAL, POINTER, DIMENSION(:):: LNATVENT_NIGHT !Has nocturnal surventilation been necessary and possible this night ?
!
! WORK VARIABLES: not prognostic, recomputed at every call
!
  REAL, POINTER, DIMENSION(:)   :: XAUX_MAX      ! Auxiliar variable for autosize calcs
  REAL, POINTER, DIMENSION(:)   :: XT_ADP        ! Apparatus dewpoint temperature of the cooling coil [K]
  REAL, POINTER, DIMENSION(:)   :: XCAP_SYS_RAT  ! Rated capacity of the cooling system [W m-2(bld)]
!                                                  ! (recalibrated by the autosize block of BEM)
  REAL, POINTER, DIMENSION(:)   :: XM_SYS_RAT    ! Rated HVAC mass flow rate [kg s-1 m-2(bld)]
!                                                  ! (recalibrated by the autosize block of BEM)
  REAL, POINTER, DIMENSION(:)   :: XALB_WIN      ! window albedo      (derived from XU_WIN/XSHGC)
  REAL, POINTER, DIMENSION(:)   :: XABS_WIN      ! window absortance  (derived)
  REAL, POINTER, DIMENSION(:)   :: XTRAN_WIN     ! window transmittance (derived)
  REAL, POINTER, DIMENSION(:)   :: XUGG_WIN      ! Window glass-to-glass U-factor (derived)
!
! RESERVED: i/o mirrors of the ventilation and shading flags. The physics uses
! LSHADE and CNATVENT (the logical and the character flags); these REAL mirrors are
! filled from driver constants and are not read anywhere in this tree.
! TODO: decide whether they are needed at all (kept for now as the SURFEX i/o
! interface).
!
  REAL,    POINTER, DIMENSION(:):: XSHADE        ! flag to activate shading devices -> REAL for i/o 0. or 1.
  REAL,    POINTER, DIMENSION(:):: XNATVENT      ! flag to describe surventilation system for i/o
!                                                  ! 0 for NONE, 1 for MANU and 2 for AUTO
!
END TYPE BEM_t
!
TYPE BEM_NP_t
  !
  TYPE(BEM_t), POINTER :: AL(:) => NULL()
  !
END TYPE BEM_NP_t
!
CONTAINS

!----------------------------------------------------------------------------
!
SUBROUTINE BEM_INIT(YBEM)
TYPE(BEM_t), INTENT(INOUT) :: YBEM
REAL(KIND=JPRB) :: ZHOOK_HANDLE
IF (LHOOK) CALL DR_HOOK("MODD_BEM_N:BEM_INIT",0,ZHOOK_HANDLE)
  NULLIFY(YBEM%XTI_BLD)
  NULLIFY(YBEM%XT_FLOOR)
  NULLIFY(YBEM%XT_MASS)
  NULLIFY(YBEM%XAUX_MAX)
  NULLIFY(YBEM%XCAP_SYS_RAT)
  NULLIFY(YBEM%XM_SYS_RAT)
  NULLIFY(YBEM%XALB_WIN)
  NULLIFY(YBEM%XABS_WIN)
  NULLIFY(YBEM%XTRAN_WIN)
  NULLIFY(YBEM%XUGG_WIN)
  NULLIFY(YBEM%XT_WIN2)
  NULLIFY(YBEM%XQI_BLD)
  NULLIFY(YBEM%XT_ADP)
  NULLIFY(YBEM%XT_WIN1)
  NULLIFY(YBEM%LSHAD_DAY)
  NULLIFY(YBEM%LNATVENT_NIGHT)
  NULLIFY(YBEM%LSHADE)
  NULLIFY(YBEM%XSHADE)
  NULLIFY(YBEM%XNATVENT)
IF (LHOOK) CALL DR_HOOK("MODD_BEM_N:BEM_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE BEM_INIT
!
SUBROUTINE BEM_NP_INIT(YNBEM,KPATCH)
TYPE(BEM_NP_t), INTENT(INOUT) :: YNBEM
INTEGER, INTENT(IN) :: KPATCH
INTEGER :: JP
REAL(KIND=JPRB) :: ZHOOK_HANDLE
IF (LHOOK) CALL DR_HOOK("MODD_BEM_N:BEM_NP_INIT",0,ZHOOK_HANDLE)
IF (.NOT.ASSOCIATED(YNBEM%AL)) THEN
  ALLOCATE(YNBEM%AL(KPATCH))
  DO JP=1,KPATCH
    CALL BEM_INIT(YNBEM%AL(JP))
  ENDDO
ELSE
  DO JP=1,KPATCH
    CALL BEM_INIT(YNBEM%AL(JP))
  ENDDO
  DEALLOCATE(YNBEM%AL)  
ENDIF 
IF (LHOOK) CALL DR_HOOK("MODD_BEM_N:BEM_NP_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE BEM_NP_INIT
!
!
END MODULE MODD_BEM_n
