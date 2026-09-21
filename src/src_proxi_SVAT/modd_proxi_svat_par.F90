!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 1998-2013 Meteo-France
! This is part of the TEB software governed by the CeCILL-C licence version 1.
! See LICENCE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt for details.
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-fr.txt
! The CeCILL-C licence is compatible with L-GPL
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     ##########################
      MODULE MODD_PROXI_SVAT_PAR
!     ##########################
!
!!****  *MODD_PROXI_SVAT_PAR* - fixed parameters of the TEB surface
!!                              vegetation proxies (directory src_proxi_SVAT)
!!
!!    PURPOSE
!!    -------
!
!     SINGLE SOURCE OF TRUTH for the fixed surface parameters shared by the
!     TEB surface-vegetation proxies and by their external (host model)
!     counterparts.
!
!     Every version of the garden scheme selected by the namelist key
!     teb_type_garden must take these parameters here:
!
!       'PROXY_OLD' : historical fixed Bowen-ratio proxy (GARDEN)
!       'PROXY_NEW' : diagnostic closed surface energy balance (GARDEN)
!       'EXT'       : external garden model (TEB_GARDEN, URBAN_DRAG); the
!                     values below are the defaults used by the offline
!                     driver when no host model provides them
!       'EXT_NEU'   : same external garden, but the diagnostic garden
!                     coefficients of URBAN_DRAG follow the neutral formulation
!                     of the internal scheme (GARDEN_PCD_NEUTRAL)
!
!     This avoids duplicating the same physical constant in GARDEN,
!     GREENROOF, TEB_VEG_PROPERTIES and RUN_TEB_OFFLINE.
!
!!**  IMPLICIT ARGUMENTS
!!    ------------------
!!      None
!!
!!    REFERENCE
!!    ---------
!!
!!    AUTHOR
!!    ------
!!      TEB-Ru
!!
!!    MODIFICATIONS
!!    -------------
!!      Original    09/2026   gathering of the garden roughness length
!-------------------------------------------------------------------------------
!
!*       0.   DECLARATIONS
!             ------------
!
IMPLICIT NONE
!
!-------------------------------------------------------------------------------
!*       0.1  Garden surface parameters
!             -----------------------
!
!* Garden roughness length (m). Used as the DEFAULT value of the namelist item
!* z0_garden (RUN_TEB_OFFLINE), which is the value actually used by all the
!* garden versions:
!*   - GARDEN     : PZ0_GD argument -> aerodynamical conductance Ca of the
!*                  internal proxies ('PROXY_OLD' and 'PROXY_NEW')
!*   - URBAN_DRAG : PZ0_GARDEN_EXT -> diagnostic garden roughness used by the
!*                  *_GARDEN_CAN / *_GARDEN_ATM columns ('EXT' and 'EXT_NEU')
!
REAL, PARAMETER :: XZ0_GD = 0.10
!* Greenroof roughness length (m). Default of the namelist item urb_z0_grf
!* (RUN_TEB_OFFLINE); the physical value is propagated as the PZ0_GR argument
!* of the GREENROOF scheme (and as ZUW_GR to the roof momentum flux).
REAL, PARAMETER :: XZ0_GR = 0.01
!
!-------------------------------------------------------------------------------
!
END MODULE MODD_PROXI_SVAT_PAR
