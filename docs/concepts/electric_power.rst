Electric Power Assessment
#########################

The WSIM electric power assessment estimates the risk of hydroelectric generation loss due to hydrologic anomalies.

Losses are calculated for hydroelectric power plants and then aggregated to provinces, countries, and hydrologic basins for reporting.

Power Plant Data
^^^^^^^^^^^^^^^^

The electric power assessment requires a database of power plants with the following information:

* Plant location
* Fuel type
* Generation capacity
* Actual generation (where absent, this can be estimated from default factors per fuel type.)

Power plant locations, fuel types, and capacities are available from the open-source `Global Power Plant Database <https://github.com/wri/global-power-plant-database>`_ (GPPD). In some cases, estimated generation is also available in GPPD.

Calculating Hydrologic Anomalies
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Hydrologic anomalies for the electric power assessment are evaluated at the level of hydrologic basins rather than map pixels.
Total blue water is used as the indicator of water quantity in each basin.
Runoff for each basin is computed from the pixel-based land surface model outputs using `exactextract <https://github.com/isciences/exactextract>`_, which considers the portion of each pixel that covers a basin.
Total blue water is calculated for each basin by accumulating each basin's runoff into the downstream basin to which it is linked by an ID reference.
Total blue water values are time-integrated by summing total blue water over time-integration periods of 12, 24, and 36 months.
A statistical distribution is fit for each basin and time-integration period, which is then be used to estimate the median flow associated with an integration period.

The availability of storage reservoirs in a basin impacts the time scale over which hydrologic anomalies have an effect.
In basins with little storage capacity, electric power generation may be affected by month-to-month changes in hydrologic conditions.
In basins with significant storage capacity, the impact of short-term water deficits may be reduced by releasing stored water, and long-term water deficits may impact generation even after they have ended, while reservoir storage is replenished.
In these basins, the effect of storage is taken into account by the use of a longer time-integration period for hydrologic anomaly calculation.

To account for the effect of upstream storage, a time-integration period for each basin is selected to correspond to the number of months of typical flow that can be stored in reservoirs.
Cumulative upstream storage capacity is computed for each basin using the Global Reservoir and Dam (GRanD) database :cite:`Lehner:2011`.
Not all reservoirs provide storage that is available to downstream electric power generation, so reservoirs used for irrigation, flood control, and water supply are excluded from the upstream storage calculation unless they are explicitly coded as used for electric power generation.

Cumulative upstream storage is calculated for each basin as the capacity of all available reservoirs in any upstream basin, plus the capacity of any available reservoirs in the basin of interest.
This storage volume is converted to months of storage by dividing the total storage capacity by the median annual total blue water sum and multiplying by 12.
A basin's cumulative upstream storage capacity determines the time period over which total blue water is evaluated when computing return periods within that basin, as shown in the table below.

+--------------------------------+-----------------+------------------+---------------+
|Months of Storage Available     | :math:`[0, 24)` | :math:`[24, 36)` | :math:`[36, )`| 
+--------------------------------+-----------------+------------------+---------------+
|Time integration period (months)|               12|                24|             36|
+--------------------------------+-----------------+------------------+---------------+

Calculating Hydropower Losses
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Hydropower loss is estimated over a 12-month period using a regression on total
blue water (:math:`\mathrm{Bt}`) expressed as a proportion of the median total
blue water sum for the period ending in the current month:

.. math::

   \mathrm{loss} = -0.0134 - 0.282 \mathrm{ln} \left( \frac{\mathrm{Bt}}{\mathrm{Bt}_{median}} \right)

This regression is based on a fit of generation data in the United States from
2000 to 2017, obtained using the ``eia923`` R package.

This curve is illustrated in :numref:`hydropower_loss_function` below:

.. figure:: /_generated/hydropower_loss_risk.svg
   :name: hydropower_loss_function
   :align: center

   Hydropower loss function.


Spatial Aggregation
^^^^^^^^^^^^^^^^^^^

The coordinates of each power plant are used to assign it to a hydrologic basin, province, and country.

The electric power assessment then computes the following summary statistics for each basin, province, and country:

* Gross loss in megawatt-hours, and percentage of total generation.
* Hydroelectric plant loss in megawatt-hours, and as a percentage of total hydroelectric generation.
