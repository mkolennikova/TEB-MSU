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
!     SINGLE SOURCE OF TRUTH for the fixed surface parameters of the garden
!     and of the greenroof of the CONTROL tree (src_ctrl).
!
!     These are the values that the BASE model (the first commit, 582c3ab) sets
!     directly in RUN_TEB_OFFLINE before the time loop:
!
!       teb_z0_gd  (:) = 0.8    teb_alb_gd (:) = 0.15   teb_emis_gd (:) = 0.9
!       teb_alb_gr (:) = 0.15   teb_emis_gr(:) = 0.9
!
!     and the greenroof roughness length, written as the constant 0.01 m in the
!     comment of the friction flux of GREENROOF.
!
!     The dev tree (src_dev) reads the same six quantities from the namelist
!     (urb_z0_gdn / urb_alb_gdn / urb_emis_gdn, urb_z0_grf / urb_alb_grf /
!     urb_emis_grf) and documents them here. The control tree reads the very
!     same namelist items - the namelist files are shared - but keeps these
!     values as the DEFAULTS used when an item is absent from the namelist, so
!     that a run with an empty (or base-model) namelist reproduces the first
!     commit bit for bit.
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
!!      Original    09/2026   gathering of the base-model surface constants
!-------------------------------------------------------------------------------
!
!*       0.   DECLARATIONS
!             ------------
!
IMPLICIT NONE
!
!-------------------------------------------------------------------------------
!*       0.1  Base-model values of the garden and of the greenroof
!             ---------------------------------------------------
!
!* Each of the six values below is the value that the BASE model (the first
!* commit, 582c3ab) sets directly in RUN_TEB_OFFLINE (garden) or writes as a
!* constant inside GREENROOF (greenroof roughness). It is kept here as a
!* PARAMETER because it is ALSO the default of the namelist item that now
!* carries it (0.3 below), so that a run whose namelist does not define the
!* item falls back to the base-model physics.
!
!* Garden roughness length (m): base-model value, default of urb_z0_gdn.
REAL, PARAMETER :: XZ0_GD  = 0.80
!* Garden albedo (-): base-model value, default of urb_alb_gdn.
REAL, PARAMETER :: XALB_GD = 0.15
!* Garden emissivity (-): base-model value, default of urb_emis_gdn.
REAL, PARAMETER :: XEMIS_GD = 0.90
!* Garden surface relative humidity (-): the base-model value, i.e. the constant
!* that the base GARDEN proxy used as the surface humidity of the garden.
!* TEB_GARDEN uses it as the moisture multiplier of the canyon node for an
!* INTERNAL garden; an external garden takes the multiplier from the state of
!* the host instead (see the EXT block of TEB_GARDEN), which is why this is a
!* PARAMETER of the physics and not a namelist item of this tree.
REAL, PARAMETER :: XPHU_GD  = 0.8
!* Greenroof roughness length (m): base-model value (the constant 0.01 of the
!* friction flux of GREENROOF), default of urb_z0_grf.
REAL, PARAMETER :: XZ0_GR   = 0.01
!* Greenroof albedo (-): base-model value, default of urb_alb_grf.
REAL, PARAMETER :: XALB_GR  = 0.15
!* Greenroof emissivity (-): base-model value, default of urb_emis_grf.
REAL, PARAMETER :: XEMIS_GR = 0.90
!
!*       0.2  Base-model values of the urban aerodynamics
!             -----------------------------------------
!
!* The two entries are resolved in CALL_DRIVER (URB_AERO_PARAMS): '0.1H' is
!* 0.1*urb_h_bld (the base-model z0 of the town) and 'H/3' is urb_h_bld/3 (the
!* base-model reference height of the canyon wind profile).
CHARACTER(LEN=16), PARAMETER :: XURB_Z0_TOWN_DEF = '0.1H'
CHARACTER(LEN=16), PARAMETER :: XURB_ZD_TOWN_DEF = 'H/3'
!
!*       0.3  Namelist items of /tebparam/ carried by this module
!             ------------------------------------------------
!
!* The shared namelist files give these items to BOTH trees (src_dev and
!* src_ctrl). They are declared here - and not in RUN_TEB_OFFLINE - so that the
!* physics files of the control tree (GREENROOF) and the driver read the very
!* same storage; the driver only has to put them in its NAMELIST statement
!* (a NAMELIST group can reference use-associated variables).
!
!* Garden surface parameters: z0 (m), albedo (-), emissivity (-).
REAL :: urb_z0_gdn   = XZ0_GD
REAL :: urb_alb_gdn  = XALB_GD
REAL :: urb_emis_gdn = XEMIS_GD
!* Greenroof surface parameters: z0 (m), albedo (-), emissivity (-).
REAL :: urb_z0_grf   = XZ0_GR
REAL :: urb_alb_grf  = XALB_GR
REAL :: urb_emis_grf = XEMIS_GR
!* Urban aerodynamic entries: z0 of the town and the displacement height. Both
!* accept a value in metres, '<fraction>H' (fraction of urb_h_bld) or 'H/<n>'
!* (urb_h_bld divided by n); the named parameterizations of the dev tree
!* (MACDONALD1998...) are NOT implemented in the control tree and stop the run.
CHARACTER(LEN=16) :: urb_z0_town = XURB_Z0_TOWN_DEF
CHARACTER(LEN=16) :: urb_zd_town = XURB_ZD_TOWN_DEF
!* Garden and greenroof model types. The control tree has a single internal
!* (proxy) parameterization for each of them, so only the proxy names of the
!* dev tree are accepted; 'EXT'/'EXT_NEU' (external emulators) are a src_dev
!* feature and stop the run here.
CHARACTER(LEN=9) :: teb_type_garden    = 'PROXY_NEW'
CHARACTER(LEN=9) :: teb_type_greenroof = 'PROXY_NEW'
!
!*       0.4  Resolved urban displacement height
!             ---------------------------------
!
!* Displacement height (m) of the urban surface, resolved in CALL_DRIVER from
!* the entry urb_zd_town (see URB_AERO_PARAMS) and used by URBAN_DRAG as the
!* reference height of the canyon wind profile. Its base-model value (the
!* hard-coded '+ T%XBLD_HEIGHT/3.' of the first commit) is urb_h_bld/3, i.e.
!* the default entry 'H/3'.
REAL, DIMENSION(1) :: XZD_TOWN = 0.
!
!-------------------------------------------------------------------------------
!
END MODULE MODD_PROXI_SVAT_PAR

