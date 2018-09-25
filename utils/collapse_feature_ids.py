#!/usr/bin/env python3

# Copyright (c) 2018 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import print_function  # Avoid bombing in Python 2 before we even hit our version check

import sys

if sys.version_info.major < 3:
    sys.stderr.write("Must use Python 3\n")
    sys.exit(1)

import argparse
import fiona
import glob
import logging

logging.basicConfig(level=logging.INFO,
                    format=__file__ + ' [%(levelname)s]: %(asctime)s %(message)s',
                    datefmt="%Y-%m-%d %H:%M:%S")


def parse_args(args):
    parser = argparse.ArgumentParser('Collapse feature IDs to a sequence beginning at zero')

    parser.add_argument('--input',
                        help='Name or glob referring to one or more GDAL-readable vector files. Multiple --input '
                             'arguments may be provided.',
                        action='append',
                        required=True)
    parser.add_argument('--output',
                        help='Path to output shapefile',
                        required=True)
    parser.add_argument('--remap',
                        help='Name of feature ID column to remap. If multiple column names are provided (through '
                             'repeated --fid arguments), the first occurrence will be used as a source of IDs to '
                             'generate the mapping that will be applied to all columns.',
                        action='append',
                        required=True)

    parsed = parser.parse_args(args)

    return parsed


def main(raw_args):
    args = parse_args(raw_args)

    id_map = {0: 0}

    inputs = [f for pattern in args.input for f in glob.glob(pattern)]

    ids = []
    with fiona.drivers():
        meta = None
        for f in inputs:
            logging.info('Collecting IDs from ' + f)
            with fiona.open(f) as data:
                # Store metadata for constructing output. Assume it's consistent across inputs.
                if not meta:
                    meta = data.meta
                ids += [feature['properties'][args.remap[0]] for feature in data]

        for mapped_id, original_id in enumerate(ids, start=1):
            id_map[original_id] = mapped_id

        logging.info('Collected {} ids.'.format(len(id_map)))

        with fiona.open(args.output, 'w', **meta) as out:
            for f in inputs:
                logging.info('Writing features from {} to {}'.format(f, args.output))
                with fiona.open(f) as data:
                    for feature in data:
                        for field_name in args.remap:
                            feature['properties'][field_name] = id_map[feature['properties'][field_name]]

                        out.write(feature)

    logging.info('Done.')


if __name__ == "__main__":
    main(sys.argv[1:])
