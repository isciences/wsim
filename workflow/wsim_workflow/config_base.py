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

import abc
from . import dates

class ConfigBase(metaclass=abc.ABCMeta):

    distribution = "gev"

    @abc.abstractmethod
    def historical_years(self):
        """
        Provides a list of the years of historical record available for use
        during spin-up.
        """
        return []

    def historical_yearmons(self):
        """
        Provides all YYYYMM time steps within the historical period
        """
        return [dates.format_yearmon(year, month)
                for year in self.historical_years()
                for month in dates.all_months]

    @abc.abstractmethod
    def result_fit_years(self):
        """
        Provides a list of years of data to be considered in fitting distributions
        for computed variables.
        """
        return []

    def result_fit_yearmons(self):
        """
        Provides all YYYYMM time steps within the result fitting period
        """
        return [dates.format_yearmon(year, month)
                for year in self.result_fit_years()
                for month in dates.all_months]

    @abc.abstractmethod
    def static_data(self):
        pass

    @abc.abstractmethod
    def workspace(self):
        pass

    @abc.abstractmethod
    def observed_data(self):
        """
        Returns a Forcing instance capable of providing data for a given YYYYMM
        :return:
        """
        pass

    def forecast_data(self):
        """
        Returns a Forcing instance capable of providing data for a given YYYYMM/forecast target/ensemble member
        :return:
        """

    def global_prep(self):
        """
        Returns a (possibly empty) list of steps that are included exactly once in the Makefile, regardless
        of which time steps/forecasts/etc. are also present in the Makefile.
        :return:
        """
        return []

    def should_run_spinup(self):
        """
        Indicates whether this configuration requires a spinup phase.
        :return:
        """
        return True

    def should_run_lsm(self, yearmon=None):
        return True

    def result_postprocess_steps(self, yearmon=None, target=None, member=None):
        """
        Provides a list of one or more postprocessing steps to be applied to LSM results
        for a givem YYYYMM/forecast target/ensemble member
        """
        return []

    def forecast_targets(self, yearmon):
        """
        Provides a list of forecast target YYYYMM values for a given YYYYMM, or an empty
        list if the configuration does not contain forecasts.
        """
        return []

    def forecast_ensemble_members(self, yearmon):
        """
        Provides a list of forecast ensemble members for a given YYYYMM, or
        an empty list if the configuration does not contain forecasts.
        """
        return []

    @staticmethod
    def integration_windows():
        """
        Provides a list of integration windows (in months)
        """
        return [ 3, 6, 12, 24, 36, 60 ]

    @staticmethod
    def forcing_rp_vars():
        """
        Provides a list of forcing variables for which return periods should be calculated
        """
        return [
            'T',
            'Pr'
        ]

    @staticmethod
    def lsm_rp_vars():
        """
        Provides a list of LSM output variables for which return periods should be calculated
        """
        return [
            'Bt_RO',
            'PETmE',
            'PET',
            'P_net',
            'RO_mm',
            'Sa',
            'Sm',
            'Ws'
        ]

    @classmethod
    def lsm_integrated_vars(cls):
        """
        Provides a dictionary whose keys are LSM output variables to be time-integrated, and whose
        values are lists of stats to apply to each of those variables (min, max, ave, etc.)
        """
        return {
            'Bt_RO'     : [ 'min', 'max', 'sum' ],
            'E'         : [ 'sum' ],
            'PETmE'     : [ 'sum' ],
            'P_net'     : [ 'sum' ],
            'RO_mm'     : [ 'sum' ],
            'Ws'        : [ 'ave' ]
        }

    @classmethod
    def lsm_integrated_stats(cls):
        """
        Provides a dictionary whose keys are stat names and whose values are a list of variables
        two which that stat should be applied. It can be thought of as the inverse of lsm_integrated_vars()
        """
        integrated_stats = {}

        for var, varstats in cls.lsm_integrated_vars().items():
            for stat in varstats:
                if stat not in integrated_stats:
                    integrated_stats[stat] = []
                integrated_stats[stat].append(var)

        return integrated_stats


    @classmethod
    def lsm_integrated_var_names(cls):
        """
        Provides a flat list of time-integrated variable names
        """
        return [var + '_' + stat for var, stats in cls.lsm_integrated_vars().items() for stat in stats]
