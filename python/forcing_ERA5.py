
import cdsapi
import re
import os
import glob
import zipfile
import shutil
import numpy as np
import pandas as pd
import xarray as xr
from forcing_utils import plot_forcing_mpl, write_forcing, prepare_namelist


from pathlib import Path

from concurrent.futures import ThreadPoolExecutor, as_completed

# Default set of 10 variables: t2m, d2m, sp, u10, v10, fdir, ssrd, strd, ptype, tp
DEF_FORCING_VARIABLES = [
    '2m_temperature',                                 # t2m
    '2m_dewpoint_temperature',                        # d2m
    'surface_pressure',                               # sp
    '10m_u_component_of_wind',                        # u10
    '10m_v_component_of_wind',                        # v10
    'total_sky_direct_solar_radiation_at_surface',    # fdir (direct solar radiation)
    'surface_solar_radiation_downwards',              # ssrd (global solar radiation)
    'surface_thermal_radiation_downwards',            # strd (thermal/longwave)
    'total_precipitation',                            # tp
]

#'precipitation_type',                             # ptype


def download_chunk(chunk_start, chunk_end, chunk_file, base_request, verbose=True, force_reload=False):
    """
    Download a single time chunk using the timeseries dataset.
    Handles ZIP archive with one NetCDF file inside.
    """
    # Check if file already exists
    if os.path.exists(chunk_file) and not force_reload:
        if verbose:
            print(f"⏭️ File already exists, skipping: {chunk_file}")
        return chunk_file

    # If force_reload and file exists, remove it
    if os.path.exists(chunk_file) and force_reload:
        os.remove(chunk_file)
        if verbose:
            print(f"🔄 Removing existing file for reload: {chunk_file}")

    client = cdsapi.Client()
    request = base_request.copy()
    request['date'] = f"{chunk_start}/{chunk_end}"

    temp_file = chunk_file + '.tmp'
    client.retrieve('reanalysis-era5-single-levels-timeseries', request, temp_file)

    # Check if ZIP archive
    is_zip = False
    with open(temp_file, 'rb') as f:
        if f.read(4) == b'PK\x03\x04':
            is_zip = True

    if is_zip:
        extract_dir = os.path.dirname(temp_file)
        with zipfile.ZipFile(temp_file, 'r') as zf:
            names = zf.namelist()
            zf.extractall(extract_dir)
        os.remove(temp_file)
        if names:
            src = os.path.join(extract_dir, names[0])
            shutil.move(src, chunk_file)
        else:
            raise RuntimeError("ZIP archive is empty")
        if verbose:
            print(f"✅ Extracted and saved to {chunk_file}")
    else:
        shutil.move(temp_file, chunk_file)
        if verbose:
            print(f"✅ Saved to {chunk_file}")

    return chunk_file

def download(
    lat,
    lon,
    start_date,
    end_date,
    variables=DEF_FORCING_VARIABLES,
    output_file="era5_data.nc",
    output_dir=None,
    time=None,
    chunk_by=None,
    verbose=True,
    force_reload=False,
    max_workers=1,
):
    """
    Download ERA5 point time series using the dedicated dataset
    'reanalysis-era5-single-levels-timeseries'.

    Parameters
    ----------
    lat, lon : float
        Coordinates of the point.
    start_date, end_date : str
        Date range in 'YYYY-MM-DD' format.
    variables : list
        List of variable names (default: DEF_FORCING_VARIABLES).
    output_file : str
        Base name for the output file (will be placed in output_dir).
    output_dir : str, optional
        Directory where files are saved. Defaults to current directory.
    time : str or list
        Time step like '3h' or list of times ['00:00', ...]. Default '3h'.
    chunk_by : str, optional
        Split time range into 'month' or 'year' chunks. If None, one file.
    verbose : bool
        Print progress.
    max_workers : int
        Parallel downloads (only when chunk_by is used).
    """
    # Resolve output directory
    file_dir, file_base = os.path.split(output_file)
    if not file_base:
        file_base = "era5_data.nc"
    out_dir = output_dir if output_dir is not None else (file_dir if file_dir else '.')
    os.makedirs(out_dir, exist_ok=True)

    # Process time parameter
    if time is None:
        time = '3h'
    if isinstance(time, str):
        match = re.match(r'^(\d+)h$', time)
        if not match:
            raise ValueError("time string must be like '1h', '3h', '6h'")
        hours = int(match.group(1))
        if 24 % hours != 0:
            raise ValueError(f"hours ({hours}) must divide 24")
        times = [f"{h:02d}:00" for h in range(0, 24, hours)]
    elif isinstance(time, (list, tuple)):
        times = list(time)
        for t in times:
            if not re.match(r'^([01]\d|2[0-3]):[0-5]\d$', t):
                raise ValueError(f"Invalid time format: {t}. Must be HH:MM")
    else:
        raise TypeError("time must be a string or a list/tuple of times")

    # Generate chunks
    start = pd.to_datetime(start_date)
    end = pd.to_datetime(end_date)
    if start > end:
        raise ValueError("start_date must be before end_date")

    chunks = []
    if chunk_by is None:
        chunks = [(start_date, end_date)]
    elif chunk_by == 'month':
        current = start.replace(day=1)
        while current <= end:
            chunk_start = current.strftime('%Y-%m-%d')
            next_month = current + pd.offsets.MonthEnd(1)
            chunk_end = (next_month if next_month <= end else end).strftime('%Y-%m-%d')
            chunks.append((chunk_start, chunk_end))
            current = current + pd.offsets.MonthBegin(1)
    elif chunk_by == 'year':
        current = start.replace(month=1, day=1)
        while current <= end:
            chunk_start = current.strftime('%Y-%m-%d')
            next_year = current + pd.offsets.YearEnd(1)
            chunk_end = (next_year if next_year <= end else end).strftime('%Y-%m-%d')
            chunks.append((chunk_start, chunk_end))
            current = current + pd.offsets.YearBegin(1)
    else:
        raise ValueError("chunk_by must be 'month', 'year', or None")

    # Base request for timeseries dataset
    base_request = {
        'variable': variables,
        'time': times,
        'location': {"latitude": lat, "longitude": lon},
        'format': 'netcdf',
    }

    # Generate output file names
    base_name, ext = os.path.splitext(file_base)
    if not ext:
        ext = '.nc'
    chunk_files = []
    if len(chunks) == 1:
        chunk_files = [os.path.join(out_dir, file_base)]
    else:
        for i, (chunk_start, chunk_end) in enumerate(chunks, 1):
            if chunk_by == 'month':
                suffix = pd.to_datetime(chunk_start).strftime('%Y-%m')
            elif chunk_by == 'year':
                suffix = pd.to_datetime(chunk_start).strftime('%Y')
            else:
                suffix = f"{i:02d}"
            chunk_file = os.path.join(out_dir, f"{base_name}_{suffix}{ext}")
            chunk_files.append(chunk_file)

    # Execute downloads (sequential or parallel)
    all_files = []
    if len(chunks) == 1 or max_workers <= 1:
        for (chunk_start, chunk_end), chunk_file in zip(chunks, chunk_files):
            f = download_chunk(chunk_start, chunk_end, chunk_file, base_request, verbose)
            all_files.append(f)
    else:
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {}
            for (chunk_start, chunk_end), chunk_file in zip(chunks, chunk_files):
                future = executor.submit(download_chunk, chunk_start, chunk_end, chunk_file, base_request, verbose, force_reload)
                futures[future] = chunk_file
            for future in as_completed(futures):
                try:
                    f = future.result()
                    all_files.append(f)
                except Exception as e:
                    print(f"❌ Error downloading chunk: {e}")

    if verbose and len(chunks) > 1:
        print(f"✅ All chunks downloaded. Files: {', '.join(all_files)}")

    return all_files

def convert_nc2df(
    input_path,
    lat=None,
    lon=None,
    method='nearest',
    output_file=None,
    engine=None,
):
    """
    Prepare forcing variables from ERA5 single‑level NetCDF files (or GRIB with engine='cfgrib').
    Handles both gridded data (with latitude/longitude as dimensions) and point time series
    (where coordinates are scalars). If lat/lon are None, assumes the data is already a point.

    If 'ptype' is missing, approximates precipitation type from 2m temperature.
    """
    # Locate files
    path_obj = Path(input_path)
    if path_obj.is_dir():
        file_pattern = str(path_obj / '*.nc')
    else:
        file_pattern = input_path

    files = glob.glob(file_pattern)
    if not files:
        raise FileNotFoundError(f"No files found matching pattern: {file_pattern}")

    # Open dataset(s)
    if len(files) == 1:
        if engine is not None:
            ds = xr.open_dataset(files[0], engine=engine)
        else:
            ds = xr.open_dataset(files[0])
    else:
        if engine is not None:
            ds = xr.open_mfdataset(files, combine='by_coords', parallel=True, engine=engine)
        else:
            ds = xr.open_mfdataset(files, combine='by_coords', parallel=True)

    # Rename coordinates if needed. The CDS point time series files may provide
    # the location as scalar data variables instead of coordinates: accept both
    # forms (the columns are dropped from the forcing DataFrame further below).
    if 'latitude' not in ds.coords and 'longitude' not in ds.coords:
        if 'lat' in ds.coords and 'lon' in ds.coords:
            ds = ds.rename({'lat': 'latitude', 'lon': 'longitude'})
        elif 'latitude' in ds.data_vars and 'longitude' in ds.data_vars:
            ds = ds.set_coords(['latitude', 'longitude'])
        else:
            raise KeyError("Dataset does not contain 'latitude'/'longitude' or 'lat'/'lon' coordinates")

    # A point time series downloaded in several chunks (open_mfdataset) carries
    # its location as an array repeating the same value at every time step: the
    # coordinates above are then one-dimensional along time and, having no index
    # of their own, they cannot be used by the point selection below. Reduce such
    # a degenerate (constant) location array to a scalar coordinate; a gridded
    # dataset keeps its latitude/longitude dimensions with their index and is
    # therefore left untouched.
    time_dims = {d for d in ds.dims if d in ('valid_time', 'time')}
    for c in ('latitude', 'longitude'):
        if c in ds.variables and ds[c].ndim == 1 and set(ds[c].dims) <= time_dims:
            values = np.asarray(ds[c].values, dtype=float)
            if np.allclose(values, values[0]):
                ds = ds.drop_vars(c).assign_coords({c: float(values[0])})

    # Extract point if lat/lon provided
    if lat is not None and lon is not None:
        lat_coord = ds.coords['latitude']
        lon_coord = ds.coords['longitude']
        if lat_coord.ndim == 0 and lon_coord.ndim == 0:
            # Scalar coordinates: just use the whole dataset, but warn if mismatch
            if not (np.isclose(float(lat_coord), lat) and np.isclose(float(lon_coord), lon)):
                print(f"Warning: Requested point ({lat}, {lon}) differs from file coordinates ({float(lat_coord)}, {float(lon_coord)})")
            point = ds
        else:
            point = ds.sel(latitude=lat, longitude=lon, method=method)
    else:
        # No lat/lon provided: assume data is already a point (scalar coords)
        # If coords are not scalar, raise an error
        lat_coord = ds.coords['latitude']
        lon_coord = ds.coords['longitude']
        if lat_coord.ndim != 0 or lon_coord.ndim != 0:
            raise ValueError("lat and lon must be provided when dataset contains multiple grid points.")
        point = ds

    # Check required variables
    required_vars = ['t2m', 'd2m', 'sp', 'u10', 'v10', 'fdir', 'ssrd', 'strd', 'tp']
    missing = [v for v in required_vars if v not in point.data_vars]
    if missing:
        raise KeyError(f"Missing required variables: {missing}")

    has_ptype = 'ptype' in point.data_vars

    # Compute derived variables
    t2m_c = point['t2m'] - 273.15
    d2m_c = point['d2m'] - 273.15
    sp = point['sp']

    E = 100 * 6.1 * (10 ** (7.45 * t2m_c / (235 + t2m_c)))
    e = 100 * 6.1 * (10 ** (7.45 * d2m_c / (235 + d2m_c)))
    rh = 100 * (e / E)
    q = 0.622 * e / (sp - 0.378 * e)

    u10 = point['u10']
    v10 = point['v10']
    wind_speed = np.sqrt(u10**2 + v10**2)
    wind_dir = np.mod(180 + (180 / np.pi) * np.arctan2(u10, v10), 360)

    fdir_flux = point['fdir'] / 3600
    ssrd_flux = point['ssrd'] / 3600
    strd_flux = point['strd'] / 3600
    diff_sw = ssrd_flux - fdir_flux

    tp_mm_s = point['tp'] * 1000 / 3600

    if has_ptype:
        ptype = point['ptype']
        rain = tp_mm_s.where(ptype < 2, other=0)
        snow = tp_mm_s.where(ptype >= 2, other=0)
    else:
        print("Warning: 'ptype' not found. Approximating precipitation type from 2m temperature.")
        rain = tp_mm_s.where(t2m_c > 0, other=0)
        snow = tp_mm_s.where(t2m_c <= 0, other=0)

    forcing_ds = xr.Dataset({
        'Forc_TA': point['t2m'],
        'Forc_QA': q,
        'Forc_WIND': wind_speed,
        'Forc_DIR': wind_dir,
        'Forc_DIR_SW': fdir_flux,
        'Forc_SCA_SW': diff_sw,
        'Forc_LW': strd_flux,
        'Forc_PS': sp,
        'Forc_RAIN': rain,
        'Forc_SNOW': snow,
        'RH2m': rh,
    })

    df = forcing_ds.to_dataframe()
    df = df.reset_index(drop=False)
    df = df.set_index('valid_time')

    # Drop latitude/longitude columns if present
    for col in ['latitude', 'longitude']:
        if col in df.columns:
            df = df.drop(columns=[col])

    if output_file:
        df.to_csv(output_file)
        print(f"DataFrame saved to {output_file}")

    ds.close()
    return df




def prepare_forcing(
    lat,
    lon,
    start_date,
    end_date,
    base_dir,
    variables=DEF_FORCING_VARIABLES,
    time='1h',
    chunk_by=None,
    max_workers=1,
    verbose=True,
    force_reload=False,
    save_plot=True,
    plot_title=None,
):
    """
    Master function to download ERA5 data, prepare forcing, save files, and plot.

    Parameters
    ----------
    lat, lon : float
        Coordinates of the point.
    start_date, end_date : str
        Date range in 'YYYY-MM-DD' format.
    base_dir : str
        Root directory for all outputs. Subdirectories will be created.
    variables : list
        List of variable names (default: DEF_FORCING_VARIABLES).
    time : str or list
        Time step like '3h' or list of times. Default '3h'.
    chunk_by : str
        'month' or 'year' for splitting downloads. Default 'month'.
    max_workers : int
        Parallel downloads. Default 1.
    verbose : bool
        Print progress.
    save_plot : bool
        Whether to save the plot.
    plot_title : str, optional
        Title for the plot. If None, uses location and date range.
    """
    # ------------------------------------------------------------------
    # 1. Create directory structure
    # ------------------------------------------------------------------
    base_path = Path(base_dir) / 'forcing_ERA5'
    netcdf_dir = base_path / 'forcing_nc'
    forcing_dir = base_path / 'forcing_txt'
    netcdf_dir.mkdir(parents=True, exist_ok=True)
    forcing_dir.mkdir(parents=True, exist_ok=True)

    # Define file names
    date_tag = f"{start_date}_{end_date}"
    netcdf_pattern = f"era5_{date_tag}.nc"
    netcdf_file = netcdf_dir / netcdf_pattern
    csv_file = base_path / f"era5_forcing_{date_tag}.csv"
    plot_file = base_path / f"era5_forcing_{date_tag}.png"

    # ------------------------------------------------------------------
    # 2. Download data
    # ------------------------------------------------------------------
    if verbose:
        print(f"📥 Downloading ERA5 data for ({lat}, {lon}) from {start_date} to {end_date}...")
    downloaded_files = download(lat=lat,
                                lon=lon,
                                start_date=start_date,
                                end_date=end_date,
                                variables=variables,
                                output_file=str(netcdf_file),
                                output_dir=None,   # we already gave full path in output_file
                                time=time,
                                chunk_by=chunk_by,
                                verbose=verbose,
                                force_reload=force_reload,
                                max_workers=max_workers)
    if verbose:
        print(f"✅ Downloaded {len(downloaded_files)} file(s) to {netcdf_dir}")

    # ------------------------------------------------------------------
    # 3. Prepare DataFrame
    # ------------------------------------------------------------------
    if verbose:
        print("📊 Preparing forcing DataFrame...")
    df = convert_nc2df(
        input_path=str(netcdf_dir),   # read all .nc files in the directory
        lat=lat,
        lon=lon,
        output_file=str(csv_file))
    if verbose:
        print(f"✅ DataFrame saved to {csv_file}")

    # ------------------------------------------------------------------
    # 4. Write forcing text files
    # ------------------------------------------------------------------
    if verbose:
        print("💾 Writing forcing text files...")
    # Ensure df is sorted by time
    df_sorted = df.sort_index()
    write_forcing(df_sorted, str(forcing_dir) + '/')
    if verbose:
        print(f"✅ Forcing files written to {forcing_dir}")

        # 5. Write namelist
    if verbose:
        print("📝 Writing namelist...")
    
    namelist_filename = "namelist_forcing.nml"
    prepare_namelist(lon=lon, lat=lat, hlev=10.0,
                     df=df_sorted,
                     forcing_path=str(forcing_dir.absolute()),  # absolute path
                     output_dir=str(base_path), 
                     filename=namelist_filename)
    
    if verbose:
        print(f"✅ Namelist saved to {base_path / namelist_filename}")

    # ------------------------------------------------------------------
    # 5. Plot and save figure
    # ------------------------------------------------------------------
    if save_plot:
        if verbose:
            print("📈 Generating plot...")
        if plot_title is None:
            plot_title = f"ERA5 Forcing: ({lat:.2f}, {lon:.2f})  {start_date} to {end_date}"
        plot_forcing_mpl(
            df_sorted,
            title=plot_title,
            save_path=str(plot_file),
            figsize=(14, 10)
        )
        if verbose:
            print(f"✅ Plot saved to {plot_file}")
