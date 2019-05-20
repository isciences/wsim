#!/usr/bin/env Rscript

'
Process GLDAS NOAH monthly land surface model results to input to WSIM.

Usage: gldas_noah_extract (--input=<file>) (--output=<file>)

--input <file>        GLDAS NOAH source file (netCDF)
--output <file>       Output netCDF file with WSIM-friendly parameters
' -> usage

# GLDAS 2.0 NOAH parameters

# *** Note that kg/m2 of water is equivalent to mm of water ***
#   #   kg      1000g       cm^3       m^2         10mm
#   # ----- X ---------- X ----- X ------------ X ------ = mm
#   #  m^2       kg          g      10000 cm^2     1cm



convert_w_msquared2mm_d <- function(watts_per_m2){
  # converts from  W m-2 to mm day-1
  #
  #  W      J         kg           m^3        1000 mm    86400 sec     mm
  # --- X ------ X ---------- X  --------- X -------- X ----------- = ----
  # m^2    W sec   2.5*10^6 J     1000 kg      1m          day       day

  # (FAO, 1998. Crop evapotranpiration - Guidelines for computing crop water
  #  requirements -- FAO Irrigation and drainage paper 56. Table 1.
  # http://www.fao.org/3/x0490e/x0490e04.htm#chapter%201%20%20%20introduction%20to%20evapotranspiration )
  #
  # And LDAS FAQs: https://ldas.gsfc.nasa.gov/faq/ldas

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
  #   m^2     kg     10000 cm^2       g          cm             8 3hr
  #  ____________________________________________________ X  __________
  #                     3hr                                      day
  #

  mm_per_day <- kg_per_m2_per_3hr * 8
  return(mm_per_day)
}





main <- function(raw_args){
  args <- wsim.io::parse_args(usage=usage, args=raw_args)

  fname <- args$input
  outfile <- args$output

  if (!wsim.io::can_write(outfile)) {
    wsim.io::die_with_message("Cannot open", outfile, "for writing.")
  }

  monthdays <- wsim.gldas::get_ndays_from_fname(fname)
  gldas_list <- wsim.io::read_vars_from_cdf(fname)

  # Create new raster layers using arithmetic on the raster brick
  T         <- gldas_list$data$Tair_f_inst - 273.15
  Pr        <- converth2o_kg_msquared_s2mm_day(gldas_list$data$Rainf_f_tavg)*monthdays
  # "Evap" is equivalent to evapotranspiration, and
  # "PotEvap" is equivalent to PET, as described in the
  # Land Information System (LIS) Users' Guide 7.2 (May 2017)
  # https://modelingguru.nasa.gov/servlet/JiveServlet/previewBody/2634-102-1-6531/LIS_usersguide.pdf
  potevaptr <- convert_w_msquared2mm_d(gldas_list$data$PotEvap_tavg)*monthdays
  actevaptr <- converth2o_kg_msquared_s2mm_day(gldas_list$data$Evap_tavg)*monthdays
  PETmE     <- potevaptr - actevaptr
  RO_mm     <- converth20_kg_msquared_3hour2mm_day(gldas_list$data$Qs_acc)*monthdays +
    converth20_kg_msquared_3hour2mm_day(gldas_list$data$Qsb_acc)*monthdays +
    converth20_kg_msquared_3hour2mm_day(gldas_list$data$Qsm_acc)*monthdays

  # Soil moisture is in kg m-2, which == mm for water
  #Ws <- (0.1*gldas_list$data$SoilMoi0_10cm_inst+0.3*gldas_list$data$SoilMoi10_40cm_inst+0.6*gldas_list$data$SoilMoi40_100cm_inst)
  Ws <- (gldas_list$data$SoilMoi0_10cm_inst + gldas_list$data$SoilMoi10_40cm_inst + gldas_list$data$SoilMoi40_100cm_inst)

  # Create list of matrices and write to netCDF
  gldas_newmats <- list(T=T, Pr=Pr, PETmE=PETmE, RO_mm=RO_mm, Ws=Ws)

  # Write to file
  wsim.io::write_vars_to_cdf(vars=gldas_newmats, filename=outfile, extent=gldas_list$extent)
}


tryCatch(main(commandArgs(TRUE)), error=wsim.io::die_with_message)
