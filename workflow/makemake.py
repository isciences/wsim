from __future__ import print_function # Avoid bombing in Python 2 before we even hit our version check

import sys

if sys.version_info.major < 3:
    print("Must use Python 3")
    sys.exit(1)

import os
import monthly
import spinup
import dates
import argparse

def load_config(path, source, derived):
    from importlib.machinery import SourceFileLoader
    return SourceFileLoader("config", path).load_module().config(source, derived)

def parse_args(args):
    parser = argparse.ArgumentParser('Generate a Makefile for WSIM data processing')

    parser.add_argument('--bindir',
                        help='Path to WSIM executables',
                        required=False,
                        default='/wsim')
    parser.add_argument('--config',
                        help='Python file describing run configuration',
                        required=True)
    parser.add_argument('--nospinup',
                        help='Skip model spin-up steps',
                        action='store_true')
    parser.add_argument('--makefile',
                        help='Name of generated makefile',
                        required=False,
                        default='Makefile')
    parser.add_argument('--source',
                        help='Root directory for source data files',
                        required=True)
    parser.add_argument('--workspace',
                        help='Root directory workspace (derived files)',
                        required=True)
    parser.add_argument('--start',
                        help='Start date in YYYYMM format',
                        required=True)
    parser.add_argument('--stop',
                        help='End date in YYYYMM format',
                        required=False)

    parsed = parser.parse_args(args)

    if parsed.stop is None:
        parsed.stop = parsed.start

    return parsed

def find_duplicate_targets(steps):
    targets = set()
    duplicates = set()

    for step in steps:
        for target in step.target:
            if target in targets:
                duplicates.add(target)
            targets.add(target)

    return sorted(list(duplicates))

def write_makefile(filename, steps, bindir):
    with open(filename, 'w') as outfile:
        outfile.write('.DELETE_ON_ERROR:\n')
        outfile.write('.SECONDARY:\n')

        outfile.write('\n')

        for step in reversed(steps):
            outfile.write(step.get_text({'BINDIR' : bindir}))

        print("Done")

def main(raw_args):
    args = parse_args(raw_args)

    config = load_config(args.config, args.source, args.workspace)

    steps = []

    if config.should_run_spinup() and not args.nospinup:
        steps += spinup.spinup(config)

    for i, yearmon in enumerate(reversed(list(dates.get_yearmons(args.start, args.stop)))):
        steps += monthly.monthly_observed(config, yearmon)

        # Only add forecast steps for the final yearmon
        if i == 0:
            steps += monthly.monthly_forecast(config, yearmon)

    duplicate_targets = find_duplicate_targets(steps)
    if duplicate_targets:
        for target in duplicate_targets[:100]:
            print("Duplicate target encountered:", target, file=sys.stderr)
        #sys.exit(1)

    write_makefile(os.path.join(args.workspace, args.makefile), steps, args.bindir)

if __name__ == "__main__":
    main(sys.argv[1:])

#test_args = ["--config", "config_cfs.py", "--start", "201701", "--workspace", '/tmp/fizz', '--source', '/mnt/fig/WSIM/WSIM_source_V1.2']
