Anomaly and Return Period Calculations
**************************************

The central premise of WSIM is that populations structure their activities based on expected availability of water, and that stresses are created when conditions vary behind these historically-derived expectations.
The magnitude of the stress is typically a function of the rarity of the event.
Populations that live in regions with a history of high variability in water supplies generally develop coping mechanisms to adapt (e.g., dams for irrigation and flood control).
However, when a given event is rare, it can overwhelm existing adaptations and has the potential to become an economic and human security concern.
As a result, WSIM transforms all of its water security indicators from scientific units (e.g., millimeters or cubic meters) into return periods expressed in years.
The inverse of the return period is the probability of observing an event greater than or equal to a given magnitude in a given year, so a 5-year event would have a 20% probability of occurring in any given year.

A benefit of using anomalies expressed as return periods is that it only requires the estimates of water security indicators to be accurate relative to one another.
Most surface hydrology models undergo a calibration process based on linear regressions between predicted and observed values.
This process corrects for bias and scaling issues, but not for skewing.
Use of return periods implicitly corrects for bias and scaling, but also skew.
Users should therefore have greater confidence in the return period estimates than in the raw indicator estimates.

WSIM uses a common statistical method to compute anomalies expressed in return periods.

As an example, consider the set of precipitation observations shown below:

.. figure:: /_generated/anomaly_calculations_obs.svg
   :align: center

First, a theoretical distribution is fit to the historical observations.
WSIM supports multiple theoretical distributions, including the generalized extreme value (GEV) distribution, a flexible three-parameter distribution designed for this purpose.
The GEV distribution accounts for the location (modal value), scale (spread), and skew (the difference between the mean and the median) of the historical distributions and appears to perform better than the Pearson Type 3 distribution for this purpose.
Statistical distribution fitting is performed using the method of L-moments as described by Hosking and Wallis :cite:`Hosking:1997` and Hosking :cite:`Hosking:2017`.

.. TODO do we have a citation for GEV performing better than PE3?
.. TODO is "skew" synonymous with "shape" in the paragraph above?

The plot below shows the empirical cumulative probability distribution (black marks) and the fitted theoretical distribution (orange line) for the observed values above.
The theoretical distribution can be used to obtain the probability of observing a value less than or equal to a given observation; this is done by examining where value falls on the cumulative distribution function.
In the example, the probability of observing 77 mm of precipitation is less than 0.85.

.. figure:: /_generated/anomaly_calculations_cdfs.svg
   :align: center

The probability is then converted to an exceedance probability: that of obtaining a value *more extreme* than the observed value (0.15 in the example).
Finally, the return period is calculated at the inverse of the exceedance probability:

.. math::

   \frac{1}{1 - 0.85} = 6.7

Observations can also be expressed as *standard anomalies*: the value on a standard normal distribution having the same cumulative probability as the observed precipitation on its theoretical distribution.
This is computed by applying the standard normal quantile function (inverse cumulative distribution function) to the cumulative probability above:

.. math::

   Q(0.85) = 1.04

Return periods and standard anomalies can be computed using functions in the ``wsim.distributions`` R package, or using the ``wsim_anom`` command-line utility.

