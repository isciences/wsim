Combining variables into a netCDF (wsim_merge)
**********************************************

The ``wsim_merge`` utility provides a simple way to combine variables from mutiple files into a single netCDF.

Variables are combined by calling ``wsim_merge`` with one or more ``--input`` arguments, each of which may import multiple variables,
and an ``--output`` argument specifying where the combined file should be saved.

Attributes can be added to the resulting netCDF by specifying one or more ``--attr`` arguments.

