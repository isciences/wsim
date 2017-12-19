WSIM Data Sets
==============

This section provides some examples of parameter and forcing datasets that are suitable for use with WSIM.

GHCN+CAMS Temperature and PREC/L Precipitation Data
---------------------------------------------------

The GHCN+CAMS and PREC/L datasets provide monthly average temperature and precipitation data from 1948-present on a global half-degree grid.
Because of the long historical record, these datasets are well-suited for defining historical distributions of water surplus and deficit conditions.

These datasets are available in netCDF format from NOAA at the following links: 

* `GHCN+CAMS <https://www.esrl.noaa.gov/psd/data/gridded/data.ghcncams.html>`_
* `PREC/L <https://www.esrl.noaa.gov/psd/data/gridded/data.precl.html>`_

Both of these datasets are masked to cover land only.
In some cases, the mask may remove cells that would be considered as "land" in other datasets.
An alternate version of these datasets, produced with a smaller ocean mask, is available from the CPC `Global Monthly Leaky Bucket Soil Moisture Analysis <http://www.cpc.ncep.noaa.gov/soilmst/leaky_glb.htm>`_.
This version of the files is available `by FTP <ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/>`_ in a raw binary format. (The ``p.long`` file contains precipitation data, and ``t.long`` contains temperature data.)
In addition, incremental files are published containing each month's data.
Data can be extracted from these files using the ``read_binary_grid.R`` utility script included with WSIM.

Example commands to download and extract these datasets are shown below.

.. code-block:: console

    # Fetch historical precipitation data
    wget ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/p.long

    # Fetch historical temperature data
    wget ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/t.long

    # Extract temperature and precipitation to individual netCDF files
    mkdir extracted
    utils/read_binary_grid.R --input p.long --var P --output_path extracted
    utils/read_binary_grid.R --input t.long --var T --output_path extracted

NOAA/CPC Unified Gauge-Based Analysis of Global Daily Precipitation
-------------------------------------------------------------------

The NOAA/CPC Unified Gauge-Based Analysis of Global Daily Precipitation dataset provides reports of daily precipitation from January 1979-present on a global half-degree grid.
It can be used to compute the number of wet days per month from January 1979-present.

The data is available `by FTP <ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/>`_, with an individual file for each day. Files are stored in a raw binary format which can be read directly with the ``wsim.io`` R package.

