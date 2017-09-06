#' Read all variables from a netCDF file
#'
#' @param fname Filename to open
#' @return A list having the following structure:
#' \describe{
#' \item{attrs}{a list of global attributes in the file}
#' \item{}
#' }
#' @export
read_vars_from_cdf <- function(fname) {
  cdf <- ncdf4::nc_open(fname)

  lats <- ncdf4::ncvar_get(cdf, "lat")
  lons <- ncdf4::ncvar_get(cdf, "lon")

  dlat <- abs(lats[2] - lats[1])
  dlon <- abs(lons[2] - lons[1])

  extent <- c(min(lons) - dlon/2,
              max(lons) + dlon/2,
              min(lats) - dlat/2,
              max(lats) + dlat/2)

  global_attrs <- ncdf4::ncatt_get(cdf, 0)

  data <- lapply(cdf$var, function(var) {
    d <- t(ncdf4::ncvar_get(cdf, var$name))
    attrs <- ncdf4::ncatt_get(cdf, var$name)
    for (k in names(attrs)) {
      attr(d, k) <- attrs[[k]]
    }

    return(d)
  })

  ncdf4::nc_close(cdf)

  return(list(
    attrs= global_attrs,
    data= data,
    extent= extent
  ))
}
