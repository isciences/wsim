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
from paths import Vardef

from config_base import ConfigBase

class StaticNLDAS():

    def __init__(self, source):
        self.source = source
        self.file = os.path.join(self.source, 'static_nldas_grid.nc')

    def wc(self):
        return Vardef(self.file, 'Wc')

    def flowdir(self):
        return Vardef(self.file, 'flowdir')

    def elevation(self):
        return Vardef(self.file, 'elevation')

class NLDAS(paths.ObservedForcing):

    def __init__(self, source):
        self.source = source

    def precip_monthly(self, *, yearmon):
        return Vardef(os.path.join(self.source, 'NLDAS_FORA125_M.002', 'Pr', 'Pr_{yearmon}.img'.format(yearmon=yearmon)), '1')

    def temp_monthly(self, *, yearmon):
        return Vardef(os.path.join(self.source, 'NLDAS_FORA125_M.002', 'T', 'T_{yearmon}.img'.format(yearmon=yearmon)), '1')

    def p_wetdays(self, *, yearmon):
        return Vardef(os.path.join(self.source, 'NLDAS_FORA125_H.002/WetDay/pWetDay_{yearmon}.img'.format(yearmon=yearmon)), '1')

class NLDASConfig(ConfigBase):

    def __init__(self, source, derived):
        self._observed = NLDAS(source)
        self._static = StaticNLDAS('.')
        self._workspace = paths.DefaultWorkspace(derived)

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
