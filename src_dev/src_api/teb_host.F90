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
USE MODI_URB_AERO_PARAMS,   ONLY : URB_AERO_PARAMS
USE MODI_BEM_MORPHO_STRUCT, ONLY : BEM_MORPHO_STRUCT
USE MODI_WINDOW_DATA_STRUCT, ONLY : WINDOW_DATA_STRUCT
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
                            ahf_industry, teb_itype_wind, teb_utc_hour, &
                            teb_lgreenroof_ext, teb_lbem_ac)
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
LOGICAL, INTENT(IN) :: teb_lgreenroof_ext, teb_lbem_ac
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
    BOP%LBEM_AC              = teb_lbem_ac
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
    TOP%ITYPE_WIND          = teb_itype_wind
    TOP%NUTC_HOUR           = teb_utc_hour
    TOP%LGREENROOF_EXT      = teb_lgreenroof_ext
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
!* TP/BP/TOP/BOP here, so that CALL_DRIVER does not derive statics any more
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
BP%XQIN          = 5.8
BP%XQIN_FRAD     = 0.2
BP%XQIN_FLAT     = 0.2
BP%XSHGC         = 0.763
BP%XSHGC_SH      = 0.025
BP%XF_WATER_COND = 0.
BP%XF_WASTE_CAN  = 1.0
BP%XEFF_HEAT     = 0.9
BP%XHR_TARGET    = 0.5
TOP%CCH_BEM      = ' '
BOP%LAUTOSIZE    = .FALSE.
!MV202609 z0 and zd to namelist
TOP%CZ0H         = 'MASC95'
!
DO K = KSTART, KEND
!
!* Roof layers
    TP%XHC_ROOF(K,1) = urb_hcap_rf(K)
    TP%XHC_ROOF(K,2) = urb_hcap_rf(K)
    TP%XHC_ROOF(K,3) = urb_hcap_rf(K)
    TP%XHC_ROOF(K,4) = 1127845.62
    TP%XHC_ROOF(K,5) =   52030.
    TP%XTC_ROOF(K,1) = urb_hcon_rf(K)
    TP%XTC_ROOF(K,2) = urb_hcon_rf(K)
    TP%XTC_ROOF(K,3) = urb_hcon_rf(K)
    TP%XTC_ROOF(K,4) = 0.095454545
    TP%XTC_ROOF(K,5) = 0.03
    TP%XD_ROOF(K,1)  = 0.001
    TP%XD_ROOF(K,2)  = 0.098
    TP%XD_ROOF(K,3)  = 0.132
    TP%XD_ROOF(K,4)  = 0.098
    TP%XD_ROOF(K,5)  = 0.001
!
!* Road layers
    TP%XHC_ROAD(K,1) = urb_hcap_rd(K)
    TP%XHC_ROAD(K,2) = urb_hcap_rd(K)
    TP%XHC_ROAD(K,3) = 1989600.
    TP%XHC_ROAD(K,4) = 1640000.
    TP%XHC_ROAD(K,5) = 1400000.
    TP%XTC_ROAD(K,1) = urb_hcon_rd(K)
    TP%XTC_ROAD(K,2) = urb_hcon_rd(K)
    TP%XTC_ROAD(K,3) = 1.976584
    TP%XTC_ROAD(K,4) = 0.5915493
    TP%XTC_ROAD(K,5) = 0.4000
    TP%XD_ROAD(K,1)  = 0.001
    TP%XD_ROAD(K,2)  = 0.045296296
    TP%XD_ROAD(K,3)  = 0.092592593
    TP%XD_ROAD(K,4)  = 0.27777778
    TP%XD_ROAD(K,5)  = 0.83333333
!
!* Wall layers
    TP%XHC_WALL(K,1) = urb_hcap_wl(K)
    TP%XHC_WALL(K,2) = urb_hcap_wl(K)
    TP%XHC_WALL(K,3) = urb_hcap_wl(K)
    TP%XHC_WALL(K,4) = 1127845.6
    TP%XHC_WALL(K,5) =   52030.
    TP%XTC_WALL(K,1) = urb_hcon_wl(K)
    TP%XTC_WALL(K,2) = urb_hcon_wl(K)
    TP%XTC_WALL(K,3) = urb_hcon_wl(K)
    TP%XTC_WALL(K,4) = 0.095454545
    TP%XTC_WALL(K,5) = 0.03
    TP%XD_WALL(K,1)  = 0.001
    TP%XD_WALL(K,2)  = 0.098
    TP%XD_WALL(K,3)  = 0.132
    TP%XD_WALL(K,4)  = 0.098
    TP%XD_WALL(K,5)  = 0.001
!
!* Floor and internal mass layers
    BP%XHC_FLOOR(K,1) = 2016000.
    BP%XHC_FLOOR(K,2) = 2016000.
    BP%XHC_FLOOR(K,3) = 2016000.
    BP%XHC_FLOOR(K,4) = 2016000.
    BP%XHC_FLOOR(K,5) = 2016000.
    BP%XTC_FLOOR(K,1) = 1.95
    BP%XTC_FLOOR(K,2) = 1.95
    BP%XTC_FLOOR(K,3) = 1.95
    BP%XTC_FLOOR(K,4) = 1.95
    BP%XTC_FLOOR(K,5) = 1.95
    BP%XD_FLOOR(K,1)  = 0.001
    BP%XD_FLOOR(K,2)  = 0.0064074074
    BP%XD_FLOOR(K,3)  = 0.014814815
    BP%XD_FLOOR(K,4)  = 0.044444444
    BP%XD_FLOOR(K,5)  = 0.13333333
!
!* roughness coefficients (DOE-2 case)
    TP%XROUGH_ROOF(K) = 1.52
    TP%XROUGH_WALL(K) = 1.52
!
!* frontal area index and the annual-mean traffic flux
    TP%XFAI(K,:)            = fai(K,:)
    TP%XH_TRAFFIC_MEAN(K)   = ahf_traffic(K)
!
!* geometry fractions and sky-view factors
    ZROAD        = 1. - TP%XBLD(K) - TP%XGARDEN(K)
    ZWALL_O_HOR  = 2. * TP%XCAN_HW_RATIO(K) * (1. - TP%XBLD(K))
    TP%XSVF_ROAD(K)   = SQRT(TP%XCAN_HW_RATIO(K)**2 + 1.) - TP%XCAN_HW_RATIO(K)
    TP%XSVF_GARDEN(K) = TP%XSVF_ROAD(K)
    TP%XSVF_WALL(K)   = 0.5 * (TP%XCAN_HW_RATIO(K) + 1. - SQRT(TP%XCAN_HW_RATIO(K)**2 + 1.)) / TP%XCAN_HW_RATIO(K)
    ZTOTS_O_HORS  = 1. + ZWALL_O_HOR
    ZROAD_FRAC    = ZROAD      / ZTOTS_O_HORS
    ZWALL_FRAC    = ZWALL_O_HOR / ZTOTS_O_HORS
    ZGARDEN_FRAC  = TP%XGARDEN(K) / ZTOTS_O_HORS
    TP%XROAD(K)          = ZROAD
    TP%XWALL_O_HOR(K)    = ZWALL_O_HOR
    TP%XWALL_O_GRND(K)   = ZWALL_FRAC / (ZROAD_FRAC + ZGARDEN_FRAC)
    TP%XROAD_O_GRND(K)   = ZROAD / (ZROAD + TP%XGARDEN(K))
    TP%XGARDEN_O_GRND(K) = TP%XGARDEN(K) / (ZROAD + TP%XGARDEN(K))
!
!* BEM morphology (building view factors) and the window optics
    ZPFLOOR(1) = 3.0
    IF (ZPFLOOR(1) > TP%XBLD_HEIGHT(K)) ZPFLOOR(1) = TP%XBLD_HEIGHT(K)
    ZN_FLOOR(1) = FLOAT(NINT(TP%XBLD_HEIGHT(K) / ZPFLOOR(1)))
    ZF_WASTE_CAN(1) = 1.0
    CALL BEM_MORPHO_STRUCT(TP%XBLD(K:K), TP%XWALL_O_HOR(K:K), TP%XBLD_HEIGHT(K:K), ZPFLOOR, &
                           BP%XGR(K:K), ZN_FLOOR, ZWALL_O_BLD, ZGLAZ_O_BLD, ZMASS_O_BLD, &
                           ZFLOOR_HW_RATIO, ZF_FLOOR_MASS, ZF_FLOOR_WALL, ZF_FLOOR_WIN, &
                           ZF_FLOOR_ROOF, ZF_WALL_FLOOR, ZF_WALL_MASS, ZF_WALL_WIN, &
                           ZF_WIN_FLOOR, ZF_WIN_MASS, ZF_WIN_WALL, ZF_MASS_FLOOR, &
                           ZF_MASS_WALL, ZF_MASS_WIN, ZF_WASTE_CAN, ZF_WIN_WIN)
    BP%XN_FLOOR(K)        = ZN_FLOOR(1)
    TP%XWALL_O_BLD(K)     = ZWALL_O_BLD(1)
    BP%XGLAZ_O_BLD(K)     = ZGLAZ_O_BLD(1)
    BP%XMASS_O_BLD(K)     = ZMASS_O_BLD(1)
    BP%XFLOOR_HW_RATIO(K) = ZFLOOR_HW_RATIO(1)
    BP%XF_FLOOR_MASS(K)   = ZF_FLOOR_MASS(1)
    BP%XF_FLOOR_WALL(K)   = ZF_FLOOR_WALL(1)
    BP%XF_FLOOR_WIN(K)    = ZF_FLOOR_WIN(1)
    BP%XF_FLOOR_ROOF(K)   = ZF_FLOOR_ROOF(1)
    BP%XF_WALL_FLOOR(K)   = ZF_WALL_FLOOR(1)
    BP%XF_WALL_MASS(K)    = ZF_WALL_MASS(1)
    BP%XF_WALL_WIN(K)     = ZF_WALL_WIN(1)
    BP%XF_WIN_FLOOR(K)    = ZF_WIN_FLOOR(1)
    BP%XF_WIN_MASS(K)     = ZF_WIN_MASS(1)
    BP%XF_WIN_WALL(K)     = ZF_WIN_WALL(1)
    BP%XF_MASS_FLOOR(K)   = ZF_MASS_FLOOR(1)
    BP%XF_MASS_WALL(K)    = ZF_MASS_WALL(1)
    BP%XF_MASS_WIN(K)     = ZF_MASS_WIN(1)
    BP%XF_WIN_WIN(K)      = ZF_WIN_WIN(1)
    ! BP%XF_WASTE_CAN was set above; BEM_MORPHO_STRUCT passes it through
    ZSHGC(1)  = 0.763
    PU_WIN(1) = 2.716
    CALL WINDOW_DATA_STRUCT(1, ZSHGC, PU_WIN, BSTATE%XALB_WIN(K:K), ZABS_WIN, ZUGG_WIN, ZTRAN_WIN)
    BSTATE%XABS_WIN(K:K)  = ZABS_WIN
    BSTATE%XUGG_WIN(K:K)  = ZUGG_WIN
    BSTATE%XTRAN_WIN(K:K) = ZTRAN_WIN
!
!* z0 and zd from the namelist (URB_AERO_PARAMS, moved out of CALL_DRIVER)
    CALL URB_AERO_PARAMS(urb_z0_town, urb_zd_town, TP%XBLD_HEIGHT(K:K), TP%XBLD(K:K), TP%XFAI(K:K,:), ZZ0, ZZDU)
    TP%XZ0_TOWN(K) = ZZ0(1)
    TP%XZD_TOWN(K) = ZZDU(1)
    IF (TP%XZ0_TOWN(K) <= 0. .OR. TP%XZ0_TOWN(K) > 0.5*TP%XBLD_HEIGHT(K)) THEN
       WRITE(*,*) 'ERROR in CALL_DRIVER: urb_z0_town = ', TRIM(urb_z0_town), ' -> z0 = ', TP%XZ0_TOWN(K), ' m'
       WRITE(*,*) '   z0 must be in (0, 0.5*urb_h_bld], urb_h_bld = ', TP%XBLD_HEIGHT(K), ' m'
       STOP
    ENDIF
    IF (TP%XZD_TOWN(K) < 0. .OR. TP%XZD_TOWN(K) >= TP%XBLD_HEIGHT(K)) THEN
       WRITE(*,*) 'ERROR in CALL_DRIVER: urb_zd_town = ', TRIM(urb_zd_town), ' -> zd = ', TP%XZD_TOWN(K), ' m'
       WRITE(*,*) '   zd must be in [0, urb_h_bld), urb_h_bld = ', TP%XBLD_HEIGHT(K), ' m'
       STOP
    ENDIF
END DO
!
!* anthropogenic latent fluxes are zero in this version
TP%XLE_TRAFFIC  = 0.0
TP%XLE_INDUSTRY = 0.0
!
END SUBROUTINE TEB_FILL_DERIVED
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
