Forecast Bias Correction
************************

Background
----------

Any climate model has systematic errors that are specific to the parameter of interest, as well as to the location on the globe, time (season of the year), and forecast lead time.
The errors can be in terms of the mean, dispersion, and shape of the distribution (skewness).
Error correction often only accounts for shifts in the mean or assumes a normal distribution by correcting the standard deviation.
However, ideally a bias correction method would address all three of the systematic errors by taking into account differences in the shape of the modeled vs. observed distributions.

To do this, WSIM uses a quantile-matching correction method based on the estimated cumulative distribution functions (CDFs) of the observed and forecast data at a specific pixel/month/lead time combination:

.. math::

  \hat{z}_0 = F_0\left(F_m\left(z_m\right)\right)^{-1}

where :math:`\hat{z}_0` represents the corrected forecast value, :math:`F_0` is the CDF for the observed data at a specific pixel/month/lead time combination, :math:`F_m` is the CDF for the forecast data at the same pixel/month/lead time, and :math:`z_m` represents the forecast value to be corrected.
This method determines the quantile represented by :math:`z_m` on the model distribution, and then translates that quantile back into the original units by means of the observed distribution.
The following picture provides a graphical representation of the procedure:

.. figure:: /_static/bias_correction_graph.svg
  :align: center

This approach requires two sets of data for each parameter to be corrected: one set to estimate the CDF of the modeled data and one set for the observed data.

Bias Correction of CFSv2 Forecast Data
--------------------------------------

WSIM can bias-correct CFSv2 forecasts using the above procedure, once distributions for observed and forecast data have been estimated for each pixel/month/lead time.

Distributions for forecast data can be estimated using a set of reforecasts (hindcasts) published by `NCEP <http://www.ncep.noaa.gov/>`_ for the 27-year period from 1983-2009.
(Some hindcasts are available that target 1982 and 2010, but they are not available for all target month / lead-time combinations.)
Every five days within the hindcast period, a forecast is published at 12 AM, 6 AM, 12 PM, and 6 PM.
This allows construction of a 24-member forecast ensemble for each forecast issue month and target month.
(As a particularity of the five-day spacing between forecasts, a 28-member ensemble is available for forecasts issued in November.)

Hindcast data is available for download for `temperature <https://nomads.ncdc.noaa.gov/data/cfsr-rfl-mmts/tmp2m/>`_ and `precipitation rate <https://nomads.ncdc.noaa.gov/data/cfsr-rfl-mmts/prate/>`_, among other parameters.

.. note::

  The organization of hindcast data into files reflects operational use of the data by NCEP; this organization can make the files  confusing to work with in other contexts.
  In particular, the monthly files into which forecasts are divided reflect the month in which the forecast will be used by NCEP, not the date in which the forecast was issued, nor the date targeted by the forecast.
  To use the forecasts, it is simplest to extract all forecasts from all GRIB files into individual forecast files so that they can be grouped as needed for analysis.
  
An example file name is as follows: ``prate.m04.oct.cfsv2.data.grb2``.
This file contains GRIB 308 messages, covering forecasts issued on September 8 at 6 PM over 28 different years, for 11 different lead times (0-1 months to 10-11 months, 11 x 28 = 308).
As another example, the file ``prate.m20.feb.cfsv2.data.grb2`` contains forecasts from January 31 at 6 PM.
Because it is produced late within the month, it does not contain a 0-1 month forecast (for January).
This file contains 10 x 28 = 280 messages.

WSIM provides a utility to extract forecasts from the GRIB files into individual files per forecast date, and target date.

.. warning::

  Extracting all forecasts from the GRIB files creates a substantial volume of data: 73 forecast dates / year * 4 forecasts / day * 9 lead months / forecast * 28 years * 2 variables = 147,168 forecast files.

The following command can be use to extract all forecasts from all GRIB files:

.. code-block:: console

  ls -1 *.grb2 | xargs -I{} /wsim/utils/hindcast_extract.sh {} workspace/source/NCEP_CFSv2/hindcasts

Once extracted, distributions can be fit for each pixel-month using ``wsim_fit``.
The ``hindcast_fit`` script automates this process:

.. code-block:: console

  utils/noaa_cfsv2_forecast/hindcast_fit.sh workspace/source/NCEP_CFSv2/hindcasts workspace/source/NCEP workspace/source/NCEP_CFSv2/hindcast_fits

