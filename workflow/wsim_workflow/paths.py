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

import os
import re

from abc import ABCMeta, abstractmethod
from enum import Enum
from typing import Union, List, Optional

from . import step

RE_GDAL_DATASET = re.compile('^(?P<driver>\w+:)?(?P<filename>[^:]+)(?P<dataset>:\w+)?$')


class Basis(Enum):
    BASIN = 'basin'
    COUNTRY = 'country'
    POWER_PLANT = 'power_plant'
    PROVINCE = 'province'


class Method(Enum):
    RAINFED = 'rainfed'
    IRRIGATED = 'irrigated'


class Sector(Enum):
    AGRICULTURE = 'agriculture'
    ELECTRIC_POWER = 'electric_power'


def gdaldataset2filename(dataset: str) -> str:
    return re.search(RE_GDAL_DATASET, dataset).group('filename')


def read_vars(*args) -> str:
    file = args[0]
    var_list = args[1:]

    return file + '::' + ','.join(var_list)


def date_range(*args):
    """
    Create a date range string (as used by the wsim.io R package) given any of:
    - start, stop
    - start, stop, step
    - list (from which start and stop will be extracted, and a step of 1 assumed)
    """
    step = 1

    if len(args) == 1 and type(args[0]) is list:
        begin = args[0][0]
        end = args[0][-1]
    elif len(args) >= 2:
        begin = args[0]
        end = args[1]

        if len(args) == 3:
            step = args[2]
    else:
        raise Exception('Invalid date range')

    return '[{}:{}:{}]'.format(begin, end, step)


class Vardef:

    def __init__(self, file: str, var: Optional[str]):
        self.file = file
        self.var = var

    def read_as(self, new_name: str) -> str:
        assert self.var is not None

        return self.file + '::' + self.var + '->' + new_name

    def __str__(self) -> str:
        if self.var is None:
            return self.file
        else:
            return self.file + '::' + self.var


class ObservedForcing(metaclass=ABCMeta):

    @abstractmethod
    def precip_monthly(self, *, yearmon: str) -> Vardef:
        """
        Return a Vardef for the precipitation variable
        """
        pass

    @abstractmethod
    def temp_monthly(self, *, yearmon: str) -> Vardef:
        """
        Return a Vardef for the average monthly temparature
        """
        pass

    @abstractmethod
    def p_wetdays(self, *, yearmon: str) -> Vardef:
        """
        Return a Vardef for the percentage of wet days in a month
        """
        pass

    @abstractmethod
    def mean_p_wetdays(self, month: int) -> Vardef:
        """
        Return a Vardef for the long-term mean of pWetDays. This is
        typically needed by forecast data.
        """
        pass

    def prep_steps(self, *, yearmon: str) -> List[step.Step]:
        """
        Returns one or more Steps needed to prepare this dataset for use
        for a given yearmon
        """
        return []

    def global_prep_steps(self) -> List[step.Step]:
        """
        Returns one or more Steps needed to prepare this dataset for use
        (included only once for all yearmons)
        """
        return []


class ForecastForcing(metaclass=ABCMeta):

    @abstractmethod
    def precip_monthly(self, *, yearmon: str, target: str, member: str) -> Vardef:
        """
        Return a Vardef for the precipitation variable
        """
        pass

    @abstractmethod
    def temp_monthly(self, *, yearmon: str, target: str, member: str) -> Vardef:
        """
        Return a Vardef for the average monthly temperature
        """
        pass

    @abstractmethod
    def p_wetdays(self, *, yearmon: str, target: str, member: str) -> Vardef:
        """
        Return a Vardef for the percentage of wet days in a month
        """
        pass

    @abstractmethod
    def fit_obs(self, *, var, month):
        """
        Return a fit of observed data for `var` during `month`
        """
        pass

    @abstractmethod
    def fit_retro(self, *, var, target_month, lead_months):
        """
        Return a hindcast fit for forecast of `var` during `target_month` as estimated `lead_months` ahead
        """
        pass

    @abstractmethod
    def forecast_raw(self, *, yearmon: str, target: str, member: str) -> str:
        pass

    @abstractmethod
    def forecast_corrected(self, *, yearmon: str, target: str, member: str) -> str:
        pass

    @abstractmethod
    def observed(self) -> ObservedForcing:
        """
        Return a link to an associated set of observed data, for use in bias-correcting the forecast.
        """
        pass

    def prep_steps(self, *, yearmon, target, member):
        """
        Returns one or more Steps needed to prepare this dataset for use
        for a given yearmon/target month/ensemble member
        """
        return []

    @staticmethod
    def requires_bias_correction() -> bool:
        return True

    @staticmethod
    def global_prep_steps():
        """
        Returns one or more Steps needed to prepare this dataset for use
        (included only once for all yearmons/targets/members)
        """
        return []


class Static(metaclass=ABCMeta):

    def __init__(self, source):
        self.source = source

    def global_prep_steps(self) -> List[step.Step]:
        pass

    def wc(self) -> Vardef:
        pass

    def flowdir(self) -> Vardef:
        pass

    def elevation(self) -> Vardef:
        pass


class ElectricityStatic(metaclass=ABCMeta):

    def __init__(self, source):
        self.source = source

    def global_prep_steps(self) -> List[step.Step]:
        pass

    def basins(self) -> Vardef:
        pass

    def basin_downstream(self) -> Vardef:
        pass

    def water_stress(self) -> Vardef:
        pass

    def dam_locations(self) -> Vardef:
        pass

    def power_plants(self) -> Vardef:
        pass

    def countries(self) -> Vardef:
        pass

    def provinces(self) -> Vardef:
        pass


class AgricultureStatic(metaclass=ABCMeta):

    def __init__(self, source):
        self.source = source

    @abstractmethod
    def crop_calendar(self, method: Method) -> str:
        pass

    @abstractmethod
    def production(self, method: Method) -> Vardef:
        pass

    @abstractmethod
    def ag_yield_anomaly_model(self, model_name: str) -> str:
        pass

    def basins(self) -> Vardef:
        pass

    def countries(self) -> Vardef:
        pass

    def provinces(self) -> Vardef:
        pass



class DefaultWorkspace:

    def __init__(self, outputs: str, tempdir: Optional[str]=None):
        self.outputs = outputs
        if tempdir:
            self.tempdir = tempdir
        else:
            self.tempdir = os.path.join(self.outputs, '.tmp')

    def root(self) -> str:
        return self.outputs

    def make_path(self, thing: str, *,
                  year: int=None,
                  yearmon: str=None,
                  window: int=None,
                  target: str=None,
                  model: Optional[str] = None,
                  member: str=None,
                  temporary: bool=False,
                  basis: Optional[Basis]=None,
                  summary: bool=False,
                  sector: Optional[Sector]=None,
                  method: Optional[Method]=None) -> str:

        assert (year is None) != (yearmon is None)
        assert (member is None) == (model is None)

        if target:
            assert (summary and member is None) or (not summary and member is not None)
        elif sector != Sector.AGRICULTURE:
            assert not summary
            assert member is None

        if temporary:
            root = self.tempdir
        else:
            root = self.outputs

        if sector:
            root = os.path.join(root, sector.value)

        ret = os.path.join(root,
                            self.make_dirname(thing,
                                              window=window,
                                              basis=basis,
                                              summary=summary,
                                              annual=year is not None,
                                              model=model,
                                              method=method),
                            self.make_filename(thing,
                                               time=yearmon or year,
                                               window=window,
                                               target=target,
                                               member=member,
                                               basis=basis,
                                               model=model,
                                               summary=summary))

        # TODO normalize these paths?
        if thing in {'composite', 'composite_adjusted', 'composite_anom', 'composite_anom_rp'}:
            return ret.replace('_integrated', '').replace('_summary', '')

        return ret

    @staticmethod
    def make_stem(thing: str, *,
                  basis: Optional[Basis] = None,
                  method: Optional[str] = None,
                  model: Optional[str] = None,
                  summary: Optional[bool] = False) -> str:
        return '_'.join(filter(None, (basis.value if basis else None, thing, method, 'summary' if summary else None, model)))

    @staticmethod
    def make_dirname(thing, *,
                     window: int,
                     basis: Basis,
                     summary: bool,
                     annual: bool,
                     model: Optional[str] = None,
                     method: Method) -> str:
        return '_'.join(filter(None, (basis.value if basis else None,
                                      thing,
                                      method.value if method else None,
                                      'integrated' if window and window > 1 else None,
                                      'summary' if summary else None,
                                      'annual' if annual else None
                                      )))

    @staticmethod
    def make_filename(thing: str, *,
                      time: Union[int, str]=None,
                      window: Optional[int]=None,
                      target: Optional[str]=None,
                      model: Optional[str] = None,
                      member: Optional[str]=None,
                      basis: Optional[Basis]=None,
                      method: Optional[str]=None,
                      summary: bool=False) -> str:
        filename = DefaultWorkspace.make_stem(thing, basis=basis, method=method, summary=summary)

        assert (model is None) == (member is None)

        if window:
            filename += '_{window}mo'

        filename += '_{time}'

        if target:
            filename += '_trgt{target}'

        if member:
            filename += '_fcst{model}_{member}'

        filename += '.nc'

        return filename.format(thing=thing,
                               method=method,
                               window=window,
                               time=time,
                               target=target,
                               model=model.lower() if model else None,
                               member=member,
                               basis=basis.value if basis else None)

    # Summaries of data from multi-member forecast ensembles
    def composite_summary(self, *, yearmon: str, window: int, target: Optional[str]=None) -> str:
        assert window is not None
        return self.make_path('composite',
                              yearmon=yearmon,
                              window=window,
                              summary=target is not None,
                              target=target)

    def composite_summary_adjusted(self, *, yearmon: str, window: int, target: Optional[str]=None) -> str:
        return self.make_path('composite_adjusted',
                              yearmon=yearmon,
                              summary=target is not None,
                              window=window,
                              target=target)

    def composite_anomaly(self, *, yearmon: str, window: int, target: Optional[str]=None) -> str:
        return self.make_path('composite_anom',
                              yearmon=yearmon,
                              summary=target is not None,
                              window=window,
                              target=target)

    def composite_anomaly_return_period(self, *,
                                        yearmon: str,
                                        window: int,
                                        target: Optional[str]=None,
                                        temporary: bool=False) -> str:
        return self.make_path('composite_anom_rp',
                              yearmon=yearmon,
                              window=window,
                              target=target,
                              summary=target is not None,
                              temporary=temporary)

    def return_period_summary(self, *, yearmon: str, window: int, target: str) -> str:
        assert window is not None

        return self.make_path('rp', yearmon=yearmon, window=window, target=target, summary=True)

    def standard_anomaly_summary(self, *, yearmon: str, window: int, target: str) -> str:
        assert window is not None

        return self.make_path('anom', yearmon=yearmon, window=window, target=target, summary=True)

    def forcing_summary(self, *, yearmon: str, target: str, window: int) -> str:
        return self.make_path('forcing', yearmon=yearmon, target=target, window= window, summary=True)

    def results_summary(self, *, yearmon: str, window: int, target: Optional[str]=None) -> str:
        return self.make_path('results', yearmon=yearmon, window=window, target=target, summary=True)

    # Individual model inputs, outputs, and derivatives
    def state(self, *,
              sector: Optional[Sector]=None,
              yearmon: str,
              model: Optional[str] = None,
              member: Optional[str]=None,
              target: Optional[str]=None,
              method: Optional[Method]=None) -> str:
        assert (sector == Sector.AGRICULTURE) == (method is not None)

        return self.make_path('state', sector=sector, yearmon=yearmon, model=model, member=member, target=target, window=None, method=method)

    def forcing(self, *,
                yearmon: str,
                window: int,
                model: Optional[str] = None,
                member: Optional[str]=None,
                target: Optional[str]=None,
                basis: Optional[Basis]=None) -> str:
        return self.make_path('forcing', model=model, yearmon=yearmon, member=member, target=target, window=window, basis=basis)

    def results(self, *,
                sector: Optional[Sector]=None,
                year: Optional[int]=None,
                yearmon: Optional[str]=None,
                window: int,
                member: Optional[str]=None,
                model: Optional[str] = None,
                target: Optional[str]=None,
                temporary: bool=False,
                basis: Optional[Basis]=None,
                method: Optional[Method]=None,
                summary: Optional[bool]=False) -> str:

        assert window is not None

        if year:
            # Check that "annual" summaries are not generated for return periods
            # greater than one year.
            assert window < 12

        return self.make_path('results',
                              sector=sector,
                              method=method,
                              year=year,
                              yearmon=yearmon,
                              window=window,
                              model=model,
                              member=member,
                              target=target,
                              temporary=temporary,
                              basis=basis,
                              summary=summary)

    def return_period(self, *,
                      yearmon: str,
                      window: int,
                      model: Optional[str] = None,
                      member: Optional[str]=None,
                      target: Optional[str]=None,
                      temporary: bool=False,
                      basis: Optional[Basis]=None) -> str:

        assert window is not None

        return self.make_path('rp',
                              yearmon=yearmon,
                              window=window,
                              model=model,
                              member=member,
                              target=target,
                              temporary=temporary,
                              basis=basis)

    def standard_anomaly(self, *,
                         yearmon: str,
                         window: int,
                         model: Optional[str] = None,
                         member: Optional[str]=None,
                         target: Optional[str]=None,
                         temporary: bool=False,
                         basis: Optional[Basis]=None) -> str:

        assert window is not None

        return self.make_path('anom',
                              yearmon=yearmon,
                              window=window,
                              model=model,
                              member=member,
                              target=target,
                              temporary=temporary,
                              basis=basis)

    # Spinup files
    def initial_state(self) -> str:
        return os.path.join(self.outputs, 'spinup', 'initial_state.nc')

    def climate_norm_forcing(self, *, month: int, temporary: bool=False) -> str:
        return os.path.join(self.tempdir if temporary else self.outputs,
                            'spinup',
                            'climate_norm_forcing_{month:02d}.nc'.format(month=month))

    def final_state_norms(self) -> str:
        return os.path.join(self.outputs, 'spinup', 'final_state_norms.nc')

    def spinup_state(self, yearmon: str) -> str:
        return os.path.join(self.outputs, 'spinup', 'spinup_state_{yearmon}.nc'.format(yearmon=yearmon))

    def spinup_state_pattern(self) -> str:
        return self.spinup_state(yearmon='%T')

    def spinup_mean_state(self, *, month: int) -> str:
        return os.path.join(self.outputs, 'spinup', 'spinup_mean_state_month_{month:02d}.nc'.format(month=month))

    def tag(self, name):
        return os.path.join(self.outputs, 'tags', name)

    # Electricity assessment misc
    def basin_loss_factors(self, *, yearmon: str, model: Optional[str], target: Optional[str], member: Optional[str]) -> str:
        return self.make_path('loss_factors', sector=Sector.ELECTRIC_POWER, yearmon=yearmon, window=12, target=target, model=model, member=member, basis=Basis.BASIN)

    def basin_upstream_storage(self, sector: Sector) -> str:
        return os.path.join(self.outputs, sector.value, 'spinup', 'basin_upstream_storage.nc')

    def basin_water_stress(self) -> str:
        return os.path.join(self.outputs, Sector.ELECTRIC_POWER.value, 'basin_baseline_water_stress.nc')

    def power_plants(self) -> str:
        return os.path.join(self.outputs, Sector.ELECTRIC_POWER.value, 'spinup', 'power_plants.nc')

    # Ag assessment misc
    def agriculture_bt_ro_rp(self, *, yearmon: str, model: Optional[str]=None, target: Optional[str]=None, member: Optional[str]=None) -> str:
        return self.make_path('bt_ro_rp', sector=Sector.AGRICULTURE, model=model, yearmon=yearmon, target=target, member=member)

    def loss_params(self, *, sector: Sector, method: Method):
        assert sector == Sector.AGRICULTURE

        return os.path.join(self.outputs, sector.value, 'spinup', 'loss_params_{}.csv'.format(method.value))

    # Distribution fit files. Must provide either a numeric month, or an annual_stat
    def fit_obs(self, *,
                var: str,
                month: Optional[int]=None,
                window: int,
                stat: Optional[str]=None,
                basis: Optional[Basis]=None,
                annual_stat: Optional[str]=None) -> str:
        assert window is not None
        assert (annual_stat is None) != (month is None)

        if basis:
            basis = basis.value
            filename = '{basis}_{var}'
        else:
            filename = '{var}'

        if stat:
            filename += '_{stat}'

        if window:
            filename += '_{window}mo'

        if annual_stat:
            filename += '_annual_{annual_stat}'

        if month:
            filename += '_month_{month:02d}'

        filename += '.nc'

        return os.path.join(self.outputs, 'fits', filename.format_map(locals()))

    def fit_composite_anomalies(self, *, indicator: str, window: int) -> str:
        return os.path.join(self.outputs,
                            'fits',
                            'composite_anom_{indicator}_{window}mo.nc'.format(window=window,
                                                                              indicator=indicator))


