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

compare <- function(date, param) {
 test <- raster::raster(paste0('/tmp/', param, '_', date, '.img'))
 actual <- raster::raster(paste0('/home/dbaston/SCI/', param, '_trgt', date, '.img'))

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
   " ",
   date,
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
  static$flow_directions <- loadSource('UNH_Data', 'g_network.asc')
  static$elevation <- loadSource('SRTM30', 'elevation_half_degree.img')
  static$area_m2 <- loadSource('area_hlf_deg.img') * 1e6
  static$Wc <- loadSource('HWSD', 'hwsd_tawc_05deg_noZeroNoVoids.img')

  # State data
  state <- list()
  state$Snowpack <- loadIniData('Snowpack_in_trgt201703.img')
  state$Ws <- loadIniData('Ws_in_trgt201703.img')
  state$Dr <- loadIniData('Dr_in_trgt201703.img')
  state$Ds <- loadIniData('Ds_in_trgt201703.img')

  t_minus_1 <- loadSci('T_trgt201702.img')
  t_minus_2 <- loadSci('T_trgt201701.img')
  state$snowmelt_month <- (t_minus_1 > -1) + (t_minus_1 > -1 & t_minus_2 > -1)

  # Forcing data
  forcing <- list(
    list(
      T=loadNcep('CPC_Leaky_T_201703.FLT'),
      daylength=loadSource('Daylength', 'FLT', 'daylength-halfdeg-201703.flt'),
      Pr=loadNcep('CPC_Leaky_P_201703.FLT'),
      pWetDays=loadNcep('pWetDays_201703.img'),
      nDays=31
    )
    ,list(
      T=loadNcep('CPC_Leaky_T_201704.FLT'),
      daylength=loadSource('Daylength', 'FLT', 'daylength-halfdeg-201704.flt'),
      Pr=loadNcep('CPC_Leaky_P_201704.FLT'),
      pWetDays=loadNcep('pWetDays_201704.img'),
      nDays=30
    )
    ,list(
      T=loadNcep('CPC_Leaky_T_201705.FLT'),
      daylength=loadSource('Daylength', 'FLT', 'daylength-halfdeg-201705.flt'),
      Pr=loadNcep('CPC_Leaky_P_201705.FLT'),
      pWetDays=loadNcep('pWetDays_201705.img'),
      nDays=31
    )
  )

  wsim.lsm::run_with_rasters(static, state, forcing, iter_fun=function(iter_number, iter) {
    dates = list('201703', '201704', '201705', '201706')
    pdf(file=paste0('/home/dbaston/lsm_cpp_compare_', dates[[iter_number]], '.pdf'))


    for (vartype in names(iter)) {
      for (key in names(iter[[vartype]])) {
        if (key != 'snowmelt_month') {
          cat(vartype, ":", key, "\n")
          r <- iter[[vartype]][[key]]

          if (vartype == "next_state") {
            key <- paste0(key, "_in")
            date <- dates[[iter_number + 1]]
          } else {
            date <- dates[[iter_number]]
          }

          raster::writeRaster(r, paste0('/tmp/',
                                        key,
                                        '_',
                                        date,
                                        '.img'), datatype='FLT4S', overwrite=TRUE)
          compare(date, key)
        }
      }
    }

    dev.off()
  })

}

#doIt()

