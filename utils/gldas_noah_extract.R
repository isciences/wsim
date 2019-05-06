#!/usr/bin/env Rscript

'
Process GLDAS NOAH monthly land surface model results to input to WSIM.

Usage: gldas_noah_extract (--input=<file>) (--output=<file>) [--cores=<num>]...

--input <file>        GLDAS NOAH source file (netCDF)
--output <file>       Output netCDF file with WSIM-friendly parameters
' -> usage

# GLDAS 2.0 NOAH parameters

# *** Note that kg/m2 of water is equivalent to mm of water ***
#   #   kg      1000g       cm^3       m^2         10mm
#   # ----- X ---------- X ----- X ------------ X ------
#   #  m^2       kg          g      10000 cm^2     1cm

n_days_in_month <- function(month_num){
  days <- c(31, 28, 31, 30, # jan, feb, mar, apr
            31, 30, 31, 31, # may, jun, jul, aug
            30, 31, 30, 31  # sep, oct, nov, dec
            )
  return(days[month_num])
}

convert_w_msquared2mm_d <- function(watts_per_m2){
  # converts from  W m-2 to mm day-1
  #
  #  W        kg         J       m^3    1000mm    86400 sec     mm
  # --- X ---------- X ----- X ------ X ------ X ----------- = ----
  # m^2   2.5*10^6 J   W sec   1000kg    1m          day       day

  mm_per_day <- watts_per_m2 / (2.5e6) * 86400
  return(mm_per_day)
}



converth2o_kg_msquared_s2mm_day <- function(kg_per_m2_per_s){
  # Converts from kg water m-2 sec-1 to mm day-1
  #
  #   kg     1000g      m^2          cm^3       10 mm
  #  ---- X ------ X ---------- X ---------- X --------
  #   m^2     kg     10000 cm^2       g          cm           86400 sec
  #  ____________________________________________________ X  ___________
  #                     sec                                      day
  #

  mm_per_day <- kg_per_m2_per_s * 86400
  return(mm_per_day)
}



converth20_kg_msquared_3hour2mm_day <- function(kg_per_m2_per_3hr){
  # Converts from kg water m-2 (3hour)-1 to mm day-1
  #
  #   kg     1000g      m^2          cm^3       10 mm
  #  ---- X ------ X ---------- X ---------- X --------
  #   m^2     kg     10000 cm^2       g          cm             8*3hr
  #  ____________________________________________________ X  ___________
  #                     3hr                                      day
  #

  mm_per_day <- kg_per_m2_per_3hr * 8
  return(mm_per_day)
}


get_ndays_from_fname <- function(raster_fname){
  fname_regex <- regexpr('[0-9]{6}', raster_fname)
  yearmon <- substr(raster_fname, start = fname_regex[1], stop = fname_regex[1] + attr(fname_regex, 'match.length') - 1)
  # Kind of interesting that this works:
  stopifnot(substr(yearmon, 1, 2) %in% 19:20 & substr(yearmon, 5,6) %in% sprintf("%02d",1:12))
  monthnum <- as.integer(substr(yearmon, 5, 6))

  return(n_days_in_month(monthnum))
}


main <- function(raw_args){
  args <- wsim.io::parse_args(usage=usage, args=raw_args)

  fname <- args$input
  outfile <- args$output

  if (!wsim.io::can_write(outfile)) {
    wsim.io::die_with_message("Cannot open", outfile, "for writing.")
  }

  monthdays <- get_ndays_from_fname(fname)
  gldas_list <- wsim.io::read_vars_from_cdf(fname)

  # Create new raster layers using arithmetic on the raster brick
  T         <- gldas_list$data$Tair_f_inst - 273.15
  Pr        <- converth2o_kg_msquared_s2mm_day(gldas_list$data$Rainf_f_tavg)*monthdays
  potevaptr <- convert_w_msquared2mm_d(gldas_list$data$PotEvap_tavg)*monthdays
  actevaptr <- converth2o_kg_msquared_s2mm_day(gldas_list$data$Evap_tavg)*monthdays
  PETmE     <- potevaptr - actevaptr
  RO_mm     <- converth20_kg_msquared_3hour2mm_day(gldas_list$data$Qs_acc)*monthdays +
    converth20_kg_msquared_3hour2mm_day(gldas_list$data$Qsb_acc)*monthdays +
    converth20_kg_msquared_3hour2mm_day(gldas_list$data$Qsm_acc)*monthdays

  # Soil moisture is in kg m-2, which == mm for water
  Ws <- (0.1*gldas_list$data$SoilMoi0_10cm_inst+0.3*gldas_list$data$SoilMoi10_40cm_inst+0.6*gldas_list$data$SoilMoi40_100cm_inst)

  # Stack up the new layers
  gldas_newmats <- list(T, Pr, PETmE, RO_mm, Ws)
  names(gldas_newmats) <- c('T', 'Pr', 'PETmE', 'RO_mm', 'Ws')

  # Write to file
  wsim.io::write_vars_to_cdf(vars=gldas_newmats, filename=outfile, extent=gldas_list$extent)
  #tst <- wsim.io::read_vars_from_cdf(outfile)

}


tryCatch(main(commandArgs(TRUE)), error=wsim.io::die_with_message)
