# Copyright (c) 2018-2019 ISciences, LLC.
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

from wsim_workflow.step import Step
from wsim_workflow import paths
from wsim_workflow.grids import Grid
from wsim_workflow.config_base import ConfigBase
from wsim_workflow.data_sources import ntsg_drt, hydrobasins

import os

GLDAS_GRID = Grid("gldas_025",
                  xmin=-180,
                  xmax=180,
                  ymin=-60,
                  ymax=90,
                  nx=1440,
                  ny=600)

# This file provides an example configuration using the results of the
# Noah land surface model, as run in GLDAS v2.0.
# This dataset is available from 1948-2014 at the following URL:
# https://disc.sci.gsfc.nasa.gov/datasets/GLDAS_NOAH025_M_V2.0/summary?keywords=GLDAS

class GLDAS20_NoahStatic(paths.Static):
    def __init__(self, source):
        super(GLDAS20_NoahStatic, self).__init__(source)

        self.flowdir_raw = os.path.join(self.source, 'NTSG_DRT', 'drt_flow_directions_025deg.asc')

    def global_prep_steps(self):
        return \
            ntsg_drt.global_flow_direction(self.flowdir_raw, resolution=0.25) + self.extend_flowdir() + \
            hydrobasins.basins(source_dir=self.source, filename=self.basins().file, level=7) + \
            hydrobasins.downstream_ids(source_dir=self.source, basins_file=self.basins().file, ids_file=self.basin_downstream().file)

    def extend_flowdir(self):
        return [Step(
            targets=self.flowdir().file,
            dependencies=self.flowdir_raw,
            commands=[[
                'gdalwarp',
                '-s_srs', 'EPSG:4326',
                '-t_srs', 'EPSG:4326',
                '-of', 'GTiff',
                '-te', '-180', '-60', '180', '90',
                '-co', 'COMPRESS=deflate',
                self.flowdir_raw, self.flowdir().file
            ]]
        )]

    def flowdir(self):
        return paths.Vardef(os.path.join(self.source, 'NTSG_DRT', 'drt_flow_directions_025deg_gldas.tif'), var='1')

    def basins(self):
        return paths.Vardef(os.path.join(self.source, 'HydroBASINS', 'basins_lev07.shp'), '1')

    def basin_downstream(self):
        return paths.Vardef(os.path.join(self.source, 'HydroBASINS', 'basins_lev07_downstream.nc'), 'next_down')


# Although the GLDAS configuration is rigged up in such a way that we have no
# "observed" dataset, we still require an observed dataset name.
class GLDASName:
    def name(self):
        return 'GLDAS20_Noah'


class GLDAS20_NoahConfig(ConfigBase):

    def __init__(self, source, derived):
        fit_start, *_, fit_end = self.result_fit_years()

        self._source = source
        self._static = GLDAS20_NoahStatic(source)
        self._workspace = paths.DefaultWorkspace(derived,
                                                 distribution=self.distribution,
                                                 fit_start_year=fit_start,
                                                 fit_end_year=fit_end)

    def global_prep(self):
        return self._static.global_prep_steps()

    def should_run_spinup(self):
        return True

    def should_run_lsm(self, yearmon=None):
        return False

    def historical_years(self):
        return range(1948, 2015)

    def result_fit_years(self):
        return range(1950, 2010)  # 1950-2009 gives even 60-year period

    def static_data(self):
        return self._static

    def observed_data(self):
        return GLDASName()

    def workspace(self):
        return self._workspace

    @staticmethod
    def integration_windows():
        return [3, 6, 12]

    @classmethod
    def forcing_rp_vars(cls, basis=None):
        return []

    @classmethod
    def forcing_integrated_vars(cls, basis=None):
        return {}

    @classmethod
    def lsm_rp_vars(cls, basis=None):
        if not basis:
            return [
                'Bt_RO',
                'PETmE',
                'RO_mm',
                'Ws',
                'T',
                'Pr'
            ]

        if basis == Basis.BASIN:
            return [
                'Bt_RO_m3'
            ]

        assert False

    @classmethod
    def state_rp_vars(cls, basis=None):
        return[]
        
    @classmethod
    def lsm_integrated_vars(cls, basis=None):
        if not basis:
            return {
                'Bt_RO': ['min', 'max', 'sum'],
                'PETmE': ['sum'],
                'RO_mm': ['sum'],
                'Ws': ['ave'],
                'T': ['ave'],
                'Pr': ['sum']
            }

        if basis == 'basin':
            return {
                'Bt_RO_m3': ['sum']
            }

        assert False

    def result_postprocess_steps(self, model=None, yearmon=None, target=None, member=None):
        input_file = os.path.join(self._source,
                                  'GLDAS_NOAH025_M.A{}.020.nc4'.format(yearmon))

        output_file = self.workspace().results(yearmon=yearmon, window=1)

        return [
            Step(
                targets=output_file,
                dependencies=[input_file, self.static_data().flowdir().file],
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'gldas_noah_extract.R'),
                        '--input', input_file,
                        '--output', output_file
                    ],
                    [
                        os.path.join('{BINDIR}', 'wsim_flow.R'),
                        '--input', paths.read_vars(output_file, 'RO_m3'),
                        '--flowdir', self.static_data().flowdir().file,
                        '--output', output_file,
                        '--varname', 'Bt_RO',
                        '--wrapx'
                    ]
                ]
            )
        ]


config = GLDAS20_NoahConfig
