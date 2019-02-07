# Copyright (c) 2018-2019 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Read one or more variables from raster files
#'
#' @inheritParams parse_vardef
#'
#' @param expect.nvars  If specified, \code{read_vars} will throw an
#'                      error unless exactly \code{expect.nvars}
#'                      variables are read from the file.
#' @param expect.dims   If specified, \code{read_vars} will throw an
#'                      error if dimensions of read data are not
#'                      equal to \code{expect.dims}.
#' @param expect.extent If specified, \code{read_vars} will throw an
#'                      error if extent of read data is not exactly
#'                      \code{expect.extent}.
#' @param expect.ids    If specified, \code{read_vars} will throw an
#'                      error if ids of read data are not exactly
#'                      and in the same order as \code{expect.ids}.
#' @param offset        Specifies dimension-wise (X, Y, ...) offsets
#'                      from the upper-left corner of the raster
#'                      (xmin, ymax) from which reading should begin.
#'                      A value of c(1,1) refers to the corner cell
#'                      itself (i.e., there is no offset). This
#'                      follows the convention of the \code{ncdf4}
#'                      package. If \code{offset} is specified, then
#'                      \code{count} must also be specified.
#' @param count         Specifies dimension-wise (X, Y, ...) numbers of
#'                      cells to read, beginning at the origin cell
#'                      specified by \code{offset}. A value of \code{-1}
#'                      signifies that all values after the origin cell
#'                      should be read. If \code{count} is specified, then
#'                      \code{origin} must also be specified.
#' @param as.data.frame If \code{TRUE}, \code{read_vars} will return a
#'                      data frame
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
#'               in the order xmin, xmax, ymin, ymax. Will be null if
#'               the data is not gridded}
#' \item{ids}{a vector of integer ids for the data. Will be null if
#'            the data is gridded}
#' }
#'
#' @export
read_vars <- function(vardef, expect.nvars=NULL, expect.dims=NULL, expect.extent=NULL, expect.ids=NULL, offset=NULL, count=NULL, as.data.frame=FALSE) {
  stopifnot(
    (is.character(vardef) && length(vardef) == 1)
    || is.wsim.io.vardef(vardef))

  def <- parse_vardef(vardef)

  if(!file.exists(def$filename)) {
    stop('File ', def$filename, ' does not exist.')
  }

  if (isTRUE(as.data.frame) && !endsWith(def$filename, '.nc')) {
    # Data frame output only supported for netCDF
    stop('Only non-spatial data in netCDF files can be read to a data frame.')
  }

  if(endsWith(def$filename, '.nc')) {
    loaded <- read_vars_from_cdf(vardef, offset=offset, count=count, as.data.frame=as.data.frame)

    check_extent(def, loaded, expect.extent)
    check_ids(def, loaded, expect.ids)

    if (!is.null(expect.dims)) {
      if(as.data.frame) {
        stop("Can't check dimensions of data loaded to data frame.")
      }

      check_dims(def, loaded, expect.dims)
    }

    if (!is.null(expect.nvars)) {
      if (as.data.frame) {
        stop("Can't check number of variables in data loaded to data frame.")
      }

      check_nvars(def, loaded, expect.nvars)
    }

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
      nx <- info[["columns"]]
      ny <- info[["rows"]]

      if (is.null(offset)) {
        loaded$extent <- c(xmin,
                           xmin + dx*nx,
                           ymin,
                           ymin + dy*ny)
      } else {
        # Copy the syntax from the ncdf4 package, in which a count of "-1"
        # is taken to mean "all data including and after the offset"
        if (count[1] == -1)
          count[1] = nx - offset[1] + 1
        if (count[2] == -1)
          count[2] = ny - offset[2] + 1

        loaded$extent <- c(xmin + dx*(offset[1] - 1),
                           xmin + dx*(offset[1] - 1 + count[1]),
                           ymin + dy*(ny - offset[2] + 1 - count[2]),
                           ymin + dy*(ny - offset[2] + 1))

      }
    }

    if (is_mon(def$filename)) {
      stopifnot(is.null(offset) && is.null(count))

      vals <- read_mon_file(def$filename)
    } else if (is_ncep_daily_precip(def$filename)) {
      # Ugly special case: a file of global half-degree precipitation from NCEP
      #
      # Because these files are shipped with malformed *.ctl files (that assume the .RT files are in
      # a path on a NOAA server somewhere) we can't convert them to a standard format like netCDF
      # without fudging our own .ctl file.
      #
      stopifnot(is.null(offset) && is.null(count))

      vals <- read_ncep_daily_precip(def$filename)
    } else {
      rast <- rgdal::GDAL.open(def$filename, read.only=TRUE)

      if (is.null(offset)) {
        vals <- t(rgdal::getRasterData(rast,
                                       band=as.integer(var$var_in)))
      } else {
        vals <- t(rgdal::getRasterData(rast,
                                       band=as.integer(var$var_in),
                                       offset=rev(offset)-1,
                                       region.dim=rev(count)))

        # Un-collapse dimension
        if (count[1] == 1) {
          vals <- matrix(vals, ncol=1)
        }
      }

      rgdal::GDAL.close(rast)
    }

    loaded$data[[var$var_out]] <- perform_transforms(vals, var$transforms)
  }

  check_nvars(def, loaded, expect.nvars)
  check_extent(def, loaded, expect.extent)
  check_dims(def, loaded, expect.dims)
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

check_extent <- function(def, data, extent) {
  extent_cmp_eps <- 1e-14

  if (is.null(extent) || all(abs(data$extent - extent) < extent_cmp_eps)) {
    return()
  }

  stop("Unexpected extent of ", def$filename,
       " (expected [", paste(extent, collapse=", "), "]",
       ", got [", paste(data$extent, collapse=", "), "])")
}

check_ids <- function(def, data, ids) {
  if (any(ids != data$ids)) {
    stop("Unexpected IDs in ", def$filename,
         " (expected [", format_ids(ids, 5), "],",
         " got [", format_ids(data$ids, 5), "])")
  }
}

format_ids <- function(ids, n) {
  if (length(ids) < n) {
    paste(ids, collapse=", ")
  } else {
    paste0(paste(ids[1:n], collapse=", "), "...")
  }
}

check_dims <- function(def, data, dims) {
  if (is.null(dims) || length(data$data) == 0 || all(dim(data$data[[1]]) == dims)) {
    return()
  }

  stop("Unexpected dimensions of ", def$filename,
       " (expected [", paste(dims, collapse=", "), "]",
       ", got [", paste(dim(data$data[[1]]), collapse=", "), "])")
}

is_mon <- function(fname) {
  endsWith(fname, '.mon')
}

is_ncep_daily_precip <- function(fname) {
  grepl(
    '^PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.\\d{8}([.]?RT)?([.]gz)?$',
    basename(fname))
}

to_data_frame <- function(dataset) {
  df <- cbind(do.call(combos, dimnames(dataset$data[[1]])),
        lapply(dataset$data, as.vector),
        stringsAsFactors=FALSE)

  # Copy global attributes over to data frame
  for (attrname in names(dataset$attrs)) {
    if (!(attrname %in% c('ids', 'class', 'names')))
      attr(df, attrname) <- dataset$attrs[[attrname]]
  }

  # Copy variable attributes over to data frame
  for (varname in names(dataset$data)) {
    for (attrname in names(attributes(dataset$data[[varname]]))) {
      if (!(attrname %in% c('dim', 'dimnames'))) {
        attr(df[[varname]], attrname) <- attr(dataset$data[[varname]], attrname)
      }
    }
  }

  return(df)
}

to_data_frame_2 <- function(dataset) {
  #as.data.frame.table(dataset$data$fertilizer, responseName='fertilizer', stringsAsFactors=FALSE)
}

to_data_frame_3 <- function(dataset) {
  cbind(do.call(combos, dimnames(dataset$data[[1]])),
        lapply(dataset$data, as.vector),
        stringsAsFactors=FALSE)

  # TODO affix attributes etc.
}
