!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!     #########
MODULE MODI_TEB_GARDEN_STRUCT
!
INTERFACE
!
    SUBROUTINE TEB_GARDEN_STRUCT (icell, iblock, OGREENROOF_EXT, HIMPLICIT_WIND, PBEM_AC, PTSUN, PT_CAN, &
                 PQ_CAN, PU_CAN, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN, PZ_LOWCAN, &
                 PWS_ROAD, HSNOW_ROOF, HSNOW_ROAD, PPEW_A_COEF, PPEW_B_COEF, &
                 PPEW_A_COEF_LOWCAN, PPEW_B_COEF_LOWCAN, PZ0_GARDEN_EXT, PPS, &
                 PPA, PEXNS, PEXNA, PTA, PQA, PRHOA, PCO2, PLW_RAD, PDIR_SW, &
                 PSCA_SW, PSW_BANDS, KSW, PZENITH, PAZIM, PRR, PSR, PZREF, &
                 PUREF, PVMOD, PH_TRAFFIC, PLE_TRAFFIC, PTSTEP, PRN_ROOF, &
                 PH_ROOF, PLE_ROOF, PLEW_ROOF, PGFLUX_ROOF, PRUNOFF_ROOF, &
                 PRN_ROAD, PH_ROAD, PLE_ROAD, PLEW_ROAD, PGFLUX_ROAD, &
                 PRUNOFF_ROAD, PRN_WALL_A, PH_WALL_A, PLE_WALL_A, &
                 PGFLUX_WALL_A, PRN_WALL_B, PH_WALL_B, PLE_WALL_B, &
                 PGFLUX_WALL_B, PRN_STRLROOF, PH_STRLROOF, PLE_STRLROOF, &
                 PGFLUX_STRLROOF, PRUNOFF_STRLROOF, PRN_BLT, PH_BLT, PLE_BLT, &
                 PGFLUX_BLT, PRNSNOW_ROOF, PHSNOW_ROOF, PLESNOW_ROOF, &
                 PGSNOW_ROOF, PMELT_ROOF, PRNSNOW_ROAD, PHSNOW_ROAD, &
                 PLESNOW_ROAD, PGSNOW_ROAD, PMELT_ROAD, PRN_GRND, PH_GRND, &
                 PLE_GRND, PGFLUX_GRND, PRN_TOWN, PH_TOWN, PLE_TOWN, &
                 PGFLUX_TOWN, PEVAP_TOWN, PRUNOFF_TOWN, PSFCO2, PUW_GRND, &
                 PUW_ROOF, PDUWDU_GRND, PDUWDU_ROOF, PUSTAR_TOWN, PCD, PCDN, &
                 PCH_TOWN, PRI_TOWN, PTS_TOWN, PEMIS_TOWN, PDIR_ALB_TOWN, &
                 PSCA_ALB_TOWN, PSO_ALB_TOWN, ZSW_UP_SO, PRESA_TOWN, &
                 PDQS_TOWN, PQF_TOWN, PQF_BLD, PFLX_BLD, PAC_ROOF, PAC_ROAD, &
                 PAC_WALL, PAC_GARDEN, PAC_GREENROOF, PAC_ROAD_WAT, &
                 PAC_GARDEN_WAT, PAC_GREENROOF_WAT, PABS_SW_ROOF, &
                 PABS_LW_ROOF, PABS_SW_SNOW_ROOF, PABS_LW_SNOW_ROOF, &
                 PABS_SW_ROAD, PABS_LW_ROAD, PABS_SW_SNOW_ROAD, &
                 PABS_LW_SNOW_ROAD, PABS_SW_WALL_A, PABS_LW_WALL_A, &
                 PABS_SW_WALL_B, PABS_LW_WALL_B, PABS_SW_PANEL, &
                 PABS_LW_PANEL, PABS_SW_GARDEN, PABS_LW_GARDEN, &
                 PABS_SW_GREENROOF, PABS_LW_GREENROOF, PG_GREENROOF_ROOF, &
                 PNATVENT, KDAY, PAUX_MAX, PT_FLOOR, PT_MASS, PH_BLD_COOL, &
                 PT_BLD_COOL, PH_BLD_HEAT, PLE_BLD_COOL, PLE_BLD_HEAT, &
                 PH_WASTE, PLE_WASTE, PHVAC_COOL, PHVAC_HEAT, PT_ADP, &
                 PCAP_SYS, PM_SYS, PCOP, PQ_SYS, PT_SYS, PTR_SW_WIN, &
                 PFAN_POWER, PHC_FLOOR, PTC_FLOOR, PD_FLOOR, PABS_SW_WIN, &
                 PABS_LW_WIN, PUGG_WIN, PALB_WIN, PABS_WIN, PEMIT_LW_FAC, &
                 PEMIT_LW_GRND, PT_RAD_IND, PREF_SW_GRND, PREF_SW_FAC, &
                 PHU_BLD, PTIME, PSHADE, OCANOPY, PTRAN_WIN, OPAR_RD_IRRIG, &
                 PRD_START_MONTH, PRD_END_MONTH, PRD_START_HOUR, &
                 PRD_END_HOUR, PRD_24H_IRRIG, PIRRIG_ROAD, PEMIS_PANEL, &
                 PALB_PANEL, PEFF_PANEL, PFRAC_PANEL, PTHER_PROD_PANEL, &
                 PPHOT_PROD_PANEL, PPROD_PANEL, PTHER_PROD_BLD, &
                 PPHOT_PROD_BLD, PPROD_BLD, PTHER_PRODC_DAY, PH_PANEL, &
                 PRN_PANEL, PCUR_TCOOL_TARGET, PCUR_THEAT_TARGET, PCUR_QIN, &
                 PDN_RF, PDN_RD, PMELT_BLT, PSNOWD_RF, PSNOWD_RD, PLW_UP, &
                 PZ0_GR_EXT, PALB_GR_EXT, PEMIS_GR_EXT, PTSRAD_GR_EXT, &
                 PQV_GR_EXT, PH_GR_EXT, PLE_GR_EXT, PEVAP_GR_EXT, &
                 PRUNOFF_GR_EXT, PALB_GD_EXT, PEMIS_GD_EXT, PTSRAD_GD_EXT, &
                 PQV_GD_EXT, PH_GD_EXT, PLE_GD_EXT, PEVAP_GD_EXT, PCH_GD, &
                 PCD_GD, PRUNOFF_GD_EXT, PCH_RD, PCH_RF, PCH_WL, PCH_TOP, &
                 PAC_TOP, ILMO_ROAD, ILMO_ROOF, ILMO_TOP, PCD_GARDEN_ATM, &
                 PCH_GARDEN_ATM, PCD_ROAD_CAN, PCDN_ROAD_CAN, PRI_ROAD_CAN, &
                 ZZ0H_ROAD_CAN, PAC_ROAD_ATM, PCH_ROAD_ATM, PCD_ROAD_ATM, &
                 PCDN_ROAD_ATM, PRI_ROAD_ATM, ZZ0H_ROAD_ATM, PCDN_GARDEN_CAN, &
                 PRI_GARDEN_CAN, ZZ0H_GARDEN_CAN, PAC_GARDEN_ATM, &
                 PCDN_GARDEN_ATM, PRI_GARDEN_ATM, ZZ0H_GARDEN_ATM, &
                 PH_ROAD_CAN, PLE_ROAD_CAN, PH_ROAD_ATM, PLE_ROAD_ATM, &
                 PT_CAN0, PT_CAN1, PPHI_CAN1, PAC_ROAD_ATM_WAT, LE_ROAD_WAT, &
                 LE_ROAD_SNOW, LE_ROOF_WAT, LE_ROOF_SNOW, XTAU_HW_THRESH, &
                 XTAU_HW_WIDTH, PTSRAD_GARDEN, PRN_GARDEN, PH_GARDEN, &
                 PLE_GARDEN, PEVAP_GARDEN, PQSAT_GARDEN, PHU_GARDEN, &
                 PH_GARDEN_CAN, PH_GARDEN_ATM, PLE_GARDEN_CAN, &
                 PLE_GARDEN_ATM, PTSRAD_GREENROOF, PRN_GREENROOF, &
                 PH_GREENROOF, PLE_GREENROOF, PEVAP_GREENROOF, &
                 PQSAT_GREENROOF, PHU_GREENROOF, PAC_GREENROOF_ATM, &
                 PCD_GREENROOF_ATM, PCDN_GREENROOF_ATM, PCH_GREENROOF_ATM, &
                 PRI_GREENROOF_ATM, ZZ0H_GREENROOF_ATM, DMT, TOP, TP, BOP, &
                 BP, PZ0_TOWN, TSTATE, BSTATE, TPN, TIR)
!   ##########################################################################
!
!!****  *TEB_GARDEN_STRUCT*  
!!
!!    PURPOSE
!!    -------
!
! To put all individual variables in the corresponding fortran structure
! for the call to TEB_GARDEN routine.
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
!!      V. Masson           * Meteo-France *
!!
!!    MODIFICATIONS
!!    -------------
!!    Original    03/2018
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_TYPE_DATE_SURF
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
!
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_PARAMS_n, ONLY : TEB_PARAMS_t
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t
USE MODD_TEB_n,       ONLY : TEB_t
USE MODD_BEM_n,       ONLY : BEM_t
USE MODD_TEB_PANEL_n, ONLY : TEB_PANEL_t
USE MODD_TEB_IRRIG_n, ONLY : TEB_IRRIG_t
IMPLICIT NONE

TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: TOP
TYPE(TEB_PARAMS_t),  INTENT(INOUT) :: TP
TYPE(BEM_OPTIONS_t), INTENT(INOUT) :: BOP
TYPE(BEM_PARAMS_t),  INTENT(INOUT) :: BP
REAL, DIMENSION(:), INTENT(IN) :: PZ0_TOWN
!
!*      0.1    Declarations of arguments
!
!
!
!
 INTEGER                             :: icell                                                      
 INTEGER                             :: iblock
 LOGICAL,              INTENT(IN)    :: OGREENROOF_EXT    ! Flag to use a greenroof model on roofs (external model)
!                                                         ! 'MASC95' : Mascart et al 1995
!                                                         ! 'BRUT82' : Brustaert     1982
!                                                         ! 'KAND07' : Kanda         2007
 CHARACTER(LEN=*),     INTENT(IN)  :: HIMPLICIT_WIND       ! wind implicitation option
!                                                         ! 'OLD' = direct
!                                                         ! 'NEW' = Taylor serie, order 1
                                                          ! 'UNIF' : uniform roads
                                                          ! 'ORIE' : specified
                                                          !   road orientation 
                                                          ! 'UNIF' : uniform walls
                                                          ! 'TWO ' : 2 opposite  walls
LOGICAL,INTENT(IN)                  :: PBEM_AC            ! Flag to use air conditioners
REAL, DIMENSION(:),   INTENT(IN)    :: PTSUN              ! solar time   (s from midnight)

!                                                         
REAL, DIMENSION(:)  , INTENT(INOUT) :: PT_CAN             ! canyon air temperature
REAL, DIMENSION(:)  , INTENT(INOUT) :: PQ_CAN             ! canyon air specific humidity
REAL, DIMENSION(:)  , INTENT(IN)    :: PU_CAN             ! canyon hor. wind
REAL, DIMENSION(:)  , INTENT(IN)    :: PU_LOWCAN          ! wind near the road
REAL, DIMENSION(:)  , INTENT(IN)    :: PT_LOWCAN          ! temp. near the road
REAL, DIMENSION(:)  , INTENT(IN)    :: PQ_LOWCAN          ! hum. near the road
REAL, DIMENSION(:)  , INTENT(IN)    :: PZ_LOWCAN          ! height of atm. var. near the road
REAL, DIMENSION(:)  , INTENT(INOUT) :: PWS_ROAD           ! road water reservoir
 CHARACTER(LEN=*)    , INTENT(IN)    :: HSNOW_ROOF         ! snow roof scheme 'NONE', 'D95 ', '1-L '
 CHARACTER(LEN=*)    , INTENT(IN)    :: HSNOW_ROAD         ! snow road scheme 'NONE', 'D95 ', '1-L '
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_A_COEF        ! implicit coefficients
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_B_COEF        ! for wind coupling
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_A_COEF_LOWCAN ! implicit coefficients for wind coupling
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_B_COEF_LOWCAN ! between low canyon wind and road
REAL, DIMENSION(:)  , INTENT(IN)    :: PZ0_GARDEN_EXT     ! garden roughness length
REAL, DIMENSION(:)  , INTENT(IN)    :: PPS                ! pressure at the surface
REAL, DIMENSION(:)  , INTENT(IN)    :: PPA                ! pressure at the first atmospheric level
REAL, DIMENSION(:)  , INTENT(IN)    :: PEXNS              ! surface exner function
REAL, DIMENSION(:)  , INTENT(IN)    :: PTA                ! temperature at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)    :: PQA                ! specific humidity at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)    :: PVMOD              ! module of the horizontal wind
REAL, DIMENSION(:)  , INTENT(IN)    :: PEXNA              ! exner function at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)    :: PRHOA              ! air density at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)    :: PCO2               ! CO2 concentration in the air    (kg/m3)
REAL, DIMENSION(:)  , INTENT(IN)    :: PLW_RAD            ! atmospheric infrared radiation
REAL, DIMENSION(:,:), INTENT(IN)    :: PDIR_SW            ! incoming direct solar rad on an horizontal surface
REAL, DIMENSION(:,:), INTENT(IN)    :: PSCA_SW            ! scattered incoming solar rad.
REAL, DIMENSION(:)  , INTENT(IN)    :: PSW_BANDS          ! mean wavelength of each shortwave band (m)
INTEGER,              INTENT(IN)    :: KSW                ! number of short-wave spectral bands
REAL, DIMENSION(:)  , INTENT(IN)    :: PZENITH            ! solar zenithal angle
REAL, DIMENSION(:)  , INTENT(IN)    :: PAZIM              ! solar azimuthal angle
                                                          ! (radian form N, clockwise)
REAL, DIMENSION(:)  , INTENT(IN)    :: PRR                ! rain rate
REAL, DIMENSION(:)  , INTENT(IN)    :: PSR                ! snow rate
REAL, DIMENSION(:)  , INTENT(IN)    :: PH_TRAFFIC         ! anthropogenic sensible heat fluxes due to traffic
REAL, DIMENSION(:)  , INTENT(IN)    :: PLE_TRAFFIC        ! anthropogenic latent heat fluxes due to traffic
REAL, DIMENSION(:)  , INTENT(IN)    :: PZREF              ! reference height of the first atm level (temperature)
REAL, DIMENSION(:)  , INTENT(IN)    :: PUREF              ! reference height of the first atm level (wind)
REAL                , INTENT(IN)    :: PTSTEP             ! time step
!MV202609 z0 and zd to namelist
     !
REAL, DIMENSION(:)  , INTENT(IN)    :: PZ0_GR_EXT         ! greenroof roughness length (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PALB_GR_EXT        ! green roof albedo (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PEMIS_GR_EXT       ! green roof emissivity (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PTSRAD_GR_EXT      ! greenroof radiative surface temp. (snow free) (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PQV_GR_EXT         ! greenroof specific humidity (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PH_GR_EXT          ! sensible heat flux over greenroofs (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PLE_GR_EXT         ! latent heat flux over greenroofs (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PEVAP_GR_EXT       ! total evaporation over greenroofs (kg/m2/s) (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PRUNOFF_GR_EXT     ! greenroof surface runoff (external model)

REAL, DIMENSION(:)  , INTENT(IN)    :: PALB_GD_EXT        ! garden albedo
REAL, DIMENSION(:)  , INTENT(IN)    :: PEMIS_GD_EXT       ! garden emissivity 
REAL, DIMENSION(:)  , INTENT(IN)    :: PTSRAD_GD_EXT      ! garden radiative surface temp. (snow free) 
REAL, DIMENSION(:)  , INTENT(IN)    :: PQV_GD_EXT         ! garden specific humidity
REAL, DIMENSION(:)  , INTENT(IN)    :: PH_GD_EXT          ! sensible heat flux over garden 
REAL, DIMENSION(:)  , INTENT(IN)    :: PLE_GD_EXT         ! latent heat flux over garden 
REAL, DIMENSION(:)  , INTENT(IN)    :: PEVAP_GD_EXT       ! total evaporation over garden (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_GD             ! drag coeifficient for heat
REAL, DIMENSION(:)  , INTENT(INOUT)   :: PCD_GD             ! garden  surf. exchange coefficient
REAL, DIMENSION(:)  , INTENT(IN)    :: PRUNOFF_GD_EXT     ! garden surface runoff 

REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_RD             ! drag coeifficient for heat
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_RF             ! drag coeifficient for heat
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_WL             ! drag coeifficient for heat
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_TOP            ! drag coeifficient for heat
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_TOP            ! drag coeifficient for heat
REAL, DIMENSION(:)  , INTENT(OUT)   :: ILMO_ROAD          ! 1/length of Monin-Obukov
REAL, DIMENSION(:)  , INTENT(OUT)   :: ILMO_ROOF          ! 1/length of Monin-Obukov
REAL, DIMENSION(:)  , INTENT(OUT)   :: ILMO_TOP           ! 1/length of Monin-Obukov

	 !
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_ROOF           ! net radiation over roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_ROOF            ! sensible heat flux over roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_ROOF           ! latent heat flux over roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLEW_ROOF          ! latent heat flux over roof (snow)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_ROOF        ! flux through the roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRUNOFF_ROOF       ! runoff over the ground
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_ROAD           ! net radiation over road
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_ROAD            ! sensible heat flux over road
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_ROAD           ! latent heat flux over road
!MV202609 CBS scheme of the road (revision: puddle diagnostics)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_ROAD_ATM_WAT   ! road water conductance (forcing level, water-limited)
REAL, DIMENSION(:)  , INTENT(OUT)   :: LE_ROAD_WAT        ! road latent heat flux of the snow-free road (W/m2 road)
REAL, DIMENSION(:)  , INTENT(OUT)   :: LE_ROAD_SNOW       ! road latent heat flux of the snow-covered road (W/m2 road)
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
REAL, DIMENSION(:)  , INTENT(OUT)   :: LE_ROOF_WAT        ! roof latent heat flux of the snow-free roof (W/m2 roof)
REAL, DIMENSION(:)  , INTENT(OUT)   :: LE_ROOF_SNOW       ! roof latent heat flux of the snow-covered roof (W/m2 roof)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLEW_ROAD          ! latent heat flux over road (snow)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_ROAD        ! flux through the road
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRUNOFF_ROAD       ! runoff over the ground
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_WALL_A         ! net radiation over wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_WALL_A          ! sensible heat flux over wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_WALL_A         ! latent heat flux over wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_WALL_A      ! flux through the wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_WALL_B         ! net radiation over wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_WALL_B          ! sensible heat flux over wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_WALL_B         ! latent heat flux over wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_WALL_B      ! flux through the wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_STRLROOF       ! net radiation over structural roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_STRLROOF        ! sensible heat flux over structural roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_STRLROOF       ! latent heat flux over structural roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_STRLROOF    ! flux through the structural roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRUNOFF_STRLROOF   ! runoff aver structural roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_BLT            ! net radiation over built surf 
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_BLT             ! sensible heat flux over built surf 
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_BLT            ! latent heat flux over built surf 
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_BLT         ! flux through the built surf 
!
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRNSNOW_ROOF       ! net radiation over snow
REAL, DIMENSION(:)  , INTENT(OUT)   :: PHSNOW_ROOF        ! sensible heat flux over snow
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLESNOW_ROOF       ! latent heat flux over snow
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGSNOW_ROOF        ! flux under the snow
REAL, DIMENSION(:)  , INTENT(OUT)   :: PMELT_ROOF         ! snow melt
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRNSNOW_ROAD       ! net radiation over snow
REAL, DIMENSION(:)  , INTENT(OUT)   :: PHSNOW_ROAD        ! sensible heat flux over snow
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLESNOW_ROAD       ! latent heat flux over snow
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGSNOW_ROAD        ! flux under the snow
REAL, DIMENSION(:)  , INTENT(OUT)   :: PMELT_ROAD         ! snow melt
!MV202609 CBS scheme of the road (revision: snow-to-atmosphere branch)
!* local branch diagnostics of the road snow exchange (internal to the wrapper)
REAL, DIMENSION(SIZE(PWS_ROAD)) :: PHSN_RD_CAN        ! sensible heat flux over snow, snow -> canyon air
REAL, DIMENSION(SIZE(PWS_ROAD)) :: PHSN_RD_ATM        ! sensible heat flux over snow, snow -> forcing level
REAL, DIMENSION(SIZE(PWS_ROAD)) :: PLESN_RD_CAN       ! latent heat flux over snow, snow -> canyon air
REAL, DIMENSION(SIZE(PWS_ROAD)) :: PLESN_RD_ATM       ! latent heat flux over snow, snow -> forcing level
!
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_GRND           ! net radiation over ground
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_GRND            ! sensible heat flux over ground
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_GRND           ! latent heat flux over ground
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_GRND        ! flux through the ground
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_TOWN           ! net radiation over town
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_TOWN            ! sensible heat flux over town
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_TOWN           ! latent heat flux over town
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_TOWN        ! flux through the ground
REAL, DIMENSION(:)  , INTENT(OUT)   :: PEVAP_TOWN         ! evaporation flux (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRUNOFF_TOWN       ! runoff over the ground
REAL, DIMENSION(:)  , INTENT(OUT)   :: PSFCO2             ! flux of CO2       (m/s*kg_CO2/kg_air)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PUW_GRND           ! momentum flux for ground built surf
REAL, DIMENSION(:)  , INTENT(OUT)   :: PUW_ROOF           ! momentum flux for roofs
REAL, DIMENSION(:)  , INTENT(OUT)   :: PDUWDU_GRND        !
REAL, DIMENSION(:)  , INTENT(OUT)   :: PDUWDU_ROOF        !
REAL, DIMENSION(:)  , INTENT(OUT)   :: PUSTAR_TOWN        ! friciton velocity over town
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCD                ! town averaged drag coefficient
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCDN               ! town averaged neutral drag coefficient
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_TOWN           ! town averaged heat transfer coefficient
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRI_TOWN           ! town averaged Richardson number
REAL, DIMENSION(:)  , INTENT(OUT)   :: PTS_TOWN           ! town surface temperature
REAL, DIMENSION(:)  , INTENT(OUT)   :: PEMIS_TOWN         ! town equivalent emissivity
REAL, DIMENSION(:)  , INTENT(OUT)   :: PDIR_ALB_TOWN      ! town equivalent direct albedo
REAL, DIMENSION(:)  , INTENT(OUT)   :: PSCA_ALB_TOWN      ! town equivalent diffuse albedo
REAL, DIMENSION(:)  , INTENT(OUT)   :: PSO_ALB_TOWN       ! town equivalent solar albedo
REAL, DIMENSION(:)  , INTENT(OUT)   :: ZSW_UP_SO          ! outgoing solar radiation
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRESA_TOWN         ! town aerodynamical resistance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PDQS_TOWN          ! heat storage inside town
REAL, DIMENSION(:)  , INTENT(OUT)   :: PQF_TOWN           ! total anthropogenic heat
REAL, DIMENSION(:)  , INTENT(OUT)   :: PQF_BLD            ! anthropogenic heat flux of domestic heating
REAL, DIMENSION(:)  , INTENT(OUT)   :: PFLX_BLD           ! heat flx from inside bld through its structure
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_ROOF           ! roof conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_ROAD           ! road conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_WALL           ! wall conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_GARDEN         ! green area conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_GREENROOF      ! green roof conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_ROAD_WAT       ! road conductance for latent heat
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_GARDEN_WAT     ! green area conductance for latent heat
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_GREENROOF_WAT  ! green roof conductance for latent heat
!
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_SW_ROOF       ! absorbed solar rad by roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_SW_SNOW_ROOF  ! absorbed solar rad by snow on roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_LW_ROOF       ! absorbed IR rad by roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_LW_SNOW_ROOF  ! absorbed IR rad by snow on roof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_SW_ROAD       ! absorbed solar rad by road
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_SW_SNOW_ROAD  ! absorbed solar rad by snow on road
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_LW_ROAD       ! absorbed IR rad by road
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_LW_SNOW_ROAD  ! absorbed IR rad by snow on road
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_SW_WALL_A     ! absorbed solar rad by wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_LW_WALL_A     ! absorbed IR rad by wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_SW_WALL_B     ! absorbed solar rad by wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_LW_WALL_B     ! absorbed IR rad by wall
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_SW_PANEL      ! absorbed solar rad by solar panels
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_LW_PANEL      ! absorbed IR rad by solar panels
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_SW_GARDEN     ! absorbed solar rad by green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_LW_GARDEN     ! absorbed IR rad by green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_SW_GREENROOF  ! absorbed solar rad by green roofs
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_LW_GREENROOF  ! absorbed IR rad by green roofs
REAL, DIMENSION(:)  , INTENT(OUT)   :: PG_GREENROOF_ROOF  ! heat flux between base of greenroof
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCD_GARDEN_ATM
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_GARDEN_ATM
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
REAL, DIMENSION(:), INTENT(OUT)   :: PCD_ROAD_CAN     ! road   drag coefficient (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN_ROAD_CAN    ! road   neutral drag coefficient (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_ROAD_CAN     ! road   Richardson number (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: ZZ0H_ROAD_CAN    ! road   roughness length for heat (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROAD_ATM     ! road   aerodynamical conductance (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_ROAD_ATM     ! road   drag coefficient for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCD_ROAD_ATM     ! road   drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN_ROAD_ATM    ! road   neutral drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_ROAD_ATM     ! road   Richardson number (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: ZZ0H_ROAD_ATM    ! road   roughness length for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN_GARDEN_CAN  ! garden neutral drag coefficient (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_GARDEN_CAN   ! garden Richardson number (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: ZZ0H_GARDEN_CAN  ! garden roughness length for heat (canyon)
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_GARDEN_ATM   ! garden aerodynamical conductance (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN_GARDEN_ATM  ! garden neutral drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_GARDEN_ATM   ! garden Richardson number (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: ZZ0H_GARDEN_ATM  ! garden roughness length for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PH_ROAD_CAN      ! road sensible heat flux, road -> canyon air [W m-2]
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_ROAD_CAN     ! road latent heat flux, road -> canyon air [W m-2]
REAL, DIMENSION(:), INTENT(OUT)   :: PH_ROAD_ATM      ! road sensible heat flux, road -> forcing level [W m-2]
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_ROAD_ATM     ! road latent heat flux, road -> forcing level [W m-2]
!MV202609 CBS scheme of the road (revision: three-temperature construction)
REAL, DIMENSION(:), INTENT(OUT)   :: PT_CAN0          ! canyon air temperature without tau [K]
REAL, DIMENSION(:), INTENT(OUT)   :: PT_CAN1          ! free layer (second canopy) air temperature [K]
REAL, DIMENSION(:), INTENT(OUT)   :: PPHI_CAN1        ! free layer air temperature / theta* ratio of the MOST profile [-]
!MV202609 garden diagnostics
REAL, DIMENSION(:), INTENT(OUT)   :: PTSRAD_GARDEN    ! garden surface temperature [K]
REAL, DIMENSION(:), INTENT(OUT)   :: PRN_GARDEN       ! net radiation over the garden [W/m2 garden]
REAL, DIMENSION(:), INTENT(OUT)   :: PH_GARDEN        ! sensible heat flux over the garden [W/m2 garden]
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_GARDEN       ! latent heat flux over the garden [W/m2 garden]
REAL, DIMENSION(:), INTENT(OUT)   :: PEVAP_GARDEN     ! total evaporation over the garden [kg/m2/s]
REAL, DIMENSION(:), INTENT(OUT)   :: PQSAT_GARDEN     ! garden saturation specific humidity [kg/kg]
REAL, DIMENSION(:), INTENT(OUT)   :: PHU_GARDEN       ! garden aggregated relative humidity [-]
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
REAL, DIMENSION(:), INTENT(OUT)   :: PH_GARDEN_CAN    ! garden sensible heat flux, garden -> canyon air [W m-2]
REAL, DIMENSION(:), INTENT(OUT)   :: PH_GARDEN_ATM    ! garden sensible heat flux, garden -> forcing level [W m-2]
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_GARDEN_CAN   ! garden latent  heat flux, garden -> canyon air [W m-2]
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_GARDEN_ATM   ! garden latent  heat flux, garden -> forcing level [W m-2]
!MV202609 greenroof diagnostics
REAL, DIMENSION(:), INTENT(OUT)   :: PTSRAD_GREENROOF ! greenroof surface temperature [K]
REAL, DIMENSION(:), INTENT(OUT)   :: PRN_GREENROOF    ! net radiation over the greenroof [W/m2 greenroof]
REAL, DIMENSION(:), INTENT(OUT)   :: PH_GREENROOF     ! sensible heat flux over the greenroof [W/m2 greenroof]
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_GREENROOF    ! latent heat flux over the greenroof [W/m2 greenroof]
REAL, DIMENSION(:), INTENT(OUT)   :: PEVAP_GREENROOF  ! total evaporation over the greenroof [kg/m2/s]
REAL, DIMENSION(:), INTENT(OUT)   :: PQSAT_GREENROOF  ! greenroof saturation specific humidity [kg/kg]
REAL, DIMENSION(:), INTENT(OUT)   :: PHU_GREENROOF    ! greenroof aggregated relative humidity [-]
!MV202609 greenroof-to-atm exchange diagnostics (from URBAN_DRAG)
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_GREENROOF_ATM ! greenroof aerodynamical conductance (atm.)
REAL, DIMENSION(:), INTENT(INOUT)   :: PCD_GREENROOF_ATM ! greenroof drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN_GREENROOF_ATM! greenroof neutral drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_GREENROOF_ATM ! greenroof drag coefficient for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_GREENROOF_ATM ! greenroof Richardson number (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: ZZ0H_GREENROOF_ATM! greenroof roughness length for heat (atm.)
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT   ! diagnostics container (owned by the driver)
TYPE(TEB_t),         INTENT(INOUT) :: TSTATE   ! state of TEB
TYPE(BEM_t),         INTENT(INOUT) :: BSTATE   ! state of BEM
TYPE(TEB_PANEL_t),   INTENT(INOUT) :: TPN      ! solar panels
TYPE(TEB_IRRIG_t),   INTENT(INOUT) :: TIR      ! irrigation
!MV202609 CBS scheme of the road
REAL,                 INTENT(IN)  :: XTAU_HW_THRESH   ! H/W giving tau = 0.5 (CBS scheme)
REAL,                 INTENT(IN)  :: XTAU_HW_WIDTH    ! width of the tanh relaxation (CBS scheme)
!MV202609 garden thermal roughness (z0h)
!MV202609 greenroof model type, thermal roughness and surface humidity

!                                                         !    and structural roof
!
! new arguments created after BEM
!
REAL, DIMENSION(:)  , INTENT(IN)    :: PNATVENT           ! flag to describe surventilation system for i/o 
                                                          ! 0 for NONE, 1 for MANU and 2 for AUTO
INTEGER             , INTENT(IN)    :: KDAY               ! Simulation day
REAL, DIMENSION(:)  , INTENT(INOUT) :: PAUX_MAX           ! Auxiliar variable for autosize calcs
REAL, DIMENSION(:,:), INTENT(INOUT) :: PT_FLOOR           ! Floor layers temperatures [K]
REAL, DIMENSION(:,:), INTENT(INOUT) :: PT_MASS            ! Internal mass layers temperatures [K]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_BLD_COOL        ! Sensible cooling energy demand  
                                                          ! of the building [W m-2(bld)]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PT_BLD_COOL        ! Total cooling energy demand  
                                                          ! of the building [W m-2(bld)]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_BLD_HEAT        ! Heating energy demand       
                                                          ! of the building [W m-2(bld)]
REAL, DIMENSION(:  ), INTENT(OUT)   :: PLE_BLD_COOL       ! Latent cooling energy demand 
                                                          ! of the building [W m-2(bld)]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_BLD_HEAT       ! Latent heating energy demand 
                                                          ! of the building [W m-2(bld)]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_WASTE           ! Sensible waste heat from HVAC system
                                                          ! [W m-2(tot)]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_WASTE          ! Latent waste heat from HVAC system
                                                          ! [W m-2(tot)]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PHVAC_COOL         ! Energy consumption of the cooling system
                                                          ! [W m-2(bld)]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PHVAC_HEAT         ! Energy consumption of the heating system
                                                          ! [W m-2(bld)]
                                                          ! [W m-2(bld)]
                                                          ! [W m-2(bld)]
REAL, DIMENSION(:)  , INTENT(IN)    :: PT_ADP             ! Apparatus dewpoint temperature of the
                                                          ! cooling coil [K]
                                                          ! [kg s-1 m-2(bld)]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCAP_SYS           ! Actual capacity of the cooling system
                                                          ! [W m-2(bld)] 
REAL, DIMENSION(:)  , INTENT(OUT)   :: PM_SYS             ! Actual HVAC mass flow rate 
                                                          ! [kg s-1 m-2(bld)]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCOP               ! COP of the cooling system
REAL, DIMENSION(:)  , INTENT(OUT)   :: PQ_SYS             ! Supply air specific humidity [kg kg-1]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PT_SYS             ! Supply air temperature [K]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PTR_SW_WIN         ! Solar radiation transmitted throught
                                                          ! windows [W m-2(bld)]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PFAN_POWER         ! HVAC fan power
REAL, DIMENSION(:,:), INTENT(IN)    :: PHC_FLOOR          ! heat capacity for road layers
REAL, DIMENSION(:,:), INTENT(IN)    :: PTC_FLOOR          ! thermal conductivity for 
                                                          ! road layers
REAL, DIMENSION(:,:), INTENT(IN)    :: PD_FLOOR           ! depth of road layers

REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_SW_WIN        ! window absorbed shortwave radiation [W m-2] 
REAL, DIMENSION(:)  , INTENT(OUT)   :: PABS_LW_WIN        ! absorbed infrared rad. [W m-2]
REAL, DIMENSION(:)  , INTENT(IN)    :: PUGG_WIN           ! window glass-to-glass U-factro [W m-2 K-1]
REAL, DIMENSION(:)  , INTENT(OUT)   :: PALB_WIN           ! window albedo
REAL, DIMENSION(:)  , INTENT(IN)    :: PABS_WIN           ! window absortance
REAL, DIMENSION(:)  , INTENT(IN)    :: PTRAN_WIN          ! window transmittance
!
! new argument for the UTCI calculation
REAL, DIMENSION(:)  , INTENT(OUT)    :: PEMIT_LW_GRND     ! LW flux emitted by the ground (W/m2 ground)
REAL, DIMENSION(:)  , INTENT(OUT)    :: PEMIT_LW_FAC      ! LW flux emitted by the facade (W/m2 ground)
REAL, DIMENSION(:)  , INTENT(OUT)    :: PT_RAD_IND        ! Indoor mean radiant temperature [K]
REAL, DIMENSION(:)  , INTENT(OUT)    :: PREF_SW_GRND      ! total solar rad reflected from ground
REAL, DIMENSION(:)  , INTENT(OUT)    :: PREF_SW_FAC       ! total solar rad reflected from facade
REAL, DIMENSION(:)  , INTENT(OUT)    :: PHU_BLD           ! Indoor relative humidity 0 < (-) < 1
!
! new arguments for shading, schedule or natural ventilation
REAL                , INTENT(IN)     :: PTIME             ! current time since midnight (UTC, s)
REAL, DIMENSION(:)  , INTENT(IN)     :: PSHADE            ! flag to activate shading devices -> REAL for i/o 0. or 1     
!
LOGICAL             , INTENT(IN)     :: OCANOPY           ! is canopy active ?
!
!* arguments for road watering
!
LOGICAL,              INTENT(IN)      :: OPAR_RD_IRRIG  ! True if there is potentially irrigation
REAL, DIMENSION(:),   INTENT(IN)      :: PRD_START_MONTH! First month of irrigation
REAL, DIMENSION(:),   INTENT(IN)      :: PRD_END_MONTH  ! Last month of irrigation
REAL, DIMENSION(:),   INTENT(IN)      :: PRD_START_HOUR ! First hour of irrigation (included)
REAL, DIMENSION(:),   INTENT(IN)      :: PRD_END_HOUR   ! Last hour of irrigation  (excluded)
REAL, DIMENSION(:),   INTENT(IN)      :: PRD_24H_IRRIG  ! diurnal averaged irrigation flux (kg/m2/s)
REAL, DIMENSION(:),   INTENT(OUT)     :: PIRRIG_ROAD    ! man-made watering of roads (kg/m2/s)
!
!* arguments for solar panels
!
REAL, DIMENSION(:),   INTENT(IN)      :: PEMIS_PANEL    ! Emissivity of solar panels (-)
REAL, DIMENSION(:),   INTENT(IN)      :: PALB_PANEL     ! Albedo     of solar panels (-)
REAL, DIMENSION(:),   INTENT(IN)      :: PEFF_PANEL     ! Efficiency of solar panel (-)
REAL, DIMENSION(:),   INTENT(IN)      :: PFRAC_PANEL    ! Fraction of solar panel on roofs (-)
REAL, DIMENSION(:),   INTENT(OUT)     :: PTHER_PROD_PANEL ! Thermal      Energy production of solar panel on roofs (W/m2 panel)
REAL, DIMENSION(:),   INTENT(OUT)     :: PPHOT_PROD_PANEL ! Photovoltaic Energy production of solar panel on roofs (W/m2 panel)
REAL, DIMENSION(:),   INTENT(OUT)     :: PPROD_PANEL      ! Averaged     Energy production of solar panel on roofs (W/m2 panel)
REAL, DIMENSION(:),   INTENT(OUT)     :: PTHER_PROD_BLD   ! Thermal      Energy production of solar panel on roofs (W/m2 bld  )
REAL, DIMENSION(:),   INTENT(OUT)     :: PPHOT_PROD_BLD   ! Photovoltaic Energy production of solar panel on roofs (W/m2 bld  )
REAL, DIMENSION(:),   INTENT(OUT)     :: PPROD_BLD        ! Averaged     Energy production of solar panel on roofs (W/m2 bld  )
REAL, DIMENSION(:),   INTENT(INOUT)   :: PTHER_PRODC_DAY  ! Present day integrated thermal production of energy    (J/m2 panel)
REAL, DIMENSION(:),   INTENT(OUT)     :: PH_PANEL       ! Sensible heat flux from solar panels      (W/m2 panel)
REAL, DIMENSION(:),   INTENT(OUT)     :: PRN_PANEL      ! Net radiation        of solar panel       (W/m2 panel)
!
!* arguments for building's use description
!
REAL, DIMENSION(:),   INTENT(OUT)     :: PCUR_TCOOL_TARGET ! Cooling target temperature at current time (K)
REAL, DIMENSION(:),   INTENT(OUT)     :: PCUR_THEAT_TARGET ! Heating target temperature at current time (K)
REAL, DIMENSION(:),   INTENT(OUT)     :: PCUR_QIN          ! Internal heat gains        at current time (W/m2 floor)

REAL, DIMENSION(:)  , INTENT(OUT)     :: PDN_RF            ! snow fraction on roofs
REAL, DIMENSION(:)  , INTENT(OUT)     :: PDN_RD            ! snow fraction on roads
REAL, DIMENSION(:)  , INTENT(OUT)     :: PMELT_BLT         ! Snow melt for built & impervious part
REAL, DIMENSION(:)  , INTENT(OUT)     :: PSNOWD_RF         ! snow depth on roofs
REAL, DIMENSION(:)  , INTENT(OUT)     :: PSNOWD_RD         ! snow depth on roads
REAL, DIMENSION(:)  , INTENT(OUT)     :: PLW_UP            ! upwards longwave radiation

!
!-------------------------------------------------------------------------------
!
!
END SUBROUTINE TEB_GARDEN_STRUCT
!
END INTERFACE
!
END MODULE MODI_TEB_GARDEN_STRUCT
