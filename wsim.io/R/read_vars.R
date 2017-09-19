#' Read one or more variables from raster files
#'
#' @inheritParams parse_vardef
#'
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
#'
#' @export
read_vars <- function(vardef) {
  if(grepl('.nc', vardef, fixed=TRUE)) {
    return(read_vars_from_cdf(vardef))
  }

  def <- parse_vardef(vardef)

  if (length(def$vars) == 0) {
    def$vars <- list(make_var("1"))
  }

  loaded <- list(
    attrs= list(),
    data= list(),
    extent= NULL
  )

  if (endsWith(def$filename, '.mon')) {
    # .mon files are global
    loaded$extent <- c(-180, 180, -90, 90)
  }

  for (var in def$vars) {
    if (is.null(loaded$extent)) {
      info <- rgdal::GDALinfo(def$filename, returnStats=FALSE, silent=TRUE)
      dx <- info[["res.x"]]
      dy <- info[["res.y"]]
      xmin <- info[["ll.x"]]
      ymin <- info[["ll.y"]]

      loaded$extent <- c(xmin,
                         xmin + dx*info[["columns"]],
                         ymin,
                         ymin + dy*info[["rows"]])

    }

    if (endsWith(def$filename, '.mon')) {
      vals <- read_mon_file(def$filename)
    } else {
      rast <- rgdal::GDAL.open(def$filename, read.only=TRUE)

      vals <- t(rgdal::getRasterData(rast,
                                     band=as.integer(var$var_in)))
      rgdal::GDAL.close(rast)
    }

    loaded$data[[var$var_out]] <- perform_transforms(vals, var$transforms)
  }

  return(loaded)
}
