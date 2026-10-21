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
USE MODD_TEB_PARAMS_n, ONLY : TEB_PARAMS_t, ALLOC_TEB_PARAMS, DEALLOC_TEB_PARAMS
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t, ALLOC_BEM_PARAMS, DEALLOC_BEM_PARAMS
USE MODD_TEB_n,           ONLY : TEB_t
USE MODD_BEM_n,           ONLY : BEM_t
USE MODD_TEB_PANEL_n,     ONLY : TEB_PANEL_t
USE MODD_TEB_IRRIG_n,     ONLY : TEB_IRRIG_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE MODI_ALLOC_TEB_STRUCT,   ONLY : ALLOC_TEB_STRUCT
USE MODI_DEALLOC_TEB_STRUCT, ONLY : DEALLOC_TEB_STRUCT
USE MODI_DIAG_MISC_TEB_UTIL, ONLY : DIAG_MISC_TEB_ALLOC, DIAG_MISC_TEB_DEALLOC
IMPLICIT NONE
!
!
!*       0.   MODULE DATA: the containers of the TEB configuration, state
!             and diagnostics. They are declared here, allocated lazily by
!             TEB_HOST_ENSURE on the first call of TEB_INTERFACE (one set per
!             thread), filled per call and passed down the call chain.
!
TYPE(TEB_OPTIONS_t),  SAVE :: TOP   ! options of TEB
TYPE(TEB_PARAMS_t),   SAVE :: TP    ! parameters of TEB
TYPE(TEB_t),          SAVE :: TSTATE     ! state of TEB
TYPE(BEM_OPTIONS_t),  SAVE :: BOP   ! options of BEM
TYPE(BEM_PARAMS_t),   SAVE :: BP    ! parameters of BEM
TYPE(BEM_t),          SAVE :: BSTATE     ! state of BEM
TYPE(TEB_PANEL_t),    SAVE :: TPN   ! solar panels
TYPE(TEB_IRRIG_t),    SAVE :: TIR   ! irrigation
TYPE(DIAG_MISC_TEB_t),SAVE :: DMT   ! diagnostics
LOGICAL,              SAVE :: LTEB_HOST_ALLOC = .FALSE.
!$OMP THREADPRIVATE(TOP,TP,T,BOP,BP,B,TPN,TIR,DMT,LTEB_HOST_ALLOC)
!
CONTAINS

!
!------------------------------------------------------------------------------
!*      1.   FILL THE PARAMETER CONTAINERS FROM THE CONFIGURATION
!------------------------------------------------------------------------------
SUBROUTINE TEB_FILL_PARAMS (KSTART, KEND, &
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
!
!------------------------------------------------------------------------------
!*      2.   LAZY ALLOCATION OF THE CONTAINERS (first call, per thread)
!------------------------------------------------------------------------------
SUBROUTINE TEB_HOST_ENSURE (KNVEC, KROOF, KROAD, KWALL, KFLOOR)
!
INTEGER, INTENT(IN) :: KNVEC   ! number of grid points of the window
INTEGER, INTENT(IN) :: KROOF   ! number of roof layers
INTEGER, INTENT(IN) :: KROAD   ! number of road layers
INTEGER, INTENT(IN) :: KWALL   ! number of wall layers
INTEGER, INTENT(IN) :: KFLOOR  ! number of floor layers
!------------------------------------------------------------------------------
!
IF (.NOT. LTEB_HOST_ALLOC) THEN
   CALL ALLOC_TEB_STRUCT(KROOF, KROAD, KWALL, KFLOOR, TOP, TSTATE, BOP, BSTATE, TPN, TIR)
   CALL ALLOC_TEB_PARAMS(TP, KROOF, KROAD, KWALL)
   CALL ALLOC_BEM_PARAMS(BP, KFLOOR)
   CALL DIAG_MISC_TEB_ALLOC(DMT, KNVEC)
   LTEB_HOST_ALLOC = .TRUE.
END IF
!
END SUBROUTINE TEB_HOST_ENSURE
!
!------------------------------------------------------------------------------
!*      3.   FINAL RELEASE OF THE CONTAINERS (end of the run)
!------------------------------------------------------------------------------
SUBROUTINE TEB_HOST_FINAL
!------------------------------------------------------------------------------
!
IF (LTEB_HOST_ALLOC) THEN
   CALL DEALLOC_TEB_STRUCT(TOP, TSTATE, BOP, BSTATE, TPN, TIR)
   CALL DEALLOC_TEB_PARAMS(TP)
   CALL DEALLOC_BEM_PARAMS(BP)
   CALL DIAG_MISC_TEB_DEALLOC(DMT)
   LTEB_HOST_ALLOC = .FALSE.
END IF
!
END SUBROUTINE TEB_HOST_FINAL
!
SUBROUTINE TEB_BIND_STATE (KSTART, KEND, teb_ti_bld, teb_twin2, teb_qi_bld, teb_cap_sys_rat, teb_m_sys_rat, teb_twin1, lshade_arg, teb_lshade, teb_shad_day, teb_natvent_night, teb_ws_roof, teb_troof, teb_troad, teb_twalla, teb_twallb, teb_wsnow_roof, teb_tsnow_roof, teb_rsnow_roof, teb_asnow_roof, teb_esnow_roof, teb_tssnow_roof, teb_wsnow_road, teb_tsnow_road, teb_rsnow_road, teb_asnow_road, teb_esnow_road, teb_tssnow_road)
!
INTEGER, INTENT(IN) :: KSTART, KEND
REAL, DIMENSION(:), INTENT(INOUT) :: teb_ti_bld
REAL, DIMENSION(:), INTENT(INOUT) :: teb_twin2
REAL, DIMENSION(:), INTENT(INOUT) :: teb_qi_bld
REAL, DIMENSION(:), INTENT(INOUT) :: teb_cap_sys_rat
REAL, DIMENSION(:), INTENT(INOUT) :: teb_m_sys_rat
REAL, DIMENSION(:), INTENT(INOUT) :: teb_twin1
LOGICAL, DIMENSION(:), INTENT(INOUT) :: lshade_arg
LOGICAL, INTENT(INOUT) :: teb_lshade
LOGICAL, DIMENSION(:), INTENT(INOUT) :: teb_shad_day
LOGICAL, DIMENSION(:), INTENT(INOUT) :: teb_natvent_night
REAL, DIMENSION(:), INTENT(INOUT) :: teb_ws_roof
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_troof
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_troad
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_twalla
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_twallb
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_wsnow_roof
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_tsnow_roof
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_rsnow_roof
REAL, DIMENSION(:), INTENT(INOUT) :: teb_asnow_roof
REAL, DIMENSION(:), INTENT(INOUT) :: teb_esnow_roof
REAL, DIMENSION(:), INTENT(INOUT) :: teb_tssnow_roof
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_wsnow_road
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_tsnow_road
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_rsnow_road
REAL, DIMENSION(:), INTENT(INOUT) :: teb_asnow_road
REAL, DIMENSION(:), INTENT(INOUT) :: teb_esnow_road
REAL, DIMENSION(:), INTENT(INOUT) :: teb_tssnow_road
!
    BSTATE%XTI_BLD(KSTART:KEND)                    = teb_ti_bld(KSTART:KEND)
    BSTATE%XT_WIN2(KSTART:KEND)                    = teb_twin2(KSTART:KEND)
    BSTATE%XQI_BLD(KSTART:KEND)                    = teb_qi_bld(KSTART:KEND)
    BSTATE%XCAP_SYS_RAT(KSTART:KEND)               = teb_cap_sys_rat(KSTART:KEND)
    BSTATE%XM_SYS_RAT(KSTART:KEND)                 = teb_m_sys_rat(KSTART:KEND)
    BSTATE%XT_WIN1(KSTART:KEND)                    = teb_twin1(KSTART:KEND)
    BSTATE%LSHADE(KSTART:KEND)                     = teb_lshade
    BSTATE%LSHAD_DAY(KSTART:KEND)                  = teb_shad_day(KSTART:KEND)
    BSTATE%LNATVENT_NIGHT(KSTART:KEND)             = teb_natvent_night(KSTART:KEND)
    TSTATE%XWS_ROOF(KSTART:KEND)                   = teb_ws_roof(KSTART:KEND)
    TSTATE%XT_ROOF(KSTART:KEND,:)                  = teb_troof(KSTART:KEND,:)
    TSTATE%XT_ROAD(KSTART:KEND,:)                  = teb_troad(KSTART:KEND,:)
    TSTATE%XT_WALL_A(KSTART:KEND,:)                = teb_twalla(KSTART:KEND,:)
    TSTATE%XT_WALL_B(KSTART:KEND,:)                = teb_twallb(KSTART:KEND,:)
    TSTATE%TSNOW_ROOF%WSNOW(KSTART:KEND,:)         = teb_wsnow_roof(KSTART:KEND,:)
    TSTATE%TSNOW_ROOF%T(KSTART:KEND,:)             = teb_tsnow_roof(KSTART:KEND,:)
    TSTATE%TSNOW_ROOF%RHO(KSTART:KEND,:)           = teb_rsnow_roof(KSTART:KEND,:)
    TSTATE%TSNOW_ROOF%ALB(KSTART:KEND)             = teb_asnow_roof(KSTART:KEND)
    TSTATE%TSNOW_ROOF%EMIS(KSTART:KEND)            = teb_esnow_roof(KSTART:KEND)
    TSTATE%TSNOW_ROOF%TS(KSTART:KEND)              = teb_tssnow_roof(KSTART:KEND)
    TSTATE%TSNOW_ROAD%WSNOW(KSTART:KEND,:)         = teb_wsnow_road(KSTART:KEND,:)
    TSTATE%TSNOW_ROAD%T(KSTART:KEND,:)             = teb_tsnow_road(KSTART:KEND,:)
    TSTATE%TSNOW_ROAD%RHO(KSTART:KEND,:)           = teb_rsnow_road(KSTART:KEND,:)
    TSTATE%TSNOW_ROAD%ALB(KSTART:KEND)             = teb_asnow_road(KSTART:KEND)
    TSTATE%TSNOW_ROAD%EMIS(KSTART:KEND)            = teb_esnow_road(KSTART:KEND)
    TSTATE%TSNOW_ROAD%TS(KSTART:KEND)              = teb_tssnow_road(KSTART:KEND)
!
END SUBROUTINE TEB_BIND_STATE
!
SUBROUTINE TEB_UNBIND_STATE (KSTART, KEND, teb_ti_bld, teb_twin2, teb_qi_bld, teb_cap_sys_rat, teb_m_sys_rat, teb_twin1, lshade_arg, teb_lshade, teb_shad_day, teb_natvent_night, teb_ws_roof, teb_troof, teb_troad, teb_twalla, teb_twallb, teb_wsnow_roof, teb_tsnow_roof, teb_rsnow_roof, teb_asnow_roof, teb_esnow_roof, teb_tssnow_roof, teb_wsnow_road, teb_tsnow_road, teb_rsnow_road, teb_asnow_road, teb_esnow_road, teb_tssnow_road)
!
INTEGER, INTENT(IN) :: KSTART, KEND
REAL, DIMENSION(:), INTENT(INOUT) :: teb_ti_bld
REAL, DIMENSION(:), INTENT(INOUT) :: teb_twin2
REAL, DIMENSION(:), INTENT(INOUT) :: teb_qi_bld
REAL, DIMENSION(:), INTENT(INOUT) :: teb_cap_sys_rat
REAL, DIMENSION(:), INTENT(INOUT) :: teb_m_sys_rat
REAL, DIMENSION(:), INTENT(INOUT) :: teb_twin1
LOGICAL, DIMENSION(:), INTENT(INOUT) :: lshade_arg
LOGICAL, INTENT(INOUT) :: teb_lshade
LOGICAL, DIMENSION(:), INTENT(INOUT) :: teb_shad_day
LOGICAL, DIMENSION(:), INTENT(INOUT) :: teb_natvent_night
REAL, DIMENSION(:), INTENT(INOUT) :: teb_ws_roof
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_troof
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_troad
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_twalla
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_twallb
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_wsnow_roof
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_tsnow_roof
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_rsnow_roof
REAL, DIMENSION(:), INTENT(INOUT) :: teb_asnow_roof
REAL, DIMENSION(:), INTENT(INOUT) :: teb_esnow_roof
REAL, DIMENSION(:), INTENT(INOUT) :: teb_tssnow_roof
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_wsnow_road
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_tsnow_road
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_rsnow_road
REAL, DIMENSION(:), INTENT(INOUT) :: teb_asnow_road
REAL, DIMENSION(:), INTENT(INOUT) :: teb_esnow_road
REAL, DIMENSION(:), INTENT(INOUT) :: teb_tssnow_road
!
    teb_ti_bld(KSTART:KEND)                        = BSTATE%XTI_BLD(KSTART:KEND)
    teb_qi_bld(KSTART:KEND)                        = BSTATE%XQI_BLD(KSTART:KEND)
    teb_twin1(KSTART:KEND)                         = BSTATE%XT_WIN1(KSTART:KEND)
    teb_twin2(KSTART:KEND)                         = BSTATE%XT_WIN2(KSTART:KEND)
    teb_cap_sys_rat(KSTART:KEND)                   = BSTATE%XCAP_SYS_RAT(KSTART:KEND)
    teb_m_sys_rat(KSTART:KEND)                     = BSTATE%XM_SYS_RAT(KSTART:KEND)
    teb_shad_day(KSTART:KEND)                      = BSTATE%LSHAD_DAY(KSTART:KEND)
    teb_natvent_night(KSTART:KEND)                 = BSTATE%LNATVENT_NIGHT(KSTART:KEND)
    teb_troof(KSTART:KEND,:)                       = TSTATE%XT_ROOF(KSTART:KEND,:)
    teb_troad(KSTART:KEND,:)                       = TSTATE%XT_ROAD(KSTART:KEND,:)
    teb_twalla(KSTART:KEND,:)                      = TSTATE%XT_WALL_A(KSTART:KEND,:)
    teb_twallb(KSTART:KEND,:)                      = TSTATE%XT_WALL_B(KSTART:KEND,:)
    teb_ws_roof(KSTART:KEND)                       = TSTATE%XWS_ROOF(KSTART:KEND)
    teb_wsnow_roof(KSTART:KEND,:)                  = TSTATE%TSNOW_ROOF%WSNOW(KSTART:KEND,:)
    teb_tsnow_roof(KSTART:KEND,:)                  = TSTATE%TSNOW_ROOF%T(KSTART:KEND,:)
    teb_rsnow_roof(KSTART:KEND,:)                  = TSTATE%TSNOW_ROOF%RHO(KSTART:KEND,:)
    teb_asnow_roof(KSTART:KEND)                    = TSTATE%TSNOW_ROOF%ALB(KSTART:KEND)
    teb_esnow_roof(KSTART:KEND)                    = TSTATE%TSNOW_ROOF%EMIS(KSTART:KEND)
    teb_tssnow_roof(KSTART:KEND)                   = TSTATE%TSNOW_ROOF%TS(KSTART:KEND)
    teb_wsnow_road(KSTART:KEND,:)                  = TSTATE%TSNOW_ROAD%WSNOW(KSTART:KEND,:)
    teb_tsnow_road(KSTART:KEND,:)                  = TSTATE%TSNOW_ROAD%T(KSTART:KEND,:)
    teb_rsnow_road(KSTART:KEND,:)                  = TSTATE%TSNOW_ROAD%RHO(KSTART:KEND,:)
    teb_asnow_road(KSTART:KEND)                    = TSTATE%TSNOW_ROAD%ALB(KSTART:KEND)
    teb_esnow_road(KSTART:KEND)                    = TSTATE%TSNOW_ROAD%EMIS(KSTART:KEND)
    teb_tssnow_road(KSTART:KEND)                   = TSTATE%TSNOW_ROAD%TS(KSTART:KEND)
!
END SUBROUTINE TEB_UNBIND_STATE
!
END MODULE TEB_HOST
