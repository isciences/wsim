Anomaly and Return Period Calculations
**************************************

The central premise of WSIM is that populations structure their activities based on expected availability of water, and that stresses are created when conditions vary behind these historically-derived expectations.
The magnitude of the stress is typically a function of the rarity of the event.
Populations that live in regions with a history of high variability in water supplies generally develop coping mechanisms to adapt (e.g., dams for irrigation and flood control).
However, when a given event is rare, it can overwhelm existing adaptations and has the potential to become an economic and human security concern.

To quantify the rarity of an event, WSIM transforms all of its water security indicators from scientific units (e.g., millimeters or cubic meters) into return periods expressed in years.
The inverse of the return period is the probability of observing an event greater than or equal to a given magnitude in a given year, so a 5-year event would have a 20% probability of occurring in any given year.

A benefit of evaluating water stress using return periods, rather than scientific units, is that it only requires estimates of water security indicators to be accurate relative to one another.
Most surface hydrology models undergo a calibration process based on linear regressions between predicted and observed values.
This process corrects for bias and scaling issues, but not for skewing.
Use of return periods implicitly corrects for bias, scaling, and skewing.
Users should therefore have greater confidence in the return period estimates than in the raw indicator estimates.

WSIM uses a common statistical method to compute return periods.

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

.. figure:: /_generated/anomaly_calculations_cdfs.svg
   :align: center

In the example, the probability of observing 93 mm of precipitation or less is 0.85.
To express the frequency of a 93 mm as a return period, we first convert the above probability into an exceedance probability (the probability of obtaining a value greater than 93 mm), which is simply :math:`1 - 0.85 = 0.15`.
The return period is then calculated as the inverse of this exceedance probability, or :math:`1/0.15=6.7`.
So on average, we should expect to see more than 93 mm of precipitation once every 6.7 years.

The above example shows a case in which precipitation is higher than normal (:math:`0.85 > 0.50`).
If we had an unusually low precipitation, we express the frequency as a negative return period.
On the theoretical distribution above, the probability of obtaining less than 35 mm of precipitation is 0.08.
In this case, we calculate the return period as the negative inverse of this cumulative probability, or :math:`-1/0.08 = -12.5`.
So on average, we should expect to see less than 35 mm of precipitation once every 12.5 years.

Observations can also be expressed as *standardized anomalies*: the value on a standard normal distribution having the same cumulative probability as the observed precipitation on its theoretical distribution.
This is computed by applying the standard normal quantile function (inverse cumulative distribution function) to the cumulative probabilities above.

For 93 mm of precipitation, the standardized anomaly is :math:`Q(0.85) = 1.04`; for 35 mm of precipitation, the standardized anomaly is :math:`Q(0.08) = -1.41`.
When precipitation is greater than average, the standardized anomaly is positive; when precipitation is lower than average, the standardized anomaly is negative.

Return periods and standardized anomalies can be computed using functions in the ``wsim.distributions`` R package, or using the ``wsim_anom`` command-line utility.
