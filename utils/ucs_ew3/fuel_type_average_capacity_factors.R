library(dplyr)
library(readxl)

download.file('https://www.ucsusa.org/sites/default/files/attach/2016/03/UCS-EW3-Energy-Water-Database.xlsx',
              destfile='UCS_EW3.xlsx')

ew3 <- read_xlsx('UCS_EW3.xlsx', sheet='MAIN DATA', skip=4)

capacity_factors <- ew3 %>%
  group_by(Fuel) %>%
  summarize(mean_capacity_factor= mean(`Estimated Capacity Factor`))
