#' readNCEP_Daily_P
#'
#' Reads an 0.5-degree daily precipitation file produced by the CPC
#' Gauge-Based  #' Analysis of Global Daily Precipitation project, as described at
#' ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/DOCU/PRCP_CU_GAUGE_V1.0GLB_0.50deg_README.txt
#'
#' The files are in a GrADS format.  URL to download an example file:
#' ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/RT/2017/
#'
#' @param fname filename to read
#' @param mv NODATA value
#' @return a matrix of daily precipitation values in 0.1 mm/day
#' @export
readNCEP_Daily_P <- function(fname, mv=-999.0) {

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
	pmap        <- fdata[,,1]
	mvmap       <- (pmap==mv)
	pmap[mvmap] <- NA

	# rearrange data so central meridian is correct
	pmap <- rbind(pmap[361:720,],pmap[1:360,])

	# rearrange data so [1,1] is north/west pixel
	rindices <- ncol(pmap):1
	pmap <- pmap[,rindices]

	return(pmap)
}
