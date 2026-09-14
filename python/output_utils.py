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


def read_output (output_dir, namelist_path=None, fmt='auto', include_forcing=True):
  """Read the output of a TEB-Ru offline run.

  Two formats are supported:

  * ``'csv'`` - the current output: a single semicolon-separated file
    ``TEB_output.csv`` with a header line. Column 1 is ``time`` (the time of the model
    state, i.e. the end of the forcing interval, ``t0 + n * forc_step``), then the
    model variables, then the atmospheric forcing used by the model at that step
    (columns ``Forc_*``).
  * ``'txt'`` - the legacy output: one ``<VARIABLE>.txt`` file per variable with one
    value per forcing step (no time stamps; the index is reconstructed from the
    forcing namelist).

  Parameters
  ----------
  output_dir : str
      Directory with the output (with or without a trailing separator).
  namelist_path : str, optional
      Forcing namelist. Required for the legacy txt format only, because the CSV file
      carries its own time stamps.
  fmt : {'auto', 'csv', 'txt'}
      'auto' (default) reads ``TEB_output.csv`` when it is present, otherwise the
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
  output_dir = str(output_dir)
  if not output_dir.endswith((os.sep, '/')):
    output_dir += os.sep
  csv_file = os.path.join(output_dir, 'TEB_output.csv')

  fmt = fmt.lower()
  if fmt == 'auto':
    fmt = 'csv' if os.path.isfile(csv_file) else 'txt'
  if fmt not in ('csv', 'txt'):
    raise ValueError(f"fmt must be 'auto', 'csv' or 'txt', got {fmt!r}")

  if fmt == 'txt':
    if namelist_path is None:
      raise ValueError('namelist_path is required to read the legacy txt output')
    return read_output_txt(output_dir, namelist_path)

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
# Optional 'forcing' entries overlay the corresponding columns of forcing_df
# as black reference lines (see preview_output_mpl / preview_output_plotly)
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
    Each entry is looked up in `forcing_df` (a DataFrame with 'Forc_*' columns, e.g.
    from forcing_utils.read_forcing). The keys 'color' and 'linewidth' of an entry
    override the function-level defaults; the forcing lines are always solid.

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


def preview_output_mpl(df, subplots_config=None, figsize=(10, 18), 
                       save_path=None, dpi=300, start=None, end=None,
                       forcing_df=None, forcing_color='black',
                       forcing_linewidth=1.5):
    """
    Preview TEB-Ru outputs using Matplotlib.
    
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
        'Forc_*' columns (e.g. from forcing_utils.read_forcing). The panels that show
        forcing data declare the columns in their config with a 'forcing' key; if
        forcing_df is None (default) nothing is overlaid.
    forcing_color : str, optional
        Colour of the forcing curves (default 'black').
    forcing_linewidth : float, optional
        Line width of the forcing curves (default 1.5).
    
    Returns:
    --------
    fig : matplotlib.figure.Figure
    axes : numpy.ndarray
    """
    
    # Filter DataFrame if time range specified
    df_plot = _filter_df_by_time(df, start, end)

    # Forcing data are filtered with the same time range
    forcing_plot = _filter_df_by_time(forcing_df, start, end) if forcing_df is not None else None
    
    if subplots_config is None:
        subplots_config = DEFAULT_SUBPLOTS_CONFIG
    
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
    Preview TEB-Ru outputs using Plotly (interactive) with grouped vertical legend.
    
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
        'Forc_*' columns (e.g. from forcing_utils.read_forcing). The panels that show
        forcing data declare the columns in their config with a 'forcing' key; if
        forcing_df is None (default) nothing is overlaid.
    forcing_color : str, optional
        Colour of the forcing curves (default 'black').
    forcing_linewidth : float, optional
        Line width of the forcing curves (default 1.5).
    
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
    
    n_rows = len(subplots_config)
    
    # Forcing data are filtered with the same time range
    forcing_plot = _filter_df_by_time(forcing_df, start, end) if forcing_df is not None else None

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
