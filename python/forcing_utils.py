import os
import glob
import numpy as np
from pathlib import Path
from tqdm import tqdm
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import pandas as pd
import f90nml


def write_forcing(df4point, save_dir):
    os.makedirs(save_dir, exist_ok=True)

    for var in tqdm (df4point.columns, desc='Saving forcing variables'):
        if 'Forc_' in var:
            np.savetxt(save_dir + var + '.txt', df4point[var].to_numpy(), '%.5f')


def read_forcing(namelist_path, forcing_path=None, drop_last=True):
    """
    Read the ASCII atmospheric forcing (Forc_*.txt) used by a TEB run.

    Column names are the file names without extension ('Forc_TA', 'Forc_WIND', ...),
    i.e. the same convention as write_forcing() and plot_forcing_mpl().

    The time index is built so that the forcing can be overlaid on the model output
    (see output_utils.read_output): forcing record i is the left boundary of the
    forcing interval of the model step i, and the model state written for that step
    is time-stamped with the end of the interval. Record i is therefore labelled with
    the time t0 + i * forc_step, where t0 is the start date stored in the namelist
    (teb_year / teb_month / teb_day).

    The same forcing values are also written by the model to the output file
    TEB_output.csv (columns ``Forc_*``, see output_utils.read_output); read_forcing()
    is still useful for the forcing directory itself (e.g. to inspect the forcing
    without a run) and for old results.

    Parameters
    ----------
    namelist_path : str
        Path to the forcing namelist (the 'tebforcing' group with forcing_path,
        start date, nsteps and forc_step - as written by prepare_namelist()).
    forcing_path : str, optional
        Directory with the Forc_*.txt files. If None, the 'forcing_path' entry of the
        namelist is used (relative paths are also looked up relative to the namelist
        directory and to the repository root).
    drop_last : bool, optional
        If True (default), the last forcing record is dropped, so that the DataFrame has
        nsteps - 1 rows - one row per model output step. The last record is only used by
        the model to interpolate the final forcing interval.

    Returns
    -------
    pandas.DataFrame
        Forcing data indexed by time (datetime index).
    """
    nml = f90nml.read(namelist_path)['tebforcing']

    # ---- Locate the directory with the Forc_*.txt files ----------------------
    if forcing_path is not None:
        candidates = [Path(forcing_path)]
    else:
        namelist_dir = Path(namelist_path).parent
        raw_path = Path(nml['forcing_path'])
        candidates = [raw_path]
        if not raw_path.is_absolute():
            candidates.append(namelist_dir / raw_path)
            candidates.append(namelist_dir.parent / raw_path)

    forcing_dir = next((c for c in candidates if c.is_dir()), None)
    if forcing_dir is None:
        raise FileNotFoundError('Forcing directory not found. Tried: '
                                + ', '.join(str(c) for c in candidates))

    # ---- Read the forcing files ---------------------------------------------
    file_paths = sorted(glob.glob(os.path.join(str(forcing_dir), 'Forc_*.txt')))
    if not file_paths:
        raise FileNotFoundError(f'No Forc_*.txt files found in {forcing_dir}')

    forcing_df = pd.DataFrame()
    for file_path in file_paths:
        var_name = os.path.basename(file_path).split('.')[0]
        try:
            var_data = pd.read_csv(file_path, header=None)
        except pd.errors.EmptyDataError:
            print(f'{file_path} is empty, skipping')
            continue
        forcing_df[var_name] = var_data.iloc[:, 0]

    # ---- Time index (aligned with the model output, see read_output) ---------
    nsteps = int(nml['nsteps'])
    n_rows = nsteps - 1 if drop_last else nsteps
    forcing_df = forcing_df.iloc[:n_rows].copy()

    forc_step = float(nml['forc_step'])
    # record i is the left boundary of the interval of the model step i, while the
    # model output written for that step is time-stamped with the end of the interval
    # (t0 + forc_step, t0 + 2*forc_step, ...)
    start = pd.Timestamp(int(nml['teb_year']), int(nml['teb_month']),
                         int(nml['teb_day'])) + pd.Timedelta(seconds=forc_step)
    forcing_df.index = pd.date_range(start, periods=len(forcing_df),
                                     freq=pd.Timedelta(seconds=forc_step))

    return forcing_df

def plot_forcing_mpl(df, title=None, save_path=None, figsize=(14, 10), resample='auto'):
    """
    Plot forcing variables from ERA5.

    Parameters
    ----------
    df : pandas.DataFrame
        DataFrame from prepare() function, indexed by time.
    title : str, optional
        Title for the entire figure.
    save_path : str, optional
        If provided, saves the figure to this path.
    figsize : tuple, optional
        Figure size (width, height) in inches. Default (14, 10).
    resample : str, optional
        Resampling rule for temporal aggregation (e.g., 'D' for daily, 'M' for monthly, 'Y' for yearly).
        If 'auto', automatically selects based on number of points.
        If None, original time frequency is used.
    """
    # Ensure time index is datetime
    if not isinstance(df.index, pd.DatetimeIndex):
        df.index = pd.to_datetime(df.index)

    # Automatic resampling based on number of points
    if resample == 'auto':
        n = len(df)
        if n > 10000:
            resample = 'M'
            print(f"Auto-resampling to monthly (number of points: {n})")
        elif n > 2000:
            resample = 'D'
            print(f"Auto-resampling to daily (number of points: {n})")
        else:
            resample = None
            print(f"No resampling (number of points: {n})")
    # Apply resampling if requested
    if resample is not None:
        df_plot = df.resample(resample).mean()
        if title:
            title = f"{title} (resampled to {resample})"
    else:
        df_plot = df

    # Create figure and subplots (4 rows)
    fig, axes = plt.subplots(4, 1, figsize=figsize, sharex=True)
    fig.subplots_adjust(hspace=0.3)

    # 1. Pressure
    ax = axes[0]
    ax.plot(df_plot.index, df_plot['Forc_PS'] / 100, color='black', linewidth=1.5)
    ax.set_ylabel('Pressure (hPa)')
    ax.grid(True, linestyle='--', alpha=0.6)
    ax.set_title('Surface Pressure')

    # 2. Radiation (direct, diffuse, longwave)
    ax = axes[1]
    ax.plot(df_plot.index, df_plot['Forc_DIR_SW'], label='Direct SW', color='orange', linewidth=1.5)
    ax.plot(df_plot.index, df_plot['Forc_SCA_SW'], label='Diffuse SW', color='gold', linewidth=1.5)
    ax.plot(df_plot.index, df_plot['Forc_LW'], label='LW', color='red', linewidth=1.5)
    ax.set_ylabel('Radiation (W/m²)')
    ax.legend(loc='best')
    ax.grid(True, linestyle='--', alpha=0.6)
    ax.set_title('Radiation Components')

    # 3. Temperature and specific humidity (twinx)
    ax = axes[2]
    color1 = 'tab:red'
    ax.set_xlabel('')
    ax.set_ylabel('Temperature (°C)', color=color1)
    ax.plot(df_plot.index, df_plot['Forc_TA'] - 273.15, color=color1, linewidth=1.5)
    ax.tick_params(axis='y', labelcolor=color1)
    ax.grid(True, linestyle='--', alpha=0.3)

    ax2 = ax.twinx()
    color2 = 'tab:blue'
    ax2.set_ylabel('Specific humidity (kg/kg)', color=color2)
    ax2.plot(df_plot.index, df_plot['Forc_QA'], color=color2, linewidth=1.5)
    ax2.tick_params(axis='y', labelcolor=color2)
    ax2.grid(False)
    ax.set_title('Temperature and Humidity')

    # 4. Precipitation (rain and snow bars)
    ax = axes[3]
    rain_positive = df_plot['Forc_RAIN'].clip(lower=0)
    snow_positive = df_plot['Forc_SNOW'].clip(lower=0)

    # Bar width (auto)
    if len(df_plot) > 1:
        width = (df_plot.index[1] - df_plot.index[0]).total_seconds() / 3600 / 24 * 0.8
    else:
        width = 0.8

    ax.bar(df_plot.index, rain_positive, width=width, label='Rain', color='green', alpha=0.7)
    ax.bar(df_plot.index, snow_positive, width=width, label='Snow', color='blue', alpha=0.7, bottom=rain_positive)
    ax.set_ylabel('Precipitation (mm/s)')
    ax.legend(loc='best')
    ax.grid(True, linestyle='--', alpha=0.3)
    ax.set_title('Precipitation (rain + snow)')

    # Format x-axis for all subplots
    for ax in axes:
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d'))
        ax.xaxis.set_major_locator(mdates.AutoDateLocator())
        ax.tick_params(axis='x', rotation=45)

    # Overall title
    if title:
        fig.suptitle(title, fontsize=16, y=1.02)

    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"Plot saved to {save_path}")

    plt.show()
    return fig, axes


def prepare_namelist(
    lon,
    lat,
    hlev,
    df,
    forcing_path='forcing_txt/',
    output_dir='.',
    filename='namelist_forcing.nml'):
    """
    Create TEB namelist from forcing DataFrame using f90nml.

    Parameters
    ----------
    lon, lat, hlev : float
        Coordinates and height level for the TEB point.
    df : pandas.DataFrame
        DataFrame from prepare_df() with forcing variables, indexed by time.
    forcing_path : str, optional
        Path to directory containing Forc_*.txt files (as used in namelist).
    output_dir : str, optional
        Directory where namelist will be saved.
    filename : str, optional
        Name of the namelist file.
    
    Returns
    -------
    str
        Path to the created namelist file.
    """
    # Ensure datetime index
    if not isinstance(df.index, pd.DatetimeIndex):
        df.index = pd.to_datetime(df.index)

    # Extract parameters from DataFrame
    start_date = df.index[0]
    nsteps = len(df)
    forc_step = (df.index[1] - df.index[0]).total_seconds() if len(df) > 1 else 1800.0

    # Date components
    teb_year = start_date.year
    teb_month = start_date.month
    teb_day = start_date.day
    teb_hour = start_date.hour + start_date.minute / 60.0

    # Ensure forcing_path ends with a slash
    if not forcing_path.endswith('/'):
        forcing_path += '/'

    # Build namelist dictionary
    nml = {
        'tebforcing': {
            'forcing_path': forcing_path,
            'lon_teb': float(lon),
            'lat_teb': float(lat),
            'hlev_teb': float(hlev),
            'teb_year': int(teb_year),
            'teb_month': int(teb_month),
            'teb_day': int(teb_day),
            'teb_hour': round(teb_hour, 2),
            'teb_min': 0.0,
            'nsteps': int(nsteps),
            'forc_step': float(forc_step),
        }
    }

    # Write namelist file
    os.makedirs(output_dir, exist_ok=True)
    out_file = os.path.join(output_dir, filename)
    f90nml.write(nml, out_file, force=True)