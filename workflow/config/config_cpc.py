import os
from typing import Iterable, List

from wsim_workflow.config_base import ConfigBase
from wsim_workflow.step import Step

import wsim_workflow.paths as paths

from wsim_workflow.data_sources import cpc_daily_temperature, cpc_daily_precipitation

from config_cfs import CFSForecast, CFSStatic


class CPC(paths.ObservedForcing):

    def __init__(self, source):
        self.source = source

        self.temp_workdir = os.path.join(self.source, 'CPC_Global_Daily_Temperature', 'raw')
        self.precip_workdir = os.path.join(self.source, 'CPC_Global_Daily_Precipitation', 'raw')

    def prep_steps(self, *, yearmon: str) -> List[Step]:
        return \
            cpc_daily_temperature.download_monthly_temperature(
                yearmon=yearmon,
                workdir=self.temp_workdir,
                output_filename=self.temp_monthly(yearmon=yearmon).file) + \
            cpc_daily_precipitation.download_monthly_precipitation(
                yearmon=yearmon,
                workdir=self.precip_workdir,
                precipitation_fname=self.precip_monthly(yearmon=yearmon).file,
                wetdays_fname=self.p_wetdays(yearmon=yearmon).file)

    def precip_monthly(self, *, yearmon: str) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'CPC_Global_Daily_Precipitation', 'monthly_sum', 'P_{}.nc'.format(yearmon)), 'Pr')

    def temp_monthly(self, *, yearmon: str) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'CPC_Global_Daily_Temperature', 'monthly_mean', 'T_{}.nc'.format(yearmon)), 'tavg')

    def p_wetdays(self, *, yearmon: str) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'CPC_Global_Daily_Precipitation', 'monthly_wetdays', 'pWetDays_{}.nc'.format(yearmon)), 'pWetDays')


class CPCConfig(ConfigBase):
    def result_fit_years(self) -> Iterable[int]:
        return range(1981, 2019)

    def static_data(self):
        return self._static

    def workspace(self) -> paths.DefaultWorkspace:
        return self._workspace

    def observed_data(self) -> paths.ObservedForcing:
        return self._observed

    def historical_years(self):
        return range(1979, 2019)  # 1979 to 2018

    def __init__(self, source, derived):
        self._observed = CPC(source)
        self._forecast = {
            'CFSv2':  CFSForecast(source, derived, self._observed),
        }
        self._static = CFSStatic(source)
        self._workspace = paths.DefaultWorkspace(derived)


config = CPCConfig
