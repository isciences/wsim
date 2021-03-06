# Copyright (c) 2019 ISciences, LLC. # All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

context('MIRCA crop calendar functions')

test_that('Condensed crop calendar can be parsed', {
  fname <- tempfile()
  conn <- file(fname)
  writeLines(c(
    '4000 1 2  1181492.48 11 5  0.00 7 10',
    '4000 2 0',
    '4000 3 5  0.00 4 11  0.00 4 10  1964.19 7 10  0.00 11 2  100.0 3 6',
    '8000 1 2  100738.67 11 7  0.00 5 8'
  ), conn)   
  close(conn)
  
  calendar <- parse_mirca_condensed_crop_calendar(fname, header_lines=0) 
  
  expected <- data.frame(rbind(
    c(unit_code=4000, crop=1, subcrop=1, area_ha=1181492.48, plant_month=11, harvest_month=5 ),
    c(unit_code=4000, crop=1, subcrop=2, area_ha=0,          plant_month=7,  harvest_month=10),
    
    c(unit_code=4000, crop=3, subcrop=1, area_ha=0,         plant_month=4,  harvest_month=11),
    c(unit_code=4000, crop=3, subcrop=2, area_ha=0,         plant_month=4,  harvest_month=10),
    c(unit_code=4000, crop=3, subcrop=3, area_ha=1964.19,   plant_month=7,  harvest_month=10),
    c(unit_code=4000, crop=3, subcrop=4, area_ha=0,         plant_month=11, harvest_month=2),
    c(unit_code=4000, crop=3, subcrop=5, area_ha=100.0,     plant_month=3,  harvest_month=6),
    
    c(unit_code=8000, crop=1, subcrop=1, area_ha=100738.67, plant_month=11, harvest_month=7 ),
    c(unit_code=8000, crop=1, subcrop=2, area_ha=0,         plant_month=5,  harvest_month=8 )
  ))
  
  expect_equal(calendar, expected, check.attributes=FALSE)
  
  file.remove(fname)
})

test_that('Calendars are combined correctly', {
  rainfed_japan <- data.frame(rbind(
    c(unit_code=392000, crop=1, subcrop=1, area_ha=120, plant_month=10, harvest_month=7),
    c(unit_code=392000, crop=1, subcrop=2, area_ha=13,  plant_month=5,  harvest_month=9),
    c(unit_code=392000, crop=2, subcrop=1, area_ha=91,  plant_month=5,  harvest_month=9),
    c(unit_code=392000, crop=4, subcrop=1, area_ha=20,  plant_month=11, harvest_month=4),
    c(unit_code=392000, crop=4, subcrop=2, area_ha=2,   plant_month=5,  harvest_month=9),
    c(unit_code=392000, crop=6, subcrop=3, area_ha=0.3, plant_month=5,  harvest_month=9)
  ))
  
  irrigated_japan <- data.frame(rbind(
    c(unit_code=392000, crop=1, subcrop=1, area_ha=120,  plant_month=10, harvest_month=7),
    c(unit_code=392000, crop=2, subcrop=1, area_ha=91,   plant_month=5,  harvest_month=9),
    c(unit_code=392000, crop=3, subcrop=1, area_ha=1213, plant_month=5,  harvest_month=9),
    c(unit_code=392000, crop=3, subcrop=2, area_ha=607,  plant_month=10, harvest_month=4),
    c(unit_code=392000, crop=4, subcrop=1, area_ha=37,   plant_month=11, harvest_month=4)
  ))
  
  # crop 3 is copied from irrigated calendar, everything else left as-is
  expect_equal(combine_calendars(rainfed_japan, irrigated_japan),
               data.frame(rbind(
                 c(unit_code=392000, crop=1, subcrop=1, area_ha=120,  plant_month=10, harvest_month=7),
                 c(unit_code=392000, crop=1, subcrop=2, area_ha=13,   plant_month=5,  harvest_month=9),
                 c(unit_code=392000, crop=2, subcrop=1, area_ha=91,   plant_month=5,  harvest_month=9),
                 c(unit_code=392000, crop=4, subcrop=1, area_ha=20,   plant_month=11, harvest_month=4),
                 c(unit_code=392000, crop=4, subcrop=2, area_ha=2,    plant_month=5,  harvest_month=9),
                 c(unit_code=392000, crop=6, subcrop=3, area_ha=0.3,  plant_month=5,  harvest_month=9),
                 c(unit_code=392000, crop=3, subcrop=1, area_ha=1213, plant_month=5,  harvest_month=9),
                 c(unit_code=392000, crop=3, subcrop=2, area_ha=607,  plant_month=10, harvest_month=4)
               ))
  )
  
  # crop 6 copied from rainfed to irrigated. note that subcrop 2 of crop 1 is not copied, even though
  # it is absent in the irrigated calendar.
  expect_equal(combine_calendars(irrigated_japan, rainfed_japan),
               data.frame(rbind(
                 c(unit_code=392000, crop=1, subcrop=1, area_ha=120,  plant_month=10, harvest_month=7),
                 c(unit_code=392000, crop=2, subcrop=1, area_ha=91,   plant_month=5,  harvest_month=9),
                 c(unit_code=392000, crop=3, subcrop=1, area_ha=1213, plant_month=5,  harvest_month=9),
                 c(unit_code=392000, crop=3, subcrop=2, area_ha=607,  plant_month=10, harvest_month=4),
                 c(unit_code=392000, crop=4, subcrop=1, area_ha=37,   plant_month=11, harvest_month=4),
                 c(unit_code=392000, crop=6, subcrop=3, area_ha=0.3,  plant_month=5,  harvest_month=9)
               ))
  )
})
