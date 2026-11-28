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


def split_parameters(content: str, *, defaults: dict[str, str] | None = None) -> str:
    """Regroup a flat scalar-run fixture, retaining its literal values."""
    entries = {}
    name = None
    chunks = []
    for line in content.splitlines():
        match = re.match(r"\s*([a-zA-Z]\w*)\s*=", line)
        if match or re.match(r"\s*/\s*$", line):
            if name is not None:
                if name in entries:
                    raise ValueError(f"duplicate parameter in fixture: {name}")
                entries[name] = "\n".join(chunks)
            name = match.group(1).lower() if match else None
            chunks = []
        if name is not None:
            chunks.append(line)
    if name is not None:
        raise ValueError("Parameter fixture has no terminating slash")
    if not entries:
        raise ValueError("Empty parameter fixture")
    for key, value in (defaults or {}).items():
        entries.setdefault(key, f" {key}={value},")
    options = [entries.pop("nvec", " nvec=1,")]
    options += [text for key, text in entries.items() if key in OPTION_NAMES]
    parameters = [text for key, text in entries.items() if key not in OPTION_NAMES]
    return ("&tebopts\n" + "\n".join(options) + "\n/\n"
            + "&tebparams\n" + "\n".join(parameters) + "\n/\n").replace("\n", "\r\n")


def canonicalize_legacy_selectors(content: str) -> str:
    """Translate flat-fixture keys before creating a split namelist."""
    names = {
        "teb_itype_bem": "teb_ctype_bem",
        "teb_itype_natvent": "teb_ctype_natvent",
        "teb_itype_bem_cool": "teb_ctype_bem_cool",
        "teb_itype_bem_heat": "teb_ctype_bem_heat",
        "teb_type_garden": "teb_ctype_garden",
        "teb_type_greenroof": "teb_ctype_greenroof",
        "urb_z0_town": "teb_ctype_z0_town",
        "urb_zd_town": "teb_ctype_zd_town",
        "teb_ctype_exch_road": "teb_ctype_exch_rd",
        "teb_ctype_exch_roof": "teb_ctype_exch_rf",
        "teb_tau_hw_thresh": "teb_cbs_hw_thresh",
        "teb_tau_hw_width": "teb_cbs_hw_width",
    }
    for old, new in names.items():
        content = re.sub(r"(?im)^([ \t]*)" + re.escape(old) + r"([ \t]*=)",
                         lambda match: match.group(1) + new + match.group(2), content)
    pattern = re.compile(r"(?im)^([ \t]*)teb_itype_wind([ \t]*=[ \t]*)([^!,\r\n]+)")

    def wind(match):
        value = match.group(3).strip()
        if value not in ("0", "1"):
            raise ValueError(f"unexpected legacy wind selector: {value}")
        selector = "'DEF'" if value == "0" else "'WANG'"
        return match.group(1) + "teb_ctype_wind" + match.group(2) + selector

    return pattern.sub(wind, content)
