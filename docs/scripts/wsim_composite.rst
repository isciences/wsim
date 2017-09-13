wsim_composite
**************

The ``wsim_composite`` utility computes composite indicators (TODO add link explaining what these are) from multiple surplus and deficit input variables.

The composite indicators are output to a netCDF file with the following variables:


``surplus``
    the worst (most positive) return period of all input surplus variables
``surplus_cause``
    a coded variable indicating which of the surplus variables was responsible for the composite surplus indicator value
``deficit``
    the worst (most negative) return period of all input deficit variables
``deficit_cause``
    a coded variable indicating which of the deficit variables was responsible for the composite deficit indicator value
``both``
    the greater magnitude of ``surplus`` and ``deficit``, whenever both of these indicators have a magnitude higher than a specified threshold

Usage is as follows:

.. code-block:: console

    Usage: wsim_composite \
        (--surplus=<file>)... \
        (--deficit=<file>)... \
        --both_threshold=<value> \
        [--mask=<file>] \
        --output=<file>

The ``--surplus`` and ``--deficit`` arguments are used to specify variables that should be considered in computing the composite surplus and deficit indicators. each argument may refer to more than one variable, and each argument may be provided multiple times. The WSIM variable definition notation (TODO link) is fully supported.  
The ``--both_threshold`` argument specifies the minimum magnitude of the composite surplus and deficit indicators for a pixel to be considered to simultaneously experience surplus and deficit.

The ``--mask`` allows an optional mask to be defined, so that all composite indicators have the same maximum extent.

As a more complete example, the following command was is used to produce the WSIM composite indicators for January 2017 from multiple raster inputs:

.. code-block:: console

    ./wsim_composite.R \
      --deficit "~/freq/PETmE_freq_trgt201701.img::1@fill0@negate->Neg_PETmE" \
      --deficit "~/freq/Ws_freq_trgt201701.img::1->Ws" \
      --deficit "~/freq/Bt_RO_freq_trgt201701.img::1->Bt_RO" \
      --surplus "~/freq/Bt_RO_freq_trgt201701.img::1->Bt_RO" \
      --surplus "~/freq/RO_mm_freq_trgt201701.img::1->RO_mm" \
      --mask "~/freq/Ws_freq_trgt201701.img"
      --both_threshold 3 \
      --output "/tmp/composite_201701.nc"
..

 A few points are worth noting in this example:

 * The ``Bt_RO`` variable is considered in computation of both the surplus and deficit indicators
 * The ``PETmE`` variable is transformed by filling NODATA values with zero, and then negating all values.
 * The ``Ws`` variable was used as a mask for the composite indicators. If this were not done, the composite
   deficit would be populated in all pixels, because of the transformation done to ``PETmE``.

