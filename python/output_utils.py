import pandas as pd
import os
import f90nml
import glob

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

def read_output_txt(output_dir, namelist_path):
  """Read the legacy model output: one <VARIABLE>.txt file per variable.

  The time index is reconstructed from the forcing namelist:
  output line i corresponds to t0 + (i - 1) * forc_step.
  """
  file_paths = glob.glob(f'{output_dir}/*.txt')

  output_df = pd.DataFrame()
  for out_file in file_paths:
    var_name = os.path.basename(out_file).split('.')[0]
    try:
      # converters=float: the pandas fast float parser may lose 1 ULP on some values
      var_data = pd.read_csv(out_file, header=None, converters={0: float})
    except pd.errors.EmptyDataError:
      print (f'{out_file} is empty, skipping')
      continue

    output_df[var_name] = var_data.iloc[:, 0]

  namelist = f90nml.read(namelist_path)
  t1 = pd.Timestamp (namelist['tebforcing']['teb_year'], namelist['tebforcing']['teb_month'],  namelist['tebforcing']['teb_day'])
  t2 = t1 + pd.Timedelta (seconds=namelist['tebforcing']['forc_step']) * (namelist['tebforcing']['nsteps']-2)
  output_df.index = pd.date_range(t1, t2, freq=pd.Timedelta (seconds=namelist['tebforcing']['forc_step']))
  return output_df


def _find_csv (output_dir):
  """Locate the universal output table in an output directory.

  The current driver writes one table per selected (block, cell) pair,
  ``TEB_output_b<block>_c<cell>.csv``; the pre-P-log name ``TEB_output.csv`` is
  still accepted for old runs. If the directory holds several per-cell tables,
  the choice is ambiguous and the caller must pass the file it wants.
  """
  per_cell = sorted(glob.glob(os.path.join(output_dir, 'TEB_output_b*_c*.csv')))
  if len(per_cell) == 1:
    return per_cell[0]
  if len(per_cell) > 1:
    names = ', '.join(os.path.basename(p) for p in per_cell)
    raise ValueError(f'{output_dir}: several per-cell output tables ({names}); '
                     'pass one of them explicitly')
  return os.path.join(output_dir, 'TEB_output.csv')


def read_output (output_path, namelist_path=None, fmt='auto', include_forcing=True):
  """Read the output of a TEB-MSU offline run.

  Two formats are supported:

  * ``'csv'`` - the current output: one semicolon-separated table per selected
    (block, cell) pair, ``TEB_output_b<block>_c<cell>.csv`` with a header line.
    Column 1 is ``time`` (the time of the model state, i.e. the end of the
    forcing interval, ``t0 + n * forc_step``), then the model variables, then the
    atmospheric forcing used by the model at that step (columns ``Forc_*``).
  * ``'txt'`` - the legacy output: one ``<VARIABLE>.txt`` file per variable with one
    value per forcing step (no time stamps; the index is reconstructed from the
    forcing namelist).

  Parameters
  ----------
  output_path : str
      The output directory (with or without a trailing separator) or the output file
      itself, e.g. ``.../output/TEB_output_b1_c1.csv``. A directory is looked up for
      the per-cell tables (the legacy ``TEB_output.csv`` is still accepted).
  namelist_path : str, optional
      Forcing namelist. Required for the legacy txt format only, because the CSV file
      carries its own time stamps.
  fmt : {'auto', 'csv', 'txt'}
      'auto' (default) reads the CSV table when it is present, otherwise the
      legacy txt files.
  include_forcing : bool
      For the CSV format only: if False, the ``Forc_*`` columns are dropped, so that
      the returned DataFrame has the model variables of the legacy format.

  Returns
  -------
  pandas.DataFrame
      Model output indexed by time. Numeric values are parsed with the Python
      ``float`` (the pandas fast float parser may lose 1 ULP for some real(8) values).
  """
  output_path = str(output_path)

  # A path to a concrete file is used as is; a directory is looked up for the
  # universal table (TEB_output_b<block>_c<cell>.csv, legacy TEB_output.csv).
  output_is_file = os.path.isfile(output_path) or output_path.lower().endswith('.csv')
  if output_is_file:
    csv_file = output_path
  else:
    if not output_path.endswith((os.sep, '/')):
      output_path += os.sep
    if not os.path.isdir(output_path):
      raise FileNotFoundError(f'no such directory: {output_path}')
    csv_file = _find_csv(output_path)

  fmt = fmt.lower()
  if fmt == 'auto':
    fmt = 'csv' if (output_is_file or os.path.isfile(csv_file)) else 'txt'
  if fmt not in ('csv', 'txt'):
    raise ValueError(f"fmt must be 'auto', 'csv' or 'txt', got {fmt!r}")

  if fmt == 'txt':
    if output_is_file:
      raise ValueError(f'{output_path} is a file: the legacy txt output is a directory '
                       'of <VARIABLE>.txt files - pass the directory instead')
    if namelist_path is None:
      raise ValueError('namelist_path is required to read the legacy txt output')
    return read_output_txt(output_path, namelist_path)

  if not os.path.isfile(csv_file):
    raise FileNotFoundError(f'no such file: {csv_file}')

  columns = pd.read_csv(csv_file, sep=';', nrows=0).columns.tolist()
  if 'time' not in columns:
    raise ValueError(f'{csv_file}: no "time" column (found: {columns})')
  values = [c for c in columns if c != 'time']

  output_df = pd.read_csv(csv_file, sep=';', parse_dates=['time'],
                          converters={c: float for c in values})
  output_df = output_df.set_index('time')
  if not include_forcing:
    output_df = output_df[[c for c in output_df.columns if not c.startswith('Forc_')]]
  return output_df



# ============================================================================
# Default configuration for subplots (uses variable names in legend)
# Optional 'forcing' entries overlay the corresponding Forc_* columns as black
# reference lines; they come from an explicit forcing_df or from the output itself
# ============================================================================
DEFAULT_SUBPLOTS_CONFIG = [
    {
        'variables': ['TI_BLD', 'T_CANYON', 'T_ROOF1', 'T_WALLA1', 'T_WALLB1'],
        'title': 'Temperatures',
        'ylabel': 'Temperature (K)',
        # 'labels' omitted -> uses variable names
        'forcing': [{'column': 'Forc_TA', 'label': 'FORC_TA'}]
    },
    {
        'variables': ['U_CANYON', 'WIND_TOP'],
        'title': 'Wind Speed',
        'ylabel': 'Wind speed (m/s)',
        # 'labels' omitted -> uses variable names
        'forcing': [{'column': 'Forc_WIND', 'label': 'FORC_WIND'}]
    },
    {
        'variables': ['H_TOWN', 'LE_TOWN'],
        'title': 'Turbulent Heat Fluxes',
        'ylabel': 'Heat flux (W/m²)',
        'colors': ['#e41a1c', '#4daf4a']
        # 'labels' omitted -> uses variable names
    },
    {
        'variables': ['RN_TOWN'],
        'title': 'Net Radiation',
        'ylabel': 'Net radiation (W/m²)'
    },
    {
        'variables': ['HVAC_HEAT', 'HVAC_COOL'],
        'title': 'HVAC Energy Consumption',
        'ylabel': 'Energy (W/m²)',
        'colors': ['#d95f02', '#1f78b4']
        # 'labels' omitted -> uses variable names
    }
]


def _filter_df_by_time(df, start=None, end=None):
    """
    Filter DataFrame by time range.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        DataFrame with datetime index.
    start : str, datetime, or None
        Start time for slicing.
    end : str, datetime, or None
        End time for slicing.
    
    Returns:
    --------
    pandas.DataFrame
        Filtered DataFrame.
    """
    if start is not None or end is not None:
        return df.loc[start:end]
    return df


def _resolve_forcing_series(forcing_df, config, color='black', linewidth=1.5):
    """
    Collect the forcing curves that have to be overlaid on one subplot.

    A subplot config may contain an optional 'forcing' list, e.g.
        'forcing': [{'column': 'Forc_TA', 'label': 'FORC_TA'}]
    Each entry is looked up in `forcing_df` (a DataFrame with 'Forc_*' columns: an
    explicit one, or the model output itself - see _forcing_frame). The keys 'color' and
    'linewidth' of an entry override the function-level defaults; the forcing lines are always
    solid.

    Returns
    -------
    list of tuples (x, y, label, color, linewidth)
        Empty when there is nothing to draw (no forcing_df, no 'forcing' key or the
        requested columns are missing / empty).
    """
    specs = config.get('forcing') or []
    if forcing_df is None or not specs:
        return []

    series = []
    for spec in specs:
        column = spec.get('column')
        if column is None or column not in forcing_df.columns:
            continue
        y = forcing_df[column]
        if y.isna().all():
            continue
        series.append((forcing_df.index, y, spec.get('label', column),
                       spec.get('color', color), spec.get('linewidth', linewidth)))
    return series


def _forcing_frame(df, forcing_df=None):
    """
    DataFrame the forcing overlay is taken from.

    `forcing_df` wins when it is given (e.g. from forcing_utils.read_forcing). Otherwise the
    'Forc_*' columns of the output itself are used: recent versions of the model write the
    atmospheric forcing of every step into TEB_output.csv, so a separate forcing file is not
    needed. Returns None when there is nothing to overlay.
    """
    if forcing_df is not None:
        return forcing_df
    if df is not None and any(str(col).startswith('Forc_') for col in df.columns):
        return df
    return None


def _mrt_subplot(df):
    """Panel config for the pedestrian MRT curves, or None when the output has none.

    The `src_dev` tree writes the mean radiant temperature of a pedestrian on the
    road and on the roof (`MRT_ROAD`, `MRT_ROAD_SUN`, `MRT_ROOF`, see
    `docs/TEB_MSU_MRT_pedestrian_scheme.md`); the control tree and older outputs do
    not. The panel shows the canyon air temperature next to the two radiant
    temperatures, so that the air/radiant contrast of the two locations is visible.
    """
    if df is None:
        return None
    names = [c for c in ('MRT_ROAD', 'MRT_ROOF')
             if c in df.columns and not df[c].isna().all()]
    if not names:
        return None

    variables, labels, colors = [], [], []
    if 'T_CANYON' in df.columns and not df['T_CANYON'].isna().all():
        variables.append('T_CANYON')
        labels.append('T_CANYON')
        colors.append('#377eb8')
    titles = {'MRT_ROAD': 'MRT_ROAD (pedestrian on the road)',
              'MRT_ROOF': 'MRT_ROOF (pedestrian on the roof)'}
    palette = {'MRT_ROAD': '#e41a1c', 'MRT_ROOF': '#ff7f00'}
    for name in names:
        variables.append(name)
        labels.append(titles[name])
        colors.append(palette[name])

    return {
        'variables': variables,
        'title': 'Mean Radiant Temperature (pedestrian)',
        'ylabel': 'Temperature (K)',
        'labels': labels,
        'colors': colors,
        'forcing': [{'column': 'Forc_TA', 'label': 'FORC_TA'}],
    }


def _with_mrt_subplot(subplots_config, df):
    """Append the pedestrian-MRT panel to a subplot config when the data has MRT.

    The panel is inserted after the 'Temperatures' panel (or appended when there
    is no such panel) and only once: a caller whose config already draws one of
    the MRT columns keeps its own layout. Without MRT columns in `df` the config
    is returned unchanged, so the control tree and older outputs keep the usual
    set of panels.
    """
    panel = _mrt_subplot(df)
    if panel is None:
        return subplots_config
    # 'T_CANYON' is also drawn in the Temperatures panel: only the MRT curves
    # themselves decide whether the caller has already configured this panel
    mrt_vars = [var for var in panel['variables'] if var.startswith('MRT_')]
    if any(var in config.get('variables', [])
           for config in subplots_config for var in mrt_vars):
        return subplots_config

    configs = list(subplots_config)
    position = next((idx + 1 for idx, config in enumerate(configs)
                     if config.get('title') == 'Temperatures'), len(configs))
    configs.insert(position, panel)
    return configs


def preview_output_mpl(df, subplots_config=None, figsize=(10, 18), 
                       save_path=None, dpi=300, start=None, end=None,
                       forcing_df=None, forcing_color='black',
                       forcing_linewidth=1.5):
    """
    Preview TEB-MSU outputs using Matplotlib.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        DataFrame with model outputs (datetime index recommended).
    subplots_config : list of dict, optional
        Configuration for subplots. If None, uses DEFAULT_SUBPLOTS_CONFIG.
    figsize : tuple, optional
        Figure size (width, height) in inches.
    save_path : str, optional
        Path to save figure (.png, .pdf, etc.). If None, figure is displayed.
    dpi : int, optional
        Resolution for saved figure.
    start : str, datetime, or None, optional
        Start time for filtering DataFrame (e.g., '2024-01-01' or Timestamp).
    end : str, datetime, or None, optional
        End time for filtering DataFrame.
    forcing_df : pandas.DataFrame, optional
        Forcing data to overlay as black reference lines, indexed by time and with
        'Forc_*' columns. If None (default), the 'Forc_*' columns of `df` itself are used
        when present - recent model output already carries the forcing of every step, so
        no separate forcing file is needed. The panels that show forcing data declare
        the columns in their config with a 'forcing' key.
    forcing_color : str, optional
        Colour of the forcing curves (default 'black').
    forcing_linewidth : float, optional
        Line width of the forcing curves (default 1.5).

    Notes
    -----
    When `df` carries the pedestrian mean radiant temperature written by the
    `src_dev` tree (`MRT_ROAD`, `MRT_ROOF`), a separate panel with `T_CANYON` and
    the two MRT curves is added after the *Temperatures* panel (the forcing air
    temperature is overlaid as on the other temperature panels). Outputs without
    those columns - the control tree and older runs - keep the default set of
    panels, so the figure is unchanged for them.

    Returns:
    --------
    fig : matplotlib.figure.Figure
    axes : numpy.ndarray
    """
    
    # Filter DataFrame if time range specified
    df_plot = _filter_df_by_time(df, start, end)

    # Forcing overlay: an explicit forcing_df, otherwise the 'Forc_*' columns of df
    forcing_source = _forcing_frame(df, forcing_df)
    forcing_plot = _filter_df_by_time(forcing_source, start, end) if forcing_source is not None else None
    
    if subplots_config is None:
        subplots_config = DEFAULT_SUBPLOTS_CONFIG

    # Pedestrian MRT panel: added only when the output carries the MRT columns
    subplots_config = _with_mrt_subplot(subplots_config, df_plot)

    n_rows = len(subplots_config)
    fig, axes = plt.subplots(n_rows, 1, figsize=figsize, sharex=True)
    
    if n_rows == 1:
        axes = [axes]
    
    x = df_plot.index
    
    for idx, config in enumerate(subplots_config):
        ax = axes[idx]
        
        variables = config.get('variables', [])
        title = config.get('title', '')
        ylabel = config.get('ylabel', '')
        labels = config.get('labels', None)  # custom labels if provided
        colors = config.get('colors', None)
        linestyles = config.get('linestyles', None)
        linewidths = config.get('linewidths', None)
        
        # Filter valid variables
        valid_vars = [v for v in variables if v in df_plot.columns and not df_plot[v].isna().all()]
        
        if not valid_vars:
            ax.text(0.5, 0.5, 'No data available', ha='center', va='center', transform=ax.transAxes,
                   fontsize=12, color='gray')
            ax.set_title(title)
            ax.grid(True, alpha=0.3)
            continue
        
        # Prepare legend labels
        if labels is None:
            leg_labels = valid_vars  # use variable names
        else:
            leg_labels = [labels[i] for i, v in enumerate(variables) if v in df_plot.columns and not df_plot[v].isna().all()]
            if len(leg_labels) != len(valid_vars):
                leg_labels = valid_vars
        
        # Colors
        if colors is None:
            color_cycle = plt.rcParams['axes.prop_cycle'].by_key()['color']
            colors = [color_cycle[i % len(color_cycle)] for i in range(len(valid_vars))]
        else:
            colors = [colors[i] for i, v in enumerate(variables) if v in df_plot.columns and not df_plot[v].isna().all()]
            if len(colors) != len(valid_vars):
                color_cycle = plt.rcParams['axes.prop_cycle'].by_key()['color']
                colors = [color_cycle[i % len(color_cycle)] for i in range(len(valid_vars))]
        
        # Linestyles
        if linestyles is None:
            linestyles = ['-'] * len(valid_vars)
        else:
            linestyles = [linestyles[i] for i, v in enumerate(variables) if v in df_plot.columns and not df_plot[v].isna().all()]
            if len(linestyles) != len(valid_vars):
                linestyles = ['-'] * len(valid_vars)
        
        # Linewidths
        if linewidths is None:
            linewidths = [2] * len(valid_vars)
        else:
            linewidths = [linewidths[i] for i, v in enumerate(variables) if v in df_plot.columns and not df_plot[v].isna().all()]
            if len(linewidths) != len(valid_vars):
                linewidths = [2] * len(valid_vars)
        
        # Forcing curves (black reference lines, drawn under the model curves)
        forcing_series = _resolve_forcing_series(forcing_plot, config, color=forcing_color,
                                                 linewidth=forcing_linewidth)
        for xf, yf, f_label, f_color, f_lw in forcing_series:
            ax.plot(xf, yf, label=f_label, color=f_color, linewidth=f_lw, zorder=1)

        # Plot model outputs (on top of the forcing curves)
        for var, label, color, ls, lw in zip(valid_vars, leg_labels, colors, linestyles, linewidths):
            ax.plot(x, df_plot[var], label=label, color=color, linestyle=ls, linewidth=lw, zorder=2)
        
        if ylabel:
            ax.set_ylabel(ylabel)
        if title:
            ax.set_title(title)
        
        if len(valid_vars) + len(forcing_series) > 1:
            ax.legend(loc='upper right', fontsize=8)
        
        ax.grid(True, alpha=0.3)
    
    axes[-1].set_xlabel('Time')
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=dpi, bbox_inches='tight')
        print(f"Figure saved to: {save_path}")
    
    return fig, axes


def preview_output_plotly(df, subplots_config=None, save_path=None, height=None,
                          start=None, end=None, vertical_spacing=0.03, 
                          layout_kwargs=None, legend_side='right',
                          forcing_df=None, forcing_color='black',
                          forcing_linewidth=1.5):
    """
    Preview TEB-MSU outputs using Plotly (interactive) with grouped vertical legend.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        DataFrame with model outputs (datetime index recommended).
    subplots_config : list of dict, optional
        Configuration for subplots. If None, uses DEFAULT_SUBPLOTS_CONFIG.
    save_path : str, optional
        Path to save figure (.html recommended). If None, figure is displayed.
    height : int, optional
        Height of the figure in pixels. If None, automatically calculated.
    start : str, datetime, or None, optional
        Start time for filtering DataFrame.
    end : str, datetime, or None, optional
        End time for filtering DataFrame.
    vertical_spacing : float, optional
        Vertical spacing between subplots (default 0.03).
    layout_kwargs : dict, optional
        Additional layout parameters for fig.update_layout().
    legend_side : str, optional
        Legend placement: 'right' (default) or 'left'.
    forcing_df : pandas.DataFrame, optional
        Forcing data to overlay as black reference lines, indexed by time and with
        'Forc_*' columns. If None (default), the 'Forc_*' columns of `df` itself are used
        when present - recent model output already carries the forcing of every step, so
        no separate forcing file is needed. The panels that show forcing data declare
        the columns in their config with a 'forcing' key.
    forcing_color : str, optional
        Colour of the forcing curves (default 'black').
    forcing_linewidth : float, optional
        Line width of the forcing curves (default 1.5).

    Notes
    -----
    When `df` carries the pedestrian mean radiant temperature written by the
    `src_dev` tree (`MRT_ROAD`, `MRT_ROOF`), a separate panel with `T_CANYON` and
    the two MRT curves is added after the *Temperatures* panel (the forcing air
    temperature is overlaid as on the other temperature panels). Outputs without
    those columns - the control tree and older runs - keep the default set of
    panels, so the figure is unchanged for them.

    Returns:
    --------
    fig : plotly.graph_objects.Figure
    """
    
    try:
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
    except ImportError:
        raise ImportError("Plotly is required for preview_output_plotly. Install with: pip install plotly")
    
    # Filter DataFrame if time range specified
    df_plot = _filter_df_by_time(df, start, end)
    
    if subplots_config is None:
        subplots_config = DEFAULT_SUBPLOTS_CONFIG

    # Pedestrian MRT panel: added only when the output carries the MRT columns
    subplots_config = _with_mrt_subplot(subplots_config, df_plot)

    n_rows = len(subplots_config)

    # Forcing overlay: an explicit forcing_df, otherwise the 'Forc_*' columns of df
    forcing_source = _forcing_frame(df, forcing_df)
    forcing_plot = _filter_df_by_time(forcing_source, start, end) if forcing_source is not None else None

    if height is None:
        height = max(600, n_rows * 200)
    
    # Create subplot grid with shared x-axis
    fig = make_subplots(rows=n_rows, cols=1, shared_xaxes=True,
                        vertical_spacing=vertical_spacing,
                        subplot_titles=[cfg.get('title', '') for cfg in subplots_config])
    
    x = df_plot.index
    
    # Determine legend position
    if legend_side == 'right':
        legend_x = 1.02
        legend_xanchor = 'left'
    else:  # 'left'
        legend_x = -0.02
        legend_xanchor = 'right'
    
    for row_idx, config in enumerate(subplots_config, start=1):
        variables = config.get('variables', [])
        ylabel = config.get('ylabel', '')
        labels = config.get('labels', None)
        colors = config.get('colors', None)
        linestyles = config.get('linestyles', None)
        linewidths = config.get('linewidths', None)
        group_title = config.get('title', f'Subplot {row_idx}')
        
        # Filter valid variables
        valid_vars = [v for v in variables if v in df_plot.columns and not df_plot[v].isna().all()]
        
        if not valid_vars:
            fig.add_trace(go.Scatter(x=[], y=[], name='No data', showlegend=False), row=row_idx, col=1)
            continue
        
        # Legend labels
        if labels is None:
            leg_labels = valid_vars
        else:
            leg_labels = [labels[i] for i, v in enumerate(variables) if v in df_plot.columns and not df_plot[v].isna().all()]
            if len(leg_labels) != len(valid_vars):
                leg_labels = valid_vars
        
        # Colors
        if colors is None:
            colors = [None] * len(valid_vars)
        else:
            colors = [colors[i] for i, v in enumerate(variables) if v in df_plot.columns and not df_plot[v].isna().all()]
            if len(colors) != len(valid_vars):
                colors = [None] * len(valid_vars)
        
        # Linestyles
        if linestyles is None:
            linestyles = ['solid'] * len(valid_vars)
        else:
            linestyles = [linestyles[i] for i, v in enumerate(variables) if v in df_plot.columns and not df_plot[v].isna().all()]
            if len(linestyles) != len(valid_vars):
                linestyles = ['solid'] * len(valid_vars)
        
        # Linewidths
        if linewidths is None:
            linewidths = [2] * len(valid_vars)
        else:
            linewidths = [linewidths[i] for i, v in enumerate(variables) if v in df_plot.columns and not df_plot[v].isna().all()]
            if len(linewidths) != len(valid_vars):
                linewidths = [2] * len(valid_vars)
        
        # Forcing curves (black reference lines, added first so that the model
        # curves stay on top of them)
        forcing_series = _resolve_forcing_series(forcing_plot, config, color=forcing_color,
                                                 linewidth=forcing_linewidth)
        for xf, yf, f_label, f_color, f_lw in forcing_series:
            fig.add_trace(
                go.Scatter(
                    x=xf,
                    y=yf,
                    mode='lines',
                    name=f_label,
                    legendgroup=f"group_{row_idx}",
                    legendgrouptitle_text=group_title if row_idx == 1 else None,  # only first trace per group sets title
                    line=dict(color=f_color, width=f_lw)
                ),
                row=row_idx, col=1
            )

        # Add traces with legend group and group title
        for var, label, color, ls, lw in zip(valid_vars, leg_labels, colors, linestyles, linewidths):
            fig.add_trace(
                go.Scatter(
                    x=x,
                    y=df_plot[var],
                    mode='lines',
                    name=label,
                    legendgroup=f"group_{row_idx}",
                    legendgrouptitle_text=group_title if row_idx == 1 else None,  # only first trace per group sets title
                    line=dict(color=color, dash=ls, width=lw)
                ),
                row=row_idx, col=1
            )
        
        if ylabel:
            fig.update_yaxes(title_text=ylabel, row=row_idx, col=1)
    
    # Update x-axis label on the last subplot
    fig.update_xaxes(title_text='Time', row=n_rows, col=1)
    
    # Base layout with vertical legend on the side
    base_layout = {
        'height': height,
        'showlegend': True,
        'legend': dict(
            orientation='v',
            yanchor='middle',
            y=0.5,
            xanchor=legend_xanchor,
            x=legend_x,
            itemclick='toggleothers',
            itemdoubleclick='toggle',
            groupclick='toggleitem',
            font=dict(size=10)
        ),
        'hovermode': 'x unified',
        'margin': dict(
            l=80 if legend_side == 'left' else 60,
            r=80 if legend_side == 'right' else 60,
            t=60,
            b=60
        )
    }
    
    # Merge with user-provided layout_kwargs
    if layout_kwargs:
        base_layout.update(layout_kwargs)
    
    fig.update_layout(**base_layout)
    
    # Save or show
    if save_path:
        if save_path.endswith('.html'):
            fig.write_html(save_path)
        else:
            try:
                fig.write_image(save_path)
            except Exception as e:
                print(f"Could not save as image. Saving as HTML instead: {save_path}.html")
                fig.write_html(save_path + '.html')
        print(f"Figure saved to: {save_path}")
    
    return fig


# ----------------------------------------------------------------------------------
# Comparison of several experiments
# ----------------------------------------------------------------------------------
#: Colours of the experiments: the same colour in every panel identifies the run.
EXPERIMENT_COLORS = ['#1b9e77', '#d95f02', '#7570b3', '#e7298a', '#66a61e', '#e6ab02']
#: Line styles of the variables inside one panel (a panel usually has one variable).
VARIABLE_LINESTYLES = ['solid', 'dash', 'dot', 'dashdot']
#: Default y-label of a variable, by the prefix of its name.
_YLABEL_PREFIXES = (('MRT_', 'Temperature (K)'),
                    ('HVAC_', 'Energy (W/m²)'),
                    ('T_', 'Temperature (K)'),
                    ('Q_', 'Specific humidity (kg/kg)'),
                    ('LE_', 'Latent heat flux (W/m²)'),
                    ('H_', 'Sensible heat flux (W/m²)'),
                    ('RN_', 'Net radiation (W/m²)'),
                    ('GFLUX', 'Ground flux (W/m²)'),
                    ('U_', 'Wind speed (m/s)'),
                    ('WIND', 'Wind speed (m/s)'))


def _default_ylabel(name):
    """Default axis label of a variable ('' when the name is not recognised)."""
    for prefix, label in _YLABEL_PREFIXES:
        if str(name).startswith(prefix):
            return label
    return ''


def read_experiments(paths, fmt='auto'):
    """Read several runs into an ordered {label: DataFrame} mapping.

    `paths` is a mapping {label: output directory or CSV path} (or a list of
    (label, path) pairs); every entry is read with `read_output`, so the
    per-cell tables, the legacy `TEB_output.csv` and the legacy txt directories
    are accepted. The order of the mapping is kept: it is the order of the
    experiments in the comparison plots.
    """
    items = paths.items() if isinstance(paths, dict) else paths
    experiments = {}
    for label, path in items:
        frame = read_output(path, fmt=fmt)
        experiments[str(label)] = frame
        print(f'{label}: {len(frame)} time steps, {len(frame.columns)} variables [{path}]')
    if not experiments:
        raise ValueError('no experiments given')
    return experiments


def _experiment_list(experiments):
    """[(label, DataFrame)] from a mapping, a list of pairs or a single frame."""
    if isinstance(experiments, pd.DataFrame):
        return [('experiment', experiments)]
    items = experiments.items() if isinstance(experiments, dict) else experiments
    out = []
    for item in items:
        if (isinstance(item, (tuple, list)) and len(item) == 2
                and isinstance(item[1], pd.DataFrame)):
            out.append((str(item[0]), item[1]))
        else:
            raise TypeError('experiments must be a {label: DataFrame} mapping '
                            'or a list of (label, DataFrame) pairs')
    if not out:
        raise ValueError('no experiments given')
    return out


def _comparison_panels(variables, subplots_config):
    """Panel list of a comparison: one panel per variable unless a config is given."""
    if subplots_config is not None:
        panels = [dict(config) for config in subplots_config]
        if not panels:
            raise ValueError('subplots_config is empty')
        return panels
    if not variables:
        raise ValueError('give `variables` (one panel per variable) or `subplots_config`')
    if isinstance(variables, str):
        variables = [variables]
    return [{'variables': [var], 'title': var, 'ylabel': _default_ylabel(var)}
            for var in variables]



def compare_experiments_mpl(experiments, variables=None, subplots_config=None,
                            figsize=None, save_path=None, dpi=300, start=None, end=None,
                            title=None, linewidth=1.8):
    """Compare two or more runs with Matplotlib: one panel per variable, shared x axis.

    Parameters
    ----------
    experiments : dict {label: DataFrame} or list of (label, DataFrame)
        The runs to compare, e.g. ``{'CTRL': ctrl_df, 'ALBEDO': alb_df}`` (see
        `read_experiments`). The order is kept and defines the colours.
    variables : str or list of str, optional
        One panel per variable, e.g. ``['HVAC_COOL', 'HVAC_HEAT', 'MRT_ROAD']``.
        `subplots_config` (the format of `preview_output_mpl`) takes precedence
        when given.
    subplots_config : list of dict, optional
        Custom panels; a panel may hold several variables (the line style then
        identifies the variable, the colour the experiment).
    figsize : tuple, optional
        Figure size; by default the height grows with the number of panels.
    save_path, dpi : optional
        Saved figure and its resolution.
    start, end : optional
        Time window, as in `preview_output_mpl`.
    title : str, optional
        Figure title.
    linewidth : float, optional
        Line width of the curves.

    Returns
    -------
    fig : matplotlib.figure.Figure
    axes : numpy.ndarray of the panels

    Notes
    -----
    The colour identifies the experiment in every panel and one legend is placed
    above the figure (``experiment`` for the usual one-variable panels,
    ``experiment · variable`` when a panel carries several variables). A variable
    missing in all runs is shown as an empty panel with a note, so a comparison
    of outputs of different trees (e.g. `src_dev` with the MRT diagnostics and
    `src_ctrl` without them) still draws every requested panel.
    """
    runs = _experiment_list(experiments)
    panels = _comparison_panels(variables, subplots_config)
    plot_runs = [(label, _filter_df_by_time(frame, start, end)) for label, frame in runs]

    n_rows = len(panels)
    if figsize is None:
        figsize = (10, max(3.0, 2.2 * n_rows) + 1.4)
    fig, axes = plt.subplots(n_rows, 1, figsize=figsize, sharex=True)
    if n_rows == 1:
        axes = [axes]

    handles, labels, seen = [], [], set()
    for row, panel in enumerate(panels):
        ax = axes[row]
        panel_vars = panel.get('variables', [])
        multi = len(panel_vars) > 1
        plotted = False
        for i, (label, frame) in enumerate(plot_runs):
            color = EXPERIMENT_COLORS[i % len(EXPERIMENT_COLORS)]
            for k, var in enumerate(panel_vars):
                if var not in frame.columns or frame[var].isna().all():
                    continue
                style = VARIABLE_LINESTYLES[k % len(VARIABLE_LINESTYLES)] if multi else '-'
                line, = ax.plot(frame.index, frame[var], color=color, linestyle=style,
                                linewidth=linewidth, zorder=2)
                plotted = True
                key = (label, var) if multi else label
                if key not in seen:
                    seen.add(key)
                    handles.append(line)
                    labels.append(f'{label} · {var}' if multi else label)
        if not plotted:
            ax.text(0.5, 0.5, 'No data available', ha='center', va='center',
                    transform=ax.transAxes, fontsize=11, color='gray')
        ylabel = panel.get('ylabel') or (_default_ylabel(panel_vars[0]) if panel_vars else '')
        if ylabel:
            ax.set_ylabel(ylabel)
        ax.set_title(panel.get('title', ''))
        ax.grid(True, alpha=0.3)

    axes[-1].set_xlabel('Time')

    if handles:
        fig.legend(handles, labels, loc='upper center', ncol=min(len(labels), 4),
                   fontsize=9, frameon=False, bbox_to_anchor=(0.5, 1.0))
    if title:
        fig.suptitle(title, fontsize=12)
    top = 0.90 if title else (0.96 if handles else 1.0)
    fig.tight_layout(rect=(0, 0, 1, top))

    if save_path:
        fig.savefig(save_path, dpi=dpi, bbox_inches='tight')
        print(f'Figure saved to: {save_path}')

    return fig, axes



def compare_experiments_plotly(experiments, variables=None, subplots_config=None,
                               title=None, height=None, save_path=None, start=None, end=None,
                               vertical_spacing=0.07, legend_side='right',
                               layout_kwargs=None, linewidth=2):
    """Interactive comparison of several runs: one panel per variable, shared x axis.

    The interactive twin of `compare_experiments_mpl`: the same experiments,
    variables and panels, the colour identifies the experiment and the dash the
    variable inside a multi-variable panel. The curves of one experiment form a
    legend group (a click toggles the whole run), as in `preview_output_plotly`.

    Parameters
    ----------
    experiments, variables, subplots_config, title, save_path, start, end
        As in `compare_experiments_mpl`.
    height : int, optional
        Figure height in pixels; by default it grows with the number of panels.
    vertical_spacing : float, optional
        Spacing between the panels (default 0.07).
    legend_side : str, optional
        'right' (default) or 'left'.
    layout_kwargs : dict, optional
        Extra layout parameters of `fig.update_layout`.
    linewidth : float, optional
        Line width of the curves.

    Returns
    -------
    fig : plotly.graph_objects.Figure
    """
    try:
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
    except ImportError:
        raise ImportError("Plotly is required for compare_experiments_plotly. "
                          "Install with: pip install plotly")

    runs = _experiment_list(experiments)
    panels = _comparison_panels(variables, subplots_config)
    plot_runs = [(label, _filter_df_by_time(frame, start, end)) for label, frame in runs]

    n_rows = len(panels)
    if height is None:
        height = max(500, 240 * n_rows)

    fig = make_subplots(rows=n_rows, cols=1, shared_xaxes=True,
                        vertical_spacing=vertical_spacing,
                        subplot_titles=[panel.get('title', '') for panel in panels])

    for row, panel in enumerate(panels, start=1):
        panel_vars = panel.get('variables', [])
        multi = len(panel_vars) > 1
        for i, (label, frame) in enumerate(plot_runs):
            color = EXPERIMENT_COLORS[i % len(EXPERIMENT_COLORS)]
            for k, var in enumerate(panel_vars):
                if var not in frame.columns or frame[var].isna().all():
                    continue
                dash = VARIABLE_LINESTYLES[k % len(VARIABLE_LINESTYLES)] if multi else 'solid'
                fig.add_trace(
                    go.Scatter(
                        x=frame.index,
                        y=frame[var],
                        mode='lines',
                        name=f'{label} · {var}' if multi else label,
                        legendgroup=label,
                        legendgrouptitle_text=label,
                        line=dict(color=color, dash=dash, width=linewidth)
                    ),
                    row=row, col=1
                )
        ylabel = panel.get('ylabel') or (_default_ylabel(panel_vars[0]) if panel_vars else '')
        if ylabel:
            fig.update_yaxes(title_text=ylabel, row=row, col=1)

    fig.update_xaxes(title_text='Time', row=n_rows, col=1)

    if legend_side == 'right':
        legend_x, legend_xanchor = 1.02, 'left'
    else:
        legend_x, legend_xanchor = -0.02, 'right'

    layout = {
        'height': height,
        'showlegend': True,
        'legend': dict(
            orientation='v',
            yanchor='middle',
            y=0.5,
            xanchor=legend_xanchor,
            x=legend_x,
            itemclick='toggleothers',
            itemdoubleclick='toggle',
            groupclick='toggleitem',
            font=dict(size=10)
        ),
        'hovermode': 'x unified',
        'margin': dict(
            l=80 if legend_side == 'left' else 60,
            r=80 if legend_side == 'right' else 60,
            t=60,
            b=60
        )
    }
    if title:
        layout['title'] = dict(text=title, x=0.5, xanchor='center')
    if layout_kwargs:
        layout.update(layout_kwargs)
    fig.update_layout(**layout)

    if save_path:
        if save_path.endswith('.html'):
            fig.write_html(save_path)
        else:
            try:
                fig.write_image(save_path)
            except Exception as e:
                print(f"Could not save as image. Saving as HTML instead: {save_path}.html")
                fig.write_html(save_path + '.html')
        print(f"Figure saved to: {save_path}")

    return fig

