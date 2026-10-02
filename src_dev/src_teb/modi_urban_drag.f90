!auto_modi:spll_urban_drag.D
MODULE MODI_URBAN_DRAG
INTERFACE
    SUBROUTINE URBAN_DRAG(icell, iblock, TOP, T, B, HIMPLICIT_WIND, PTSTEP, PTIME, PT_CANYON, PQ_CANYON, &
                          PU_CANYON, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN, PZ_LOWCAN,   &
                          PTS_ROOF, PTS_ROAD, PTS_WALL, PTS_GARDEN, PQS_GARDEN,    &
                          PDELT_SNOW_ROOF, PDELT_SNOW_ROAD,  PTAU, PEXNS, PEXNA, PTA,    &
                          PQA, PPS, PRHOA,PZREF, PUREF, PVMOD, PWS_ROOF_MAX,       &
                          PWS_ROAD_MAX, PPEW_A_COEF, PPEW_B_COEF,                  &
                          PPEW_A_COEF_LOWCAN, PPEW_B_COEF_LOWCAN, PZ0_GARDEN_EXT, PZ0_GREENROOF_EXT,  &
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
                          PRI_GARDEN_ATM, ZZ0H_GARDEN_ATM,                  &
                          PAC_ROAD_ATM_WAT,                                              &
!MV202609 greenroof-to-atm exchange diagnostics
                          PAC_GREENROOF_ATM, PCD_GREENROOF_ATM, PCDN_GREENROOF_ATM,       &
                          PCH_GREENROOF_ATM, PRI_GREENROOF_ATM, ZZ0H_GREENROOF_ATM   ) 
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_n, ONLY : TEB_t
USE MODD_BEM_n, ONLY : BEM_t
IMPLICIT NONE
INTEGER                           :: icell
INTEGER                           :: iblock 
TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: TOP
TYPE(TEB_t), INTENT(INOUT) :: T
TYPE(BEM_t), INTENT(INOUT) :: B
CHARACTER(LEN=*),     INTENT(IN)  :: HIMPLICIT_WIND   ! wind implicitation option
REAL,               INTENT(IN)    :: PTSTEP         ! time-step
REAL, INTENT(IN)    :: PTIME         ! current time since midnight (UTC, s)
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
REAL, DIMENSION(:), INTENT(IN)    :: PVMOD          ! module of the horizontal wind
REAL, DIMENSION(:), INTENT(IN)    :: PPS            ! pressure at the surface
REAL, DIMENSION(:), INTENT(IN)    :: PEXNA          ! exner function
REAL, DIMENSION(:), INTENT(IN)    :: PRHOA          ! air density
REAL, DIMENSION(:), INTENT(IN)    :: PZREF          ! reference height of the first
REAL, DIMENSION(:), INTENT(IN)    :: PUREF          ! reference height of the first
REAL, DIMENSION(:), INTENT(IN)    :: PWS_ROOF_MAX   ! maximum deepness of roof
REAL, DIMENSION(:), INTENT(IN)    :: PWS_ROAD_MAX   ! and water reservoirs (kg/m2)
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_A_COEF    ! implicit coefficients (m2s/kg)
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_B_COEF    ! for wind coupling     (m/s)
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_A_COEF_LOWCAN ! implicit coefficients for wind coupling (m2s/kg)
REAL, DIMENSION(:), INTENT(IN)    :: PPEW_B_COEF_LOWCAN ! between low canyon wind and road (m/s)
REAL, DIMENSION(:), INTENT(IN)    :: PZ0_GARDEN_EXT     ! garden roughness length
REAL, DIMENSION(:), INTENT(IN)    :: PZ0_GREENROOF_EXT  ! greenroof roughness length
REAL, DIMENSION(:), INTENT(IN)    :: PTSRAD_GR     !
REAL, DIMENSION(:), INTENT(IN)    :: PRUNOFF_GR     !

REAL, DIMENSION(:), INTENT(OUT)   :: PQSAT_ROOF     ! qsat(Ts)
REAL, DIMENSION(:), INTENT(OUT)   :: PQSAT_ROAD     ! qsat(Ts)
REAL, DIMENSION(:), INTENT(OUT)   :: PDELT_ROOF     ! water fraction on
REAL, DIMENSION(:), INTENT(OUT)   :: PDELT_ROAD     ! snow-free surfaces
REAL, DIMENSION(:), INTENT(OUT)   :: PCD            ! drag coefficient
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN           ! neutral drag coefficient
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROOF       ! aerodynamical conductance
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROOF_WAT   ! aerodynamical conductance (for water)
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_WALL       ! aerodynamical conductance
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROAD_CAN       ! aerodynamical conductance
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_ROAD_WAT   ! aerodynamical conductance
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_TOP        ! aerodynamical conductance
REAL, DIMENSION(:), INTENT(IN)    :: PAC_GARDEN_CAN     ! aerodynamical conductance
REAL, DIMENSION(:), INTENT(OUT)   :: PRI            ! Town Richardson number
REAL, DIMENSION(:), INTENT(OUT)   :: PUW_ROAD       ! Momentum flux for roads
REAL, DIMENSION(:), INTENT(OUT)   :: PUW_ROOF       ! Momentum flux for roofs
REAL, DIMENSION(:), INTENT(OUT)   :: PDUWDU_ROAD    ! 
REAL, DIMENSION(:), INTENT(OUT)   :: PDUWDU_ROOF    ! 
REAL, DIMENSION(:), INTENT(OUT)   :: PUSTAR_TOWN    ! Fraction velocity for town
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
!MV202609 greenroof-to-atm exchange diagnostics
REAL, DIMENSION(:), INTENT(OUT)   :: PAC_GREENROOF_ATM ! greenroof aerodynamical conductance (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCD_GREENROOF_ATM ! greenroof surf. exchange coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCDN_GREENROOF_ATM! greenroof neutral drag coefficient (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PCH_GREENROOF_ATM ! greenroof drag coefficient for heat (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: PRI_GREENROOF_ATM ! greenroof Richardson number (atm.)
REAL, DIMENSION(:), INTENT(OUT)   :: ZZ0H_GREENROOF_ATM! greenroof roughness length for heat (atm.)

END SUBROUTINE URBAN_DRAG
END INTERFACE
END MODULE MODI_URBAN_DRAG
