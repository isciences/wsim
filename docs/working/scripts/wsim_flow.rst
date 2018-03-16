Running the flow accumulator (``wsim_flow``)
============================================

The ``wsim_flow`` utility runs the :ref:`flow accumulator <flow_accumulation>` independently of the :doc:`WSIM land surface model <../../concepts/lsm>`.
This is useful when computing :doc:`composite indices <../../concepts/composite_indices>` from the output of other land surface models.

Usage is as follows:

.. code-block:: console

    wsim_flow --input=<file> --flowdir=<file> --varname=<varname> --output=<file> [--wrapx --wrapy]

where

* ``--input`` is a variable definition for the values to be accumulated (e.g., ``results.nc::RO``)
* ``--flowdir`` is a variable definition for the flow direction matrix
* ``--varname`` specifies the name of the output variable (e.g., ``Bt_RO``)
* ``--output`` specifies the name of the output file
* ``--wrapx`` indicates that flow should be wrapped in the x dimension
* ``--wrapy`` indicates that flow should be wrapped in the y dimension
