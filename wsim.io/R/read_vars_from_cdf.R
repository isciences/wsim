#' Read all variables from a netCDF file
#'
#' @param fname Filename to open.  Optionally, the filename string
#'              may be suffixed by "::", followed by a comma-separated
#'              list of variables to read.
#' @param vars A list of variables to read.  If NULL (default),
#'             all variables will be read.
#' @return A list having the following structure:
#' \describe{
#' \item{attrs}{a list of global attributes in the file}
#' \item{data}{a list of matrices containing data for each
#'             variable in the file.  Matrices are consistent
#'             with the "raster" package, with rows representing
#'             decreasing latitude and columns representing
#'             increasing longitude.  Any netCDF attributes defined
#'             for the variables will be attached as attributes of the
#'             matrix.}
#' \item{extent}{the extent of the lat/lon coordinates for the data,
#'               in the order xmin, xmax, ymin, ymax}
#' }
#' @export
read_vars_from_cdf <- function(fname, vars=NULL) {
  # Parse a filename in the form of "mydata.cdf::var1,var2"
  # Add any vars found by this method to the list of vars
  split_fname <- strsplit(fname, '::', fixed=TRUE)[[1]]
  fname <- split_fname[1]
  if (length(split_fname) == 2) {
    vars <- c(vars, strsplit(split_fname[2], ',', fixed=TRUE)[[1]])
  }

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

  data <- list()
  for (var in cdf$var) {
    if (var$ndims > 0) {
      # Read this as a regular variable
      if (is.null(vars) || var$name %in% vars) {
        d <- t(ncdf4::ncvar_get(cdf, var$name))
        attrs <- ncdf4::ncatt_get(cdf, var$name)
        for (k in names(attrs)) {
          attr(d, k) <- attrs[[k]]
        }

        data[[var$name]] <- d
      }
    } else {
      # This variable has no dimensions, and is
      # only used to store attributes.  Read the
      # attributes and put them in with the global
      # attributes.

      var_attrs <- ncdf4::ncatt_get(cdf, var$name)
      global_attrs[[var$name]] <- var_attrs
    }
  }

  ncdf4::nc_close(cdf)

  return(list(
    attrs= global_attrs,
    data= data,
    extent= extent
  ))
}
