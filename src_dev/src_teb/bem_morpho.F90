!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!#####################################################################
SUBROUTINE BEM_MORPHO(PBLD, PWALL_O_HOR, PBLD_HEIGHT, PWALL_O_BLD, BSTATE, BPARAMS)
!#####################################################################
!
!!**** *BEM_MORPHO 
!!
!!    PURPOSE
!!    -------
!! compute morphometric parameter of the building for BEM
!! 
!!**  METHOD
!!    ------
!!
!!    EXTERNAL
!!    --------
!!
!!
!!    IMPLICIT ARGUMENTS
!!    ------------------
!!
!!    REFERENCE
!!    ---------
!!
!!
!!    AUTHOR
!!    ------
!!      G. Pigeon   *Meteo France*
!!
!!    MODIFICATIONS
!!    -------------
!!      Original    10/2011
!-------------------------------------------------------------------------------
!
!*       0.    DECLARATIONS
!              ------------
!
USE MODD_BEM_n, ONLY : BEM_t
!
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t
IMPLICIT NONE
TYPE(BEM_PARAMS_t), INTENT(INOUT) :: BPARAMS

!
!*       0.1   Declarations of arguments
!              -------------------------
!
REAL, DIMENSION(:),   INTENT(IN)  :: PBLD         ! Urban horizontal building density
REAL, DIMENSION(:),   INTENT(IN)  :: PWALL_O_HOR  ! Wall to horizontal surface ratio
REAL, DIMENSION(:),   INTENT(IN)  :: PBLD_HEIGHT  ! Average building height [m]
REAL, DIMENSION(:),   INTENT(OUT) :: PWALL_O_BLD  ! wall surface per ground building surface [m2(wall)/m2(bld)]
TYPE(BEM_t), INTENT(INOUT) :: BSTATE
!
!*      0.2    Declarations of local variables 
!
REAL, DIMENSION(SIZE(PBLD)):: ZF_AUX2       ! Auxiliar view factor
!
!RJ: missing declaration
INTEGER :: JJ
!
!------------------------------------------------------------------------------
!
!*    1.   Verify floor height
!          -------------------
!
DO JJ=1,SIZE(PBLD)
  IF (BPARAMS%XFLOOR_HEIGHT(JJ) < 2.5) THEN
!    WRITE(ILUOUT,*) 'WARNING: BPARAMS%XFLOOR_HEIGHT low ',BPARAMS%XFLOOR_HEIGHT(JJ),' grid mesh number ',JJ
    BPARAMS%XFLOOR_HEIGHT(JJ) = 2.5
  ENDIF
  IF (BPARAMS%XFLOOR_HEIGHT(JJ) > PBLD_HEIGHT(JJ)) THEN
!    WRITE(ILUOUT,*) 'WARNING: BPARAMS%XFLOOR_HEIGHT higher than PBLD_HEIGHT ',BPARAMS%XFLOOR_HEIGHT(JJ),' grid mesh number ',JJ, &
!                    'set to PBLD_HEIGHT'
    BPARAMS%XFLOOR_HEIGHT(JJ) = PBLD_HEIGHT(JJ)
  ENDIF
!
!*    1.   Verify location of HVAC release for very extended buildings
!          -----------------------------------------------------------
!
  IF (PBLD(JJ) > 0.9999 .AND. BPARAMS%XF_WASTE_CAN(JJ) > 0.) THEN
!    WRITE(ILUOUT,*) 'WARNING: BPARAMS%XF_WASTE_CAN cannot be higher than 0. while PBLD is 0.9999',BPARAMS%XF_WASTE_CAN(JJ), &
!                    ' grid mesh number ',JJ,' set to 0.'
    BPARAMS%XF_WASTE_CAN(JJ) = 0.
  ENDIF
END DO
!
!*       1.    floor number, relative surf. and view factors caculation
!              --------------------------------------------------------
!
BPARAMS%XN_FLOOR(:) = FLOAT(NINT(PBLD_HEIGHT(:) / BPARAMS%XFLOOR_HEIGHT(:) ))
PWALL_O_BLD(:) = PWALL_O_HOR(:) * (1. - BPARAMS%XGR(:)) / PBLD(:) ! [m2(wall)/m2(bld)]
BPARAMS%XGLAZ_O_BLD(:) = PWALL_O_HOR(:) * BPARAMS%XGR(:)        / PBLD(:) ! [m2(win)/m2(bld)]

WHERE(BPARAMS%XN_FLOOR > 1.5)
   !* more than 1 floor level -> the floor and the roof don't see each other
   !
   !           ROOF
   !  |---------------------|
   !  |                     |
   !  |                     |
   !  |        MASS         |
   !  |---------------------|
   !  |---------------------|
   !  |        MASS         |
   !  |                     |
   !  |                     |
   !  |        FLOOR        |
   !  |---------------------|
   !
   BPARAMS%XMASS_O_BLD(:) = 2 * (BPARAMS%XN_FLOOR(:) - 1.)                     ! [m2(mass)/m2(bld)]
   BPARAMS%XFLOOR_HW_RATIO(:) = PWALL_O_HOR(:) / BPARAMS%XN_FLOOR(:) / PBLD(:) / 2.
   !
   BPARAMS%XF_FLOOR_MASS(:) = (BPARAMS%XFLOOR_HW_RATIO(:)**2 + 1.)**0.5  - BPARAMS%XFLOOR_HW_RATIO(:)
   BPARAMS%XF_FLOOR_WALL(:) = (1. - BPARAMS%XF_FLOOR_MASS(:)) * (1. - BPARAMS%XGR(:))
   BPARAMS%XF_FLOOR_WIN (:) = (1. - BPARAMS%XF_FLOOR_MASS(:)) * BPARAMS%XGR(:)
   BPARAMS%XF_FLOOR_ROOF(:) = 0. ! no rad interaction between floor and roof
   !
   ZF_AUX2      (:) = (1. - BPARAMS%XF_FLOOR_MASS(:)) / BPARAMS%XFLOOR_HW_RATIO(:)
   !
   BPARAMS%XF_WALL_FLOOR(:) = ZF_AUX2(:) / ( 2.*BPARAMS%XN_FLOOR(:) )
   BPARAMS%XF_WALL_MASS (:) = BPARAMS%XF_WALL_FLOOR(:) * (2.*BPARAMS%XN_FLOOR(:)-2.) 
   BPARAMS%XF_WALL_WIN  (:) = (1. - ZF_AUX2(:)) * BPARAMS%XGR(:)
   !
   BPARAMS%XF_WIN_FLOOR(:) = BPARAMS%XF_WALL_FLOOR(:)
   BPARAMS%XF_WIN_MASS (:) = BPARAMS%XF_WALL_MASS (:)
   BPARAMS%XF_WIN_WALL (:) = (1. - BPARAMS%XF_WIN_FLOOR(:) * 2. - BPARAMS%XF_WIN_MASS(:) ) * (1. - BPARAMS%XGR(:))
   BPARAMS%XF_WIN_WIN  (:) = (1. - BPARAMS%XF_WIN_FLOOR(:) * 2. - BPARAMS%XF_WIN_MASS(:) ) * BPARAMS%XGR(:)
   !
   BPARAMS%XF_MASS_FLOOR(:) = BPARAMS%XF_FLOOR_MASS(:) / BPARAMS%XMASS_O_BLD(:)
   BPARAMS%XF_MASS_WALL (:) = PWALL_O_BLD(:) * BPARAMS%XF_WALL_MASS(:) / BPARAMS%XMASS_O_BLD(:)
   BPARAMS%XF_MASS_WIN  (:) = BPARAMS%XGLAZ_O_BLD (:) * BPARAMS%XF_WIN_MASS(:)  / BPARAMS%XMASS_O_BLD(:)
ELSE WHERE
   !* 1 floor level -> no mass view factors ; roof and floor see each other
   !
   !           ROOF
   !  |---------------------|
   !  |                     |
   !  |                     |
   !  |        FLOOR        |
   !  |---------------------|
   !
   BPARAMS%XMASS_O_BLD(:) = 0.
   BPARAMS%XFLOOR_HW_RATIO(:) = PWALL_O_HOR(:) / PBLD(:) / 2.
   !
   BPARAMS%XF_FLOOR_ROOF(:) = (BPARAMS%XFLOOR_HW_RATIO(:)**2 + 1.)**0.5  - BPARAMS%XFLOOR_HW_RATIO(:)
   BPARAMS%XF_FLOOR_MASS(:) = 0.
   BPARAMS%XF_FLOOR_WALL(:) = (1. - BPARAMS%XF_FLOOR_ROOF(:)) * (1. - BPARAMS%XGR(:))
   BPARAMS%XF_FLOOR_WIN (:) = (1. - BPARAMS%XF_FLOOR_ROOF(:)) * BPARAMS%XGR(:)
   !
   ZF_AUX2      (:) = (1. - BPARAMS%XF_FLOOR_ROOF(:)) / BPARAMS%XFLOOR_HW_RATIO(:)
   !
   BPARAMS%XF_WALL_FLOOR(:) = ZF_AUX2(:) / 2.
   BPARAMS%XF_WALL_MASS (:) = 0.
   BPARAMS%XF_WALL_WIN  (:) = (1. - ZF_AUX2(:)) * BPARAMS%XGR(:)
   !
   BPARAMS%XF_WIN_FLOOR(:) = BPARAMS%XF_WALL_FLOOR(:)
   BPARAMS%XF_WIN_MASS (:) = 0.
   BPARAMS%XF_WIN_WALL (:) = (1. - BPARAMS%XF_WIN_FLOOR(:) * 2. - BPARAMS%XF_WIN_MASS(:) ) * (1. - BPARAMS%XGR(:))
   BPARAMS%XF_WIN_WIN  (:) = (1. - BPARAMS%XF_WIN_FLOOR(:) * 2. - BPARAMS%XF_WIN_MASS(:) ) * BPARAMS%XGR(:)
   !
   BPARAMS%XF_MASS_FLOOR(:) = 0.
   BPARAMS%XF_MASS_WALL (:) = 0.
   BPARAMS%XF_MASS_WIN  (:) = 0.
END WHERE
!
END SUBROUTINE BEM_MORPHO
!-------------------------------------------------------------------------------
