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
import unittest

from config_cfs import NCEP
from config_nmme import NMMEForecast


class TestNMMEConfig(unittest.TestCase):
    source = '/tmp/source'
    derived = '/tmp/derived'

    def test_model_iteration_correct(self):
        # WSIM's "yearmon" variable is based on the last month of observed data available.
        # In other words, the "201901" model iteration is run in February 2019 using observed
        # data through the end of January 2019. This is different from the "reference time" used
        # in NMME files, which refers to the month in which the forecast was generated. A
        # confusing result of this offset is that we use the "201902" NMME data to produce
        # the "201901" WSIM run. This offset is handled by the NMME path generator, since
        # other parts of the code have no reason to know about this.

        observed = NCEP(self.source)
        nmme = NMMEForecast(self.source, self.derived, observed, 'Model3', 1969, 2008)

        params = {
            'yearmon': '201901',
            'target': '201904',
            'member': '8'
        }

        raw_fcst = nmme.forecast_raw(**params).split('::')[0]

        # the raw forecast file uses the WSIM month, 201901
        self.assertTrue(raw_fcst.endswith('model3_201901_trgt201904_fcst8.nc'))

        # and its dependencies use the NMME month, 201902
        anom_to_raw = [s for s in nmme.prep_steps(**params) if raw_fcst in s.targets][0]

        self.assertIn(os.path.join(nmme.model_dir(), 'clim', 'model3.prate.02.mon.clim.nc'), anom_to_raw.dependencies)
        self.assertIn(os.path.join(nmme.model_dir(), 'clim', 'model3.tmp2m.02.mon.clim.nc'), anom_to_raw.dependencies)

        self.assertIn(os.path.join(nmme.model_dir(), 'raw_anom', 'nmme_201902', 'model3.tmp2m.201902.anom.nc'),
                      anom_to_raw.dependencies)

        self.assertIn(os.path.join(nmme.model_dir(), 'raw_anom', 'nmme_201902', 'model3.prate.201902.anom.nc'),
                      anom_to_raw.dependencies)

        # when we bias-correct it,

