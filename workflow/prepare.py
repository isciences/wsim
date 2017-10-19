from step import Step
from commands import *
from paths import Vardef

def cfs_prepare(data, forecast_targets, ensemble_members):
    steps = []

    for i, target in enumerate(forecast_targets):
        lead_months = i+1

        for icm in ensemble_members:
            # Convert the forecast data from GRIB to netCDF
            steps += convert_forecast(data, icm, target)

            # Bias-correct the forecast
            steps += correct_forecast(data, icm, target, lead_months)

    return steps

def convert_forecast(data, icm, target):
    return [
        Step(
            targets=data.forecast_raw(icm=icm, target=target),
            dependencies=[data.forecast_grib(icm=icm, target=target)],
            commands=[
                forecast_convert('$<', '$@')
            ]
        )
    ]

def correct_forecast(data, icm, target, lead_months):
    target_month = int(target[-2:])

    return [
        Step(
            targets=data.forecast_corrected(icm=icm, target=target),
            dependencies=[data.forecast_raw(icm=icm, target=target)] +
                         [data.fit_retro(target_month=target_month,
                                         lead_months=lead_months,
                                         var=var)
                          for var in ('T', 'Pr')] +
                         [data.fit_obs(month=target_month,
                                       var=var)
                          for var in ('T', 'Pr')],
            commands=[
                wsim_correct(retro=data.fit_retro(target_month=target_month, lead_months=lead_months, var='T'),
                             obs=data.fit_obs(month=target_month, var='T'),
                             forecast=Vardef(data.forecast_raw(icm=icm, target=target), 'tmp2m').read_as('T'),
                             output=data.forecast_corrected(icm=icm, target=target)),
                wsim_correct(retro=data.fit_retro(target_month=target_month, lead_months=lead_months, var='Pr'),
                             obs=data.fit_obs(month=target_month, var='Pr'),
                             forecast=Vardef(data.forecast_raw(icm=icm, target=target), 'prate').read_as('Pr'),
                             output=data.forecast_corrected(icm=icm, target=target),
                             append=True)
            ]
        )
    ]
