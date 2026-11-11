#!/usr/bin/env python3
"""Compare ctrl with dev's inherited-bug build on shared configurations."""

from __future__ import annotations

import argparse
import csv
import hashlib
from itertools import zip_longest
import json
import math
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
CASE = REPO / "tests" / "CAPITOUL"
PARAM_TEMPLATE = CASE / "namelist" / "namelist.nml"
FORCING_TEMPLATE = CASE / "namelist" / "namelist_forcing.nml"
DEFAULT_OUT = REPO / "build" / "ctrl_dev_base_test"
ATOL = 1e-10
RTOL = 1e-10

# This is an explicit contract, not the accidental intersection of CSV headers.
MODEL_COLUMNS = (
    "T_ROOF1", "T_CANYON", "T_ROAD1", "T_WALLA1", "T_WALLB1", "TI_BLD",
    "Q_CANYON", "P_CANYON", "U_CANYON", "U_CAN_PED", "U_CAN_10M",
    "H_TOWN", "LE_TOWN", "RN_TOWN", "HVAC_COOL", "HVAC_HEAT",
    "USTAR_TOWN", "ALB_TOWN", "AHF_TRAFFIC", "GFLUX_TOWN", "H_WASTE",
    "SOLAR_ZENITH", "SOLAR_ELEV", "SOLAR_AZIM",
)
FORCING_COLUMNS = (
    "Forc_TA", "Forc_QA", "Forc_QV", "Forc_U", "Forc_V", "Forc_PS",
    "Forc_RHOA", "Forc_RAIN", "Forc_SNOW", "Forc_LW", "Forc_DIR_SW",
    "Forc_SCA_SW",
)
EXCLUDED_CTRL_COLUMNS = {
    "WIND_TOP": "different diagnostic meaning at teb_itype_wind=0",
    "SOLAR_PROD": "dev omits the column when solar panels are off",
}

# Every overlay is applied to the same shared CAPITOUL parameter namelist.
CASE_OVERRIDES = {
    "base": {},
    "garden": {"teb_lgarden": ".TRUE.", "fr_garden": "0.11",
               "teb_type_garden": "'PROXY_OLD'"},
    "greenroof": {"teb_lgreenroof": ".TRUE.", "teb_frac_gr": "0.3",
                  "teb_type_greenroof": "'PROXY_OLD'"},
    "garden_greenroof": {"teb_lgarden": ".TRUE.", "fr_garden": "0.11",
                         "teb_type_garden": "'PROXY_OLD'",
                         "teb_lgreenroof": ".TRUE.", "teb_frac_gr": "0.3",
                         "teb_type_greenroof": "'PROXY_OLD'"},
    "irrigation": {"teb_lroad_irrig": ".TRUE."},
    "wang_zd": {"teb_itype_wind": "1", "urb_zd_town": "'0.4H'"},
    "no_bem": {"teb_itype_bem": "'DEF'", "teb_frac_gz": "0.0"},
    "shade": {"teb_lshade": ".TRUE."},
}

# Direct active diagnostics (dev only), or case-vs-base response fields.
ACTIVITY = {
    "garden": (("H_GARDEN",), ()),
    "greenroof": (("H_GREENROOF",), ()),
    "garden_greenroof": (("H_GARDEN", "H_GREENROOF"), ()),
    "irrigation": ((), ("WS_ROAD",)),
    "wang_zd": ((), ("U_CANYON",)),
    "no_bem": ((), ("TI_BLD",)),
    "shade": ((), ("TI_BLD", "HVAC_COOL", "HVAC_HEAT")),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_template(path: Path) -> str:
    # Preserve CRLF: the offline drivers use strict Fortran namelist reads.
    with path.open("r", encoding="utf-8", newline="") as stream:
        return stream.read()


def write_template(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as stream:
        stream.write(content)


def namelist_value(content: str, key: str) -> str:
    pattern = re.compile(r"^\s*" + re.escape(key) + r"\s*=\s*([^!,\r\n]+)", re.I | re.M)
    matches = pattern.findall(content)
    if len(matches) != 1:
        raise ValueError(f"expected exactly one {key} in base namelist")
    return matches[0].strip().lower()


def set_namelist_value(content: str, key: str, value: str) -> str:
    pattern = re.compile(r"(?im)^([ \t]*" + re.escape(key) + r"[ \t]*=[ \t]*)[^!\r\n]*")
    if len(pattern.findall(content)) == 1:
        return pattern.sub(lambda match: match.group(1) + value + ",", content, count=1)
    if pattern.search(content):
        raise ValueError(f"duplicate namelist key: {key}")
    newline = "\r\n" if "\r\n" in content else "\n"
    content, count = re.subn(r"(?m)^/[ \t]*(?=\r?$)",
                             " " + key + "=" + value + "," + newline + "/", content)
    if count != 1:
        raise ValueError(f"could not insert namelist key {key}")
    return content


def prepare_namelists(out: Path, smoke_steps: int, forcing_source: Path,
                      forcing_dir: Path | None, irrigation_months: tuple[int, int] | None,
                      replacement_wind: Path | None) -> dict:
    dev_driver = (REPO / "src_dev" / "src_driver" / "run_teb_offline.F90").read_text(
        encoding="utf-8", errors="replace")
    if not re.search(r"(?im)^\s*teb_lcbs_scheme\s*=\s*\.false\.\s*!", dev_driver):
        raise ValueError("src_dev CBS default is no longer explicitly .FALSE.")
    param = read_template(PARAM_TEMPLATE)
    expected = {
        "teb_lgarden": ".false.",
        "fr_garden": "0.0",
        "teb_lgreenroof": ".false.",
        "teb_frac_gr": "0.0",
        "teb_lsolar_panel": ".false.",
        "teb_lroad_irrig": ".false.",
        "teb_itype_bem": "'bem'",
        "teb_itype_wind": "0",
    }
    for key, value in expected.items():
        actual = namelist_value(param, key)
        if actual != value:
            raise ValueError(f"base namelist has {key}={actual}, expected {value}")
    if re.search(r"^\s*teb_lcbs_scheme\s*=", param, re.I | re.M):
        raise ValueError("teb_lcbs_scheme is not a shared ctrl/dev namelist item")
    if re.search(r"^\s*teb_lshade\s*=", param, re.I | re.M):
        raise ValueError("base namelist already sets teb_lshade; review the test configuration")
    param = set_namelist_value(param, "teb_lshade", ".FALSE.")
    case_overrides = {case: dict(overrides) for case, overrides in CASE_OVERRIDES.items()}
    if irrigation_months is not None:
        start, end = irrigation_months
        case_overrides["irrigation"].update({"teb_rd_irrig_start_m": str(start),
                                             "teb_rd_irrig_end_m": str(end)})
    param_paths = {}
    for case, overrides in case_overrides.items():
        case_param = param
        for key, value in overrides.items():
            case_param = set_namelist_value(case_param, key, value)
        param_path = out / "config" / case / "namelist.nml"
        write_template(param_path, case_param)
        param_paths[case] = param_path

    forcing = read_template(forcing_source)
    full_steps = int(namelist_value(forcing, "nsteps"))
    if not 2 <= smoke_steps <= full_steps:
        raise ValueError(f"smoke-steps must be in 2..{full_steps}")
    source_forcing_dir = forcing_dir
    if forcing_dir is not None:
        if not forcing_dir.is_dir():
            raise ValueError(f"forcing directory does not exist: {forcing_dir}")
        if replacement_wind is not None:
            if not replacement_wind.is_file():
                raise ValueError(f"replacement wind file does not exist: {replacement_wind}")
            copied_dir = out / "config" / "forcing_txt"
            copied_dir.mkdir(parents=True, exist_ok=True)
            for old_file in copied_dir.glob("Forc_*.txt"):
                old_file.unlink()
            for source_file in forcing_dir.glob("Forc_*.txt"):
                shutil.copyfile(source_file, copied_dir / source_file.name)
            shutil.copyfile(replacement_wind, copied_dir / "Forc_WIND.txt")
            forcing_dir = copied_dir.resolve()
        for name in ("DIR_SW", "DIR", "LW", "PS", "QA", "RAIN", "SCA_SW",
                     "SNOW", "TA", "WIND"):
            file = forcing_dir / f"Forc_{name}.txt"
            if not file.is_file():
                raise ValueError(f"missing forcing file: {file}")
            with file.open("r", encoding="utf-8") as stream:
                rows = sum(1 for _ in stream)
            if rows < full_steps:
                raise ValueError(f"{file} has {rows} rows, expected at least {full_steps}")
        forcing = set_namelist_value(
            forcing, "forcing_path", "'" + forcing_dir.as_posix().rstrip("/") + "/'")
    elif replacement_wind is not None:
        raise ValueError("replacement wind requires an explicit or inferred forcing directory")
    smoke = set_namelist_value(forcing, "nsteps", str(smoke_steps))
    smoke_path = out / "config" / "namelist_forcing_smoke.nml"
    full_path = out / "config" / "namelist_forcing_full.nml"
    write_template(smoke_path, smoke)
    write_template(full_path, forcing)
    return {"params": param_paths, "smoke": smoke_path, "full": full_path,
            "full_steps": full_steps, "forcing_source": forcing_source,
            "forcing_dir": forcing_dir, "source_forcing_dir": source_forcing_dir,
            "replacement_wind": replacement_wind, "case_overrides": case_overrides}


def environment(toolchain_dir: Path | None) -> dict[str, str]:
    env = os.environ.copy()
    if toolchain_dir is not None:
        if not toolchain_dir.is_dir():
            raise ValueError(f"toolchain directory does not exist: {toolchain_dir}")
        env["PATH"] = str(toolchain_dir) + os.pathsep + env.get("PATH", "")
    return env


def executable(name: str, env: dict[str, str]) -> str:
    result = shutil.which(name, path=env.get("PATH"))
    if result is None:
        raise ValueError(f"{name} not found in PATH; pass --toolchain-dir")
    return result


def run_command(command: list[str], cwd: Path, env: dict[str, str], log: Path) -> None:
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8", errors="replace") as stream:
        stream.write("command: " + " ".join(command) + "\n")
        stream.write(f"cwd: {cwd}\n\n")
        stream.flush()
        result = subprocess.run(command, cwd=cwd, env=env, stdout=stream,
                                stderr=subprocess.STDOUT, check=False)
    if result.returncode:
        tail = "\n".join(log.read_text(encoding="utf-8", errors="replace").splitlines()[-18:])
        raise RuntimeError(f"command failed (rc={result.returncode}): {log}\n{tail}")


def build_binaries(out: Path, env: dict[str, str], jobs: int) -> dict[str, Path]:
    make = executable("make", env)
    executable("gfortran", env)
    binaries = {}
    for tree, label, define in (
        ("src_dev", "dev_bugs", "-DTEB_UPSTREAM_CONS_BUGS"),
        ("src_ctrl", "ctrl", ""),
    ):
        binary = (out / "bin" / ("TEB_offline_" + label + ".exe")).resolve()
        binary.parent.mkdir(parents=True, exist_ok=True)
        obj = (out / ("obj_" + label)).resolve()
        # Makefile paths are interpreted relative to the source tree.
        command = [make, "-C", str(REPO / tree), "-j", str(jobs),
                   "FC=gfortran", "LD=gfortran", f"OBJDIR={obj}",
                   f"EXEC={binary}", f"CPPDEFS={define}"]
        print(f"build {label} ...", flush=True)
        run_command(command, REPO, env, out / "logs" / ("build_" + label + ".log"))
        if not binary.is_file():
            raise RuntimeError(f"build did not create {binary}")
        binaries[label] = binary
    return binaries


def get_binaries(out: Path) -> dict[str, Path]:
    binaries = {label: out / "bin" / ("TEB_offline_" + label + ".exe")
                for label in ("dev_bugs", "ctrl")}
    for binary in binaries.values():
        if not binary.is_file():
            raise ValueError(f"missing {binary}; rerun without --skip-build")
    return binaries


def run_model(binary: Path, label: str, case: str, stage: str, forcing: Path,
              param: Path, out: Path, env: dict[str, str]) -> Path:
    output_dir = out / "runs" / case / stage / label
    output_dir.mkdir(parents=True, exist_ok=True)
    output = output_dir / ("TEB_output_b1_c1.csv" if label == "dev_bugs"
                           else "TEB_output.csv")
    output.unlink(missing_ok=True)
    log = out / "logs" / f"run_{case}_{stage}_{label}.log"
    command = [str(binary), "-forcing_nml", str(forcing),
               "-param_nml", str(param), "-output", str(output_dir)]
    print(f"run {case}/{stage} {label} ...", flush=True)
    run_command(command, CASE, env, log)
    if not output.is_file():
        raise RuntimeError(f"model did not write {output}")
    return output


def checked_header(reader: csv.DictReader, path: Path) -> list[str]:
    header = reader.fieldnames
    if header is None or len(header) != len(set(header)):
        raise ValueError(f"missing or duplicate CSV columns: {path}")
    return header


def compare_outputs(dev_csv: Path, ctrl_csv: Path, expected_rows: int,
                    case: str = "base") -> dict:
    excluded = dict(EXCLUDED_CTRL_COLUMNS)
    if case == "wang_zd":
        excluded.pop("WIND_TOP")
    if case == "no_bem":
        excluded.update({"HVAC_COOL": "dev omits HVAC without BEM",
                         "HVAC_HEAT": "dev omits HVAC without BEM",
                         "H_WASTE": "D6: uninitialized ctrl diagnostic without BEM"})
    model_columns = tuple(key for key in MODEL_COLUMNS if key not in excluded)
    if case == "wang_zd":
        model_columns += ("WIND_TOP",)
    expected_columns = ("time",) + model_columns + FORCING_COLUMNS
    stats = {key: {"text_differences": 0, "failures": 0,
                   "max_abs": 0.0, "max_rel": 0.0,
                   "first_difference": None, "first_failure": None}
             for key in model_columns}
    result = {"rows": 0, "expected_rows": expected_rows, "status": "pass",
              "columns": stats, "dev_csv": str(dev_csv), "ctrl_csv": str(ctrl_csv),
              "excluded_ctrl_columns": excluded,
              "rain_rows": 0, "snow_rows": 0,
              "road_snow_rows": 0, "roof_snow_rows": 0}
    with dev_csv.open("r", encoding="utf-8", newline="") as dstream, \
         ctrl_csv.open("r", encoding="utf-8", newline="") as cstream:
        dev, ctrl = csv.DictReader(dstream, delimiter=";"), csv.DictReader(cstream, delimiter=";")
        dhead, chead = checked_header(dev, dev_csv), checked_header(ctrl, ctrl_csv)
        for key in expected_columns:
            if key not in dhead or key not in chead:
                raise ValueError(f"required shared column {key} is missing")
        for key in ("PDN_RD", "PDN_RF"):
            if key not in dhead:
                raise ValueError(f"coverage diagnostic {key} is missing from dev")
        if not set(excluded).issubset(chead):
            raise ValueError("a documented excluded ctrl column is missing")
        if "SOLAR_PROD" in dhead:
            raise ValueError("dev unexpectedly writes SOLAR_PROD with panels off")
        if case == "no_bem" and ("HVAC_COOL" in dhead or "HVAC_HEAT" in dhead):
            raise ValueError("dev unexpectedly writes HVAC without BEM")
        unexpected = set(chead) - set(expected_columns) - set(excluded)
        if unexpected:
            raise ValueError(f"unclassified ctrl columns: {sorted(unexpected)}")
        for row_number, pair in enumerate(zip_longest(dev, ctrl), start=1):
            drow, crow = pair
            if drow is None or crow is None:
                raise ValueError(f"different output lengths, first missing row {row_number}")
            if None in drow or None in crow or any(value is None for value in drow.values()) \
                    or any(value is None for value in crow.values()):
                raise ValueError(f"malformed CSV row {row_number}")
            result["rows"] = row_number
            if drow["time"] != crow["time"]:
                raise ValueError(f"time differs at row {row_number}: {drow['time']} / {crow['time']}")
            for key in FORCING_COLUMNS:
                if drow[key] != crow[key]:
                    raise ValueError(f"forcing {key} differs at row {row_number}: {drow[key]} / {crow[key]}")
                if not math.isfinite(float(drow[key])):
                    raise ValueError(f"nonfinite forcing {key} at row {row_number}")
            result["rain_rows"] += float(drow["Forc_RAIN"]) > 0.0
            result["snow_rows"] += float(drow["Forc_SNOW"]) > 0.0
            for key, count_key in (("PDN_RD", "road_snow_rows"),
                                   ("PDN_RF", "roof_snow_rows")):
                snow_fraction = float(drow[key])
                if not math.isfinite(snow_fraction):
                    raise ValueError(f"nonfinite {key} at row {row_number}")
                result[count_key] += snow_fraction > 0.0
            for key in model_columns:
                a, b = float(drow[key]), float(crow[key])
                if not math.isfinite(a) or not math.isfinite(b):
                    raise ValueError(f"nonfinite {key} at row {row_number}: {a} / {b}")
                item = stats[key]
                if drow[key] != crow[key]:
                    item["text_differences"] += 1
                    if item["first_difference"] is None:
                        item["first_difference"] = {"row": row_number,
                                                    "time": drow["time"],
                                                    "dev": a, "ctrl": b}
                delta = abs(a - b)
                scale = max(abs(a), abs(b))
                item["max_abs"] = max(item["max_abs"], delta)
                item["max_rel"] = max(item["max_rel"], delta / scale if scale else 0.0)
                if delta > ATOL + RTOL * scale:
                    item["failures"] += 1
                    if item["first_failure"] is None:
                        item["first_failure"] = {"row": row_number, "time": drow["time"],
                                                 "dev": a, "ctrl": b, "abs": delta}
    if result["rows"] != expected_rows:
        raise ValueError(f"expected {expected_rows} rows, got {result['rows']}")
    if any(item["failures"] for item in stats.values()):
        result["status"] = "fail"
    return result


def check_activity(case: str, case_csv: Path, base_csv: Path) -> dict:
    direct, response = ACTIVITY[case]
    counts = {key: 0 for key in direct + response}
    with case_csv.open("r", encoding="utf-8", newline="") as case_stream, \
         base_csv.open("r", encoding="utf-8", newline="") as base_stream:
        case_rows = csv.DictReader(case_stream, delimiter=";")
        base_rows = csv.DictReader(base_stream, delimiter=";")
        for key in counts:
            if key not in case_rows.fieldnames or key not in base_rows.fieldnames:
                raise ValueError(f"missing activity field {key} for {case}")
        for row_number, (row, base) in enumerate(zip_longest(case_rows, base_rows), start=1):
            if row is None or base is None or row["time"] != base["time"]:
                raise ValueError(f"activity alignment failed for {case} at row {row_number}")
            for key in direct:
                value = float(row[key])
                if not math.isfinite(value):
                    raise ValueError(f"nonfinite activity {key} for {case} at row {row_number}")
                counts[key] += abs(value) > 1e-8
            for key in response:
                value, reference = float(row[key]), float(base[key])
                if not math.isfinite(value) or not math.isfinite(reference):
                    raise ValueError(f"nonfinite response {key} for {case} at row {row_number}")
                counts[key] += abs(value - reference) > 1e-8
    active = all(counts[key] > 0 for key in direct) and (not response or any(
        counts[key] > 0 for key in response))
    return {"active": active, "direct_nonzero_or_response_rows": counts}


def report_markdown(report: dict) -> str:
    lines = ["# Ctrl/dev forcing comparison", "", f"Status: **{report['status']}**",
             f"Comparison: **{report['comparison_status']}**; "
             f"case activity: **{report['activity_status']}**.",
             "", "## Configuration", "",
             "- One shared parameter namelist per case, derived from CAPITOUL; CBS off.",
             f"- Forcing namelist: `{report['forcing_source']}`; full run: {report['full_steps']} steps.",
             f"- Forcing directory: `{report['forcing_dir'] or 'from source namelist'}`.",
             f"- Source forcing directory: `{report['source_forcing_dir'] or 'from source namelist'}`.",
             f"- Replacement wind file: `{report['replacement_wind'] or 'none'}`.",
             "- src_dev: `-DTEB_UPSTREAM_CONS_BUGS`; src_ctrl: no `TEB_UPSTREAM_CONS`.",
             f"- Numeric threshold: `abs(dev-ctrl) <= {ATOL:g} + {RTOL:g} * max(abs(dev),abs(ctrl))`.",
             "- BEM-off exclusions: `HVAC_COOL`, `HVAC_HEAT` (absent from dev) and `H_WASTE` (D6 in ctrl).",
             "", "## Summary", "",
             "| case | overrides | smoke | full | active | failing columns |",
             "| --- | --- | --- | --- | --- | ---: |"]
    for case, data in report["cases"].items():
        overrides = ", ".join(f"`{key}={value}`" for key, value in
                              report["case_overrides"][case].items()) or "base"
        smoke = data.get("smoke", {}).get("status", "—")
        full = data.get("full", {}).get("status", "—")
        activity = data.get("activity", {}).get("active", "—")
        failures = sum(sum(stat["failures"] > 0 for stat in item["columns"].values())
                       for stage, item in data.items() if stage in ("smoke", "full"))
        lines.append(f"| {case} | {overrides} | {smoke} | {full} | {activity} | {failures} |")
    lines.extend(["", "## Inputs and executables", ""])
    for key, value in report["sha256"].items():
        lines.append(f"- `{key}`: `{value}`")
    for case, data in report["cases"].items():
        lines.extend(["", f"## {case}", ""])
        activity = data.get("activity")
        if activity:
            lines.append(f"Activity: **{'yes' if activity['active'] else 'no'}**; "
                         + ", ".join(f"{key}: {count} rows" for key, count in
                                     activity["direct_nonzero_or_response_rows"].items()))
        for stage in ("smoke", "full"):
            if stage not in data:
                continue
            item = data[stage]
            lines.extend(["", f"### {stage}: {item['status']} ({item['rows']}/{item['expected_rows']} rows)",
                      "", f"Forcing rows with rain: {item['rain_rows']}; with snow: {item['snow_rows']}.",
                      f"Dev rows with road snow: {item['road_snow_rows']}; with roof snow: {item['roof_snow_rows']}.",
                      "Excluded ctrl columns: " + ", ".join(
                          f"`{key}` ({reason})" for key, reason in item["excluded_ctrl_columns"].items()) + ".",
                      "", "| column | text differences | failures | max abs | max rel | first difference | first failure |",
                      "| --- | ---: | ---: | ---: | ---: | --- | --- |"])
            for key, stat in item["columns"].items():
                initial = stat["first_difference"]
                first = stat["first_failure"]
                earliest = "" if initial is None else f"{initial['row']} ({initial['time']})"
                location = "" if first is None else f"{first['row']} ({first['time']})"
                lines.append(f"| {key} | {stat['text_differences']} | {stat['failures']} | "
                             f"{stat['max_abs']:.6g} | {stat['max_rel']:.6g} | {earliest} | {location} |")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--toolchain-dir", type=Path)
    parser.add_argument("--forcing-nml", type=Path, default=FORCING_TEMPLATE,
                        help="source forcing namelist (default: CAPITOUL)")
    parser.add_argument("--forcing-dir", type=Path,
                        help="forcing data directory; inferred from a custom namelist's forcing_txt/")
    parser.add_argument("--replacement-wind", type=Path,
                        help="replace Forc_WIND.txt in a generated copy of the forcing directory")
    parser.add_argument("--irrigation-months", nargs=2, type=int, metavar=("START", "END"),
                        help="override the road irrigation schedule in the irrigation case")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--smoke-steps", type=int, default=101,
                        help="forcing nsteps; output has nsteps-1 rows")
    parser.add_argument("--smoke-only", action="store_true")
    parser.add_argument("--skip-build", action="store_true")
    args = parser.parse_args()
    if args.smoke_steps < 2 or args.jobs < 1:
        parser.error("smoke-steps must be at least 2 and jobs must be positive")
    if args.irrigation_months and any(not 1 <= month <= 12 for month in args.irrigation_months):
        parser.error("irrigation months must be in 1..12")
    out = args.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    for name in ("report.md", "report.json", "error.txt"):
        (out / name).unlink(missing_ok=True)
    try:
        env = environment(args.toolchain_dir.resolve() if args.toolchain_dir else None)
        forcing_source = args.forcing_nml.resolve()
        forcing_dir = args.forcing_dir.resolve() if args.forcing_dir else None
        if forcing_dir is None and forcing_source != FORCING_TEMPLATE:
            forcing_dir = forcing_source.parent / "forcing_txt"
        replacement_wind = args.replacement_wind.resolve() if args.replacement_wind else None
        paths = prepare_namelists(out, args.smoke_steps, forcing_source, forcing_dir,
                                  tuple(args.irrigation_months) if args.irrigation_months else None,
                                  replacement_wind)
        binaries = get_binaries(out) if args.skip_build else build_binaries(out, env, args.jobs)
        report = {"status": "pass", "comparison_status": "pass", "activity_status": "pass",
                  "cases": {case: {} for case in CASE_OVERRIDES},
                  "forcing_source": str(paths["forcing_source"]),
                  "forcing_dir": str(paths["forcing_dir"]) if paths["forcing_dir"] else None,
                  "source_forcing_dir": str(paths["source_forcing_dir"])
                  if paths["source_forcing_dir"] else None,
                  "replacement_wind": str(replacement_wind) if replacement_wind else None,
                  "full_steps": paths["full_steps"], "case_overrides": paths["case_overrides"],
                  "sha256": {
            "source_forcing_namelist": sha256(forcing_source),
            "smoke_forcing_namelist": sha256(paths["smoke"]),
            "full_forcing_namelist": sha256(paths["full"]),
            "dev_bugs_exe": sha256(binaries["dev_bugs"]),
            "ctrl_exe": sha256(binaries["ctrl"]),
        }}
        for case, param in paths["params"].items():
            report["sha256"][case + "_param_namelist"] = sha256(param)
        if forcing_dir is not None:
            if replacement_wind is not None:
                report["sha256"]["source_Forc_WIND.txt"] = sha256(
                    paths["source_forcing_dir"] / "Forc_WIND.txt")
                report["sha256"]["replacement_Forc_WIND.txt"] = sha256(replacement_wind)
            for forcing_file in sorted(paths["forcing_dir"].glob("Forc_*.txt")):
                report["sha256"][forcing_file.name] = sha256(forcing_file)
        stages = (("smoke", args.smoke_steps),) if args.smoke_only else (
            ("smoke", args.smoke_steps), ("full", paths["full_steps"]))
        for stage, steps in stages:
            base_dev_csv = None
            for case, param in paths["params"].items():
                outputs = {}
                for label in ("dev_bugs", "ctrl"):
                    outputs[label] = run_model(binaries[label], label, case, stage,
                                               paths[stage], param, out, env)
                item = compare_outputs(outputs["dev_bugs"], outputs["ctrl"], steps - 1, case)
                report["cases"][case][stage] = item
                if case == "base":
                    base_dev_csv = outputs["dev_bugs"]
                elif stage == "full":
                    activity = check_activity(case, outputs["dev_bugs"], base_dev_csv)
                    report["cases"][case]["activity"] = activity
                    if not activity["active"]:
                        report["status"] = "fail"
                        report["activity_status"] = "fail"
                nfail = sum(v["failures"] > 0 for v in item["columns"].values())
                print(f"{case}/{stage}: {item['status']}, {item['rows']} rows, "
                      f"{nfail} failing columns", flush=True)
                if item["status"] != "pass":
                    report["status"] = "fail"
                    report["comparison_status"] = "fail"
        (out / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        (out / "report.md").write_text(report_markdown(report), encoding="utf-8")
        print(f"report: {out / 'report.md'}", flush=True)
        return 0 if report["status"] == "pass" else 1
    except (ValueError, RuntimeError, OSError) as error:
        (out / "error.txt").write_text(str(error) + "\n", encoding="utf-8")
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
