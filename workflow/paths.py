import os

def read_vars(*args):
    file = args[0]
    vars = args[1:]

    return file + '::' + ','.join(vars)

class Vardef:

    def __init__(self, file, var):
        self.file = file
        self.var = var

    def read_as(self, new_name):
        return self.file + '::' + self.var + '->' + new_name

    def __str__(self):
        return self.file + '::' + self.var

class Static:
    def __init__(self, source):
        self.source = source

    # Static inputs
    def wc(self):
        return Vardef(os.path.join(self.source, 'HWSD', 'hwsd_tawc_05deg_noZeroNoVoids.img'), '1')

    def flowdir(self):
        return Vardef(os.path.join(self.source, 'UNH_Data', 'g_network.asc'), '1')

    def elevation(self):
        return Vardef(os.path.join(self.source, 'SRTM30', 'elevation_half_degree.img'), '1')

class StaticNLDAS:

    def __init__(self, file):
        self.file = file

    def wc(self):
        return Vardef(self.file, 'Wc')

    def flowdir(self):
        return Vardef(self.file, 'flowdir')

    def elevation(self):
        return Vardef(self.file, 'elevation')

class NCEP:

    # TODO remove dependency on "Derived"
    def __init__(self, source, derived):
        self.source = source
        self.derived = derived

    def precip_daily(self, yyyymmdd):
        year = int(yyyymmdd[:4])

        # TODO figure out actual cutoff year
        if year > 2016:
            return Vardef(os.path.join(self.source, 'NCEP', 'Daily_precip', 'Originals', str(year), 'PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.{DATE}.RT'.format(DATE=yyyymmdd)), '1')
        else:
            raise FileNotFoundError

    def precip_monthly(self, **kwargs):
        year = int(kwargs['yearmon'][:4])

        # TODO figure out actual cutoff year
        if year > 2016:
            return Vardef(os.path.join(self.source, 'NCEP', 'originals', 'p.{yearmon}.mon'.format_map(kwargs)), '1')
        else:
            return Vardef(os.path.join(self.source, 'NCEP', 'P', 'CPC_Leaky_P_{yearmon}.FLT'.format_map(kwargs)), '1')

    def temp_monthly(self, **kwargs):
        year = int(kwargs['yearmon'][:4])

        # TODO figure out actual cutoff year
        if year > 2016:
            return Vardef(os.path.join(self.source, 'NCEP', 'originals', 't.{yearmon}.mon'.format_map(kwargs)), '1')
        else:
            return Vardef(os.path.join(self.source, 'NCEP', 'T', 'CPC_Leaky_T_{yearmon}'.format_map(kwargs)), '1')

    def p_wetdays(self, **kwargs):
        year = int(kwargs['yearmon'][:4])
        month = int(kwargs['yearmon'][4:])

        if year < 1979:
            return Vardef(os.path.join(self.source, 'WetDay_CRU', 'cru_pWD_LTMEAN_{month:02d}.img'.format(month=month)), '1')
        else:
            return Vardef(os.path.join(self.derived, 'prepared_inputs', 'wetdays_{yearmon}.nc'.format_map(kwargs)), 'pWetDays')

class CFSForecast:

    def __init__(self, source):
        self.source = source

    def temp_monthly(self, **kwargs):
        return Vardef(os.path.join(self.source, 'prepared_inputs', 'cfs_fcst{icm}_{target}_corrected.nc'.format_map(kwargs)), 'T')

    def precip_monthly(self, **kwargs):
        return Vardef(os.path.join(self.source, 'prepared_inputs', 'cfs_fcst{icm}_{target}_corrected.nc'.format_map(kwargs)), 'Pr')

    def p_wetdays(self, **kwargs):
        month = int(kwargs['target'][-2:])

        return Vardef(os.path.join(self.source, 'WetDay_CRU', 'cru_pWD_LTMEAN_{month:02d}.img'.format(month=month)), '1')




class NLDAS:

    def __init__(self, source):
        self.source = source

    def precip_monthly(self, **kwargs):
        return Vardef(os.path.join(self.source, 'NLDAS_FORA125_M.002', 'Pr', 'Pr_{yearmon}.img'.format_map(kwargs)), '1')

    def temp_monthly(self, **kwargs):
        return Vardef(os.path.join(self.source, 'NLDAS_FORA125_M.002', 'T', 'T_{yearmon}.img'.format_map(kwargs)), '1')

    def p_wetdays(self, **kwargs):
        return Vardef(os.path.join(self.source, 'NLDAS_FORA125_H.002/WetDay/pWetDay_{yearmon}.img'.format_map(kwargs)), '1')

class Workspace:

    def __init__(self, outputs):
        self.outputs = outputs

    def climate_norms(self, **kwargs):
        return os.path.join(self.outputs, 'spinup', 'climate_norms_{month:02d}.nc'.format_map(kwargs))

    def climate_norm_forcing(self, **kwargs):
        return os.path.join(self.outputs, 'spinup', 'climate_norm_forcing_{month:02d}.nc'.format_map(kwargs))

    def composite_summary(self, **kwargs):
        filename = "composite_summary"

        if 'window' in kwargs and kwargs['window'] is not None:
            filename += '_{window}mo'

        filename += '_{yearmon}'

        if 'target' in kwargs and kwargs['target'] is not None:
            filename += '_trgt{target}'

        filename += '.nc'

        return os.path.join(self.outputs, 'composite', filename.format_map(kwargs))

    def initial_state(self):
        return os.path.join(self.outputs, 'spinup', 'initial_state.nc')

    def final_state_norms(self):
        return os.path.join(self.outputs, 'spinup', 'final_state_norms.nc')

    def return_period(self, **kwargs):
        filename = "rp_"

        if "icm" in kwargs and kwargs['icm']:
            filename += "{icm}_"

        if "window" in kwargs and kwargs['window']:
            filename += "{window}mo_"

        filename += "{target}.nc"

        return os.path.join(self.outputs, 'rp', filename.format_map(kwargs))

    def spinup_state(self, **kwargs):
        return os.path.join(self.outputs, 'spinup', 'spinup_state_{target}.nc'.format_map(kwargs))

    def spinup_state_pattern(self):
        return self.spinup_state(target='%T')

    def spinup_mean_state(self, **kwargs):
        return os.path.join(self.outputs, 'spinup', 'spinup_mean_state_month_{month:02d}.nc'.format_map(kwargs))

    def state(self, **kwargs):
        filename = 'state_'

        if 'icm' in kwargs and kwargs['icm'] is not None:
            filename += 'fcst{icm}_'

        filename += '{target}.nc'

        return os.path.join(self.outputs, 'state', filename.format_map(kwargs))

    def forcing(self, **kwargs):
        filename = 'forcing_'

        if 'icm' in kwargs and kwargs['icm'] is not None:
            filename += 'fcst{icm}_'

        filename += '{target}.nc'

        return os.path.join(self.outputs, 'forcing', filename.format_map(kwargs))

    def results(self, **kwargs):
        filename = 'results'

        if 'icm' in kwargs and kwargs['icm'] is not None:
            filename += '_fcst{icm}'

        if 'window' in kwargs and kwargs['window'] is not None:
            filename += '_{window}mo'

        filename += '_{target}.nc'

        if 'var' in kwargs:
            filename += '::' + kwargs['var']

        return os.path.join(self.outputs, 'results', filename.format_map(kwargs))

    def fit_obs(self, **kwargs):
        if 'target_month' in kwargs:
            return os.path.join(self.outputs, 'fits', 'obs_{var}_month{target_month}.nc'.format_map(kwargs))

        filename = '{var}'

        if 'stat' in kwargs and kwargs['stat'] is not None:
            filename += '_{stat}'

        if 'window' in kwargs and kwargs['window'] is not None:
            filename += '_{window}mo'

        filename += '_month_{month:02d}.nc'

        return os.path.join(self.outputs, 'fits', filename.format_map(kwargs))

def initial_state():
    return '{OUTPUTS}/spinup/initial_state.nc'

def climate_norms(**kwargs):
    return '{{OUTPUTS}}/spinup/climate_norms_{month:02d}.nc'.format_map(kwargs)

def climate_norm_forcing(**kwargs):
    return '{{OUTPUTS}}/spinup/climate_norm_forcing_{month:02d}.nc'.format_map(kwargs)

def final_state_norms():
    return '{OUTPUTS}/spinup/final_state_norms.nc'

def spinup_state(**kwargs):
    return '{{OUTPUTS}}/spinup/spinup_state_{target}.nc'.format_map(kwargs)

def spinup_mean_state(**kwargs):
    return '{{OUTPUTS}}/spinup/spinup_mean_state_month_{month:02d}.nc'.format_map(kwargs)

def historical_precip(**kwargs):
    return '{{INPUTS}}/NCEP/P/CPC_Leaky_P_{target}.FLT'.format_map(kwargs)

def historical_temp(**kwargs):
    return '{{INPUTS}}/NCEP/T/CPC_Leaky_T_{target}.FLT'.format_map(kwargs)

def historical_wetdays(**kwargs):
    year = kwargs['target'][:4]

    return '{{INPUTS}}/NCEP/Daily_precip/Adjusted/{year}/pWetDays_{target}.img'.format(year=year, target=kwargs['target'])

def wetday_norms(**kwargs):
    return '{{INPUTS}}/WetDay_CRU/cru_pWD_LTMEAN_{month:02d}.img'.format_map(kwargs)

def wetdays(**kwargs):
    return '{{OUTPUTS}}/prepared_inputs/wetdays_{target}.nc'.format_map(kwargs)

def daily_precip(yyyymmdd):
    year = yyyymmdd[:4]

    return "{{INPUTS}}/NCEP/Daily_precip/Originals/{YEAR}/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.{DATE}.RT".format(DATE=yyyymmdd, YEAR=year)

def cfs_forecast_grib(**kwargs):
    params = {
        'forecast_date' : kwargs['icm'][:-2]
    }
    params.update(kwargs)

    return "{{INPUTS}}/NCEP.CFSv2/raw_forecast/cfs.{forecast_date}/flxf.01.{icm}.{target}.avrg.grib.grb2".format_map(params)

def cfs_forecast_raw(**kwargs):
    return '{{OUTPUTS}}/prepared_inputs/cfs_fcst{icm}_{target}_raw.nc'.format_map(kwargs)

def cfs_forecast_corrected(**kwargs):
    return '{{OUTPUTS}}/prepared_inputs/cfs_fcst{icm}_{target}_corrected.nc'.format_map(kwargs)

def average_wetdays(**kwargs):
    return '{{INPUTS}}/WetDay_CRU/cru_pWD_LTMEAN_{month}.img'.format_map(kwargs)

def return_period(**kwargs):
    txt = "{{OUTPUTS}}/rp/rp_"
    if "icm" in kwargs:
        txt += "{icm}_"
    if "window" in kwargs and kwargs['window']:
        txt += "{window}mo_"
    txt += "{target}.nc"

    return txt.format_map(kwargs)

def return_period_summary(**kwargs):
    return '{{OUTPUTS}}/rp/rp_summary_{yearmon}_trgt{target}.nc'.format_map(kwargs)

def composite_summary(**kwargs):
    txt = '{{OUTPUTS}}/composite/composite_summary'

    if 'window' in kwargs and kwargs['window'] is not None:
        txt += '_{window}mo'

    txt += '_{yearmon}'

    if 'target' in kwargs and kwargs['target'] is not None:
        txt += '_trgt{target}'

    txt += '.nc'
    return txt.format_map(kwargs)

def fit_retro(**kwargs):
    params = {
        'lead' : '{:01d}'.format(kwargs['lead_months'])
    }
    params.update(kwargs)

    return '{{OUTPUTS}}/fits/retro_{var}_month{target_month}_lead_{lead}.nc'.format_map(params)

