#' Write an initial agriculture state file to disk
#' 
#' @param fname      name of output file
#' @param dim        dimensions of state (e.g., (360, 720))
#' @param extent     spatial extent, specified as vector of (xmin, xmax, ymin, ymax)
#' @param crop_names values of crop dimension (e.g., maize_1, maize_1, rice_1, etc.)
#' @param stresses   values of stress dimension (e.g., surplus, deficit, heat, cold)
#' @export
write_empty_state <- function(fname, dim, extent, subcrop_names, stresses, fill_zero=TRUE) {
  months_stress <- array(0L, dim=c(dim, length(subcrop_names), length(stresses)))
  
  cumulative_loss <- array(0L, dim=c(dim, length(subcrop_names)))
  
  write_vars_to_cdf(list(months_stress=months_stress),
                    fname,
                    extent=extent,
                    extra_dims=list(crop=subcrop_names,
                                    stress=stresses),
                    prec='byte',
                    put_data=fill_zero)
  
  write_vars_to_cdf(list(cumulative_loss=cumulative_loss),
                    fname,
                    extent=extent,
                    extra_dims=list(crop=subcrop_names),
                    prec='double',
                    append=TRUE,
                    put_data=fill_zero)
}
