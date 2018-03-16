Quick Start
===========

This page provides instructions for running WSIM using an example configuration stored in the source repository.

.. note::

  The instructions assume that WSIM will be run through `Docker <https://www.docker.com>`_, and that Docker is already installed.
  
The configuration operates globally at half-degree resolution and is based on use of the following datasets:

* :ref:`GHCN/CAMS <data-ncep>` observed temperatures
* :ref:`PREC/L <data-ncep>` observed precipitation
* :ref:`CFSv2 <data-cfs>` forecast temperature and precipitation
* :ref:`ISRIC <data-isric-wise>` 30-second soil properties
* :ref:`GMTED2010 <data-gmted>` global elevations
* :ref:`STN-30 <data-stn30>` flow direction

To begin, two directories should be created to store WSIM data:

* a ``source`` directory, in which WSIM will store raw and processed input data files; and
* a ``runs`` directory, in which WSIM will create a :ref:`data workspace <data-workspace>` for the model configuration.

In this example, the ``source`` directory is ``~/wsim/source`` and the ``runs`` directory is ``~/wsim/runs``.

Once these directories have been created, a Makefile can be generated with instructions to fetch and preprocess source data, spin-up the land surface model, and produce composite indices of water surplus and deficit.
The Makefile encapsulates a complex process, requiring about 25,000 steps to spin up a model and produce composite indices.
About 75% of these steps occur as part of the model spinup process, and only need to be executed the first time WSIM is run.

The command below requests a Makefile based on the ``workflow/config_cfs.py`` config file for the ``201801`` (January 2018) model iteration.

.. code-block:: bash

  docker run \
    -it \
    --rm \
    -v /home/dbaston/wsim:/opt/wsim_data:rw \
    isciences/wsim:latest \
    workflow/makemake.py \
      --config workflow/config_cfs.py \
      --source /opt/wsim_data/source \
      --workspace /opt/wsim_data/runs/quickstart \
      --start 201801

.. note::

  The steps for model iterations up to January 2017 are automatically included in the file as part of the spinup process.
  If we try to run ``201802`` or a later step, WSIM will fail because we have to run ``201801`` first.

Then, the following command can be run to generate composite indices from the Makefile. Note the use of the ``-j8`` flag, instructing Make to run up to 8 processes in parallel.

.. code-block:: bash

  docker run \
    -it \
    --rm \
    -v /home/dbaston/wsim:/opt/wsim_data:rw \
    --workdir /opt/wsim_data/runs/quickstart \
    isciences/wsim:latest \
    make \
      -j8 \
      all_composites

.. warning::

  Running the spin-up process will cause several gigabytes of data to be downloaded and will occupy a multi-core processor for several hours.

After running, a series of netCDF files with composite indices will be present in ``~/wsim/runs/quickstart/composite``.
Some examples are below:

* ``composite_1mo_201801.nc`` contains composite indices calculated from observed data for January 2018.
* ``composite_12mo_201801.nc`` contains composite indices calculated from observed data for the 12-month period ending in January 2018.
* ``composite_12mo_201801_trgt201810.nc`` contains forecast composite indices for the 12-month period ending in October 2018, calculated using observed data from November 2017 to January 2018, and predictions of a 28-member forecast ensemble from February 2018 to October 2018.

Each netCDF file contains variables with the composite surplus/deficit values, and variables indicating which input indicator (runoff, soil moisture, etc.) was primarily responsible for the surplus/deficit.

Data in these files can be viewed with a netCDF viewer such as `Panoply <https://www.giss.nasa.gov/tools/panoply/>`_ or a general-purpose GIS such as `QGIS <https://www.qgis.org/>`_.

Another option is to use `GeoServer <http://geoserver.org/>`_ which can read a directory of netCDF files and publish it as a `Web Map Service <http://www.opengeospatial.org/standards/wms>`_.

The ``isciences/wsim_geoserver`` Docker container contains a GeoServer installation and script that can be used to serve data output from WSIM.
The following command can be used to start the GeoServer container:

.. code-block:: bash

  docker run \
    -d \
    --name wsim_geoserver \
    --publish 8080:8080 \
    --log-driver json-file \
    --log-opt max-size=100m \
    -v /mnt/fig_rw/WSIM_DEV/runs:/opt/wsim_data:ro \
    isciences/wsim_geoserver:latest

Once the GeoServer container is up and running, we can run a script from within the container to configure layers from the ``quickstart`` workspace:

.. code-block:: bash

  docker exec \
    -it \
    wsim_geoserver \
    configure_geoserver.py \
      quickstart init


Once the configuration script has run, you can open a web browser and request a hotspot for a given model iteration, forecast target date, and time integration window:

.. code-block:: bash

  http://localhost:8080/geoserver/quickstart/wms?service=WMS&version=1.1.0&request=GetMap&srs=EPSG%3A4326&format=image%2Fpng&width=884&height=442&layers=quickstart%3Awsim_hotspot_forecast%2Cnatural_earth_mask%2Cne_110m_admin_0_countries&bbox=-180%2C-90%2C180%2C90&time=2018-01-01&dim_window=1&env=months%3A1&dim_target=2018-05-01


