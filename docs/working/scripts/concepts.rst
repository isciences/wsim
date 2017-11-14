General Concepts
****************

File formats
============

WSIM tools use `netCDF <https://www.unidata.ucar.edu/software/netcdf/>`_ as a standard file format, using the `CF Conventions <http://cfconventions.org/>`_ for metadata. Although the output of all WSIM tools is in netCDF format, tools are also capable of reading data from any format supported by `GDAL <http://www.gdal.org/>`_.

.. _variable-definitions:

Variable definitions
====================

Many tools use one or more ``--input`` arguments to provide references to variables used in computations performed by the tool. A variable definition may be as simple as a file name, and all file names are valid variable definitions. However, additional syntax recognized by WSIM allows a single variable definition to refer to one or more variables in one or more files.

Wildcard expansion
------------------

Wildcard expansion can be used with ``--input`` arguments. For example, a pattern like ``--input=temp_19[7-9]*.nc`` could be used to load temperature values from 1970 to 1999.

Regular variables
-----------------

If a raw netCDF filename is provided to an ``--input`` argument, WSIM tools will assume that all "regular" variables in the file should be loaded. A "regular" variable is a file that:

* is not a coordinate variable
* is associated with at least one dimension

As an example, consider the following netCDF file (representing output from :doc:`wsim_fit`, as described by ``ncinfo``:

::

    root group (NETCDF4 data model, file format HDF5):
        Conventions: CF-1.6
        date_created: 2017-09-11T11:0224-0400
        distribution: gev
        dimensions(sizes): lon(720), lat(360)
        variables(dimensions): float64 lon(lon), float64 lat(lat), float64 location(lat,lon), float64 scale(lat,lon), float64 shape(lat,lon), int32 crs()
        groups: 


In this file, `lon` and `lat` are not read by WSIM tools because they are coordinate variables. The `crs` variable is not associated with any dimensions and is also ignored by WSIM tools.


Reading specific variables using ``::``
---------------------------------------

A filename may optionally followed by ``::``, followed by a comma-separated list of variable names or band numbers in the file. If ``::`` is not provided, it will be assumed that all "regular" variables in the file should be loaded. A "regular" variable is a variable that is not a coordinate variable, and that is associated with at least one dimension.

**TODO this is the case for netCDF files, but how about GDAL? Need to investigate.**

In the netCDF file example shown above:

* ``--input=fits.nc`` would load the three regular variables: ``location``, ``scale``, and ``shape``.
* ``--input=fits.nc::location`` would load only the ``location`` variable
* ``--input=fits.nc::shape,location`` would load the ``shape`` and ``location`` variables. The same variables could be loaded with multiple arguments (``--input=fits.nc::shape --input=fits.nc::location``) although this is less efficient.

The ``::`` syntax (and other variable operators described below) can be used in conjunction with filename wildcard matching, for example: ``--input="obs_19980[1-6].nc::T,Pr`` could be used to load temperature and precipitation observations from January to June 1980.

Renaming variables using ``->``
-------------------------------

A variable can be renamed using the ``->`` symbol as part of the specification.  For example, one could write ``--input="my_image.tiff::1->red,2->green,3->blue"``, which would load bands 1,2, and 3 of ``my_image.tiff`` and assign them the names ``red``, ``green``, and ``blue``.

Transforming variables using ``@``
----------------------------------

Basic transformations can be performed on loaded data by specifying one or more named transformations.  For example, the following variable definition loads the variable ``PETmE``, negates the values, fills NODATA cells with zero, and names the resulting variable ``Negative_PETmE``: ``PETmE@negate@fill0->Negative_PETmE``.

The following transformations are supported:

* ``negate`` : negates all values
* ``fill0`` : replaces all NODATA values with zero
* ``[x*x + cos(x)]`` : evaluate any R expression, where `x` is a cell value.







