#!/usr/bin/env bash

set -eu

GPW_IN=$1
GPW_OUT=$2
GPW_LEFT=$(tempfile --suffix=.vrt)
GPW_RIGHT=$(tempfile --suffix=.vrt)
gdal_translate -projwin -180 90 -179.875 -90 -a_ullr 180 90 180.125 -90 ${GPW_IN} ${GPW_LEFT}
gdal_translate -projwin -179.875 90 180 -90 ${GPW_IN} ${GPW_RIGHT}
gdal_merge.py -o ${GPW_OUT} -co COMPRESS=LZW ${GPW_LEFT} ${GPW_RIGHT}


