Fitting statistical distributions (``wsim_fit``)
************************************************

The ``wsim_fit`` utility computes pixel-wise fits of statistical distributions.

Usage is as follows:

.. code-block:: console

    wsim_fit (--distribution=<dist>) (--input=<file>)... (--output=<file>)


* ``--distribution`` specifies the statistical distribution to be used. The following distributions are currently supported:

    * ``gev`` : `generalized extreme value <https://en.wikipedia.org/wiki/Generalized_extreme_value_distribution>`_ distribution

* ``--input`` specifies input files to be used.  Multiple `--input` arguments can be provided, and each argument may refer to an individual file or a glob of files (e.g., ``--input=precip_2017*.img``)
* ``--output`` specifies the name of the output file.

All input values must be rasters of equal extent and resolution.

Program output is a single netCDF file, with global attributes indicating the variable fitted and distribution used, and `float64` variables containing the fit parameters.
Example ``ncinfo`` output for a netCDF generated by ``wsim_fit`` follows:

.. code-block:: console

    root group (NETCDF3_CLASSIC data model, file format NETCDF3):
    distribution: gev
    dimensions(sizes): lon(720), lat(360)
    variables(dimensions): float64 lon(lon), float64 lat(lat), float64 location(lat,lon), float64 scale(lat,lon), float64 shape(lat,lon)
    groups: 


