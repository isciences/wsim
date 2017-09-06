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
 #actual <- raster::raster(paste0('/home/dbaston/SCI/', param, '_trgt', date, '.img'))

 loader <- ifelse(endsWith(param, '_in'), loadIniData, loadSci)

 actual <- raster::raster(loader(param, paste0(param, '_trgt', date, '.img')))
 #actual <- raster::raster(paste0('/mnt/fig/WSIM/WSIM_home/dbaston/SCI/', param, '_trgt', date, '.img'))

 max_diff <- raster::cellStats(abs(actual-test), 'max')

 tm <- raster::as.matrix(test)
 am <- raster::as.matrix(actual)
 errors <- raster::setValues(test, ifelse( abs(tm - am) < 1e-3 , NA, (tm - am) / am))

 graphics::par(mfrow=c(2,2), oma=c(0,0,2,0))
 raster::plot(test)
 graphics::title('test result')
 raster::plot(actual)
 graphics::title('Past result')
 raster::plot(abs(errors))
 graphics::title('abs(test-result)/result')
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
  path
  #raster::raster(path)
}

loadSource <- function(...) {
  do.call(load, append(list('/home', Sys.info()[["user"]], 'wsim_erdc', 'inputs'), list(...)))
  #do.call(load, append(list('/mnt', 'fig', 'WSIM', 'WSIM_source_V1.2'), list(...)))
}

loadSci <- function(...) {
  #do.call(load, append(list('/home', 'dbaston', 'SCI'), list(...)))
  do.call(load, append(list('/home', Sys.info()[["user"]], 'wsim_erdc', 'derived', 'Observed', 'SCI'), list(...)))
  #do.call(load, append(list('/mnt', 'fig', 'WSIM', 'WSIM_derived_V1.2', 'Observed', 'SCI'), list(...)))
}

loadIniData <- function(...) {
  #do.call(load, append(list('/mnt', 'fig', 'WSIM', 'WSIM_source_V1.2', 'IniData'), list(...)))
  do.call(load, append(list('/home', Sys.info()[["user"]], 'wsim_erdc', 'inputs', 'IniData'), list(...)))
  #do.call(load, append(list('/home', 'dbaston', 'IniData'), list(...)))
}

loadNcep <- function(...) {
  do.call(load, append(list('/home', Sys.info()[["user"]], 'wsim_erdc', 'inputs', 'NCEP'), list(...)))
  #do.call(load, append(list('/home', 'dbaston', 'NCEP'), list(...)))
}

daysInMonth <- function(date) {
  first_day <- as.Date(paste0(date, '01'), '%Y%m%d')
  return(unname(lubridate::days_in_month(first_day)))
}

previousMonth <- function(date) {
  first_day_of_current_month <- as.Date(paste0(date, '01'), '%Y%m%d')
  last_day_of_previous_month <- first_day_of_current_month - 1
  return(strftime(last_day_of_previous_month, '%Y%m'))
}

nextMonth <- function(date) {
  first_day_of_current_month <- as.Date(paste0(date, '01'), '%Y%m%d')
  return(strftime(first_day_of_current_month + daysInMonth(date), '%Y%m'))
}

forcingForDate <- function(date) {
  year <- substr(date, 1, 4)

  files <- list(
      extent=c(-180, 180, -90, 90),
      T=loadSource('NCEP', 'T', paste0('CPC_Leaky_T_', date, '.FLT')),
      daylength=loadSource('Daylength', 'FLT', paste0('daylength-halfdeg-', date, '.flt')),
      Pr=loadSource('NCEP', 'P', paste0('CPC_Leaky_P_', date, '.FLT')),
      pWetDays=loadSource('NCEP', 'Daily_precip', 'Adjusted', year, paste0('pWetDays_', date, '.img'))
  )

  do.call(wsim.lsm::make_forcing, lapply(files, wsim.io::load_matrix))
}

stateForDate <- function(date) {
  state <- list()
  state$extent <- c(-180, 180, -90, 90)
  state$Snowpack <- loadIniData('Snowpack_in', paste0('Snowpack_in_trgt', date, '.img'))
  state$Ws <- loadIniData('Ws_in', paste0('Ws_in_trgt', date, '.img'))
  state$Dr <- loadIniData('Dr_in', paste0('Dr_in_trgt', date, '.img'))
  state$Ds <- loadIniData('Ds_in', paste0('Ds_in_trgt', date, '.img'))
  state$yearmon <- date

  prev1 <- previousMonth(date)
  prev2 <- previousMonth(prev1)

  t_minus_1 <- raster::raster(loadSci('T', paste0('T_trgt', prev1, '.img')))
  t_minus_2 <- raster::raster(loadSci('T', paste0('T_trgt', prev2, '.img')))
  state$snowmelt_month <- (t_minus_1 > -1) + (t_minus_1 > -1 & t_minus_2 > -1)

  return(do.call(make_state, lapply(state, wsim.io::load_matrix)))
}

saveIter <- function(iter_number, iter) {
  date <- iter$forcing$date
  fname <- paste0('/home/', Sys.info()[["user"]], '/wsim_output/lsm_', date, '.rds')
  saveRDS(iter, file=fname)

  cat(date, '\n')
}

plotIter <- function(iter_number, iter) {
  date <- previousMonth(iter$next_state$yearmon)

  if (!endsWith(date, "01")) {
    #return();
  }

  fname <- paste0('/home/', Sys.info()[["user"]], '/lsm_cpp_compare_', date, '.pdf')
  pdf(file=fname)
  cat('Writing ', fname, '\n')

  for (vartype in c("obs", "next_state")) {
    for (key in names(iter[[vartype]])) {
      if (key %in% c('dayLength', 'yearmon')) {
        next
      }

      cat(vartype, ":", key, "\n")
      r <- iter[[vartype]][[key]]

      if (vartype == "next_state") {
        #key <- paste0(key, "_in")
        filedate <- nextMonth(date)
        #filedate <- date
      } else {
        filedate <- date
      }

      if (vartype == "next_state") {
        key <- paste0(key, '_in')
      }

      raster::writeRaster(r, paste0('/tmp/',
                                    key,
                                    '_',
                                    filedate,
                                    '.img'), datatype='FLT4S', overwrite=TRUE)
      if (!startsWith(key, 'snowmelt_month')) {
        compare(filedate, key)
      }
    }
  }

  dev.off()
}

loadStatic <- function() {
  static <- list()
  static$flow_directions <- loadSource('UNH_Data', 'g_network.asc')
  static$elevation <- loadSource('SRTM30', 'elevation_half_degree.img')
  static$Wc <- loadSource('HWSD', 'hwsd_tawc_05deg_noZeroNoVoids.img')

  return(static)
}

monthly_timesteps <- function(years) {
  months <- sprintf("%02d", 1:12)

  steps <- c()
  for (year in years) {
    for (month in months) {
      steps <- c(steps, paste0(year, month))
    }
  }

  return(steps)
}

doIt <- function(times) {
  static <- loadStatic()

  if (nchar(times[1]) == 4) {
    # Run entire years
    #years <- as.character(times)
    timesteps <- monthly_timesteps(times)
  } else {
    timesteps <- times
    timesteps <- c(previousMonth(timesteps[1]), timesteps)
    timesteps <- c(previousMonth(timesteps[1]), timesteps)
  }

  # State data
  state <- stateForDate(timesteps[3])

  # Forcing data
  forcing <- lapply(timesteps[-c(1,2)], forcingForDate) # drop first two timesteps that we needed to get snowmelt month
  cat('Preparing to run', length(forcing), 'timesteps.\n')

  wsim.lsm::run_with_rasters(static, state, forcing, iter_fun=saveIter)
}

#doIt(1980:1981)
#plotIter(0, readRDS('/home/dan/wsim_output/lsm_198110.rds'))

lookup <- function(rast, x, y) {
  if (class(rast) != "RasterLayer")
    rast <- raster::raster(rast)
  raster::values(rast)[raster::cellFromXY(rast, matrix(c(x, y), nrow=1))]
}

make_state_cdf <- function(yearmon) {
  s <- stateForDate(yearmon)
  wsim.lsm::write_state_to_cdf(s,
                               paste0('/tmp/wsim_init_', yearmon, '.nc'),
                               wsim.lsm::cdf_attrs)
}

make_forcing_cdfs <- function(years) {
  dates <- monthly_timesteps(years)

  for (date in dates) {
    forcing <- forcingForDate(date)
    cat(date, '\n')

    fname <- paste0('/home/dbaston/wsim_forcing/forcing_', date, '.nc')

    wsim.io::write_vars_to_cdf(forcing[c("daylength", "pWetDays", "T", "Pr")],
                               forcing$extent[1],
                               forcing$extent[2],
                               forcing$extent[3],
                               forcing$extent[4],
                               fname,
                               list())
  }
}

