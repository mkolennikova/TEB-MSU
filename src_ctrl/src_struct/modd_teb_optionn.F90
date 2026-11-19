!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!     ################
      MODULE MODD_TEB_OPTION_n
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
!!      V. Masson       06/2013         splits module
!!      TEB-MSU development
!!      11/2026 -- OpenAI Codex
!!        Configure reference road, roof and canyon exchange independently.
!!      11/2026 -- OpenAI Codex
!!        Configure thermal roughness independently of the exchange algorithm.
!
!*       0.   DECLARATIONS
!             ------------
!
USE MODD_TYPE_DATE_SURF
!
!
USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
USE PARKIND1  ,ONLY : JPRB
!
IMPLICIT NONE

CHARACTER(LEN=6), PARAMETER :: CTEB_EXCH_DEFAULT = 'MASC95'

TYPE TEB_Z0H_RULE_t
  CHARACTER(LEN=6) :: CFORM = ''  ! Empty selects the caller's legacy CZ0H.
  REAL :: XRATIO = 200.
END TYPE TEB_Z0H_RULE_t

TYPE TEB_Z0H_t
  TYPE(TEB_Z0H_RULE_t) :: RD, RF, TOWN
END TYPE TEB_Z0H_t

TYPE(TEB_Z0H_t), SAVE :: TZ0H_OFFLINE

TYPE TEB_OPTIONS_t
! TEB scheme option
!
  LOGICAL                        :: LCANOPY     ! T: SBL scheme within the canopy
                                                ! F: no atmospheric layers below forcing level      
  LOGICAL                        :: LGARDEN     ! T: Urban green areas (call ISBA from TEB)
                                                ! F: No urban green areas
  CHARACTER(LEN=4)               :: CROAD_DIR   ! TEB option for road directions
                                                ! 'UNIF' : no specific direction
                                                ! 'ORIE' : many road ORIEntations
                                                ! ( one per TEB patch)
  CHARACTER(LEN=4)               :: CWALL_OPT   ! TEB option for walls
                                                ! 'UNIF' : uniform walls
                                                ! 'TWO ' : two separated walls
  CHARACTER(LEN=3)               :: CBLD_ATYPE  ! Type of averaging for walls
                                                ! 'ARI'  : Characteristics are
                                                !          linearly averaged
                                                ! 'MAJ ' : Majoritary building in
                                                !          grid mesh is chosen
  CHARACTER(LEN=6)               :: CZ0H        ! TEB option for z0h roof & road
                                                ! 'MASC95' : Mascart et al 1995
                                                ! 'BRUT82' : Brustaert     1982
                                                ! 'KAND07' : Kanda         2007
  ! Blank keeps the legacy algorithm for callers that set CZ0H directly.
  CHARACTER(LEN=6)               :: CEXCH_ROAD = ''
  CHARACTER(LEN=6)               :: CEXCH_ROOF = ''
  CHARACTER(LEN=6)               :: CEXCH_CANYON = ''
  TYPE(TEB_Z0H_t)                :: TZ0H
  CHARACTER(LEN=5)               :: CCH_BEM     ! BEM option for roof/wall outside convective coefficient
                                                ! 'DOE-2' : DOE-2 model from
                                                ! EnergyPlus Engineering reference, p65
  CHARACTER(LEN=3)               :: CBEM        ! TEB option for the building energy model
                                                ! 'DEF':  DEFault version force-restore model from Masson et al. 2002
                                                ! 'BEM':  Building Energy Model Bueno et al. 2011

  CHARACTER(LEN=3)               :: CTREE         ! TEB option for the high vegetation
                                                  ! 'DEF':  DEFault version without radiative, dynamic effects or turbulent fluxes
                                                  ! 'RAD':  only RADiative effects 
                                                  ! 'DYN':  radiative and DYNamic effects 
                                                  ! 'FLX':  radiative, dynamic effects, and turbulent fluxes 
  LOGICAL                        :: LGREENROOF    ! T: green roofs (call ISBA from TEB)
  LOGICAL                        :: LHYDRO        ! T: urban subsoil and hydrology processes
  LOGICAL                        :: LSOLAR_PANEL  ! T: solar panels on roofs
! 
! type of initialization of vegetation: from cover types (ecoclimap) or parameters prescribed
!
  LOGICAL                        :: LECOCLIMAP  ! T: parameters computed from ecoclimap
!                                                ! F: they are read in the file
!
! General surface: 
!
  REAL, POINTER, DIMENSION(:)   :: XZS         ! orography                        (m)
  REAL, POINTER, DIMENSION(:,:) :: XCOVER      ! fraction of each ecosystem       (-)
  LOGICAL, POINTER, DIMENSION(:):: LCOVER      ! GCOVER(i)=T --> ith cover field is not 0.
  INTEGER                       :: NTEB_PATCH  ! number of TEB patches
  REAL, POINTER, DIMENSION(:,:) :: XTEB_PATCH  ! fraction of each TEB patch
!
! Number of layers
!
  INTEGER                       :: NROOF_LAYER  ! number of layers in roofs
  INTEGER                       :: NROAD_LAYER  ! number of layers in roads
  INTEGER                       :: NWALL_LAYER  ! number of layers in walls
!
! Date:
!
  TYPE (DATE_TIME)              :: TTIME  ! current date and time
!
! Time-step:
!
  REAL                          :: XTSTEP  ! time step for TEB
!
  REAL                          :: XOUT_TSTEP  ! TEB output writing time step
!
END TYPE TEB_OPTIONS_t



CONTAINS
!----------------------------------------------------------------------------

!




ELEMENTAL LOGICAL FUNCTION TEB_Z0_RATIO_VALID(PRATIO)
USE, INTRINSIC :: IEEE_ARITHMETIC, ONLY : IEEE_IS_FINITE
REAL, INTENT(IN) :: PRATIO

TEB_Z0_RATIO_VALID = .FALSE.
IF (IEEE_IS_FINITE(PRATIO)) TEB_Z0_RATIO_VALID = PRATIO >= 1.
END FUNCTION TEB_Z0_RATIO_VALID

SUBROUTINE TEB_PARSE_Z0H(HSPEC, YRULE, OVALID)
CHARACTER(LEN=*), INTENT(IN) :: HSPEC
TYPE(TEB_Z0H_RULE_t), INTENT(OUT) :: YRULE
LOGICAL, INTENT(OUT) :: OVALID
CHARACTER(LEN=LEN(HSPEC)) :: CSPEC
REAL :: ZRATIO
INTEGER :: IOS

OVALID = .FALSE.
CSPEC = ADJUSTL(HSPEC)
SELECT CASE (CSPEC)
CASE ('KANDA07')
  YRULE%CFORM = 'KAND07'
CASE ('BRUT82')
  YRULE%CFORM = 'BRUT82'
CASE DEFAULT
  ! Accept one numeric literal. List-directed READ alone ignores extra tokens.
  IF (VERIFY(TRIM(CSPEC),'0123456789+-.eEdD') /= 0) RETURN
  IF (SCAN(CSPEC,'0123456789') == 0) RETURN
  READ(CSPEC,*,IOSTAT=IOS) ZRATIO
  IF (IOS /= 0) RETURN
  IF (.NOT. TEB_Z0_RATIO_VALID(ZRATIO)) RETURN
  YRULE%XRATIO = ZRATIO
  YRULE%CFORM = 'MASC95'  ! Fixed-ratio branch of URBAN_EXCH_COEF.
END SELECT
OVALID = .TRUE.
END SUBROUTINE TEB_PARSE_Z0H

PURE LOGICAL FUNCTION TEB_EXCH_VALID(HEXCH)
CHARACTER(LEN=*), INTENT(IN) :: HEXCH
TEB_EXCH_VALID = HEXCH == CTEB_EXCH_DEFAULT .OR. HEXCH == 'DELAGE'
END FUNCTION TEB_EXCH_VALID

FUNCTION TEB_EXCH_METHOD(HEXCH, HKEY) RESULT(CMETHOD)
CHARACTER(LEN=*), INTENT(IN), OPTIONAL :: HEXCH
CHARACTER(LEN=*), INTENT(IN) :: HKEY
CHARACTER(LEN=6) :: CMETHOD

CMETHOD = CTEB_EXCH_DEFAULT
IF (PRESENT(HEXCH)) THEN
  IF (.NOT. TEB_EXCH_VALID(HEXCH)) &
    ERROR STOP 'Invalid '//HKEY//': expected MASC95 or DELAGE'
  CMETHOD = HEXCH
END IF
END FUNCTION TEB_EXCH_METHOD

SUBROUTINE TEB_OPTIONS_INIT(YTEB_OPTIONS)
TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: YTEB_OPTIONS
REAL(KIND=JPRB) :: ZHOOK_HANDLE
IF (LHOOK) CALL DR_HOOK("MODD_TEB_N:TEB_OPTIONS_INIT",0,ZHOOK_HANDLE)
NULLIFY(YTEB_OPTIONS%XZS)
NULLIFY(YTEB_OPTIONS%XCOVER)
NULLIFY(YTEB_OPTIONS%LCOVER)
NULLIFY(YTEB_OPTIONS%XTEB_PATCH)
YTEB_OPTIONS%LCANOPY=.FALSE.
YTEB_OPTIONS%LGARDEN=.FALSE.
YTEB_OPTIONS%CROAD_DIR=' '
YTEB_OPTIONS%CWALL_OPT=' '
YTEB_OPTIONS%CBLD_ATYPE=' '
YTEB_OPTIONS%CZ0H=' '
YTEB_OPTIONS%CEXCH_ROAD=''
YTEB_OPTIONS%CEXCH_ROOF=''
YTEB_OPTIONS%CEXCH_CANYON=''
YTEB_OPTIONS%TZ0H=TEB_Z0H_t()
YTEB_OPTIONS%CCH_BEM=' '
YTEB_OPTIONS%CBEM=' '
YTEB_OPTIONS%CTREE=' '
YTEB_OPTIONS%LGREENROOF=.FALSE.
YTEB_OPTIONS%LHYDRO=.FALSE.
YTEB_OPTIONS%LSOLAR_PANEL=.FALSE.
YTEB_OPTIONS%LECOCLIMAP=.FALSE.
YTEB_OPTIONS%NTEB_PATCH=0
YTEB_OPTIONS%NROOF_LAYER=0
YTEB_OPTIONS%NROAD_LAYER=0
YTEB_OPTIONS%NWALL_LAYER=0
YTEB_OPTIONS%XTSTEP=0.
YTEB_OPTIONS%XOUT_TSTEP=0.
IF (LHOOK) CALL DR_HOOK("MODD_TEB_N:TEB_OPTIONS_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE TEB_OPTIONS_INIT


!----------------------------------------------------------------------------
END MODULE MODD_TEB_OPTION_n
