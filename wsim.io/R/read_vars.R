#' Read one or more variables from raster files
#'
#' @inheritParams parse_vardef
#'
#' @param nvars If specified, \code{read_vars} will throw an error
#'              unless exactly \code{nvars} variables are read from
#'              the file.
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
read_vars <- function(vardef, nvars=NULL) {
  def <- parse_vardef(vardef)

  if(endsWith(def$filename, '.nc')) {
    loaded <- read_vars_from_cdf(vardef)
    check_nvars(def, loaded, nvars)
    return(loaded)
  }

  if (length(def$vars) == 0) {
    def$vars <- list(make_var("1"))
  }

  loaded <- list(
    attrs= list(),
    data= list(),
    extent= NULL
  )

  if (is_mon(def$filename) || is_ncep_daily_precip(def$filename)) {
    # .mon and precip files are global
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

    if (is_mon(def$filename)) {
      vals <- read_mon_file(def$filename)
    } else if (is_ncep_daily_precip(def$filename)) {
      # Ugly special case: a file of global half-degree precipitation from NCEP
      #
      # Because these files are shipped with malformed *.ctl files (that assume the .RT files are in
      # a path on a NOAA server somewhere) we can't convert them to a standard format like netCDF
      # without fudging our own .ctl file.
      #
      vals <- read_ncep_daily_precip(def$filename)
    } else {
      rast <- rgdal::GDAL.open(def$filename, read.only=TRUE)

      vals <- t(rgdal::getRasterData(rast,
                                     band=as.integer(var$var_in)))
      rgdal::GDAL.close(rast)
    }

    loaded$data[[var$var_out]] <- perform_transforms(vals, var$transforms)
  }

  check_nvars(def, loaded, nvars)
  return(loaded)
}

check_nvars <- function(def, data, nvars) {
  if (is.null(nvars) || length(data$data) == nvars) {
    return()
  }

  stop("Expected to read exactly ",
       nvars, " variable", ifelse(nvars==1, "", "s"),
       " from ", def$filename,
       " (got ", length(data$data), ")")
}

is_mon <- function(fname) {
  endsWith(fname, '.mon')
}

is_ncep_daily_precip <- function(fname) {
  endsWith(fname, '.RT') && startsWith(basename(fname), 'PRCP_CU_GAUGE_V1.0GLB_0.50deg')
}
