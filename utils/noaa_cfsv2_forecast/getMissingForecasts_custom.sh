#!/usr/bin/bash

#
#To download CFS2 forecasts using Dan's shell script (git WSIM repo)
#*reqires python 3

#Example on Baobab:

##open an Ubuntu window and change to the correct working dir
#cd /c/git/wsim/

## modify the script to do what you want (downloading appropriate 
#. utils/noaa_cfsv2_forecast/getMissingForecasts_R[yyyymm].sh
#

set +x
# sample line: python3 download_cfsv2_forecast.py --timestamp 2019102118 --target 202001 --output_dir /tmp
year=2022
mon=10
#outRoot=//192.168.100.210/wsim/WSIM_source_V1.2/NCEP.CFSv2/raw_forecast
#outRoot=/mnt/wsim/WSIM_source_V1.2/NCEP.CFSv2/raw_forecast
#outRoot=/mnt/fig/WSIM/WSIM_source_V1.2/NCEP.CFSv2/raw_forecast
outRoot=/c/scratch/WSIM_TEMP
echo "outRoot: $outRoot"
#for day in {9..14}
#for day in {1..8}
#for day in 22
for day in 27 
do
	yrmod=$year$mon$day
	echo ""
	echo "yrmod: $yrmod"
	outDir=$outRoot/cfs.$yrmod
	echo "outDir: $outDir"
	mkdir $outDir
	for hour in 00 06 12 18
	do 
		timestamp=$year$mon$day$hour
		echo "  timestamp: $timestamp"
		for target in 202210 202211 202212 202301 202302 202303 202304 202305 202306 202307 202308
		do
			cmd="python3 download_cfsv2_forecast.py --timestamp $timestamp --target $target --output_dir $outDir"
			echo "    cmd:  $cmd"
			#echo " "
			python3 utils/noaa_cfsv2_forecast/download_cfsv2_forecast.py --timestamp $timestamp --target $target --output_dir $outDir
		done
	done
done
