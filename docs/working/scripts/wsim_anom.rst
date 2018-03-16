Computing anomalies and return periods (``wsim_anom``)
******************************************************

The ``wsim_anom`` utility computes standard anomalies and return periods from observed data with a known statistical distribution.

Usage is as follows:

.. code-block:: console

    Usage: wsim_anom \
        --fits=<fits>... \
        --obs=<file>... \
        [--sa=<file>] \
        [--rp=<file>] \
        [--cores=<num_cores>]

The ``--fits`` argument is used to provide one or more netCDF files containing pixel-specific distribution fit parameters.
The variables in the netCDF file can vary according to the distribution, but are typically ``location``, ``scale``, and ``shape``.
The name of the statistical distribution must be specified in the netCDF file using the ``distribution`` global attribute, and the name of the fitted variable must be specified using the ``variable`` global attribute.

The ``--obs`` argument is used to provide one or more netCDF files of observations.
The variable names read from the netCDF files must match the variable name specified in the fit files.
(See :ref:`renaming-variables` for information on renaming variables at runtime.)
Given the fit parameters, these observations will be used to compute standard anomalies and return periods, which may be written to files specified using ``--sa`` and ``--rp``.

By default, computations are performed in a single thread, but multiple cores can be used if ``--cores`` is specified.

