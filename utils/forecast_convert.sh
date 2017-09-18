#!/usr/bin/env bash
set -e

display_usage() {
	echo "Convert a CFS forecast from GRIB2 (Gaussian grid) to netCDF (0.5-degree grid)"
	echo "forecast_convert.sh [in] [out]"
}

if [ $# -le 1 ]
then
	display_usage
	exit 1
fi

TEMP_GRB2=/tmp/regrid_halfdeg.grb2

wgrib2 $1 -match "PRATE:surface|TMP:2 m" -new_grid latlon -179.75:720:0.5 -89.75:360:0.5 $TEMP_GRB2
wgrib2 $TEMP_GRB2 -nc_grads -netcdf $2
rm $TEMP_GRB2
ncrename -h \
	 -vlatitude,lat \
	 -vlongitude,lon \
	 -dlatitude,lat \
	 -dlongitude,lon \
	 -vTMP_2maboveground,tmp2m \
	 -vPRATE_surface,prate \
	 $2
# Drop the time dimension
ncwa -h -O -a time $2 $2
# Drop the time variable
ncks -h -C -O -x -v time $2 $2
# Add a CRS variable
ncap -h -O -s 'crs=-9999' $2 $2
ncatted -h -O \
	-a spatial_ref,crs,c,c,'GEOGCS[\"GCS_WGS_1984\",DATUM[\"WGS_1984\",SPHEROID[\"WGS_84\",6378137.0,298.257223563]],PRIMEM[\"Greenwich\",0.0],UNIT[\"Degree\",0.017453292519943295]]' \
	-a grid_mapping_name,crs,c,c,'latitude_longitude' \
	-a longitude_of_prime_meridian,crs,c,d,0 \
	-a semi_major_axis,crs,c,d,6378137 \
        -a inverse_flattening,crs,c,d,298.257223563 \
	-a grid_mapping,tmp2m,c,c,'crs' \
	-a grid_mapping,prate,c,c,'crs' \
	$2

