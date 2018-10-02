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

import os
import os.path

from ..step import Step

def baseline_water_stress(source_dir, filename):
    url = 'https://data.wri.org/Aqueduct/web/aqueduct_global_maps_21_shp.zip'
    dirname = os.path.join(source_dir, 'Aqueduct')

    zip_path = os.path.join(dirname, url.split('/')[-1])
    aqueduct_shp = os.path.join(dirname, 'aqueduct_global_dl_20150409.shp')
    aqueduct_tif = os.path.join(dirname, filename)

    nodata = "-3.4028234663852886e+38"

    aqueduct_gdal_layer = os.path.splitext(os.path.basename(aqueduct_shp))[0]

    return [
        # Download Aqueduct shapefile
        Step(
            targets=zip_path,
            dependencies=[],
            commands=[
                [ 'wget',
                  '--no-check-certificate',
                  '--directory-prefix', dirname,
                  url ]
            ]
        ),
        # Unzip shapefiles
        Step(
            targets=aqueduct_shp,
            dependencies=zip_path,
            commands=[
                [ 'unzip', '-d', dirname, zip_path ],
                [ 'touch', aqueduct_shp ]
            ]
        ),
        Step(
            targets=aqueduct_tif,
            dependencies=aqueduct_shp,
            commands=[
                ['gdal_rasterize',
                 '-init',     nodata,
                 '-a_nodata', nodata,
                 '-at',                          # include all touched pixels
                 '-te',       '-180 -90 180 90', # global extent
                 '-ts',       '43200 21600',     # 30-arc-second resolution
                 '-a',       'BWS',              # baseline water stress. needs to be clamped to (0,1)
                 '-ot',      'Float32',
                 '-sql',     '"SELECT MIN(MAX(BWS,0),1) AS BWS, geometry FROM {} WHERE BWS > -32767"'.format(aqueduct_gdal_layer),
                 '-dialect', 'sqlite',           # needed for two-argument min and max functions
                 '-co',      '"COMPRESS=deflate"',
                 aqueduct_shp,
                 aqueduct_tif]
            ]
        )
    ]

