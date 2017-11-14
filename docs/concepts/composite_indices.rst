Composite Indices
*****************

One of the standard means of reporting WSIM results is the global “hot spot” map (as shown :ref:`here <example-global-hotspot>`) that identifies regions of the globe experiencing anomalous water stress, either surplus or deficit. 
These hot spot maps are created from the Composite Deficit Index and Composite Surplus Index, which in turn are calculated from other water security indicators. ISciences computes the composite indices as follows:

- The Composite Deficit Index is calculated as the “worst” (most negative as measured by return period) of three water deficit indicators: soil moisture, EmPET (actual minus potential evapotranspiration), and total blue water. The index is calculated on a monthly basis and is designed to depict the aggregate effect of water deficits for a wide variety of water uses. Deficits are shown in shades of red on the hot spot maps.
- The Composite Surplus Index is calculated as the “worst” (most positive as measured by return period) of two water surplus indicators: runoff and total blue water. The index is calculated on a monthly basis and is designed to depict the aggregate effect of water surpluses for a wide variety of water uses. Surpluses are shown in shades of blue on the hot spot maps.
- Occasionally there are regions that experience both surplus and deficit either simultaneously or in quick succession. An example of this would be an area where lack of precipitation has resulted in very dry soils (high soil moisture deficit) but heavy rains (or snow melt) in upstream areas have caused stream flows to be abnormally high (blue water surplus). Areas experiencing both deficits and surpluses are shown in shades of purple on the hot spot maps.

To help assess sequencing effects, such as the degree to which a hot spot represents a long-term persistent anomaly or a shorter-term extreme, these hot spot maps are produced for a variety of time periods (5-year, 3-year, 1-year, 6-month, 3-month, and monthly).
This temporal integration is accomplished by calculating statistics (sum, average, minimum, and/or maximum) for each of the components of the composite index (e.g., soil moisture, total blue water, etc.) as measured in scientific units over the time period. The return period for these statistics is then calculated and integrated into the multi-month composite index.


