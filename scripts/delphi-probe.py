#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Compile the chart units that need only the RTL with Delphi's command-line compilers.

    python scripts/delphi-probe.py [--bin <Delphi bin directory>] [--verbose]

Windows only: it runs dcc32.exe and dcc64.exe from a Delphi installation. Nothing is written
into the repository; the compiled units go to a temporary directory that is removed at the end.

For every unit in UNITS and for both compilers it prints the number of errors and warnings,
then the warnings summed up by code per compiler, then PROBE OK or PROBE FAILED.
With --verbose the error lines are printed too.

Exit code: 0 no errors, 1 at least one error, 2 the compilers were not found.
The list of units grows with the later plans (every unit added reaches only units already listed
or the RTL).
"""
import argparse
import collections
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'source')
DEFAULT_BIN = r'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin'
PREFIX = 'tyControls.AdvanceChart.'

UNITS = ['Types', 'StrConsts', 'JsMath', 'JsRegExp', 'Jitter', 'Locate', 'GeoFix', 'Connect', 'Catalog']
COMPILERS = ['dcc32', 'dcc64']

MSG_RE = re.compile(r'\b([EWFH])(\d{4})\b')


def compile_unit(exe, unit, tmp):
    cmd = [exe, '-Q', '-B', '-NSSystem', '-U' + SRC, '-NU' + tmp, '-E' + tmp,
           PREFIX + unit + '.pas']
    p = subprocess.run(cmd, cwd=SRC, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.stdout.decode('utf-8', 'replace').splitlines()
    errors, warnings = [], []
    for line in out:
        m = MSG_RE.search(line)
        if not m:
            continue
        if m.group(1) in 'EF':
            errors.append(line.strip())
        elif m.group(1) == 'W':
            warnings.append((m.group(2), line.strip()))
    if p.returncode != 0 and not errors:
        errors.append('compiler exit code %d: %s' % (p.returncode, ' | '.join(out[-3:])))
    return errors, warnings


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--bin', default=DEFAULT_BIN, help='Delphi bin directory (default: %(default)s)')
    ap.add_argument('--verbose', action='store_true', help='print the error lines')
    args = ap.parse_args()

    exes = {c: os.path.join(args.bin, c + '.exe') for c in COMPILERS}
    missing = [e for e in exes.values() if not os.path.isfile(e)]
    if missing:
        print('Delphi compilers not found: ' + ', '.join(missing))
        print('Give the bin directory of a Delphi installation with --bin.')
        return 2

    tmp = tempfile.mkdtemp(prefix='delphi-probe-')
    total_errors = 0
    warn_by_code = {c: collections.Counter() for c in COMPILERS}
    try:
        for unit in UNITS:
            for c in COMPILERS:
                errors, warnings = compile_unit(exes[c], unit, tmp)
                total_errors += len(errors)
                for code, _ in warnings:
                    warn_by_code[c]['W' + code] += 1
                print('%-9s %-6s errors %d  warnings %d' % (unit, c, len(errors), len(warnings)))
                if args.verbose:
                    for e in errors:
                        print('    ' + e)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    for c in COMPILERS:
        print('warnings by code, %s:' % c)
        for code, n in sorted(warn_by_code[c].items()):
            print('  %s: %d' % (code, n))
        if not warn_by_code[c]:
            print('  none')
    if total_errors:
        print('PROBE FAILED (%d errors)' % total_errors)
        return 1
    print('PROBE OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
