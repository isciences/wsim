Bias-correcting a forecast (``wsim_correct``)
*********************************************

The ``wsim_correct`` utility bias-corrects forecast data, given statistical distributions of observed data and retrospective forecasts.

Usage is as follows:

.. code-block:: console

    Usage: wsim_correct \
        --retro=<fits>... \
        --obs=<file>... \
        --forecast=<file>... \
        --output=<file>

The ``--retro`` and ``--obs`` arguments are used to provide netCDF files containing pixel-specific fit parameters for distributions of retrospective forecast data and observed data, respectively.
The variables in the netCDF file can vary according to the distribution, but are typically ``location``, ``scale``, and ``shape``.
The name of the statistical distribution must be specified in the netCDF file using the ``distribution`` global attribute, and the name of the fitted variable must be specified using the ``variable`` global attribute.

The ``--forecast`` argument is used to provide one or more files of forecast data to be corrected (only one file can be provided for each forecast variable, but variables stored in separate files can be processed in a single program execution.)

