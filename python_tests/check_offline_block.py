#!/usr/bin/env python3
"""Exercise the runtime-sized src_dev offline host against separate processes.

All generated files belong to --out-root (outside the checkout). Uses the Python
standard library and GNU Fortran/Make. --exe skips the regular build; memory
instrumentation still requires its matching objects and compiler. Includes the
full nvec=1,2,7,16,31 matrix, sensitivity, masks, restart and file forcing.
No reference outputs or model sources are modified.
"""
from __future__ import annotations

import argparse
from array import array
import csv
from dataclasses import dataclass
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import struct
import sys
import time

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
PROFILES = ('DEF', 'BEM', 'WANG', 'CBS', 'BEM_WANG', 'GARDEN_EXT',
            'GARDEN_NEU', 'ROOF_EXT', 'ROOF_NEU', 'COMBINED_EXT', 'SNOW')
SIZES = (1, 2, 7, 16, 31)
# Observable thresholds are in the native API units, chosen before the run.
MODIFICATIONS = (
    ('DEF', 'ahf_traffic', 2., 0., 0, ('ahf_traffic_now', 'teb_shfl'), 1.e-6),
    ('DEF', 'urb_alb_rf_so', 1., .15, 0, ('teb_alb_so', 'teb_tsroof'), 1.e-6),
    ('DEF', 'urb_hcap_rd', 2., 0., 0, ('teb_troad[1]',), 1.e-6),
    ('DEF', 'urb_h2w', 1., .3, 0, ('teb_wind_canyon', 'teb_shfl'), 1.e-6),
    ('CBS', 'urb_h2w', 1., .3, 0, ('teb_wind_canyon', 'teb_shfl'), 1.e-6),
    ('DEF', 'u', 1., 1., 0, ('teb_wind_canyon',), 1.e-8),
    ('WANG', 'u', 1., 1., 0, ('teb_wind_canyon', 'teb_ustar_town'), 1.e-8),
    ('DEF', 't', 1., 2., 0, ('teb_shfl', 'teb_tcanyon'), 1.e-6),
    ('DEF', 'teb_troad_top', 1., 2., 6, ('teb_troad[1]', 'teb_shfl'), 1.e-6),
    ('ROOF_EXT', 'teb_z0_gr', 2., 0., 0, ('teb_cd_greenroof_atm', 'teb_shfl'), 1.e-8),
)


def external(path: Path) -> Path:
    path = path.expanduser().resolve()
    if path == ROOT or path.is_relative_to(ROOT):
        raise ValueError(f'Artifacts must be outside the checkout: {path}')
    return path


def nml_value(value):
    if isinstance(value, bool):
        return '.TRUE.' if value else '.FALSE.'
    if isinstance(value, str):
        return "'" + value.replace('\\', '/').replace("'", "''") + "'"
    return repr(value)


def write_nml(path, group, values):
    text = '&' + group + '\n' + ''.join(
        f' {key}={nml_value(value)},\n' for key, value in values.items()) + '/\n'
    path.write_text(text, encoding='utf-8')


def command(args, cwd, log, env, marker=None):
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run([str(x) for x in args], cwd=cwd, env=env,
                                stdout=stream, stderr=subprocess.STDOUT, check=False)
    text = log.read_text(encoding='utf-8', errors='replace')
    if result.returncode or (marker and marker not in text):
        raise RuntimeError(f'Command failed ({result.returncode}), see {log}\n{text[-2200:]}')
    if re.search(r'(?im)^.*(?:Error:|Error \d+ \(ignored\)).*$', text):
        raise RuntimeError(f'Error reported despite successful exit: {log}')


@dataclass
class Record:
    meta: tuple
    data: array


class Dump:
    def __init__(self, directory):
        self.directory = directory
        with (directory / 'fields.csv').open(encoding='utf-8', newline='') as stream:
            self.schema = list(csv.DictReader(stream, delimiter=';'))
        self.names = [s['name'] for s in self.schema]
        for role, expected in (('INOUT', 33), ('OUT', 53)):
            names = {s['name'].split('[')[0] for s in self.schema if s['intent'] == role}
            if len(names) != expected:
                raise AssertionError(f'API contract changed: {role}={len(names)}, expected {expected}')
        self.outputs = [i for i, s in enumerate(self.schema) if s['intent'] in ('INOUT', 'OUT')]
        self.states = [i for i, s in enumerate(self.schema) if s['intent'] == 'INOUT']
        path = directory / 'records.bin'
        self.records = []
        with path.open('rb') as stream:
            header = struct.unpack('<4i', stream.read(16))
            if list(header) != [1413825073, 1, len(self.schema), 8]:
                raise AssertionError(f'Invalid REAL64 dump header: {path}: {header}')
            record_bytes = 24 + 8 * len(self.schema)
            if (path.stat().st_size - 16) % record_bytes:
                raise AssertionError(f'Truncated record: {path}')
            while packet := stream.read(record_bytes):
                data = array('d')
                data.frombytes(packet[24:])
                if sys.byteorder != 'little':
                    data.byteswap()
                self.records.append(Record(struct.unpack('<6i', packet[:24]), data))
        if not self.records or not all(math.isfinite(x) for r in self.records for x in r.data):
            raise AssertionError(f'Empty or nonfinite dump: {path}')
        self.after = [r for r in self.records if r.meta[5] == 1]
        self.before = [r for r in self.records if r.meta[5] == 0]
        if len(self.after) != len(self.before):
            raise AssertionError(f'Before/after record counts differ: {path}')
        self.by_key = {r.meta[:3]: r for r in self.after}
        self.cells = {r.meta[2] for r in self.after}
        if len(self.by_key) != len(self.after):
            raise AssertionError(f'Duplicate cell/time records: {path}')
        marker = (directory / 'completed.txt').read_text(encoding='utf-8').split()
        if len(marker) != 6 or marker[0] != 'BLOCK_COMPLETED':
            raise AssertionError(f'Invalid completion marker: {directory}')
        self.first, self.last, self.nvec, self.nblocks, count = map(int, marker[1:])
        if count != len(self.schema) or len(self.after) != (self.last - self.first + 1) * self.nvec * self.nblocks:
            raise AssertionError(f'Incomplete cell/time coverage: {directory}')
        expected = {(s, b, c) for s in range(self.first, self.last + 1)
                    for b in range(1, self.nblocks + 1) for c in self.cells}
        if len(self.cells) != self.nvec or self.by_key.keys() != expected:
            raise AssertionError(f'Incomplete logical cell IDs: {directory}')
        if any(not 1 <= r.meta[3] <= self.nvec or r.meta[4] not in (0, 1) for r in self.after):
            raise AssertionError(f'Invalid native index or active flag: {directory}')

    def field(self, name):
        return self.names.index(name)


def equal_values(actual, expected, fields, names, metadata, context):
    for field in fields:
        if actual[field] != expected[field]:
            step, block, cell = metadata[:3]
            raise AssertionError(f'{context}: step={step}, block={block}, cell={cell}, '
                                 f'field={names[field]}, expected={expected[field]:.17g}, '
                                 f'actual={actual[field]:.17g}')


def compare_reference(dump, references):
    count = 0
    for record in dump.after:
        step, block, cell, _, active, _ = record.meta
        if not active:
            continue
        reference = references[cell]
        if reference.schema != dump.schema:
            raise AssertionError('The API dump schemas differ')
        expected = reference.by_key[(step, block, cell if cell in reference.cells else 1)]
        equal_values(record.data, expected.data, dump.outputs, dump.names,
                     record.meta, str(dump.directory))
        count += len(dump.outputs)
    return count


def inactive_preserved(dump):
    count = 0
    for before, after in zip(dump.before, dump.after):
        if before.meta[:5] != after.meta[:5]:
            raise AssertionError('Input/output indexing differs')
        if after.meta[4]:
            continue
        equal_values(after.data, before.data, dump.states, dump.names,
                     after.meta, 'Inactive state changed')
        count += len(dump.states)
    return count


# Explicit fixtures replace the former hard-coded Fortran profile defaults.
# Values were captured from the pre-unification host's input namelists.
BASE_PARAMETERS = {'dt': '3.00000000000000000E+002',
 'urb_h_bld': '1.20000000000000000E+001',
 'urb_fr_bld': '4.00000000000000022E-001',
 'fr_garden': '0.00000000000000000E+000',
 'urb_h2w': '5.99999999999999978E-001',
 'teb_road_dir': '0.00000000000000000E+000',
 'teb_hroad_dir': "'UNIF'",
 'teb_wall_opt': "'UNIF'",
 'urb_alb_rf_so': '4.00000000000000022E-001',
 'urb_alb_rf_th': '2.99999999999999989E-002',
 'urb_hcap_rf': '1.58000000000000000E+006',
 'urb_hcon_rf': '1.14999999999999991E+000',
 'urb_alb_rd_so': '8.00000000000000017E-002',
 'urb_alb_rd_th': '4.00000000000000008E-002',
 'urb_hcap_rd': '1.74000000000000000E+006',
 'urb_hcon_rd': '8.19999999999999951E-001',
 'urb_alb_wl_so': '3.20000000000000007E-001',
 'urb_alb_wl_th': '2.99999999999999989E-002',
 'urb_hcap_wl': '1.58000000000000000E+006',
 'urb_hcon_wl': '1.14999999999999991E+000',
 'teb_ctype_bem': "'DEF'",
 'teb_lbem_ac': 'T',
 'teb_ctype_natvent': "'NONE'",
 'teb_ctype_bem_cool': "'IDEAL'",
 'teb_ctype_bem_heat': "'IDEAL'",
 'teb_frac_gz': '0.00000000000000000E+000',
 'teb_tcool_target': '2.97160000000000025E+002',
 'teb_theat_target': '2.92160000000000025E+002',
 'teb_zresidential': '1.00000000000000000E+000',
 'teb_dt_res': '0.00000000000000000E+000',
 'teb_dt_off': '0.00000000000000000E+000',
 'teb_bem_inf': '5.00000000000000000E-001',
 'teb_bem_vent': '0.00000000000000000E+000',
 'teb_bem_cop': '2.50000000000000000E+000',
 'teb_cap_sys_rat': '1.00000000000000000E+002',
 'teb_m_sys_rat': '6.70000000000000023E-003',
 'teb_cap_sys_heat': '9.00000000000000000E+001',
 'ahf_traffic': '2.00000000000000000E+001',
 'ahf_industry': '5.00000000000000000E+000',
 'teb_ctype_wind': "'DEF'",
 'teb_fai': '5.00000000000000000E-001,  5.00000000000000000E-001,  5.00000000000000000E-001,  '
            '5.00000000000000000E-001,  5.00000000000000000E-001,  5.00000000000000000E-001,  '
            '5.00000000000000000E-001,  5.00000000000000000E-001',
 'teb_lgarden': 'F',
 'teb_ctype_garden': "'PROXY_NEW'",
 'urb_z0_o_z0h_gdn': '4.00000000000000000E+000',
 'teb_lgreenroof': 'F',
 'teb_ctype_greenroof': "'PROXY_NEW'",
 'teb_frac_gr': '0.00000000000000000E+000',
 'urb_z0_o_z0h_grf': '4.00000000000000000E+000',
 'teb_lsolar_panel': 'F',
 'teb_fr_panel': '0.00000000000000000E+000',
 'teb_lroad_irrig': 'F',
 'teb_rd_irrig_start_m': '0.00000000000000000E+000',
 'teb_rd_irrig_end_m': '0.00000000000000000E+000',
 'teb_rd_irrig_start_h': '0.00000000000000000E+000',
 'teb_rd_irrig_end_h': '0.00000000000000000E+000',
 'teb_rd_irrig_sum': '0.00000000000000000E+000',
 'teb_utc_hour': '0',
 'teb_lshade': 'F',
 'teb_ctype_z0_town': "'0.1H'",
 'urb_zd_town': "'H/3'",
 'teb_lcbs_scheme': 'F',
 'teb_tau_hw_thresh': '5.00000000000000000E-001',
 'teb_tau_hw_width': '2.50000000000000000E-001',
 'teb_ti_bld_init': '2.97160000000000025E+002',
 'teb_qi_bld_init': '7.00000000000000015E-003'}
PROFILE_OVERRIDES = {'DEF': {},
 'BEM': {'teb_ctype_bem': "'BEM'", 'teb_frac_gz': '2.00000000000000011E-001'},
 'WANG': {'teb_ctype_wind': "'WANG'"},
 'CBS': {'teb_lcbs_scheme': 'T'},
 'BEM_WANG': {'teb_ctype_bem': "'BEM'",
              'teb_frac_gz': '2.00000000000000011E-001',
              'teb_ctype_wind': "'WANG'"},
 'GARDEN_EXT': {'fr_garden': '2.00000000000000011E-001',
                'teb_lgarden': 'T',
                'teb_ctype_garden': "'EXT'",
                'teb_lcbs_scheme': 'T'},
 'GARDEN_NEU': {'fr_garden': '2.00000000000000011E-001',
                'teb_lgarden': 'T',
                'teb_ctype_garden': "'EXT_NEU'",
                'teb_lcbs_scheme': 'T'},
 'ROOF_EXT': {'teb_lgreenroof': 'T',
              'teb_ctype_greenroof': "'EXT'",
              'teb_frac_gr': '3.49999999999999978E-001',
              'teb_lcbs_scheme': 'T'},
 'ROOF_NEU': {'teb_lgreenroof': 'T',
              'teb_ctype_greenroof': "'EXT_NEU'",
              'teb_frac_gr': '3.49999999999999978E-001',
              'teb_lcbs_scheme': 'T'},
 'COMBINED_EXT': {'fr_garden': '2.00000000000000011E-001',
                  'teb_lgarden': 'T',
                  'teb_ctype_garden': "'EXT'",
                  'teb_lgreenroof': 'T',
                  'teb_ctype_greenroof': "'EXT'",
                  'teb_frac_gr': '3.49999999999999978E-001',
                  'teb_lcbs_scheme': 'T'},
 'SNOW': {}}
OPTION_NAMES = {'dt',
 'teb_hroad_dir',
 'teb_ctype_bem',
 'teb_ctype_bem_cool',
 'teb_ctype_bem_heat',
 'teb_ctype_natvent',
 'teb_ctype_wind',
 'teb_ctype_z0_town',
 'teb_ctype_exch_rd',
 'teb_ctype_exch_rf',
 'teb_ctype_exch_canyon',
 'teb_ctype_z0_o_z0h_rd',
 'teb_ctype_z0_o_z0h_rf',
 'teb_ctype_z0_o_z0h_town',
 'teb_lbem_ac',
 'teb_lcbs_scheme',
 'teb_lgarden',
 'teb_lgreenroof',
 'teb_lroad_irrig',
 'teb_lshade',
 'teb_lsolar_panel',
 'teb_snow_check',
 'teb_ctype_garden',
 'teb_ctype_greenroof',
 'teb_wall_opt'}


def write_physics(path, cfg, overrides=None):
    values = dict(BASE_PARAMETERS)
    values.update(PROFILE_OVERRIDES[cfg['profile']])
    values['dt'] = repr(cfg.get('dt', 300.))
    if overrides:
        values.update(overrides)
        values = {name: value for name, value in values.items() if value is not None}
        for surface in ('rf', 'rd', 'wl'):
            if 'urb_emis_' + surface in overrides:
                values.pop('urb_alb_' + surface + '_th', None)
    enabled = nml_value(cfg.get('model_log', False))
    opts = dict(nvec=str(cfg['nvec']), teb_lwrite_output=enabled,
                teb_lwrite_emu=enabled, teb_lwrite_runoff=enabled,
                teb_lwrite_test_dump='.TRUE.')
    opts.update((name, value) for name, value in values.items() if name in OPTION_NAMES)
    params = {name: value for name, value in values.items() if name not in OPTION_NAMES}
    text = '&tebopts\n' + ''.join(f' {k}={v},\n' for k, v in opts.items()) + '/\n'
    text += '&tebparams\n' + ''.join(f' {k}={v},\n' for k, v in params.items()) + '/\n'
    path.write_text(text, encoding='utf-8')


class Suite:
    def __init__(self, work, exe, ordinary, env, quick):
        self.work, self.exe, self.ordinary, self.env = work, exe, ordinary, env
        self.quick = quick
        self.entries, self.cache = [], {}
        self.comparisons = 0
        self.runs = 0

    def run(self, **updates):
        cfg = dict(nvec=1, nblocks=1, nsteps=48, profile='DEF')
        cfg.update(updates)
        key = json.dumps(cfg, sort_keys=True)
        if key in self.cache:
            return self.cache[key]
        digest = hashlib.sha256(key.encode()).hexdigest()[:16]
        directory = self.work / 'runs' / (f'{cfg["profile"]}_{cfg["nvec"]}_' + digest)
        # A completed run is never reused across suite invocations.
        directory.mkdir(parents=True, exist_ok=False)
        write_physics(directory / 'parameters.nml', cfg, cfg.get('parameters'))
        controls = {k: v for k, v in cfg.items() if k != 'parameters'}
        write_nml(directory / 'block_test.nml', 'block_test', dict(controls, param_nml='parameters.nml'))
        command([self.exe, '-config', directory / 'block_test.nml', '-output', directory],
                directory, directory / 'run.log', self.env, 'BLOCK_COMPLETED')
        if not (directory / 'completed.txt').is_file():
            raise AssertionError(f'Missing completion marker: {directory}')
        dump = Dump(directory)
        if dump.nvec != cfg['nvec'] or dump.nblocks != cfg['nblocks']:
            raise AssertionError(f'Runtime dimensions differ from requested dimensions: {directory}')
        self.runs += 1
        self.cache[key] = dump
        return dump

    def record(self, name, **details):
        entry = dict(test=name, result='PASS', **details)
        self.entries.append(entry)
        print(json.dumps(entry), flush=True)
        self.report()

    def report(self, failure=None):
        summary = dict(result='FAIL' if failure else 'PASS', process_runs=self.runs,
                       exact_field_comparisons=self.comparisons, tests=self.entries)
        if failure:
            summary['failure'] = str(failure)
        (self.work / 'checks' / 'summary.json').write_text(
            json.dumps(summary, indent=2) + '\n', encoding='utf-8')

    def refs(self, cfg, cells):
        result = {}
        for cell in cells:
            scalar = dict(cfg)
            scalar.update(nvec=1, source_nvec=cfg['nvec'], sample_column=cell)
            for field in ('reverse', 'permute_step', 'fresh_work', 'test_fault', 'layout',
                          'ivstart', 'ivend', 'mask_stride', 'stop_after', 'checkpoint_file', 'restart_file'):
                scalar.pop(field, None)
            result[cell] = self.run(**scalar)
        return result

    def uniform(self):
        for profile in PROFILES:
            base = self.run(profile=profile)
            if profile == 'SNOW':
                for name in ('teb_wsnow_town', 'teb_snow_melt'):
                    if not any(0. < r.data[base.field(name)] < 1.e10 for r in base.after):
                        raise AssertionError(f'Snow profile did not activate {name}')
            for size in ((1, 2, 7) if self.quick else SIZES):
                block = self.run(nvec=size, profile=profile)
                self.comparisons += compare_reference(block, dict.fromkeys(range(1, size + 1), base))
            self.record('uniform', profile=profile, nvec=[1, 2, 7] if self.quick else list(SIZES))

    def sensitivity(self):
        for profile, parameter, factor, delta, start, observables, threshold in MODIFICATIONS:
            max_response = {name: 0. for name in observables}
            positions = []
            for size in ((2, 7) if self.quick else SIZES[1:]):
                for cell in sorted({1, (size + 1) // 2, size}):
                    cfg = dict(nvec=size, profile=profile, scenario='SINGLE', parameter=parameter,
                               factor=factor, delta=delta, from_step=start, perturb_column=cell)
                    block = self.run(**cfg)
                    changed = self.refs(cfg, [cell])[cell]
                    base = self.run(profile=profile)
                    refs = dict.fromkeys(range(1, size + 1), base)
                    refs[cell] = changed
                    self.comparisons += compare_reference(block, refs)
                    target = [r for r in block.after if r.meta[2] == cell]
                    for name in observables:
                        fi = block.field(name)
                        value = max(abs(r.data[fi] - s.data[fi]) for r, s in zip(target, base.after))
                        if value <= threshold:
                            raise AssertionError(f'No physical response: {profile}/{parameter}, {name}: {value}')
                        max_response[name] = max(max_response[name], value)
                    for row in target:
                        step = row.meta[0]
                        if parameter == 'ahf_traffic':
                            fi = block.field('ahf_traffic_now')
                            if row.data[fi] != 2. * base.by_key[(step, 1, 1)].data[fi]:
                                raise AssertionError('Current traffic was not doubled exactly')
                        if step < start:
                            equal_values(row.data, base.by_key[(step, 1, 1)].data, block.outputs,
                                         block.names, row.meta, 'Changed before warm intervention')
                        if parameter == 'teb_troad_top' and step == start:
                            fi = block.field('teb_troad_before[1]')
                            expected = base.by_key[(step - 1, 1, 1)].data[block.field('teb_troad[1]')] + 2.
                            if row.data[fi] != expected:
                                raise AssertionError('Warm road snapshot did not receive the supplied state')
                    positions.append([size, cell])
            self.record('sensitivity', profile=profile, parameter=parameter, positions=positions,
                        threshold_native_units=threshold, max_response_native_units=max_response)

    def heterogeneous(self):
        for profile, parameter, delta in (('DEF', 'ahf_traffic', 2.), ('COMBINED_EXT', 't', .15)):
            cfg = dict(nvec=7, nblocks=2, profile=profile, scenario='RAMP', parameter=parameter, delta=delta)
            base = self.run(**cfg)
            refs = self.refs(cfg, range(1, 8))
            self.comparisons += compare_reference(base, refs)
            for extras in (dict(reverse=True), dict(permute_step=6), dict(fresh_work=True), dict(layout='SERIAL')):
                result = self.run(**cfg, **extras)
                self.comparisons += compare_reference(result, refs)
            self.record('ramp_permutation_two_blocks_fresh_serial', profile=profile, parameter=parameter,
                        nvec=7, nblocks=2)

    def memory(self):
        # pres_grad=0 in WIND_CALCULATION_WANG: u* affects CL, but only the
        # zero pressure-gradient contribution uses CL. Do not claim sensitivity.
        # Roof CD changes the local PUW_GR/PUW_RF momentum flux. Those quantities
        # are absent from the current public outputs; town u* is calculated earlier.
        for profile, parameter, reason in (
            ('WANG', 'teb_ustar_town', 'pres_grad=0 in Wang'),
            ('ROOF_EXT', 'teb_cd_greenroof_atm', 'roof momentum flux is not a public output')):
            cfg = dict(nvec=7, profile=profile, scenario='SINGLE', parameter=parameter,
                       factor=1.5, from_step=6, perturb_column=4)
            dump = self.run(**cfg)
            refs = self.refs(cfg, [4])
            base = self.run(profile=profile)
            self.comparisons += compare_reference(dump, {i: refs[4] if i == 4 else base for i in range(1, 8)})
            before = next(r for r in dump.before if r.meta[:3] == (6, 1, 4))
            index = dump.field(parameter)
            if before.data[index] != 1.5 * base.by_key[(5, 1, 1)].data[index]:
                raise AssertionError('Host did not modify warm coupling memory')
            for row in dump.after:
                equal_values(row.data, base.by_key[(row.meta[0], 1, 1)].data,
                             dump.outputs, dump.names, row.meta, 'Unexpected public response to coupling memory')
            self.record('warm_memory_public_equivalence', profile=profile, parameter=parameter, host_input_factor=1.5,
                        limitation=reason + '; API entry transfer needs instrumented audit')

    def memory_probe(self):
        """Observe the API-to-driver load in external instrumented API copies.

        The production library and its equations remain untouched. Each positive
        probe must preserve every public result. Removing either load must fail.
        """
        build = self.exe.parent.parent
        profile = build / 'build-profile.txt'
        if not profile.is_file():
            raise RuntimeError('Memory probe needs the matching build-profile.txt; use --skip-memory-probe for exe-only checks')
        paths = dict(line.split('=', 1) for line in profile.read_text().splitlines() if '=' in line)
        out = self.work / 'checks' / 'memory_probe'
        out.mkdir()
        source = (ROOT / 'src_dev' / 'src_api' / 'sfc_teb.F90').read_text(encoding='utf-8')
        source, count = re.subn(r'(?im)^(MODULE sfc_teb\s*)$',
            r'\1\nUSE MODD_SURF_PAR, ONLY: probe_undef=>XUNDEF', source, count=1)
        if count != 1:
            raise AssertionError('Review the memory probe: API module was not found')
        guard = '''IF (ntstep > 0) THEN
 IF (DMT%XUSTAR_TOWN(1) /= teb_ustar_town(i)) ERROR STOP 'MEMORY_PROBE_USTAR'
 IF (DMT%XPCD_GREENROOF_ATM(1) /= teb_cd_greenroof_atm(i)) ERROR STOP 'MEMORY_PROBE_ROOF_CD'
ELSE
 IF (DMT%XUSTAR_TOWN(1) /= 0.2) ERROR STOP 'MEMORY_PROBE_COLD_USTAR'
 IF (DMT%XPCD_GREENROOF_ATM(1) /= probe_undef) ERROR STOP 'MEMORY_PROBE_COLD_ROOF_CD'
END IF
IF(ntstep==6 .AND. i==4) WRITE(*,*) 'MEMORY_PROBE_OK'
'''
        source, count = re.subn(r'(?im)^(\s*CALL CALL_DRIVER\b)', guard + r'\1', source, count=1)
        if count != 1:
            raise AssertionError('Review the memory probe: CALL_DRIVER entry was not found')
        objects = [Path(paths['BLOCK_OBJDIR']) / (name + '.o')
                   for name in ('run_teb_offline_block',)]
        objects += sorted(p for p in Path(paths['OFFLINE_OBJDIR']).glob('*.o') if p.stem != 'run_teb_offline')
        if len(objects) != 14 or not all(p.is_file() for p in objects):
            raise RuntimeError('Memory probe requires the matching block and offline helper objects')
        compiler = paths['FC']
        if 'gfortran' not in compiler:
            raise RuntimeError('Memory instrumentation currently supports gfortran; use --skip-memory-probe for another compiler')
        platform = Path(paths['PLATFORM_OBJDIR']) / 'wrap_setlocale.o'
        platform_args = [platform, '-static-libgfortran', '-Wl,--wrap=setlocale'] if paths['WRAP_LOCALE'] == '1' else []
        for tag, field, argument, marker in (
            ('positive', '', '', ''), ('missing_ustar', 'XUSTAR_TOWN', 'teb_ustar_town', 'MEMORY_PROBE_USTAR'),
            ('missing_roof_cd', 'XPCD_GREENROOF_ATM', 'teb_cd_greenroof_atm', 'MEMORY_PROBE_ROOF_CD')):
            text = source
            if field:
                pattern = r'(?m)^\s*DMT%' + field + r'\(1:1\) = ' + argument + r'\(i:i\)\s*$'
                text, count = re.subn(pattern, '', text, count=1)
                if count != 1:
                    raise AssertionError('Review the memory probe: state load was not found')
            src, obj, exe = (out / (tag + suffix) for suffix in ('.F90', '.o', '.exe'))
            src.write_text(text, encoding='utf-8')
            command([compiler, '-O0', '-g', '-fdefault-real-8', '-fcheck=all', '-ffpe-trap=invalid,zero',
                     '-ffree-line-length-none', '-J' + str(out), '-I' + paths['MODDIR'], '-c', src, '-o', obj],
                    out, out / (tag + '_compile.log'), self.env)
            command([compiler, *objects, obj, paths['LIB'], *platform_args, '-o', exe],
                    out, out / (tag + '_link.log'), self.env)
            for physics, parameter in (('WANG', 'teb_ustar_town'), ('ROOF_EXT', 'teb_cd_greenroof_atm')):
                if field and parameter != argument:
                    continue
                cfg = dict(nvec=7, profile=physics, scenario='SINGLE', parameter=parameter,
                           factor=1.5, from_step=6, perturb_column=4)
                directory = out / (tag + '_' + physics)
                directory.mkdir()
                write_physics(directory / 'parameters.nml', cfg)
                write_nml(directory / 'block.nml', 'block_test', dict(cfg, param_nml='parameters.nml'))
                args = [exe, '-config', directory / 'block.nml', '-output', directory]
                log = directory / 'run.log'
                if field:
                    with log.open('w', encoding='utf-8') as stream:
                        result = subprocess.run([str(x) for x in args], cwd=directory, env=self.env,
                                                stdout=stream, stderr=subprocess.STDOUT, check=False)
                    if result.returncode == 0 or marker not in log.read_text(encoding='utf-8', errors='replace'):
                        raise AssertionError('A removed memory load escaped the instrumented check: ' + tag)
                else:
                    command(args, directory, log, self.env, 'BLOCK_COMPLETED')
                    if 'MEMORY_PROBE_OK' not in log.read_text(encoding='utf-8', errors='replace'):
                        raise AssertionError('Instrumented API was not called at the warm intervention')
                    actual, expected = Dump(directory), self.run(**cfg)
                    if len(actual.after) != len(expected.after):
                        raise AssertionError('Incomplete instrumented run')
                    for row in actual.after:
                        reference = expected.by_key[row.meta[:3]]
                        equal_values(row.data, reference.data, actual.outputs, actual.names,
                                     row.meta, 'Instrumentation changed public results')
                        self.comparisons += len(actual.outputs)
                self.runs += 1
        self.record('instrumented_memory_transfer', nvec=7, cold_and_warm=True,
                    negative_controls=['missing_ustar', 'missing_roof_cd'])

    def masks(self):
        base = self.run()
        for name, changes in (
            ('mask', dict(mask_stride=3)), ('no_city', dict(mask_stride=1)),
            ('window_tail', dict(ivstart=2, ivend=6)), ('empty_window', dict(ivstart=4, ivend=3))):
            dump = self.run(nvec=7, **changes)
            self.comparisons += compare_reference(dump, dict.fromkeys(range(1, 8), base))
            self.comparisons += inactive_preserved(dump)
            self.record(name, nvec=7)

    def restart(self):
        cfg = dict(nvec=7, nblocks=2, profile='COMBINED_EXT', scenario='RAMP',
                   parameter='t', delta=.15, permute_step=6)
        continuous = self.run(**cfg)
        checkpoint = self.work / 'checks' / 'checkpoint.bin'
        first = self.run(**cfg, stop_after=24, checkpoint_file=str(checkpoint))
        resumed = self.run(**cfg, restart_file=str(checkpoint))
        for part in (first, resumed):
            for record in part.after:
                expected = continuous.by_key[record.meta[:3]]
                equal_values(record.data, expected.data, part.outputs, part.names,
                             record.meta, 'Restart differs from continuous run')
                self.comparisons += len(part.outputs)
        if len(first.after) + len(resumed.after) != len(continuous.after):
            raise AssertionError('Restart has a time gap or overlap')
        self.record('restart_new_process', split_after=24, nvec=7, nblocks=2, profile='COMBINED_EXT')

    def negative(self):
        cfg = dict(nvec=2, scenario='SINGLE', parameter='t', delta=2., perturb_column=2)
        bad = self.run(**cfg, test_fault='BROADCAST_FIRST')
        refs = self.refs(cfg, [1, 2])
        try:
            compare_reference(bad, refs)
        except AssertionError as error:
            if 'cell=2' not in str(error):
                raise
            self.record('negative_broadcast_first_detected', first_mismatch=str(error))
        else:
            raise AssertionError('The sensitivity checker missed the intentional broadcast error')

    def unified_namelists(self):
        # Scalar expansion must agree with explicit lists and independent runs.
        for profile in ('DEF', 'BEM_WANG', 'COMBINED_EXT'):
            scalar = self.run(nvec=7, profile=profile)
            values = dict(BASE_PARAMETERS, **PROFILE_OVERRIDES[profile])
            repeated = {name: ', '.join([values[name]] * 7)
                        for name in ('urb_h_bld', 'urb_h2w', 'urb_hcap_rd',
                                     'ahf_traffic', 'teb_tcool_target', 'teb_qi_bld_init',
                                     'urb_z0_o_z0h_gdn', 'urb_z0_o_z0h_grf')}
            explicit = self.run(nvec=7, profile=profile, parameters=repeated)
            self.comparisons += compare_reference(explicit, dict.fromkeys(range(1, 8), scalar))
            self.record('namelist_scalar_equals_repeated_list', profile=profile, nvec=7)
        fai = '0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8'
        eight = self.run(nvec=8, nsteps=2, profile='WANG', parameters={'teb_fai': fai})
        for record in eight.before:
            for direction, value in enumerate(map(float, fai.split(',')), 1):
                if record.data[eight.field(f'teb_fai[{direction}]')] != value:
                    raise AssertionError('nvec=8 was confused with the eight FAI directions')
        self.record('common_fai_when_nvec_equals_eight')
        long_list = ', '.join(['1.3815800000000000'] * 257)
        long_case = self.run(nvec=257, nsteps=1, profile='DEF', parameters={'urb_h2w': long_list})
        if any(r.data[long_case.field('urb_h2w')] != 1.38158 for r in long_case.before):
            raise AssertionError('A long namelist record was truncated')
        self.record('long_namelist_record', nvec=257, characters=len(long_list))

        forcing = self.work / 'runs' / 'file_inputs' / 'forcing.nml'
        series = {
            'urb_h_bld': [12. + 2*j for j in range(7)],
            'urb_h2w': [.25 + .25*j for j in range(7)],
            'urb_hcap_rd': [1740000. + 100000*j for j in range(7)],
            'urb_alb_rf_so': [.1 + .04*j for j in range(7)],
            'ahf_traffic': [5.*j for j in range(7)],
            'teb_tcool_target': [294. + j for j in range(7)],
            'urb_z0_gdn': [.05 + .02*j for j in range(7)],
            'urb_z0_grf': [.01 + .005*j for j in range(7)],
            'urb_z0_o_z0h_gdn': [1. + j for j in range(7)],
            'urb_z0_o_z0h_grf': [8. - j for j in range(7)],
            'urb_alb_gdn': [.1 + .02*j for j in range(7)],
            'urb_emis_rf': [.9 + .01*j for j in range(7)],
            'urb_emis_grf': [.9 + .01*j for j in range(7)],
        }
        common = dict(teb_ctype_bem="'BEM'", teb_ctype_wind="'WANG'",
                      teb_ti_bld_init=None, teb_qi_bld_init=None,
                      teb_fai='0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8')
        parameters = dict(common, **{name: ', '.join(map(repr, values))
                                    for name, values in series.items()})
        cfg = dict(nvec=7, nblocks=2, nsteps=0, profile='COMBINED_EXT',
                   forcing_source='FILE', forcing_nml=forcing.as_posix(), model_log=True,
                   parameters=parameters)
        block = self.run(**cfg)
        refs = {}
        for cell in range(1, 8):
            point_params = dict(common, **{name: repr(values[cell-1]) for name, values in series.items()})
            refs[cell] = self.run(**dict(cfg, nvec=1, source_nvec=7, sample_column=cell,
                                        parameters=point_params))
        self.comparisons += compare_reference(block, refs)
        for cell, ref in refs.items():
            for b in (1, 2):
                for kind in ('output', 'emu', 'runoff'):
                    name = f'TEB_{kind}_b{b}_c{cell}.csv'
                    if (block.directory/name).read_bytes() != (ref.directory/name).read_bytes():
                        raise AssertionError(f'Per-cell CSV differs from an independent process: {name}')
        for step in range(block.first, block.last + 1):
            records = [r for r in block.before if r.meta[0] == step]
            first = records[0]
            for record in records[1:]:
                for name in ('t', 'qv', 'u', 'v', 'ps', 'rho', 'lwd_s', 'swdir_s', 'swdifd_s'):
                    index = block.field(name)
                    if record.data[index] != first.data[index]:
                        raise AssertionError(f'Common forcing differs across cells: {name}')
        for record in block.before:
            for direction in range(1, 9):
                expected = float(common['teb_fai'].split(',')[direction-1])
                if record.data[block.field(f'teb_fai[{direction}]')] != expected:
                    raise AssertionError('FAI profile was not broadcast across the block')
        self.record('heterogeneous_namelist_and_all_csv', nvec=7, nblocks=2,
                    independent_processes=7, varied_parameters=len(series))

        permuted_cfg = dict(cfg, permute_step=6)
        permuted = self.run(**permuted_cfg)
        self.comparisons += compare_reference(permuted, refs)
        for name in block.directory.glob('TEB_*.csv'):
            if name.read_bytes() != (permuted.directory/name.name).read_bytes():
                raise AssertionError(f'CSV identity changed after a storage permutation: {name.name}')
        self.record('stable_csv_cell_ids_after_permutation', nvec=7, nblocks=2)

        checkpoint = self.work / 'checks' / 'output_checkpoint.bin'
        first = self.run(**dict(permuted_cfg, stop_after=17, checkpoint_file=checkpoint.as_posix()))
        resumed = self.run(**dict(permuted_cfg, restart_file=checkpoint.as_posix()))
        self.comparisons += compare_reference(first, refs) + compare_reference(resumed, refs)
        for name in block.directory.glob('TEB_*.csv'):
            whole = name.read_bytes().splitlines()
            left = (first.directory/name.name).read_bytes().splitlines()
            right = (resumed.directory/name.name).read_bytes().splitlines()
            if not whole:
                if left or right:
                    raise AssertionError('Unexpected emulator output after restart')
                continue
            if left[0] != whole[0] or right[0] != whole[0] or left + right[1:] != whole:
                raise AssertionError(f'CSV restart changed output or an interval accumulator: {name.name}')
        self.record('csv_restart_inside_accumulation_interval', split_after=17, cadence=6,
                    nblocks=2, permute_step=6)

        # Both entry points consume exactly the same physical namelist at nvec>1.
        entry_root = self.work / 'runs' / 'unified_entry_points'
        for tag, exe in (('ordinary', self.ordinary), ('block', self.exe)):
            directory = entry_root / tag
            directory.mkdir(parents=True)
            command([exe, '-param_nml', block.directory/'parameters.nml',
                     '-forcing_nml', forcing, '-output', directory],
                    directory, directory/'run.log', self.env, 'ENDS CORRECTLY')
        a, b = entry_root/'ordinary', entry_root/'block'
        for name in a.glob('TEB_*.csv'):
            if name.read_bytes() != (b/name.name).read_bytes():
                raise AssertionError(f'Entry points differ: {name.name}')
        self.runs += 2
        self.record('same_namelist_both_entry_points', nvec=7)

        for wind, code in (('DEF', 0), ('WANG', 1)):
            for dt in (150., 600.):
                result = self.run(nvec=2, profile='DEF', dt=dt,
                                  parameters={'teb_ctype_wind': nml_value(wind)})
                for record in result.before:
                    if record.data[result.field('dt')] != dt:
                        raise AssertionError('tebopts dt did not reach the API')
                    if record.data[result.field('teb_itype_wind')] != code:
                        raise AssertionError('Named wind selector did not reach the numeric API')
                self.record('named_wind_and_option_dt', selector=wind, api_code=code, dt=dt)

    def strict_namelists(self):
        root = self.work / 'runs' / 'invalid_namelists'
        forcing = self.work / 'runs' / 'file_inputs' / 'forcing.nml'
        cases = {
            'short_list': ("&tebopts nvec=3 / &tebparams urb_h_bld=10.,20. /", 'urb_h_bld'),
            'long_list': ("&tebopts nvec=3 / &tebparams urb_h_bld=10.,20.,30.,40. /", 'urb_h_bld'),
            'repeat': ("&tebopts nvec=3 / &tebparams urb_h_bld=3*10. /", 'urb_h_bld'),
            'null': ("&tebopts nvec=3 / &tebparams urb_h_bld=10.,,30. /", 'urb_h_bld'),
            'leading_null': ("&tebopts nvec=3 / &tebparams urb_h_bld=,10. /", 'urb_h_bld'),
            'indexed': ("&tebopts nvec=3 / &tebparams urb_h_bld(1)=10. /", 'urb_h_bld'),
            'duplicate': ("&tebopts nvec=3 / &tebparams urb_h_bld=10.,urb_h_bld=20. /", 'urb_h_bld'),
            'logical_array': ("&tebopts nvec=3,teb_lgarden=T,F,T / &tebparams /", 'teb_lgarden'),
            'selector_array': ("&tebopts nvec=3,teb_ctype_bem='DEF','BEM','DEF' / &tebparams /", 'teb_ctype_bem'),
            'scalar_array': ("&tebopts nvec=3,dt=300.,300.,300. / &tebparams /", 'dt'),
            'fai_short': ("&tebopts nvec=3 / &tebparams teb_fai=.1,.2,.3 /", 'teb_fai'),
            'fai_cells': ("&tebopts nvec=3 / &tebparams teb_fai="+','.join(['.5']*24)+" /", 'teb_fai'),
            'wrong_group': ("&tebopts nvec=3 / &tebparams teb_lgarden=T /", 'teb_lgarden'),
            'mixed_formats': ("&tebparam dt=300. / &tebopts nvec=3 / &tebparams /", 'cannot mix'),
            'invalid_nvec': ("&tebopts nvec=0 / &tebparams /", 'nvec'),
            'real_nvec': ("&tebopts nvec=3.0 / &tebparams /", 'integer'),
            'missing_slash': ("&tebopts nvec=3 / &tebparams urb_h_bld=10.", 'terminating slash'),
            'bad_geometry': ("&tebopts nvec=3 / &tebparams urb_h_bld=10.,-1.,20. /", 'geometry'),
            'nonfinite': ("&tebopts nvec=3 / &tebparams urb_h_bld=10.,NaN,20. /", 'non-finite'),
            'long_selector': ("&tebopts nvec=3,teb_ctype_bem='BEM_extra' / &tebparams /", 'length'),
            'invalid_thermal_ratio': ("&tebopts nvec=3 / &tebparams urb_z0_o_z0h_gdn=1.e30 /", 'ratio'),
            'short_thermal_ratio_list': ("&tebopts nvec=3 / &tebparams urb_z0_o_z0h_grf=3.,4. /",
                                         'urb_z0_o_z0h_grf'),
            'invalid_thermal_ratio_list_value': (
                "&tebopts nvec=3 / &tebparams urb_z0_o_z0h_gdn=1.,0.5,4. /", 'finite ratio >= 1'),
            'invalid_road_z0h_rule': ("&tebopts teb_ctype_z0_o_z0h_rd='200 300' / &tebparams /",
                                     'expected a finite ratio >= 1, KANDA07 or BRUT82'),
            'roof_z0h_rule_list': ("&tebopts nvec=2,teb_ctype_z0_o_z0h_rf='200','BRUT82' / &tebparams /",
                                   'teb_ctype_z0_o_z0h_rf'),
            'deprecated_road_exchange': (
                "&tebopts teb_ctype_exch_road='MASC95' / &tebparams /",
                'teb_ctype_exch_road is deprecated. Use teb_ctype_exch_rd in &tebopts.'),
            'deprecated_roof_exchange_with_replacement': (
                "&tebopts teb_ctype_exch_rf='MASC95',teb_ctype_exch_roof='DELAGE' / &tebparams /",
                'teb_ctype_exch_roof is deprecated. Use teb_ctype_exch_rf in &tebopts.'),
        }
        cases.update({
            'dt_in_parameters': ("&tebopts / &tebparams dt=300. /", 'dt'),
            'numeric_wind_zero': ("&tebopts teb_ctype_wind=0 / &tebparams /", 'DEF or WANG'),
            'numeric_wind_one': ("&tebopts teb_ctype_wind=1 / &tebparams /", 'DEF or WANG'),
            'unknown_wind': ("&tebopts teb_ctype_wind='OTHER' / &tebparams /", 'length'),
            'unknown_wind_short': ("&tebopts teb_ctype_wind='BAD' / &tebparams /", 'DEF or WANG'),
            'wind_list': ("&tebopts nvec=2,teb_ctype_wind='DEF','WANG' / &tebparams /", 'teb_ctype_wind'),
            'zero_dt': ("&tebopts dt=0. / &tebparams /", 'dt'),
            'deprecated_z0_town': ("&tebparams urb_z0_town='0.1H' /", 'urb_z0_town is deprecated'),
            'z0_town_list': ("&tebopts teb_ctype_z0_town='0.1H','0.5' / &tebparams /", 'expected 1 or 1'),
        })
        for key in ('teb_itype_bem', 'teb_itype_natvent', 'teb_itype_bem_cool',
                    'teb_itype_bem_heat', 'teb_itype_wind', 'teb_type_garden', 'teb_type_greenroof'):
            cases['legacy_key_' + key] = (f"&tebopts {key}='DEF' / &tebparams /", key)
        for name, (text, expected) in cases.items():
            directory = root / name
            directory.mkdir(parents=True)
            (directory/'params.nml').write_text(text, encoding='utf-8')
            with (directory/'run.log').open('w') as log:
                result = subprocess.run([str(self.ordinary), '-param_nml', 'params.nml',
                                         '-forcing_nml', str(forcing), '-output', '.'],
                                        cwd=directory, env=self.env, stdout=log, stderr=subprocess.STDOUT)
            message = (directory/'run.log').read_text(errors='replace')
            if result.returncode == 0 or expected.lower() not in message.lower() or (directory/'completed.txt').exists():
                raise AssertionError(f'Strict namelist validation failed: {name}: {message[-800:]}')
            self.runs += 1
        self.record('strict_namelist_rejections', cases=len(cases))

    def files(self):
        case = self.work / 'runs' / 'file_inputs'
        case.mkdir(parents=True)
        shutil.copytree(ROOT / 'tests' / 'CAPITOUL' / 'input', case / 'input')
        forcing = case / 'forcing.nml'
        write_nml(forcing, 'tebforcing', dict(forcing_path=(case / 'input').as_posix() + '/',
                  lon_teb=1.3, lat_teb=43.484, hlev_teb=28., teb_year=2004, teb_month=2, teb_day=20,
                  teb_hour=0, teb_min=0, nsteps=9, forc_step=1800.))
        for profile in ('DEF', 'BEM', 'WANG'):
            cfg = dict(forcing_source='FILE', forcing_nml=str(forcing), nsteps=0, profile=profile, model_log=True)
            scalar = self.run(**cfg)
            block = self.run(**cfg, nvec=7)
            self.comparisons += compare_reference(block, dict.fromkeys(range(1, 8), scalar))
            out = case / profile
            out.mkdir()
            # Both entry points read the same new-format physical namelist.
            shutil.copyfile(scalar.directory / 'parameters.nml', out / 'params.nml')
            (out / 'forcing.nml').write_text(forcing.read_text(encoding='utf-8').replace(
                (case / 'input').as_posix() + '/', '../input/'), encoding='utf-8')
            command([self.ordinary, '-forcing_nml', 'forcing.nml', '-param_nml', 'params.nml', '-output', '.'],
                    out, out / 'run.log', self.env, 'ENDS CORRECTLY')
            before = out / 'TEB_output_b1_c1.csv'
            after = scalar.directory / before.name
            if before.read_bytes() != after.read_bytes():
                a = list(csv.reader(before.open(), delimiter=';'))
                b = list(csv.reader(after.open(), delimiter=';'))
                if a[0] != b[0] or len(a) != len(b):
                    raise AssertionError(f'Ordinary/block CSV schema or row count mismatch: {profile}')
                for i, (ra, rb) in enumerate(zip(a[1:], b[1:])):
                    for j, (va, vb) in enumerate(zip(ra, rb)):
                        if va != vb:
                            raise AssertionError(f'Ordinary/block CSV mismatch {profile}: row={i}, '
                                                 f'column={a[0][j]}, ordinary={va}, block={vb}')
                raise AssertionError('CSV bytes differ despite identical rows')
            self.record('file_forcing_ordinary_identical', profile=profile, model_steps=48, csv_rows=8,
                        sha256=hashlib.sha256(before.read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out-root', type=Path, required=True, help='New external task directory')
    parser.add_argument('--build-root', type=Path)
    parser.add_argument('--exe', type=Path, help='Existing block executable; skips build')
    parser.add_argument('--ordinary-exe', type=Path, help='Ordinary executable for file-forcing comparison')
    parser.add_argument('--quick', action='store_true', help='Smaller 1,2,7 matrix for development')
    parser.add_argument('--skip-memory-probe', action='store_true', help='Exe-only tests; omit compilation of instrumented API copies')
    options = parser.parse_args()
    work = external(options.out_root)
    # Refuse a populated run directory so results always describe this execution.
    if (work / 'runs').exists() or (work / 'checks' / 'summary.json').exists():
        parser.error('Choose a new --out-root; existing test results are preserved')
    for name in ('logs', 'checks'):
        (work / name).mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    if os.name == 'nt':
        env['PATH'] = 'C:/msys64/ucrt64/bin;C:/msys64/usr/bin;' + env['PATH']
    build = external(options.build_root or work / 'build')
    exe = (options.exe or build / 'bin' / 'TEB_offline_block_dev.exe').resolve()
    ordinary = (options.ordinary_exe or exe.with_name('TEB_offline_dev.exe')).resolve()
    if not options.exe:
        args = ['make', '-C', ROOT / 'src_dev', '-j4', 'offline-block', 'offline',
                'FC=gfortran', 'LD=gfortran', 'BUILD_ROOT=' + build.as_posix(), 'OTHERFLAGS=-fcheck=all']
        if os.name == 'nt':
            args += ['SHELL=C:/msys64/usr/bin/sh.exe', 'WRAP_LOCALE=1']
        command(args, work, work / 'logs' / 'build.log', env)
    if not exe.is_file() or not ordinary.is_file():
        parser.error('Both block and ordinary executables are required')
    metadata = dict(source=str(ROOT), block_executable=str(exe), ordinary_executable=str(ordinary),
                    block_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(), quick=options.quick,
                    memory_instrumentation=not options.skip_memory_probe,
                    comparison='exact REAL64 equality, no numeric tolerance', started_utc=time.time())
    profile = exe.parent.parent / 'build-profile.txt'
    if profile.is_file():
        shutil.copyfile(profile, work / 'checks' / 'build-profile.txt')
        metadata['build_profile'] = str(profile)
    compiler = shutil.which('gfortran', path=env['PATH'])
    if compiler:
        metadata['compiler_version'] = subprocess.check_output(
            [compiler, '--version'], env=env, text=True, errors='replace').splitlines()[0]
    (work / 'checks' / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    suite = Suite(work, exe, ordinary, env, options.quick)
    try:
        suite.uniform()
        suite.sensitivity()
        suite.memory()
        if not options.skip_memory_probe:
            suite.memory_probe()
        suite.heterogeneous()
        suite.masks()
        suite.restart()
        suite.negative()
        suite.files()
        suite.unified_namelists()
        suite.strict_namelists()
    except Exception as error:
        suite.report(error)
        raise
    suite.report()
    print(f'PASS: {suite.runs} separate processes; {suite.comparisons} exact field comparisons; {work}', flush=True)


if __name__ == '__main__':
    main()
