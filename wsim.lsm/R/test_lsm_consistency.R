require(testthat)

nadiff <- function(r1, r2) {
  v1 <- raster::values(r1)
  v2 <- raster::values(r2)

  nd <- ifelse(is.na(v1) == is.na(v2),
               NA,
               ifelse(is.na(v1), 1, 2))

  ndr <- raster::raster(r1)
  raster::values(ndr) <- nd
  ndr
}

compare <- function(param) {
 test <- raster::raster(paste0('/home/dbaston/2_', param, '.img'))
 actual <- raster::raster(paste0('/home/dbaston/SCI/', param, '_trgt201705.img'))
 #last[[param]] <<- actual

 #print(test)
 #print(actual)

 max_diff <- raster::cellStats(abs(actual-test), 'max')

 graphics::par(mfrow=c(2,2), oma=c(0,0,2,0))
 raster::plot(test)
 graphics::title('Test result')
 raster::plot(actual)
 graphics::title('Past result')
 raster::plot(abs(test-actual))
 graphics::title('abs(test-result)')
 raster::plot(nadiff(actual, test) )
 graphics::title('NA differences')
 graphics::title(paste0(c(
   param,
   " (dmax=",
   sprintf("%.e", max_diff),
   ")"), collapse=""), outer=TRUE)
}

load <- function(..., nodata=NULL) {
  path <- do.call(file.path, list(...))
  raster::raster(path)
}

loadSource <- function(...) {
  do.call(load, append(list('/home', 'dbaston', 'wsim_erdc', 'inputs'), list(...)))
  #do.call(load, append(list('/mnt', 'fig', 'WSIM', 'WSIM_source_V1.2'), list(...)))
}

loadSci <- function(...) {
  do.call(load, append(list('/home', 'dbaston', 'SCI'), list(...)))
}

loadIniData <- function(...) {
  do.call(load, append(list('/home', 'dbaston', 'IniData'), list(...)))
}

loadNcep <- function(...) {
  do.call(load, append(list('/home', 'dbaston', 'NCEP'), list(...)))
}

doIt <- function() {
  static <- list()
  static$daylength <- loadSource('Daylength', 'FLT', 'daylength-halfdeg-201705.flt')
  static$flow_directions <- loadSource('UNH_Data', 'g_network.asc')
  static$elevation <- loadSource('SRTM30', 'elevation_half_degree.img')
  static$area_m2 <- loadSource('area_hlf_deg.img') * 1e6
  static$Wc <- loadSource('HWSD', 'hwsd_tawc_05deg_noZeroNoVoids.img')

  # State data
  state <- list()
  state$snowpack <- loadIniData('Snowpack_in_trgt201705.img')
  state$Ws <- loadIniData('Ws_in_trgt201705.img')
  state$Dr <- loadIniData('Dr_in_trgt201705.img')
  state$Ds <- loadIniData('Ds_in_trgt201705.img')

  t_minus_1 <- loadSci('T_trgt201704.img')
  t_minus_2 <- loadSci('T_trgt201703.img')
  state$snowmelt_month <- (t_minus_1 > -1) + (t_minus_1 > -1 & t_minus_2 > -1)

  # Forcing data
  forcing <- list()
  forcing$T <- loadNcep('CPC_Leaky_T_201705.FLT')#, nodata=-999)
  forcing$Pr <- loadNcep('CPC_Leaky_P_201705.FLT')#, nodata=-999)
  forcing$nDays <- 31 # TODO get this automatically
  forcing$pWetDays <- loadNcep('pWetDays_201705.img')#, nodata=-32768.0)

  iter <- wsim.lsm::run(static, state, forcing)

  pdf(file='/home/dbaston/lsm_compare.pdf')
  for (key in names(iter$obs)) {
    print(key)
    r <- iter$obs[[key]]
    raster::writeRaster(r, paste0('/home/dbaston/2_', key, '.img'), overwrite=TRUE)
    compare(key)
  }

  dev.off()
}

#doIt()

