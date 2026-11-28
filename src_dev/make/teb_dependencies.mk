# MV202611 Fortran module dependencies for the explicit source manifest.
# Each object names its source and the objects providing its USE modules.
# External procedures resolve through the archive index at final link time.

#    MODIFICATIONS
#    -------------
#      TEB-MSU development
#      11/2026 -- Mikhail Varentsov (MV)
#        Declare explicit module/include dependencies for the split
#        common-library and offline builds.
#        Order the shared offline modules before both thin main programs.
#-------------------------------------------------------------------------------
$(OBJDIR)/sfc_teb.o: src_api/sfc_teb.F90 \
    $(OBJDIR)/teb_host.o \
    $(OBJDIR)/teb_log.o \
    $(OBJDIR)/call_driver.o \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/modi_ini_csts.o

$(OBJDIR)/teb_host.o: src_api/teb_host.F90 \
    $(OBJDIR)/urb_aero_params.o \
    $(OBJDIR)/circumsolar_rad.o \
    $(OBJDIR)/sunpos.o \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_ext_surfn.o \
    $(OBJDIR)/modd_teb_forcingn.o \
    $(OBJDIR)/modd_teb_irrign.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/modi_alloc_teb_struct.o \
    $(OBJDIR)/modi_bem_morpho_struct.o \
    $(OBJDIR)/modi_dealloc_teb_struct.o \
    $(OBJDIR)/modi_diag_misc_teb_util.o \
    $(OBJDIR)/modi_window_data_struct.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/mode_thermos.o

$(OBJDIR)/teb_log.o: src_api/teb_log.F90 \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_forcingn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o

$(OBJDIR)/urb_aero_params.o: src_api/urb_aero_params.F90 \
    $(OBJDIR)/modd_csts.o

$(OBJDIR)/abor1_sfx.o: src_driver/abor1_sfx.F90 \
    $(OBJDIR)/close_file.o \
    $(OBJDIR)/modd_surf_conf.o

$(OBJDIR)/ahf_traffic_now.o: src_driver/ahf_traffic_now.F90

$(OBJDIR)/call_driver.o: src_driver/call_driver.F90 \
    $(OBJDIR)/mode_urban_utci.o \
    $(OBJDIR)/teb_log.o \
    $(OBJDIR)/urb_aero_params.o \
    $(OBJDIR)/ahf_traffic_now.o \
    $(OBJDIR)/modd_reprod_oper.o \
    $(OBJDIR)/wind_profile_wang.o \
    $(OBJDIR)/circumsolar_rad.o \
    $(OBJDIR)/sunpos.o \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_ext_surfn.o \
    $(OBJDIR)/modd_teb_forcingn.o \
    $(OBJDIR)/modd_teb_irrign.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/modi_bem_morpho_struct.o \
    $(OBJDIR)/modi_window_data_struct.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_atm.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/modd_type_date_surf.o \
    $(OBJDIR)/mode_thermos.o \
    $(OBJDIR)/modi_init_surfconsphy.o \
    $(OBJDIR)/modi_teb_garden.o \
    $(OBJDIR)/modi_urban_mrt.o \
    $(OBJDIR)/modi_wind_threshold.o

$(OBJDIR)/close_file.o: src_driver/close_file.F90

$(OBJDIR)/close_file_asc.o: src_driver/close_file_asc.F90

$(OBJDIR)/modd_reprod_oper.o: src_driver/modd_reprod_oper.F90

$(OBJDIR)/modd_surf_conf.o: src_driver/modd_surf_conf.F90

$(OBJDIR)/wind_profile_wang.o: src_driver/wind_profile_wang.F90 \
    $(OBJDIR)/modd_surf_par.o

$(OBJDIR)/garden.o: src_proxi_SVAT/garden.F90 \
    $(OBJDIR)/modd_proxi_svat_par.o \
    $(OBJDIR)/modi_garden.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/mode_thermos.o

$(OBJDIR)/greenroof.o: src_proxi_SVAT/greenroof.F90 \
    $(OBJDIR)/garden.o \
    $(OBJDIR)/modd_proxi_svat_par.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_type_date_surf.o \
    $(OBJDIR)/mode_thermos.o

$(OBJDIR)/modd_proxi_svat_par.o: src_proxi_SVAT/modd_proxi_svat_par.F90

$(OBJDIR)/modi_garden.o: src_proxi_SVAT/modi_garden.F90

$(OBJDIR)/modi_greenroof.o: src_proxi_SVAT/modi_greenroof.F90 \
    $(OBJDIR)/modd_type_date_surf.o

$(OBJDIR)/modi_teb_veg_properties.o: src_proxi_SVAT/modi_teb_veg_properties.F90

$(OBJDIR)/teb_veg_properties.o: src_proxi_SVAT/teb_veg_properties.F90

$(OBJDIR)/circumsolar_rad.o: src_solar/circumsolar_rad.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o

$(OBJDIR)/sunpos.o: src_solar/sunpos.F90 \
    $(OBJDIR)/modd_csts.o

$(OBJDIR)/alloc_teb_struct.o: src_struct/alloc_teb_struct.F90 \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_irrign.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/bem_morpho_struct.o: src_struct/bem_morpho_struct.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/modi_bem_morpho.o

$(OBJDIR)/dealloc_teb_struct.o: src_struct/dealloc_teb_struct.F90 \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_irrign.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modd_bem_optionn.o: src_struct/modd_bem_optionn.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/modd_bem_paramsn.o: src_struct/modd_bem_paramsn.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/modd_bemn.o: src_struct/modd_bemn.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/modd_diag_misc_tebn.o: src_struct/modd_diag_misc_tebn.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/modd_teb_ext_surfn.o: src_struct/modd_teb_ext_surfn.F90

$(OBJDIR)/modd_teb_forcingn.o: src_struct/modd_teb_forcingn.F90

$(OBJDIR)/modd_teb_irrign.o: src_struct/modd_teb_irrign.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/modd_teb_optionn.o: src_struct/modd_teb_optionn.F90 \
    $(OBJDIR)/modd_proxi_svat_par.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_type_date_surf.o

$(OBJDIR)/modd_teb_paneln.o: src_struct/modd_teb_paneln.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/modd_teb_paramsn.o: src_struct/modd_teb_paramsn.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/modd_tebn.o: src_struct/modd_tebn.F90 \
    $(OBJDIR)/modd_type_snow.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_type_date_surf.o

$(OBJDIR)/modd_type_snow.o: src_struct/modd_type_snow.F90

$(OBJDIR)/modi_alloc_teb_struct.o: src_struct/modi_alloc_teb_struct.F90 \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_irrign.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_bem_morpho_struct.o: src_struct/modi_bem_morpho_struct.f90

$(OBJDIR)/modi_dealloc_teb_struct.o: src_struct/modi_dealloc_teb_struct.F90 \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_irrign.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_diag_misc_teb_util.o: src_struct/modi_diag_misc_teb_util.F90 \
    $(OBJDIR)/modd_diag_misc_tebn.o

$(OBJDIR)/modi_window_data_struct.o: src_struct/modi_window_data_struct.f90

$(OBJDIR)/window_data_struct.o: src_struct/window_data_struct.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modi_window_data.o

$(OBJDIR)/avg_urban_fluxes.o: src_teb/avg_urban_fluxes.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/mode_thermos.o

$(OBJDIR)/bem.o: src_teb/bem.F90 \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/mode_conv_DOE.o \
    $(OBJDIR)/mode_psychro.o \
    $(OBJDIR)/mode_thermos.o \
    $(OBJDIR)/modi_dx_air_cooling_coil_cv.o \
    $(OBJDIR)/modi_floor_layer_e_budget.o \
    $(OBJDIR)/modi_mass_layer_e_budget.o

$(OBJDIR)/bem_morpho.o: src_teb/bem_morpho.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o

$(OBJDIR)/bld_e_budget.o: src_teb/bld_e_budget.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o

$(OBJDIR)/bld_occ_calendar.o: src_teb/bld_occ_calendar.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_type_date_surf.o \
    $(OBJDIR)/modi_day_of_week.o

$(OBJDIR)/day_of_week.o: src_teb/day_of_week.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/dx_air_cooling_coil_cv.o: src_teb/dx_air_cooling_coil_cv.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/mode_psychro.o \
    $(OBJDIR)/mode_thermos.o

$(OBJDIR)/facade_e_budget.o: src_teb/facade_e_budget.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/modi_wall_layer_e_budget.o \
    $(OBJDIR)/modi_window_e_budget.o

$(OBJDIR)/floor_layer_e_budget.o: src_teb/floor_layer_e_budget.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/mode_conv_DOE.o \
    $(OBJDIR)/modi_layer_e_budget.o \
    $(OBJDIR)/modi_layer_e_budget_get_coef.o

$(OBJDIR)/flxsurf3bx.o: src_teb/flxsurf3bx.F

$(OBJDIR)/hook.o: src_teb/hook.F90

$(OBJDIR)/ini_csts.o: src_teb/ini_csts.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o

$(OBJDIR)/init_surfconsphy.o: src_teb/init_surfconsphy.F

$(OBJDIR)/layer_e_budget.o: src_teb/layer_e_budget.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modi_tridiag_ground.o

$(OBJDIR)/layer_e_budget_get_coef.o: src_teb/layer_e_budget_get_coef.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/mass_layer_e_budget.o: src_teb/mass_layer_e_budget.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/mode_conv_DOE.o \
    $(OBJDIR)/modi_layer_e_budget.o \
    $(OBJDIR)/modi_layer_e_budget_get_coef.o

$(OBJDIR)/modd_bem_cst.o: src_teb/modd_bem_cst.F90

$(OBJDIR)/modd_csts.o: src_teb/modd_csts.F90

$(OBJDIR)/modd_flood_par.o: src_teb/modd_flood_par.F90

$(OBJDIR)/modd_snow_par.o: src_teb/modd_snow_par.F90

$(OBJDIR)/modd_surf_atm.o: src_teb/modd_surf_atm.F90

$(OBJDIR)/modd_surf_par.o: src_teb/modd_surf_par.F90

$(OBJDIR)/modd_type_date_surf.o: src_teb/modd_type_date_surf.F90

$(OBJDIR)/modd_water_par.o: src_teb/modd_water_par.F90

$(OBJDIR)/mode_conv_DOE.o: src_teb/mode_conv_DOE.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/mode_psychro.o: src_teb/mode_psychro.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/mode_thermos.o

$(OBJDIR)/mode_surf_snow_frac.o: src_teb/mode_surf_snow_frac.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_snow_par.o

$(OBJDIR)/mode_thermos.o: src_teb/mode_thermos.F90 \
    $(OBJDIR)/modd_reprod_oper.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o

$(OBJDIR)/modi_avg_urban_fluxes.o: src_teb/modi_avg_urban_fluxes.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_bem.o: src_teb/modi_bem.f90 \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_bem_morpho.o: src_teb/modi_bem_morpho.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o

$(OBJDIR)/modi_bld_e_budget.o: src_teb/modi_bld_e_budget.f90

$(OBJDIR)/modi_bld_occ_calendar.o: src_teb/modi_bld_occ_calendar.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/modd_type_date_surf.o

$(OBJDIR)/modi_day_of_week.o: src_teb/modi_day_of_week.f90

$(OBJDIR)/modi_dx_air_cooling_coil_cv.o: src_teb/modi_dx_air_cooling_coil_cv.f90

$(OBJDIR)/modi_facade_e_budget.o: src_teb/modi_facade_e_budget.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_floor_layer_e_budget.o: src_teb/modi_floor_layer_e_budget.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o

$(OBJDIR)/modi_flxsurf3bx.o: src_teb/modi_flxsurf3bx.f

$(OBJDIR)/modi_ini_csts.o: src_teb/modi_ini_csts.f90

$(OBJDIR)/modi_init_surfconsphy.o: src_teb/modi_init_surfconsphy.f

$(OBJDIR)/modi_layer_e_budget.o: src_teb/modi_layer_e_budget.f90

$(OBJDIR)/modi_layer_e_budget_get_coef.o: src_teb/modi_layer_e_budget_get_coef.f90

$(OBJDIR)/modi_mass_layer_e_budget.o: src_teb/modi_mass_layer_e_budget.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o

$(OBJDIR)/modi_road_layer_e_budget.o: src_teb/modi_road_layer_e_budget.f90 \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_roof_impl_coef.o: src_teb/modi_roof_impl_coef.f90 \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_roof_layer_e_budget.o: src_teb/modi_roof_layer_e_budget.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_snow_cover_1layer.o: src_teb/modi_snow_cover_1layer.f90 \
    $(OBJDIR)/modd_type_snow.o

$(OBJDIR)/modi_solar_panel.o: src_teb/modi_solar_panel.f90 \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_paneln.o

$(OBJDIR)/modi_surface_aero_cond.o: src_teb/modi_surface_aero_cond.f90

$(OBJDIR)/modi_surface_cd.o: src_teb/modi_surface_cd.f90

$(OBJDIR)/modi_surface_ri.o: src_teb/modi_surface_ri.f90

$(OBJDIR)/modi_teb.o: src_teb/modi_teb.f90 \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_irrign.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_teb_garden.o: src_teb/modi_teb_garden.f90 \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_ext_surfn.o \
    $(OBJDIR)/modd_teb_forcingn.o \
    $(OBJDIR)/modd_teb_irrign.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_teb_irrig.o: src_teb/modi_teb_irrig.f90

$(OBJDIR)/modi_tridiag_ground.o: src_teb/modi_tridiag_ground.f90

$(OBJDIR)/modi_urban_drag.o: src_teb/modi_urban_drag.f90 \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_urban_exch_coef.o: src_teb/modi_urban_exch_coef.f90

$(OBJDIR)/modi_urban_fluxes.o: src_teb/modi_urban_fluxes.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_urban_hydro.o: src_teb/modi_urban_hydro.f90

$(OBJDIR)/modi_urban_lw_coef.o: src_teb/modi_urban_lw_coef.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_urban_mrt.o: src_teb/modi_urban_mrt.F90 \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_ext_surfn.o \
    $(OBJDIR)/modd_teb_forcingn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_urban_snow_evol.o: src_teb/modi_urban_snow_evol.f90 \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_urban_solar_abs.o: src_teb/modi_urban_solar_abs.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_wall_layer_e_budget.o: src_teb/modi_wall_layer_e_budget.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o

$(OBJDIR)/modi_wind_threshold.o: src_teb/modi_wind_threshold.f90

$(OBJDIR)/modi_window_data.o: src_teb/modi_window_data.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o

$(OBJDIR)/modi_window_e_budget.o: src_teb/modi_window_e_budget.f90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o

$(OBJDIR)/modi_window_shading.o: src_teb/modi_window_shading.f90

$(OBJDIR)/modi_window_shading_availability.o: src_teb/modi_window_shading_availability.f90

$(OBJDIR)/road_layer_e_budget.o: src_teb/road_layer_e_budget.F90 \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/mode_thermos.o \
    $(OBJDIR)/modi_layer_e_budget.o \
    $(OBJDIR)/modi_layer_e_budget_get_coef.o

$(OBJDIR)/roof_impl_coef.o: src_teb/roof_impl_coef.F90 \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modi_layer_e_budget_get_coef.o

$(OBJDIR)/roof_layer_e_budget.o: src_teb/roof_layer_e_budget.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/mode_conv_DOE.o \
    $(OBJDIR)/mode_thermos.o \
    $(OBJDIR)/modi_layer_e_budget.o \
    $(OBJDIR)/modi_layer_e_budget_get_coef.o

$(OBJDIR)/snow_cover_1layer.o: src_teb/snow_cover_1layer.F90 \
    $(OBJDIR)/modd_type_snow.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_snow_par.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/mode_thermos.o \
    $(OBJDIR)/modi_surface_aero_cond.o \
    $(OBJDIR)/modi_surface_ri.o

$(OBJDIR)/solar_panel.o: src_teb/solar_panel.F90 \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o

$(OBJDIR)/surface_aero_cond.o: src_teb/surface_aero_cond.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/mode_thermos.o \
    $(OBJDIR)/modi_wind_threshold.o

$(OBJDIR)/surface_cd.o: src_teb/surface_cd.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/mode_thermos.o

$(OBJDIR)/surface_ri.o: src_teb/surface_ri.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_atm.o \
    $(OBJDIR)/modi_wind_threshold.o

$(OBJDIR)/teb.o: src_teb/teb.F90 \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_irrign.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_snow_par.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/modd_type_date_surf.o \
    $(OBJDIR)/mode_surf_snow_frac.o \
    $(OBJDIR)/mode_thermos.o \
    $(OBJDIR)/modi_bem.o \
    $(OBJDIR)/modi_bld_e_budget.o \
    $(OBJDIR)/modi_facade_e_budget.o \
    $(OBJDIR)/modi_road_layer_e_budget.o \
    $(OBJDIR)/modi_roof_layer_e_budget.o \
    $(OBJDIR)/modi_snow_cover_1layer.o \
    $(OBJDIR)/modi_teb_irrig.o \
    $(OBJDIR)/modi_urban_drag.o \
    $(OBJDIR)/modi_urban_fluxes.o \
    $(OBJDIR)/modi_urban_hydro.o \
    $(OBJDIR)/modi_urban_snow_evol.o \
    $(OBJDIR)/modi_wind_threshold.o

$(OBJDIR)/teb_garden.o: src_teb/teb_garden.F90 \
    $(OBJDIR)/urban_mrt.o \
    $(OBJDIR)/garden.o \
    $(OBJDIR)/modi_garden.o \
    $(OBJDIR)/modi_greenroof.o \
    $(OBJDIR)/modi_teb_veg_properties.o \
    $(OBJDIR)/modd_bem_optionn.o \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_ext_surfn.o \
    $(OBJDIR)/modd_teb_forcingn.o \
    $(OBJDIR)/modd_teb_irrign.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paneln.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_snow_par.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/modd_type_date_surf.o \
    $(OBJDIR)/mode_surf_snow_frac.o \
    $(OBJDIR)/mode_thermos.o \
    $(OBJDIR)/modi_avg_urban_fluxes.o \
    $(OBJDIR)/modi_bld_occ_calendar.o \
    $(OBJDIR)/modi_solar_panel.o \
    $(OBJDIR)/modi_teb.o \
    $(OBJDIR)/modi_urban_lw_coef.o \
    $(OBJDIR)/modi_urban_solar_abs.o \
    $(OBJDIR)/modi_window_shading_availability.o

$(OBJDIR)/teb_irrig.o: src_teb/teb_irrig.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/tridiag_ground.o: src_teb/tridiag_ground.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/urban_drag.o: src_teb/urban_drag.F90 \
    $(OBJDIR)/garden.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/mode_conv_DOE.o \
    $(OBJDIR)/mode_thermos.o \
    $(OBJDIR)/modi_urban_exch_coef.o \
    $(OBJDIR)/modi_wind_threshold.o

$(OBJDIR)/urban_exch_coef.o: src_teb/urban_exch_coef.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modi_flxsurf3bx.o \
    $(OBJDIR)/modi_surface_aero_cond.o \
    $(OBJDIR)/modi_surface_cd.o \
    $(OBJDIR)/modi_surface_ri.o \
    $(OBJDIR)/modi_wind_threshold.o

$(OBJDIR)/urban_fluxes.o: src_teb/urban_fluxes.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o

$(OBJDIR)/urban_hydro.o: src_teb/urban_hydro.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o

$(OBJDIR)/urban_lw_coef.o: src_teb/urban_lw_coef.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o

$(OBJDIR)/mode_urban_utci.o: src_teb/mode_urban_utci.F90 \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/urban_mrt.o

$(OBJDIR)/urban_mrt.o: src_teb/urban_mrt.F90 \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_ext_surfn.o \
    $(OBJDIR)/modd_teb_forcingn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o

$(OBJDIR)/urban_snow_evol.o: src_teb/urban_snow_evol.F90 \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_snow_par.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/mode_surf_snow_frac.o \
    $(OBJDIR)/modi_roof_impl_coef.o \
    $(OBJDIR)/modi_snow_cover_1layer.o

$(OBJDIR)/urban_solar_abs.o: src_teb/urban_solar_abs.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_diag_misc_tebn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_bem_cst.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/modi_window_shading.o

$(OBJDIR)/vslog.o: src_teb/vslog.f

$(OBJDIR)/wall_layer_e_budget.o: src_teb/wall_layer_e_budget.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/modd_tebn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o \
    $(OBJDIR)/mode_conv_DOE.o \
    $(OBJDIR)/modi_layer_e_budget.o \
    $(OBJDIR)/modi_layer_e_budget_get_coef.o

$(OBJDIR)/wind_threshold.o: src_teb/wind_threshold.F90 \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_surf_atm.o

$(OBJDIR)/window_data.o: src_teb/window_data.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/hook.o

$(OBJDIR)/window_e_budget.o: src_teb/window_e_budget.F90 \
    $(OBJDIR)/modd_bem_paramsn.o \
    $(OBJDIR)/modd_bemn.o \
    $(OBJDIR)/hook.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/mode_conv_DOE.o

$(OBJDIR)/window_shading.o: src_teb/window_shading.F90 \
    $(OBJDIR)/hook.o

$(OBJDIR)/window_shading_availability.o: src_teb/window_shading_availability.F90 \
    $(OBJDIR)/modd_bem_cst.o

$(OFFLINE_OBJDIR)/add_forecast_to_date_surf.o: src_offline/add_forecast_to_date_surf.F90

$(OFFLINE_OBJDIR)/modd_forc_atm.o: src_offline/modd_forc_atm.F90

$(OFFLINE_OBJDIR)/ol_alloc_atm.o: src_offline/ol_alloc_atm.F90 \
    $(OFFLINE_OBJDIR)/modd_forc_atm.o \
    $(OBJDIR)/modd_surf_par.o

$(OFFLINE_OBJDIR)/ol_read_atm.o: src_offline/ol_read_atm.F90 \
    $(OFFLINE_OBJDIR)/ol_read_atm_ascii.o \
    $(OBJDIR)/mode_thermos.o

$(OFFLINE_OBJDIR)/ol_read_atm_ascii.o: src_offline/ol_read_atm_ascii.F90 \
    $(OFFLINE_OBJDIR)/read_surf_atm.o

$(OFFLINE_OBJDIR)/ol_time_interp_atm.o: src_offline/ol_time_interp_atm.F90 \
    $(OFFLINE_OBJDIR)/modd_forc_atm.o \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_surf_par.o

$(OFFLINE_OBJDIR)/open_close_bin_asc_forc.o: src_offline/open_close_bin_asc_forc.F90

$(OFFLINE_OBJDIR)/read_surf_atm.o: src_offline/read_surf_atm.F90

$(OFFLINE_OBJDIR)/run_teb_offline.o: src_offline/run_teb_offline.F90 \
    $(OFFLINE_OBJDIR)/teb_offline_driver.o

# Module outputs are also checked when reusing a build directory.
$(OBJDIR)/flxsurf3bx.o: src_teb/impnone.cdk src_teb/surfcon.cdk src_teb/consphy.cdk src_teb/stabfunc2.cdk
$(OBJDIR)/init_surfconsphy.o: src_teb/surfcon.cdk src_teb/consphy.cdk
$(OBJDIR)/vslog.o: src_teb/impnone.cdk

TEB_MODULES_sfc_teb := sfc_teb
TEB_MODULES_teb_host := teb_host
TEB_MODULES_teb_log := teb_log
TEB_MODULES_urb_aero_params := modi_urb_aero_params
TEB_MODULES_ahf_traffic_now := ahf_traffic_now
TEB_MODULES_call_driver := modi_call_driver
TEB_MODULES_close_file := modi_close_file
TEB_MODULES_close_file_asc := modi_close_file_asc
TEB_MODULES_modd_reprod_oper := modd_reprod_oper
TEB_MODULES_modd_surf_conf := modd_surf_conf
TEB_MODULES_wind_profile_wang := wind_profile_wang
TEB_MODULES_garden := mode_garden_balance
TEB_MODULES_modd_proxi_svat_par := modd_proxi_svat_par
TEB_MODULES_modi_garden := modi_garden
TEB_MODULES_modi_greenroof := modi_greenroof
TEB_MODULES_modi_teb_veg_properties := modi_teb_veg_properties
TEB_MODULES_circumsolar_rad := modi_circumsolar_rad
TEB_MODULES_sunpos := modi_sunpos
TEB_MODULES_modd_bem_optionn := modd_bem_option_n
TEB_MODULES_modd_bem_paramsn := modd_bem_params_n
TEB_MODULES_modd_bemn := modd_bem_n
TEB_MODULES_modd_diag_misc_tebn := modd_diag_misc_teb_n
TEB_MODULES_modd_teb_ext_surfn := modd_teb_ext_surf_n
TEB_MODULES_modd_teb_forcingn := modd_teb_forcing_n
TEB_MODULES_modd_teb_irrign := modd_teb_irrig_n
TEB_MODULES_modd_teb_optionn := modd_teb_option_n
TEB_MODULES_modd_teb_paneln := modd_teb_panel_n
TEB_MODULES_modd_teb_paramsn := modd_teb_params_n
TEB_MODULES_modd_tebn := modd_teb_n
TEB_MODULES_modd_type_snow := modd_type_snow
TEB_MODULES_modi_alloc_teb_struct := modi_alloc_teb_struct
TEB_MODULES_modi_bem_morpho_struct := modi_bem_morpho_struct
TEB_MODULES_modi_dealloc_teb_struct := modi_dealloc_teb_struct
TEB_MODULES_modi_diag_misc_teb_util := modi_diag_misc_teb_util
TEB_MODULES_modi_window_data_struct := modi_window_data_struct
TEB_MODULES_hook := parkind1 yomhook
TEB_MODULES_modd_bem_cst := modd_bem_cst
TEB_MODULES_modd_csts := modd_csts
TEB_MODULES_modd_flood_par := modd_flood_par
TEB_MODULES_modd_snow_par := modd_snow_par
TEB_MODULES_modd_surf_atm := modd_surf_atm
TEB_MODULES_modd_surf_par := modd_surf_par
TEB_MODULES_modd_type_date_surf := modd_type_date_surf
TEB_MODULES_modd_water_par := modd_water_par
TEB_MODULES_mode_conv_DOE := mode_conv_doe
TEB_MODULES_mode_psychro := mode_psychro
TEB_MODULES_mode_surf_snow_frac := mode_surf_snow_frac
TEB_MODULES_mode_thermos := mode_thermos
TEB_MODULES_urban_mrt := mode_urban_mrt
TEB_MODULES_mode_urban_utci := mode_urban_utci
TEB_MODULES_modi_avg_urban_fluxes := modi_avg_urban_fluxes
TEB_MODULES_modi_bem := modi_bem
TEB_MODULES_modi_bem_morpho := modi_bem_morpho
TEB_MODULES_modi_bld_e_budget := modi_bld_e_budget
TEB_MODULES_modi_bld_occ_calendar := modi_bld_occ_calendar
TEB_MODULES_modi_day_of_week := modi_day_of_week
TEB_MODULES_modi_dx_air_cooling_coil_cv := modi_dx_air_cooling_coil_cv
TEB_MODULES_modi_facade_e_budget := modi_facade_e_budget
TEB_MODULES_modi_floor_layer_e_budget := modi_floor_layer_e_budget
TEB_MODULES_modi_flxsurf3bx := modi_flxsurf3bx
TEB_MODULES_modi_ini_csts := modi_ini_csts
TEB_MODULES_modi_init_surfconsphy := modi_init_surfconsphy
TEB_MODULES_modi_layer_e_budget := modi_layer_e_budget
TEB_MODULES_modi_layer_e_budget_get_coef := modi_layer_e_budget_get_coef
TEB_MODULES_modi_mass_layer_e_budget := modi_mass_layer_e_budget
TEB_MODULES_modi_road_layer_e_budget := modi_road_layer_e_budget
TEB_MODULES_modi_roof_impl_coef := modi_roof_impl_coef
TEB_MODULES_modi_roof_layer_e_budget := modi_roof_layer_e_budget
TEB_MODULES_modi_snow_cover_1layer := modi_snow_cover_1layer
TEB_MODULES_modi_solar_panel := modi_solar_panel
TEB_MODULES_modi_surface_aero_cond := modi_surface_aero_cond
TEB_MODULES_modi_surface_cd := modi_surface_cd
TEB_MODULES_modi_surface_ri := modi_surface_ri
TEB_MODULES_modi_teb := modi_teb
TEB_MODULES_modi_teb_garden := modi_teb_garden
TEB_MODULES_modi_teb_irrig := modi_teb_irrig
TEB_MODULES_modi_tridiag_ground := modi_tridiag_ground
TEB_MODULES_modi_urban_drag := modi_urban_drag
TEB_MODULES_modi_urban_exch_coef := modi_urban_exch_coef
TEB_MODULES_modi_urban_fluxes := modi_urban_fluxes
TEB_MODULES_modi_urban_hydro := modi_urban_hydro
TEB_MODULES_modi_urban_lw_coef := modi_urban_lw_coef
TEB_MODULES_modi_urban_mrt := modi_urban_mrt
TEB_MODULES_modi_urban_snow_evol := modi_urban_snow_evol
TEB_MODULES_modi_urban_solar_abs := modi_urban_solar_abs
TEB_MODULES_modi_wall_layer_e_budget := modi_wall_layer_e_budget
TEB_MODULES_modi_wind_threshold := modi_wind_threshold
TEB_MODULES_modi_window_data := modi_window_data
TEB_MODULES_modi_window_e_budget := modi_window_e_budget
TEB_MODULES_modi_window_shading := modi_window_shading
TEB_MODULES_modi_window_shading_availability := modi_window_shading_availability
TEB_MODULES_add_forecast_to_date_surf := modi_add_forecast_to_date_surf
TEB_MODULES_modd_forc_atm := modd_forc_atm
TEB_MODULES_ol_alloc_atm := modi_ol_alloc_atm
TEB_MODULES_ol_read_atm := modi_ol_read_atm
TEB_MODULES_ol_read_atm_ascii := modi_ol_read_atm_ascii
TEB_MODULES_ol_time_interp_atm := modi_ol_time_interp_atm
TEB_MODULES_read_surf_atm := modi_read_surf_atm

COMMON_MODULES := \
    ahf_traffic_now \
    modd_bem_cst \
    modd_bem_n \
    modd_bem_option_n \
    modd_bem_params_n \
    modd_csts \
    modd_diag_misc_teb_n \
    modd_flood_par \
    modd_proxi_svat_par \
    modd_reprod_oper \
    modd_snow_par \
    modd_surf_atm \
    modd_surf_conf \
    modd_surf_par \
    modd_teb_ext_surf_n \
    modd_teb_forcing_n \
    modd_teb_irrig_n \
    modd_teb_n \
    modd_teb_option_n \
    modd_teb_panel_n \
    modd_teb_params_n \
    modd_type_date_surf \
    modd_type_snow \
    modd_water_par \
    mode_conv_doe \
    mode_garden_balance \
    mode_psychro \
    mode_surf_snow_frac \
    mode_thermos \
    mode_urban_mrt \
    mode_urban_utci \
    modi_alloc_teb_struct \
    modi_avg_urban_fluxes \
    modi_bem \
    modi_bem_morpho \
    modi_bem_morpho_struct \
    modi_bld_e_budget \
    modi_bld_occ_calendar \
    modi_call_driver \
    modi_circumsolar_rad \
    modi_close_file \
    modi_close_file_asc \
    modi_day_of_week \
    modi_dealloc_teb_struct \
    modi_diag_misc_teb_util \
    modi_dx_air_cooling_coil_cv \
    modi_facade_e_budget \
    modi_floor_layer_e_budget \
    modi_flxsurf3bx \
    modi_garden \
    modi_greenroof \
    modi_ini_csts \
    modi_init_surfconsphy \
    modi_layer_e_budget \
    modi_layer_e_budget_get_coef \
    modi_mass_layer_e_budget \
    modi_road_layer_e_budget \
    modi_roof_impl_coef \
    modi_roof_layer_e_budget \
    modi_snow_cover_1layer \
    modi_solar_panel \
    modi_sunpos \
    modi_surface_aero_cond \
    modi_surface_cd \
    modi_surface_ri \
    modi_teb \
    modi_teb_garden \
    modi_teb_irrig \
    modi_teb_veg_properties \
    modi_tridiag_ground \
    modi_urb_aero_params \
    modi_urban_drag \
    modi_urban_exch_coef \
    modi_urban_fluxes \
    modi_urban_hydro \
    modi_urban_lw_coef \
    modi_urban_mrt \
    modi_urban_snow_evol \
    modi_urban_solar_abs \
    modi_wall_layer_e_budget \
    modi_wind_threshold \
    modi_window_data \
    modi_window_data_struct \
    modi_window_e_budget \
    modi_window_shading \
    modi_window_shading_availability \
    parkind1 \
    sfc_teb \
    teb_host \
    teb_log \
    wind_profile_wang \
    yomhook

OFFLINE_MODULES := \
    modd_forc_atm \
    modi_add_forecast_to_date_surf \
    modi_ol_alloc_atm \
    modi_ol_read_atm \
    modi_ol_read_atm_ascii \
    modi_ol_time_interp_atm \
    modi_read_surf_atm

# Shared offline modules are consumers of the archive, never archive members.
$(OFFLINE_OBJDIR)/teb_offline_host.o: src_offline/teb_offline_host.F90 \
    $(OBJDIR)/modd_teb_paramsn.o \
    $(OBJDIR)/sfc_teb.o $(OBJDIR)/teb_host.o $(OBJDIR)/teb_log.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modi_ini_csts.o \
    $(OBJDIR)/mode_thermos.o $(OBJDIR)/modi_garden.o \
    $(OBJDIR)/garden.o $(OBJDIR)/modd_proxi_svat_par.o \
    $(OFFLINE_OBJDIR)/modd_forc_atm.o $(OFFLINE_OBJDIR)/ol_alloc_atm.o \
    $(OFFLINE_OBJDIR)/ol_read_atm.o $(OFFLINE_OBJDIR)/ol_time_interp_atm.o \
    $(OFFLINE_OBJDIR)/add_forecast_to_date_surf.o
$(OFFLINE_OBJDIR)/teb_offline_namelists.o: src_offline/teb_offline_namelists.F90 \
    $(OBJDIR)/modd_csts.o \
    $(OBJDIR)/modd_snow_par.o \
    $(OBJDIR)/modd_teb_optionn.o \
    $(OBJDIR)/teb_host.o \
    $(OFFLINE_OBJDIR)/teb_offline_host.o
$(OFFLINE_OBJDIR)/teb_offline_surfaces.o: src_offline/teb_offline_surfaces.F90 \
    $(OFFLINE_OBJDIR)/teb_offline_host.o
$(OFFLINE_OBJDIR)/teb_offline_output.o: src_offline/teb_offline_output.F90 \
    $(OFFLINE_OBJDIR)/teb_offline_host.o
$(OFFLINE_OBJDIR)/teb_offline_driver.o: src_offline/teb_offline_driver.F90 \
    $(OFFLINE_OBJDIR)/teb_offline_host.o \
    $(OFFLINE_OBJDIR)/teb_offline_namelists.o \
    $(OFFLINE_OBJDIR)/teb_offline_surfaces.o \
    $(OFFLINE_OBJDIR)/teb_offline_output.o
$(BLOCK_OBJDIR)/run_teb_offline_block.o: src_offline/run_teb_offline_block.F90 \
    $(OFFLINE_OBJDIR)/teb_offline_driver.o
TEB_MODULES_teb_offline_host := teb_offline_host
TEB_MODULES_teb_offline_namelists := teb_offline_namelists
TEB_MODULES_teb_offline_surfaces := teb_offline_surfaces
TEB_MODULES_teb_offline_output := teb_offline_output
TEB_MODULES_teb_offline_driver := teb_offline_driver
TEB_MODULES_run_teb_offline_block :=
OFFLINE_MODULES += teb_offline_host teb_offline_namelists teb_offline_surfaces teb_offline_output teb_offline_driver
BLOCK_MODULES :=
