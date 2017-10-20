import os
import sys

import paths
import monthly
import spinup
import dates

from prepare import cfs_prepare

if sys.version_info.major < 3:
    print("Must use Python 3")
    sys.exit(1)

def get_icms(yearmon):
    last_day = dates.get_last_day_of_month(yearmon)

    return [yearmon + '{:02d}{:02d}'.format(day, hour)
            for day in range(last_day - 6, last_day + 1)
            for hour in (0, 6, 12, 18)]

def get_forecast_targets(yearmon):
    targets = [dates.get_next_yearmon(yearmon)]

    for _ in range(8):
        targets.append(dates.get_next_yearmon(targets[-1]))

    return targets

lsm_vars = [
    'Bt_RO',
    'Bt_Runoff',
    'EmPET',
    'PETmE',
    'PET',
    'P_net',
    #    'Pr',
    'RO_m3',
    'RO_mm',
    'Runoff_mm',
    'Runoff_m3',
    'Sa',
    'Sm',
    #    'Snowpack',
    #    'T',
    'Ws'
]

integrated_vars = {
    'Bt_RO'     : [ 'min', 'max', 'sum' ],
    'Bt_Runoff' : [ 'sum' ],
    'EmPET'     : [ 'sum' ],
    'E'         : [ 'sum' ],
    'PETmE'     : [ 'sum' ],
    'P_net'     : [ 'sum' ],
    #'Pr'        : [ 'sum' ]n
    'RO_mm'     : [ 'sum' ],
    'Runoff_mm' : [ 'sum' ],
    #'Snowpack'  : [ 'sum' ],
    #'T'         : [ 'ave' ],
    'Ws'        : [ 'ave' ]
}

bindir = '/wsim'

data = 'ncep'
use_forecast = True

steps = []

if data == 'ncep':
    integration_windows = [ 3, 6, 12, 24, 36, 60 ]
    historical_years = range(1948, 2017) # the complete historical record
    result_fit_years = range(1950, 2010) # the lsm results we want to use for GEV fits

    workspace = paths.Workspace('/mnt/fig_rw/WSIM_DEV/wsim2')
    static = paths.Static('/mnt/fig/WSIM/WSIM_source_V1.2')
    inputs = paths.NCEP('/mnt/fig/WSIM/WSIM_source_V1.2', '/mnt/fig_rw/WSIM_DEV/wsim2')
    makefile = '/mnt/fig_rw/WSIM_DEV/wsim2'

    forecast_inputs = paths.CFSForecast('/mnt/fig/WSIM/WSIM_source_V1.2',
                                        '/mnt/fig_rw/WSIM_DEV/wsim2')


elif data == 'nldas':
    integration_windows = [ 3, 6, 12, 24, 36, 60 ]
    historical_years = range(1989, 2012) # the complete historical record
    result_fit_years = range(1990, 2010) # the lsm results we want to use for GEV fits

    workspace = paths.Workspace('/mnt/fig_rw/WSIM_DEV/wsim2/nldas')
    static = paths.StaticNLDAS('/mnt/fig_rw/WSIM_DEV/wsim2/nldas/static_nldas_grid.nc')
    inputs = paths.NLDAS('/mnt/fig/Data_Global/NLDAS')
    makefile = workspace.outputs

steps += spinup.spinup(workspace,
                      static,
                      inputs,
                      historical_years,
                      result_fit_years,
                      integration_windows,
                      integrated_vars,
                      lsm_vars)

#for month in dates.all_months:
if True:
    month = 1
    yearmon = dates.format_yearmon(2017, month)

    steps += monthly.monthly_observed(workspace,
                                      static,
                                      inputs,
                                      integration_windows,
                                      integrated_vars,
                                      lsm_vars,
                                      yearmon)

    if data == 'ncep':
        if use_forecast:
            icms = get_icms(yearmon)
            targets = get_forecast_targets(yearmon)

            steps += cfs_prepare(forecast_inputs, targets, icms)

            steps += monthly.monthly_forecast(workspace,
                                              static,
                                              forecast_inputs,
                                              integration_windows,
                                              integrated_vars,
                                              lsm_vars,
                                              yearmon,
                                              targets,
                                              icms)

import socket
if socket.gethostname() == 'flaxvm':
    print("Checking steps only")
    targets = set()
    for step in steps:
        for target in step.target:
            if target in targets:
                print("Duplicate target", step.target)
            targets.add(target)
        step.get_text({'BINDIR' : bindir})
else:
    with open(os.path.join(makefile, 'Makefile'), 'w') as outfile:
        outfile.write('.DELETE_ON_ERROR:\n')
        outfile.write('.SECONDARY:\n')

        outfile.write('\n')

        for step in reversed(steps):
            outfile.write(step.get_text({'BINDIR' : bindir}))

        print("Done")
