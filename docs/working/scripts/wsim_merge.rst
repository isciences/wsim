Combining variables into a netCDF (``wsim_merge``)
**************************************************

The ``wsim_merge`` utility provides a simple way to combine variables from multiple files into a single netCDF.

Variables are combined by calling ``wsim_merge`` with one or more ``--input`` arguments, each of which may import multiple variables,
and an ``--output`` argument specifying where the combined file should be saved.

Attributes can be added to the resulting netCDF by specifying one or more ``--attr`` arguments.
If an attribute is specified without a value (for example, ``--attr="temperature:units"`` instead of ``--attr="temperature:units=degree_C``", then the value will be copied from the source file.)

