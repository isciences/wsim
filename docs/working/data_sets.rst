Data Sets
*********

This section provides some examples of parameter and forcing datasets that are suitable for use with WSIM.

Forcing Datasets
================

CFSv2 Temperature and Precipitation Forecasts
---------------------------------------------

NOAA's CFSv2 model provides global forecasts of monthly average temperature and precipitation with lead times of 1-9 months.
Forecasts are issued every six hours.

Forecast data issued over the past seven days is available in a `rolling archive <http://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/>`_.
A `long-term archive <https://nomads.ncdc.noaa.gov/modeldata/cfsv2_forecast_mm_9mon/>`_ stores earlier forecasts, from April 2011 onward.

CFSv2 forecast data is provided on a 384x190 Gaussian grid.  
WSIM provides scripts to download forecast files from NOAA's archives and extract temperature and precipitation from the Gaussian-grid GRIB files into netCDF files on a half-degree Cartesian grid.

The ``download_cfsv2_forecast.py`` script downloads a forecast GRIB file given a timestamp and target month, sourcing the file from the appropriate NOAA archive:

.. code-block:: console

  utils/noaa_cfsv2_forecast/download_cfsv2_forecast.py \
     --timestamp 2018010906 \
     --target 201806 \
     --output_dir /tmp/forecasts

The ``convert_cfsv2.sh`` script can then be used to convert the GRIB file into netCDF:

.. code-block:: console

  utils/noaa_cfsv2_forecast/convert_cfsv2_forecast.sh \
     /tmp/forecasts/flxf.01.2018010906.201806.avrg.grib.grb2
     /tmp/forecasts/fcst2018010906_trgt201806.nc

The ``wsim_correct`` tool can then be used to bias-correct these forecasts based on retrospective forecast data.
A detailed discussion of forecast bias correction is provided :doc:`here </concepts/forecast_bias_correction>`.

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

NLDAS-2 Primary Forcing Dataset
-------------------------------

The NLDAS Phase 2 Primary Forcing dataset provides, among other variables, monthly average temperature and precipitation from 1979-present on the 0.125-degree NLDAS grid.
Data is available in GRIB format `from NASA <https://disc.sci.gsfc.nasa.gov/datasets/NLDAS_FORA0125_M_V002/summary?keywords=NLDAS>`_.

Wet days are not included in the monthly average files.
This parameter can be computed by summarizing the version of the NLDAS-2 forcing dataset `at 1-hour resolution <https://disc.sci.gsfc.nasa.gov/datasets/NLDAS_FORA0125_H_V002/summary?keywords=NLDAS>`_.


Parameter Datasets
==================

Simulated Topological Network Flow Directions
---------------------------------------------

A global flow direction grid at 0.5-degree resolution is available from the `Simulated Topological Networks (STN-30p) project <http://www.wsag.unh.edu/Stn-30/stn-30.html>`_.

Global Flow Directions derived from Dominant River Tracing (DRT)
----------------------------------------------------------------

The Numerical Terradynamic Simulation Group at the University of Montana publishes near-global flow direction grids (84 degrees North to 56 degrees South) at various resolutions, derived using a dominant river tracing (DRT) algorithm. Data can be accessed from `this link <http://www.ntsg.umt.edu/project/drt.php>`_.

Global Multi-resolution Terrain Elevation Data 2010 (GMTED2010)
---------------------------------------------------------------

The GMTED2010 dataset, developed by the USGS and NGA, provides global or near-global elevation data based on a compilation of 11 raster-based elevation datasets.
The data is offered at three resolutions, with varying coverages:

* 30 arc-seconds, from 84 degrees north to 90 degrees south
* 15 arc-seconds, from 84 degrees north to 56 degrees south
* 7.5 arc-seconds, from 84 degrees north to 56 degrees south

Data can be download in Arc/Info binary grid format from `this link <https://topotools.cr.usgs.gov/GMTED_viewer/gmted2010_global_grids.php>`_.

ISRIC WISE-Derived Soil Properties
----------------------------------

A database of soil properties, including total available water capacity (TAWC), is available at 30 arc-second resolution from `ISRIC <http://data.isric.org/geonetwork/srv/eng/catalog.search;jsessionid=A84EFD2FD6E854EE80FC5268239F134D#/metadata/dc7b283a-8f19-45e1-aaed-e9bd515119bc>`_.
The dataset covers all longitudes from approximately 60 degrees south to 83 degrees north.
It is published as a single raster file, with 16-bit integer values corresponding to a soil map unit identifier.
An accompanying data file provides, for each map unit, the relative proportions of multiple soil types (and the properties of those soil types) found over discrete depth intervals.

WSIM provides a utility (``extract_isric_tawc.R``) to extract TAWC values from this dataset, using a weighted average of the soil types present within each depth interval, up to a specified maximum depth.

Once extracted, the TAWC raster can be downsampled to the desired resolution.
For example, a global raster of TAWC at 0.5-degree resolution can be produced using GDAL with the following command:

.. code-block:: console

    gdal_translate -of GTiff -r average -tr 0.5 0.5 -projwin -180 90 180 -90 wise_30sec_v1_tawc.tif wise_half_degree_tawc.tif

However, this method causes a propagation of NODATA values, because 0.5-degree cells that are partly covered by NODATA pixels may become NODATA in the downsampled version.
An alternative is to use the ``aggregate`` function provided by R's ``raster`` package.
The following code sample demonstrates the use of this approach to extract TAWC values on a half-degree global grid.

.. code-block:: R

   require(raster)

   # Write a half-degree global grid
   halfdeg <- aggregate(raster('wise_30sec_v1_tawc.tif'), fact=60, fun=mean, na.rm=TRUE)
   
   # Although the raster created by the aggregate function is at half-degree 
   # resolution, its latitude extents do not line up to half-degree parallels. 
   # So we use the resample function (with the nearest-neighbor method, to prevent
   # smoothing) to shift the grid.
   halfdeg_global <- resample(halfdeg, raster(xmn=-180, xmx=180, ymn=-90, ymx=90, nrow=360, ncol=720), method='ngb')
   writeRaster(halfdeg_global, 'wise_half_degree_tawc.tif', 'GTiff')  

As an additional example, the following code extracts TAWC values on the NLDAS grid:

.. code-block:: R

   require(raster)

   # Write a 0.125-degree NLDAS grid
   eigth_degree <- aggregate(raster('wise_30sec_v1_tawc.tif'), fact=15, fun=mean, na.rm=TRUE)

   # Since the generated grid already lines up to eigth-degree parallels, we
   # can use the crop function to limit its extent to the NLDAS domain.
   nldas <- crop(eigth_degree, c(-125, -67, 25, 53))
   writeRaster(nldas, 'wise_nldas_tawc.tif', 'GTiff')


