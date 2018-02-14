import abc
import dates

class ConfigBase(metaclass=abc.ABCMeta):

    distribution = "gev"

    @abc.abstractmethod
    def historical_years(self):
        """
        Provides a list of the years of historical record available for use
        during spin-up.
        """
        pass

    def historical_yearmons(self):
        return [dates.format_yearmon(year, month)
                for year in self.historical_years()
                for month in dates.all_months]

    @abc.abstractmethod
    def result_fit_years(self):
        """
        Provides a list of years of data to be considered in fitting distributions
        for computed variables.
        """
        pass

    @abc.abstractmethod
    def static_data(self):
        pass

    @abc.abstractmethod
    def workspace(self):
        pass

    @abc.abstractmethod
    def observed_data(self):
        pass

    def global_prep(self):
        return []

    def should_run_spinup(self):
        return True

    def should_run_lsm(self, yearmon=None):
        return True

    def result_postprocess_steps(self, yearmon=None, target=None, member=None):
        return []

    def forecast_targets(self, yearmon):
        """
        Provides a list of forecast targets for a given yearmon, or an empty
        list if the configuration does not contain forecasts.
        """
        return []

    def forecast_ensemble_members(self, yearmon):
        """
        Provides a list of forecast ensemble members for a given yearmon, or
        an empty list if the configuration does not contain forecasts.
        """
        return []

    def integration_windows(self):
        """
        Provides a list of integration windows (in months)
        """
        return [ 3, 6, 12, 24, 36, 60 ]

    def lsm_vars(self):
        return [
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

    def integrated_vars(self):
        """
        Provides a dictionary whose keys are LSM output variables to be time-integrated, and whose
        values are lists of stats to apply to each of those variables (min, max, ave, etc.)
        """
        return {
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

    def integrated_var_names(self):
        """
        Provides a flat list of time-integrated variable names
        """
        return [var + '_' + stat for var, stats in self.integrated_vars().items() for stat in stats]

