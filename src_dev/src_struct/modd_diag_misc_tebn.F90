!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!     ############################
      MODULE MODD_DIAG_MISC_TEB_n
!     ############################
!
!!****  *MODD_DIAG_MISC_TEB - declaration of packed surface parameters for TEB scheme
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
!!      P. Le Moigne   *Meteo France*
!!
!!    MODIFICATIONS
!!    -------------
!!      Original       07/10/04
!!      C de Munck        02/13  adding runoff contributions for teb garden  
!!      V. Masson      06/2013  splits module in two
!
!
!*       0.   DECLARATIONS
!             ------------
!
!
!
USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
USE PARKIND1  ,ONLY : JPRB
!
IMPLICIT NONE
!
TYPE DIAG_MISC_TEB_t
!
!* miscellaneous variables
!
  REAL, POINTER, DIMENSION(:)   :: XZ0_TOWN  ! town roughness length
  REAL, POINTER, DIMENSION(:)   :: XQF_BLD   ! domestic heating
  REAL, POINTER, DIMENSION(:)   :: XFLX_BLD ! heat flux from bld
  REAL, POINTER, DIMENSION(:)   :: XQF_TOWN  ! total anthropogenic heat
  REAL, POINTER, DIMENSION(:)   :: XDQS_TOWN ! storage inside building
!
  REAL, POINTER, DIMENSION(:)   :: XH_WALL_A   ! wall sensible heat flux          (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XH_WALL_B   ! wall sensible heat flux          (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XH_ROOF     ! roof sensible heat flux          (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XH_ROAD     ! road sensible heat flux          (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XH_STRLROOF ! structural roof sens. heat flux  (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XH_BLT      ! built surf sensible heat flux    (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XRN_WALL_A  ! net radiation at wall            (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XRN_WALL_B  ! net radiation at wall            (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XRN_ROOF    ! net radiation at roof            (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XRN_ROAD    ! net radiation at road            (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XRN_STRLROOF !net radiation at structural roofs(W/m2)
  REAL, POINTER, DIMENSION(:)   :: XRN_BLT     ! net radiation at built surf      (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XGFLUX_WALL_A !net wall conduction flux        (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XGFLUX_WALL_B !net wall conduction flux        (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XGFLUX_ROOF ! net roof conduction flux         (W/m2)                                         
  REAL, POINTER, DIMENSION(:)   :: XGFLUX_ROAD ! net road conduction flux         (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XGFLUX_STRLROOF !net structural roof cond flux (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XGFLUX_BLT  ! net built surf conduction flux   (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XLE_ROOF    ! roof latent heat flux            (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XLE_ROAD    ! road latent heat flux            (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XLE_STRLROOF !structural roof latent heat flux (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XLE_BLT     ! built surf latent heat flux      (W/m2)
!MV202609 CBS scheme of the road (snow-to-atmosphere branch diagnostics)
!* Branch diagnostics of the snow-on-road exchange: they are computed by the snow
!* scheme of TEB (URBAN_SNOW_EVOL, an INTENT(OUT) argument of TEB) and they are
!* READ by the canyon air nodes (AVG_URBAN_FLUXES, TEB_GARDEN2) of the SAME
!* sub-step, which runs BEFORE the snow scheme: they are the value of the previous
!* sub-step, so they must be PERSISTENT. As automatic arrays of TEB_GARDEN_STRUCT
!* they were read before being written (undefined values, seen only when the road
!* snow fraction is non-zero; the garbage could also be NaN and trap the run).
  REAL, POINTER, DIMENSION(:)   :: XPHSN_RD_CAN ! snow -> canyon air sensible heat (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XPHSN_RD_ATM ! snow -> forcing level sensible heat (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XPLESN_RD_CAN ! snow -> canyon air latent heat (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XPLESN_RD_ATM ! snow -> forcing level latent heat (W/m2)
!
  REAL, POINTER, DIMENSION(:)   :: XRUNOFF_TOWN      ! aggregated water runoff for town      (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XIRRIG_GARDEN     ! summer ground irrigation rate         (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XRUNOFF_ROAD      ! water runoff for roads                (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XIRRIG_ROAD       ! road man-made watering rate           (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XRUNOFF_ROOF      ! aggregated water runoff for roofs     (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XRUNOFF_STRLROOF  ! water runoff for structural roofs     (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XIRRIG_GREENROOF  ! summer ground irrigation rate         (kg/m2/s)
!
  REAL, POINTER, DIMENSION(:)   :: XABS_SW_ROOF      ! absorbed shortwave radiation over roofs
  REAL, POINTER, DIMENSION(:)   :: XABS_SW_SNOW_ROOF ! absorbed longwave radiation over roofs
  REAL, POINTER, DIMENSION(:)   :: XABS_LW_ROOF      ! absorbed shortwave radiation over roofs
  REAL, POINTER, DIMENSION(:)   :: XABS_LW_SNOW_ROOF ! absorbed longwave radiation over roofs
  REAL, POINTER, DIMENSION(:)   :: XABS_SW_ROAD      ! absorbed shortwave radiation over roads
  REAL, POINTER, DIMENSION(:)   :: XABS_SW_SNOW_ROAD ! absorbed longwave radiation over roads
  REAL, POINTER, DIMENSION(:)   :: XABS_LW_ROAD      ! absorbed shortwave radiation over roads
  REAL, POINTER, DIMENSION(:)   :: XABS_LW_SNOW_ROAD ! absorbed longwave radiation over roads
  REAL, POINTER, DIMENSION(:)   :: XABS_SW_WALL_A    ! absorbed shortwave radiation over walls
  REAL, POINTER, DIMENSION(:)   :: XABS_SW_WALL_B    ! absorbed shortwave radiation over walls
  REAL, POINTER, DIMENSION(:)   :: XABS_LW_WALL_A    ! absorbed shortwave radiation over walls
  REAL, POINTER, DIMENSION(:)   :: XABS_LW_WALL_B    ! absorbed shortwave radiation over walls
  REAL, POINTER, DIMENSION(:)   :: XABS_SW_GARDEN    ! absorbed shortwave radiation over green areas
  REAL, POINTER, DIMENSION(:)   :: XABS_LW_GARDEN    ! absorbed shortwave radiation over green areas
  REAL, POINTER, DIMENSION(:)   :: XABS_SW_GREENROOF ! absorbed shortwave radiation over green roofs
  REAL, POINTER, DIMENSION(:)   :: XABS_LW_GREENROOF ! absorbed shortwave radiation over green roofs
  REAL, POINTER, DIMENSION(:)   :: XG_GREENROOF_ROOF ! Heat flux between green roof and structural roof
  REAL, POINTER, DIMENSION(:)   :: XABS_SW_PANEL     ! absorbed shortwave radiation over solar panels
  REAL, POINTER, DIMENSION(:)   :: XABS_LW_PANEL     ! absorbed longwave  radiation over solar panels
!
  REAL, POINTER, DIMENSION(:)   :: XRN_PANEL         ! net radiation           over solar panels (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XH_PANEL          ! sensible heat flux      over solar panels (W/m2)
  REAL, POINTER, DIMENSION(:)   :: XTHER_PROD_PANEL  ! thermal      production of   solar panels (W/m2 thermal panel)
  REAL, POINTER, DIMENSION(:)   :: XPHOT_PROD_PANEL  ! photovoltaic production of   solar panels (W/m2 photovoltaic panel)
  REAL, POINTER, DIMENSION(:)   :: XPROD_PANEL       !              production of   solar panels (W/m2 panel)
  REAL, POINTER, DIMENSION(:)   :: XTHER_PROD_BLD    ! thermal      production of   solar panels (W/m2 bld)
  REAL, POINTER, DIMENSION(:)   :: XPHOT_PROD_BLD    ! photovoltaic production of   solar panels (W/m2 bld)

  REAL, POINTER, DIMENSION(:)   :: XH_BLD_COOL       ! Sensible cooling energy demand  
                                                     ! of the building [W m-2(bld)]
  REAL, POINTER, DIMENSION(:)   :: XT_BLD_COOL       ! Total cooling energy demand  
                                                     ! of the building [W m-2(bld)]
  REAL, POINTER, DIMENSION(:)   :: XH_BLD_HEAT       ! Heating energy demand       
                                                     ! of the building [W m-2(bld)]
  REAL, POINTER, DIMENSION(:)   :: XLE_BLD_COOL      ! Latent cooling energy demand 
                                                     ! of the building [W m-2(bld)]
  REAL, POINTER, DIMENSION(:)   :: XLE_BLD_HEAT      ! Latent heating energy demand 
                                                     ! of the building [W m-2(bld)]
  REAL, POINTER, DIMENSION(:)   :: XH_WASTE          ! Sensible waste heat from HVAC system
                                                     ! [W m-2(tot)]
  REAL, POINTER, DIMENSION(:)   :: XLE_WASTE         ! Latent waste heat from HVAC system
                                                     ! [W m-2(tot)]
  REAL, POINTER, DIMENSION(:)   :: XHVAC_COOL        ! Energy consumption of the cooling system
                                                     ! [W m-2(bld)]
  REAL, POINTER, DIMENSION(:)   :: XHVAC_HEAT        ! Energy consumption of the heating system
                                                     ! [W m-2(bld)]
  REAL, POINTER, DIMENSION(:)   :: XCAP_SYS          ! Actual capacity of the cooling system
                                                     ! [W m-2(bld)] 
  REAL, POINTER, DIMENSION(:)   :: XM_SYS            ! Actual HVAC mass flow rate 
                                                     ! [kg s-1 m-2(bld)]
  REAL, POINTER, DIMENSION(:)   :: XCOP              ! COP of the cooling system
  REAL, POINTER, DIMENSION(:)   :: XQ_SYS            ! Supply air specific humidity [kg kg-1]
  REAL, POINTER, DIMENSION(:)   :: XT_SYS            ! Supply air temperature [K]
  REAL, POINTER, DIMENSION(:)   :: XTR_SW_WIN        ! Solar radiation transmitted throught
                                                     ! windows [W m-2(bld)]
  REAL, POINTER, DIMENSION(:)   :: XFAN_POWER        ! HVAC fan power
  REAL, POINTER, DIMENSION(:)   :: XABS_SW_WIN       ! window absorbed shortwave radiation [W m-2] 
  REAL, POINTER, DIMENSION(:)   :: XABS_LW_WIN       ! absorbed infrared rad. [W m-2]

  REAL, POINTER, DIMENSION(:)   :: XEMIT_LW_FAC      ! LW flux emitted by the facade (W/m2 facade)
  REAL, POINTER, DIMENSION(:)   :: XEMIT_LW_GRND     ! LW flux emitted by the ground (W/m2 ground = road + garden)
  REAL, POINTER, DIMENSION(:)   :: XT_RAD_IND     !Indoor mean radiant temperature [K]
  REAL, POINTER, DIMENSION(:)   :: XREF_SW_GRND ! total solar rad reflected by ground
  REAL, POINTER, DIMENSION(:)   :: XREF_SW_FAC ! total solar rad reflected by facade
  REAL, POINTER, DIMENSION(:)   :: XHU_BLD !Indoor relative humidity
!
  REAL, POINTER, DIMENSION(:)   :: XTCOOL_TARGET ! current cooling setpoint of indoor air
  REAL, POINTER, DIMENSION(:)   :: XTHEAT_TARGET ! current heating setpoint of indoor air
  REAL, POINTER, DIMENSION(:)   :: XQIN          ! current internal heat gains [W m-2(floor)]

!------------------------------------------------------------------------------
!

!MV202609 diagnostics moved into the container (Phase 4a)
!* The fields carry the diagnostics listed in
!* python_tests/diag_container/container_fields.csv (driver variable -> CSV column):
!* they are declared, allocated and deallocated here so that the diagnostics can
!* leave the argument lists of RUN_TEB_OFFLINE -> TEB_INTERFACE -> CALL_DRIVER in
!* the following sub-phases of the refactor.
  REAL, POINTER, DIMENSION(:)   :: XLE_ROAD_SNOW                    ! LE_ROAD_SNOW (CSV LE_ROAD_SNOW) - road latent heat flux of the snow-covered road (W/m2 road)
  REAL, POINTER, DIMENSION(:)   :: XLE_ROAD_WAT                     ! LE_ROAD_WAT (CSV LE_ROAD_WAT) - road latent heat flux of the snow-free road (W/m2 road)
  REAL, POINTER, DIMENSION(:)   :: XLE_ROOF_SNOW                    ! LE_ROOF_SNOW (CSV LE_ROOF_SNOW) - roof latent heat flux of the snow-covered roof (W/m2 roof)
  REAL, POINTER, DIMENSION(:)   :: XLE_ROOF_WAT                     ! LE_ROOF_WAT (CSV LE_ROOF_WAT) - roof latent heat flux of the snow-free roof (W/m2 roof)
  REAL, POINTER, DIMENSION(:)   :: XPAC_GARDEN_ATM                  ! PAC_GARDEN_ATM (CSV PAC_GARDEN_ATM) - garden aerodynamical conductance (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPAC_ROAD_ATM                    ! PAC_ROAD_ATM (CSV PAC_ROAD_ATM) - road   aerodynamical conductance (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPAC_ROAD_ATM_WAT                ! PAC_ROAD_ATM_WAT (CSV PAC_ROAD_ATM_WAT) - road water conductance (forcing level, water-limited)
  REAL, POINTER, DIMENSION(:)   :: XPAC_ROAD_WAT                    ! PAC_ROAD_WAT (CSV PAC_ROAD_WAT) - road water conductance (canyon, water-limited)
  REAL, POINTER, DIMENSION(:)   :: XPCDN_GARDEN_ATM                 ! PCDN_GARDEN_ATM (CSV PCDN_GARDEN_ATM) - garden neutral drag coefficient (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPCDN_GARDEN_CAN                 ! PCDN_GARDEN_CAN (CSV PCDN_GARDEN_CAN) - garden neutral drag coefficient (canyon)
  REAL, POINTER, DIMENSION(:)   :: XPCDN_ROAD_ATM                   ! PCDN_ROAD_ATM (CSV PCDN_ROAD_ATM) - road   neutral drag coefficient (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPCDN_ROAD_CAN                   ! PCDN_ROAD_CAN (CSV PCDN_ROAD_CAN) - road   neutral drag coefficient (canyon)
  REAL, POINTER, DIMENSION(:)   :: XPCD_ROAD_ATM                    ! PCD_ROAD_ATM (CSV PCD_ROAD_ATM) - road   drag coefficient (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPCD_ROAD_CAN                    ! PCD_ROAD_CAN (CSV PCD_ROAD_CAN) - road   drag coefficient (canyon)
  REAL, POINTER, DIMENSION(:)   :: XPCH_ROAD_ATM                    ! PCH_ROAD_ATM (CSV PCH_ROAD_ATM) - road   drag coefficient for heat (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPDN_RD                          ! PDN_RD (CSV PDN_RD) - road snow fraction (-)
  REAL, POINTER, DIMENSION(:)   :: XPDN_RF                          ! PDN_RF (CSV PDN_RF) - roof snow fraction (-)
  REAL, POINTER, DIMENSION(:)   :: XPH_ROAD                         ! PH_ROAD (CSV H_ROAD) - road sensible heat flux, CBS scheme [W m-2]
  REAL, POINTER, DIMENSION(:)   :: XPH_ROAD_ATM                     ! PH_ROAD_ATM (CSV H_ROAD_ATM) - road sensible heat flux, road -> forcing level [W m-2]
  REAL, POINTER, DIMENSION(:)   :: XPH_ROAD_CAN                     ! PH_ROAD_CAN (CSV H_ROAD_CAN) - road sensible heat flux, road -> canyon air [W m-2]
  REAL, POINTER, DIMENSION(:)   :: XPLE_ROAD                        ! PLE_ROAD (CSV LE_ROAD) - road latent heat flux, CBS scheme [W m-2]
  REAL, POINTER, DIMENSION(:)   :: XPLE_ROAD_ATM                    ! PLE_ROAD_ATM (CSV LE_ROAD_ATM) - road latent heat flux, road -> forcing level [W m-2]
  REAL, POINTER, DIMENSION(:)   :: XPLE_ROAD_CAN                    ! PLE_ROAD_CAN (CSV LE_ROAD_CAN) - road latent heat flux, road -> canyon air [W m-2]
  REAL, POINTER, DIMENSION(:)   :: XPPHI_CAN1                       ! PPHI_CAN1 (CSV PHI_CAN1) - free layer air temperature / theta* ratio of the MOST profile [-]
  REAL, POINTER, DIMENSION(:)   :: XPRI_GARDEN_ATM                  ! PRI_GARDEN_ATM (CSV PRI_GARDEN_ATM) - garden Richardson number (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPRI_GARDEN_CAN                  ! PRI_GARDEN_CAN (CSV PRI_GARDEN_CAN) - garden Richardson number (canyon)
  REAL, POINTER, DIMENSION(:)   :: XPRI_ROAD_ATM                    ! PRI_ROAD_ATM (CSV PRI_ROAD_ATM) - road   Richardson number (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPRI_ROAD_CAN                    ! PRI_ROAD_CAN (CSV PRI_ROAD_CAN) - road   Richardson number (canyon)
  REAL, POINTER, DIMENSION(:)   :: XPT_CAN0                         ! PT_CAN0 (CSV T_CAN0) - canyon air temperature without tau [K]
  REAL, POINTER, DIMENSION(:)   :: XPT_CAN1                         ! PT_CAN1 (CSV T_CAN1) - free layer (second canopy) air temperature [K]
  REAL, POINTER, DIMENSION(:)   :: XZZ0H_GARDEN_ATM                 ! ZZ0H_GARDEN_ATM (CSV ZZ0H_GARDEN_ATM) - garden roughness length for heat (atm.)
  REAL, POINTER, DIMENSION(:)   :: XZZ0H_GARDEN_CAN                 ! ZZ0H_GARDEN_CAN (CSV ZZ0H_GARDEN_CAN) - garden roughness length for heat (canyon)
  REAL, POINTER, DIMENSION(:)   :: XZZ0H_ROAD_ATM                   ! ZZ0H_ROAD_ATM (CSV ZZ0H_ROAD_ATM) - road   roughness length for heat (atm.)
  REAL, POINTER, DIMENSION(:)   :: XZZ0H_ROAD_CAN                   ! ZZ0H_ROAD_CAN (CSV ZZ0H_ROAD_CAN) - road   roughness length for heat (canyon)
  REAL, POINTER, DIMENSION(:)   :: XAHF_TRAFFIC_NOW                 ! ahf_traffic_now (CSV AHF_TRAFFIC) - OUT Anthropogenic heat flux by traffic (current value)
  REAL, POINTER, DIMENSION(:)   :: XAC_RD                           ! teb_ac_rd (CSV PAC_ROAD_CAN) - OUT Road aerodynamical conductance
  REAL, POINTER, DIMENSION(:)   :: XAC_RF                           ! teb_ac_rf - OUT Roof aerodynamical conductance
  REAL, POINTER, DIMENSION(:)   :: XAC_TOP                          ! teb_ac_top - OUT Canyon-atm. aerodynamical conductance
  REAL, POINTER, DIMENSION(:)   :: XAC_WL                           ! teb_ac_wl - OUT Wall aerodynamical conductance
  REAL, POINTER, DIMENSION(:)   :: XALB_SO                          ! teb_alb_so - OUT town solar albedo
  REAL, POINTER, DIMENSION(:)   :: XALB_TH                          ! teb_alb_th - OUT town thermal albedo
  REAL, POINTER, DIMENSION(:)   :: XCD_GARDEN_ATM                   ! teb_cd_garden_atm (CSV PCD_GARDEN_ATM)
  REAL, POINTER, DIMENSION(:)   :: XCH_GARDEN_ATM                   ! teb_ch_garden_atm (CSV PCH_GARDEN_ATM)
  REAL, POINTER, DIMENSION(:)   :: XEVAP_GARDEN                     ! teb_evap_garden (CSV EVAP_GARDEN) - OUT total evaporation over the garden (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XEVAP_GREENROOF                  ! teb_evap_greenroof (CSV EVAP_GREENROOF) - OUT total evaporation over the greenroof (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XFRSNOW                          ! teb_frsnow - OUT snow fraction over town
  REAL, POINTER, DIMENSION(:)   :: XGFLUX_TOWN                      ! teb_gflux (CSV GFLUX_TOWN) - OUT Flux through the ground for town
  REAL, POINTER, DIMENSION(:)   :: XH_GARDEN                        ! teb_h_garden (CSV H_GARDEN) - OUT sensible heat flux over the garden (W/m2 garden)
  REAL, POINTER, DIMENSION(:)   :: XH_GARDEN_ATM                    ! teb_h_garden_atm (CSV H_GARDEN_ATM) - OUT garden sensible heat flux, garden -> forcing level (W/m2 garden)
  REAL, POINTER, DIMENSION(:)   :: XH_GARDEN_CAN                    ! teb_h_garden_can (CSV H_GARDEN_CAN) - OUT garden sensible heat flux, garden -> canyon air (W/m2 garden)
  REAL, POINTER, DIMENSION(:)   :: XH_GREENROOF                     ! teb_h_greenroof (CSV H_GREENROOF) - OUT sensible heat flux over the greenroof (W/m2 greenroof)
  REAL, POINTER, DIMENSION(:)   :: XHSNOW_TOWN                      ! teb_hsnow_town - OUT town snow depth
  REAL, POINTER, DIMENSION(:)   :: XHSNOW_TOWN_NOW                  ! teb_hsnow_town_now - OUT town snow depth at previous time-step
  REAL, POINTER, DIMENSION(:)   :: XLE_GARDEN                       ! teb_le_garden (CSV LE_GARDEN) - OUT latent heat flux over the garden (W/m2 garden)
  REAL, POINTER, DIMENSION(:)   :: XLE_GARDEN_ATM                   ! teb_le_garden_atm (CSV LE_GARDEN_ATM) - OUT garden latent  heat flux, garden -> forcing level (W/m2 garden)
  REAL, POINTER, DIMENSION(:)   :: XLE_GARDEN_CAN                   ! teb_le_garden_can (CSV LE_GARDEN_CAN) - OUT garden latent  heat flux, garden -> canyon air (W/m2 garden)
  REAL, POINTER, DIMENSION(:)   :: XLE_GREENROOF                    ! teb_le_greenroof (CSV LE_GREENROOF) - OUT latent heat flux over the greenroof (W/m2 greenroof)
  REAL, POINTER, DIMENSION(:)   :: XLE_TOWN                         ! teb_lhfl (CSV LE_TOWN) - OUT latent heat flux over town
  REAL, POINTER, DIMENSION(:)   :: XLHFL_SNOW                       ! teb_lhfl_snow - OUT latent heat flux over snow
  REAL, POINTER, DIMENSION(:)   :: XPAC_GARDEN                      ! teb_pac_garden (CSV PAC_GARDEN) - OUT garden aerodynamic conductance (m/s)
  REAL, POINTER, DIMENSION(:)   :: XPAC_GREENROOF                   ! teb_pac_greenroof (CSV PAC_GREENROOF) - OUT green roof conductance (m/s)
  REAL, POINTER, DIMENSION(:)   :: XPAC_GREENROOF_ATM               ! teb_pac_greenroof_atm (CSV PAC_GREENROOF_ATM) - OUT greenroof aerodynamical conductance (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPCD_GREENROOF_ATM               ! teb_pcd_greenroof_atm (CSV PCD_GREENROOF_ATM) - OUT greenroof drag coefficient (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPCDN_GREENROOF_ATM              ! teb_pcdn_greenroof_atm (CSV PCDN_GREENROOF_ATM) - OUT greenroof neutral drag coefficient (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPCH_GREENROOF_ATM               ! teb_pch_greenroof_atm (CSV PCH_GREENROOF_ATM) - OUT greenroof drag coefficient for heat (atm.)
  REAL, POINTER, DIMENSION(:)   :: XPHU_GARDEN                      ! teb_phu_garden (CSV PHU_GARDEN) - OUT garden aggregated relative humidity (-)
  REAL, POINTER, DIMENSION(:)   :: XPHU_GREENROOF                   ! teb_phu_greenroof (CSV PHU_GREENROOF) - OUT greenroof aggregated relative humidity (-)
  REAL, POINTER, DIMENSION(:)   :: XPRI_GREENROOF_ATM               ! teb_pri_greenroof_atm (CSV PRI_GREENROOF_ATM) - OUT greenroof Richardson number (atm.)
  REAL, POINTER, DIMENSION(:)   :: XQSAT_GARDEN                     ! teb_qsat_garden (CSV QSAT_GARDEN) - OUT garden saturation specific humidity (kg/kg)
  REAL, POINTER, DIMENSION(:)   :: XQSAT_GREENROOF                  ! teb_qsat_greenroof (CSV QSAT_GREENROOF) - OUT greenroof saturation specific humidity (kg/kg)
  REAL, POINTER, DIMENSION(:)   :: XQSTOWN_S                        ! teb_qstown_s - OUT town surface specific humidity from flux calculation (kg/kg)
  REAL, POINTER, DIMENSION(:)   :: XQVFL                            ! teb_qvfl - OUT evaporation (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XRN_GARDEN                       ! teb_rn_garden (CSV RN_GARDEN) - OUT net radiation over the garden (W/m2 garden)
  REAL, POINTER, DIMENSION(:)   :: XRN_GREENROOF                    ! teb_rn_greenroof (CSV RN_GREENROOF) - OUT net radiation over the greenroof (W/m2 greenroof)
  REAL, POINTER, DIMENSION(:)   :: XRN_TOWN                         ! teb_rn_town (CSV RN_TOWN) - OUT Net radiation over town
  REAL, POINTER, DIMENSION(:)   :: XRSNOW_TOWN                      ! teb_rsnow_town - OUT town snow layers density (kg/m3)
  REAL, POINTER, DIMENSION(:)   :: XRSNOW_TOWN_NOW                  ! teb_rsnow_town_now - OUT town snow layers density (kg/m3) at previous time-step
  REAL, POINTER, DIMENSION(:)   :: XH_TOWN                          ! teb_shfl (CSV H_TOWN) - OUT sensible heat flux over town
  REAL, POINTER, DIMENSION(:)   :: XH_ROAD_FR                       ! teb_shfl_rd - OUT Sensible heat flux over road
  REAL, POINTER, DIMENSION(:)   :: XH_ROOF_FR                       ! teb_shfl_rf - OUT Sensible heat flux over roof
  REAL, POINTER, DIMENSION(:)   :: XSHFL_SNOW                       ! teb_shfl_snow - OUT sensible heat flux over snow
  REAL, POINTER, DIMENSION(:)   :: XH_WALL_FR                       ! teb_shfl_wl - OUT Sensible heat flux over wall
  REAL, POINTER, DIMENSION(:)   :: XSNOW_MELT                       ! teb_snow_melt - OUT Snow melt for built & impervious part (kg/m2)
  REAL, POINTER, DIMENSION(:)   :: XSOBS                            ! teb_sobs - OUT Shortwave radiation absorbed by garden
  REAL, POINTER, DIMENSION(:)   :: XSOLAR_PROD                      ! teb_solar_prod (CSV SOLAR_PROD) - OUT Averaged Energy production of solar panel on roofs (W/m2 bld  )
  REAL, POINTER, DIMENSION(:)   :: XTCH_RD                          ! teb_tch_rd (CSV PCH_ROAD_CAN) - OUT road transfer coefficient for heat
  REAL, POINTER, DIMENSION(:)   :: XTCH_RF                          ! teb_tch_rf - OUT roof transfer coefficient for heat
  REAL, POINTER, DIMENSION(:)   :: XTCH_TOP                         ! teb_tch_top - OUT between canyon top and atm. transfer coefficient for hea
  REAL, POINTER, DIMENSION(:)   :: XTCH_TOWN                        ! teb_tch_town - OUT Heat exchange coefficient
  REAL, POINTER, DIMENSION(:)   :: XTCH_WL                          ! teb_tch_wl - OUT wall transfer coefficient for heat
  REAL, POINTER, DIMENSION(:)   :: XTHBS                            ! teb_thbs - OUT Longwave radiation absorbed by garden
  REAL, POINTER, DIMENSION(:)   :: XTS_GARDEN                       ! teb_ts_garden (CSV TS_GARDEN) - OUT garden surface temperature (K)
  REAL, POINTER, DIMENSION(:)   :: XTS_GREENROOF                    ! teb_ts_greenroof (CSV TS_GREENROOF) - OUT greenroof surface temperature (K)
  REAL, POINTER, DIMENSION(:)   :: XTS_ROAD                         ! teb_tsroad (CSV T_ROAD1) - OUT road surface temperature   [K]
  REAL, POINTER, DIMENSION(:)   :: XTS_ROOF                         ! teb_tsroof (CSV T_ROOF1) - OUT roof surface temperature   [K]
  REAL, POINTER, DIMENSION(:)   :: XTSSNOW_TOWN                     ! teb_tssnow_town - OUT town snow surface temperature (K)
  REAL, POINTER, DIMENSION(:)   :: XTSSNOW_TOWN_NOW                 ! teb_tssnow_town_now - OUT town snow surface temperature (K) at previous time-step
  REAL, POINTER, DIMENSION(:)   :: XTSTOWN_S                        ! teb_tstown_s - OUT town surface temperature from flux calculation
  REAL, POINTER, DIMENSION(:)   :: XTSTOWN_S_NOW                    ! teb_tstown_s_now - OUT town surface temperature from flux calculation at previous time-step
  REAL, POINTER, DIMENSION(:)   :: XTS_WALL_A                       ! teb_tswalla (CSV T_WALLA1) - OUT wall 'A' surface temperature [K]
  REAL, POINTER, DIMENSION(:)   :: XTS_WALL_B                       ! teb_tswallb (CSV T_WALLB1) - OUT wall 'B' surface temperature [K]
  REAL, POINTER, DIMENSION(:)   :: XUCANYON                         ! teb_ucanyon - OUT u-wind component of wind inside the canyon
  REAL, POINTER, DIMENSION(:)   :: XUSTAR_TOWN                      ! teb_ustar_town (CSV USTAR_TOWN) - OUT friction velocity over the town [m/s]
  REAL, POINTER, DIMENSION(:)   :: XVCANYON                         ! teb_vcanyon - OUT v-wind component of wind inside the canyon
  REAL, POINTER, DIMENSION(:)   :: XWIND_CANYON                     ! teb_wind_canyon (CSV U_CANYON) - OUT Wind speed in canyon
  REAL, POINTER, DIMENSION(:)   :: XWIND_TOP                        ! teb_wind_top (CSV WIND_TOP) - OUT Wind speed at canyon top (m/s)
  REAL, POINTER, DIMENSION(:)   :: XWSNOW_TOWN                      ! teb_wsnow_town - OUT town snow (& liq. water) content (m H2O)
  REAL, POINTER, DIMENSION(:)   :: XWSNOW_TOWN_NOW                  ! teb_wsnow_town_now - OUT town snow (& liq. water) content (m H2O) at previous time-step
  REAL, POINTER, DIMENSION(:)   :: XWSTOWN                          ! teb_wstown - OUT town water content (m H2O)
  REAL, POINTER, DIMENSION(:)   :: XWSTOWN_NOW                      ! teb_wstown_now - OUT town water content (m H2O) at previous time-step
  REAL, POINTER, DIMENSION(:)   :: XZZ0H_GREENROOF_ATM              ! teb_zz0h_greenroof_atm (CSV ZZ0H_GREENROOF_ATM) - OUT greenroof roughness length for heat (atm.)
END TYPE DIAG_MISC_TEB_t

TYPE DIAG_MISC_TEB_NP_t
  !
  TYPE(DIAG_MISC_TEB_t), POINTER :: AL(:) => NULL()
  !
END TYPE DIAG_MISC_TEB_NP_t
!
CONTAINS
!
SUBROUTINE DIAG_MISC_TEB_INIT(YDIAG_MISC_TEB)
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: YDIAG_MISC_TEB
REAL(KIND=JPRB) :: ZHOOK_HANDLE
!MV202609 the absorbed-radiation fields were missing from the NULLIFY list
!* (they are allocated right after DIAG_MISC_TEB_INIT is called, so this is an
!* invariant repair, not a behaviour change; found by
!* python_tests/check_diag_container.py)
  NULLIFY(YDIAG_MISC_TEB%XABS_SW_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XABS_SW_SNOW_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XABS_LW_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XABS_LW_SNOW_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XABS_SW_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XABS_SW_SNOW_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XABS_LW_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XABS_LW_SNOW_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XABS_SW_WALL_A)
  NULLIFY(YDIAG_MISC_TEB%XABS_SW_WALL_B)
  NULLIFY(YDIAG_MISC_TEB%XABS_LW_WALL_A)
  NULLIFY(YDIAG_MISC_TEB%XABS_LW_WALL_B)
  NULLIFY(YDIAG_MISC_TEB%XABS_SW_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XABS_LW_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XABS_SW_GREENROOF)

!MV202609 diagnostics moved into the container (Phase 4a)
!* The fields carry the diagnostics listed in
!* python_tests/diag_container/container_fields.csv (driver variable -> CSV column):
!* they are declared, allocated and deallocated here so that the diagnostics can
!* leave the argument lists of RUN_TEB_OFFLINE -> TEB_INTERFACE -> CALL_DRIVER in
!* the following sub-phases of the refactor.
  NULLIFY(YDIAG_MISC_TEB%XLE_ROAD_SNOW)
  NULLIFY(YDIAG_MISC_TEB%XLE_ROAD_WAT)
  NULLIFY(YDIAG_MISC_TEB%XLE_ROOF_SNOW)
  NULLIFY(YDIAG_MISC_TEB%XLE_ROOF_WAT)
  NULLIFY(YDIAG_MISC_TEB%XPAC_GARDEN_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPAC_ROAD_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPAC_ROAD_ATM_WAT)
  NULLIFY(YDIAG_MISC_TEB%XPAC_ROAD_WAT)
  NULLIFY(YDIAG_MISC_TEB%XPCDN_GARDEN_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPCDN_GARDEN_CAN)
  NULLIFY(YDIAG_MISC_TEB%XPCDN_ROAD_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPCDN_ROAD_CAN)
  NULLIFY(YDIAG_MISC_TEB%XPCD_ROAD_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPCD_ROAD_CAN)
  NULLIFY(YDIAG_MISC_TEB%XPCH_ROAD_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPDN_RD)
  NULLIFY(YDIAG_MISC_TEB%XPDN_RF)
  NULLIFY(YDIAG_MISC_TEB%XPH_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XPH_ROAD_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPH_ROAD_CAN)
  NULLIFY(YDIAG_MISC_TEB%XPLE_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XPLE_ROAD_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPLE_ROAD_CAN)
  NULLIFY(YDIAG_MISC_TEB%XPPHI_CAN1)
  NULLIFY(YDIAG_MISC_TEB%XPRI_GARDEN_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPRI_GARDEN_CAN)
  NULLIFY(YDIAG_MISC_TEB%XPRI_ROAD_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPRI_ROAD_CAN)
  NULLIFY(YDIAG_MISC_TEB%XPT_CAN0)
  NULLIFY(YDIAG_MISC_TEB%XPT_CAN1)
  NULLIFY(YDIAG_MISC_TEB%XZZ0H_GARDEN_ATM)
  NULLIFY(YDIAG_MISC_TEB%XZZ0H_GARDEN_CAN)
  NULLIFY(YDIAG_MISC_TEB%XZZ0H_ROAD_ATM)
  NULLIFY(YDIAG_MISC_TEB%XZZ0H_ROAD_CAN)
  NULLIFY(YDIAG_MISC_TEB%XAHF_TRAFFIC_NOW)
  NULLIFY(YDIAG_MISC_TEB%XAC_RD)
  NULLIFY(YDIAG_MISC_TEB%XAC_RF)
  NULLIFY(YDIAG_MISC_TEB%XAC_TOP)
  NULLIFY(YDIAG_MISC_TEB%XAC_WL)
  NULLIFY(YDIAG_MISC_TEB%XALB_SO)
  NULLIFY(YDIAG_MISC_TEB%XALB_TH)
  NULLIFY(YDIAG_MISC_TEB%XCD_GARDEN_ATM)
  NULLIFY(YDIAG_MISC_TEB%XCH_GARDEN_ATM)
  NULLIFY(YDIAG_MISC_TEB%XEVAP_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XEVAP_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XFRSNOW)
  NULLIFY(YDIAG_MISC_TEB%XGFLUX_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XH_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XH_GARDEN_ATM)
  NULLIFY(YDIAG_MISC_TEB%XH_GARDEN_CAN)
  NULLIFY(YDIAG_MISC_TEB%XH_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XHSNOW_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XHSNOW_TOWN_NOW)
  NULLIFY(YDIAG_MISC_TEB%XLE_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XLE_GARDEN_ATM)
  NULLIFY(YDIAG_MISC_TEB%XLE_GARDEN_CAN)
  NULLIFY(YDIAG_MISC_TEB%XLE_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XLE_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XLHFL_SNOW)
  NULLIFY(YDIAG_MISC_TEB%XPAC_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XPAC_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XPAC_GREENROOF_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPCD_GREENROOF_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPCDN_GREENROOF_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPCH_GREENROOF_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPHU_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XPHU_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XPRI_GREENROOF_ATM)
  NULLIFY(YDIAG_MISC_TEB%XQSAT_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XQSAT_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XQSTOWN_S)
  NULLIFY(YDIAG_MISC_TEB%XQVFL)
  NULLIFY(YDIAG_MISC_TEB%XRN_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XRN_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XRN_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XRSNOW_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XRSNOW_TOWN_NOW)
  NULLIFY(YDIAG_MISC_TEB%XH_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XH_ROAD_FR)
  NULLIFY(YDIAG_MISC_TEB%XH_ROOF_FR)
  NULLIFY(YDIAG_MISC_TEB%XSHFL_SNOW)
  NULLIFY(YDIAG_MISC_TEB%XH_WALL_FR)
  NULLIFY(YDIAG_MISC_TEB%XSNOW_MELT)
  NULLIFY(YDIAG_MISC_TEB%XSOBS)
  NULLIFY(YDIAG_MISC_TEB%XSOLAR_PROD)
  NULLIFY(YDIAG_MISC_TEB%XTCH_RD)
  NULLIFY(YDIAG_MISC_TEB%XTCH_RF)
  NULLIFY(YDIAG_MISC_TEB%XTCH_TOP)
  NULLIFY(YDIAG_MISC_TEB%XTCH_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XTCH_WL)
  NULLIFY(YDIAG_MISC_TEB%XTHBS)
  NULLIFY(YDIAG_MISC_TEB%XTS_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XTS_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XTS_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XTS_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XTSSNOW_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XTSSNOW_TOWN_NOW)
  NULLIFY(YDIAG_MISC_TEB%XTSTOWN_S)
  NULLIFY(YDIAG_MISC_TEB%XTSTOWN_S_NOW)
  NULLIFY(YDIAG_MISC_TEB%XTS_WALL_A)
  NULLIFY(YDIAG_MISC_TEB%XTS_WALL_B)
  NULLIFY(YDIAG_MISC_TEB%XUCANYON)
  NULLIFY(YDIAG_MISC_TEB%XUSTAR_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XVCANYON)
  NULLIFY(YDIAG_MISC_TEB%XWIND_CANYON)
  NULLIFY(YDIAG_MISC_TEB%XWIND_TOP)
  NULLIFY(YDIAG_MISC_TEB%XWSNOW_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XWSNOW_TOWN_NOW)
  NULLIFY(YDIAG_MISC_TEB%XWSTOWN)
  NULLIFY(YDIAG_MISC_TEB%XWSTOWN_NOW)
  NULLIFY(YDIAG_MISC_TEB%XZZ0H_GREENROOF_ATM)
IF (LHOOK) CALL DR_HOOK("MODD_DIAG_MISC_TEB_N:DIAG_MISC_TEB_INIT",0,ZHOOK_HANDLE)
  NULLIFY(YDIAG_MISC_TEB%XZ0_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XQF_BLD)
  NULLIFY(YDIAG_MISC_TEB%XFLX_BLD)
  NULLIFY(YDIAG_MISC_TEB%XQF_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XDQS_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XH_WALL_A)
  NULLIFY(YDIAG_MISC_TEB%XH_WALL_B)
  NULLIFY(YDIAG_MISC_TEB%XH_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XH_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XH_STRLROOF)
  NULLIFY(YDIAG_MISC_TEB%XH_BLT)
  NULLIFY(YDIAG_MISC_TEB%XRN_WALL_A)
  NULLIFY(YDIAG_MISC_TEB%XRN_WALL_B)
  NULLIFY(YDIAG_MISC_TEB%XRN_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XRN_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XRN_STRLROOF)
  NULLIFY(YDIAG_MISC_TEB%XRN_BLT)
  NULLIFY(YDIAG_MISC_TEB%XGFLUX_WALL_A)
  NULLIFY(YDIAG_MISC_TEB%XGFLUX_WALL_B)
  NULLIFY(YDIAG_MISC_TEB%XGFLUX_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XGFLUX_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XGFLUX_STRLROOF)
  NULLIFY(YDIAG_MISC_TEB%XGFLUX_BLT)
  NULLIFY(YDIAG_MISC_TEB%XLE_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XLE_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XLE_STRLROOF)
  NULLIFY(YDIAG_MISC_TEB%XLE_BLT)
!MV202609 CBS scheme of the road (snow-to-atmosphere branch diagnostics)
  NULLIFY(YDIAG_MISC_TEB%XPHSN_RD_CAN)
  NULLIFY(YDIAG_MISC_TEB%XPHSN_RD_ATM)
  NULLIFY(YDIAG_MISC_TEB%XPLESN_RD_CAN)
  NULLIFY(YDIAG_MISC_TEB%XPLESN_RD_ATM)
  NULLIFY(YDIAG_MISC_TEB%XRUNOFF_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XIRRIG_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XRUNOFF_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XIRRIG_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XRUNOFF_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XRUNOFF_STRLROOF)
  NULLIFY(YDIAG_MISC_TEB%XIRRIG_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XABS_LW_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XG_GREENROOF_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XABS_SW_PANEL)
  NULLIFY(YDIAG_MISC_TEB%XABS_LW_PANEL)
  NULLIFY(YDIAG_MISC_TEB%XRN_PANEL)
  NULLIFY(YDIAG_MISC_TEB%XH_PANEL)
  NULLIFY(YDIAG_MISC_TEB%XTHER_PROD_PANEL)
  NULLIFY(YDIAG_MISC_TEB%XPHOT_PROD_PANEL)
  NULLIFY(YDIAG_MISC_TEB%XPROD_PANEL)
  NULLIFY(YDIAG_MISC_TEB%XTHER_PROD_BLD)
  NULLIFY(YDIAG_MISC_TEB%XPHOT_PROD_BLD)
  NULLIFY(YDIAG_MISC_TEB%XT_BLD_COOL)
  NULLIFY(YDIAG_MISC_TEB%XH_BLD_COOL)
  NULLIFY(YDIAG_MISC_TEB%XH_BLD_HEAT)
  NULLIFY(YDIAG_MISC_TEB%XLE_BLD_COOL)
  NULLIFY(YDIAG_MISC_TEB%XLE_BLD_HEAT)
  NULLIFY(YDIAG_MISC_TEB%XHVAC_COOL)
  NULLIFY(YDIAG_MISC_TEB%XHVAC_HEAT)
  NULLIFY(YDIAG_MISC_TEB%XH_WASTE)
  NULLIFY(YDIAG_MISC_TEB%XLE_WASTE)
  NULLIFY(YDIAG_MISC_TEB%XCAP_SYS)
  NULLIFY(YDIAG_MISC_TEB%XM_SYS)
  NULLIFY(YDIAG_MISC_TEB%XCOP)
  NULLIFY(YDIAG_MISC_TEB%XQ_SYS)
  NULLIFY(YDIAG_MISC_TEB%XT_SYS)
  NULLIFY(YDIAG_MISC_TEB%XTR_SW_WIN)
  NULLIFY(YDIAG_MISC_TEB%XFAN_POWER)
  NULLIFY(YDIAG_MISC_TEB%XABS_SW_WIN)
  NULLIFY(YDIAG_MISC_TEB%XABS_LW_WIN)
  NULLIFY(YDIAG_MISC_TEB%XEMIT_LW_GRND)
  NULLIFY(YDIAG_MISC_TEB%XEMIT_LW_FAC)
  NULLIFY(YDIAG_MISC_TEB%XT_RAD_IND)
  NULLIFY(YDIAG_MISC_TEB%XREF_SW_GRND)
  NULLIFY(YDIAG_MISC_TEB%XREF_SW_FAC)
  NULLIFY(YDIAG_MISC_TEB%XHU_BLD)
  NULLIFY(YDIAG_MISC_TEB%XTCOOL_TARGET)
  NULLIFY(YDIAG_MISC_TEB%XTHEAT_TARGET)
  NULLIFY(YDIAG_MISC_TEB%XQIN)
IF (LHOOK) CALL DR_HOOK("MODD_DIAG_MISC_TEB_N:DIAG_MISC_TEB_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE DIAG_MISC_TEB_INIT
!
SUBROUTINE DIAG_MISC_TEB_NP_INIT(YNDIAG_MISC_TEB,KPATCH)
TYPE(DIAG_MISC_TEB_NP_t), INTENT(INOUT) :: YNDIAG_MISC_TEB
INTEGER, INTENT(IN) :: KPATCH
INTEGER :: JP
REAL(KIND=JPRB) :: ZHOOK_HANDLE
IF (LHOOK) CALL DR_HOOK("MODD_DIAG_MISC_TEB_N:DIAG_MISC_TEB_NP_INIT",0,ZHOOK_HANDLE)
IF (.NOT.ASSOCIATED(YNDIAG_MISC_TEB%AL)) THEN
  ALLOCATE(YNDIAG_MISC_TEB%AL(KPATCH))
  DO JP=1,KPATCH
    CALL DIAG_MISC_TEB_INIT(YNDIAG_MISC_TEB%AL(JP))
  ENDDO
ELSE
  DO JP=1,KPATCH
    CALL DIAG_MISC_TEB_INIT(YNDIAG_MISC_TEB%AL(JP))
  ENDDO
  DEALLOCATE(YNDIAG_MISC_TEB%AL)
ENDIF  
IF (LHOOK) CALL DR_HOOK("MODD_DIAG_MISC_TEB_N:DIAG_MISC_TEB_NP_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE DIAG_MISC_TEB_NP_INIT



END MODULE MODD_DIAG_MISC_TEB_n
