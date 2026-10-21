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
!*       0.1  CBS branch diagnostics: one record per exchange path
!* The CBS scheme exchanges the road, the garden and the road snow with two air
!* reservoirs: the canyon air (CAN) and the forcing level (ATM). Both branches
!* carry the same quantities, so they share this record and it is used twice in
!* DIAG_MISC_TEB_t. The tau-weight of the aggregation (PTAU) mixes the two.
!*
TYPE TEB_CBS_BRANCH_t
  !* road <-> branch
  REAL, POINTER, DIMENSION(:)   :: PCDN_ROAD      ! neutral drag coefficient            (-)
  REAL, POINTER, DIMENSION(:)   :: PCD_ROAD       ! drag coefficient                    (-)
  REAL, POINTER, DIMENSION(:)   :: PRI_ROAD       ! Richardson number                   (-)
  REAL, POINTER, DIMENSION(:)   :: ZZ0H_ROAD      ! roughness length for heat           (m)
  REAL, POINTER, DIMENSION(:)   :: PAC_ROAD       ! aerodynamic conductance (CSV PAC_ROAD_CAN / PAC_ROAD_ATM)      (m/s)
  REAL, POINTER, DIMENSION(:)   :: PAC_ROAD_WAT   ! water-limited conductance (CSV PAC_ROAD_WAT / PAC_ROAD_ATM_WAT)(m/s)
  REAL, POINTER, DIMENSION(:)   :: PCH_ROAD       ! conductance for heat (CSV PCH_ROAD_CAN / PCH_ROAD_ATM)          (m/s)
  REAL, POINTER, DIMENSION(:)   :: PH_ROAD        ! sensible heat flux, road -> branch  (W/m2 road)
  REAL, POINTER, DIMENSION(:)   :: PLE_ROAD       ! latent heat flux,   road -> branch  (W/m2 road)
  !* garden <-> branch
  REAL, POINTER, DIMENSION(:)   :: PCDN_GARDEN    ! neutral drag coefficient            (-)
  REAL, POINTER, DIMENSION(:)   :: PRI_GARDEN     ! Richardson number                   (-)
  REAL, POINTER, DIMENSION(:)   :: ZZ0H_GARDEN    ! roughness length for heat           (m)
  REAL, POINTER, DIMENSION(:)   :: PCD_GARDEN     ! drag coefficient (CSV PCD_GARDEN_CAN / PCD_GARDEN_ATM)           (-)
  REAL, POINTER, DIMENSION(:)   :: PCH_GARDEN     ! conductance for heat (CSV PCH_GARDEN_CAN / PCH_GARDEN_ATM)      (m/s)
  REAL, POINTER, DIMENSION(:)   :: PAC_GARDEN     ! aerodynamic conductance (CSV PAC_GARDEN / PAC_GARDEN_ATM)        (m/s)
  REAL, POINTER, DIMENSION(:)   :: H_GARDEN       ! sensible heat flux, garden -> branch(W/m2 garden)
  REAL, POINTER, DIMENSION(:)   :: LE_GARDEN      ! latent heat flux,   garden -> branch(W/m2 garden)
  !* snow on the road <-> branch
  !* PERSISTENT: AVG_URBAN_FLUXES reads these at the start of the sub-step, before
  !* URBAN_SNOW_EVOL writes them, so they carry the PREVIOUS sub-step value
  REAL, POINTER, DIMENSION(:)   :: PHSN_RD        ! snow -> branch sensible heat        (W/m2)
  REAL, POINTER, DIMENSION(:)   :: PLESN_RD       ! snow -> branch latent heat          (W/m2)
END TYPE TEB_CBS_BRANCH_t
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
!* The snow-on-road pair (PHSN_RD, PLESN_RD) is part of the CBS branch record:
!* it is PERSISTENT (the canyon nodes read it before the snow scheme writes it),
!* see the comment inside TEB_CBS_BRANCH_t.
  !* CBS branch diagnostics: the same record for both exchange paths
  TYPE(TEB_CBS_BRANCH_t)        :: CAN           ! canyon-air branch
  TYPE(TEB_CBS_BRANCH_t)        :: ATM           ! forcing-level branch
!
  REAL, POINTER, DIMENSION(:)   :: XRUNOFF_TOWN      ! aggregated water runoff for town      (kg/m2/s)
!* RESERVED: garden irrigation rate. The proxy garden (GARDEN_CBS / GARDEN_PCD)
!* returns PIRRIG_GARDEN = 0. and no model fills this field: the pointer is
!* allocated and NULLIFY-ed but never written or read. It is kept as a
!* placeholder for a future garden irrigation scheme (the road and greenroof
!* counterparts, XIRRIG_ROAD / XIRRIG_GREENROOF, are wired end to end).
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
  REAL, POINTER, DIMENSION(:)   :: XPDN_RD                          ! PDN_RD (CSV PDN_RD) - road snow fraction (-)
  REAL, POINTER, DIMENSION(:)   :: XPDN_RF                          ! PDN_RF (CSV PDN_RF) - roof snow fraction (-)
  REAL, POINTER, DIMENSION(:)   :: XPH_ROAD                         ! PH_ROAD (CSV H_ROAD) - road sensible heat flux, CBS scheme [W m-2]
  REAL, POINTER, DIMENSION(:)   :: XPLE_ROAD                        ! PLE_ROAD (CSV LE_ROAD) - road latent heat flux, CBS scheme [W m-2]
  REAL, POINTER, DIMENSION(:)   :: XPPHI_CAN1                       ! PPHI_CAN1 (CSV PHI_CAN1) - free layer air temperature / theta* ratio of the MOST profile [-]
  REAL, POINTER, DIMENSION(:)   :: XPT_CAN0                         ! PT_CAN0 (CSV T_CAN0) - canyon air temperature without tau [K]
  REAL, POINTER, DIMENSION(:)   :: XPT_CAN1                         ! PT_CAN1 (CSV T_CAN1) - free layer (second canopy) air temperature [K]
  REAL, POINTER, DIMENSION(:)   :: XAHF_TRAFFIC_NOW                 ! ahf_traffic_now (CSV AHF_TRAFFIC) - OUT Anthropogenic heat flux by traffic (current value)
  REAL, POINTER, DIMENSION(:)   :: XAC_RF                           ! teb_ac_rf - OUT Roof aerodynamical conductance
  REAL, POINTER, DIMENSION(:)   :: XAC_TOP                          ! teb_ac_top - OUT Canyon-atm. aerodynamical conductance
  REAL, POINTER, DIMENSION(:)   :: XAC_WL                           ! teb_ac_wl - OUT Wall aerodynamical conductance
  REAL, POINTER, DIMENSION(:)   :: XALB_SO                          ! teb_alb_so - OUT town solar albedo
  REAL, POINTER, DIMENSION(:)   :: XEVAP_GARDEN                     ! teb_evap_garden (CSV EVAP_GARDEN) - OUT total evaporation over the garden (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XEVAP_GREENROOF                  ! teb_evap_greenroof (CSV EVAP_GREENROOF) - OUT total evaporation over the greenroof (kg/m2/s)
  REAL, POINTER, DIMENSION(:)   :: XFRSNOW                          ! teb_frsnow - OUT snow fraction over town
  REAL, POINTER, DIMENSION(:)   :: XGFLUX_TOWN                      ! teb_gflux (CSV GFLUX_TOWN) - OUT Flux through the ground for town
  REAL, POINTER, DIMENSION(:)   :: XH_GARDEN                        ! teb_h_garden (CSV H_GARDEN) - OUT sensible heat flux over the garden (W/m2 garden)
  REAL, POINTER, DIMENSION(:)   :: XH_GREENROOF                     ! teb_h_greenroof (CSV H_GREENROOF) - OUT sensible heat flux over the greenroof (W/m2 greenroof)
  REAL, POINTER, DIMENSION(:)   :: XHSNOW_TOWN                      ! teb_hsnow_town - OUT town snow depth
  REAL, POINTER, DIMENSION(:)   :: XHSNOW_TOWN_NOW                  ! teb_hsnow_town_now - OUT town snow depth at previous time-step
  REAL, POINTER, DIMENSION(:)   :: XLE_GARDEN                       ! teb_le_garden (CSV LE_GARDEN) - OUT latent heat flux over the garden (W/m2 garden)
  REAL, POINTER, DIMENSION(:)   :: XLE_GREENROOF                    ! teb_le_greenroof (CSV LE_GREENROOF) - OUT latent heat flux over the greenroof (W/m2 greenroof)
  REAL, POINTER, DIMENSION(:)   :: XLE_TOWN                         ! teb_lhfl (CSV LE_TOWN) - OUT latent heat flux over town
  REAL, POINTER, DIMENSION(:)   :: XLHFL_SNOW                       ! teb_lhfl_snow - OUT latent heat flux over snow
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
  REAL, POINTER, DIMENSION(:)   :: XH_SNOW_ROOF                     ! per-surface snow sensible heat flux over roof (W/m2 roof)
  REAL, POINTER, DIMENSION(:)   :: XH_SNOW_ROAD                     ! per-surface snow sensible heat flux over road (W/m2 road)
  REAL, POINTER, DIMENSION(:)   :: XLE_SNOW_ROOF                    ! per-surface snow latent heat flux over roof (W/m2 roof)
  REAL, POINTER, DIMENSION(:)   :: XLE_SNOW_ROAD                    ! per-surface snow latent heat flux over road (W/m2 road)
  REAL, POINTER, DIMENSION(:)   :: XSNOWD_ROOF                      ! per-surface roof snow depth (m)
  REAL, POINTER, DIMENSION(:)   :: XSNOWD_ROAD                      ! per-surface road snow depth (m)
  REAL, POINTER, DIMENSION(:)   :: XH_WALL_FR                       ! teb_shfl_wl - OUT Sensible heat flux over wall
  REAL, POINTER, DIMENSION(:)   :: XSNOW_MELT                       ! teb_snow_melt - OUT Snow melt for built & impervious part (kg/m2)
  REAL, POINTER, DIMENSION(:)   :: XSOLAR_PROD                      ! teb_solar_prod (CSV SOLAR_PROD) - OUT Averaged Energy production of solar panel on roofs (W/m2 bld  )
  REAL, POINTER, DIMENSION(:)   :: XTCH_RF                          ! teb_tch_rf - OUT roof transfer coefficient for heat
  REAL, POINTER, DIMENSION(:)   :: XTCH_TOP                         ! teb_tch_top - OUT between canyon top and atm. transfer coefficient for hea
  REAL, POINTER, DIMENSION(:)   :: XTCH_TOWN                        ! teb_tch_town - OUT Heat exchange coefficient
  REAL, POINTER, DIMENSION(:)   :: XTCH_WL                          ! teb_tch_wl - OUT wall transfer coefficient for heat
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

!MV202610 pedestrian mean radiant temperature on the road (MRT)
!* URBAN_SOLAR_ABS exposes the two incident shortwave components that the
!* pedestrian budget needs (the absorbed XABS_SW_ROAD alone cannot be split into
!* the beam and the wall reflection), URBAN_MRT assembles the MRT of a person
!* standing on the road at the canyon axis (z = 1.1 m). The MRT_* components are
!* debug outputs: MRT_ROAD, MRT_ROAD_SUN and the two SW_*_ROAD fields are the
!* quantities the invariants and python_tests/check_mrt.py are built on.
  REAL, POINTER, DIMENSION(:)   :: XSW_DIR_ROAD                     ! SW_DIR_ROAD (CSV SW_DIR_ROAD) - direct shortwave reaching the snow-free road (W/m2 road)
  REAL, POINTER, DIMENSION(:)   :: XSW_SKY_ROAD                     ! SW_SKY_ROAD (CSV SW_SKY_ROAD) - diffuse sky shortwave reaching the snow-free road (W/m2 road)
  REAL, POINTER, DIMENSION(:)   :: XSW_WALL_ROAD                    ! SW_WALL_ROAD (CSV SW_WALL_ROAD) - shortwave reflected by the walls onto the road (W/m2 road)
  REAL, POINTER, DIMENSION(:)   :: XSW_TOT_ROAD                     ! SW_TOT_ROAD (CSV SW_TOT_ROAD) - total shortwave incident on the snow-free road (W/m2 road)
  REAL, POINTER, DIMENSION(:)   :: XSUN_FRAC_ROAD                   ! SUN_FRAC_ROAD (CSV SUN_FRAC_ROAD) - sunlit area fraction of the road (-)
  REAL, POINTER, DIMENSION(:)   :: XMRT                            ! MRT_ROAD (CSV MRT_ROAD) - mean radiant temperature of a pedestrian on the road, sunlit fraction weighted (K)
  REAL, POINTER, DIMENSION(:)   :: XMRT_SUN                        ! MRT_ROAD_SUN (CSV MRT_ROAD_SUN) - the same for a pedestrian standing in the sunlit part (K)
  REAL, POINTER, DIMENSION(:)   :: XMRT_F_SKY                      ! MRT_F_SKY (CSV MRT_F_SKY) - sky view factor of the pedestrian (-)
  REAL, POINTER, DIMENSION(:)   :: XMRT_F_WALL                     ! MRT_F_WALL (CSV MRT_F_WALL) - walls view factor of the pedestrian (-)
  REAL, POINTER, DIMENSION(:)   :: XMRT_F_ROAD                     ! MRT_F_ROAD (CSV MRT_F_ROAD) - road view factor of the pedestrian (-)
  REAL, POINTER, DIMENSION(:)   :: XMRT_SW_DIR                     ! MRT_SW_DIR (CSV MRT_SW_DIR) - beam absorbed by the body (W/m2 body)
  REAL, POINTER, DIMENSION(:)   :: XMRT_SW_SKY                     ! MRT_SW_SKY (CSV MRT_SW_SKY) - diffuse sky shortwave absorbed by the body (W/m2 body)
  REAL, POINTER, DIMENSION(:)   :: XMRT_SW_WALL                    ! MRT_SW_WALL (CSV MRT_SW_WALL) - wall-reflected shortwave absorbed by the body (W/m2 body)
  REAL, POINTER, DIMENSION(:)   :: XMRT_SW_ROAD                    ! MRT_SW_ROAD (CSV MRT_SW_ROAD) - road-reflected shortwave absorbed by the body (W/m2 body)
  REAL, POINTER, DIMENSION(:)   :: XMRT_LW_SKY                     ! MRT_LW_SKY (CSV MRT_LW_SKY) - sky longwave absorbed by the body (W/m2 body)
  REAL, POINTER, DIMENSION(:)   :: XMRT_LW_WALL                    ! MRT_LW_WALL (CSV MRT_LW_WALL) - wall longwave absorbed by the body (W/m2 body)
  REAL, POINTER, DIMENSION(:)   :: XMRT_LW_ROAD                    ! MRT_LW_ROAD (CSV MRT_LW_ROAD) - road longwave absorbed by the body (W/m2 body)
!MV202610 pedestrian mean radiant temperature on the roof (MRT)
!* the same budget for a person standing on the roof: the roof is a flat
!* infinite surface, so there are no walls (F_sky = F_roof = 0.5) and the roof is
!* never shadowed by the canyon; the three incident shortwave components are
!* exported by URBAN_SOLAR_ABS like the road ones
  REAL, POINTER, DIMENSION(:)   :: XSW_DIR_ROOF                     ! SW_DIR_ROOF (CSV SW_DIR_ROOF) - direct shortwave reaching the roof (W/m2 roof)
  REAL, POINTER, DIMENSION(:)   :: XSW_SKY_ROOF                     ! SW_SKY_ROOF (CSV SW_SKY_ROOF) - diffuse sky shortwave reaching the roof (W/m2 roof)
  REAL, POINTER, DIMENSION(:)   :: XSW_TOT_ROOF                     ! SW_TOT_ROOF (CSV SW_TOT_ROOF) - total shortwave incident on the snow-free roof (W/m2 roof)
  REAL, POINTER, DIMENSION(:)   :: XMRT_ROOF                        ! MRT_ROOF (CSV MRT_ROOF) - mean radiant temperature of a pedestrian on the roof (K)
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
  CALL INIT_CBS_BRANCH(YDIAG_MISC_TEB%CAN)
  CALL INIT_CBS_BRANCH(YDIAG_MISC_TEB%ATM)
  NULLIFY(YDIAG_MISC_TEB%XPDN_RD)
  NULLIFY(YDIAG_MISC_TEB%XPDN_RF)
  NULLIFY(YDIAG_MISC_TEB%XPH_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XPLE_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XPPHI_CAN1)
  NULLIFY(YDIAG_MISC_TEB%XPT_CAN0)
  NULLIFY(YDIAG_MISC_TEB%XPT_CAN1)
  NULLIFY(YDIAG_MISC_TEB%XAHF_TRAFFIC_NOW)
  NULLIFY(YDIAG_MISC_TEB%XAC_RF)
  NULLIFY(YDIAG_MISC_TEB%XAC_TOP)
  NULLIFY(YDIAG_MISC_TEB%XAC_WL)
  NULLIFY(YDIAG_MISC_TEB%XALB_SO)
  NULLIFY(YDIAG_MISC_TEB%XEVAP_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XEVAP_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XFRSNOW)
  NULLIFY(YDIAG_MISC_TEB%XGFLUX_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XH_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XH_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XHSNOW_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XHSNOW_TOWN_NOW)
  NULLIFY(YDIAG_MISC_TEB%XLE_GARDEN)
  NULLIFY(YDIAG_MISC_TEB%XLE_GREENROOF)
  NULLIFY(YDIAG_MISC_TEB%XLE_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XLHFL_SNOW)
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
  NULLIFY(YDIAG_MISC_TEB%XH_SNOW_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XH_SNOW_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XLE_SNOW_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XLE_SNOW_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XSNOWD_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XSNOWD_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XH_WALL_FR)
  NULLIFY(YDIAG_MISC_TEB%XSNOW_MELT)
  NULLIFY(YDIAG_MISC_TEB%XSOLAR_PROD)
  NULLIFY(YDIAG_MISC_TEB%XTCH_RF)
  NULLIFY(YDIAG_MISC_TEB%XTCH_TOP)
  NULLIFY(YDIAG_MISC_TEB%XTCH_TOWN)
  NULLIFY(YDIAG_MISC_TEB%XTCH_WL)
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
!MV202610 pedestrian mean radiant temperature on the road (MRT)
  NULLIFY(YDIAG_MISC_TEB%XSW_DIR_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XSW_SKY_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XSW_WALL_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XSW_TOT_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XSUN_FRAC_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XMRT)
  NULLIFY(YDIAG_MISC_TEB%XMRT_SUN)
  NULLIFY(YDIAG_MISC_TEB%XMRT_F_SKY)
  NULLIFY(YDIAG_MISC_TEB%XMRT_F_WALL)
  NULLIFY(YDIAG_MISC_TEB%XMRT_F_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XMRT_SW_DIR)
  NULLIFY(YDIAG_MISC_TEB%XMRT_SW_SKY)
  NULLIFY(YDIAG_MISC_TEB%XMRT_SW_WALL)
  NULLIFY(YDIAG_MISC_TEB%XMRT_SW_ROAD)
  NULLIFY(YDIAG_MISC_TEB%XMRT_LW_SKY)
  NULLIFY(YDIAG_MISC_TEB%XMRT_LW_WALL)
  NULLIFY(YDIAG_MISC_TEB%XMRT_LW_ROAD)
!MV202610 pedestrian mean radiant temperature on the roof (MRT)
  NULLIFY(YDIAG_MISC_TEB%XSW_DIR_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XSW_SKY_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XSW_TOT_ROOF)
  NULLIFY(YDIAG_MISC_TEB%XMRT_ROOF)
IF (LHOOK) CALL DR_HOOK("MODD_DIAG_MISC_TEB_N:DIAG_MISC_TEB_INIT",1,ZHOOK_HANDLE)
END SUBROUTINE DIAG_MISC_TEB_INIT
SUBROUTINE INIT_CBS_BRANCH(YBRANCH)
!!****  *INIT_CBS_BRANCH* - NULLIFY one CBS branch record
TYPE(TEB_CBS_BRANCH_t), INTENT(INOUT) :: YBRANCH
!
NULLIFY(YBRANCH%PCDN_ROAD)
NULLIFY(YBRANCH%PCD_ROAD)
NULLIFY(YBRANCH%PRI_ROAD)
NULLIFY(YBRANCH%ZZ0H_ROAD)
NULLIFY(YBRANCH%PAC_ROAD)
NULLIFY(YBRANCH%PAC_ROAD_WAT)
NULLIFY(YBRANCH%PCH_ROAD)
NULLIFY(YBRANCH%PH_ROAD)
NULLIFY(YBRANCH%PLE_ROAD)
NULLIFY(YBRANCH%PCDN_GARDEN)
NULLIFY(YBRANCH%PRI_GARDEN)
NULLIFY(YBRANCH%ZZ0H_GARDEN)
NULLIFY(YBRANCH%PCD_GARDEN)
NULLIFY(YBRANCH%PCH_GARDEN)
NULLIFY(YBRANCH%PAC_GARDEN)
NULLIFY(YBRANCH%H_GARDEN)
NULLIFY(YBRANCH%LE_GARDEN)
NULLIFY(YBRANCH%PHSN_RD)
NULLIFY(YBRANCH%PLESN_RD)
!
END SUBROUTINE INIT_CBS_BRANCH

!
SUBROUTINE ALLOC_CBS_BRANCH(YBRANCH, KB)
!!****  *ALLOC_CBS_BRANCH* - allocate one CBS branch record
TYPE(TEB_CBS_BRANCH_t), INTENT(INOUT) :: YBRANCH
INTEGER,               INTENT(IN)    :: KB
!
ALLOCATE(YBRANCH%PCDN_ROAD(KB))
ALLOCATE(YBRANCH%PCD_ROAD(KB))
ALLOCATE(YBRANCH%PRI_ROAD(KB))
ALLOCATE(YBRANCH%ZZ0H_ROAD(KB))
ALLOCATE(YBRANCH%PAC_ROAD(KB))
ALLOCATE(YBRANCH%PAC_ROAD_WAT(KB))
ALLOCATE(YBRANCH%PCH_ROAD(KB))
ALLOCATE(YBRANCH%PH_ROAD(KB))
ALLOCATE(YBRANCH%PLE_ROAD(KB))
ALLOCATE(YBRANCH%PCDN_GARDEN(KB))
ALLOCATE(YBRANCH%PRI_GARDEN(KB))
ALLOCATE(YBRANCH%ZZ0H_GARDEN(KB))
ALLOCATE(YBRANCH%PCD_GARDEN(KB))
ALLOCATE(YBRANCH%PCH_GARDEN(KB))
ALLOCATE(YBRANCH%PAC_GARDEN(KB))
ALLOCATE(YBRANCH%H_GARDEN(KB))
ALLOCATE(YBRANCH%LE_GARDEN(KB))
ALLOCATE(YBRANCH%PHSN_RD(KB))
ALLOCATE(YBRANCH%PLESN_RD(KB))
!
END SUBROUTINE ALLOC_CBS_BRANCH

!
SUBROUTINE DEALLOC_CBS_BRANCH(YBRANCH)
!!****  *DEALLOC_CBS_BRANCH* - release one CBS branch record
TYPE(TEB_CBS_BRANCH_t), INTENT(INOUT) :: YBRANCH
!
DEALLOCATE(YBRANCH%PCDN_ROAD)
DEALLOCATE(YBRANCH%PCD_ROAD)
DEALLOCATE(YBRANCH%PRI_ROAD)
DEALLOCATE(YBRANCH%ZZ0H_ROAD)
DEALLOCATE(YBRANCH%PAC_ROAD)
DEALLOCATE(YBRANCH%PAC_ROAD_WAT)
DEALLOCATE(YBRANCH%PCH_ROAD)
DEALLOCATE(YBRANCH%PH_ROAD)
DEALLOCATE(YBRANCH%PLE_ROAD)
DEALLOCATE(YBRANCH%PCDN_GARDEN)
DEALLOCATE(YBRANCH%PRI_GARDEN)
DEALLOCATE(YBRANCH%ZZ0H_GARDEN)
DEALLOCATE(YBRANCH%PCD_GARDEN)
DEALLOCATE(YBRANCH%PCH_GARDEN)
DEALLOCATE(YBRANCH%PAC_GARDEN)
DEALLOCATE(YBRANCH%H_GARDEN)
DEALLOCATE(YBRANCH%LE_GARDEN)
DEALLOCATE(YBRANCH%PHSN_RD)
DEALLOCATE(YBRANCH%PLESN_RD)
!
END SUBROUTINE DEALLOC_CBS_BRANCH

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
