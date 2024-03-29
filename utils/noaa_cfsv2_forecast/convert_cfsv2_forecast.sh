#!/usr/bin/env bash

# Copyright (c) 2018-2021 ISciences, LLC.
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

set -eu

display_usage() {
	echo "Convert a CFS forecast from GRIB2 (Gaussian grid) to netCDF (0.5-degree grid)"
	echo "convert_cfsv2_forecast.sh [in] [out] [wgrib_grid_def]"
}

if [ $# -le 2 ]
then
	display_usage
	exit 1
fi

INFILE=$1
OUTFILE=$2
WGRIB_GRID=$3

TEMP_GRB2=/tmp/regrid.$$.grb2
TEMP_NC1=/tmp/$(basename "$OUTFILE").tmp1.$$.nc
TEMP_NC2=/tmp/$(basename "$OUTFILE").tmp2.$$.nc
TEMP_NC3=/tmp/$(basename "$OUTFILE").tmp3.$$.nc
TEMP_NC4=/tmp/$(basename "$OUTFILE").tmp4.$$.nc

function cleanup {
  rm -f $TEMP_GRB2
  rm -f $TEMP_NC1
  rm -f $TEMP_NC2
  rm -f $TEMP_NC3
  rm -f $TEMP_NC4
}
trap cleanup EXIT

wgrib2 "$INFILE" -match "PRATE:surface|TMP:2 m" -new_grid latlon $WGRIB_GRID $TEMP_GRB2
wgrib2 $TEMP_GRB2 -nc_grads -netcdf $TEMP_NC1

# Rename each variable in separate commands
# Some versions of NCO fail to find variables
# when we perform all of the renames in a single
# command.
ncrename -h -vlatitude,lat $TEMP_NC1
ncrename -h -vlongitude,lon $TEMP_NC1
ncrename -h -vTMP_2maboveground,T $TEMP_NC1
ncrename -h -vPRATE_surface,Pr $TEMP_NC1
ncrename -h -dlatitude,lat $TEMP_NC1
ncrename -h -dlongitude,lon $TEMP_NC1

ncatted -h -a standard_name,T,c,c,'surface_temperature' $TEMP_NC1
ncatted -h -a standard_name,Pr,c,c,'precipitation_flux' $TEMP_NC1

# Use the --no_tmp_fl option to NCO and manage the temp files ourselves
# Do this to avoid "permission denied" errors when writing to CIFS shares
# under certain conditions

# Drop the time dimension
ncwa --no_tmp_fl -h -a time $TEMP_NC1 $TEMP_NC2
# Drop the time variable
ncks --no_tmp_fl -h -C -O -x -v time $TEMP_NC2 $TEMP_NC3
# Add a CRS variable
ncap2 --no_tmp_fl -h -O -s 'crs=-9999' $TEMP_NC3 $TEMP_NC4
ncatted -h -O \
	-a spatial_ref,crs,c,c,'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AXIS["Latitude",NORTH],AXIS["Longitude",EAST],AUTHORITY["EPSG","4326"]]' \
	-a grid_mapping_name,crs,c,c,'latitude_longitude' \
	-a longitude_of_prime_meridian,crs,c,d,0 \
	-a semi_major_axis,crs,c,d,6378137 \
        -a inverse_flattening,crs,c,d,298.257223563 \
	-a grid_mapping,T,c,c,'crs' \
	-a grid_mapping,Pr,c,c,'crs' \
	$TEMP_NC4

# Compress the netCDF
ncks $TEMP_NC4 -O -L1 -7 $2
