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
	echo "Extract CFSv2 Reanalysis File"
	echo "extract_cfs_v2_hindcast.sh [file] [dir]"
}

if [ $# -ne 2 ]
then
	display_usage
	exit 1
fi

GRIB=$1 # /mnt/fig/Data_Global/NCEP.CFSv2/retro/grib/prate/prate.m03.jan.cfsv2.data.grb2
OUTDIR=$2
GRIB_BASENAME=`basename ${GRIB}`
VAR=${GRIB_BASENAME:0:5}

if [ $VAR == 'tmp2m' ] ; then
	GRIB_VAR=TMP_2maboveground
elif [ $VAR == 'prate' ] ; then
	GRIB_VAR=PRATE_surface
else
	echo "Unknown variable $VAR"
	exit 1
fi

FCST_TIMESTAMP_REGEX='(?<=d=)[0-9]{8}'

TEMP_GRIB=/tmp/hindcast_regrid.$$.grb2

for lead in {1..9} ; do
	# Extract the date (YYYYMMHH) reflecting the initial conditions of the forecast
	for fcst_timestamp in `wgrib2 $GRIB -match ":$lead-" | grep -oP "(?<=d=)[0-9]{10}" ` ; do
		# Compute the target date (YYYYMM) of the forecast
		target=`date --date "${fcst_timestamp:0:8} + $lead months" "+%Y%m"`
		OUTFILE_TEMP=/tmp/${VAR}_fcst${fcst_timestamp}_trgt${target}_lead${lead}.nc
		OUTFILE=${OUTDIR}/${VAR}_fcst${fcst_timestamp}_trgt${target}_lead${lead}.nc

		if [ -f $OUTFILE ] ; then
			echo Skipping $OUTFILE
			continue
		fi

		echo Writing $OUTFILE
		echo  From $GRIB Lead: $lead months, Forecast conditions: $fcst_timestamp, Target month: $target

		# Create a temporary GRIB on a half-degree global grid
		wgrib2 $GRIB -match "d=$fcst_timestamp" -match ":$lead-" -new_grid latlon -179.75:720:0.5 -89.75:360:0.5 $TEMP_GRIB
		# Convert GRIB to a temporary netCDF. 
		# wgrib2 writes uncompressed netCDFs, so we'll use nccopy later
		# to write it as a compressed netCDF.
		wgrib2 $TEMP_GRIB -netcdf $OUTFILE_TEMP
		rm $TEMP_GRIB

		ncrename -h \
			 -vlatitude,lat \
			 -vlongitude,lon \
			 -dlatitude,lat \
			 -dlongitude,lon \
			 "-v${GRIB_VAR},${VAR}" \
			 $OUTFILE_TEMP

		# Drop the time dimension
		ncwa -h -O -a time $OUTFILE_TEMP $OUTFILE_TEMP
		# Drop the time variable
		ncks -h -C -O -x -v time $OUTFILE_TEMP $OUTFILE_TEMP
		# Add a CRS variable
		ncap -h -O -s 'crs=-9999' $OUTFILE_TEMP $OUTFILE_TEMP
		ncatted -h -O \
			-a spatial_ref,crs,c,c,'GEOGCS[\"GCS_WGS_1984\",DATUM[\"WGS_1984\",SPHEROID[\"WGS_84\",6378137.0,298.257223563]],PRIMEM[\"Greenwich\",0.0],UNIT[\"Degree\",0.017453292519943295]]' \
			-a grid_mapping_name,crs,c,c,'latitude_longitude' \
			-a longitude_of_prime_meridian,crs,c,d,0 \
			-a semi_major_axis,crs,c,d,6378137 \
			-a inverse_flattening,crs,c,d,298.257223563 \
			-a grid_mapping,${VAR},c,c,'crs' \
			$OUTFILE_TEMP
		nccopy -d 1 $OUTFILE_TEMP $OUTFILE
		rm $OUTFILE_TEMP
	done
done

