#!/usr/bin/env bash
set -e

display_usage() {
	echo "Download a NOAA CFSv2 monthly forecast produced at a given"
	echo "timestamp, for a specified target month. Forecast timestamps"
        echo "use the format YYYYMMDDHH, where HH must be 00, 06, 12, or 18."
	echo ""
	echo "download_cfsv2.sh [timestamp] [target_yearmon] [dir]"
	echo ""
}

if [ $# -ne 3 ]
then
	display_usage
	exit 1
fi

TIMESTAMP=$1
TARGET=$2
OUTDIR=$3

YEAR=${TIMESTAMP:0:4}
MONTH=${TIMESTAMP:4:2}
DAY=${TIMESTAMP:6:2}
HOUR=${TIMESTAMP:8:2}

GRIBFILE=flxf.01.${TIMESTAMP}.${TARGET}.avrg.grib.grb2

TIMESTAMP_EPOCH=$(date --date "${YEAR}${MONTH}${DAY}" "+%s")
ROLLING_ARCHIVE_EPOCH=$(date --date "7 days ago" "+%s")

if (( TIMESTAMP_EPOCH > ROLLING_ARCHIVE_EPOCH )) ; then
	echo "Using rolling archive URL"
	URL=http://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs/cfs.${YEAR}${MONTH}${DAY}/${HOUR}/monthly_grib_01/${GRIBFILE}
else
	echo "Using long-term archive URL"
	URL=https://nomads.ncdc.noaa.gov/modeldata/cfsv2_forecast_mm_9mon/${YEAR}/${YEAR}${MONTH}/${YEAR}${MONTH}${DAY}/${TIMESTAMP}/${GRIBFILE}
fi

echo $URL

wget --continue --directory-prefix ${OUTDIR} ${URL}
