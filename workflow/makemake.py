import os
import sys

import paths
import monthly
import spinup
import dates

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
data = 'nldas'

if data == 'ncep':
    integration_windows = [ 3, 6, 12, 24, 36, 60 ]
    historical_years = range(1948, 2017) # the complete historical record
    result_fit_years = range(1950, 2010) # the lsm results we want to use for GEV fits

    workspace = paths.Workspace('/mnt/fig_rw/WSIM_DEV/wsim2')
    static = paths.Static('/mnt/fig/WSIM/WSIM_source_V1.2')
    inputs = paths.NCEP('/mnt/fig/WSIM/WSIM_source_V1.2', '/mnt/fig_rw/WSIM_DEV/wsim2')
    makefile = '/mnt/fig_rw/WSIM_DEV/wsim2'

elif data == 'nldas':
    integration_windows = [ 3, 6, 12, 24, 36, 60 ]
    historical_years = range(1989, 2012) # the complete historical record
    result_fit_years = range(1990, 2010) # the lsm results we want to use for GEV fits

    workspace = paths.Workspace('/mnt/fig_rw/WSIM_DEV/wsim2/nldas')
    static = paths.StaticNLDAS('/mnt/fig_rw/WSIM_DEV/wsim2/nldas/static_nldas_grid.nc')
    inputs = paths.NLDAS('/mnt/fig/Data_Global/NLDAS')
    makefile = workspace.outputs

steps = spinup.spinup(workspace,
                      static,
                      inputs,
                      historical_years,
                      result_fit_years,
                      integration_windows,
                      integrated_vars,
                      lsm_vars)

for month in dates.all_months:
    yearmon = dates.format_yearmon(2012, month)

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
        step.get_text({'BINDIR' : bindir})
else:
    with open(os.path.join(makefile, 'Makefile'), 'w') as outfile:
        outfile.write('.DELETE_ON_ERROR:\n')
        outfile.write('.SECONDARY:\n')

        outfile.write('\n')

        for step in reversed(steps):
            outfile.write(step.get_text({'BINDIR' : bindir}))

        print("Done")

