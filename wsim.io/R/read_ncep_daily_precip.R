# Copyright (c) 2018 ISciences, LLC.
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

#' Read GrADS file containing NCEP global precipitation
#'
#' Reads an 0.5-degree daily precipitation file produced by the CPC
#' Gauge-Based Analysis of Global Daily Precipitation project, as described at
#' ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/DOCU/PRCP_CU_GAUGE_V1.0GLB_0.50deg_README.txt
#'
#' The files are in a GrADS format.  URL to download an example file:
#' ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/RT/2017/
#'
#' @param fname filename to read
#' @param mv NODATA value
#' @param layer layer to retrieve (1 = precipitation rates, 2 = number of stations)
#' @return a matrix of daily precipitation values in 0.1 mm/day
#' @export
read_ncep_daily_precip <- function(fname, mv=-999.0, layer=1) {
  stopifnot(layer %in% c(1, 2))

	# we're expecting 1/2 degree global geographic data
	nr     <- 360 # number of map columns
	nc     <- 720 # number of map rows
	nv     <- 2   # number of values per pixel
	bpv    <- 4   # number of bytes per value
	nbytes <- nc * nr * bpv * nv # (rows * columns * bytes/value * nvalue)

	fh    <- gzfile(fname, "rb")

	# read the data
	fdata <- array(
		data=readBin(fh, "numeric", nbytes, size=4, endian="little"),
		dim=c(nc, nr, nv)
	)

	# close the file
	close(fh)

	# first value is the precipitation map
	pmap        <- fdata[,,layer]
	mvmap       <- (pmap==mv)
	pmap[mvmap] <- NA

	# rearrange data so central meridian is correct
	pmap <- rbind(pmap[361:720,],pmap[1:360,])

	# rearrange data so [1,1] is north/west pixel
	rindices <- ncol(pmap):1
	pmap <- pmap[,rindices]

	return(t(pmap))
}
