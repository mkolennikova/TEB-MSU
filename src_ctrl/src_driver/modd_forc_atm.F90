!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 1998-2013 Meteo-France
! This is part of the TEB software governed by the CeCILL-C licence version 1.
! See LICENCE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt for details.
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-fr.txt
! The CeCILL-C licence is compatible with L-GPL
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     ######################
MODULE MODD_FORC_ATM
!     ######################
!
!!****  *MODD_FORC_ATM - declaration of atmospheric forcing variables
!!
!!    PURPOSE
!!    -------
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
!!	F. Habets   *Meteo France*
!!
!!    MODIFICATIONS
!!    -------------
!!      Original       20/09/02
!
!*       0.   DECLARATIONS
!             ------------
!
!
IMPLICIT NONE
!------------------------------------------------------------------------------
!
CHARACTER(LEN=6), DIMENSION(1)  :: CSV       ! name of all scalar variables
REAL,             DIMENSION(1,1)  :: XDIR_ALB  ! direct albedo for each band
REAL,             DIMENSION(1,1)  :: XSCA_ALB  ! diffuse albedo for each band
REAL,             DIMENSION(1)  :: XEMIS     ! emissivity
REAL,             DIMENSION(1)  :: XTSRAD    ! radiative temperature

REAL, DIMENSION(1)   :: XTSUN     ! solar time                    (s from midnight)
REAL, DIMENSION(1)   :: XZREF     ! height of T,q forcing                 (m)
REAL, DIMENSION(1)   :: XUREF     ! height of wind forcing                (m)
!
REAL, DIMENSION(1)   :: XTA       ! air temperature forcing               (K)
REAL, DIMENSION(1)   :: XQA       ! air specific humidity forcing         (kg/m3)
REAL, DIMENSION(1)   :: XRHOA     ! air density forcing                   (kg/m3)
REAL, DIMENSION(1,1)  :: XSV       ! scalar variables
REAL, DIMENSION(1)   :: XU        ! zonal wind                            (m/s)
REAL, DIMENSION(1)   :: XV        ! meridian wind                         (m/s)
REAL, DIMENSION(1,1)  :: XDIR_SW   ! direct  solar radiation (on horizontal surf.)
!                                            !                                       (W/m2)
REAL, DIMENSION(1,1)  :: XSCA_SW   ! diffuse solar radiation (on horizontal surf.)
!                                            !                                       (W/m2)
REAL, DIMENSION(1)   :: XSW_BANDS ! mean wavelength of each shortwave band (m)
REAL, DIMENSION(1)   :: XZENITH   ! zenithal angle at t  (radian from the vertical)
REAL, DIMENSION(1)   :: XZENITH2  ! zenithal angle at t+1(radian from the vertical)
REAL, DIMENSION(1)   :: XAZIM     ! azimuthal angle      (radian from North, clockwise)
REAL, DIMENSION(1)   :: XLW       ! longwave radiation (on horizontal surf.)
!                                            !                                       (W/m2)
REAL, DIMENSION(1)   :: XPS       ! pressure at atmospheric model surface (Pa)
REAL, DIMENSION(1)   :: XPA       ! pressure at forcing level             (Pa)
REAL, DIMENSION(1)   :: XZS       ! atmospheric model orography           (m)
REAL, DIMENSION(1)   :: XCO2      ! CO2 concentration in the air          (kg/kg)
REAL, DIMENSION(1)   :: XSNOW     ! snow precipitation                    (kg/m2/s)
REAL, DIMENSION(1)   :: XRAIN     ! liquid precipitation                  (kg/m2/s)
!
!
REAL, DIMENSION(1)  :: XSFTH     ! flux of heat                          (W/m2)
REAL, DIMENSION(1)  :: XSFTQ     ! flux of water vapor                   (kg/m2/s)
REAL, DIMENSION(1)  :: XSFU      ! zonal momentum flux                   (pa)
REAL, DIMENSION(1)  :: XSFV      ! meridian momentum flux                (pa)
REAL, DIMENSION(1)  :: XSFCO2    ! flux of CO2                           (kg/m2/s)
REAL, DIMENSION(1,1) :: XSFTS     ! flux of scalar var.                   (kg/m2/s)
!
REAL, DIMENSION(1)  :: XPEW_A_COEF ! implicit coefficients
REAL, DIMENSION(1)  :: XPEW_B_COEF ! needed if HCOUPLING='I'
REAL, DIMENSION(1)  :: XPET_A_COEF
REAL, DIMENSION(1)  :: XPEQ_A_COEF
REAL, DIMENSION(1)  :: XPET_B_COEF
REAL, DIMENSION(1)  :: XPEQ_B_COEF

!------------------------------------------------------------------------------
!
END MODULE MODD_FORC_ATM

