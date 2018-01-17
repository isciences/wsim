Soil Moisture and Runoff
************************

The core objective of the soil moisture/runoff component is to estimate soil moisture, runoff, potential evapotranspiration, and actual evapotranspiration based on the inputs described above. This section describes the computational steps that WSIM employs to make these estimates.

Water Balance
=============

The WSIM model is based on the Thornthwaite :cite:`Thornthwaite:1948,Thornthwaite:1955` water balance equation:

.. math::
  :label: thornthwaite

  R = P - E - \frac{dW}{dt}


where :math:`R` is the rate of surplus water (runoff and/or recharge) in mm/day;
:math:`P` is the effective precipitation rate in mm/day (see Equation :eq:`effective_precipitation` below);
:math:`E` is the rate of evapotranspiration (evaporation plus plant transpiration) in mm/day;
and :math:`\frac{dW}{dt}` is the change in soil moisture in mm/day.

Effective precipitation (:math:`P`) is a function of measured precipitation (:math:`P_r`) in mm/day),
snow accumulation (:math:`S_a` in mm/day), and 
snow melt (:math:`S_m` in mm/day).

Snow accumulation and snow melt are represented as snow water equivalent (not snow depth).

.. math::
  :label: effective_precipitation

  P = P_r - S_a + S_m

Change in soil moisture (:math:`\frac{dW}{dt}`) is a function of 
effective precipitation (:math:`P` in mm/day),
potential evapotranspiration (:math:`E_0` in mm/day),
soil moisture deficit (:math:`D_{ws}` in mm/day),
and a unitless soil drying function :math:`g(W_s, W_c, E_0, P)`.

.. math::
  :label: soil_moisture_change

  \frac{dW}{dt} = \begin{cases}
    -g(W_s, W_c, E_0, P) & P < E_0 \\
    P - E_0              & E_0 < P < D_{ws} \\
    D_{ws} - E_0         & P \ge D_{ws}
  \end{cases}

Potential Evapotranspiration
============================

There are numerous formulations for estimating potential evapotranspiration (:math:`E_0`) which can, broadly speaking, be divided into two major categories:  
The first category consists of highly simplified reduced-form estimates based on empirical fits for a given reference land cover of short grass. Examples include formulas proposed by Hamon, Thornthwaite, Turc, Jensen-Haise, Hargreaves, and others (:cite:`Federer:2010,Vorosmarty:1998,Lu:2005,Oudin:2005,Kingston:2009`).
However, it is well known that land cover is a major factor in estimating potential evapotranspiration and it is widely assumed that formulations that take land cover into account are more accurate. 
All other factors being equal, bare ground will have the lowest potential evapotranspiration and deciduous forest will have the highest.

This gives rise to the second category of formulations that are highly parameterized to include land cover type and many other variables. 
These process-based or combination methods can explicitly account for different surface characteristics, including vegetation characteristics and the proportion of exposed bare soil. 
These methods include the Priestly-Taylor, McNaughton-Black, Penman-Monteith and Shuttleworth-Wallace methods. 
The most sophisticated method is the Shuttleworth-Wallace method, which is a modification of Penman-Monteith (the most commonly used method and the FAO standard). 
Shuttleworth-Wallace modifies Penman-Monteith to incorporate a term for bare soil. 
These methods are all described in :cite:`Lu:2005`, :cite:`Oudin:2005`, and :cite:`Vorosmarty:1998`.
See also :cite:`Zhou:2006` and :cite:`Zhou:2009` for a description of Shuttleworth-Wallace and how it could be parameterized with global data. 

Vörösmarty et al. (:cite:`Vorosmarty:1998`) compared 11 different methods of modeling potential evapotranspiration, including methods that either did or did not incorporate differences in land cover. 
They found that the two best methods for minimizing bias and mean annual error were Hamon's method and the Shuttleworth-Wallace method. 
More recently, Oudin et al. :cite:`Oudin:2005` also compared a number of different potential evapotranspiration methods (27 in all). 
They also found that simple “reference” approaches such as Hamon's and McGuinness' performed better than more complex variations. 
As Oudin et al. :cite:`Oudin:2005` wrote:  “...if a simple temperature-based [potential evapotranspiration] estimation works as well as a Penman-type model, why not using [sic] a simpler model with lower data requirements?”

Based on this literature and concurring advice from our science advisors, WSIM chose to implement Hamon’s Equation (:cite:`Hamon:1961`, :cite:`Hamon:1963`) to estimate potential evapotranspiration as specified in :cite:`Vorosmarty:1998`:

.. math::
  :label: hamon

  E_0 = 715.5 \Lambda e_{T_m} / (T_m + 273.2)


where 
:math:`\Lambda` is the average day length specified as a fraction of the 24-hour day between sunrise and sunset, 
:math:`T_m` is the mean temperature in Celsius, and 
:math:`e_{T_m}` is the saturated vapor pressure at :math:`T_m` in kPa.

We estimate :math:`e_{T_m}` using Buck’s Equation (:cite:`Buck:1981,Vomel:2016`):

.. math::
  :label: bucks

  e_{T_m} = 6.1121 e^\frac{18.678 - \frac{T_m}{234.5}}{257.14 + T_m}

Soil Drying
===========

Returning to Equation :eq:`soil_moisture_change`, the soil moisture deficit (:math:`D_{ws}`) is the amount of water needed within a time step to fill the remaining soil water holding capacity (:math:`W_c` in mm) while satisfying potential evapotranspiration (:math:`E_0`). :math:`W_s` is the soil moisture in mm.

.. math::
  :label: soil_moisture_deficit

  D_{ws} = \left( W_c - W_s \right) + E_0

The unitless drying function, :math:`g(W_s, W_c, E_0, P)`, is defined as:

.. math::
  :label: drying

  g(W_s, W_c, E_0, P) = g_1(W_s, W_c) g_2(W_s, E_0, P)

.. math::
  :label: drying_1

  g_1(W_s, W_c) = \frac{1-e^{\frac{-\alpha W_s}{W_c}}}{1 - e^{-\alpha}} \textrm{ and } \alpha = 5.0

.. math::
  :label: drying_2

  g_2(W_s, E_0, P) = \begin{cases}
    E_0 - P                                                         & \beta < 1 \\
    W_s \frac{1 - e^{ -\beta \left(E_0 - P\right)}}{1 - e^{-\beta}} & \beta \ge 1
  \end{cases} \textrm{ and } \beta = \frac{E_0}{W_s}

The specification follows Vörösmarty et al. :cite:`Vorosmarty:1998`.
The WSIM team defined :math:`g_2(W_s, E_0, P)` to ensure that when :math:`P < E_0`, :math:`-g(W_s, W_c, E_0, P) \le W_s` (i.e., imposing a constraint that :math:`\frac{dW}{dt} \le W_s`).

Evapotranspiration
==================

Returning to Equation :eq:`thornthwaite`, actual evapotranspiration (:math:`E`) is calculated as:

.. math::
  :label: evapotranspiration

  E = \begin{cases}
  P - \frac{dW}{dt} & P < E_0 \\
  E_0               & P \ge E_0
  \end{cases}  

Returning to Equation :eq:`effective_precipitation`, WSIM follows Vörösmarty et al. :cite:`Vorosmarty:1998` to estimate snow accumulation (:math:`S_a`) and snow melt (:math:`S_m`).
When monthly average temperature is less than or equal to -1ºC, we assume all precipitation accumulates as snow pack.
This snow pack then melts when monthly average temperature is greater than -1ºC.
In elevations less than or equal to 500m, the entire snow pack melts in one month.
In elevations above 500m, the snow pack requires two months to melt.

The formulas described above are run on a daily time step using monthly average temperature and an imputed value for daily total precipitation derived by dividing total monthly precipitation by the number of wet days within the month and evenly distributing them within the month.
We anticipate that a future version of WSIM may use actual daily precipitation totals.

Runoff
======

Finally, WSIM computes two forms of runoff.
The runoff as specified above (:math:`R`) is always zero during periods when precipitation accumulates as snow pack.
This is clearly a falsehood, since most rivers continue to flow in the winter.
Therefore, we follow Vörösmarty et al. :cite:`Vorosmarty:1998` by including some logic for detention pools (lakes, ponds, shallow groundwater, etc.) that slow down the rate at which runoff as computed above leaves a given grid cell. 
The revised runoff that accounts for detention pools (:math:`R'`) is computed as the sum of detained runoff due to net precipitation (:math:`R_p'`) and detained runoff due to snow melt (:math:`R_s'`) with a monthly time step as described in 
Equations 11, 12, and 13 below. (:math:`D_r`) and (:math:`D_s`) represent the detention pools due to rain and snow, respectively.

.. math::
  :label: runoff_detained
  
  R' = R_p' + R_s'

.. math::
  :label: runoff_rain_detained

  R_p' = 0.5 \left( D_r + X_r \right) 
  \textrm{ where } X_r = \frac{P_r - S_a}{P}R 
  \textrm{ and } \frac{dD_r}{dt} = 0.5 \left(D_r + X_r \right)

.. math::
  :label: runoff_snowmelt_detained

  R_s' = \begin{cases}
  0.1 \left(D_s + X_s \right) & z < 500 \textrm{ and } m = 1 \\
  0.5 \left(D_s + X_s \right) & z < 500 \textrm{ and } m > 1 \\
  0.1 \left(D_s + X_s \right) & z \ge 500 \textrm{ and } m = 1 \\
  0.25\left(D_s + X_s \right) & z \ge 500 \textrm{ and } m = 2 \\
  0.1 \left(D_s + X_s \right) & z \ge 500 \textrm{ and } m > 2
  \end{cases}

where :math:`z` is elevation in meters, and 
:math:`m` is the number of consecutive months of melting conditions (:math:`T > -1 \mathrm{^\circ C}`).

