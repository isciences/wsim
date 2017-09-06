#' Write model state to netCDF file
#'
#' @param state
#' @param xmin
#' @param xmax
#' @param ymin
#' @param ymax
#' @param fname
#' @param cdf_attrs A list of variable attributes, where each item is defined by a list
#'                  containing the item "var", and one or more other items representing
#'                  attributes to be applied to "var".
#'
#' @export
write_state_to_cdf <- function(state, xmin, xmax, ymin, ymax, fname, cdf_attrs) {
  is_matrix_like <- function(q) { is.vector(dim(q)) }

  # Find the elements of our state that represent pixel-specific values, such
  # as soil moisture.  These should be represented as netCDF variables.
  state_vars <- Filter(is_matrix_like, state)

  # Find the elements of our state that represent constants, such as the timestep
  # date.  These elements should be represented as netCDF global attributes.
  state_attrs <- Filter(Negate(is_matrix_like), state)

  # Find cdf_attrs that are applicable to the variables
  var_attrs <- Filter(function(attr) {
    attr$var %in% names(state_vars)
  }, cdf_attrs)

  # Make sure we found attributes for everything
  if (length(var_attrs) != length(state_vars)) {
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
  global_attrs <- lapply(names(state_attrs), function(k) {
    list(key=k, val=state[[k]])
  })

  # Merge the flattened attributes with any constants (such as timestamp date), which
  # will be applied as global attributes.
  flat_attrs <- c(do.call(c, lapply(var_attrs, flatten_attributes)), global_attrs)

  wsim.io::write_vars_to_cdf(state_vars, xmin, xmax, ymin, ymax, fname, attrs=flat_attrs)
}
