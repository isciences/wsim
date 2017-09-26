Running the Land Surface Model (wsim_lsm)
*****************************************

The ``wsim.lsm`` utility runs one ore more iterations of the WSIM Land Surface Model.

Usage is as follows:

.. code-block:: console

    wsim_lsm --state <file> \
        [--forcing <file>]... \
         --flowdir <file> \
         --wc <file> \
         --elevation <file> \
         --results <file> \
         --next_state <file>

* ``--state`` is a netCDF file representing the input state of the model.  It must provide four variables:

  * ``Dr`` amount of detained runoff in millimeters
  * ``Ds`` amount of detained snowmelt in millimeters
  * ``Snowpack`` snowpack water equivalent in millimeters
  * ``Ws`` soil moisture in millimeters
  * ``snowmelt_month``` the number of consecutive months of melting conditions

  In addition, the state file must define a global attribute ``yearmon`` that specifies a year and month YYYYMM format.  The state file will be considered to represent conditions at the start of this month.


* ``--forcing`` specifies one or more netCDF files of forcing data to be used, with each file providing data for a single model iteration. Multiple ``--forcing`` arguments may be provided, and each argument may refer to a single file or a glob of multiple files.  Forcing data will be applied in a character-sort order based on the file names of the inputs, not the order in which they are specified.  Each forcing file must contain the following variables:

  * ``T`` the average monthly temperature in degrees Celsius
  * ``Pr`` the total monthly precipitation (rainfall and snowfall) in millimeters
  * ``pWetDays`` the fraction of days during which precipitation falls
  * ``daylength`` the average day length, as a fraction of a 24-hour period

* ``--wc`` a file providing the soil moisture holding capacity in millimeters
* ``--elevation`` a file providing land surface elevation in meters
* ``--flowdir`` a file providing a surface flow direction matrix (TODO link to specification of format)

The following arguments define model outputs:

* ``--results`` a netCDF file to which model results will be written.  If the filename contains the the pattern ``%T``, results from all model iteration will be written to disk as separate files, with the filename formed by substituting the timestep year-month for ``%T``.  If the ``%T`` pattern is not present in the filename, only the results of the final iteration will be written to disk.

* ``--next_state`` a netCDF file to which a model state will be written, suitable for use in a subsequent model iteration.  Substitution of ``%T`` is performed in the same manner as for the ``--results`` argument.
