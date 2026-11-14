!auto_modi:spll_teb_garden.D
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      Pre-repository -- Maria Tarasova (MT)
!!        Extend the explicit TEB_GARDEN interface for the inherited
!!        host-coupling implementation.
!!      09-10/2026 -- Mikhail Varentsov (MV)
!!        Update the explicit TEB_GARDEN interface for diagnostic/CBS surface
!!        coupling and the parameter/state reorganization.
!!------------------------------------------------------------------------------
MODULE MODI_TEB_GARDEN
INTERFACE
    SUBROUTINE TEB_GARDEN (icell, iblock, TOPTS, TSTATE, BOPTS, BSTATE, TPN, TIR, DMT, &
                           OGREENROOF_EXT, HIMPLICIT_WIND, PBEM_AC, FORC, EXT, HSNOW_ROOF, HSNOW_ROAD, PPEW_A_COEF, &
                           PPEW_B_COEF, PPEW_A_COEF_LOWCAN, PPEW_B_COEF_LOWCAN, KSW, PH_TRAFFIC, PTSTEP, KDAY, PTIME, &
                           PCH_GD, PCD_GD, TPARAMS, BPARAMS)
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_n, ONLY : TEB_t
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t
USE MODD_BEM_n, ONLY : BEM_t
USE MODD_TEB_PANEL_n, ONLY : TEB_PANEL_t
USE MODD_TEB_IRRIG_n, ONLY : TEB_IRRIG_t
USE MODD_TEB_FORCING_n, ONLY : TEB_FORCING_t
USE MODD_TEB_EXT_SURF_n, ONLY : TEB_EXT_SURF_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE MODD_TEB_PARAMS_n, ONLY : TEB_PARAMS_t
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t
IMPLICIT NONE
TYPE(TEB_PARAMS_t), INTENT(IN) :: TPARAMS
TYPE(BEM_PARAMS_t), INTENT(INOUT) :: BPARAMS


INTEGER                             :: icell                                                      
INTEGER                             :: iblock
TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: TOPTS
TYPE(TEB_t), INTENT(INOUT) :: TSTATE
TYPE(BEM_OPTIONS_t), INTENT(INOUT) :: BOPTS
TYPE(BEM_t), INTENT(INOUT) :: BSTATE
TYPE(TEB_PANEL_t), INTENT(INOUT) :: TPN
TYPE(TEB_IRRIG_t), INTENT(INOUT) :: TIR
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT
!
LOGICAL,              INTENT(IN)  :: OGREENROOF_EXT  !IN Flag to use a green roofs scheme (external)
CHARACTER(LEN=*),     INTENT(IN)  :: HIMPLICIT_WIND  ! wind implicitation option
!                                                         ! 'OLD' = direct
!                                                         ! 'NEW' = Taylor serie, order 1
TYPE(TEB_EXT_SURF_t), INTENT(IN)    :: EXT         ! external garden/greenroof surface (host -> TEB)
TYPE(TEB_FORCING_t),  INTENT(IN)    :: FORC        ! atmospheric forcing of the sub-step
LOGICAL,INTENT(IN)                  :: PBEM_AC     ! Flag to use air conditioners
CHARACTER(LEN=*)    , INTENT(IN)    :: HSNOW_ROOF  ! snow roof scheme 'NONE', 'D95 ', '1-L '
CHARACTER(LEN=*)    , INTENT(IN)    :: HSNOW_ROAD  ! snow road scheme 'NONE', 'D95 ', '1-L '
!
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_A_COEF         ! implicit coefficients
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_B_COEF         ! for wind coupling
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_A_COEF_LOWCAN  ! implicit coefficients for wind coupling
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_B_COEF_LOWCAN  ! between low canyon wind and road
INTEGER,              INTENT(IN)    :: KSW                 ! number of short-wave spectral bands
REAL, DIMENSION(:)  , INTENT(IN)    :: PH_TRAFFIC          ! anthropogenic sensible heat fluxes due to traffic
REAL                , INTENT(IN)    :: PTSTEP              ! time step


REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_GD    ! drag coeifficient for heat
REAL, DIMENSION(:)  , INTENT(INOUT)   :: PCD_GD  ! garden  surf. exchange coefficient


!* INOUT: read by the canyon air nodes before the snow scheme of TEB writes them
INTEGER             , INTENT(IN)    :: KDAY    ! Simulation day
REAL                , INTENT(IN)     :: PTIME  ! current time since midnight (UTC, s)
END SUBROUTINE TEB_GARDEN
END INTERFACE
END MODULE MODI_TEB_GARDEN
