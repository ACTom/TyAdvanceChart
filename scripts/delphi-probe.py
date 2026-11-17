#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Compile the chart units that need only the RTL with Delphi's command-line compilers.

    python scripts/delphi-probe.py [--bin <Delphi bin directory>] [--verbose]
                                   [--standins DIR --all] [--values]

Windows only: it runs dcc32.exe and dcc64.exe from a Delphi installation. Nothing is written
into the repository; the compiled units go to a temporary directory that is removed at the end.

For every unit in UNITS and for both compilers it prints the number of errors and warnings of
that compiler call, then per compiler the warnings and the hints summed up by code, then per
compiler the number of units that compiled, then PROBE OK or PROBE FAILED. The sums count each
message once (one file, line and code, however many calls compiled that file) and only messages
about files under source/, not about the stand-ins. With --verbose the error and the warning lines
are printed too.

--standins DIR   puts DIR (compile-only stand-ins for the units Delphi lacks) on the unit and include paths.
--all            compiles every unit under source/ except the control and the units that need the LCL
                 (see EXCLUDED); needs --standins. The units share one output folder per compiler and
                 dcc's own make logic reuses what compiled. A unit whose first error is in another file
                 failed because of a unit it uses; its line says which file.
--values         builds delphi/tests/tyadvchart_values.dpr with both compilers, runs it, and requires
                 exit code 0 and DELPHI VALUES OK as the last output line.
Every dcc call and every run of the values program has a timeout (TIMEOUT seconds); a timeout is an error.

Exit code: 0 no errors, 1 at least one error or no unit compiled with a compiler, 2 the compilers
were not found.
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

UNITS = ['Types', 'StrConsts', 'JsMath', 'JsRegExp', 'Jitter', 'Locate', 'GeoFix', 'Connect', 'Catalog', 'NativeStr']
COMPILERS = ['dcc32', 'dcc64']
# --all leaves out the control unit itself (PREFIX without the dot) and these, which need the LCL
EXCLUDED = ['Render', 'Images', 'DirtyRect', 'ToolboxDlg', 'KeyNav']
VALUES_DPR = os.path.join(ROOT, 'delphi', 'tests', 'tyadvchart_values.dpr')
TIMEOUT = 120

MSG_RE = re.compile(r'\b([EWFH])(\d{4})\b')


def all_units():
    skip = [PREFIX[:-1]] + [PREFIX + x for x in EXCLUDED]
    names = sorted(f[:-4] for f in os.listdir(SRC) if f.endswith('.pas'))
    return [n[len(PREFIX):] for n in names if n not in skip]


def dcc_args(tmp, standins):
    extra = [standins] if standins else []
    return ['-Q', '-NSSystem;Winapi', '--codepage:65001', '-U' + ';'.join([SRC, tmp] + extra),
            '-I' + ';'.join([SRC] + extra), '-NU' + tmp, '-E' + tmp]


def run_dcc(cmd, cwd):
    """Returns (return code, output lines); a timeout gives return code -1 and says so."""
    try:
        p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return -1, ['timeout: no result after %d seconds' % TIMEOUT]
    return p.returncode, p.stdout.decode('utf-8', 'replace').splitlines()


def compile_unit(exe, unit, tmp, standins=None, rebuild=True):
    cmd = [exe] + dcc_args(tmp, standins) + (['-B'] if rebuild else []) + [PREFIX + unit + '.pas']
    rc, out = run_dcc(cmd, SRC)
    errors, warnings, hints = [], [], []
    for line in out:
        m = MSG_RE.search(line)
        if not m:
            continue
        if m.group(1) in 'EF':
            errors.append(line.strip())
        elif m.group(1) == 'W':
            warnings.append((m.group(2), line.strip()))
        elif m.group(1) == 'H':
            hints.append((m.group(2), line.strip()))
    if rc != 0 and not errors:
        errors.append('compiler exit code %d: %s' % (rc, ' | '.join(out[-3:])))
    return errors, warnings, hints


def source_place(line):
    """(file, line number) of a message about a file under source/, None for any other file.
    dcc runs in source/, so a file named without a folder is one of source/."""
    m = re.match(r'(.*?)\((\d+)\)', line)
    if not m:
        return None
    path = os.path.normcase(os.path.abspath(os.path.join(SRC, m.group(1))))
    if os.path.dirname(path) != os.path.normcase(os.path.abspath(SRC)):
        return None
    return path, int(m.group(2))


def error_file(line):
    """The source file an error line is about, '' when it names none."""
    m = re.match(r'(.*?)\(\d+\)', line)
    return os.path.basename(m.group(1)) if m else ''


def run_values(exe, tmp):
    """Builds and runs the values program; returns the list of errors (empty when it is fine)."""
    rc, out = run_dcc([exe] + dcc_args(tmp, None) + ['-B', VALUES_DPR], os.path.dirname(VALUES_DPR))
    if rc != 0:
        errs = [l.strip() for l in out if MSG_RE.search(l) and MSG_RE.search(l).group(1) in 'EF']
        return ['values program does not compile: ' + (errs[0] if errs else ' | '.join(out[-3:]))]
    try:
        p = subprocess.run([os.path.join(tmp, 'tyadvchart_values.exe')], cwd=tmp,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return ['values program: timeout after %d seconds' % TIMEOUT]
    lines = p.stdout.decode('utf-8', 'replace').splitlines()
    last = lines[-1].strip() if lines else ''
    if p.returncode != 0 or last != 'DELPHI VALUES OK':
        return ['values program: exit code %d, output: %s' % (p.returncode, ' | '.join(l.strip() for l in lines))]
    return []


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--bin', default=DEFAULT_BIN, help='Delphi bin directory (default: %(default)s)')
    ap.add_argument('--verbose', action='store_true', help='print the error and warning lines')
    ap.add_argument('--standins', help='folder of compile-only stand-ins, added to the unit and include paths')
    ap.add_argument('--all', action='store_true', help='compile every neutral unit (needs --standins)')
    ap.add_argument('--values', action='store_true', help='build and run delphi/tests/tyadvchart_values.dpr')
    args = ap.parse_args()
    if args.all and not args.standins:
        ap.error('--all needs --standins')
    if args.standins and not os.path.isdir(args.standins):
        ap.error('--standins: no such folder: ' + args.standins)
    standins = os.path.abspath(args.standins) if args.standins else None

    exes = {c: os.path.join(args.bin, c + '.exe') for c in COMPILERS}
    missing = [e for e in exes.values() if not os.path.isfile(e)]
    if missing:
        print('Delphi compilers not found: ' + ', '.join(missing))
        print('Give the bin directory of a Delphi installation with --bin.')
        return 2

    tmp = tempfile.mkdtemp(prefix='delphi-probe-')
    tmps = {c: os.path.join(tmp, c) for c in COMPILERS}  # the units of both compilers are .dcu files
    for d in tmps.values():
        os.mkdir(d)
    units = all_units() if args.all else UNITS
    total_errors = 0
    # each message once: the set of (file, line, code) per compiler and kind, files under source/ only
    seen = {c: {'W': set(), 'H': set()} for c in COMPILERS}
    compiled = {c: 0 for c in COMPILERS}
    try:
        for unit in units:
            for c in COMPILERS:
                errors, warnings, hints = compile_unit(exes[c], unit, tmps[c], standins, rebuild=not args.all)
                total_errors += len(errors)
                if not errors:
                    compiled[c] += 1
                for kind, msgs in (('W', warnings), ('H', hints)):
                    for code, line in msgs:
                        place = source_place(line)
                        if place:
                            seen[c][kind].add(place + (kind + code,))
                note = ''
                if errors and args.all:
                    f = error_file(errors[0])
                    if f and f != PREFIX + unit + '.pas':
                        note = '  (first error in ' + f + ')'
                print('%-9s %-6s errors %d  warnings %d%s' % (unit, c, len(errors), len(warnings), note))
                if args.verbose:
                    for e in errors:
                        print('    ' + e)
                    for _, w in warnings:
                        print('    ' + w)
        if args.values:
            for c in COMPILERS:
                errors = run_values(exes[c], tmps[c])
                total_errors += len(errors)
                print('%-9s %-6s %s' % ('values', c, 'DELPHI VALUES OK' if not errors else 'errors %d' % len(errors)))
                for e in errors:
                    print('    ' + e)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    for kind, what in (('W', 'warnings'), ('H', 'hints')):
        for c in COMPILERS:
            by_code = collections.Counter(code for _, _, code in seen[c][kind])
            print('%s by code, %s (each once, source/ only):' % (what, c))
            for code, n in sorted(by_code.items()):
                print('  %s: %d' % (code, n))
            if not by_code:
                print('  none')
    for c in COMPILERS:
        print('units, %s: %d' % (c, compiled[c]))
    if total_errors:
        print('PROBE FAILED (%d errors)' % total_errors)
        return 1
    if not all(compiled.values()):
        print('PROBE FAILED (no unit compiled with %s)' % ', '.join(c for c in COMPILERS if not compiled[c]))
        return 1
    print('PROBE OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
