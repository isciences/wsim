convert_w_msquared2mm_d <- function(watts_per_m2){
  # converts from  W m-2 to mm day-1
  #
  #  W      J         kg           m^3       1000mm    86400 sec     mm
  # --- X ------ X ---------- X  -------- X ------- X ----------- = ----
  # m^2    W sec   2.5*10^6 J     1000kg      1m          day       day

  # (FAO, 1998. Crop evapotranpiration - Guidelines for computing crop water
  #  requirements -- FAO Irrigation and drainage paper 56. Table 1.
  # http://www.fao.org/3/x0490e/x0490e04.htm#chapter%201%20%20%20introduction%20to%20evapotranspiration )

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
  #  ____________________________________________________ X  __________
  #                     3hr                                      day
  #

  mm_per_day <- kg_per_m2_per_3hr * 8
  return(mm_per_day)
}


get_ndays_from_fname <- function(raster_fname){
  fname_regex <- regexpr('[0-9]{6}', raster_fname)
  yyyymm       <- substr(raster_fname,
                         start = fname_regex[1],
                         stop = fname_regex[1] + attr(fname_regex, 'match.length') - 1)
  if(!(substr(yyyymm, 1, 2) %in% 19:20) | !(substr(yyyymm, 5,6) %in% sprintf("%02d",1:12))){
    stop("Failed to detect date from filename; cannot determine number of days in month for file ", raster_fname)
  }

  return(wsim.lsm::days_in_yyyymm(yyyymm))
}
