#!/usr/bin/env bash
set -e

display_usage() {
	echo "Compute pWetDays from NOAA/CPC daily precipitation data"
	echo "compute_noaa_cpc_pwetdays.sh [yearmon] [wsim_dir] [input_dir] [output_dir]"
}

if [ $# -ne 4 ]
then
	display_usage
	exit 1
fi

YEARMON=$1
WSIM_DIR=$2
INDIR=$3
OUTDIR=$4

OUTFILE=${OUTDIR}/wetdays_${YEARMON}.nc

YEAR=${YEARMON:0:4}
DAYS_IN_MONTH=$(date -d "${YEARMON}01 + 1 month - 1 day" "+%d")

if (( $YEAR < 1979 )); then
	(>&2 echo "Daily precipitation data not available before 1979")
	exit 1
elif (( $YEAR < 2006 )); then
	EXT=".gz"
elif (( $YEAR < 2007)); then
	EXT="RT.gz"
elif (( $YEAR < 2009)); then
	EXT=".RT.gz"
else
	EXT=".RT"
fi

INFILES="${INDIR}/${YEAR}/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.[${YEARMON}01:${YEARMON}${DAYS_IN_MONTH}]${EXT}::1@[x-1]->Pr" 

${WSIM_DIR}/wsim_integrate.R --input "${INFILES}" --stat fraction_defined_above_zero --output ${OUTFILE}
ncrename -O "-vPr_fraction_defined_above_zero,pWetDays" ${OUTFILE}
