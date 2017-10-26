import os
from abc import ABCMeta, abstractmethod

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

class Forcing(metaclass=ABCMeta):

    @abstractmethod
    def precip_monthly(self, **kwargs):
        """
        Return a Vardef for the precipitation variable
        """
        pass

    @abstractmethod
    def temp_monthly(self, **kwargs):
        """
        Return a Vardef for the average monthly temparature
        """
        pass

    @abstractmethod
    def p_wetdays(self, **kwargs):
        """
        Return a Vardef for the percentage of wet days in a month
        """
        pass

    def prep_steps(self, **kwargs):
        """
        Returns one or more Steps needed to prepare this dataset for use
        """
        return []

class DefaultWorkspace:

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

    def results_summary(self, **kwargs):
        filename = 'results_summary_{yearmon}_'

        if 'window' in kwargs and kwargs['window']:
            filename += '{window}mo_'

        filename += 'trgt{target}.nc'

        return os.path.join(self.outputs,
                            'summary',
                            filename.format_map(kwargs))

    def return_period(self, **kwargs):
        filename = "rp_"

        if "icm" in kwargs and kwargs['icm']:
            filename += "{icm}_"

        if "window" in kwargs and kwargs['window']:
            filename += "{window}mo_"

        filename += "{target}.nc"

        return os.path.join(self.outputs, 'rp', filename.format_map(kwargs))

    def return_period_summary(self, **kwargs):
        filename = 'rp_summary_{yearmon}_'

        if "window" in kwargs and kwargs['window']:
            filename += "{window}mo_"

        filename += "trgt{target}.nc"

        return os.path.join(self.outputs, 'summary', filename.format_map(kwargs))

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
        filename = '{var}'

        if 'stat' in kwargs and kwargs['stat'] is not None:
            filename += '_{stat}'

        if 'window' in kwargs and kwargs['window'] is not None:
            filename += '_{window}mo'

        filename += '_month_{month:02d}.nc'

        return os.path.join(self.outputs, 'fits', filename.format_map(kwargs))


