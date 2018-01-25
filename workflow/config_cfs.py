# This configuration file is provided as an example of an automated operational WSIM workflow.

import paths
import dates
import os
from config_base import ConfigBase
from step import Step
import commands

class Static:
    def __init__(self, source):
        self.source = source

    def prep_flowdir(self):
        dir = os.path.join(self.source, 'STN_30')
        url = 'global_30_minute_potential_network_v601_asc.zip'
        zip_path = os.path.join(dir, url.split('/')[-1])

        return [
            # Download flow grid
            Step(
                targets=zip_path,
                dependencies=[],
                commands=[
                    [ 'wget', '--directory-prefix', dir, url ]
                ]
            ),

            # Unzip flow grid
            Step(
                targets=self.flowdir().file,
                dependencies=zip_path,
                commands=[
                    [ 'unzip', '-j', zip_path, 'global_potential_network_v601_asc/g_network.asc', '-d', dir ],
                    [ 'touch', self.flowdir().file ]
                ]
            )
        ]

    def prep_elevation(self):
        dir = os.path.join(self.source, 'GMTED2010')
        url = 'http://edcintl.cr.usgs.gov/downloads/sciweb1/shared/topo/downloads/GMTED/Grid_ZipFiles/mn30_grd.zip'
        zip_path = os.path.join(dir, url.split('/')[-1])
        raw_file = os.path.join(dir, 'mn30_grd')

        return [
            # Download elevation data
            Step(
                targets=zip_path,
                dependencies=[],
                commands=[
                    [ 'wget', '--directory-prefix', dir, url ]
                ]
            ),

            # Unzip elevation data
            Step(
                targets=raw_file,
                dependencies=zip_path,
                commands=[
                    [ 'unzip', '-d', dir, zip_path ],
                    [ 'touch', raw_file ]
                ]
            ),

            # Aggregate elevation data
            Step(
                targets=self.elevation().file,
                dependencies=raw_file,
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'isric_30sec_soils', 'aggregate_tawc.R'),
                        '--res', '0.5',
                        '--input', raw_file,
                        '--output', self.elevation().file
                    ]
                ]
            )
        ]

    def prep_wc(self):
        dir = os.path.join(self.source, 'ISRIC')
        url = 'ftp://ftp.isric.org/wise/wise_30sec_v1.zip'
        zip_path = os.path.join(dir, url.split('/')[-1])
        raw_file = os.path.join(dir, 'HW30s_FULL.txt') # there are others, but might as well avoid a multi-target rule
        full_res_file = os.path.join(dir, 'wise_30sec_v1_tawc.tif')

        return [
            # Download ISRIC data
            Step(
                targets=zip_path,
                dependencies=[],
                commands=[
                    [
                        'wget',
                        '--directory-prefix', dir,
                        '--user', 'public',
                        '--password', 'public',
                        url
                    ]
                ]
            ),

            # Unzip ISRIC data
            Step(
                targets=raw_file,
                dependencies=zip_path,
                commands=[
                    [
                        'unzip', '-j', zip_path, '-d', dir,
                        'wise_30sec_v1/Interchangeable_format/HW30s_FULL.txt',
                        'wise_30sec_v1/Interchangeable_format/wise_30sec_v1.tif',
                        'wise_30sec_v1/Interchangeable_format/wise_30sec_v1.tsv'
                    ],
                    [ 'touch', raw_file ]
                ]
            ),

            # Create TAWC TIFF
            Step(
                targets=full_res_file,
                dependencies=raw_file,
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'isric_30sec_soils', 'extract_isric_tawc.R'),
                        '--data',      os.path.join(dir, 'HW30s_FULL.txt'),
                        '--missing',   os.path.join('{BINDIR}', 'utils', 'isric_30sec_soils', 'example_tawc_defaults.csv'),
                        '--codes',     os.path.join(dir, 'wise_30sec_v1.tsv'),
                        '--raster',    os.path.join(dir, 'wise_30sec_v1.tif'),
                        '--max_depth', '1'
                    ]
                ]
            ),

            # Aggregate TAWC data
            Step(
                targets=self.wc().file,
                dependencies=full_res_file,
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'isric_30sec_soils', 'aggregate_tawc.R'),
                        '--res', '0.5',
                        '--input', full_res_file,
                        '--output', self.wc().file
                    ]
                ]
            )
        ]

    def global_prep_steps(self):
        return \
            self.prep_elevation() + \
            self.prep_flowdir() + \
            self.prep_wc()

    # Static inputs
    def wc(self):
        return paths.Vardef(os.path.join(self.source, 'ISRIC', 'wise_05deg_v1_tawc.tif'), '1')

    def flowdir(self):
        return paths.Vardef(os.path.join(self.source, 'STN_30', 'g_network.asc'), '1')

    def elevation(self):
        return paths.Vardef(os.path.join(self.source, 'GMTED2010', 'gmted2010_05deg.tif'), '1')

class NCEP(paths.Forcing):

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

    def compute_wetday_ltmeans(self, start_year, stop_year):
        """
        Steps to compute long-term means in wetdays that can be used
        for months where daily precipitation data is not available
        """
        steps = []

        wetday_ltmean_years = range(start_year, stop_year + 1)
        for month in range(1, 13):
            input_vardefs=[self.p_wetdays(yearmon=dates.format_yearmon(year, month)) for year in wetday_ltmean_years]
            ltmean_file=self.p_wetdays(yearmon=dates.format_yearmon(start_year - 1, month)).file,

            steps.append(
                Step(
                    targets=ltmean_file,
                    dependencies=[vardef.file for vardef in input_vardefs],
                    commands=[
                        commands.wsim_integrate(
                            stats=['ave'],
                            inputs=input_vardefs,
                            output=ltmean_file,
                            keepvarnames=True
                        )
                    ]
                ),
            )

        return steps

    def prep_steps(self, yearmon):
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

    def temp_monthly(self, **kwargs):
        return paths.Vardef(os.path.join(self.source, 'NCEP', 'T', 'T_{yearmon}.nc'.format_map(kwargs)), 'T')

    def precip_monthly(self, **kwargs):
        return paths.Vardef(os.path.join(self.source, 'NCEP', 'P', 'P_{yearmon}.nc'.format_map(kwargs)), 'P')

    def p_wetdays(self, **kwargs):
        year = int(kwargs['yearmon'][:4])
        month = int(kwargs['yearmon'][4:])

        if year < 1979:
            return paths.Vardef(os.path.join(self.source, 'NCEP', 'wetdays_ltmean', 'wetdays_ltmean_month_{month:02d}.nc'.format(month=month)), 'pWetDays')
        else:
            return paths.Vardef(os.path.join(self.source, 'NCEP', 'wetdays', 'wetdays_{yearmon}.nc'.format_map(kwargs)), 'pWetDays')

class CFSForecast(paths.Forcing):

    def __init__(self, source, derived):
        self.source = source
        self.derived = derived

    def temp_monthly(self, **kwargs):
        return paths.Vardef(self.forecast_corrected(**kwargs), 'T')

    def precip_monthly(self, **kwargs):
        return paths.Vardef(self.forecast_corrected(**kwargs), 'Pr')

    def p_wetdays(self, **kwargs):
        return paths.Vardef(os.path.join(self.source,
                                         'NCEP',
                                         'wetdays',
                                         'wetdays_{yearmon}.nc'.format_map(kwargs)), 'pWetDays')

    def fit_obs(self, **kwargs):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'hindcast_fits',
                            'obs_{var}_month_{month:02d}.nc'.format_map(kwargs))

    def fit_retro(self, **kwargs):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'hindcast_fits',
                            'retro_{var}_month_{target_month:02d}_lead_{lead_months:d}.nc'.format_map(kwargs))

    def forecast_raw(self, **kwargs):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'raw_nc',
                            'cfs_trgt{target}_fcst{member}_raw.nc'.format_map(kwargs))

    def forecast_corrected(self, **kwargs):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'corrected',
                            'cfs_trgt{target}_fcst{member}_corrected.nc'.format_map(kwargs))

    def grib_dir(self, *, member):
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'raw_grib',
                            'cfs.{}'.format(member[:-2]))

    def forecast_grib(self, *, member, target):
        return os.path.join(self.grib_dir(member=member),
                            'flxf.01.{member}.{target}.avrg.grib.grb2'.format(member=member, target=target))

    def prep_steps(self, **kwargs):
        target = kwargs['target']
        member = kwargs['member']

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
            Step(
                targets=self.forecast_raw(member=member, target=target),
                dependencies=[self.forecast_grib(member=member, target=target)],
                commands=[
                    commands.forecast_convert('$<', '$@')
                ]
            )
        ]

class CFSConfig(ConfigBase):

    def __init__(self, source, derived):
        self._observed = NCEP(source)
        self._forecast = CFSForecast(source, derived)
        self._static = Static(source)
        self._workspace = paths.DefaultWorkspace(derived)

    def global_prep(self):
        return \
            self._static.global_prep_steps() + \
            self._observed.global_prep_steps() + \
            self._forecast.global_prep_steps()

    def historical_years(self):
        return range(1948, 2017)

    def result_fit_years(self):
        return range(1950, 2010) #1950-2009

    def forecast_ensemble_members(self, yearmon):
        last_day = dates.get_last_day_of_month(yearmon)

        return [yearmon + '{:02d}{:02d}'.format(day, hour)
                for day in range(last_day - 6, last_day + 1)
                for hour in (0, 6, 12, 18)]

    def forecast_targets(self, yearmon):
        targets = [dates.get_next_yearmon(yearmon)]

        for _ in range(8):
            targets.append(dates.get_next_yearmon(targets[-1]))

        return targets

    def forecast_data(self):
        return self._forecast

    def observed_data(self):
        return self._observed

    def static_data(self):
        return self._static

    def workspace(self):
        return self._workspace

config = CFSConfig
