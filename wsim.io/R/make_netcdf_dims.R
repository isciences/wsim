#' Create netCDF dimensions
#'
#' @inheritParams write_vars_to_cdf
#' @param unlimited_dims character vector of dimension names which should
#'                       be created as unlimited
#' @return list of \code{ncdim4} objects
#'
make_netcdf_dims <- function(vars, extent, ids, extra_dims, unlimited_dims=NULL) {
  c(make_netcdf_base_dims(vars, extent, ids, unlimited_dims),
    make_netcdf_extra_dims(extra_dims, unlimited_dims))
}

make_netcdf_base_dims <- function(vars, extent, ids, unlimited_dims=NULL) {
  is_spatial <- is.null(ids)

  if (is_spatial) {
    lats <- lat_seq(extent, dim(vars[[1]]))
    lons <- lon_seq(extent, dim(vars[[1]]))

    return(list(
      lon = ncdf4::ncdim_def("lon",
                             units="degrees_east",
                             vals=lons,
                             longname="Longitude",
                             create_dimvar=TRUE,
                             unlim="lon" %in% unlimited_dims),
      lat = ncdf4::ncdim_def("lat",
                             units="degrees_north",
                             vals=lats,
                             longname="Latitude",
                             create_dimvar=TRUE,
                             unlim="lat" %in% unlimited_dims)
    ))
  } else {
    if (mode(ids) == 'character') {
      # The R ncdf4 library does not support proper netCDF 4 strings. So we do it the
      # old-school way, with fixed-length character arrays. Data written in this
      # way seems to be interpreted correctly by software such as QGIS.
      return(list(
        id = ncdf4::ncdim_def("id",
                              units="",
                              vals=1:length(ids),
                              create_dimvar=FALSE,
                              unlim="id" %in% unlimited_dims)
      ))
    } else {
      # integer ids
      return(list(
        id = ncdf4::ncdim_def("id",
                              units="",
                              vals=ids,
                              create_dimvar=TRUE,
                              unlim="id" %in% unlimited_dims)
      ))
    }
  }
}

make_netcdf_extra_dims <- function(extra_dims, unlimited_dims=NULL) {
  extra_ncdf_dims <- list()

  for (dimname in names(extra_dims)) {
    vals <- extra_dims[[dimname]]
    unlim <- dimname %in% unlimited_dims

    if (mode(vals) == 'character') {
      new_dim <- ncdf4::ncdim_def(dimname, units='', vals=1:length(vals), create_dimvar=FALSE, unlim=unlim)
    } else {
      new_dim <- ncdf4::ncdim_def(dimname, units='', vals=vals, create_dimvar=TRUE, unlim=unlim)
    }
    extra_ncdf_dims[[dimname]] <- new_dim
  }

  return(extra_ncdf_dims)
}
