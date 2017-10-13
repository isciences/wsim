#' @export
cdf_attrs <- list(
  list(
    var="lat",
    description="Latitude (degrees)",
    long_name="latitude",
    standard_name="latitude",
    units="degrees_north"
  ),
  list(
    var="lon",
    description="Longitude (degrees)",
    long_name="longitude",
    standard_name="longitude",
    units="degrees_north"
  ),
  list(
    var="Bt_RO",
    description="Total Blue Water (mm)",
    long_name="Total Blue Water",
    units="mm"
  ),
  list(
    var="Bt_Runoff",
    description="Total Blue Water, not accounting for detention (mm)",
    long_name="Total Blue Water",
    units="mm"
  ),
  list(
    var="RO_mm",
    description="Runoff (mm)",
    long_name="Runoff",
    standard_name="surface_runoff_amount",
    units="mm"
  ),
  list(
    var="RO_m3",
    description="Runoff (m3)",
    long_name="Runoff",
    standard_name="surface_runoff_amount",
    units="m^3"
  ),
  list(
    var="Runoff_mm",
    description="Runoff (mm), not accounting for detention",
    long_name="Runoff",
    standard_name="surface_runoff_amount",
    units="mm"
  ),
  list(
    var="Runoff_m3",
    description="Runoff (m3), not accounting for detention",
    long_name="Runoff",
    standard_name="surface_runoff_amount",
    units="m^3"
  ),
  list(
    var="daylength",
    description="Length of Day (fraction of 24h period)",
    long_name="Daylength",
    units="1" # Recommended by CF conventions 1.7, sec 3.1
  ),
  list(
    var="pWetDays",
    description="Fraction of Days with Precipitation",
    long_name="Fraction of Days with Precipitation",
    units="1"
  ),
  list(
    var="E",
    description="Evapotranspiration (mm)",
    long_name="Evapotranspiration",
    standard_name="water_evaporation_amount",
    units="mm"
  ),
  list(
    var="EmPET",
    description="Evapotranspiration minus Potential Evapotranspiration (mm)",
    long_name="Evapotranspiration minus Potential Evapotranspiration",
    units="mm"
  ),
  list(
    var="PETmE",
    description="Potential minus Actual Evapotranspiration (mm)",
    long_name="Potential minus Actual Evapotranspiration",
    units="mm"
  ),
  list(
    var="P_net",
    description="Net Precipitation (mm)",
    long_name="Net Precipitation",
    units="mm"
  ),
  list(
    var="Pr",
    description="Total Precipitation (mm)",
    long_name="Precipitation",
    standard_name="precipitation_amount",
    units="mm"
  ),
  list(
    var="PET",
    description="Potential Evapotranspiration (mm)",
    long_name="Potential Evapotranspiration",
    standard_name="water_potential_evaporation_amount",
    units="mm"
  ),
  list(
    var="Sm",
    description="Snowmelt (mm)",
    long_name="Snowmelt",
    standard_name="surface_snow_melt_amount",
    units="mm"
  ),
  list(
    var="Sa",
    description="Snow Accumulation (mm)",
    long_name="Snow Accmulation",
    standard_name="snowfall_amount",
    units="mm"
  ),
  list(
    var="T",
    description="Temperature (C)",
    long_name="Temperature",
    standard_name="surface_temperature",
    units="mm"
  ),
  list(
    var="Dr",
    description="Detained Runoff (mm)",
    long_name="Detained Runoff",
    units="mm"
  ),
  list(
    var="Ds",
    description="Detained Snowmelt (mm)",
    long_name="Detained Snowmelt",
    units="mm"
  ),
  list(
    var="Ws",
    description="Soil Moisture (mm)",
    long_name="Soil Moisture (mm)",
    standard_name="soil_moisture_content",
    units="mm"
  ),
  list(
    var="dWdt",
    description="Change in Soil Moisture (mm)",
    long_name="Change in Soil Moisture",
    units="mm"
  ),
  list(
    var="snowmelt_month",
    description="Number of consecutive months of melting conditions",
    long_name="Snowmelt Month",
    units="1"
  ),
  list(
    var="Snowpack",
    description="Water Equivalent of Snowpack (mm)",
    long_name="Snowpack",
    standard_name="surface_snow_amount",
    units="mm"
  )
)
