Potential Evapotranspiration (PET)
**********************************

Potential evapotranspiration is computed by Hamon's equation.

.. math::
  
  E_0 = 715.5 \Lambda e_{T_m} / (T_m + 273.2)

where :math:`\Lambda` is the average daylength specified as a fraction of the 24-hour day between sunrise and sunset, :math:`T_m` is the mean temperature in Celsius, and :math:`e_{T_m}` is the saturated vapor pressure at :math:`T_m` in kPa.

Buck's Equation is used to estimate :math:`e_{T_m}`:

.. math::

  e_{T_m} = 6.112 e^{18.5678 - T_m / 234.5) T_m / (257.14 + T_m)}
