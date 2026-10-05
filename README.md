# TEB-Ru: Single-Layer Urban Canopy Model

[![Fortran](https://img.shields.io/badge/Fortran-734f96?logo=fortran&logoColor=white)](https://fortran-lang.org/)
[![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-CeCILL--C-blue.svg)](https://cecill.info/licences/Licence_CeCILL-C_V1-en.html)

TEB-Ru is a single-layer urban canopy model developed at Lomonosov Moscow State University based on the popular French open-source model TEB (Town Energy Balance) [[Masson, 2000]](#references). This model provides simplified but computationally effective parameterization of turbulent and radiant energy exchange within the urban canopy described as an idealized street canyon, considering building energy use, including heating and air conditioning, simulated by building energy model (BEM) [[Bueno et al., 2012]](#references). It also allows representing urban vegetation inside the street canyon [[Lemonsu et al., 2012]](#references) and on buildings' roofs [[De Munck et al., 2013]](#references), as well as solar panels on the roofs.

## Key Features

- **Single-layer urban canopy scheme** with idealized street canyon geometry
- **Building Energy Model (BEM)** for simulating heating and air conditioning energy use
- **Urban vegetation** inside street canyons and on green roofs
- **Solar panels** on building roofs
- **Advanced wind profile** parameterization following [[Wang, 2012]](#references) verified with microscale modelling [[Tarasova et al., 2024]](#references)
- **Anthropogenic heat flux** from traffic with diurnal cycle parameterization
- **Flexible coupling interface** for standalone mode with given atmospheric forcing or two-way coupling with atmospheric models (e.g., COSMO) [[Tarasova et al., 2025]](#references)

## Distinctive Features of TEB-Ru

Compared to the original TEB model, TEB-Ru includes:

- **Improvements to physical parameterizations** and their adaptation to Russian cities
- **Elaborate program interfaces** for easier coupling and configuration
- **Multiple modifications to BEM** for better representation of urban energy consumption
- **New wind speed profile parameterization** following the Wang (2012) approach
- **New parameterization of diurnal cycle** of anthropogenic heat flux from traffic
- **New interface for coupling with land surface models** for describing soil and vegetation in street canyons
- **Flexible mode switching** between standalone and coupled operation
- **Python library suite** for preparing atmospheric forcing data, including utilities for processing meteorological observations, reanalysis data, and generating input files for offline simulations

The development line (`src_dev`, see [Two source trees](#two-source-trees-src_dev-and-src_ctrl)) additionally contains:

- **Fixes of defects of the original TEB** found during this work: the weighting of the snow fluxes in the canyon nodes, the latent heat of the phase change (`XLVTT`/`XLSTT`), the melt-water path, and the uninitialised radiation diagnostics of the green surfaces and canyon ground temperature — [`docs/TEB_Ru_source_defects.md`](docs/TEB_Ru_source_defects.md)
- **τ-scheme of the surface–canyon exchange**: a weight τ ∈ [0, 1] blends the "through the canyon" and the "directly to the forcing level" paths (τ = 1 reproduces the original TEB, τ → 0 makes the surface flat); the air seen by the surfaces is a τ-relaxation of the classical canyon node (`T_CAN0`) and of the surface layer (`T_CAN1`) — [`docs/TEB_Ru_tau_scheme_T_CAN_reformulation.md`](docs/TEB_Ru_tau_scheme_T_CAN_reformulation.md)
- **Diagnostic garden and green-roof scheme**: the surface energy balance `Rn = H + LE` with a surface relative humidity, solved by Newton iterations, coupled to the canyon air, with external modes (`EXT`, `EXT_NEU`) — [`docs/TEB_Ru_garden_diagnostic_scheme.md`](docs/TEB_Ru_garden_diagnostic_scheme.md)
- **Urban roughness and displacement height from the namelist or from the Macdonald et al. (1998) morphometric scheme** [[Macdonald et al., 1998]](#references) instead of the hard-coded `zd = H/3` correction — [`docs/TEB_Ru_source_defects.md`](docs/TEB_Ru_source_defects.md) (D7)

### Quick Start

#### Option 1: Google Colab (Recommended)

Open and run the [`TEB_sandbox.ipynb`](https://github.com/mkolennikova/TEB-Ru/blob/main/TEB_sandbox.ipynb) notebook in Google Colab. It will automatically:

1. Clone the repository
2. Set up the environment
3. Compile the model (the source tree `src_dev` or `src_ctrl` is selected in the notebook)
4. Download the ERA5 meteorological forcing for the chosen site and period
5. Run a test simulation
6. Visualize the results

The same notebook is also the local (Windows) pipeline: it detects the repository, the
toolchain and the Python environment instead of installing anything.

#### Option 2: Local Build

To build and run TEB-Ru locally:

```bash
# Clone the repository
git clone https://github.com/mkolennikova/TEB-Ru.git
cd TEB-Ru

# Check the compiler flags in src_dev/gfortran_args (or src_ctrl/gfortran_args)
# The model automatically detects ifort or gfortran

# Build a source tree (sources and Makefile live in the tree; the object files
# and the executable are written to build/)
make -C src_dev clean
make -C src_dev          # -> build/TEB_offline_dev.exe

# Run the reference case from its own directory
cd tests/CAPITOUL
../../build/TEB_offline_dev.exe
```

### Two source trees: `src_dev` and `src_ctrl`

The Fortran sources are split into two independent trees, each with its own `Makefile` and
`gfortran_args` and its own executable:

| Tree | Physics | Builds |
| --- | --- | --- |
| `src_dev/` | development line (branch `MV_devs`) with the modern I/O | `build/TEB_offline_dev.exe` |
| `src_ctrl/` | control line (physics of the first commit `582c3ab`) with the same I/O and namelists | `build/TEB_offline_ctrl.exe` |

Both trees share `tests/`, `python/` and `docs/`, are built in the same way
(`make -C src_dev` / `make -C src_ctrl`) and write the same columns to `TEB_output.csv`, so
runs of the two trees can be compared line by line.

## Repository Layout

| Path | Content |
| --- | --- |
| `src_dev/` | Development Fortran sources (`src_driver/`, `src_teb/`, `src_struct/`, `src_solar/`, `src_proxi_SVAT/`) with their `Makefile` and `gfortran_args`; builds `build/TEB_offline_dev.exe` |
| `src_ctrl/` | Control Fortran sources (same layout, physics of the first commit); builds `build/TEB_offline_ctrl.exe` |
| `python/` | Python libraries shared by the notebook and the test benches: output handling (`output_utils.py`), forcing preparation (`forcing_ERA5.py`, `forcing_utils.py`) and the notebook helpers (`run_utils.py`, `install_utils.py`) |
| `python_tests/` | Python test benches and comparison/sensitivity experiments verifying the model revisions |
| `tests/` | Test cases; `tests/CAPITOUL/` is the reference case: `namelist/`, `input/` (ASCII forcing) and `output_ref/` |
| `build/` | Build output of `make`: `obj_dev/`, `obj_ctrl/`, `logs/` (the `make` logs) and the executables; created automatically and not tracked |
| `docs/` | Model documentation: the variable description (`TEB_Ru_variables_description.md`), the τ-scheme (`TEB_Ru_tau_scheme_T_CAN_reformulation.md`), the diagnostic garden and green-roof scheme (`TEB_Ru_garden_diagnostic_scheme.md`), the defects of the original TEB found and fixed in TEB-Ru (`TEB_Ru_source_defects.md`), the commit-referenced change history (`TEB_Ru_change_history.md`), the coupling checklist (`TEB_Ru_coupling_checklist.md`) and the documentation rules (`TEB_Ru_documentation_rules.md`) |
| `TEB_sandbox.ipynb` | Step-by-step pipeline notebook: Google Colab and local (Windows) build and run |

The executable is started in the directory of the case, because the driver reads `namelist/` and
the forcing directory and writes `output/` relative to the working directory (for the reference
case that is `tests/CAPITOUL/`). The command-line options `-forcing_nml`, `-param_nml` and
`-output` override each of them.

## Configuration

The model is configured by two Fortran namelist files — `namelist.nml` (model parameters) and
`namelist_forcing.nml` (atmospheric forcing and the period of the run) — which the driver reads at
start-up. They must be composed according to the rules of
[`docs/TEB_Ru_variables_description.md`](docs/TEB_Ru_variables_description.md), which documents
every item, its type, units, accepted values and defaults.

Namelist examples for CAPITOUL test case availible at  
[`tests/CAPITOUL/namelist/`](https://github.com/mkolennikova/TEB-Ru/tree/main/tests/CAPITOUL/namelist).

- **[namelist_forcing.nml](https://github.com/mkolennikova/TEB-Ru/blob/main/tests/CAPITOUL/namelist/namelist_forcing.nml)** – example of the atmospheric forcing parameters (temperature, humidity, wind, radiation, precipitation, etc.) and of the run period
- **[namelist.nml](https://github.com/mkolennikova/TEB-Ru/blob/main/tests/CAPITOUL/namelist/namelist.nml)** – example of the urban geometry, material properties, BEM parameters, vegetation settings and other model options

For another site, copy and adapt these examples (the notebook `TEB_sandbox.ipynb` writes its own
`params_<experiment>.nml` from the CAPITOUL parameters).

<!-- MV202609 strict namelist date/time reading -->
⚠️ **The driver stops if a namelist cannot be read.** Both namelist files
(`namelist_forcing.nml` and `namelist.nml`) are read with the same policy: on an
`IOSTAT > 0` the run stops with an error (**no parameters are silently taken from the
program**), the log lists every declared item of the failing group with its line
number and its state, and the **first line at which the read fails** is reported. The
items that are simply not present in the file are listed separately, together with the
notice that the driver default is used for them.

Integer items must be written without a decimal point: `teb_year`, `teb_month`,
`teb_day`, `teb_hour`, `teb_min`, `nsteps` and `teb_utc_hour` are INTEGER items and a
real value (`teb_hour = 0.0`) makes the READ fail at that entry. The start date/time
items of the forcing namelist have **no default value** any more and are validated
(range check): a run without a valid start date cannot start. The start date, the end
date of the run, the forcing window and the location are echoed in the log.

### Model Output

The model writes all output variables, together with the atmospheric forcing used at
each step, to a single semicolon-separated file `<output_dir>/TEB_output.csv`
(`-output <dir>` on the command line, `output/` by default). The file contains one line
per forcing step: first the time column `time` (ISO 8601, the end of the forcing
interval, e.g. `2004-02-20 00:30:00`), then the model variables, then the forcing
columns `Forc_*` (see [TEB_Ru_variables_description.md](docs/TEB_Ru_variables_description.md)).
The columns depend on the model options (e.g. `HVAC_*` only with the Building Energy
Model, `SOLAR_PROD` only with solar panels).

The Python utility [`python/output_utils.py`](python/output_utils.py) reads this file (the
`Forc_*` columns it contains are used as the forcing overlay in the plots) as well as the
legacy per-variable `*.txt` output of older runs:

```python
import output_utils

df = output_utils.read_output('output/TEB_output.csv')    # the output file itself
df = output_utils.read_output('output/')                  # ... or its directory
df = output_utils.read_output('output_old/', fmt='txt',   # legacy <VAR>.txt files
                              namelist_path='namelist_forcing.nml')
```

### Compiler Flags

Compiler settings are defined in [`src_dev/gfortran_args`](https://github.com/mkolennikova/TEB-Ru/blob/main/src_dev/gfortran_args)
(the same file exists in [`src_ctrl/gfortran_args`](https://github.com/mkolennikova/TEB-Ru/blob/main/src_ctrl/gfortran_args)).
The model automatically detects the available compiler:

- `ifort` – Intel Fortran Compiler (if available)
- `gfortran` – GNU Fortran Compiler (fallback)

Key compilation flags:
- `-ffree-line-length-0` – Allow unlimited line length (avoids line truncation errors)
- `-fdefault-real-8` – Use double precision real numbers
- `-J$(OBJDIR)` – Place module files in the build directory (`build/obj_dev` or `build/obj_ctrl`)

On Windows the build additionally links `libgfortran` statically and applies a small
workaround for a locale defect of the UCRT runtime (`src_dev/src_driver/wrap_setlocale.c`,
also in `src_ctrl`): the formatted output of real numbers of `libgfortran` saves a
`setlocale` pointer that the UCRT invalidates, which causes rare `SIGSEGV` failures of long
runs. The workaround does not change the results (`WRAP_LOCALE=0` disables it explicitly);
details and measurements are in §5.8 of
[`docs/TEB_Ru_change_history.md`](docs/TEB_Ru_change_history.md).

## References

1. [Bueno, B., Pigeon, G., Norford, L.K., Zibouche, K., Marchadier, C., 2012. Development and evaluation of a building energy model integrated in the TEB scheme. Geoscientific Model Development 5, 433–448.](https://doi.org/10.5194/gmd-5-433-2012)

2. [De Munck, C.S., Lemonsu, A., Bouzouidja, R., Masson, V., Claverie, R., 2013. The GREENROOF module (v7.3) for modelling green roof hydrological and energetic performances within TEB. Geoscientific Model Development 6, 1941–1960.](https://doi.org/10.5194/gmd-6-1941-2013)

3. [Lemonsu, A., Masson, V., Shashua-Bar, L., Erell, E., Pearlmutter, D., 2012. Inclusion of vegetation in the Town Energy Balance model for modelling urban green areas. Geoscientific Model Development 5, 1377–1393.](https://doi.org/10.5194/gmd-5-1377-2012)

4. [Macdonald, R.W., Griffiths, R.F., Hall, D.J., 1998. An improved method for the estimation of surface roughness of obstacle arrays. Atmospheric Environment 32, 1857–1864.](https://doi.org/10.1016/S1352-2310(97)00403-2)

5. [Masson, V., 2000. A Physically-Based Scheme For The Urban Energy Budget In Atmospheric Models. Boundary-Layer Meteorology 94, 357–397.](https://doi.org/10.1023/A:1002463829265)

6. [Meyer, D., Schoetter, R., Masson, V., Grimmond, S., 2020. Enhanced software and platform for the Town Energy Balance (TEB) model. Journal of Open Source Software 5, 2008.](https://doi.org/10.21105/joss.02008)

7. [Tarasova, M.A., Debolskiy, A.V., Mortikov, E.V., Varentsov, M.I., Glazunov, A.V., Stepanenko, V.M., 2024. On the Parameterization of the Mean Wind Profile for Urban Canopy Models. Lobachevskii Journal of Mathematics 45, 3198–3210.](https://doi.org/10.1134/S1995080224603801)

8. [Tarasova, M.A., Varentsov, M.I., Debolskiy, A.V., Stepanenko, V.M., 2025. Coupling the Town Energy Balance (TEB) Scheme with the COSMO Atmospheric Model: Evaluation Against a Bulk Parameterization (TERRA_URB) for the Moscow Megacity. GES 18, 118–134.](https://doi.org/10.24057/2071-9388-2025-3975)

9. [Wang, W., 2012. An Analytical Model for Mean Wind Profiles in Sparse Canopies. Boundary-Layer Meteorology 142, 383–399.](https://doi.org/10.1007/s10546-011-9687-0)

## Citation

If you use TEB-Ru in your research, please cite:

> [Tarasova, M.A., Varentsov, M.I., Debolskiy, A.V., Stepanenko, V.M., 2025. Coupling the Town Energy Balance (TEB) Scheme with the COSMO Atmospheric Model: Evaluation Against a Bulk Parameterization (TERRA_URB) for the Moscow Megacity. GES 18, 118–134.](https://doi.org/10.24057/2071-9388-2025-3975)

Also, please cite the original TEB model and the relevant references listed above.

## License

TEB-Ru is distributed under the [CeCILL-C](https://cecill.info/licences/Licence_CeCILL-C_V1-en.html) license, following the original TEB model.

## Acknowledgments

TEB-Ru development is supported by Lomonosov Moscow State University and acknowledges the original TEB model development team at CNRM (Météo-France/CNRS).
