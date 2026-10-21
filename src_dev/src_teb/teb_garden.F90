!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!     #########
    SUBROUTINE TEB_GARDEN (icell, iblock, TOPTS, TSTATE, BOPTS, BSTATE, TPN, TIR, DMT, &
      OGREENROOF_EXT, HIMPLICIT_WIND, PBEM_AC, FORC, HSNOW_ROOF, HSNOW_ROAD, PPEW_A_COEF, &
      PPEW_B_COEF, PPEW_A_COEF_LOWCAN, PPEW_B_COEF_LOWCAN, PZ0_GARDEN_EXT, KSW, PH_TRAFFIC, &
      PTSTEP, KDAY, PTIME, PZ0_GR_EXT, PALB_GR_EXT, PEMIS_GR_EXT, PTSRAD_GR_EXT, PQV_GR_EXT, &
      PH_GR_EXT, PLE_GR_EXT, PEVAP_GR_EXT, PRUNOFF_GR_EXT, PALB_GD_EXT, PEMIS_GD_EXT, &
      PTSRAD_GD_EXT, PQV_GD_EXT, PH_GD_EXT, PLE_GD_EXT, PEVAP_GD_EXT, PCH_GD, PCD_GD, &
      PRUNOFF_GD_EXT, TPARAMS, BPARAMS)
!   ##########################################################################
!
!!****  *TEB_GARDEN*  
!!
!!    PURPOSE
!!    -------
!
!     
!!**  METHOD
!     ------
!
!
!!    EXTERNAL
!!    --------
!!
!!
!!    IMPLICIT ARGUMENTS
!!    ------------------
!!
!!      
!!    REFERENCE
!!    ---------
!!
!!      
!!    AUTHOR
!!    ------
!!
!!      A. Lemonsu          * Meteo-France *
!!
!!    MODIFICATIONS
!!    -------------
!!    Original    05/2009
!!                04/2012 add BSTATE%XTRAN_WIN
!!    modified    08/2012 TOPTS%CCH_BEM/ ROUGH_WALL and ROUGH_ROOF for buildind conv coef.
!!    modified    10/2012 add BPARAMS%XF_WIN_WIN as arg
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_n, ONLY : TEB_t
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t
USE MODD_BEM_n, ONLY : BEM_t
USE MODD_TEB_PANEL_n, ONLY : TEB_PANEL_t
USE MODD_TEB_IRRIG_n, ONLY : TEB_IRRIG_t
USE MODD_TEB_FORCING_n, ONLY : TEB_FORCING_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
!
USE MODD_TYPE_DATE_SURF,    ONLY: DATE_TIME
USE MODD_CSTS,              ONLY: XTT, XSTEFAN
USE MODD_SURF_PAR,          ONLY: XUNDEF, teb_snow_check
USE MODD_SNOW_PAR,          ONLY: XEMISSN, XANSMAX
!
USE MODE_THERMOS
USE MODE_SURF_SNOW_FRAC
!
USE MODI_SOLAR_PANEL
USE MODI_TEB_VEG_PROPERTIES
USE MODI_WINDOW_SHADING_AVAILABILITY
USE MODI_URBAN_SOLAR_ABS
USE MODI_URBAN_LW_COEF
USE MODI_GARDEN
!MV202609 garden thermal roughness (z0h)
!* neutral formulation of the garden exchange coefficients (single source
!* shared with URBAN_DRAG and with the emulator of the offline driver)
USE MODE_GARDEN_BALANCE, ONLY : GARDEN_PCD_NEUTRAL, GARDEN_PCH_NEUTRAL
USE MODI_GREENROOF
USE MODI_TEB
USE MODI_AVG_URBAN_FLUXES
USE MODI_BLD_OCC_CALENDAR
!
USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
USE PARKIND1  ,ONLY : JPRB
!
USE MODD_TEB_PARAMS_n, ONLY : TEB_PARAMS_t
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t
IMPLICIT NONE
TYPE(TEB_PARAMS_t), INTENT(IN) :: TPARAMS
TYPE(BEM_PARAMS_t), INTENT(INOUT) :: BPARAMS

!
!*      0.1    Declarations of arguments

INTEGER                           :: icell
INTEGER                           :: iblock 
!
TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: TOPTS
TYPE(TEB_t), INTENT(INOUT) :: TSTATE
TYPE(BEM_OPTIONS_t), INTENT(INOUT) :: BOPTS
TYPE(BEM_t), INTENT(INOUT) :: BSTATE
TYPE(TEB_PANEL_t), INTENT(INOUT) :: TPN
TYPE(TEB_IRRIG_t), INTENT(INOUT) :: TIR
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT
!
 LOGICAL,              INTENT(IN)  :: OGREENROOF_EXT      ! Flag to use EXTERNAL greenroof model 
 CHARACTER(LEN=*),     INTENT(IN)  :: HIMPLICIT_WIND      ! wind implicitation option
!                                                         ! 'OLD' = direct
															! 'NEW' = Taylor serie, order 1
!  

TYPE(TEB_FORCING_t),  INTENT(IN)    :: FORC               ! atmospheric forcing of the sub-step
LOGICAL,INTENT(IN)                  :: PBEM_AC            ! Flag to use air conditioners
 CHARACTER(LEN=*)    , INTENT(IN)    :: HSNOW_ROOF         ! snow roof scheme 'NONE', 'D95 ', '1-L '
 CHARACTER(LEN=*)    , INTENT(IN)    :: HSNOW_ROAD         ! snow road scheme 'NONE', 'D95 ', '1-L '
!                                                         
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_A_COEF        ! implicit coefficients
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_B_COEF        ! for wind coupling
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_A_COEF_LOWCAN ! implicit coefficients for wind coupling
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_B_COEF_LOWCAN ! between low canyon wind and road
REAL, DIMENSION(:)  , INTENT(IN)    :: PZ0_GARDEN_EXT     ! garden roughness length (external model)
INTEGER,              INTENT(IN)    :: KSW                ! number of short-wave spectral bands
                                                          ! (radian form N, clockwise)
REAL, DIMENSION(:)  , INTENT(IN)    :: PH_TRAFFIC         ! anthropogenic sensible heat fluxes due to traffic
REAL                , INTENT(IN)    :: PTSTEP             ! time step
!
REAL, DIMENSION(:)  , INTENT(IN)    :: PZ0_GR_EXT         ! green roof roughness length (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PALB_GR_EXT        ! green roof albedo
REAL, DIMENSION(:)  , INTENT(IN)    :: PEMIS_GR_EXT       ! green roof emissivity 
REAL, DIMENSION(:)  , INTENT(IN)    :: PTSRAD_GR_EXT      ! greenroof radiative surface temp. (snow free)
REAL, DIMENSION(:)  , INTENT(IN)    :: PQV_GR_EXT         ! greenroof specific humidity (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PH_GR_EXT          ! sensible heat flux over greenroofs 
REAL, DIMENSION(:)  , INTENT(IN)    :: PLE_GR_EXT         ! latent heat flux over greenroofs 
REAL, DIMENSION(:)  , INTENT(IN)    :: PEVAP_GR_EXT       ! total evaporation over greenroofs (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(IN)    :: PRUNOFF_GR_EXT     ! greenroof surface runoff
! COSMO + TEB GARDEN
REAL, DIMENSION(:)  , INTENT(IN)    :: PALB_GD_EXT        ! garden albedo (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PEMIS_GD_EXT       ! garden emissivity  (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PTSRAD_GD_EXT      ! garden radiative surface temp. (snow free) (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PQV_GD_EXT         ! garden specific humidity (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PH_GD_EXT          ! sensible heat flux over garden (external model) 
REAL, DIMENSION(:)  , INTENT(IN)    :: PLE_GD_EXT         ! latent heat flux over garden (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PEVAP_GD_EXT       ! total evaporation over garden (kg/m2/s) (external model)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_GD             ! drag coeifficient for heat
REAL, DIMENSION(:)  , INTENT(INOUT)   :: PCD_GD             ! garden  surf. exchange coefficient
REAL, DIMENSION(:)  , INTENT(IN)    :: PRUNOFF_GD_EXT     ! garden surface runoff (external model)




!
!MV202609 CBS scheme of the road (revision: snow-to-atmosphere branch)
!* INOUT: the canyon air nodes of TEB_GARDEN2 read these branch diagnostics
!* (AVG_URBAN_FLUXES) BEFORE the snow scheme of TEB writes them, so they carry the
!* value of the previous sub-step (they are persistent in DMT)
!
!
! new arguments created after BEM
!
INTEGER             , INTENT(IN)    :: KDAY               ! Simulation day
! new argument for the UTCI calculation
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!MV202609 CBS scheme of the road
!MV202609 CBS scheme of the road (revision: puddle diagnostics)
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
!MV202609 CBS scheme of the road (revision: three-temperature construction)
!MV202609 garden diagnostics
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
!* potential garden fluxes per m2 of garden (see GARDEN): the flux that the single
!* garden surface would release if the whole exchange went through the canyon air
!* (CAN) or directly to the air of the forcing level (ATM). Diagnostics only.
!MV202609 greenroof diagnostics
!MV202609 greenroof-to-atm exchange diagnostics (from URBAN_DRAG)
!
! new arguments for shading, schedule or natural ventilation
REAL                , INTENT(IN)     :: PTIME             ! current time since midnight (UTC, s)
!
!* arguments for solar panels
!
!
!*      0.2    Declarations of local variables
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZTA            ! air temperature extrapolated at roof level
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZQA            ! air humidity extrapolated at roof level
REAL, DIMENSION(SIZE(FORC%XTA)) :: PLEW_RF
REAL, DIMENSION(SIZE(FORC%XTA)) :: PLEW_RD
REAL, DIMENSION(SIZE(FORC%XTA)) :: PLE_WL_A
REAL, DIMENSION(SIZE(FORC%XTA)) :: PLE_WL_B
REAL, DIMENSION(SIZE(FORC%XTA)) :: PRNSN_RF
REAL, DIMENSION(SIZE(FORC%XTA)) :: PGSN_RF
REAL, DIMENSION(SIZE(FORC%XTA)) :: PMELT_RF
REAL, DIMENSION(SIZE(FORC%XTA)) :: PRNSN_RD
REAL, DIMENSION(SIZE(FORC%XTA)) :: PGSN_RD
REAL, DIMENSION(SIZE(FORC%XTA)) :: PMELT_RD
REAL, DIMENSION(SIZE(FORC%XTA)) :: PRN_GRND
REAL, DIMENSION(SIZE(FORC%XTA)) :: PH_GRND
REAL, DIMENSION(SIZE(FORC%XTA)) :: PLE_GRND
REAL, DIMENSION(SIZE(FORC%XTA)) :: PGFLX_GRND
REAL, DIMENSION(SIZE(FORC%XTA)) :: PSFCO2
REAL, DIMENSION(SIZE(FORC%XTA)) :: PUW_GRND
REAL, DIMENSION(SIZE(FORC%XTA)) :: PUW_RF
REAL, DIMENSION(SIZE(FORC%XTA)) :: PDUWDU_GRND
REAL, DIMENSION(SIZE(FORC%XTA)) :: PDUWDU_RF
REAL, DIMENSION(SIZE(FORC%XTA)) :: PCD
REAL, DIMENSION(SIZE(FORC%XTA)) :: PCDN
REAL, DIMENSION(SIZE(FORC%XTA)) :: PRI_TWN
REAL, DIMENSION(SIZE(FORC%XTA)) :: PEMIS_TWN
REAL, DIMENSION(SIZE(FORC%XTA)) :: PDIR_ALB_TWN
REAL, DIMENSION(SIZE(FORC%XTA)) :: PSCA_ALB_TWN
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZSW_UP_SO
REAL, DIMENSION(SIZE(FORC%XTA)) :: PRESA_TWN
REAL, DIMENSION(SIZE(FORC%XTA)) :: PAC_GD_WAT
REAL, DIMENSION(SIZE(FORC%XTA)) :: PAC_GR_WAT
REAL, DIMENSION(SIZE(FORC%XTA)) :: PLW_UP
REAL, DIMENSION(SIZE(FORC%XTA)) :: ILMO_ROAD
REAL, DIMENSION(SIZE(FORC%XTA)) :: ILMO_ROOF
REAL, DIMENSION(SIZE(FORC%XTA)) :: ILMO_TOP

! MT
REAL, DIMENSION(SIZE(FORC%XTA))  :: WSNOW_ROOF_CHECK    ! new snow content to exclude very low snow rate
REAL, DIMENSION(SIZE(FORC%XTA))  :: WSNOW_ROAD_CHECK    ! new snow content to exclude very low snow rate

!
!REAL, DIMENSION(SIZE(PTA)) :: ZDN_RF       ! snow fraction on roofs
!REAL, DIMENSION(SIZE(PTA)) :: ZDN_RD       ! snow fraction on roads
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZDF_RF       ! free-snow fraction on roofs
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZDF_RD       ! free-snow fraction on roads
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZDELT_RD     ! fraction of water on roads
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZDELT_RF     ! fraction of water on roofs
!MV202609 CBS scheme of the road
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZTAU         ! CBS scheme weight of the canyon path (-)
!MV202609 CBS scheme of the road (revision: three-temperature construction)
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZQ_CAN0      ! canyon air humidity without tau (kg/kg)
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZQ_CAN1        ! free layer air humidity (kg/kg)
!REAL, DIMENSION(SIZE(PTA)) :: ZAC_RF       ! roof conductance
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZAC_RF_WAT   ! roof water conductance
!REAL, DIMENSION(SIZE(PTA)) :: ZAC_WL       ! wall conductance
!REAL, DIMENSION(SIZE(PTA)) :: ZAC_TOP      ! top conductance
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZQSAT_RD     ! hum of saturation for roads
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZQSAT_GD     ! hum of saturation for green areas
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZQSAT_RF     ! hum of saturation for roofs
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZQSAT_GR     ! hum of saturation for green roofs
!
! coefficients for LW computations over snow (from previous time-step)
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZTSSN_RF   ! roof snow temp at previous time-step
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZTSSN_RD   ! road snow temp at previous time-step
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZESN_RF    ! snow emissivity at previous time-step
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZESN_RD    ! snow emissivity at previous time-step
!
! incoming shortwave radiation
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZDIR_SW             ! direct  solar rad
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZSCA_SW             ! diffuse solar rad
INTEGER                    :: JSWB
!
! albedo & emissivity
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZALB_GD    ! albedo     for green areas
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZEMIS_GD   ! emissivity for green areas
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZALB_GR    ! albedo     for green roofs
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZEMIS_GR   ! emissivity for green roofs
!
! radiation received by surfaces
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZREC_SW_RD      ! solar rad received by roads
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZREC_SW_WL_A    ! solar rad received by walls
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZREC_SW_WL_B    ! solar rad received by walls
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZREC_SW_GD      ! solar rad received by gardens
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZREC_SW_SN_RD   ! solar rad received by snow on roads
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZREC_LW_GD      ! IR rad received by gardens
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZSW_RAD_GD      ! solar radiation reaching urban green areas
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZREC_SW_RF      ! solar rad received by roofs in presence of solar panels
!
! coefficients for LW contributions
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WA_TO_WB        ! LW contrib. wall       -> opposite wall
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WA_TO_R         ! LW contrib. wall       -> road
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WB_TO_R         ! LW contrib. wall       -> road
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WA_TO_G         ! LW contrib. wall       -> green
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WB_TO_G         ! LW contrib. wall       -> green
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WA_TO_WIN       ! Radiative heat trasfer coeff wall-window 
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WB_TO_WIN       ! Radiative heat trasfer coeff wall-window 
                                                  ! [W K-1 m-2] 
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WA_TO_NR        ! LW contrib. wall       -> road(snow)
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WB_TO_NR        ! LW contrib. wall       -> road(snow)
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_R_TO_WA         ! LW contrib. road       -> wall
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_R_TO_WB         ! LW contrib. road       -> wall
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_R_TO_WIN        ! Radiative heat trasfer coeff road-window 
                                                  ! [W K-1 m-2] 
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_G_TO_WA         ! LW contrib. green      -> wall
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_G_TO_WB         ! LW contrib. green      -> wall
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_G_TO_WIN        ! L.W. interactions GARDEN areas->road
                                                  !
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WIN_TO_WA       ! Radiative heat trasfer coeff window-wall
                                                  ! [W K-1 m-2] 
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WIN_TO_WB       ! Radiative heat trasfer coeff window-wall
                                                  ! [W K-1 m-2] 
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WIN_TO_R        ! Radiative heat trasfer coeff window-road 
                                                  ! [W K-1 m-2]
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WIN_TO_G        ! Radiative heat trasfer coeff window-garden 
                                                  ! [W K-1 m-2]
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_WIN_TO_NR       ! Radiative heat trasfer coeff window-road(snow) 
                                                  ! [W K-1 m-2] 
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_S_TO_WA         ! LW contrib. sky        -> wall
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_S_TO_WB         ! LW contrib. sky        -> wall
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_S_TO_R          ! LW contrib. sky        -> road
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_S_TO_G          ! LW contrib. sky        -> green
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_S_TO_WIN        ! Radiative heat trasfer coeff window-sky 
                                                  ! [W K-1 m-2]
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_S_TO_NR         ! LW contrib. sky        -> road(snow)
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_NR_TO_WA        ! LW contrib. road(snow) -> wall
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_NR_TO_WB        ! LW contrib. road(snow) -> wall
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZLW_NR_TO_WIN       ! L.W. interactions snow(road)->GARDEN areas
                                                  !
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZREC_SW_WIN         ! solar received by windows [W m-2(win)]
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZT_SKY              ! sky temperature [K]
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZREC_LW_RF          ! Incoming LW on roofs in presence of solar panels
!
! local variable at previous time-step
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZPET_A_COEF          
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZPET_B_COEF          
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZPEQ_A_COEF          
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZPEQ_B_COEF          
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZUW_RD       ! momentum flux for roads
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZUW_GD       ! momentum flux for green areas
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZUW_GR       ! momentum flux for green roofs
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZDUWDU_RD    !
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZHU_AGG_GD   ! aggreg. relative humidity for green areas
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZHU_AGG_GR   ! aggreg. relative humidity for green roofs
!
!  surfaces relative fractions
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZRF_FRAC        ! roof, wall and
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZWL_FRAC        ! road fractions
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZRD_FRAC        ! of exchange surf.
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZGD_FRAC        !                  
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZTOTS_O_HORS    ! total canyon+roof surface
!                                             ! over horizontal surface
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZWL_O_RD        ! wall surface over road surface
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZWL_O_GRND      ! wall surface over (road+green area) surface
!
! surface temperatures
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZMTC_O_GR_R1 ! mean thermal conductivity over distance 
!                                          ! between two layers (bottom GR & roof)
!
! fluxes from green surfaces
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZSFCO2_GD      ! CO2 fluxes (m/s*kg_CO2/kg_air)
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZEMIT_LW_GD    ! LW flux emitted by the garden (W/m2 garden)
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZSFCO2_GR      ! CO2 fluxes over greenroofs (m/s*kg_CO2/kg_air)
!
! fluxes from built surfaces
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZEMIT_LW_RD    ! LW flux emitted by the road (W/m2 road)
!
! fluxes from/to solar panel
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZEMIT_LWDN_PANEL  ! LW flux emitted DOWNWARDS by the solar panel (W/m2 panel)
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZEMIT_LWUP_PANEL  ! LW flux emitted UPWARDS   by the solar panel (W/m2 panel)
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZEMIT_LW_RF       ! LW flux emitted UPWARDS   by the roof        (W/m2 roof )
!
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZRN_GD, ZDRAIN_GD, ZIRRIG_GD, ZGFLUX_GD
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZH_GD, ZLE_GD, ZEVAP_GD, ZTSRAD_GD, ZRUNOFF_GD
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZPH_GD_CAN, ZPH_GD_ATM     ! garden sensible heat flux, canyon / atmosphere branch
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZPLE_GD_CAN, ZPLE_GD_ATM   ! garden latent  heat flux, canyon / atmosphere branch
REAL, DIMENSIOn(SIZE(FORC%XTA)) :: ZQV_GD
REAL, DIMENSIOn(SIZE(FORC%XTA)) :: ZRN_GR, ZGFLUX_GR

REAL, DIMENSIOn(SIZE(FORC%XTA)) :: ZH_GR, ZLE_GR, ZRUNOFF_GR
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZDRAIN_GR, ZIRRIG_GR
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZEVAP_GR, ZTSRAD_GR
!
!new local variables for shading
REAL, DIMENSION(SIZE(FORC%XTA)) :: ZE_SHADING          ! energy not ref., nor absorbed, nor
                                                  ! trans. by glazing [Wm-2(win)]
LOGICAL, DIMENSION(SIZE(FORC%XTA)) :: GSHADE           ! describes if one encounters the
!                                                 ! conditions to close windows

INTEGER :: JJ

REAL(KIND=JPRB) :: ZHOOK_HANDLE
!-------------------------------------------------------------------------------
!
!*      1.     Initializations
!              ---------------
!
!*      1.0    broadband radiative fluxes
!              --------------------------
!
IF (LHOOK) CALL DR_HOOK('TEB_GARDEN',0,ZHOOK_HANDLE)
!
ZDIR_SW(:) = 0.
ZSCA_SW(:) = 0.
!
! snow scheme names (from the driver)
TSTATE%TSNOW_ROOF%SCHEME = HSNOW_ROOF
TSTATE%TSNOW_ROAD%SCHEME = HSNOW_ROAD
!
!MV202609 the diagnostics container (Phase 4b): OUT diagnostics initialised to XUNDEF
DMT%XLE_ROAD_SNOW                  = XUNDEF
DMT%XLE_ROAD_WAT                   = XUNDEF
DMT%XLE_ROOF_SNOW                  = XUNDEF
DMT%XLE_ROOF_WAT                   = XUNDEF
DMT%XEVAP_GARDEN                   = XUNDEF
DMT%XH_GARDEN                      = XUNDEF
DMT%ATM%H_GARDEN                  = XUNDEF
DMT%CAN%H_GARDEN                  = XUNDEF
DMT%XLE_GARDEN                     = XUNDEF
DMT%ATM%LE_GARDEN                 = XUNDEF
DMT%CAN%LE_GARDEN                 = XUNDEF
DMT%XPHU_GARDEN                    = XUNDEF
DMT%XQSAT_GARDEN                   = XUNDEF
DMT%XRN_GARDEN                     = XUNDEF
DMT%XTS_GARDEN                     = XUNDEF
DMT%CAN%PAC_GARDEN                    = XUNDEF
DMT%XUSTAR_TOWN                    = XUNDEF
DMT%XTCH_TOWN                      = XUNDEF
DMT%XAC_RF                         = XUNDEF
DMT%CAN%PAC_ROAD                         = XUNDEF
DMT%XAC_WL                         = XUNDEF
DMT%CAN%PAC_ROAD_WAT                  = XUNDEF
DMT%ATM%PAC_ROAD_WAT              = XUNDEF
DMT%XEMIT_LW_GRND                  = XUNDEF
DMT%XEMIT_LW_FAC                   = XUNDEF
DMT%XT_RAD_IND                     = XUNDEF
DMT%XREF_SW_GRND                   = XUNDEF
DMT%XREF_SW_FAC                    = XUNDEF
DMT%XHU_BLD                        = XUNDEF
PCD(:)                             = XUNDEF
PCDN(:)                            = XUNDEF
PRI_TWN(:)                         = XUNDEF
PRESA_TWN(:)                       = XUNDEF
PLEW_RF(:)                         = XUNDEF
PLEW_RD(:)                         = XUNDEF
PLE_WL_A(:)                        = XUNDEF
PLE_WL_B(:)                        = XUNDEF
PRNSN_RF(:)                        = XUNDEF
PRNSN_RD(:)                        = XUNDEF
PGSN_RF(:)                         = XUNDEF
PGSN_RD(:)                         = XUNDEF
PMELT_RF(:)                        = XUNDEF
PMELT_RD(:)                        = XUNDEF
PUW_RF(:)                          = XUNDEF
PDUWDU_RF(:)                       = XUNDEF
PEMIS_TWN(:)                       = XUNDEF
PDIR_ALB_TWN(:)                    = XUNDEF
PSCA_ALB_TWN(:)                    = XUNDEF
PRN_GRND(:)                        = XUNDEF
PH_GRND(:)                         = XUNDEF
PLE_GRND(:)                        = XUNDEF
PGFLX_GRND(:)                      = XUNDEF
PSFCO2(:)                          = XUNDEF
!
DO JSWB=1,KSW
  DO JJ=1,SIZE(FORC%XDIR_SW,1)
    ZDIR_SW(JJ) = ZDIR_SW(JJ) + FORC%XDIR_SW(JJ,JSWB)
    ZSCA_SW(JJ) = ZSCA_SW(JJ) + FORC%XSCA_SW(JJ,JSWB)
  ENDDO
END DO
!
!
!*      1.1    surfaces relative fractions
!              ---------------------------
!
DO JJ=1,SIZE(TPARAMS%XROAD)
  IF (TPARAMS%XROAD(JJ) .GT. 0.) THEN
    ZTOTS_O_HORS(JJ) = 1. + TPARAMS%XWALL_O_HOR(JJ)
    ZRF_FRAC  (JJ) = TPARAMS%XBLD       (JJ) / ZTOTS_O_HORS(JJ)
    ZWL_FRAC  (JJ) = TPARAMS%XWALL_O_HOR(JJ) / ZTOTS_O_HORS(JJ)
    ZRD_FRAC  (JJ) = TPARAMS%XROAD      (JJ) / ZTOTS_O_HORS(JJ)
    ZGD_FRAC  (JJ) = TPARAMS%XGARDEN    (JJ) / ZTOTS_O_HORS(JJ)
    ZWL_O_RD  (JJ) = ZWL_FRAC     (JJ) / ZRD_FRAC(JJ)
    ZWL_O_GRND(JJ) = ZWL_FRAC     (JJ) / (ZRD_FRAC(JJ)+ZGD_FRAC(JJ))
  ELSEIF (TPARAMS%XBLD(JJ) .EQ. 0. .AND. TPARAMS%XROAD(JJ) .EQ. 0.) THEN
    ZTOTS_O_HORS(JJ) = 1. + TPARAMS%XWALL_O_HOR(JJ)
    ZRF_FRAC  (JJ) = 0.
    ZWL_FRAC  (JJ) = TPARAMS%XWALL_O_HOR(JJ) / ZTOTS_O_HORS(JJ)
    ZRD_FRAC  (JJ) = 0.
    ZGD_FRAC  (JJ) = TPARAMS%XGARDEN    (JJ) / ZTOTS_O_HORS(JJ)
    ZWL_O_RD  (JJ) = 0.
    ZWL_O_GRND(JJ) = ZWL_FRAC     (JJ) / ZGD_FRAC(JJ)
  ENDIF
ENDDO
!
!-------------------------------------------------------------------------------
!
!*      2.     Snow-covered surfaces relative effects
!              --------------------------------------
!
!*      2.1    Snow-covered surfaces relative fractions (at previous time-step)
!              ----------------------------------------
 CALL SNOW_FRAC_ROAD(TSTATE%TSNOW_ROAD%WSNOW(:,1),FORC%XSNOW(:)>0.,DMT%XPDN_RD(1:1),ZDF_RD)
 CALL SNOW_FRAC_ROOF(TSTATE%TSNOW_ROOF%WSNOW(:,1),FORC%XSNOW(:)>0.,DMT%XPDN_RF(1:1),ZDF_RF)

 ! MT  teb_snow_check = .TRUE. activates the correction of the coupled model
 IF (teb_snow_check) THEN
   ! Claculation of snow content to exclude cases of very low snow rate
   WSNOW_ROOF_CHECK = 0.
   WSNOW_ROAD_CHECK = 0.
   WHERE (TSTATE%TSNOW_ROAD%WSNOW(:,1)==0. .AND. FORC%XSNOW(:)>0.) WSNOW_ROAD_CHECK = PTSTEP * FORC%XSNOW(:)
   WHERE (TSTATE%TSNOW_ROOF%WSNOW(:,1)==0. .AND. FORC%XSNOW(:)>0.) WSNOW_ROOF_CHECK = PTSTEP * FORC%XSNOW(:)
 ENDIF
 
!
!* new snow albedo
!
WHERE (TSTATE%TSNOW_ROAD%WSNOW(:,1)==0. .AND. FORC%XSNOW(:)>0.) TSTATE%TSNOW_ROAD%ALB(:) = XANSMAX
WHERE (TSTATE%TSNOW_ROOF%WSNOW(:,1)==0. .AND. FORC%XSNOW(:)>0.) TSTATE%TSNOW_ROOF%ALB(:) = XANSMAX
!

!*      2.2    If snow was not present at previous time-step but is falling
!              ------------------------------------------------------------
!
WHERE (TSTATE%TSNOW_ROAD%WSNOW(:,1)==0. .AND. FORC%XSNOW(:)>0.)
  TSTATE%TSNOW_ROAD%ALB (:) = XANSMAX
  TSTATE%TSNOW_ROAD%EMIS(:) = XEMISSN
  TSTATE%TSNOW_ROAD%TS  (:) = MIN(TSTATE%XT_ROAD(:,1), XTT)
END WHERE
WHERE (TSTATE%TSNOW_ROOF%WSNOW(:,1)==0. .AND. FORC%XSNOW(:)>0.)
  TSTATE%TSNOW_ROOF%ALB (:) = XANSMAX
  TSTATE%TSNOW_ROOF%EMIS(:) = XEMISSN
  TSTATE%TSNOW_ROOF%TS  (:) = MIN(TSTATE%XT_ROOF(:,1), XTT)
END WHERE

! MT  teb_snow_check = .TRUE. activates the correction of the coupled model
IF (teb_snow_check) THEN
  ! Exclude cases of very low snow rate
  WHERE ( WSNOW_ROAD_CHECK(:)<1.E-8 * PTSTEP )
     TSTATE%TSNOW_ROAD%ALB (:) = XUNDEF
     TSTATE%TSNOW_ROAD%EMIS(:) = XUNDEF
     TSTATE%TSNOW_ROAD%TS  (:) = XUNDEF
     DMT%XPDN_RD(1:1) = 0.
     ZDF_RD = 1.
  END WHERE
  !
  WHERE ( WSNOW_ROOF_CHECK(:)<1.E-8 * PTSTEP )
     TSTATE%TSNOW_ROOF%ALB (:) = XUNDEF
     TSTATE%TSNOW_ROOF%EMIS(:) = XUNDEF
     TSTATE%TSNOW_ROOF%TS  (:) = XUNDEF
     DMT%XPDN_RF(1:1) = 0.
     ZDF_RF = 1.
  END WHERE
ENDIF

!
!*      2.3    Radiative snow variables at previous time-step
!              ----------------------------------------------
!
ZESN_RF  (:) = TSTATE%TSNOW_ROOF%EMIS(:)
ZESN_RD  (:) = TSTATE%TSNOW_ROAD%EMIS(:)
ZTSSN_RF (:) = TSTATE%TSNOW_ROOF%TS  (:)
ZTSSN_RD (:) = TSTATE%TSNOW_ROAD%TS  (:)
!
!-------------------------------------------------------------------------------
!
!*      3.     Extrapolation of atmospheric T and q at roof level (for fluxes computation)
!              --------------------------------------------------
!
ZTA(:) = FORC%XTA(:) * FORC%XEXNS(:) / FORC%XEXNA(:)
ZQA(:) = FORC%XQA(:) * QSAT(ZTA(:),FORC%XPS(:)) / QSAT(FORC%XTA(:),FORC%XPA(:))
!
!-------------------------------------------------------------------------------
!

!*      4.     Grid-averaged albedo and emissivity of green areas
!              --------------------------------------------------
!

!* Initialise the grid-averaged albedo, emissivity and radiative temperature of
!  green areas and green roofs to XUNDEF before the optional blocks below.
!  These arrays are passed to URBAN_SOLAR_ABS / URBAN_LW_COEF and are used there
!  even when the garden / greenroof schemes are disabled (LGARDEN / LGREENROOF
!  = .FALSE.); without this initialisation uninitialised memory would be used.
!  When a scheme is enabled the values below are overwritten either by the
!  external data (*_EXT) or by TEB_VEG_PROPERTIES, so both operating modes
!  (built-in and external) are unaffected.
ZALB_GD   = XUNDEF
ZEMIS_GD  = XUNDEF
ZTSRAD_GD = XUNDEF
ZALB_GR   = XUNDEF
ZEMIS_GR  = XUNDEF
ZTSRAD_GR = XUNDEF

!!
IF (TOPTS%LGARDEN) THEN
  IF (TOPTS%CTYPE_GARDEN /= 'EXT' .AND. TOPTS%CTYPE_GARDEN /= 'EXT_NEU') THEN
    ZALB_GD   = XUNDEF
    ZEMIS_GD  = XUNDEF
    ZTSRAD_GD = XUNDEF
    CALL TEB_VEG_PROPERTIES(FORC%XDIR_SW, FORC%XSCA_SW,   &
                        ZTSRAD_GD, ZEMIS_GD, ZALB_GD,       &
                        PTA=TSTATE%XT_CANYON(icell:icell)                       )
  ELSE
    ZTSRAD_GD = PTSRAD_GD_EXT
  ENDIF	
    !* the albedo and the emissivity come from the namelist
    !* (urb_alb_gdn / urb_emis_gdn) in EVERY mode, so that the radiation
    !* budget of TEB and the internal proxy (GARDEN) use the same values
    ZALB_GD  = PALB_GD_EXT
    ZEMIS_GD = PEMIS_GD_EXT
ENDIF

!
! for greenroofs :
IF (TOPTS%LGREENROOF) THEN
  IF (.NOT. OGREENROOF_EXT .AND. TOPTS%CTYPE_GREENROOF /= 'EXT' .AND. &
      TOPTS%CTYPE_GREENROOF /= 'EXT_NEU') THEN
    ZALB_GR   = XUNDEF
    ZEMIS_GR  = XUNDEF
    ZTSRAD_GR = XUNDEF
    CALL TEB_VEG_PROPERTIES(  FORC%XDIR_SW, FORC%XSCA_SW,    &
                           ZTSRAD_GR, ZEMIS_GR, ZALB_GR,        &
                           PTA=FORC%XTA                              )
  ELSE
    ZTSRAD_GR = PTSRAD_GR_EXT
  ENDIF	

    !* albedo and emissivity from the namelist (urb_alb_grf / urb_emis_grf)
    ZALB_GR  = PALB_GR_EXT
    ZEMIS_GR = PEMIS_GR_EXT
ENDIF
!
!-------------------------------------------------------------------------------
!
!*      5.     Occupation of buildings
!              -----------------------
!
!* when building in unoccupied, target temperature is modified
!
IF (TOPTS%CBEM=="BEM") THEN
  CALL BLD_OCC_CALENDAR(TOPTS%TTIME, FORC%XTSUN, TSTATE, BSTATE, 1., DMT%XTCOOL_TARGET, DMT%XTHEAT_TARGET, DMT%XQIN , TPARAMS, BPARAMS)
ENDIF
!
!-------------------------------------------------------------------------------
!
!*      5.     Solar radiation
!              ---------------
!
!
!*       5.1   Windows management
!              ------------------
!
!* checks if one encouters the conditions for closing the windows at day
!  (needs to be equiped of solar protections and not to be confortable inside)
!  
GSHADE(:) = .FALSE.
IF (TOPTS%CBEM=="BEM") THEN
 CALL WINDOW_SHADING_AVAILABILITY(BSTATE%LSHADE, BSTATE%XTI_BLD, DMT%XTCOOL_TARGET, GSHADE)
! MT deactivation of shading devices
!GSHADE(:) = .FALSE.
!
!* Reinitialize shading of windows when changing day
!
  WHERE (FORC%XTSUN .LT. PTSTEP + 1E-3) BSTATE%LSHAD_DAY(:) = .FALSE.
END IF
!
!
!*       5.2   computes solar radiation exchanges
!              ----------------------------------
!
 CALL URBAN_SOLAR_ABS(TOPTS, TSTATE, BSTATE, DMT, ZDIR_SW, ZSCA_SW, FORC%XZENITH, FORC%XAZIM,  &
                      TPN%XFRAC_PANEL, TPN%XALB_PANEL, ZALB_GD,     &
                      TPARAMS%XSVF_GARDEN, ZALB_GR, DMT%XPDN_RF(1:1), ZDF_RF,       &
                      DMT%XPDN_RD(1:1), ZDF_RD, ZREC_SW_RD, ZREC_SW_SN_RD,    &
                      ZREC_SW_WL_A, ZREC_SW_WL_B, ZREC_SW_GD,       &
                      ZREC_SW_RF, PDIR_ALB_TWN, PSCA_ALB_TWN,       &
                      DMT%XALB_SO(1:1), ZSW_UP_SO, ZSW_RAD_GD, ZREC_SW_WIN,         &
					  DMT%XREF_SW_GRND(1:1), DMT%XREF_SW_FAC(1:1), ZE_SHADING, BSTATE%LSHAD_DAY, GSHADE , TPARAMS, BPARAMS)

!
!-------------------------------------------------------------------------------
!
!*      6.     LW properties
!              -------------
!
  CALL URBAN_LW_COEF(BSTATE, TSTATE, FORC%XLW, ZEMIS_GD, TSTATE%TSNOW_ROAD%TS, ZTSRAD_GD,  &
                     ZLW_WA_TO_WB, ZLW_WA_TO_R, ZLW_WB_TO_R,            &
                     ZLW_WA_TO_NR, ZLW_WB_TO_NR, ZLW_WA_TO_G,           &
                     ZLW_WB_TO_G, ZLW_WA_TO_WIN, ZLW_WB_TO_WIN,         &
                     ZLW_R_TO_WA, ZLW_R_TO_WB, ZLW_R_TO_WIN,            &
                     ZLW_G_TO_WA, ZLW_G_TO_WB, ZLW_G_TO_WIN,            &
                     ZLW_S_TO_WA, ZLW_S_TO_WB, ZLW_S_TO_R,              &
                     ZLW_S_TO_NR, ZLW_S_TO_G,ZLW_S_TO_WIN,              &
                     ZLW_WIN_TO_WA, ZLW_WIN_TO_WB, ZLW_WIN_TO_R,        &
                     ZLW_WIN_TO_NR, ZLW_WIN_TO_G, ZLW_NR_TO_WA,         &
                     ZLW_NR_TO_WB, ZLW_NR_TO_WIN          , TPARAMS, BPARAMS)

!
!-------------------------------------------------------------------------------
!
!MV202609 CBS scheme of the road (and of the garden)
!* tau is the fraction of the surface exchange performed with the canyon air, the
!* remaining part (1-tau) exchanging directly with the air of the forcing level.
!* tau is a tanh relaxation of the canyon H/W ratio (see CBS_TAU below):
!* tau -> 0 for very sparse buildings and tau = 1 for a dense canyon. With the
!* scheme disabled tau = 1, which reproduces the former behaviour exactly.
!* It is evaluated here, before TEB_GARDEN2, because it is used both by the garden
!* (inside TEB_GARDEN2) and by the road (in TEB below).
!
IF (TOPTS%LCBS_SCHEME) THEN
  ZTAU(:) = CBS_TAU(TPARAMS%XCAN_HW_RATIO(:), TOPTS%XTAU_HW_THRESH, TOPTS%XTAU_HW_WIDTH, TPARAMS%XBLD_HEIGHT(:))
ELSE
  ZTAU(:) = 1.
ENDIF
!
!-------------------------------------------------------------------------------
!
! The subroutine is splitted in 2 because of compilation optimization issues
 CALL TEB_GARDEN2

 !
!*     9.      Treatment of built covers
!              -------------------------
!

!MV202609 CBS scheme of the road
!* (tau itself is computed above, before TEB_GARDEN2, and is used by the garden
!* and by the road energy budget of TEB below)
!
  CALL TEB  (icell, iblock, TOPTS, TSTATE, BOPTS, BSTATE, TIR, DMT, HIMPLICIT_WIND, PBEM_AC,     &
             FORC%XTSUN, TSTATE%XT_CANYON(icell:icell), TSTATE%XQ_CANYON(icell:icell), DMT%XWIND_CANYON(1:1), TSTATE%XT_CANYON(icell:icell), TSTATE%XQ_CANYON(icell:icell), DMT%XWIND_CANYON(1:1),       &
             TPARAMS%XBLD_HEIGHT(icell:icell)/2, PPEW_A_COEF, PPEW_B_COEF, PPEW_A_COEF_LOWCAN,              &
             PPEW_B_COEF_LOWCAN, PZ0_GARDEN_EXT, PZ0_GR_EXT, FORC%XPS, FORC%XPA, FORC%XEXNS, FORC%XEXNA, FORC%XTA, FORC%XQA, FORC%XRHOA, FORC%XLW, &
             FORC%XRAIN, FORC%XSNOW, FORC%XZREF, FORC%XUREF, FORC%XVMOD, PH_TRAFFIC, TPARAMS%XLE_TRAFFIC(icell:icell), PTSTEP,       &
             ZDF_RF, DMT%XPDN_RF(1:1), ZDF_RD, DMT%XPDN_RD(1:1), ZQSAT_RF, ZQSAT_RD, ZDELT_RF,         &
             ZDELT_RD, ZTSRAD_GD, ZQV_GD, PLEW_RF, ZUW_GR, PLEW_RD, PLE_WL_A,              &
             PLE_WL_B, PRNSN_RF, DMT%XH_SNOW_ROOF(1:1), DMT%XLE_SNOW_ROOF(1:1), PGSN_RF, PMELT_RF,             &
             ZRN_GR, ZH_GR, ZLE_GR, ZGFLUX_GR, ZDRAIN_GR, ZTSRAD_GR, ZRUNOFF_GR,              &
             PRNSN_RD, DMT%XH_SNOW_ROAD(1:1), DMT%XLE_SNOW_ROAD(1:1), PGSN_RD, PMELT_RD, ZUW_RD, PUW_RF,       &
             ZDUWDU_RD,                                                             &
!MV202609 CBS scheme of the road (revision: snow-to-atmosphere branch)
             DMT%CAN%PHSN_RD, DMT%ATM%PHSN_RD, DMT%CAN%PLESN_RD, DMT%ATM%PLESN_RD,                  &
             PDUWDU_RF, DMT%XUSTAR_TOWN(1:1), PCD, PCDN, DMT%XTCH_TOWN(1:1), PRI_TWN, PRESA_TWN, &
             DMT%XAC_RF(1:1), DMT%CAN%PAC_ROAD(1:1), DMT%XAC_WL(1:1), DMT%XAC_TOP(1:1), DMT%CAN%PAC_GARDEN(1:1), ZAC_RF_WAT, DMT%CAN%PAC_ROAD_WAT(1:1),      &
             ZLW_WA_TO_WB, ZLW_WA_TO_R, ZLW_WB_TO_R, ZLW_WA_TO_NR, ZLW_WB_TO_NR,   &
             ZLW_R_TO_WA, ZLW_R_TO_WB, ZLW_G_TO_WA, ZLW_G_TO_WB, ZLW_S_TO_WA,      &
             ZLW_S_TO_WB, ZLW_S_TO_R, ZLW_S_TO_NR, ZLW_NR_TO_WA, ZLW_NR_TO_WB,     &
             ZLW_NR_TO_WIN, ZLW_WA_TO_WIN, ZLW_WB_TO_WIN, ZLW_G_TO_WIN,            &
             ZLW_R_TO_WIN, ZLW_S_TO_WIN, ZLW_WIN_TO_WA, ZLW_WIN_TO_WB,             &
             ZLW_WIN_TO_R, ZLW_WIN_TO_NR, KDAY, DMT%XEMIT_LW_FAC(1:1), ZEMIT_LW_RD,         &
             DMT%XT_RAD_IND(1:1), DMT%XHU_BLD(1:1), PTIME, ZE_SHADING, DMT%XSNOW_MELT(1:1), DMT%XSNOWD_ROOF(1:1),         &
			 DMT%XSNOWD_ROAD(1:1), PCH_GD, PCD_GD, DMT%CAN%PCH_ROAD(1:1), DMT%XTCH_RF(1:1), DMT%XTCH_WL(1:1), DMT%XTCH_TOP(1:1), ILMO_ROAD,&
             ILMO_ROOF, ILMO_TOP, DMT%ATM%PCD_GARDEN(1:1), DMT%ATM%PCH_GARDEN(1:1)			 ,                         &
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
                          DMT%CAN%PCD_ROAD(1:1), DMT%CAN%PCDN_ROAD(1:1), DMT%CAN%PRI_ROAD(1:1), DMT%CAN%ZZ0H_ROAD(1:1), &
                          DMT%ATM%PAC_ROAD(1:1), DMT%ATM%PCH_ROAD(1:1), DMT%ATM%PCD_ROAD(1:1), DMT%ATM%PCDN_ROAD(1:1), &
                          DMT%ATM%PRI_ROAD(1:1), DMT%ATM%ZZ0H_ROAD(1:1), DMT%CAN%PCDN_GARDEN(1:1), DMT%CAN%PRI_GARDEN(1:1), &
                          DMT%CAN%ZZ0H_GARDEN(1:1), DMT%ATM%PAC_GARDEN(1:1), DMT%ATM%PCDN_GARDEN(1:1), DMT%ATM%PRI_GARDEN(1:1), DMT%ATM%ZZ0H_GARDEN(1:1), &
!MV202609 greenroof-to-atm exchange diagnostics
                          DMT%XPAC_GREENROOF_ATM(1:1), DMT%XPCD_GREENROOF_ATM(1:1), DMT%XPCDN_GREENROOF_ATM(1:1), DMT%XPCH_GREENROOF_ATM(1:1), &
                          DMT%XPRI_GREENROOF_ATM(1:1), DMT%XZZ0H_GREENROOF_ATM(1:1), &
                          DMT%CAN%PH_ROAD(1:1), DMT%CAN%PLE_ROAD(1:1), DMT%ATM%PH_ROAD(1:1), DMT%ATM%PLE_ROAD(1:1),          &
!MV202609 CBS scheme of the road
                          ZTAU, DMT%XPH_ROAD(1:1), DMT%XPLE_ROAD(1:1), DMT%ATM%PAC_ROAD_WAT(1:1), DMT%XLE_ROAD_WAT(1:1), DMT%XLE_ROAD_SNOW(1:1), &
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
                          DMT%XLE_ROOF_WAT(1:1), DMT%XLE_ROOF_SNOW(1:1), TPARAMS, BPARAMS)
!
!* canyon-path coefficients of the garden, as handed to the host through the
!* interface (teb_tcm_gd / teb_tch_gd): stored after URBAN_DRAG has written them
!* inside TEB, so that the diagnostic container holds both branches of the scheme
DMT%CAN%PCD_GARDEN(:) = PCD_GD(:)
DMT%CAN%PCH_GARDEN(:) = PCH_GD(:)

!
!-------------------------------------------------------------------------------
!
!*    10.      Treatment of solar panels
!              -------------------------
!
IF (TOPTS%LSOLAR_PANEL) THEN
  ! 
  !* LW radiation coming upwards from roofs
  !
  ZEMIT_LW_RF =  ZREC_LW_RF   &
     - (        TPARAMS%XGREENROOF(:)  *             DMT%XABS_LW_GREENROOF(:)  &
          + (1.-TPARAMS%XGREENROOF(:)) * ZDF_RF(:) * DMT%XABS_LW_ROOF(:)       &
          + (1.-TPARAMS%XGREENROOF(:)) * DMT%XPDN_RF(:) * DMT%XABS_LW_SNOW_ROOF(:) )

  !
  ! note that, for the time being, one considers that the solar panel 
  ! intercept radiation both above roof and greenroofs (if any)
  CALL SOLAR_PANEL(TPN, DMT, PTSTEP, FORC%XTSUN, TPARAMS%XRESIDENTIAL, ZEMIT_LW_RF, ZEMIT_LWDN_PANEL, &
                   FORC%XLW, FORC%XTA, BPARAMS%XN_FLOOR, DMT%XSOLAR_PROD(1:1)   )
ELSE
  DMT%XSOLAR_PROD(1:1)        = XUNDEF  
END IF
!-------------------------------------------------------------------------------
!
!*     11.     Aggregation
!              -----------
!
 CALL AVG_URBAN_FLUXES(icell, iblock, TOPTS, TSTATE, BSTATE, TPN, DMT,                                               &
                       DMT%XTSTOWN_S(1:1), PEMIS_TWN, TSTATE%XT_CANYON(icell:icell), TSTATE%XQ_CANYON(icell:icell), TSTATE%XT_CANYON(icell:icell), TSTATE%XQ_CANYON(icell:icell),          &
                       ZTA, ZQA, FORC%XRHOA, FORC%XPS, PH_TRAFFIC,  TPARAMS%XLE_TRAFFIC(icell:icell), ZWL_O_GRND,        &
                       ZESN_RF, ZEMIS_GR, FORC%XLW,  DMT%XAC_RF(1:1), ZAC_RF_WAT, DMT%XAC_WL(1:1), DMT%CAN%PAC_ROAD(1:1),  &
                       DMT%CAN%PAC_ROAD_WAT(1:1), DMT%XAC_TOP(1:1), DMT%CAN%PAC_GARDEN(1:1), ZQSAT_GD, ZHU_AGG_GD,     &
                       ZQSAT_RF, ZQSAT_RD, ZDELT_RF, ZDELT_RD, ZRF_FRAC, ZWL_FRAC,        &
                       ZRD_FRAC, ZGD_FRAC, ZTOTS_O_HORS, ZDF_RF, DMT%XPDN_RF(1:1), ZDF_RD, DMT%XPDN_RD(1:1),  &
                       PLE_WL_A, PLE_WL_B, PLEW_RF, DMT%XLE_SNOW_ROOF(1:1), PLEW_RD, DMT%XLE_SNOW_ROAD(1:1), DMT%XH_SNOW_ROAD(1:1), &
                       ZTSRAD_GD, ZRN_GD, ZH_GD, ZLE_GD, ZGFLUX_GD, ZEVAP_GD,             &
!MV202609 CBS scheme of the garden (atmosphere branch in the free layer)
                       ZPH_GD_ATM, ZPLE_GD_ATM,                                            &
                       ZRUNOFF_GD, ZEVAP_GR, ZRUNOFF_GR, ZDRAIN_GR,                       &
                       PRN_GRND, PH_GRND, PLE_GRND, PGFLX_GRND, DMT%XRN_TOWN(1:1), DMT%XH_TOWN(1:1), DMT%XLE_TOWN(1:1), &
                       DMT%XGFLUX_TOWN(1:1), DMT%XQVFL(1:1), ZEMIT_LW_RD,ZEMIT_LW_GD, DMT%XEMIT_LW_GRND(1:1), ZEMIS_GD, PLW_UP, &
!MV202609 CBS scheme of the road
                       ZTAU,                                                               &
!MV202609 CBS scheme of the road (revision: three-temperature construction)
                       DMT%ATM%PH_ROAD(1:1), DMT%ATM%PLE_ROAD(1:1), DMT%ATM%PCD_ROAD(1:1), DMT%ATM%ZZ0H_ROAD(1:1),             &
                       FORC%XZREF, FORC%XVMOD,                                                       &
                       DMT%XPT_CAN0(1:1), DMT%XPT_CAN1(1:1), DMT%XPPHI_CAN1(1:1), ZQ_CAN0, ZQ_CAN1,                       &
!MV202609 CBS scheme of the road (revision: snow-to-atmosphere branch)
                       DMT%CAN%PHSN_RD, DMT%ATM%PHSN_RD, DMT%CAN%PLESN_RD, DMT%ATM%PLESN_RD , TPARAMS, BPARAMS)
!
PSFCO2(:) = TPARAMS%XGARDEN(:) * ZSFCO2_GD(:) + TPARAMS%XBLD(:) * TPARAMS%XGREENROOF(:) * ZSFCO2_GR(:) ! no CO2 flux from built and road yet.
!
!-------------------------------------------------------------------------------
!
!*     11.1   Garden diagnostics (per m2 of garden)
!              ------------------------------------
!* Per-m2-of-garden values of the garden surface (as computed by the garden
!* model selected with teb_type_garden); they are diagnostics only.
!
DMT%XTS_GARDEN(:) = ZTSRAD_GD(:)
DMT%XRN_GARDEN(:) = ZRN_GD(:)
DMT%XH_GARDEN(:) = ZH_GD(:)
DMT%XLE_GARDEN(:) = ZLE_GD(:)
DMT%XEVAP_GARDEN(:) = ZEVAP_GD(:)
DMT%XQSAT_GARDEN(:) = ZQSAT_GD(:)
!* the moisture multiplier of the canyon node: unlike the greenroof one below, it is
!* NOT a diagnostic -- AVG_URBAN_FLUXES uses it for the water budget of the canyon
!* air (the garden couples back to the canyon air, the greenroof does not)
DMT%XPHU_GARDEN(:) = ZHU_AGG_GD(:)
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
DMT%CAN%H_GARDEN(:) = ZPH_GD_CAN(:)
DMT%ATM%H_GARDEN(:) = ZPH_GD_ATM(:)
DMT%CAN%LE_GARDEN(:) = ZPLE_GD_CAN(:)
DMT%ATM%LE_GARDEN(:) = ZPLE_GD_ATM(:)
!
!MV202609 greenroof diagnostics (per m2 of greenroof)
!* Per-m2-of-greenroof values of the greenroof surface (as computed by the
!* greenroof model selected with teb_type_greenroof); they are diagnostics only.
!
DMT%XTS_GREENROOF(:) = ZTSRAD_GR(:)
DMT%XRN_GREENROOF(:) = ZRN_GR(:)
DMT%XH_GREENROOF(:) = ZH_GR(:)
DMT%XLE_GREENROOF(:) = ZLE_GR(:)
DMT%XEVAP_GREENROOF(:) = ZEVAP_GR(:)
DMT%XQSAT_GREENROOF(:) = ZQSAT_GR(:)
!* a diagnostic of the aggregated moisture exchange of the roof surface:
!* it feeds the PHU_GREENROOF column and no budget (the greenroof does not
!* couple back to the canyon air), unlike the multiplier of the garden
DMT%XPHU_GREENROOF(:) = ZHU_AGG_GR(:)
!
!-------------------------------------------------------------------------------
!
!*     12.     Momentum flux for ground built surfaces
!              ---------------------------------------
!
PUW_GRND (:)     = (TPARAMS%XROAD(:)*ZUW_RD(:) + TPARAMS%XGARDEN(:)*ZUW_GD(:)) / (TPARAMS%XROAD(:)+TPARAMS%XGARDEN(:))
!
PDUWDU_GRND (:)  = 0.
!





!
IF (LHOOK) CALL DR_HOOK('TEB_GARDEN',1,ZHOOK_HANDLE)
!-------------------------------------------------------------------------------
CONTAINS
!-------------------------------------------------------------------------------
!
!MV202609 CBS scheme of the road
!!****  *CBS_TAU*
!!
!!    PURPOSE
!!    -------
!!
!!    Weight of the canyon path in the CBS scheme of the road: tau = 1 for a
!!    dense canyon (the road exchanges with the canyon air only) and tau -> 0
!!    for very sparse buildings (the road exchanges directly with the air of
!!    the forcing level). The transition is a tanh relaxation centred on the
!!    canyon H/W ratio HW_THRESH, of width HW_WIDTH.
!!
!!    The building height H_BLD is not used yet: it is kept in the argument
!!    list so that a more elaborate formulation can be introduced later without
!!    changing the callers.
!!
ELEMENTAL FUNCTION CBS_TAU(HW_RATIO, HW_THRESH, HW_WIDTH, H_BLD) RESULT(TAU)
   REAL, INTENT(IN) :: HW_RATIO    ! canyon H/W ratio                      (-)
   REAL, INTENT(IN) :: HW_THRESH   ! H/W giving tau = 0.5                  (-)
   REAL, INTENT(IN) :: HW_WIDTH    ! width of the tanh relaxation          (-)
   REAL, INTENT(IN) :: H_BLD       ! building height (reserved for future) (m)
   REAL             :: TAU         ! weight of the canyon path             (-)
!-------------------------------------------------------------------------------
   TAU = 0.5 * (1.0 + TANH((HW_RATIO - HW_THRESH) / MAX(HW_WIDTH, TINY(1.0))))
END FUNCTION CBS_TAU
!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
SUBROUTINE TEB_GARDEN2
!
!*      7.     Terms of radiation absorption
!              -----------------------------
!
!*      7.1    IR rad received by gardens (snow free and snow covered separately)
!              --------------------------
!
IF (TOPTS%LGARDEN) THEN
  ZT_SKY  (:) = (FORC%XLW(:)/XSTEFAN)**0.25
  ZREC_LW_GD(:) = (ZLW_S_TO_G  (:) * (ZT_SKY(:)       - ZTSRAD_GD(:))   &
                 + ZLW_WA_TO_G (:) * (TSTATE%XT_WALL_A(:,1)- ZTSRAD_GD(:))   &
                 + ZLW_WB_TO_G (:) * (TSTATE%XT_WALL_B(:,1)- ZTSRAD_GD(:))   &
                 + ZLW_WIN_TO_G(:) * (BSTATE%XT_WIN1(:)    - ZTSRAD_GD(:)) ) &
                   / ZEMIS_GD(:) + XSTEFAN * ZTSRAD_GD(:)**4
ELSE
  ZREC_LW_GD      (:) = XUNDEF
END IF
!
!*     7.2     Effect of solar panels on incoming LW on roofs
!              ----------------------------------------------
!
IF (TOPTS%LSOLAR_PANEL) THEN
  !
  ! solar panels downwards surface is supposed to be at air temperature
  ! and to be have an emissivity of 1.
  !
  ZEMIT_LWDN_PANEL = XSTEFAN * FORC%XTA**4
  !
  ! note that, for the time being, one considers that the solar panel 
  ! intercept radiation both above roof and greenroofs (if any)
  ZREC_LW_RF = (1.-TPN%XFRAC_PANEL(:)) * FORC%XLW + TPN%XFRAC_PANEL(:) * ZEMIT_LWDN_PANEL
ELSE
  ZEMIT_LWDN_PANEL = XUNDEF
  ZREC_LW_RF       = FORC%XLW
END IF
!
!-------------------------------------------------------------------------------
!
!*      8.     Treatment of green areas
!              ------------------------
!
!*      8.1    Implicit coeefs for T and Q
!              ---------------------------
!
!* explicit coupling for the time being.
!  canopy may need implicitation if there is a lot a garden in the grid mesh
!
ZPET_A_COEF(:) = 0.
ZPET_B_COEF(:) = TSTATE%XT_CANYON(icell:icell) / FORC%XEXNS(:)
ZPEQ_A_COEF(:) = 0.
ZPEQ_B_COEF(:) = TSTATE%XQ_CANYON(icell:icell)
!
!*      8.2    Call ISBA for green areas
!              -------------------------
!
IF (TOPTS%LGARDEN) THEN
  !
  !* the garden model of an INTERNAL garden is the diagnostic proxy called here.
  !* The external garden ('EXT'/'EXT_NEU') is not modelled by any proxy: its state,
  !* its fluxes and its conductance come from the coupling interface, so the call is
  !* skipped and the coupling quantities are built in the ELSE branch below
  IF (TOPTS%CTYPE_GARDEN /= 'EXT' .AND. TOPTS%CTYPE_GARDEN /= 'EXT_NEU') THEN
    CALL GARDEN_CBS(TOPTS%CTYPE_GARDEN, TPARAMS%XBLD_HEIGHT(icell:icell)/2, TSTATE%XT_CANYON(icell:icell), TSTATE%XQ_CANYON(icell:icell), DMT%XWIND_CANYON(1:1), PZ0_GARDEN_EXT, &
!MV202609 garden thermal roughness (z0h)
!* z0/z0h ratio of the garden: the scalar (thermal) coefficient of the diagnostic
!* balance is built from it (single value of TOPTS, the same one that URBAN_DRAG
!* exports and that the emulator of the offline driver uses)
    TOPTS%XZ0_O_Z0H_GD,                                                          &
!MV202609 CBS scheme of the garden
!* the split (tau vs 1 - tau) is applied only to the internal diagnostic proxy:
!* 'PROXY_OLD' has a single flux which is reported in both branches
    FORC%XUREF, FORC%XVMOD, FORC%XTA, FORC%XQA,                                                     &
    ZTAU, ( TOPTS%LCBS_SCHEME .AND. TOPTS%CTYPE_GARDEN == 'PROXY_NEW' ),           &
    PALB_GD_EXT, PEMIS_GD_EXT, FORC%XRHOA, FORC%XPS, ZREC_SW_GD, ZREC_LW_GD,             &
    ZRN_GD, ZH_GD, ZLE_GD, ZGFLUX_GD,                                          &
    ZSFCO2_GD, ZEVAP_GD, ZUW_GD, ZRUNOFF_GD, DMT%CAN%PAC_GARDEN(1:1), ZQSAT_GD, ZTSRAD_GD,      &
    ZDRAIN_GD, ZIRRIG_GD,                              &
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
    ZPH_GD_CAN, ZPH_GD_ATM, ZPLE_GD_CAN, ZPLE_GD_ATM,                          &
!MV202609 garden exchange coefficients, returned by the garden model
    PCD_GD, PCH_GD, ZHU_AGG_GD )
  ELSE
    !
    !* external garden ('EXT'/'EXT_NEU'): no proxy model is called. The state,
    !* the fluxes and the surface humidity come from the coupling interface; only
    !* the derived quantities are built here: qsat(Ts) and the friction flux.
    !*
    !* The friction uses the MOMENTUM coefficient of the external model itself - the
    !* one URBAN_DRAG computed with URBAN_EXCH_COEF and exported to the host - and
    !* not a neutral one: here it is the CANYON path coefficient (PCD_GARDEN_CAN),
    !* because the momentum conductance of the garden has no atmosphere branch (the
    !* tau split applies to heat and moisture only). It is the value of the previous
    !* sub-step (URBAN_DRAG is called after this section); when it is not available
    !* yet - the first sub-step of a run - the neutral coefficients of this module
    !* are used (they are then also what the caller receives). No wind floor: the
    !* wind is the one of the host, as in the historical proxy and in COSMO-TEB
    ZQSAT_GD(:)  = QSAT(ZTSRAD_GD(:), FORC%XPS(:))
!MV202609 friction of the external surfaces (URBAN_DRAG momentum coefficient)
    WHERE (PCD_GD(:) > 0. .AND. PCD_GD(:) < XUNDEF)
      ZUW_GD(:) = - PCD_GD(:) * DMT%XWIND_CANYON(1:1)**2
    ELSEWHERE
      PCD_GD(:) = GARDEN_PCD_NEUTRAL(TPARAMS%XBLD_HEIGHT(icell:icell)/2, PZ0_GARDEN_EXT(:))
      ZUW_GD(:) = - PCD_GD(:) * DMT%XWIND_CANYON(1:1)**2
    END WHERE
    ZGFLUX_GD(:) = 0.
    ZSFCO2_GD(:) = 0.
  END IF
  !
  !* moisture multiplier of the canyon node (DMT%CAN%PAC_GARDEN(1:1)*PHU_AGG_GD*ZGD): returned by
  !* the call above for an internal garden (the PHU parameter of that model)
  PAC_GD_WAT(:) = DMT%CAN%PAC_GARDEN(:)
  DMT%XABS_SW_GARDEN(:) = (1.-ZALB_GD(:)) * ZREC_SW_GD
  DMT%XABS_LW_GARDEN(:) = ZEMIS_GD(:) * ZREC_LW_GD(:) - XSTEFAN * ZEMIS_GD(:) * ZTSRAD_GD(:)**4
  ZEMIT_LW_GD(:) = XSTEFAN * ZTSRAD_GD(:)**4 + (1 - ZEMIS_GD(:)) / ZEMIS_GD(:) * DMT%XABS_LW_GARDEN(:)
  ZQV_GD(:) = 0.
!MV202609 garden thermal roughness (z0h)
!* exchange coefficients of the garden: computed and returned by the garden model
!* itself (GARDEN_CBS / GARDEN of src_proxi_SVAT, section 8.2 above) and handed
!* over here directly through the argument list of the call. They are exported in
!* the PCD_GARDEN_CAN / PCH_GARDEN_CAN columns and returned to the caller (and to
!* a coupled host as teb_tch_gd/teb_tcm_gd). For the EXTERNAL garden the proxy is
!* not called at all and these arrays keep the values URBAN_DRAG computed in its
!* OGARDEN_EXT branch (as in COSMO-TEB)
  !
  IF (TOPTS%CTYPE_GARDEN == 'EXT' .OR. TOPTS%CTYPE_GARDEN == 'EXT_NEU') THEN
    ZH_GD(:) = PH_GD_EXT(:)
    ZLE_GD(:) = PLE_GD_EXT(:)
    ZEVAP_GD(:) = PEVAP_GD_EXT(:)
    ZRUNOFF_GD(:) = PRUNOFF_GD_EXT(:)
    ZQV_GD(:) = PQV_GD_EXT(:)
    ZHU_AGG_GD(:) = PQV_GD_EXT(:)/ZQSAT_GD(:)
    ZHU_AGG_GD(:) = MIN(ZHU_AGG_GD(:), 1.)
    ZHU_AGG_GD(:) = MAX(ZHU_AGG_GD(:), 0.01)
    ! COSMO+TEB GARDEN
    ZRN_GD(:) =  DMT%XABS_SW_GARDEN(:) + DMT%XABS_LW_GARDEN(:)
    !MV202609 CBS scheme of the garden
    !* the external model provides a single set of fluxes (already computed for the
    !* averaged forcing), so both branches of the tau split carry the same flux
    ZPH_GD_CAN (:) = ZH_GD(:)
    ZPH_GD_ATM (:) = ZH_GD(:)
    ZPLE_GD_CAN(:) = ZLE_GD(:)
    ZPLE_GD_ATM(:) = ZLE_GD(:)
  ENDIF
ELSE
  !
  ZRN_GD    (:) = 0.
  ZH_GD     (:) = 0.
  ZLE_GD    (:) = 0.
  ZGFLUX_GD (:) = 0.
  ZEVAP_GD  (:) = 0.
  ZRUNOFF_GD(:) = 0.
  !
  ZTSRAD_GD (:) = XUNDEF
  !
  ZUW_GD     (:) = 0.
  DMT%CAN%PAC_GARDEN(:) = 0.
  PCH_GD(:) = 0.
  PCD_GD(:) = 0.
  ZSFCO2_GD  (:) = 0.
  ZQSAT_GD   (:) = XUNDEF
  ZHU_AGG_GD (:) = XUNDEF
  PAC_GD_WAT (:) = XUNDEF
  ZEMIT_LW_GD(:) = 0.
  !MV202609 CBS scheme of the garden
  ZPH_GD_CAN (:) = 0.
  ZPH_GD_ATM (:) = 0.
  ZPLE_GD_CAN(:) = 0.
  ZPLE_GD_ATM(:) = 0.
  !
  DMT%XABS_SW_GARDEN (:) = XUNDEF
  DMT%XABS_LW_GARDEN (:) = XUNDEF
  !
  ENDIF
!
!*      8.3    Call ISBA for greenroofs
!              -------------------------
!
IF (TOPTS%LGREENROOF) THEN
  !
  !* the greenroof model of an INTERNAL greenroof is the proxy called here: it
  !* owns its PHU parameter and returns the multiplier of the roof node (a
  !* diagnostic: the greenroof does not couple back to the canyon air)
  IF (.NOT. OGREENROOF_EXT .AND. TOPTS%CTYPE_GREENROOF /= 'EXT' .AND. &
      TOPTS%CTYPE_GREENROOF /= 'EXT_NEU') THEN
    CALL GREENROOF(TOPTS%CTYPE_GREENROOF, HIMPLICIT_WIND, TOPTS%TTIME, FORC%XTSUN, PPEW_A_COEF, PPEW_B_COEF,  &
    ZPET_A_COEF, ZPEQ_A_COEF, ZPET_B_COEF, ZPEQ_B_COEF, PTSTEP, FORC%XZREF,  &
    FORC%XUREF, FORC%XTA, FORC%XQA, FORC%XEXNS, FORC%XEXNA,FORC%XRHOA, FORC%XCO2, FORC%XPS, FORC%XRAIN, FORC%XSNOW, FORC%XZENITH,  &
    ZREC_SW_RF, ZREC_LW_RF, FORC%XVMOD, PALB_GR_EXT, PEMIS_GR_EXT, PZ0_GR_EXT,  &
!MV202609 greenroof thermal roughness (z0h)
!* z0/z0h ratio of the greenroof: the scalar (thermal) coefficient of the
!* diagnostic balance is built from it (single value of TOPTS, the same one
!* that URBAN_DRAG exports and that the emulator of the driver uses)
    TOPTS%XZ0_O_Z0H_GR,                                      &
    ZRN_GR, ZH_GR, ZLE_GR,               &
    ZGFLUX_GR, ZSFCO2_GR, ZEVAP_GR, ZUW_GR,                             &
    DMT%XPAC_GREENROOF(1:1), ZQSAT_GR, ZTSRAD_GR, ZHU_AGG_GR,                &
    DMT%XG_GREENROOF_ROOF, ZRUNOFF_GR, ZDRAIN_GR, ZIRRIG_GR )
  ELSE
    !
    !* external greenroof ('EXT'/'EXT_NEU'): no proxy model is called. The state,
    !* the fluxes and the surface humidity come from the coupling interface; only
    !* the derived quantities are built here, exactly as for the external garden
    !* above: qsat(Ts), the moisture multiplier (clamp(q_v/qsat), as in COSMO-TEB)
    !* and the friction flux, with the wind of the host (no wind floor). The roof has
    !* a single exchange path, so the friction uses the momentum coefficient of that
    !* path (DMT%XPCD_GREENROOF_ATM(1:1), from URBAN_DRAG) and its neutral value only when the
    !* coefficient is not available yet (first sub-step of a run)
    ZQSAT_GR(:)   = QSAT(ZTSRAD_GR(:), FORC%XPS(:))
!MV202609 friction of the external surfaces (URBAN_DRAG momentum coefficient)
    WHERE (DMT%XPCD_GREENROOF_ATM(:) > 0. .AND. DMT%XPCD_GREENROOF_ATM(:) < XUNDEF)
      ZUW_GR(:) = - DMT%XPCD_GREENROOF_ATM(:) * FORC%XVMOD(:)**2
    ELSEWHERE
      DMT%XPCD_GREENROOF_ATM(:) = GARDEN_PCD_NEUTRAL(FORC%XUREF(:), PZ0_GR_EXT(:))
      ZUW_GR(:) = - DMT%XPCD_GREENROOF_ATM(:) * FORC%XVMOD(:)**2
    END WHERE
    ZHU_AGG_GR(:) = PQV_GR_EXT(:)/ZQSAT_GR(:)
    ZHU_AGG_GR(:) = MIN(ZHU_AGG_GR(:), 1.)
    ZHU_AGG_GR(:) = MAX(ZHU_AGG_GR(:), 0.01)
    DMT%XPAC_GREENROOF(:)     = 0.      ! no implicit coupling of an external surface (as in COSMO-TEB)
    ZGFLUX_GR(:)  = 0.
    ZSFCO2_GR(:)  = 0.
    !* the remaining outputs of the greenroof model (no soil, no drainage, no
    !* irrigation) are zero in that mode, exactly as in the proxy
    DMT%XG_GREENROOF_ROOF(:) = 0.
    ZDRAIN_GR(:) = 0.
    ZIRRIG_GR(:) = 0.
  END IF
  !
  !
  PAC_GR_WAT(:) = DMT%XPAC_GREENROOF(:)
  DMT%XABS_SW_GREENROOF(:) = (1.-ZALB_GR(:)) * ZREC_SW_RF
  DMT%XABS_LW_GREENROOF(:) = ZEMIS_GR * ZREC_LW_RF - XSTEFAN * ZEMIS_GR * ZTSRAD_GR**4
  !
  IF (OGREENROOF_EXT .OR. TOPTS%CTYPE_GREENROOF == 'EXT' .OR. &
      TOPTS%CTYPE_GREENROOF == 'EXT_NEU') THEN
    ZH_GR(:) = PH_GR_EXT(:)
    ZLE_GR(:) = PLE_GR_EXT(:)
    ZEVAP_GR(:) = PEVAP_GR_EXT(:)
    ZRUNOFF_GR(:) = PRUNOFF_GR_EXT(:)
    ZRN_GR(:) =  DMT%XABS_SW_GREENROOF(:) + DMT%XABS_LW_GREENROOF(:)
  ENDIF
ELSE
  !
  ZRN_GR    (:) = 0.
  ZH_GR     (:) = 0.
  ZLE_GR    (:) = 0.
  ZGFLUX_GR (:) = 0.
  ZEVAP_GR  (:) = 0.
  ZRUNOFF_GR(:) = 0.
  ZDRAIN_GR (:) = 0.
  !
  ZTSRAD_GR (:) = XUNDEF
  !
  ZUW_GR    (:) = 0.
  DMT%XPAC_GREENROOF(:) = 0.
  ZSFCO2_GR (:) = 0.
  ZQSAT_GR  (:) = XUNDEF
  ZHU_AGG_GR(:) = XUNDEF
  !
  DMT%XIRRIG_GREENROOF (:) = 0.
  DMT%XABS_SW_GREENROOF(:) = XUNDEF
  DMT%XABS_LW_GREENROOF(:) = XUNDEF
  DMT%XG_GREENROOF_ROOF(:) = XUNDEF
  !
ENDIF

END SUBROUTINE TEB_GARDEN2
!-------------------------------------------------------------------------------

!
!-------------------------------------------------------------------------------
!
!
END SUBROUTINE TEB_GARDEN
