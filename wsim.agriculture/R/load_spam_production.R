#' Load SPAM production for one or more crops / methods
#' 
#' @param spam_zip_fpath path to SPAM zip (\code{spam2010v1r0_global_prod.geotiff.zip})
#' @param spam_abbrevs SPAM abbreviations to load (e.g., \code{barl}, \code{whea})
#' @param methods cultivation methods (\code{irrigated} and/or \code{rainfed})
#' @return matrix of production values
#' @export
load_spam_production <- function(spam_zip_fpath, spam_abbrevs, methods) {
  workdir <- tempdir()
  tot <- NULL
  
  for (method in methods){
    stopifnot(method %in% c('irrigated', 'i', 'rainfed', 'r'))
  
    for (abbrev in spam_abbrevs) {
      fname <- sprintf('spam2010v1r0_global_production_%s_%s.tif', abbrev, substr(method, 1, 1))
      fpath <- sprintf('spam2010v1r0_global_prod.geotiff/%s', fname)
      
      unzip(spam_zip_fpath, fpath, junkpaths=TRUE, exdir=workdir)
      prod <- wsim.io::read_vars(file.path(workdir, fname), expect.nvars = 1)$data[[1]]
      
      if (is.null(tot)) {
        tot <- wsim.lsm::coalesce(prod, 0) # replace NA production (what would that mean?) with zero
      } else {
        tot <- psum(tot, prod, na.rm=TRUE)
      }
      
      file.remove(file.path(workdir, fname))
    }
  }
  
  return(tot)
}

