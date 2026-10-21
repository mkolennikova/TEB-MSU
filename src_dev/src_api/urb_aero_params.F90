!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!     ##############################
       MODULE MODI_URB_AERO_PARAMS
!     ##############################
!!
!!****  *MODI_URB_AERO_PARAMS* - z0 and zd of the urban surface from the namelist
!!
!!    PURPOSE
!!    -------
!!    Resolves the namelist entries urb_z0_town / urb_zd_town (an explicit value,
!!    a fraction of the building height, or a named parameterization) into the
!!    roughness length z0 and the displacement height zd.
!!
!!    Moved out of MODI_CALL_DRIVER (P-C1b) so that the container layer TEB_HOST
!!    can derive the aerodynamic parameters in TEB_FILL_DERIVED.
!
USE MODD_CSTS, ONLY : XKARMAN
!
IMPLICIT NONE
!
CONTAINS
!
!MV202609 z0 and zd to namelist
SUBROUTINE URB_AERO_PARAMS(CZ0, CZD, PBLD_HEIGHT, PBLD_FRAC, PFAI, PZ0, PZD)
! Aerodynamic parameters of the urban surface: z0 of the town and the
! displacement height zd. Both are defined by the namelist entries
! (urb_z0_town, urb_zd_town), each of them accepting (case insensitive):
!   0.5 | 0.5m  - value in metres
!   0.1H        - fraction of the building height
!   H/3         - building height divided by n
!   <name>      - a named parameterization (see URB_AERO_SCHEME_Z0 and
!                 URB_AERO_SCHEME_ZD: MACDONALD1998, MACDONALD1998SQ)
! The two entries are resolved independently, so that zd can be taken from a
! parameterization ('MACDONALD1998') while z0 is given explicitly ('0.1H'),
! and vice versa.
CHARACTER(LEN=*),    INTENT(IN)  :: CZ0, CZD      ! namelist entries
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_HEIGHT   ! building height (m)
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_FRAC    ! plan area index (-)
REAL, DIMENSION(:,:),INTENT(IN)  :: PFAI          ! frontal area index (8 dir.)
REAL, DIMENSION(:),  INTENT(OUT) :: PZ0, PZD      ! resulting z0 and zd (m)

!MV202609 z0 and zd to namelist
LOGICAL           :: LSCHEME_Z0, LSCHEME_ZD
INTEGER           :: KERR
CHARACTER(LEN=16) :: CSCHEME_Z0, CSCHEME_ZD

!MV202609 z0 and zd to namelist
! z0: explicit value or a parameterization name
CALL URB_AERO_ONE(CZ0, PBLD_HEIGHT, PZ0, LSCHEME_Z0, CSCHEME_Z0)
IF (LSCHEME_Z0) THEN
  CALL URB_AERO_SCHEME_Z0(CSCHEME_Z0, PBLD_HEIGHT, PBLD_FRAC, PFAI, PZ0, KERR)
  IF (KERR /= 0) CALL URB_AERO_STOP('urb_z0_town', CZ0, CZD)
ENDIF

!MV202609 z0 and zd to namelist
! zd: explicit value or a parameterization name
CALL URB_AERO_ONE(CZD, PBLD_HEIGHT, PZD, LSCHEME_ZD, CSCHEME_ZD)
IF (LSCHEME_ZD) THEN
  CALL URB_AERO_SCHEME_ZD(CSCHEME_ZD, PBLD_HEIGHT, PBLD_FRAC, PZD, KERR)
  IF (KERR /= 0) CALL URB_AERO_STOP('urb_zd_town', CZ0, CZD)
ENDIF
END SUBROUTINE URB_AERO_PARAMS

!MV202609 z0 and zd to namelist
SUBROUTINE URB_AERO_STOP(CNAME, CZ0, CZD)
! Stops the run with a message about an unknown value or parameterization name
CHARACTER(LEN=*), INTENT(IN) :: CNAME             ! offending namelist entry
CHARACTER(LEN=*), INTENT(IN) :: CZ0, CZD          ! both namelist entries

WRITE(*,*) 'ERROR in CALL_DRIVER: cannot interpret the namelist entry '//TRIM(CNAME)
WRITE(*,*) '   urb_z0_town = ', TRIM(CZ0)
WRITE(*,*) '   urb_zd_town = ', TRIM(CZD)
WRITE(*,*) '   accepted forms: <value> (m), <value>m, <value>H, H/<n>'
WRITE(*,*) '   named parameterizations: MACDONALD1998, MACDONALD1998SQ'
STOP
END SUBROUTINE URB_AERO_STOP

!MV202609 z0 and zd to namelist
SUBROUTINE URB_AERO_ONE(CVALUE, PBLD_HEIGHT, PVALUE, LSCHEME, CSCHEME)
! Parses one namelist entry of an urban aerodynamic length (see URB_AERO_PARAMS).
! If the entry is not a number, it is returned as a parameterization name.
CHARACTER(LEN=*),    INTENT(IN)  :: CVALUE       ! namelist entry
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_HEIGHT  ! building height (m)
REAL, DIMENSION(:),  INTENT(OUT) :: PVALUE       ! resulting length (m)
LOGICAL,             INTENT(OUT) :: LSCHEME      ! true if CVALUE is a scheme name
CHARACTER(LEN=16),   INTENT(OUT) :: CSCHEME      ! scheme name (upper case)

INTEGER           :: IJ, ILEN, IOS, ICHR
REAL              :: ZPVAL
CHARACTER(LEN=16) :: YSTR, YNUM

YSTR = ADJUSTL(CVALUE)
ILEN = LEN_TRIM(YSTR)
DO IJ = 1, ILEN
  ICHR = ICHAR(YSTR(IJ:IJ))
  IF (ICHR >= ICHAR('a') .AND. ICHR <= ICHAR('z')) YSTR(IJ:IJ) = CHAR(ICHR - 32)
ENDDO

LSCHEME = .FALSE.
CSCHEME = ' '
IF (ILEN == 0) THEN
  LSCHEME = .TRUE.
  RETURN
ENDIF

! 'H/<n>' - building height divided by n
IF (ILEN > 2) THEN
  IF (YSTR(1:2) == 'H/') THEN
    YNUM = YSTR(3:ILEN)
    READ(YNUM,*,IOSTAT=IOS) ZPVAL
    IF (IOS == 0 .AND. ZPVAL /= 0.) THEN
      PVALUE = PBLD_HEIGHT / ZPVAL
      RETURN
    ENDIF
  ENDIF
ENDIF

! '<value>H' - fraction of the building height
IF (ILEN > 1) THEN
  IF (YSTR(ILEN:ILEN) == 'H') THEN
    YNUM = YSTR(1:ILEN-1)
    READ(YNUM,*,IOSTAT=IOS) ZPVAL
    IF (IOS == 0) THEN
      PVALUE = ZPVAL * PBLD_HEIGHT
      RETURN
    ENDIF
  ENDIF
ENDIF

! '<value>m' - value in metres
IF (ILEN > 1) THEN
  IF (YSTR(ILEN:ILEN) == 'M') THEN
    YNUM = YSTR(1:ILEN-1)
    READ(YNUM,*,IOSTAT=IOS) ZPVAL
    IF (IOS == 0) THEN
      PVALUE = ZPVAL
      RETURN
    ENDIF
  ENDIF
ENDIF

! '<value>' - value in metres
YNUM = YSTR(1:ILEN)
READ(YNUM,*,IOSTAT=IOS) ZPVAL
IF (IOS == 0) THEN
  PVALUE = ZPVAL
  RETURN
ENDIF

! otherwise: a parameterization name
LSCHEME = .TRUE.
CSCHEME = YSTR
END SUBROUTINE URB_AERO_ONE

!MV202609 z0 and zd to namelist
SUBROUTINE URB_AERO_SCHEME_Z0(CSCHEME, PBLD_HEIGHT, PBLD_FRAC, PFAI, PZ0, KERR)
! Roughness length z0 from a named parameterization. It uses the building
! height, the plan area index and the frontal area index. Available schemes:
!   'MACDONALD1998'   - Macdonald et al. (1998), staggered arrays
!   'MACDONALD1998SQ' - Macdonald et al. (1998), square arrays
CHARACTER(LEN=*),    INTENT(IN)  :: CSCHEME
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_HEIGHT
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_FRAC
REAL, DIMENSION(:,:),INTENT(IN)  :: PFAI
REAL, DIMENSION(:),  INTENT(OUT) :: PZ0
INTEGER,             INTENT(OUT) :: KERR

!MV202609 z0 and zd to namelist
REAL              :: ZLAMBDA_P, ZLAMBDA_F
CHARACTER(LEN=16) :: CWHERE

KERR = 1
PZ0(:) = 0.

!MV202609 z0 and zd to namelist
! plan area index (building fraction) and frontal area index (mean over the
! 8 wind directions, i.e. the isotropic variant)
ZLAMBDA_P = SUM(PBLD_FRAC) / REAL(SIZE(PBLD_FRAC))
ZLAMBDA_F = SUM(PFAI)      / REAL(SIZE(PFAI))

!MV202609 z0 and zd to namelist
SELECT CASE (TRIM(CSCHEME))
CASE ('MACDONALD1998', 'MACDONALD', 'MACDONALD98')
  CWHERE = 'STAG'
CASE ('MACDONALD1998SQ', 'MACDONALD98SQ')
  CWHERE = 'SQUARE'
CASE DEFAULT
  CWHERE = ' '
END SELECT

!MV202609 z0 and zd to namelist
IF (CWHERE /= ' ') THEN
  PZ0 = URB_Z0_MACDONALD(PBLD_HEIGHT, ZLAMBDA_P, ZLAMBDA_F, CWHERE)
  KERR = 0
ENDIF
END SUBROUTINE URB_AERO_SCHEME_Z0

!MV202609 z0 and zd to namelist
SUBROUTINE URB_AERO_SCHEME_ZD(CSCHEME, PBLD_HEIGHT, PBLD_FRAC, PZD, KERR)
! Displacement height zd from a named parameterization. It uses the building
! height and the plan area index. Available schemes:
!   'MACDONALD1998'   - Macdonald et al. (1998), staggered arrays
!   'MACDONALD1998SQ' - Macdonald et al. (1998), square arrays
CHARACTER(LEN=*),    INTENT(IN)  :: CSCHEME
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_HEIGHT
REAL, DIMENSION(:),  INTENT(IN)  :: PBLD_FRAC
REAL, DIMENSION(:),  INTENT(OUT) :: PZD
INTEGER,             INTENT(OUT) :: KERR

!MV202609 z0 and zd to namelist
REAL              :: ZLAMBDA_P
CHARACTER(LEN=16) :: CWHERE

KERR = 1
PZD(:) = 0.

!MV202609 z0 and zd to namelist
! plan area index (building fraction)
ZLAMBDA_P = SUM(PBLD_FRAC) / REAL(SIZE(PBLD_FRAC))

!MV202609 z0 and zd to namelist
SELECT CASE (TRIM(CSCHEME))
CASE ('MACDONALD1998', 'MACDONALD', 'MACDONALD98')
  CWHERE = 'STAG'
CASE ('MACDONALD1998SQ', 'MACDONALD98SQ')
  CWHERE = 'SQUARE'
CASE DEFAULT
  CWHERE = ' '
END SELECT

!MV202609 z0 and zd to namelist
IF (CWHERE /= ' ') THEN
  PZD = URB_ZD_MACDONALD(PBLD_HEIGHT, ZLAMBDA_P, CWHERE)
  KERR = 0
ENDIF
END SUBROUTINE URB_AERO_SCHEME_ZD

!MV202609 z0 and zd to namelist
FUNCTION URB_ZD_MACDONALD(PBLD_HEIGHT, PLAMBDA_P, CWHERE) RESULT(PZD)
! Displacement height after Macdonald et al. (1998), eq. (23):
!   d/H = 1 + A^(-lambda_p) * (lambda_p - 1)
! with A = 4.43 for staggered arrays and A = 3.59 for square arrays.
! DOI 10.1016/S1352-2310(97)00403-2
REAL, DIMENSION(:), INTENT(IN) :: PBLD_HEIGHT     ! building height (m)
REAL,             INTENT(IN)   :: PLAMBDA_P       ! plan area index (-)
CHARACTER(LEN=*), INTENT(IN)   :: CWHERE          ! 'STAG' or 'SQUARE'
REAL, DIMENSION(SIZE(PBLD_HEIGHT)) :: PZD

!MV202609 z0 and zd to namelist
REAL :: ZA

ZA = 4.43
IF (TRIM(CWHERE) == 'SQUARE') ZA = 3.59

!MV202609 z0 and zd to namelist
! degenerate cases: no buildings, or a fully built-up surface
IF (PLAMBDA_P <= 0.) THEN
  PZD(:) = 0.
  RETURN
ENDIF
IF (PLAMBDA_P >= 1.) THEN
  PZD(:) = PBLD_HEIGHT
  RETURN
ENDIF

!MV202609 z0 and zd to namelist
PZD = PBLD_HEIGHT * (1. + ZA**(-PLAMBDA_P) * (PLAMBDA_P - 1.))
END FUNCTION URB_ZD_MACDONALD

!MV202609 z0 and zd to namelist
FUNCTION URB_Z0_MACDONALD(PBLD_HEIGHT, PLAMBDA_P, PLAMBDA_F, CWHERE) RESULT(PZ0)
! Roughness length after Macdonald et al. (1998), eq. (22):
!   z0/H = (1 - d/H) * exp( -( 0.5*beta*(Cd/kappa**2)*(1 - d/H)*lambda_f )**(-0.5) )
! with Cd = 1.2, kappa = 0.4 (von Karman) and beta = 1.0 for staggered arrays
! or beta = 0.55 for square arrays.
! DOI 10.1016/S1352-2310(97)00403-2
REAL, DIMENSION(:), INTENT(IN) :: PBLD_HEIGHT     ! building height (m)
REAL,             INTENT(IN)   :: PLAMBDA_P       ! plan area index (-)
REAL,             INTENT(IN)   :: PLAMBDA_F       ! frontal area index (-)
CHARACTER(LEN=*), INTENT(IN)   :: CWHERE          ! 'STAG' or 'SQUARE'
REAL, DIMENSION(SIZE(PBLD_HEIGHT)) :: PZ0

!MV202609 z0 and zd to namelist
REAL :: ZBETA, ZCD, ZKAPPA, ZLAMBDA
REAL, DIMENSION(SIZE(PBLD_HEIGHT)) :: ZD, ZONE_MINUS_D, ZINNER

ZBETA  = 1.0
IF (TRIM(CWHERE) == 'SQUARE') ZBETA = 0.55
ZCD    = 1.2
ZKAPPA = XKARMAN

!MV202609 z0 and zd to namelist
! degenerate cases: no buildings or no frontal area -> smooth surface
IF (PLAMBDA_P <= 0. .OR. PLAMBDA_F <= 0.) THEN
  PZ0(:) = 1.E-3
  RETURN
ENDIF
ZLAMBDA = MIN(PLAMBDA_P, 0.999)

!MV202609 z0 and zd to namelist
! displacement height and the factor (1 - d/H)
ZD           = URB_ZD_MACDONALD(PBLD_HEIGHT, ZLAMBDA, CWHERE)
ZONE_MINUS_D = 1. - ZD / PBLD_HEIGHT
IF (MINVAL(ZONE_MINUS_D) <= 0.) THEN
  PZ0(:) = 1.E-3
  RETURN
ENDIF

!MV202609 z0 and zd to namelist
! inner expression of eq. (22)
ZINNER = 0.5 * ZBETA * (ZCD / ZKAPPA**2) * ZONE_MINUS_D * PLAMBDA_F
IF (MINVAL(ZINNER) <= 0.) THEN
  PZ0(:) = 1.E-3
  RETURN
ENDIF

!MV202609 z0 and zd to namelist
PZ0 = PBLD_HEIGHT * ZONE_MINUS_D * EXP(-(ZINNER**(-0.5)))
END FUNCTION URB_Z0_MACDONALD

!
END MODULE MODI_URB_AERO_PARAMS