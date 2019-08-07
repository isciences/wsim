make_netcdf_dims <- function(extent, ids, dims=NULL) {
  if (is.null(ids)) {
    lats <- lat_seq(extent, dims)
    lons <- lon_seq(extent, dims)

    return(list(
      ncdf4::ncdim_def("lon", units="degrees_east", vals=lons, longname="Longitude", create_dimvar=TRUE),
      ncdf4::ncdim_def("lat", units="degrees_north", vals=lats, longname="Latitude", create_dimvar=TRUE)
    ))
  } else {
    if (mode(ids) == 'character') {
      # The R ncdf4 library does not support proper netCDF 4 strings. So we do it the
      # old-school way, with fixed-length character arrays. Data written in this
      # way seems to be interpreted correctly by software such as QGIS.
      return(list(
        ncdf4::ncdim_def("id", units="", vals=1:length(ids), create_dimvar=FALSE)
      ))
    } else {
      # integer ids
      return(list(
        ncdf4::ncdim_def("id", units="", vals=ids, create_dimvar=TRUE)
      ))
    }
  }
}



