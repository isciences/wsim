# Copyright (c) 2018-2019 ISciences, LLC.)
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

import datetime
import os
import re

from typing import List, Optional

from wsim_workflow import commands
from wsim_workflow import dates
from wsim_workflow import paths

from wsim_workflow.config_base import ConfigBase
from wsim_workflow.data_sources import aqueduct, grand, hydrobasins, isric, gadm, gmted, gppd, stn30, natural_earth, mirca2000, spam2010
from wsim_workflow.paths import Method
from wsim_workflow.step import Step

WSIM_FORCING_VARIABLES = ('T', 'Pr')
CFS_VARS = {'T': 'tmp2m', 'Pr': 'prate'}

HINDCAST_DATES_FOR_MONTH = [
    None,
    [1, 6, 11, 16, 26, 31],  # January
    [5, 10, 15, 20, 25],  # February
    [2, 7, 12, 17, 22, 27],  # March
    [1, 6, 11, 16, 26],  # April
    [1, 6, 11, 16, 26, 31],  # May
    [5, 10, 15, 20, 25, 30],  # June
    [5, 10, 15, 20, 25, 30],  # July
    [4, 9, 14, 19, 24, 29],  # August
    [3, 8, 13, 18, 23, 28],  # September
    [3, 8, 13, 18, 23, 28],  # October
    [2, 7, 12, 17, 22, 27],  # November
    [2, 7, 12, 17, 22, 27],  # December
]

MISSING_HINDCASTS = {
    '1985092306': {'198602'},
    '1986011618': {'198606'},
    '1986040612': {'198606', '198609'},
    '1986081400': {'198701'},
    '1987072000': {'198804'},
    '1987080906': {'198709'},
    '1987091306': {'198710', '198804'},
    '1987101312': {'198801'},
    '1988011612': {'198802'},
    '1988021000': {'198810'},
    '1988122212': {'198905'},
    '1989021500': {'198903', '198905', '198909'},
    '1989061000': {'198908'},
    '1989070500': {'198908'},
    '1989100818': {'199004'},
    '2004010118': {'200406'},
}

CORRUPT_HINDCASTS = {
    '1984092800': {'198504'}
}


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
            spam2010.allocate_spam_production(spam_zip = spam2010.spam_zip(self.source),
                                     method = Method.IRRIGATED,
                                     area_fractions = self.crop_calendar(method=Method.IRRIGATED),
                                     output = self.production(method=Method.IRRIGATED).file) + \
            spam2010.allocate_spam_production(spam_zip = spam2010.spam_zip(self.source),
                                              method = Method.RAINFED,
                                              area_fractions = self.crop_calendar(method=Method.RAINFED),
                                              output = self.production(method=Method.RAINFED).file)


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

    def crop_calendar(self, method: Method) -> str:
        return os.path.join(self.source, 'MIRCA2000', 'crop_calendar_{}.nc'.format(method.value))

    def production(self, method: Method) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, spam2010.SUBDIR, 'production_{}.nc'.format(method.value)),
                            'production')


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
            # FIXME call new code in data_sources and Delete compute_noaa_cpc_pwetdays.py

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

    def __init__(self, source: str, derived: str, observed: paths.ObservedForcing):
        self.source = source
        self.derived = derived,
        self.observed = observed
        self.min_fit_year = 1983 # although we have hindcasts generated in 1982, we don't have
                                 # all month/lead time combinations until 1983.
        self.max_fit_year = 2009

    def temp_monthly(self, *, yearmon, target, member):
        return paths.Vardef(self.forecast_corrected(yearmon=yearmon, target=target, member=member), 'T')

    def precip_monthly(self, *, yearmon, target, member):
        return paths.Vardef(self.forecast_corrected(yearmon=yearmon, target=target, member=member), 'Pr')

    def p_wetdays(self, *, yearmon=None, target, member=None):
        month = int(target[4:])

        # FIXME use global_prep steps to create wet day ltmeans here instead of assuming they're available
        # (when they're not part of the ObservedForcing interface)

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

    def forecast_raw(self, *, yearmon, target, member) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'raw_nc',
                            member[:6],
                            'cfs_trgt{target}_fcst{member}_raw.nc'.format(target=target, member=member))

    def hindcast_raw(self, *, timestamp: str, target: str) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'hindcast_nc',
                            timestamp[:6],
                            'cfs_trgt{target}_fcst{timestamp}_raw.nc').format(target=target, timestamp=timestamp)

    def forecast_corrected(self, *, yearmon, target, member):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'corrected',
                            'cfs_trgt{target}_fcst{member}_corrected.nc'.format(target=target, member=member))

    def grib_dir(self, *, timestamp: str) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'raw_grib',
                            'cfs.{}'.format(timestamp[:-2]))

    def hindcast_grib(self, *, timestamp: str, target: str) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'hindcast_grib',
                            'cfs.{}'.format(timestamp[:-2]),
                            'flxf{}.01.{}.avrg.grb2'.format(timestamp, target))

    def forecast_grib(self, *, timestamp, target) -> str:
        return os.path.join(self.grib_dir(timestamp=timestamp),
                            'flxf.01.{member}.{target}.avrg.grib.grb2'.format(member=timestamp, target=target))

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

        for month in dates.all_months:
            # Compute these using our local data
            for var in WSIM_FORCING_VARIABLES:
                steps += self.compute_fit_obs(var, month)

            for lead in range(1, 10):
                steps += self.download_hindcasts(month, lead)

                for var in WSIM_FORCING_VARIABLES:
                    steps += self.compute_fit_hindcast(var, month, lead)

        return steps

    def compute_fit_obs(self, varname: str, month: int) -> List[Step]:
        assert varname in {'T', 'Pr'}

        start = dates.format_yearmon(self.min_fit_year, month)
        stop = dates.format_yearmon(self.max_fit_year, month)

        rng = dates.format_range(start, stop, 12)

        if varname == 'Pr':
            inputs = self.observed.precip_monthly(yearmon=rng).read_as('Pr')
        if varname == 'T':
            inputs = self.observed.temp_monthly(yearmon=rng)

        return [
            commands.wsim_fit(distribution='gev',
                              inputs=[inputs],
                              output=self.fit_obs(var=varname, month=month),
                              window=1)
        ]

    def available_hindcasts(self, target_month: int, lead: int) -> List[str]:
        forecast_month = target_month - lead
        if forecast_month < 1:
            forecast_month += 12

        for forecast_year in range(self.min_fit_year - 1, self.max_fit_year + 1):
            target = dates.add_months(dates.format_yearmon(forecast_year, forecast_month), lead)
            target_year, _ = dates.parse_yearmon(target)

            if target_year > self.max_fit_year:
                continue

            assert dates.parse_yearmon(target)[1] == target_month

            for day in HINDCAST_DATES_FOR_MONTH[forecast_month]:
                for hour in (0, 6, 12, 18):
                    timestamp = '{:04d}{:02d}{:02d}{:02d}'.format(forecast_year, forecast_month, day, hour)

                    if timestamp in MISSING_HINDCASTS and target in MISSING_HINDCASTS[timestamp]:
                        continue

                    if timestamp in CORRUPT_HINDCASTS and target in CORRUPT_HINDCASTS[timestamp]:
                        continue

                    yield timestamp, target

    def download_hindcasts(self, target_month: int, lead: int) -> List[Step]:
        steps = []

        for timestamp, target in self.available_hindcasts(target_month, lead):
            grib_file = self.hindcast_grib(timestamp=timestamp, target=target)
            grib_dir = os.path.dirname(grib_file)

            netcdf_file = self.hindcast_raw(timestamp=timestamp, target=target)

            steps.append(Step(
                targets=grib_file,
                dependencies=[],
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'noaa_cfsv2_forecast', 'download_cfsv2_forecast.py'),
                        '--timestamp', timestamp,
                        '--target', target,
                        '--output_dir', grib_dir
                    ]
                ]
            ))

            steps.append(commands.forecast_convert(grib_file, netcdf_file))

        return steps

    def compute_fit_hindcast(self, varname: str, target_month: int, lead: int) -> List[Step]:
        assert varname in {'T', 'Pr'}

        inputs = [str(paths.Vardef(self.hindcast_raw(timestamp=timestamp, target=target), varname))
                  for timestamp, target in self.available_hindcasts(target_month, lead)]

        return [
            commands.wsim_fit(
                distribution='gev',
                inputs=inputs,
                output=self.fit_retro(var=varname, target_month=target_month, lead_months=lead),
                window=1
            )
        ]

    def prep_steps(self, *, yearmon: str, target: str, member: str) -> List[Step]:
        outfile = self.forecast_raw(yearmon=yearmon, member=member, target=target).split('::')[0]
        infile = self.forecast_grib(timestamp=member, target=target)

        return [
            # Download the GRIB, if needed
            Step(
                targets=self.forecast_grib(timestamp=member, target=target),
                dependencies=[],
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'noaa_cfsv2_forecast', 'download_cfsv2_forecast.py'),
                        '--timestamp', member,
                        '--target', target,
                        '--output_dir', self.grib_dir(timestamp=member)
                    ]
                ]

            ),
            # Convert the forecast data from GRIB to netCDF
            commands.forecast_convert(infile, outfile)
        ]


class CFSConfig(ConfigBase):

    def __init__(self, source, derived):
        self._observed = NCEP(source)
        self._forecast = {'CFSv2' : CFSForecast(source, derived, self._observed)}
        self._static = CFSStatic(source)
        self._workspace = paths.DefaultWorkspace(derived)

    def historical_years(self):
        return range(1948, 2018)  # 1948-2017

    def result_fit_years(self):
        return range(1950, 2010)  # 1950-2009

    def models(self):
        return ['CFSv2']

    def forecast_ensemble_members(self, model, yearmon, *, lag_hours: Optional[int] = None):
        assert model in self.models()

        # Build an ensemble of 28 forecasts by taking the four
        # forecasts issued on each of the last 7 days of the month.
        last_day = dates.get_last_day_of_month(yearmon)

        year, month = dates.parse_yearmon(yearmon)

        members = [datetime.datetime(year, month, day, hour)
                   for day in range(last_day - 6, last_day + 1)
                   for hour in (0, 6, 12, 18)]

        if lag_hours is not None:
            members = [m for m in members if datetime.datetime.utcnow() - m > datetime.timedelta(hours=lag_hours)]

        return [m.strftime('%Y%m%d%H') for m in members]

    def forecast_targets(self, yearmon):
        return dates.get_next_yearmons(yearmon, 9)

    def forecast_data(self, model: str):
        return self._forecast[model]

    def observed_data(self):
        return self._observed

    def static_data(self):
        return self._static

    def workspace(self) -> paths.DefaultWorkspace:
        return self._workspace


config = CFSConfig
