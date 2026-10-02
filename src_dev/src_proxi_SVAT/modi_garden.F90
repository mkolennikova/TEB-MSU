!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 1998-2013 Meteo-France
! This is part of the TEB software governed by the CeCILL-C licence version 1.
! See LICENCE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt for details.
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt
! http://www.cecill.info/licences/Licence_CeCILL-C_V1-fr.txt
! The CeCILL-C licence is compatible with L-GPL
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
MODULE MODI_GARDEN
!
!*** Interfaces of the three garden routines of src_proxi_SVAT/garden.F90:
!***   GARDEN_TAU - garden of the model with the tau split (called by TEB)
!***   GARDEN     - reduced diagnostic garden without the tau split
!***   GARDEN_PCD - diagnostic garden with external exchange coefficients
!***                (no reference height and no roughness length among its
!***                arguments: both are already inside the coefficients; the
!***                momentum coefficient gives the friction flux, the thermal
!***                one the balance of heat and moisture, see z0h)
!*** Only GARDEN_TAU returns the tau-branch decomposition (PH_GARDEN_CAN/ATM,
!*** PLE_GARDEN_CAN/ATM): GARDEN and GARDEN_PCD return a single set of fluxes.
!
INTERFACE
!
    SUBROUTINE GARDEN_TAU(TYPE_GARDEN, PZ_LOWCAN, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN, PZ0_GD, &
                PZ0_O_Z0H, PPHU_GD,                                                       &
                PUREF, PVMOD, PTA, PQA, PTAU, LTAU_SPLIT,                                  &
                PALB_GD, PEMIS_GD, PRHOA, PPS, PSW, PLW,                                   &
                PRN_GARDEN,PH_GARDEN,PLE_GARDEN,PGFLUX_GARDEN,PSFCO2,                      &
                PEVAP_GARDEN, PUW_GARDEN,PRUNOFF_GARDEN,                                   &
                PAC_GARDEN,PQSAT_GARDEN,PTS_GARDEN,                                        &
                PAC_AGG_GARDEN, PHU_AGG_GARDEN, PDRAIN_GARDEN, PIRRIG_GARDEN,              &
!MV202609 tau scheme of the garden (canyon and atmosphere branch fluxes)
                PH_GARDEN_CAN, PH_GARDEN_ATM, PLE_GARDEN_CAN, PLE_GARDEN_ATM               )
 CHARACTER(LEN=*),     INTENT(IN)  :: TYPE_GARDEN      ! type of the garden model
REAL, DIMENSION(:)  , INTENT(IN)  :: PZ_LOWCAN        ! height of the reference air (m)
REAL, DIMENSION(:)  , INTENT(IN)  :: PT_LOWCAN        ! reference air temperature (K)
REAL, DIMENSION(:)  , INTENT(IN)  :: PQ_LOWCAN        ! reference air humidity (kg/kg)
REAL, DIMENSION(:)  , INTENT(IN)  :: PU_LOWCAN        ! reference wind (m/s)
REAL, DIMENSION(:)  , INTENT(IN)  :: PZ0_GD           ! garden roughness length (m)
!MV202609 garden thermal roughness (z0h)
REAL,               INTENT(IN)  :: PZ0_O_Z0H        ! garden z0/z0h ratio (-), >= 1
 !MV202609 tunable surface relative humidity of the garden (namelist urb_phu_gdn)
 REAL,               INTENT(IN)  :: PPHU_GD          ! garden surface relative humidity (-)

REAL, DIMENSION(:)  , INTENT(IN)  :: PUREF            ! height of the wind of the forcing level (m)
REAL, DIMENSION(:)  , INTENT(IN)  :: PVMOD            ! wind speed at the forcing level (m/s)
REAL, DIMENSION(:)  , INTENT(IN)  :: PTA              ! air temperature of the forcing level (K)
REAL, DIMENSION(:)  , INTENT(IN)  :: PQA              ! air specific humidity of the forcing level (kg/kg)
REAL, DIMENSION(:)  , INTENT(IN)  :: PTAU             ! tau weight of the canyon path (-)
LOGICAL             , INTENT(IN)  :: LTAU_SPLIT       ! .TRUE.: split the garden exchange by tau
REAL, DIMENSION(:)  , INTENT(IN)  :: PALB_GD          ! garden albedo
REAL, DIMENSION(:)  , INTENT(IN)  :: PEMIS_GD         ! garden emissivity
REAL, DIMENSION(:)  , INTENT(IN)  :: PRHOA            ! air density at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)  :: PPS              ! pressure at the surface
REAL, DIMENSION(:)  , INTENT(IN)  :: PSW              ! received solar radiation
REAL, DIMENSION(:)  , INTENT(IN)  :: PLW              ! received infrared radiation
REAL, DIMENSION(:)  , INTENT(OUT) :: PRN_GARDEN       ! net radiation over green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PH_GARDEN        ! sensible heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PLE_GARDEN       ! latent heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PGFLUX_GARDEN    ! flux through the green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PSFCO2           ! flux of CO2 (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PEVAP_GARDEN     ! total evaporation (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PUW_GARDEN       ! friction flux (m2/s2)
REAL, DIMENSION(:)  , INTENT(OUT) :: PRUNOFF_GARDEN   ! runoff over garden (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PAC_GARDEN       ! aerodynamical conductance (m/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PQSAT_GARDEN     ! saturation humidity (kg/kg)
REAL, DIMENSION(:)  , INTENT(INOUT) :: PTS_GARDEN     ! radiative surface temp. (snow free) (K)
REAL, DIMENSION(:)  , INTENT(OUT) :: PAC_AGG_GARDEN   ! aggregated conductance (m/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PHU_AGG_GARDEN   ! aggregated relative humidity (-)
REAL, DIMENSION(:)  , INTENT(OUT) :: PDRAIN_GARDEN    ! garden total (vertical) drainage (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PIRRIG_GARDEN    ! garden summer irrigation rate (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PH_GARDEN_CAN    ! sensible heat flux, canyon branch (W/m2)
REAL, DIMENSION(:)  , INTENT(OUT) :: PH_GARDEN_ATM    ! sensible heat flux, atmosphere branch (W/m2)
REAL, DIMENSION(:)  , INTENT(OUT) :: PLE_GARDEN_CAN   ! latent heat flux, canyon branch (W/m2)
REAL, DIMENSION(:)  , INTENT(OUT) :: PLE_GARDEN_ATM   ! latent heat flux, atmosphere branch (W/m2)
END SUBROUTINE GARDEN_TAU
!
    SUBROUTINE GARDEN(TYPE_GARDEN, PZ_LOWCAN, PT_LOWCAN, PQ_LOWCAN, PU_LOWCAN, PZ0_GD,    &
                PZ0_O_Z0H, PPHU_GD,                                                       &
                PALB_GD, PEMIS_GD, PRHOA, PPS, PSW, PLW,                                  &
                PRN_GARDEN,PH_GARDEN,PLE_GARDEN,PGFLUX_GARDEN,PSFCO2,                     &
                PEVAP_GARDEN, PUW_GARDEN,PRUNOFF_GARDEN,                                  &
                PAC_GARDEN,PQSAT_GARDEN,PTS_GARDEN,                                       &
                PAC_AGG_GARDEN, PHU_AGG_GARDEN, PDRAIN_GARDEN, PIRRIG_GARDEN              )
 CHARACTER(LEN=*),     INTENT(IN)  :: TYPE_GARDEN      ! type of the garden model
REAL, DIMENSION(:)  , INTENT(IN)  :: PZ_LOWCAN        ! height of the reference air (m)
REAL, DIMENSION(:)  , INTENT(IN)  :: PT_LOWCAN        ! reference air temperature (K)
REAL, DIMENSION(:)  , INTENT(IN)  :: PQ_LOWCAN        ! reference air humidity (kg/kg)
REAL, DIMENSION(:)  , INTENT(IN)  :: PU_LOWCAN        ! reference wind (m/s)
 !MV202609 tunable surface relative humidity of the garden (namelist urb_phu_gdn)
 REAL,               INTENT(IN)  :: PPHU_GD          ! garden surface relative humidity (-)

REAL, DIMENSION(:)  , INTENT(IN)  :: PZ0_GD           ! garden roughness length (m)
!MV202609 garden thermal roughness (z0h)
REAL,               INTENT(IN)  :: PZ0_O_Z0H        ! garden z0/z0h ratio (-), >= 1
REAL, DIMENSION(:)  , INTENT(IN)  :: PALB_GD          ! garden albedo
REAL, DIMENSION(:)  , INTENT(IN)  :: PEMIS_GD         ! garden emissivity
REAL, DIMENSION(:)  , INTENT(IN)  :: PRHOA            ! air density at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)  :: PPS              ! pressure at the surface
REAL, DIMENSION(:)  , INTENT(IN)  :: PSW              ! received solar radiation
REAL, DIMENSION(:)  , INTENT(IN)  :: PLW              ! received infrared radiation
REAL, DIMENSION(:)  , INTENT(OUT) :: PRN_GARDEN       ! net radiation over green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PH_GARDEN        ! sensible heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PLE_GARDEN       ! latent heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PGFLUX_GARDEN    ! flux through the green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PSFCO2           ! flux of CO2 (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PEVAP_GARDEN     ! total evaporation (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PUW_GARDEN       ! friction flux (m2/s2)
REAL, DIMENSION(:)  , INTENT(OUT) :: PRUNOFF_GARDEN   ! runoff over garden (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PAC_GARDEN       ! aerodynamical conductance (m/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PQSAT_GARDEN     ! saturation humidity (kg/kg)
REAL, DIMENSION(:)  , INTENT(INOUT) :: PTS_GARDEN     ! radiative surface temp. (snow free) (K)
REAL, DIMENSION(:)  , INTENT(OUT) :: PAC_AGG_GARDEN   ! aggregated conductance (m/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PHU_AGG_GARDEN   ! aggregated relative humidity (-)
REAL, DIMENSION(:)  , INTENT(OUT) :: PDRAIN_GARDEN    ! garden total (vertical) drainage (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PIRRIG_GARDEN    ! garden summer irrigation rate (kg/m2/s)
END SUBROUTINE GARDEN
!
!MV202609 diagnostic garden with an external exchange coefficient (experiment interface)
    SUBROUTINE GARDEN_PCD(TYPE_GARDEN, PPCD_GD, PPCH_GD, PV_GD, PT_REF, PQ_REF, PPHU_GD,  &
                PALB_GD, PEMIS_GD, PRHOA, PPS, PSW, PLW,                                  &
                PRN_GARDEN,PH_GARDEN,PLE_GARDEN,PGFLUX_GARDEN,PSFCO2,                     &
                PEVAP_GARDEN, PUW_GARDEN,PRUNOFF_GARDEN,                                  &
                PAC_GARDEN,PQSAT_GARDEN,PTS_GARDEN,                                       &
                PAC_AGG_GARDEN, PHU_AGG_GARDEN, PDRAIN_GARDEN, PIRRIG_GARDEN              )
 CHARACTER(LEN=*),     INTENT(IN)  :: TYPE_GARDEN      ! type of the garden model
 !MV202609 tunable surface relative humidity of the garden (namelist urb_phu_gdn)
 REAL                , INTENT(IN)  :: PPHU_GD          ! garden surface relative humidity (-)

REAL, DIMENSION(:)  , INTENT(IN)  :: PPCD_GD          ! momentum exchange coefficient (-)
!MV202609 garden thermal roughness (z0h)
REAL, DIMENSION(:)  , INTENT(IN)  :: PPCH_GD          ! thermal (scalar) exchange coefficient (-)
REAL, DIMENSION(:)  , INTENT(IN)  :: PV_GD            ! wind of the reference state (m/s)
REAL, DIMENSION(:)  , INTENT(IN)  :: PT_REF           ! reference air temperature (K)
REAL, DIMENSION(:)  , INTENT(IN)  :: PQ_REF           ! reference air humidity (kg/kg)
REAL, DIMENSION(:)  , INTENT(IN)  :: PALB_GD          ! garden albedo
REAL, DIMENSION(:)  , INTENT(IN)  :: PEMIS_GD         ! garden emissivity
REAL, DIMENSION(:)  , INTENT(IN)  :: PRHOA            ! air density at the lowest level
REAL, DIMENSION(:)  , INTENT(IN)  :: PPS              ! pressure at the surface
REAL, DIMENSION(:)  , INTENT(IN)  :: PSW              ! received solar radiation
REAL, DIMENSION(:)  , INTENT(IN)  :: PLW              ! received infrared radiation
REAL, DIMENSION(:)  , INTENT(OUT) :: PRN_GARDEN       ! net radiation over green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PH_GARDEN        ! sensible heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PLE_GARDEN       ! latent heat flux over green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PGFLUX_GARDEN    ! flux through the green areas
REAL, DIMENSION(:)  , INTENT(OUT) :: PSFCO2           ! flux of CO2 (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PEVAP_GARDEN     ! total evaporation (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PUW_GARDEN       ! friction flux (m2/s2)
REAL, DIMENSION(:)  , INTENT(OUT) :: PRUNOFF_GARDEN   ! runoff over garden (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PAC_GARDEN       ! aerodynamical conductance (m/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PQSAT_GARDEN     ! saturation humidity (kg/kg)
REAL, DIMENSION(:)  , INTENT(INOUT) :: PTS_GARDEN     ! radiative surface temp. (snow free) (K)
REAL, DIMENSION(:)  , INTENT(OUT) :: PAC_AGG_GARDEN   ! aggregated conductance (m/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PHU_AGG_GARDEN   ! aggregated relative humidity (-)
REAL, DIMENSION(:)  , INTENT(OUT) :: PDRAIN_GARDEN    ! garden total (vertical) drainage (kg/m2/s)
REAL, DIMENSION(:)  , INTENT(OUT) :: PIRRIG_GARDEN    ! garden summer irrigation rate (kg/m2/s)
END SUBROUTINE GARDEN_PCD
!
END INTERFACE
END MODULE MODI_GARDEN