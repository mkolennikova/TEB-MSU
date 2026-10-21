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
!!    The parameter containers (TOPTS, TPARAMS, BOPTS, BPARAMS) are filled here, at the
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
USE MODI_URB_AERO_PARAMS,   ONLY : URB_AERO_PARAMS
USE MODI_BEM_MORPHO_STRUCT, ONLY : BEM_MORPHO_STRUCT
USE MODI_WINDOW_DATA_STRUCT, ONLY : WINDOW_DATA_STRUCT
USE MODD_TEB_FORCING_n,   ONLY : TEB_FORCING_t, ALLOC_TEB_FORCING, DEALLOC_TEB_FORCING
USE MODI_SUNPOS,          ONLY : SUNPOS
USE MODI_CIRCUMSOLAR_RAD, ONLY : CIRCUMSOLAR_RAD
USE MODD_CSTS,            ONLY : XRD, XRV, XCPD, XP00, XG, XPI
USE MODD_SURF_PAR,        ONLY : XUNDEF
IMPLICIT NONE
!
!
!*       0.   MODULE DATA: the containers of the TEB configuration, state
!             and diagnostics. They are declared here, allocated lazily by
!             TEB_HOST_ENSURE on the first call of TEB_INTERFACE (one set per
!             thread), filled per call and passed down the call chain.
!
TYPE(TEB_OPTIONS_t),  SAVE :: TOPTS     ! options of TEB
TYPE(TEB_PARAMS_t),   SAVE :: TPARAMS   ! parameters of TEB
TYPE(TEB_t),          SAVE :: TSTATE    ! state of TEB
TYPE(BEM_OPTIONS_t),  SAVE :: BOPTS     ! options of BEM
TYPE(BEM_PARAMS_t),   SAVE :: BPARAMS   ! parameters of BEM
TYPE(BEM_t),          SAVE :: BSTATE    ! state of BEM
TYPE(TEB_PANEL_t),    SAVE :: TPN       ! solar panels
TYPE(TEB_IRRIG_t),    SAVE :: TIR       ! irrigation
TYPE(DIAG_MISC_TEB_t),SAVE :: DMT       ! diagnostics
TYPE(TEB_FORCING_t),  SAVE :: FORC      ! atmospheric forcing of the sub-step
LOGICAL,              SAVE :: LTEB_HOST_ALLOC = .FALSE.
!$OMP THREADPRIVATE(TOPTS,TPARAMS,TSTATE,BOPTS,BPARAMS,BSTATE,FORC,TPN,TIR,DMT,LTEB_HOST_ALLOC)
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
                            ahf_industry, teb_itype_wind, teb_utc_hour, &
                            teb_lgreenroof_ext, teb_lbem_ac, &
                            teb_fr_panel, teb_lroad_irrig, teb_rd_irrig_start_m, &
                            teb_rd_irrig_end_m, teb_rd_irrig_start_h, teb_rd_irrig_end_h, &
                            teb_rd_irrig_sum)
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
INTEGER, INTENT(IN) :: teb_itype_wind, teb_utc_hour
LOGICAL, INTENT(IN) :: teb_lgreenroof_ext, teb_lbem_ac, teb_lroad_irrig
REAL, INTENT(IN) :: teb_tau_hw_thresh, teb_tau_hw_width
REAL, INTENT(IN) :: urb_z0_o_z0h_gdn, urb_z0_o_z0h_grf
REAL, DIMENSION(:), INTENT(IN) :: teb_tcool_target, teb_theat_target, teb_frac_gz
REAL, DIMENSION(:), INTENT(IN) :: teb_bem_inf, teb_bem_vent, teb_cap_sys_heat, teb_bem_cop
REAL, DIMENSION(:), INTENT(IN) :: teb_road_dir, fr_garden, teb_frac_gr, urb_fr_bld
REAL, DIMENSION(:), INTENT(IN) :: urb_h2w, urb_h_bld
REAL, DIMENSION(:), INTENT(IN) :: urb_alb_rf_so, urb_alb_rd_so, urb_alb_wl_so
REAL, DIMENSION(:), INTENT(IN) :: urb_alb_rd_th, urb_alb_rf_th, urb_alb_wl_th
REAL, DIMENSION(:), INTENT(IN) :: teb_zresidential, teb_dt_res, teb_dt_off, ahf_industry
REAL, DIMENSION(:), INTENT(IN) :: teb_fr_panel, teb_rd_irrig_start_m, teb_rd_irrig_end_m
REAL, DIMENSION(:), INTENT(IN) :: teb_rd_irrig_start_h, teb_rd_irrig_end_h, teb_rd_irrig_sum
!
!*       0.3  locals
!             ------
INTEGER :: K
!------------------------------------------------------------------------------
!
DO K = KSTART, KEND
!
!* BEM options and parameters
    BOPTS%CCOOL_COIL            = teb_itype_bem_cool
    BOPTS%CHEAT_COIL            = teb_itype_bem_heat
    BOPTS%LBEM_AC              = teb_lbem_ac
    BPARAMS%XTCOOL_TARGET(K)       = teb_tcool_target(K)
    BPARAMS%XTHEAT_TARGET(K)       = teb_theat_target(K)
    BPARAMS%XGR(K)                 = teb_frac_gz(K)
    BPARAMS%XINF(K)                = teb_bem_inf(K)
    BPARAMS%XV_VENT(K)             = teb_bem_vent(K)
    BPARAMS%XCAP_SYS_HEAT(K)       = teb_cap_sys_heat(K)
    BPARAMS%XCOP_RAT(K)            = teb_bem_cop(K)
    BPARAMS%CNATVENT(K)            = teb_itype_natvent
!
!* TEB options
    TOPTS%LGARDEN               = teb_lgarden
    TOPTS%CROAD_DIR             = teb_hroad_dir
    TOPTS%CWALL_OPT             = teb_wall_opt
    TOPTS%CBEM                  = teb_itype_bem
    TOPTS%LGREENROOF            = teb_lgreenroof
    TOPTS%CTYPE_GARDEN          = teb_type_garden
    TOPTS%CTYPE_GREENROOF       = teb_type_greenroof
    TOPTS%LSOLAR_PANEL          = teb_lsolar_panel
    TOPTS%ITYPE_WIND          = teb_itype_wind
    TOPTS%NUTC_HOUR           = teb_utc_hour
    TOPTS%LGREENROOF_EXT      = teb_lgreenroof_ext
    TOPTS%LCBS_SCHEME           = teb_lcbs_scheme
    TOPTS%XTAU_HW_THRESH        = teb_tau_hw_thresh
    TOPTS%XTAU_HW_WIDTH         = teb_tau_hw_width
    TOPTS%XZ0_O_Z0H_GD          = urb_z0_o_z0h_gdn
    TOPTS%XZ0_O_Z0H_GR          = urb_z0_o_z0h_grf
!
!* TEB parameters
    TPARAMS%XROAD_DIR(K)           = teb_road_dir(K)
    TPARAMS%XGARDEN(K)             = fr_garden(K)
    TPARAMS%XGREENROOF(K)          = teb_frac_gr(K)
    TPARAMS%XBLD(K)                = urb_fr_bld(K)
    TPARAMS%XCAN_HW_RATIO(K)       = urb_h2w(K)
    TPARAMS%XBLD_HEIGHT(K)         = urb_h_bld(K)
    TPARAMS%XALB_ROOF(K)           = urb_alb_rf_so(K)
    TPARAMS%XEMIS_ROOF(K)          = 1. - urb_alb_rf_th(K)
    TPARAMS%XALB_ROAD(K)           = urb_alb_rd_so(K)
    TPARAMS%XEMIS_ROAD(K)          = 1. - urb_alb_rd_th(K)
    TPARAMS%XALB_WALL(K)           = urb_alb_wl_so(K)
    TPARAMS%XEMIS_WALL(K)          = 1. - urb_alb_wl_th(K)
    TPARAMS%XRESIDENTIAL(K)        = teb_zresidential(K)
    TPARAMS%XDT_RES                 = teb_dt_res(K)
    TPARAMS%XDT_OFF                 = teb_dt_off(K)
    TPARAMS%XH_INDUSTRY(K)         = ahf_industry(K)
!
!* solar panels and road irrigation (P-C4: filled here, not in CALL_DRIVER)
    TPN%XEMIS_PANEL(K)       = 0.9
    TPN%XALB_PANEL(K)        = 0.1
    TPN%XEFF_PANEL(K)        = 0.14
    TPN%XFRAC_PANEL(K)       = teb_fr_panel(K)
    TIR%LPAR_RD_IRRIG        = teb_lroad_irrig
    TIR%XRD_START_MONTH(K)   = teb_rd_irrig_start_m(K)
    TIR%XRD_END_MONTH(K)     = teb_rd_irrig_end_m(K)
    TIR%XRD_START_HOUR(K)    = teb_rd_irrig_start_h(K)
    TIR%XRD_END_HOUR(K)      = teb_rd_irrig_end_h(K)
    TIR%XRD_24H_IRRIG(K)     = teb_rd_irrig_sum(K)
!
END DO
!
END SUBROUTINE TEB_FILL_PARAMS
!
!------------------------------------------------------------------------------
!*      1b.  DERIVED STATIC PARAMETERS OF THE URBAN SURFACE
!------------------------------------------------------------------------------
SUBROUTINE TEB_FILL_DERIVED (KSTART, KEND, &
                             urb_z0_town, urb_zd_town, &
                             urb_hcap_rd, urb_hcap_rf, urb_hcap_wl, &
                             urb_hcon_rd, urb_hcon_rf, urb_hcon_wl, &
                             ahf_traffic, fai)
!
!* The derived static parameters: the layer profiles of the roof/road/wall/floor,
!* the geometry fractions, the sky-view factors, z0/zd, the roughness coefficients,
!* the BEM constants and the anthropogenic fluxes. Everything is written into
!* TPARAMS/BPARAMS/TOPTS/BOPTS here, so that CALL_DRIVER does not derive statics any more
!* (P-C1b). Only the window KSTART:KEND is filled.
!
INTEGER, INTENT(IN) :: KSTART, KEND
CHARACTER(LEN=16), INTENT(IN) :: urb_z0_town, urb_zd_town
REAL, DIMENSION(:), INTENT(IN) :: urb_hcap_rd, urb_hcap_rf, urb_hcap_wl
REAL, DIMENSION(:), INTENT(IN) :: urb_hcon_rd, urb_hcon_rf, urb_hcon_wl
REAL, DIMENSION(:), INTENT(IN) :: ahf_traffic
REAL, DIMENSION(:,:), INTENT(IN) :: fai
!
INTEGER :: K
REAL :: ZROAD, ZWALL_O_HOR, ZTOTS_O_HORS, ZROAD_FRAC, ZWALL_FRAC, ZGARDEN_FRAC
REAL, DIMENSION(1) :: ZZ0, ZZDU
REAL, DIMENSION(1) :: ZPFLOOR, ZN_FLOOR, ZWALL_O_BLD, ZGLAZ_O_BLD, ZMASS_O_BLD, ZFLOOR_HW_RATIO
REAL, DIMENSION(1) :: ZF_FLOOR_MASS, ZF_FLOOR_WALL, ZF_FLOOR_WIN, ZF_FLOOR_ROOF, ZF_WALL_FLOOR
REAL, DIMENSION(1) :: ZF_WALL_MASS, ZF_WALL_WIN, ZF_WIN_FLOOR, ZF_WIN_MASS, ZF_WIN_WALL
REAL, DIMENSION(1) :: ZF_MASS_FLOOR, ZF_MASS_WALL, ZF_MASS_WIN, ZF_WASTE_CAN, ZF_WIN_WIN
REAL, DIMENSION(1) :: ZSHGC, PU_WIN, ZABS_WIN, ZUGG_WIN, ZTRAN_WIN
!------------------------------------------------------------------------------
!
!* BEM constants (single-valued, once per run)
BPARAMS%XQIN          = 5.8
BPARAMS%XQIN_FRAD     = 0.2
BPARAMS%XQIN_FLAT     = 0.2
BPARAMS%XSHGC         = 0.763
BPARAMS%XSHGC_SH      = 0.025
BPARAMS%XF_WATER_COND = 0.
BPARAMS%XF_WASTE_CAN  = 1.0
BPARAMS%XEFF_HEAT     = 0.9
BPARAMS%XHR_TARGET    = 0.5
TOPTS%CCH_BEM      = ' '
BOPTS%LAUTOSIZE    = .FALSE.
!MV202609 z0 and zd to namelist
TOPTS%CZ0H         = 'MASC95'
!
DO K = KSTART, KEND
!
!* Roof layers
    TPARAMS%XHC_ROOF(K,1) = urb_hcap_rf(K)
    TPARAMS%XHC_ROOF(K,2) = urb_hcap_rf(K)
    TPARAMS%XHC_ROOF(K,3) = urb_hcap_rf(K)
    TPARAMS%XHC_ROOF(K,4) = 1127845.62
    TPARAMS%XHC_ROOF(K,5) =   52030.
    TPARAMS%XTC_ROOF(K,1) = urb_hcon_rf(K)
    TPARAMS%XTC_ROOF(K,2) = urb_hcon_rf(K)
    TPARAMS%XTC_ROOF(K,3) = urb_hcon_rf(K)
    TPARAMS%XTC_ROOF(K,4) = 0.095454545
    TPARAMS%XTC_ROOF(K,5) = 0.03
    TPARAMS%XD_ROOF(K,1)  = 0.001
    TPARAMS%XD_ROOF(K,2)  = 0.098
    TPARAMS%XD_ROOF(K,3)  = 0.132
    TPARAMS%XD_ROOF(K,4)  = 0.098
    TPARAMS%XD_ROOF(K,5)  = 0.001
!
!* Road layers
    TPARAMS%XHC_ROAD(K,1) = urb_hcap_rd(K)
    TPARAMS%XHC_ROAD(K,2) = urb_hcap_rd(K)
    TPARAMS%XHC_ROAD(K,3) = 1989600.
    TPARAMS%XHC_ROAD(K,4) = 1640000.
    TPARAMS%XHC_ROAD(K,5) = 1400000.
    TPARAMS%XTC_ROAD(K,1) = urb_hcon_rd(K)
    TPARAMS%XTC_ROAD(K,2) = urb_hcon_rd(K)
    TPARAMS%XTC_ROAD(K,3) = 1.976584
    TPARAMS%XTC_ROAD(K,4) = 0.5915493
    TPARAMS%XTC_ROAD(K,5) = 0.4000
    TPARAMS%XD_ROAD(K,1)  = 0.001
    TPARAMS%XD_ROAD(K,2)  = 0.045296296
    TPARAMS%XD_ROAD(K,3)  = 0.092592593
    TPARAMS%XD_ROAD(K,4)  = 0.27777778
    TPARAMS%XD_ROAD(K,5)  = 0.83333333
!
!* Wall layers
    TPARAMS%XHC_WALL(K,1) = urb_hcap_wl(K)
    TPARAMS%XHC_WALL(K,2) = urb_hcap_wl(K)
    TPARAMS%XHC_WALL(K,3) = urb_hcap_wl(K)
    TPARAMS%XHC_WALL(K,4) = 1127845.6
    TPARAMS%XHC_WALL(K,5) =   52030.
    TPARAMS%XTC_WALL(K,1) = urb_hcon_wl(K)
    TPARAMS%XTC_WALL(K,2) = urb_hcon_wl(K)
    TPARAMS%XTC_WALL(K,3) = urb_hcon_wl(K)
    TPARAMS%XTC_WALL(K,4) = 0.095454545
    TPARAMS%XTC_WALL(K,5) = 0.03
    TPARAMS%XD_WALL(K,1)  = 0.001
    TPARAMS%XD_WALL(K,2)  = 0.098
    TPARAMS%XD_WALL(K,3)  = 0.132
    TPARAMS%XD_WALL(K,4)  = 0.098
    TPARAMS%XD_WALL(K,5)  = 0.001
!
!* Floor and internal mass layers
    BPARAMS%XHC_FLOOR(K,1) = 2016000.
    BPARAMS%XHC_FLOOR(K,2) = 2016000.
    BPARAMS%XHC_FLOOR(K,3) = 2016000.
    BPARAMS%XHC_FLOOR(K,4) = 2016000.
    BPARAMS%XHC_FLOOR(K,5) = 2016000.
    BPARAMS%XTC_FLOOR(K,1) = 1.95
    BPARAMS%XTC_FLOOR(K,2) = 1.95
    BPARAMS%XTC_FLOOR(K,3) = 1.95
    BPARAMS%XTC_FLOOR(K,4) = 1.95
    BPARAMS%XTC_FLOOR(K,5) = 1.95
    BPARAMS%XD_FLOOR(K,1)  = 0.001
    BPARAMS%XD_FLOOR(K,2)  = 0.0064074074
    BPARAMS%XD_FLOOR(K,3)  = 0.014814815
    BPARAMS%XD_FLOOR(K,4)  = 0.044444444
    BPARAMS%XD_FLOOR(K,5)  = 0.13333333
!
!* roughness coefficients (DOE-2 case)
    TPARAMS%XROUGH_ROOF(K) = 1.52
    TPARAMS%XROUGH_WALL(K) = 1.52
!
!* frontal area index and the annual-mean traffic flux
    TPARAMS%XFAI(K,:)            = fai(K,:)
    TPARAMS%XH_TRAFFIC_MEAN(K)   = ahf_traffic(K)
!
!* geometry fractions and sky-view factors
    ZROAD        = 1. - TPARAMS%XBLD(K) - TPARAMS%XGARDEN(K)
    ZWALL_O_HOR  = 2. * TPARAMS%XCAN_HW_RATIO(K) * (1. - TPARAMS%XBLD(K))
    TPARAMS%XSVF_ROAD(K)   = SQRT(TPARAMS%XCAN_HW_RATIO(K)**2 + 1.) - TPARAMS%XCAN_HW_RATIO(K)
    TPARAMS%XSVF_GARDEN(K) = TPARAMS%XSVF_ROAD(K)
    TPARAMS%XSVF_WALL(K)   = 0.5 * (TPARAMS%XCAN_HW_RATIO(K) + 1. - SQRT(TPARAMS%XCAN_HW_RATIO(K)**2 + 1.)) / TPARAMS%XCAN_HW_RATIO(K)
    ZTOTS_O_HORS  = 1. + ZWALL_O_HOR
    ZROAD_FRAC    = ZROAD      / ZTOTS_O_HORS
    ZWALL_FRAC    = ZWALL_O_HOR / ZTOTS_O_HORS
    ZGARDEN_FRAC  = TPARAMS%XGARDEN(K) / ZTOTS_O_HORS
    TPARAMS%XROAD(K)          = ZROAD
    TPARAMS%XWALL_O_HOR(K)    = ZWALL_O_HOR
    TPARAMS%XWALL_O_GRND(K)   = ZWALL_FRAC / (ZROAD_FRAC + ZGARDEN_FRAC)
    TPARAMS%XROAD_O_GRND(K)   = ZROAD / (ZROAD + TPARAMS%XGARDEN(K))
    TPARAMS%XGARDEN_O_GRND(K) = TPARAMS%XGARDEN(K) / (ZROAD + TPARAMS%XGARDEN(K))
!
!* BEM morphology (building view factors) and the window optics
    ZPFLOOR(1) = 3.0
    IF (ZPFLOOR(1) > TPARAMS%XBLD_HEIGHT(K)) ZPFLOOR(1) = TPARAMS%XBLD_HEIGHT(K)
    ZN_FLOOR(1) = FLOAT(NINT(TPARAMS%XBLD_HEIGHT(K) / ZPFLOOR(1)))
    ZF_WASTE_CAN(1) = 1.0
    CALL BEM_MORPHO_STRUCT(TPARAMS%XBLD(K:K), TPARAMS%XWALL_O_HOR(K:K), TPARAMS%XBLD_HEIGHT(K:K), ZPFLOOR, &
                           BPARAMS%XGR(K:K), ZN_FLOOR, ZWALL_O_BLD, ZGLAZ_O_BLD, ZMASS_O_BLD, &
                           ZFLOOR_HW_RATIO, ZF_FLOOR_MASS, ZF_FLOOR_WALL, ZF_FLOOR_WIN, &
                           ZF_FLOOR_ROOF, ZF_WALL_FLOOR, ZF_WALL_MASS, ZF_WALL_WIN, &
                           ZF_WIN_FLOOR, ZF_WIN_MASS, ZF_WIN_WALL, ZF_MASS_FLOOR, &
                           ZF_MASS_WALL, ZF_MASS_WIN, ZF_WASTE_CAN, ZF_WIN_WIN)
    BPARAMS%XN_FLOOR(K)        = ZN_FLOOR(1)
    TPARAMS%XWALL_O_BLD(K)     = ZWALL_O_BLD(1)
    BPARAMS%XGLAZ_O_BLD(K)     = ZGLAZ_O_BLD(1)
    BPARAMS%XMASS_O_BLD(K)     = ZMASS_O_BLD(1)
    BPARAMS%XFLOOR_HW_RATIO(K) = ZFLOOR_HW_RATIO(1)
    BPARAMS%XF_FLOOR_MASS(K)   = ZF_FLOOR_MASS(1)
    BPARAMS%XF_FLOOR_WALL(K)   = ZF_FLOOR_WALL(1)
    BPARAMS%XF_FLOOR_WIN(K)    = ZF_FLOOR_WIN(1)
    BPARAMS%XF_FLOOR_ROOF(K)   = ZF_FLOOR_ROOF(1)
    BPARAMS%XF_WALL_FLOOR(K)   = ZF_WALL_FLOOR(1)
    BPARAMS%XF_WALL_MASS(K)    = ZF_WALL_MASS(1)
    BPARAMS%XF_WALL_WIN(K)     = ZF_WALL_WIN(1)
    BPARAMS%XF_WIN_FLOOR(K)    = ZF_WIN_FLOOR(1)
    BPARAMS%XF_WIN_MASS(K)     = ZF_WIN_MASS(1)
    BPARAMS%XF_WIN_WALL(K)     = ZF_WIN_WALL(1)
    BPARAMS%XF_MASS_FLOOR(K)   = ZF_MASS_FLOOR(1)
    BPARAMS%XF_MASS_WALL(K)    = ZF_MASS_WALL(1)
    BPARAMS%XF_MASS_WIN(K)     = ZF_MASS_WIN(1)
    BPARAMS%XF_WIN_WIN(K)      = ZF_WIN_WIN(1)
    ! BPARAMS%XF_WASTE_CAN was set above; BEM_MORPHO_STRUCT passes it through
    ZSHGC(1)  = 0.763
    PU_WIN(1) = 2.716
    CALL WINDOW_DATA_STRUCT(1, ZSHGC, PU_WIN, BSTATE%XALB_WIN(K:K), ZABS_WIN, ZUGG_WIN, ZTRAN_WIN)
    BSTATE%XABS_WIN(K:K)  = ZABS_WIN
    BSTATE%XUGG_WIN(K:K)  = ZUGG_WIN
    BSTATE%XTRAN_WIN(K:K) = ZTRAN_WIN
!
!* z0 and zd from the namelist (URB_AERO_PARAMS, moved out of CALL_DRIVER)
    CALL URB_AERO_PARAMS(urb_z0_town, urb_zd_town, TPARAMS%XBLD_HEIGHT(K:K), TPARAMS%XBLD(K:K), TPARAMS%XFAI(K:K,:), ZZ0, ZZDU)
    TPARAMS%XZ0_TOWN(K) = ZZ0(1)
    TPARAMS%XZD_TOWN(K) = ZZDU(1)
    IF (TPARAMS%XZ0_TOWN(K) <= 0. .OR. TPARAMS%XZ0_TOWN(K) > 0.5*TPARAMS%XBLD_HEIGHT(K)) THEN
       WRITE(*,*) 'ERROR in CALL_DRIVER: urb_z0_town = ', TRIM(urb_z0_town), ' -> z0 = ', TPARAMS%XZ0_TOWN(K), ' m'
       WRITE(*,*) '   z0 must be in (0, 0.5*urb_h_bld], urb_h_bld = ', TPARAMS%XBLD_HEIGHT(K), ' m'
       STOP
    ENDIF
    IF (TPARAMS%XZD_TOWN(K) < 0. .OR. TPARAMS%XZD_TOWN(K) >= TPARAMS%XBLD_HEIGHT(K)) THEN
       WRITE(*,*) 'ERROR in CALL_DRIVER: urb_zd_town = ', TRIM(urb_zd_town), ' -> zd = ', TPARAMS%XZD_TOWN(K), ' m'
       WRITE(*,*) '   zd must be in [0, urb_h_bld), urb_h_bld = ', TPARAMS%XBLD_HEIGHT(K), ' m'
       STOP
    ENDIF
END DO
!
!* anthropogenic latent fluxes are zero in this version
TPARAMS%XLE_TRAFFIC  = 0.0
TPARAMS%XLE_INDUSTRY = 0.0
!
END SUBROUTINE TEB_FILL_DERIVED
!
!
!
!------------------------------------------------------------------------------
!*      1.3  FILL THE FORCING CONTAINER OF THE SUB-STEP
!------------------------------------------------------------------------------
SUBROUTINE TEB_FILL_FORCING (KSTART, KEND, KYEAR, KMONTH, KDAY, PZTIME, &
                             PLON, PLAT, PU, PV, PTA, PQA, PPS, &
                             PRAIN_CONV, PSNOW_CONV, PRAIN_LSP, PSNOW_LSP, PGRAUPEL, &
                             PLW, PDIR_SW, PDIF_SW, PZREF, PUREF)
!!****  *TEB_FILL_FORCING* - fill the forcing container of one sub-step
!!
!!    The raw forcing of the window KSTART:KEND is copied from the host arrays
!!    and the derived quantities are computed here, once per sub-step: the
!!    pressure, the Exner functions and the density at the forcing level, the
!!    wind speed, the solar time and the sun position (SUNPOS) and the direct /
!!    diffuse partition of the circumsolar model (CIRCUMSOLAR_RAD).
!!
!!    The formulas, their order and the XUNDEF fallbacks are the ones of
!!    CALL_DRIVER before the container existed, so that the forcing seen by the
!!    physics is bit-for-bit the same.
!!
INTEGER,            INTENT(IN) :: KSTART, KEND           ! window of the block
INTEGER,            INTENT(IN) :: KYEAR, KMONTH, KDAY    ! date (UTC)
REAL,               INTENT(IN) :: PZTIME                 ! time of the day  (s)
REAL, DIMENSION(:), INTENT(IN) :: PLON, PLAT             ! coordinates      (deg)
REAL, DIMENSION(:), INTENT(IN) :: PU, PV                 ! wind             (m/s)
REAL, DIMENSION(:), INTENT(IN) :: PTA, PQA, PPS          ! T, qv, pressure
REAL, DIMENSION(:), INTENT(IN) :: PRAIN_CONV, PSNOW_CONV, PRAIN_LSP, PSNOW_LSP, PGRAUPEL
REAL, DIMENSION(:), INTENT(IN) :: PLW, PDIR_SW, PDIF_SW  ! radiation        (W/m2)
REAL, DIMENSION(:), INTENT(IN) :: PZREF, PUREF           ! forcing heights  (m)
!
REAL, DIMENSION(SIZE(PTA)) :: ZF1_O_B   ! circumsolar partition coefficient (-)
REAL, DIMENSION(SIZE(PTA)) :: ZCOEF     ! horizon correction of the direct beam (-)
!
!* the offline host provides no orography: SURFEX initialises it to XUNDEF and
!* the historical fallback of the pressure therefore keeps its behaviour
FORC%XZS(KSTART:KEND) = XUNDEF
!
!* raw forcing, then the density and the pressure of the forcing level (these
!* two do not use the fallback below: the order is the one of the former block)
FORC%XTA  (KSTART:KEND) = PTA(KSTART:KEND)
FORC%XPS  (KSTART:KEND) = PPS(KSTART:KEND)
FORC%XZREF(KSTART:KEND) = PZREF(KSTART:KEND)
FORC%XUREF(KSTART:KEND) = PUREF(KSTART:KEND)
FORC%XQA  (KSTART:KEND) = PQA(KSTART:KEND)
FORC%XRHOA(KSTART:KEND) = FORC%XPS(KSTART:KEND)                                         &
    / ( FORC%XTA(KSTART:KEND)*XRD*(1.+((XRV/XRD)-1.)*PQA(KSTART:KEND))                  &
        + FORC%XZREF(KSTART:KEND)*XG )
!
!* precipitation, pressure, wind and radiation of the forcing level
FORC%XSNOW(KSTART:KEND) = PSNOW_CONV(KSTART:KEND) + PSNOW_LSP(KSTART:KEND) + PGRAUPEL(KSTART:KEND)
FORC%XRAIN(KSTART:KEND) = PRAIN_CONV(KSTART:KEND) + PRAIN_LSP(KSTART:KEND)
FORC%XPA  (KSTART:KEND) = FORC%XPS(KSTART:KEND) - FORC%XRHOA(KSTART:KEND)*XG*FORC%XZREF(KSTART:KEND)
FORC%XCO2 (KSTART:KEND) = 0.
FORC%XU   (KSTART:KEND) = PU(KSTART:KEND)
FORC%XV   (KSTART:KEND) = PV(KSTART:KEND)
FORC%XLW  (KSTART:KEND) = PLW(KSTART:KEND)
FORC%XDIR_SW(KSTART:KEND,1) = PDIR_SW(KSTART:KEND)
FORC%XSCA_SW(KSTART:KEND,1) = PDIF_SW(KSTART:KEND)
!
!* missing-value fallbacks (the same conditions as in CALL_DRIVER: they act on
!* the whole window when any point carries XUNDEF)
IF (MINVAL(FORC%XPS(KSTART:KEND)) == XUNDEF) THEN
   FORC%XPS(KSTART:KEND) = 101325.*(1.-0.0065*FORC%XZS(KSTART:KEND)/288.15)**5.31
END IF
IF (MINVAL(FORC%XDIR_SW(KSTART:KEND,1)) == XUNDEF) FORC%XDIR_SW(KSTART:KEND,1) = 0.
IF (MINVAL(FORC%XSCA_SW(KSTART:KEND,1)) == XUNDEF) FORC%XSCA_SW(KSTART:KEND,1) = 0.
!
!* Exner functions and wind speed
FORC%XEXNS(KSTART:KEND) = (FORC%XPS(KSTART:KEND)/XP00)**(XRD/XCPD)
FORC%XEXNA(KSTART:KEND) = (FORC%XPA(KSTART:KEND)/XP00)**(XRD/XCPD)
FORC%XVMOD(KSTART:KEND) = SQRT(FORC%XU(KSTART:KEND)**2 + FORC%XV(KSTART:KEND)**2)
!
!* sun position
CALL SUNPOS(KYEAR, KMONTH, KDAY, PZTIME, PLON(KSTART:KEND), PLAT(KSTART:KEND), &
            FORC%XTSUN(KSTART:KEND), FORC%XZENITH(KSTART:KEND), FORC%XAZIM(KSTART:KEND))
!
!* coherence between the zenith angle and the radiation: when the sun is close to
!* the horizon the direct beam is transferred to the scattered one
ZCOEF(KSTART:KEND) = (XPI/2. - FORC%XZENITH(KSTART:KEND) - 0.05) / 0.05
ZCOEF(KSTART:KEND) = MAX(MIN(ZCOEF(KSTART:KEND),1.),0.)
FORC%XSCA_SW(KSTART:KEND,1) = FORC%XSCA_SW(KSTART:KEND,1)                               &
                              + FORC%XDIR_SW(KSTART:KEND,1) * (1. - ZCOEF(KSTART:KEND))
FORC%XDIR_SW(KSTART:KEND,1) = FORC%XDIR_SW(KSTART:KEND,1) * ZCOEF(KSTART:KEND)
!
!* directional contribution of the scattered radiation (circumsolar model)
CALL CIRCUMSOLAR_RAD(FORC%XDIR_SW(KSTART:KEND,1), FORC%XSCA_SW(KSTART:KEND,1), &
                     FORC%XZENITH(KSTART:KEND), ZF1_O_B(KSTART:KEND))
FORC%XDIR_SW(KSTART:KEND,1) = FORC%XDIR_SW(KSTART:KEND,1)                               &
                              + FORC%XSCA_SW(KSTART:KEND,1) * ZF1_O_B(KSTART:KEND)
FORC%XSCA_SW(KSTART:KEND,1) = FORC%XSCA_SW(KSTART:KEND,1) * (1. - ZF1_O_B(KSTART:KEND))
!
END SUBROUTINE TEB_FILL_FORCING
!
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
   CALL ALLOC_TEB_STRUCT(KROOF, KROAD, KWALL, KFLOOR, TOPTS, TSTATE, BOPTS, BSTATE, TPN, TIR)
   CALL ALLOC_TEB_PARAMS(TPARAMS, KROOF, KROAD, KWALL)
   CALL ALLOC_BEM_PARAMS(BPARAMS, KFLOOR)
   CALL DIAG_MISC_TEB_ALLOC(DMT, KNVEC)
   CALL ALLOC_TEB_FORCING(FORC, KNVEC)
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
   CALL DEALLOC_TEB_STRUCT(TOPTS, TSTATE, BOPTS, BSTATE, TPN, TIR)
   CALL DEALLOC_TEB_PARAMS(TPARAMS)
   CALL DEALLOC_BEM_PARAMS(BPARAMS)
   CALL DIAG_MISC_TEB_DEALLOC(DMT)
   CALL DEALLOC_TEB_FORCING(FORC)
   LTEB_HOST_ALLOC = .FALSE.
END IF
!
END SUBROUTINE TEB_HOST_FINAL
!
SUBROUTINE TEB_BIND_STATE (KSTART, KEND, teb_ti_bld, teb_twin2, teb_qi_bld, teb_cap_sys_rat, teb_m_sys_rat, teb_twin1, teb_lshade, teb_shad_day, teb_natvent_night, teb_ws_roof, teb_troof, teb_troad, teb_twalla, teb_twallb, teb_wsnow_roof, teb_tsnow_roof, teb_rsnow_roof, teb_asnow_roof, teb_esnow_roof, teb_tssnow_roof, teb_wsnow_road, teb_tsnow_road, teb_rsnow_road, teb_asnow_road, teb_esnow_road, teb_tssnow_road, teb_tcanyon, teb_qcanyon, teb_ws_road, teb_tfloor, teb_tmass)
!
INTEGER, INTENT(IN) :: KSTART, KEND
REAL, DIMENSION(:), INTENT(INOUT) :: teb_ti_bld
REAL, DIMENSION(:), INTENT(INOUT) :: teb_twin2
REAL, DIMENSION(:), INTENT(INOUT) :: teb_qi_bld
REAL, DIMENSION(:), INTENT(INOUT) :: teb_cap_sys_rat
REAL, DIMENSION(:), INTENT(INOUT) :: teb_m_sys_rat
REAL, DIMENSION(:), INTENT(INOUT) :: teb_twin1
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
REAL, DIMENSION(:), INTENT(INOUT) :: teb_tcanyon
REAL, DIMENSION(:), INTENT(INOUT) :: teb_qcanyon
REAL, DIMENSION(:), INTENT(INOUT) :: teb_ws_road
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_tfloor
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_tmass
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
    TSTATE%XT_CANYON(KSTART:KEND)                   = teb_tcanyon(KSTART:KEND)
    TSTATE%XQ_CANYON(KSTART:KEND)                   = teb_qcanyon(KSTART:KEND)
    TSTATE%XWS_ROAD(KSTART:KEND)                    = teb_ws_road(KSTART:KEND)
    BSTATE%XT_FLOOR(KSTART:KEND,:)                  = teb_tfloor(KSTART:KEND,:)
    BSTATE%XT_MASS(KSTART:KEND,:)                   = teb_tmass(KSTART:KEND,:)
!
END SUBROUTINE TEB_BIND_STATE
!
SUBROUTINE TEB_UNBIND_STATE (KSTART, KEND, teb_ti_bld, teb_twin2, teb_qi_bld, teb_cap_sys_rat, teb_m_sys_rat, teb_twin1, teb_lshade, teb_shad_day, teb_natvent_night, teb_ws_roof, teb_troof, teb_troad, teb_twalla, teb_twallb, teb_wsnow_roof, teb_tsnow_roof, teb_rsnow_roof, teb_asnow_roof, teb_esnow_roof, teb_tssnow_roof, teb_wsnow_road, teb_tsnow_road, teb_rsnow_road, teb_asnow_road, teb_esnow_road, teb_tssnow_road, teb_tcanyon, teb_qcanyon, teb_ws_road, teb_tfloor, teb_tmass, teb_albwin)
!
INTEGER, INTENT(IN) :: KSTART, KEND
REAL, DIMENSION(:), INTENT(INOUT) :: teb_ti_bld
REAL, DIMENSION(:), INTENT(INOUT) :: teb_twin2
REAL, DIMENSION(:), INTENT(INOUT) :: teb_qi_bld
REAL, DIMENSION(:), INTENT(INOUT) :: teb_cap_sys_rat
REAL, DIMENSION(:), INTENT(INOUT) :: teb_m_sys_rat
REAL, DIMENSION(:), INTENT(INOUT) :: teb_twin1
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
REAL, DIMENSION(:), INTENT(INOUT) :: teb_tcanyon
REAL, DIMENSION(:), INTENT(INOUT) :: teb_qcanyon
REAL, DIMENSION(:), INTENT(INOUT) :: teb_ws_road
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_tfloor
REAL, DIMENSION(:,:), INTENT(INOUT) :: teb_tmass
REAL, DIMENSION(:), INTENT(INOUT) :: teb_albwin
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
    teb_tcanyon(KSTART:KEND)                        = TSTATE%XT_CANYON(KSTART:KEND)
    teb_qcanyon(KSTART:KEND)                        = TSTATE%XQ_CANYON(KSTART:KEND)
    teb_ws_road(KSTART:KEND)                        = TSTATE%XWS_ROAD(KSTART:KEND)
    teb_tfloor(KSTART:KEND,:)                       = BSTATE%XT_FLOOR(KSTART:KEND,:)
    teb_tmass(KSTART:KEND,:)                        = BSTATE%XT_MASS(KSTART:KEND,:)
    teb_albwin(KSTART:KEND)                         = BSTATE%XALB_WIN(KSTART:KEND)
!
END SUBROUTINE TEB_UNBIND_STATE
!
END MODULE TEB_HOST
