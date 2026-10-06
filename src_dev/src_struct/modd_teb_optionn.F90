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
!
!*       0.   DECLARATIONS
!             ------------
!
USE MODD_TYPE_DATE_SURF
!MV202609 garden/greenroof surface parameters (single source of truth, shared
!* with the namelist items of the offline driver)
USE MODD_PROXI_SVAT_PAR, ONLY : XZ0_O_Z0H_GD, XZ0_O_Z0H_GR
!
!
USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
USE PARKIND1  ,ONLY : JPRB
!
IMPLICIT NONE


TYPE TEB_OPTIONS_t
! TEB scheme option
!
  LOGICAL                        :: LCANOPY      ! T: SBL scheme within the canopy
                                                 ! F: no atmospheric layers below forcing level      
  LOGICAL                        :: LGARDEN      ! T: Urban green areas (call ISBA from TEB)
                                                 ! F: No urban green areas
  CHARACTER(LEN=4)               :: CROAD_DIR    ! TEB option for road directions
                                                 ! 'UNIF' : no specific direction
                                                 ! 'ORIE' : many road ORIEntations
                                                 ! ( one per TEB patch)
  CHARACTER(LEN=4)               :: CWALL_OPT    ! TEB option for walls
                                                 ! 'UNIF' : uniform walls
                                                 ! 'TWO ' : two separated walls
  CHARACTER(LEN=3)               :: CBLD_ATYPE   ! Type of averaging for walls
                                                 ! 'ARI'  : Characteristics are
                                                 !          linearly averaged
                                                 ! 'MAJ ' : Majoritary building in
                                                 !          grid mesh is chosen
  CHARACTER(LEN=6)               :: CZ0H         ! TEB option for z0h roof & road
                                                 ! 'MASC95' : Mascart et al 1995
                                                 ! 'BRUT82' : Brustaert     1982
                                                 ! 'KAND07' : Kanda         2007
  CHARACTER(LEN=5)               :: CCH_BEM      ! BEM option for roof/wall outside convective coefficient
                                                 ! 'DOE-2' : DOE-2 model from
                                                 ! EnergyPlus Engineering reference, p65
  CHARACTER(LEN=3)               :: CBEM         ! TEB option for the building energy model
                                                 ! 'DEF':  DEFault version force-restore model from Masson et al. 2002
                                                 ! 'BEM':  Building Energy Model Bueno et al. 2011

  CHARACTER(LEN=3)               :: CTREE        ! TEB option for the high vegetation
                                                 ! 'DEF':  DEFault version without radiative, dynamic effects or turbulent fluxes
                                                 ! 'RAD':  only RADiative effects 
                                                 ! 'DYN':  radiative and DYNamic effects 
                                                 ! 'FLX':  radiative, dynamic effects, and turbulent fluxes 
  LOGICAL                        :: LGREENROOF   ! T: green roofs (call ISBA from TEB)
  LOGICAL                        :: LHYDRO       ! T: urban subsoil and hydrology processes
  LOGICAL                        :: LSOLAR_PANEL ! T: solar panels on roofs
!MV202609 garden model type
! type of the garden model (namelist teb_type_garden):
!   'PROXY_OLD' : fixed Bowen-ratio proxy (the historical scheme)
!   'PROXY_NEW' : diagnostic closed surface energy balance (default)
!   'EXT'       : external garden model (fluxes provided by an external model),
!                 the diagnostic garden coefficients of URBAN_DRAG use the full
!                 URBAN_EXCH_COEF set (Richardson number, z0h)
!   'EXT_NEU'   : same external garden, but the coefficients use the neutral
!                 formulation of the internal garden (no stratification, the same
!                 thermal roughness z0h)
  CHARACTER(LEN=9)               :: CTYPE_GARDEN ! TEB option for the garden model
!MV202609 garden thermal roughness (z0h)
! Thermal (scalar) roughness of the garden: z0h = urb_z0_gdn/XZ0_O_Z0H_GD, i.e.
! the ratio z0/z0h of the namelist item urb_z0_o_z0h_gdn (>= 1, default
! XZ0_O_Z0H_GD = 4.0 of MODD_PROXI_SVAT_PAR). Heat and moisture of the garden use
! the neutral scalar coefficient PCH = kappa**2/(ln(z/z0)*ln(z/z0h)), the
! momentum keeps z0; with XZ0_O_Z0H_GD = 1 the garden is exactly the one without
! thermal roughness. It is the single source of the value used by the internal
! garden (GARDEN_CBS), by the exported coefficients of URBAN_DRAG ('EXT' and
! 'EXT_NEU') and by the emulator of the offline driver.
  REAL                           :: XZ0_O_Z0H_GD ! garden z0/z0h ratio (-)
!MV202609 greenroof model type (namelist teb_type_greenroof)
!   'PROXY_OLD' : fixed Bowen-ratio proxy (the historical scheme)
!   'PROXY_NEW' : diagnostic closed surface energy balance (default); the
!                 greenroof is a ROOF surface and exchanges only with the air of
!                 the forcing level (no canyon branch and no tau split)
  CHARACTER(LEN=9)               :: CTYPE_GREENROOF ! TEB option for the greenroof model
!MV202609 greenroof thermal roughness (z0h): same formulation as the garden,
!* ratio z0/z0h of the namelist item urb_z0_o_z0h_grf (>= 1, default XZ0_O_Z0H_GR)
  REAL                           :: XZ0_O_Z0H_GR ! greenroof z0/z0h ratio (-)

!MV202609 CBS scheme of the road
! CBS scheme for the road: the actual road fluxes are the weighted mean of the
! road/canyon and road/forcing-level fluxes, with the weights tau and 1-tau,
! tau being a tanh relaxation of the canyon H/W ratio (see CBS_TAU in
! TEB_GARDEN): tau -> 0 for very sparse building (H/W -> 0, the road exchanges
! directly with the air of the forcing level) and tau = 1 for dense canyons
! (H/W above the threshold, the road exchanges with the canyon air only).
!
  LOGICAL                        :: LCBS_SCHEME  ! T: CBS scheme activated
  REAL                           :: XTAU_HW_THRESH ! H/W giving tau = 0.5       (-)
  REAL                           :: XTAU_HW_WIDTH  ! width of the tanh relaxation (-)
! 
! type of initialization of vegetation: from cover types (ecoclimap) or parameters prescribed
!
  LOGICAL                        :: LECOCLIMAP   ! T: parameters computed from ecoclimap
!                                                ! F: they are read in the file
!
! General surface: 
!
  REAL, POINTER, DIMENSION(:)   :: XZS           ! orography                        (m)
  REAL, POINTER, DIMENSION(:,:) :: XCOVER        ! fraction of each ecosystem       (-)
  LOGICAL, POINTER, DIMENSION(:):: LCOVER        ! GCOVER(i)=T --> ith cover field is not 0.
  INTEGER                       :: NTEB_PATCH    ! number of TEB patches
  REAL, POINTER, DIMENSION(:,:) :: XTEB_PATCH    ! fraction of each TEB patch
!
! Number of layers
!
  INTEGER                       :: NROOF_LAYER   ! number of layers in roofs
  INTEGER                       :: NROAD_LAYER   ! number of layers in roads
  INTEGER                       :: NWALL_LAYER   ! number of layers in walls
!
! Date:
!
  TYPE (DATE_TIME)              :: TTIME         ! current date and time
!
! Time-step:
!
  REAL                          :: XTSTEP        ! time step for TEB
!
  REAL                          :: XOUT_TSTEP    ! TEB output writing time step
!
END TYPE TEB_OPTIONS_t



CONTAINS
!----------------------------------------------------------------------------

!




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
YTEB_OPTIONS%CCH_BEM=' '
YTEB_OPTIONS%CBEM=' '
YTEB_OPTIONS%CTREE=' '
YTEB_OPTIONS%LGREENROOF=.FALSE.
YTEB_OPTIONS%CTYPE_GARDEN='PROXY_NEW'
!MV202609 garden thermal roughness (z0h)
YTEB_OPTIONS%XZ0_O_Z0H_GD=XZ0_O_Z0H_GD
!MV202609 greenroof model type and thermal roughness
YTEB_OPTIONS%CTYPE_GREENROOF='PROXY_NEW'
YTEB_OPTIONS%XZ0_O_Z0H_GR=XZ0_O_Z0H_GR
YTEB_OPTIONS%LHYDRO=.FALSE.
YTEB_OPTIONS%LSOLAR_PANEL=.FALSE.
YTEB_OPTIONS%LCBS_SCHEME=.FALSE.
YTEB_OPTIONS%XTAU_HW_THRESH=0.5
YTEB_OPTIONS%XTAU_HW_WIDTH=0.25
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
