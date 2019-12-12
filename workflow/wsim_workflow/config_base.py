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

from typing import Dict, List, Optional, Iterable, Tuple

import abc
from . import dates
from . import paths
from .paths import Basis
from .step import Step


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
    def result_fit_years(self) -> Iterable[int]:
        """
        Provides a list of years of data to be considered in fitting distributions
        for computed variables.
        """
        return []

    def result_fit_yearmons(self) -> List[str]:
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
    def workspace(self) -> paths.DefaultWorkspace:
        pass

    @abc.abstractmethod
    def observed_data(self) -> paths.ObservedForcing:
        """
        Returns a Forcing instance capable of providing data for a given YYYYMM
        :return:
        """
        pass

    def forecast_data(self, model: str) -> paths.ForecastForcing:
        """
        Returns a Forcing instance capable of providing data for a given YYYYMM/forecast target/ensemble member
        :return:
        """
        pass

    def global_prep(self) -> List[Step]:
        """
        Returns a (possibly empty) list of steps that are included exactly once in the Makefile, regardless
        of which time steps/forecasts/etc. are also present in the Makefile.
        :return:
        """
        steps = self.static_data().global_prep_steps() + self.observed_data().global_prep_steps()
        for model in self.models():
            steps += self.forecast_data(model).global_prep_steps()
        return steps

    def should_run_spinup(self) -> bool:
        """
        Indicates whether this configuration requires a spinup phase.
        :return:
        """
        return True

    def should_run_lsm(self, yearmon: Optional[str]=None) -> bool:
        return True

    def result_postprocess_steps(self, model: str = None, yearmon: str = None, target: str = None, member: str = None) -> List[Step]:
        """
        Provides a list of one or more postprocessing steps to be applied to LSM results
        for a given YYYYMM/forecast target/ensemble member
        """
        return []

    def forecast_targets(self, yearmon: str) -> List[str]:
        """
        Provides a list of forecast target YYYYMM values for a given YYYYMM, or an empty
        list if the configuration does not contain forecasts.
        """
        return []

    def models(self) -> List[str]:
        """
        Provides a list of forecast models used in this configuration.
        """
        return []

    def forecast_ensemble_members(self, model: str, yearmon: str, *, lag_hours: Optional[int] = None) -> List[str]:
        """
        Provides a list of forecast ensemble members for a given YYYYMM, or
        an empty list if the configuration does not contain forecasts.
        If `lag_hours` is provided, only return ensemble members generated
        within more than `lag_hours` from present time.
        """
        return []

    def weighted_members(self, yearmon: str) -> Iterable[Tuple[str, str, float]]:
        for model in self.models():
            members = self.forecast_ensemble_members(model, yearmon)
            for member in members:
                weight = 1.0/len(members)/len(self.models())
                yield model, member, weight

    @staticmethod
    def integration_windows() -> List[int]:
        """
        Provides a list of integration windows (in months)
        """
        return [3, 6, 12, 24, 36, 60]

    @staticmethod
    def forcing_rp_vars(*, basis: Optional[Basis]=None) -> List[str]:
        """
        Provides a list of forcing variables for which return periods should be calculated
        """
        if not basis:
            return [
                'T',
                'Pr'
            ]

        if basis == Basis.BASIN:
            return [
                'T',
                'Pr'
            ]

        assert False

    @staticmethod
    def lsm_rp_vars(*, basis: Optional[Basis]=None) -> List[str]:
        """
        Provides a list of LSM output variables for which return periods should be calculated
        """

        if not basis:
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

        if basis == Basis.BASIN:
            return [
                'Bt_RO'
            ]

        assert False


    @staticmethod
    def state_rp_vars(*, basis: Optional[Basis]=None) -> List[str]:
        """
        Provides a list of state variables for which return periods should be calculated
        """

        if not basis:
            return['Snowpack']

        if basis == Basis.BASIN:
            return []

    @classmethod
    def forcing_integrated_vars(cls, basis: Optional[Basis]=None) -> Dict[str, List[str]]:
        """
        Provides a dictionary whose keys are forcing variables to be time-integrated, and whose
        values are lists of stats to apply to each of those variables (min, max, ave, etc.)
        """
        if not basis or basis == Basis.BASIN:
            return {
                'Pr'   : ['sum'],
                'T'    : ['ave']
                }
        
        assert False
            
    @classmethod
    def lsm_integrated_vars(cls, basis: Optional[Basis]=None) -> Dict[str, List[str]]:
        """
        Provides a dictionary whose keys are LSM output variables to be time-integrated, and whose
        values are lists of stats to apply to each of those variables (min, max, ave, etc.)
        """

        if not basis:
            return {
                'Bt_RO': ['min', 'max', 'sum'],
                'E': ['sum'],
                'PETmE': ['sum'],
                'P_net': ['sum'],
                'RO_mm': ['sum'],
                'Sa'   : ['sum'],
                'Ws': ['ave'],
            }

        if basis == Basis.BASIN:
            return {
                'Bt_RO': ['sum']
            }

        assert False

    @classmethod
    def lsm_integrated_stats(cls, basis: Optional[Basis]=None) -> Dict[str, List[str]]:
        """
        Provides a dictionary whose keys are stat names and whose values are a list of variables
        two which that stat should be applied. It can be thought of as the inverse of lsm_integrated_vars()
        """
        integrated_stats = {}

        for var, varstats in cls.lsm_integrated_vars(basis=basis).items():
            for stat in varstats:
                if stat not in integrated_stats:
                    integrated_stats[stat] = []
                integrated_stats[stat].append(var)

        return integrated_stats

    @classmethod
    def lsm_integrated_var_names(cls, basis: Optional[Basis]=None) -> List[str]:
        """
        Provides a flat list of time-integrated variable names
        """
        return [var + '_' + stat for var, stats in cls.lsm_integrated_vars(basis=basis).items() for stat in stats]


    @classmethod
    def forcing_integrated_stats(cls, basis: Optional[Basis]=None) -> Dict[str, List[str]]:
        """
        Provides a dictionary whose keys are stat names and whose values are a list of variables
        two which that stat should be applied. It can be thought of as the inverse of forcing_integrated_vars()
        """
        integrated_stats = {}

        for var, varstats in cls.forcing_integrated_vars(basis=basis).items():
            for stat in varstats:
                if stat not in integrated_stats:
                    integrated_stats[stat] = []
                integrated_stats[stat].append(var)

        return integrated_stats

    @classmethod
    def forcing_integrated_var_names(cls, basis: Optional[Basis]=None) -> List[str]:
        """
        Provides a flat list of time-integrated variable names
        """
        return [var + '_' + stat for var, stats in cls.forcing_integrated_vars(basis=basis).items() for stat in stats]

    @classmethod
    def all_integrated_stats(cls, basis: Optional[Basis]=None) -> Dict[str, List[str]]:
        """
        Provides a dictionary whose keys are stat names and whose values are a list of variables
        two which that stat should be applied. This combines the inverse of forcing_integrated_vars()
        and lsm_integrated_vars().
        """
        integrated_stats = cls.lsm_integrated_stats(basis=basis)

        for var, varstats in cls.forcing_integrated_vars(basis=basis).items():
            for stat in varstats:
                if stat not in integrated_stats:
                    integrated_stats[stat] = []
                integrated_stats[stat].append(var)

        return integrated_stats


