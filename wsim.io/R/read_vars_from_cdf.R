#' Read all variables from a netCDF file
#'
#' @inheritParams parse_vardef
#' @param vars A list of variables to read.  If NULL (default),
#'             all variables will be read.
#' @return structure described in \code{\link{read_vars}}
#' @export
read_vars_from_cdf <- function(vardef, vars=as.character(c())) {
  def <- parse_vardef(vardef)
  fname <- def$filename
  if (is.character(vars)) {
    vars <- lapply(vars, parse_var)
  }

  vars <- c(vars, def$vars)

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

  if (is.null(vars) || length(vars) == 0) {
    vars <- lapply(
      Filter(function(var) {
        var$ndims > 0
      },
      cdf$var), function(var) {
        make_var(var$name)
    })
  }

  for (var in cdf$var) {
    if (var$ndims > 0) {
      # Read this as a regular variable
      for (var_to_load in vars) {
        if (var_to_load$var_in == var$name) {
          d <- t(ncdf4::ncvar_get(cdf, var$name))
          attrs <- ncdf4::ncatt_get(cdf, var$name)
          for (k in names(attrs)) {
            attr(d, k) <- attrs[[k]]
          }

          data[[var_to_load$var_out]] <- perform_transforms(d, var_to_load$transforms)
        }
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
