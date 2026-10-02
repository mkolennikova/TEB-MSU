# Makefile created by mkmf.pl $Id: mkmf,v 14.0 2007/03/20 22:13:27 fms Exp $ 

include gfortran_args


.DEFAULT:
	-touch $@
all: driver1.exe
abor1_sfx.o: src_driver/abor1_sfx.F90 close_file.o modd_surf_conf.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/abor1_sfx.F90
add_forecast_to_date_surf.o: src_driver/add_forecast_to_date_surf.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/add_forecast_to_date_surf.F90
ahf_traffic_now.o: src_driver/ahf_traffic_now.F90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/ahf_traffic_now.F90
alloc_teb_struct.o: src_struct/alloc_teb_struct.F90 modd_teb_optionn.o modd_tebn.o modd_bem_optionn.o modd_bemn.o modd_teb_paneln.o modd_teb_irrign.o modd_diag_misc_tebn.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/alloc_teb_struct.F90
avg_urban_fluxes.o: src_teb/avg_urban_fluxes.F90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_teb_paneln.o modd_diag_misc_tebn.o modd_csts.o mode_thermos.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/avg_urban_fluxes.F90
bem.o: src_teb/bem.F90 modd_bem_optionn.o modd_tebn.o modd_bemn.o modd_diag_misc_tebn.o modd_csts.o mode_thermos.o mode_psychro.o modi_dx_air_cooling_coil_cv.o modi_floor_layer_e_budget.o modi_mass_layer_e_budget.o mode_conv_DOE.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/bem.F90
bem_morpho.o: src_teb/bem_morpho.F90 modd_bemn.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/bem_morpho.F90
bem_morpho_struct.o: src_struct/bem_morpho_struct.F90 modi_bem_morpho.o modd_bemn.o modd_tebn.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/bem_morpho_struct.F90
bld_e_budget.o: src_teb/bld_e_budget.F90 modd_csts.o modd_surf_par.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/bld_e_budget.F90
bld_occ_calendar.o: src_teb/bld_occ_calendar.F90 modd_tebn.o modd_bemn.o modd_type_date_surf.o modd_csts.o modi_day_of_week.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/bld_occ_calendar.F90
circumsolar_rad.o: src_solar/circumsolar_rad.F90 hook.o modd_csts.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_solar/circumsolar_rad.F90
close_file.o: src_driver/close_file.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/close_file.F90
close_file_asc.o: src_driver/close_file_asc.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/close_file_asc.F90
day_of_week.o: src_teb/day_of_week.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/day_of_week.F90
dealloc_teb_struct.o: src_struct/dealloc_teb_struct.F90 modd_teb_optionn.o modd_tebn.o modd_bem_optionn.o modd_bemn.o modd_teb_paneln.o modd_teb_irrign.o modd_diag_misc_tebn.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/dealloc_teb_struct.F90
call_driver.o: src_driver/call_driver.F90 modd_csts.o modd_surf_atm.o modd_surf_par.o modd_type_date_surf.o mode_thermos.o modd_reprod_oper.o modi_init_surfconsphy.o sunpos.o ol_read_atm.o ol_alloc_atm.o ol_time_interp_atm.o modi_teb_garden_struct.o modi_window_data_struct.o modi_bem_morpho_struct.o circumsolar_rad.o modd_forc_atm.o wind_profile_wang.o modi_wind_threshold.o ahf_traffic_now.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/call_driver.F90
sfc_teb.o: src_driver/sfc_teb.F90 call_driver.o 
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/sfc_teb.F90
run_teb_offline.o: src_driver/run_teb_offline.F90 sfc_teb.o modd_csts.o modd_surf_atm.o ol_read_atm.o ol_alloc_atm.o ol_time_interp_atm.o modd_surf_par.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/run_teb_offline.F90
dx_air_cooling_coil_cv.o: src_teb/dx_air_cooling_coil_cv.F90 mode_thermos.o mode_psychro.o modd_csts.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/dx_air_cooling_coil_cv.F90
facade_e_budget.o: src_teb/facade_e_budget.F90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_diag_misc_tebn.o modd_surf_par.o modd_csts.o modi_wall_layer_e_budget.o modi_window_e_budget.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/facade_e_budget.F90
floor_layer_e_budget.o: src_teb/floor_layer_e_budget.F90 modd_bemn.o modi_layer_e_budget_get_coef.o modi_layer_e_budget.o mode_conv_DOE.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/floor_layer_e_budget.F90
flxsurf3bx.o: src_teb/flxsurf3bx.F
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/flxsurf3bx.F
garden.o: src_proxi_SVAT/garden.F90 modd_csts.o mode_thermos.o modd_type_date_surf.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_proxi_SVAT/garden.F90
greenroof.o: src_proxi_SVAT/greenroof.F90 modd_csts.o mode_thermos.o modd_type_date_surf.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_proxi_SVAT/greenroof.F90
hook.o: src_teb/hook.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/hook.F90
ini_csts.o: src_teb/ini_csts.F90 modd_csts.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/ini_csts.F90
init_surfconsphy.o: src_teb/init_surfconsphy.F
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/init_surfconsphy.F
layer_e_budget.o: src_teb/layer_e_budget.F90 modi_tridiag_ground.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/layer_e_budget.F90
layer_e_budget_get_coef.o: src_teb/layer_e_budget_get_coef.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/layer_e_budget_get_coef.F90
mass_layer_e_budget.o: src_teb/mass_layer_e_budget.F90 modd_bemn.o modi_layer_e_budget_get_coef.o modi_layer_e_budget.o mode_conv_DOE.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/mass_layer_e_budget.F90
modd_arch.o: src_driver/modd_arch.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/modd_arch.F90
modd_bem_cst.o: src_teb/modd_bem_cst.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modd_bem_cst.F90
modd_bem_optionn.o: src_struct/modd_bem_optionn.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modd_bem_optionn.F90
modd_bemn.o: src_struct/modd_bemn.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modd_bemn.F90
modd_csts.o: src_teb/modd_csts.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modd_csts.F90
modd_diag_misc_tebn.o: src_struct/modd_diag_misc_tebn.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modd_diag_misc_tebn.F90
modd_flood_par.o: src_teb/modd_flood_par.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modd_flood_par.F90
modd_forc_atm.o: src_driver/modd_forc_atm.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/modd_forc_atm.F90
modd_reprod_oper.o: src_driver/modd_reprod_oper.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/modd_reprod_oper.F90
modd_snow_par.o: src_teb/modd_snow_par.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modd_snow_par.F90
modd_surf_atm.o: src_teb/modd_surf_atm.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modd_surf_atm.F90
modd_surf_conf.o: src_driver/modd_surf_conf.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/modd_surf_conf.F90
modd_surf_par.o: src_teb/modd_surf_par.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modd_surf_par.F90
modd_teb_irrign.o: src_struct/modd_teb_irrign.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modd_teb_irrign.F90
modd_teb_optionn.o: src_struct/modd_teb_optionn.F90 modd_type_date_surf.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modd_teb_optionn.F90
modd_teb_paneln.o: src_struct/modd_teb_paneln.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modd_teb_paneln.F90
modd_tebn.o: src_struct/modd_tebn.F90 modd_type_snow.o modd_type_date_surf.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modd_tebn.F90
modd_type_date_surf.o: src_teb/modd_type_date_surf.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modd_type_date_surf.F90
modd_type_snow.o: src_struct/modd_type_snow.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modd_type_snow.F90
modd_water_par.o: src_teb/modd_water_par.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modd_water_par.F90
mode_char2real.o: src_driver/mode_char2real.F90 modd_arch.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/mode_char2real.F90
mode_conv_DOE.o: src_teb/mode_conv_DOE.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/mode_conv_DOE.F90
mode_psychro.o: src_teb/mode_psychro.F90 hook.o modd_csts.o modd_surf_par.o mode_thermos.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/mode_psychro.F90
mode_surf_snow_frac.o: src_teb/mode_surf_snow_frac.F90 hook.o modd_snow_par.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/mode_surf_snow_frac.F90
mode_thermos.o: src_teb/mode_thermos.F90 hook.o modd_csts.o modd_reprod_oper.o modd_surf_par.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/mode_thermos.F90
modi_alloc_teb_struct.o: src_struct/modi_alloc_teb_struct.F90 modd_teb_optionn.o modd_tebn.o modd_bem_optionn.o modd_bemn.o modd_teb_paneln.o modd_teb_irrign.o modd_diag_misc_tebn.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modi_alloc_teb_struct.F90
modi_avg_urban_fluxes.o: src_teb/modi_avg_urban_fluxes.f90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_teb_paneln.o modd_diag_misc_tebn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_avg_urban_fluxes.f90
modi_bem.o: src_teb/modi_bem.f90 modd_bem_optionn.o modd_tebn.o modd_bemn.o modd_diag_misc_tebn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_bem.f90
modi_bem_morpho.o: src_teb/modi_bem_morpho.f90 modd_bemn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_bem_morpho.f90
modi_bem_morpho_struct.o: src_struct/modi_bem_morpho_struct.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modi_bem_morpho_struct.f90
modi_bld_e_budget.o: src_teb/modi_bld_e_budget.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_bld_e_budget.f90
modi_bld_occ_calendar.o: src_teb/modi_bld_occ_calendar.f90 modd_tebn.o modd_bemn.o modd_type_date_surf.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_bld_occ_calendar.f90
modi_day_of_week.o: src_teb/modi_day_of_week.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_day_of_week.f90
modi_dealloc_teb_struct.o: src_struct/modi_dealloc_teb_struct.F90 modd_teb_optionn.o modd_tebn.o modd_bem_optionn.o modd_bemn.o modd_teb_paneln.o modd_teb_irrign.o modd_diag_misc_tebn.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modi_dealloc_teb_struct.F90
modi_dx_air_cooling_coil_cv.o: src_teb/modi_dx_air_cooling_coil_cv.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_dx_air_cooling_coil_cv.f90
modi_facade_e_budget.o: src_teb/modi_facade_e_budget.f90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_diag_misc_tebn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_facade_e_budget.f90
modi_floor_layer_e_budget.o: src_teb/modi_floor_layer_e_budget.f90 modd_bemn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_floor_layer_e_budget.f90
modi_flxsurf3bx.o: src_teb/modi_flxsurf3bx.f
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_flxsurf3bx.f
modi_garden.o: src_proxi_SVAT/modi_garden.F90 modd_type_date_surf.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_proxi_SVAT/modi_garden.F90
modi_greenroof.o: src_proxi_SVAT/modi_greenroof.F90 modd_type_date_surf.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_proxi_SVAT/modi_greenroof.F90
modi_ini_csts.o: src_teb/modi_ini_csts.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_ini_csts.f90
modi_init_surfconsphy.o: src_teb/modi_init_surfconsphy.f
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_init_surfconsphy.f
modi_layer_e_budget.o: src_teb/modi_layer_e_budget.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_layer_e_budget.f90
modi_layer_e_budget_get_coef.o: src_teb/modi_layer_e_budget_get_coef.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_layer_e_budget_get_coef.f90
modi_mass_layer_e_budget.o: src_teb/modi_mass_layer_e_budget.f90 modd_bemn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_mass_layer_e_budget.f90
modi_road_layer_e_budget.o: src_teb/modi_road_layer_e_budget.f90 modd_tebn.o modd_bemn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_road_layer_e_budget.f90
modi_roof_impl_coef.o: src_teb/modi_roof_impl_coef.f90 modd_tebn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_roof_impl_coef.f90
modi_roof_layer_e_budget.o: src_teb/modi_roof_layer_e_budget.f90 modd_teb_optionn.o modd_tebn.o modd_bemn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_roof_layer_e_budget.f90
modi_snow_cover_1layer.o: src_teb/modi_snow_cover_1layer.f90 modd_type_snow.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_snow_cover_1layer.f90
modi_solar_panel.o: src_teb/modi_solar_panel.f90 modd_teb_paneln.o modd_diag_misc_tebn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_solar_panel.f90
modi_surface_aero_cond.o: src_teb/modi_surface_aero_cond.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_surface_aero_cond.f90
modi_surface_cd.o: src_teb/modi_surface_cd.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_surface_cd.f90
modi_surface_ri.o: src_teb/modi_surface_ri.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_surface_ri.f90
modi_teb.o: src_teb/modi_teb.f90 modd_teb_optionn.o modd_tebn.o modd_bem_optionn.o modd_bemn.o modd_teb_irrign.o modd_diag_misc_tebn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_teb.f90
modi_teb_garden.o: src_teb/modi_teb_garden.f90 modd_teb_optionn.o modd_tebn.o modd_bem_optionn.o modd_bemn.o modd_teb_paneln.o modd_teb_irrign.o modd_diag_misc_tebn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_teb_garden.f90
modi_teb_garden_struct.o: src_struct/modi_teb_garden_struct.f90 modd_type_date_surf.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modi_teb_garden_struct.f90
modi_teb_irrig.o: src_teb/modi_teb_irrig.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_teb_irrig.f90
modi_teb_veg_properties.o: src_proxi_SVAT/modi_teb_veg_properties.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_proxi_SVAT/modi_teb_veg_properties.F90
modi_tridiag_ground.o: src_teb/modi_tridiag_ground.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_tridiag_ground.f90
modi_urban_drag.o: src_teb/modi_urban_drag.f90 modd_teb_optionn.o modd_tebn.o modd_bemn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_urban_drag.f90
modi_urban_exch_coef.o: src_teb/modi_urban_exch_coef.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_urban_exch_coef.f90
modi_urban_fluxes.o: src_teb/modi_urban_fluxes.f90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_diag_misc_tebn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_urban_fluxes.f90
modi_urban_hydro.o: src_teb/modi_urban_hydro.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_urban_hydro.f90
modi_urban_lw_coef.o: src_teb/modi_urban_lw_coef.f90 modd_bemn.o modd_tebn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_urban_lw_coef.f90
modi_urban_snow_evol.o: src_teb/modi_urban_snow_evol.f90 modd_tebn.o modd_bemn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_urban_snow_evol.f90
modi_urban_solar_abs.o: src_teb/modi_urban_solar_abs.f90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_diag_misc_tebn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_urban_solar_abs.f90
modi_wall_layer_e_budget.o: src_teb/modi_wall_layer_e_budget.f90 modd_teb_optionn.o modd_tebn.o modd_bemn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_wall_layer_e_budget.f90
modi_wind_threshold.o: src_teb/modi_wind_threshold.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_wind_threshold.f90
modi_window_data.o: src_teb/modi_window_data.f90 modd_bemn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_window_data.f90
modi_window_data_struct.o: src_struct/modi_window_data_struct.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/modi_window_data_struct.f90
modi_window_e_budget.o: src_teb/modi_window_e_budget.f90 modd_bemn.o
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_window_e_budget.f90
modi_window_shading.o: src_teb/modi_window_shading.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_window_shading.f90
modi_window_shading_availability.o: src_teb/modi_window_shading_availability.f90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/modi_window_shading_availability.f90
ol_alloc_atm.o: src_driver/ol_alloc_atm.F90 modd_surf_par.o modd_forc_atm.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/ol_alloc_atm.F90
ol_read_atm.o: src_driver/ol_read_atm.F90 ol_read_atm_ascii.o mode_thermos.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/ol_read_atm.F90
ol_read_atm_ascii.o: src_driver/ol_read_atm_ascii.F90 read_surf_atm.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/ol_read_atm_ascii.F90
ol_time_interp_atm.o: src_driver/ol_time_interp_atm.F90 modd_csts.o modd_surf_par.o modd_forc_atm.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/ol_time_interp_atm.F90
open_close_bin_asc_forc.o: src_driver/open_close_bin_asc_forc.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/open_close_bin_asc_forc.F90
read_surf_atm.o: src_driver/read_surf_atm.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/read_surf_atm.F90
road_layer_e_budget.o: src_teb/road_layer_e_budget.F90 modd_tebn.o modd_bemn.o modd_csts.o mode_thermos.o modi_layer_e_budget.o modi_layer_e_budget_get_coef.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/road_layer_e_budget.F90
roof_impl_coef.o: src_teb/roof_impl_coef.F90 modd_tebn.o hook.o modi_layer_e_budget_get_coef.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/roof_impl_coef.F90
roof_layer_e_budget.o: src_teb/roof_layer_e_budget.F90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_surf_par.o modd_csts.o mode_thermos.o modi_layer_e_budget.o modi_layer_e_budget_get_coef.o mode_conv_DOE.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/roof_layer_e_budget.F90
snow_cover_1layer.o: src_teb/snow_cover_1layer.F90 modd_type_snow.o modd_csts.o modd_snow_par.o modd_surf_par.o mode_thermos.o modi_surface_ri.o modi_surface_aero_cond.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/snow_cover_1layer.F90
solar_panel.o: src_teb/solar_panel.F90 modd_teb_paneln.o modd_diag_misc_tebn.o modd_surf_par.o modd_csts.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/solar_panel.F90
sunpos.o: src_solar/sunpos.F90 modd_csts.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_solar/sunpos.F90
surface_aero_cond.o: src_teb/surface_aero_cond.F90 modd_csts.o modi_wind_threshold.o mode_thermos.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/surface_aero_cond.F90
surface_cd.o: src_teb/surface_cd.F90 modd_csts.o mode_thermos.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/surface_cd.F90
surface_ri.o: src_teb/surface_ri.F90 modd_csts.o modd_surf_atm.o modi_wind_threshold.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/surface_ri.F90
teb.o: src_teb/teb.F90 modd_teb_optionn.o modd_tebn.o modd_bem_optionn.o modd_bemn.o modd_teb_irrign.o modd_diag_misc_tebn.o modd_type_date_surf.o modd_csts.o modd_surf_par.o modd_snow_par.o mode_thermos.o mode_surf_snow_frac.o modi_snow_cover_1layer.o modi_urban_drag.o modi_urban_snow_evol.o modi_roof_layer_e_budget.o modi_road_layer_e_budget.o modi_facade_e_budget.o modi_urban_fluxes.o modi_urban_hydro.o modi_bld_e_budget.o modi_wind_threshold.o modi_bem.o modi_teb_irrig.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/teb.F90
teb_garden.o: src_teb/teb_garden.F90 modd_teb_optionn.o modd_tebn.o modd_bem_optionn.o modd_bemn.o modd_teb_paneln.o modd_teb_irrign.o modd_diag_misc_tebn.o modd_type_date_surf.o modd_csts.o modd_surf_par.o modd_snow_par.o mode_thermos.o mode_surf_snow_frac.o modi_solar_panel.o modi_teb_veg_properties.o modi_window_shading_availability.o modi_urban_solar_abs.o modi_urban_lw_coef.o modi_garden.o modi_greenroof.o modi_teb.o modi_avg_urban_fluxes.o modi_bld_occ_calendar.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/teb_garden.F90
teb_garden_struct.o: src_struct/teb_garden_struct.F90 modd_type_date_surf.o modd_surf_par.o modd_teb_optionn.o modd_tebn.o modd_bem_optionn.o modd_bemn.o modd_teb_paneln.o modd_teb_irrign.o modd_diag_misc_tebn.o modi_alloc_teb_struct.o modi_dealloc_teb_struct.o modi_teb_garden.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/teb_garden_struct.F90
teb_irrig.o: src_teb/teb_irrig.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/teb_irrig.F90
teb_veg_properties.o: src_proxi_SVAT/teb_veg_properties.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_proxi_SVAT/teb_veg_properties.F90
tridiag_ground.o: src_teb/tridiag_ground.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/tridiag_ground.F90
urban_drag.o: src_teb/urban_drag.F90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_surf_par.o modd_csts.o mode_thermos.o modi_urban_exch_coef.o mode_conv_DOE.o hook.o modi_wind_threshold.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/urban_drag.F90
urban_exch_coef.o: src_teb/urban_exch_coef.F90 modi_surface_ri.o modi_surface_cd.o modi_surface_aero_cond.o modi_wind_threshold.o modd_csts.o hook.o modi_flxsurf3bx.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/urban_exch_coef.F90
urban_fluxes.o: src_teb/urban_fluxes.F90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_diag_misc_tebn.o modd_surf_par.o modd_csts.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/urban_fluxes.F90
urban_hydro.o: src_teb/urban_hydro.F90 modd_csts.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/urban_hydro.F90
urban_lw_coef.o: src_teb/urban_lw_coef.F90 modd_bemn.o modd_tebn.o modd_csts.o modd_surf_par.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/urban_lw_coef.F90
urban_snow_evol.o: src_teb/urban_snow_evol.F90 modd_tebn.o modd_bemn.o modd_snow_par.o modd_csts.o mode_surf_snow_frac.o modi_roof_impl_coef.o modi_snow_cover_1layer.o modd_surf_par.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/urban_snow_evol.F90
urban_solar_abs.o: src_teb/urban_solar_abs.F90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_diag_misc_tebn.o modd_csts.o modd_bem_cst.o modd_surf_par.o modi_window_shading.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/urban_solar_abs.F90
vslog.o: src_teb/vslog.f
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/vslog.f
wall_layer_e_budget.o: src_teb/wall_layer_e_budget.F90 modd_teb_optionn.o modd_tebn.o modd_bemn.o modd_surf_par.o modd_csts.o modi_layer_e_budget_get_coef.o modi_layer_e_budget.o mode_conv_DOE.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/wall_layer_e_budget.F90
wind_threshold.o: src_teb/wind_threshold.F90 modd_surf_atm.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/wind_threshold.F90
wind_profile_wang.o: src_driver/wind_profile_wang.F90
	$(FC) $(FFLAGS) $(OTHERFLAGS) -c	src_driver/wind_profile_wang.F90
window_data.o: src_teb/window_data.F90 modd_bemn.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/window_data.F90
window_data_struct.o: src_struct/window_data_struct.F90 modi_window_data.o modd_bemn.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_struct/window_data_struct.F90
window_e_budget.o: src_teb/window_e_budget.F90 modd_bemn.o modd_csts.o mode_conv_DOE.o hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/window_e_budget.F90
window_shading.o: src_teb/window_shading.F90 hook.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/window_shading.F90
window_shading_availability.o: src_teb/window_shading_availability.F90 modd_bem_cst.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c	src_teb/window_shading_availability.F90
./wind_threshold.F90: src_teb/wind_threshold.F90
	cp src_teb/wind_threshold.F90 .
./wind_profile_wang.F90: src_driver/wind_profile_wang.F90
	cp src_driver/wind_profile_wang.F90 .
./ahf_traffic_now.F90: src_driver/ahf_traffic_now.F90
	cp src_driver/ahf_traffic_now.F90 .
./modi_window_shading_availability.f90: src_teb/modi_window_shading_availability.f90
	cp src_teb/modi_window_shading_availability.f90 .
./urban_fluxes.F90: src_teb/urban_fluxes.F90
	cp src_teb/urban_fluxes.F90 .
./window_e_budget.F90: src_teb/window_e_budget.F90
	cp src_teb/window_e_budget.F90 .
./modi_dealloc_teb_struct.F90: src_struct/modi_dealloc_teb_struct.F90
	cp src_struct/modi_dealloc_teb_struct.F90 .
./urban_lw_coef.F90: src_teb/urban_lw_coef.F90
	cp src_teb/urban_lw_coef.F90 .
./modd_teb_paneln.F90: src_struct/modd_teb_paneln.F90
	cp src_struct/modd_teb_paneln.F90 .
./close_file_asc.F90: src_driver/close_file_asc.F90
	cp src_driver/close_file_asc.F90 .
./modi_layer_e_budget.f90: src_teb/modi_layer_e_budget.f90
	cp src_teb/modi_layer_e_budget.f90 .
./modi_bld_e_budget.f90: src_teb/modi_bld_e_budget.f90
	cp src_teb/modi_bld_e_budget.f90 .
./modi_teb_garden.f90: src_teb/modi_teb_garden.f90
	cp src_teb/modi_teb_garden.f90 .
./vslog.f: src_teb/vslog.f
	cp src_teb/vslog.f .
./surface_cd.F90: src_teb/surface_cd.F90
	cp src_teb/surface_cd.F90 .
./ol_time_interp_atm.F90: src_driver/ol_time_interp_atm.F90
	cp src_driver/ol_time_interp_atm.F90 .
./call_driver.F90: src_driver/call_driver.F90
	cp src_driver/call_driver.F90 .
./sfc_teb.F90: src_driver/sfc_teb.F90
	cp src_driver/sfc_teb.F90 .
./run_teb_offline.F90: src_driver/run_teb_offline.F90
	cp src_driver/run_teb_offline.F90 .
./modi_mass_layer_e_budget.f90: src_teb/modi_mass_layer_e_budget.f90
	cp src_teb/modi_mass_layer_e_budget.f90 .
./bem_morpho.F90: src_teb/bem_morpho.F90
	cp src_teb/bem_morpho.F90 .
./flxsurf3bx.F: src_teb/flxsurf3bx.F
	cp src_teb/flxsurf3bx.F .
./surface_ri.F90: src_teb/surface_ri.F90
	cp src_teb/surface_ri.F90 .
./window_shading_availability.F90: src_teb/window_shading_availability.F90
	cp src_teb/window_shading_availability.F90 .
./modd_flood_par.F90: src_teb/modd_flood_par.F90
	cp src_teb/modd_flood_par.F90 .
./modd_diag_misc_tebn.F90: src_struct/modd_diag_misc_tebn.F90
	cp src_struct/modd_diag_misc_tebn.F90 .
./modi_day_of_week.f90: src_teb/modi_day_of_week.f90
	cp src_teb/modi_day_of_week.f90 .
./teb_irrig.F90: src_teb/teb_irrig.F90
	cp src_teb/teb_irrig.F90 .
./mode_surf_snow_frac.F90: src_teb/mode_surf_snow_frac.F90
	cp src_teb/mode_surf_snow_frac.F90 .
./abor1_sfx.F90: src_driver/abor1_sfx.F90
	cp src_driver/abor1_sfx.F90 .
./modi_init_surfconsphy.f: src_teb/modi_init_surfconsphy.f
	cp src_teb/modi_init_surfconsphy.f .
./add_forecast_to_date_surf.F90: src_driver/add_forecast_to_date_surf.F90
	cp src_driver/add_forecast_to_date_surf.F90 .
./sunpos.F90: src_solar/sunpos.F90
	cp src_solar/sunpos.F90 .
./garden.F90: src_proxi_SVAT/garden.F90
	cp src_proxi_SVAT/garden.F90 .
./modd_teb_optionn.F90: src_struct/modd_teb_optionn.F90
	cp src_struct/modd_teb_optionn.F90 .
./window_data.F90: src_teb/window_data.F90
	cp src_teb/window_data.F90 .
./surface_aero_cond.F90: src_teb/surface_aero_cond.F90
	cp src_teb/surface_aero_cond.F90 .
./modi_tridiag_ground.f90: src_teb/modi_tridiag_ground.f90
	cp src_teb/modi_tridiag_ground.f90 .
./modd_surf_conf.F90: src_driver/modd_surf_conf.F90
	cp src_driver/modd_surf_conf.F90 .
./init_surfconsphy.F: src_teb/init_surfconsphy.F
	cp src_teb/init_surfconsphy.F .
./modi_surface_ri.f90: src_teb/modi_surface_ri.f90
	cp src_teb/modi_surface_ri.f90 .
./urban_hydro.F90: src_teb/urban_hydro.F90
	cp src_teb/urban_hydro.F90 .
./teb.F90: src_teb/teb.F90
	cp src_teb/teb.F90 .
./modd_type_snow.F90: src_struct/modd_type_snow.F90
	cp src_struct/modd_type_snow.F90 .
./tridiag_ground.F90: src_teb/tridiag_ground.F90
	cp src_teb/tridiag_ground.F90 .
./modi_urban_hydro.f90: src_teb/modi_urban_hydro.f90
	cp src_teb/modi_urban_hydro.f90 .
./modi_wall_layer_e_budget.f90: src_teb/modi_wall_layer_e_budget.f90
	cp src_teb/modi_wall_layer_e_budget.f90 .
./day_of_week.F90: src_teb/day_of_week.F90
	cp src_teb/day_of_week.F90 .
./avg_urban_fluxes.F90: src_teb/avg_urban_fluxes.F90
	cp src_teb/avg_urban_fluxes.F90 .
./mode_char2real.F90: src_driver/mode_char2real.F90
	cp src_driver/mode_char2real.F90 .
./modi_layer_e_budget_get_coef.f90: src_teb/modi_layer_e_budget_get_coef.f90
	cp src_teb/modi_layer_e_budget_get_coef.f90 .
./urban_exch_coef.F90: src_teb/urban_exch_coef.F90
	cp src_teb/urban_exch_coef.F90 .
./modi_teb_veg_properties.F90: src_proxi_SVAT/modi_teb_veg_properties.F90
	cp src_proxi_SVAT/modi_teb_veg_properties.F90 .
./modi_road_layer_e_budget.f90: src_teb/modi_road_layer_e_budget.f90
	cp src_teb/modi_road_layer_e_budget.f90 .
./floor_layer_e_budget.F90: src_teb/floor_layer_e_budget.F90
	cp src_teb/floor_layer_e_budget.F90 .
./modi_urban_exch_coef.f90: src_teb/modi_urban_exch_coef.f90
	cp src_teb/modi_urban_exch_coef.f90 .
./ol_alloc_atm.F90: src_driver/ol_alloc_atm.F90
	cp src_driver/ol_alloc_atm.F90 .
./bld_e_budget.F90: src_teb/bld_e_budget.F90
	cp src_teb/bld_e_budget.F90 .
./modi_roof_layer_e_budget.f90: src_teb/modi_roof_layer_e_budget.f90
	cp src_teb/modi_roof_layer_e_budget.f90 .
./modi_bem_morpho.f90: src_teb/modi_bem_morpho.f90
	cp src_teb/modi_bem_morpho.f90 .
./ol_read_atm.F90: src_driver/ol_read_atm.F90
	cp src_driver/ol_read_atm.F90 .
./modi_wind_threshold.f90: src_teb/modi_wind_threshold.f90
	cp src_teb/modi_wind_threshold.f90 .
./mode_psychro.F90: src_teb/mode_psychro.F90
	cp src_teb/mode_psychro.F90 .
./layer_e_budget.F90: src_teb/layer_e_budget.F90
	cp src_teb/layer_e_budget.F90 .
./modd_surf_atm.F90: src_teb/modd_surf_atm.F90
	cp src_teb/modd_surf_atm.F90 .
./window_shading.F90: src_teb/window_shading.F90
	cp src_teb/window_shading.F90 .
./modd_csts.F90: src_teb/modd_csts.F90
	cp src_teb/modd_csts.F90 .
./modi_urban_solar_abs.f90: src_teb/modi_urban_solar_abs.f90
	cp src_teb/modi_urban_solar_abs.f90 .
./modd_type_date_surf.F90: src_teb/modd_type_date_surf.F90
	cp src_teb/modd_type_date_surf.F90 .
./roof_impl_coef.F90: src_teb/roof_impl_coef.F90
	cp src_teb/roof_impl_coef.F90 .
./modd_water_par.F90: src_teb/modd_water_par.F90
	cp src_teb/modd_water_par.F90 .
./modi_roof_impl_coef.f90: src_teb/modi_roof_impl_coef.f90
	cp src_teb/modi_roof_impl_coef.f90 .
./road_layer_e_budget.F90: src_teb/road_layer_e_budget.F90
	cp src_teb/road_layer_e_budget.F90 .
./modi_bem.f90: src_teb/modi_bem.f90
	cp src_teb/modi_bem.f90 .
./modd_snow_par.F90: src_teb/modd_snow_par.F90
	cp src_teb/modd_snow_par.F90 .
./alloc_teb_struct.F90: src_struct/alloc_teb_struct.F90
	cp src_struct/alloc_teb_struct.F90 .
./facade_e_budget.F90: src_teb/facade_e_budget.F90
	cp src_teb/facade_e_budget.F90 .
./modi_window_shading.f90: src_teb/modi_window_shading.f90
	cp src_teb/modi_window_shading.f90 .
./dealloc_teb_struct.F90: src_struct/dealloc_teb_struct.F90
	cp src_struct/dealloc_teb_struct.F90 .
./modi_alloc_teb_struct.F90: src_struct/modi_alloc_teb_struct.F90
	cp src_struct/modi_alloc_teb_struct.F90 .
./modi_teb.f90: src_teb/modi_teb.f90
	cp src_teb/modi_teb.f90 .
./window_data_struct.F90: src_struct/window_data_struct.F90
	cp src_struct/window_data_struct.F90 .
./modi_solar_panel.f90: src_teb/modi_solar_panel.f90
	cp src_teb/modi_solar_panel.f90 .
./modd_bem_optionn.F90: src_struct/modd_bem_optionn.F90
	cp src_struct/modd_bem_optionn.F90 .
./modd_reprod_oper.F90: src_driver/modd_reprod_oper.F90
	cp src_driver/modd_reprod_oper.F90 .
./teb_garden_struct.F90: src_struct/teb_garden_struct.F90
	cp src_struct/teb_garden_struct.F90 .
./bld_occ_calendar.F90: src_teb/bld_occ_calendar.F90
	cp src_teb/bld_occ_calendar.F90 .
./mode_thermos.F90: src_teb/mode_thermos.F90
	cp src_teb/mode_thermos.F90 .
./urban_drag.F90: src_teb/urban_drag.F90
	cp src_teb/urban_drag.F90 .
./urban_snow_evol.F90: src_teb/urban_snow_evol.F90
	cp src_teb/urban_snow_evol.F90 .
./modi_facade_e_budget.f90: src_teb/modi_facade_e_budget.f90
	cp src_teb/modi_facade_e_budget.f90 .
./modd_teb_irrign.F90: src_struct/modd_teb_irrign.F90
	cp src_struct/modd_teb_irrign.F90 .
./ol_read_atm_ascii.F90: src_driver/ol_read_atm_ascii.F90
	cp src_driver/ol_read_atm_ascii.F90 .
./hook.F90: src_teb/hook.F90
	cp src_teb/hook.F90 .
./open_close_bin_asc_forc.F90: src_driver/open_close_bin_asc_forc.F90
	cp src_driver/open_close_bin_asc_forc.F90 .
./modi_ini_csts.f90: src_teb/modi_ini_csts.f90
	cp src_teb/modi_ini_csts.f90 .
./read_surf_atm.F90: src_driver/read_surf_atm.F90
	cp src_driver/read_surf_atm.F90 .
./modi_urban_snow_evol.f90: src_teb/modi_urban_snow_evol.f90
	cp src_teb/modi_urban_snow_evol.f90 .
./modi_surface_cd.f90: src_teb/modi_surface_cd.f90
	cp src_teb/modi_surface_cd.f90 .
./modi_teb_irrig.f90: src_teb/modi_teb_irrig.f90
	cp src_teb/modi_teb_irrig.f90 .
./modd_tebn.F90: src_struct/modd_tebn.F90
	cp src_struct/modd_tebn.F90 .
./mass_layer_e_budget.F90: src_teb/mass_layer_e_budget.F90
	cp src_teb/mass_layer_e_budget.F90 .
./ini_csts.F90: src_teb/ini_csts.F90
	cp src_teb/ini_csts.F90 .
./snow_cover_1layer.F90: src_teb/snow_cover_1layer.F90
	cp src_teb/snow_cover_1layer.F90 .
./modd_bemn.F90: src_struct/modd_bemn.F90
	cp src_struct/modd_bemn.F90 .
./teb_veg_properties.F90: src_proxi_SVAT/teb_veg_properties.F90
	cp src_proxi_SVAT/teb_veg_properties.F90 .
./modi_flxsurf3bx.f: src_teb/modi_flxsurf3bx.f
	cp src_teb/modi_flxsurf3bx.f .
./modi_urban_drag.f90: src_teb/modi_urban_drag.f90
	cp src_teb/modi_urban_drag.f90 .
./modd_bem_cst.F90: src_teb/modd_bem_cst.F90
	cp src_teb/modd_bem_cst.F90 .
./solar_panel.F90: src_teb/solar_panel.F90
	cp src_teb/solar_panel.F90 .
./modi_snow_cover_1layer.f90: src_teb/modi_snow_cover_1layer.f90
	cp src_teb/modi_snow_cover_1layer.f90 .
./roof_layer_e_budget.F90: src_teb/roof_layer_e_budget.F90
	cp src_teb/roof_layer_e_budget.F90 .
./modi_garden.F90: src_proxi_SVAT/modi_garden.F90
	cp src_proxi_SVAT/modi_garden.F90 .
./modd_forc_atm.F90: src_driver/modd_forc_atm.F90
	cp src_driver/modd_forc_atm.F90 .
./urban_solar_abs.F90: src_teb/urban_solar_abs.F90
	cp src_teb/urban_solar_abs.F90 .
./teb_garden.F90: src_teb/teb_garden.F90
	cp src_teb/teb_garden.F90 .
./bem.F90: src_teb/bem.F90
	cp src_teb/bem.F90 .
./layer_e_budget_get_coef.F90: src_teb/layer_e_budget_get_coef.F90
	cp src_teb/layer_e_budget_get_coef.F90 .
./modd_surf_par.F90: src_teb/modd_surf_par.F90
	cp src_teb/modd_surf_par.F90 .
./modi_window_data_struct.f90: src_struct/modi_window_data_struct.f90
	cp src_struct/modi_window_data_struct.f90 .
./greenroof.F90: src_proxi_SVAT/greenroof.F90
	cp src_proxi_SVAT/greenroof.F90 .
./mode_conv_DOE.F90: src_teb/mode_conv_DOE.F90
	cp src_teb/mode_conv_DOE.F90 .
./modi_window_e_budget.f90: src_teb/modi_window_e_budget.f90
	cp src_teb/modi_window_e_budget.f90 .
./bem_morpho_struct.F90: src_struct/bem_morpho_struct.F90
	cp src_struct/bem_morpho_struct.F90 .
./modi_urban_fluxes.f90: src_teb/modi_urban_fluxes.f90
	cp src_teb/modi_urban_fluxes.f90 .
./close_file.F90: src_driver/close_file.F90
	cp src_driver/close_file.F90 .
./modi_bld_occ_calendar.f90: src_teb/modi_bld_occ_calendar.f90
	cp src_teb/modi_bld_occ_calendar.f90 .
./modi_teb_garden_struct.f90: src_struct/modi_teb_garden_struct.f90
	cp src_struct/modi_teb_garden_struct.f90 .
./modi_floor_layer_e_budget.f90: src_teb/modi_floor_layer_e_budget.f90
	cp src_teb/modi_floor_layer_e_budget.f90 .
./modd_arch.F90: src_driver/modd_arch.F90
	cp src_driver/modd_arch.F90 .
./circumsolar_rad.F90: src_solar/circumsolar_rad.F90
	cp src_solar/circumsolar_rad.F90 .
./dx_air_cooling_coil_cv.F90: src_teb/dx_air_cooling_coil_cv.F90
	cp src_teb/dx_air_cooling_coil_cv.F90 .
./wall_layer_e_budget.F90: src_teb/wall_layer_e_budget.F90
	cp src_teb/wall_layer_e_budget.F90 .
./modi_urban_lw_coef.f90: src_teb/modi_urban_lw_coef.f90
	cp src_teb/modi_urban_lw_coef.f90 .
./modi_window_data.f90: src_teb/modi_window_data.f90
	cp src_teb/modi_window_data.f90 .
./modi_dx_air_cooling_coil_cv.f90: src_teb/modi_dx_air_cooling_coil_cv.f90
	cp src_teb/modi_dx_air_cooling_coil_cv.f90 .
./modi_greenroof.F90: src_proxi_SVAT/modi_greenroof.F90
	cp src_proxi_SVAT/modi_greenroof.F90 .
./modi_bem_morpho_struct.f90: src_struct/modi_bem_morpho_struct.f90
	cp src_struct/modi_bem_morpho_struct.f90 .
./modi_surface_aero_cond.f90: src_teb/modi_surface_aero_cond.f90
	cp src_teb/modi_surface_aero_cond.f90 .
./modi_avg_urban_fluxes.f90: src_teb/modi_avg_urban_fluxes.f90
	cp src_teb/modi_avg_urban_fluxes.f90 .
SRC = src_teb/snow_cover_1layer.F90 src_teb/modi_teb_garden.f90 src_driver/modd_reprod_oper.F90 src_teb/mode_surf_snow_frac.F90 src_teb/surface_ri.F90 src_teb/layer_e_budget_get_coef.F90 src_teb/modi_wall_layer_e_budget.f90 src_teb/modi_avg_urban_fluxes.f90 src_driver/close_file_asc.F90 src_struct/dealloc_teb_struct.F90 src_teb/modi_bem_morpho.f90 src_teb/modi_solar_panel.f90 src_teb/modi_ini_csts.f90 src_proxi_SVAT/modi_teb_veg_properties.F90 src_teb/road_layer_e_budget.F90 src_struct/modd_teb_paneln.F90 src_teb/modd_snow_par.F90 src_teb/modi_floor_layer_e_budget.f90 src_teb/solar_panel.F90 src_teb/modi_urban_hydro.f90 src_driver/ol_alloc_atm.F90 src_teb/modi_teb.f90 src_teb/floor_layer_e_budget.F90 src_teb/modi_urban_fluxes.f90 src_teb/modi_facade_e_budget.f90 src_teb/urban_snow_evol.F90 src_struct/modd_teb_irrign.F90 src_teb/window_e_budget.F90 src_teb/modi_bld_e_budget.f90 src_teb/roof_impl_coef.F90 src_teb/urban_exch_coef.F90 src_teb/modi_road_layer_e_budget.f90 src_driver/read_surf_atm.F90 src_driver/modd_forc_atm.F90 src_teb/modi_urban_snow_evol.f90 src_teb/modd_type_date_surf.F90 src_driver/modd_surf_conf.F90 src_teb/modi_roof_impl_coef.f90 src_teb/urban_solar_abs.F90 src_teb/teb_garden.F90 src_struct/alloc_teb_struct.F90 src_proxi_SVAT/teb_veg_properties.F90 src_driver/close_file.F90 src_teb/window_data.F90 src_solar/circumsolar_rad.F90 src_teb/window_shading_availability.F90 src_teb/dx_air_cooling_coil_cv.F90 src_teb/modi_mass_layer_e_budget.f90 src_teb/modi_urban_lw_coef.f90 src_struct/modi_teb_garden_struct.f90 src_teb/modi_dx_air_cooling_coil_cv.f90 src_teb/vslog.f src_struct/modd_bemn.F90 src_teb/urban_fluxes.F90 src_teb/modd_bem_cst.F90 src_teb/ini_csts.F90 src_teb/modi_window_shading_availability.f90 src_struct/bem_morpho_struct.F90 src_driver/mode_char2real.F90 src_driver/abor1_sfx.F90 src_teb/bem.F90 src_teb/urban_lw_coef.F90 src_driver/modd_arch.F90 src_teb/modd_csts.F90 src_teb/roof_layer_e_budget.F90 src_teb/hook.F90 src_teb/modi_window_shading.f90 src_teb/modi_window_data.f90 src_teb/wind_threshold.F90 src_driver/wind_profile_wang.F90 src_driver/ahf_traffic_now.f90 src_struct/modd_bem_optionn.F90 src_struct/modi_bem_morpho_struct.f90 src_struct/modi_alloc_teb_struct.F90 src_teb/mode_psychro.F90 src_proxi_SVAT/modi_greenroof.F90 src_teb/surface_aero_cond.F90 src_teb/day_of_week.F90 src_teb/flxsurf3bx.F src_teb/window_shading.F90 src_teb/modd_flood_par.F90 src_teb/teb_irrig.F90 src_teb/mass_layer_e_budget.F90 src_teb/avg_urban_fluxes.F90 src_teb/layer_e_budget.F90 src_struct/modd_teb_optionn.F90 src_teb/bem_morpho.F90 src_proxi_SVAT/garden.F90 src_struct/modi_dealloc_teb_struct.F90 src_driver/ol_read_atm.F90 src_teb/modi_day_of_week.f90 src_teb/modi_flxsurf3bx.f src_teb/modi_layer_e_budget_get_coef.f90 src_struct/modd_tebn.F90 src_teb/modi_init_surfconsphy.f src_struct/modd_type_snow.F90 src_driver/open_close_bin_asc_forc.F90 src_teb/wall_layer_e_budget.F90 src_teb/mode_conv_DOE.F90 src_teb/facade_e_budget.F90 src_teb/modd_water_par.F90 src_teb/modi_tridiag_ground.f90 src_struct/teb_garden_struct.F90 src_struct/window_data_struct.F90 src_teb/modd_surf_par.F90 src_teb/surface_cd.F90 src_teb/modi_surface_cd.f90 src_teb/modi_snow_cover_1layer.f90 src_driver/ol_time_interp_atm.F90 src_teb/teb.F90 src_teb/modi_urban_drag.f90 src_teb/modi_surface_ri.f90 src_solar/sunpos.F90 src_teb/modd_surf_atm.F90 src_teb/modi_bem.f90 src_teb/modi_window_e_budget.f90 src_teb/urban_drag.F90 src_driver/run_teb_offline.F90 src_driver/sfc_teb.F90 src_driver/call_driver.F90 src_teb/mode_thermos.F90 src_teb/modi_urban_solar_abs.f90 src_proxi_SVAT/greenroof.F90 src_teb/urban_hydro.F90 src_struct/modd_diag_misc_tebn.F90 src_teb/modi_bld_occ_calendar.f90 src_teb/modi_urban_exch_coef.f90 src_teb/tridiag_ground.F90 src_teb/modi_wind_threshold.f90 src_teb/modi_roof_layer_e_budget.f90 src_teb/init_surfconsphy.F src_struct/modi_window_data_struct.f90 src_teb/modi_surface_aero_cond.f90 src_teb/modi_layer_e_budget.f90 src_driver/add_forecast_to_date_surf.F90 src_teb/bld_occ_calendar.F90 src_teb/bld_e_budget.F90 src_proxi_SVAT/modi_garden.F90 src_driver/ol_read_atm_ascii.F90 src_teb/modi_teb_irrig.f90
OBJ = snow_cover_1layer.o modi_teb_garden.o modd_reprod_oper.o mode_surf_snow_frac.o surface_ri.o layer_e_budget_get_coef.o modi_wall_layer_e_budget.o modi_avg_urban_fluxes.o close_file_asc.o dealloc_teb_struct.o modi_bem_morpho.o modi_solar_panel.o modi_ini_csts.o modi_teb_veg_properties.o road_layer_e_budget.o modd_teb_paneln.o modd_snow_par.o modi_floor_layer_e_budget.o solar_panel.o modi_urban_hydro.o ol_alloc_atm.o modi_teb.o floor_layer_e_budget.o modi_urban_fluxes.o modi_facade_e_budget.o urban_snow_evol.o modd_teb_irrign.o window_e_budget.o modi_bld_e_budget.o roof_impl_coef.o urban_exch_coef.o modi_road_layer_e_budget.o read_surf_atm.o modd_forc_atm.o modi_urban_snow_evol.o modd_type_date_surf.o modd_surf_conf.o modi_roof_impl_coef.o urban_solar_abs.o teb_garden.o alloc_teb_struct.o teb_veg_properties.o close_file.o window_data.o circumsolar_rad.o window_shading_availability.o dx_air_cooling_coil_cv.o modi_mass_layer_e_budget.o modi_urban_lw_coef.o modi_teb_garden_struct.o modi_dx_air_cooling_coil_cv.o vslog.o modd_bemn.o urban_fluxes.o modd_bem_cst.o ini_csts.o modi_window_shading_availability.o bem_morpho_struct.o mode_char2real.o abor1_sfx.o bem.o urban_lw_coef.o modd_arch.o modd_csts.o roof_layer_e_budget.o hook.o modi_window_shading.o modi_window_data.o wind_threshold.o wind_profile_wang.o ahf_traffic_now.o modd_bem_optionn.o modi_bem_morpho_struct.o modi_alloc_teb_struct.o mode_psychro.o modi_greenroof.o surface_aero_cond.o day_of_week.o flxsurf3bx.o window_shading.o modd_flood_par.o teb_irrig.o mass_layer_e_budget.o avg_urban_fluxes.o layer_e_budget.o modd_teb_optionn.o bem_morpho.o garden.o modi_dealloc_teb_struct.o ol_read_atm.o modi_day_of_week.o modi_flxsurf3bx.o modi_layer_e_budget_get_coef.o modd_tebn.o modi_init_surfconsphy.o modd_type_snow.o open_close_bin_asc_forc.o wall_layer_e_budget.o mode_conv_DOE.o facade_e_budget.o modd_water_par.o modi_tridiag_ground.o teb_garden_struct.o window_data_struct.o modd_surf_par.o surface_cd.o modi_surface_cd.o modi_snow_cover_1layer.o ol_time_interp_atm.o teb.o modi_urban_drag.o modi_surface_ri.o sunpos.o modd_surf_atm.o modi_bem.o modi_window_e_budget.o urban_drag.o run_teb_offline.o sfc_teb.o call_driver.o mode_thermos.o modi_urban_solar_abs.o greenroof.o urban_hydro.o modd_diag_misc_tebn.o modi_bld_occ_calendar.o modi_urban_exch_coef.o tridiag_ground.o modi_wind_threshold.o modi_roof_layer_e_budget.o init_surfconsphy.o modi_window_data_struct.o modi_surface_aero_cond.o modi_layer_e_budget.o add_forecast_to_date_surf.o bld_occ_calendar.o bld_e_budget.o modi_garden.o ol_read_atm_ascii.o modi_teb_irrig.o
OFF = src_teb/wind_threshold.F90 src_driver/wind_profile_wang.F90 src_driver/ahf_traffic_now.F90 src_teb/modi_window_shading_availability.f90 src_teb/urban_fluxes.F90 src_teb/window_e_budget.F90 src_struct/modi_dealloc_teb_struct.F90 src_teb/urban_lw_coef.F90 src_struct/modd_teb_paneln.F90 src_driver/close_file_asc.F90 src_teb/modi_layer_e_budget.f90 src_teb/modi_bld_e_budget.f90 src_teb/modi_teb_garden.f90 src_teb/vslog.f src_teb/surface_cd.F90 src_driver/ol_time_interp_atm.F90 src_driver/call_teb_teb_interface.F90 src_driver/sfc_teb.F90 src_driver/call_driver.F90 src_teb/modi_mass_layer_e_budget.f90 src_teb/bem_morpho.F90 src_teb/flxsurf3bx.F src_teb/surface_ri.F90 src_teb/window_shading_availability.F90 src_teb/modd_flood_par.F90 src_struct/modd_diag_misc_tebn.F90 src_teb/modi_day_of_week.f90 src_teb/teb_irrig.F90 src_teb/mode_surf_snow_frac.F90 src_driver/abor1_sfx.F90 src_teb/modi_init_surfconsphy.f src_driver/add_forecast_to_date_surf.F90 src_solar/sunpos.F90 src_proxi_SVAT/garden.F90 src_struct/modd_teb_optionn.F90 src_teb/window_data.F90 src_teb/surface_aero_cond.F90 src_teb/modi_tridiag_ground.f90 src_driver/modd_surf_conf.F90 src_teb/init_surfconsphy.F src_teb/modi_surface_ri.f90 src_teb/urban_hydro.F90 src_teb/teb.F90 src_struct/modd_type_snow.F90 src_teb/tridiag_ground.F90 src_teb/modi_urban_hydro.f90 src_teb/modi_wall_layer_e_budget.f90 src_teb/day_of_week.F90 src_teb/avg_urban_fluxes.F90 src_driver/mode_char2real.F90 src_teb/modi_layer_e_budget_get_coef.f90 src_teb/urban_exch_coef.F90 src_proxi_SVAT/modi_teb_veg_properties.F90 src_teb/modi_road_layer_e_budget.f90 src_teb/floor_layer_e_budget.F90 src_teb/modi_urban_exch_coef.f90 src_driver/ol_alloc_atm.F90 src_teb/bld_e_budget.F90 src_teb/modi_roof_layer_e_budget.f90 src_teb/modi_bem_morpho.f90 src_driver/ol_read_atm.F90 src_teb/modi_wind_threshold.f90 src_teb/mode_psychro.F90 src_teb/layer_e_budget.F90 src_teb/modd_surf_atm.F90 src_teb/window_shading.F90 src_teb/modd_csts.F90 src_teb/modi_urban_solar_abs.f90 src_teb/modd_type_date_surf.F90 src_teb/roof_impl_coef.F90 src_teb/modd_water_par.F90 src_teb/modi_roof_impl_coef.f90 src_teb/road_layer_e_budget.F90 src_teb/modi_bem.f90 src_teb/modd_snow_par.F90 src_struct/alloc_teb_struct.F90 src_teb/facade_e_budget.F90 src_teb/modi_window_shading.f90 src_struct/dealloc_teb_struct.F90 src_struct/modi_alloc_teb_struct.F90 src_teb/modi_teb.f90 src_struct/window_data_struct.F90 src_teb/modi_solar_panel.f90 src_struct/modd_bem_optionn.F90 src_driver/modd_reprod_oper.F90 src_struct/teb_garden_struct.F90 src_teb/bld_occ_calendar.F90 src_teb/mode_thermos.F90 src_teb/urban_drag.F90 src_teb/urban_snow_evol.F90 src_teb/modi_facade_e_budget.f90 src_struct/modd_teb_irrign.F90 src_driver/ol_read_atm_ascii.F90 src_teb/hook.F90 src_driver/open_close_bin_asc_forc.F90 src_teb/modi_ini_csts.f90 src_driver/read_surf_atm.F90 src_teb/modi_urban_snow_evol.f90 src_teb/modi_surface_cd.f90 src_teb/modi_teb_irrig.f90 src_struct/modd_tebn.F90 src_teb/mass_layer_e_budget.F90 src_teb/ini_csts.F90 src_teb/snow_cover_1layer.F90 src_struct/modd_bemn.F90 src_proxi_SVAT/teb_veg_properties.F90 src_teb/modi_flxsurf3bx.f src_teb/modi_urban_drag.f90 src_teb/modd_bem_cst.F90 src_teb/solar_panel.F90 src_teb/modi_snow_cover_1layer.f90 src_teb/roof_layer_e_budget.F90 src_proxi_SVAT/modi_garden.F90 src_driver/modd_forc_atm.F90 src_teb/urban_solar_abs.F90 src_teb/teb_garden.F90 src_teb/bem.F90 src_teb/layer_e_budget_get_coef.F90 src_teb/modd_surf_par.F90 src_struct/modi_window_data_struct.f90 src_proxi_SVAT/greenroof.F90 src_teb/mode_conv_DOE.F90 src_teb/modi_window_e_budget.f90 src_struct/bem_morpho_struct.F90 src_teb/modi_urban_fluxes.f90 src_driver/close_file.F90 src_teb/modi_bld_occ_calendar.f90 src_struct/modi_teb_garden_struct.f90 src_teb/modi_floor_layer_e_budget.f90 src_driver/modd_arch.F90 src_solar/circumsolar_rad.F90 src_teb/dx_air_cooling_coil_cv.F90 src_teb/wall_layer_e_budget.F90 src_teb/modi_urban_lw_coef.f90 src_teb/modi_window_data.f90 src_teb/modi_dx_air_cooling_coil_cv.f90 src_proxi_SVAT/modi_greenroof.F90 src_struct/modi_bem_morpho_struct.f90 src_teb/modi_surface_aero_cond.f90 src_teb/modi_avg_urban_fluxes.f90
clean: neat
	-rm -f .cppdefs $(OBJ) *.obj driver1.exe *.mod
neat:
	-rm -f $(TMPFILES)
localize: $(OFF)
	cp $(OFF) .
TAGS: $(SRC)
	etags $(SRC)
tags: $(SRC)
	ctags $(SRC)
driver1.exe: $(OBJ) 
	$(LD) $(OBJ) -o driver1.exe  $(LDFLAGS)
