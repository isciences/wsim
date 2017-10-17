import calendar

all_months = range(1, 13)

def parse_yearmon(yearmon):
    return ( int(yearmon[:4]), int(yearmon[4:] ))

def format_yearmon(year, month):
    return '{}{:02d}'.format(year, month)

def format_mon(month):
    return '{:02d}'.format(month)

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

def rolling_window(yearmon, n):
    window = [yearmon]

    while len(window) < n:
        window.insert(0, get_previous_yearmon(window[0]))

    return window

def days_in_month(yearmon):
    return [yearmon + '{:02d}'.format(day + 1) for day in range(calendar.monthrange(*parse_yearmon(yearmon))[1])]

def get_icms(yearmon):
    prev = get_previous_yearmon(yearmon)
    last_day = calendar.monthrange(*parse_yearmon(prev))[1]

    start_day = last_day - 6

    icms = []
    for day in range(start_day, last_day + 1):
        for hour in (0, 6, 12, 18):
            icms.append(prev + '{:02d}{:02d}'.format(day, hour))
    return icms

def get_forecast_targets(yearmon):
    targets = [get_next_yearmon(yearmon)]

    while len(targets) < 9:
        targets.append(get_next_yearmon(targets[-1]))

    return targets
