Electric Power Assessment
#########################

The WSIM electric power assessment estimates the risk of electrical generation loss due to hydrologic and temperature anomalies.

The following types of losses are considered by WSIM:

- hydroelectric generation losses due to low flow
- thermoelectric generation losses due to 

  - insufficient water for cooling
  - high water temperature
  - low air temperature
  - high air temperature

Losses are calculated for individual power plants and then aggregated to provinces, countries, and hydrologic basins for reporting.

Power Plant Data
^^^^^^^^^^^^^^^^

The electric power assessment requires a database of power plants with the following information:

* Plant location
* Fuel type
* Generation capacity
* Actual generation (where absent, this can be estimated from default factors per fuel type.)
* Cooling type. In particular, the electric power assessment must know whether a given thermoelectic plant is water-cooled, whether the source of that water is seawater is freshwater, and whether a once-through cooling system is used.

Power plant locations, fuel types, and capacities are available from the open-source `Global Power Plant Database <https://github.com/wri/global-power-plant-database>`_ (GPPD). In some cases, estimated generation is also avilable in GPPD.
Cooling type and generation information can be appended to GPPD by linking against the commercial World Electric Power Plant database.
When this information is not available, WSIM makes the following assumptions:

* A plant is water-cooled if its declared fuel type is biomass, cogeneration, coal, nuclear, or waste.
* A plant uses seawater as the source of its cooling if it is within 3 km of the ocean.
* A plant uses once-through cooling if is is located within 1 km of a plant having the same fuel type in a dataset of once-through cooled plants provided by Raptis and Pfister :cite:`Raptis:2016`.
* Generation can be estimated based on capacity, using average capacity factors per fuel type from the `EW3 database of U.S. Power Plants <https://www.ucsusa.org/clean-energy/energy-water-use/ucs-power-plant-database>`_.


Calculating Hydrologic Anomalies
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Hydrologic anomalies for the electric power assessment are evaluated at the level of hydrologic basins rather than map pixels.
Total blue water is used as the indicator of water quantity in each basin.
Runoff for each basin is computed from the pixel-based land surface model outputs using `exactextract <https://github.com/isciences/exactextract>`_, which considers the portion of each pixel that covers a basin.
Total blue water is calculated for each basin by accumulating each basin's runoff into the downstream basin to which it is linked by an ID reference.
Total blue water values are time-integrated by summing total blue water over time-integration periods of 3, 6, 12, 24, and 36 months.
A statistical distribution is fit for each basin and time-integration period, which can then be used to calculate the :doc:`return period <anomaly_calculations>` associated with an individual total blue water value and integration period.

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

+--------------------------------+----------------+---------------+----------------+------------------+------------------+---------------+
|Months of Storage Available     | :math:`[0, 3)` | :math:`[3,6)` | :math:`[6,12)` | :math:`[12, 24)` | :math:`[24, 36)` | :math:`[36, )`| 
+--------------------------------+----------------+---------------+----------------+------------------+------------------+---------------+
|Time integration period (months)| 1              |             3 |               6|                12|                24|             36|
+--------------------------------+----------------+---------------+----------------+------------------+------------------+---------------+

The generation loss calculations applied to hydroelectric and water-cooled power plants are described below.

Hydroelectric Generation Losses from Hydrologic Anomalies
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Hydropower loss risk is taken to be directly related to total blue water (:math:`\mathrm{Bt}`) expressed as a proportion of the median total blue water sum for the period ending in the current month:

.. math::

   \mathrm{Bt}_{ratio} = \frac{\mathrm{Bt_{observed}}}{\mathrm{Bt}_{median}}

A loss model was developed based on annual hydropower generation data for California from 1983 through 2012 :cite:`California_Energy_Commission:2013`. The form of the model is described by the following equation:

.. math::

   \mathrm{loss} = 1 - \left(\frac{\textrm{Bt}_{observed}}{\textrm{Bt}_{median}}\right)^{H}

A value of :math:`H = 0.6` was determined based on initial applications to global data.
The hydropower loss risk curve is illustrated in :numref:`hydropower_loss_function` below:

.. figure:: /_generated/hydropower_loss_risk.svg
   :name: hydropower_loss_function
   :align: center

   Hydropower loss function.


Water-Cooled Generation Losses from Hydrologic Anomalies
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Water-cooled power plants are designed to handle some degree of hydrologic anomalies.
Intake pipes, for example, are set deep enough in the source body of water so that moderate fluctuations in water level do not expose the intakes and thus reduce the quantity of water that can be extracted.
For example, if seasonal low water typically occurs in the summer, then low water anomalies in January may not be of consequence if flows remain above summer levels.
Because of this expectation of variability, return periods used in estimating losses for water-cooled plants are computed by comparing total blue water to the distribution of annual minimum total blue water, rather than the distribution of total blue water for the month being evaluated:

* For a basin with ≤ 1 month of storage capacity, the total blue water return period for a given month is based on the distribution of annual minimum total blue water.
* For a basin with 3 or 6 months of storage capacity, the return period is based on the distribution of annual minimum 3-month or 6-month sums of total blue water.
* For basins with 12, 24, or 36 months of storage capacity, return periods are based on the distributions of 12-, 24-, and 36-month sums of total blue water for time periods ending in the month of December.

The fraction of generation that is lost is calculated using the following equation:

.. math::

   \mathrm{loss} = A^{\left(\bar{X}-X_c\right)}-1, \ \mathrm{where} \ A = e^{\left(\frac{\ln{101}}{X_{\mathrm{max}}-X_c}\right)}

where :math:`\bar{X}` is the basin-level return period for integrated total blue water, :math:`X_c` is the basin-level period at which loss begins to occur, and :math:`X_{\mathrm{max}}` is the return period associated with complete loss.   

Parameters :math:`X_c` and :math:`X_{\mathrm{max}}` are set for each basin as a function of water stress, defined as the ratio of water withdrawals to total blue water in a given basin.
Water stress is not calculated by WSIM and must be imported from another source such as `Aqueduct <https://www.wri.org/our-work/project/aqueduct>`_.
Higher water stress suggests less resilience to hydrologic anomalies, so the onset of loss occurs sooner.
For example, if normal water use is 98% of the typical blue water level, even small reductions in total blue water will have an impact.
The value of :math:`X_c` is determined by linear interpolation among the values in the table below, as shown in :numref:`onset_graph`.

+------------+--+----+---+---+---+
|Water Stress|0 | 0.1|0.2|0.4|0.8|
+============+==+====+===+===+===+
|:math:`X_c` |30|  25| 20| 15| 10|
+------------+--+----+---+---+---+

.. figure:: /_generated/thermoelectric_loss_onset.svg
   :name: onset_graph
   :align: center

   Return period associated with the onset of loss, as a function of water stress.

The return period associated with total loss :math:`X_{\mathrm{max}}` is taken to be :math:`X_c + 30`. :numref:`water_cooled_loss_graph` shows the output of the loss function for a basin with no water stress (dotted line) and a basin with maximum water stress (solid line).


.. figure:: /_generated/thermoelectric_loss_risk.svg
   :name: water_cooled_loss_graph
   :align: center

   Losses to water-cooled generation as a function of total blue water return period, for a basin with no water stress (dotted line) and a basin with maximum water stress (solid line).


Temperature-based losses
^^^^^^^^^^^^^^^^^^^^^^^^

The electric power assessment includes an estimation of generation losses due to temperature anomalies.
The following factors are considered:

* low air temperatures, which can cause equipment failure or freezing of equipment, piping, and/or fuel stockpiles;
* high air temperatures, which reduce the efficiency of generation and transmission; and
* high water temperatures, under which generation must be reduced to comply with effluent temperature regulations.

The temperature loss function uses three WSIM outputs as inputs:

+--------------+------------------------------------------------------------------------+
|Parameter     |Description                                                             |
+==============+========================================================================+
|:math:`T`     |Air temperature at plant                                                |
+--------------+------------------------------------------------------------------------+
|:math:`T_{rp}`|Air temperature anomaly at plant, expressed as a return period          |
+--------------+------------------------------------------------------------------------+
|:math:`T_{Bt}`|Average air temperature in basin, weighted by total blue water          |
+--------------+------------------------------------------------------------------------+

Due to the lack of globally consistent temporal water temperature data, the mean parameters of a set of linear models by Segura et al. :cite:`Segura:2015` are used to compute water temperature :math:`T_w` from air temperature :math:`T_a`:

.. math::
   T_w = 2.5 + 0.76T_a

Temperature is assumed to equilibrate such that upstream water temperature can be ignored at the monthly time scale used for the electricity assessment.

The temperature loss function depends on several parameters:

+----------------+-----------------------------------------------------------------------------------+------------------------------------------------------+
|Parameter       |Description                                                                        |Value                                                 |
+================+===================================================================================+======================================================+
|:math:`T_c`     |Plant air temperature at which losses begin due to cold air temperature            |-15° C                                                |
+----------------+-----------------------------------------------------------------------------------+------------------------------------------------------+
|:math:`T_{eff}` |Plant air temperature at which efficiency losses begin due to high air temperature |20 °C                                                 |
+----------------+-----------------------------------------------------------------------------------+------------------------------------------------------+
|:math:`eff`     |Efficiency loss per degree C air temperature                                       |0.005/°C (based on summary in :cite:`USDOE:2013`)     |
+----------------+-----------------------------------------------------------------------------------+------------------------------------------------------+
|:math:`T_{reg}` |Regulatory limit water temperature                                                 | 32 °C :cite:`Madden:2013`, :cite:`Raptis:2016`       |
+----------------+-----------------------------------------------------------------------------------+------------------------------------------------------+
|:math:`T_{diff}`|Temperature rise in once-through cooled plant                                      | 8-12 °C  :cite:`Langford:2001` ,                     |
|                |                                                                                   | 11-14 °C :cite:`EPRI:2003`,                          |
|                |                                                                                   | 7°C :cite:`Boogert:2005`                             |
+----------------+-----------------------------------------------------------------------------------+------------------------------------------------------+

The loss function is defined as follows:

.. math::

   \mathrm{loss} = \begin{cases}
   0.03\left(T_c - T\right)                                  & T < T_c \ \mathrm{and} \ T_{rp} < -30 \\
   0.005\left(T - T_{eff}\right)                             & \left(T_{reg}-T_{diff}\right) < T < T_{eff} \\
   \frac{T-\left(T_{reg} - T_{diff}\right)}{T_{reg}-T_{diff}} & T > \left(T_{reg}-T_{diff}\right)
   \end{cases}


Computed temperature-based losses are shown in :numref:`air_temperature_loss_graph` for a hypothetical plant that uses once-through cooling (solid line) and non-once-through cooling (dotted line).

.. figure:: /_generated/air_temperature_loss.svg
   :name: air_temperature_loss_graph
   :align: center

Spatial Aggregation
^^^^^^^^^^^^^^^^^^^

The calculations described above are used to estimate generation losses for each plant in a power plant database.
The coordinates of each power plant are used to assign it to a hydrologic basin, province, and country.
A "reserve capacity" is calculated for each boundary, consisting of unused generation (capacity - actual generation) for plants that are not affected by hydrologic anomalies.

The electric power assessment then computes the following summary statistics for each basin, province, and country:

* Gross loss in megawatt-hours, and percentage of total generation.
* Net loss (gross loss - available reserve generation) in megawatt-hours and as a percentage of total generation.
* Nuclear plant loss in megawatt-hours, and as a percentage of total nuclear generation.
* Hydroelectric plant loss in megawatt-hours, and as a percentage of total hydroelectric generation.
* Reseve capacity utilization (percent).
