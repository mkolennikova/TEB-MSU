!SFX_LIC TEB/SURFEX interfaces are distributed under the CeCILL-C licence.
!!    MODIFICATIONS
!!    -------------
!!      TEB-MSU development
!!      09/2026 -- Mikhail Varentsov (MV)
!!        Emulate external diagnostic garden and greenroof surfaces.
!!      11/2026 -- Mikhail Varentsov (MV)
!!        Share the ordinary-driver equations and diagnostics per host column.
!-------------------------------------------------------------------------------
MODULE TEB_OFFLINE_SURFACES
USE TEB_OFFLINE_HOST, ONLY: TEB_BLOCK, active
USE MODD_CSTS, ONLY: XSTEFAN
USE MODD_PROXI_SVAT_PAR, ONLY: proxy_phu_gdn,proxy_phu_grf
USE MODI_GARDEN, ONLY: GARDEN_PCD
USE MODE_GARDEN_BALANCE, ONLY: GARDEN_PCD_NEUTRAL,GARDEN_PCH_NEUTRAL,XVMIN_GD
IMPLICIT NONE
PRIVATE
PUBLIC :: EXTERNAL_SURFACES
CONTAINS
SUBROUTINE EXTERNAL_SURFACES(c)
TYPE(TEB_BLOCK),INTENT(INOUT)::c
IF(c%teb_type_garden=='EXT' .OR. c%teb_type_garden=='EXT_NEU') CALL PCD_GARDEN(c)
IF(c%teb_lgreenroof_ext) CALL PCD_GREENROOF(c)
END SUBROUTINE
SUBROUTINE PCD_GARDEN(c)
TYPE(TEB_BLOCK),INTENT(INOUT)::c
INTEGER :: JI
DO JI = 1, c%nvec
  IF(.NOT.active(c,JI)) CYCLE
  !* tau of the garden exchange: the same tanh relaxation of the canyon
  !* H/W ratio as CBS_TAU of src/src_teb/teb_garden.F90 (which does not use
  !* the building height), with the namelist parameters; tau = 1 when the
  !* CBS scheme is disabled
  c%emu_tau(JI) = 1.
  IF (c%teb_lcbs_scheme) THEN
    c%emu_tau(JI) = 0.5*(1.+TANH((c%urb_h2w(JI)-c%teb_tau_hw_thresh) &
      /MAX(c%teb_tau_hw_width,TINY(1.))))
  END IF
  !* canyon path: reference air at the low canyon level (height H/2, the
  !* same height, the same roughness length and the same thermal roughness
  !* as the internal scheme: the shared neutral formulation)
  !* PCD (momentum, friction only) and PCH (heat and moisture, z0h) come
  !* from the module of the internal garden, so that the emulated garden and
  !* the internal one use exactly the same coefficients
  c%emu_pcd_can(JI)                         = GARDEN_PCD_NEUTRAL(c%urb_h_bld(JI)/2., c%teb_z0_gd(JI))
  c%emu_pch_can(JI)                         = GARDEN_PCH_NEUTRAL(c%urb_h_bld(JI)/2., c%teb_z0_gd(JI), &
    c%urb_z0_o_z0h_gdn(JI))
  c%emu_v_can(JI)                           = 0.
  IF (c%emu_pcd_can(JI) > 0.) c%emu_v_can(JI) = MAX(c%teb_wind_canyon(JI), XVMIN_GD)
  !* atmosphere path: reference air of the forcing level
  c%emu_pcd_atm(JI)                         = GARDEN_PCD_NEUTRAL(c%hlev_teb(JI), c%teb_z0_gd(JI))
  c%emu_pch_atm(JI)                         = GARDEN_PCH_NEUTRAL(c%hlev_teb(JI), c%teb_z0_gd(JI), &
    c%urb_z0_o_z0h_gdn(JI))
  c%emu_v_atm(JI)                           = 0.
  IF (c%emu_pcd_atm(JI) > 0.) c%emu_v_atm(JI) = MAX(SQRT(c%u(JI)**2+c%v(JI)**2), XVMIN_GD)
  !* tau aggregation of the THERMAL conductances (they carry the balance)
  c%emu_ca_can(JI) = c%emu_pch_can(JI)*c%emu_v_can(JI)
  c%emu_ca_atm(JI) = c%emu_pch_atm(JI)*c%emu_v_atm(JI)
  c%emu_ca_eff(JI) = c%emu_tau(JI)*c%emu_ca_can(JI) + (1.-c%emu_tau(JI))*c%emu_ca_atm(JI)
  !* the single complete set (wind, air) given to the external model
  c%emu_v_star(JI) = c%emu_tau(JI)*c%emu_v_can(JI) + (1.-c%emu_tau(JI))*c%emu_v_atm(JI)
  c%emu_t_star(JI) = c%teb_tcanyon(JI)            ! first approximation: canyon air
  c%emu_q_star(JI) = c%teb_qcanyon(JI)
  !* effective coefficients (covariance term of the tau averaging removed);
  !* the heat/moisture one is built from the thermal conductances, the
  !* momentum one from the momentum coefficient of the canyon path
  c%emu_ch_naive(JI)                        = c%emu_tau(JI)*c%emu_pch_can(JI) + &
    (1.-c%emu_tau(JI))*c%emu_pch_atm(JI)
  c%emu_ch_eff(JI)                          = 0.
  IF (c%emu_ca_eff(JI) > 0.) c%emu_ch_eff(JI) = c%emu_ca_eff(JI)/MAX(c%emu_v_star(JI), XVMIN_GD)
  c%emu_cd_eff(JI)                          = 0.
  IF (c%emu_v_star(JI) > 0.) THEN
    c%emu_cd_eff(JI) = c%emu_pcd_can(JI)*c%emu_v_can(JI)**2/MAX(c%emu_v_star(JI),XVMIN_GD)**2
  END IF
  !* radiation received by the garden, from the fluxes absorbed by TEB
  c%emu_psw(JI) = 0.
  c%emu_plw(JI) = 0.
  IF (1.-c%teb_alb_gd(JI) > 1.E-6) c%emu_psw(JI) = c%teb_sobs(JI)/(1.-c%teb_alb_gd(JI))
  IF (c%teb_emis_gd(JI) > 1.E-6) THEN
    c%emu_plw(JI) = c%teb_thbs(JI)/c%teb_emis_gd(JI) + XSTEFAN*c%teb_ts_gd(JI)**4
  END IF
  CALL GARDEN_PCD('PROXY_NEW', c%emu_cd_eff(JI:JI), c%emu_ch_eff(JI:JI), c%emu_v_star(JI:JI), &
                  c%emu_t_star(JI:JI), c%emu_q_star(JI:JI), proxy_phu_gdn,   &
                  c%teb_alb_gd(JI:JI), c%teb_emis_gd(JI:JI), c%rho(JI:JI), c%ps(JI:JI), c%emu_psw(JI:JI), &
                  c%emu_plw(JI:JI),            &
                  c%emu_rn(JI:JI), c%emu_h(JI:JI), c%emu_le(JI:JI), c%emu_gflux(JI:JI), c%emu_sfco2(JI:JI), &
                  c%emu_evap(JI:JI),         &
                  c%emu_puw(JI:JI), c%emu_runoff(JI:JI), c%emu_pac(JI:JI), c%emu_qsat(JI:JI), &
                  c%teb_ts_gd(JI:JI),             &
                  c%emu_drain(JI:JI), c%emu_irrig(JI:JI))
  !* state and fluxes prescribed to TEB at the next model sub-step
  c%emu_ts(JI:JI)        = c%teb_ts_gd(JI:JI)
  c%teb_qs_gd(JI:JI)     = proxy_phu_gdn*c%emu_qsat(JI:JI)
  c%teb_shfl_gd(JI:JI)   = c%emu_h(JI:JI)
  c%teb_lhfl_gd(JI:JI)   = c%emu_le(JI:JI)
  c%teb_qvfl_gd(JI:JI)   = c%emu_evap(JI:JI)
  c%teb_runoff_gd(JI:JI) = 0.
  !* first call: the effective coefficient must reproduce the tau-aggregated
  !* conductance exactly (the covariance term of the averaging is removed)
END DO
END SUBROUTINE PCD_GARDEN
SUBROUTINE PCD_GREENROOF(c)
TYPE(TEB_BLOCK),INTENT(INOUT)::c
INTEGER :: JI
DO JI = 1, c%nvec
  IF(.NOT.active(c,JI)) CYCLE
  !* single path: reference air of the forcing level (height hlev_teb,
  !* wind PVMOD), with the same height, the same roughness length and the
  !* same thermal roughness as the internal diagnostic greenroof (the
  !* shared neutral formulation, see MODE_GARDEN_BALANCE)
  c%emu_gr_pcd(JI)                        = GARDEN_PCD_NEUTRAL(c%hlev_teb(JI), c%teb_z0_gr(JI))
  c%emu_gr_pch(JI)                        = GARDEN_PCH_NEUTRAL(c%hlev_teb(JI), c%teb_z0_gr(JI), &
    c%urb_z0_o_z0h_grf(JI))
  c%emu_gr_v(JI)                          = 0.
  IF (c%emu_gr_pcd(JI) > 0.) c%emu_gr_v(JI) = MAX(SQRT(c%u(JI)**2+c%v(JI)**2), XVMIN_GD)
  c%emu_gr_ca(JI)                         = c%emu_gr_pch(JI)*c%emu_gr_v(JI)
  !* the single complete set (wind, air) given to the external model
  c%emu_gr_t(JI) = c%t(JI)
  c%emu_gr_q(JI) = c%qv(JI)
  !* effective coefficients: a single path, so no covariance term of a
  !* tau averaging; the momentum one serves the friction flux
  c%emu_gr_cd(JI) = c%emu_gr_pcd(JI)
  c%emu_gr_ch(JI) = c%emu_gr_pch(JI)
  !* radiative forcing of the city (the greenroof is on the roof)
  c%emu_gr_psw(JI) = (c%swdir_s(JI) + c%swdifd_s(JI)) * (1.-c%teb_fr_panel(JI))
  c%emu_gr_plw(JI) = c%lwd_s(JI) * (1.-c%teb_fr_panel(JI))
  CALL GARDEN_PCD('PROXY_NEW', c%emu_gr_cd(JI:JI), c%emu_gr_ch(JI:JI), c%emu_gr_v(JI:JI), &
                  c%emu_gr_t(JI:JI), c%emu_gr_q(JI:JI), proxy_phu_grf, &
                  c%teb_alb_gr(JI:JI), c%teb_emis_gr(JI:JI), c%rho(JI:JI), c%ps(JI:JI), &
                  c%emu_gr_psw(JI:JI), c%emu_gr_plw(JI:JI),                   &
                  c%emu_gr_rn(JI:JI), c%emu_gr_h(JI:JI), c%emu_gr_le(JI:JI), c%emu_gr_gflux(JI:JI), &
                  c%emu_gr_sfco2(JI:JI), c%emu_gr_evap(JI:JI),    &
                  c%emu_gr_puw(JI:JI), c%emu_gr_runoff(JI:JI), c%emu_gr_pac(JI:JI), c%emu_gr_qsat(JI:JI), &
                  c%teb_ts_gr(JI:JI),              &
                  c%emu_gr_drain(JI:JI), c%emu_gr_irrig(JI:JI))
  !* state and fluxes prescribed to TEB at the next model sub-step
  c%emu_gr_ts(JI:JI)     = c%teb_ts_gr(JI:JI)
  c%teb_qs_gr(JI:JI)     = proxy_phu_grf*c%emu_gr_qsat(JI:JI)
  c%teb_shfl_gr(JI:JI)   = c%emu_gr_h(JI:JI)
  c%teb_lhfl_gr(JI:JI)   = c%emu_gr_le(JI:JI)
  c%teb_qvfl_gr(JI:JI)   = c%emu_gr_evap(JI:JI)
  c%teb_runoff_gr(JI:JI) = 0.
  !* first call: the effective coefficients must reproduce the conductances
  !* exactly (CH_eff*max(V*,Vmin) = Ca by construction, a single path)
END DO
END SUBROUTINE PCD_GREENROOF
END MODULE TEB_OFFLINE_SURFACES
