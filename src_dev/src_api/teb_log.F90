!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!     ###################
      MODULE TEB_LOG
!     ###################
!!
!!****  *TEB_LOG* - the per-cell text output of TEB (CSV)
!!
!!    One CSV file per selected (block, cell) pair, the pair number is part of
!!    the file name (<prefix>_b<block>_c<cell>.csv). The host passes the path
!!    prefix and the output cadence (in model calls) once in TEB_LOG_INIT.
!!
!!    Console: the module itself prints only errors and the one-off list of the
!!    columns it writes. The informational output of the model (e.g. the
!!    configuration dump of CALL_DRIVER) is enabled by the host through
!!    TEB_LOG_SET_VERBOSE and is printed once per run (see section 0.1).
!
USE MODD_DIAG_MISC_TEB_n, ONLY : DIAG_MISC_TEB_t
USE MODD_FORC_ATM,  ONLY : XPS, XZENITH, XAZIM
USE MODD_CSTS,      ONLY : XPI
!
IMPLICIT NONE
!
!*       0.   MODULE DATA
!             -----------
CHARACTER(LEN=256), SAVE :: CTEB_LOG_PREFIX = ''   ! path prefix of the CSV files
INTEGER, SAVE :: NTEB_LOG_CADENCE = 0              ! calls per output row (host policy)
INTEGER, SAVE :: NTEB_LOG_NSUB     = 0             ! calls since the last row
INTEGER, SAVE, ALLOCATABLE :: TEB_LOG_BLOCK(:)     ! selected blocks
INTEGER, SAVE, ALLOCATABLE :: TEB_LOG_POINT(:)     ! selected cells
INTEGER, SAVE, ALLOCATABLE :: TEB_LOG_UNITS(:)     ! one unit per selected pair
LOGICAL, SAVE, ALLOCATABLE :: LTEB_LOG_HDR(:)      ! header written per pair
!
CHARACTER(LEN=1), PARAMETER :: out_sep = ';'  ! CSV field separator
!
!*       0.1  CONSOLE POLICY
!             --------------
!* TEB writes to the console only for errors and for the one-off line that
!* documents the CSV columns it produces. Everything else (banner, namelists,
!* progress, final summary) is the output of the host. An informational block
!* built from the model configuration (the parameter dump of CALL_DRIVER) is
!* printed only if the host asks for it with TEB_LOG_SET_VERBOSE, and at most
!* once per run: the block sits in the per-cell loop and would otherwise be
!* repeated at every model call.
LOGICAL, SAVE :: LTEB_LOG_VERBOSE  = .FALSE.  ! host enabled the informational output
LOGICAL, SAVE :: LTEB_LOG_CFG_DONE = .FALSE.  ! configuration dump already printed
!
CONTAINS
!
SUBROUTINE TEB_LOG_INIT (CPATH_PREFIX, KCADENCE, KRC)
!
CHARACTER(LEN=*), INTENT(IN)  :: CPATH_PREFIX   ! files: <prefix>_b<B>_c<C>.csv
INTEGER,          INTENT(IN)  :: KCADENCE       ! model calls per output row
INTEGER,          INTENT(OUT) :: KRC            ! status (0 = ok)
!
CTEB_LOG_PREFIX   = CPATH_PREFIX
NTEB_LOG_CADENCE  = MAX(KCADENCE, 1)
NTEB_LOG_NSUB     = 0
LTEB_LOG_CFG_DONE = .FALSE.      ! a new run prints its configuration once more
KRC = 0
!
END SUBROUTINE TEB_LOG_INIT
!
SUBROUTINE TEB_LOG_SET_VERBOSE (LVERBOSE)
!
!* Console policy of the host: .TRUE. allows the informational blocks of TEB
!* (a configuration dump, printed at most once per run), .FALSE. keeps the model
!* silent. Errors and the column list are not affected.
!
LOGICAL, INTENT(IN) :: LVERBOSE
!
LTEB_LOG_VERBOSE = LVERBOSE
!
END SUBROUTINE TEB_LOG_SET_VERBOSE
!
LOGICAL FUNCTION TEB_LOG_VERBOSE_FIRST ()
!
!* .TRUE. only if the host enabled the informational output and this is the first
!* call of the run. Blocks that sit in the per-cell loop of CALL_DRIVER use it, so
!* that they are printed once instead of once per cell and per model call.
!
TEB_LOG_VERBOSE_FIRST = LTEB_LOG_VERBOSE .AND. (.NOT. LTEB_LOG_CFG_DONE)
IF (TEB_LOG_VERBOSE_FIRST) LTEB_LOG_CFG_DONE = .TRUE.
!
END FUNCTION TEB_LOG_VERBOSE_FIRST
!
SUBROUTINE TEB_LOG_SET_FILTER (KBLOCK, KPOINT)
!
!* Empty lists mean no files at all (the default of the coupled model).
!
INTEGER, DIMENSION(:), INTENT(IN) :: KBLOCK
INTEGER, DIMENSION(:), INTENT(IN) :: KPOINT
CHARACTER(LEN=16)  :: CB, CC
CHARACTER(LEN=512) :: CFILE
INTEGER :: J, U, IERR
!
!* Idempotent: the host calls this at every model call; the files are created
!* once and kept open until the selection changes (or the run ends).
!
IF (ALLOCATED(TEB_LOG_BLOCK)) THEN
   IF (SIZE(TEB_LOG_BLOCK) == SIZE(KBLOCK) .AND. SIZE(TEB_LOG_POINT) == SIZE(KPOINT)) THEN
      IF (ALL(TEB_LOG_BLOCK == KBLOCK) .AND. ALL(TEB_LOG_POINT == KPOINT)) RETURN
   END IF
END IF
!
IF (ALLOCATED(TEB_LOG_UNITS)) THEN
   DO J = 1, SIZE(TEB_LOG_UNITS)
      CLOSE(TEB_LOG_UNITS(J))
   END DO
END IF
IF (ALLOCATED(TEB_LOG_BLOCK))  DEALLOCATE(TEB_LOG_BLOCK)
IF (ALLOCATED(TEB_LOG_POINT))  DEALLOCATE(TEB_LOG_POINT)
IF (ALLOCATED(TEB_LOG_UNITS))  DEALLOCATE(TEB_LOG_UNITS)
IF (ALLOCATED(LTEB_LOG_HDR))   DEALLOCATE(LTEB_LOG_HDR)
ALLOCATE(TEB_LOG_BLOCK(SIZE(KBLOCK)), TEB_LOG_POINT(SIZE(KPOINT)))
TEB_LOG_BLOCK(:) = KBLOCK(:)
TEB_LOG_POINT(:) = KPOINT(:)
IF (SIZE(KBLOCK) == 0 .OR. SIZE(KBLOCK) /= SIZE(KPOINT)) RETURN
ALLOCATE(TEB_LOG_UNITS(SIZE(KBLOCK)), LTEB_LOG_HDR(SIZE(KBLOCK)))
LTEB_LOG_HDR(:) = .FALSE.
IF (LEN_TRIM(CTEB_LOG_PREFIX) == 0) RETURN
DO J = 1, SIZE(KBLOCK)
   WRITE(CB, '(I0)') KBLOCK(J)
   WRITE(CC, '(I0)') KPOINT(J)
   CFILE = TRIM(CTEB_LOG_PREFIX)//'_b'//TRIM(CB)//'_c'//TRIM(CC)//'.csv'
   OPEN(NEWUNIT=U, FILE=CFILE, STATUS='REPLACE', ACTION='WRITE', IOSTAT=IERR)
   IF (IERR == 0) THEN
      TEB_LOG_UNITS(J) = U
   ELSE
      TEB_LOG_UNITS(J) = -1
      WRITE(*,*) 'ERROR TEB_LOG: cannot open ', TRIM(CFILE), ' IOSTAT=', IERR
   END IF
END DO
!
END SUBROUTINE TEB_LOG_SET_FILTER
!
SUBROUTINE TEB_LOG_HEADER (KIBLOCK, KICELL, CLINE)
!
INTEGER, INTENT(IN) :: KIBLOCK, KICELL
CHARACTER(LEN=*), INTENT(IN) :: CLINE
INTEGER :: J
!
DO J = 1, SIZE(TEB_LOG_BLOCK)
   IF (TEB_LOG_BLOCK(J) == KIBLOCK .AND. TEB_LOG_POINT(J) == KICELL) THEN
      IF (TEB_LOG_UNITS(J) /= -1 .AND. .NOT. LTEB_LOG_HDR(J)) THEN
         WRITE(TEB_LOG_UNITS(J),'(A)') TRIM(CLINE)
         LTEB_LOG_HDR(J) = .TRUE.
      END IF
      RETURN
   END IF
END DO
!
END SUBROUTINE TEB_LOG_HEADER
!
SUBROUTINE TEB_LOG_STEP (KIBLOCK, KICELL, CLINE)
!
INTEGER, INTENT(IN) :: KIBLOCK, KICELL
CHARACTER(LEN=*), INTENT(IN) :: CLINE
INTEGER :: J
!
DO J = 1, SIZE(TEB_LOG_BLOCK)
   IF (TEB_LOG_BLOCK(J) == KIBLOCK .AND. TEB_LOG_POINT(J) == KICELL) THEN
      IF (TEB_LOG_UNITS(J) /= -1) WRITE(TEB_LOG_UNITS(J),'(A)') TRIM(CLINE)
      RETURN
   END IF
END DO
!
END SUBROUTINE TEB_LOG_STEP
!
LOGICAL FUNCTION TEB_LOG_AT_CADENCE ()
!
IF (NTEB_LOG_CADENCE > 0) THEN
   NTEB_LOG_NSUB = NTEB_LOG_NSUB + 1
   IF (NTEB_LOG_NSUB >= NTEB_LOG_CADENCE) THEN
      NTEB_LOG_NSUB = 0
      TEB_LOG_AT_CADENCE = .TRUE.
      RETURN
   END IF
END IF
TEB_LOG_AT_CADENCE = .FALSE.
!
END FUNCTION TEB_LOG_AT_CADENCE
!
SUBROUTINE TEB_LOG_FINAL
!
INTEGER :: J
!
IF (ALLOCATED(TEB_LOG_UNITS)) THEN
   DO J = 1, SIZE(TEB_LOG_UNITS)
      IF (TEB_LOG_UNITS(J) /= -1) CLOSE(TEB_LOG_UNITS(J))
   END DO
   DEALLOCATE(TEB_LOG_UNITS)
END IF
!
END SUBROUTINE TEB_LOG_FINAL
!
SUBROUTINE TEB_LOG_ROW (DMT, KICELL, teb_year, teb_month, teb_day, teb_hour_seconds, teb_tcanyon, teb_ti_bld, teb_qcanyon, teb_tsnow_road, teb_tch_gd, teb_tcm_gd, teb_ws_road, teb_ws_roof, teb_wsnow_road, teb_wsnow_roof, teb_itype_bem, teb_lsolar_panel, t, qv, ps, rho, u, v, prr_con, prs_con, prr_gsp, prs_gsp, prg_gsp, lwd_s, swdir_s, swdifd_s, CHDR, COUT, KNCOL, CNAME)
!
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT
INTEGER, INTENT(IN) :: KICELL   ! index of the cell in the window
INTEGER, INTENT(IN) :: teb_year, teb_month, teb_day
REAL, DIMENSION(:), INTENT(IN) :: teb_hour_seconds
CHARACTER(LEN=*), INTENT(IN) :: teb_itype_bem
LOGICAL, INTENT(IN) :: teb_lsolar_panel
REAL, DIMENSION(:), INTENT(IN) :: teb_tcanyon
REAL, DIMENSION(:), INTENT(IN) :: teb_ti_bld
REAL, DIMENSION(:), INTENT(IN) :: teb_qcanyon
REAL, DIMENSION(:,:), INTENT(IN) :: teb_tsnow_road
REAL, DIMENSION(:), INTENT(IN) :: teb_tch_gd
REAL, DIMENSION(:), INTENT(IN) :: teb_tcm_gd
REAL, DIMENSION(:), INTENT(IN) :: teb_ws_road
REAL, DIMENSION(:), INTENT(IN) :: teb_ws_roof
REAL, DIMENSION(:,:), INTENT(IN) :: teb_wsnow_road
REAL, DIMENSION(:,:), INTENT(IN) :: teb_wsnow_roof
REAL, DIMENSION(:), INTENT(IN) :: t
REAL, DIMENSION(:), INTENT(IN) :: qv
REAL, DIMENSION(:), INTENT(IN) :: ps
REAL, DIMENSION(:), INTENT(IN) :: rho
REAL, DIMENSION(:), INTENT(IN) :: u
REAL, DIMENSION(:), INTENT(IN) :: v
REAL, DIMENSION(:), INTENT(IN) :: prr_con
REAL, DIMENSION(:), INTENT(IN) :: prs_con
REAL, DIMENSION(:), INTENT(IN) :: prr_gsp
REAL, DIMENSION(:), INTENT(IN) :: prs_gsp
REAL, DIMENSION(:), INTENT(IN) :: prg_gsp
REAL, DIMENSION(:), INTENT(IN) :: lwd_s
REAL, DIMENSION(:), INTENT(IN) :: swdir_s
REAL, DIMENSION(:), INTENT(IN) :: swdifd_s
CHARACTER(LEN=*), INTENT(INOUT) :: CHDR, COUT
INTEGER, INTENT(INOUT) :: KNCOL
CHARACTER(LEN=*), DIMENSION(:), INTENT(INOUT) :: CNAME
!
CHARACTER(LEN=32) :: time_buf

!------------------------------------------------------------------------------
!
WRITE(time_buf,'(I4.4,"-",I2.2,"-",I2.2," ",I2.2,":",I2.2,":",I2.2)')              &
         teb_year, teb_month, teb_day,                                                &
         INT(teb_hour_seconds(1)/3600.),                                              &
         INT(MOD(teb_hour_seconds(1), 3600.)/60.),                                    &
         INT(MOD(teb_hour_seconds(1), 60.))
    KNCOL = 0
    CHDR = 'time'
    COUT = TRIM(time_buf)
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'T_ROOF1', DMT%XTS_ROOF(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'T_CANYON', teb_tcanyon(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'T_ROAD1', DMT%XTS_ROAD(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'T_WALLA1', DMT%XTS_WALL_A(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'T_WALLB1', DMT%XTS_WALL_B(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'TI_BLD', teb_ti_bld(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Q_CANYON', teb_qcanyon(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'P_CANYON', XPS(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'U_CANYON', DMT%XWIND_CANYON(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'H_TOWN', DMT%XH_TOWN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_TOWN', DMT%XLE_TOWN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'RN_TOWN', DMT%XRN_TOWN(KICELL))
    IF (teb_itype_bem == 'BEM') THEN
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'HVAC_COOL', DMT%XHVAC_COOL(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'HVAC_HEAT', DMT%XHVAC_HEAT(KICELL))
    END IF
    IF (teb_lsolar_panel) THEN
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'SOLAR_PROD', DMT%XSOLAR_PROD(KICELL))
    END IF
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'WIND_TOP', DMT%XWIND_TOP(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'USTAR_TOWN', DMT%XUSTAR_TOWN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCD_ROAD_CAN', DMT%XPCD_ROAD_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCDN_ROAD_CAN', DMT%XPCDN_ROAD_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PRI_ROAD_CAN', DMT%XPRI_ROAD_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'ZZ0H_ROAD_CAN', DMT%XZZ0H_ROAD_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PAC_ROAD_ATM', DMT%XPAC_ROAD_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCH_ROAD_ATM', DMT%XPCH_ROAD_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCD_ROAD_ATM', DMT%XPCD_ROAD_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCDN_ROAD_ATM', DMT%XPCDN_ROAD_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PRI_ROAD_ATM', DMT%XPRI_ROAD_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'ZZ0H_ROAD_ATM', DMT%XZZ0H_ROAD_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCDN_GARDEN_CAN', DMT%XPCDN_GARDEN_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PRI_GARDEN_CAN', DMT%XPRI_GARDEN_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'ZZ0H_GARDEN_CAN', DMT%XZZ0H_GARDEN_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PAC_GARDEN_ATM', DMT%XPAC_GARDEN_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCDN_GARDEN_ATM', DMT%XPCDN_GARDEN_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PRI_GARDEN_ATM', DMT%XPRI_GARDEN_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'ZZ0H_GARDEN_ATM', DMT%XZZ0H_GARDEN_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PAC_ROAD_CAN', DMT%XAC_RD(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCH_ROAD_CAN', DMT%XTCH_RD(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCD_GARDEN_CAN', teb_tcm_gd(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCH_GARDEN_CAN', teb_tch_gd(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCD_GARDEN_ATM', DMT%XCD_GARDEN_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCH_GARDEN_ATM', DMT%XCH_GARDEN_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'H_ROAD_CAN', DMT%XPH_ROAD_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_ROAD_CAN', DMT%XPLE_ROAD_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'H_ROAD_ATM', DMT%XPH_ROAD_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_ROAD_ATM', DMT%XPLE_ROAD_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'H_ROAD', DMT%XPH_ROAD(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_ROAD', DMT%XPLE_ROAD(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PAC_ROAD_WAT', DMT%XPAC_ROAD_WAT(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PAC_ROAD_ATM_WAT', DMT%XPAC_ROAD_ATM_WAT(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PDN_RD', DMT%XPDN_RD(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_ROAD_WAT', DMT%XLE_ROAD_WAT(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_ROAD_SNOW', DMT%XLE_ROAD_SNOW(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'WS_ROAD', teb_ws_road(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'AHF_TRAFFIC', DMT%XAHF_TRAFFIC_NOW(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'H_WASTE', DMT%XH_WASTE(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_WASTE', DMT%XLE_WASTE(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'GFLUX_TOWN', DMT%XGFLUX_TOWN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'T_CAN0', DMT%XPT_CAN0(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'T_CAN1', DMT%XPT_CAN1(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PHI_CAN1', DMT%XPPHI_CAN1(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'WSNOW_RD', teb_wsnow_road(1,1))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'TSNOW_RD', teb_tsnow_road(1,1))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PDN_RF', DMT%XPDN_RF(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_ROOF_WAT', DMT%XLE_ROOF_WAT(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_ROOF_SNOW', DMT%XLE_ROOF_SNOW(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'WS_ROOF', teb_ws_roof(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'WSNOW_RF', teb_wsnow_roof(1,1))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'TS_GARDEN', DMT%XTS_GARDEN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'RN_GARDEN', DMT%XRN_GARDEN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'H_GARDEN', DMT%XH_GARDEN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_GARDEN', DMT%XLE_GARDEN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'EVAP_GARDEN', DMT%XEVAP_GARDEN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'QSAT_GARDEN', DMT%XQSAT_GARDEN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PHU_GARDEN', DMT%XPHU_GARDEN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PAC_GARDEN', DMT%XPAC_GARDEN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'H_GARDEN_CAN', DMT%XH_GARDEN_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'H_GARDEN_ATM', DMT%XH_GARDEN_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_GARDEN_CAN', DMT%XLE_GARDEN_CAN(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_GARDEN_ATM', DMT%XLE_GARDEN_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'TS_GREENROOF', DMT%XTS_GREENROOF(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'RN_GREENROOF', DMT%XRN_GREENROOF(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'H_GREENROOF', DMT%XH_GREENROOF(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'LE_GREENROOF', DMT%XLE_GREENROOF(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'EVAP_GREENROOF', DMT%XEVAP_GREENROOF(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'QSAT_GREENROOF', DMT%XQSAT_GREENROOF(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PHU_GREENROOF', DMT%XPHU_GREENROOF(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PAC_GREENROOF', DMT%XPAC_GREENROOF(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PAC_GREENROOF_ATM', DMT%XPAC_GREENROOF_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCD_GREENROOF_ATM', DMT%XPCD_GREENROOF_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCDN_GREENROOF_ATM', DMT%XPCDN_GREENROOF_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PCH_GREENROOF_ATM', DMT%XPCH_GREENROOF_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'PRI_GREENROOF_ATM', DMT%XPRI_GREENROOF_ATM(KICELL))
    CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'ZZ0H_GREENROOF_ATM', DMT%XZZ0H_GREENROOF_ATM(KICELL))
!
END SUBROUTINE TEB_LOG_ROW
!
SUBROUTINE CSV_ADD(header, line, ncol, names, name, value)
    !MV202609 table-driven CSV: register a column and append its value
    !* One call defines a column completely - the name goes to the header line, the
    !* value goes to the data row - so the two cannot drift apart (the earlier code
    !* kept two parallel lists, the names and the CALL CSV_APPEND sequence, that had
    !* to be kept in the same order by hand). The header line is written once, just
    !* before the first data row, from the same calls.
    !* This is the TEB copy of the writer: it serves the per-cell files
    !* <prefix>_b<block>_c<cell>.csv only. The host keeps its own copy of the same
    !* protocol (RUN_TEB_OFFLINE:CSV_ADD) for the files it owns (TEB_emu.csv,
    !* TEB_runoff.csv); the two writers never touch the same file, so the column
    !* registry of a file always lives next to the code that fills it.
    CHARACTER(LEN=*), INTENT(INOUT) :: header  ! header line being built
    CHARACTER(LEN=*), INTENT(INOUT) :: line    ! data row being built
    INTEGER, INTENT(INOUT) :: ncol             ! number of columns registered so far
    CHARACTER(LEN=*), DIMENSION(:), INTENT(INOUT) :: names  ! column names (1:ncol)
    CHARACTER(LEN=*), INTENT(IN) :: name       ! name of this column
    REAL, INTENT(IN) :: value                  ! value of this column
    INTEGER :: l
    ncol = ncol + 1
    IF (ncol > SIZE(names)) THEN
       WRITE(*,*) 'ERROR TEB_LOG: too many output columns: ', ncol, &
                  ' > SIZE(names) = ', SIZE(names)
       WRITE(*,*) 'Increase the size of the names array.'
       STOP 1
    END IF
    names(ncol) = name
    l = LEN_TRIM(header)
    IF (l + 1 + LEN_TRIM(name) > LEN(header)) THEN
       WRITE(*,*) 'ERROR: header line is too long, increase the size of hdr_line'
       STOP 1
    END IF
    header(l+1:l+1) = out_sep
    header(l+2:) = TRIM(name)
    CALL CSV_APPEND(line, value)
END SUBROUTINE CSV_ADD


SUBROUTINE CSV_APPEND(line, value)
    CHARACTER(LEN=*), INTENT(INOUT) :: line
    REAL, INTENT(IN) :: value
    CHARACTER(LEN=64) :: buf
    INTEGER :: l
    WRITE(buf,*) value
    l = LEN_TRIM(line)
    IF (l + 1 + LEN_TRIM(ADJUSTL(buf)) > LEN(line)) THEN
       WRITE(*,*) 'ERROR: output line is too long, increase the size of out_line'
       STOP 1
    END IF
    line(l+1:l+1) = out_sep
    line(l+2:) = TRIM(ADJUSTL(buf))
END SUBROUTINE CSV_APPEND
!

SUBROUTINE TEB_LOG_EMIT (KIBLOCK, DMT, teb_year, teb_month, teb_day, teb_hour_seconds, teb_tcanyon, teb_ti_bld, teb_qcanyon, teb_tsnow_road, teb_tch_gd, teb_tcm_gd, teb_ws_road, teb_ws_roof, teb_wsnow_road, teb_wsnow_roof, teb_itype_bem, teb_lsolar_panel, t, qv, ps, rho, u, v, prr_con, prs_con, prr_gsp, prs_gsp, prg_gsp, lwd_s, swdir_s, swdifd_s)
!
!* The universal output row: the TEB diagnostics of one cell (TEB_LOG_ROW)
!* followed by the solar geometry and the atmospheric forcing of the step.
!
INTEGER, INTENT(IN) :: KIBLOCK   ! the block of this call
TYPE(DIAG_MISC_TEB_t), INTENT(INOUT) :: DMT
INTEGER, INTENT(IN) :: teb_year, teb_month, teb_day
REAL, DIMENSION(:), INTENT(IN) :: teb_hour_seconds
CHARACTER(LEN=*), INTENT(IN) :: teb_itype_bem
LOGICAL, INTENT(IN) :: teb_lsolar_panel
REAL, DIMENSION(:), INTENT(IN) :: teb_tcanyon
REAL, DIMENSION(:), INTENT(IN) :: teb_ti_bld
REAL, DIMENSION(:), INTENT(IN) :: teb_qcanyon
REAL, DIMENSION(:,:), INTENT(IN) :: teb_tsnow_road
REAL, DIMENSION(:), INTENT(IN) :: teb_tch_gd
REAL, DIMENSION(:), INTENT(IN) :: teb_tcm_gd
REAL, DIMENSION(:), INTENT(IN) :: teb_ws_road
REAL, DIMENSION(:), INTENT(IN) :: teb_ws_roof
REAL, DIMENSION(:,:), INTENT(IN) :: teb_wsnow_road
REAL, DIMENSION(:,:), INTENT(IN) :: teb_wsnow_roof
REAL, DIMENSION(:), INTENT(IN) :: t
REAL, DIMENSION(:), INTENT(IN) :: qv
REAL, DIMENSION(:), INTENT(IN) :: ps
REAL, DIMENSION(:), INTENT(IN) :: rho
REAL, DIMENSION(:), INTENT(IN) :: u
REAL, DIMENSION(:), INTENT(IN) :: v
REAL, DIMENSION(:), INTENT(IN) :: prr_con
REAL, DIMENSION(:), INTENT(IN) :: prs_con
REAL, DIMENSION(:), INTENT(IN) :: prr_gsp
REAL, DIMENSION(:), INTENT(IN) :: prs_gsp
REAL, DIMENSION(:), INTENT(IN) :: prg_gsp
REAL, DIMENSION(:), INTENT(IN) :: lwd_s
REAL, DIMENSION(:), INTENT(IN) :: swdir_s
REAL, DIMENSION(:), INTENT(IN) :: swdifd_s
!
CHARACTER(LEN=4096) :: CHDR, COUT
INTEGER             :: KNCOL, J
CHARACTER(LEN=24), DIMENSION(192) :: CNAME
REAL                :: ZFORC_WIND, ZFORC_DIR
LOGICAL, SAVE :: LTEB_LOG_EMITTED = .FALSE.
!
DO J = 1, SIZE(TEB_LOG_BLOCK)
   IF (TEB_LOG_BLOCK(J) /= KIBLOCK) CYCLE
   KNCOL = 0
   CHDR  = 'time'
   CALL TEB_LOG_ROW(DMT, TEB_LOG_POINT(J), teb_year, teb_month, teb_day, teb_hour_seconds, teb_tcanyon, teb_ti_bld, teb_qcanyon, teb_tsnow_road, teb_tch_gd, teb_tcm_gd, teb_ws_road, teb_ws_roof, teb_wsnow_road, teb_wsnow_roof, teb_itype_bem, teb_lsolar_panel, t, qv, ps, rho, u, v, prr_con, prs_con, prr_gsp, prs_gsp, prg_gsp, lwd_s, swdir_s, swdifd_s, CHDR, COUT, KNCOL, CNAME)
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'SOLAR_ZENITH', XZENITH(1) * 180. / XPI)
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'SOLAR_ELEV', 90. - XZENITH(1) * 180. / XPI)
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'SOLAR_AZIM', MOD(XAZIM(1) * 180. / XPI + 360., 360.))
   ZFORC_WIND = SQRT(U(1)**2 + V(1)**2)
   ZFORC_DIR  = MOD(ATAN2(U(1), V(1))*180./XPI + 360., 360.)
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_TA', T(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_QA', QV(1)*RHO(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_QV', QV(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_U', U(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_V', V(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_WIND', ZFORC_WIND)
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_DIR', ZFORC_DIR)
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_PS', PS(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_RHOA', RHO(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_RAIN', PRR_CON(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_SNOW', PRS_CON(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_LW', LWD_S(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_DIR_SW', SWDIR_S(1))
   CALL CSV_ADD(CHDR, COUT, KNCOL, CNAME, 'Forc_SCA_SW', SWDIFD_S(1))
   CALL TEB_LOG_HEADER(TEB_LOG_BLOCK(J), TEB_LOG_POINT(J), CHDR)
   IF (.NOT. LTEB_LOG_EMITTED) THEN
      WRITE(*,*) '  Output columns: ', TRIM(CHDR)
      LTEB_LOG_EMITTED = .TRUE.
   END IF
   CALL TEB_LOG_STEP(TEB_LOG_BLOCK(J), TEB_LOG_POINT(J), COUT)
END DO
!
END SUBROUTINE TEB_LOG_EMIT

!
END MODULE TEB_LOG
