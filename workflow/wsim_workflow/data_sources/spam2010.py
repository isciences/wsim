# Copyright (c) 2019 ISciences, LLC.
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

import os
import string

from typing import List, Union

from ..step import Step

SUBDIR = 'SPAM2010'


def production(*, source_dir: str) -> List[Step]:
    dirname = os.path.join(source_dir, SUBDIR)
    url = 'https://s3.amazonaws.com/mapspam/2010/v1.0/geotiff/spam2010v1r0_global_prod.geotiff.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])

    steps = [
        # Download
        Step(
            targets=zip_path,
            dependencies=[],
            commands=[
                [
                    'wget',
                    '--directory-prefix', dirname,
                    url
                ]
            ]
        )
    ]

    spam_crops = {
        'wheat'      : 'whea',
        'rice'       : 'rice',
        'maize'      : 'maiz',
        'barley'     : 'barl',
        'millet'     : ['pmil', 'smil'],
        'sorghum'    : 'sorg',
        'soybeans'   : 'soyb',
        'sunflower'  : 'sunf',
        'potatoes'   : 'pota',
        'cassava'    : 'cass',
        'sugarcane'  : 'sugc',
        'sugarbeet'  : 'sugb',
        'oilpalm'    : 'oilp',
        'rapeseed'   : 'rape',
        'groundnuts' : 'grou',
        'pulses'     : ['bean', 'chic', 'cowp', 'pige', 'lent', 'opul'],
        'cotton'     : 'cott',
        'cocoa'      : 'coco',
        'coffee'     : ['acof', 'rcof']
    }

    tempdir = '/tmp'
    dir_in_zip = 'spam2010v1r0_global_prod.geotiff'

    for method in ('rainfed', 'irrigated'):
        for crop, abbrev in spam_crops.items():
            wsim_fname = 'spam_production_{}_{}.tif'.format(crop, method)

            if type(abbrev) is str:
                spam_fname = production_tif(abbrev, method)

                steps += [
                    Step(
                        targets=os.path.join(dirname, wsim_fname),
                        dependencies=zip_path,
                        commands=[
                            extract_from_zip(zip_path, [dir_in_zip, spam_fname], tempdir),
                            set_global_extent(
                                os.path.join(tempdir, spam_fname),
                                os.path.join(dirname, wsim_fname)
                            ),
                            rm(os.path.join(tempdir, spam_fname))
                        ]
                    )
                ]
            else:
                spam_fnames = [production_tif(a, method) for a in abbrev]

                steps += [
                    Step(
                        targets=os.path.join(dirname, wsim_fname),
                        dependencies=zip_path,
                        commands=[extract_from_zip(zip_path, [dir_in_zip, f], tempdir) for f in spam_fnames] +
                                 [sum_rasters([os.path.join(tempdir, f) for f in spam_fnames],
                                             os.path.join(tempdir, wsim_fname))] +
                                 [rm(os.path.join(tempdir, f)) for f in spam_fnames] +
                                 [set_global_extent(os.path.join(tempdir, wsim_fname),
                                                    os.path.join(dirname, wsim_fname))] +
                                 [rm(os.path.join(tempdir, wsim_fname))]
                    )
                ]

    return steps


def production_tif(abbrev: str, method: str):
    return 'spam2010v1r0_global_production_{}_{}.tif'.format(abbrev, method[0])


def set_global_extent(fname_in: str, fname_out:str) -> List[str]:
    return [
        'gdal_translate',
        '-a_ullr', '-180 90 180 -90',
        '-co', '"COMPRESS=LZW"',
        fname_in,
        fname_out
    ]


def rm(fname: str) -> List[str]:
    return ['rm', fname]


def extract_from_zip(zipfile: str, fname: Union[str, List[str]], extract_dir: str) -> List[str]:
    if type(fname) is list:
        fname = os.path.join(*fname)

    return [
        'unzip',
        '-q',  # avoid printing zip name and extracted file name
        '-D',  # avoid changing timestamp
        '-j',  # junk within-zip paths
        zipfile,
        fname,
        '-d', extract_dir
    ]


def sum_rasters(inputs: List[str], output: str) -> List[str]:
    assert output.endswith('.tif')

    cmd = [
        'gdal_calc.py',
        '--calc="{}"'.format('+'.join(string.ascii_uppercase[:len(inputs)])),
        '--type=Float32',
        '--format=GTiff',
        '--creation-option="COMPRESS=DEFLATE"',
        '--outfile={}'.format(output)
    ]

    for i, input in enumerate(inputs):
        cmd += ['-{}'.format(string.ascii_uppercase[i]), input]

    return cmd
