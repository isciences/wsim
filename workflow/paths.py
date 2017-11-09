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

    def initial_state(self):
        return os.path.join(self.outputs, 'spinup', 'initial_state.nc')

    def final_state_norms(self):
        return os.path.join(self.outputs, 'spinup', 'final_state_norms.nc')

    def make_path(self, thing, **kwargs):
        return os.path.join(self.outputs, thing, self.make_filename(thing, **kwargs))

    def make_filename(self, thing, *, yearmon, window=None, target=None, member=None):
        filename = thing

        if window:
            filename += '_{window}mo'

        filename += '_{yearmon}'

        if target:
            filename += '_trgt{target}'

        if member:
            filename += '_fcst{member}'

        filename += '.nc'

        return filename.format(window=window, yearmon=yearmon, target=target, member=member)

    # Summaries of data from multi-member forecast ensembles
    def composite_summary(self, **kwargs):
        return self.make_path('composite', **kwargs)

    def return_period_summary(self, **kwargs):
        return self.make_path('rp_summary', **kwargs)

    def results_summary(self, **kwargs):
        return self.make_path('results_summary', **kwargs)

    # Individual model inputs, outputs, and derivatives
    def state(self, **kwargs):
        return self.make_path('state', **kwargs)

    def forcing(self, **kwargs):
        return self.make_path('forcing', **kwargs)

    def results(self, **kwargs):
        return self.make_path('results', **kwargs)

    def return_period(self, **kwargs):
        return self.make_path('rp', **kwargs)

    # Spinup files
    def spinup_state(self, yearmon=None):
        return os.path.join(self.outputs, 'spinup', 'spinup_state_{yearmon}.nc'.format(yearmon=yearmon))

    def spinup_state_pattern(self):
        return self.spinup_state(yearmon='%T')

    def spinup_mean_state(self, **kwargs):
        return os.path.join(self.outputs, 'spinup', 'spinup_mean_state_month_{month:02d}.nc'.format_map(kwargs))

    def fit_obs(self, **kwargs):
        filename = '{var}'

        if 'stat' in kwargs and kwargs['stat'] is not None:
            filename += '_{stat}'

        if 'window' in kwargs and kwargs['window'] is not None:
            filename += '_{window}mo'

        filename += '_month_{month:02d}.nc'

        return os.path.join(self.outputs, 'fits', filename.format_map(kwargs))


