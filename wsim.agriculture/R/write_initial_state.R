#' Write an empty agriculture state file to disk
#' 
#' @param fname      name of output file
#' @param res        resolution in degrees
#' @param extent     spatial extent, specified as vector of (xmin, xmax, ymin, ymax)
#' @param crop_names values of crop dimension (e.g., maize_1, maize_1, rice_1, etc.)
#' @param fill_zero  whether to fill \code{months_stress} and \code{cumulative_loss}
#'                   variables with zero. If these will be fully overwritten by a later
#'                   process, this is unnecessary.
#' @export
write_empty_state <- function(fname, 
                              res=0.5,
                              extent=c(-180, 180, -90, 90),
                              crop_names=wsim_subcrop_names(),
                              fill_zero=TRUE) {
  write_empty_results(fname, res, extent,
                      crop_names=crop_names,
                      vars=c('fraction_remaining_current_year',
                             'fraction_remaining_next_year',
                             'loss_days_current_year',
                             'loss_days_next_year'),
                      fill_zero=fill_zero) 
}

#' Write an empty agriculture results file to disk
#' 
#' @param vars a list of variable names to create in the results file
#' @inheritParams write_empty_state
#' @export
write_empty_results <- function(fname,
                                res=0.5,
                                extent=c(-180, 180, -90, 90),
                                crop_names=wsim_subcrop_names(),
                                vars=c('loss',
                                       'mean_loss_current_year',
                                       'mean_loss_next_year',
                                       'cumulative_loss_current_year',
                                       'cumulative_loss_next_year'),
                                fill_zero=TRUE) {
  dim <- c((extent[4]-extent[3]), (extent[2]-extent[1]))/res
  
  placeholder <- array(0L, dim=c(dim, length(crop_names)))
  
  to_write <- list()
  for (var in vars) {
    to_write[[var]] <- placeholder
  }
  
  wsim.io::write_vars_to_cdf(
    to_write,
    fname,
    extent=extent,
    extra_dims=list(crop=crop_names),
    prec='single',
    put_data=fill_zero)
}
