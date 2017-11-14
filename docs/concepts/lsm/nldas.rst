Using NLDAS Data
****************


Land surface elevation data for the NLDAS grid can be downloaded from NASA https://ldas.gsfc.nasa.gov/nldas/NLDASelevation.php

https://ldas.gsfc.nasa.gov/nldas/asc/gtopomean15k.asc

Soil parameters from the Noah model can be downloaded from

https://ldas.gsfc.nasa.gov/nldas/asc/NLDAS_Noah_soilparms.asc

Soil porosity can be extracted from the ``.asc`` file using ``awk``.

.. code-block:: console

    awk '{ print $3 " " $4 " " $5 }' /mnt/fig/Data_Global/NLDAS/NLDAS_Noah_soilparms.asc > out.asc



Using GLDAS Data
****************

Just need to run flow accumulator, grid at http://files.ntsg.umt.edu/data/DRT/upscaled_global_hydrography/by_HydroSHEDS_Hydro1k/flow_direction/DRT_qd_FDR_globe.asc

The extent of the flow direction grid is somewhat smaller than GLDAS. While GLDAS extends from -60 S to the North Pole, the DRT grid extends only from 56 S to 84 N

We need to extend the DRT grid to the GLDAS grid, filling the added areas with NODATA values

.. code-block:: console
    
    /usr/local/bin/gdalwarp -overwrite -of HFA -te -180 -60 180 90 DRT_qd_FDR_globe.asc flowdirs.img


