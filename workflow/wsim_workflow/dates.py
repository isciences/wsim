# Copyright (c) 2018-2019 ISciences, LLC.
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
import re

from typing import Generator, List, Optional, Tuple, Union

all_months = range(1, 13)


def is_yearmon(s: str) -> bool:
    """
    Check if a string represents a valid date in YYYYMM format
    """
    if not re.match('^[0-9]{6}$', s):
        return False

    _, month = parse_yearmon(s)

    return month >= 1 and month <= 12


def parse_yearmon(yearmon: str) -> Tuple[int, int]:
    """
    Parse a YYYYMM string and return a (year, month) integer tuple
    """
    return int(yearmon[:4]), int(yearmon[4:])


def format_yearmon(year: int, month: int) -> str:
    """
    Format a year and month as YYYYMM
    """
    return '{:04d}{:02d}'.format(year, month)


def get_yearmons(start: str, stop: str) -> Generator[str, None, None]:
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


def get_last_day_of_month(yearmon: str) -> int:
    """
    Get integer last day or month for YYYYMM
    """
    return calendar.monthrange(*parse_yearmon(yearmon))[1]


def get_previous_yearmon(yearmon: str) -> str:
    """
    Get previous YYYYMM to input
    """
    year, month = parse_yearmon(yearmon)

    month -= 1
    if month == 0:
        month = 12
        year -= 1

    return format_yearmon(year, month)


def get_next_yearmon(yearmon: str) -> str:
    """
    Get next YYYYMM to input
    """
    year, month = parse_yearmon(yearmon)

    month += 1
    if month == 13:
        month = 1
        year += 1

    return format_yearmon(year, month)


def get_next_yearmons(yearmon: str, n: int) -> List[str]:
    """
    Get next n YYYYMMs after input
    """
    targets = [get_next_yearmon(yearmon)]

    for _ in range(n - 1):
        targets.append(get_next_yearmon(targets[-1]))

    return targets


def rolling_window(yearmon: str, n: int) -> List[str]:
    """
    Return n months ending with (and including) input
    """
    window = [yearmon]

    while len(window) < n:
        window.insert(0, get_previous_yearmon(window[0]))

    return window


def days_in_month(yearmon: str) -> List[str]:
    """
    Return YYYYMMDD strings for each day in input YYYYMM
    """
    return [yearmon + '{:02d}'.format(day + 1) for day in range(calendar.monthrange(*parse_yearmon(yearmon))[1])]


def add_years(yyyy: Union[str, int], n: int) -> str:
    """
    Add n years to YYYY
    """
    return '{:04d}'.format(int(yyyy) + n)


def add_months(yyyymm: str, n: int) -> str:
    """
    Add n months to YYYYMM
    """
    year = int(yyyymm[:4])
    month = int(yyyymm[4:])

    month += n

    while month > 12:
        month -= 12
        year += 1
    while month <= 0:
        month += 12
        year -= 1

    return '{:04d}{:02d}'.format(year, month)


def add_days(yyyymmdd: str, n: int) -> str:
    """
    Add n days to YYYYMMDD
    """
    date = datetime.date(int(yyyymmdd[0:4]),
                         int(yyyymmdd[4:6]),
                         int(yyyymmdd[6:8]))

    date += datetime.timedelta(days=n)

    return date.strftime('%Y%m%d')


def expand_date_range(start: str, stop: str, step: int) -> List[str]:
    """
    Return all dates in the list >= start and <= stop, separated by step.
    Inputs may be YYYY, YYYYMM, or YYYYMMDD strings
    """
    dates = [start]

    if len(start) != len(stop):
        raise ValueError("Start and stop dates must be in same format")

    if len(start) == 4:
        increment_date = add_years
    elif len(start) == 6:
        increment_date = add_months
    elif len(start) == 8:
        increment_date = add_days
    else:
        raise ValueError("Unknown date format")

    while True:
        nxt = increment_date(dates[-1], step)
        if nxt <= stop:
            dates.append(nxt)
        else:
            break

    return dates


def next_occurence_of_month(yearmon: str, month_b: int) -> str:
    assert 0 < month_b <= 12

    year, month = parse_yearmon(yearmon)

    if month <= month_b:
        return format_yearmon(year, month_b)
    else:
        return format_yearmon(year+1, month_b)


def format_range(start, end, step=None) -> str:
    if step:
        return '[{}:{}:{}]'.format(start, end, step)
    else:
        return '[{}:{}]'.format(start, end)

def available_yearmon_range(*, window: int, month: Optional[int]=None, start_year: int, end_year: int) -> str:
    assert start_year + (window-1) // 12 <= end_year

    range_str = '[{begin}:{end}:{step}]'

    available_start = add_months(format_yearmon(start_year, 1), window-1)

    start_yearmon = available_start if month is None else next_occurence_of_month(available_start, month)

    return range_str.format(begin=start_yearmon,
                            end=format_yearmon(end_year, 12 if month is None else month),
                            step=1 if month is None else 12)


def get_lead_months(yearmon: str, target: str) -> int:
    assert target >= yearmon

    # dumb implementation, can improve later
    lead = 0
    while yearmon < target:
        yearmon = add_months(yearmon, 1)
        lead += 1

    return lead
