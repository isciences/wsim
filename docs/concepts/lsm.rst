Land Surface Model
******************

WSIM includes a Land Surface Model (LSM), based on a synthesis of two frequently cited soil moisture/runoff models: 
WBM :cite:`Fekete:2010` and “Leaky Bucket” :cite:`Huang:1996,VanDenDool:2003`.
The LSM is driven by three variables:

* Average monthly temperature (:math:`T`)
* Total monthly precipitation (:math:`Pr`)
* The fraction of days in the month during which precipitation falls (:math:`p_{wet}`)

It produces estimates of the following quantities:

+-----------------------------+---------------+-------------------------+
|Parameter                    | Symbol        | Variable Name           |
+=============================+===============+=========================+
|Evapotranspiration           | :math:`E`     | ``E``                   |
+-----------------------------+---------------+-------------------------+
|Evapotranspiration minus     | :math:`E-E_0` | ``EmPET``               |
|potential evapotranspiration |               |                         |
+-----------------------------+---------------+-------------------------+
|Net precipitation            | :math:`P`     | ``P_net``               |
+-----------------------------+---------------+-------------------------+
|Potential evapotranspiration | :math:`E_0`   | ``PET``                 |
+-----------------------------+---------------+-------------------------+
|Potential minus actual       | :math:`E_0-E` | ``PETmE``               |
|evapotranspiration           |               |                         |
+-----------------------------+---------------+-------------------------+
|Runoff                       | :math:`R`     | ``RO_mm``, or ``RO_m3`` |
+-----------------------------+---------------+-------------------------+
|Soil Moisture                | :math:`W_s`   | ``Ws``, or ``dWdt`` for +
|                             |               | change in soil moisture |
+-----------------------------+---------------+-------------------------+
|Snow Accumulation            | :math:`S_a`   | ``Sa``                  |
+-----------------------------+---------------+-------------------------+
|Snow Melt                    | :math:`S_m`   | ``Sm``                  |
+-----------------------------+---------------+-------------------------+
|Total Blue Water             |               | ``Bt_RO``               |
|(runoff plus upstream runoff)|               |                         |
+-----------------------------+---------------+-------------------------+

.. note::
   Runoff quanties (``RO_mm`` and ``Bt_RO``) are also output in variant
   forms (``Runoff_mm`` and ``Bt_Runoff``) that represent runoff computed
   for a model iteration in isolation, ignoring all effects of runoff
   detention between timesteps.

Core functionality of the LSM is implemented in the ``wsim.lsm`` R package.

Data dependencies
=================

In addition to the forcing data (:math:`T`, :math:`Pr`, :math:`p_{wet}`), the LSM relies on the following static data:

* elevation, used to estimate the rate of snow melting
* soil total available water capacity (TAWC), used in estimating soil moisture
* flow direction, used in the flow accumulation process described :ref:`below <flow_accumulation>`.



Beginning a model iteration
===========================

The LSM operates on a monthly timestep.
At the beginning each step, four state variables must be defined for each pixel:

* soil moisture (:math:`W_s`)
* the amount of detained runoff from rainfall (:math:`D_r`)
* the amount of detained runoff from snowmelt (:math:`D_s`)
* the snowpack water equivalent
* the number of consecutive months of melting conditions

The three driver variables are used to advance the model for a single one-month timestep, producing updated versions of the state variables:

These variables are used to perform a water balance on a *daily* timestep, for each day of the month.

To produce daily water balance inputs from the monthly data, the :math:`p_{wet}` parameter is used to divide :math:`Pr` among :math:`n_{wet}` equally-spaced precipitation days, such that:

.. math::

  P_{daily} = \begin{cases}
  \frac{Pr}{n_{wet}} & \textrm{on a precipitation day} \\
  0                  & \textrm{on a dry day}
  \end{cases}

Monthly snowmelt is evenly distributed throughout the month.

Daily Water Balance
===================

The water balance is an implementation of the Thornthwaite :cite:`Thornthwaite:1948,Thornthwaite:1955` equation:

.. math::
  :label: thornthwaite

  R = P - E - \frac{dW}{dt}

where :math:`R` is the rate of surplus water runoff and/or recharge;
:math:`P` is the effective precipitation rate (equation :eq:`effective_precipitation` below);
:math:`E` is the rate of evapotranspiration (evaporation plus plant transpiration);
and :math:`\frac{dW}{dt}` is the change in soil moisture.

Effective precipitation (:math:`P`) is a function of measured precipitation (:math:`P_r`),
snow accumulation (:math:`S_a`), and 
snow melt (:math:`S_m`):

.. math::
  :label: effective_precipitation

  P = P_r - S_a + S_m

.. note::

  Snow accumulation and snow melt are represented as snow water equivalent (not snow depth).

Of the quantities in the Thornthwaite's equation (:eq:`thornthwaite`), only effective precipitation is known directly.

WSIM therefore uses the following steps to arrive at a solution:

1. Estimate potential evapotranspiration (:math:`E_0`), based on day length and temperature.
2. Use the estimate of :math:`E_0`, and the known soil moisture, to estimate :math:`dW/dt`.
3. Estimate :math:`E`, based on :math:`E_0` and :math:`dW/dt`.
4. Solve directly for :math:`R`.

Potential Evapotranspiration
----------------------------

Potential evapotranspiration in the WSIM LSM is calculated using Hamon's Equation (:cite:`Hamon:1961`, :cite:`Hamon:1963`) to estimate potential evapotranspiration as specified in :cite:`Vorosmarty:1998`:

.. math::
  :label: hamon

  E_0 = 715.5 \Lambda e_{T_m} / (T_m + 273.2)


where 
:math:`\Lambda` is the average day length specified as a fraction of the 24-hour day between sunrise and sunset, 
:math:`T_m` is the mean temperature in Celsius, and 
:math:`e_{T_m}` is the saturated vapor pressure at :math:`T_m` in kPa.

Buck’s Equation (:cite:`Buck:1981,Vomel:2016`) is used to estimate :math:`e_{T_m}`:

.. math::
  :label: bucks

  e_{T_m} = 6.1121 e^\frac{18.678 - \frac{T_m}{234.5}}{257.14 + T_m}

.. note::

  There are numerous formulations for estimating potential evapotranspiration (:math:`E_0`) which can, broadly speaking, be divided into two major categories.
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
  
  Vörösmarty et al. :cite:`Vorosmarty:1998` compared 11 different methods of modeling potential evapotranspiration, including methods that either did or did not incorporate differences in land cover. 
  They found that the two best methods for minimizing bias and mean annual error were Hamon's method and the Shuttleworth-Wallace method. 
  More recently, Oudin et al. :cite:`Oudin:2005` also compared a number of different potential evapotranspiration methods (27 in all). 
  They also found that simple “reference” approaches such as Hamon's and McGuinness' performed better than more complex variations. 
  As Oudin et al. :cite:`Oudin:2005` wrote:  “...if a simple temperature-based [potential evapotranspiration] estimation works as well as a Penman-type model, why not using [sic] a simpler model with lower data requirements?”
  
  Based on this literature and concurring advice from our science advisors, WSIM chose to implement Hamon’s Equation.
  
Change in Soil Moisture
-----------------------

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


The soil moisture deficit (:math:`D_{ws}`) is the amount of water needed within a time step to fill the remaining soil water holding capacity (:math:`W_c` in mm) while satisfying potential evapotranspiration (:math:`E_0`). :math:`W_s` is the soil moisture in mm.

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
WSIM defines :math:`g_2(W_s, E_0, P)` to ensure that when :math:`P < E_0`, :math:`-g(W_s, W_c, E_0, P) \le W_s` (i.e., imposing a constraint that :math:`\frac{dW}{dt} \le W_s`).

Evapotranspiration
------------------

Returning to Equation :eq:`thornthwaite`, actual evapotranspiration (:math:`E`) is calculated as:

.. math::
  :label: evapotranspiration

  E = \begin{cases}
  P - \frac{dW}{dt} & P < E_0 \\
  E_0               & P \ge E_0
  \end{cases}  

Returning to Equation :eq:`effective_precipitation`, WSIM follows Vörösmarty et al. :cite:`Vorosmarty:1998` to estimate snow accumulation (:math:`S_a`) and snow melt (:math:`S_m`).
When monthly average temperature is less than or equal to -1ºC, it assumes all precipitation accumulates as snow pack.
This snow pack then melts when monthly average temperature is greater than -1ºC.
In elevations less than or equal to 500m, the entire snow pack melts in one month.
In elevations above 500m, the snow pack requires two months to melt.

Runoff
------

Finally, WSIM computes two forms of runoff.
The runoff as specified above (:math:`R`) is always zero during periods when precipitation accumulates as snow pack.
This is clearly a falsehood, since most rivers continue to flow in the winter.
Therefore, WSIM follows Vörösmarty et al. :cite:`Vorosmarty:1998` by including some logic for detention pools (lakes, ponds, shallow groundwater, etc.) that slow down the rate at which runoff as computed above leaves a given grid cell. 
The revised runoff that accounts for detention pools (:math:`R'`) is computed as the sum of detained runoff due to net precipitation (:math:`R_p'`) and detained runoff due to snow melt (:math:`R_s'`) with a monthly time step as described in 
Equations :eq:`runoff_detained`, :eq:`runoff_rain_detained`, and :eq:`runoff_snowmelt_detained` below. 
(:math:`D_r`) and (:math:`D_s`) represent the detention pools due to rain and snow, respectively.

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

.. _flow_accumulation:

Flow accumulation
=================

After the water balance process has been completed for each day of the month, a flow accumulation algorithm is used to determine the amount of runoff in each grid cell that arrives from upstream locations.

WSIM uses a traditional pixel-to-pixel based flow accumulation algorithm for this computation.
The algorithm uses an eight-neighbor flow direction grid that identifies the downstream grid cell for each grid cell.
The algorithm has two major benefits: it is well known and easy to implement, and it produces results that highlight the specific paths of the stream network during periods of extreme anomalies. 

.. _flow-direction-specification:

Flow Direction Specification
----------------------------

Flow directions for the pixel-to-pixel flow accumulator are encoded using the following values:

+-----------+-------+
| Direction | Value |
+===========+=======+
| East      | 1     |
+-----------+-------+
| Southeast | 2     |
+-----------+-------+
| South     | 4     |
+-----------+-------+
| Southwest | 8     |
+-----------+-------+
| West      | 16    |
+-----------+-------+
| Northwest | 32    |
+-----------+-------+
| North     | 64    |
+-----------+-------+
| Northeast | 128   |
+-----------+-------+



