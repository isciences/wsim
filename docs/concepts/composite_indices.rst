Composite Indices
*****************

A useful means of reporting WSIM results is the global “hot spot” map (as shown :ref:`here <example-global-hotspot>`) that identifies regions of the globe experiencing anomalous water surplus or deficit.
Areas of overall water deficit are shown in shades of red, and areas of overall water surplus are shown in shades of blue.
Shades of purple are used to indicate regions experiencing both surplus and deficit, either simultaneously or in quick succession.
(An example of this is when low precipitation has resulted in dry soils but rapid upstream snow melt has caused river flows to be high.)

The overall values of water surplus and deficit plotted on the hot spot maps are provided by the Composite Surplus Index and the Composite Deficit Index, which summarize multiple surplus and deficit indicators.
The selection of indicators used in constructing these composite indices can be controlled by the user.
To depict the aggregate effect of water surpluses and deficits on a variety of water uses, ISciences computes the composite indices as follows:

- The *Composite Surplus Index* is calculated as the greatest return period of runoff and total blue water.
- The *Composite Deficit Index* is calculated as the "worst" return period of three underlying indicators: low soil moisture, high PETmE (potential minus actual evapotranspiration), and low total blue water.
  In other words, it is taken to be the greatest magnitude of the three underlying indicators, considering negative return periods of soil moisture and total blue water, and positive return periods of PETmE.

To help assess sequencing effects, such as the degree to which a hot spot represents a long-term persistent anomaly or a shorter-term extreme, these composite indices can be produced for a variety of time periods (e.g., 12-month, 3-year).
To evaluate time periods greater than one month, statistics are calculated (sum, average, minimum, and/or maximum) for each of the components of the composite index (e.g., soil moisture, total blue water, etc.) as measured in scientific units over the time period.
Multi-month composite indices are calculated based on the return period of these statistics.

Adjusted Composite Indicies
^^^^^^^^^^^^^^^^^^^^^^^^^^^

The composite indices described above are simple to calculate and provide a quick means to compare relative water stress between regions and throughout time.
While they are useful for relative comparison of stresses and surpluses, the absolute values of the indices can be difficult to interpret.
Because the composite indices are calculated as the maximum (or minimum) or several return periods, the value of composite index itself cannot be easily interpreted as a return period.
(The return period of a 30-year composite surplus is expected to be less than 30 years.)

WSIM can also compute adjusted composite indices for applications where the return period of the composite index itself is important.
These adjusted composites are calculated according to the following procedure:

1. Compute composite surplus and deficit indices (as standardized anomalies) for the reference historical period (e.g., 1950-2009).
2. Fit a distribution of historical composite surplus values, and a distribution of historical composite deficit values.
3. Compute composite surplus and deficit (as standardized anomalies) for the observed or forecast period of interest.
4. Compute the return period of the composite surplus and deficit anomalies from Step 3, given the distributions from Step 2.

Worked Example
^^^^^^^^^^^^^^

This section presents a worked example from a single pixel in Chittenden County, Vermont, which experienced a drought in fall 2016.
A composite deficit index will be developed using soil moisture, PETmE, and total blue water as inputs.
The table below shows modeled values for the these three parameters, as well as the parameters that define their generalized extreme value distribution.

.. csv-table::
   :header: "Parameter","Modeled Value","GEV Location","GEV Scale","GEV Shape"

   "Soil Moisture (3-month average, mm)", 110.6,    131.2,    29.3,      0.764
   "PETmE (3-month sum, mm)",             4.875,    0.5859,   0.9393,   -0.591
   "Total Blue Water (3-month sum, mm)",  8.99e+07, 3.69e+08, 2.00e+08, -0.0616

Using the `cumulative distribution function for the GEV distribution <https://en.wikipedia.org/wiki/Generalized_extreme_value_distribution#Specification>`_, these modeled values can be expressed in terms of cumulative probabilities:

.. figure:: /_generated/composite_example_cdfs.svg
   :align: center

These cumulative probabilities can also be expressed as standardized anomalies and return periods, following the methods described :doc:`previously </concepts/anomaly_calculations>`:

.. csv-table::
   :header: "Parameter","Modeled Value", "Cum. Prob.","Std. Anomaly","Return Period"

   "Soil Moisture (3-month average, mm)", 110.6,    0.173,  :math:`Q_{\textrm{norm}}\left( 0.173 \right) = -0.943`, :math:`-1/.173=-5.8`
   "PETmE (3-month sum, mm)",             4.875,    0.894,  :math:`Q_{\textrm{norm}}\left( 0.894 \right) = 1.26`,   :math:`1/(1-0.894)=9.43`
   "Total Blue Water (3-month sum, mm)",  8.99e+07, 0.0135, :math:`Q_{\textrm{norm}}\left( 0.0135 \right)= -2.21`,  :math:`-1/.0135=-74.1`

Considering that deficit is characterized by low soil moisture, low blue water, and high potential-actual evapotranspiration, the composite deficit can be calculated as:

.. math::

   \textrm{min}\left(W_s,Bt_{RO},-PETmE\right)

In this case, the composite deficit is governed by total blue water with a return period of -74.1 years (i.e., the 3-month blue water sum is expected to be this low only once every 74 years).
In practice, the composite deficit index may be clamped to a lower magnitude (-60) to avoid extrapolation beyond the length of the historical reference period (1950-2009).

How often would we expect to have a composite deficit of this magnitude?
To find out, we can consult the historical distribution of composite deficits.
This distribution was estimated by computing the composite deficit for every month from January 1950 to December 2009.
For this pixel, the composite deficit parameters are as follows:

.. csv-table::
   :header: "Parameter","Modeled Value","GEV Location","GEV Scale","GEV Shape"

   "Composite Deficit Anomaly",-2.21,-0.7565543,0.9031551,0.2727567 

From the cumulative distribution function, we can see that a deficit of this magnitude is expected to occur about once every 45 years:

.. figure:: /_generated/composite_example_adjusted_cdf.svg
   :align: center

.. csv-table::
   :header: "Parameter","Modeled Value","Cumulative Probability","Return Period"

   "Composite Deficit Anomaly",-2.21,0.022,:math:`-1/0.022 = -45.45`

.. _adjusted-composites:

