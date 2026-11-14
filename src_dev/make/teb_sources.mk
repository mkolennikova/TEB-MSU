# MV202611 explicit source ownership for the common library and offline host.
# Keep experimental/original snapshots out of these lists. Update dependencies
# in teb_dependencies.mk when adding or changing Fortran USE associations.

#    MODIFICATIONS
#    -------------
#      TEB-MSU development
#      11/2026 -- Mikhail Varentsov (MV)
#        Declare separate common-library and offline source ownership, excluding
#        experimental snapshots from the production archive.
#-------------------------------------------------------------------------------
COMMON_SRC := \
    src_api/sfc_teb.F90 \
    src_api/teb_host.F90 \
    src_api/teb_log.F90 \
    src_api/urb_aero_params.F90 \
    src_driver/abor1_sfx.F90 \
    src_driver/ahf_traffic_now.F90 \
    src_driver/call_driver.F90 \
    src_driver/close_file.F90 \
    src_driver/close_file_asc.F90 \
    src_driver/modd_reprod_oper.F90 \
    src_driver/modd_surf_conf.F90 \
    src_driver/wind_profile_wang.F90 \
    src_proxi_SVAT/garden.F90 \
    src_proxi_SVAT/greenroof.F90 \
    src_proxi_SVAT/modd_proxi_svat_par.F90 \
    src_proxi_SVAT/modi_garden.F90 \
    src_proxi_SVAT/modi_greenroof.F90 \
    src_proxi_SVAT/modi_teb_veg_properties.F90 \
    src_proxi_SVAT/teb_veg_properties.F90 \
    src_solar/circumsolar_rad.F90 \
    src_solar/sunpos.F90 \
    src_struct/alloc_teb_struct.F90 \
    src_struct/bem_morpho_struct.F90 \
    src_struct/dealloc_teb_struct.F90 \
    src_struct/modd_bem_optionn.F90 \
    src_struct/modd_bem_paramsn.F90 \
    src_struct/modd_bemn.F90 \
    src_struct/modd_diag_misc_tebn.F90 \
    src_struct/modd_teb_ext_surfn.F90 \
    src_struct/modd_teb_forcingn.F90 \
    src_struct/modd_teb_irrign.F90 \
    src_struct/modd_teb_optionn.F90 \
    src_struct/modd_teb_paneln.F90 \
    src_struct/modd_teb_paramsn.F90 \
    src_struct/modd_tebn.F90 \
    src_struct/modd_type_snow.F90 \
    src_struct/modi_alloc_teb_struct.F90 \
    src_struct/modi_bem_morpho_struct.f90 \
    src_struct/modi_dealloc_teb_struct.F90 \
    src_struct/modi_diag_misc_teb_util.F90 \
    src_struct/modi_window_data_struct.f90 \
    src_struct/window_data_struct.F90 \
    src_teb/avg_urban_fluxes.F90 \
    src_teb/bem.F90 \
    src_teb/bem_morpho.F90 \
    src_teb/bld_e_budget.F90 \
    src_teb/bld_occ_calendar.F90 \
    src_teb/day_of_week.F90 \
    src_teb/dx_air_cooling_coil_cv.F90 \
    src_teb/facade_e_budget.F90 \
    src_teb/floor_layer_e_budget.F90 \
    src_teb/flxsurf3bx.F \
    src_teb/hook.F90 \
    src_teb/ini_csts.F90 \
    src_teb/init_surfconsphy.F \
    src_teb/layer_e_budget.F90 \
    src_teb/layer_e_budget_get_coef.F90 \
    src_teb/mass_layer_e_budget.F90 \
    src_teb/modd_bem_cst.F90 \
    src_teb/modd_csts.F90 \
    src_teb/modd_flood_par.F90 \
    src_teb/modd_snow_par.F90 \
    src_teb/modd_surf_atm.F90 \
    src_teb/modd_surf_par.F90 \
    src_teb/modd_type_date_surf.F90 \
    src_teb/modd_water_par.F90 \
    src_teb/mode_conv_DOE.F90 \
    src_teb/mode_psychro.F90 \
    src_teb/mode_surf_snow_frac.F90 \
    src_teb/mode_thermos.F90 \
    src_teb/modi_avg_urban_fluxes.f90 \
    src_teb/modi_bem.f90 \
    src_teb/modi_bem_morpho.f90 \
    src_teb/modi_bld_e_budget.f90 \
    src_teb/modi_bld_occ_calendar.f90 \
    src_teb/modi_day_of_week.f90 \
    src_teb/modi_dx_air_cooling_coil_cv.f90 \
    src_teb/modi_facade_e_budget.f90 \
    src_teb/modi_floor_layer_e_budget.f90 \
    src_teb/modi_flxsurf3bx.f \
    src_teb/modi_ini_csts.f90 \
    src_teb/modi_init_surfconsphy.f \
    src_teb/modi_layer_e_budget.f90 \
    src_teb/modi_layer_e_budget_get_coef.f90 \
    src_teb/modi_mass_layer_e_budget.f90 \
    src_teb/modi_road_layer_e_budget.f90 \
    src_teb/modi_roof_impl_coef.f90 \
    src_teb/modi_roof_layer_e_budget.f90 \
    src_teb/modi_snow_cover_1layer.f90 \
    src_teb/modi_solar_panel.f90 \
    src_teb/modi_surface_aero_cond.f90 \
    src_teb/modi_surface_cd.f90 \
    src_teb/modi_surface_ri.f90 \
    src_teb/modi_teb.f90 \
    src_teb/modi_teb_garden.f90 \
    src_teb/modi_teb_irrig.f90 \
    src_teb/modi_tridiag_ground.f90 \
    src_teb/modi_urban_drag.f90 \
    src_teb/modi_urban_exch_coef.f90 \
    src_teb/modi_urban_fluxes.f90 \
    src_teb/modi_urban_hydro.f90 \
    src_teb/modi_urban_lw_coef.f90 \
    src_teb/modi_urban_mrt.F90 \
    src_teb/modi_urban_snow_evol.f90 \
    src_teb/modi_urban_solar_abs.f90 \
    src_teb/modi_wall_layer_e_budget.f90 \
    src_teb/modi_wind_threshold.f90 \
    src_teb/modi_window_data.f90 \
    src_teb/modi_window_e_budget.f90 \
    src_teb/modi_window_shading.f90 \
    src_teb/modi_window_shading_availability.f90 \
    src_teb/road_layer_e_budget.F90 \
    src_teb/roof_impl_coef.F90 \
    src_teb/roof_layer_e_budget.F90 \
    src_teb/snow_cover_1layer.F90 \
    src_teb/solar_panel.F90 \
    src_teb/surface_aero_cond.F90 \
    src_teb/surface_cd.F90 \
    src_teb/surface_ri.F90 \
    src_teb/teb.F90 \
    src_teb/teb_garden.F90 \
    src_teb/teb_irrig.F90 \
    src_teb/tridiag_ground.F90 \
    src_teb/urban_drag.F90 \
    src_teb/urban_exch_coef.F90 \
    src_teb/urban_fluxes.F90 \
    src_teb/urban_hydro.F90 \
    src_teb/urban_lw_coef.F90 \
    src_teb/urban_mrt.F90 \
    src_teb/urban_snow_evol.F90 \
    src_teb/urban_solar_abs.F90 \
    src_teb/vslog.f \
    src_teb/wall_layer_e_budget.F90 \
    src_teb/wind_threshold.F90 \
    src_teb/window_data.F90 \
    src_teb/window_e_budget.F90 \
    src_teb/window_shading.F90 \
    src_teb/window_shading_availability.F90

OFFLINE_SRC := \
    src_offline/add_forecast_to_date_surf.F90 \
    src_offline/modd_forc_atm.F90 \
    src_offline/ol_alloc_atm.F90 \
    src_offline/ol_read_atm.F90 \
    src_offline/ol_read_atm_ascii.F90 \
    src_offline/ol_time_interp_atm.F90 \
    src_offline/open_close_bin_asc_forc.F90 \
    src_offline/read_surf_atm.F90 \
    src_offline/run_teb_offline.F90

BLOCK_SRC := \
    src_offline/teb_offline_block_host.F90 \
    src_offline/run_teb_offline_block.F90

LEGACY_SRC := \
    src_driver/mode_char2real.F90 \
    src_driver/modd_arch.F90

PLATFORM_SRC := src_driver/wrap_setlocale.c

# Preprocessor include files used by the common Fortran sources.
COMMON_INC := src_teb/impnone.cdk src_teb/surfcon.cdk src_teb/consphy.cdk src_teb/stabfunc2.cdk
