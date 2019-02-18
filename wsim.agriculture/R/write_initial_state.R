#' Write an empty agriculture state file to disk
#' 
#' @param fname      name of output file
#' @param dim        dimensions of state (e.g., (360, 720))
#' @param extent     spatial extent, specified as vector of (xmin, xmax, ymin, ymax)
#' @param crop_names values of crop dimension (e.g., maize_1, maize_1, rice_1, etc.)
#' @param stresses   values of stress dimension (e.g., surplus, deficit, heat, cold)
#' @param fill_zero  whether to fill \code{months_stress} and \code{cumulative_loss}
#'                   variables with zero. If these will be fully overwritten by a later
#'                   process, this is unnecessary.
#' @export
write_empty_state <- function(fname, dim, extent, crop_names, stresses, fill_zero=TRUE) {
  months_stress <- array(0L, dim=c(dim, length(crop_names), length(stresses)))
  
  cumulative_loss <- array(0L, dim=c(dim, length(crop_names)))
  
  wsim.io::write_vars_to_cdf(
    list(months_stress=months_stress),
    fname,
    extent=extent,
    extra_dims=list(crop=crop_names,
                    stress=stresses),
    prec='byte',
    put_data=fill_zero)
  
  wsim.io::write_vars_to_cdf(
    list(cumulative_loss=cumulative_loss),
    fname,
    extent=extent,
    extra_dims=list(crop=crop_names),
    prec='double',
    append=TRUE,
    put_data=fill_zero)
}

#' Write an empty agriculture results file to disk
#' 
#' @inheritParams write_empty_state
#' @export
write_empty_results <- function(fname, dim, extent, crop_names, methods, fill_zero=TRUE) {
  placeholder <- array(0L, dim=c(dim, length(crop_names), length(methods)))
  
  wsim.io::write_vars_to_cdf(
    list(loss=placeholder,
         growing_season_loss=placeholder),
    fname,
    extent=extent,
    extra_dims=list(crop=crop_names),
    prec='single',
    put_data=fill_zero)
}
