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
import paths

from step import Step
from paths import Vardef
from config_base import ConfigBase

from data_sources import isric, gmted, ntsg_drt

class StaticNLDAS(paths.Static):

    def __init__(self, source):
        super(StaticNLDAS, self).__init__(source)

    def global_prep_steps(self):
        tawc_raw = os.path.join(self.source, 'ISRIC', 'wise_0125deg_v1_tawc.tif')
        elev_raw = os.path.join(self.source, 'GMTED2010', 'gmted2010_0125deg.tif')
        flowdir_raw = os.path.join(self.source, 'NTSG_DRT', 'drt_flow_directions_0125deg.tif')

        return \
            gmted.global_elevation(source_dir=self.source, filename=elev_raw, resolution=0.125) + \
            isric.global_tawc(source_dir=self.source, filename=tawc_raw, resolution=0.125) + \
            ntsg_drt.global_flow_direction(filename=flowdir_raw, resolution=0.125) + \
            self.crop_to_nldas(tawc_raw, self.wc().file) + \
            self.crop_to_nldas(elev_raw, self.elevation().file) + \
            self.crop_to_nldas(flowdir_raw, self.flowdir().file)

    @staticmethod
    def crop_to_nldas(file_in, file_out):
        return [Step(
            targets=file_out,
            dependencies=file_in,
            commands=[[
                'gdalwarp',
                '-s_srs', 'EPSG:4326',
                '-t_srs', 'EPSG:4326',
                '-of', 'GTiff',
                '-te', '-125.0005', '25.0005', '-67.0005', '53.0005',
                '-co', 'COMPRESS=deflate',
                file_in, file_out
            ]]
        )]

    def wc(self):
        return paths.Vardef(os.path.join(self.source, 'ISRIC', 'wise_0125deg_nldas_v1_tawc.tif'), '1')

    def flowdir(self):
        return paths.Vardef(os.path.join(self.source, 'NTSG_DRT', 'drt_flow_directions_0125deg_nldas.tif'), var='1')

    def elevation(self):
        return paths.Vardef(os.path.join(self.source, 'GMTED2010', 'gmted2010_0125deg_nldas.tif'), '1')

class NLDAS(paths.ObservedForcing):

    def __init__(self, source):
        self.source = source

    def precip_monthly(self, *, yearmon, target=None, member=None):
        return Vardef(os.path.join(self.source, 'NLDAS_FORA125_M.002', 'Pr', 'Pr_{yearmon}.img'.format(yearmon=yearmon)), '1')

    def temp_monthly(self, *, yearmon, target=None, member=None):
        return Vardef(os.path.join(self.source, 'NLDAS_FORA125_M.002', 'T', 'T_{yearmon}.img'.format(yearmon=yearmon)), '1')

    def p_wetdays(self, *, yearmon, target=None, member=None):
        return Vardef(os.path.join(self.source, 'NLDAS_FORA125_H.002/WetDay/pWetDay_{yearmon}.img'.format(yearmon=yearmon)), '1')

class NLDASConfig(ConfigBase):

    def __init__(self, source, derived):
        self._observed = NLDAS(source)
        self._static = StaticNLDAS(source)
        self._workspace = paths.DefaultWorkspace(derived)

    def global_prep(self):
        return self._static.global_prep_steps()

    def historical_years(self):
        return range(1989, 2012)

    def result_fit_years(self):
        return range(1990, 2010)

    def observed_data(self):
        return self._observed

    def static_data(self):
        return self._static

    def workspace(self):
        return self._workspace

config = NLDASConfig
