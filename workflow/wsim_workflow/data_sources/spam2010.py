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

# Lookup dict generated in R using:
# toJSON(
#   lapply(
#     split(
#       merge(wsim.agriculture::wsim_crops, wsim.agriculture::spam_crops),
#       merge(wsim.agriculture::wsim_crops, wsim.agriculture::spam_crops)$wsim_name
#     ),
#     function(group) group$spam_abbrev
#   )
# )
_spam_crops = {
    "barley":["barl"],
    "cassava":["cass"],
    "cocoa":["coco"],
    "coffee":["acof","rcof"],
    "cotton":["cott"],
    "groundnuts":["grou"],
    "maize":["maiz"],
    "millet":["pmil","smil"],
    "oilpalm":["oilp"],
    "potatoes":["pota"],
    "pulses":["lent","pige","opul","chic","cowp","bean"],
    "rapeseed":["rape"],
    "rice":["rice"],
    "sorghum":["sorg"],
    "soybeans":["soyb"],
    "sugarbeets":["sugb"],
    "sugarcane":["sugc"],
    "sunflower":["sunf"],
    "wheat":["whea"]
}


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

    tempdir = '/tmp'
    dir_in_zip = 'spam2010v1r0_global_prod.geotiff'

    for method in ('rainfed', 'irrigated'):
        for crop, abbrev in _spam_crops.items():
            wsim_fname = wsim_production_tif(crop, method)

            if len(abbrev) == 1:
                spam_fname = spam_production_tif(abbrev[0], method)

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
                spam_fnames = [spam_production_tif(a, method) for a in abbrev]

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


def wsim_production_tif(crop: str, method: str) -> str:
    return 'spam_production_{}_{}.tif'.format(crop, method)


def spam_production_tif(abbrev: str, method: str) -> str:
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
