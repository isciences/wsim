wsim_correct
************

The ``wsim_correct`` utility bias-corrects forecast data, given statistical distributions of observed data and retrospective forecasts.

Usage is as follows:

.. code-block:: console

    Usage: wsim_correct \
        --retro=<fits> \
        --obs=<file> \
        --forecast=<file> \
        --output=<file>

The ``--retro`` and ``--obs`` arguments are used to provide netCDF files containing pixel-specific fit parameters for distributions of retrospective forecast data and observed data, respectively. The variables in the netCDF file can vary according to the distribution, but are typically ``location``, ``scale``, and ``shape``. The name of the statistical distribution must be specified in the netCDF file using the ``distribution`` global attribute.

The ``--forecast`` argument is used to provide a file of forecast data.

.. WARNING::
  There is currently a mismatch between the expected units of the various inputs. Fit parameters must be provided in units of degrees Celsius (for temperature) or millimeters per month (for precipitation). Forecast data must be provided in units of degrees Kelvin and millimeters per second.

