#' Write model values (state, observations, forcing) to netCDF file
#'
#' @param values One of the following objects:
#'               \itemize{
#'               \item{\code{wsim.lsm.forcing}}
#'               \item{\code{wsim.lsm.results}}
#'               \item{\code{wsim.lsm.state}}
#'               }
#' @param fname Output filename
#'
#' @export
write_lsm_values_to_cdf <- function(values, fname, prec) {
  stopifnot(is.wsim.lsm.forcing(values) ||
            is.wsim.lsm.results(values) ||
            is.wsim.lsm.state(values))

  is_matrix_like <- function(q) { is.vector(dim(q)) }

  # Find the elements of our data that represent pixel-specific values, such
  # as soil moisture.  These should be represented as netCDF variables.
  data_vars <- Filter(is_matrix_like, values)

  # Find the elements of our data that represent constants, such as the timestep
  # date.  These elements should be represented as netCDF global attributes.
  data_attrs <- Filter(Negate(is_matrix_like), values)

  # Find cdf_attrs that are applicable to the variables
  var_attrs <- Filter(function(attr) {
    attr$var %in% names(data_vars)
  }, cdf_attrs)

  # Make sure we found attributes for everything
  if (length(var_attrs) != length(data_vars)) {
    stop("Could not find CDF attributes for all state variables.")
  }

  # Flatten the attributes from the compressed format of cdf_attrs
  # into the verbose format expected by write_vars_to_cdf
  flatten_attributes <- function(att) {
    att_names <- Filter(function(k) {
      k != 'att'
    }, names(att))

    lapply(att_names, function(k) {
      list(
        var= att$var,
        key= k,
        val= att[[k]]
      )
    })
  }

  # Transform the state attrs into global netCDF attrs
  global_attrs <- lapply(names(data_attrs), function(k) {
    list(key=k, val=values[[k]])
  })

  # Merge the flattened attributes with any constants (such as timestamp date), which
  # will be applied as global attributes.
  flat_attrs <- c(do.call(c, lapply(var_attrs, flatten_attributes)), global_attrs)

  wsim.io::write_vars_to_cdf(data_vars,
                             fname,
                             extent=values$extent,
                             fname,
                             attrs=flat_attrs,
                             prec=prec)
}
