!auto_modi:spll_avg_urban_fluxes.D
MODULE MODI_AVG_URBAN_FLUXES
INTERFACE
    SUBROUTINE AVG_URBAN_FLUXES(icell, iblock, TOP, T, B, TPN, DMT,                               &
                                PTS_TWN, PEMIS_TWN,  PT_CAN,                       &
                                PQ_CAN, PT_LOWCAN, PQ_LOWCAN, PTA, PQA, PRHOA, PPS,&
                                PH_TRAFFIC, PLE_TRAFFIC, PWL_O_GRND, PESN_RF,      &
                                PEMIS_GR, PLW_RAD, PAC_RF, PAC_RF_WAT, PAC_WL,     &
                                PAC_RD, PAC_RD_WAT, PAC_TOP, PAC_GD, PQSAT_GD,     &
                                PAC_AGG_GD, PHU_AGG_GD, PQSAT_RF, PQSAT_RD,        &
                                PDELT_RF, PDELT_RD, PRF_FRAC, PWL_FRAC, PRD_FRAC,  &
                                PGD_FRAC, PTOTS_O_HORS, PDF_RF, PDN_RF, PDF_RD,    &
                                PDN_RD, PLE_WL_A, PLE_WL_B, PLEW_RF, PLESN_RF,     &
                                PLEW_RD, PLESN_RD, PHSN_RD,                        &
                                PTSRAD_GD, PRN_GD, PH_GD, PLE_GD, PGFLUX_GD, PEVAP_GD,&
!MV202609 tau scheme of the garden (atmosphere branch of the garden fluxes)
                                PH_GD_ATM, PLE_GD_ATM,                       &
                                PRUNOFF_GD, PEVAP_GR, PRUNOFF_GR, PDRAIN_GR,       &
                                PRN_GRND, PH_GRND, PLE_GRND, PGFLX_GRND,           &
                                PRN_TWN, PH_TWN, PLE_TWN, PGFLX_TWN, PEVAP_TWN,    &
                                PEMIT_LW_RD, PEMIT_LW_GD, PEMIT_LW_GRND, PEMIS_GD, PLW_UP, &
!MV202609 tau scheme of the road
                                PTAU,                                        &
!MV202609 tau scheme of the road (revision: three-temperature construction)
                                PH_ROAD_ATM, PLE_ROAD_ATM, PCD_ROAD_ATM,     &
                                ZZ0H_ROAD_ATM, PZREF, PVMOD,                 &
                                PT_CAN0, PT_CAN1, PPHI_CAN1,                 &
                                PQ_CAN0, PQ_CAN1,                             &
!MV202609 tau scheme of the road (revision: snow-to-atmosphere branch)
                                PHSN_RD_CAN, PHSN_RD_ATM, PLESN_RD_CAN, PLESN_RD_ATM)
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_n, ONLY : TEB_t
USE MODD_BEM_n, ONLY : BEM_t
USE MODD_TEB_PANEL_n, ONLY : TEB_PANEL_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
IMPLICIT NONE
INTEGER                           :: icell
INTEGER                           :: iblock 
TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: TOP
TYPE(TEB_t), INTENT(INOUT) :: T
TYPE(BEM_t), INTENT(INOUT) :: B
TYPE(TEB_PANEL_t), INTENT(INOUT) :: TPN
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT
!
REAL, DIMENSION(:), INTENT(OUT)   :: PTS_TWN           ! town surface temperature
REAL, DIMENSION(:), INTENT(OUT)   :: PEMIS_TWN         ! town equivalent emissivity
REAL, DIMENSION(:), INTENT(INOUT) :: PT_CAN            ! canyon air temperature
REAL, DIMENSION(:), INTENT(INOUT) :: PQ_CAN            ! canyon air specific humidity
REAL, DIMENSION(:), INTENT(IN)    :: PT_LOWCAN         ! low canyon air temperature
REAL, DIMENSION(:), INTENT(IN)    :: PQ_LOWCAN         ! low canyon air specific humidity
!
REAL, DIMENSION(:), INTENT(IN)    :: PTA               ! temperature at roof level
REAL, DIMENSION(:), INTENT(IN)    :: PQA               ! specific humidity
                                                       ! at roof level
REAL, DIMENSION(:), INTENT(IN)    :: PRHOA             ! air density
                                                       ! at the lowest level
REAL, DIMENSION(:), INTENT(IN)    :: PPS               ! surface pressure
REAL, DIMENSION(:), INTENT(IN)    :: PH_TRAFFIC        ! anthropogenic sensible
!                                                      ! heat fluxes due to traffic
REAL, DIMENSION(:), INTENT(IN)    :: PLE_TRAFFIC       ! anthropogenic latent
!                                                      ! heat fluxes due to traffic
REAL, DIMENSION(:), INTENT(IN)    :: PWL_O_GRND        ! wall Surf. / ground (road+green) Surf.
!   
REAL, DIMENSION(:), INTENT(IN)    :: PESN_RF           ! snow roof emissivity
!
REAL, DIMENSION(:), INTENT(IN)    :: PEMIS_GR          ! green roof emissivity
!
REAL, DIMENSION(:), INTENT(IN)    :: PLW_RAD           ! incoming longwave rad.
!
REAL, DIMENSION(:), INTENT(IN)    :: PAC_RF            ! surface conductance
!                                                      ! for heat transfers
!                                                      ! above roofs
REAL, DIMENSION(:), INTENT(IN)    :: PAC_RF_WAT        ! surface conductance
!                                                      ! for heat transfers
!                                                      ! above roofs (for water)
REAL, DIMENSION(:), INTENT(IN)    :: PAC_WL            ! surface conductance
!                                                      ! for heat transfer
!                                                      ! between wall and canyon
REAL, DIMENSION(:), INTENT(IN)    :: PAC_RD            ! surface conductance
!                                                      ! for heat transfers
!                                                      ! between road and canyon
REAL, DIMENSION(:), INTENT(IN)    :: PAC_RD_WAT        ! surface conductance
!                                                      ! for heat transfers
!                                                      ! inside canyon (for water)
REAL, DIMENSION(:), INTENT(IN)    :: PAC_TOP           ! aerodynamical conductance
!                                                      ! between atmosphere and
!                                                      ! canyon top
REAL, DIMENSION(:), INTENT(IN)    :: PAC_GD            ! aerodynamical conductance
!                                                      ! between atmosphere and
!                                                      ! green areas
REAL, DIMENSION(:), INTENT(IN)    :: PQSAT_GD      ! q_sat(Ts)
REAL, DIMENSION(:), INTENT(IN)    :: PAC_AGG_GD    ! aggregated aerodyn resistance for green areas
REAL, DIMENSION(:), INTENT(IN)    :: PHU_AGG_GD    ! aggregated relative humidity for green areas
!
REAL, DIMENSION(:), INTENT(IN)    :: PQSAT_RF        ! q_sat(Ts)
REAL, DIMENSION(:), INTENT(IN)    :: PQSAT_RD        ! q_sat(Ts)
REAL, DIMENSION(:), INTENT(IN)    :: PDELT_RF        ! water fraction on snow-free
REAL, DIMENSION(:), INTENT(IN)    :: PDELT_RD        ! roof and roads
REAL, DIMENSION(:), INTENT(IN)    :: PRF_FRAC        ! roof, wall,
REAL, DIMENSION(:), INTENT(IN)    :: PWL_FRAC        ! road, and green area
REAL, DIMENSION(:), INTENT(IN)    :: PRD_FRAC        ! fractions
REAL, DIMENSION(:), INTENT(IN)    :: PGD_FRAC        ! of exchange surf.
REAL, DIMENSION(:), INTENT(IN)    :: PTOTS_O_HORS    ! total canyon+roof surface
!                                                    ! over horizontal surface
REAL, DIMENSION(:), INTENT(IN)    :: PDF_RF          ! snow-free    roof fraction
REAL, DIMENSION(:), INTENT(IN)    :: PDN_RF          ! snow-covered roof fraction
REAL, DIMENSION(:), INTENT(IN)    :: PDF_RD          ! snow-free    road fraction
REAL, DIMENSION(:), INTENT(IN)    :: PDN_RD          ! snow-covered road fraction
!
REAL, DIMENSION(:), INTENT(IN)    :: PLE_WL_A        ! latent heat flux over wall
REAL, DIMENSION(:), INTENT(IN)    :: PLE_WL_B        ! latent heat flux over wall
!
REAL, DIMENSION(:), INTENT(IN)    :: PLEW_RF         ! latent heat flux of snowfree roof
REAL, DIMENSION(:), INTENT(IN)    :: PLESN_RF        ! latent heat flux over snow
REAL, DIMENSION(:), INTENT(IN)    :: PLEW_RD         ! latent heat flux of snowfree road
REAL, DIMENSION(:), INTENT(IN)    :: PLESN_RD        ! latent heat flux over snow
REAL, DIMENSION(:), INTENT(IN)    :: PHSN_RD         ! sensible heat flux over snow

REAL, DIMENSION(:), INTENT(IN)    :: PTSRAD_GD     ! green area surface temperature
REAL, DIMENSION(:), INTENT(IN)    :: PRN_GD        ! net radiation over green areas
REAL, DIMENSION(:), INTENT(IN)    :: PH_GD         ! sensible heat flux over green areas
REAL, DIMENSION(:), INTENT(IN)    :: PLE_GD        ! latent heat flux over green areas
!MV202609 tau scheme of the garden (atmosphere branch of the garden fluxes)
REAL, DIMENSION(:), INTENT(IN)    :: PH_GD_ATM     ! garden sensible heat flux towards the atmosphere [W m-2 garden]
REAL, DIMENSION(:), INTENT(IN)    :: PLE_GD_ATM    ! garden latent  heat flux towards the atmosphere [W m-2 garden]
REAL, DIMENSION(:), INTENT(IN)    :: PGFLUX_GD     ! flux through the green areas
REAL, DIMENSION(:), INTENT(IN)    :: PEVAP_GD      ! evaporation over gardens
REAL, DIMENSION(:), INTENT(IN)    :: PRUNOFF_GD    ! surface runoff over green areas      (kg/m2/s)
REAL, DIMENSION(:), INTENT(IN)    :: PEVAP_GR      ! evaporation over green roofs
REAL, DIMENSION(:), INTENT(IN)    :: PRUNOFF_GR    ! surface runoff over green roofs      (kg/m2/s)
REAL, DIMENSION(:), INTENT(IN)    :: PDRAIN_GR     ! outlet drainage at green roof base   (kg/m2/s)
!
!
REAL, DIMENSION(:), INTENT(OUT)   :: PRN_GRND         ! net radiation over ground
REAL, DIMENSION(:), INTENT(OUT)   :: PH_GRND          ! sensible heat flux over ground
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_GRND         ! latent heat flux over ground
REAL, DIMENSION(:), INTENT(OUT)   :: PGFLX_GRND       ! flux through the ground
REAL, DIMENSION(:), INTENT(OUT)   :: PRN_TWN          ! net radiation over town
REAL, DIMENSION(:), INTENT(OUT)   :: PH_TWN           ! sensible heat flux over town
REAL, DIMENSION(:), INTENT(OUT)   :: PLE_TWN          ! latent heat flux over town
REAL, DIMENSION(:), INTENT(OUT)   :: PGFLX_TWN        ! flux through the ground for town
REAL, DIMENSION(:), INTENT(OUT)   :: PEVAP_TWN        ! evaporation (kg/m2/s)
!
REAL, DIMENSION(:), INTENT(IN)    :: PEMIT_LW_RD   ! LW emitted by the road (W/m2 road)
REAL, DIMENSION(:), INTENT(IN)    :: PEMIT_LW_GD   ! LW emitted by the garden (W/m2 garden)
REAL, DIMENSION(:), INTENT(OUT)   :: PEMIT_LW_GRND ! LW emitted by the ground (road+garden) (W/m2 ground)
!
REAL, DIMENSION(:), INTENT(IN)    :: PEMIS_GD  ! garden emissivity
REAL, DIMENSION(:), INTENT(OUT)   :: PLW_UP    ! upwards longwave radiation
!MV202609 tau scheme of the road
REAL, DIMENSION(:), INTENT(IN)    :: PTAU      ! tau scheme weight of the canyon path (-)
!MV202609 tau scheme of the road (revision: three-temperature construction)
REAL, DIMENSION(:), INTENT(IN)    :: PH_ROAD_ATM    ! road sensible heat flux towards the atmosphere [W m-2 road]
REAL, DIMENSION(:), INTENT(IN)    :: PLE_ROAD_ATM   ! road latent  heat flux towards the atmosphere [W m-2 road]
REAL, DIMENSION(:), INTENT(IN)    :: PCD_ROAD_ATM   ! road drag coefficient to the atmosphere (-)
REAL, DIMENSION(:), INTENT(IN)    :: ZZ0H_ROAD_ATM  ! road roughness length for heat to the atmosphere (m)
REAL, DIMENSION(:), INTENT(IN)    :: PZREF          ! reference height of the forcing level (m)
REAL, DIMENSION(:), INTENT(IN)    :: PVMOD          ! wind speed at the forcing level (m s-1)
REAL, DIMENSION(:), INTENT(OUT)   :: PT_CAN0        ! canyon air temperature without tau (K)
REAL, DIMENSION(:), INTENT(OUT)   :: PT_CAN1        ! free layer (second canopy) air temperature (K)
REAL, DIMENSION(:), INTENT(OUT)   :: PPHI_CAN1      ! free layer air temperature / theta* ratio of the MOST profile (-)
REAL, DIMENSION(:), INTENT(OUT)   :: PQ_CAN0        ! canyon air humidity without tau (kg kg-1)
REAL, DIMENSION(:), INTENT(OUT)   :: PQ_CAN1        ! free layer air humidity (kg kg-1)
!MV202609 tau scheme of the road (revision: snow-to-atmosphere branch)
REAL, DIMENSION(:), INTENT(IN)    :: PHSN_RD_CAN    ! snow -> canyon air sensible heat flux (W/m2 road snow)
REAL, DIMENSION(:), INTENT(IN)    :: PHSN_RD_ATM    ! snow -> forcing level sensible heat flux (W/m2 road snow)
REAL, DIMENSION(:), INTENT(IN)    :: PLESN_RD_CAN   ! snow -> canyon air latent heat flux (W/m2 road snow)
REAL, DIMENSION(:), INTENT(IN)    :: PLESN_RD_ATM   ! snow -> forcing level latent heat flux (W/m2 road snow)

END SUBROUTINE AVG_URBAN_FLUXES
END INTERFACE
END MODULE MODI_AVG_URBAN_FLUXES
