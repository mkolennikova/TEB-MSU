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
!MV202609 garden thermal roughness (z0h)
!* Garden thermal (scalar) roughness ratio z0/z0h (-), i.e. z0h = z0/XZ0_O_Z0H_GD.
!* It is used as the DEFAULT value of the namelist item urb_z0_o_z0h_gdn
!* (RUN_TEB_OFFLINE), which is the value actually used by all the garden versions:
!*   - GARDEN / GARDEN_TAU : the diagnostic surface energy balance exchanges heat
!*                  and moisture through the scalar coefficient
!*                  PCH = kappa**2/(ln(z/z0)*ln(z/z0h)) (the momentum keeps z0:
!*                  only the friction flux uses PCD), see GARDEN_PCH_NEUTRAL
!*   - URBAN_DRAG : the same z0h is exported by the 'EXT_NEU' garden and is
!*                  handed over to URBAN_EXCH_COEF by the 'EXT' garden (where it
!*                  replaces the former hard-coded value 4.)
!* The ratio must be >= 1 (z0h <= z0: the momentum roughness is the upper bound
!* of the scalar one in this formulation); with XZ0_O_Z0H_GD = 1 the garden is
!* exactly the one without thermal roughness.
REAL, PARAMETER :: XZ0_O_Z0H_GD = 4.0
!MV202609 tunable surface relative humidity of the garden
!* Default value of the namelist item urb_phu_gdn (RUN_TEB_OFFLINE): the
!* relative humidity of the garden surface used by BOTH proxy schemes
!* ('PROXY_NEW' drives the latent flux LE = rho*Lv*Ca*(PHU*qsat(Ts) - qa);
!* 'PROXY_OLD' is a Bowen-ratio proxy, so its PHU only enters the moisture
!* multiplier of the canyon node, which TEB_GARDEN builds from this value).
!* An external garden ('EXT'/'EXT_NEU') does not use it: TEB_GARDEN takes
!* the multiplier from the surface humidity of the host then (see its EXT
!* block), and the garden proxies are not called at all in that mode.
!MV202609 default PHU revision
!* 0.7 is the literature-based estimate for a typical (unstressed-to-mildly
!* stressed) urban lawn; the BASE model value was 0.8 (a well-watered lawn, on
!* the wet side). To reproduce the base model bit for bit, set urb_phu_gdn = 0.8.
REAL, PARAMETER :: XPHU_GD = 0.7
!* Greenroof roughness length (m). Default of the namelist item urb_z0_grf
!* (RUN_TEB_OFFLINE); the physical value is propagated as the PZ0_GR argument
!* of the GREENROOF scheme (and as ZUW_GR to the roof momentum flux).
REAL, PARAMETER :: XZ0_GR = 0.01
!MV202609 greenroof thermal roughness (z0h)
!* Greenroof thermal (scalar) roughness ratio z0/z0h (-), i.e. z0h = z0/XZ0_O_Z0H_GR.
!* Default of the namelist item urb_z0_o_z0h_grf (RUN_TEB_OFFLINE); the greenroof
!* exchanges heat and moisture through PCH = kappa**2/(ln(z/z0)*ln(z/z0h)) like the
!* garden, while its momentum keeps z0.
REAL, PARAMETER :: XZ0_O_Z0H_GR = 4.0
!MV202609 tunable surface relative humidity of the greenroof
!* Default value of the namelist item urb_phu_grf (RUN_TEB_OFFLINE): the relative
!* humidity of the greenroof surface used by BOTH proxy schemes (see XPHU_GD).
!MV202609 default PHU revision
!* 0.7 is the literature-based estimate for an extensive (sedum) greenroof; the
!* BASE model value was 0.3, which is below the typical ambient relative humidity
!* and puts the surface into spurious daytime condensation instead of transpiration.
!* To reproduce the base model bit for bit, set urb_phu_grf = 0.3.
REAL, PARAMETER :: XPHU_GR = 0.7
!
!-------------------------------------------------------------------------------
!
END MODULE MODD_PROXI_SVAT_PAR
