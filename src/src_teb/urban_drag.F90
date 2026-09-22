!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!     #########
    SUBROUTINE URBAN_DRAG(icell, iblock, TOP, T, B, HIMPLICIT_WIND, PTSTEP, PTIME, PT_CANYON, PQ_CANYON, &
                          PU_CANYON, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN, PZ_LOWCAN,   &
                          PTS_ROOF, PTS_ROAD, PTS_WALL, PTS_GARDEN, PQS_GARDEN,    &
                          PDELT_SNOW_ROOF, PDELT_SNOW_ROAD,  PTAU, PEXNS, PEXNA, PTA,    &
                          PQA, PPS, PRHOA,PZREF, PUREF, PVMOD, PWS_ROOF_MAX,       &
                          PWS_ROAD_MAX, PPEW_A_COEF, PPEW_B_COEF,                  &
                          PPEW_A_COEF_LOWCAN, PPEW_B_COEF_LOWCAN, PZ0_GARDEN_EXT,  &
						  PTSRAD_GR, PRUNOFF_GR, PQSAT_ROOF,      &
                          PQSAT_ROAD, PDELT_ROOF, PDELT_ROAD, PCD, PCDN, PAC_ROOF, &
                          PAC_ROOF_WAT, PAC_WALL, PAC_ROAD_CAN, PAC_ROAD_WAT, PAC_TOP, &
                          PAC_GARDEN_CAN, PRI, PUW_ROAD, PUW_ROOF, PDUWDU_ROAD,        &
                          PDUWDU_ROOF, PUSTAR_TOWN, PAC_WIN, PCH_GARDEN_CAN,           &
						  PCD_GARDEN_CAN, PCH_ROAD_CAN, PCH_ROOF, PCH_WALL, PCH_TOP,       &
                          ILMO_ROAD_CAN, ILMO_ROOF, ILMO_TOP, PCD_GARDEN_ATM, PCH_GARDEN_ATM,      &
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
                          PCD_ROAD_CAN, PCDN_ROAD_CAN, PRI_ROAD_CAN, ZZ0H_ROAD_CAN,    &
                          PAC_ROAD_ATM, PCH_ROAD_ATM, PCD_ROAD_ATM, PCDN_ROAD_ATM,    &
                          PRI_ROAD_ATM, ZZ0H_ROAD_ATM, PCDN_GARDEN_CAN, PRI_GARDEN_CAN,&
                          ZZ0H_GARDEN_CAN, PAC_GARDEN_ATM, PCDN_GARDEN_ATM,            &
                          PRI_GARDEN_ATM, ZZ0H_GARDEN_ATM,                              &
                          PAC_ROAD_ATM_WAT	  ) 
!   ##########################################################################
!
!!****  *URBAN_DRAG*  
!!
!!    PURPOSE
!!    -------
!
!     Computes the surface drag over artificial surfaces as towns, 
!     taking into account the canyon like geometry of urbanized areas.
!         
!     
!!**  METHOD
!!    ------
!
!
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
!!      Original    20/01/98 
!!          01/00 (V. Masson)  separation of skimming, wake and isolated flows
!!          09/00 (V. Masson)  use of Z0 for roads
!!          12/02 (A. Lemonsu) convective speed w* in canyon
!             04 (A. Lemonsu) z0h=z0m for resistance canyon-atmosphere
!          03/08 (S. Leroyer) debug PU_CAN (1. * H/3)
!          12/08 (S. Leroyer) option (TOP%CZ0H) for z0h applied on roof, road and town
!!         09/12 B. Decharme new wind implicitation
!          11/11 (G. Pigeon) apply only urban_exch_coef when necessary if
!                            canopy/no canopy
!          09/12 (G. Pigeon) add new formulation for outdoor conv. coef for
!                            wall/roof/window
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!!
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_n, ONLY : TEB_t
USE MODD_BEM_n, ONLY : BEM_t
!
USE MODD_SURF_PAR, ONLY : XUNDEF
USE MODD_CSTS,ONLY : XLVTT, XPI, XCPD, XG, XKARMAN
!
USE MODI_WIND_THRESHOLD
!
!USE MODE_SBLS
USE MODE_THERMOS
USE MODI_URBAN_EXCH_COEF
USE MODE_GARDEN_BALANCE, ONLY : GARDEN_PCD_NEUTRAL, GARDEN_CA_NEUTRAL
!MV202609 garden thermal roughness (z0h)
!* neutral thermal (scalar) coefficient and conductance of the garden: the
!* 'EXT_NEU' coefficients are the ones the internal diagnostic garden uses
USE MODE_GARDEN_BALANCE, ONLY : GARDEN_PCH_NEUTRAL, GARDEN_CAH_NEUTRAL
USE MODE_CONV_DOE
!
USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
USE PARKIND1  ,ONLY : JPRB
!
IMPLICIT NONE
!
!*      0.1    declarations of arguments
!
INTEGER                           :: icell
INTEGER                           :: iblock 

TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: TOP
TYPE(TEB_t), INTENT(INOUT) :: T
TYPE(BEM_t), INTENT(INOUT) :: B
!
  CHARACTER(LEN=*),     INTENT(IN)  :: HIMPLICIT_WIND   ! wind implicitation option
!                                                     ! 'OLD' = direct
!                                                     ! 'NEW' = Taylor serie, order 1
!
REAL,               INTENT(IN)    :: PTSTEP         ! time-step
REAL, INTENT(IN)    :: PTIME          ! current time since midnight (UTC, s)
REAL, DIMENSION(:), INTENT(IN)    :: PT_CANYON      ! canyon air temperature
REAL, DIMENSION(:), INTENT(IN)    :: PQ_CANYON      ! canyon air specific humidity.
REAL, DIMENSION(:), INTENT(IN)    :: PU_CANYON      ! hor. wind in canyon
REAL, DIMENSION(:), INTENT(IN)    :: PU_LOWCAN     ! wind near the road
REAL, DIMENSION(:), INTENT(IN)    :: PT_LOWCAN     ! temp. near the road
REAL, DIMENSION(:), INTENT(IN)    :: PQ_LOWCAN     ! hum. near the road
REAL, DIMENSION(:), INTENT(IN)    :: PZ_LOWCAN     ! height of atm. var. near the road
REAL, DIMENSION(:), INTENT(IN)    :: PTS_ROOF       ! surface temperature
REAL, DIMENSION(:), INTENT(IN)    :: PTS_ROAD       ! surface temperature
REAL, DIMENSION(:), INTENT(IN)    :: PTS_WALL       ! surface temperature
REAL, DIMENSION(:), INTENT(IN)    :: PTS_GARDEN     ! surface temperature
REAL, DIMENSION(:), INTENT(IN)    :: PQS_GARDEN     ! surface humidity
REAL, DIMENSION(:), INTENT(IN)    :: PDELT_SNOW_ROOF! fraction of snow on roof
REAL, DIMENSION(:), INTENT(IN)    :: PDELT_SNOW_ROAD! fraction of snow on road
REAL, DIMENSION(:), INTENT(IN)    :: PTAU           ! tau scheme weight of the canyon path (-)
REAL, DIMENSION(:), INTENT(IN)    :: PEXNS          ! surface exner function
REAL, DIMENSION(:), INTENT(IN)    :: PTA            ! temperature at the lowest level
REAL, DIMENSION(:), INTENT(IN)    :: PQA            ! specific humidity
                                                    ! at the lowest level
REAL, DIMENSION(:), INTENT(IN)    :: PVMOD          ! module of the horizontal wind
REAL, DIMENSION(:), INTENT(IN)    :: PPS            ! pressure at the surface
REAL, DIMENSION(:), INTENT(IN)    :: PEXNA          ! exner function
                                                    ! at the lowest level
REAL, DIMENSION(:), INTENT(IN)    :: PRHOA          ! air density
REAL, DIMENSION(:), INTENT(IN)    :: PZREF          ! reference height of the first
                                                    ! atmospheric level (temperature)
REAL, DIMENSION(:), INTENT(IN)    :: PUREF          ! reference height of the first
                                                    ! atmospheric level (wind)
REAL, DIMENSION(:), INTENT(IN)    :: PWS_ROOF_MAX   ! maximum deepness of roof
REAL, DIMENSION(:), INTENT(IN)    :: PWS_ROAD_MAX   ! and water reservoirs (kg/m2)
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_A_COEF    ! implicit coefficients (m2s/kg)
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_B_COEF    ! for wind coupling     (m/s)
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_A_COEF_LOWCAN ! implicit coefficients for wind coupling (m2s/kg)
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_B_COEF_LOWCAN ! between low canyon wind and road (m/s)
REAL, DIMENSION(:), INTENT(IN)    :: PZ0_GARDEN_EXT     ! garden roughness length (external model)
REAL, DIMENSION(:), INTENT(IN)    :: PTSRAD_GR     !
REAL, DIMENSION(:), INTENT(IN)    :: PRUNOFF_GR     !

!
REAL, DIMENSION(:), INTENT(OUT)   :: PQSAT_ROOF     ! qsat(Ts)
REAL, DIMENSION(:), INTENT(OUT)   :: PQSAT_ROAD     ! qsat(Ts)
REAL, DIMENSION(:), INTENT(OUT)   :: PDELT_ROOF     ! water fraction on
REAL, DIMENSION(:), INTENT(OUT)   :: PDELT_ROAD     ! snow-free surfaces
REAL, DIMENSION(:), INTENT(OUT)   :: PCD            ! drag coefficient
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN           ! neutral drag coefficient
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROOF       ! aerodynamical conductance
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROOF_WAT   ! aerodynamical conductance (for water)
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_WALL       ! aerodynamical conductance
!                                                   ! between canyon air and
!                                                   ! walls 
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROAD_CAN       ! aerodynamical conductance
!                                                   ! between canyon air and
!                                                   ! roads
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROAD_WAT   ! aerodynamical conductance
!                                                   ! between canyon air and
!                                                   ! road (for water)
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_GARDEN_CAN     ! aerodynamical conductance
!                                                   ! between canyon air and
!                                                   ! garden
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_TOP        ! aerodynamical conductance
!                                                   ! between canyon top and atm.
!REAL, DIMENSION(:), INTENT(IN)    :: PAC_GARDEN_CAN     ! aerodynamical conductance
!                                                   ! between canyon air and GARDEN areas
REAL, DIMENSION(:), INTENT(OUT)   :: PRI            ! Town Richardson number
!
REAL, DIMENSION(:), INTENT(OUT)   :: PUW_ROAD       ! Momentum flux for roads
REAL, DIMENSION(:), INTENT(OUT)   :: PUW_ROOF       ! Momentum flux for roofs
REAL, DIMENSION(:), INTENT(OUT)   :: PDUWDU_ROAD    ! 
REAL, DIMENSION(:), INTENT(OUT)   :: PDUWDU_ROOF    ! 
REAL, DIMENSION(:), INTENT(OUT)   :: PUSTAR_TOWN    ! Fraction velocity for town
!
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_WIN        ! aerodynamical conductance for window
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_GARDEN_CAN     ! drag coeifficient for heat
REAL, DIMENSION(:), INTENT(OUT)   :: PCD_GARDEN_CAN     ! garden  surf. exchange coefficient
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_ROAD_CAN       ! drag coeifficient for heat
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_ROOF       ! drag coeifficient for heat
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_WALL       ! drag coeifficient for heat
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_TOP        ! drag coeifficient for heat

REAL, DIMENSION(:), INTENT(OUT)   :: ILMO_ROAD_CAN      ! 1/length of Monin-Obukov
REAL, DIMENSION(:), INTENT(OUT)   :: ILMO_ROOF      ! 1/length of Monin-Obukov
REAL, DIMENSION(:), INTENT(OUT)   :: ILMO_TOP       ! 1/length of Monin-Obukov
REAL, DIMENSION(:), INTENT(OUT)   :: PCD_GARDEN_ATM ! garden surf. exchange coeff. (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_GARDEN_ATM ! garden drag coeff. for heat (atm.)
!
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!* full set of URBAN_EXCH_COEF outputs for the exchange between the road and the
!* garden surfaces and the air of the canyon (_CAN) or of the forcing level (_ATM)
!* (diagnostic variables only, see section 8.3 below)
!
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
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROAD_ATM_WAT ! road   conductance for water (atm.)

!
!*      0.2    declarations of local variables
!
!
REAL, DIMENSION(SIZE(PTA)) :: ILMO_GARDEN  ! 1/length of Monin-Obukov
REAL, DIMENSION(SIZE(PTA)) :: ILMO_TOWN    ! 1/length of Monin-Obukov
REAL, DIMENSION(SIZE(PTA)) :: ZTS_TOWN     ! town averaged temp.
REAL, DIMENSION(SIZE(PTA)) :: ZQ_TOWN      ! town averaged hum.
REAL, DIMENSION(SIZE(PTA)) :: ZAVDELT_ROOF ! averaged water frac.
REAL, DIMENSION(SIZE(PTA)) :: ZQ_ROOF      ! roof spec. hum.
REAL, DIMENSION(SIZE(PTA)) :: ZZ0_ROOF     ! roof roughness length
REAL, DIMENSION(SIZE(PTA)) :: ZZ0_ROAD     ! road roughness length
REAL, DIMENSION(SIZE(PTA)) :: ZW_CAN       ! ver. wind in canyon
REAL, DIMENSION(SIZE(PTA)) :: ZRI          ! Richardson number
REAL, DIMENSION(SIZE(PTA)) :: ZLE_MAX      ! maximum latent heat flux available
REAL, DIMENSION(SIZE(PTA)) :: ZLE          ! roof latent heat flux (free)
REAL, DIMENSION(SIZE(PTA)) :: ZLE_CAN_FREE ! road latent heat flux, road -> canyon (unlimited)
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
REAL, DIMENSION(SIZE(PTA)) :: ZLE_ATM_FREE ! road latent heat flux, road -> forcing level (unlimited)
REAL, DIMENSION(SIZE(PTA)) :: ZLE_TOT      ! tau-weighted sum of the free branch latent fluxes
REAL, DIMENSION(SIZE(PTA)) :: ZFRAC_WAT    ! water availability factor applied to both branches
REAL, DIMENSION(SIZE(PTA)) :: ZRA_ROOF     ! aerodynamical resistance
!REAL, DIMENSION(SIZE(PTA)) :: ZCH_ROOF     ! drag coefficient for heat
REAL, DIMENSION(SIZE(PTA)) :: ZRA_TOP      ! aerodynamical resistance
!REAL, DIMENSION(SIZE(PTA)) :: ZCH_TOP      ! drag coefficient for heat
REAL, DIMENSION(SIZE(PTA)) :: ZRA_ROAD_CAN     ! road aerodynamical resistance (canyon)
REAL, DIMENSION(SIZE(PTA)) :: ZRA_GARDEN_CAN   ! garden aerodynamical resistance (canyon)
REAL, DIMENSION(SIZE(PTA)) :: ZRA_ROAD_ATM     ! road aerodynamical resistance (atm., unused)
REAL, DIMENSION(SIZE(PTA)) :: ZILMO_ROAD_ATM   ! road 1/L of Monin-Obukov (atm., unused)
REAL, DIMENSION(SIZE(PTA)) :: ZAC          ! town aerodynamical conductance (not used)
REAL, DIMENSION(SIZE(PTA)) :: ZRA          ! town aerodynamical resistance  (not used)
REAL, DIMENSION(SIZE(PTA)) :: ZCH          ! town drag coefficient for heat (not used)
REAL, DIMENSION(SIZE(PTA)) :: ZCD          ! any surf. exchange coefficient (not used)
REAL, DIMENSION(SIZE(PTA)) :: ZCDN         ! any surf. neutral exch. coef.  (not used)
!
REAL, DIMENSION(SIZE(PTA)) :: ZU_STAR, ZW_STAR !! 
REAL, DIMENSION(SIZE(PTA)) :: ZQ0              !! 
!
REAL, DIMENSION(SIZE(PTA)) :: ZUSTAR2      ! square of friction velocity (m2/s2
REAL, DIMENSION(SIZE(PTA)) :: ZVMOD        ! module of the horizontal wind at t+1
!
! for calculation of momentum fluxes
REAL, DIMENSION(SIZE(PTA)) :: ZLMO         ! Monin-Obukhov length
REAL, DIMENSION(SIZE(PTA)) :: ZUSTAR_ROAD  ! friction velocity for roads
REAL, DIMENSION(SIZE(PTA)) :: ZUSTAR_ROOF  ! friction velocity for roofs
REAL, DIMENSION(SIZE(PTA)) :: ZUSTAR_TOWN  !
!
REAL, DIMENSION(SIZE(PTA)) :: ZZ0_TOP      ! roughness length for zac_top calculation
REAL, DIMENSION(SIZE(PTA)) :: ZZ0H_TOP      ! roughness length for zac_top calculation
REAL, DIMENSION(SIZE(PTA)) :: ZZ0H_ROOF      ! roughness length for zac_top calculation
REAL, DIMENSION(SIZE(PTA)) :: ZZ0H_TOWN      ! roughness length for zac_top calculation
REAL, DIMENSION(SIZE(PTA)) :: ZCHTCN_WIN   ! natural convective heat transfer coef. for window [W/(m2.K)]
REAL, DIMENSION(SIZE(PTA)) :: ZCHTCN_ROOF  ! natural convective heat transfer coef. for roof [W/(m2.K)]
REAL, DIMENSION(SIZE(PTA)) :: ZCHTCS_ROOF  ! forced convective heat transfer coef. for smooth roof [W/(m2.K)]
REAL, DIMENSION(SIZE(PTA)) :: ZCHTCN_WALL  ! natural convective heat transfer coef. for wall [W/(m2.K)]
REAL, DIMENSION(SIZE(PTA)) :: ZCHTCS_WALL  ! forced natural convective heat transfer coef. for smooth wall [W/(m2.K)]
REAL, DIMENSION(SIZE(PTA)) :: ZTS_GROUND   ! Surface temperature of ground (road + garden)
REAL, DIMENSION(SIZE(PTA)) :: ZRA_GARDEN_ATM
REAL, DIMENSION(SIZE(PTA)) :: ZILMO_GARDEN_ATM
REAL, DIMENSION(SIZE(PTA)) :: ZVMOD_TOWN
REAL, DIMENSION(SIZE(PTA)) :: ZVMOD_TOP
REAL, DIMENSION(SIZE(PTA)) :: ZUSTAR_TOP
REAL, DIMENSION(SIZE(PTA)) :: ZVMOD_ROOF
REAL, DIMENSION(SIZE(PTA)) :: ZVMOD_ROAD
REAL, DIMENSION(SIZE(PTA)) :: ZVMOD_GARDEN
REAL, DIMENSION(SIZE(PTA)) :: ZUSTAR_GARDEN
REAL, DIMENSION(SIZE(PTA)) :: ZVMOD_TERRA
REAL, DIMENSION(SIZE(PTA)) :: ZUSTAR_TERRA
REAL, DIMENSION(SIZE(PTA)) :: k_ustar


CHARACTER(LEN=*), PARAMETER       :: ZZ0H_TOWN1 = 'output/ZZ0H_TOWN1.txt'
CHARACTER(LEN=*), PARAMETER       :: ZZ0H_ROOF1 = 'output/ZZ0H_ROOF1.txt'
CHARACTER(LEN=*), PARAMETER       :: ZZ0H_ROAD1 = 'output/ZZ0H_ROAD1.txt'


!
INTEGER                   ::  JLOOP, JJ            !! 
!
REAL :: ZZ0_O_Z0H = 200.  ! z0/z0h ratio used in Mascart (1995) formulation.
!                         ! It is set to the maximum value acceptable by
!                         ! formulation. Observed values are often larger in cities.
REAL(KIND=JPRB) :: ZHOOK_HANDLE
!-------------------------------------------------------------------------------
!
!
IF (LHOOK) CALL DR_HOOK('URBAN_DRAG',0,ZHOOK_HANDLE)
!
ZZ0_ROOF(:)    = 0.15                      ! z0 for roofs
ZZ0_ROAD(:)    = MIN(0.05,0.1*PZ_LOWCAN(:))! z0 for roads
!
ZZ0_TOP(:) = T%XZ0_TOWN(:)
!
PCD    (:) = XUNDEF
PCDN   (:) = XUNDEF
PAC_TOP(:) = XUNDEF
PRI    (:) = XUNDEF
!
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!* diagnostic exchange coefficients between the surfaces and the air of the
!* canyon or of the forcing level (see section 8.3); the garden ones are filled
!* for an external garden: 'EXT' with the full URBAN_EXCH_COEF set, 'EXT_NEU'
!* with the neutral formulation of the internal garden (see section 8.5)
!
PCD_ROAD_CAN   (:) = XUNDEF
PCDN_ROAD_CAN  (:) = XUNDEF
PRI_ROAD_CAN   (:) = XUNDEF
ZZ0H_ROAD_CAN  (:) = XUNDEF
PAC_ROAD_ATM   (:) = XUNDEF
PAC_ROAD_ATM_WAT(:) = XUNDEF
PCH_ROAD_ATM   (:) = XUNDEF
PCD_ROAD_ATM   (:) = XUNDEF
PCDN_ROAD_ATM  (:) = XUNDEF
PRI_ROAD_ATM   (:) = XUNDEF
ZZ0H_ROAD_ATM  (:) = XUNDEF
PCDN_GARDEN_CAN(:) = XUNDEF
PRI_GARDEN_CAN (:) = XUNDEF
ZZ0H_GARDEN_CAN(:) = XUNDEF
PAC_GARDEN_ATM (:) = XUNDEF
PCDN_GARDEN_ATM(:) = XUNDEF
PRI_GARDEN_ATM (:) = XUNDEF
ZZ0H_GARDEN_ATM(:) = XUNDEF
PCD_GARDEN_ATM (:) = XUNDEF
PCH_GARDEN_ATM (:) = XUNDEF
!
!* 1/L is not computed under MASC95 (see URBAN_EXCH_COEF): the corresponding
!* outputs are set here to XUNDEF so that no uninitialised value leaves this routine
!
ILMO_ROAD_CAN  (:) = XUNDEF
ILMO_ROOF      (:) = XUNDEF
ILMO_TOP       (:) = XUNDEF
!
PUW_ROAD   (:) = XUNDEF
PUW_ROOF   (:) = XUNDEF
PDUWDU_ROAD(:) = XUNDEF
PDUWDU_ROOF(:) = XUNDEF
PUSTAR_TOWN(:) = XUNDEF
!
!-------------------------------------------------------------------------------
!
!*      1.     roof and road saturation specific humidity
!              ------------------------------------------
!
PQSAT_ROOF(:) = QSAT (PTS_ROOF(:), PPS(:))
!
PQSAT_ROAD(:) = QSAT (PTS_ROAD(:), PPS(:))
!
!-------------------------------------------------------------------------------
!
!*      2.     fraction of water on roofs
!              --------------------------
!
PDELT_ROOF=1.
!
!*      2.1    general case
!              ------------
!
WHERE (PQSAT_ROOF(:) >= PQA(:) )
  PDELT_ROOF(:) = (T%XWS_ROOF(:)/PWS_ROOF_MAX)**(2./3.)
END WHERE
!
!*      2.2    dew deposition on roofs (PDELT_ROOF=1)
!              -----------------------
!
!-------------------------------------------------------------------------------
!
!*      3.     fraction of water on roads
!              --------------------------
!
PDELT_ROAD=1.
!
!*      3.1    general case
!              ------------
!
WHERE (PQSAT_ROAD(:) >= PQ_CANYON(:) )
  PDELT_ROAD(:) = (T%XWS_ROAD(:)/PWS_ROAD_MAX)**(2./3.)
END WHERE
!
!*      3.2    dew deposition on roads (PDELT_ROAD=1)
!              -----------------------
!
!-------------------------------------------------------------------------------
!
!*      4.     Drag coefficient for momentum between roof level and atmosphere
!              ---------------------------------------------------------------
!
!
DO JJ=1,SIZE(PTA)
!
!*      4.1    Averaged temperature at roof level
!              ----------------------------------
!
  ZTS_TOWN(JJ) = T%XBLD(JJ) * PTS_ROOF(JJ) + (1.-T%XBLD(JJ)) * PT_CANYON(JJ)
!
!*      4.2    Averaged water fraction on roofs
!              -------------------------------
!
  ZAVDELT_ROOF(JJ) = PDELT_ROOF(JJ) * PDELT_SNOW_ROOF(JJ)
!
!*      4.3    Roof specific humidity
!              ----------------------
!
  ZQ_ROOF(JJ) = PQSAT_ROOF(JJ) * ZAVDELT_ROOF(JJ)
!
!*      4.4    Averaged Saturation specific humidity
!              -------------------------------------
!
  ZQ_TOWN(JJ) =  T%XBLD(JJ) * ZQ_ROOF(JJ) + (1.-T%XBLD(JJ)) * PQ_CANYON(JJ)
!
ENDDO
!
!-------------------------------------------------------------------------------
!
!*      5.     Momentum drag coefficient
!              -------------------------
!
IF (.NOT. TOP%LCANOPY) THEN
 
!MV202609 z0 and zd to namelist
! The reference heights are taken above the displacement surface:
!   (roof height - zd) + PZREF = (T%XBLD_HEIGHT - T%XZD_TOWN) + PZREF
! (the official TEB has a hard-coded '+ T%XBLD_HEIGHT/3.' here, which corresponds
!  to zd = 2/3*H and is not consistent with the wind profile of the driver,
!  where 2/3*H = H - zd gives zd = H/3)
  CALL URBAN_EXCH_COEF(TOP%CZ0H, ZZ0_O_Z0H, ZTS_TOWN, ZQ_TOWN, PEXNS, PEXNA, PTA, PQA,     &
                       PZREF+ (T%XBLD_HEIGHT-T%XZD_TOWN), PUREF+(T%XBLD_HEIGHT-T%XZD_TOWN), PVMOD, T%XZ0_TOWN, &
                       PRI, PCD, PCDN, ZAC, ZRA, ZCH, ZZ0H_TOWN, ILMO_TOWN              )
  
!  OPEN(UNIT=27, FILE = ZZ0H_TOWN1, ACCESS = 'APPEND')
!  WRITE(27,*) ZZ0H_TOWN
!  CLOSE(27)

ENDIF
!
!-------------------------------------------------------------------------------
!
!*      6.     Drag coefficient for heat fluxes between roofs and atmosphere
!              -------------------------------------------------------------
!


IF (TOP%CCH_BEM == "DOE-2") THEN
   ZCHTCN_ROOF = CHTC_UP_DOE(PTS_ROOF, PTA)
   ZCHTCS_ROOF = CHTC_SMOOTH_WIND_DOE(ZCHTCN_ROOF, PVMOD)
   PAC_ROOF = CHTC_ROUGH_DOE(ZCHTCN_ROOF, ZCHTCS_ROOF, T%XROUGH_ROOF) / PRHOA / XCPD
ELSE
   
   CALL URBAN_EXCH_COEF(TOP%CZ0H, ZZ0_O_Z0H, PTS_ROOF, ZQ_ROOF, PEXNS, PEXNA, PTA, PQA, &
                        PZREF, PUREF, PVMOD, ZZ0_ROOF, ZRI, ZCD, ZCDN, PAC_ROOF,        &
                        ZRA_ROOF, PCH_ROOF, ZZ0H_ROOF, ILMO_ROOF               )


ENDIF
!IF (icell == 1 .AND. iblock == 1884) THEN
!   print*, 'ILMO_ROOF = ', ILMO_ROOF
!   print*, 'PCH_ROOF = ', PCH_ROOF
!ENDIF   
!PAC_ROOF(:) = PAC_ROOF(:) * 2.
!PCH_ROOF(:) = PCH_ROOF(:) * 2.
!
!
DO JJ=1,SIZE(PTA)
  ZLE_MAX(JJ)     = T%XWS_ROOF(JJ) / PTSTEP * XLVTT
  ZLE    (JJ)     =(PQSAT_ROOF(JJ) - PQA(JJ)) &
                 * PAC_ROOF(JJ) * PDELT_ROOF(JJ) * XLVTT * PRHOA(JJ)
!
  PAC_ROOF_WAT(JJ) = PAC_ROOF(JJ)
!
  IF (PDELT_ROOF(JJ)==0.) PAC_ROOF_WAT(JJ)=0.
!
  IF (ZLE(JJ)>0.) PAC_ROOF_WAT(JJ) = PAC_ROOF(JJ) * MIN ( 1. , ZLE_MAX(JJ)/ZLE(JJ) )
!
ENDDO
!-------------------------------------------------------------------------------
!
!*      7.     Drag coefficient for heat fluxes between canyon and atmosphere
!              --------------------------------------------------------------
!
!* Because air/air exchanges are considered, roughness length for heat is set
!  equal to roughness length for momentum.
!
IF (.NOT. TOP%LCANOPY) THEN 

  CALL URBAN_EXCH_COEF('MASC95', 1., PT_CANYON, PQ_CANYON, PEXNS, PEXNA, PTA, PQA,    &
                      PZREF+T%XBLD_HEIGHT-PZ_LOWCAN, PUREF+T%XBLD_HEIGHT-PZ_LOWCAN, &
                      PVMOD, ZZ0_TOP,  ZRI, ZCD, ZCDN, PAC_TOP, ZRA_TOP, PCH_TOP, ZZ0H_TOP, ILMO_TOP  )

!  CALL URBAN_EXCH_COEF(TOP%CZ0H, 1., PT_CANYON, PQ_CANYON, PEXNS, PEXNA, PTA, PQA,    &
!                        PZREF+T%XBLD_HEIGHT-PZ_LOWCAN, PUREF+T%XBLD_HEIGHT-PZ_LOWCAN, &
!                        PVMOD, ZZ0_TOP,  ZRI, ZCD, ZCDN, PAC_TOP, ZRA_TOP, PCH_TOP,   &
!  						ZZ0H_TOP, ILMO_TOP  )

ENDIF
!IF (icell == 1 .AND. iblock == 1884) THEN
!   print*, 'PTSTEP = ', PTSTEP
!   print*, 'ILMO_TOP = ', ILMO_TOP
!   print*, 'PCH_TOP = ', PCH_TOP
!ENDIF

!IF (PTIME >= 32400. .AND. PTIME <= 75600.) THEN
!PAC_TOP = PAC_TOP * 2.	
!PCH_TOP = PCH_TOP * 2.
!ENDIF

!print*, 'PCH_TOP = ', PCH_TOP
!print*, 'PTIME = ', PTIME
!
!-------------------------------------------------------------------------------
!
!*      8.     Drag coefficient for heat fluxes between walls, road and canyon
!              ---------------------------------------------------------------
!
!*      8.1    aerodynamical conductance for walls
!              -----------------------------------
!
IF (TOP%CCH_BEM == "DOE-2") THEN
  DO JJ=1,SIZE(PTA)
    ZCHTCN_WALL(JJ) = CHTC_VERT_DOE(PTS_WALL(JJ), PT_CANYON(JJ))
    ZCHTCS_WALL(JJ) = 0.5 * (CHTC_SMOOTH_LEE_DOE (ZCHTCN_WALL(JJ), PU_CANYON(JJ)) + &
                             CHTC_SMOOTH_WIND_DOE(ZCHTCN_WALL(JJ), PU_CANYON(JJ)) )
                      
    PAC_WALL(JJ) = CHTC_ROUGH_DOE(ZCHTCN_WALL(JJ), ZCHTCS_WALL(JJ), T%XROUGH_WALL(JJ)) / XCPD / PRHOA(JJ)
  END DO
ELSE
  PAC_WALL(:) = ( 11.8 + 4.2 * PU_CANYON(:) ) / XCPD / PRHOA(:)
END IF
PCH_WALL(:) = PAC_WALL(:) / PU_CANYON(:)
!PAC_WALL(:) = PAC_WALL(:) * 2.
!PCH_WALL(:) = PCH_WALL(:) * 2.
!
!*      8.2    aerodynamical conductance for roads
!              -----------------------------------
!
ZW_STAR(:) = 0.
ZQ0(:)     = 0.
!
!
DO JLOOP=1,3
 !
  ZW_CAN(:)   = ZW_STAR(:)
  !
  !
  
  
!* Surface temperature of the ground (road + garden) averaged with the road and
!  garden fractions. This value is used in ZQ0 below (canyon wind), but its
!  computation was commented out, so ZTS_GROUND was used uninitialised.
!  The zero-denominator case (no road and no garden) is guarded, as done for
!  ZRD/ZGD in URBAN_SOLAR_ABS.
WHERE (T%XROAD(:) + T%XGARDEN(:) > 0.)
  ZTS_GROUND(:) = PTS_ROAD(:)   * T%XROAD(:)   / (T%XROAD(:) + T%XGARDEN(:)) &
                + PTS_GARDEN(:) * T%XGARDEN(:) / (T%XROAD(:) + T%XGARDEN(:))
ELSEWHERE
  ZTS_GROUND(:) = PTS_ROAD(:)
END WHERE
!
   
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
  CALL URBAN_EXCH_COEF(TOP%CZ0H, ZZ0_O_Z0H, PTS_ROAD, PQ_LOWCAN, PEXNS, PEXNA,  &
						PT_LOWCAN, PQ_LOWCAN, PZ_LOWCAN, PZ_LOWCAN,              &
						PU_LOWCAN+ZW_CAN, ZZ0_ROAD, PRI_ROAD_CAN, PCD_ROAD_CAN, PCDN_ROAD_CAN,         &
						PAC_ROAD_CAN, ZRA_ROAD_CAN, PCH_ROAD_CAN, ZZ0H_ROAD_CAN, ILMO_ROAD_CAN        )
  
  !
					   
  
  DO JJ=1,SIZE(PTA)

    ZQ0(JJ)     = (PTS_WALL  (JJ) - PT_CANYON(JJ)) * PAC_WALL  (JJ) * T%XWALL_O_GRND(JJ)

    IF (T%XROAD(JJ) .GT. 0.) THEN
!      ZQ0(JJ)   = ZQ0(JJ) &
!            + (PTS_ROAD  (JJ) - PT_LOWCAN(JJ)) * PAC_ROAD_CAN  (JJ) * T%XROAD  (JJ)/(T%XROAD(JJ)+T%XGARDEN(JJ)) 

      ZQ0(JJ)   = ZQ0(JJ) &
            + (ZTS_GROUND  (JJ) - PT_LOWCAN(JJ)) * PAC_ROAD_CAN  (JJ)

    ENDIF
! 
    IF (ZQ0(JJ) >= 0.) THEN
      ZW_STAR(JJ) = ( (XG * PEXNA(JJ) / PTA(JJ)) * ZQ0(JJ) * T%XBLD_HEIGHT(JJ)) ** (1/3.)
    ELSE
      ZW_STAR(JJ) = 0.
    ENDIF
!
  ENDDO
!
END DO
!-------------------------------------------------------------------------------
!
!*      8.3    Exchange coefficients between the road and the atmosphere
!              at the forcing level (direct exchange, without the canyon)
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!              ------------------------------------------------------------
!
!* Same kind of diagnostic as the garden/atmosphere (TERRA) coefficients: the
!  value of the aerodynamic coefficients that the road surface would have if it
!  exchanged directly with the air of the forcing level (PTA, PQA and PVMOD at
!  the heights PZREF and PUREF) instead of the low canyon air (PT_LOWCAN,
!  PQ_LOWCAN and PU_LOWCAN at the height PZ_LOWCAN).
!
!* This call is the exact analogue of the road/canyon one (section 8.2): same
!  roughness length for momentum (ZZ0_ROAD), same option for the roughness length
!  for heat (TOP%CZ0H with the ZZ0_O_Z0H ratio) and same wind thresholding, only
!  the reference air is changed.
!
!* These coefficients are diagnostic variables only: they do not feed back on the
!  surface energy budget.
!
CALL URBAN_EXCH_COEF(TOP%CZ0H, ZZ0_O_Z0H, PTS_ROAD, PQA, PEXNS, PEXNA, PTA, PQA, &
                     PZREF, PUREF, PVMOD, ZZ0_ROAD, PRI_ROAD_ATM, PCD_ROAD_ATM, &
                     PCDN_ROAD_ATM, PAC_ROAD_ATM, ZRA_ROAD_ATM, PCH_ROAD_ATM,  &
                     ZZ0H_ROAD_ATM, ZILMO_ROAD_ATM                              )
!
!PCH_ROAD_CAN(:) = PCH_ROAD_CAN(:) * 2.
!PAC_ROAD_CAN(:) = PAC_ROAD_CAN(:) * 2.
!IF (icell == 1 .AND. iblock == 1884) THEN
!   print*, 'ZZ0H_ROAD_CAN = ', ZZ0H_ROAD_CAN
!   print*, 'PCH_ROAD_CAN = ', PCH_ROAD_CAN
!ENDIF

!IF (TOP%LGARDEN) THEN
!	PCH_GARDEN_CAN(:) = PCH_ROAD_CAN(:)
!	PAC_GARDEN_CAN(:) = PAC_ROAD_CAN(:)
!	PCD_GARDEN_CAN(:) = PCD_ROAD_CAN(:)
!ELSE
!	PCH_GARDEN_CAN(:) = 0.
!	PAC_GARDEN_CAN(:) = 0.
!	PCD_GARDEN_CAN(:) = 0.
!ENDIF	
!
!
!*      8.4    aerodynamical conductance for water limited by available water
!              --------------------------------------------------------------
!
DO JJ=1,SIZE(PTA)
  !
  ZLE_MAX(JJ)     = T%XWS_ROAD(JJ) / PTSTEP * XLVTT
  !
  !MV202609 tau scheme of the road (revision: single bucket over both branches)
  !* free (unlimited) latent fluxes of the two branches of the road (canyon air
  !* and forcing level), per m2 of snow-free road
  ZLE_CAN_FREE(JJ) = ( PQSAT_ROAD(JJ) - PQ_LOWCAN(JJ) )                 &
                     * PAC_ROAD_CAN(JJ) * PDELT_ROAD(JJ) * XLVTT * PRHOA(JJ)
  ZLE_ATM_FREE(JJ) = ( PQSAT_ROAD(JJ) - PQA(JJ) )                        &
                     * PAC_ROAD_ATM(JJ) * PDELT_ROAD(JJ) * XLVTT * PRHOA(JJ)
  !
  !* the two branches share the water of the single road reservoir: the tau-
  !*-weighted sum of their free fluxes may not exceed the available water
  !   ZLE_TOT = tau*ZLE_CAN_FREE + (1-tau)*ZLE_ATM_FREE
  !   f       = min(1, ZLE_MAX/ZLE_TOT)   (no limit for condensation, ZLE_TOT <= 0)
  ! so the reservoir constraint applies to the branches taken together, not to
  ! each branch separately (with tau = 1 or the tau scheme disabled this reduces
  ! to the classic canyon-branch rule and the former behaviour is reproduced
  ! exactly). The same factor f applies to both branches, therefore the actual
  ! road latent flux is exactly tau*PLE_ROAD_CAN + (1-tau)*PLE_ROAD_ATM also
  ! when the water limitation is active.
  ZLE_TOT(JJ)   = PTAU(JJ) * ZLE_CAN_FREE(JJ) + (1.-PTAU(JJ)) * ZLE_ATM_FREE(JJ)
  !
  ZFRAC_WAT(JJ) = 1.
  IF (ZLE_TOT(JJ) > 0.) ZFRAC_WAT(JJ) = MIN(1., ZLE_MAX(JJ)/ZLE_TOT(JJ))
  !
  !MV202609 road-to-atm and garden-to-atm exchange diagnostics
  !* the canyon and the forcing-level branches get the same water-limitation
  !* factor; PAC_ROAD_ATM_WAT is the conductance used by the road -> atmosphere
  !* flux diagnostic computed in ROAD_LAYER_E_BUDGET (same water as PAC_ROAD_WAT)
  PAC_ROAD_WAT    (JJ) = PAC_ROAD_CAN(JJ) * ZFRAC_WAT(JJ)
  PAC_ROAD_ATM_WAT(JJ) = PAC_ROAD_ATM(JJ) * ZFRAC_WAT(JJ)
  !
  !* a bone-dry road has no water at all whatever the limit factor
  IF (PDELT_ROAD(JJ)==0.) THEN
    PAC_ROAD_WAT    (JJ) = 0.
    PAC_ROAD_ATM_WAT(JJ) = 0.
  ENDIF
  !
  !
  !
  !
  !
  !
  !*      8.5    aerodynamical conductance for window
  !              ------------------------------------
  !
  ZCHTCN_WIN(JJ) = CHTC_VERT_DOE(B%XT_WIN1(JJ), PT_CANYON(JJ))
  !
  PAC_WIN(JJ) = 0.5 * (CHTC_SMOOTH_LEE_DOE(ZCHTCN_WIN(JJ), PU_CANYON(JJ)) + &
                      CHTC_SMOOTH_WIND_DOE(ZCHTCN_WIN(JJ), PU_CANYON(JJ)) ) &
                   / PRHOA(JJ) / XCPD
				   
				   
  !-------------------------------------------------------------------------------
!
!*      8.5     Drag coefficient for heat fluxes between GARDEN and atmosphere
!              -------------------------------------------------------------
!


!IF (TOP%LGARDEN) THEN
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!* garden exchange coefficients, canyon path and atmosphere path.
!*
!* 'EXT_NEU' - the garden of an external model with the NEUTRAL exchange
!* coefficients of the internal diagnostic garden (src_proxi_SVAT/garden.F90):
!*     PCD = (kappa/ln(z/z0))**2,   PCH = kappa**2/(ln(z/z0)*ln(z/z0h))
!*     Ca_h = PCH*max(V, XVMIN_GD),   z0h = z0/TOP%XZ0_O_Z0H_GD
!* with the same wind floor XVMIN_GD and the same thermal roughness z0h as the
!* internal garden: the momentum coefficient serves the friction, the thermal one
!* the heat and the moisture, so PCD = PCDN > PCH (equality at z0h = z0).
!* PRI_GARDEN_* is not defined in this formulation (no Richardson number) and
!* keeps its XUNDEF initialisation, while ZZ0H_GARDEN_* is the thermal roughness
!* used. This is the coefficient set a coupled external garden model is meant to
!* be driven with: it coincides with the coefficients of the internal garden and
!* with the emulator of run_teb_offline.
!*
!* 'EXT' - the same two paths but with the full URBAN_EXCH_COEF set (Richardson
!* number, the same z0h = z0/TOP%XZ0_O_Z0H_GD, WIND_THRESHOLD), i.e. the
!* description of the garden coefficients used for the bookkeeping of a coupled
!* model.
!
IF (TOP%CTYPE_GARDEN == 'EXT_NEU') THEN
   ! canyon path (low canyon level, the heights and the wind of the internal garden)
   PCDN_GARDEN_CAN(:) = GARDEN_PCD_NEUTRAL    (PZ_LOWCAN(:), PZ0_GARDEN_EXT(:))
   PCD_GARDEN_CAN (:) = PCDN_GARDEN_CAN(:)
   PCH_GARDEN_CAN (:) = GARDEN_PCH_NEUTRAL    (PZ_LOWCAN(:), PZ0_GARDEN_EXT(:), TOP%XZ0_O_Z0H_GD)
   PAC_GARDEN_CAN (:) = GARDEN_CAH_NEUTRAL    (PZ_LOWCAN(:), PZ0_GARDEN_EXT(:), TOP%XZ0_O_Z0H_GD, PU_LOWCAN(:))
   ZZ0H_GARDEN_CAN(:) = PZ0_GARDEN_EXT(:) / MAX(TOP%XZ0_O_Z0H_GD, 1.)
   ! atmosphere path (reference air of the forcing level)
   PCDN_GARDEN_ATM(:) = GARDEN_PCD_NEUTRAL    (PUREF(:), PZ0_GARDEN_EXT(:))
   PCD_GARDEN_ATM (:) = PCDN_GARDEN_ATM(:)
   PCH_GARDEN_ATM (:) = GARDEN_PCH_NEUTRAL    (PUREF(:), PZ0_GARDEN_EXT(:), TOP%XZ0_O_Z0H_GD)
   PAC_GARDEN_ATM (:) = GARDEN_CAH_NEUTRAL    (PUREF(:), PZ0_GARDEN_EXT(:), TOP%XZ0_O_Z0H_GD, PVMOD(:))
   ZZ0H_GARDEN_ATM(:) = PZ0_GARDEN_EXT(:) / MAX(TOP%XZ0_O_Z0H_GD, 1.)
   !
ELSEIF (TOP%CTYPE_GARDEN == 'EXT') THEN
   !* garden/canyon exchange coefficients: computed only when the garden is
   !* provided by an EXTERNAL model (TOP%CTYPE_GARDEN == 'EXT')
   !MV202609 garden thermal roughness (z0h)
   !* the z0/z0h ratio is the one of the namelist item urb_z0_o_z0h_gdn (it used
   !* to be the hard-coded value 4.), so that the coefficients exported here and
   !* the ones used by the internal diagnostic garden cannot disagree
   !
CALL URBAN_EXCH_COEF(TOP%CZ0H, TOP%XZ0_O_Z0H_GD, PTS_GARDEN, PQS_GARDEN, PEXNS, PEXNA,  &
                       PT_LOWCAN, PQ_LOWCAN, PZ_LOWCAN, PZ_LOWCAN,              &
                       PU_LOWCAN, PZ0_GARDEN_EXT, PRI_GARDEN_CAN, PCD_GARDEN_CAN, PCDN_GARDEN_CAN,         &
                       PAC_GARDEN_CAN, ZRA_GARDEN_CAN, PCH_GARDEN_CAN, ZZ0H_GARDEN_CAN, ILMO_GARDEN        )	
   !
!   CALL URBAN_EXCH_COEF(TOP%CZ0H, 4., PTSRAD_GR, PRUNOFF_GR, PEXNS, PEXNA,  &
!                       PTA, PQA, PZREF, PZREF,              &
!                       PVMOD, PZ0_GARDEN, ZRI, PCD_GARDEN_ATM, PCDN_GARDEN_ATM,         &
!                       PAC_GARDEN_ATM, ZRA_GARDEN_ATM, PCH_GARDEN_ATM, ZZ0H_GARDEN_ATM, ZILMO_GARDEN_ATM        )
   !
   !* garden/atmosphere (TERRA-type) exchange coefficients: diagnostic variables,
   !* computed ONLY together with the garden/canyon coefficients above, i.e. when
   !* the garden is provided by an EXTERNAL model (TOP%CTYPE_GARDEN = 'EXT'): only then
   !* PTS_GARDEN and PQS_GARDEN describe a real garden surface state. With the
   !* internal (proxy-SVAT) garden the surface state is a placeholder
   !* (PTS_GARDEN = canyon air temperature from TEB_VEG_PROPERTIES, PQS_GARDEN = 0),
   !* so the forcing-level coefficients would be meaningless; they keep their XUNDEF
   !* initialisation in that case, as well as when no garden is modelled at all.
   !
CALL URBAN_EXCH_COEF(TOP%CZ0H, TOP%XZ0_O_Z0H_GD, PTS_GARDEN, PQS_GARDEN, PEXNS, PEXNA,  &
                       PTA, PQA, PZREF, PZREF,              &
                       PVMOD, PZ0_GARDEN_EXT, PRI_GARDEN_ATM, PCD_GARDEN_ATM, PCDN_GARDEN_ATM,         &
                       PAC_GARDEN_ATM, ZRA_GARDEN_ATM, PCH_GARDEN_ATM, ZZ0H_GARDEN_ATM, ZILMO_GARDEN_ATM        )
   !
ENDIF

		
	

!IF (icell == 16 .AND. iblock == 1585) THEN
!IF (icell == 7 .AND. iblock == 1837) THEN
!	print*, 'urban_drag PTA = ', PTA
!	print*, 'urban_drag PQA = ', PQA
!	print*, 'urban_drag PVMOD = ', PVMOD
!    print*, 'urban_drag PZ0_GARDEN = ', PZ0_GARDEN
!    print*, 'urban_drag PZ_LOWCAN = ', PZ_LOWCAN
!    print*, 'urban_drag PCH_GARDEN_CAN = ', PCH_GARDEN_CAN
!	print*, 'urban_drag PCDN_GARDEN_CAN = ', PCDN_GARDEN_CAN
!    print*, 'urban_drag PCD_GARDEN_CAN = ', PCD_GARDEN_CAN
!    print*, 'urban_drag PZREF = ', PZREF
!	print*, 'urban_drag PTSRAD_GR = ', PTSRAD_GR
!	print*, 'urban_drag PRUNOFF_GR = ', PRUNOFF_GR
!	print*, 'urban_drag PEXNS = ', PEXNS
!	print*, 'urban_drag PEXNA = ', PEXNA

!    print*, 'urban_drag PCH_GARDEN_ATM = ', PCH_GARDEN_ATM
!	print*, 'urban_drag PCDN_GARDEN_ATM = ', PCDN_GARDEN_ATM
!    print*, 'urban_drag PCD_GARDEN_ATM = ', PCD_GARDEN_ATM
!ENDIF
				   
  !
  !-------------------------------------------------------------------------------
  !
  !*      9.     Momentum fluxes
  !              ---------------
  !
  !*      9.1    For roads
  !              ---------
  !
  !* road friction
  !
  IF (TOP%LCANOPY) THEN
    !
    ZUSTAR2(JJ)=XUNDEF
    !
    IF(HIMPLICIT_WIND=='OLD')THEN
      !   old implicitation
      ZUSTAR2(JJ) = (PCD_ROAD_CAN(JJ)*PU_LOWCAN(JJ)*PPEW_B_COEF_LOWCAN(JJ))/              &
                    (1.0-PRHOA(JJ)*PCD_ROAD_CAN(JJ)*PU_LOWCAN(JJ)*PPEW_A_COEF_LOWCAN(JJ))
    ELSE
      !   new implicitation
      ZUSTAR2(JJ) = (PCD_ROAD_CAN(JJ)*PU_LOWCAN(JJ)*(2.*PPEW_B_COEF_LOWCAN(JJ)-PU_LOWCAN(JJ)))/  &
                    (1.0-2.0*PRHOA(JJ)*PCD_ROAD_CAN(JJ)*PU_LOWCAN(JJ)*PPEW_A_COEF_LOWCAN(JJ))
      !                   
      ZVMOD(JJ) = PRHOA(JJ)*PPEW_A_COEF_LOWCAN(JJ)*ZUSTAR2(JJ) + PPEW_B_COEF_LOWCAN(JJ)
      ZVMOD(JJ) = MAX(ZVMOD(JJ),0.)
      !
      IF(PPEW_A_COEF_LOWCAN(JJ)/= 0.)THEN
        ZUSTAR2(JJ) = MAX( ( ZVMOD(JJ) - PPEW_B_COEF_LOWCAN(JJ) ) / (PRHOA(JJ)*PPEW_A_COEF_LOWCAN(JJ)), 0.)
      ENDIF
      !              
    ENDIF

    !
    PUW_ROAD(JJ) = - ZUSTAR2(JJ)
    !
    PDUWDU_ROAD(JJ) = 0. ! implicitation already taken into account in PUW_ROAD
    !
    !*      9.2    For roofs
    !              ---------
    !
    !* roof friction
    !* neutral case, as guess
    !
    !
    ZUSTAR_ROOF(JJ) = PVMOD(JJ) * XKARMAN / LOG(PZREF(JJ)/ZZ0_ROOF(JJ))
    !
    PUW_ROOF(JJ)    = - ZUSTAR_ROOF(JJ)**2
    PDUWDU_ROOF(JJ) = 0.
    IF (PVMOD(JJ)/=0.) PDUWDU_ROOF(JJ) = 2. * PUW_ROOF(JJ) / PVMOD(JJ)
    !
  ELSE
    !
    !*      9.3    For town
    !              --------
    !
    ZUSTAR2(JJ)=XUNDEF
    !  
    IF(HIMPLICIT_WIND=='OLD')THEN
      !   old implicitation
      ZUSTAR2(JJ) = (PCD(JJ)*PVMOD(JJ)*PPEW_B_COEF(JJ))/            &
                    (1.0-PRHOA(JJ)*PCD(JJ)*PVMOD(JJ)*PPEW_A_COEF(JJ))
    ELSE
      !   new implicitation
      ZUSTAR2(JJ) = (PCD(JJ)*PVMOD(JJ)*(2.*PPEW_B_COEF(JJ)-PVMOD(JJ)))/ &
                    (1.0-2.0*PRHOA(JJ)*PCD(JJ)*PVMOD(JJ)*PPEW_A_COEF(JJ)) 
      ! 
      ZVMOD(JJ) = PRHOA(JJ)*PPEW_A_COEF(JJ)*ZUSTAR2(JJ) + PPEW_B_COEF(JJ)
      ZVMOD(JJ) = MAX(ZVMOD(JJ),0.)
      !
      IF(PPEW_A_COEF(JJ)/= 0.)THEN
        ZUSTAR2(JJ) = MAX( ( ZVMOD(JJ) - PPEW_B_COEF(JJ) ) / (PRHOA(JJ)*PPEW_A_COEF(JJ)), 0.)
      ENDIF
      !                        
    ENDIF
    !
    PUSTAR_TOWN(JJ) = SQRT(ZUSTAR2(JJ))
	PUSTAR_TOWN(JJ) = MAX(PUSTAR_TOWN(JJ), 0.1)
    !
  ENDIF
  !
ENDDO
!

! Increase PCH_TOP according to U*
k_ustar = sigmoida(PUSTAR_TOWN)
!PCH_TOP = PCH_TOP * k_ustar
!PAC_TOP = PAC_TOP * k_ustar



IF (LHOOK) CALL DR_HOOK('URBAN_DRAG',1,ZHOOK_HANDLE)
!-------------------------------------------------------------------------------
!

contains
 
FUNCTION sigmoida(PUSTAR_TOWN)
    REAL, DIMENSION(1) :: sigmoida
	REAL, DIMENSION(1) :: f_night     
	REAL, DIMENSION(1) :: f_day     
	REAL, DIMENSION(1) :: arg_night
	REAL, DIMENSION(1) :: arg_day
	REAL, DIMENSION(1) :: s_u
	REAL, DIMENSION(1) :: u0
	REAL, DIMENSION(1) :: PUSTAR_TOWN

	REAL, DIMENSION(1) :: k_min        ! Asymptote when U* -> 0
	REAL, DIMENSION(1) :: k_max        ! Asymptote when U* -> ∞
	REAL, DIMENSION(1) :: M            ! Multiplier when U* = 0.55
	REAL, DIMENSION(1) :: u_night      ! U* night
	REAL, DIMENSION(1) :: u_day        ! U* day

	! constants for calculation of anthropogenic heat, see Flanner, 2009
	k_min        = 0.9   
	k_max        = 3.
	M            = 2.      
	u_night      = 0.3 
	u_day        = 0.55    
     
    ! Sigmoida calculation
    f_night = (1.0 - k_min) / (k_max - k_min)
    f_day   = (M - k_min) / (k_max - k_min)
    arg_night = LOG(f_night / (1.0 - f_night))
    arg_day   = LOG(f_day   / (1.0 - f_day))
    
    s_u = (u_day - u_night) / (arg_day - arg_night)
    u0 = u_night - s_u * arg_night
	
	sigmoida = k_min + (k_max - k_min) / (1.0 + EXP(-(PUSTAR_TOWN - u0) / s_u))

	return
END FUNCTION sigmoida


END SUBROUTINE URBAN_DRAG

