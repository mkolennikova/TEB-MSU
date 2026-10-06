!auto_modi:spll_snow_cover_1layer.D
MODULE MODI_SNOW_COVER_1LAYER
INTERFACE
    SUBROUTINE SNOW_COVER_1LAYER(PTSTEP, PANSMIN, PANSMAX, PTODRY, PRHOSMIN, PRHOSMAX,   &
                                 PRHOFOLD, OALL_MELT, PDRAIN_TIME, PWCRN, PZ0SN, PZ0HSN, &
                                 TPSNOW, PTG, PTG_COEFA, PTG_COEFB, PABS_SW, PLW1, PLW2, &
                                 PTA, PQA, PVMOD, PPS, PRHOA, PSR, PZREF, PUREF, PRNSNOW,&
                                 PHSNOW, PLESNOW, PGSNOW, PMELT, PDQS_SNOW, PABS_LW, PSNOW_D  ,&
!MV202609 CBS scheme of the road (revision: snow-to-atmosphere branch)
                                 PTA_ATM, PQA_ATM, PVMOD_ATM, PZREF_ATM, PUREF_ATM,    &
                                 PTAU, LCBS_SPLIT, PHSNOW_CAN, PHSNOW_ATM,             &
                                 PLESNOW_CAN, PLESNOW_ATM   )  
USE MODD_TYPE_SNOW, ONLY : SURF_SNOW
IMPLICIT NONE
REAL,                 INTENT(IN)    :: PTSTEP   ! time step
REAL,                 INTENT(IN)    :: PANSMIN  ! minimum snow albedo
REAL,                 INTENT(IN)    :: PANSMAX  ! maximum snow albedo
REAL,                 INTENT(IN)    :: PTODRY   ! snow albedo decreasing constant
REAL,                 INTENT(IN)    :: PRHOSMIN ! minimum snow density
REAL,                 INTENT(IN)    :: PRHOSMAX ! maximum snow density
REAL,                 INTENT(IN)    :: PRHOFOLD ! snow density increasing constant
LOGICAL,              INTENT(IN)    :: OALL_MELT! T --> all snow runs off if
REAL,                 INTENT(IN)    :: PDRAIN_TIME ! drainage folding time (days)
REAL,                 INTENT(IN)    :: PWCRN    ! critical snow amount necessary
REAL,                 INTENT(IN)    :: PZ0SN    ! snow roughness length for momentum
REAL,                 INTENT(IN)    :: PZ0HSN   ! snow roughness length for heat
TYPE(SURF_SNOW), INTENT(INOUT) :: TPSNOW
REAL, DIMENSION(:), INTENT(IN)    :: PTG      ! underlying ground temperature
REAL, DIMENSION(:), INTENT(IN)    :: PTG_COEFA! underlying ground temperature
REAL, DIMENSION(:), INTENT(IN)    :: PTG_COEFB! implicit terms
REAL, DIMENSION(:), INTENT(IN)    :: PABS_SW  ! absorbed SW energy (Wm-2)
REAL, DIMENSION(:), INTENT(IN)    :: PLW1     ! LW coef independant of TSNOW
REAL, DIMENSION(:), INTENT(IN)    :: PLW2     ! LW coef dependant   of TSNOW
REAL, DIMENSION(:), INTENT(IN)    :: PTA      ! temperature at the lowest level
REAL, DIMENSION(:), INTENT(IN)    :: PQA      ! specific humidity
REAL, DIMENSION(:), INTENT(IN)    :: PVMOD    ! module of the horizontal wind
REAL, DIMENSION(:), INTENT(IN)    :: PPS      ! pressure at the surface
REAL, DIMENSION(:), INTENT(IN)    :: PRHOA    ! air density
REAL, DIMENSION(:), INTENT(IN)    :: PSR      ! snow rate
REAL, DIMENSION(:), INTENT(IN)    :: PZREF    ! reference height of the first
REAL, DIMENSION(:), INTENT(IN)    :: PUREF    ! reference height of the first
REAL, DIMENSION(:), INTENT(OUT)   :: PRNSNOW  ! net radiation over snow
REAL, DIMENSION(:), INTENT(OUT)   :: PHSNOW   ! sensible heat flux over snow
REAL, DIMENSION(:), INTENT(OUT)   :: PLESNOW  ! latent heat flux over snow
REAL, DIMENSION(:), INTENT(OUT)   :: PGSNOW   ! flux under the snow
REAL, DIMENSION(:), INTENT(OUT)   :: PMELT    ! snow melting rate (kg/m2/s)
REAL, DIMENSION(:), INTENT(OUT)   :: PDQS_SNOW! heat storage inside snow
REAL, DIMENSION(:), INTENT(OUT)   :: PABS_LW  ! absorbed LW rad by snow (W/m2)
REAL, DIMENSION(:), INTENT(OUT)   :: PSNOW_D  ! snow depth
!MV202609 CBS scheme of the road (revision: snow-to-atmosphere branch)
REAL, DIMENSION(:), INTENT(IN)    :: PTA_ATM      ! air temperature of the forcing level (free atmosphere)
REAL, DIMENSION(:), INTENT(IN)    :: PQA_ATM      ! specific humidity of the forcing level
REAL, DIMENSION(:), INTENT(IN)    :: PVMOD_ATM    ! wind of the forcing level
REAL, DIMENSION(:), INTENT(IN)    :: PZREF_ATM    ! reference height of the forcing level (temperature)
REAL, DIMENSION(:), INTENT(IN)    :: PUREF_ATM    ! reference height of the forcing level (wind)
REAL, DIMENSION(:), INTENT(IN)    :: PTAU         ! CBS scheme weight of the canyon path (-)
LOGICAL,              INTENT(IN)  :: LCBS_SPLIT   ! T: the tau split of the snow exchange is active
REAL, DIMENSION(:), INTENT(OUT)   :: PHSNOW_CAN   ! sensible heat flux over snow, snow -> canyon air
REAL, DIMENSION(:), INTENT(OUT)   :: PHSNOW_ATM   ! sensible heat flux over snow, snow -> forcing level
REAL, DIMENSION(:), INTENT(OUT)   :: PLESNOW_CAN  ! latent heat flux over snow, snow -> canyon air
REAL, DIMENSION(:), INTENT(OUT)   :: PLESNOW_ATM  ! latent heat flux over snow, snow -> forcing level
END SUBROUTINE SNOW_COVER_1LAYER
END INTERFACE
END MODULE MODI_SNOW_COVER_1LAYER
