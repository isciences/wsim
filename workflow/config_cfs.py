import paths
import dates
import os
from config_base import ConfigBase
from step import Step
import commands

class Static:
    def __init__(self, source):
        self.source = source

    # Static inputs
    def wc(self):
        return paths.Vardef(os.path.join(self.source, 'HWSD', 'hwsd_tawc_05deg_noZeroNoVoids.img'), '1')

    def flowdir(self):
        return paths.Vardef(os.path.join(self.source, 'UNH_Data', 'g_network.asc'), '1')

    def elevation(self):
        return paths.Vardef(os.path.join(self.source, 'SRTM30', 'elevation_half_degree.img'), '1')

class NCEP(paths.Forcing):

    # TODO remove dependency on "Derived" ?
    def __init__(self, source, derived):
        self.source = source
        self.derived = derived

    def prep_steps(self, yearmon):
        steps = []

        year, month = dates.parse_yearmon(yearmon)

        if year >= 1979:
            daily_precip_files = [self.precip_daily(date).file for date in dates.days_in_month(yearmon)]

            steps.append(
                Step(
                    targets=self.p_wetdays(yearmon=yearmon).file,
                    dependencies=daily_precip_files,
                    commands=[
                        commands.wsim_integrate(
                            inputs=[file + '::1@[x-1]->Pr' for file in daily_precip_files],
                            stats=['fraction_defined_above_zero'],
                            output='$@'
                        ),
                        ['ncrename', '-O', '-vPr_fraction_defined_above_zero,pWetDays', '$@']
                    ]
                )
            )

        return steps

    def precip_daily(self, yyyymmdd):
        # There is some inconsistency in how daily precipitation files are named
        # from year to year. Because we want to be able to mirror this data source
        # using wget, we don't correct the inconsistencies in our local copy.
        year = int(yyyymmdd[:4])

        filename = 'PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.{DATE}'.format(DATE=yyyymmdd)
        if year < 1979:
            raise Exception('Daily precipitation not available before 1979')
        if year < 2006:
            filename += '.gz'
        elif year == 2006:
            filename += 'RT.gz'
        elif year in (2007, 2008):
            filename += '.RT.gz'
        else:
            filename += '.RT'

        return paths.Vardef(os.path.join(self.source, 'NCEP', 'Daily_precip', str(year), filename), '1')

    def precip_monthly(self, **kwargs):
        return paths.Vardef(os.path.join(self.source, 'NCEP', 'P', 'P_{yearmon}.nc'.format_map(kwargs)), 'P')

    def temp_monthly(self, **kwargs):
        return paths.Vardef(os.path.join(self.source, 'NCEP', 'T', 'T_{yearmon}.nc'.format_map(kwargs)), 'T')

    def p_wetdays(self, **kwargs):
        year = int(kwargs['yearmon'][:4])
        month = int(kwargs['yearmon'][4:])

        if year < 1979:
            return paths.Vardef(os.path.join(self.source, 'WetDay_CRU', 'cru_pWD_LTMEAN_{month:02d}.img'.format(month=month)), '1')
        else:
            return paths.Vardef(os.path.join(self.derived, 'prepared_inputs', 'wetdays_{yearmon}.nc'.format_map(kwargs)), 'pWetDays')

class CFSForecast(paths.Forcing):

    def __init__(self, source, derived):
        self.source = source
        self.derived = derived

    def temp_monthly(self, **kwargs):
        return paths.Vardef(self.forecast_corrected(**kwargs), 'T')

    def precip_monthly(self, **kwargs):
        return paths.Vardef(self.forecast_corrected(**kwargs), 'Pr')

    def p_wetdays(self, **kwargs):
        month = int(kwargs['target'][-2:])

        return paths.Vardef(os.path.join(self.source, 'WetDay_CRU', 'cru_pWD_LTMEAN_{month:02d}.img'.format(month=month)), '1')

    def fit_obs(self, **kwargs):
        return os.path.join(self.derived,
                            'cfs',
                            'fits',
                            'obs_{var}_month_{month:02d}.nc'.format_map(kwargs))

    def fit_retro(self, **kwargs):
        return os.path.join(self.derived,
                            'cfs',
                            'fits',
                            'retro_{var}_month_{target_month:02d}_lead_{lead_months:02d}.nc'.format_map(kwargs))

    def forecast_raw(self, **kwargs):
        return os.path.join(self.derived,
                            'cfs',
                            'raw',
                            'cfs_trgt{target}_fcst{member}_raw.nc'.format_map(kwargs))

    def forecast_corrected(self, **kwargs):
        return os.path.join(self.derived,
                            'cfs',
                            'corrected',
                            'cfs_trgt{target}_fcst{member}_corrected.nc'.format_map(kwargs))

    def forecast_grib(self, **kwargs):
        return os.path.join(self.source,
                            'NCEP.CFSv2',
                            'raw_forecast',
                            'cfs.{}'.format(kwargs['member'][:-2]),
                            'flxf.01.{member}.{target}.avrg.grib.grb2'.format_map(kwargs))

    def prep_steps(data, **kwargs):
        target = kwargs['target']
        member = kwargs['member']

        return [
            # Convert the forecast data from GRIB to netCDF
            Step(
                targets=data.forecast_raw(member=member, target=target),
                dependencies=[data.forecast_grib(member=member, target=target)],
                commands=[
                    commands.forecast_convert('$<', '$@')
                ]
            )
        ]

class CFSConfig(ConfigBase):

    def __init__(self, source, derived):
        self._observed = NCEP(source, derived)
        self._forecast = CFSForecast(source, derived)
        self._static = Static(source)
        self._workspace = paths.DefaultWorkspace(derived)

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
