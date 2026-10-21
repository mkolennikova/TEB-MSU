!auto_modi:spll_teb_garden.D
MODULE MODI_TEB_GARDEN
INTERFACE
    SUBROUTINE TEB_GARDEN (icell, iblock, TOPTS, TSTATE, BOPTS, BSTATE, TPN, TIR, DMT, OGREENROOF_EXT,                     &
                           HIMPLICIT_WIND, PBEM_AC, PTSUN, HSNOW_ROOF, HSNOW_ROAD, &
                           PPEW_A_COEF, PPEW_B_COEF, PPEW_A_COEF_LOWCAN,    &
                           PPEW_B_COEF_LOWCAN, PZ0_GARDEN_EXT, PPS, PPA, PEXNS, PEXNA, PTA, PQA, PRHOA, PCO2,     &
                           PLW_RAD, PDIR_SW, PSCA_SW, PSW_BANDS, KSW, PZENITH, PAZIM, PRR, PSR,   &
                           PZREF, PUREF, PVMOD, PH_TRAFFIC, PTSTEP,  &
!MV202609 CBS scheme of the road (revision: snow-to-atmosphere branch)
                          						       KDAY,         &
						        PTIME,  &
						   PZ0_GR_EXT, PALB_GR_EXT, PEMIS_GR_EXT, PTSRAD_GR_EXT, PQV_GR_EXT, PH_GR_EXT, PLE_GR_EXT, PEVAP_GR_EXT, PRUNOFF_GR_EXT,     &
						   PALB_GD_EXT, PEMIS_GD_EXT, PTSRAD_GD_EXT, PQV_GD_EXT, PH_GD_EXT, PLE_GD_EXT, PEVAP_GD_EXT,         &
						   PCH_GD, PCD_GD, PRUNOFF_GD_EXT,       &
                             TPARAMS, BPARAMS)
USE MODD_TEB_OPTION_n, ONLY : TEB_OPTIONS_t
USE MODD_TEB_n, ONLY : TEB_t
USE MODD_BEM_OPTION_n, ONLY : BEM_OPTIONS_t
USE MODD_BEM_n, ONLY : BEM_t
USE MODD_TEB_PANEL_n, ONLY : TEB_PANEL_t
USE MODD_TEB_IRRIG_n, ONLY : TEB_IRRIG_t
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE MODD_TEB_PARAMS_n, ONLY : TEB_PARAMS_t
USE MODD_BEM_PARAMS_n, ONLY : BEM_PARAMS_t
IMPLICIT NONE
TYPE(TEB_PARAMS_t), INTENT(IN) :: TPARAMS
TYPE(BEM_PARAMS_t), INTENT(INOUT) :: BPARAMS


INTEGER                             :: icell                                                      
INTEGER                             :: iblock
TYPE(TEB_OPTIONS_t), INTENT(INOUT) :: TOPTS
TYPE(TEB_t), INTENT(INOUT) :: TSTATE
TYPE(BEM_OPTIONS_t), INTENT(INOUT) :: BOPTS
TYPE(BEM_t), INTENT(INOUT) :: BSTATE
TYPE(TEB_PANEL_t), INTENT(INOUT) :: TPN
TYPE(TEB_IRRIG_t), INTENT(INOUT) :: TIR
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT
!
LOGICAL,              INTENT(IN)  :: OGREENROOF_EXT   !IN Flag to use a green roofs scheme (external)
CHARACTER(LEN=*),     INTENT(IN)  :: HIMPLICIT_WIND      ! wind implicitation option
!                                                         ! 'OLD' = direct
!                                                         ! 'NEW' = Taylor serie, order 1
LOGICAL,INTENT(IN)                  :: PBEM_AC            ! Flag to use air conditioners
REAL, DIMENSION(:),   INTENT(IN)    :: PTSUN              ! solar time   (s from midnight)
 CHARACTER(LEN=*)    , INTENT(IN)    :: HSNOW_ROOF         ! snow roof scheme 'NONE', 'D95 ', '1-L '
 CHARACTER(LEN=*)    , INTENT(IN)    :: HSNOW_ROAD         ! snow road scheme 'NONE', 'D95 ', '1-L '
!
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_A_COEF        ! implicit coefficients
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_B_COEF        ! for wind coupling
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_A_COEF_LOWCAN ! implicit coefficients for wind coupling
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_B_COEF_LOWCAN ! between low canyon wind and road
REAL, DIMENSION(:)  , INTENT(IN)    :: PZ0_GARDEN_EXT     ! garden roughness length (external model)
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
REAL, DIMENSION(:)  , INTENT(IN)    :: PRR                ! rain rate
REAL, DIMENSION(:)  , INTENT(IN)    :: PSR                ! snow rate
REAL, DIMENSION(:)  , INTENT(IN)    :: PH_TRAFFIC         ! anthropogenic sensible heat fluxes due to traffic
REAL, DIMENSION(:)  , INTENT(IN)    :: PZREF              ! reference height of the first atm level (temperature)
REAL, DIMENSION(:)  , INTENT(IN)    :: PUREF              ! reference height of the first atm level (wind)
REAL                , INTENT(IN)    :: PTSTEP             ! time step

REAL, DIMENSION(:)  , INTENT(IN)    :: PZ0_GR_EXT         ! green roof roughness length (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PALB_GR_EXT        ! green roof albedo (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PEMIS_GR_EXT       ! green roof emissivity (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PTSRAD_GR_EXT      ! greenroof radiative surface temp. (snow free) (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PQV_GR_EXT         ! greenroof specific humidity (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PH_GR_EXT          ! sensible heat flux over greenroofs (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PLE_GR_EXT         ! latent heat flux over greenroofs (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PEVAP_GR_EXT       ! total evaporation over greenroofs (kg/m2/s) (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PRUNOFF_GR_EXT     ! greenroof surface runoff (external model)

REAL, DIMENSION(:)  , INTENT(IN)    :: PALB_GD_EXT            ! garden albedo (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PEMIS_GD_EXT           ! garden emissivity (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PTSRAD_GD_EXT          ! garden radiative surface temp. (snow free) (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PQV_GD_EXT             ! garden specific humidity (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PH_GD_EXT              ! sensible heat flux over garden (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PLE_GD_EXT             ! latent heat flux over garden (external model)
REAL, DIMENSION(:)  , INTENT(IN)    :: PEVAP_GD_EXT           ! total evaporation over garden (kg/m2/s) (external model)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_GD                 ! drag coeifficient for heat
REAL, DIMENSION(:)  , INTENT(INOUT)   :: PCD_GD                 ! garden  surf. exchange coefficient
REAL, DIMENSION(:)  , INTENT(IN)    :: PRUNOFF_GD_EXT         ! garden surface runoff (external model)


!MV202609 CBS scheme of the road (revision: snow-to-atmosphere branch)
!* INOUT: read by the canyon air nodes before the snow scheme of TEB writes them
INTEGER             , INTENT(IN)    :: KDAY               ! Simulation day
REAL                , INTENT(IN)     :: PTIME             ! current time since midnight (UTC, s)
!MV202609 road-to-atm and garden-to-atm exchange diagnostics
!MV202609 CBS scheme of the road
!MV202609 CBS scheme of the road (revision: puddle diagnostics)
!MV202609 fixes of the snow melt / roof puddle water path (roof diagnostics)
!MV202609 CBS scheme of the road (revision: three-temperature construction)
!MV202609 garden diagnostics
!MV202609 CBS scheme of the garden (canyon and atmosphere branch fluxes)
!MV202609 greenroof diagnostics
!MV202609 greenroof-to-atm exchange diagnostics (from URBAN_DRAG)
END SUBROUTINE TEB_GARDEN
END INTERFACE
END MODULE MODI_TEB_GARDEN
