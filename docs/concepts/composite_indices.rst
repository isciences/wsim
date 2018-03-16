Composite Indices
*****************

One of the standard means of reporting WSIM results is the global “hot spot” map (as shown :ref:`here <example-global-hotspot>`) that identifies regions of the globe experiencing anomalous water stress, either surplus or deficit. 
These hot spot maps are created from the Composite Deficit Index and Composite Surplus Index, which in turn are calculated from other water security indicators. ISciences computes the composite indices as follows:

- The *Composite Deficit Index* is calculated as the “worst” (most negative as measured by return period) of three water deficit indicators: soil moisture, EmPET (actual minus potential evapotranspiration), and total blue water. The index is calculated on a monthly basis and is designed to depict the aggregate effect of water deficits for a wide variety of water uses. Deficits are shown in shades of red on the hot spot maps.
- The *Composite Surplus Index* is calculated as the “worst” (most positive as measured by return period) of two water surplus indicators: runoff and total blue water. The index is calculated on a monthly basis and is designed to depict the aggregate effect of water surpluses for a wide variety of water uses. Surpluses are shown in shades of blue on the hot spot maps.
  w
- Occasionally there are regions that experience both surplus and deficit either simultaneously or in quick succession. An example of this would be an area where lack of precipitation has resulted in very dry soils (high soil moisture deficit) but heavy rains (or snow melt) in upstream areas have caused stream flows to be abnormally high. Areas experiencing both deficits and surpluses are shown in shades of purple on the hot spot maps.

The indicators used in constructing composite indices is controlled by command-line arguments and can be customized by the user.

To help assess sequencing effects, such as the degree to which a hot spot represents a long-term persistent anomaly or a shorter-term extreme, these composite indices maps can be produced for a variety of time periods (e.g., 12-month, 3-year).
This temporal integration is accomplished by calculating statistics (sum, average, minimum, and/or maximum) for each of the components of the composite index (e.g., soil moisture, total blue water, etc.) as measured in scientific units over the time period. The return period for these statistics is then calculated and integrated into the multi-month composite index.

Adjusted Composite Indicies
^^^^^^^^^^^^^^^^^^^^^^^^^^^

The composite indices as described above are simple to calculate and provide a quick means to compare relative water stress between regions and throughout time.
The absolute values of the indices can be difficult to interpret, however.
Because the composite indices are calculated as the maximum (or minimum) or several return periods, the value of composite index itself cannot be easily interpreted as a return period.
(The return period of a 30-year composite surplus is expected to be something less than 30 years.)

WSIM can also compute adjusted composite indices for applications where the return period of the composite index itself is important.
These adjusted composites are calculated according to the following procedure:

1. Compute composite surplus and deficit indices (as standardized anomalies) for the reference historical period (e.g., 1950-2009).
2. Compute composite surplus and deficit (as standardized anomalies) for the observed or forecast period of interest.
3. Compute the return period of the composite surplus and deficit anomalies, given the distributions from Step 1.

