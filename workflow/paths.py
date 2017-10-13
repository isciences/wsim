def read_vars(*args):
    file = args[0]
    vars = args[1:]

    return file + '::' + ','.join(vars)

def wc():
    return '{INPUTS}/HWSD/hwsd_tawc_05deg_noZeroNoVoids.img'

def flowdir():
    return '{INPUTS}/UNH_Data/g_network.asc'

def elevation():
    return '{INPUTS}/SRTM30/elevation_half_degree.img'

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

def spinup_state_pattern():
    return spinup_state(target='%T')

def wetday_norms(**kwargs):
    return '{{INPUTS}}/WetDay_CRU/cru_pWD_LTMEAN_{month:02d}.img'.format_map(kwargs)

def wetdays(**kwargs):
    return '{{OUTPUTS}}/prepared_inputs/wetdays_{target}.nc'.format_map(kwargs)

def state(**kwargs):
    txt = '{{OUTPUTS}}/state/state_'

    if 'icm' in kwargs and kwargs['icm'] is not None:
        txt += 'fcst{icm}_'

    txt += '{target}.nc'
    return txt.format_map(kwargs)

def forcing(**kwargs):
    txt = '{{OUTPUTS}}/forcing/forcing_'

    if 'icm' in kwargs and kwargs['icm'] is not None:
        txt += 'fcst{icm}_'

    txt += '{target}.nc'
    return txt.format_map(kwargs)

def results(**kwargs):
    txt = "{{OUTPUTS}}/results/results"
    if 'icm' in kwargs:
        txt += '_fcst{icm}'
    if 'window' in kwargs and kwargs['window'] is not None:
        txt += '_{window}mo'
    txt += '_{target}.nc'

    if 'var' in kwargs:
        txt += '::' + kwargs['var']

    return txt.format_map(kwargs)

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

def fit_obs(**kwargs):
    if 'target_month' in kwargs:
        return '{{OUTPUTS}}/fits/obs_{var}_month{target_month}.nc'.format_map(kwargs)
    else:
        base = '{{OUTPUTS}}/fits/{var}'

        if 'window' in kwargs and kwargs['window'] is not None:
            base += '_{window}mo'

        base += '_month_{month:02d}.nc'

        return base.format_map(kwargs)
