!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt
!     #####################
      MODULE TEB_HOST
!     #####################
!!
!!****  *TEB_HOST* - filling of the TEB/BEM parameter containers
!!
!!    PURPOSE
!!    -------
!!    The parameter containers (TOP, TP, BOP, BP) are filled here, at the
!!    level where the configuration values are known: in TEB_INTERFACE.
!!    CALL_DRIVER therefore does not copy its arguments into the containers
!!    any more, and does not need them as dummies.
!!
!!    Only the window KSTART:KEND is filled, so the inactive tail of the
!!    arrays is never touched.
!!
!!    AUTHOR
!!    ------
!!      MV   *TEB-MSU*   10/2026
!
!*       0.   DECLARATIONS
!             ------------
!
!
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_PARAMS_n, ONLY : TEB_PARAMS_t
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t
IMPLICIT NONE
!
CONTAINS
!
!------------------------------------------------------------------------------
!*      1.   FILL THE PARAMETER CONTAINERS FROM THE CONFIGURATION
!------------------------------------------------------------------------------
SUBROUTINE TEB_FILL_PARAMS (TOP, TP, BOP, BP, KSTART, KEND, &
                            teb_itype_bem_cool, teb_itype_bem_heat, teb_tcool_target, &
                            teb_theat_target, teb_frac_gz, teb_bem_inf, teb_bem_vent, &
                            teb_cap_sys_heat, teb_bem_cop, teb_itype_natvent, teb_lgarden, &
                            teb_hroad_dir, teb_wall_opt, teb_itype_bem, teb_lgreenroof, &
                            teb_type_garden, teb_type_greenroof, teb_lsolar_panel, &
                            teb_lcbs_scheme, teb_tau_hw_thresh, teb_tau_hw_width, &
                            urb_z0_o_z0h_gdn, urb_z0_o_z0h_grf, teb_road_dir, fr_garden, &
                            teb_frac_gr, urb_fr_bld, urb_h2w, urb_h_bld, urb_alb_rf_so, &
                            urb_alb_rd_so, urb_alb_wl_so, urb_alb_rd_th, urb_alb_rf_th, &
                            urb_alb_wl_th, teb_zresidential, teb_dt_res, teb_dt_off, &
                            ahf_industry)
!
!*       0.1  containers
!             ----------
TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: TOP   ! options of TEB
TYPE(TEB_PARAMS_t),  INTENT(INOUT) :: TP    ! parameters of TEB
TYPE(BEM_OPTIONS_t), INTENT(INOUT) :: BOP   ! options of BEM
TYPE(BEM_PARAMS_t),  INTENT(INOUT) :: BP    ! parameters of BEM
!
!*       0.2  configuration
!             -------------
INTEGER, INTENT(IN) :: KSTART, KEND
CHARACTER(LEN=*), INTENT(IN) :: teb_itype_bem_cool, teb_itype_bem_heat, teb_itype_natvent
CHARACTER(LEN=*), INTENT(IN) :: teb_itype_bem, teb_hroad_dir, teb_wall_opt
CHARACTER(LEN=*), INTENT(IN) :: teb_type_garden, teb_type_greenroof
LOGICAL, INTENT(IN) :: teb_lgarden, teb_lgreenroof, teb_lsolar_panel, teb_lcbs_scheme
REAL, INTENT(IN) :: teb_tau_hw_thresh, teb_tau_hw_width
REAL, INTENT(IN) :: urb_z0_o_z0h_gdn, urb_z0_o_z0h_grf
REAL, DIMENSION(:), INTENT(IN) :: teb_tcool_target, teb_theat_target, teb_frac_gz
REAL, DIMENSION(:), INTENT(IN) :: teb_bem_inf, teb_bem_vent, teb_cap_sys_heat, teb_bem_cop
REAL, DIMENSION(:), INTENT(IN) :: teb_road_dir, fr_garden, teb_frac_gr, urb_fr_bld
REAL, DIMENSION(:), INTENT(IN) :: urb_h2w, urb_h_bld
REAL, DIMENSION(:), INTENT(IN) :: urb_alb_rf_so, urb_alb_rd_so, urb_alb_wl_so
REAL, DIMENSION(:), INTENT(IN) :: urb_alb_rd_th, urb_alb_rf_th, urb_alb_wl_th
REAL, DIMENSION(:), INTENT(IN) :: teb_zresidential, teb_dt_res, teb_dt_off, ahf_industry
!
!*       0.3  locals
!             ------
INTEGER :: K
!------------------------------------------------------------------------------
!
DO K = KSTART, KEND
!
!* BEM options and parameters
    BOP%CCOOL_COIL            = teb_itype_bem_cool
    BOP%CHEAT_COIL            = teb_itype_bem_heat
    BP%XTCOOL_TARGET(K)       = teb_tcool_target(K)
    BP%XTHEAT_TARGET(K)       = teb_theat_target(K)
    BP%XGR(K)                 = teb_frac_gz(K)
    BP%XINF(K)                = teb_bem_inf(K)
    BP%XV_VENT(K)             = teb_bem_vent(K)
    BP%XCAP_SYS_HEAT(K)       = teb_cap_sys_heat(K)
    BP%XCOP_RAT(K)            = teb_bem_cop(K)
    BP%CNATVENT(K)            = teb_itype_natvent
!
!* TEB options
    TOP%LGARDEN               = teb_lgarden
    TOP%CROAD_DIR             = teb_hroad_dir
    TOP%CWALL_OPT             = teb_wall_opt
    TOP%CBEM                  = teb_itype_bem
    TOP%LGREENROOF            = teb_lgreenroof
    TOP%CTYPE_GARDEN          = teb_type_garden
    TOP%CTYPE_GREENROOF       = teb_type_greenroof
    TOP%LSOLAR_PANEL          = teb_lsolar_panel
    TOP%LCBS_SCHEME           = teb_lcbs_scheme
    TOP%XTAU_HW_THRESH        = teb_tau_hw_thresh
    TOP%XTAU_HW_WIDTH         = teb_tau_hw_width
    TOP%XZ0_O_Z0H_GD          = urb_z0_o_z0h_gdn
    TOP%XZ0_O_Z0H_GR          = urb_z0_o_z0h_grf
!
!* TEB parameters
    TP%XROAD_DIR(K)           = teb_road_dir(K)
    TP%XGARDEN(K)             = fr_garden(K)
    TP%XGREENROOF(K)          = teb_frac_gr(K)
    TP%XBLD(K)                = urb_fr_bld(K)
    TP%XCAN_HW_RATIO(K)       = urb_h2w(K)
    TP%XBLD_HEIGHT(K)         = urb_h_bld(K)
    TP%XALB_ROOF(K)           = urb_alb_rf_so(K)
    TP%XEMIS_ROOF(K)          = 1. - urb_alb_rf_th(K)
    TP%XALB_ROAD(K)           = urb_alb_rd_so(K)
    TP%XEMIS_ROAD(K)          = 1. - urb_alb_rd_th(K)
    TP%XALB_WALL(K)           = urb_alb_wl_so(K)
    TP%XEMIS_WALL(K)          = 1. - urb_alb_wl_th(K)
    TP%XRESIDENTIAL(K)        = teb_zresidential(K)
    TP%XDT_RES                 = teb_dt_res(K)
    TP%XDT_OFF                 = teb_dt_off(K)
    TP%XH_INDUSTRY(K)         = ahf_industry(K)
!
END DO
!
END SUBROUTINE TEB_FILL_PARAMS
!
END MODULE TEB_HOST
