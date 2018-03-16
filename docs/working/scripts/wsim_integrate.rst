Summarizing data (``wsim_integrate``)
*************************************

The ``wsim_integrate`` utility integrates, or accumulates multiple observations of the same variable and performs pixel-wise summary statistics on the values.

Usage is as follows.

.. code-block:: console

    Usage: wsim_integrate (--stat=<stat>)... (--input=<input>)... (--output=<output>) [--attr=<attr>...]

Arguments are defined as follows:

* ``stat`` : One or more of the following summary statistics: ``ave``, ``max``, ``min``, ``sum``. By default, the statistic will be computed for all input variables. A limited list of variables can be specified using the following notation: ``--stat ave::T,Pr``.
* ``input`` : One or more input variable definitions
* ``output`` : Output netCDF file(s) to write integrated results to
* ``attr`` : Optional attribute(s) to be attached to output netCDF
* ``window`` : Size of rolling window (see below)
* ``--keepvarnames`` : If specified, prevents ``wsim_integrate`` from appending the statistic computed to the name of the output variables. If this option is selected, only one stat can be computed per input variable.
    
As an example, the following command is used to compute statistics of return periods for a single variable, estimated from 28 forecast ensemble members:

.. code-block:: console

 ./wsim_integrate.R \
    --input "ensemble/*trgt201703*.img::1->Bt_RO_Sum" \
    --stat min \
    --stat max \
    --stat ave \
    --stat q25 \
    --stat q50 \
    --stat q75 \
    --output /tmp/Bt_RO_Sum_24mo_fcst201612_trgt201703.nc

The command below shows an example of creating monthly climatology using wet day data from 1980-2009:

.. code-block:: console

 for month in {01..12} ; do 
   outfile="source/NCEP/wetdays_ltmean/wetdays_ltmean_month_${month}.nc"
   ./wsim_integrate.R \
      --stat ave \
      --input "source/NCEP/wetdays/wetdays_[1980${month}:2009${month}:12].nc" \
      --output $outfile
   ncrename -O "-vpWetDays_ave,pWetDays" $outfile
 done

Rolling Windows
^^^^^^^^^^^^^^^

``wsim_integrate`` can be used to efficiently compute statistics over a rolling time window by specifying multiple input files, multiple output files, and a rolling window size.
For example, the following command computes statistics with a 6-month rolling window from 1950 to 2009:

.. code-block:: console

  ./wsim_integrate.R \
    --stat max::Bt_RO \
    --stat sum::Bt_RO,E,PETmE,RO_mm,P_net \
    --stat ave::Ws \
    --stat min::Bt_RO \
    --input "/mnt/wsim/runs/mar07/results/results_1mo_[195001:200912:1].nc::Bt_RO,E,Ws,PETmE,RO_mm,P_net" \
    --attr integration_period=6 \
    --window 6 \
    --output "/mnt/wsim/runs/mar07/results_integrated/results_6mo_[195006:200912:1].nc" 


Note the use of :ref:`date range expansion <date-range-expansion>` and the differing number of files specified for ``--input`` and ``--output``.
If the number of output files specified is inconsistent with the rolling window size, ``wsim_integrate`` will raise and error and exit.
