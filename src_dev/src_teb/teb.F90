!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!   ##########################################################################
    SUBROUTINE TEB  (icell, iblock, TOP, T, BOP, B, TIR, DMT, HIMPLICIT_WIND, PBEM_AC, PTSUN,                   &
                     PT_CANYON, PQ_CANYON, PU_CANYON, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN,  &
                     PZ_LOWCAN, PPEW_A_COEF, PPEW_B_COEF, PPEW_A_COEF_LOWCAN,           &
                     PPEW_B_COEF_LOWCAN, PZ0_GARDEN_EXT, PZ0_GR_EXT, PPS, PPA, PEXNS, PEXNA, PTA, PQA, PRHOA,       &
                     PLW_RAD, PRR, PSR, PZREF, PUREF, PVMOD, PH_TRAFFIC, PLE_TRAFFIC,   &
                     PTSTEP, PDF_RF, PDN_RF, PDF_RD, PDN_RD, PQSAT_RF, PQSAT_RD,        &
                     PDELT_RF, PDELT_RD, PTS_GARDEN, PQS_GARDEN, PLEW_RF, PUW_GR, PLEW_RD, PLE_WL_A,&
                     PLE_WL_B, PRNSN_RF, PHSN_RF, PLESN_RF, PGSN_RF, PMELT_RF, PRN_GR, &
                     PH_GR, PLE_GR, PGFLUX_GR, PDRAIN_GR, PTSRAD_GR, PRUNOFF_GR, PRNSN_RD,    &
                     PHSN_RD, PLESN_RD, PGSN_RD, PMELT_RD, PUW_RD, PUW_RF, PDUWDU_RD,   &
!MV202609 tau scheme of the road (revision: snow-to-atmosphere branch)
                      PHSN_RD_CAN, PHSN_RD_ATM, PLESN_RD_CAN, PLESN_RD_ATM,   &
                     PDUWDU_RF, PUSTAR_TWN, PCD, PCDN, PCH_TWN, PRI_TWN, PRESA_TWN,     &
                     PAC_RF, PAC_RD, PAC_WL, PAC_TOP, PAC_GARDEN, PAC_RF_WAT,           &
                     PAC_RD_WAT, PLW_WA_TO_WB, PLW_WA_TO_R, PLW_WB_TO_R, PLW_WA_TO_NR,  &
                     PLW_WB_TO_NR, PLW_R_TO_WA, PLW_R_TO_WB, PLW_G_TO_WA, PLW_G_TO_WB,  &
                     PLW_S_TO_WA, PLW_S_TO_WB, PLW_S_TO_R, PLW_S_TO_NR, PLW_NR_TO_WA,   &
                     PLW_NR_TO_WB, PLW_NR_TO_WIN, PLW_WA_TO_WIN, PLW_WB_TO_WIN,         &
                     PLW_G_TO_WIN, PLW_R_TO_WIN, PLW_S_TO_WIN, PLW_WIN_TO_WA,           &
                     PLW_WIN_TO_WB, PLW_WIN_TO_R, PLW_WIN_TO_NR, KDAY, PEMIT_LW_FAC,    &
                     PEMIT_LW_RD, PT_RAD_IND, PHU_BLD, PTIME, PE_SHADING, PMELT_BLT,    &
					 PSNOWD_RF, PSNOWD_RD, PCH_GARDEN, PCD_GARDEN, PCH_ROAD, PCH_ROOF,  &
					 PCH_WALL, PCH_TOP, ILMO_ROAD, ILMO_ROOF, ILMO_TOP, PCD_GARDEN_ATM,      &
					 PCH_GARDEN_ATM,                         &
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
                          PCD_ROAD_CAN, PCDN_ROAD_CAN, PRI_ROAD_CAN, ZZ0H_ROAD_CAN, &
                          PAC_ROAD_ATM, PCH_ROAD_ATM, PCD_ROAD_ATM, PCDN_ROAD_ATM, &
                          PRI_ROAD_ATM, ZZ0H_ROAD_ATM, PCDN_GARDEN_CAN, PRI_GARDEN_CAN, &
                          ZZ0H_GARDEN_CAN, PAC_GARDEN_ATM, PCDN_GARDEN_ATM, PRI_GARDEN_ATM, ZZ0H_GARDEN_ATM, &
!MV202609 greenroof-to-atm exchange diagnostics
                          PAC_GREENROOF_ATM, PCD_GREENROOF_ATM, PCDN_GREENROOF_ATM, PCH_GREENROOF_ATM, &
                          PRI_GREENROOF_ATM, ZZ0H_GREENROOF_ATM, &
                          PH_ROAD_CAN, PLE_ROAD_CAN, PH_ROAD_ATM, PLE_ROAD_ATM, &
!MV202609 tau scheme of the road
                          PTAU, PH_ROAD, PLE_ROAD, PAC_ROAD_ATM_WAT, LE_ROAD_WAT, LE_ROAD_SNOW, &
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
                          LE_ROOF_WAT, LE_ROOF_SNOW)
					 
				 
!   ##########################################################################
!
!!****  *TEB*  
!!
!!    PURPOSE
!!    -------
!
!     Computes the evoultion of prognostic variables and the fluxes
!     over artificial surfaces as towns, taking into account the canyon like
!     geometry of urbanized areas.
!         
!     
!!**  METHOD
!     ------
!
!     The prognostic variables are:
!       - the surface temperature for roofs, roads, and walls
!       - the water reservoir, whose maximum value is 10mm
!
!
!    1 : Warning about snow
!        ******************
!
!     Except for snow mantel evolution, all other computation with snow
!   variables must be performed with these variables at previous time-step,
!   and NOT new time-step. This insure coherence between snow fractions
!   (computed at the begining) and other snow characteristics (albedo, Ts).
!
!
!    2 : computation of input solar radiation on each surface
!        ****************************************************
!
!      Those are now done in subroutine urban_solar_abs.F90
!
!    3 : drag coefficient for momentum 
!        *****************************
!
!
!    4 : aerodynamical resistance for heat transfers
!        *******************************************
!
!
!    5 : equation for evolution of Ts_roof
!        *********************************
!
!
!       Rn = (dir_Rg + sca_Rg) (1-a) + emis * ( Rat - sigma Ts**4 (t+dt) )
!
!       H  = rho Cp CH V ( Ts (t+dt) - Tas )
!
!       LE = rho Lv CH V ( qs (t+dt) - qas )
!
!      where the as subscript denotes atmospheric values at ground level
!      (and not at first half level)
!
!
!    6 : equations for evolution of Ts_road and Ts_wall simultaneously
!        *************************************************************
!
!
!
!   Rn_w = abs_Rg_w 
!  - sigma * emis_w                                                   * Ts_w**4 (t+dt)
!  +         emis_w                       *      SVF_w                * Rat
!  + sigma * emis_w * emis_r              *      SVF_w                * Ts_r**4 (t+dt)
!  + sigma * emis_w * emis_w              * (1-2*SVF_w)               * Ts_w**4 (t+dt)
!  + sigma * emis_w * emis_w * (1-emis_r) *      SVF_w  * (1-  SVF_r) * Ts_w**4 (t+dt)
!  + sigma * emis_w * emis_w * (1-emis_w) * (1-2*SVF_w) * (1-2*SVF_w) * Ts_w**4 (t+dt)
!  + sigma * emis_w * emis_r * (1-emis_w) *      SVF_w  * (1-2*SVF_w) * Ts_r**4 (t+dt)
!
!   Rn_r = abs_Rg_r
!  - sigma * emis_r                                                   * Ts_r**4 (t+dt)
!  +         emis_r                       *    SVF_r                  * Rat
!  + sigma * emis_r * emis_w              * (1-SVF_r)                 * Ts_w**4 (t+dt)
!  + sigma * emis_r * emis_w * (1-emis_w) * (1-SVF_r)   * (1-2*SVF_w) * Ts_w**4 (t+dt)
!  + sigma * emis_r * emis_r * (1-emis_w) * (1-SVF_r)   *      SVF_w  * Ts_r**4 (t+dt)
!
!  H_w  = rho Cp CH V ( Ts_w (t+dt) - Ta_canyon )
!
!  LE_w = rho Lv CH V ( qs_w (t+dt) - qa_canyon )
!
!  H_r  = rho Cp CH V ( Ts_r (t+dt) - Ta_canyon )
!
!  LE_r = rho Lv CH V ( qs_r (t+dt) - qa_canyon )
!
! with again
!                AC_can * Swall/Sroad * Twall + AC_can * Troad + AC_top * Ta + H_traffic/Cp/rho/Sroad
!   Ta_canyon = -------------------------------------------------------------------------------------
!                AC_can * Swall/Sroad         + AC_can         + AC_top
!
!
!                 AC_can * delt_road * Hu_road * qsat(Troad) + AC_top * qa + LE_traffic/Lv/rho/Sroad
!   qa_canyon = ------------------------------------------------------------------------------------
!                 AC_can * delt_road                        + AC_top
!
!
!
!
!    7 : computation of fluxes for each surface type
!        *******************************************
!
!
!    8 : averaging of the fluxes
!        ***********************
!
!   This is done on the total exchange surface (roof + wall + road),
!  which is bigger than the horizontal surface (roof+road), leading
!  to bigger fluxes.
!
!   The fluxes due to industrial activity are directly added into the 
!  atmosphere
!
!
!    9 : road reservoir evolution
!        ************************
!
!   The roof reservoir runoff goes directly into the road reservoir.
!
!   Runoff occurs for road reservoir (too much water), as well as drainage
!   (evacuation system, typical time scale: 1 day)
!
!
!------------------------
!!    EXTERNAL
!!    --------
!!
!!
!!    IMPLICIT ARGUMENTS
!!    ------------------
!!
!!    MODD_CST
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
!!      Original    23/01/98 
!!     21 / 10 / 2003   P. Tulet    output aerodynamical resistance
!!     01 / 07 / 2005   P.Le Moigne Exner functions as arguments to urban_fluxes
!!     17 / 10 / 2005   (G. Pigeon) computation of anthropogenic heat from domestic heating
!!          01 / 2012   V. Masson   Separates the 2 walls 
!!     25 / 09 / 2012   B. Decharme new wind implicitation
!!          07 / 2013   V. Masson   Adds road watering
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!     ------------
!
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_n, ONLY : TEB_t
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t
USE MODD_BEM_n, ONLY : BEM_t
USE MODD_TEB_IRRIG_n, ONLY : TEB_IRRIG_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
!
USE MODD_TYPE_DATE_SURF,ONLY: DATE_TIME
USE MODD_CSTS,         ONLY : XTT, XSTEFAN, XCPD, XLVTT
USE MODD_SURF_PAR,     ONLY : XUNDEF
USE MODD_SNOW_PAR,     ONLY : XEMISSN, XANSMAX_ROOF, &
                          XANSMAX_ROAD,XWCRN_ROOF,XWCRN_ROAD
!
USE MODE_THERMOS
USE MODE_SURF_SNOW_FRAC
!
USE MODI_SNOW_COVER_1LAYER
USE MODI_URBAN_DRAG
USE MODI_URBAN_SNOW_EVOL
USE MODI_ROOF_LAYER_E_BUDGET
USE MODI_ROAD_LAYER_E_BUDGET
USE MODI_FACADE_E_BUDGET
USE MODI_URBAN_FLUXES
USE MODI_URBAN_HYDRO
USE MODI_BLD_E_BUDGET
USE MODI_WIND_THRESHOLD
USE MODI_BEM
USE MODI_TEB_IRRIG
!
USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
USE PARKIND1  ,ONLY : JPRB
!
IMPLICIT NONE
!
!*      0.1    Declarations of arguments

INTEGER                           :: icell
INTEGER                           :: iblock 

!
TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: TOP
TYPE(TEB_t), INTENT(INOUT) :: T
TYPE(BEM_OPTIONS_t), INTENT(INOUT) :: BOP
TYPE(BEM_t), INTENT(INOUT) :: B
TYPE(TEB_IRRIG_t), INTENT(INOUT) :: TIR
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT
!
  CHARACTER(LEN=*),     INTENT(IN)  :: HIMPLICIT_WIND   ! wind implicitation option
!                                                     ! 'OLD' = direct
!                                                     ! 'NEW' = Taylor serie, order 1


LOGICAL,INTENT(IN)                :: PBEM_AC       ! Flag to use air conditioners
REAL, DIMENSION(:), INTENT(IN)    :: PTSUN         ! solar time   (s from midnight)
REAL, DIMENSION(:), INTENT(INOUT) :: PT_CANYON     ! canyon air temperature
REAL, DIMENSION(:), INTENT(INOUT) :: PQ_CANYON     ! canyon air specific humidity
REAL, DIMENSION(:), INTENT(IN)    :: PU_CANYON     ! canyon hor. wind
REAL, DIMENSION(:), INTENT(IN)    :: PU_LOWCAN     ! wind near the road
REAL, DIMENSION(:), INTENT(IN)    :: PT_LOWCAN     ! temp. near the road
REAL, DIMENSION(:), INTENT(IN)    :: PQ_LOWCAN     ! hum. near the road
REAL, DIMENSION(:), INTENT(IN)    :: PZ_LOWCAN     ! height of atm. var. near the road
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_A_COEF   ! implicit coefficients
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_B_COEF   ! for wind coupling
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_A_COEF_LOWCAN ! implicit coefficients for wind coupling
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_B_COEF_LOWCAN ! between low canyon wind and road
REAL, DIMENSION(:), INTENT(IN)    :: PPS           ! pressure at the surface
REAL, DIMENSION(:), INTENT(IN)    :: PPA           ! pressure at the first atmospheric level
REAL, DIMENSION(:), INTENT(IN)    :: PEXNS         ! surface exner function
REAL, DIMENSION(:), INTENT(IN)    :: PTA           ! temperature at the lowest level
REAL, DIMENSION(:), INTENT(IN)    :: PQA           ! specific humidity
                                                   ! at the lowest level
REAL, DIMENSION(:), INTENT(IN)    :: PVMOD         ! module of the horizontal wind
REAL, DIMENSION(:), INTENT(IN)    :: PH_TRAFFIC    ! anthropogenic sensible
!                                                  ! heat fluxes due to traffic
REAL, DIMENSION(:), INTENT(IN)    :: PLE_TRAFFIC   ! anthropogenic latent
!                                                  ! heat fluxes due to traffic
REAL, DIMENSION(:), INTENT(IN)    :: PEXNA         ! exner function
                                                   ! at the lowest level
REAL, DIMENSION(:), INTENT(IN)    :: PRHOA         ! air density
                                                   ! at the lowest level
REAL, DIMENSION(:), INTENT(IN)    :: PLW_RAD       ! atmospheric infrared radiation
REAL, DIMENSION(:), INTENT(IN)    :: PRR           ! rain rate
REAL, DIMENSION(:), INTENT(IN)    :: PSR           ! snow rate
REAL, DIMENSION(:), INTENT(IN)    :: PZREF         ! reference height of the first
                                                   ! atmospheric level (temperature)
REAL, DIMENSION(:), INTENT(IN)    :: PUREF         ! reference height of the first
                                                   ! atmospheric level (wind)
REAL,               INTENT(IN)    :: PTSTEP        ! time step
!
REAL, DIMENSION(:), INTENT(INOUT) :: PDF_RF      ! snow-free    fraction on roofs
REAL, DIMENSION(:), INTENT(INOUT) :: PDN_RF      ! snow-covered fraction on roofs
REAL, DIMENSION(:), INTENT(INOUT) :: PDF_RD      ! snow-free    fraction on roads
REAL, DIMENSION(:), INTENT(INOUT) :: PDN_RD      ! snow-covered fraction on roads
REAL, DIMENSION(:), INTENT(OUT)   :: PQSAT_RF    ! hum at saturation over roof
REAL, DIMENSION(:), INTENT(OUT)   :: PQSAT_RD    ! hum at saturation over road
REAL, DIMENSION(:), INTENT(OUT)   :: PDELT_RF    ! water fraction on roof
REAL, DIMENSION(:), INTENT(OUT)   :: PDELT_RD    ! water fraction on road
!
REAL, DIMENSION(:), INTENT(IN)    :: PTS_GARDEN    ! GARDEN area surf temp.
REAL, DIMENSION(:), INTENT(IN)    :: PQS_GARDEN    ! GARDEN area surf hum.
! greenroof
REAL, DIMENSION(:), INTENT(OUT)   :: PLEW_RF    ! latent heat flux over roof (snow)
REAL, DIMENSION(:), INTENT(OUT)   :: PLEW_RD    ! latent heat flux over road (snow)
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_WL_A   ! latent heat flux over wall
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_WL_B   ! latent heat flux over wall
!
REAL, DIMENSION(:), INTENT(IN)    :: PUW_GR     ! Momentum flux for greenroofs
!
REAL, DIMENSION(:), INTENT(OUT)   :: PRNSN_RF ! net radiation over snow
REAL, DIMENSION(:), INTENT(OUT)   :: PHSN_RF  ! sensible heat flux over snow
REAL, DIMENSION(:), INTENT(OUT)   :: PLESN_RF ! latent heat flux over snow
REAL, DIMENSION(:), INTENT(OUT)   :: PGSN_RF  ! flux under the snow
REAL, DIMENSION(:), INTENT(OUT)   :: PMELT_RF   ! snow melt
REAL, DIMENSION(:), INTENT(OUT)   :: PRNSN_RD ! net radiation over snow
REAL, DIMENSION(:), INTENT(OUT)   :: PHSN_RD  ! sensible heat flux over snow
REAL, DIMENSION(:), INTENT(OUT)   :: PLESN_RD ! latent heat flux over snow
!MV202609 tau scheme of the road (revision: snow-to-atmosphere branch)
REAL, DIMENSION(:), INTENT(OUT)   :: PHSN_RD_CAN  ! sensible heat flux over snow, snow -> canyon air
REAL, DIMENSION(:), INTENT(OUT)   :: PHSN_RD_ATM  ! sensible heat flux over snow, snow -> forcing level
REAL, DIMENSION(:), INTENT(OUT)   :: PLESN_RD_CAN ! latent heat flux over snow, snow -> canyon air
REAL, DIMENSION(:), INTENT(OUT)   :: PLESN_RD_ATM ! latent heat flux over snow, snow -> forcing level
REAL, DIMENSION(:), INTENT(OUT)   :: PGSN_RD  ! flux under the snow
REAL, DIMENSION(:), INTENT(OUT)   :: PMELT_RD   ! snow melt
!
REAL, DIMENSION(:), INTENT(OUT)   :: PUW_RD     ! Momentum flux for roads
REAL, DIMENSION(:), INTENT(OUT)   :: PUW_RF     ! Momentum flux for roofs
REAL, DIMENSION(:), INTENT(OUT)   :: PDUWDU_RD  !
REAL, DIMENSION(:), INTENT(OUT)   :: PDUWDU_RF  !
REAL, DIMENSION(:), INTENT(OUT)   :: PUSTAR_TWN ! friciton velocity over town
!
REAL, DIMENSION(:), INTENT(IN)    :: PRN_GR     ! net radiation over greenroof
REAL, DIMENSION(:), INTENT(IN)    :: PH_GR      ! sensible heat flux over greenroof
REAL, DIMENSION(:), INTENT(IN)    :: PLE_GR     ! latent heat flux over greenroof
REAL, DIMENSION(:), INTENT(IN)    :: PGFLUX_GR  ! flux through the greenroof
REAL, DIMENSION(:), INTENT(IN)    :: PTSRAD_GR !
REAL, DIMENSION(:), INTENT(IN)    :: PRUNOFF_GR ! runoff over green roofs
REAL, DIMENSION(:), INTENT(IN)    :: PDRAIN_GR  ! outlet drainage at base of green roofs
!
REAL, DIMENSION(:), INTENT(OUT)   :: PCD          ! town averaged drag coefficient
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN         ! town averaged neutral drag coefficient
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_TWN     ! town averaged heat transfer
!                                                 ! coefficient
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_TWN      ! town averaged Richardson number
REAL, DIMENSION(:), INTENT(OUT)   :: PRESA_TWN    ! town aerodynamical resistance
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_RF      ! roof conductance
REAL, DIMENSION(:), INTENT(INOUT) :: PAC_RD      ! road conductance
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_WL      ! wall conductance
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_TOP       ! top conductance
REAL, DIMENSION(:), INTENT(IN)    :: PAC_GARDEN    ! garden conductance
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_RF_WAT  ! roof water conductance
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_RD_WAT  ! roof water conductance
!
REAL, DIMENSION(:), INTENT(IN)    :: PLW_WA_TO_WB      ! LW contrib. wall A (orB) -> wall B (or A)
REAL, DIMENSION(:), INTENT(IN)    :: PLW_WA_TO_R         ! LW contrib. wall       -> road
REAL, DIMENSION(:), INTENT(IN)    :: PLW_WB_TO_R         ! LW contrib. wall       -> road
REAL, DIMENSION(:), INTENT(IN)    :: PLW_WA_TO_NR        ! LW contrib. wall       -> road(snow)
REAL, DIMENSION(:), INTENT(IN)    :: PLW_WB_TO_NR        ! LW contrib. wall       -> road(snow)
REAL, DIMENSION(:), INTENT(IN)    :: PLW_R_TO_WA         ! LW contrib. road       -> wall
REAL, DIMENSION(:), INTENT(IN)    :: PLW_R_TO_WB         ! LW contrib. road       -> wall
REAL, DIMENSION(:), INTENT(IN)    :: PLW_G_TO_WA         ! LW contrib. GARDEN     -> wall
REAL, DIMENSION(:), INTENT(IN)    :: PLW_G_TO_WB         ! LW contrib. GARDEN     -> wall
REAL, DIMENSION(:), INTENT(IN)    :: PLW_NR_TO_WA        ! LW contrib. road(snow) -> wall
REAL, DIMENSION(:), INTENT(IN)    :: PLW_NR_TO_WB        ! LW contrib. road(snow) -> wall
REAL, DIMENSION(:), INTENT(IN)    :: PLW_S_TO_WA         ! LW contrib. sky        -> wall
REAL, DIMENSION(:), INTENT(IN)    :: PLW_S_TO_WB         ! LW contrib. sky        -> wall
REAL, DIMENSION(:), INTENT(IN)    :: PLW_S_TO_R          ! LW contrib. sky        -> road
REAL, DIMENSION(:), INTENT(IN)    :: PLW_S_TO_NR         ! LW contrib. sky        -> road(snow)
REAL, DIMENSION(:), INTENT(IN)    :: PZ0_GARDEN_EXT      ! garden roughness length (external model)
REAL, DIMENSION(:), INTENT(IN)    :: PZ0_GR_EXT          ! greenroof roughness length (external model)
!
! new arguments after BEM
!
INTEGER,            INTENT(IN)     :: KDAY         ! Simulation day
REAL, DIMENSION(:), INTENT(IN)   :: PLW_WA_TO_WIN ! Radiative heat trasfer coeff wall-window 
                                                  ! [W K-1 m-2] 
REAL, DIMENSION(:), INTENT(IN)   :: PLW_WB_TO_WIN ! Radiative heat trasfer coeff wall-window 
                                                  ! [W K-1 m-2] 
REAL, DIMENSION(:), INTENT(IN)   :: PLW_G_TO_WIN  ! Radiative heat trasfer coeff garden-window 
                                                  ! [W K-1 m-2]
REAL, DIMENSION(:), INTENT(IN)   :: PLW_R_TO_WIN  ! Radiative heat trasfer coeff road-window 
                                                  ! [W K-1 m-2] 
REAL, DIMENSION(:), INTENT(IN)   :: PLW_S_TO_WIN ! Radiative heat trasfer coeff window-sky 
                                                 ! [W K-1 m-2]
REAL, DIMENSION(:), INTENT(IN)   :: PLW_WIN_TO_WA! Radiative heat trasfer coeff window-wall
                                                 ! [W K-1 m-2] 
REAL, DIMENSION(:), INTENT(IN)   :: PLW_WIN_TO_WB! Radiative heat trasfer coeff window-wall
                                                 ! [W K-1 m-2] 
REAL, DIMENSION(:), INTENT(IN)   :: PLW_WIN_TO_R ! Radiative heat trasfer coeff window-road 
                                                 ! [W K-1 m-2]
REAL, DIMENSION(:), INTENT(IN)   :: PLW_NR_TO_WIN! Radiative heat trasfer coeff road(snow)-win 
                                                 ! [W K-1 m-2]
REAL, DIMENSION(:), INTENT(IN)   :: PLW_WIN_TO_NR! Radiative heat trasfer coeff win-road(snow) 
                                                 ! [W K-1 m-2]
 !new argument for PET calculation
REAL, DIMENSION(:), INTENT(OUT) :: PEMIT_LW_RD ! LW fluxes emitted by road (W/m2 surf road)
REAL, DIMENSION(:), INTENT(OUT) :: PEMIT_LW_FAC  ! LW fluxes emitted by wall (W/m2 surf wall)
REAL, DIMENSION(:), INTENT(OUT) :: PT_RAD_IND    ! Indoor mean radiant temperature [K]
REAL, DIMENSION(:), INTENT(OUT) :: PHU_BLD       ! Indoor relative humidity 0 < (-) < 1
REAL,                INTENT(IN)  :: PTIME        ! current time since midnight (UTC, s)
REAL, DIMENSION(:), INTENT(IN)  :: PE_SHADING    !energy not ref., nor absorbed, nor
												 !trans. by glazing [Wm-2(win)]

REAL, DIMENSION(:), INTENT(OUT) :: PMELT_BLT     ! Snow melt for built & impervious part
REAL, DIMENSION(:), INTENT(OUT) :: PSNOWD_RF     ! snow depth on roofs
REAL, DIMENSION(:), INTENT(OUT) :: PSNOWD_RD     ! snow depth on roads                                              
REAL, DIMENSION(:), INTENT(OUT) :: PCH_GARDEN    ! drag coeifficient for heat
REAL, DIMENSION(:), INTENT(OUT) :: PCD_GARDEN    ! garden  surf. exchange coefficient
REAL, DIMENSION(:), INTENT(OUT) :: PCH_ROAD      ! drag coeifficient for heat
REAL, DIMENSION(:), INTENT(OUT) :: PCH_ROOF      ! drag coeifficient for heat
REAL, DIMENSION(:), INTENT(OUT) :: PCH_WALL      ! drag coeifficient for heat
REAL, DIMENSION(:), INTENT(OUT) :: PCH_TOP       ! drag coeifficient for heat
REAL, DIMENSION(:), INTENT(OUT) :: ILMO_ROAD      ! 1/length of Monin-Obukov
REAL, DIMENSION(:), INTENT(OUT) :: ILMO_ROOF      ! 1/length of Monin-Obukov
REAL, DIMENSION(:), INTENT(OUT) :: ILMO_TOP       ! 1/length of Monin-Obukov
REAL, DIMENSION(:), INTENT(OUT) :: PCD_GARDEN_ATM
REAL, DIMENSION(:), INTENT(OUT) :: PCH_GARDEN_ATM
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
REAL, DIMENSION(:), INTENT(OUT) :: PH_ROAD_ATM   ! sensible heat flux, road -> forcing level [W m-2]
REAL, DIMENSION(:), INTENT(OUT) :: PLE_ROAD_ATM  ! latent heat flux, road -> forcing level [W m-2]
REAL, DIMENSION(:), INTENT(OUT) :: PH_ROAD_CAN   ! sensible heat flux, road -> canyon air [W m-2]
REAL, DIMENSION(:), INTENT(OUT) :: PLE_ROAD_CAN  ! latent heat flux, road -> canyon air [W m-2]
!MV202609 tau scheme of the road
REAL, DIMENSION(:), INTENT(OUT) :: PH_ROAD       ! road sensible heat flux, tau scheme [W m-2]
REAL, DIMENSION(:), INTENT(OUT) :: PLE_ROAD      ! road latent heat flux, tau scheme [W m-2]
!MV202609 tau scheme of the road (revision: puddle diagnostics)
REAL, DIMENSION(:), INTENT(OUT) :: PAC_ROAD_ATM_WAT ! road water conductance, road -> forcing level (water-limited)
REAL, DIMENSION(:), INTENT(OUT) :: LE_ROAD_WAT      ! road latent heat flux of the snow-free road (W/m2 road)
REAL, DIMENSION(:), INTENT(OUT) :: LE_ROAD_SNOW     ! road latent heat flux of the snow-covered road (W/m2 road)
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
REAL, DIMENSION(:), INTENT(OUT) :: LE_ROOF_WAT      ! roof latent heat flux of the snow-free roof (W/m2 roof)
REAL, DIMENSION(:), INTENT(OUT) :: LE_ROOF_SNOW     ! roof latent heat flux of the snow-covered roof (W/m2 roof)
!
!*      0.2    Declarations of local variables
!
REAL, DIMENSION(SIZE(PTA)) :: ZVMOD          ! wind
REAL, DIMENSION(SIZE(PTA)) :: ZWS_RF_MAX   ! maximum deepness of roof
REAL, DIMENSION(SIZE(PTA)) :: ZWS_RD_MAX   ! and road water reservoirs
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
REAL, DIMENSION(SIZE(PTA)) :: ZAC_RD_ATM_WAT ! road conductance for water (forcing level)
REAL, DIMENSION(SIZE(PTA)) :: ZDF_RD         ! snow-free road fraction (for the atm. flux)
!MV202609 tau scheme of the road
REAL, DIMENSION(:), INTENT(IN) :: PTAU       ! tau scheme weight of the canyon path (-)
REAL, DIMENSION(SIZE(PTA)) :: ZPAC_RD        ! road conductance, tau-aggregated
REAL, DIMENSION(SIZE(PTA)) :: ZPAC_RD_WAT    ! road water conductance, tau-aggregated
REAL, DIMENSION(SIZE(PTA)) :: ZT_REF         ! reference air temperature of the road fluxes [K]
REAL, DIMENSION(SIZE(PTA)) :: ZQ_REF         ! reference air humidity of the road fluxes [kg kg-1]
INTEGER                    :: JJ             ! loop index (tau scheme)
!
REAL, DIMENSION(SIZE(PTA)) :: ZAC_BLD        ! surface conductance inside the building itself in DEF building model
REAL, DIMENSION(SIZE(PTA)) :: ZTA            ! air temperature extrapolated at roof level
REAL, DIMENSION(SIZE(PTA)) :: ZQA            ! air humidity extrapolated at roof level
!
REAL, DIMENSION(SIZE(PTA)) :: ZDQS_RD      ! heat storage inside road
REAL, DIMENSION(SIZE(PTA)) :: ZDQS_RF      ! heat storage inside roof
REAL, DIMENSION(SIZE(PTA)) :: ZDQS_WL_A    ! heat storage inside wall
REAL, DIMENSION(SIZE(PTA)) :: ZDQS_WL_B    ! heat storage inside wall
REAL, DIMENSION(SIZE(PTA)) :: ZFLX_BLD_RF  !heat flux from inside through roof
REAL, DIMENSION(SIZE(PTA)) :: ZFLX_BLD_WL_A!heat flux from inside through wall
REAL, DIMENSION(SIZE(PTA)) :: ZFLX_BLD_WL_B!heat flux from inside through wall
REAL, DIMENSION(SIZE(PTA)) :: ZFLX_BLD_FL !heat flux from inside through floor
REAL, DIMENSION(SIZE(PTA)) :: ZFLX_BLD_MA  !heat flux from inside through mass
!
REAL, DIMENSION(SIZE(PTA)) :: ZDQS_SN_RF ! heat storage inside roof snowpack
REAL, DIMENSION(SIZE(PTA)) :: ZDQS_SN_RD ! heat storage inside road snowpack

!
! coefficients for LW computations over snow (from previous time-step)
!
REAL, DIMENSION(SIZE(PTA)) :: ZTSSN_RD ! road snow temperature
!                                          ! at previous time-step
! new local variables after BEM
!
REAL, DIMENSION(SIZE(PTA)) :: ZIMB_RF      ! residual energy imbalance
                                             ! of the roof for
                                             ! verification
REAL, DIMENSION(SIZE(PTA)) :: ZIMB_RD      ! road residual energy imbalance 
                                             ! for verification [W m-2]
REAL, DIMENSION(SIZE(PTA)) :: ZIMB_WL      ! wall residual energy imbalance 
                                             ! for verification [W m-2]
REAL, DIMENSION(SIZE(PTA)) :: ZTS_RD       ! road surface temperature 
!                                            ! at previous time-step
REAL, DIMENSION(SIZE(PTA)) :: ZTS_WL_A     ! wall A surface temperature 
!                                            ! at previous time-step
REAL, DIMENSION(SIZE(PTA)) :: ZTS_WL_B     ! wall B surface temperature 
!                                            ! at previous time-step
REAL, DIMENSION(SIZE(PTA)) :: ZTS_WL       ! averaged wall surface temperature 
!                                            ! at previous time-step
REAL, DIMENSION(SIZE(PTA)) :: ZTS_RF       ! roof surface temperature 
!                                            ! at previous time-step
REAL, DIMENSION(SIZE(PTA),SIZE(T%XT_WALL_A,2)) :: ZT_WL ! averaged wall surface temperature 
!
INTEGER :: IWL, IRF                      ! number of wall, roof layer
REAL, DIMENSION(SIZE(PTA)) :: ZRADHT_IN     ! Indoor radiant heat transfer coefficient
                                                    ! [W K-1 m-2]
REAL, DIMENSION(SIZE(PTA)) :: ZTS_FL       ! floor surface temperature [K]
REAL, DIMENSION(SIZE(PTA)) :: ZRAD_RF_WL  ! rad. flux from roof to averaged wall [W m-2(roof)]
REAL, DIMENSION(SIZE(PTA)) :: ZRAD_RF_WIN   ! rad. flux from roof to window [W m-2(roof)]
REAL, DIMENSION(SIZE(PTA)) :: ZRAD_RF_FL ! rad. flux from roof to floor [W m-2(roof)]
REAL, DIMENSION(SIZE(PTA)) :: ZRAD_RF_MA  ! rad. flux from roof to mass [W m-2(roof)]
REAL, DIMENSION(SIZE(PTA)) :: ZCONV_RF_BLD  ! rad. flux from roof to bld [W m-2(roof)]
REAL, DIMENSION(SIZE(PTA)) :: ZRAD_WL_FL ! rad. flux from averaged wall to floor [W m-2(wall)]
REAL, DIMENSION(SIZE(PTA)) :: ZRAD_WL_MA  ! rad. flux from averaged wall to mass [W m-2(wall)]
REAL, DIMENSION(SIZE(PTA)) :: ZRAD_WIN_FL  ! rad. flux from averaged wall to floor [W m-2(win)]
REAL, DIMENSION(SIZE(PTA)) :: ZRAD_WIN_MA   ! rad. flux from averaged wall to mass [W m-2(win)]
REAL, DIMENSION(SIZE(PTA)) :: ZCONV_WL_BLD  ! rad. flux from roof to bld [W m-2(wall)]
REAL, DIMENSION(SIZE(PTA)) :: ZCONV_WIN_BLD   ! rad. flux from roof to bld [W m-2(win)]
REAL, DIMENSION(SIZE(PTA)) :: ZAC_WIN         ! window aerodynamic conductance
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!* diagnostic exchange coefficients between the road/garden surfaces and the air
!* of the canyon (_CAN) or of the forcing level (_ATM), computed in URBAN_DRAG
!* (see there section 8.3); full set of URBAN_EXCH_COEF outputs
!
REAL, DIMENSION(:), INTENT(OUT) :: PCD_ROAD_CAN    ! road   drag coefficient (canyon)
REAL, DIMENSION(:), INTENT(OUT) :: PCDN_ROAD_CAN   ! road   neutral drag coefficient (canyon)
REAL, DIMENSION(:), INTENT(OUT) :: PRI_ROAD_CAN    ! road   Richardson number (canyon)
REAL, DIMENSION(:), INTENT(OUT) :: ZZ0H_ROAD_CAN   ! road   roughness length for heat (canyon)
REAL, DIMENSION(:), INTENT(OUT) :: PAC_ROAD_ATM    ! road   aerodynamical conductance (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PCH_ROAD_ATM    ! road   drag coefficient for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PCD_ROAD_ATM    ! road   drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PCDN_ROAD_ATM   ! road   neutral drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PRI_ROAD_ATM    ! road   Richardson number (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: ZZ0H_ROAD_ATM   ! road   roughness length for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PCDN_GARDEN_CAN ! garden neutral drag coefficient (canyon)
REAL, DIMENSION(:), INTENT(OUT) :: PRI_GARDEN_CAN  ! garden Richardson number (canyon)
REAL, DIMENSION(:), INTENT(OUT) :: ZZ0H_GARDEN_CAN ! garden roughness length for heat (canyon)
REAL, DIMENSION(:), INTENT(OUT) :: PAC_GARDEN_ATM  ! garden aerodynamical conductance (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PCDN_GARDEN_ATM ! garden neutral drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PRI_GARDEN_ATM  ! garden Richardson number (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: ZZ0H_GARDEN_ATM ! garden roughness length for heat (atm.)
!MV202609 greenroof-to-atm exchange diagnostics
REAL, DIMENSION(:), INTENT(OUT) :: PAC_GREENROOF_ATM  ! greenroof aerodynamical conductance (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PCD_GREENROOF_ATM  ! greenroof drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PCDN_GREENROOF_ATM ! greenroof neutral drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PCH_GREENROOF_ATM  ! greenroof drag coefficient for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: PRI_GREENROOF_ATM  ! greenroof Richardson number (atm.)
REAL, DIMENSION(:), INTENT(OUT) :: ZZ0H_GREENROOF_ATM ! greenroof roughness length for heat (atm.)

REAL, DIMENSION(SIZE(PTA)) :: ZLOAD_IN_RF   ! indoor load on roof W/m2[roof]
REAL, DIMENSION(SIZE(PTA)) :: ZLOAD_IN_FL   ! indoor load on floor W/m2[floor]
REAL, DIMENSION(SIZE(PTA)) :: ZLOAD_IN_WL   ! indoor load on wall W/m2[wall]
REAL, DIMENSION(SIZE(PTA)) :: ZLOAD_IN_WIN   ! indoor load on win W/m2[win]
REAL, DIMENSION(SIZE(PTA)) :: ZLOAD_IN_MA   ! indoor load on mass W/m2[mass]
!
REAL(KIND=JPRB) :: ZHOOK_HANDLE                                             
!-------------------------------------------------------------------------------
!

   
IF (LHOOK) CALL DR_HOOK('TEB',0,ZHOOK_HANDLE)
!
!*      1.     Initializations
!              ---------------
!
!*      1.1    Water reservoirs
!              ----------------
!
ZWS_RF_MAX =  1. ! (1mm) maximum deepness of roof water reservoir
ZWS_RD_MAX =  1. ! (1mm) maximum deepness of road water reservoir



!
!*      1.2    radiative snow variables at previous time-step
!              ----------------------------------------------
!
ZTSSN_RD(:) = T%TSNOW_ROAD%TS(:)



!
!
!*      1.3    indoor aerodynamique conductance for DEF case
!              ----------------------------------------------
!
ZAC_BLD(:) = XUNDEF
IF (TOP%CBEM=='DEF') ZAC_BLD=1. / 0.123 / (XCPD * PRHOA(:)) !* (normalized by rho Cp for convenience)
!-------------------------------------------------------------------------------
!
!*      1.3    number of roof/wall layer
!              -------------------------
!
IWL = SIZE(T%XT_WALL_A,2)
IRF = SIZE(T%XT_ROOF,2)
!
ZTS_WL_A  (:)=T%XT_WALL_A   (:,1)
ZTS_WL_B  (:)=T%XT_WALL_B   (:,1)
ZTS_WL    (:)=0.5 * (ZTS_WL_A(:)+ZTS_WL_B(:))
ZTS_RD    (:)=T%XT_ROAD     (:,1)
ZTS_RF    (:)=T%XT_ROOF     (:,1)



!
!
!*      1.4    load on indoor walls
!              -------------------------
!
IF (TOP%CBEM=='BEM') THEN
  !
  ZLOAD_IN_RF = B%XF_FLOOR_WIN * DMT%XTR_SW_WIN + DMT%XQIN * B%XN_FLOOR * (1-B%XQIN_FLAT) * B%XQIN_FRAD  &
           / (2 + T%XWALL_O_BLD + B%XGLAZ_O_BLD + B%XMASS_O_BLD ) ! W/m2 [ROOF]
  ZLOAD_IN_FL = B%XF_FLOOR_WIN * DMT%XTR_SW_WIN + DMT%XQIN * B%XN_FLOOR * (1-B%XQIN_FLAT) * B%XQIN_FRAD  &
           / (2 + T%XWALL_O_BLD + B%XGLAZ_O_BLD + B%XMASS_O_BLD )
  ZLOAD_IN_MA = B%XF_MASS_WIN * DMT%XTR_SW_WIN + DMT%XQIN * B%XN_FLOOR * (1-B%XQIN_FLAT) * B%XQIN_FRAD  &
           / (2 + T%XWALL_O_BLD + B%XGLAZ_O_BLD + B%XMASS_O_BLD )
  ZLOAD_IN_WL = B%XF_WALL_WIN * DMT%XTR_SW_WIN + DMT%XQIN * B%XN_FLOOR * (1-B%XQIN_FLAT) * B%XQIN_FRAD  &
           / (2 + T%XWALL_O_BLD + B%XGLAZ_O_BLD + B%XMASS_O_BLD )
  ZLOAD_IN_WIN = B%XF_WIN_WIN * DMT%XTR_SW_WIN + DMT%XQIN * B%XN_FLOOR * (1-B%XQIN_FLAT) * B%XQIN_FRAD  &
           / (2 + T%XWALL_O_BLD + B%XGLAZ_O_BLD + B%XMASS_O_BLD )
ELSE
  ZLOAD_IN_RF = 0.
  ZLOAD_IN_FL = 0.
  ZLOAD_IN_MA = 0.
  ZLOAD_IN_WL = 0.
  ZLOAD_IN_WIN = 0.
ENDIF


!-------------------------------------------------------------------------------
!
!*      2.     Snow-covered surfaces relative effects
!              --------------------------------------
!
!*      2.1    Effects on water reservoirs
!              ---------------------------
!
ZWS_RF_MAX(:) = ZWS_RF_MAX(:) * PDF_RF(:)
ZWS_RD_MAX(:) = ZWS_RD_MAX(:) * PDF_RD(:)


!
!-------------------------------------------------------------------------------
!
!*      3.     Surface drag
!              ------------
!
 CALL URBAN_DRAG(icell, iblock, TOP, T, B, HIMPLICIT_WIND, PTSTEP, PTIME, PT_CANYON, PQ_CANYON, &
                 PU_CANYON, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN, PZ_LOWCAN, &
                 ZTS_RF, ZTS_RD, ZTS_WL, PTS_GARDEN, PQS_GARDEN, PDN_RF, PDN_RD, PTAU,    &
                 PEXNS, PEXNA, PTA, PQA, PPS, PRHOA, PZREF, PUREF,      &
                 PVMOD, ZWS_RF_MAX, ZWS_RD_MAX, PPEW_A_COEF,            &
                 PPEW_B_COEF, PPEW_A_COEF_LOWCAN, PPEW_B_COEF_LOWCAN, PZ0_GARDEN_EXT, PZ0_GR_EXT, &   
				 PTSRAD_GR, PRUNOFF_GR,&
                 PQSAT_RF, PQSAT_RD, PDELT_RF, PDELT_RD, PCD, PCDN,     &
                 PAC_RF, PAC_RF_WAT, PAC_WL, PAC_RD, PAC_RD_WAT,        &
                 PAC_TOP, PAC_GARDEN, PRI_TWN, PUW_RD, PUW_RF,          &
                 PDUWDU_RD, PDUWDU_RF, PUSTAR_TWN, ZAC_WIN, PCH_GARDEN, &
			     PCD_GARDEN, PCH_ROAD, PCH_ROOF, PCH_WALL, PCH_TOP,     &
                 ILMO_ROAD, ILMO_ROOF, ILMO_TOP, PCD_GARDEN_ATM, PCH_GARDEN_ATM,                      &
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
                  PCD_ROAD_CAN, PCDN_ROAD_CAN, PRI_ROAD_CAN, ZZ0H_ROAD_CAN,              &
                  PAC_ROAD_ATM, PCH_ROAD_ATM, PCD_ROAD_ATM, PCDN_ROAD_ATM,               &
                  PRI_ROAD_ATM, ZZ0H_ROAD_ATM, PCDN_GARDEN_CAN, PRI_GARDEN_CAN,          &
                  ZZ0H_GARDEN_CAN, PAC_GARDEN_ATM, PCDN_GARDEN_ATM, PRI_GARDEN_ATM,      &
                  ZZ0H_GARDEN_ATM,                                                       &
                  ZAC_RD_ATM_WAT,                                                        &
!MV202609 greenroof-to-atm exchange diagnostics
                  PAC_GREENROOF_ATM, PCD_GREENROOF_ATM, PCDN_GREENROOF_ATM, PCH_GREENROOF_ATM, &
                  PRI_GREENROOF_ATM, ZZ0H_GREENROOF_ATM )
!MV202609 tau scheme of the road (revision: puddle diagnostics)
!* road -> forcing level water-limited conductance (diagnostic; also used by the
!* tau aggregation and by the reference humidity ZQ_REF of the road budget)
PAC_ROAD_ATM_WAT(:) = ZAC_RD_ATM_WAT(:)
!IF (icell == 5 .AND. iblock == 2532) THEN
!	print*, 'after urban_drag PCH_GARDEN = ', PCH_GARDEN
!    print*, 'after urban_drag PCD_GARDEN = ', PCD_GARDEN
!    print*, 'after urban_drag PAC_GARDEN = ', PAC_GARDEN
!
!	print*, 'after urban_drag PCH_GARDEN = ', PCH_GARDEN
!    print*, 'after urban_drag PCD_GARDEN = ', PCD_GARDEN
!    print*, 'after urban_drag PAC_RD = ', PAC_RD
!ENDIF

!
!* area-averaged heat transfer coefficient
!
ZVMOD(:) = WIND_THRESHOLD(PVMOD(:),PUREF(:))
!
PCH_TWN(:) = (T%XBLD(:) * PAC_RF(:) + (1.-T%XBLD(:)) * PAC_TOP (:)) / ZVMOD(:)
!
!* aggregation of momentum fluxes for roofs (=> derivate of flux also recalculated)
!
PUW_RF (:) = (1-T%XGREENROOF(:)) * PUW_RF(:) + T%XGREENROOF(:) * PUW_GR(:)
WHERE (PVMOD(:)/=0.) PDUWDU_RF(:) = 2. * PUW_RF(:) / PVMOD(:)


!
!-------------------------------------------------------------------------------
!
!*      4.     Extrapolation of atmospheric T and q at roof level (for fluxes computation)
!              --------------------------------------------------
!
! difference compared to surfex v8.1 official code: bug correction
!ZTA(:) = PTA(:) * PEXNS(:) / PEXNA(:)
!ZQA(:) = PQA(:) * QSAT(PTA(:),PPS(:)) / QSAT(ZTA(:),PPA(:))
!
ZTA(:) = PTA(:) * PEXNS(:) / PEXNA(:)
!ZTA(:) = PTA(:)
ZQA(:) = PQA(:) * QSAT(ZTA(:),PPS(:)) / QSAT(PTA(:),PPA(:))


!
!-------------------------------------------------------------------------------
!
!*      5.     Snow mantel model
!              -----------------
!
 CALL URBAN_SNOW_EVOL(T, B, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN, ZTS_RF, ZTS_RD, ZTS_WL_A,    &
                      ZTS_WL_B, PPS, ZTA, ZQA, PRHOA, PLW_RAD, PSR, PZREF, PUREF, PVMOD,  &
                      PTSTEP,  PZ_LOWCAN, PDN_RF, DMT%XABS_SW_SNOW_ROOF,                 &
                      DMT%XABS_LW_SNOW_ROOF, PDN_RD, DMT%XABS_SW_SNOW_ROAD,             &
                      DMT%XABS_LW_SNOW_ROAD, PRNSN_RF, PHSN_RF, PLESN_RF, PGSN_RF,       &
                      PMELT_RF, PRNSN_RD, PHSN_RD, PLESN_RD, PGSN_RD, PMELT_RD,           &
                      PLW_WA_TO_NR, PLW_WB_TO_NR, PLW_S_TO_NR, PLW_WIN_TO_NR, ZDQS_SN_RF, &
                      ZDQS_SN_RD, PSNOWD_RF, PSNOWD_RD, PTAU,                           &
!MV202609 tau scheme of the road (revision: snow-to-atmosphere branch)
                      PHSN_RD_CAN, PHSN_RD_ATM, PLESN_RD_CAN, PLESN_RD_ATM      )
					  

!
!-------------------------------------------------------------------------------
!
!*      6.    LW properties
!              -------------
!
PDF_RD (:) = 1. - PDN_RD (:)



!
!-------------------------------------------------------------------------------
!
!*      7.    Indoor radiative temperature
!              ---------------------------
!
! uses the averaged temperature of both walls for the building energy balance
ZT_WL   (:,:)=0.5 * (T%XT_WALL_A(:,:)+T%XT_WALL_B(:,:))
!
SELECT CASE(TOP%CBEM)
   CASE("DEF")
      ZTS_FL(:) = 19. + XTT
	  PT_RAD_IND(:) = ( T%XWALL_O_HOR(:) / T%XBLD(:) * ZT_WL(:,IWL) + &
                  T%XT_ROOF(:,IRF) + ZTS_FL(:) ) / (T%XWALL_O_HOR(:) / T%XBLD(:) + 1. + 1.) 
      ZRADHT_IN(:) = XUNDEF
   CASE("BEM")
      ZTS_FL(:) = B%XT_FLOOR(:,1)
      PT_RAD_IND(:)  = (B%XT_MASS(:,1)*B%XMASS_O_BLD(:) + ZT_WL(:,IWL)*T%XWALL_O_BLD(:)     &
                   + ZTS_FL(:) + T%XT_ROOF(:,IRF) + B%XT_WIN2(:) * B%XGLAZ_O_BLD(:)) &
                   /(B%XMASS_O_BLD(:) + T%XWALL_O_BLD(:) + 1. + 1. + B%XGLAZ_O_BLD(:))
      !             Assuming indoor surface emissivities of 0.9
      ZRADHT_IN(:)   = 0.9 * 0.9 * 4 * XSTEFAN * PT_RAD_IND(:)**3          
END SELECT



!
!
!*      7.    Roof Ts computation
!              -------------------
!
!* ts_roof and qsat_roof are updated
!
 
 CALL ROOF_LAYER_E_BUDGET(TOP, T, B, PQSAT_RF, ZAC_BLD, PTSTEP, PDN_RF, PRHOA,    &
                          PAC_RF, PAC_RF_WAT, PLW_RAD, PPS, PDELT_RF, ZTA, ZQA,   &
                          PEXNA, PEXNS, DMT%XABS_SW_ROOF, PGSN_RF,  ZFLX_BLD_RF, &
                          ZDQS_RF, DMT%XABS_LW_ROOF, DMT%XH_ROOF, PLEW_RF, ZIMB_RF, &
                          DMT%XG_GREENROOF_ROOF, ZRADHT_IN, ZTS_FL, ZT_WL(:,IWL),&
                          ZRAD_RF_WL, ZRAD_RF_WIN, ZRAD_RF_FL, ZRAD_RF_MA, ZCONV_RF_BLD, &
                          PRR, & !modif to add heating/cooling of rain
                          ZLOAD_IN_RF )

!
!-------------------------------------------------------------------------------
!
!*      8.    Road Ts computations
!              -----------------------------
!
!* Road watering

 CALL TEB_IRRIG(TIR%LPAR_RD_IRRIG, PTSTEP, TOP%TTIME%TDATE%MONTH, PTSUN,   &
               TIR%XRD_START_MONTH, TIR%XRD_END_MONTH, TIR%XRD_START_HOUR, &
               TIR%XRD_END_HOUR, TIR%XRD_24H_IRRIG, DMT%XIRRIG_ROAD      )
			   


!MV202609 tau scheme of the road
!* effective conductance and reference air of the road energy budget: when the
!* tau scheme is activated the road budget is fed with the tau-weighted mean of
!* the road/canyon and road/forcing-level exchanges (this is exact, the flux
!* being linear in the conductance at a given surface temperature); with the
!* scheme disabled the effective values are the canyon ones, so that the former
!* behaviour is reproduced exactly.
!
ZPAC_RD(:)     = PAC_RD(:)
ZPAC_RD_WAT(:) = PAC_RD_WAT(:)
ZT_REF(:)      = PT_LOWCAN(:)
ZQ_REF(:)      = PQ_LOWCAN(:)
IF (TOP%LTAU_SCHEME) THEN
  ZPAC_RD(:)     = PTAU(:) * PAC_RD(:)     + (1.-PTAU(:)) * PAC_ROAD_ATM(:)
  ZPAC_RD_WAT(:) = PTAU(:) * PAC_RD_WAT(:) + (1.-PTAU(:)) * ZAC_RD_ATM_WAT(:)
  !* the effective reference air is only needed where the effective conductance
  !* does not vanish (a dry road has a zero water conductance and the
  !* corresponding latent flux vanishes whatever the reference humidity)
  DO JJ = 1, SIZE(PTA)
    IF (ZPAC_RD(JJ) > 0.) THEN
      ZT_REF(JJ) = ( PTAU(JJ) * PAC_RD(JJ) * PT_LOWCAN(JJ)                     &
                     + (1.-PTAU(JJ)) * PAC_ROAD_ATM(JJ) * PTA(JJ) ) / ZPAC_RD(JJ)
    ELSE
      ZT_REF(JJ) = PT_LOWCAN(JJ)
    ENDIF
    IF (ZPAC_RD_WAT(JJ) > 0.) THEN
      ZQ_REF(JJ) = ( PTAU(JJ) * PAC_RD_WAT(JJ) * PQ_LOWCAN(JJ)                 &
                     + (1.-PTAU(JJ)) * ZAC_RD_ATM_WAT(JJ) * PQA(JJ) ) / ZPAC_RD_WAT(JJ)
    ELSE
      ZQ_REF(JJ) = PQ_LOWCAN(JJ)
    ENDIF
  ENDDO
ENDIF
!
!* ts_road, ts_wall, qsat_road, t_canyon and q_canyon are updated
!
 CALL ROAD_LAYER_E_BUDGET(T, B, PTSTEP, PDN_RD, PRHOA, ZPAC_RD, ZPAC_RD_WAT, &
                          PLW_RAD, PPS, PQSAT_RD, PDELT_RD, PEXNS,         &
                          DMT%XABS_SW_ROAD, PGSN_RD, ZQ_REF, ZT_REF,       &
                          ZTS_WL_A, ZTS_WL_B, ZTSSN_RD,  PTS_GARDEN,       &
                          PLW_WA_TO_R, PLW_WB_TO_R, PLW_S_TO_R,            &
                          PLW_WIN_TO_R, PEMIT_LW_RD, ZDQS_RD, DMT%XABS_LW_ROAD,  &
                          DMT%XH_ROAD, PLEW_RD, ZIMB_RD, PRR+DMT%XIRRIG_ROAD    )
!
!MV202609 tau scheme of the road
!* actual road fluxes: sensible and latent heat fluxes used by the road energy
!* budget (i.e. the tau-aggregated fluxes when the tau scheme is activated)
PH_ROAD(:)  = DMT%XH_ROAD(:)
PLE_ROAD(:) = PLEW_RD(:)
!MV202609 fixes of the road puddle water normalization (PLEW_RD is tile-mean, no double PDF_RD weight)
!* liquid and snow contributions to the road latent heat flux, per m2 of road:
!* the road energy budget computes PLEW_RD already as a tile-mean quantity (the
!* snow-free fraction 1-PDN_RD is inside ZRHO_ACF_R_WAT of the budget), so the
!* liquid part LE_ROAD_WAT = PLEW_RD coincides with the CSV column LE_ROAD;
!* LE_ROAD_SNOW is the tile-mean snow part; LE_ROAD_WAT + LE_ROAD_SNOW is the
!* tile-mean total latent heat flux of the road (DMT%XLE_ROAD).
LE_ROAD_WAT (:) = PLEW_RD(:)
LE_ROAD_SNOW(:) = PDN_RD(:) * PLESN_RD(:)
!
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
!* roof decomposition, with the same convention as the road one: PLEW_RF and
!* PLESN_RF are given per m2 of snow-free roof and per m2 of snow (see
!* ROOF_LAYER_E_BUDGET and URBAN_SNOW_EVOL), so the tile-mean values use
!* (1-PDN_RF) = PDF_RF and PDN_RF. LE_ROOF_WAT is the liquid water flux that
!* drains the roof puddle (the flux passed to URBAN_HYDRO below) and
!* LE_ROOF_SNOW the tile-mean snow part; their sum is the structural roof
!* latent heat flux per m2 of roof (the liquid+snow parts of DMT%XLE_STRLROOF,
!* the greenroof and the building waste heat being excluded, see URBAN_FLUXES).
LE_ROOF_WAT (:) = ( 1. - PDN_RF(:) ) * PLEW_RF(:)
LE_ROOF_SNOW(:) =        PDN_RF(:)   * PLESN_RF(:)
!
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!* potential component fluxes of the road: same quantity as if the whole exchange
!* occurred with the canyon air (tau = 1) or directly with the air of the forcing
!* level (tau = 0), computed from the surface temperature resulting from the road
!* energy-budget solve (T%XT_ROAD(:,1), which is also the surface temperature used
!* by the road/canyon fluxes, the scheme being fully implicit). Same formula, same
!* water limitation and same cp/Exns convention as PHFREE_ROAD/PLEFREE_ROAD, only
!* the reference air - and hence its conductance - is changed. Diagnostics only:
!* they do not feed back on the road energy budget.
!
ZDF_RD(:)       = 1. - PDN_RD(:)
PH_ROAD_CAN(:)  = PRHOA(:) * PAC_RD(:)         * ZDF_RD(:) * XCPD/PEXNS(:)  &
                  * (T%XT_ROAD(:,1) - PT_LOWCAN(:))
PLE_ROAD_CAN(:) = PRHOA(:) * PAC_RD_WAT(:)     * ZDF_RD(:) * XLVTT         &
                  * PDELT_RD(:) * (PQSAT_RD(:) - PQ_LOWCAN(:))
PH_ROAD_ATM(:)  = PRHOA(:) * PAC_ROAD_ATM(:)   * ZDF_RD(:) * XCPD/PEXNS(:)  &
                  * (T%XT_ROAD(:,1) - PTA(:))
PLE_ROAD_ATM(:) = PRHOA(:) * ZAC_RD_ATM_WAT(:) * ZDF_RD(:) * XLVTT         &
                  * PDELT_RD(:) * (PQSAT_RD(:) - PQA(:))
						  

!

!-------------------------------------------------------------------------------
!
!*      8.     Wall Ts computations
!              -----------------------------
!
 CALL FACADE_E_BUDGET(TOP, T, B, DMT, PTSTEP, PDN_RD, PRHOA, PAC_WL, ZAC_BLD,   &
                      PLW_RAD, PPS, PEXNS, PT_CANYON, ZTS_RD, ZTSSN_RD, PTS_GARDEN, &
                      ZTS_FL, PLW_WA_TO_WB, PLW_R_TO_WA, PLW_R_TO_WB,      &
                      PLW_G_TO_WA, PLW_G_TO_WB, PLW_S_TO_WA, PLW_S_TO_WB,  &
                      PLW_NR_TO_WA, PLW_NR_TO_WB, PLW_WIN_TO_WA,           &
                      PLW_WIN_TO_WB, PLW_S_TO_WIN, PLW_WA_TO_WIN,          &
                      PLW_WB_TO_WIN, PLW_R_TO_WIN, PLW_G_TO_WIN,           &
                      PLW_NR_TO_WIN, ZFLX_BLD_WL_A, ZDQS_WL_A,             &
                      ZFLX_BLD_WL_B, ZDQS_WL_B, PEMIT_LW_FAC, ZIMB_WL,     &
                      ZRADHT_IN, ZRAD_RF_WL, ZRAD_RF_WIN, ZRAD_WL_FL,      &
                      ZRAD_WL_MA, ZRAD_WIN_FL, ZRAD_WIN_MA, ZCONV_WL_BLD,  &
                      ZCONV_WIN_BLD, ZAC_WIN, ZLOAD_IN_WL, ZLOAD_IN_WIN   )
					  

!
!-------------------------------------------------------------------------------
!
!*      9.     Evolution of interior building air temperature
!              ----------------------------------------------
!
! uses the averaged temperature of both walls for the building energy balance
ZT_WL   (:,:)=0.5 * (T%XT_WALL_A(:,:)+T%XT_WALL_B(:,:))
!
SELECT CASE(TOP%CBEM)
CASE("DEF")
!
   CALL BLD_E_BUDGET(.TRUE., PTSTEP, T%XBLD, T%XWALL_O_HOR,        &
                     PRHOA, T%XT_ROOF, ZT_WL, B%XTI_BLD, ZTS_FL(:) )

   !variables that needs to be computed apart
   B%XQI_BLD = 0.5 * QSAT(B%XTI_BLD, PPS)
   !variables that need to be set 0 for calculation
   ZFLX_BLD_FL(:) = 0.
   ZFLX_BLD_MA (:) = 0.
   !other variables
   PHU_BLD(:)     = XUNDEF
!MV202609 waste heat diagnostics: the waste heat of the buildings is produced by
!* the BEM only; the simple building budget ('DEF') has no HVAC system, so the
!* two diagnostics are zero. They must be defined anyway: they are written to the
!* output and, in the BEM configuration, they feed the canyon air and the town
!* fluxes (see AVG_URBAN_FLUXES).
   DMT%XH_WASTE (:) = 0.
   DMT%XLE_WASTE(:) = 0.

CASE("BEM")
  CALL BEM(icell, iblock, BOP, T, B, DMT, PTSTEP, PBEM_AC, PTSUN, KDAY, PPS, PRHOA, PT_CANYON, &
           PQ_CANYON, PU_CANYON, PHU_BLD, PT_RAD_IND, ZFLX_BLD_FL,&
           ZFLX_BLD_MA, ZRADHT_IN, ZRAD_RF_MA, ZRAD_RF_FL,        &
           ZRAD_WL_MA, ZRAD_WL_FL, ZRAD_WIN_MA, ZRAD_WIN_FL,      &
           ZCONV_RF_BLD, ZCONV_WL_BLD, ZCONV_WIN_BLD, ZLOAD_IN_FL,&
           ZLOAD_IN_MA                                 )

   DMT%XH_WASTE  = DMT%XH_WASTE  * T%XBLD
   DMT%XLE_WASTE = DMT%XLE_WASTE * T%XBLD
END SELECT


!
!-------------------------------------------------------------------------------
!
!*      10.    Fluxes over built surfaces
!              --------------------------
!
 CALL URBAN_FLUXES   (TOP, T, B, DMT, HIMPLICIT_WIND, PT_CANYON, PPEW_A_COEF, PPEW_B_COEF,      &
                      PEXNS, PRHOA, PVMOD, PH_TRAFFIC, PLE_TRAFFIC,PAC_WL, PCD, PDF_RF,         &
                      PDN_RF, PDF_RD, PDN_RD, PRNSN_RF, PHSN_RF, PLESN_RF, PGSN_RF,             &
                      PRNSN_RD, PHSN_RD, PLESN_RD, PGSN_RD, PMELT_RF, ZDQS_RF, PMELT_RD,        &
                      ZDQS_RD, ZDQS_WL_A, ZDQS_WL_B, ZFLX_BLD_RF, ZFLX_BLD_WL_A,                &
                      ZFLX_BLD_WL_B, ZFLX_BLD_FL, ZFLX_BLD_MA, PE_SHADING, PLEW_RF,             &
                      PRN_GR, PH_GR, PLE_GR, PGFLUX_GR,                                         &
                      PLEW_RD, PLE_WL_A, PLE_WL_B, PMELT_BLT, PUSTAR_TWN                        )
!
!
! Water transfer from snow reservoir to water reservoir in case of snow melt
!
!MV202609 fixes of the snow melt / roof puddle water path (melt injection)
!* PMELT_RF / PMELT_RD are computed by URBAN_SNOW_EVOL for each m2 of SNOW
!* ("All computations are then done only for each m2 of snow, and not for each
!* m2 of roof/road": the snowpack is divided by PDN_* before the call and
!* multiplied back afterwards, see URBAN_SNOW_EVOL), so the melt water that
!* reaches the roof/road reservoirs is PDN_RF*PMELT_RF / PDN_RD*PMELT_RD per m2
!* of roof/road, exactly like the tile-mean snow latent flux PDN_*PLESN_*.
!* Without the PDN_* weight the reservoirs receive 1/PDN_* times the real melt
!* (a spurious water source, maximal for a patchy snowpack: with PDN = 0.7 the
!* melt water injected is 43% too large).
!* The MIN() with the reservoir capacity is also removed here: URBAN_HYDRO
!* (called just below) applies the capacity and turns the excess into runoff,
!* while capping the reservoir here silently DESTROYS the melt water that does
!* not fit in the roof/road puddle (a water leak of the same order as the melt
!* itself during the melt season, ZWS_*_MAX being only 1 mm * (1-PDN_*)).
WHERE (PMELT_RF(:) .GT. 0.)
  T%XWS_ROOF(:) = T%XWS_ROOF(:) + PDN_RF(:) * PMELT_RF(:) * PTSTEP
ENDWHERE
!
WHERE (PMELT_RD(:) .GT. 0.)
  T%XWS_ROAD(:) = T%XWS_ROAD(:) + PDN_RD(:) * PMELT_RD(:) * PTSTEP
ENDWHERE

!
!-------------------------------------------------------------------------------
!
!*      11.    Roof ans road reservoirs evolution
!              ----------------------------------
!
!MV202609 fixes of the road puddle water normalization (PLEW_RD is tile-mean, no double PDF_RD weight)
!* the road water reservoir is drained by the liquid latent heat flux of the
!* snow-free road, PLEW_RD: this flux is computed by the road energy budget as a
!* tile-mean quantity (per m2 of road), i.e. it already contains the snow-free
!* fraction factor (1-PDN_RD) via ZRHO_ACF_R_WAT inside the budget, so no
!* additional weight must be applied here. The sublimation/deposition of the
!* road snow is already accounted in the road snowpack (WSNOW_RD): feeding it
!* once more into the puddle would double-count it. The liquid fraction uses
!* XLVTT (the snow one XLSTT, see the snow scheme)
!MV202609 fixes of the snow melt / roof puddle water path (roof reservoir drain)
!* the roof reservoir is drained by the liquid latent heat flux of the snow-free
!* STRUCTURAL roof per m2 of roof, LE_ROOF_WAT = (1-PDN_RF)*PLEW_RF (the same
!* quantity as the liquid part of DMT%XLE_STRLROOF, and the same convention as
!* the road one: PLEW_RF is given per m2 of snow-free roof only). The roof
!* puddle must NOT be drained by DMT%XLE_ROOF (used before this revision):
!*  - with the greenroof, DMT%XLE_ROOF contains PLE_GR (the greenroof
!*    transpiration is fed by the garden/BEM water, not by the roof puddle),
!*  - with BEM it contains the building latent waste heat LE_WASTE/XBLD (vapour
!*    produced by the HVAC system, not water from the roof puddle),
!*  - in all cases it contains the roof snow sublimation PDN_RF*PLESN_RF, which
!*    is already taken from the roof snowpack by the snow scheme (WSNOW_RF):
!*    draining the puddle with it evaporates the roof puddle water a second time
!*    (and with XLVTT instead of the XLSTT used by the snow scheme).
 CALL URBAN_HYDRO(ZWS_RF_MAX, ZWS_RD_MAX, T%XWS_ROOF, T%XWS_ROAD, PRR,          &
                  DMT%XIRRIG_ROAD, PTSTEP, T%XBLD, LE_ROOF_WAT(:),              &
                  PLEW_RD(:),                                                    &
                  DMT%XRUNOFF_STRLROOF, DMT%XRUNOFF_ROAD   )
!
IF (TOP%LGREENROOF) THEN
  DMT%XRUNOFF_ROOF(:) =  (1.-T%XGREENROOF(:)) * DMT%XRUNOFF_STRLROOF(:) &
                        + T%XGREENROOF(:) * (PRUNOFF_GR(:) + PDRAIN_GR(:))
ELSE
  DMT%XRUNOFF_ROOF(:) =  DMT%XRUNOFF_STRLROOF(:)
ENDIF         

                                           
!
!-------------------------------------------------------------------------------
!
!*      19.    Compute aerodynamical resistance 
!              --------------------------------
!
PRESA_TWN(:) = 1. / ( T%XBLD(:) * PAC_RF(:)  + ( 1. - T%XBLD(:)) * PAC_TOP (:))
!



IF (LHOOK) CALL DR_HOOK('TEB',1,ZHOOK_HANDLE)
!-------------------------------------------------------------------------------
!
END SUBROUTINE TEB
