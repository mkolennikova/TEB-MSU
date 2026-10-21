!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!     #############################################################
SUBROUTINE WINDOW_DATA_STRUCT(KI,PSHGC, PU_WIN, PALB_WIN, PABS_WIN, PUGG_WIN, PTRAN_WIN)
!     #############################################################
!
!
!!****  *WINDOW_DATA*  
!!
!!    PURPOSE
!!    -------
!
!     Computes the radiative properties of the window
!         
!     
!!**  METHOD
!!     ------
!! uses U_WIN (window conductivity) and SHGC (window solar heat gain coef)
!! to compute the normal incident transmittance/reflectance
!! a factor to normal incident tran/ref is applied to take into account all
!! possible incidence between 18deg and 72deg
!!
!!
!!    EXTERNAL
!!    --------
!!
!!
!!    IMPLICIT ARGUMENTS
!!    ------------------
!!
!!    MODD_CST
!!
!!      
!!    REFERENCE
!!    ---------
!!
!! Simple Window Model from EnergyPlus Engineering Reference V7, 2012, p. 217.
!!      
!!    AUTHOR
!!    ------
!!
!!      B. Bueno           * Meteo-France *
!!
!!    MODIFICATIONS
!!    -------------
!!      Original    11/10
!!      G. Pigeon & J. Le Bras  09/12 apply new factor to normal incident tran/ref
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!

!
!
USE MODI_WINDOW_DATA
!
USE MODD_BEM_n, ONLY : BEM_t
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t, BEM_PARAMS_INIT
!
IMPLICIT NONE
!
INTEGER,             INTENT(IN)  :: KI       ! number of points
REAL, DIMENSION(KI), INTENT(IN)  :: PSHGC    ! solar heat gain coef. of windows
REAL, DIMENSION(KI), INTENT(IN)  :: PU_WIN   ! window U-factor [K m W-2]
REAL, DIMENSION(KI), INTENT(OUT) :: PALB_WIN ! window albedo
REAL, DIMENSION(KI), INTENT(OUT) :: PABS_WIN ! window absortance
REAL, DIMENSION(KI), INTENT(OUT) :: PUGG_WIN ! window glass-to-glass U-factor [W m-2 K-1]
REAL, DIMENSION(KI), INTENT(OUT) :: PTRAN_WIN! window transmittance (-)
!
!
!*      0.2    Declarations of local variables 
!
TYPE(BEM_t) :: BSTATE
TYPE(BEM_PARAMS_t) :: BPARAMS
!
!
!------------------------------------------------------------------------------
CALL BEM_PARAMS_INIT(BPARAMS)
ALLOCATE(BPARAMS%XSHGC    (1))
ALLOCATE(BPARAMS%XU_WIN   (1))
ALLOCATE(BSTATE%XALB_WIN (1))
ALLOCATE(BSTATE%XABS_WIN (1))
ALLOCATE(BSTATE%XUGG_WIN (1))
ALLOCATE(BSTATE%XTRAN_WIN(1))
!------------------------------------------------------------------------------
!
! put input variables in structures
BPARAMS%XSHGC  = PSHGC    ! solar heat gain coef. of windows
BPARAMS%XU_WIN = PU_WIN   ! window U-factor [K m W-2]
!------------------------------------------------------------------------------
!
CALL WINDOW_DATA(KI,BSTATE, BPARAMS)
!
!------------------------------------------------------------------------------
!
! put computed variables in output variables
PALB_WIN = BSTATE%XALB_WIN ! window albedo
PABS_WIN = BSTATE%XABS_WIN ! window absortance
PUGG_WIN = BSTATE%XUGG_WIN ! window glass-to-glass U-factor [W m-2 K-1]
PTRAN_WIN= BSTATE%XTRAN_WIN! window transmittance (-)!
!------------------------------------------------------------------------------
DEALLOCATE(BPARAMS%XSHGC    )
DEALLOCATE(BPARAMS%XU_WIN   )
DEALLOCATE(BSTATE%XALB_WIN )
DEALLOCATE(BSTATE%XABS_WIN )
DEALLOCATE(BSTATE%XUGG_WIN )
DEALLOCATE(BSTATE%XTRAN_WIN)
!------------------------------------------------------------------------------
!
END SUBROUTINE WINDOW_DATA_STRUCT
