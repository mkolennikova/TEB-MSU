# Makefile created by mkmf.pl $Id: mkmf,v 14.0 2007/03/20 22:13:27 fms Exp $ 

include gfortran_args
EXEC = TEB_offline.exe
OBJDIR = obj

# Ensure module files go to OBJDIR and include paths are set
ifeq ($(FC),ifort)
    FFLAGS += -module $(OBJDIR) -I. -Isrc_teb
else
    FFLAGS += -J$(OBJDIR) -I. -Isrc_teb
endif
$(shell mkdir -p $(OBJDIR))


.DEFAULT:
	-touch $@
all: $(EXEC)
$(OBJDIR)/abor1_sfx.o: src_driver/abor1_sfx.F90 $(OBJDIR)/close_file.o $(OBJDIR)/modd_surf_conf.o
$(OBJDIR)/add_forecast_to_date_surf.o: src_driver/add_forecast_to_date_surf.F90
$(OBJDIR)/ahf_traffic_now.o: src_driver/ahf_traffic_now.F90
$(OBJDIR)/alloc_teb_struct.o: src_struct/alloc_teb_struct.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_teb_irrign.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/avg_urban_fluxes.o: src_teb/avg_urban_fluxes.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_diag_misc_tebn.o $(OBJDIR)/modd_csts.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/hook.o
$(OBJDIR)/bem.o: src_teb/bem.F90 $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_diag_misc_tebn.o $(OBJDIR)/modd_csts.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/mode_psychro.o $(OBJDIR)/modi_dx_air_cooling_coil_cv.o $(OBJDIR)/modi_floor_layer_e_budget.o $(OBJDIR)/modi_mass_layer_e_budget.o $(OBJDIR)/mode_conv_DOE.o $(OBJDIR)/hook.o
$(OBJDIR)/bem_morpho.o: src_teb/bem_morpho.F90 $(OBJDIR)/modd_bemn.o
$(OBJDIR)/bem_morpho_struct.o: src_struct/bem_morpho_struct.F90 $(OBJDIR)/modi_bem_morpho.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_tebn.o
$(OBJDIR)/bld_e_budget.o: src_teb/bld_e_budget.F90 $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/hook.o
$(OBJDIR)/bld_occ_calendar.o: src_teb/bld_occ_calendar.F90 $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_type_date_surf.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modi_day_of_week.o $(OBJDIR)/hook.o
$(OBJDIR)/circumsolar_rad.o: src_solar/circumsolar_rad.F90 $(OBJDIR)/hook.o $(OBJDIR)/modd_csts.o
$(OBJDIR)/close_file.o: src_driver/close_file.F90
$(OBJDIR)/close_file_asc.o: src_driver/close_file_asc.F90
$(OBJDIR)/day_of_week.o: src_teb/day_of_week.F90 $(OBJDIR)/hook.o
$(OBJDIR)/dealloc_teb_struct.o: src_struct/dealloc_teb_struct.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_teb_irrign.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/call_driver.o: src_driver/call_driver.F90 $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_surf_atm.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_type_date_surf.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/modd_reprod_oper.o $(OBJDIR)/modi_init_surfconsphy.o $(OBJDIR)/sunpos.o $(OBJDIR)/ol_read_atm.o $(OBJDIR)/ol_alloc_atm.o $(OBJDIR)/ol_time_interp_atm.o $(OBJDIR)/modi_teb_garden_struct.o $(OBJDIR)/modi_window_data_struct.o $(OBJDIR)/modi_bem_morpho_struct.o $(OBJDIR)/circumsolar_rad.o $(OBJDIR)/modd_forc_atm.o $(OBJDIR)/wind_profile_wang.o $(OBJDIR)/modi_wind_threshold.o $(OBJDIR)/ahf_traffic_now.o
$(OBJDIR)/sfc_teb.o: src_driver/sfc_teb.F90 $(OBJDIR)/call_driver.o 
$(OBJDIR)/run_teb_offline.o: src_driver/run_teb_offline.F90 $(OBJDIR)/sfc_teb.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_proxi_svat_par.o $(OBJDIR)/modd_surf_atm.o $(OBJDIR)/ol_read_atm.o $(OBJDIR)/ol_alloc_atm.o $(OBJDIR)/ol_time_interp_atm.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modi_garden.o $(OBJDIR)/garden.o $(OBJDIR)/mode_thermos.o
$(OBJDIR)/dx_air_cooling_coil_cv.o: src_teb/dx_air_cooling_coil_cv.F90 $(OBJDIR)/mode_thermos.o $(OBJDIR)/mode_psychro.o $(OBJDIR)/modd_csts.o $(OBJDIR)/hook.o
$(OBJDIR)/facade_e_budget.o: src_teb/facade_e_budget.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_diag_misc_tebn.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modi_wall_layer_e_budget.o $(OBJDIR)/modi_window_e_budget.o $(OBJDIR)/hook.o
$(OBJDIR)/floor_layer_e_budget.o: src_teb/floor_layer_e_budget.F90 $(OBJDIR)/modd_bemn.o $(OBJDIR)/modi_layer_e_budget_get_coef.o $(OBJDIR)/modi_layer_e_budget.o $(OBJDIR)/mode_conv_DOE.o $(OBJDIR)/hook.o
$(OBJDIR)/flxsurf3bx.o: src_teb/flxsurf3bx.F
$(OBJDIR)/garden.o: src_proxi_SVAT/garden.F90 $(OBJDIR)/modd_csts.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/modi_garden.o
$(OBJDIR)/greenroof.o: src_proxi_SVAT/greenroof.F90 $(OBJDIR)/modd_csts.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/modd_type_date_surf.o
$(OBJDIR)/hook.o: src_teb/hook.F90
$(OBJDIR)/ini_csts.o: src_teb/ini_csts.F90 $(OBJDIR)/modd_csts.o $(OBJDIR)/hook.o
$(OBJDIR)/init_surfconsphy.o: src_teb/init_surfconsphy.F
$(OBJDIR)/layer_e_budget.o: src_teb/layer_e_budget.F90 $(OBJDIR)/modi_tridiag_ground.o $(OBJDIR)/hook.o
$(OBJDIR)/layer_e_budget_get_coef.o: src_teb/layer_e_budget_get_coef.F90 $(OBJDIR)/hook.o
$(OBJDIR)/mass_layer_e_budget.o: src_teb/mass_layer_e_budget.F90 $(OBJDIR)/modd_bemn.o $(OBJDIR)/modi_layer_e_budget_get_coef.o $(OBJDIR)/modi_layer_e_budget.o $(OBJDIR)/mode_conv_DOE.o $(OBJDIR)/hook.o
$(OBJDIR)/modd_arch.o: src_driver/modd_arch.F90
$(OBJDIR)/modd_bem_cst.o: src_teb/modd_bem_cst.F90
$(OBJDIR)/modd_bem_optionn.o: src_struct/modd_bem_optionn.F90 $(OBJDIR)/hook.o
$(OBJDIR)/modd_bemn.o: src_struct/modd_bemn.F90 $(OBJDIR)/hook.o
$(OBJDIR)/modd_csts.o: src_teb/modd_csts.F90
$(OBJDIR)/modd_proxi_svat_par.o: src_proxi_SVAT/modd_proxi_svat_par.F90
$(OBJDIR)/modd_diag_misc_tebn.o: src_struct/modd_diag_misc_tebn.F90 $(OBJDIR)/hook.o
$(OBJDIR)/modd_flood_par.o: src_teb/modd_flood_par.F90
$(OBJDIR)/modd_forc_atm.o: src_driver/modd_forc_atm.F90
$(OBJDIR)/modd_reprod_oper.o: src_driver/modd_reprod_oper.F90
$(OBJDIR)/modd_snow_par.o: src_teb/modd_snow_par.F90
$(OBJDIR)/modd_surf_atm.o: src_teb/modd_surf_atm.F90
$(OBJDIR)/modd_surf_conf.o: src_driver/modd_surf_conf.F90
$(OBJDIR)/modd_surf_par.o: src_teb/modd_surf_par.F90
$(OBJDIR)/modd_teb_irrign.o: src_struct/modd_teb_irrign.F90 $(OBJDIR)/hook.o
$(OBJDIR)/modd_teb_optionn.o: src_struct/modd_teb_optionn.F90 $(OBJDIR)/modd_type_date_surf.o $(OBJDIR)/hook.o
$(OBJDIR)/modd_teb_paneln.o: src_struct/modd_teb_paneln.F90 $(OBJDIR)/hook.o
$(OBJDIR)/modd_tebn.o: src_struct/modd_tebn.F90 $(OBJDIR)/modd_type_snow.o $(OBJDIR)/modd_type_date_surf.o $(OBJDIR)/hook.o
$(OBJDIR)/modd_type_date_surf.o: src_teb/modd_type_date_surf.F90
$(OBJDIR)/modd_type_snow.o: src_struct/modd_type_snow.F90
$(OBJDIR)/modd_water_par.o: src_teb/modd_water_par.F90
$(OBJDIR)/mode_char2real.o: src_driver/mode_char2real.F90 $(OBJDIR)/modd_arch.o
$(OBJDIR)/mode_conv_DOE.o: src_teb/mode_conv_DOE.F90 $(OBJDIR)/hook.o
$(OBJDIR)/mode_psychro.o: src_teb/mode_psychro.F90 $(OBJDIR)/hook.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/mode_thermos.o
$(OBJDIR)/mode_surf_snow_frac.o: src_teb/mode_surf_snow_frac.F90 $(OBJDIR)/hook.o $(OBJDIR)/modd_snow_par.o
$(OBJDIR)/mode_thermos.o: src_teb/mode_thermos.F90 $(OBJDIR)/hook.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_reprod_oper.o $(OBJDIR)/modd_surf_par.o
$(OBJDIR)/modi_alloc_teb_struct.o: src_struct/modi_alloc_teb_struct.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_teb_irrign.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/modi_avg_urban_fluxes.o: src_teb/modi_avg_urban_fluxes.f90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/modi_bem.o: src_teb/modi_bem.f90 $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/modi_bem_morpho.o: src_teb/modi_bem_morpho.f90 $(OBJDIR)/modd_bemn.o
$(OBJDIR)/modi_bem_morpho_struct.o: src_struct/modi_bem_morpho_struct.f90
$(OBJDIR)/modi_bld_e_budget.o: src_teb/modi_bld_e_budget.f90
$(OBJDIR)/modi_bld_occ_calendar.o: src_teb/modi_bld_occ_calendar.f90 $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_type_date_surf.o
$(OBJDIR)/modi_day_of_week.o: src_teb/modi_day_of_week.f90
$(OBJDIR)/modi_dealloc_teb_struct.o: src_struct/modi_dealloc_teb_struct.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_teb_irrign.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/modi_dx_air_cooling_coil_cv.o: src_teb/modi_dx_air_cooling_coil_cv.f90
$(OBJDIR)/modi_facade_e_budget.o: src_teb/modi_facade_e_budget.f90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/modi_floor_layer_e_budget.o: src_teb/modi_floor_layer_e_budget.f90 $(OBJDIR)/modd_bemn.o
$(OBJDIR)/modi_flxsurf3bx.o: src_teb/modi_flxsurf3bx.f
$(OBJDIR)/modi_garden.o: src_proxi_SVAT/modi_garden.F90
$(OBJDIR)/modi_greenroof.o: src_proxi_SVAT/modi_greenroof.F90 $(OBJDIR)/modd_type_date_surf.o
$(OBJDIR)/modi_ini_csts.o: src_teb/modi_ini_csts.f90
$(OBJDIR)/modi_init_surfconsphy.o: src_teb/modi_init_surfconsphy.f
$(OBJDIR)/modi_layer_e_budget.o: src_teb/modi_layer_e_budget.f90
$(OBJDIR)/modi_layer_e_budget_get_coef.o: src_teb/modi_layer_e_budget_get_coef.f90
$(OBJDIR)/modi_mass_layer_e_budget.o: src_teb/modi_mass_layer_e_budget.f90 $(OBJDIR)/modd_bemn.o
$(OBJDIR)/modi_road_layer_e_budget.o: src_teb/modi_road_layer_e_budget.f90 $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o
$(OBJDIR)/modi_roof_impl_coef.o: src_teb/modi_roof_impl_coef.f90 $(OBJDIR)/modd_tebn.o
$(OBJDIR)/modi_roof_layer_e_budget.o: src_teb/modi_roof_layer_e_budget.f90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o
$(OBJDIR)/modi_snow_cover_1layer.o: src_teb/modi_snow_cover_1layer.f90 $(OBJDIR)/modd_type_snow.o
$(OBJDIR)/modi_solar_panel.o: src_teb/modi_solar_panel.f90 $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/modi_surface_aero_cond.o: src_teb/modi_surface_aero_cond.f90
$(OBJDIR)/modi_surface_cd.o: src_teb/modi_surface_cd.f90
$(OBJDIR)/modi_surface_ri.o: src_teb/modi_surface_ri.f90
$(OBJDIR)/modi_teb.o: src_teb/modi_teb.f90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_irrign.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/modi_teb_garden.o: src_teb/modi_teb_garden.f90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_teb_irrign.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/modi_teb_garden_struct.o: src_struct/modi_teb_garden_struct.f90 $(OBJDIR)/modd_type_date_surf.o
$(OBJDIR)/modi_teb_irrig.o: src_teb/modi_teb_irrig.f90
$(OBJDIR)/modi_teb_veg_properties.o: src_proxi_SVAT/modi_teb_veg_properties.F90
$(OBJDIR)/modi_tridiag_ground.o: src_teb/modi_tridiag_ground.f90
$(OBJDIR)/modi_urban_drag.o: src_teb/modi_urban_drag.f90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o
$(OBJDIR)/modi_urban_exch_coef.o: src_teb/modi_urban_exch_coef.f90
$(OBJDIR)/modi_urban_fluxes.o: src_teb/modi_urban_fluxes.f90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/modi_urban_hydro.o: src_teb/modi_urban_hydro.f90
$(OBJDIR)/modi_urban_lw_coef.o: src_teb/modi_urban_lw_coef.f90 $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_tebn.o
$(OBJDIR)/modi_urban_snow_evol.o: src_teb/modi_urban_snow_evol.f90 $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o
$(OBJDIR)/modi_urban_solar_abs.o: src_teb/modi_urban_solar_abs.f90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_diag_misc_tebn.o
$(OBJDIR)/modi_wall_layer_e_budget.o: src_teb/modi_wall_layer_e_budget.f90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o
$(OBJDIR)/modi_wind_threshold.o: src_teb/modi_wind_threshold.f90
$(OBJDIR)/modi_window_data.o: src_teb/modi_window_data.f90 $(OBJDIR)/modd_bemn.o
$(OBJDIR)/modi_window_data_struct.o: src_struct/modi_window_data_struct.f90
$(OBJDIR)/modi_window_e_budget.o: src_teb/modi_window_e_budget.f90 $(OBJDIR)/modd_bemn.o
$(OBJDIR)/modi_window_shading.o: src_teb/modi_window_shading.f90
$(OBJDIR)/modi_window_shading_availability.o: src_teb/modi_window_shading_availability.f90
$(OBJDIR)/ol_alloc_atm.o: src_driver/ol_alloc_atm.F90 $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_forc_atm.o
$(OBJDIR)/ol_read_atm.o: src_driver/ol_read_atm.F90 $(OBJDIR)/ol_read_atm_ascii.o $(OBJDIR)/mode_thermos.o
$(OBJDIR)/ol_read_atm_ascii.o: src_driver/ol_read_atm_ascii.F90 $(OBJDIR)/read_surf_atm.o
$(OBJDIR)/ol_time_interp_atm.o: src_driver/ol_time_interp_atm.F90 $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_forc_atm.o
$(OBJDIR)/open_close_bin_asc_forc.o: src_driver/open_close_bin_asc_forc.F90
$(OBJDIR)/read_surf_atm.o: src_driver/read_surf_atm.F90
$(OBJDIR)/road_layer_e_budget.o: src_teb/road_layer_e_budget.F90 $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_csts.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/modi_layer_e_budget.o $(OBJDIR)/modi_layer_e_budget_get_coef.o $(OBJDIR)/hook.o
$(OBJDIR)/roof_impl_coef.o: src_teb/roof_impl_coef.F90 $(OBJDIR)/modd_tebn.o $(OBJDIR)/hook.o $(OBJDIR)/modi_layer_e_budget_get_coef.o
$(OBJDIR)/roof_layer_e_budget.o: src_teb/roof_layer_e_budget.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_csts.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/modi_layer_e_budget.o $(OBJDIR)/modi_layer_e_budget_get_coef.o $(OBJDIR)/mode_conv_DOE.o $(OBJDIR)/hook.o
$(OBJDIR)/snow_cover_1layer.o: src_teb/snow_cover_1layer.F90 $(OBJDIR)/modd_type_snow.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_snow_par.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/modi_surface_ri.o $(OBJDIR)/modi_surface_aero_cond.o $(OBJDIR)/hook.o
$(OBJDIR)/solar_panel.o: src_teb/solar_panel.F90 $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_diag_misc_tebn.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_csts.o $(OBJDIR)/hook.o
$(OBJDIR)/sunpos.o: src_solar/sunpos.F90 $(OBJDIR)/modd_csts.o
$(OBJDIR)/surface_aero_cond.o: src_teb/surface_aero_cond.F90 $(OBJDIR)/modd_csts.o $(OBJDIR)/modi_wind_threshold.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/hook.o
$(OBJDIR)/surface_cd.o: src_teb/surface_cd.F90 $(OBJDIR)/modd_csts.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/hook.o
$(OBJDIR)/surface_ri.o: src_teb/surface_ri.F90 $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_surf_atm.o $(OBJDIR)/modi_wind_threshold.o $(OBJDIR)/hook.o
$(OBJDIR)/teb.o: src_teb/teb.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_irrign.o $(OBJDIR)/modd_diag_misc_tebn.o $(OBJDIR)/modd_type_date_surf.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_snow_par.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/mode_surf_snow_frac.o $(OBJDIR)/modi_snow_cover_1layer.o $(OBJDIR)/modi_urban_drag.o $(OBJDIR)/modi_urban_snow_evol.o $(OBJDIR)/modi_roof_layer_e_budget.o $(OBJDIR)/modi_road_layer_e_budget.o $(OBJDIR)/modi_facade_e_budget.o $(OBJDIR)/modi_urban_fluxes.o $(OBJDIR)/modi_urban_hydro.o $(OBJDIR)/modi_bld_e_budget.o $(OBJDIR)/modi_wind_threshold.o $(OBJDIR)/modi_bem.o $(OBJDIR)/modi_teb_irrig.o $(OBJDIR)/hook.o
$(OBJDIR)/teb_garden.o: src_teb/teb_garden.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_teb_irrign.o $(OBJDIR)/modd_diag_misc_tebn.o $(OBJDIR)/modd_type_date_surf.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_snow_par.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/mode_surf_snow_frac.o $(OBJDIR)/modi_solar_panel.o $(OBJDIR)/modi_teb_veg_properties.o $(OBJDIR)/modi_window_shading_availability.o $(OBJDIR)/modi_urban_solar_abs.o $(OBJDIR)/modi_urban_lw_coef.o $(OBJDIR)/modi_garden.o $(OBJDIR)/modi_greenroof.o $(OBJDIR)/modi_teb.o $(OBJDIR)/modi_avg_urban_fluxes.o $(OBJDIR)/modi_bld_occ_calendar.o $(OBJDIR)/hook.o
$(OBJDIR)/teb_garden_struct.o: src_struct/teb_garden_struct.F90 $(OBJDIR)/modd_type_date_surf.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bem_optionn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_teb_paneln.o $(OBJDIR)/modd_teb_irrign.o $(OBJDIR)/modd_diag_misc_tebn.o $(OBJDIR)/modi_alloc_teb_struct.o $(OBJDIR)/modi_dealloc_teb_struct.o $(OBJDIR)/modi_teb_garden.o
$(OBJDIR)/teb_irrig.o: src_teb/teb_irrig.F90 $(OBJDIR)/hook.o
$(OBJDIR)/teb_veg_properties.o: src_proxi_SVAT/teb_veg_properties.F90
$(OBJDIR)/tridiag_ground.o: src_teb/tridiag_ground.F90 $(OBJDIR)/hook.o
$(OBJDIR)/urban_drag.o: src_teb/urban_drag.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_csts.o $(OBJDIR)/mode_thermos.o $(OBJDIR)/modi_urban_exch_coef.o $(OBJDIR)/mode_conv_DOE.o $(OBJDIR)/hook.o $(OBJDIR)/modi_wind_threshold.o $(OBJDIR)/garden.o
$(OBJDIR)/urban_exch_coef.o: src_teb/urban_exch_coef.F90 $(OBJDIR)/modi_surface_ri.o $(OBJDIR)/modi_surface_cd.o $(OBJDIR)/modi_surface_aero_cond.o $(OBJDIR)/modi_wind_threshold.o $(OBJDIR)/modd_csts.o $(OBJDIR)/hook.o $(OBJDIR)/modi_flxsurf3bx.o
$(OBJDIR)/urban_fluxes.o: src_teb/urban_fluxes.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_diag_misc_tebn.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_csts.o $(OBJDIR)/hook.o
$(OBJDIR)/urban_hydro.o: src_teb/urban_hydro.F90 $(OBJDIR)/modd_csts.o $(OBJDIR)/hook.o
$(OBJDIR)/urban_lw_coef.o: src_teb/urban_lw_coef.F90 $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/hook.o
$(OBJDIR)/urban_snow_evol.o: src_teb/urban_snow_evol.F90 $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_snow_par.o $(OBJDIR)/modd_csts.o $(OBJDIR)/mode_surf_snow_frac.o $(OBJDIR)/modi_roof_impl_coef.o $(OBJDIR)/modi_snow_cover_1layer.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/hook.o
$(OBJDIR)/urban_solar_abs.o: src_teb/urban_solar_abs.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_diag_misc_tebn.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modd_bem_cst.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modi_window_shading.o $(OBJDIR)/hook.o
$(OBJDIR)/vslog.o: src_teb/vslog.f
$(OBJDIR)/wall_layer_e_budget.o: src_teb/wall_layer_e_budget.F90 $(OBJDIR)/modd_teb_optionn.o $(OBJDIR)/modd_tebn.o $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_surf_par.o $(OBJDIR)/modd_csts.o $(OBJDIR)/modi_layer_e_budget_get_coef.o $(OBJDIR)/modi_layer_e_budget.o $(OBJDIR)/mode_conv_DOE.o $(OBJDIR)/hook.o
$(OBJDIR)/wind_threshold.o: src_teb/wind_threshold.F90 $(OBJDIR)/modd_surf_atm.o $(OBJDIR)/hook.o
$(OBJDIR)/wind_profile_wang.o: src_driver/wind_profile_wang.F90
$(OBJDIR)/window_data.o: src_teb/window_data.F90 $(OBJDIR)/modd_bemn.o $(OBJDIR)/hook.o
$(OBJDIR)/window_data_struct.o: src_struct/window_data_struct.F90 $(OBJDIR)/modi_window_data.o $(OBJDIR)/modd_bemn.o
$(OBJDIR)/window_e_budget.o: src_teb/window_e_budget.F90 $(OBJDIR)/modd_bemn.o $(OBJDIR)/modd_csts.o $(OBJDIR)/mode_conv_DOE.o $(OBJDIR)/hook.o
$(OBJDIR)/window_shading.o: src_teb/window_shading.F90 $(OBJDIR)/hook.o
$(OBJDIR)/window_shading_availability.o: src_teb/window_shading_availability.F90 $(OBJDIR)/modd_bem_cst.o
SRC = src_teb/snow_cover_1layer.F90 src_teb/modi_teb_garden.f90 src_driver/modd_reprod_oper.F90 src_teb/mode_surf_snow_frac.F90 src_teb/surface_ri.F90 src_teb/layer_e_budget_get_coef.F90 src_teb/modi_wall_layer_e_budget.f90 src_teb/modi_avg_urban_fluxes.f90 src_driver/close_file_asc.F90 src_struct/dealloc_teb_struct.F90 src_teb/modi_bem_morpho.f90 src_teb/modi_solar_panel.f90 src_teb/modi_ini_csts.f90 src_proxi_SVAT/modi_teb_veg_properties.F90 src_teb/road_layer_e_budget.F90 src_struct/modd_teb_paneln.F90 src_teb/modd_snow_par.F90 src_teb/modi_floor_layer_e_budget.f90 src_teb/solar_panel.F90 src_teb/modi_urban_hydro.f90 src_driver/ol_alloc_atm.F90 src_teb/modi_teb.f90 src_teb/floor_layer_e_budget.F90 src_teb/modi_urban_fluxes.f90 src_teb/modi_facade_e_budget.f90 src_teb/urban_snow_evol.F90 src_struct/modd_teb_irrign.F90 src_teb/window_e_budget.F90 src_teb/modi_bld_e_budget.f90 src_teb/roof_impl_coef.F90 src_teb/urban_exch_coef.F90 src_teb/modi_road_layer_e_budget.f90 src_driver/read_surf_atm.F90 src_driver/modd_forc_atm.F90 src_teb/modi_urban_snow_evol.f90 src_teb/modd_type_date_surf.F90 src_driver/modd_surf_conf.F90 src_teb/modi_roof_impl_coef.f90 src_teb/urban_solar_abs.F90 src_teb/teb_garden.F90 src_struct/alloc_teb_struct.F90 src_proxi_SVAT/teb_veg_properties.F90 src_driver/close_file.F90 src_teb/window_data.F90 src_solar/circumsolar_rad.F90 src_teb/window_shading_availability.F90 src_teb/dx_air_cooling_coil_cv.F90 src_teb/modi_mass_layer_e_budget.f90 src_teb/modi_urban_lw_coef.f90 src_struct/modi_teb_garden_struct.f90 src_teb/modi_dx_air_cooling_coil_cv.f90 src_teb/vslog.f src_struct/modd_bemn.F90 src_teb/urban_fluxes.F90 src_teb/modd_bem_cst.F90 src_teb/ini_csts.F90 src_teb/modi_window_shading_availability.f90 src_struct/bem_morpho_struct.F90 src_driver/mode_char2real.F90 src_driver/abor1_sfx.F90 src_teb/bem.F90 src_teb/urban_lw_coef.F90 src_driver/modd_arch.F90 src_teb/modd_csts.F90 src_teb/roof_layer_e_budget.F90 src_teb/hook.F90 src_teb/modi_window_shading.f90 src_teb/modi_window_data.f90 src_teb/wind_threshold.F90 src_driver/wind_profile_wang.F90 src_driver/ahf_traffic_now.f90 src_struct/modd_bem_optionn.F90 src_struct/modi_bem_morpho_struct.f90 src_struct/modi_alloc_teb_struct.F90 src_teb/mode_psychro.F90 src_proxi_SVAT/modi_greenroof.F90 src_teb/surface_aero_cond.F90 src_teb/day_of_week.F90 src_teb/flxsurf3bx.F src_teb/window_shading.F90 src_teb/modd_flood_par.F90 src_teb/teb_irrig.F90 src_teb/mass_layer_e_budget.F90 src_teb/avg_urban_fluxes.F90 src_teb/layer_e_budget.F90 src_struct/modd_teb_optionn.F90 src_teb/bem_morpho.F90 src_proxi_SVAT/garden.F90 src_struct/modi_dealloc_teb_struct.F90 src_driver/ol_read_atm.F90 src_teb/modi_day_of_week.f90 src_teb/modi_flxsurf3bx.f src_teb/modi_layer_e_budget_get_coef.f90 src_struct/modd_tebn.F90 src_teb/modi_init_surfconsphy.f src_struct/modd_type_snow.F90 src_driver/open_close_bin_asc_forc.F90 src_teb/wall_layer_e_budget.F90 src_teb/mode_conv_DOE.F90 src_teb/facade_e_budget.F90 src_teb/modd_water_par.F90 src_teb/modi_tridiag_ground.f90 src_struct/teb_garden_struct.F90 src_struct/window_data_struct.F90 src_teb/modd_surf_par.F90 src_teb/surface_cd.F90 src_teb/modi_surface_cd.f90 src_teb/modi_snow_cover_1layer.f90 src_driver/ol_time_interp_atm.F90 src_teb/teb.F90 src_teb/modi_urban_drag.f90 src_teb/modi_surface_ri.f90 src_solar/sunpos.F90 src_teb/modd_surf_atm.F90 src_teb/modi_bem.f90 src_teb/modi_window_e_budget.f90 src_teb/urban_drag.F90 src_driver/run_teb_offline.F90 src_driver/sfc_teb.F90 src_driver/call_driver.F90 src_teb/mode_thermos.F90 src_teb/modi_urban_solar_abs.f90 src_proxi_SVAT/greenroof.F90 src_teb/urban_hydro.F90 src_struct/modd_diag_misc_tebn.F90 src_teb/modi_bld_occ_calendar.f90 src_teb/modi_urban_exch_coef.f90 src_teb/tridiag_ground.F90 src_teb/modi_wind_threshold.f90 src_teb/modi_roof_layer_e_budget.f90 src_teb/init_surfconsphy.F src_struct/modi_window_data_struct.f90 src_teb/modi_surface_aero_cond.f90 src_teb/modi_layer_e_budget.f90 src_driver/add_forecast_to_date_surf.F90 src_teb/bld_occ_calendar.F90 src_teb/bld_e_budget.F90 src_proxi_SVAT/modi_garden.F90 src_driver/ol_read_atm_ascii.F90 src_teb/modi_teb_irrig.f90
OBJ = $(addprefix $(OBJDIR)/, snow_cover_1layer.o modi_teb_garden.o modd_reprod_oper.o mode_surf_snow_frac.o surface_ri.o layer_e_budget_get_coef.o modi_wall_layer_e_budget.o modi_avg_urban_fluxes.o close_file_asc.o dealloc_teb_struct.o modi_bem_morpho.o modi_solar_panel.o modi_ini_csts.o modi_teb_veg_properties.o road_layer_e_budget.o modd_teb_paneln.o modd_snow_par.o modi_floor_layer_e_budget.o solar_panel.o modi_urban_hydro.o ol_alloc_atm.o modi_teb.o floor_layer_e_budget.o modi_urban_fluxes.o modi_facade_e_budget.o urban_snow_evol.o modd_teb_irrign.o window_e_budget.o modi_bld_e_budget.o roof_impl_coef.o urban_exch_coef.o modi_road_layer_e_budget.o read_surf_atm.o modd_forc_atm.o modi_urban_snow_evol.o modd_type_date_surf.o modd_surf_conf.o modi_roof_impl_coef.o urban_solar_abs.o teb_garden.o alloc_teb_struct.o teb_veg_properties.o close_file.o window_data.o circumsolar_rad.o window_shading_availability.o dx_air_cooling_coil_cv.o modi_mass_layer_e_budget.o modi_urban_lw_coef.o modi_teb_garden_struct.o modi_dx_air_cooling_coil_cv.o vslog.o modd_bemn.o urban_fluxes.o modd_bem_cst.o ini_csts.o modi_window_shading_availability.o bem_morpho_struct.o mode_char2real.o abor1_sfx.o bem.o urban_lw_coef.o modd_arch.o modd_csts.o modd_proxi_svat_par.o roof_layer_e_budget.o hook.o modi_window_shading.o modi_window_data.o wind_threshold.o wind_profile_wang.o ahf_traffic_now.o modd_bem_optionn.o modi_bem_morpho_struct.o modi_alloc_teb_struct.o mode_psychro.o modi_greenroof.o surface_aero_cond.o day_of_week.o flxsurf3bx.o window_shading.o modd_flood_par.o teb_irrig.o mass_layer_e_budget.o avg_urban_fluxes.o layer_e_budget.o modd_teb_optionn.o bem_morpho.o garden.o modi_dealloc_teb_struct.o ol_read_atm.o modi_day_of_week.o modi_flxsurf3bx.o modi_layer_e_budget_get_coef.o modd_tebn.o modi_init_surfconsphy.o modd_type_snow.o open_close_bin_asc_forc.o wall_layer_e_budget.o mode_conv_DOE.o facade_e_budget.o modd_water_par.o modi_tridiag_ground.o teb_garden_struct.o window_data_struct.o modd_surf_par.o surface_cd.o modi_surface_cd.o modi_snow_cover_1layer.o ol_time_interp_atm.o teb.o modi_urban_drag.o modi_surface_ri.o sunpos.o modd_surf_atm.o modi_bem.o modi_window_e_budget.o urban_drag.o run_teb_offline.o sfc_teb.o call_driver.o mode_thermos.o modi_urban_solar_abs.o greenroof.o urban_hydro.o modd_diag_misc_tebn.o modi_bld_occ_calendar.o modi_urban_exch_coef.o tridiag_ground.o modi_wind_threshold.o modi_roof_layer_e_budget.o init_surfconsphy.o modi_window_data_struct.o modi_surface_aero_cond.o modi_layer_e_budget.o add_forecast_to_date_surf.o bld_occ_calendar.o bld_e_budget.o modi_garden.o ol_read_atm_ascii.o modi_teb_irrig.o)
clean: neat
	-rm -rf $(OBJDIR)
	-rm -f $(shell find . -name "*.mod" 2>/dev/null)
	-rm -f .cppdefs $(OBJ) *.obj $(EXEC) *.mod
neat:
	-rm -f $(TMPFILES)
TAGS: $(SRC)
	etags $(SRC)
tags: $(SRC)
	ctags $(SRC)
$(EXEC): $(OBJ) | $(OBJDIR)
	$(LD) $(OBJ) -o $(EXEC) $(LDFLAGS)

# ----- Generic rules for building into obj/ (fallback) -----
vpath %.F90 src_driver src_teb src_struct src_proxi_SVAT src_solar
vpath %.f90 src_driver src_teb src_struct src_proxi_SVAT src_solar
vpath %.F   src_teb
vpath %.f   src_teb

$(OBJDIR)/%.o: %.F90 | $(OBJDIR)
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.f90 | $(OBJDIR)
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.F | $(OBJDIR)
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.f | $(OBJDIR)
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c $< -o $@
