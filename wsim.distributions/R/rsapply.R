#' Apply a per-pixel function across a Raster*
#'
#' \code{rsapply} accepts either a single RasterLayer or a multi-layer RasterStack/RasterBrick.
#' At each pixel, \code{fun} will be called with a vector representing the values of
#' each layer at that pixel.  \code{fun} must return a vector of the same length
#' at every pixel.  If \code{fun} returns a vector with more than one element,
#' the result will be returned as a RasterStack; otherwise, it will be returned
#' as a RasterLayer.
#'
#' @param rast A Raster*
#' @param fun a function to apply to each pixel of the raster.  The function
#'        will be called with a vector representing the pixel values of
#'        each raster in the stack, at a given (x,y).
#' @param names the names of the values returned by fun
#' @return a new RasterLayer or RasterStack containing the values returned by
#'         \code{fun} at each pixel.
#'@examples
#'\dontrun{
#'#
#'# Fit per-pixel GEV distributions, given a RasterStack of
#'# observed values.
#'rsapply(observed, function(pvals) {
#'  lmr <- lmom::samlmu(pvals, nmom = 5)
#'  ret <- try(lmom::pelgev(lmr), silent=FALSE)
#'}, names=c('location', 'scale', 'shape'))}
#'
#'\dontrun{
#'# Compute summary statistics over time-integrated observations
#'rsapply(precip_6mo, function(pvals) {
#'  c(min(pvals), mean(pvals), max(pvals))
#'}, names=c('min', 'ave', 'max'))
#'}
#'@export
rsapply <- function(rast, fun, names=NULL) {
  # Copy our inputs to an in-memory matrix, for speed
  data <- raster::as.array(rast)

  result_data <- apply(data, c(1,2), fun)

  if (length(dim(result_data)) == 2) {
    # fun returned a single value, so we return a raster
    return(raster::raster(result_data, template=rast))
  }

  result_stack <- raster::stack(apply(result_data, 1, function(v) raster::raster(v, template=rast)))

  if (!is.null(names)) {
    names(result_stack) <- names
  }

  return (result_stack)
}
