# Copyright (c) 2018 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import re

from abc import ABCMeta, abstractmethod

from . import dates

def read_vars(*args):
    file = args[0]
    var_list = args[1:]

    return file + '::' + ','.join(var_list)

def date_range(*args):
    """
    Create a date range string (as used by the wsim.io R package) given any of:
    - start, stop
    - start, stop, step
    - list (from which start and stop will be extracted, and a step of 1 assumed)
    """
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

RE_DATE_RANGE = re.compile('\[(?P<start>\d+):(?P<stop>\d+)(:(?P<step>\d+))?\]')

def expand_filename_dates(filename):
    # Short-circuit regex test.
    # This statement improves program runtime by ~50%.
    if '[' not in filename:
        return [filename]

    match = re.search(RE_DATE_RANGE, filename)

    if not match:
        return [filename]

    start = match.group('start')
    stop = match.group('stop')
    step = int(match.group('step') or 1)

    filenames = []
    for d in dates.expand_date_range(start, stop, step):
        filenames.append(filename[:match.start()] + d + filename[match.end():])

    return filenames


class Vardef:

    def __init__(self, file, var):
        self.file = file
        self.var = var

    def read_as(self, new_name):
        return self.file + '::' + self.var + '->' + new_name

    def __str__(self):
        return self.file + '::' + self.var

class ForecastForcing(metaclass=ABCMeta):

    @abstractmethod
    def precip_monthly(self, *, yearmon, target, member):
        """
        Return a Vardef for the precipitation variable
        """
        pass

    @abstractmethod
    def temp_monthly(self, *, yearmon, target, member):
        """
        Return a Vardef for the average monthly temparature
        """
        pass

    @abstractmethod
    def p_wetdays(self, *, yearmon, target, member):
        """
        Return a Vardef for the percentage of wet days in a month
        """
        pass

    def prep_steps(self, *, yearmon, target, member):
        """
        Returns one or more Steps needed to prepare this dataset for use
        for a given yearmon/target month/ensemble member
        """
        return []

    @staticmethod
    def global_prep_steps():
        """
        Returns one or more Steps needed to prepare this dataset for use
        (included only once for all yearmons/targets/members)
        """
        return []

class ObservedForcing(metaclass=ABCMeta):

    @abstractmethod
    def precip_monthly(self, *, yearmon):
        """
        Return a Vardef for the precipitation variable
        """
        pass

    @abstractmethod
    def temp_monthly(self, *, yearmon):
        """
        Return a Vardef for the average monthly temparature
        """
        pass

    @abstractmethod
    def p_wetdays(self, *, yearmon):
        """
        Return a Vardef for the percentage of wet days in a month
        """
        pass

    def prep_steps(self, *, yearmon):
        """
        Returns one or more Steps needed to prepare this dataset for use
        for a given yearmon
        """
        return []

    def global_prep_steps(self):
        """
        Returns one or more Steps needed to prepare this dataset for use
        (included only once for all yearmons)
        """
        return []

class Static(metaclass=ABCMeta):

    def __init__(self, source):
        self.source = source

    def global_prep_steps(self):
        return []

    def wc(self):
        return None

    def flowdir(self):
        return None

    def elevation(self):
        return None

class DefaultWorkspace:

    def __init__(self, outputs, tempdir=None):
        self.outputs = outputs
        if tempdir:
            self.tempdir = tempdir
        else:
            self.tempdir = os.path.join(self.outputs, '.tmp')

    def root(self):
        return self.outputs

    def make_path(self, thing, *, yearmon=None, window=None, target=None, member=None, temporary=False, basis=None, summary=False):
        return os.path.join(self.tempdir if temporary else self.outputs,
                            self.make_dirname(thing, window, basis, summary),
                            self.make_filename(thing,
                                               yearmon=yearmon,
                                               window=window,
                                               target=target,
                                               member=member,
                                               basis=basis,
                                               summary=summary))

    @staticmethod
    def make_stem(thing, basis, summary):
        return '_'.join(filter(None, (basis, thing, 'summary' if summary else None)))

    @staticmethod
    def make_dirname(thing, window, basis, summary):
        return '_'.join(filter(None, (basis,
                                      thing,
                                      'integrated' if window and window > 1 else None,
                                      'summary' if summary else None)))

    @staticmethod
    def make_filename(thing, *, yearmon, window=None, target=None, member=None, basis=None, summary=False):
        filename = DefaultWorkspace.make_stem(thing, basis, summary)

        if window:
            filename += '_{window}mo'

        filename += '_{yearmon}'

        if target:
            filename += '_trgt{target}'

        if member:
            filename += '_fcst{member}'

        filename += '.nc'

        return filename.format(thing=thing, window=window, yearmon=yearmon, target=target, member=member, basis=basis)

    # Summaries of data from multi-member forecast ensembles
    def composite_summary(self, *, yearmon, window, target=None):
        assert window is not None
        return self.make_path('composite', yearmon=yearmon, window=window, target=target).replace('composite_integrated', 'composite')

    def composite_summary_adjusted(self, *, yearmon, window, target=None):
        return self.make_path('composite_adjusted', yearmon=yearmon, window=window, target=target).replace('composite_adjusted_integrated', 'composite_adjusted')

    def composite_anomaly(self, *, yearmon, window, target=None):
        return self.make_path('composite_anom', yearmon=yearmon, window=window, target=target).replace('composite_anom_integrated', 'composite_anom')

    def composite_anomaly_return_period(self, *, yearmon, window, target=None, temporary=False):
        return self.make_path('composite_anom_rp', yearmon=yearmon, window=window, target=target, temporary=temporary).replace('composite_anom_rp_integrated', 'composite_anom_rp')

    def return_period_summary(self, *, yearmon, window, target):
        assert window is not None

        return self.make_path('rp', yearmon=yearmon, window=window, target=target, summary=True)

    def standard_anomaly_summary(self, *, yearmon, window, target):
        assert window is not None

        return self.make_path('anom', yearmon=yearmon, window=window, target=target, summary=True)

    def forcing_summary(self, *, yearmon, target):
        return self.make_path('forcing', yearmon=yearmon, target=target, summary=True)

    def results_summary(self, *, yearmon, window, target=None):
        return self.make_path('results', yearmon=yearmon, window=window, target=target, summary=True)

    # Individual model inputs, outputs, and derivatives
    def state(self, *, yearmon, member=None, target=None):
        return self.make_path('state', yearmon=yearmon, member=member, target=target, window=None)

    def forcing(self, *, yearmon, member=None, target=None):
        return self.make_path('forcing', yearmon=yearmon, member=member, target=target, window=None)

    def results(self, *, yearmon, window, member=None, target=None, temporary=False, basis=None):
        assert window is not None

        return self.make_path('results', yearmon=yearmon, window=window, member=member, target=target, temporary=temporary, basis=basis)

    def return_period(self, *, yearmon, window, member=None, target=None, temporary=False, basis=None):
        assert window is not None

        return self.make_path('rp', yearmon=yearmon, window=window, member=member, target=target, temporary=temporary, basis=basis)

    def standard_anomaly(self, *, yearmon, window, member=None, target=None, temporary=False, basis=None):
        assert window is not None

        return self.make_path('anom', yearmon=yearmon, window=window, member=member, target=target, temporary=temporary, basis=basis)

    # Spinup files
    def initial_state(self):
        return os.path.join(self.outputs, 'spinup', 'initial_state.nc')

    def climate_norm_forcing(self, *, month, temporary=False):
        return os.path.join(self.tempdir if temporary else self.outputs,
                            'spinup',
                            'climate_norm_forcing_{month:02d}.nc'.format(month=month))

    def final_state_norms(self):
        return os.path.join(self.outputs, 'spinup', 'final_state_norms.nc')

    def spinup_state(self, yearmon=None):
        return os.path.join(self.outputs, 'spinup', 'spinup_state_{yearmon}.nc'.format(yearmon=yearmon))

    def spinup_state_pattern(self):
        return self.spinup_state(yearmon='%T')

    def spinup_mean_state(self, *, month):
        return os.path.join(self.outputs, 'spinup', 'spinup_mean_state_month_{month:02d}.nc'.format(month=month))

    def tag(self, name):
        return os.path.join(self.outputs, 'tags', name)

    # Distribution fit files
    def fit_obs(self, *, var, month, window, stat=None, basis=None):
        assert window is not None

        if basis:
            filename = '{basis}_{var}'
        else:
            filename = '{var}'

        if stat:
            filename += '_{stat}'

        if window:
            filename += '_{window}mo'

        filename += '_month_{month:02d}.nc'

        return os.path.join(self.outputs, 'fits', filename.format_map(locals()))

    def fit_composite_anomalies(self, *, indicator, window):
        return os.path.join(self.outputs, 'fits', 'composite_anom_{indicator}_{window}mo.nc'.format(window=window,
                                                                                                    indicator=indicator))


