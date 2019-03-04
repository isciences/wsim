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

# This configuration file is provided as an example of an automated operational WSIM workflow.

import os
import re

from typing import List

from wsim_workflow import commands
from wsim_workflow import dates
from wsim_workflow import paths

from wsim_workflow.config_base import ConfigBase
from wsim_workflow.data_sources import aqueduct, grand, hydrobasins, isric, gadm, gmted, gppd, stn30, natural_earth, mirca2000, spam2010
from wsim_workflow.step import Step


class CFSStatic(paths.Static, paths.ElectricityStatic, paths.AgricultureStatic):
    def __init__(self, source):
        super(CFSStatic, self).__init__(source)

    def global_prep_steps(self):
        return \
            aqueduct.baseline_water_stress(source_dir=self.source, filename=self.water_stress().file) + \
            gmted.global_elevation(source_dir=self.source, filename=self.elevation().file, resolution=0.5) + \
            isric.global_tawc(source_dir=self.source, filename=self.wc().file, resolution=0.5) + \
            stn30.global_flow_direction(source_dir=self.source, filename=self.flowdir().file, resolution=0.5) + \
            gadm.admin_boundaries(source_dir=self.source, levels=[0,1]) + \
            gppd.power_plant_database(source_dir=self.source) + \
            grand.dam_locations(source_dir=self.source) + \
            hydrobasins.basins(source_dir=self.source, filename=self.basins().file, level=5) + \
            hydrobasins.downstream_ids(source_dir=self.source, basins_file=self.basins().file, ids_file=self.basin_downstream().file) + \
            natural_earth.natural_earth(source_dir=self.source, layer='coastline', resolution=10) + \
            mirca2000.crop_calendars(source_dir=self.source) + \
            spam2010.production(source_dir=self.source) + \
            [Step(targets='/tmp/factors.csv', commands=[['touch', '/tmp/factors.csv']])] # TODO

    # Static inputs
    def wc(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'ISRIC', 'wise_05deg_v1_tawc.tif'), '1')

    def flowdir(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'STN_30', 'g_network.asc'), '1')

    def elevation(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'GMTED2010', 'gmted2010_05deg.tif'), '1')

    def basins(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'HydroBASINS', 'basins_lev05.shp'), None)

    def basin_downstream(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'HydroBASINS', 'basins_lev05_downstream.nc'), 'next_down')

    def dam_locations(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'GRanD', 'GRanD_dams_v1_1.shp'), None)

    def water_stress(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'Aqueduct', 'aqueduct_baseline_water_stress.tif'), '1')

    def power_plants(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'GPPD', 'gppd_inferred_cooling.nc'), None)

    def countries(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'GADM', 'gadm36_level_0.gpkg'), None)

    def provinces(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'GADM', 'gadm36_level_1.gpkg'), None)

    def crop_calendar(self, method: str) -> str:
        return os.path.join(self.source, 'MIRCA2000', 'crop_calendar_{}.nc'.format(method))

    def growth_stage_loss_factors(self) -> str:
        # FIXME
        return '/tmp/factors.csv'

    def production(self, crop: str, method: str) -> str:
        return os.path.join(self.source_dir, spam2010.SUBDIR, spam2010.spam_production_tif())

class NCEP(paths.ObservedForcing):

    def __init__(self, source):
        self.source = source

    def global_prep_steps(self):
        return \
            self.download_monthly_temp_and_precip_files() + \
            self.compute_wetday_ltmeans(1979, 2008)

    def download_monthly_temp_and_precip_files(self):
        """
        Steps to download (or update) the t.long and p.long full data sets from NCEP.
        Because this is a single step (no matter which yearmon we're running), we can't
        include it in prep_steps below.
        """
        return [
            Step(
                targets=self.full_temp_file(),
                dependencies=[],
                commands=[
                    [
                        'wget', '--continue',
                        '--directory-prefix', os.path.join(self.source, 'NCEP'),
                        'ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/t.long'
                    ]
                ]
            ),
            Step(
                targets=self.full_precip_file(),
                dependencies=[],
                commands=[
                    [
                        'wget', '--continue',
                        '--directory-prefix', os.path.join(self.source, 'NCEP'),
                        'ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/p.long'
                    ]
                ]
            )
        ]

    def compute_wetday_ltmeans(self, start_year: int, stop_year: int) -> List[Step]:
        """
        Steps to compute long-term means in wetdays that can be used
        for months where daily precipitation data is not available
        """
        steps = []

        wetday_ltmean_years = range(start_year, stop_year + 1)
        for month in range(1, 13):
            input_vardefs = [self.p_wetdays(yearmon=dates.format_yearmon(year, month)) for year in wetday_ltmean_years]
            ltmean_file = self.p_wetdays(yearmon=dates.format_yearmon(start_year - 1, month)).file,

            steps.append(
                commands.wsim_integrate(
                    stats=['ave'],
                    inputs=input_vardefs,
                    output=ltmean_file,
                    keepvarnames=True
                )
            )

        return steps

    def prep_steps(self, *, yearmon):
        """
        Prep steps are data preparation tasks that are executed once per model iteration.
        They may include downloading, unpackaging, aggregation, or conversion of data inputs.

        :param yearmon: yearmon of model iteration
        :return: a list of Steps
        """
        steps = []

        year, month = dates.parse_yearmon(yearmon)

        # Extract netCDF of monthly precipitation from full binary file
        steps.append(
            Step(
                targets=self.precip_monthly(yearmon=yearmon).file,
                dependencies=self.full_precip_file(),
                commands=[
                    [
                        os.path.join('{BINDIR}',
                                     'utils',
                                     'noaa_global_leaky_bucket',
                                     'read_binary_grid.R'),
                        '--input',   self.full_precip_file(),
                        '--update_url', 'ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/p.long',
                        '--output',  self.precip_monthly(yearmon=yearmon).file,
                        '--var',     'P',
                        '--yearmon', yearmon,
                    ]
                ]
            )
        )

        # Extract netCDF of monthly temperature from full binary file
        steps.append(
            Step(
                targets=self.temp_monthly(yearmon=yearmon).file,
                dependencies=self.full_temp_file(),
                commands=[
                    [
                        os.path.join('{BINDIR}',
                                     'utils',
                                     'noaa_global_leaky_bucket',
                                     'read_binary_grid.R'),
                        '--input',   self.full_temp_file(),
                        '--update_url', 'ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/t.long',
                        '--output',  self.temp_monthly(yearmon=yearmon).file,
                        '--var',     'T',
                        '--yearmon', yearmon
                    ]
                ]
            )
        )

        if year >= 1979:
            # Download and process files in a single command
            # We do this to avoid including 365 files/year as
            # individual dependencies, clogging up the Makefile.
            #
            # If the precip files already exist, they won't be
            # re-downloaded.
            steps.append(
                Step(
                    targets=self.p_wetdays(yearmon=yearmon).file,
                    dependencies=[],
                    commands=[
                        [
                            os.path.join('{BINDIR}',
                                         'utils',
                                         'noaa_cpc_daily_precip',
                                         'download_noaa_cpc_daily_precip.py'),
                            '--yearmon', yearmon,
                            '--output_dir', os.path.join(self.source,
                                                         'NCEP',
                                                         'daily_precip')
                        ],
                        [
                            os.path.join('{BINDIR}',
                                         'utils',
                                         'noaa_cpc_daily_precip',
                                         'compute_noaa_cpc_pwetdays.py'),
                            '--bindir', '{BINDIR}',
                            '--yearmon', yearmon,
                            '--input_dir', os.path.join(self.source,
                                                        'NCEP',
                                                        'daily_precip'),
                            '--output_dir', os.path.join(self.source,
                                                         'NCEP',
                                                         'wetdays')
                        ]
                    ]
                )
            )

        return steps

    def full_temp_file(self):
        return os.path.join(self.source, 'NCEP', 't.long')

    def full_precip_file(self):
        return os.path.join(self.source, 'NCEP', 'p.long')

    def temp_monthly(self, *, yearmon, target=None, member=None):
        return paths.Vardef(os.path.join(self.source, 'NCEP', 'T', 'T_{yearmon}.nc'.format(yearmon=yearmon)), 'T')

    def precip_monthly(self, *, yearmon, target=None, member=None):
        return paths.Vardef(os.path.join(self.source, 'NCEP', 'P', 'P_{yearmon}.nc'.format(yearmon=yearmon)), 'P')

    def p_wetdays(self, *, yearmon, target=None, member=None):
        year = int(yearmon[:4])
        month = int(yearmon[4:])

        if year < 1979:
            return paths.Vardef(os.path.join(self.source,
                                             'NCEP',
                                             'wetdays_ltmean',
                                             'wetdays_ltmean_month_{month:02d}.nc'.format(month=month)),
                                'pWetDays')
        else:
            return paths.Vardef(os.path.join(self.source,
                                             'NCEP',
                                             'wetdays',
                                             'wetdays_{yearmon}.nc'.format(yearmon=yearmon)),
                                'pWetDays')


class CFSForecast(paths.ForecastForcing):

    def __init__(self, source, derived):
        self.source = source
        self.derived = derived

    def temp_monthly(self, *, yearmon, target, member):
        return paths.Vardef(self.forecast_corrected(target=target, member=member), 'T')

    def precip_monthly(self, *, yearmon, target, member):
        return paths.Vardef(self.forecast_corrected(target=target, member=member), 'Pr')

    def p_wetdays(self, *, yearmon=None, target, member=None):
        month = int(target[4:])

        return paths.Vardef(os.path.join(self.source,
                                         'NCEP',
                                         'wetdays_ltmean',
                                         'wetdays_ltmean_month_{month:02d}.nc'.format(month=month)),
                            'pWetDays')

    def fit_obs(self, *, var, month):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'hindcast_fits',
                            'obs_{var}_month_{month:02d}.nc'.format(var=var, month=month))

    def fit_retro(self, *, var, target_month, lead_months):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'hindcast_fits',
                            'retro_{var}_month_{target_month:02d}_lead_{lead_months:d}.nc'.format(var=var,
                                                                                                  target_month=target_month,  # noqa
                                                                                                  lead_months=lead_months))   # noqa

    def forecast_raw(self, *, target, member):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'raw_nc',
                            'cfs_trgt{target}_fcst{member}_raw.nc'.format(target=target, member=member))

    def forecast_corrected(self, *, target, member):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'corrected',
                            'cfs_trgt{target}_fcst{member}_corrected.nc'.format(target=target, member=member))

    def grib_dir(self, *, member):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'raw_grib',
                            'cfs.{}'.format(member[:-2]))

    def forecast_grib(self, *, member, target):
        return os.path.join(self.grib_dir(member=member),
                            'flxf.01.{member}.{target}.avrg.grib.grb2'.format(member=member, target=target))

    def global_prep_steps(self):
        tarfile_dir = os.path.join(self.source,
                                   'NCEP_CFSv2')
        tarfile = os.path.join(tarfile_dir, 'hindcast_fits.tar.gz')
        steps = []

        steps.append(
            Step(
                targets=tarfile,
                dependencies=[],
                commands=[
                    [
                        'wget',
                        '--continue',
                        '-P', tarfile_dir,
                        'https://s3.us-east-2.amazonaws.com/wsim-datasets/hindcast_fits.tar.gz'
                     ]
                ]
            )
        )

        for var in ('T', 'Pr'):
            for month in range(1, 13):
                fitfile = self.fit_obs(var=var, month=month)
                fitdir = os.path.dirname(fitfile)
                fitfile_arcname = re.sub('^.*(?=hindcast_fits)', '', fitfile)

                steps.append(
                    commands.extract_from_tar(tarfile, fitfile_arcname, fitdir)
                )

                for lead in range(1, 10):
                    fitfile = self.fit_retro(var=var, target_month=month, lead_months=lead)
                    fitdir = os.path.dirname(fitfile)
                    fitfile_arcname = re.sub('^.*(?=hindcast_fits)', '', fitfile)

                    steps.append(
                        commands.extract_from_tar(tarfile, fitfile_arcname, fitdir)
                    )

        return steps

    def prep_steps(self, *, yearmon=None, target, member):
        outfile = self.forecast_raw(member=member, target=target)
        infile = self.forecast_grib(member=member, target=target)

        return [
            # Download the GRIB, if needed
            Step(
                targets=self.forecast_grib(member=member, target=target),
                dependencies=[],
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'noaa_cfsv2_forecast', 'download_cfsv2_forecast.py'),
                        '--timestamp', member,
                        '--target', target,
                        '--output_dir', self.grib_dir(member=member)
                    ]
                ]

            ),
            # Convert the forecast data from GRIB to netCDF
            commands.forecast_convert(infile, outfile)
        ]


class CFSConfig(ConfigBase):

    def __init__(self, source, derived):
        self._observed = NCEP(source)
        self._forecast = CFSForecast(source, derived)
        self._static = CFSStatic(source)
        self._workspace = paths.DefaultWorkspace(derived)

    def global_prep(self):
        return \
            self._static.global_prep_steps() + \
            self._observed.global_prep_steps() + \
            self._forecast.global_prep_steps()

    def historical_years(self):
        return range(1948, 2018)  # 1948-2017

    def result_fit_years(self):
        return range(1950, 2010)  # 1950-2009

    def forecast_ensemble_members(self, yearmon):
        # Build an ensemble of 28 forecasts by taking the four
        # forecasts issued on each of the last 7 days of the month.
        last_day = dates.get_last_day_of_month(yearmon)

        return ['{}{:02d}{:02d}'.format(yearmon, day, hour)
                for day in range(last_day - 6, last_day + 1)
                for hour in (0, 6, 12, 18)]

    def forecast_targets(self, yearmon):
        return dates.get_next_yearmons(yearmon, 9)

    def forecast_data(self):
        return self._forecast

    def observed_data(self):
        return self._observed

    def static_data(self):
        return self._static

    def workspace(self):
        return self._workspace


config = CFSConfig
