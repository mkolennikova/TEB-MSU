"""Shared namelist layout for the offline regression tests."""

from __future__ import annotations

import re


OPTION_NAMES = frozenset((
    "nvec", "dt", "teb_nroof_layer", "teb_nroad_layer", "teb_nwall_layer",
    "teb_lbem_ac", "teb_lshade", "teb_lgarden", "teb_lgreenroof",
    "teb_lsolar_panel", "teb_lroad_irrig", "teb_snow_check", "teb_lcbs_scheme",
    "teb_cbs_hw_thresh", "teb_cbs_hw_width",
    "teb_ctype_bem", "teb_ctype_natvent", "teb_ctype_bem_cool", "teb_ctype_bem_heat",
    "teb_ctype_wind", "teb_ctype_garden", "teb_ctype_greenroof", "teb_ctype_z0_town",
    "teb_ctype_zd_town", "teb_ctype_z0_town_dyncorr", "teb_ctype_zd_town_dyncorr",
    "teb_ctype_exch_rd", "teb_ctype_exch_rf", "teb_ctype_exch_canyon",
    "teb_ctype_z0_o_z0h_rd", "teb_ctype_z0_o_z0h_rf", "teb_ctype_z0_o_z0h_town",
    "teb_hroad_dir", "teb_wall_opt",
    "teb_lwrite_output", "teb_lwrite_emu", "teb_lwrite_runoff", "teb_lwrite_test_dump",
))

# These values reproduce the shared aerodynamic defaults of the two drivers.
AERODYNAMIC_DEFAULTS = {
    "teb_ctype_exch_rd": "'MASC95'",
    "teb_ctype_exch_rf": "'MASC95'",
    "teb_ctype_exch_canyon": "'MASC95'",
    "teb_ctype_z0_town": "'0.1H'",
    "teb_ctype_zd_town": "'H/3'",
    "teb_ctype_z0_o_z0h_rd": "'200'",
    "teb_ctype_z0_o_z0h_rf": "'200'",
    "teb_ctype_z0_o_z0h_town": "'200'",
    "urb_z0_rd": "0.05",
    "urb_z0_rf": "0.15",
    "urb_z0_snow": "0.001",
    "urb_z0_o_z0h_gdn": "4.0",
}


def find_group(lines: list[str], group: str) -> tuple[int, int]:
    """Return (start, end) line indices of ``&group`` ... ``/``."""
    token = '&' + group.lower()
    start = None
    for i, line in enumerate(lines):
        if line.partition('!')[0].strip().lower() == token:
            start = i
            break
    if start is None:
        raise SystemExit(f'ERROR: namelist group &{group} not found')
    for j in range(start + 1, len(lines)):
        if lines[j].strip().startswith('/'):
            return start, j
    raise SystemExit(f'ERROR: namelist group &{group} has no terminating /')


def _replace_item(line: str, key: str, value: str) -> str | None:
    """Replace ``key = ...`` in a single namelist line, or return None."""
    code, sep, comment = line.partition('!')
    pattern = re.compile(
        r'^(\s*)(' + re.escape(key) + r')(\s*=\s*)(.*?)(\s*),?\s*$', re.I)
    m = pattern.match(code)
    if not m:
        return None
    prefix, name, eq = m.group(1), m.group(2), m.group(3)
    tail = ''
    if sep:
        tail = ' !' + comment
    return f'{prefix}{name}{eq}{value},{tail}'.rstrip()


def apply_namelist_overrides(text: str, group: str, overrides: dict[str, str]) -> str:
    """Apply ``overrides`` to one namelist group, preserving the rest.

    A missing item is inserted just before the terminating ``/`` of the group.
    """
    newline = '\r\n' if '\r\n' in text else '\n'
    lines = text.replace('\r\n', '\n').split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    start, end = find_group(lines, group)
    for key, value in overrides.items():
        replaced = False
        for i in range(start + 1, end):
            new_line = _replace_item(lines[i], key, value)
            if new_line is not None:
                lines[i] = new_line
                replaced = True
                break
        if not replaced:
            # Insert before the terminating '/'. The previous item must be
            # terminated by a comma (a newline is also a valid Fortran namelist
            # separator, but the generated file is easier to audit when every
            # item ends with a comma).
            prev = end - 1
            while prev > start and (not lines[prev].strip()
                                    or lines[prev].strip().startswith('!')):
                prev -= 1
            code, sep, comment = lines[prev].partition('!')
            if prev > start and not code.rstrip().endswith(','):
                tail = (' !' + comment) if sep else ''
                lines[prev] = code.rstrip() + ',' + tail
            lines.insert(end, f' {key}={value},')
            end += 1
    return newline.join(lines) + newline


def group_values(text: str, group: str) -> dict[str, str]:
    """Return ``{lowercase item: raw value}`` of one namelist group."""
    lines = text.replace('\r\n', '\n').split('\n')
    start, end = find_group(lines, group)
    values: dict[str, str] = {}
    duplicates = []
    for line in lines[start + 1:end]:
        code = line.partition('!')[0]
        m = re.match(r'\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*,?\s*$', code)
        if not m:
            continue
        key = m.group(1).lower()
        if key in values:
            duplicates.append(key)
        values[key] = m.group(2).strip()
    if duplicates:
        raise SystemExit(f'ERROR: duplicate namelist items in &{group}: '
                         f'{duplicates}')
    return values


def apply_model_overrides(text: str, overrides: dict[str, str], *,
                          defaults: dict[str, str] | None = None) -> str:
    """Edit a model fixture, placing each scalar or list in its proper group."""
    if re.search(r"(?im)^[ \t]*&tebparam\b", text):
        raise ValueError("&tebparam is no longer supported. Use &tebopts and &tebparams.")
    if not re.search(r"(?im)^[ \t]*&tebopts\b", text):
        newline = '\r\n' if '\r\n' in text else '\n'
        text = newline.join(('&tebopts', '/', text))
    for group, is_option in (('tebopts', True), ('tebparams', False)):
        existing = group_values(text, group)
        edits = {name: value for name, value in (defaults or {}).items()
                 if (name in OPTION_NAMES) == is_option and name not in existing}
        edits.update((name, value) for name, value in overrides.items()
                     if (name in OPTION_NAMES) == is_option)
        text = apply_namelist_overrides(text, group, edits)
    return text


def read_model_namelist(path):
    """Load the split model groups for callers already using f90nml."""
    import f90nml

    nml = f90nml.read(str(path))
    if 'tebparam' in nml:
        raise ValueError(f"{path}: &tebparam is no longer supported. Use &tebopts and &tebparams.")
    if 'tebparams' not in nml:
        raise ValueError(f"{path}: missing &tebparams")
    nml.setdefault('tebopts', {})
    return nml
