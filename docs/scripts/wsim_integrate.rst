wsim_integrate
**************

The ``wsim_integrate`` utility integrates, or accumulates multiple observations of the same variable and performs pixel-wise summary statistics on the values.

Usage is as follows.

.. code-block:: console

    Usage: wsim_integrate (--stat=<stat>)... (--input=<input>)... (--output=<output>) [--attr=<attr>...]

Arguments are defined as follows:

* ``stat`` : One or more of the following summary statistics: ``ave``, ``max``, ``min``, ``sum``
* ``input`` : One or more input variable definitions
* ``output`` : Output netCDF file to write integrated results to
* ``attr`` : Optional attribute(s) to be attached to output netCDF
    



