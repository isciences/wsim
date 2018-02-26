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

all_months = range(1, 13)

def parse_yearmon(yearmon):
    return int(yearmon[:4]), int(yearmon[4:])

def format_yearmon(year, month):
    return '{}{:02d}'.format(year, month)

def format_mon(month):
    return '{:02d}'.format(month)

def get_yearmons(start, stop):
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
    return calendar.monthrange(*parse_yearmon(yearmon))[1]

def get_previous_yearmon(yearmon):
    year, month = parse_yearmon(yearmon)

    month -= 1
    if month == 0:
        month = 12
        year -= 1

    return format_yearmon(year, month)

def get_next_yearmon(yearmon):
    year, month = parse_yearmon(yearmon)

    month += 1
    if month == 13:
        month = 1
        year += 1

    return format_yearmon(year, month)

def get_next_yearmons(yearmon, n):
    targets = [get_next_yearmon(yearmon)]

    for _ in range(n - 1):
        targets.append(get_next_yearmon(targets[-1]))

    return targets


def rolling_window(yearmon, n):
    window = [yearmon]

    while len(window) < n:
        window.insert(0, get_previous_yearmon(window[0]))

    return window

def days_in_month(yearmon):
    return [yearmon + '{:02d}'.format(day + 1) for day in range(calendar.monthrange(*parse_yearmon(yearmon))[1])]
