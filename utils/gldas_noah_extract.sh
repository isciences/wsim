#!/usr/bin/env bash
set -e

display_usage() {
	echo "Convert a CFS forecast from GRIB2 (Gaussian grid) to netCDF (0.5-degree grid)"
	echo "gldas_noah_extract.sh [in] [out]"
}

if [ $# -le 1 ]
then
	display_usage
	exit 1
fi

ncap2 -O -v -s "PETmE=(PotEvap_tavg-Evap_tavg);Ws=(0.1*SoilMoi0_10cm_inst+0.3*SoilMoi10_40cm_inst+0.6*SoilMoi40_100cm_inst);RO_mm=Qs_acc+Qsb_acc+Qsm_acc" $1 $2
ncpdq -O -a -lat $2 $2 # Flip latitudes to get North -> South ordering
ncatted -h -O \
	-a long_name,PETmE,o,c,'Potential minus Actual Evapotranspiration' \
	-a vmin,PETmE,d,, \
	-a vmax,PETmE,d,, \
	-a long_name,Ws,o,c,'Average Soil Moisture' \
	-a standard_name,Ws,o,c,'soil_moisture_content' \
	-a vmin,Ws,d,, \
	-a vmax,Ws,d,, \
	-a long_name,RO_mm,o,c,'Runoff' \
	-a standard_name,RO_mm,o,c,'surface_runoff_amount' \
	-a vmin,RO_mm,d,, \
	-a vmax,RO_mm,d,, $2

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
	-a grid_mapping,PETmE,c,c,'crs' \
	-a grid_mapping,Ws,c,c,'crs' \
	-a grid_mapping,RO_mm,c,c,'crs' \
	$2
