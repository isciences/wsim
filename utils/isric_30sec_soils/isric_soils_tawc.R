require(dplyr)
require(readr)

data <- read_csv('/home/dbaston/wise_30sec/HW30s_FULL.txt')
codes <- read_tsv('/home/dbaston/wise_30sec/wise_30sec_v1.tsv')

weighted_mean_tawc <- data %>%
  filter(TAWC >= 0) %>%
  mutate(thickness_m= (BotDep-TopDep)/100) %>%
  mutate(layer_capacity_mm= 10*TAWC*thickness_m) %>%
  group_by(NEWSUID, Layer) %>%
  summarise(avg_layer_capacity_mm = weighted.mean(layer_capacity_mm, PROP)) %>%
  group_by(NEWSUID) %>%
  summarise(TAWC= sum(avg_layer_capacity_mm))

most_common_nodata <- data %>%
  filter(TAWC < 0) %>%
  group_by(NEWSUID) %>%
  summarise(TAWC_nodata= modal(TAWC)) %>%
  anti_join(weighted_mean_tawc, by="NEWSUID")

tawc_for_pixel <- tawc_including_nodata %>%
  inner_join(codes, by=c("NEWSUID"="description")) %>%
  rename(pixel_value= pixel_vaue) %>%
  dplyr::select(pixel_value, TAWC)

missing_data_pixels <- most_common_nodata %>%
  inner_join(codes, by=c("NEWSUID"="description")) %>%
  rename(pixel_value= pixel_vaue) %>%
  dplyr::select(pixel_value, TAWC_nodata)

write_csv(tawc_for_pixel, '/home/dbaston/wise_30sec/wise_tawc_for_pixel_value.csv')
write_csv(missing_data_pixels, '/home/dbaston/wise_30sec/wise_missing_data_for_pixel_value.csv')
