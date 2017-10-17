from step import Step
from spinup import spinup
import paths
from paths import *
from commands import *
from dates import *

import monthly

#steps = []


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



#vars = {
#    'BINDIR'  : '/home/dbaston/dev/wsim2',
#    'YEARMON' : '201709',
#    'INPUTS'  : '/mnt/fig/WSIM/WSIM_source_V1.2',
#    'OUTPUTS' : '/mnt/fig_rw/WSIM_DEV/wsim2'
#}

# Spinup

vars = {
    #'BINDIR'  : '/home/dbaston/dev/wsim2',
    'BINDIR'  : '/wsim',
    'YEARMON' : '201709',
    'INPUTS'  : '/mnt/fig/WSIM/WSIM_source_V1.2',
    'OUTPUTS' : '.'
}

# TODO eliminate these
vars['YEARMON_PREV'] = get_previous_yearmon(vars['YEARMON'])
vars['YEARMON_NEXT'] = get_next_yearmon(vars['YEARMON'])
vars['YEAR'] = vars['YEARMON'][:4]
vars['MONTH'] = vars['YEARMON'][4:]

data = 'nldas'

if data == 'ncep':
    integration_windows = [ 3, 6, 12, 24, 36, 60 ]
    historical_years = range(1948, 2017) # the complete historical record
    result_fit_years = range(1950, 2010) # the lsm results we want to use for GEV fits

    workspace = paths.Workspace('.')
    static = paths.Static(vars['INPUTS'])
    inputs = paths.NCEP(vars['INPUTS'],
                      '.')
    makefile = '/mnt/fig_rw/WSIM_DEV/wsim2'

elif data == 'nldas':
    integration_windows = [ 3, 6, 12, 24, 36, 60 ]
    historical_years = range(1989, 2012) # the complete historical record
    result_fit_years = range(1990, 2010) # the lsm results we want to use for GEV fits

    workspace = paths.Workspace('/mnt/fig_rw/WSIM_DEV/wsim2/nldas')
    static = paths.StaticNLDAS('/mnt/fig_rw/WSIM_DEV/wsim2/nldas/static_nldas_grid.nc')
    inputs = paths.NLDAS('/mnt/fig/Data_Global/NLDAS')
    makefile = workspace.outputs

steps = spinup(workspace,
               static,
               inputs,
               historical_years,
               result_fit_years,
               integration_windows,
               integrated_vars)

import dates
for month in dates.all_months:
    yearmon = format_yearmon(2012, month)

    steps += monthly.monthly_observed(workspace,
                                      static,
                                      inputs,
                                      integration_windows,
                                      integrated_vars,
                                      lsm_vars,
                                      yearmon)

import socket
if socket.gethostname() == 'flaxvm':
    print("Checking steps only")
    for step in steps:
        step.get_text(vars)
else:
    with open(os.path.join(makefile, 'Makefile'), 'w') as outfile:
        outfile.write('.DELETE_ON_ERROR:\n')
        outfile.write('.SECONDARY:\n')

        outfile.write('\n')

        for step in reversed(steps):
            outfile.write(step.get_text(vars))
            step.get_text(vars)

        print("Done")

