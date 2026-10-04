!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 1998-2013 Meteo-France
! This is part of the TEB software governed by the CeCILL-C licence version 1.
! See LICENCE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt for details.
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-fr.txt
! The CeCILL-C licence is compatible with L-GPL
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     #########
    SUBROUTINE GREENROOF(TYPE_GREENROOF, HIMPLICIT_WIND, TPTIME, PTSUN, PPEW_A_COEF, PPEW_B_COEF,    &
                PPET_A_COEF, PPEQ_A_COEF, PPET_B_COEF, PPEQ_B_COEF,                  &
                PTSTEP, PZREF, PUREF,                                                &
                PTA, PQA, PEXNS, PEXNA,PRHOA, PCO2, PPS, PRR, PSR, PZENITH,          &
                PSW,PLW, PVMOD, PALB_GR, PEMIS_GR, PZ0_GR, PZ0_O_Z0H_GR, PPHU_GR,     &
                PRN_GREENROOF,PH_GREENROOF,PLE_GREENROOF,PGFLUX_GREENROOF,           &
                PSFCO2,PEVAP_GREENROOF, PUW_GREENROOF,                               &
                PAC_GREENROOF,PQSAT_GREENROOF,PTS_GREENROOF,                         &
                PHU_AGG_GREENROOF,PDEEP_FLUX,                     &
                PRUNOFF_GREENROOF, PDRAIN_GREENROOF, PIRRIG_GREENROOF                )  
!   ##################################################################################
!
!!****  *GREENROOF*  
!!
!!    PURPOSE
!!    -------
!
!!call  a proxi of green roof scheme inside TEB
!
!!========================================================================
!!========================================================================
!!========================================================================
!!
!! ==> YOU ARE (MORE THAN) WELCOME TO USE YOUR OWN GREEN ROOF SCHEME HERE
!!
!!========================================================================
!!========================================================================
!!========================================================================
!
!!**  METHOD
!!     ------
!!    based on subroutine "garden" 
!!
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
!!    Based on subroutine "garden"
!!      
!!    AUTHOR
!!    ------
!!
!!	C. de Munck & A. Lemonsu          * Meteo-France *
!!
!!    MODIFICATIONS
!!    -------------
!     Original    09/2011 
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_CSTS, ONLY : XLVTT , &   ! Latent heat constant for evaporation
                      XCPD,   &   ! specific heat of dry air
                      XSTEFAN, &  ! Stefan-Boltzmann constant
                      XKARMAN     ! Von Karman constant
USE MODE_THERMOS                  ! Function to compute humidity at saturation
USE MODE_GARDEN_BALANCE           ! shared diagnostic balance, neutral coefficients,
!                                 ! wind floor and flux clips of the garden scheme
USE MODD_TYPE_DATE_SURF,    ONLY: DATE_TIME
!
IMPLICIT NONE
!
!*      0.1    Declarations of arguments
!
 !* Type of the greenroof parameterization (from the namelist teb_type_greenroof):
 !*   'PROXY_NEW' : diagnostic closed surface energy balance (default)
 !*   'PROXY_OLD' : historical fixed Bowen-ratio proxy (PH = 0.5*Rn, LE = 0.5*Rn)
 CHARACTER(LEN=*),     INTENT(IN)  :: TYPE_GREENROOF    ! type of the greenroof model
 CHARACTER(LEN=*),     INTENT(IN)  :: HIMPLICIT_WIND   ! wind implicitation option
!                                                     ! 'OLD' = direct
!                                                     ! 'NEW' = Taylor serie, order 1
TYPE(DATE_TIME)     , INTENT(IN)    :: TPTIME             ! current date and time from teb
REAL, DIMENSION(:)  , INTENT(IN)    :: PTSUN              ! solar time      (s from midnight)
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_A_COEF        ! implicit coefficients
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEW_B_COEF        ! for wind coupling
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEQ_A_COEF        ! implicit coefficients
REAL, DIMENSION(:)  , INTENT(IN)    :: PPEQ_B_COEF        ! for humidity
REAL, DIMENSION(:)  , INTENT(IN)    :: PPET_A_COEF        ! implicit coefficients
REAL, DIMENSION(:)  , INTENT(IN)    :: PPET_B_COEF        ! for temperature
REAL                , INTENT(IN)    :: PTSTEP             ! time step
REAL, DIMENSION(:)  , INTENT(IN)    :: PZREF              ! height of the first atmospheric level                                                !
REAL, DIMENSION(:)  , INTENT(IN)    :: PUREF              ! reference height for the wind
REAL, DIMENSION(:)  , INTENT(IN)    :: PTA                ! temperature at first atm. level 
REAL, DIMENSION(:)  , INTENT(IN)    :: PQA                ! specific humidity at first atm. level
REAL, DIMENSION(:)  , INTENT(IN)    :: PPS                ! pressure at the surface
REAL, DIMENSION(:)  , INTENT(IN)    :: PEXNA              ! Exner function at first atm. level
REAL, DIMENSION(:)  , INTENT(IN)    :: PEXNS              ! surface Exner function
REAL, DIMENSION(:)  , INTENT(IN)    :: PRHOA              ! air density at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)    :: PCO2               ! CO2 concentration in the air    (kg/m3)
REAL, DIMENSION(:)  , INTENT(IN)    :: PRR                ! rain rate
REAL, DIMENSION(:)  , INTENT(IN)    :: PSR                ! snow rate
REAL, DIMENSION(:)  , INTENT(IN)    :: PZENITH            ! solar zenithal angle
REAL, DIMENSION(:)  , INTENT(IN)    :: PSW                ! incoming total solar rad on an horizontal surface
REAL, DIMENSION(:)  , INTENT(IN)    :: PLW                ! atmospheric infrared radiation
REAL, DIMENSION(:)  , INTENT(IN)    :: PVMOD              ! module of horizontal wind near first atm. level
REAL, DIMENSION(:)  , INTENT(IN)    :: PALB_GR            ! green roof albedo (namelist urb_alb_grf)
REAL, DIMENSION(:)  , INTENT(IN)    :: PEMIS_GR           ! green roof emissivity (namelist urb_emis_grf; not used by this proxy)
REAL, DIMENSION(:)  , INTENT(IN)    :: PZ0_GR             ! green roof roughness length (m) (namelist urb_z0_grf)
 !MV202609 greenroof thermal roughness (z0h) and tunable surface humidity
 !* z0/z0h ratio (-), >= 1: the scalar (thermal) roughness is z0h = PZ0_GR/PZ0_O_Z0H_GR,
 !* used by heat and moisture (the momentum keeps PZ0_GR), see GARDEN_PCH_NEUTRAL.
 !* PPHU_GR is the relative humidity of the greenroof surface (namelist urb_phu_grf).
 REAL,               INTENT(IN)    :: PZ0_O_Z0H_GR        ! greenroof z0/z0h ratio (-), >= 1
 REAL,               INTENT(IN)    :: PPHU_GR             ! greenroof surface relative humidity (-)


REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_GREENROOF         ! net radiation over greenroofs
REAL, DIMENSION(:)  , INTENT(INOUT) :: PH_GREENROOF          ! sensible heat flux over greenroofs
REAL, DIMENSION(:)  , INTENT(INOUT) :: PLE_GREENROOF         ! latent heat flux over greenroofs
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_GREENROOF      ! flux through the greenroofs
REAL, DIMENSION(:)  , INTENT(OUT)   :: PSFCO2                ! flux of greenroof CO2       (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(INOUT) :: PEVAP_GREENROOF       ! total evaporation over greenroofs (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PUW_GREENROOF         ! friction flux (m2/s2)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_GREENROOF         ! greenroof aerodynamical conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PQSAT_GREENROOF       ! saturation humidity
REAL, DIMENSION(:)  , INTENT(INOUT) :: PTS_GREENROOF         ! greenroof radiative surface temp. (snow free)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PHU_AGG_GREENROOF     ! aggreg. relative humidity for greenroofs for latent heat flux
REAL, DIMENSION(:)  , INTENT(OUT)   :: PDEEP_FLUX            ! Heat Flux at the bottom layer of the greenroof
REAL, DIMENSION(:)  , INTENT(INOUT) :: PRUNOFF_GREENROOF     ! greenroof surface runoff
REAL, DIMENSION(:)  , INTENT(OUT)   :: PDRAIN_GREENROOF      ! greenroof total (vertical) drainage
REAL, DIMENSION(:)  , INTENT(OUT)   :: PIRRIG_GREENROOF      ! greenroof irrigation during time step
!
!
!*      0.2    Declarations of local variables
!
!MV202609 local conductance and coefficients of the diagnostic greenroof
REAL, DIMENSION(SIZE(PTA)) :: ZV_GR    ! wind with the floor XVMIN_GD (m/s)
REAL, DIMENSION(SIZE(PTA)) :: ZPCD_GR  ! neutral-log momentum coefficient (-)
REAL, DIMENSION(SIZE(PTA)) :: ZPCH_GR  ! neutral-log thermal (scalar) coefficient (-)
REAL, DIMENSION(SIZE(PTA)) :: ZCA_M_GR ! momentum conductance (m/s), friction only
REAL, DIMENSION(SIZE(PTA)) :: ZCA_GR   ! thermal conductance (m/s), heat and moisture
INTEGER                    :: JI_GR    ! loop index
!
!-------------------------------------------------------------------------------
!
!*      1.     Greenroof parameterizations
!              --------------------------
!
!* albedo and emissivity come from the namelist (urb_alb_grf / urb_emis_grf)
!
SELECT CASE (TYPE_GREENROOF)
!
CASE ('PROXY_NEW')
!* 1.1  diagnostic closed surface energy balance (same solver as the garden,
!*      but the greenroof is a ROOF surface: it exchanges only with the air of
!*      the forcing level (PTA/PQA, wind PVMOD at the height PUREF), so there is
!*      no canyon branch and no tau split)
   DO JI_GR = 1, SIZE(PTA)
      ZV_GR   (JI_GR) = MAX(PVMOD(JI_GR), XVMIN_GD)
      ZPCD_GR (JI_GR) = GARDEN_PCD_NEUTRAL(PUREF(JI_GR), PZ0_GR(JI_GR))
      ZPCH_GR (JI_GR) = GARDEN_PCH_NEUTRAL(PUREF(JI_GR), PZ0_GR(JI_GR), PZ0_O_Z0H_GR)
      ZCA_M_GR(JI_GR) = ZPCD_GR(JI_GR) * ZV_GR(JI_GR)
      ZCA_GR  (JI_GR) = ZPCH_GR(JI_GR) * ZV_GR(JI_GR)
   END DO
   PUW_GREENROOF(:) = -ZCA_M_GR(:) * ZV_GR(:)
   PAC_GREENROOF(:) = ZCA_GR(:)
   !
   !* surface energy balance Rn(Ts) = H + LE with the reference air of the
   !* forcing level and the surface humidity PPHU_GR (G = 0: no heat flux into
   !* the structural roof)
   CALL GARDEN_BALANCE(ZCA_GR, PTA, PQA, PPHU_GR, PRHOA, PPS, PSW, PLW, PALB_GR, PEMIS_GR,  &
                       PTS_GREENROOF, PQSAT_GREENROOF, PH_GREENROOF, PLE_GREENROOF)
   PGFLUX_GREENROOF(:) = 0.       ! no heat flux into the structural roof
   PRN_GREENROOF(:)    = (1.-PALB_GR(:))*PSW(:) + PEMIS_GR(:)*(PLW(:) - XSTEFAN*PTS_GREENROOF(:)**4)
   PEVAP_GREENROOF(:)  = PLE_GREENROOF(:) / XLVTT
   !
   !* flux clips (safety only, as in the garden)
   PH_GREENROOF(:)     = MAX(-XHMAX_GD,  MIN(XHMAX_GD,  PH_GREENROOF(:)))
   PLE_GREENROOF(:)    = MAX(XLEMIN_GD,  MIN(XLEMAX_GD, PLE_GREENROOF(:)))
   PEVAP_GREENROOF(:)  = PLE_GREENROOF(:) / XLVTT
   !
   !* aggregated latent exchange (diagnostics; the greenroof does not couple
   !* back to the canyon air: it is a roof surface)
   PHU_AGG_GREENROOF(:) = PPHU_GR
   !
CASE ('PROXY_OLD')
!* 1.2  historical fixed Bowen-ratio proxy (PH = 0.5*Rn, LE = 0.5*Rn)
   PRN_GREENROOF(:) = (1.-PALB_GR(:)) * PSW(:)
   PH_GREENROOF (:) = 0.5 * PRN_GREENROOF(:)
   PLE_GREENROOF(:) = 0.5 * PRN_GREENROOF(:)
   PGFLUX_GREENROOF(:) = 0.
   PEVAP_GREENROOF(:) = PLE_GREENROOF(:) / XLVTT
   !
   !* friction flux: neutral formulation with the greenroof roughness (as before)
   PUW_GREENROOF(:) = - (XKARMAN/LOG(PUREF(:)/PZ0_GR(:)))**2 * PVMOD(:)**2
   !
   !* aerodynamical conductance: neglected (the Bowen proxy does not depend on Ts)
   PAC_GREENROOF(:) = 0.
   !
   !* surface saturation humidity and temperature (placeholder, not solved)
   PQSAT_GREENROOF(:) = QSAT(PTA(:),PPS(:))
   !
   !* aggregated latent exchange (diagnostics)
   PHU_AGG_GREENROOF(:) = PPHU_GR   ! surface relative humidity from the namelist urb_phu_grf
   !
CASE ('EXT', 'EXT_NEU')
!* 1.3  EXTERNAL greenroof: the fluxes come from the coupling interface
!*      (PH_GR_EXT, PLE_GR_EXT, ...), they are prescribed by the caller; only
!*      the placeholders are set here. The diagnostic exchange coefficients of
!*      an external greenroof are computed in URBAN_DRAG (EXT/EXT_NEU).
   PRN_GREENROOF(:) = 0.
   PH_GREENROOF (:) = 0.
   PLE_GREENROOF(:) = 0.
   PGFLUX_GREENROOF(:) = 0.
   PEVAP_GREENROOF(:) = 0.
   !
   !* friction flux: neutral formulation with the greenroof roughness (as before)
   PUW_GREENROOF(:) = - (XKARMAN/LOG(PUREF(:)/PZ0_GR(:)))**2 * PVMOD(:)**2
   !
   !* aerodynamical conductance: provided by URBAN_DRAG for an external greenroof
   PAC_GREENROOF(:) = 0.
   !
   !* surface saturation humidity (placeholder, not solved)
   PQSAT_GREENROOF(:) = QSAT(PTA(:),PPS(:))
   !
   !* aggregated latent exchange (diagnostics)
   PHU_AGG_GREENROOF(:) = PPHU_GR
   !
END SELECT
!
!* CO2 flux is neglected (no photosynthesis)
PSFCO2(:) = 0.
!
!* Heat Flux at the bottom layer of the greenroof (G = 0 in both schemes)
PDEEP_FLUX(:) = 0.
!
!* greenroof hydrological diagnostics
PRUNOFF_GREENROOF(:) = 0.    ! greenroof surface runoff
PDRAIN_GREENROOF (:) = 0.    ! greenroof total (vertical) drainage
PIRRIG_GREENROOF (:) = 0.    ! greenroof irrigation during time step
!-------------------------------------------------------------------------------
!
!
END SUBROUTINE GREENROOF
