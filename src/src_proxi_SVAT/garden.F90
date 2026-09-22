!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 1998-2013 Meteo-France
! This is part of the TEB software governed by the CeCILL-C licence version 1.
! See LICENCE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt for details.
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-fr.txt
! The CeCILL-C licence is compatible with L-GPL
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! This file contains the garden parameterizations of TEB-Ru:
!
!   GARDEN_TAU  - garden of the model: the exchange is split by tau between the
!                 canyon air and the air of the forcing level. THIS IS THE ONLY
!                 ROUTINE CALLED BY TEB.
!   GARDEN      - reduced diagnostic garden without the tau split: the
!                 dimensionless coefficients of the neutral log profiles are
!                 computed from the reference height and the garden roughness
!                 lengths (PCD for the momentum, PCH for heat and moisture with
!                 the thermal roughness z0h = z0/PZ0_O_Z0H) and GARDEN_PCD is
!                 called (behaviour of the model before the tau scheme of the
!                 garden was introduced). Used by the offline experiments.
!   GARDEN_PCD  - same diagnostic garden, but the dimensionless coefficients and
!                 the reference state (T, q, wind) are provided by the caller: no
!                 height and no roughness length appear among its arguments (they
!                 are already inside the coefficients). Used by the coupling
!                 experiments with externally provided coefficients.
!
! The friction flux of the garden is always computed from the MOMENTUM
! coefficient PCD (z0), while the surface energy balance (H, LE) and the coupling
! of the garden with the air of the canyon use the THERMAL (scalar) coefficient
! PCH (z0h): see GARDEN_PCD_NEUTRAL / GARDEN_PCH_NEUTRAL below. With z0h = z0
! (PZ0_O_Z0H = 1) the two coincide and the formulation without thermal roughness
! is reproduced exactly.
!
! ONLY GARDEN_TAU returns the tau-branch decomposition (PH_GARDEN_CAN/ATM,
! PLE_GARDEN_CAN/ATM): it is the only routine that knows the two path
! conductances and the two reference airs. GARDEN and GARDEN_PCD have no tau
! split and return a SINGLE set of fluxes; their caller duplicates the flux in
! both branches when a branch presentation is needed (this is what GARDEN_TAU
! itself does in its non-tau path, and what TEB does for an external garden).
!
! The three routines share the same diagnostic surface energy balance
! (Rn = H + LE, no heat flux into the soil) and the same numerical parameters:
! both live in the module MODE_GARDEN_BALANCE below.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!     #########################
      MODULE MODE_GARDEN_BALANCE
!     #########################
!
!!****  *MODE_GARDEN_BALANCE* - fixed parameters and diagnostic surface energy
!!                              balance shared by the TEB garden proxies
!!
!!    PURPOSE
!!    -------
!!      Parameters of the diagnostic garden scheme, its single Newton solver and
!!      the neutral log coefficients shared by its users, used by the three
!!      garden routines of this file:
!!
!!        GARDEN_TAU  computes the tau-aggregated (thermal) conductance and
!!                    reference air and calls GARDEN_BALANCE with them directly
!!        GARDEN_PCD  builds the thermal conductance Ca_h = PCH*max(V, Vmin) from
!!                    the coefficients and the wind given by its caller (and the
!!                    friction conductance from the momentum coefficient PCD) and
!!                    calls GARDEN_BALANCE
!!        GARDEN      computes both neutral-log coefficients PCD and PCH from the
!!                    reference height, the garden roughness z0 and the thermal
!!                    roughness z0h = z0/PZ0_O_Z0H
!!
!!      The neutral formulation below (PCD, PCH, Ca) is the SINGLE source of the
!!      garden exchange coefficients: the internal garden, the external garden of
!!      URBAN_DRAG ('EXT_NEU') and the emulator of the offline driver all call it.
!!
!!**  IMPLICIT ARGUMENTS
!!    ------------------
!!      MODD_CSTS    : XCPD, XLVTT, XSTEFAN
!!      MODE_THERMOS : QSAT, DQSAT
!!
!!    AUTHOR
!!    ------
!!      TEB-Ru
!!
!!    MODIFICATIONS
!!    -------------
!!      Original    01/2026   extraction of the shared balance
!!                  09/2026   thermal roughness z0h of the garden (PCH, Ca_h)
!-------------------------------------------------------------------------------
!
USE MODD_CSTS, ONLY : XCPD, XLVTT, XSTEFAN, XKARMAN
USE MODE_THERMOS
!
IMPLICIT NONE
!
!* Fixed surface relative humidity of the diagnostic scheme
REAL, PARAMETER :: XPHU_GD   = 0.80
!* Minimum wind speed of the diagnostic scheme (m/s): the surface must not be
!* decoupled from the air when the wind vanishes, otherwise the surface
!* temperature is not anchored by the turbulent fluxes any more. It is applied by
!* GARDEN_PCD_NEUTRAL / GARDEN_PCH_NEUTRAL and their conductances below, i.e. it
!* is the single wind floor of the neutral garden formulation - both for the
!* internal garden (GARDEN, GARDEN_TAU) and for the external garden of URBAN_DRAG
!* ('EXT_NEU').
REAL, PARAMETER :: XVMIN_GD  = 0.5
!* Numerical parameters of the diagnostic Newton iteration
INTEGER, PARAMETER :: NITER_GD   = 8
REAL,    PARAMETER :: XDTSTEP_GD = 5.0    ! max |dTs| per Newton step (K)
REAL,    PARAMETER :: XTSMIN_GD  = 230.0  ! global Ts bounds (K, numerical safety)
REAL,    PARAMETER :: XTSMAX_GD  = 350.0
REAL,    PARAMETER :: XHMAX_GD   = 1000.0 ! flux clips (W/m2)
REAL,    PARAMETER :: XLEMAX_GD  = 1000.0
REAL,    PARAMETER :: XLEMIN_GD  = -200.0
!
CONTAINS
!
!-------------------------------------------------------------------------------
!
!* Neutral aerodynamic coefficient of the diagnostic garden for MOMENTUM:
!*     PCD = (kappa/ln(z/z0))**2          (neutral log profile, 0 when z <= z0)
!* It carries NO thermal roughness: the friction flux of the garden is computed
!* from it (z0h is a scalar roughness and does not act on the momentum). The
!* exchange of heat and moisture uses GARDEN_PCH_NEUTRAL below.
!* ELEMENTAL, so it works on scalars as well as on whole arrays.
!
ELEMENTAL FUNCTION GARDEN_PCD_NEUTRAL(PZ, PZ0) RESULT(PPCD)
REAL, INTENT(IN) :: PZ     ! reference height of the air (m)
REAL, INTENT(IN) :: PZ0    ! roughness length for momentum (m)
REAL :: PPCD
!
PPCD = 0.
IF (PZ > PZ0) PPCD = (XKARMAN/LOG(PZ/PZ0))**2
!
END FUNCTION GARDEN_PCD_NEUTRAL
!-------------------------------------------------------------------------------
!
!* Aerodynamic conductance of the neutral garden for MOMENTUM at the wind PV:
!*     Ca_m = PCD*max(PV, XVMIN_GD)
!* The wind floor XVMIN_GD keeps the surface coupled to the air at low wind; it
!* is the SAME floor for every user of the neutral formulation (internal garden
!* and the external garden 'EXT_NEU' of URBAN_DRAG).
!
ELEMENTAL FUNCTION GARDEN_CA_NEUTRAL(PZ, PZ0, PV) RESULT(PCA)
REAL, INTENT(IN) :: PZ     ! reference height of the air (m)
REAL, INTENT(IN) :: PZ0    ! roughness length for momentum (m)
REAL, INTENT(IN) :: PV     ! wind at the reference height (m/s)
REAL :: PCA
!
PCA = GARDEN_PCD_NEUTRAL(PZ, PZ0) * MAX(PV, XVMIN_GD)
!
END FUNCTION GARDEN_CA_NEUTRAL
!-------------------------------------------------------------------------------
!
!* Neutral THERMAL (scalar) coefficient of the diagnostic garden: heat and
!* moisture are exchanged through the thermal roughness z0h = z0/PZ0_O_Z0H:
!*     PCH = kappa**2 / ( ln(z/z0) * ln(z/z0h) ) = PCD * ZFH
!*     ZFH = ln(z/z0)/ln(z/z0h) <= 1        (PZ0_O_Z0H = z0/z0h >= 1)
!* This is the neutral limit of the coefficient computed by SURFACE_AERO_COND,
!* i.e. of the one used by the road, the roof and the town of TEB, and by the
!* garden of an external model in URBAN_DRAG ('EXT'): the ratio of the momentum
!* and scalar profiles multiplies the momentum coefficient by ZFH.
!* With PZ0_O_Z0H = 1 (z0h = z0) the coefficient is EXACTLY PCD, i.e. the
!* formulation without thermal roughness is reproduced bit for bit.
!* It vanishes exactly where the momentum coefficient vanishes (z <= z0), so a
!* degenerate roughness disconnects the garden entirely.
!
ELEMENTAL FUNCTION GARDEN_PCH_NEUTRAL(PZ, PZ0, PZ0_O_Z0H) RESULT(PPCH)
REAL, INTENT(IN) :: PZ         ! reference height of the air (m)
REAL, INTENT(IN) :: PZ0        ! roughness length for momentum (m)
REAL, INTENT(IN) :: PZ0_O_Z0H  ! z0/z0h ratio (-), >= 1
REAL :: PPCH, ZZ0H
!
PPCH = 0.
IF (PZ > PZ0) THEN
   ZZ0H = PZ0 / MAX(PZ0_O_Z0H, 1.)
   IF (ZZ0H >= PZ0) THEN
      !* z0h = z0: no thermal roughness, the scalar coefficient is EXACTLY the
      !* momentum one, so that this formulation reproduces the garden without
      !* thermal roughness bit for bit (same expression, same rounding)
      PPCH = GARDEN_PCD_NEUTRAL(PZ, PZ0)
   ELSE
      PPCH = XKARMAN**2 / ( LOG(PZ/PZ0) * LOG(PZ/ZZ0H) )
   END IF
END IF
!
END FUNCTION GARDEN_PCH_NEUTRAL
!-------------------------------------------------------------------------------
!
!* Aerodynamic conductance for heat and moisture of the neutral garden:
!*     Ca_h = PCH*max(PV, XVMIN_GD)
!* Same wind floor as GARDEN_CA_NEUTRAL, so that Ca_h/Ca_m = ZFH exactly.
!
ELEMENTAL FUNCTION GARDEN_CAH_NEUTRAL(PZ, PZ0, PZ0_O_Z0H, PV) RESULT(PCAH)
REAL, INTENT(IN) :: PZ         ! reference height of the air (m)
REAL, INTENT(IN) :: PZ0        ! roughness length for momentum (m)
REAL, INTENT(IN) :: PZ0_O_Z0H  ! z0/z0h ratio (-), >= 1
REAL, INTENT(IN) :: PV         ! wind at the reference height (m/s)
REAL :: PCAH
!
PCAH = GARDEN_PCH_NEUTRAL(PZ, PZ0, PZ0_O_Z0H) * MAX(PV, XVMIN_GD)
!
END FUNCTION GARDEN_CAH_NEUTRAL
!-------------------------------------------------------------------------------
!
SUBROUTINE GARDEN_BALANCE(PCA, PT_REF, PQ_REF, PRHOA, PPS, PSW, PLW, PALB_GD, PEMIS_GD,  &
                          PTS_GARDEN, PQSAT_GARDEN, PH_GARDEN, PLE_GARDEN)
!
!*** Diagnostic closed surface energy balance Rn(Ts) = H + LE solved for the
!*** surface temperature by a Newton iteration (no heat flux into the soil: the
!*** garden is a diagnostic proxy without a soil reservoir).
!***   Rn = (1-alb)*SW + emis*(LW - sigma*Ts**4)
!***   H  = rho*cp*PCA*(Ts - PT_REF)
!***   LE = rho*Lv*PCA*(PHU*qsat(Ts) - PQ_REF)
!*** The aerodynamic conductance PCA and the reference air (PT_REF, PQ_REF) are
!*** INPUT arguments: this routine never computes an exchange coefficient.
!*** On entry PTS_GARDEN is the initial guess, on exit the solution. The fluxes
!*** returned are the RAW (unclipped) ones: the callers apply their own clips.
!
REAL, DIMENSION(:), INTENT(IN)    :: PCA, PT_REF, PQ_REF, PRHOA, PPS, PSW, PLW, &
                                     PALB_GD, PEMIS_GD
REAL, DIMENSION(:), INTENT(INOUT) :: PTS_GARDEN
REAL, DIMENSION(:), INTENT(OUT)   :: PQSAT_GARDEN, PH_GARDEN, PLE_GARDEN
!
REAL, DIMENSION(SIZE(PTS_GARDEN)) :: ZTS_GD, ZDELTA, ZNUM, ZDEN, ZQSAT, ZDQSAT, ZSIGT4
INTEGER :: JI_GD, JITER_GD
!
!* initial guess (reuses the previous-step surface temperature)
ZTS_GD(:) = MAX(XTSMIN_GD, MIN(XTSMAX_GD, PTS_GARDEN(:)))
!
DO JITER_GD = 1, NITER_GD
   ZQSAT(:)  = QSAT(ZTS_GD(:), PPS(:))
   ZDQSAT(:) = DQSAT(ZTS_GD(:), PPS(:), ZQSAT(:))
   ZSIGT4(:) = XSTEFAN * ZTS_GD(:)**4
   !* residual F(Ts) = net radiation - H - LE
   ZNUM(:) = (1.-PALB_GD(:))*PSW(:) + PEMIS_GD(:)*PLW(:) - PEMIS_GD(:)*ZSIGT4(:)  &
             - PRHOA(:)*XCPD*PCA(:)*(ZTS_GD(:) - PT_REF(:))                      &
             - PRHOA(:)*XLVTT*PCA(:)*(XPHU_GD*ZQSAT(:) - PQ_REF(:))
   !* denom = -F'(Ts) > 0
   ZDEN(:) = 4.*PEMIS_GD(:)*XSTEFAN*ZTS_GD(:)**3               &
             + PRHOA(:)*XCPD*PCA(:)                            &
             + PRHOA(:)*XLVTT*PCA(:)*XPHU_GD*ZDQSAT(:)
   DO JI_GD = 1, SIZE(PTS_GARDEN)
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
!* final bound on the surface temperature (numerical safety only)
ZTS_GD(:) = MAX(XTSMIN_GD, MIN(XTSMAX_GD, ZTS_GD(:)))
PTS_GARDEN(:) = ZTS_GD(:)
!
!* fluxes at the solved surface temperature (raw, not clipped)
PQSAT_GARDEN(:) = QSAT(PTS_GARDEN(:), PPS(:))
PH_GARDEN(:)    = PRHOA(:)*XCPD *PCA(:)*(PTS_GARDEN(:) - PT_REF(:))
PLE_GARDEN(:)   = PRHOA(:)*XLVTT*PCA(:)*(XPHU_GD*PQSAT_GARDEN(:) - PQ_REF(:))
!
END SUBROUTINE GARDEN_BALANCE
!
END MODULE MODE_GARDEN_BALANCE
!
!     #############
    SUBROUTINE GARDEN_PCD(TYPE_GARDEN, PPCD_GD, PPCH_GD, PV_GD, PT_REF, PQ_REF,              &
                PALB_GD, PEMIS_GD, PRHOA, PPS, PSW, PLW,                                    &
                PRN_GARDEN,PH_GARDEN,PLE_GARDEN,PGFLUX_GARDEN,PSFCO2,                       &
                PEVAP_GARDEN, PUW_GARDEN, PRUNOFF_GARDEN,                                   &
                PAC_GARDEN,PQSAT_GARDEN,PTS_GARDEN,                                         &
                PAC_AGG_GARDEN, PHU_AGG_GARDEN, PDRAIN_GARDEN, PIRRIG_GARDEN                )
!   ##########################################################################
!
!!****  *GARDEN_PCD*
!!
!!    PURPOSE
!!    -------
!!      Diagnostic garden driven by EXTERNAL exchange coefficients: the
!!      dimensionless coefficients of the neutral log profiles and the
!!      reference state (PT_REF, PQ_REF and the wind PV_GD) are provided by the
!!      caller, so that this routine can represent a garden model that receives
!!      its coefficients (and possibly an averaged forcing) from the host.
!!      This routine NEVER computes an exchange coefficient: in particular it
!!      takes NO reference height and NO roughness length, because both are
!!      already inside the coefficients it receives.
!!      The MOMENTUM coefficient PPCD_GD gives the friction flux
!!      Ca_m = PPCD*max(V, Vmin), PUW = -Ca_m*max(V, Vmin); the THERMAL (scalar)
!!      coefficient PPCH_GD gives the aerodynamic conductance used by the surface
!!      energy balance for heat and moisture, Ca_h = PPCH*max(V, Vmin), which is
!!      also the conductance returned for the coupling of the garden with the
!!      canyon air (T_CAN and Q_CAN of TEB). The two are equal when the thermal
!!      roughness is equal to the momentum one (PPCH = PPCD): the caller decides,
!!      GARDEN_PCD applies the coefficients it is given.
!!      'PROXY_OLD' / 'EXT' select the historical fixed Bowen-ratio proxy: it
!!      does not use the coefficient in the energy balance at all (only the
!!      friction flux uses it).
!!      This routine is NOT called by the model (TEB calls GARDEN_TAU): GARDEN
!!      calls it with the neutral-log coefficient of the garden roughness, the
!!      coupling experiments call it with their own (averaged) coefficient.
!!      It returns a SINGLE set of fluxes: it has no information about the tau
!!      scheme of the garden, so it does not build the canyon / atmosphere
!!      branches (the caller duplicates its flux in both of them when needed).
!!
!!**  METHOD
!!    ------
!!      See the header of MODE_GARDEN_BALANCE for the surface balance itself.
!!
!!    AUTHOR
!!    ------
!!      A. Lemonsu          * Meteo-France *
!!
!!    MODIFICATIONS
!!    -------------
!!      Original    05/2009
!!                  01/2026   external coefficient interface (TEB-Ru)
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_CSTS, ONLY : XLVTT , &   ! Latent heat constant for evaporation
                      XCPD,   &   ! specific heat of dry air
                      XSTEFAN     ! Stefan-Boltzmann constant
USE MODE_THERMOS                  ! Function to compute humidity at saturation
USE MODE_GARDEN_BALANCE          ! shared diagnostic balance and its parameters
!
IMPLICIT NONE
!
!*      0.1    Declarations of arguments
!
!* Type of the garden parameterization (from the namelist teb_type_garden)
 CHARACTER(LEN=*),     INTENT(IN)  :: TYPE_GARDEN      ! type of the garden model
!MV202609 external exchange coefficient of the garden
!* Dimensionless coefficients of the neutral log profiles (the reference height
!* and the roughness lengths are already inside them) and the reference state of
!* the garden: the conductance used by the balance for heat and moisture is
!* Ca_h = PPCH_GD*max(PV_GD, XVMIN_GD), the friction flux is
!* -PPCD_GD*max(PV_GD, XVMIN_GD)**2.
!MV202609 garden thermal roughness (z0h)
!* Two coefficients since the thermal roughness z0h is accounted for: PPCD_GD for
!* the momentum (friction), PPCH_GD for heat and moisture (<= PPCD_GD whenever
!* z0h >= z0). With PPCH_GD = PPCD_GD the two paths are the single one of the
!* formulation without thermal roughness.
REAL, DIMENSION(:)  , INTENT(IN)    :: PPCD_GD            ! garden momentum exchange coefficient (-)
REAL, DIMENSION(:)  , INTENT(IN)    :: PPCH_GD            ! garden thermal (scalar) exchange coefficient (-)
REAL, DIMENSION(:)  , INTENT(IN)    :: PV_GD              ! wind of the reference state (m/s)
REAL, DIMENSION(:)  , INTENT(IN)    :: PT_REF             ! reference air temperature (K)
REAL, DIMENSION(:)  , INTENT(IN)    :: PQ_REF             ! reference air humidity (kg/kg)
!
REAL, DIMENSION(:)  , INTENT(IN)    :: PALB_GD            ! garden albedo
REAL, DIMENSION(:)  , INTENT(IN)    :: PEMIS_GD           ! garden emissivity
REAL, DIMENSION(:)  , INTENT(IN)    :: PRHOA              ! air density at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)    :: PPS                ! pressure at the surface
REAL, DIMENSION(:)  , INTENT(IN)    :: PSW                ! received solar radiation
REAL, DIMENSION(:)  , INTENT(IN)    :: PLW                ! received infrared radiation
!
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_GARDEN         ! net radiation over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_GARDEN          ! sensible heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_GARDEN         ! latent heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_GARDEN      ! flux through the green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PSFCO2             ! flux of CO2 (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PEVAP_GARDEN       ! total evaporation (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PUW_GARDEN         ! friction flux (m2/s2)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRUNOFF_GARDEN     ! runoff over garden (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_GARDEN         ! aerodynamical conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PQSAT_GARDEN       ! saturation humidity
REAL, DIMENSION(:)  , INTENT(INOUT) :: PTS_GARDEN         ! radiative surface temp. (snow free)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_AGG_GARDEN     ! aggregated conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PHU_AGG_GARDEN     ! aggregated relative humidity
REAL, DIMENSION(:)  , INTENT(OUT)   :: PDRAIN_GARDEN      ! garden total (vertical) drainage
REAL, DIMENSION(:)  , INTENT(OUT)   :: PIRRIG_GARDEN      ! garden summer irrigation rate
!
!*      0.2    Declarations of local variables
!
REAL, DIMENSION(SIZE(PT_REF)) :: ZCA_GD    ! thermal (scalar) conductance (m/s)
REAL, DIMENSION(SIZE(PT_REF)) :: ZCA_M_GD  ! momentum conductance for the friction (m/s)
REAL, DIMENSION(SIZE(PT_REF)) :: ZV_GD     ! wind used by the conductance (m/s)
INTEGER :: JI_GD
!
!-------------------------------------------------------------------------------
!
IF (TYPE_GARDEN == 'PROXY_NEW') THEN
!
!-------------------------------------------------------------------------------
!*      2.     Diagnostic closed surface energy balance
!*             ------------------------------------------
!*       Rn = H + LE solved for Ts by Newton iteration (no heat flux into the
!*       soil: the garden is a diagnostic proxy without a soil reservoir).
!*       The conductances are built from the INPUT coefficients and wind:
!*       Ca_h = PPCH*max(V, Vmin) for heat and moisture (balance and coupling
!*       with the canyon air), Ca_m = PPCD*max(V, Vmin) for the friction flux
!*       (Vmin keeps the surface coupled at low wind).
!-------------------------------------------------------------------------------
!
!* 2.1  aerodynamic conductances (thermal and momentum) and friction
DO JI_GD = 1, SIZE(PT_REF)
   ZV_GD(JI_GD)    = MAX(PV_GD(JI_GD), XVMIN_GD)
   ZCA_M_GD(JI_GD) = PPCD_GD(JI_GD) * ZV_GD(JI_GD)
   ZCA_GD(JI_GD)   = PPCH_GD(JI_GD) * ZV_GD(JI_GD)
END DO
PAC_GARDEN(:) = ZCA_GD(:)
PUW_GARDEN(:) = -ZCA_M_GD(:) * ZV_GD(:)
!
!* 2.2  surface energy balance at the given conductance and reference air
CALL GARDEN_BALANCE(ZCA_GD, PT_REF, PQ_REF, PRHOA, PPS, PSW, PLW, PALB_GD, PEMIS_GD,  &
                    PTS_GARDEN, PQSAT_GARDEN, PH_GARDEN, PLE_GARDEN)
!
!* 2.3  fluxes
PGFLUX_GARDEN(:) = 0.       ! no heat flux into the soil (diagnostic proxy garden)
PRN_GARDEN(:)    = (1.-PALB_GD(:))*PSW(:) + PEMIS_GD(:)*(PLW(:) - XSTEFAN*PTS_GARDEN(:)**4)
PEVAP_GARDEN(:)  = PLE_GARDEN(:) / XLVTT
!
!* flux clips (safety only; small energy imbalance possible when they bite)
PH_GARDEN(:)     = MAX(-XHMAX_GD,  MIN(XHMAX_GD,  PH_GARDEN(:)))
PLE_GARDEN(:)    = MAX(XLEMIN_GD,  MIN(XLEMAX_GD, PLE_GARDEN(:)))
PEVAP_GARDEN(:)  = PLE_GARDEN(:) / XLVTT
!
!* 2.4  aggregated latent exchange: the conductance couples the garden back to
!*      the air of the reference state (canyon air in TEB)
PAC_AGG_GARDEN(:) = PAC_GARDEN(:)
PHU_AGG_GARDEN(:) = XPHU_GD
!
ELSE
!
!-------------------------------------------------------------------------------
!*      1.     Proxi model based on a fixed Bowen ratio
!              ----------------------------------------
!-------------------------------------------------------------------------------
!
!* net radiation (albedo from the namelist urb_alb_gdn)
PRN_GARDEN(:) = (1.-PALB_GD(:)) * PSW(:)
!
!* Bowen ratio fixed to 0.25
PH_GARDEN (:) = 0.2 * PRN_GARDEN(:)
PLE_GARDEN(:) = 0.8 * PRN_GARDEN(:)
!
!* Conduction heat flux is neglected
PGFLUX_GARDEN(:) = 0.
!
!* evaporation
PEVAP_GARDEN(:) = PLE_GARDEN(:) / XLVTT
!
!* Friction flux: neutral formulation with the MOMENTUM coefficient and wind
!* (the historical proxy does not use the scalar coefficient PPCH_GD)
PUW_GARDEN(:) = - PPCD_GD(:) * PV_GD(:)**2
!
!* Aerodynamical conductance: neglected because used further only for
!  implicitation of canyon air temperature when the heat flux depends on the
!  surface temperature
PAC_GARDEN(:) = 0.
!
!* surface saturation humidity
PQSAT_GARDEN(:) = QSAT(PTS_GARDEN(:),PPS(:))
!
!* aerodynamical conductance for latent heat and surface humidity
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
END SUBROUTINE GARDEN_PCD
!
!     #########
    SUBROUTINE GARDEN(TYPE_GARDEN, PZ_LOWCAN, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN, PZ0_GD,    &
                PZ0_O_Z0H,                                                                &
                PALB_GD, PEMIS_GD, PRHOA, PPS, PSW, PLW,                                  &
                PRN_GARDEN,PH_GARDEN,PLE_GARDEN,PGFLUX_GARDEN,PSFCO2,                     &
                PEVAP_GARDEN, PUW_GARDEN, PRUNOFF_GARDEN,                                 &
                PAC_GARDEN,PQSAT_GARDEN,PTS_GARDEN,                                       &
                PAC_AGG_GARDEN, PHU_AGG_GARDEN, PDRAIN_GARDEN, PIRRIG_GARDEN              )
!   ##########################################################################
!
!!****  *GARDEN*
!!
!!    PURPOSE
!!    -------
!!      Reduced diagnostic garden of TEB-Ru, without the tau split: this is the
!!      behaviour of the model before the tau scheme of the garden exchange was
!!      introduced. The dimensionless coefficients of the neutral log profiles
!!      are computed here from the reference height and the garden roughness
!!      lengths: PCD = (kappa/ln(zref/z0))**2 for the momentum (friction) and
!!      PCH = kappa**2/(ln(zref/z0)*ln(zref/z0h)) for heat and moisture, with the
!!      thermal roughness z0h = z0/PZ0_O_Z0H; GARDEN_PCD is called with the two of
!!      them (that routine performs the surface balance itself).
!!      'PROXY_OLD' / 'EXT' select the historical fixed Bowen-ratio proxy, which
!!      does not use any exchange coefficient at all.
!!      This routine is NOT called by the model (TEB calls GARDEN_TAU): it is the
!!      reference implementation used by the offline garden experiments.
!!      It returns a SINGLE set of fluxes (no tau scheme, hence no canyon /
!!      atmosphere branch decomposition: the caller duplicates the flux).
!!
!!**  METHOD
!!    ------
!!      See the header of MODE_GARDEN_BALANCE for the shared surface balance.
!!
!!    AUTHOR
!!    ------
!!      A. Lemonsu          * Meteo-France *
!!
!!    MODIFICATIONS
!!    -------------
!!      Original    05/2009
!!                  01/2026   split of the garden routines (TEB-Ru)
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODI_GARDEN, ONLY : GARDEN_PCD   ! the routine doing the surface balance
USE MODE_GARDEN_BALANCE              ! neutral formulation and its parameters
!
IMPLICIT NONE
!
!*      0.1    Declarations of arguments
!
!* Type of the garden parameterization (from the namelist teb_type_garden)
 CHARACTER(LEN=*),     INTENT(IN)  :: TYPE_GARDEN      ! type of the garden model
REAL, DIMENSION(:)  , INTENT(IN)  :: PZ_LOWCAN        ! height of the reference air (m)
REAL, DIMENSION(:)  , INTENT(IN)  :: PT_LOWCAN        ! reference air temperature (K)
REAL, DIMENSION(:)  , INTENT(IN)  :: PQ_LOWCAN        ! reference air humidity (kg/kg)
REAL, DIMENSION(:)  , INTENT(IN)  :: PU_LOWCAN        ! reference wind (m/s)
REAL, DIMENSION(:)  , INTENT(IN)  :: PZ0_GD           ! garden roughness length (m)
!MV202609 garden thermal roughness (z0h)
!* z0/z0h ratio of the garden (-), >= 1: the scalar (thermal) roughness is
!* z0h = PZ0_GD/PZ0_O_Z0H, see GARDEN_PCH_NEUTRAL
REAL,               INTENT(IN)  :: PZ0_O_Z0H        ! garden z0/z0h ratio (-)
REAL, DIMENSION(:)  , INTENT(IN)  :: PALB_GD          ! garden albedo
REAL, DIMENSION(:)  , INTENT(IN)  :: PEMIS_GD         ! garden emissivity
REAL, DIMENSION(:)  , INTENT(IN)  :: PRHOA            ! air density at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)  :: PPS              ! pressure at the surface
REAL, DIMENSION(:)  , INTENT(IN)  :: PSW              ! received solar radiation
REAL, DIMENSION(:)  , INTENT(IN)  :: PLW              ! received infrared radiation
!
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_GARDEN         ! net radiation over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_GARDEN          ! sensible heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_GARDEN         ! latent heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_GARDEN      ! flux through the green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PSFCO2             ! flux of CO2 (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PEVAP_GARDEN       ! total evaporation (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PUW_GARDEN         ! friction flux (m2/s2)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRUNOFF_GARDEN     ! runoff over garden (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_GARDEN         ! aerodynamical conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PQSAT_GARDEN       ! saturation humidity
REAL, DIMENSION(:)  , INTENT(INOUT) :: PTS_GARDEN         ! radiative surface temp. (snow free)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_AGG_GARDEN     ! aggregated conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PHU_AGG_GARDEN     ! aggregated relative humidity
REAL, DIMENSION(:)  , INTENT(OUT)   :: PDRAIN_GARDEN      ! garden total (vertical) drainage
REAL, DIMENSION(:)  , INTENT(OUT)   :: PIRRIG_GARDEN      ! garden summer irrigation rate
!
!*      0.2    Declarations of local variables
!
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZPCD_GD   ! neutral-log momentum coefficient (-)
!MV202609 garden thermal roughness (z0h)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZPCH_GD   ! neutral-log thermal (scalar) coefficient (-)
INTEGER :: JI_GD
!
!-------------------------------------------------------------------------------
!
!*      1.     Dimensionless coefficients of the neutral log profiles
!*             PCD = (kappa/ln(zref/z0))**2 and
!*             PCH = kappa**2/(ln(zref/z0)*ln(zref/z0h))  (both 0 when z0 is not
!*             below zref), from the shared neutral formulation of this module
!
DO JI_GD = 1, SIZE(PT_LOWCAN)
   ZPCD_GD(JI_GD) = GARDEN_PCD_NEUTRAL(PZ_LOWCAN(JI_GD), PZ0_GD(JI_GD))
   ZPCH_GD(JI_GD) = GARDEN_PCH_NEUTRAL(PZ_LOWCAN(JI_GD), PZ0_GD(JI_GD), PZ0_O_Z0H)
END DO
!
!-------------------------------------------------------------------------------
!
!*      2.     Surface balance of the garden (the coefficients, the wind and the
!*             reference air are handed over to GARDEN_PCD)
!              ----------------------------------------------------------
!
CALL GARDEN_PCD(TYPE_GARDEN, ZPCD_GD, ZPCH_GD, PU_LOWCAN, PT_LOWCAN, PQ_LOWCAN, PALB_GD, PEMIS_GD,  &
                PRHOA, PPS, PSW, PLW,                                                       &
                PRN_GARDEN, PH_GARDEN, PLE_GARDEN, PGFLUX_GARDEN, PSFCO2, PEVAP_GARDEN,     &
                PUW_GARDEN, PRUNOFF_GARDEN, PAC_GARDEN, PQSAT_GARDEN, PTS_GARDEN,           &
                PAC_AGG_GARDEN, PHU_AGG_GARDEN, PDRAIN_GARDEN, PIRRIG_GARDEN)
!
!-------------------------------------------------------------------------------
!
END SUBROUTINE GARDEN
!
!     #############
    SUBROUTINE GARDEN_TAU(TYPE_GARDEN, PZ_LOWCAN, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN, PZ0_GD, &
                PZ0_O_Z0H,                                                                &
                PUREF, PVMOD, PTA, PQA, PTAU, LTAU_SPLIT,                                  &
                PALB_GD, PEMIS_GD, PRHOA, PPS, PSW, PLW,                                   &
                PRN_GARDEN,PH_GARDEN,PLE_GARDEN,PGFLUX_GARDEN,PSFCO2,                      &
                PEVAP_GARDEN, PUW_GARDEN, PRUNOFF_GARDEN,                                  &
                PAC_GARDEN,PQSAT_GARDEN,PTS_GARDEN,                                        &
                PAC_AGG_GARDEN, PHU_AGG_GARDEN, PDRAIN_GARDEN, PIRRIG_GARDEN,              &
!MV202609 tau scheme of the garden (canyon and atmosphere branch fluxes)
                PH_GARDEN_CAN, PH_GARDEN_ATM, PLE_GARDEN_CAN, PLE_GARDEN_ATM               )
!   ##########################################################################
!
!!****  *GARDEN_TAU*
!!
!!    PURPOSE
!!    -------
!!      Garden model of TEB with the tau scheme: the exchange of the garden is
!!      split into a garden/canyon path (weight tau) and a direct
!!      garden/atmosphere path (weight 1 - tau). The garden remains a single
!!      surface, so the energy budget is solved for one surface temperature with
!!      the tau-aggregated conductance and the tau-aggregated reference air
!!      (GARDEN_BALANCE is called directly: the tau-aggregated conductance cannot
!!      be represented by a single PCD*max(V, Vmin) product).
!!      Without the split ('PROXY_NEW' with the tau scheme disabled) and for the
!!      historical Bowen-ratio proxy ('PROXY_OLD' / 'EXT') the reduced GARDEN
!!      routine is called instead, so that the behaviour of the model before the
!!      tau scheme is reproduced exactly.
!!      GARDEN_TAU is the ONLY garden routine returning the canyon / atmosphere
!!      branch decomposition PH_GARDEN_CAN/ATM and PLE_GARDEN_CAN/ATM. In the
!!      non-tau path the reduced garden has a single flux: it is reported in
!!      both branches, so that the blend H = PTAU*H_CAN + (1-PTAU)*H_ATM holds
!!      identically (and reproduces the former behaviour when tau = 1).
!!
!!**  METHOD
!!    ------
!!      See the header of MODE_GARDEN_BALANCE for the shared surface balance.
!!
!!    AUTHOR
!!    ------
!!      A. Lemonsu          * Meteo-France *
!!
!!    MODIFICATIONS
!!    -------------
!!      Original    05/2009
!!                  01/2026   tau split of the garden exchange (TEB-Ru)
!-------------------------------------------------------------------------------
!
!*       0.     DECLARATIONS
!               ------------
!
USE MODD_CSTS, ONLY : XLVTT , &   ! Latent heat constant for evaporation
                      XKARMAN, &  ! Von Karman constant
                      XCPD,    &  ! specific heat of dry air
                      XSTEFAN     ! Stefan-Boltzmann constant
USE MODI_GARDEN, ONLY : GARDEN    ! reduced garden used without the split
USE MODE_GARDEN_BALANCE          ! shared diagnostic balance and its parameters
!
IMPLICIT NONE
!
!*      0.1    Declarations of arguments
!
!* Type of the garden parameterization (from the namelist teb_type_garden):
!*   'PROXY_OLD' : fixed Bowen-ratio proxy (the historical scheme)
!*   'PROXY_NEW' : diagnostic closed surface energy balance (default)
!*   'EXT'       : external garden model (Bowen-ratio placeholder)
 CHARACTER(LEN=*),     INTENT(IN)  :: TYPE_GARDEN      ! type of the garden model
!* Reference state of the canyon air (the low canyon level of TEB)
REAL, DIMENSION(:)  , INTENT(IN)  :: PZ_LOWCAN        ! height of the reference air (m)
REAL, DIMENSION(:)  , INTENT(IN)  :: PT_LOWCAN        ! reference air temperature (K)
REAL, DIMENSION(:)  , INTENT(IN)  :: PQ_LOWCAN        ! reference air humidity (kg/kg)
REAL, DIMENSION(:)  , INTENT(IN)  :: PU_LOWCAN        ! reference wind (m/s)
REAL, DIMENSION(:)  , INTENT(IN)  :: PZ0_GD           ! garden roughness length (m)
!MV202609 garden thermal roughness (z0h)
!* z0/z0h ratio of the garden (-), >= 1: the scalar (thermal) roughness is
!* z0h = PZ0_GD/PZ0_O_Z0H, see GARDEN_PCH_NEUTRAL
REAL,               INTENT(IN)  :: PZ0_O_Z0H        ! garden z0/z0h ratio (-)
!MV202609 tau scheme of the garden
!* Reference state of the air of the forcing level (used by the tau split)
REAL, DIMENSION(:)  , INTENT(IN)  :: PUREF            ! height of the wind of the forcing level (m)
REAL, DIMENSION(:)  , INTENT(IN)  :: PVMOD            ! wind speed at the forcing level (m/s)
REAL, DIMENSION(:)  , INTENT(IN)  :: PTA              ! air temperature of the forcing level (K)
REAL, DIMENSION(:)  , INTENT(IN)  :: PQA              ! air specific humidity of the forcing level (kg/kg)
REAL, DIMENSION(:)  , INTENT(IN)  :: PTAU             ! tau weight of the canyon path (-)
LOGICAL             , INTENT(IN)  :: LTAU_SPLIT       ! .TRUE.: split the garden exchange by tau
!
REAL, DIMENSION(:)  , INTENT(IN)    :: PALB_GD            ! garden albedo
REAL, DIMENSION(:)  , INTENT(IN)    :: PEMIS_GD           ! garden emissivity
REAL, DIMENSION(:)  , INTENT(IN)    :: PRHOA              ! air density at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)    :: PPS                ! pressure at the surface
REAL, DIMENSION(:)  , INTENT(IN)    :: PSW                ! received solar radiation
REAL, DIMENSION(:)  , INTENT(IN)    :: PLW                ! received infrared radiation
!
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRN_GARDEN         ! net radiation over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_GARDEN          ! sensible heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_GARDEN         ! latent heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PGFLUX_GARDEN      ! flux through the green areas
REAL, DIMENSION(:)  , INTENT(OUT)   :: PSFCO2             ! flux of CO2 (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PEVAP_GARDEN       ! total evaporation (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PUW_GARDEN         ! friction flux (m2/s2)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PRUNOFF_GARDEN     ! runoff over garden (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_GARDEN         ! aerodynamical conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PQSAT_GARDEN       ! saturation humidity
REAL, DIMENSION(:)  , INTENT(INOUT) :: PTS_GARDEN         ! radiative surface temp. (snow free)
REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_AGG_GARDEN     ! aggregated conductance
REAL, DIMENSION(:)  , INTENT(OUT)   :: PHU_AGG_GARDEN     ! aggregated relative humidity
REAL, DIMENSION(:)  , INTENT(OUT)   :: PDRAIN_GARDEN      ! garden total (vertical) drainage
REAL, DIMENSION(:)  , INTENT(OUT)   :: PIRRIG_GARDEN      ! garden summer irrigation rate
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_GARDEN_CAN      ! sensible heat flux, canyon branch
REAL, DIMENSION(:)  , INTENT(OUT)   :: PH_GARDEN_ATM      ! sensible heat flux, atmosphere branch
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_GARDEN_CAN     ! latent heat flux, canyon branch
REAL, DIMENSION(:)  , INTENT(OUT)   :: PLE_GARDEN_ATM     ! latent heat flux, atmosphere branch
!
!*      0.2    Declarations of local variables
!
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZCA_GD   ! canyon-path thermal (scalar) conductance (m/s)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZCA_M_GD ! canyon-path momentum conductance, friction (m/s)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZCA_ATM  ! atmosphere-path thermal conductance (m/s)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZCA_EFF  ! tau-aggregated conductance (m/s)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZT_REF   ! tau-mixed reference air temperature (K)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZQ_REF   ! tau-mixed reference air humidity (kg/kg)
REAL, DIMENSION(SIZE(PT_LOWCAN)) :: ZV_GD    ! canyon-path wind (m/s)
INTEGER :: JI_GD
!
!-------------------------------------------------------------------------------
!
!* Garden model selected by teb_type_garden (namelist):
!*   'PROXY_NEW' with the tau scheme ON : diagnostic balance with the tau split
!*   'PROXY_NEW' with the tau scheme OFF: reduced diagnostic garden (GARDEN)
!*   'PROXY_OLD' / 'EXT'                : historical Bowen proxy (GARDEN)
!
IF (TYPE_GARDEN == 'PROXY_NEW' .AND. LTAU_SPLIT) THEN
!
!-------------------------------------------------------------------------------
!*      2.     Diagnostic closed surface energy balance with the tau split
!*             ----------------------------------------------------------
!*       The garden remains a single surface: the energy budget is solved for one
!*       Ts with the tau-aggregated conductance and the tau-aggregated reference
!*       air, so that the actual flux is identically
!*       PTAU*PH_GARDEN_CAN + (1-PTAU)*PH_GARDEN_ATM (same for LE). With tau = 1,
!*       or with a vanishing aggregated conductance, the canyon-only values are
!*       kept, so that the single-forcing behaviour is reproduced exactly.
!-------------------------------------------------------------------------------
!
!* 2.1  canyon-path THERMAL conductance for heat and moisture (reference air
!*      PT_LOWCAN/PQ_LOWCAN at the height PZ_LOWCAN) and atmosphere-path THERMAL
!*      conductance (PTA/PQA with the wind PVMOD at the height PUREF); a minimum
!*      wind speed keeps the surface coupled. The friction flux of the garden
!*      uses the MOMENTUM conductance of the canyon path (z0h does not act on
!*      the momentum)
DO JI_GD = 1, SIZE(PT_LOWCAN)
   ZV_GD(JI_GD)    = MAX(PU_LOWCAN(JI_GD), XVMIN_GD)
   ZCA_M_GD(JI_GD) = GARDEN_CA_NEUTRAL (PZ_LOWCAN(JI_GD), PZ0_GD(JI_GD), PU_LOWCAN(JI_GD))
   ZCA_GD(JI_GD)   = GARDEN_CAH_NEUTRAL(PZ_LOWCAN(JI_GD), PZ0_GD(JI_GD), PZ0_O_Z0H, PU_LOWCAN(JI_GD))
END DO
PAC_GARDEN(:) = ZCA_GD(:)
PUW_GARDEN(:) = -ZCA_M_GD(:) * ZV_GD(:)
!
ZCA_ATM(:) = 0.
ZCA_EFF(:) = ZCA_GD(:)
ZT_REF (:) = PT_LOWCAN(:)
ZQ_REF (:) = PQ_LOWCAN(:)
DO JI_GD = 1, SIZE(PT_LOWCAN)
   ZCA_ATM(JI_GD) = GARDEN_CAH_NEUTRAL(PUREF(JI_GD), PZ0_GD(JI_GD), PZ0_O_Z0H, PVMOD(JI_GD))
   IF (PTAU(JI_GD) < 1.) THEN
      ZCA_EFF(JI_GD) = PTAU(JI_GD) * ZCA_GD(JI_GD) + (1.-PTAU(JI_GD)) * ZCA_ATM(JI_GD)
      IF (ZCA_EFF(JI_GD) > 0.) THEN
         ZT_REF(JI_GD) = ( PTAU(JI_GD) * ZCA_GD(JI_GD) * PT_LOWCAN(JI_GD)      &
                         + (1.-PTAU(JI_GD)) * ZCA_ATM(JI_GD) * PTA(JI_GD) )    &
                       / ZCA_EFF(JI_GD)
         ZQ_REF(JI_GD) = ( PTAU(JI_GD) * ZCA_GD(JI_GD) * PQ_LOWCAN(JI_GD)      &
                         + (1.-PTAU(JI_GD)) * ZCA_ATM(JI_GD) * PQA(JI_GD) )    &
                       / ZCA_EFF(JI_GD)
      END IF
   END IF
END DO
!
!* 2.2  surface energy balance: one Newton solve with the tau-aggregated
!*      conductance and reference air (shared solver; G = 0)
CALL GARDEN_BALANCE(ZCA_EFF, ZT_REF, ZQ_REF, PRHOA, PPS, PSW, PLW, PALB_GD, PEMIS_GD,  &
                    PTS_GARDEN, PQSAT_GARDEN, PH_GARDEN, PLE_GARDEN)
!
!* 2.3  actual (tau-aggregated) fluxes and their canyon / atmosphere branches:
!*      the three of them share the same surface temperature, so that
!*      PH_GARDEN = PTAU*PH_GARDEN_CAN + (1-PTAU)*PH_GARDEN_ATM holds identically
PH_GARDEN_CAN(:)  = PRHOA(:)*XCPD *ZCA_GD (:)*(PTS_GARDEN(:) - PT_LOWCAN(:))
PH_GARDEN_ATM(:)  = PRHOA(:)*XCPD *ZCA_ATM(:)*(PTS_GARDEN(:) - PTA(:))
PLE_GARDEN_CAN(:) = PRHOA(:)*XLVTT*ZCA_GD (:)*(XPHU_GD*PQSAT_GARDEN(:) - PQ_LOWCAN(:))
PLE_GARDEN_ATM(:) = PRHOA(:)*XLVTT*ZCA_ATM(:)*(XPHU_GD*PQSAT_GARDEN(:) - PQA(:))
PGFLUX_GARDEN(:) = 0.       ! no heat flux into the soil (diagnostic proxy garden)
PRN_GARDEN(:)    = (1.-PALB_GD(:))*PSW(:) + PEMIS_GD(:)*(PLW(:) - XSTEFAN*PTS_GARDEN(:)**4)
PEVAP_GARDEN(:)  = PLE_GARDEN(:) / XLVTT
!
!* flux clips (safety only; small energy imbalance possible when they bite)
PH_GARDEN(:)     = MAX(-XHMAX_GD,  MIN(XHMAX_GD,  PH_GARDEN(:)))
PLE_GARDEN(:)    = MAX(XLEMIN_GD,  MIN(XLEMAX_GD, PLE_GARDEN(:)))
PEVAP_GARDEN(:)  = PLE_GARDEN(:) / XLVTT
!
!* 2.4  aggregated latent exchange: the canyon-path conductance couples the
!*      garden back to the canyon air (T_CANYON / Q_CANYON)
PAC_AGG_GARDEN(:) = PAC_GARDEN(:)
PHU_AGG_GARDEN(:) = XPHU_GD
!
ELSE
!
!* 'PROXY_NEW' without the tau split and the historical Bowen-ratio proxy
!* ('PROXY_OLD' / 'EXT'): the reduced diagnostic garden of GARDEN
CALL GARDEN(TYPE_GARDEN, PZ_LOWCAN, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN, PZ0_GD,             &
            PZ0_O_Z0H,                                                                    &
            PALB_GD, PEMIS_GD, PRHOA, PPS, PSW, PLW,                                     &
            PRN_GARDEN, PH_GARDEN, PLE_GARDEN, PGFLUX_GARDEN, PSFCO2, PEVAP_GARDEN,      &
            PUW_GARDEN, PRUNOFF_GARDEN, PAC_GARDEN, PQSAT_GARDEN, PTS_GARDEN,            &
            PAC_AGG_GARDEN, PHU_AGG_GARDEN, PDRAIN_GARDEN, PIRRIG_GARDEN)
!
!* GARDEN_TAU is the ONLY routine returning the tau-branch decomposition: the
!* reduced garden has no tau split, so both branches carry its single modelled
!* flux (the blend H = PTAU*H_CAN + (1-PTAU)*H_ATM is then trivial and, with
!* tau = 1, reproduces the former single-forcing behaviour exactly)
PH_GARDEN_CAN (:) = PH_GARDEN(:)
PH_GARDEN_ATM (:) = PH_GARDEN(:)
PLE_GARDEN_CAN(:) = PLE_GARDEN(:)
PLE_GARDEN_ATM(:) = PLE_GARDEN(:)
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
END SUBROUTINE GARDEN_TAU