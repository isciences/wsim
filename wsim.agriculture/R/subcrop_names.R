#' Return a set of crop names incorporating subcrops, where applicable
#' 
#' @param crops        a vector of crop names
#' @param num_subcrops a vector containing the number of subcrops associated
#'                     with each crop
#' @return a vector of subcrop names
#' @export
subcrop_names <- function(crops, num_subcrops) {
  Reduce(c,
         mapply(function(crop_name, nc) {
           if(nc > 1)
                  sprintf('%s_%d', crop_name, 1:nc)
           else
                  crop_name
         }, crops, num_subcrops))
}

#' List the names of implemented WSIM subcrops
#' 
#' @param crops crops for which subcrop names should be returned, or
#'              \code{NULL} for all crops
#' 
#' @export
wsim_subcrop_names <- function(crops=NULL) {
  x <- merge(wsim_crops, mirca_crops)
  x <- x[x$implemented, ]
  if (!is.null(crops)) {
    x <- x[x$wsim_name %in% crops, ]
  }
  subcrop_names(x$wsim_name, x$mirca_subcrops)
}
