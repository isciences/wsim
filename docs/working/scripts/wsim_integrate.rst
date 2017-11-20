Summarizing data (``wsim_integrate``)
*************************************

The ``wsim_integrate`` utility integrates, or accumulates multiple observations of the same variable and performs pixel-wise summary statistics on the values.

Usage is as follows.

.. code-block:: console

    Usage: wsim_integrate (--stat=<stat>)... (--input=<input>)... (--output=<output>) [--attr=<attr>...]

Arguments are defined as follows:

* ``stat`` : One or more of the following summary statistics: ``ave``, ``max``, ``min``, ``sum``
* ``input`` : One or more input variable definitions
* ``output`` : Output netCDF file to write integrated results to
* ``attr`` : Optional attribute(s) to be attached to output netCDF
    
As an example, the following command is used to compute statistics of return periods for a single variable, estimated from 28 forecast ensemble members:

.. code-block:: console

 ./wsim_integrate.R \
    --input "ensemble/*trgt201703*.img::1->Bt_RO_Sum" \
    --stat min \
    --stat max \
    --stat ave \
    --stat q25 \
    --stat q50 \
    --stat q75 \
    --output /tmp/Bt_RO_Sum_24mo_fcst201612_trgt201703.nc
