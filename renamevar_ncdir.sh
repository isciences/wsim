#!/usr/bin/env bash

display_usage() {
	echo "Rename a variable in all netCDF files in a directory"
	echo "renamevar_ncdir [dir] [old_varname] [new_varname]"
	echo "gldas_noah_extract.sh [in] [out]"
}

if [ $# -le 1 ]
then
	display_usage
	exit 1
fi

cd $1

dir_ncfiles="*.nc"
for file in ${dir_ncfiles} ; do
  ncrename -h -O -v .$2,$3 $file
done

