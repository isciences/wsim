Land Surface Model
==================

WSIM includes a Land Surface Model (LSM).  Core functionality of the LSM is implemented in the ``wsim.lsm`` R package.

The LSM is based on a synthesis of two frequently cited soil moisture/runoff models: 
WBM :cite:`Fekete:2010` and “Leaky Bucket” :cite:`Huang:1996,VanDenDool:2003`.

The surface model has two primary components.
The soil moisture/runoff component performs pixel-based calculations to estimate soil moisture and runoff.
The flow accumulation component then sums a number of water-related parameters (including runoff) through the stream network to account for upstream/downstream relationships of water availability and water use.

.. toctree::
    
   water_balance.rst
   flow_accumulation.rst 

.. bibliography:: ../../references.bib
   :style: plain
