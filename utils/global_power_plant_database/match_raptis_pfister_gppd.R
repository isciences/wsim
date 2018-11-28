library(dplyr)
library(geosphere)
library(readxl)

# This script identifies once-through cooled plants in WRI's Global Power Plant Database
# (GPPD) by matching locations against the dataset of once-through cooled plants as identified
# in Raptis, C. and Pfister, S. 2016. "Globalfreshwater thermal emissions from steam-electric
# power plants with once-through cooling systems." Energy 97, 46-57.
# http://dx.doi.org/10.1016/j.energy.2015.12.107
#
# It is not currently included in the WSIM automated workflow, so it does not use command-line
# arguments.

# Read Raptis and Pfister dataset
raptis_units <- read_xlsx('SI_xlsx.xlsx', skip=22)

# Read global power plant database from WRI.
gppd <- read.csv('global_power_plant_database.csv', stringsAsFactors=FALSE)

# Filter out plants in GPPD that can't be once-through cooled, both
# to avoid false matches, and to reduce computational effort.
gppd <- gppd %>%
  select(gppd_idnr, fuel=fuel1, longitude, latitude) %>%
  filter(!(fuel %in% c("Hydro", "Wind", "Solar", "Wave and Tidal")))

# Map Raptis and Pfister (2016) fuel types to GPPD fuel types
raptis2gppd <- function(fuel) {
  switch(fuel,
    Nuclear= "Nuclear",
    Gas= "Gas",
    Coal= "Coal",
    Oil= "Oil",
    Wsth= "Other",
    Geo= "Geothermal",
    Biofuel= "Biomass",
    Waste= "Waste"
  )
}

# Find the nearest GPPD plant to each once-through cooled plant in
# Raptis and Pfister (2016). This code requires calculating all
# distance pairs, but the data sets are small enough for this to work.
raptis_plants <- raptis_units %>%
  group_by(id_plant) %>%
  summarize(latitude= mean(latitude),
            longitude= mean(longitude),
            fuel= min(aggregated_fuel_group)
            ) %>%
  mutate(nearest_gppd= sapply(1:nrow(.), function(i)
    gppd[which.min(distGeo(   .[i, c('longitude', 'latitude')],
                           gppd[ , c('longitude', 'latitude')])), 'gppd_idnr']
  ))

# Prepare a summary table of matched plants
plants_matched <- raptis_plants %>%
  inner_join(gppd, by=c(nearest_gppd='gppd_idnr'), suffix=c('', '.gppd')) %>%
  transmute(id_plant,
            latitude,
            longitude,
            fuel= sapply(fuel, raptis2gppd),
            nearest_gppd,
            nearest_gppd_fuel= fuel.gppd,
            distance_m= distGeo(cbind(longitude, latitude), cbind(longitude.gppd, latitude.gppd)))

# Construct a list of GPPD plant IDs that are assumed to be once-through cooled.
# We don't require fuel type matching because of the small distance threshold.
gppd_once_through <- plants_matched %>%
  filter(distance_m <= 1000) %>%
  pull(nearest_gppd) %>%
  unique %>%
  sort

write.table(gppd_once_through,
            'gppd_once_through_cooled.txt',
            col.names=FALSE,
            row.names=FALSE,
            quote=FALSE)
