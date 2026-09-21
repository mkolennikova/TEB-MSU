!     #########

MODULE AHF_TRAFFIC_NOW

!------------------------------------------------------------------------------
! Public subroutines
!------------------------------------------------------------------------------

PUBLIC :: H_TRAFFIC_NOW

!------------------------------------------------------------------------------
! Parameters and variables which are global in this module
!------------------------------------------------------------------------------

CONTAINS

SUBROUTINE H_TRAFFIC_NOW(icell, iblock, PH_TRAFFIC, PHOUR, PMIN, PSEC, utc_hour, ahf_now) 
!     ##################
!
!-------------------------------------------------------------------------------
!
!*       0.    DECLARATIONS
!              ------------
!
! global variables
INTEGER                          :: icell             !IN number of cell in the block
INTEGER                          :: iblock            !IN number of block
REAL, DIMENSION(:),INTENT(IN)    :: PH_TRAFFIC        !IN heat fluxes due to traffic (mean value)              
INTEGER           ,INTENT(IN)    :: PHOUR             !IN Current hour (UTC)
INTEGER           ,INTENT(IN)    :: PMIN              !IN Current minutes (UTC)
INTEGER           ,INTENT(IN)    :: PSEC              !IN Current seconds (UTC)
INTEGER           ,INTENT(IN)    :: utc_hour          !IN Time zone
REAL, DIMENSION(:),INTENT(OUT)   :: ahf_now           !OUT heat fluxes due to traffic (current value)              

! local variables
REAL, DIMENSION(1) :: zw_d
REAL, DIMENSION(1) :: zw_d1
REAL, DIMENSION(1) :: zw_d2
INTEGER, DIMENSION(1) :: zhour1
INTEGER, DIMENSION(1) :: zhour2
INTEGER, DIMENSION(1) :: dtshift ! Shift the daily cycle to the right
!  
!-------------------------------------------------------------------------------

dtshift = 2.

zhour1  = PHOUR + utc_hour - dtshift  
zhour2  = PHOUR + utc_hour + 1. - dtshift     
	
zw_d1 = ahf_traffic_weight(zhour1)
zw_d2 = ahf_traffic_weight(zhour2)
zw_d = zw_d1 + ((PMIN * 60. + PSEC)  * (zw_d2 - zw_d1)) / 3600.

ahf_now = PH_TRAFFIC*zw_d


END SUBROUTINE H_TRAFFIC_NOW 

FUNCTION ahf_traffic_weight(hhour)

	REAL, DIMENSION(1) :: zHtd     
	REAL, DIMENSION(1) :: zNtd     
	REAL, DIMENSION(1) :: zE1
	REAL, DIMENSION(1) :: zE2
	REAL, DIMENSION(1) :: ahf_traffic_weight
	REAL, DIMENSION(1) :: zt_d
	INTEGER, DIMENSION(1) :: hhour
	
	REAL :: cb1
	REAL :: cb2
	REAL :: csig
	REAL :: cmu
	REAL :: cA1
	REAL :: cff
	REAL :: calph
	REAL :: ceps
	REAL :: pi

	! constants for calculation of anthropogenic heat, see Flanner, 2009
	cb1        = 0.451    
	!cb2        = 0.8
	cb2        = 0.4      
	!csig       = 0.18 
	csig       = 0.15    
	cmu        = 0.5      
	cA1        = -0.3     
	cff        = 2.0      
	calph      = 10.0     
	ceps       = 0.25     	
	pi         = 4.0 * ATAN (1.0)
	
	! Take care that zhour is between 0.0 and 24.0 and adapt nzjulianday in case it is not
	IF (hhour(1) < 0.0) THEN
	  hhour = hhour + 24.0
	ELSEIF (hhour(1) > 24.0) THEN
	  hhour = hhour - 24.0
	ENDIF
	zt_d  = hhour / 24.0

	zHtd = cA1 * COS(2.0 * pi * cff * zt_d)
	zNtd = 1.0 / csig/SQRT(2.0*pi)*EXP(-(zt_d-cmu)**2/(2.0*csig**2))
	zE1  = 0.5 * erf( calph*(zt_d-cmu+ceps)/csig) + 1.0
	zE2  = 0.5 * erf(-calph*(zt_d-cmu-ceps)/csig) + 1.0

	! Wieghting coefficient
	ahf_traffic_weight = zNtd*zE1*cb1+zHtd*zE1*zE2+cb2
	return
END

END MODULE AHF_TRAFFIC_NOW