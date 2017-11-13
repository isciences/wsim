from step import Step
import paths
import dates
from config_base import ConfigBase

import os

class GLDAS20_Noah(ConfigBase):

    def __init__(self, source, derived):
        self._source = source
        self._workspace = paths.DefaultWorkspace(derived)

    def should_run_spinup(self):
        return True

    def should_run_lsm(self, yearmon=None):
        return False

    def historical_years(self):
        return range(1948, 2011)

    def result_fit_years(self):
        return range(1950, 2010) # 1950-2009 gives even 60-year period

    def static_data(self):
        raise NotImplementedError()

    def observed_data(self):
        raise NotImplementedError()

    def workspace(self):
        return self._workspace

    def lsm_vars(self):
        return [
            'Bt_RO',
            #'Bt_Runoff',
            #'EmPET',
            'PETmE',
            #'PET',
            #'P_net',
            #    'Pr',
            #'RO_m3',
            'RO_mm',
            #'Runoff_mm',
            #'Runoff_m3',
            #'Sa',
            #'Sm',
            #    'Snowpack',
            #    'T',
            'Ws'
        ]

    def integrated_vars(self):
        """
        Provides a dictionary whose keys are LSM output variables to be time-integrated, and whose
        values are lists of stats to apply to each of those variables (min, max, ave, etc.)
        """
        return {
            'Bt_RO'     : [ 'min', 'max', 'sum' ],
            #'Bt_Runoff' : [ 'sum' ],
            #'EmPET'     : [ 'sum' ],
            #'E'         : [ 'sum' ],
            'PETmE'     : [ 'sum' ],
            #'P_net'     : [ 'sum' ],
            #'Pr'        : [ 'sum' ]n
            #'RO_mm'     : [ 'sum' ],
            #'Runoff_mm' : [ 'sum' ],
            #'Snowpack'  : [ 'sum' ],
            #'T'         : [ 'ave' ],
            'Ws'        : [ 'ave' ]
        }

    def result_postprocess_steps(self, yearmon=None):
        year, mon =  dates.parse_yearmon(yearmon)

        input_file = os.path.join(self._source,
                                  '{:04d}'.format(year),
                                  'GLDAS_NOAH025_M.A{}.020.nc4'.format(yearmon))

        output_file = self.workspace().results(yearmon=yearmon)

        return [
            Step(
                targets=output_file,
                dependencies=[input_file],
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'gldas_noah_extract.sh'),
                        input_file,
                        output_file
                    ],
                    [
                        os.path.join('{BINDIR}', 'wsim_flow.R'),
                        '--input', paths.read_vars(output_file, 'RO_mm'),
                        '--flowdir', os.path.join(self.workspace().root(), 'flowdirs.img'),
                        '--output', output_file,
                        '--varname', 'Bt_RO',
                        '--wrapx'
                    ]
                ]
            )
        ]

config = GLDAS20_Noah
