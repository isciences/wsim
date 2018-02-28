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

import calendar
import datetime

all_months = range(1, 13)

def parse_yearmon(yearmon):
    """
    Parse a YYYYMM string and return a (year, month) integer tuple
    """
    return int(yearmon[:4]), int(yearmon[4:])


def format_yearmon(year, month):
    """
    Format a year and month as YYYYMM
    """
    return '{:04d}{:02d}'.format(year, month)


def get_yearmons(start, stop):
    """
    Generate all YYYYMM strings between "start" and "stop"
    """
    start_year, start_month = parse_yearmon(start)
    stop_year, stop_month = parse_yearmon(stop)

    if start_year > stop_year:
        raise ValueError("Stop date is before start date.")
    if start_year == stop_year and start_month > stop_month:
        raise ValueError("Stop date is before start date.")

    yield start
    while start != stop:
        start = get_next_yearmon(start)
        yield start


def get_last_day_of_month(yearmon):
    """
    Get integer last day or month for YYYYMM
    """
    return calendar.monthrange(*parse_yearmon(yearmon))[1]


def get_previous_yearmon(yearmon):
    """
    Get previous YYYYMM to input
    """
    year, month = parse_yearmon(yearmon)

    month -= 1
    if month == 0:
        month = 12
        year -= 1

    return format_yearmon(year, month)


def get_next_yearmon(yearmon):
    """
    Get next YYYYMM to input
    """
    year, month = parse_yearmon(yearmon)

    month += 1
    if month == 13:
        month = 1
        year += 1

    return format_yearmon(year, month)


def get_next_yearmons(yearmon, n):
    """
    Get next n YYYYMMs after input
    """
    targets = [get_next_yearmon(yearmon)]

    for _ in range(n - 1):
        targets.append(get_next_yearmon(targets[-1]))

    return targets


def rolling_window(yearmon, n):
    """
    Return n months ending with (and including) input
    """
    window = [yearmon]

    while len(window) < n:
        window.insert(0, get_previous_yearmon(window[0]))

    return window

def days_in_month(yearmon):

    """
    Return YYYYMMDD strings for each day in input YYYYMM
    """
    return [yearmon + '{:02d}'.format(day + 1) for day in range(calendar.monthrange(*parse_yearmon(yearmon))[1])]

def add_years(yyyy, n):
    return '{:04d}'.format(int(yyyy) + n)

def add_months(yyyymm, n):
    year = int(yyyymm[:4])
    month = int(yyyymm[4:])

    month += n

    while month > 12:
        month -= 12
        year += 1

    return '{:04d}{:02d}'.format(year, month)

def add_days(yyyymmdd, n):
    date = datetime.date(int(yyyymmdd[0:4]),
                         int(yyyymmdd[4:6]),
                         int(yyyymmdd[6:8]))

    date += datetime.timedelta(days=n)

    return date.strftime('%Y%m%d')
