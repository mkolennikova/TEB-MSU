!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 1998-2013 Meteo-France
! This is part of the TEB software governed by the CeCILL-C licence version 1.
! See LICENCE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt for details.
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-fr.txt
! The CeCILL-C licence is compatible with L-GPL
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     #########
    SUBROUTINE GARDEN(TYPE_GARDEN, HIMPLICIT_WIND, TPTIME, PTSUN, PPEW_A_COEF, PPEW_B_COEF, &
                PPET_A_COEF, PPEQ_A_COEF, PPET_B_COEF, PPEQ_B_COEF,                  &
                PTSTEP, PZ_LOWCAN,                                                   &
                PT_LOWCAN, PQ_LOWCAN, PEXNS, PRHOA, PCO2, PPS, PRR, PSR, PZENITH,    &
                PSW, PLW, PU_LOWCAN, PZ0_GD, PALB_GD, PEMIS_GD,                                 &
                PRN_GARDEN,PH_GARDEN,PLE_GARDEN,PGFLUX_GARDEN,PSFCO2,                &
                PEVAP_GARDEN, PUW_GARDEN, PRUNOFF_GARDEN,                            &
                PAC_GARDEN,PQSAT_GARDEN,PTS_GARDEN,                                  &
                PAC_AGG_GARDEN, PHU_AGG_GARDEN, PDRAIN_GARDEN, PIRRIG_GARDEN         ) 
				
!   ##########################################################################
!
!!****  *GARDEN*  
!!
!!    PURPOSE
!!    -------
!
!!call  a proxi of vegetation scheme inside TEB
!
!!========================================================================
!!========================================================================
!!========================================================================
!!
!! ==> YOU ARE (MORE THAN) WELCOME TO USE YOUR OWN VEGETATION SCHEME HERE
!!
!!========================================================================
!!========================================================================
!!========================================================================
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
!!	A. Lemonsu          * Meteo-France *
!!
!!    MODIFICATIONS
!!    -------------
!!    Original    05/2009
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_CSTS, ONLY : XLVTT , &   ! Latent heat constant for evaporation
                      XKARMAN, &  ! Von Karman constant
                      XCPD,    &  ! specific heat of dry air
                      XSTEFAN     ! Stefan-Boltzmann constant
USE MODE_THERMOS                  ! Function to compute humidity at saturation
USE MODD_TYPE_DATE_SURF,    ONLY: DATE_TIME
!
IMPLICIT NONE
!
!*      0.1    Declarations of arguments
!
!* Type of the garden parameterization (from the namelist teb_type_garden):
!*   'PROXY_OLD' : fixed Bowen-ratio proxy (the historical scheme)
!*   'PROXY_NEW' : diagnostic closed surface energy balance (default)
!*   'EXT'       : external garden model (this routine is a no-op placeholder)
 CHARACTER(LEN=*),     INTENT(IN)  :: TYPE_GARDEN      ! type of the garden model
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
REAL, DIMENSION(:)  , INTENT(IN)    :: PZ_LOWCAN          ! height of atm. var. near the road
REAL, DIMENSION(:)  , INTENT(IN)    :: PT_LOWCAN          ! temp. near the road
REAL, DIMENSION(:)  , INTENT(IN)    :: PQ_LOWCAN          ! hum. near the road
REAL, DIMENSION(:)  , INTENT(IN)    :: PPS                ! pressure at the surface
REAL, DIMENSION(:)  , INTENT(IN)    :: PEXNS              ! surface exner function
REAL, DIMENSION(:)  , INTENT(IN)    :: PRHOA              ! air density at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)    :: PCO2               ! CO2 concentration in the air    (kg/m3)
REAL, DIMENSION(:)  , INTENT(IN)    :: PRR                ! rain rate
REAL, DIMENSION(:)  , INTENT(IN)    :: PSR                ! snow rate
REAL, DIMENSION(:)  , INTENT(IN)    :: PZENITH            ! solar zenithal angle
REAL, DIMENSION(:),   INTENT(IN)    :: PSW                ! incoming total solar rad on an horizontal surface
REAL, DIMENSION(:)  , INTENT(IN)    :: PLW                ! atmospheric infrared radiation
REAL, DIMENSION(:)  , INTENT(IN)    :: PU_LOWCAN          ! wind near the road
REAL, DIMENSION(:)  , INTENT(IN)    :: PZ0_GD             ! garden roughness length (m)  (namelist urb_z0_gdn)
REAL, DIMENSION(:)  , INTENT(IN)    :: PALB_GD            ! garden albedo                (namelist urb_alb_gdn)
REAL, DIMENSION(:)  , INTENT(IN)    :: PEMIS_GD           ! garden emissivity            (namelist urb_emis_gdn)


REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_GARDEN         ! net radiation over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_GARDEN          ! sensible heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_GARDEN         ! latent heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_GARDEN      ! flux through the green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PSFCO2             ! flux of CO2 positive toward the atmosphere (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PEVAP_GARDEN       ! total evaporation over gardens (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PUW_GARDEN         ! friction flux (m2/s2)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRUNOFF_GARDEN     ! runoff over garden (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_GARDEN         ! aerodynamical conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PQSAT_GARDEN       ! saturation humidity
REAL, DIMENSION(:)  , INTENT(INOUT) :: PTS_GARDEN         ! radiative surface temp. (snow free)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_AGG_GARDEN     ! aggreg. aeodynamic resistance for green areas for latent heat flux
REAL, DIMENSION(:)  , INTENT(OUT)   :: PHU_AGG_GARDEN     ! aggreg. relative humidity for green areas for latent heat flux
REAL, DIMENSION(:)  , INTENT(OUT)   :: PDRAIN_GARDEN      ! garden total (vertical) drainage
REAL, DIMENSION(:)  , INTENT(OUT)   :: PIRRIG_GARDEN      ! garden summer irrigation rate
!
!
!*      0.2    Declarations of local variables
!
!* Fixed surface relative humidity of the diagnostic scheme ('PROXY_NEW'):
!* the albedo and the emissivity come from the namelist (PALB_GD / PEMIS_GD)
REAL, PARAMETER :: XPHU_GD    = 0.80   ! surface relative humidity of the garden (-)
!* garden roughness length: PZ0_GD, provided by the host from the namelist
!* item z0_garden (one single value for all the garden versions)
!* Minimum wind speed used for the garden exchange coefficients (m/s): the
!* surface must not be decoupled from the canyon air when the canyon wind
!* vanishes, otherwise the surface temperature is not anchored by the
!* turbulent fluxes any more.
REAL, PARAMETER :: XVMIN_GD   = 0.5
!
!* Numerical parameters of the diagnostic Newton iteration ('PROXY_NEW')
INTEGER, PARAMETER :: NITER_GD  = 8
REAL,    PARAMETER :: XDTSTEP_GD = 5.0    ! max |dTs| per Newton step (K)
REAL,    PARAMETER :: XTSMIN_GD  = 230.0  ! global Ts bounds (K, numerical safety)
REAL,    PARAMETER :: XTSMAX_GD  = 350.0
REAL,    PARAMETER :: XHMAX_GD  = 1000.0  ! flux clips (W/m2)
REAL,    PARAMETER :: XLEMAX_GD = 1000.0
REAL,    PARAMETER :: XLEMIN_GD = -200.0
!
!* Local work arrays of the diagnostic scheme ('PROXY_NEW')
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZCA_GD   ! aerodynamic conductance (m/s)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZV_GD    ! wind used for the conductance (m/s)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZTS_GD   ! iterated surface temperature (K)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZDELTA   ! Newton step (K)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZNUM, ZDEN
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZQSAT, ZDQSAT, ZSIGT4
INTEGER :: JI_GD, JITER_GD
!-------------------------------------------------------------------------------
!
!*      Garden model selected by teb_type_garden (namelist):
!*        'PROXY_NEW' : diagnostic closed surface energy balance (section 2)
!*        'PROXY_OLD'/'EXT' : fixed Bowen-ratio proxy (section 1)
!
IF (TYPE_GARDEN == 'PROXY_NEW') THEN
!
!-------------------------------------------------------------------------------
!*      2.     Diagnostic closed surface energy balance
!*             ------------------------------------------
!*       Rn = H + LE solved for Ts by Newton iteration (no heat flux into the
!*       soil: the garden is a diagnostic proxy without a soil reservoir)
!*         Rn = (1-alb)*SW + emis*(LW - sigma*Ts**4)
!*         H  = rho*cp*Ca*(Ts - Ta)
!*         LE = rho*Lv*Ca*(PHU*qsat(Ts) - qa)
!*       Ca  = (k/ln(zref/z0))**2 * V   (neutral log profile)
!-------------------------------------------------------------------------------
!
!* 2.1  aerodynamic conductance and friction
!*      a minimum wind speed is used so that the surface is never decoupled
!*      from the canyon air (Ts is then anchored by the turbulent fluxes alone)
DO JI_GD = 1, SIZE(PT_LOWCAN)
   IF (PZ_LOWCAN(JI_GD) > PZ0_GD(JI_GD)) THEN
      ZV_GD(JI_GD)  = MAX(PU_LOWCAN(JI_GD), XVMIN_GD)
      ZCA_GD(JI_GD) = (XKARMAN/LOG(PZ_LOWCAN(JI_GD)/PZ0_GD(JI_GD)))**2 * ZV_GD(JI_GD)
   ELSE
      ZV_GD(JI_GD)  = 0.
      ZCA_GD(JI_GD) = 0.
   END IF
END DO
PAC_GARDEN(:) = ZCA_GD(:)
PUW_GARDEN(:) = -ZCA_GD(:) * ZV_GD(:)
!
!* 2.2  initial guess (reuses the previous-step surface temperature)
ZTS_GD(:) = MAX(XTSMIN_GD, MIN(XTSMAX_GD, PTS_GARDEN(:)))
!
DO JITER_GD = 1, NITER_GD
   ZQSAT(:)  = QSAT(ZTS_GD(:), PPS(:))
   ZDQSAT(:) = DQSAT(ZTS_GD(:), PPS(:), ZQSAT(:))
   ZSIGT4(:) = XSTEFAN * ZTS_GD(:)**4
   !* residual F(Ts) = net radiation - H - LE
   ZNUM(:) = (1.-PALB_GD(:))*PSW(:) + PEMIS_GD(:)*PLW(:) - PEMIS_GD(:)*ZSIGT4(:)       &
             - PRHOA(:)*XCPD*ZCA_GD(:)*(ZTS_GD(:) - PT_LOWCAN(:))               &
             - PRHOA(:)*XLVTT*ZCA_GD(:)*(XPHU_GD*ZQSAT(:) - PQ_LOWCAN(:))
   !* denom = -F'(Ts) > 0
   ZDEN(:) = 4.*PEMIS_GD(:)*XSTEFAN*ZTS_GD(:)**3                                &
             + PRHOA(:)*XCPD*ZCA_GD(:)                                        &
             + PRHOA(:)*XLVTT*ZCA_GD(:)*XPHU_GD*ZDQSAT(:)
   DO JI_GD = 1, SIZE(PT_LOWCAN)
      IF (ZDEN(JI_GD) > 1.E-8) THEN
         ZDELTA(JI_GD) = ZNUM(JI_GD) / ZDEN(JI_GD)
      ELSE
         ZDELTA(JI_GD) = 0.
      END IF
      ZDELTA(JI_GD) = MAX(-XDTSTEP_GD, MIN(XDTSTEP_GD, ZDELTA(JI_GD)))
      ZTS_GD(JI_GD) = ZTS_GD(JI_GD) + ZDELTA(JI_GD)
      ZTS_GD(JI_GD) = MAX(XTSMIN_GD, MIN(XTSMAX_GD, ZTS_GD(JI_GD)))
   END DO
END DO
!
!* 2.3  final bound on surface temperature (numerical safety only)
ZTS_GD(:) = MAX(XTSMIN_GD, MIN(XTSMAX_GD, ZTS_GD(:)))
PTS_GARDEN(:) = ZTS_GD(:)
!
!* 2.4  fluxes
PQSAT_GARDEN(:) = QSAT(PTS_GARDEN(:), PPS(:))
PH_GARDEN(:)     = PRHOA(:)*XCPD*ZCA_GD(:)*(PTS_GARDEN(:) - PT_LOWCAN(:))
PLE_GARDEN(:)    = PRHOA(:)*XLVTT*ZCA_GD(:)*(XPHU_GD*PQSAT_GARDEN(:) - PQ_LOWCAN(:))
PGFLUX_GARDEN(:) = 0.       ! no heat flux into the soil (diagnostic proxy garden)
PRN_GARDEN(:)    = (1.-PALB_GD(:))*PSW(:) + PEMIS_GD(:)*(PLW(:) - XSTEFAN*PTS_GARDEN(:)**4)
PEVAP_GARDEN(:)  = PLE_GARDEN(:) / XLVTT
!
!* flux clips (safety only; small energy imbalance possible when they bite)
PH_GARDEN(:)     = MAX(-XHMAX_GD,  MIN(XHMAX_GD,  PH_GARDEN(:)))
PLE_GARDEN(:)    = MAX(XLEMIN_GD,  MIN(XLEMAX_GD, PLE_GARDEN(:)))
PEVAP_GARDEN(:)  = PLE_GARDEN(:) / XLVTT
!
!* 2.5  aggregated latent exchange: non-zero conductance couples the garden
!*      back to the canyon air (T_CANYON / Q_CANYON)
PAC_AGG_GARDEN(:) = PAC_GARDEN(:)
PHU_AGG_GARDEN(:) = XPHU_GD
!
ELSE
!
!*      1.     Proxi model based on a fixed Bowen ratio
!              ----------------------------------------
!
!* albedo from the namelist (urb_alb_gdn)
PRN_GARDEN(:) = (1.-PALB_GD(:)) * PSW(:)
!
!* Bowen ratio fixed to 0.25
PH_GARDEN (:) = 0.2 * PRN_GARDEN(:)
PLE_GARDEN(:) = 0.8 * PRN_GARDEN(:)
!
!* Conduction heat flux is neglected
PGFLUX_GARDEN(:) = 0.
!
!* CO2 flux is neglected
PSFCO2(:) = 0.
!
!* evaporation
PEVAP_GARDEN(:) = PLE_GARDEN(:) / XLVTT
!
!* Friction flux: assumes neutral formulation with the garden roughness
!* length PZ0_GD (namelist z0_garden)
PUW_GARDEN(:) = - (XKARMAN/LOG(PZ_LOWCAN(:)/PZ0_GD(:)))**2 * PU_LOWCAN(:)**2
!
!* Aerodynamical conductance: neglected because used further only for
!  implicitation of canyon air temperature when the heat flux depends on the
!  surface temperature
!
PAC_GARDEN(:) = 0.
!
!* surface saturation humidity
!PQSAT_GARDEN(:) = QSAT(PT_LOWCAN(:),PPS(:))
PQSAT_GARDEN(:) = QSAT(PTS_GARDEN(:),PPS(:))
!
!* Surface temperature : set equal to air temperature
!PTS_GARDEN(:) = PT_LOWCAN(:)
!
!* aerocynamical conductance for latent heat and surface humidity
PAC_AGG_GARDEN(:) = 0.    ! neglected (latent flux does not depend on surface humidity)
PHU_AGG_GARDEN(:) = 0.8   ! surface humidity set to 80%
!
END IF
!
!* CO2 flux is neglected
PSFCO2(:) = 0.
!
!* garden hydrological diagnostics
PRUNOFF_GARDEN(:) = 0.    ! garden surface runoff
PDRAIN_GARDEN (:) = 0.    ! garden total (vertical) drainage
PIRRIG_GARDEN (:) = 0.    ! garden irrigation during time step
!-------------------------------------------------------------------------------
!
!
END SUBROUTINE GARDEN
