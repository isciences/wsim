import calendar

all_months = range(1, 13)

def parse_yearmon(yearmon):
    return ( int(yearmon[:4]), int(yearmon[4:] ))

def format_yearmon(year, month):
    return '{}{:02d}'.format(year, month)

def format_mon(month):
    return '{:02d}'.format(month)

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

def rolling_window(yearmon, n):
    window = [yearmon]

    while len(window) < n:
        window.insert(0, get_previous_yearmon(window[0]))

    return window

def days_in_month(yearmon):
    return [yearmon + '{:02d}'.format(day + 1) for day in range(calendar.monthrange(*parse_yearmon(yearmon))[1])]
