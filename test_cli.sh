#!/usr/bin/env bash
set -e

make_raster() {
	Rscript -e "wsim.io::generate_raster('${1}')"
	echo "Generated $1"
}

for i in {1..10}
do
	make_raster "/tmp/T_$i.nc"
done

echo "Fitting distributions"
time ./wsim_fit.R --distribution=gev --input="/tmp/T_*.nc::data" --output=/tmp/fit.nc

echo "Applying distributions"
time ./wsim_anom.R --fits=/tmp/fit.nc --obs="/tmp/T_4.nc" --sa /tmp/sa.nc --rp=/tmp/rp.nc

echo "Performing time-integration"
time ./wsim_integrate.R --stat=min --stat=max --input="/tmp/T_[1-6]*nc::data" --output="/tmp/T_stats_6.nc" --attr="year=2016" --attr="min:units="

#echo "Performing compositing"

#time ./wsim_composite.R \
#	--deficit "~/freq/PETmE_freq_trgt201701.img::1@negate->Neg_PETmE" \
#	--deficit "~/freq/Ws_freq_trgt201701.img::1->Ws" \
#	--deficit "~/freq/Bt_RO_freq_trgt201701.img::1->Bt_RO" \
#	--surplus "~/freq/Bt_RO_freq_trgt201701.img::1->Bt_RO" \
#	--surplus "~/freq/RO_mm_freq_trgt201701.img::1->RO_mm" \
#	--both_threshold 3 \
#	--output "/tmp/composite_201701.nc"

