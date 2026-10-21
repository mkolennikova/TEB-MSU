!SFX_LIC Copyright 1994-2014 CNRS, Meteo-France and Universite Paul Sabatier
!SFX_LIC This is part of the SURFEX software governed by the CeCILL-C licence
!SFX_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt
!     ###################
      MODULE TEB_LOG
!     ###################
!!
!!****  *TEB_LOG* - the text output of TEB diagnostics (CSV)
!!
!!    PURPOSE
!!    -------
!!    The input/output mechanism of the diagnostic CSV is owned by TEB, so
!!    that the offline driver and the coupled model use one and the same
!!    writer. The *content* of the header and of the rows is built by the
!!    caller and passed as a single string: this keeps the writer free of any
!!    knowledge of the fields and of the host, and keeps the produced file
!!    byte for byte identical to the one written before.
!!
!!    The writer is silent until TEB_LOG_INIT has been called; the file name,
!!    the moment of the opening and the moment of the closing stay a host
!!    decision.
!!
!!    AUTHOR
!!    ------
!!      MV   *TEB-MSU*   10/2026
!
IMPLICIT NONE
!
!*       0.   MODULE DATA
!             -----------
INTEGER, SAVE :: TEB_LOG_UNIT = -1     ! unit of the CSV file (from NEWUNIT)
LOGICAL, SAVE :: LTEB_LOG     = .FALSE.! .TRUE. when the CSV file is open
INTEGER, SAVE, ALLOCATABLE :: TEB_LOG_BLOCK(:)  ! blocks to write (empty: no filter)
INTEGER, SAVE, ALLOCATABLE :: TEB_LOG_POINT(:)  ! points to write (empty: no filter)
LOGICAL, SAVE :: LTEB_LOG_FILTER = .FALSE.      ! .TRUE. when the filter is active
!
CONTAINS
!
!------------------------------------------------------------------------------
!*      1.   OPEN THE DIAGNOSTIC FILE
!------------------------------------------------------------------------------
SUBROUTINE TEB_LOG_INIT (CPATH, KRC)
!
CHARACTER(LEN=*), INTENT(IN)  :: CPATH   ! full path of the output CSV file
INTEGER,          INTENT(OUT) :: KRC     ! status of the OPEN
!------------------------------------------------------------------------------
!
OPEN(NEWUNIT=TEB_LOG_UNIT, FILE=CPATH, STATUS='REPLACE', ACTION='WRITE', IOSTAT=KRC)
LTEB_LOG = (KRC == 0)
!
END SUBROUTINE TEB_LOG_INIT
!
!------------------------------------------------------------------------------
!*      2.   WRITE THE HEADER (called once, before the first row)
!------------------------------------------------------------------------------
SUBROUTINE TEB_LOG_HEADER (CLINE)
!
CHARACTER(LEN=*), INTENT(IN) :: CLINE   ! header line
!------------------------------------------------------------------------------
!
IF (.NOT. LTEB_LOG) RETURN
WRITE(TEB_LOG_UNIT,'(A)') TRIM(CLINE)
!
END SUBROUTINE TEB_LOG_HEADER
!
!------------------------------------------------------------------------------
!*      3.   WRITE ONE ROW
!------------------------------------------------------------------------------
SUBROUTINE TEB_LOG_STEP (CLINE)
!
CHARACTER(LEN=*), INTENT(IN) :: CLINE   ! one row of values
!------------------------------------------------------------------------------
!
IF (.NOT. LTEB_LOG) RETURN
WRITE(TEB_LOG_UNIT,'(A)') TRIM(CLINE)
!
END SUBROUTINE TEB_LOG_STEP
!
!------------------------------------------------------------------------------
!*      4.   CLOSE THE DIAGNOSTIC FILE
!------------------------------------------------------------------------------
SUBROUTINE TEB_LOG_FINAL
!------------------------------------------------------------------------------
!
IF (TEB_LOG_UNIT > 0) CLOSE(TEB_LOG_UNIT)
TEB_LOG_UNIT = -1
LTEB_LOG     = .FALSE.
!
END SUBROUTINE TEB_LOG_FINAL
!
!
!------------------------------------------------------------------------------
!*      5.   SELECTION OF THE BLOCKS AND POINTS TO WRITE
!------------------------------------------------------------------------------
SUBROUTINE TEB_LOG_SET_FILTER (KBLOCK, KPOINT)
!
!* The host passes the lists of blocks and of points for which the text
!* output is wanted. Empty lists mean no filter: every call is written,
!* which is the behaviour of the offline driver. In the coupled model the
!* lists are empty by default (see the comment in sfc_interface).
!
INTEGER, DIMENSION(:), INTENT(IN) :: KBLOCK
INTEGER, DIMENSION(:), INTENT(IN) :: KPOINT
!------------------------------------------------------------------------------
!
IF (ALLOCATED(TEB_LOG_BLOCK)) DEALLOCATE(TEB_LOG_BLOCK)
IF (ALLOCATED(TEB_LOG_POINT)) DEALLOCATE(TEB_LOG_POINT)
ALLOCATE(TEB_LOG_BLOCK(SIZE(KBLOCK)), TEB_LOG_POINT(SIZE(KPOINT)))
TEB_LOG_BLOCK(:) = KBLOCK(:)
TEB_LOG_POINT(:) = KPOINT(:)
LTEB_LOG_FILTER  = (SIZE(KBLOCK) > 0 .AND. SIZE(KBLOCK) == SIZE(KPOINT))
!
END SUBROUTINE TEB_LOG_SET_FILTER
!
!------------------------------------------------------------------------------
!*      6.   IS THIS BLOCK AND POINT TO BE WRITTEN?
!------------------------------------------------------------------------------
LOGICAL FUNCTION TEB_LOG_SELECTED (KIBLOCK, KIPOINT)
!
INTEGER, INTENT(IN) :: KIBLOCK
INTEGER, INTENT(IN) :: KIPOINT
INTEGER             :: J
!------------------------------------------------------------------------------
!
TEB_LOG_SELECTED = .TRUE.
IF (.NOT. LTEB_LOG_FILTER) RETURN
TEB_LOG_SELECTED = .FALSE.
DO J = 1, SIZE(TEB_LOG_BLOCK)
   IF (TEB_LOG_BLOCK(J) == KIBLOCK .AND. TEB_LOG_POINT(J) == KIPOINT) THEN
      TEB_LOG_SELECTED = .TRUE.
      RETURN
   END IF
END DO
!
END FUNCTION TEB_LOG_SELECTED
!
END MODULE TEB_LOG
