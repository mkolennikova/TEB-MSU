!     #####################
MODULE MODE_URBAN_UTCI
!     #####################
!!****  *MODE_URBAN_UTCI* - Outdoor Universal Thermal Climate Index.
!!
!!    METHOD
!!    ------
!!    Operational UTCI polynomial, version a 0.002 (October 2009).
!!    Coefficients copyright (C) 2009 Peter Broede, used as provided in the
!!    UTCI Program Code distribution at https://utci.org/resources/ .
!!    Broede et al. (2012), doi:10.1007/s00484-011-0454-1.
!!
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      11/2026 -- OpenAI Codex
!!        Diagnose canyon UTCI from pedestrian wind and the road MRT classes.
USE, INTRINSIC :: IEEE_ARITHMETIC, ONLY : IEEE_IS_FINITE
USE MODD_CSTS,     ONLY : XRD, XRV
USE MODD_SURF_PAR, ONLY : XUNDEF
USE MODE_URBAN_MRT, ONLY : XZ_PED
IMPLICIT NONE
PRIVATE
PUBLIC :: CANYON_UTCI

REAL, PARAMETER :: XCELSIUS_ZERO = 273.15
REAL, PARAMETER :: XREFERENCE_Z0 = 0.01  ! UTCI reference wind profile (m)
REAL, PARAMETER :: XWIND_RATIO = LOG(10./XREFERENCE_Z0)/LOG(XZ_PED/XREFERENCE_Z0)

! Regression for the offset from air temperature. Monomials have total degree
! <= 6. Within each group, wind power increases from row to row and temperature
! power increases within a row (some rows continue onto a second line).
REAL, PARAMETER :: XCOEFF(210) = [ &
  ! Vapour pressure power 0, radiant temperature difference power 0
   6.07562052E-01, -2.27712343E-02,  8.06470249E-04, -1.54271372E-04, &
  -3.24651735E-06,  7.32602852E-08,  1.35959073E-09, &
  -2.25836520E+00,  8.80326035E-02,  2.16844454E-03, -1.53347087E-05, &
  -5.72983704E-07, -2.55090145E-09, &
  -7.51269505E-01, -4.08350271E-03, -5.21670675E-05,  1.94544667E-06, &
   1.14099531E-08, &
   1.58137256E-01, -6.57263143E-05,  2.22697524E-07, -4.16117031E-08, &
  -1.27762753E-02,  9.66891875E-06,  2.52785852E-09, &
   4.56306672E-04, -1.74202546E-07, &
  -5.91491269E-06, &
  ! Vapour pressure power 0, radiant temperature difference power 1
   3.98374029E-01,  1.83945314E-04, -1.73754510E-04, -7.60781159E-07, &
   3.77830287E-08,  5.43079673E-10, &
  -2.00518269E-02,  8.92859837E-04,  3.45433048E-06, -3.77925774E-07, &
  -1.69699377E-09, &
   1.69992415E-04, -4.99204314E-05,  2.47417178E-07,  1.07596466E-08, &
   8.49242932E-05,  1.35191328E-06, -6.21531254E-09, &
  -4.99410301E-06, -1.89489258E-08, &
   8.15300114E-08, &
  ! Vapour pressure power 0, radiant temperature difference power 2
   7.55043090E-04, -5.65095215E-05, -4.52166564E-07,  2.46688878E-08, &
   2.42674348E-10, &
   1.54547250E-04,  5.24110970E-06, -8.75874982E-08, -1.50743064E-09, &
  -1.56236307E-05, -1.33895614E-07,  2.49709824E-09, &
   6.51711721E-07,  1.94960053E-09, &
  -1.00361113E-08, &
  ! Vapour pressure power 0, radiant temperature difference power 3
  -1.21206673E-05, -2.18203660E-07,  7.51269482E-09,  9.79063848E-11, &
   1.25006734E-06, -1.81584736E-09, -3.52197671E-10, &
  -3.36514630E-08,  1.35908359E-10, &
   4.17032620E-10, &
  ! Vapour pressure power 0, radiant temperature difference power 4
  -1.30369025E-09,  4.13908461E-10,  9.22652254E-12, &
  -5.08220384E-09, -2.24730961E-11, &
   1.17139133E-10, &
  ! Vapour pressure power 0, radiant temperature difference power 5
   6.62154879E-10,  4.03863260E-13, &
   1.95087203E-12, &
  ! Vapour pressure power 0, radiant temperature difference power 6
  -4.73602469E-12, &
  ! Vapour pressure power 1, radiant temperature difference power 0
   5.12733497E+00, -3.12788561E-01, -1.96701861E-02,  9.99690870E-04, &
   9.51738512E-06, -4.66426341E-07, &
   5.48050612E-01, -3.30552823E-03, -1.64119440E-03, -5.16670694E-06, &
   9.52692432E-07, &
  -4.29223622E-02,  5.00845667E-03,  1.00601257E-06, -1.81748644E-06, &
  -1.25813502E-03, -1.79330391E-04,  2.34994441E-06, &
   1.29735808E-04,  1.29064870E-06, &
  -2.28558686E-06, &
  ! Vapour pressure power 1, radiant temperature difference power 1
  -3.69476348E-02,  1.62325322E-03, -3.14279680E-05,  2.59835559E-06, &
  -4.77136523E-08, &
   8.64203390E-03, -6.87405181E-04, -9.13863872E-06,  5.15916806E-07, &
  -3.59217476E-05,  3.28696511E-05, -7.10542454E-07, &
  -1.24382300E-05, -7.38584400E-09, &
   2.20609296E-07, &
  ! Vapour pressure power 1, radiant temperature difference power 2
  -7.32469180E-04, -1.87381964E-05,  4.80925239E-06, -8.75492040E-08, &
   2.77862930E-05, -5.06004592E-06,  1.14325367E-07, &
   2.53016723E-06, -1.72857035E-08, &
  -3.95079398E-08, &
  ! Vapour pressure power 1, radiant temperature difference power 3
  -3.59413173E-07,  7.04388046E-07, -1.89309167E-08, &
  -4.79768731E-07,  7.96079978E-09, &
   1.62897058E-09, &
  ! Vapour pressure power 1, radiant temperature difference power 4
   3.94367674E-08, -1.18566247E-09, &
   3.34678041E-10, &
  ! Vapour pressure power 1, radiant temperature difference power 5
  -1.15606447E-10, &
  ! Vapour pressure power 2, radiant temperature difference power 0
  -2.80626406E+00,  5.48712484E-01, -3.99428410E-03, -9.54009191E-04, &
   1.93090978E-05, &
  -3.08806365E-01,  1.16952364E-02,  4.95271903E-04, -1.90710882E-05, &
   2.10787756E-03, -6.98445738E-04,  2.30109073E-05, &
   4.17856590E-04, -1.27043871E-05, &
  -3.04620472E-06, &
  ! Vapour pressure power 2, radiant temperature difference power 1
   5.14507424E-02, -4.32510997E-03,  8.99281156E-05, -7.14663943E-07, &
  -2.66016305E-04,  2.63789586E-04, -7.01199003E-06, &
  -1.06823306E-04,  3.61341136E-06, &
   2.29748967E-07, &
  ! Vapour pressure power 2, radiant temperature difference power 2
   3.04788893E-04, -6.42070836E-05,  1.16257971E-06, &
   7.68023384E-06, -5.47446896E-07, &
  -3.59937910E-08, &
  ! Vapour pressure power 2, radiant temperature difference power 3
  -4.36497725E-06,  1.68737969E-07, &
   2.67489271E-08, &
  ! Vapour pressure power 2, radiant temperature difference power 4
   3.23926897E-09, &
  ! Vapour pressure power 3, radiant temperature difference power 0
  -3.53874123E-02, -2.21201190E-01,  1.55126038E-02, -2.63917279E-04, &
   4.53433455E-02, -4.32943862E-03,  1.45389826E-04, &
   2.17508610E-04, -6.66724702E-05, &
   3.33217140E-05, &
  ! Vapour pressure power 3, radiant temperature difference power 1
  -2.26921615E-03,  3.80261982E-04, -5.45314314E-09, &
  -7.96355448E-04,  2.53458034E-05, &
  -6.31223658E-06, &
  ! Vapour pressure power 3, radiant temperature difference power 2
   3.02122035E-04, -4.77403547E-06, &
   1.73825715E-06, &
  ! Vapour pressure power 3, radiant temperature difference power 3
  -4.09087898E-07, &
  ! Vapour pressure power 4, radiant temperature difference power 0
   6.14155345E-01, -6.16755931E-02,  1.33374846E-03, &
   3.55375387E-03, -5.13027851E-04, &
   1.02449757E-04, &
  ! Vapour pressure power 4, radiant temperature difference power 1
  -1.48526421E-03, -4.11469183E-05, &
  -6.80434415E-06, &
  ! Vapour pressure power 4, radiant temperature difference power 2
  -9.77675906E-06, &
  ! Vapour pressure power 5, radiant temperature difference power 0
   8.82773108E-02, -3.01859306E-03, &
   1.04452989E-03, &
  ! Vapour pressure power 5, radiant temperature difference power 1
   2.47090539E-04, &
  ! Vapour pressure power 6, radiant temperature difference power 0
   1.48348065E-03 ]

CONTAINS

!-------------------------------------------------------------------------------
PURE SUBROUTINE CANYON_UTCI(PTA, PQ, PP, PWIND_PED, PMRT, PUTCI, PWIND_10M)
REAL, INTENT(IN)  :: PTA, PQ, PP, PWIND_PED ! K, kg/kg specific humidity, Pa, m/s
REAL, INTENT(IN)  :: PMRT(:)                ! mean radiant temperatures (K)
REAL, INTENT(OUT) :: PUTCI(SIZE(PMRT))      ! UTCI equivalent temperatures (degC)
REAL, INTENT(OUT) :: PWIND_10M              ! effective polynomial input (m/s)
REAL :: ZTA, ZVP, ZVP_MAX, ZEPS
REAL :: ZCOEFF_RAD(0:6), ZWIND_PART, ZTEMP_PART, ZOFFSET, ZDELTA
INTEGER :: ICOEFF, JHUM, JRAD, JWIND, JTEMP, JCLASS

PUTCI = XUNDEF
PWIND_10M = XUNDEF
IF (.NOT. IEEE_IS_FINITE(PWIND_PED)) RETURN
IF (PWIND_PED < 0. .OR. PWIND_PED > 17./XWIND_RATIO) RETURN
! Invert the neutral reference profile using the model wind at body height.
! Calm conditions are represented by the lowest wind in the fitted range.
PWIND_10M = MIN(17.,MAX(0.5,PWIND_PED*XWIND_RATIO))

IF (.NOT. ALL(IEEE_IS_FINITE([PTA,PQ,PP]))) RETURN
IF (PTA < XCELSIUS_ZERO-50. .OR. PTA > XCELSIUS_ZERO+50.) RETURN
IF (PQ < 0. .OR. PQ >= 1. .OR. PP <= 0. .OR. PP >= XUNDEF) RETURN
ZTA = PTA-XCELSIUS_ZERO
ZEPS = XRD/XRV
ZVP = 0.001*PP*PQ/(ZEPS+(1.-ZEPS)*PQ)
ZVP_MAX = MIN(5.,SATURATION_WATER_KPA(PTA))
! Allow roundoff from conversion of an exactly saturated or 5 kPa input.
IF (ZVP > ZVP_MAX + 64.*EPSILON(ZVP)*ZVP_MAX) RETURN
ZVP = MIN(ZVP,ZVP_MAX)

! Horner evaluation. Air temperature, wind and vapour pressure are shared by
! all MRT classes, so evaluate their terms only once per sub-step.
ICOEFF = SIZE(XCOEFF)
ZCOEFF_RAD = 0.
DO JHUM=6,0,-1
  DO JRAD=6-JHUM,0,-1
    ZWIND_PART = 0.
    DO JWIND=6-JHUM-JRAD,0,-1
      ZTEMP_PART = 0.
      DO JTEMP=6-JHUM-JRAD-JWIND,0,-1
        ZTEMP_PART = ZTEMP_PART*ZTA + XCOEFF(ICOEFF)
        ICOEFF = ICOEFF-1
      END DO
      ZWIND_PART = ZWIND_PART*PWIND_10M + ZTEMP_PART
    END DO
    ZCOEFF_RAD(JRAD) = ZCOEFF_RAD(JRAD)*ZVP + ZWIND_PART
  END DO
END DO

DO JCLASS=1,SIZE(PMRT)
  IF (.NOT. IEEE_IS_FINITE(PMRT(JCLASS))) CYCLE
  IF (PMRT(JCLASS) < PTA-30. .OR. PMRT(JCLASS) > PTA+70.) CYCLE
  ZDELTA = PMRT(JCLASS)-PTA
  ZOFFSET = ZCOEFF_RAD(6)
  DO JRAD=5,0,-1
    ZOFFSET = ZOFFSET*ZDELTA + ZCOEFF_RAD(JRAD)
  END DO
  PUTCI(JCLASS) = ZTA + ZOFFSET
END DO
END SUBROUTINE CANYON_UTCI

!-------------------------------------------------------------------------------
PURE REAL FUNCTION SATURATION_WATER_KPA(PT) RESULT(PES)
! ITS-90 saturation over liquid water (Hardy, 1998), as used in UTCI a 0.002.
! Specific humidity already determines e. This calculation checks RH <= 100%.
REAL, INTENT(IN) :: PT  ! air temperature (K)
REAL, PARAMETER :: XG(0:6) = [-2836.5744, -6028.076559, 19.54263612, -0.02737830188, &
                              1.6261698E-5, 7.0229056E-10, -1.8680009E-13]
REAL :: ZLOG_PA
INTEGER :: J
ZLOG_PA = 2.7150305*LOG(PT)
DO J=0,6
  ZLOG_PA = ZLOG_PA + XG(J)*PT**(J-2)
END DO
PES = 0.001*EXP(ZLOG_PA)
END FUNCTION SATURATION_WATER_KPA
END MODULE MODE_URBAN_UTCI
