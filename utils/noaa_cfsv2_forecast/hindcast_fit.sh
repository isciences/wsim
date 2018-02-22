#!/usr/bin/env bash

# Copyright (c) 2018 ISciences, LLC.
# All rights reserved.
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

set -e

display_usage() {
	echo "Fit distributions from hindcast and observed data"
	echo "hindcast_fit.sh [wsim_dir] [hindcast_dir] [obs_dir] [fit_dir]"
}

if [ $# -ne 4 ]
then
	display_usage
	exit 1
fi

START_YEAR=1983 # Although we have some hindcasts that target 1982, we do not have them 
                # for _all_ target month / lead time combinations
END_YEAR=2009   # Although we have some hindcasts that target 2010, we do not have them
                # for _all_ target month / lead time combinations
WSIM_DIR=$1
HINDCAST_DIR=$2
OBS_DIR=$3
FIT_DIR=$4

mkdir -p ${FIT_DIR}

for month in {01..12} ; do
  for var in T Pr ; do
    if [ $var == 'T' ] ; then	
      HC_VAR="tmp2m"
      OBS_VAR="T"
      CONVERSION="[x-273.15]"
    else
      HC_VAR="prate"
      OBS_VAR="P"
      CONVERSION="[x*2628000]"
    fi

    OBS_FIT="${FIT_DIR}/obs_${var}_month_${month}.nc"
    if [ ! -f ${OBS_FIT} ] ; then 
      echo "Fitting observed ${var} for month ${month}, ${START_YEAR} to ${END_YEAR}"
      ${WSIM_DIR/wsim_fit.R \
        --input "${OBS_DIR}/${OBS_VAR}/${OBS_VAR}_[${START_YEAR}${month}:${END_YEAR}${month}:12].nc::${OBS_VAR}->${var}" \
        --output ${OBS_FIT} \
        --distribution gev \
        --attr "month=${month}" \
        --attr "fit_years=${START_YEAR}-${END_YEAR}"
    fi

    for lead in {1..9} ; do
      FORECAST_FIT="${FIT_DIR}/retro_${var}_month_${month}_lead_${lead}.nc" 
      if [ ! -f ${FORECAST_FIT} ] ; then 
        echo "Fitting forecast ${var} for month ${month} (lead ${lead}, ${START_YEAR} to ${END_YEAR})"
        ${WSIM_DIR}/wsim_fit.R \
          --input "${HINDCAST_DIR}/${HC_VAR}_*trgt[${START_YEAR}${month}:${END_YEAR}${month}:12]_lead${lead}.nc::${HC_VAR}@${CONVERSION}->${var}" \
          --output ${FORECAST_FIT} \
          --attr "month=${month}" \
          --attr "lead_months=${lead}" \
          --attr "fit_years=${START_YEAR}-${END_YEAR}" \
          --distribution gev
      fi
    done
  done
done
