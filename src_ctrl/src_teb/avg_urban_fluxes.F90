!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt  
!SFX_LIC for details. version 1.
!     #########
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
                                PRUNOFF_GD, PEVAP_GR, PRUNOFF_GR, PDRAIN_GR,       &
                                PRN_GRND, PH_GRND, PLE_GRND, PGFLX_GRND,           &
                                PRN_TWN, PH_TWN, PLE_TWN, PGFLX_TWN, PEVAP_TWN,    &
                                PEMIT_LW_RD, PEMIT_LW_GD, PEMIT_LW_GRND, PEMIS_GD, PLW_UP)
!   ##########################################################################
!
!!****  *AVG_URBAN_FLUXES* computes fluxes on urbanized surfaces  
!!
!!    PURPOSE
!!    -------
!         
!     
!!**  METHOD
!     ------
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
!!                     12/02 (A. Lemonsu) modifications of emissivity and Tstown
!!                     07/07 (P. LeMoigne) expression of latent heat fluxes as 
!!                           functions of w'theta' instead of w'T'
!!                     17/10 (G. Pigeon)  computation of anthropogenic heat due
!!                           to domestic heating
!!                     10/11 (G. Pigeon) simplification for road, garden, roof,
!!                           wall fractions
!!                     08/13 (V. Masson) adds solar panels
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_n, ONLY : TEB_t
USE MODD_BEM_n, ONLY : BEM_t
USE MODD_TEB_PANEL_n, ONLY : TEB_PANEL_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
!
USE MODD_CSTS,ONLY : XCPD, XLVTT, XLSTT, XSTEFAN
!
USE MODE_THERMOS
!
!
USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK
USE PARKIND1  ,ONLY : JPRB
!
IMPLICIT NONE
!
!*      0.1    declarations of arguments
!
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

CHARACTER(LEN=*), PARAMETER       :: RN_ROOF = 'output/RN_ROOF.txt'
CHARACTER(LEN=*), PARAMETER       :: RN_ROAD = 'output/RN_ROAD.txt'
CHARACTER(LEN=*), PARAMETER       :: RN_GD = 'output/RN_GD.txt'
CHARACTER(LEN=*), PARAMETER       :: RN_WALL_A = 'output/RN_WALL_A.txt'

CHARACTER(LEN=*), PARAMETER       :: H_ROOF = 'output/H_ROOF.txt'
CHARACTER(LEN=*), PARAMETER       :: H_ROAD = 'output/H_ROAD.txt'
CHARACTER(LEN=*), PARAMETER       :: H_GD = 'output/H_GD.txt'
CHARACTER(LEN=*), PARAMETER       :: H_WALL_A = 'output/H_WALL_A.txt'

CHARACTER(LEN=*), PARAMETER       :: LE_ROOF = 'output/LE_ROOF.txt'
CHARACTER(LEN=*), PARAMETER       :: LE_ROAD = 'output/LE_ROAD.txt'
CHARACTER(LEN=*), PARAMETER       :: LE_GD = 'output/LE_GD.txt'
CHARACTER(LEN=*), PARAMETER       :: LE_WALL_A = 'output/LE_WALL_A.txt'

CHARACTER(LEN=*), PARAMETER       :: G_ROOF = 'output/G_ROOF.txt'
CHARACTER(LEN=*), PARAMETER       :: G_ROAD = 'output/G_ROAD.txt'
CHARACTER(LEN=*), PARAMETER       :: G_GD = 'output/G_GD.txt'
CHARACTER(LEN=*), PARAMETER       :: G_WALL_A = 'output/G_WALL_A.txt'



!
!*      0.2    declarations of local variables
!
INTEGER                           :: icell
INTEGER                           :: iblock 
!REAL, DIMENSION(SIZE(PLW_RAD))    :: ZLW_UP            ! upwards radiations
REAL, DIMENSION(SIZE(T%XROAD)) :: ZQSAT_CAN
REAL, DIMENSION(SIZE(T%XROAD)) :: ZRD, ZGD
!
REAL :: ZINTER
INTEGER :: JJ
REAL(KIND=JPRB) :: ZHOOK_HANDLE
!-------------------------------------------------------------------------------
!
IF (LHOOK) CALL DR_HOOK('AVG_URBAN_FLUXES',0,ZHOOK_HANDLE)
!
ZRD(:)=0.
ZGD(:)=0.
!
DO JJ=1,SIZE(T%XROAD)
!  
  IF (T%XROAD(JJ)+T%XGARDEN(JJ).NE.0.) THEN
    ZRD(JJ)  = T%XROAD(JJ)   / (T%XROAD(JJ)+T%XGARDEN(JJ))
    ZGD(JJ) =  T%XGARDEN(JJ) / (T%XROAD(JJ)+T%XGARDEN(JJ))
  ELSE
    ZRD(JJ)=0.
    ZGD(JJ)=0.
  ENDIF
!
!*      1.     Averaged fluxes for ground (green areas + road)
!              -----------------------------------------------
!
  PRN_GRND(JJ)    = ZRD(JJ) * DMT%XRN_ROAD   (JJ) + ZGD(JJ) * PRN_GD(JJ)
  
!
  PH_GRND (JJ)    = ZRD(JJ) *  DMT%XH_ROAD   (JJ) + ZGD(JJ) * PH_GD (JJ) + PH_TRAFFIC (JJ) / (1.-T%XBLD (JJ))
!

  PLE_GRND(JJ)    = ZRD(JJ) * DMT%XLE_ROAD   (JJ) + ZGD(JJ) * PLE_GD(JJ) + PLE_TRAFFIC(JJ) / (1.-T%XBLD (JJ))
!
  PGFLX_GRND(JJ)  = ZRD(JJ) * DMT%XGFLUX_ROAD(JJ) + ZGD(JJ) * PGFLUX_GD(JJ)
!
!
  PEMIT_LW_GRND(JJ) = T%XROAD_O_GRND(JJ) * PEMIT_LW_RD(JJ) + T%XGARDEN_O_GRND(JJ) * PEMIT_LW_GD(JJ)
!-------------------------------------------------------------------------------
!
!*      2.     Averaged fluxes JJ built + green areas
!              -------------------------------------
!
  PRN_TWN(JJ)    = PTOTS_O_HORS(JJ) * ( &
                 + PRF_FRAC(JJ) * DMT%XRN_ROOF   (JJ)                  &
                 + PRD_FRAC(JJ) * DMT%XRN_ROAD   (JJ)                  &
                 + PGD_FRAC(JJ) * PRN_GD         (JJ)                  &
                 + PWL_FRAC(JJ) * DMT%XRN_WALL_A (JJ) * 0.5            &
                 + PWL_FRAC(JJ) * DMT%XRN_WALL_B (JJ) * 0.5 )  
!
  PH_TWN (JJ)    = PTOTS_O_HORS(JJ) * ( &
                 + PRF_FRAC(JJ) * DMT%XH_ROOF   (JJ)                   &
                 + PRD_FRAC(JJ) * DMT%XH_ROAD   (JJ)                   &
                 + PGD_FRAC(JJ) * PH_GD         (JJ)                   &
                 + PWL_FRAC(JJ) * DMT%XH_WALL_A (JJ) * 0.5             &
                 + PWL_FRAC(JJ) * DMT%XH_WALL_B (JJ) * 0.5 )           &
                 + PH_TRAFFIC(JJ) + T%XH_INDUSTRY(JJ)  
 
!  OPEN(UNIT=34, FILE = H_ROOF, ACCESS = 'APPEND')
!  WRITE(34,*) DMT%XH_ROOF
!  CLOSE(34)
  
!  OPEN(UNIT=35, FILE = H_ROAD, ACCESS = 'APPEND')
!  WRITE(35,*) DMT%XH_ROAD
!  CLOSE(35)
  
!  OPEN(UNIT=36, FILE = H_GD, ACCESS = 'APPEND')
!  WRITE(36,*) PH_GD
!  CLOSE(36)
  
!  OPEN(UNIT=37, FILE = H_WALL_A, ACCESS = 'APPEND')
!  WRITE(37,*) DMT%XH_WALL_A
!  CLOSE(37)

!
!IF (icell == 5 .AND. iblock == 2532) THEN
!	print*, 'PTOTS_O_HORS        (JJ) = ', PTOTS_O_HORS        (JJ)
!	print*, 'PRF_FRAC        (JJ) = ', PRF_FRAC        (JJ)
!	print*, 'DMT%XLE_ROOF        (JJ) = ', DMT%XLE_ROOF        (JJ)
!    print*, 'PRD_FRAC        (JJ) = ', PRD_FRAC        (JJ)
!	print*, 'DMT%XLE_ROAD        (JJ) = ', DMT%XLE_ROAD        (JJ)
!	print*, 'PGD_FRAC        (JJ) = ', PGD_FRAC        (JJ)
!	print*, 'PLE_GD        (JJ) = ', PLE_GD        (JJ)
!	print*, 'PWL_FRAC        (JJ) = ', PWL_FRAC        (JJ)
!	print*, 'PLE_WL_A(JJ)        (JJ) = ', PLE_WL_A(JJ)        
!	print*, 'PLE_WL_B(JJ)        (JJ) = ', PLE_WL_B(JJ)        
!	print*, 'PLE_TRAFFIC(JJ)        (JJ) = ', PLE_TRAFFIC(JJ)
!    print*, 'T%XLE_INDUSTRY(JJ)        (JJ) = ', T%XLE_INDUSTRY(JJ)        
!ENDIF
  PLE_TWN(JJ)    = PTOTS_O_HORS(JJ) * ( &
                   PRF_FRAC(JJ) * DMT%XLE_ROOF  (JJ)                   &
                 + PRD_FRAC(JJ) * DMT%XLE_ROAD  (JJ)                   &
                 + PGD_FRAC(JJ) * PLE_GD        (JJ)                   &
                 + PWL_FRAC(JJ) * PLE_WL_A(JJ) * 0.5             &
                 + PWL_FRAC(JJ) * PLE_WL_B(JJ) * 0.5 )           &
                 + PLE_TRAFFIC (JJ) + T%XLE_INDUSTRY(JJ)  

!IF (icell == 5 .AND. iblock == 2532) THEN
!	print*, 'PLE_TWN        (JJ) = ', PLE_TWN        (JJ)
!ENDIF	

!  OPEN(UNIT=38, FILE = LE_ROOF, ACCESS = 'APPEND')
!  WRITE(38,*) DMT%XLE_ROOF
!  CLOSE(38)
  
!  OPEN(UNIT=39, FILE = LE_ROAD, ACCESS = 'APPEND')
!  WRITE(39,*) DMT%XLE_ROAD
!  CLOSE(39)
  
!  OPEN(UNIT=40, FILE = LE_GD, ACCESS = 'APPEND')
!  WRITE(40,*) PLE_GD
!  CLOSE(40)
  
!  OPEN(UNIT=41, FILE = LE_WALL_A, ACCESS = 'APPEND')
!  WRITE(41,*) PLE_WL_A
!  CLOSE(41)

!
  PGFLX_TWN(JJ)= PTOTS_O_HORS(JJ) * ( &
                  PRF_FRAC(JJ) * DMT%XGFLUX_ROOF  (JJ)                 &
                + PRD_FRAC(JJ) * DMT%XGFLUX_ROAD  (JJ)                 &
                + PGD_FRAC(JJ) * PGFLUX_GD        (JJ)                 &
                + PWL_FRAC(JJ) * DMT%XGFLUX_WALL_A(JJ) * 0.5           &
                + PWL_FRAC(JJ) * DMT%XGFLUX_WALL_B(JJ) * 0.5 )   
  
!  OPEN(UNIT=42, FILE = G_ROOF, ACCESS = 'APPEND')
!  WRITE(42,*) DMT%XGFLUX_ROOF
!  CLOSE(42)
  
!  OPEN(UNIT=43, FILE = G_ROAD, ACCESS = 'APPEND')
!  WRITE(43,*) DMT%XGFLUX_ROAD
!  CLOSE(43)
  
!  OPEN(UNIT=44, FILE = G_GD, ACCESS = 'APPEND')
!  WRITE(44,*) PGFLUX_GD
!  CLOSE(44)
  
!  OPEN(UNIT=45, FILE = G_WALL_A, ACCESS = 'APPEND')
!  WRITE(45,*) DMT%XGFLUX_WALL_A
!  CLOSE(45)

!
  IF (TOP%LSOLAR_PANEL) THEN
    PRN_TWN(JJ) = PRN_TWN(JJ) + PTOTS_O_HORS(JJ) * (PRF_FRAC(JJ) * DMT%XRN_PANEL(JJ) * TPN%XFRAC_PANEL(JJ))
    PH_TWN (JJ) = PH_TWN (JJ) + PTOTS_O_HORS(JJ) * (PRF_FRAC(JJ) * DMT%XH_PANEL (JJ) * TPN%XFRAC_PANEL(JJ))
  ENDIF
!-------------------------------------------------------------------------------
!
!*      3.     Infra-red Radiative properties
!              ------------------------------
!
!*      3.1    Upward IR radiation for town
!              ----------------------------
!
  PLW_UP(JJ) = PLW_RAD  (JJ)      &
            - ( PRF_FRAC(JJ) * (1.-T%XGREENROOF(JJ)) * PDF_RF(JJ) * DMT%XABS_LW_ROOF     (JJ) &
               +PRF_FRAC(JJ) * (1.-T%XGREENROOF(JJ)) * PDN_RF(JJ) * DMT%XABS_LW_SNOW_ROOF(JJ) &
               +PRF_FRAC(JJ) *     T%XGREENROOF(JJ)               * DMT%XABS_LW_GREENROOF(JJ) &
               +PRD_FRAC(JJ)                         * PDF_RD(JJ) * DMT%XABS_LW_ROAD     (JJ) &
               +PRD_FRAC(JJ)                         * PDN_RD(JJ) * DMT%XABS_LW_SNOW_ROAD(JJ) &
               +PGD_FRAC(JJ)                                      * DMT%XABS_LW_GARDEN   (JJ) &
               +PWL_FRAC(JJ)* 0.5                                 * DMT%XABS_LW_WALL_A (JJ) &
               +PWL_FRAC(JJ)* 0.5                                 * DMT%XABS_LW_WALL_B (JJ) &
              ) * PTOTS_O_HORS(JJ)  
!
  IF (TOP%LSOLAR_PANEL) THEN
    PLW_UP(JJ) = PLW_UP(JJ) - PTOTS_O_HORS(JJ) * (PRF_FRAC(JJ) * DMT%XABS_LW_PANEL(JJ) * TPN%XFRAC_PANEL(JJ))
  ENDIF
!
!*      3.2    Town emissivity
!              ---------------
!

    PEMIS_TWN(JJ) = T%XBLD       (JJ) * (1.-T%XGREENROOF(JJ)) * PDF_RF(JJ) * T%XEMIS_ROOF(JJ) * (1.-TPN%XFRAC_PANEL(JJ)) &
                  + T%XBLD       (JJ) * (1.-T%XGREENROOF(JJ)) * PDN_RF(JJ) * PESN_RF     (JJ) * (1.-TPN%XFRAC_PANEL(JJ)) &
                  + T%XBLD       (JJ) *     T%XGREENROOF(JJ)               * PEMIS_GR    (JJ) * (1.-TPN%XFRAC_PANEL(JJ)) &
                  + T%XBLD       (JJ)                                   * TPN%XEMIS_PANEL(JJ) *      TPN%XFRAC_PANEL(JJ) &
                  + T%XROAD      (JJ) * ( T%XSVF_ROAD(JJ)     * PDF_RD(JJ) * T%XEMIS_ROAD(JJ)                       &
                                      +   T%XSVF_ROAD(JJ)     * PDN_RD(JJ) * T%TSNOW_ROAD%EMIS(JJ))                 &
                  + T%XGARDEN    (JJ) *    T%XSVF_GARDEN(JJ)               * PEMIS_GD    (JJ)                       &
                  + T%XWALL_O_HOR(JJ) *    T%XSVF_WALL  (JJ)               * T%XEMIS_WALL(JJ) 
!
!*      3.3    Town radiative surface temperature
!              ----------------------------------
!
  PTS_TWN(JJ)   = ((PLW_UP(JJ) - PLW_RAD(JJ)*(1.-PEMIS_TWN(JJ))) /PEMIS_TWN(JJ)/XSTEFAN)**0.25

!
!-------------------------------------------------------------------------------
!
!*      4.     Averaged evaporative flux (kg/m2/s)
!              -----------------------------------
!
  PEVAP_TWN(JJ) = PTOTS_O_HORS(JJ)*(                                                             &
                   PRF_FRAC  (JJ) * PDF_RF(JJ) * (1.-T%XGREENROOF(JJ)) * PLEW_RF   (JJ) / XLVTT  &
                 + PRF_FRAC  (JJ) * PDN_RF(JJ) * (1.-T%XGREENROOF(JJ)) * PLESN_RF  (JJ) / XLSTT  &
                 + PRF_FRAC  (JJ)              *     T%XGREENROOF(JJ)  * PEVAP_GR  (JJ)          &
                 + PRD_FRAC  (JJ) * PDF_RD(JJ)                         * PLEW_RD   (JJ) / XLVTT  &
                 + PRD_FRAC  (JJ) * PDN_RD(JJ)                         * PLESN_RD  (JJ) / XLSTT  &
                 + PGD_FRAC  (JJ)                                      * PEVAP_GD  (JJ)          &
                 + PWL_FRAC  (JJ) * 0.5                 * (PLE_WL_A(JJ) + PLE_WL_B(JJ)) / XLVTT )&
                 +                                                     PLE_TRAFFIC (JJ) / XLVTT  &
                 +                                                   T%XLE_INDUSTRY(JJ) / XLVTT
!
  IF (TOP%CBEM=="BEM") THEN
    PEVAP_TWN(JJ) = PEVAP_TWN(JJ) + PRF_FRAC  (JJ) * (1.-B%XF_WASTE_CAN(JJ)) * DMT%XLE_WASTE(JJ) / XLVTT
  ENDIF
!-------------------------------------------------------------------------------
!
!*      5.     Averaged runoff flux (kg/m2/s)
!              -----------------------------------
!
  DMT%XRUNOFF_TOWN(JJ) =  ((1.-T%XGREENROOF(JJ))* DMT%XRUNOFF_STRLROOF (JJ)                  &
                      +   T%XGREENROOF(JJ) *(PRUNOFF_GR(JJ) + PDRAIN_GR(JJ))) * T%XBLD(JJ)   &
                      +    T%XROAD    (JJ) * DMT%XRUNOFF_ROAD(JJ)                            &
                      +    T%XGARDEN  (JJ) * PRUNOFF_GD(JJ)                 
!-------------------------------------------------------------------------------
!
!*      6.    Air canyon temperature at time t+dt
!             -----------------------------------
!
  IF (.NOT. TOP%LCANOPY) THEN
  	!print*, 'avg_urban_fluxes PAC_RD = ', PAC_RD(JJ)
	!print*, 'avg_urban_fluxes PDF_RD = ', PDF_RD(JJ)
	!print*, 'avg_urban_fluxes ZRD = ', ZRD(JJ)
	!print*, 'avg_urban_fluxes PAC_GD = ', PAC_GD(JJ)
	!print*, 'avg_urban_fluxes ZGD = ', ZGD(JJ)
	!print*, 'avg_urban_fluxes PAC_WL = ', PAC_WL(JJ)
	!print*, 'avg_urban_fluxes PWL_O_GRND = ', PWL_O_GRND(JJ)
	!print*, 'avg_urban_fluxes PAC_TOP = ', PAC_TOP(JJ)
	!print*, 'avg_urban_fluxes ZINTER = ', ZINTER
	!
  	!print*, 'avg_urban_fluxes T%XT_ROAD  (JJ,1) = ', T%XT_ROAD  (JJ,1)
	!print*, 'avg_urban_fluxes T%XT_WALL_A(JJ,1) = ', T%XT_WALL_A(JJ,1)
	!print*, 'avg_urban_fluxes B%XGR(JJ) = ', B%XGR(JJ)
	!print*, 'avg_urban_fluxes T%XT_WALL_B(JJ,1) = ', T%XT_WALL_B(JJ,1)
	!print*, 'avg_urban_fluxes B%XT_WIN1 = ', B%XT_WIN1
	!print*, 'avg_urban_fluxes PTA = ', PTA(JJ)
	!print*, 'avg_urban_fluxes PH_TRAFFIC = ', PH_TRAFFIC(JJ)
	!print*, 'avg_urban_fluxes T%XBLD (JJ) = ', T%XBLD (JJ)
	
    ZINTER = PAC_RD(JJ) * PDF_RD(JJ) * ZRD (JJ) +  PAC_GD(JJ) * ZGD(JJ) + PAC_WL(JJ) * PWL_O_GRND(JJ) + PAC_TOP(JJ) 
    PT_CAN(JJ) =  (  T%XT_ROAD  (JJ,1) * PAC_RD (JJ) * PDF_RD (JJ) * ZRD(JJ)        &
                   + T%XT_WALL_A(JJ,1) * PAC_WL (JJ) * (1.-B%XGR(JJ)) * PWL_O_GRND(JJ) * 0.5 &
                   + T%XT_WALL_B(JJ,1) * PAC_WL (JJ) * (1.-B%XGR(JJ)) * PWL_O_GRND(JJ) * 0.5 &
                   + B%XT_WIN1    (JJ) * PAC_WL (JJ) *     B%XGR(JJ)  * PWL_O_GRND(JJ)       &
                   + PTA          (JJ) * PAC_TOP(JJ)                                         &
                   + PH_TRAFFIC   (JJ) / (1.-T%XBLD (JJ))               / PRHOA(JJ) / XCPD   &
                   + PHSN_RD(JJ) * PDN_RD(JJ)                           / PRHOA(JJ) / XCPD  ) &
                                            / ZINTER  
!
!	print*, 'avg_urban_fluxes PT_CAN1 = ', PT_CAN(JJ)
	
	
    PT_CAN(JJ) = PT_CAN(JJ) + ( PTSRAD_GD(JJ) * PAC_GD(JJ) * ZGD(JJ) ) / ZINTER
	
!	print*, 'avg_urban_fluxes PT_CAN2 = ', PT_CAN(JJ)
!	print*, 'avg_urban_fluxes PTSRAD_GD = ', PTSRAD_GD(JJ)
    IF (TOP%CBEM=="BEM") THEN
      PT_CAN(JJ) = PT_CAN(JJ) + (DMT%XH_WASTE(JJ) * B%XF_WASTE_CAN(JJ) / (1-T%XBLD(JJ)) / PRHOA(JJ) / XCPD) / ZINTER
    ENDIF
!IF (icell == 5 .AND. iblock == 2532) THEN
!	print*, 'PT_CAN        (JJ) = ', PT_CAN        (JJ)       
!ENDIF
!-------------------------------------------------------------------------------
!
!*      7.     Air canyon specific humidity
!              ----------------------------
!
!IF (icell == 5 .AND. iblock == 2532) THEN
!	print*, 'PQSAT_GD        (JJ) = ', PQSAT_GD        (JJ)
!	print*, 'PAC_AGG_GD        (JJ) = ', PAC_AGG_GD        (JJ)
!	print*, 'PHU_AGG_GD        (JJ) = ', PHU_AGG_GD        (JJ)
!    print*, 'ZGD        (JJ) = ', ZGD        (JJ)
!	print*, 'ZINTER = ', ZINTER        
!ENDIF

    ZINTER = PAC_RD_WAT(JJ) * PDF_RD(JJ) * PDELT_RD(JJ) * ZRD(JJ) + PAC_AGG_GD(JJ) * PHU_AGG_GD(JJ) * ZGD(JJ) + PAC_TOP(JJ)
    PQ_CAN(JJ) = (  PQSAT_RD   (JJ) * PAC_RD_WAT(JJ) * PDF_RD    (JJ) * ZRD(JJ) * PDELT_RD(JJ)    &
                  + PQSAT_GD   (JJ) * PAC_AGG_GD(JJ) * PHU_AGG_GD(JJ) * ZGD(JJ)                   &
                  + PQA        (JJ) * PAC_TOP(JJ)                                                 &
                  + PLE_TRAFFIC(JJ) / (1.-T%XBLD(JJ)) / PRHOA(JJ) / XLVTT                         &
                  + PLESN_RD   (JJ) * PDN_RD(JJ)      / PRHOA(JJ) / XLVTT * ZRD(JJ)  ) / ZINTER

    IF (TOP%CBEM=="BEM") THEN
      PQ_CAN(JJ) = PQ_CAN(JJ) + (DMT%XLE_WASTE(JJ) * B%XF_WASTE_CAN(JJ) / (1-T%XBLD(JJ)) / PRHOA(JJ) / XLVTT) / ZINTER
    ENDIF
!IF (icell == 5 .AND. iblock == 2532) THEN
!	print*, 'PQ_CAN        (JJ) = ', PQ_CAN        (JJ)       
!ENDIF
  ENDIF
!
ENDDO
!
!*check that canyon specif. humidity lower than saturation
!
ZQSAT_CAN(:) = QSAT (PT_CAN(:), PPS(:))
WHERE (PQ_CAN(:) > ZQSAT_CAN(:))
   PQ_CAN(:) = ZQSAT_CAN(:)
END WHERE
!
IF (LHOOK) CALL DR_HOOK('AVG_URBAN_FLUXES',1,ZHOOK_HANDLE)
!-------------------------------------------------------------------------------
!
END SUBROUTINE AVG_URBAN_FLUXES
