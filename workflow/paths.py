import os
from abc import ABCMeta, abstractmethod

def read_vars(*args):
    file = args[0]
    var_list = args[1:]

    return file + '::' + ','.join(var_list)

def date_range(*args):
    step = 1

    if len(args) == 1 and type(args[0]) is list:
        begin = args[0][0]
        end   = args[0][-1]
    elif len(args) >= 2:
        begin = args[0]
        end = args[1]

        if len(args) == 3:
            step = args[2]
    else:
        raise Exception('Invalid date range')

    return '[{}:{}:{}]'.format(begin, end, step)

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
        for a given yearmon/target month/ensemble member
        """
        return []

    def global_prep_steps(self):
        """
        Returns one or more Steps needed to prepare this dataset for use
        (included only once for all yearmons/targets/members)
        """
        return []

class DefaultWorkspace:

    def __init__(self, outputs):
        self.outputs = outputs

    def root(self):
        return self.outputs

    def climate_norm_forcing(self, **kwargs):
        return os.path.join(self.outputs, 'spinup', 'climate_norm_forcing_{month:02d}.nc'.format_map(kwargs))

    def initial_state(self):
        return os.path.join(self.outputs, 'spinup', 'initial_state.nc')

    def final_state_norms(self):
        return os.path.join(self.outputs, 'spinup', 'final_state_norms.nc')

    def make_path(self, root, thing, **kwargs):
        return os.path.join(self.outputs, root, self.make_filename(thing, **kwargs))

    @staticmethod
    def make_filename(thing, *, yearmon, window=None, target=None, member=None):
        filename = thing

        if window:
            filename += '_{window}mo'

        filename += '_{yearmon}'

        if target:
            filename += '_trgt{target}'

        if member:
            filename += '_fcst{member}'

        filename += '.nc'

        return filename.format(thing=thing, window=window, yearmon=yearmon, target=target, member=member)

    # Summaries of data from multi-member forecast ensembles
    def composite_summary(self, *, yearmon, window=1, target=None):
        assert window is not None
        return self.make_path('composite', 'composite', yearmon=yearmon, window=window, target=target)

    def return_period_summary(self, *, yearmon, window=1, target):
        assert window is not None

        root = 'rp_summary' if window == 1 else 'rp_integrated_summary'

        return self.make_path(root, 'rp_summary', yearmon=yearmon, window=window, target=target)

    def results_summary(self, *, yearmon, window, target=None):
        root = 'results_summary' if window ==1 else 'results_integrated_summary'

        return self.make_path(root, 'results_summary', yearmon=yearmon, window=window, target=target)

    # Individual model inputs, outputs, and derivatives
    def state(self, *, yearmon, member=None, target=None):
        return self.make_path('state', 'state', yearmon=yearmon, member=member, target=target)

    def forcing(self, *, yearmon, member=None, target=None):
        return self.make_path('forcing', 'forcing', yearmon=yearmon, member=member, target=target)

    def results(self, *, yearmon, window=1, member=None, target=None):
        assert window is not None

        root = 'results' if window == 1 else 'results_integrated'

        return self.make_path(root, 'results', yearmon=yearmon, window=window, member=member, target=target)

    def return_period(self, *, yearmon, window=1, member=None, target=None):
        assert window is not None

        root = 'rp' if window == 1 else 'rp_integrated'

        return self.make_path(root, 'rp', yearmon=yearmon, window=window, member=member, target=target)

    def standard_anomaly(self, *, yearmon, window=1, member=None, target=None):
        assert window is not None

        root = 'anom' if window == 1 else 'anom_integrated'
        return self.make_path(root, 'anom', yearmon=yearmon, window=window, member=member, target=target)

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


