!     #########

MODULE WIND_PROFILE_WANG

!------------------------------------------------------------------------------
! Public subroutines
!------------------------------------------------------------------------------

PUBLIC :: WIND_CALCULATION_WANG

!------------------------------------------------------------------------------
! Parameters and variables which are global in this module
!------------------------------------------------------------------------------

CONTAINS



SUBROUTINE WIND_CALCULATION_WANG(icell, iblock, PBLD_HEIGHT, PUSTAR_TOWN, PU_TOP, PU, PV, PFAI, PU_CANYON_WANG) 
!     ##################
!
!-------------------------------------------------------------------------------
!
!*       0.    DECLARATIONS
!              ------------
!
! global variables
INTEGER                          :: ntstep            !IN timestep
INTEGER                          :: icell             !IN number of cell in the block
REAL, DIMENSION(:),INTENT(IN)    :: PBLD_HEIGHT
REAL, DIMENSION(:),INTENT(IN)    :: PUSTAR_TOWN
REAL, DIMENSION(:),INTENT(IN)    :: PU_TOP
REAL, DIMENSION(:),INTENT(IN)    :: PU
REAL, DIMENSION(:),INTENT(IN)    :: PV
REAL, DIMENSION(:,:),INTENT(IN)  :: PFAI
REAL, DIMENSION(1:9),INTENT(OUT) :: PU_CANYON_WANG

! local variables

INTEGER :: i, j
REAL :: kappa
REAL :: N
REAL :: Cd
REAL :: XPII
REAL, DIMENSION(1) :: ZDIR     ! Wind direction
REAL, DIMENSION(1) :: ZFAI_DIR ! Frontal area index according to wind direction
REAL, DIMENSION(1) :: z0
REAL, DIMENSION(1:9) :: zz
REAL, DIMENSION(1) :: pres_grad
REAL, DIMENSION(1) :: gh
REAL, DIMENSION(1) :: gz0
REAL, DIMENSION(1) :: gz
REAL, DIMENSION(1) :: A
REAL, DIMENSION(1) :: beta_1
REAL, DIMENSION(1) :: beta
REAL, DIMENSION(1) :: lc
REAL, DIMENSION(1) :: Sh
REAL, DIMENSION(1) :: CL
REAL, DIMENSION(1) :: up
REAL, DIMENSION(1) :: I0z0
REAL, DIMENSION(1) :: I0z
REAL, DIMENSION(1) :: I0h
REAL, DIMENSION(1) :: K0z0
REAL, DIMENSION(1) :: K0z
REAL, DIMENSION(1) :: K0h
REAL, DIMENSION(1) :: C1
REAL, DIMENSION(1) :: C2

!  
!-------------------------------------------------------------------------------
! Calculate Wind Direction from U and V components
XPII = 2.*ASIN(1.)
ZDIR = MOD(180. + 180. / XPII * atan2(PU,PV),360.) 
!IF (icell == 16 .AND. iblock == 1585) THEN
!    print*, 'wind_prifile ZDIR = ', ZDIR
!ENDIF
! Define FAI according to wind direction       
IF (ZDIR(1) > 180.) THEN
	ZDIR = ZDIR - 180.
ENDIF

IF ((ZDIR(1) <= 11.25) .OR. (ZDIR(1) > 168.75)) THEN
	ZFAI_DIR = PFAI(1,1)
ENDIF
IF ((ZDIR(1) > 11.25) .AND. (ZDIR(1) <= 33.75))  THEN
	ZFAI_DIR = PFAI(1,2)
ENDIF
IF ((ZDIR(1) > 33.75) .AND. (ZDIR(1) <= 56.25))  THEN
	ZFAI_DIR = PFAI(1,3)
ENDIF
IF ((ZDIR(1) > 56.25) .AND. (ZDIR(1) <= 78.75))  THEN
	ZFAI_DIR = PFAI(1,4)
ENDIF
IF ((ZDIR(1) > 78.75) .AND. (ZDIR(1) <= 101.25))  THEN
	ZFAI_DIR = PFAI(1,5)
ENDIF
IF ((ZDIR(1) > 101.25) .AND. (ZDIR(1) <= 123.75))  THEN
	ZFAI_DIR = PFAI(1,6)
ENDIF
IF ((ZDIR(1) > 123.75) .AND. (ZDIR(1) <= 146.25))  THEN
	ZFAI_DIR = PFAI(1,7)
ENDIF
IF ((ZDIR(1) > 146.25) .AND. (ZDIR(1) <= 168.75))  THEN
	ZFAI_DIR = PFAI(1,8)
ENDIF
      
! Von Karman constant
kappa = 0.4 
! Wind speed at half of the canyon
zz = (/0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9/)
!zz = 0.5
! Horizontal pressure gradient
pres_grad = 0.
! Constant to adjust weights of turbulent scale
N = 0.9
! Drag coefficient
Cd = .15

!-------------------------------------------------------------------------------
! Re-calculated aerodynamic roughness
z0 = 0.0025 * PBLD_HEIGHT

! A is a dimensionless parameter and can be interpreted as an attenuation coefficient, 
! characterizing how rapidly mean wind speed decreases with height deep into the canopy
A = 4.52 * ZFAI_DIR + 0.62 * ZFAI_DIR * ZFAI_DIR

! g - argument of the Bessel functions
gh = 2. * sqrt(A * PBLD_HEIGHT / PBLD_HEIGHT)
gz0 = 2. * sqrt(A * z0 / PBLD_HEIGHT)

! Sh a factor representing the effect of canopy elements on the length
beta = PUSTAR_TOWN / PU_TOP
lc = 2. * (beta**3.) / (Cd * ZFAI_DIR / PBLD_HEIGHT)
Sh = lc / ((lc ** N + (0.4 * PBLD_HEIGHT) ** N) ** (1./N))

! β is treated as an empirical parameter varying with FAI
beta_1 = 0.35 - (0.35 - kappa / log(PBLD_HEIGHT / z0)) * exp(-4. * ZFAI_DIR)

! CL - a dimensionless coefficient and assumed to be independent of height 
! but can vary with canopy features
CL = A * kappa * Sh * beta_1 / ZFAI_DIR

! up - represents a contribution by the horizontal pressure gradient force
up = pres_grad * (1. / (CL * PU_TOP * ZFAI_DIR / PBLD_HEIGHT))

! --------------------------------------------------------- !       
!!       ! Calculation of modified Bessel functions
! --------------------------------------------------------- !  
I0z0 = bessi0(gz0)
I0h = bessi0(gh)
!        
K0z0 = bessk0(I0z0,gz0)
K0h = bessk0(I0h,gh)

! ---------------------------------------------------------------------------- !       
!       ! Calculation of integration coefficients and wind speed at height z
! ---------------------------------------------------------------------------- !  

DO i = 1,size(zz)
	gz = 2. * sqrt(A * zz(i))
	I0z = bessi0(gz)
	K0z = bessk0(I0z,gz)

	C1 = (PU_TOP - up + up * K0h / K0z0) / (I0h - I0z0 * K0h / K0z0)
	C2 = -(up + C1 * I0z0) / K0z0
	PU_CANYON_WANG(i) = C1(1) * I0z(1) + C2(1) * K0z(1) + up(1)
	IF (PU_CANYON_WANG(i) < 0.01) THEN
		PU_CANYON_WANG(i) = 0.01
	ENDIF
	
ENDDO	

!-------------------------------------------------------------------------------
!
END SUBROUTINE WIND_CALCULATION_WANG 

FUNCTION bessi0(x)
!	REAL bessi0,x
	REAL, DIMENSION(1) :: bessi0, x, y, ax 
	!Returns the modified Bessel function I0(x) for any real x.
!	REAL ax
!	DOUBLE PRECISION p1,p2,p3,p4,p5,p6,p7,q1,q2,q3,q4,q5,q6,q7,q8,q9,y !Accumulate polynomials in double precision.
	DOUBLE PRECISION p1,p2,p3,p4,p5,p6,p7,q1,q2,q3,q4,q5,q6,q7,q8,q9 !Accumulate polynomials in double precision.
	SAVE p1,p2,p3,p4,p5,p6,p7,q1,q2,q3,q4,q5,q6,q7,q8,q9
	DATA p1,p2,p3,p4,p5,p6,p7/1.0d0,3.5156229d0,3.0899424d0,1.2067492d0, 0.2659732d0,0.360768d-1,0.45813d-2/
	DATA q1,q2,q3,q4,q5,q6,q7,q8,q9/0.39894228d0,0.1328592d-1,0.225319d-2,-0.157565d-2,0.916281d-2,-0.2057706d-1,0.2635537d-1,-0.1647633d-1,0.392377d-2/
	if (abs(x(1)).lt.3.75) then
		y=(x/3.75)**2
		bessi0=p1+y*(p2+y*(p3+y*(p4+y*(p5+y*(p6+y*p7)))))
	else
		ax=abs(x)
		y=3.75/ax
		bessi0=(exp(ax)/sqrt(ax))*(q1+y*(q2+y*(q3+y*(q4+y*(q5+y*(q6+y*(q7+y*(q8+y*q9))))))))
	endif
	return
END

FUNCTION bessk0(z,x)
!	REAL bessk0,x
	REAL, DIMENSION(1) :: bessk0, x, y, z
	! USES bessi0
	!Returns the modified Bessel function K0(x) for positive real x.
!	REAL bessi0
!	DOUBLE PRECISION p1,p2,p3,p4,p5,p6,p7,q1,q2,q3,q4,q5,q6,q7,y !Accumulate polynomials in double precision.
	DOUBLE PRECISION p1,p2,p3,p4,p5,p6,p7,q1,q2,q3,q4,q5,q6,q7 !Accumulate polynomials in double precision.
	SAVE p1,p2,p3,p4,p5,p6,p7,q1,q2,q3,q4,q5,q6,q7
	DATA p1,p2,p3,p4,p5,p6,p7/-0.57721566d0,0.42278420d0,0.23069756d0,0.3488590d-1,0.262698d-2,0.10750d-3,0.74d-5/
	DATA q1,q2,q3,q4,q5,q6,q7/1.25331414d0,-0.7832358d-1,0.2189568d-1,-0.1062446d-1,0.587872d-2,-0.251540d-2,0.53208d-3/
	if (x(1).le.2.0) then !Polynomial fit.
		y=x*x/4.0
		bessk0=(-log(x/2.0)*z)+(p1+y*(p2+y*(p3+y*(p4+y*(p5+y*(p6+y*p7))))))
	else
		y=(2.0/x)
		bessk0=(exp(-x)/sqrt(x))*(q1+y*(q2+y*(q3+y*(q4+y*(q5+y*(q6+y*q7))))))
	endif
	return
END


END MODULE WIND_PROFILE_WANG