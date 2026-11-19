!SFX_LIC TEB/SURFEX interfaces are distributed under the CeCILL-C licence.
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      11/2026 -- Mikhail Varentsov (MV)
!!        Validate split/legacy scalar namelists without owning model defaults.
!!        Reuse dev's strict literal/group syntax while retaining ctrl physics.
!!        Validate named common selectors while accepting legacy key lengths.
!!      11/2026 -- OpenAI Codex
!!        Require the town roughness option under its new namelist key.
!-------------------------------------------------------------------------------
MODULE TEB_CTRL_NAMELIST_INPUT
IMPLICIT NONE
PRIVATE
PUBLIC :: CTRL_PREPARE_NAMELISTS
TYPE NML_ASSIGNMENT
  CHARACTER(LEN=64) :: name=''
  CHARACTER(LEN=:),ALLOCATABLE :: value
  INTEGER :: line=0
  INTEGER :: count=0
END TYPE
CONTAINS
SUBROUTINE CTRL_PREPARE_NAMELISTS(path,opts_text,param_text,legacy,garden_z0_explicit)
CHARACTER(LEN=*),INTENT(IN)::path
CHARACTER(LEN=:),ALLOCATABLE,INTENT(OUT)::opts_text,param_text
LOGICAL,INTENT(OUT)::legacy,garden_z0_explicit
TYPE(NML_ASSIGNMENT),ALLOCATABLE::o(:),a(:),probe(:),native_opts(:)
CHARACTER(LEN=:),ALLOCATABLE::text
LOGICAL::found
INTEGER::j,n,rc
CALL read_text(path,text)
CALL scan_group(text,'tebparam',a,legacy,path)
IF(legacy) THEN
  CALL scan_group(text,'tebopts',probe,found,path)
  IF(found) CALL fail(path,'tebopts',0,'cannot mix tebparam and tebopts')
  CALL scan_group(text,'tebparams',probe,found,path)
  IF(found) CALL fail(path,'tebparams',0,'cannot mix tebparam and tebparams')
  ALLOCATE(o(0))
ELSE
  CALL scan_group(text,'tebopts',o,found,path)
  CALL scan_group(text,'tebparams',a,found,path)
  IF(.NOT.found) CALL fail(path,'tebparams',0,'missing namelist group')
END IF
ALLOCATE(native_opts(0))
DO j=1,SIZE(o)
  CALL require_count(o(j),1,1,path)
  CALL check_string(o(j),path)
  IF(o(j)%name=='nvec') THEN
    READ(o(j)%value,*,IOSTAT=rc) n
    IF(rc/=0) CALL fail(path,'nvec',o(j)%line,'expected integer nvec=1')
    IF(n/=1) CALL fail(path,'nvec',o(j)%line,'src_ctrl supports nvec=1 only')
  ELSE
    native_opts=[native_opts,o(j)]
  END IF
END DO
DO j=1,SIZE(a)
  CALL check_string(a(j),path)
  IF(a(j)%name=='teb_fai') THEN
    CALL require_count(a(j),8,8,path)
  ELSE
    CALL require_count(a(j),1,1,path)
  END IF
END DO
garden_z0_explicit=ANY(a%name=='urb_z0_gdn')
opts_text=build_text('tebopts',native_opts)
IF(legacy) THEN
  param_text=build_text('tebparam',a)
ELSE
  param_text=build_text('tebparams',a)
END IF
END SUBROUTINE
SUBROUTINE check_string(a,path)
TYPE(NML_ASSIGNMENT),INTENT(IN)::a
CHARACTER(LEN=*),INTENT(IN)::path
INTEGER::limit,n,p
CHARACTER::quote
SELECT CASE(a%name)
CASE('teb_itype_bem','teb_ctype_bem')
  limit=3
CASE('teb_itype_natvent','teb_ctype_natvent','teb_ctype_wind','teb_hroad_dir','teb_wall_opt')
  limit=4
CASE('teb_itype_bem_cool','teb_itype_bem_heat','teb_ctype_bem_cool','teb_ctype_bem_heat')
  limit=6
CASE('teb_ctype_exch_road','teb_ctype_exch_roof','teb_ctype_exch_canyon')
  limit=6
CASE('teb_type_garden','teb_type_greenroof','teb_ctype_garden','teb_ctype_greenroof')
  limit=9
CASE('teb_ctype_z0_town','urb_zd_town')
  limit=16
CASE DEFAULT
  RETURN
END SELECT
CALL require_count(a,1,1,path)
n=LEN(a%value)
quote=a%value(1:1)
IF(quote=="'" .OR. quote=='"') THEN
  n=n-2
  p=2
  DO WHILE(p<LEN(a%value))
    IF(a%value(p:p)==quote) THEN
      n=n-1
      p=p+1
    END IF
    p=p+1
  END DO
END IF
IF(n>limit) CALL fail(path,a%name,a%line,'character value exceeds supported length')
END SUBROUTINE

SUBROUTINE read_text(path,text)
USE, INTRINSIC :: ISO_FORTRAN_ENV, ONLY: IOSTAT_EOR, IOSTAT_END
CHARACTER(LEN=*),INTENT(IN)::path
CHARACTER(LEN=:),ALLOCATABLE,INTENT(OUT)::text
CHARACTER(LEN=256)::chunk
INTEGER::unit,rc,n
text=''
OPEN(NEWUNIT=unit,FILE=path,STATUS='OLD',ACTION='READ',IOSTAT=rc)
IF(rc/=0) CALL fail(path,'file',0,'cannot open namelist')
DO
  READ(unit,'(A)',ADVANCE='NO',SIZE=n,IOSTAT=rc) chunk
  IF(n>0) text=text//chunk(:n)
  IF(rc==IOSTAT_EOR) text=text//ACHAR(10)
  IF(rc==IOSTAT_END) EXIT
  IF(rc/=0 .AND. rc/=IOSTAT_EOR) CALL fail(path,'file',0,'cannot read namelist')
END DO
CLOSE(unit)
END SUBROUTINE

SUBROUTINE skip_space(text,p,line)
CHARACTER(LEN=*),INTENT(IN)::text
INTEGER,INTENT(INOUT)::p,line
DO WHILE(p<=LEN(text))
  SELECT CASE(text(p:p))
  CASE(' ',ACHAR(9),ACHAR(13))
    p=p+1
  CASE(ACHAR(10))
    p=p+1
    line=line+1
  CASE('!')
    DO WHILE(p<=LEN(text))
      IF(text(p:p)==ACHAR(10)) EXIT
      p=p+1
    END DO
  CASE DEFAULT
    EXIT
  END SELECT
END DO
END SUBROUTINE

FUNCTION lower(s) RESULT(out)
CHARACTER(LEN=*),INTENT(IN)::s
CHARACTER(LEN=LEN(s))::out
INTEGER::j,k
out=s
DO j=1,LEN(s)
  k=IACHAR(s(j:j))
  IF(k>=65 .AND. k<=90) out(j:j)=ACHAR(k+32)
END DO
END FUNCTION

LOGICAL FUNCTION name_char(c)
CHARACTER,INTENT(IN)::c
INTEGER::k
k=IACHAR(c)
name_char=(k>=65 .AND. k<=90) .OR. (k>=97 .AND. k<=122) .OR. (k>=48 .AND. k<=57) .OR. c=='_'
END FUNCTION

FUNCTION get_name(text,p) RESULT(name)
CHARACTER(LEN=*),INTENT(IN)::text
INTEGER,INTENT(INOUT)::p
CHARACTER(LEN=:),ALLOCATABLE::name
INTEGER::start
start=p
DO WHILE(p<=LEN(text))
  IF(.NOT.name_char(text(p:p))) EXIT
  p=p+1
END DO
name=lower(text(start:p-1))
END FUNCTION

FUNCTION get_value(text,p,line,path,item) RESULT(value)
CHARACTER(LEN=*),INTENT(IN)::text,path,item
INTEGER,INTENT(INOUT)::p,line
CHARACTER(LEN=:),ALLOCATABLE::value
CHARACTER::quote,c
INTEGER::start
start=p
quote=text(p:p)
IF(quote=="'" .OR. quote=='"') THEN
  p=p+1
  DO WHILE(p<=LEN(text))
    c=text(p:p)
    IF(c==ACHAR(10)) line=line+1
    IF(c==quote) THEN
      IF(p<LEN(text)) THEN
        IF(text(p+1:p+1)==quote) THEN
          p=p+2
          CYCLE
        END IF
      END IF
      p=p+1
      value=text(start:p-1)
      RETURN
    END IF
    p=p+1
  END DO
  CALL fail(path,item,line,'unterminated quoted value')
ELSE
  DO WHILE(p<=LEN(text))
    c=text(p:p)
    IF(INDEX(' ,/=*&()!'//ACHAR(9)//ACHAR(10)//ACHAR(13),c)>0) EXIT
    p=p+1
  END DO
  IF(p==start) CALL fail(path,item,line,'repetitions, indexed assignments and null values are unsupported')
  value=text(start:p-1)
END IF
END FUNCTION

SUBROUTINE scan_group(text,group,a,found,path)
CHARACTER(LEN=*),INTENT(IN)::text,group,path
TYPE(NML_ASSIGNMENT),ALLOCATABLE,INTENT(OUT)::a(:)
LOGICAL,INTENT(OUT)::found
TYPE(NML_ASSIGNMENT)::entry
CHARACTER(LEN=:),ALLOCATABLE::name,value,probe
INTEGER::p,line,q,ql,j
LOGICAL::comma,match
ALLOCATE(a(0))
found=.FALSE.
p=1
line=1
DO
  CALL skip_space(text,p,line)
  IF(p>LEN(text)) EXIT
  IF(text(p:p)/='&') CALL fail(path,group,line,'expected a namelist group')
  p=p+1
  name=get_name(text,p)
  SELECT CASE(name)
  CASE('tebopts','tebparams','tebparam','tebforcing','block_test')
  CASE DEFAULT
    CALL fail(path,name,line,'unknown namelist group')
  END SELECT
  match=name==group
  IF(match .AND. found) CALL fail(path,group,line,'duplicate namelist group')
  IF(match) found=.TRUE.
  DO
    CALL skip_space(text,p,line)
    IF(p>LEN(text)) CALL fail(path,name,line,'missing terminating slash')
    IF(text(p:p)=='/') THEN
      p=p+1
      EXIT
    END IF
    IF(.NOT.match) THEN
      ! Skip other groups with quote-aware handling of paths and H/3.
      IF(text(p:p)=="'" .OR. text(p:p)=='"') THEN
        value=get_value(text,p,line,path,name)
      ELSE
        p=p+1
      END IF
      CYCLE
    END IF
    entry%line=line
    probe=get_name(text,p)
    IF(LEN(probe)>LEN(entry%name)) CALL fail(path,group,line,'parameter name is too long')
    entry%name=probe
    IF(LEN_TRIM(entry%name)==0) CALL fail(path,group,line,'expected parameter name')
    IF(entry%name=='urb_z0_town') &
      CALL fail(path,group,line,'urb_z0_town is deprecated. Use teb_ctype_z0_town in &tebopts.')
    CALL skip_space(text,p,line)
    IF(p>LEN(text)) CALL fail(path,entry%name,line,'missing equals sign')
    IF(text(p:p)/='=') CALL fail(path,entry%name,line,'expected =; indexed assignments are unsupported')
    DO j=1,SIZE(a)
      IF(a(j)%name==entry%name) CALL fail(path,entry%name,line,'duplicate parameter')
    END DO
    p=p+1
    entry%value=''
    entry%count=0
    comma=.FALSE.
    DO
      CALL skip_space(text,p,line)
      IF(p>LEN(text)) CALL fail(path,entry%name,line,'missing terminating slash')
      IF(text(p:p)=='/') EXIT
      IF(text(p:p)==',') THEN
        IF(comma .OR. entry%count==0) CALL fail(path,entry%name,line,'null values are unsupported')
        comma=.TRUE.
        p=p+1
        CYCLE
      END IF
      q=p
      ql=line
      probe=get_name(text,q)
      IF(LEN(probe)>0) THEN
        CALL skip_space(text,q,ql)
        IF(q<=LEN(text)) THEN
          IF(text(q:q)=='=') EXIT
        END IF
      END IF
      value=get_value(text,p,line,path,entry%name)
      IF(entry%count>0) entry%value=entry%value//', '
      entry%value=entry%value//value
      entry%count=entry%count+1
      comma=.FALSE.
    END DO
    IF(entry%count==0) CALL fail(path,entry%name,entry%line,'missing value')
    a=[a,entry]
  END DO
END DO
END SUBROUTINE

SUBROUTINE require_count(a,one,n,path)
TYPE(NML_ASSIGNMENT),INTENT(IN)::a
INTEGER,INTENT(IN)::one,n
CHARACTER(LEN=*),INTENT(IN)::path
CHARACTER(LEN=160)::message
IF(a%count==one .OR. a%count==n) RETURN
WRITE(message,'(A,I0,A,I0,A,I0)') 'received ',a%count,' values; expected ',one,' or ',n
CALL fail(path,a%name,a%line,TRIM(message))
END SUBROUTINE

FUNCTION build_text(group,a) RESULT(text)
CHARACTER(LEN=*),INTENT(IN)::group
TYPE(NML_ASSIGNMENT),INTENT(IN)::a(:)
CHARACTER(LEN=:),ALLOCATABLE::text
INTEGER::j
text='&'//group//ACHAR(10)
DO j=1,SIZE(a)
  text=text//TRIM(a(j)%name)//'='//a(j)%value//','//ACHAR(10)
END DO
text=text//'/'//ACHAR(10)
END FUNCTION

SUBROUTINE fail(path,item,line,message)
CHARACTER(LEN=*),INTENT(IN)::path,item,message
INTEGER,INTENT(IN)::line
WRITE(*,'(A,A,A,I0,A,A,A,A)') 'ERROR namelist ',TRIM(path),':',line,': ',TRIM(item),': ',TRIM(message)
ERROR STOP 1
END SUBROUTINE
END MODULE TEB_CTRL_NAMELIST_INPUT
