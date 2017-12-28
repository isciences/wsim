#!/usr/bin/env bash
set -e

display_usage() {
	echo "Download NOAA/CPC Unified Gauge-Based Analysis of Global Daily Precipitation"
	echo "download_daily_precip.sh [dir]"
}

if [ $# -ne 1 ]
then
	display_usage
	exit 1
fi

echo Mirroring to $1

# Mirror pre-2006 data
wget --mirror -nH --cut-dirs=4 ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/V1.0/ --directory-prefix $1
wget --mirror -nH --cut-dirs=4 ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/RT/ --directory-prefix $1


